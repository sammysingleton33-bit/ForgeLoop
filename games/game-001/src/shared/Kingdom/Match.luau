--!strict
--[[
	Kingdom/Match — one AI Kingdoms match: four kingdoms, player assignment, the CONTRACTS G2
	phases, victory and results. Owns a Simulation with Military, Objectives, optionally Diplomacy
	(PvP flag) and the AI governor (RulerAI) installed.

	Modes (CONTRACTS G3/G11; options.mode, default config Match.mode)
		"match"  the full match. Lobby: once minPlayers are in, a countdown of durations.Lobby runs
		         (cancelled when players drop below minPlayers); the world is frozen. Founding →
		         Expansion → Conflict → Endgame run the simulation for their durations, then Results
		         for durations.Results, then a fresh world and Lobby again with the players re-seated.
		         Kingdoms without rulers are run by the AI governor (RulerAI) when aiRulers is true.
		"slice"  PROVISIONAL VS-1 rules (pending BRIEF §16.3/§16.4): Lobby 0 s (Founding starts on the
		         first join), untimed phases, the first ObjectiveCaptured ends the slice with that
		         kingdom as winner (reason "objective"); starting citizens appear when a kingdom's
		         first ruler joins; no AI governors.
		Durations come from options.phaseDurations (PacingService:phaseDurations(mode), G11), merged over
		config Match.durations[mode]; math.huge = untimed (remaining() is nil). countdownSec/resultsSec
		override Lobby/Results (spec convenience).
	Victory — PROVISIONAL, user decision pending (BRIEF §16.4); config Match.victory:
		- conquest: the last kingdom standing wins at once (any active phase).
		- crownPointsAtEnd: when Endgame ends, the most Crown Points wins; equal points share the win.
		  (With both off the match still ends at Endgame and everyone standing shares the result.)
	PvP — PROVISIONAL, user decision pending (BRIEF §16.2); config Match.pvp.enabled (default false,
	the VS-1 minimum): Diplomacy (war from Conflict, peace by consent) is installed only when enabled.
		Ranking: standing kingdoms by Crown Points (equal points share a placement), then fallen
		kingdoms, those that fell later ranking higher.
	Players
		- Up to maxRulersPerKingdom (4) rulers per kingdom, equal command rights (shared ownership).
		- join(userId, preferred?) honours a preferred kingdom when it stands and has room, then the
		  player's previous kingdom in this match, then the standing kingdom with the fewest rulers
		  (ties: kingdom order). Joining only adds a ruler (and, in slice mode, the first ruler's
		  starting citizens); no other kingdom state changes. Late joiners are seated in any phase.
		- joinParty({ userIds }, preferred?) seats a party together when one kingdom has room for all.
	State is per server and in memory; permanent progression goes through DataService only.

	API
		Match.new(options): Match
			options: { random (required), now: () -> number (unix seconds), roundIdPrefix = "km",
			  mode = Match.mode, phaseDurations = { Lobby?, Founding?, ..., Results? }, countdownSec?,
			  resultsSec?, kingdoms = 4, spacing? (square layout; default world plots), minPlayers = 1,
			  maxRulersPerKingdom = 4, aiRulers = Governor.enabled and mode == "match",
			  populateOnJoin = mode == "slice", endOnFirstCapture = mode == "slice",
			  pvp = Match.pvp.enabled, victory = Match.victory, objectives = Layout.OBJECTIVES,
			  catalog?, treasury?, costs? }   -- defaults from config
		Match.durationsFor(mode): { [MatchPhase]: number }      -- config defaults (fresh table)
		Match.checkDurations(durations): string?                -- why a full six-phase table is unusable
		match.state (MatchPhase), match.mode, match.sim, match.roundId, match.durations
		match:join(userId, preferred?): (boolean, string)       -- (true, kingdomId) | (false, error)
		match:joinParty(userIds, preferred?): (boolean, { [number]: string } | string)
		match:leave(userId)
		match:choose(userId, kingdomId): (boolean, string)      -- only in Lobby
		match:kingdomOf(userId): string?
		match:update(dt)
		match:remaining(): number?    -- seconds left in the countdown / current phase / results; nil = untimed
		match:debugSetPhase(phase): (boolean, string?)          -- Studio debug panel only (match.phase)
		match:command(userId, name, ...)                         -- Commands.execute on this simulation
		match:result(): RoundResult?  -- framework Contracts/Types RoundResult, mode "kingdoms"
		match:summary(): { winner: KingdomId?, standings: { { kingdom, crownPoints } }, durationSec,
		                   reason, winnerKingdomIds, ranking }   -- G9 MatchEnded payload (+ reason/ranking)
		match:drainEvents(): { Event }  -- simulation events + MatchPhaseChanged { phase, previous, roundId }
		                                   + CountdownChanged { running, seconds } + MatchEnded (summary fields)
	Errors from join: match_full, already_joined. From choose: too_late, not_in_match, unknown_kingdom,
	kingdom_full. From joinParty: party_too_large, match_full.
]]

local GovernorConfig = require("@game/ReplicatedStorage/Forge/Config/Governor")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Commands = require("../Sim/Commands")
local Diplomacy = require("../Sim/Diplomacy")
local Layout = require("./Layout")
local Military = require("../Sim/Military")
local Objectives = require("../Sim/Objectives")
local RulerAI = require("../Sim/RulerAI")
local Simulation = require("../Sim/Simulation")

local Match = {}
Match.__index = Match

Match.MODE = "kingdoms"
Match.ACTIVE_PHASES = table.freeze({ "Founding", "Expansion", "Conflict", "Endgame" })
Match.PHASES = table.freeze({ "Lobby", "Founding", "Expansion", "Conflict", "Endgame", "Results" })
Match.MODES = table.freeze({ "slice", "match" })

local function isActive(phase: string): boolean
	return table.find(Match.ACTIVE_PHASES, phase) ~= nil
end

-- nil when every phase has a usable length: active phases > 0, Lobby and Results >= 0, math.huge = untimed.
function Match.checkDurations(durations: any): string?
	if type(durations) ~= "table" then
		return "durations must be a table"
	end
	for _, phase in Match.PHASES do
		local seconds = durations[phase]
		local ok = type(seconds) == "number" and seconds == seconds
		if ok and isActive(phase) then
			ok = seconds > 0
		elseif ok then
			ok = seconds >= 0
		end
		if not ok then
			return `{phase} duration must be {if isActive(phase) then "> 0" else ">= 0"} (math.huge = untimed)`
		end
	end
	return nil
end

function Match.durationsFor(mode: string): { [string]: number }
	local durations = MatchConfig.durations[mode]
	assert(durations ~= nil, `Match: mode must be "slice" or "match", got {tostring(mode)}`)
	return table.clone(durations)
end

function Match.new(options: { [string]: any })
	assert(options.random ~= nil, "Match.new: random is required")
	local mode = options.mode or MatchConfig.mode
	local durations = Match.durationsFor(mode)
	for phase, seconds in options.phaseDurations or {} do
		assert(durations[phase] ~= nil, `Match.new: unknown phase '{tostring(phase)}' in phaseDurations`)
		durations[phase] = seconds
	end
	durations.Lobby = options.countdownSec or durations.Lobby
	durations.Results = options.resultsSec or durations.Results
	local problem = Match.checkDurations(durations)
	assert(problem == nil, `Match.new: {problem}`)
	local self = setmetatable({}, Match)
	self.mode = mode
	self.durations = durations
	self.options = {
		random = options.random,
		now = options.now or function()
			return 0
		end,
		roundIdPrefix = options.roundIdPrefix or "km",
		kingdoms = options.kingdoms or #KingdomsConfig.identities,
		spacing = options.spacing,
		durations = durations,
		countdownSec = durations.Lobby,
		resultsSec = durations.Results,
		minPlayers = options.minPlayers or MatchConfig.minPlayers,
		maxRulersPerKingdom = options.maxRulersPerKingdom or KingdomsConfig.maxRulersPerKingdom,
		aiRulers = if options.aiRulers == nil then GovernorConfig.enabled and mode == "match" else options.aiRulers,
		populateOnJoin = if options.populateOnJoin == nil then mode == "slice" else options.populateOnJoin,
		endOnFirstCapture = if options.endOnFirstCapture == nil then mode == "slice" else options.endOnFirstCapture,
		pvp = if options.pvp == nil then MatchConfig.pvp.enabled else options.pvp,
		victory = options.victory or MatchConfig.victory,
		objectives = options.objectives or Layout.OBJECTIVES,
		catalog = options.catalog,
		treasury = options.treasury,
		costs = options.costs,
	}
	-- phase boundaries in simulation seconds
	local t = 0
	self.phaseEnds = {} :: { [string]: number }
	for _, phase in Match.ACTIVE_PHASES do
		t += durations[phase]
		self.phaseEnds[phase] = t
	end
	self.state = "Lobby"
	self.players = {} :: { number }
	self._matchCount = 0
	self._events = {} :: { any }
	self._phaseTime = 0
	self._countdown = nil :: number?
	self:_newWorld()
	return self
end

function Match:_newWorld()
	self._matchCount += 1
	self.roundId = `{self.options.roundIdPrefix}-{self._matchCount}`
	local sim = Simulation.new({
		catalog = self.options.catalog,
		random = self.options.random,
		bounds = Layout.bounds(self.options.spacing),
		treasury = self.options.treasury,
		costs = self.options.costs,
	})
	Layout.generate(sim, {
		kingdoms = self.options.kingdoms,
		spacing = self.options.spacing,
		populate = not self.options.populateOnJoin,
	})
	Military.install(sim)
	if self.options.pvp then
		Diplomacy.install(sim, {
			graceSeconds = self.phaseEnds.Expansion,
			proposalSeconds = MatchConfig.pvp.proposalSeconds,
			peaceCooldown = MatchConfig.pvp.peaceCooldown,
		})
	end
	local objectives = {}
	for _, o in self.options.objectives do
		table.insert(objectives, table.clone(o))
	end
	Objectives.install(sim, objectives)
	if self.options.aiRulers then
		RulerAI.install(sim, {
			interval = GovernorConfig.interval,
			assistHumans = GovernorConfig.assistHumans,
			minAggression = GovernorConfig.minAggression,
			maxAggression = GovernorConfig.maxAggression,
		})
	end
	sim.active = false
	self.sim = sim
	self.participants = {} :: { [number]: { kingdomId: string, joinedAt: number, leftAt: number? } }
	self.lastKingdom = {} :: { [number]: string }
	self.startedAt = nil :: number?
	self.endedAt = nil :: number?
	self._result = nil :: any
	self._summary = nil :: any
end

function Match:_setState(nextState: string)
	local previous = self.state
	self.state = nextState
	self._phaseTime = 0
	table.insert(
		self._events,
		{ name = "MatchPhaseChanged", phase = nextState, previous = previous, roundId = self.roundId }
	)
end

function Match:_setCountdown(seconds: number?)
	if (seconds == nil) == (self._countdown == nil) then
		self._countdown = seconds
		return
	end
	self._countdown = seconds
	table.insert(self._events, { name = "CountdownChanged", running = seconds ~= nil, seconds = seconds })
end

function Match:kingdomOf(userId: number): string?
	return self.sim.rulerOf[userId]
end

function Match:_room(kingdomId: string?): number
	local k = kingdomId and self.sim.kingdoms[kingdomId]
	if k == nil or not k.alive then
		return 0
	end
	return self.options.maxRulersPerKingdom - #k.rulers
end

function Match:_pickKingdom(userId: number?, preferred: string?, seats: number): string?
	if self:_room(preferred) >= seats then
		return preferred
	end
	local previous = if userId then self.lastKingdom[userId] else nil
	if self:_room(previous) >= seats then
		return previous
	end
	local best, bestCount = nil, math.huge
	for _, kid in self.sim.kingdomOrder do
		local k = self.sim.kingdoms[kid]
		if self:_room(kid) >= seats and #k.rulers < bestCount then
			best, bestCount = kid, #k.rulers
		end
	end
	return best
end

-- Slice mode: a kingdom's starting citizens appear with its first ruler (CONTRACTS G3).
function Match:_populate(kingdomId: string)
	if self.options.populateOnJoin then
		self.sim:populate(kingdomId)
	end
end

function Match:_seat(userId: number, kingdomId: string)
	assert(self.sim:addRuler(kingdomId, userId))
	self:_populate(kingdomId)
	if not table.find(self.players, userId) then
		table.insert(self.players, userId)
	end
	self.lastKingdom[userId] = kingdomId
	local entry = self.participants[userId]
	if entry == nil or entry.kingdomId ~= kingdomId then
		self.participants[userId] = { kingdomId = kingdomId, joinedAt = self.sim.time, leftAt = nil }
	else
		entry.leftAt = nil
	end
end

function Match:join(userId: number, preferred: string?): (boolean, string)
	if self.sim.rulerOf[userId] ~= nil then
		return false, "already_joined"
	end
	local kingdomId = self:_pickKingdom(userId, preferred, 1)
	if kingdomId == nil then
		return false, "match_full"
	end
	self:_seat(userId, kingdomId)
	return true, kingdomId
end

-- The kingdom that can take every mover (counting movers already seated there): the preferred one
-- if it can, else the one that ends up with the fewest rulers (first in kingdom order on ties).
function Match:_pickPartyKingdom(movers: { number }, preferred: string?): string?
	local function fits(kingdomId: string): (boolean, number)
		local k = self.sim.kingdoms[kingdomId]
		if k == nil or not k.alive then
			return false, 0
		end
		local needed = 0
		for _, userId in movers do
			if self.sim.rulerOf[userId] ~= kingdomId then
				needed += 1
			end
		end
		return self:_room(kingdomId) >= needed, #k.rulers + needed
	end
	if preferred and fits(preferred) then
		return preferred
	end
	local best, bestCount = nil, math.huge
	for _, kid in self.sim.kingdomOrder do
		local ok, count = fits(kid)
		if ok and count < bestCount then
			best, bestCount = kid, count
		end
	end
	return best
end

-- Seats a party in one kingdom when any kingdom has room for all of them; otherwise seats each
-- newcomer individually (still balanced). In the Lobby, members already seated are moved to the
-- party's kingdom too (players are seated on arrival, before a party system can group them); after
-- the Lobby they keep their kingdom (no defecting mid-match). Returns every member's kingdom.
function Match:joinParty(userIds: { number }, preferred: string?): (boolean, any)
	if #userIds > self.options.maxRulersPerKingdom then
		return false, "party_too_large"
	end
	local regroup = self.state == "Lobby"
	local movers = {}
	for _, userId in userIds do
		if self.sim.rulerOf[userId] == nil or regroup then
			table.insert(movers, userId)
		end
	end
	local together = self:_pickPartyKingdom(movers, preferred)
	for _, userId in movers do
		local current = self.sim.rulerOf[userId]
		local ok, result = true, nil
		if together and current == nil then
			self:_seat(userId, together)
		elseif together and current ~= together then
			ok, result = self:choose(userId, together)
		elseif current == nil then
			ok, result = self:join(userId, preferred)
		end
		if not ok then
			return false, result
		end
	end
	local seated = {}
	for _, userId in userIds do
		seated[userId] = self.sim.rulerOf[userId]
	end
	return true, seated
end

function Match:leave(userId: number)
	local i = table.find(self.players, userId)
	if i then
		table.remove(self.players, i)
	end
	self.sim:removeRuler(userId)
	local entry = self.participants[userId]
	if entry then
		entry.leftAt = self.sim.time
	end
	if self.state == "Lobby" and self._countdown ~= nil and #self.players < self.options.minPlayers then
		self:_setCountdown(nil)
	end
end

-- Moves a ruler to another kingdom; only in the Lobby (no defecting mid-match).
function Match:choose(userId: number, kingdomId: string): (boolean, string)
	if self.state ~= "Lobby" then
		return false, "too_late"
	end
	local current = self.sim.rulerOf[userId]
	if current == nil then
		return false, "not_in_match"
	end
	if current == kingdomId then
		return true, kingdomId
	end
	local target = self.sim.kingdoms[kingdomId]
	if target == nil or not target.alive then
		return false, "unknown_kingdom"
	end
	if #target.rulers >= self.options.maxRulersPerKingdom then
		return false, "kingdom_full"
	end
	self.sim:removeRuler(userId)
	assert(self.sim:addRuler(kingdomId, userId))
	self:_populate(kingdomId)
	self.lastKingdom[userId] = kingdomId
	self.participants[userId] = { kingdomId = kingdomId, joinedAt = self.sim.time, leftAt = nil }
	return true, kingdomId
end

function Match:command(userId: number, name: any, ...: any): (boolean, string?, any?)
	return Commands.execute(self.sim, userId, name, ...)
end

function Match:remaining(): number?
	if self.state == "Lobby" then
		return self._countdown
	elseif isActive(self.state) then
		local ends = self.phaseEnds[self.state]
		return if ends == math.huge then nil else math.max(0, ends - self.sim.time)
	elseif self.state == "Results" then
		local seconds = self.options.resultsSec
		return if seconds == math.huge then nil else math.max(0, seconds - self._phaseTime)
	end
	return nil
end

function Match:ranking(): { any }
	local sim = self.sim
	local rows = {}
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		table.insert(rows, {
			kingdomId = kid,
			name = k.name,
			crownPoints = k.crownPoints,
			alive = k.alive,
			eliminatedAt = k.eliminatedAt or math.huge,
			index = k.index,
		})
	end
	table.sort(rows, function(a, b)
		if a.alive ~= b.alive then
			return a.alive
		end
		if a.alive then
			if a.crownPoints ~= b.crownPoints then
				return a.crownPoints > b.crownPoints
			end
		elseif a.eliminatedAt ~= b.eliminatedAt then
			return a.eliminatedAt > b.eliminatedAt
		end
		return a.index < b.index
	end)
	local out = {}
	for i, row in rows do
		local placement = i
		local prev = out[i - 1]
		local tie = prev and prev.crownPoints == row.crownPoints
		if not self.options.victory.crownPointsAtEnd then
			tie = true -- PROVISIONAL: without the Crown Points rule every standing kingdom shares the result
		end
		if prev and row.alive and prev.alive and tie then
			placement = prev.placement
		end
		table.insert(out, {
			kingdomId = row.kingdomId,
			name = row.name,
			crownPoints = row.crownPoints,
			alive = row.alive,
			placement = placement,
		})
	end
	return out
end

function Match:_finish(reason: string, winner: string?)
	local sim = self.sim
	sim.active = false
	self.endedAt = self.options.now()
	local ranking = self:ranking()
	local placementOf = {}
	local winners: { string } = {}
	local standings = {}
	for _, row in ranking do
		placementOf[row.kingdomId] = row.placement
		table.insert(standings, { kingdom = row.kingdomId, crownPoints = row.crownPoints })
		if winner == nil and row.placement == 1 and row.alive then
			table.insert(winners, row.kingdomId)
		end
	end
	if winner then
		winners = { winner }
	end
	local participants = {}
	local winnerUsers = {}
	local userIds = {}
	for userId in self.participants do
		table.insert(userIds, userId)
	end
	table.sort(userIds)
	for _, userId in userIds do
		local entry = self.participants[userId]
		local kingdom = sim.kingdoms[entry.kingdomId]
		local endT = entry.leftAt or kingdom.eliminatedAt or sim.time
		table.insert(participants, {
			userId = userId,
			placement = placementOf[entry.kingdomId],
			eliminations = kingdom.stats.conquered,
			survivedSec = math.max(0, math.floor(endT - entry.joinedAt)),
		})
		if table.find(winners, entry.kingdomId) and entry.leftAt == nil then
			table.insert(winnerUsers, userId)
		end
	end
	self._summary = {
		winner = if #winners == 1 then winners[1] else nil,
		standings = standings,
		durationSec = math.floor(sim.time),
		reason = reason,
		winnerKingdomIds = winners,
		ranking = ranking,
	}
	self._result = {
		roundId = self.roundId,
		mode = Match.MODE,
		startedAt = self.startedAt or self.endedAt,
		endedAt = self.endedAt,
		participants = participants,
		winners = winnerUsers,
	}
	self:_setState("Results")
	local ended = table.clone(self._summary)
	ended.name = "MatchEnded"
	ended.roundId = self.roundId
	table.insert(self._events, ended)
end

function Match:_checkVictory()
	local sim = self.sim
	local alive = 0
	for _, kid in sim.kingdomOrder do
		if sim.kingdoms[kid].alive then
			alive += 1
		end
	end
	if self.options.victory.conquest and alive <= 1 and #sim.kingdomOrder > 1 then
		self:_finish("conquest")
		return
	end
	if self.options.endOnFirstCapture and sim.objectives then
		-- slice mode: the first capture ends the slice (an interim rule for Studio tests, not victory)
		for _, o in sim.objectives.list do
			if o.owner ~= nil then
				self:_finish("objective", o.owner)
				return
			end
		end
	end
	while isActive(self.state) and sim.time >= self.phaseEnds[self.state] - 1e-9 do
		local index = table.find(Match.ACTIVE_PHASES, self.state) :: number
		local nextPhase = Match.ACTIVE_PHASES[index + 1]
		if nextPhase then
			self:_setState(nextPhase)
		else
			self:_finish("time")
		end
	end
end

function Match:update(dt: number)
	assert(type(dt) == "number" and dt >= 0 and dt < math.huge, "Match:update: dt must be >= 0")
	self._phaseTime += dt
	if self.state == "Lobby" then
		if #self.players < self.options.minPlayers then
			self:_setCountdown(nil)
		elseif self.options.countdownSec <= 0 then
			self:_start() -- slice mode: no countdown, Founding starts with the first join
		elseif self._countdown == nil then
			self:_setCountdown(self.options.countdownSec)
		else
			local left = (self._countdown :: number) - dt
			if left <= 1e-9 then
				self._countdown = nil
				self:_start()
			else
				self._countdown = left
			end
		end
	elseif isActive(self.state) then
		self.sim:advance(dt)
		self:_checkVictory()
	elseif self.state == "Results" then
		if self._phaseTime >= self.options.resultsSec then
			local players = table.clone(self.players)
			self:_newWorld()
			self.players = {}
			self:_setState("Lobby")
			for _, userId in players do
				self:join(userId)
			end
		end
	end
end

-- Studio debug (FL-0068 command match.phase): jump to an active phase now. The phases after it keep
-- their lengths from this moment; the simulation itself is not fast-forwarded.
function Match:debugSetPhase(phase: string): (boolean, string?)
	if not isActive(phase) then
		return false, "not an active phase"
	end
	if self.state == "Results" then
		return false, "the match is over"
	end
	if self.state == "Lobby" then
		self._countdown = nil
		self:_start()
	end
	if self.state ~= phase then
		local index = table.find(Match.ACTIVE_PHASES, phase) :: number
		local t = self.sim.time
		for i, name in Match.ACTIVE_PHASES do
			if i < index then
				self.phaseEnds[name] = self.sim.time
			else
				t += self.durations[name]
				self.phaseEnds[name] = t
			end
		end
		self:_setState(phase)
	end
	return true, nil
end

function Match:_start()
	self.startedAt = self.options.now()
	self.sim.active = true
	self:_setState("Founding")
end

function Match:result(): any
	return self._result
end

function Match:summary(): any
	return self._summary
end

function Match:drainEvents(): { any }
	local out = self.sim:drainEvents()
	for _, event in self._events do
		table.insert(out, event)
	end
	self._events = {}
	return out
end

return Match
