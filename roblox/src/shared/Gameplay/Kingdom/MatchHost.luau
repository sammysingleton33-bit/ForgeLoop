--!strict
--[[
	Gameplay/Kingdom/MatchHost — runs an AI Kingdoms match on the server: players, remotes, teams and
	spawns, the fixed simulation tick, world rendering and event fan-out. Server only.

	The future KingdomService (ownership requested from FORGE-00) is a thin loader wrapper around
	this class; until then specs drive it directly with MockEnv + RemoteService.

	API
		MatchHost.new(env, remoteService, options?): MatchHost       -- builds; never yields
			options: { seed?, tickSeconds = 0.25, snapshotEvery = 0.5, overviewEvery = 2,
			           match = { ...Match options }, worldView = true, groundY = 0,
			           positionOf = (player) -> (x, z)? }   -- default: the character's HumanoidRootPart
		host:start()        -- connects Players, handles current players, spawns the tick loop
		host:step(dt)       -- one host tick (the loop calls it; specs may call it directly)
		host:destroy()      -- stops the loop, disconnects, removes teams, spawns and world parts
		host.match          -- the Match (state, sim, ...)
		host.events: Signal -- fires (name, event) for every simulation/match event, in order
		host:kingdomOf(player): string?
		host:roundSnapshot(): { state, roundId, endsAtServerTime?, aliveCount }

	Remotes handled (declared in Gameplay/Remotes.luau): every command remote returns
	(ok, errorCode?, result?) from Kingdom/Commands; GetKingdomState / GetRoundState serve joiners.
	Fan-out:
		KingdomSnapshot  -> each kingdom's rulers every snapshotEvery seconds, and right after a
		                    successful command of theirs (instant feedback)
		KingdomOverview  -> everyone every overviewEvery seconds
		KingdomEvent     -> notable events: kingdom-scoped ones to that kingdom's rulers; wars, peace,
		                    eliminations and day/night to everyone (ResourceDelivered is not sent:
		                    snapshots carry balances)
		MatchPhase       -> everyone on every phase change and countdown start/stop (G2 MatchPhase)
		RoundState / RoundResult / Eliminated (interfaces §4) and GameEvents.RoundStateChanged (only when
		the mapped round state changes: Lobby / Countdown / Active / Results), RoundEnded (exactly once per
		match), PlayerEliminated (each ruler of a conquered kingdom).
	Ruler positions: every tick the host mirrors each ruler's character position into the simulation
	(capture zones count rulers) and uses the same server-side position to range-check Gather.
	Teams: one Team per kingdom (Layout teamColor) with a SpawnLocation beside its keep, so a ruler's
	character spawns at home. Players who cannot join (all kingdoms full) stay neutral spectators.
]]

local GameEvents = require("../../Contracts/GameEvents")
local Signal = require("../../Core/Signal")
local Layout = require("./Layout")
local Match = require("./Match")
local RulerGather = require("./RulerGather")
local Snapshot = require("./Snapshot")
local WorldView = require("./WorldView")

local MatchHost = {}
MatchHost.__index = MatchHost

local COMMAND_REMOTES: { { remote: string, command: string } } = {
	{ remote = "Gameplay.PlaceBuilding", command = "PlaceBuilding" },
	{ remote = "Gameplay.UpgradeBuilding", command = "UpgradeBuilding" },
	{ remote = "Gameplay.CancelConstruction", command = "CancelConstruction" },
	{ remote = "Gameplay.SetJobQuota", command = "SetJobQuota" },
	{ remote = "Gameplay.SetPriority", command = "SetPriority" },
	{ remote = "Gameplay.SetAlarm", command = "SetAlarm" },
	{ remote = "Gameplay.Recruit", command = "Recruit" },
	{ remote = "Gameplay.ArmyOrder", command = "ArmyOrder" },
}

local KINGDOM_EVENTS = {
	BuildingPlaced = true,
	UpgradeStarted = true,
	BuildingCompleted = true,
	ConstructionCancelled = true,
	CitizenBorn = true,
	CitizenDied = true,
	RecruitQueued = true,
	UnitRecruited = true,
	UnitKilled = true,
	BuildingDestroyed = true,
	AlarmChanged = true,
	ArmyOrdered = true,
	RulerJoined = true,
	RulerLeft = true,
	CrownPoints = true,
	RegionClaimed = true,
}
local GLOBAL_EVENTS = {
	WarDeclared = true,
	PeaceProposed = true,
	PeaceMade = true,
	KingdomEliminated = true,
	ObjectiveCaptured = true,
	DayStarted = true,
	NightFell = true,
	MatchEnded = true,
}

function MatchHost.new(env: any, remotes: any, options: { [string]: any }?)
	local opts = options or {}
	local self = setmetatable({}, MatchHost)
	self._env = env
	self._remotes = remotes
	self._tick = opts.tickSeconds or 0.25
	self._snapshotEvery = opts.snapshotEvery or 0.5
	self._overviewEvery = opts.overviewEvery or 2
	self._worldViewEnabled = if opts.worldView == nil then true else opts.worldView
	self._groundY = opts.groundY or 0
	self._snapshotClock = 0
	self._overviewClock = 0
	self._seq = 0
	self._connections = {} :: { any }
	self._running = false
	self._dirty = {} :: { [string]: boolean }
	self._roundState = nil :: string?
	self._positionOf = opts.positionOf or MatchHost.characterPosition
	self.events = Signal.new()

	local matchOptions = table.clone(opts.match or {})
	matchOptions.random = matchOptions.random or env.random(opts.seed)
	matchOptions.now = matchOptions.now or env.now
	self.match = Match.new(matchOptions)
	self:_buildWorld()

	for _, entry in COMMAND_REMOTES do
		remotes:handle(entry.remote, function(player: any, ...: any)
			return self:_command(player, entry.command, ...)
		end)
	end
	remotes:handle("Gameplay.ArmyAttack", function(player: any, kingdomId: string)
		return self:_command(player, "ArmyOrder", "Attack", kingdomId)
	end)
	remotes:handle("Gameplay.Diplomacy", function(player: any, action: string, kingdomId: string)
		return self:_command(player, action, kingdomId)
	end)
	remotes:handle("Gameplay.ChooseKingdom", function(player: any, kingdomId: string)
		local ok, result = self.match:choose(player.UserId, kingdomId)
		if not ok then
			return false, result
		end
		self:_assignTeam(player)
		self._dirty[result] = true
		return true, nil, { kingdomId = result }
	end)
	remotes:handle("Gameplay.Gather", function(player: any, nodeId: string)
		if self.match:kingdomOf(player.UserId) == nil then
			return false, "not_in_match"
		end
		local x, z = self._positionOf(player)
		if x == nil or z == nil then
			return false, "no_character"
		end
		local ok, err, result = RulerGather.gather(self.match.sim, player.UserId, nodeId, x :: number, z :: number)
		if ok then
			self._dirty[self.match:kingdomOf(player.UserId) :: string] = true
		end
		return ok, err, result
	end)
	remotes:handle("Gameplay.GetKingdomState", function(player: any)
		local kingdomId = self.match:kingdomOf(player.UserId)
		self._seq += 1
		return {
			round = self:roundSnapshot(),
			kingdomId = kingdomId,
			kingdom = if kingdomId then Snapshot.kingdom(self.match.sim, kingdomId, self._seq) else nil,
			overview = Snapshot.overview(self.match.sim, self._seq),
		}
	end)
	remotes:handle("Gameplay.GetRoundState", function(_player: any)
		return self:roundSnapshot()
	end)
	return self
end

-- ---------------------------------------------------------------- world, teams, spawns
function MatchHost:_buildWorld()
	local env = self._env
	local sim = self.match.sim
	if self._worldViewEnabled then
		self._view = WorldView.new(env, { groundY = self._groundY })
		self._view:sync(sim)
	end
	self._teams = {} :: { [string]: any }
	self._spawns = {} :: { [string]: any }
	for _, kid in sim.kingdomOrder do
		local kingdom = sim.kingdoms[kid]
		local identity = Layout.KINGDOMS[kingdom.index]
		local team = env.newInstance("Team")
		team.Name = kingdom.name
		team.TeamColor = BrickColor.new(identity.teamColor)
		team.AutoAssignable = false
		team:SetAttribute("KingdomId", kid)
		team.Parent = env.Teams
		self._teams[kid] = team

		local spawnPoint = env.newInstance("SpawnLocation")
		spawnPoint.Name = `Spawn_{kid}`
		spawnPoint.Anchored = true
		spawnPoint.Size = Vector3.new(10, 1, 10)
		local toCentre = math.atan2(-kingdom.z, -kingdom.x)
		local keep = sim.buildings[kingdom.keepId]
		local distance = keep.footprint + 10
		spawnPoint.CFrame = CFrame.new(
			kingdom.x + math.cos(toCentre) * distance,
			self._groundY + 0.5,
			kingdom.z + math.sin(toCentre) * distance
		)
		spawnPoint.TeamColor = team.TeamColor
		spawnPoint.Neutral = false
		spawnPoint.AllowTeamChangeOnTouch = false
		spawnPoint.Duration = 0
		spawnPoint:SetAttribute("KingdomId", kid)
		spawnPoint.Parent = if self._view then self._view._root else env.Workspace
		self._spawns[kid] = spawnPoint
	end
end

function MatchHost:_destroyWorld()
	for _, team in self._teams do
		team:Destroy()
	end
	for _, spawnPoint in self._spawns do
		if spawnPoint.Parent ~= nil then
			spawnPoint:Destroy()
		end
	end
	if self._view then
		self._view:destroy()
		self._view = nil
	end
	self._teams = {}
	self._spawns = {}
end

function MatchHost:_assignTeam(player: any)
	local kingdomId = self.match:kingdomOf(player.UserId)
	local team = if kingdomId then self._teams[kingdomId] else nil
	if player.Team ~= team then
		player.Team = team
		player.Neutral = team == nil
		if player.Character ~= nil then
			player:LoadCharacter() -- respawn at the new kingdom
		end
	end
end

-- ---------------------------------------------------------------- players
function MatchHost:kingdomOf(player: any): string?
	return self.match:kingdomOf(player.UserId)
end

function MatchHost:_onPlayerAdded(player: any)
	local ok, result = self.match:join(player.UserId)
	if not ok then
		self._env.log("info", "KingdomHost: player is spectating", { userId = player.UserId, reason = result })
	else
		self._dirty[result] = true
	end
	self:_assignTeam(player)
	self._remotes:fire("Gameplay.RoundState", player, self:_roundArgs())
end

function MatchHost:_onPlayerRemoving(player: any)
	local kingdomId = self.match:kingdomOf(player.UserId)
	self.match:leave(player.UserId)
	if kingdomId then
		self._dirty[kingdomId] = true
	end
end

-- ---------------------------------------------------------------- commands
function MatchHost:_command(player: any, name: string, ...: any): (boolean, string?, any?)
	local kingdomId = self.match:kingdomOf(player.UserId)
	if kingdomId == nil then
		return false, "not_in_match"
	end
	local ok, err, result = self.match:command(player.UserId, name, ...)
	if ok then
		-- instant feedback: every ruler of the kingdom sees the change before the next tick
		self:_sendKingdomSnapshot(kingdomId)
	end
	return ok, err, result
end

-- ---------------------------------------------------------------- round info
function MatchHost:_aliveCount(): number
	local n = 0
	local sim = self.match.sim
	for _, kid in sim.kingdomOrder do
		if sim.kingdoms[kid].alive then
			n += 1
		end
	end
	return n
end

function MatchHost:roundSnapshot()
	local remaining = self.match:remaining()
	return {
		state = self:roundState(),
		phase = self.match.state,
		roundId = self.match.roundId,
		endsAtServerTime = if remaining then self._env.serverTimeNow() + remaining else nil,
		aliveCount = self:_aliveCount(),
	}
end

function MatchHost:_roundArgs(): ...any
	local snap = self:roundSnapshot()
	return snap.state, snap.roundId, snap.endsAtServerTime, snap.aliveCount
end

-- Maps the game phase to the framework round state (interfaces §4) for round HUDs and GameEvents.
function MatchHost:roundState(): string
	local phase = self.match.state
	if phase == "Lobby" then
		return if self.match:remaining() ~= nil then "Countdown" else "Lobby"
	elseif phase == "Results" then
		return "Results"
	end
	return "Active"
end

-- Default ruler position: the character's HumanoidRootPart, read on the server (never from a client).
function MatchHost.characterPosition(player: any): (number?, number?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return nil, nil
	end
	local p = root.Position
	return p.X, p.Z
end

function MatchHost:_phaseChanged()
	local remaining = self.match:remaining()
	local endsAt = if remaining then self._env.serverTimeNow() + remaining else nil
	self._remotes:fireAll("Gameplay.MatchPhase", self.match.state, endsAt)
	local roundState = self:roundState()
	local snap = self:roundSnapshot()
	self._remotes:fireAll("Gameplay.RoundState", snap.state, snap.roundId, snap.endsAtServerTime, snap.aliveCount)
	if roundState ~= self._roundState then
		self._roundState = roundState
		GameEvents.RoundStateChanged:fire(roundState, {
			roundId = self.match.roundId,
			endsAt = if remaining then self._env.now() + math.ceil(remaining) else nil,
		})
	end
end

-- ---------------------------------------------------------------- event fan-out
function MatchHost:_rulersOf(kingdomId: string): { any }
	local out = {}
	local kingdom = self.match.sim.kingdoms[kingdomId]
	if kingdom == nil then
		return out
	end
	for _, userId in kingdom.rulers do
		local player = self._env.Players:GetPlayerByUserId(userId)
		if player then
			table.insert(out, player)
		end
	end
	return out
end

function MatchHost:_publicEvent(event: any): { [string]: any }
	local out = {}
	for key, value in event do
		local t = type(value)
		if t == "string" or t == "number" or t == "boolean" then
			out[key] = value
		elseif t == "table" then
			out[key] = table.clone(value) -- refund / loot / winnerKingdomIds: flat tables
		end
	end
	return out
end

function MatchHost:_handleEvent(event: any)
	self.events:fire(event.name, event)
	local name = event.name
	if name == "CountdownChanged" then
		self:_phaseChanged()
		return
	end
	if name == "MatchPhaseChanged" then
		self:_phaseChanged()
		if event.previous == "Results" then
			-- a fresh world was created for the next match: rebuild the view and re-team everyone
			self:_destroyWorld()
			self:_buildWorld()
			for _, player in self._env.Players:GetPlayers() do
				self:_assignTeam(player)
			end
		end
		return
	end
	if name == "MatchEnded" then
		local result = self.match:result()
		self._remotes:fireAll("Gameplay.RoundResult", result)
		GameEvents.RoundEnded:fire(result)
	end
	if name == "KingdomEliminated" then
		self:_announceElimination(event)
	end
	if name == "ResourceGathered" and event.source == "ruler" and event.userId then
		local player = self._env.Players:GetPlayerByUserId(event.userId)
		if player then
			self._remotes:fire("Gameplay.KingdomEvent", player, self:_publicEvent(event))
		end
		return
	end
	if GLOBAL_EVENTS[name] then
		self._remotes:fireAll("Gameplay.KingdomEvent", self:_publicEvent(event))
	elseif KINGDOM_EVENTS[name] and event.kingdomId then
		local payload = self:_publicEvent(event)
		for _, player in self:_rulersOf(event.kingdomId) do
			self._remotes:fire("Gameplay.KingdomEvent", player, payload)
		end
		self._dirty[event.kingdomId] = true
	end
end

function MatchHost:_announceElimination(event: any)
	local sim = self.match.sim
	local kingdom = sim.kingdoms[event.kingdomId]
	local conqueror = event.byKingdomId and sim.kingdoms[event.byKingdomId]
	local byUserId = if conqueror and #conqueror.rulers > 0 then conqueror.rulers[1] else nil
	local byPlayer = if byUserId then self._env.Players:GetPlayerByUserId(byUserId) else nil
	local aliveCount = self:_aliveCount()
	for _, userId in kingdom.rulers do
		self._remotes:fireAll(
			"Gameplay.Eliminated",
			{ userId = userId, cause = "conquered", byUserId = byUserId, aliveCount = aliveCount }
		)
		local player = self._env.Players:GetPlayerByUserId(userId)
		if player then
			GameEvents.PlayerEliminated:fire(
				player,
				{ roundId = self.match.roundId, cause = "conquered", by = byPlayer }
			)
		end
	end
end

-- ---------------------------------------------------------------- tick
function MatchHost:_sendKingdomSnapshot(kingdomId: string)
	local rulers = self:_rulersOf(kingdomId)
	if #rulers == 0 then
		return
	end
	self._seq += 1
	local snapshot = Snapshot.kingdom(self.match.sim, kingdomId, self._seq)
	for _, player in rulers do
		self._remotes:fire("Gameplay.KingdomSnapshot", player, snapshot)
	end
end

function MatchHost:_sendSnapshots(all: boolean)
	for _, kid in self.match.sim.kingdomOrder do
		if all or self._dirty[kid] then
			self:_sendKingdomSnapshot(kid)
		end
	end
	self._dirty = {}
end

function MatchHost:_mirrorRulers()
	local sim = self.match.sim
	for userId in sim.rulerOf do
		local player = self._env.Players:GetPlayerByUserId(userId)
		local x, z = nil, nil
		if player then
			x, z = self._positionOf(player)
		end
		sim:setRulerPosition(userId, x, z)
	end
end

function MatchHost:step(dt: number)
	self:_mirrorRulers()
	self.match:update(dt)
	for _, event in self.match:drainEvents() do
		self:_handleEvent(event)
	end
	if self._view then
		self._view:sync(self.match.sim)
	end
	self._snapshotClock += dt
	self._overviewClock += dt
	local periodic = self._snapshotClock >= self._snapshotEvery
	if periodic then
		self._snapshotClock = 0
	end
	if periodic or next(self._dirty) ~= nil then
		self:_sendSnapshots(periodic)
	end
	if self._overviewClock >= self._overviewEvery then
		self._overviewClock = 0
		self._seq += 1
		self._remotes:fireAll("Gameplay.KingdomOverview", Snapshot.overview(self.match.sim, self._seq))
	end
end

function MatchHost:start()
	assert(not self._running, "MatchHost:start: already started")
	self._running = true
	local players = self._env.Players
	table.insert(
		self._connections,
		players.PlayerAdded:Connect(function(player: any)
			self:_onPlayerAdded(player)
		end)
	)
	table.insert(
		self._connections,
		players.PlayerRemoving:Connect(function(player: any)
			self:_onPlayerRemoving(player)
		end)
	)
	for _, player in players:GetPlayers() do
		self:_onPlayerAdded(player)
	end
	self._env.spawn(function()
		while self._running do
			-- use the time actually waited (clamped, so a long hitch does not fast-forward the world)
			local waited = self._env.wait(self._tick)
			if not self._running then
				break
			end
			local dt = math.clamp(if type(waited) == "number" then waited else self._tick, 0, 1)
			local ok, err = pcall(self.step, self, dt)
			if not ok then
				-- one bad tick must not stop the kingdom; log loudly and keep going
				self._env.log("error", "KingdomHost: tick failed", { error = tostring(err) })
			end
		end
	end)
end

function MatchHost:destroy()
	self._running = false
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
	self:_destroyWorld()
	self.events:disconnectAll()
end

return MatchHost
