--!strict
--[[
	Gameplay/Kingdom/Match — one AI Kingdoms match: four kingdoms, player assignment, phases,
	victory and results. Owns a Simulation (with Military, Diplomacy and RulerAI installed).

	Phases use the shared round state names (Contracts/Types RoundState) so round HUDs work as is:
		Lobby --(enough players)--> Countdown --(countdownSec)--> Active --(victory)--> Results
		Countdown --(players drop below minPlayers)--> Lobby
		Results --(resultsSec)--> Lobby with a fresh world (current players re-assigned)
	The simulation only advances while Active. Match state is per server and in memory only; it is
	never written to player data (permanent progression is separate, through DataService).

	Players
		- Up to maxRulersPerKingdom (4) rulers per kingdom; all rulers share command rights.
		- join(userId, preferred?) honours a preferred kingdom when it is alive and not full, otherwise
		  picks the alive kingdom with the fewest rulers (ties: lowest index). A player who left and
		  rejoins the same match gets their old kingdom back when possible.
		- Joining never touches other kingdom state: it only adds the ruler (specs prove it).
		- Kingdoms without rulers are run by RulerAI (aiRulers = true).
	Victory
		- Conquest: one kingdom left standing wins at once.
		- Time: at durationSec the highest score wins; equal top scores share the win.
		Ranking: alive kingdoms by score (equal scores share a placement), then eliminated kingdoms,
		those eliminated later ranking higher.

	API
		Match.new(options): Match
			options: { random (required), now: () -> number (unix seconds, for RoundResult),
			  roundIdPrefix = "km", kingdoms = 4, spacing = 260, durationSec = 2400, countdownSec = 10,
			  resultsSec = 20, minPlayers = 1, maxRulersPerKingdom = 4, aiRulers = true,
			  graceSeconds = 300, catalog? }
		match.state, match.sim, match.roundId
		match:join(userId, preferredKingdomId?): (boolean, string)   -- (true, kingdomId) | (false, error)
		match:leave(userId)
		match:choose(userId, kingdomId): (boolean, string)   -- switch kingdom before Active; errors:
		                                   too_late, not_in_match, unknown_kingdom, kingdom_full
		match:kingdomOf(userId): string?
		match:update(dt)                 -- drive from the server's fixed tick
		match:remaining(): number?       -- seconds left in the current timed phase
		match:result(): RoundResult?     -- after Results; Contracts/Types RoundResult (mode "kingdoms")
		match:summary(): MatchSummary?   -- { reason, winnerKingdomIds, ranking = { { kingdomId, name, score, alive, placement } } }
		match:drainEvents(): { Event }   -- simulation events + MatchStateChanged { state, previous }
		                                   + MatchEnded { roundId, reason, winnerKingdomIds }
		match:command(userId, name, ...) -- Commands.execute on this match's simulation
	Errors from join: "match_full" (every alive kingdom has maxRulers), "already_joined".
]]

local Commands = require("./Commands")
local Diplomacy = require("./Diplomacy")
local Layout = require("./Layout")
local Military = require("./Military")
local RulerAI = require("./RulerAI")
local Simulation = require("./Simulation")
local Snapshot = require("./Snapshot")

local Match = {}
Match.__index = Match

Match.MODE = "kingdoms"

local TRANSITIONS: { [string]: { [string]: boolean } } = {
	Lobby = { Countdown = true },
	Countdown = { Active = true, Lobby = true },
	Active = { Results = true },
	Results = { Lobby = true },
}

function Match.new(options: { [string]: any })
	assert(options.random ~= nil, "Match.new: random is required")
	local self = setmetatable({}, Match)
	self.options = {
		random = options.random,
		now = options.now or function()
			return 0
		end,
		roundIdPrefix = options.roundIdPrefix or "km",
		kingdoms = options.kingdoms or 4,
		spacing = options.spacing or 260,
		durationSec = options.durationSec or 2400,
		countdownSec = options.countdownSec or 10,
		resultsSec = options.resultsSec or 20,
		minPlayers = options.minPlayers or 1,
		maxRulersPerKingdom = options.maxRulersPerKingdom or 4,
		aiRulers = if options.aiRulers == nil then true else options.aiRulers,
		graceSeconds = options.graceSeconds or 300,
		catalog = options.catalog,
	}
	self.state = "Lobby"
	self.players = {} :: { number } -- connected userIds in join order
	self.lastKingdom = {} :: { [number]: string }
	self._matchCount = 0
	self._events = {} :: { any }
	self._phaseTime = 0
	self:_newWorld()
	return self
end

function Match:_newWorld()
	self._matchCount += 1
	self.roundId = `{self.options.roundIdPrefix}-{self._matchCount}`
	local sim = Simulation.new({
		catalog = self.options.catalog,
		random = self.options.random,
		bounds = Layout.boundsFor(self.options.spacing),
	})
	Layout.generate(sim, { kingdoms = self.options.kingdoms, spacing = self.options.spacing })
	Military.install(sim)
	Diplomacy.install(sim, { graceSeconds = self.options.graceSeconds })
	if self.options.aiRulers then
		RulerAI.install(sim)
	end
	sim.active = false
	self.sim = sim
	self.participants = {} :: { [number]: { kingdomId: string, joinedAt: number, leftAt: number? } }
	self.startedAt = nil :: number?
	self.endedAt = nil :: number?
	self._result = nil :: any
	self._summary = nil :: any
	self.lastKingdom = {}
end

function Match:_setState(nextState: string)
	assert(TRANSITIONS[self.state][nextState], `Match: illegal transition {self.state} -> {nextState}`)
	local previous = self.state
	self.state = nextState
	self._phaseTime = 0
	table.insert(
		self._events,
		{ name = "MatchStateChanged", state = nextState, previous = previous, roundId = self.roundId }
	)
end

function Match:kingdomOf(userId: number): string?
	return self.sim.rulerOf[userId]
end

function Match:_pickKingdom(userId: number, preferred: string?): string?
	local sim = self.sim
	local max = self.options.maxRulersPerKingdom
	local function open(id: string?): boolean
		local k = id and sim.kingdoms[id]
		return k ~= nil and k.alive and #k.rulers < max
	end
	if open(preferred) then
		return preferred
	end
	local previous = self.lastKingdom[userId]
	if open(previous) then
		return previous
	end
	local best, bestCount = nil, math.huge
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		if k.alive and #k.rulers < max and #k.rulers < bestCount then
			best, bestCount = kid, #k.rulers
		end
	end
	return best
end

function Match:join(userId: number, preferred: string?): (boolean, string)
	if self.sim.rulerOf[userId] ~= nil then
		return false, "already_joined"
	end
	local kingdomId = self:_pickKingdom(userId, preferred)
	if kingdomId == nil then
		return false, "match_full"
	end
	local ok, err = self.sim:addRuler(kingdomId, userId)
	if not ok then
		return false, err or "join_failed"
	end
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
	return true, kingdomId
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
	if self.state == "Countdown" and #self.players < self.options.minPlayers then
		self:_setState("Lobby")
	end
end

-- Moves a ruler to another kingdom; only before the match is Active (no defecting mid-war).
function Match:choose(userId: number, kingdomId: string): (boolean, string)
	if self.state ~= "Lobby" and self.state ~= "Countdown" then
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
	self.lastKingdom[userId] = kingdomId
	self.participants[userId] = { kingdomId = kingdomId, joinedAt = self.sim.time, leftAt = nil }
	return true, kingdomId
end

function Match:command(userId: number, name: any, ...: any): (boolean, string?, any?)
	return Commands.execute(self.sim, userId, name, ...)
end

function Match:remaining(): number?
	if self.state == "Countdown" then
		return math.max(0, self.options.countdownSec - self._phaseTime)
	elseif self.state == "Active" then
		return math.max(0, self.options.durationSec - self.sim.time)
	elseif self.state == "Results" then
		return math.max(0, self.options.resultsSec - self._phaseTime)
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
			score = Snapshot.score(sim, k),
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
			if a.score ~= b.score then
				return a.score > b.score
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
		if prev and row.alive and prev.alive and prev.score == row.score then
			placement = prev.placement
		end
		table.insert(
			out,
			{ kingdomId = row.kingdomId, name = row.name, score = row.score, alive = row.alive, placement = placement }
		)
	end
	return out
end

function Match:_finish(reason: string)
	local sim = self.sim
	sim.active = false
	self.endedAt = self.options.now()
	local ranking = self:ranking()
	local placementOf = {}
	local winners: { string } = {}
	for _, row in ranking do
		placementOf[row.kingdomId] = row.placement
		if row.placement == 1 and row.alive then
			table.insert(winners, row.kingdomId)
		end
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
	self._summary = { reason = reason, winnerKingdomIds = winners, ranking = ranking }
	self._result = {
		roundId = self.roundId,
		mode = Match.MODE,
		startedAt = self.startedAt or self.endedAt,
		endedAt = self.endedAt,
		participants = participants,
		winners = winnerUsers,
	}
	self:_setState("Results")
	table.insert(
		self._events,
		{ name = "MatchEnded", roundId = self.roundId, reason = reason, winnerKingdomIds = winners }
	)
end

function Match:_checkVictory()
	local sim = self.sim
	local alive = 0
	for _, kid in sim.kingdomOrder do
		if sim.kingdoms[kid].alive then
			alive += 1
		end
	end
	if alive <= 1 and #sim.kingdomOrder > 1 then
		self:_finish("conquest")
	elseif sim.time >= self.options.durationSec then
		self:_finish("time")
	end
end

function Match:update(dt: number)
	assert(type(dt) == "number" and dt >= 0 and dt < math.huge, "Match:update: dt must be >= 0")
	self._phaseTime += dt
	if self.state == "Lobby" then
		if #self.players >= self.options.minPlayers then
			self:_setState("Countdown")
		end
	elseif self.state == "Countdown" then
		if #self.players < self.options.minPlayers then
			self:_setState("Lobby")
		elseif self._phaseTime >= self.options.countdownSec then
			self.startedAt = self.options.now()
			self.sim.active = true
			self:_setState("Active")
		end
	elseif self.state == "Active" then
		self.sim:advance(dt)
		self:_checkVictory()
	elseif self.state == "Results" then
		if self._phaseTime >= self.options.resultsSec then
			local players = table.clone(self.players)
			-- events of the finished world are dropped with it; the new world starts clean
			self:_newWorld()
			self.players = {}
			self:_setState("Lobby")
			for _, userId in players do
				self:join(userId)
			end
		end
	end
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
