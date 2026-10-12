--!strict
--[[
	Experience/Pacing — the AI Kingdoms match arc (Opening -> Development -> Competition -> Conflict ->
	Resolution) derived from real signals, plus dead-air detection. Design stages, not time locks:
	signals move the phase forward; the minute marks are only a soft fallback so a quiet match still
	escalates. Phases never go back. Pure; the caller passes the clock.

		local pacing = Pacing.new(startedAt, { kingdomId = "k1" })
		pacing:observe(eventName, info, now) -> newPhase?    -- returns the phase when it advances
		pacing:phase() -> string    pacing:minute(now) -> number
		pacing:noteAction(now)                               -- a meaningful action by the local kingdom
		pacing:nudgeDue(now) -> boolean                      -- idle past the phase threshold (once per idle spell)

	Targets (minutes, for analytics and tuning; FORGE-04 spec §3): Opening 0-5, Development 5-15,
	Competition 15-25, Conflict 25-38, Resolution 38-45. Advance rules:
		Opening -> Development      3 own buildings completed, or a kingdom upgrade, or minute 6
		Development -> Competition  any army recruited or territory taken from a kingdom, or minute 16
		Competition -> Conflict     any battle or siege started, or minute 28
		Conflict -> Resolution      a kingdom eliminated / round entering Results, or minute 38
	Meaningful own actions (noteAction is called automatically from observe): ConstructionStarted,
	BuildingCompleted, BuildingUpgraded, KingdomUpgraded, CitizenTaskChanged, UnitsRecruited,
	BattleStarted, SiegeStarted, TerritoryChanged.
]]

local Pacing = {}
Pacing.__index = Pacing

Pacing.PHASES = table.freeze({ "Opening", "Development", "Competition", "Conflict", "Resolution" })
Pacing.TARGET_MINUTES = table.freeze({
	Opening = table.freeze({ 0, 5 }),
	Development = table.freeze({ 5, 15 }),
	Competition = table.freeze({ 15, 25 }),
	Conflict = table.freeze({ 25, 38 }),
	Resolution = table.freeze({ 38, 45 }),
})
Pacing.FALLBACK_MINUTE = table.freeze({ Development = 6, Competition = 16, Conflict = 28, Resolution = 38 })
Pacing.IDLE_SECONDS =
	table.freeze({ Opening = 25, Development = 45, Competition = 60, Conflict = 90, Resolution = 120 })
Pacing.OPENING_BUILDINGS = 3

local MEANINGFUL = {
	ConstructionStarted = true,
	BuildingCompleted = true,
	BuildingUpgraded = true,
	KingdomUpgraded = true,
	CitizenTaskChanged = true,
	UnitsRecruited = true,
	BattleStarted = true,
	SiegeStarted = true,
	TerritoryChanged = true,
}

function Pacing.new(startedAt: number, options: { kingdomId: string? }?)
	return setmetatable({
		_startedAt = startedAt,
		_index = 1,
		_kingdomId = options and options.kingdomId,
		_buildings = 0,
		_lastAction = startedAt,
		_nudged = false,
	}, Pacing)
end

function Pacing:phase(): string
	return Pacing.PHASES[self._index]
end

function Pacing:minute(now: number): number
	return math.max(0, (now - self._startedAt) / 60)
end

function Pacing:setKingdom(kingdomId: string?)
	self._kingdomId = kingdomId
end

function Pacing:_advanceTo(index: number): string?
	if index <= self._index then
		return nil
	end
	self._index = math.min(index, #Pacing.PHASES)
	return self:phase()
end

-- Signals that justify a phase, by target phase index.
local function signalPhase(self: any, eventName: string, info: { [string]: any }): number
	local own = self._kingdomId ~= nil and info.kingdomId == self._kingdomId
	if eventName == "BuildingCompleted" and own then
		self._buildings += 1
	end
	if eventName == "RoundStateChanged" and info.state == "Results" then
		return 5
	elseif eventName == "PlayerEliminated" or eventName == "KingdomEliminated" then
		return 5
	elseif eventName == "BattleStarted" or eventName == "SiegeStarted" then
		return 4
	elseif eventName == "UnitsRecruited" or (eventName == "TerritoryChanged" and info.fromKingdomId ~= nil) then
		return 3
	elseif (eventName == "KingdomUpgraded" and own) or self._buildings >= Pacing.OPENING_BUILDINGS then
		return 2
	end
	return 1
end

function Pacing:_byClock(now: number): number
	local minute = self:minute(now)
	local index = 1
	for i = 2, #Pacing.PHASES do
		if minute >= Pacing.FALLBACK_MINUTE[Pacing.PHASES[i]] then
			index = i
		end
	end
	return index
end

function Pacing:observe(eventName: string, info: { [string]: any }?, now: number): string?
	local data = info or {}
	if MEANINGFUL[eventName] and self._kingdomId ~= nil and data.kingdomId == self._kingdomId then
		self:noteAction(now)
	end
	local target = math.max(signalPhase(self, eventName, data), self:_byClock(now))
	return self:_advanceTo(target)
end

function Pacing:tick(now: number): string?
	return self:_advanceTo(self:_byClock(now))
end

function Pacing:noteAction(now: number)
	self._lastAction = now
	self._nudged = false
end

function Pacing:idleFor(now: number): number
	return now - self._lastAction
end

function Pacing:nudgeDue(now: number): boolean
	if self._nudged then
		return false
	end
	if self:idleFor(now) >= Pacing.IDLE_SECONDS[self:phase()] then
		self._nudged = true
		return true
	end
	return false
end

return Pacing
