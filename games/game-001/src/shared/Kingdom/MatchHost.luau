--!strict
--[[
	Kingdom/MatchHost — runs an AI Kingdoms match on the server: players, kingdom remotes, teams and
	spawns, the fixed simulation tick, the interim world view and event fan-out. Server only; owned by
	MatchService (G3), which every other kingdom service reaches it through.

	API
		MatchHost.new(env, remoteService, options?): MatchHost       -- builds; never yields
			options: { seed?, tickSeconds = 0.25, snapshotEvery = 0.5, overviewEvery = 2,
			           match = { ...Match options }, worldView = true, groundY = 0,
			           positionOf = (player) -> (x, z)? }   -- default: the character's HumanoidRootPart
		host:start()        -- connects Players, seats current players, spawns the tick loop
		host:step(dt)       -- one host tick (the loop calls it; specs may call it directly)
		host:destroy()      -- stops the loop, disconnects, removes teams, spawns and world parts
		host.match          -- the Match (state, sim, ...)
		host.events: Signal -- (name, event) for every simulation/match event, in order, exactly once
		host:kingdomOf(player): KingdomId?
		host:command(player, name, ...): (boolean, string?, any?)   -- Sim/Commands for a player
		host:handleCommandRemote(remoteName, commandName, mapArgs?)  -- for Build/Army services (G8)
		host:phaseInfo(): { phase, endsAtServerTime?, roundId, aliveCount }
		host:simMsPerTick(): number         -- mean simulation cost of the last ~30 s (perf, G7)

	Remotes (Kingdom/Remotes.luau): Kingdom.GetState, Choose, Gather, SetJobQuota, SetPriority,
	SetAlarm; fan-out on Kingdom.Snapshot (rulers, ~2/s and after their commands), Kingdom.Overview
	(everyone, every 2 s), Kingdom.Event (notable events) and Kingdom.Phase (every phase change and
	countdown start/stop).
	GameEvents (CONTRACTS G9, framework bus), each exactly once:
		MatchPhaseChanged(phase) · KingdomEliminated(kingdomId, by?) · MatchEnded({ winner?, standings,
		durationSec }) · BuildingPlaced / BuildingCompleted / BuildingUpgraded / BuildingDestroyed
		(Building (G2), player?) · ResourceGathered(player?, kingdomId, resource, amount, source) ·
		UnitsRecruited(player?, kingdomId, count) · ObjectiveCaptured(objectiveId, kingdomId).
		KingdomJoined is fired by KingdomService.
	Ruler positions: each tick the host mirrors every ruler's character position into the simulation
	(capture zones count rulers) and uses the same server-side position to range-check Gather.
	Teams: one Team per kingdom (config Kingdoms teamColor) with a SpawnLocation beside its keep, so a
	ruler's character spawns at home. Players who cannot join (all kingdoms full) stay spectators.
	World view: placeholder parts (Sim/WorldView) until FORGE-02's Kit and the client entity renderer
	(FL-0049) take over.
]]

local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local RulerGather = require("../Sim/RulerGather")
local Snapshot = require("../Sim/Snapshot")
local WorldView = require("../Sim/WorldView")
local Layout = require("./Layout")
local Match = require("./Match")

local MatchHost = {}
MatchHost.__index = MatchHost

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
local SIM_MS_WINDOW = 120 -- ticks in the simMsPerTick average (30 s at 4 Hz)

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
	self._simMs = {} :: { number }
	self._positionOf = opts.positionOf or MatchHost.characterPosition
	self.events = Signal.new()

	local matchOptions = table.clone(opts.match or {})
	matchOptions.random = matchOptions.random or env.random(opts.seed)
	matchOptions.now = matchOptions.now or env.now
	self.match = Match.new(matchOptions)
	self:_buildWorld()

	for _, command in { "SetJobQuota", "SetPriority", "SetAlarm" } do
		self:handleCommandRemote("Kingdom." .. command, command)
	end
	remotes:handle("Kingdom.Choose", function(player: any, kingdomId: string)
		local ok, result = self.match:choose(player.UserId, kingdomId)
		if not ok then
			return false, result
		end
		self:_assignTeam(player)
		self._dirty[result] = true
		return true, nil, { kingdomId = result }
	end)
	remotes:handle("Kingdom.Gather", function(player: any, nodeId: string)
		local kingdomId = self.match:kingdomOf(player.UserId)
		if kingdomId == nil then
			return false, "not_in_match"
		end
		local x, z = self._positionOf(player)
		if x == nil or z == nil then
			return false, "no_character"
		end
		local ok, err, result = RulerGather.gather(self.match.sim, player.UserId, nodeId, x :: number, z :: number)
		if ok then
			self:_sendKingdomSnapshot(kingdomId)
		end
		return ok, err, result
	end)
	remotes:handle("Kingdom.GetState", function(player: any)
		local kingdomId = self.match:kingdomOf(player.UserId)
		self._seq += 1
		local info = self:phaseInfo()
		return {
			phase = info.phase,
			endsAtServerTime = info.endsAtServerTime,
			roundId = info.roundId,
			kingdomId = kingdomId,
			kingdom = if kingdomId then Snapshot.kingdom(self.match.sim, kingdomId, self._seq) else nil,
			overview = Snapshot.overview(self.match.sim, self._seq),
		}
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
	local info = self:phaseInfo()
	self._remotes:fire("Kingdom.Phase", player, info.phase, info.endsAtServerTime)
end

function MatchHost:_onPlayerRemoving(player: any)
	local kingdomId = self.match:kingdomOf(player.UserId)
	self.match:leave(player.UserId)
	if kingdomId then
		self._dirty[kingdomId] = true
	end
end

-- ---------------------------------------------------------------- commands
function MatchHost:command(player: any, name: string, ...: any): (boolean, string?, any?)
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

-- Routes a declared remote to a simulation command (Build/Army services use this for G8 remotes).
function MatchHost:handleCommandRemote(remoteName: string, commandName: string, mapArgs: ((...any) -> ...any)?)
	self._remotes:handle(remoteName, function(player: any, ...: any)
		if mapArgs then
			return self:command(player, commandName, mapArgs(...))
		end
		return self:command(player, commandName, ...)
	end)
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

-- ---------------------------------------------------------------- phase info
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

function MatchHost:phaseInfo()
	local remaining = self.match:remaining()
	return {
		phase = self.match.state,
		endsAtServerTime = if remaining then self._env.serverTimeNow() + remaining else nil,
		roundId = self.match.roundId,
		aliveCount = self:_aliveCount(),
	}
end

function MatchHost:_broadcastPhase()
	local info = self:phaseInfo()
	self._remotes:fireAll("Kingdom.Phase", info.phase, info.endsAtServerTime)
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

function MatchHost:_player(userId: number?): any?
	return if userId then self._env.Players:GetPlayerByUserId(userId) else nil
end

function MatchHost:_publicEvent(event: any): { [string]: any }
	local out = {}
	for key, value in event do
		local t = type(value)
		if t == "string" or t == "number" or t == "boolean" then
			out[key] = value
		elseif t == "table" and key ~= "building" then
			out[key] = table.clone(value) -- refund / loot / winnerKingdomIds / standings: flat tables
		end
	end
	return out
end

-- CONTRACTS G9: each simulation fact becomes exactly one framework GameEvents firing.
function MatchHost:_fireGameEvent(event: any)
	local name = event.name
	local sim = self.match.sim
	if name == "MatchPhaseChanged" then
		GameEvents.MatchPhaseChanged:fire(event.phase)
	elseif name == "KingdomEliminated" then
		GameEvents.KingdomEliminated:fire(event.kingdomId, event.byKingdomId)
	elseif name == "MatchEnded" then
		GameEvents.MatchEnded:fire({
			winner = event.winner,
			standings = event.standings,
			durationSec = event.durationSec,
		})
	elseif name == "BuildingPlaced" then
		GameEvents.BuildingPlaced:fire(sim:buildingView(event.buildingId), self:_player(event.by))
	elseif name == "BuildingCompleted" then
		local view = sim:buildingView(event.buildingId)
		if event.level > 1 then
			GameEvents.BuildingUpgraded:fire(view, nil)
		else
			GameEvents.BuildingCompleted:fire(view, nil)
		end
	elseif name == "BuildingDestroyed" then
		GameEvents.BuildingDestroyed:fire(event.building, nil)
	elseif name == "ResourceGathered" then
		GameEvents.ResourceGathered:fire(
			self:_player(event.userId),
			event.kingdomId,
			event.resource,
			event.amount,
			event.source
		)
	elseif name == "RecruitQueued" then
		GameEvents.UnitsRecruited:fire(self:_player(event.by), event.kingdomId, event.count)
	elseif name == "ObjectiveCaptured" then
		GameEvents.ObjectiveCaptured:fire(event.objectiveId, event.kingdomId)
	end
end

function MatchHost:_handleEvent(event: any)
	self.events:fire(event.name, event)
	self:_fireGameEvent(event)
	local name = event.name
	if name == "CountdownChanged" then
		self:_broadcastPhase()
		return
	end
	if name == "MatchPhaseChanged" then
		self:_broadcastPhase()
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
	if name == "ResourceGathered" then
		if event.source == "ruler" and event.userId then
			local player = self:_player(event.userId)
			if player then
				self._remotes:fire("Kingdom.Event", player, self:_publicEvent(event))
			end
		end
		return -- citizen deliveries are not sent one by one: snapshots carry the balances
	end
	if GLOBAL_EVENTS[name] then
		self._remotes:fireAll("Kingdom.Event", self:_publicEvent(event))
	elseif KINGDOM_EVENTS[name] and event.kingdomId then
		local payload = self:_publicEvent(event)
		for _, player in self:_rulersOf(event.kingdomId) do
			self._remotes:fire("Kingdom.Event", player, payload)
		end
		self._dirty[event.kingdomId] = true
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
		self._remotes:fire("Kingdom.Snapshot", player, snapshot)
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

function MatchHost:simMsPerTick(): number
	local n = #self._simMs
	if n == 0 then
		return 0
	end
	local total = 0
	for _, ms in self._simMs do
		total += ms
	end
	return math.floor(total / n * 1000 + 0.5) / 1000
end

function MatchHost:step(dt: number)
	self:_mirrorRulers()
	local started = self._env.clock()
	self.match:update(dt)
	table.insert(self._simMs, (self._env.clock() - started) * 1000)
	if #self._simMs > SIM_MS_WINDOW then
		table.remove(self._simMs, 1)
	end
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
		self._remotes:fireAll("Kingdom.Overview", Snapshot.overview(self.match.sim, self._seq))
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
