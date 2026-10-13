--!strict
--[[
	Kingdom/MatchHost — runs an AI Kingdoms match on the server: players, the Kingdom and Match remotes,
	teams, the fixed simulation tick, the interim world view and event fan-out. Server only; owned by
	MatchService (G3), through which every other kingdom service reaches it.

	API
		MatchHost.new(env, remoteService, options?): MatchHost       -- builds; never yields
			options: { seed?, tickSeconds = 0.25, stateEvery = 0.5, match = { ...Match options },
			           worldView = true, worldViewEntities = true, worldViewBuildings = "parts",
			           worldViewGround = true, groundY = 0,
			           positionOf = (player) -> (x, z)? }   -- default: the character's HumanoidRootPart
		host:start()        -- connects Players, seats current players, spawns the tick loop
		host:step(dt)       -- one host tick (the loop calls it; specs may call it directly)
		host:destroy()      -- stops the loop, disconnects, removes teams and world parts
		host.match          -- the Match (state, sim, ...)
		host.events: Signal -- (name, event) for every simulation/match event, in order, exactly once
		host.preferredKingdom: ((player) -> KingdomId?)?   -- consulted when a player arrives (KingdomService:
		                                                     party grouping); nil = balanced
		host:kingdomOf(player): KingdomId?
		host:buildingModel(buildingId): Model?              -- the Kit model drawing it (worldView), else nil
		host:kingdomView(kingdomId): Kingdom?               -- CONTRACTS G2 Kingdom (a fresh copy)
		host:kingdomsState(player?): { kingdoms: { Kingdom }, mine: KingdomId? }   -- Kingdom.State payload
		host:assignTeam(player)                             -- Player.Team = the player's kingdom team (or none)
		host:command(player, name, ...): (boolean, string?, any?)   -- Sim/Commands for a player
		host:handleCommandRemote(remoteName, commandName, mapArgs?)  -- for Build/Army services (G8)
		host:phaseInfo(): { phase, endsAtServerTime?, startedAtServerTime, roundId, aliveCount }
		host:simMsPerTick(): number         -- mean simulation cost of the last ~30 s (perf, G7)
		host:simMsP99(): number             -- its 99th percentile

	Remotes (CONTRACTS G8; Kingdom/Remotes.luau and Match/Remotes.luau)
		Kingdom.GetState() -> { kingdoms, mine }      Kingdom.State({ kingdoms, mine }) to every player when a
		                                              kingdom view changes (at most every stateEvery seconds;
		                                              membership changes at once) and to each arriving player
		Kingdom.Gather(nodeId) -> (true, ResourceId, amount) | (false, errorCode)
		Kingdom.SetJobQuota(job, count) -> (boolean, errorCode?)
		Match.GetState() -> (phase, endsAtServerTime?, startedAtServerTime)
		Match.State(phase, endsAtServerTime?, startedAtServerTime) to everyone on every phase or countdown
		                                              change, and to each arriving player
		Match.Ended({ winner?, standings, durationSec }) to everyone when the match (or the slice) ends, and
		                                              to each player who arrives while Results is on
		startedAtServerTime: server time Founding began (sim time 0); in the Lobby, when the Lobby opened.
	GameEvents (CONTRACTS G9, framework bus), each exactly once:
		MatchPhaseChanged(phase) · KingdomEliminated(kingdomId, by?) · MatchEnded({ winner?, standings,
		durationSec }) · BuildingPlaced / BuildingCompleted / BuildingUpgraded / BuildingDestroyed
		(Building (G2), player?) · ResourceGathered(player?, kingdomId, resource, amount, source) ·
		UnitsRecruited(player?, kingdomId, count) · ObjectiveCaptured(objectiveId, kingdomId).
		KingdomJoined is fired by KingdomService.
	Ruler positions: each tick the host mirrors every ruler's character position into the simulation
	(capture zones count rulers) and uses the same server-side position to range-check Gather.
	Teams: one Team per kingdom (config Kingdoms teamColor, AutoAssignable false). Characters are spawned
	by KingdomService (CharacterAutoLoads is false, G3). Players who cannot join (all kingdoms full) stay
	spectators.
	World view: placeholder parts (Sim/WorldView) until FORGE-02's Kit and the client entity renderer
	(FL-0049) take over.
]]

local SocietyConfig = require("@game/ReplicatedStorage/Forge/Config/Society")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local RulerGather = require("../Sim/RulerGather")
local WorldView = require("../Sim/WorldView")
local Layout = require("./Layout")
local Match = require("./Match")

local MatchHost = {}
MatchHost.__index = MatchHost

-- simulation events that change a G2 Kingdom view right away (membership is sent without throttling)
local MEMBERSHIP_EVENTS = { RulerJoined = true, RulerLeft = true }
local SIM_MS_WINDOW = 120 -- ticks in the simMsPerTick average (30 s at 4 Hz)

function MatchHost.new(env: any, remotes: any, options: { [string]: any }?)
	local opts = options or {}
	local self = setmetatable({}, MatchHost)
	self._env = env
	self._remotes = remotes
	self._tick = opts.tickSeconds or 0.25
	self._stateEvery = opts.stateEvery or 0.5
	self._worldViewEnabled = if opts.worldView == nil then true else opts.worldView
	self._worldViewEntities = if opts.worldViewEntities == nil then true else opts.worldViewEntities
	self._worldViewBuildings = opts.worldViewBuildings or "parts"
	self._worldViewGround = if opts.worldViewGround == nil then true else opts.worldViewGround
	self._groundY = opts.groundY or 0
	self._stateClock = 0
	self._lastStateSignature = ""
	self._membershipChanged = false
	self._connections = {} :: { any }
	self._running = false
	self._simMs = {} :: { number }
	self._positionOf = opts.positionOf or MatchHost.characterPosition
	self._startedAtServerTime = env.serverTimeNow()
	self.preferredKingdom = nil :: ((player: any) -> string?)?
	self.events = Signal.new()

	local matchOptions = table.clone(opts.match or {})
	matchOptions.random = matchOptions.random or env.random(opts.seed)
	matchOptions.now = matchOptions.now or env.now
	self.match = Match.new(matchOptions)
	self:_buildWorld()

	self:handleCommandRemote("Kingdom.SetJobQuota", "SetJobQuota")
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
		if not ok then
			return false, err
		end
		return true, result.resource, result.amount
	end)
	remotes:handle("Kingdom.GetState", function(player: any)
		return self:kingdomsState(player)
	end)
	remotes:handle("Match.GetState", function()
		local info = self:phaseInfo()
		return info.phase, info.endsAtServerTime, info.startedAtServerTime
	end)
	return self
end

-- ---------------------------------------------------------------- world, teams
function MatchHost:_buildWorld()
	local env = self._env
	local sim = self.match.sim
	if self._worldViewEnabled then
		self._view = WorldView.new(env, {
			groundY = self._groundY,
			entities = self._worldViewEntities,
			buildings = self._worldViewBuildings,
			createGround = self._worldViewGround,
		})
		self._view:sync(sim)
	end
	self._teams = {} :: { [string]: any }
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
	end
end

function MatchHost:_destroyWorld()
	for _, team in self._teams do
		team:Destroy()
	end
	if self._view then
		self._view:destroy()
		self._view = nil
	end
	self._teams = {}
end

function MatchHost:assignTeam(player: any)
	local kingdomId = self.match:kingdomOf(player.UserId)
	local team = if kingdomId then self._teams[kingdomId] else nil
	if player.Team ~= team then
		player.Team = team
		player.Neutral = team == nil
	end
end

-- ---------------------------------------------------------------- players
function MatchHost:kingdomOf(player: any): string?
	return self.match:kingdomOf(player.UserId)
end

-- The model drawing a building (WorldView; rebuilt when its level or stage changes), else nil.
function MatchHost:buildingModel(buildingId: number): any?
	return if self._view then self._view:find("building", buildingId) else nil
end

function MatchHost:_onPlayerAdded(player: any)
	local preferred = nil
	if self.preferredKingdom then
		preferred = self.preferredKingdom(player)
	end
	local ok, result = self.match:join(player.UserId, preferred)
	if not ok then
		self._env.log("info", "KingdomHost: player is spectating", { userId = player.UserId, reason = result })
	end
	self:assignTeam(player)
	local info = self:phaseInfo()
	self._remotes:fire("Match.State", player, info.phase, info.endsAtServerTime, info.startedAtServerTime)
	self._remotes:fire("Kingdom.State", player, self:kingdomsState(player))
	if self._ended then -- set by MatchEnded, cleared when Results ends
		self._remotes:fire("Match.Ended", player, MatchHost.endedPayload(self._ended)) -- what a late joiner missed
	end
end

function MatchHost:_onPlayerRemoving(player: any)
	self.match:leave(player.UserId)
end

-- ---------------------------------------------------------------- kingdom views (G2)
function MatchHost:kingdomView(kingdomId: string): { [string]: any }?
	local sim = self.match.sim
	local k = sim.kingdoms[kingdomId]
	if k == nil then
		return nil
	end
	local regions = {}
	local conditions = k.conditions or SocietyConfig.conditionStart -- ReputationService keeps k.conditions (G13.4)
	local plot = Layout.WORLD.plots[kingdomId]
	if plot and k.alive then
		table.insert(regions, plot.regionId) -- the home region (world Layout) is the kingdom's from the start
	end
	for _, regionId in sim.regionOrder do
		if sim.regions[regionId].kingdomId == kingdomId then
			table.insert(regions, regionId)
		end
	end
	return {
		id = k.id,
		name = k.name,
		color = Color3.fromRGB(k.color[1], k.color[2], k.color[3]),
		rulers = table.clone(k.rulers),
		isAI = #k.rulers == 0,
		keepBuildingId = if k.alive then k.keepId else nil,
		crownPoints = k.crownPoints,
		regions = regions,
		alive = k.alive,
		happiness = conditions.happiness,
		stability = conditions.stability,
		morale = conditions.morale,
	}
end

function MatchHost:kingdomsState(player: any?): { kingdoms: { any }, mine: string? }
	local kingdoms = {}
	for _, kid in self.match.sim.kingdomOrder do
		table.insert(kingdoms, self:kingdomView(kid))
	end
	return { kingdoms = kingdoms, mine = if player then self.match:kingdomOf(player.UserId) else nil }
end

-- What clients can see of the views; Crown Points count in whole points so hold income does not
-- resend the state every tick.
local function whole(x: number?): number
	return math.floor((x or 0) + 0.5)
end

-- What makes Kingdom.State worth sending again. The conditions drift every second, so they count when a
-- whole point changes (#68 L4), not on every fraction.
function MatchHost:_stateSignature(): string
	local parts = {}
	for _, view in self:kingdomsState().kingdoms do
		table.insert(
			parts,
			`{view.id}:{table.concat(view.rulers, ",")}:{math.floor(view.crownPoints)}:{view.alive}:{view.keepBuildingId}:{table.concat(
				view.regions,
				","
			)}:{whole(view.happiness)}:{whole(view.stability)}:{whole(view.morale)}`
		)
	end
	return table.concat(parts, "|")
end

function MatchHost:_sendKingdomState(force: boolean)
	local signature = self:_stateSignature()
	if signature == self._lastStateSignature then
		return
	end
	if not force and self._stateClock < self._stateEvery then
		return
	end
	self._lastStateSignature = signature
	self._stateClock = 0
	for _, player in self._env.Players:GetPlayers() do
		self._remotes:fire("Kingdom.State", player, self:kingdomsState(player))
	end
end

-- ---------------------------------------------------------------- commands
function MatchHost:command(player: any, name: string, ...: any): (boolean, string?, any?)
	if self.match:kingdomOf(player.UserId) == nil then
		return false, "not_in_match"
	end
	return self.match:command(player.UserId, name, ...)
end

-- Routes a declared remote to a simulation command (Build/Army services use this for G8 remotes).
function MatchHost:handleCommandRemote(remoteName: string, commandName: string, mapArgs: ((...any) -> ...any)?)
	self._remotes:handle(remoteName, function(player: any, ...: any)
		local ok, err
		if mapArgs then
			ok, err = self:command(player, commandName, mapArgs(...))
		else
			ok, err = self:command(player, commandName, ...)
		end
		return ok, err
	end)
end

-- Default ruler position: the character's HumanoidRootPart, read on the server (never from a client).
function MatchHost.characterPosition(player: any): (number?, number?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil then
		return nil, nil
	end
	local p = root.CFrame.Position
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
		startedAtServerTime = self._startedAtServerTime,
		roundId = self.match.roundId,
		aliveCount = self:_aliveCount(),
	}
end

function MatchHost:_broadcastPhase()
	local info = self:phaseInfo()
	self._remotes:fireAll("Match.State", info.phase, info.endsAtServerTime, info.startedAtServerTime)
end

-- ---------------------------------------------------------------- event fan-out
function MatchHost:_player(userId: number?): any?
	return if userId then self._env.Players:GetPlayerByUserId(userId) else nil
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
		GameEvents.MatchEnded:fire(MatchHost.endedPayload(event))
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

-- The G9 MatchEnded payload (also the Match.Ended remote payload): a fresh copy, contract fields only.
function MatchHost.endedPayload(event: any): { [string]: any }
	local standings = {}
	for _, row in event.standings do
		table.insert(standings, { kingdom = row.kingdom, crownPoints = row.crownPoints })
	end
	return { winner = event.winner, standings = standings, durationSec = event.durationSec }
end

function MatchHost:_handleEvent(event: any)
	self.events:fire(event.name, event)
	self:_fireGameEvent(event)
	local name = event.name
	if MEMBERSHIP_EVENTS[name] then
		self._membershipChanged = true
	elseif name == "CountdownChanged" then
		self:_broadcastPhase()
	elseif name == "MatchEnded" then
		self._ended = MatchHost.endedPayload(event) -- for players who arrive during Results
		self._remotes:fireAll("Match.Ended", MatchHost.endedPayload(event))
	elseif name == "MatchPhaseChanged" then
		if event.phase == "Founding" or event.phase == "Lobby" then
			self._startedAtServerTime = self._env.serverTimeNow()
		end
		self:_broadcastPhase()
		if event.phase ~= "Results" then
			self._ended = nil
		end
		if event.previous == "Results" then
			-- a fresh world was created for the next match: rebuild the view and re-team everyone
			self:_destroyWorld()
			self:_buildWorld()
			for _, player in self._env.Players:GetPlayers() do
				self:assignTeam(player)
			end
			self._membershipChanged = true
		end
	end
end

-- ---------------------------------------------------------------- tick
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

-- 99th percentile of the simulation cost per tick over the same window (perf, FL-0049).
function MatchHost:simMsP99(): number
	local n = #self._simMs
	if n == 0 then
		return 0
	end
	local sorted = table.clone(self._simMs)
	table.sort(sorted)
	return math.floor(sorted[math.max(1, math.ceil(n * 0.99))] * 1000 + 0.5) / 1000
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
	self._stateClock += dt
	self:_sendKingdomState(self._membershipChanged)
	self._membershipChanged = false
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
