--!strict
--[[
	Sim/Consequences — the sustained kingdom consequence rules as pure checks (FL-0082; living-kingdom §5).
	Owner: FORGE-01. ConsequenceService applies the effects; every threshold comes from config Society
	(`strike`, `consequences`), never from here.

	API
		Consequences.tracker(): Tracker                 -- per kingdom: when each rule's condition started holding
		Consequences.sustained(tracker, key, holds, now, seconds): boolean
			true once `holds` has been true at every check since some time at least `seconds` ago. Any check with
			`holds` false starts the wait over, so a single moment (one decision) never counts.
		Consequences.forget(tracker, key)               -- start that rule's wait over (after it fired or ended)
		Consequences.aggrieved(citizen, obedience, strikeCfg): boolean
			loyalty below loyaltyBelow, obedience below obedienceBelow and a grievance memory (any of memoryTags
			pinned)
		Consequences.effectiveStability(kingdom): number   -- stability minus the kingdom's unrest pressure
		Consequences.instigator(citizens, loyaltyBelow): citizen?   -- the least loyal citizen below the bar
		                                                (ties: the lowest id), nil when nobody is that disloyal
		Consequences.leastLoyal(citizens, count): { citizen }       -- at most `count`, least loyal first
		Consequences.moraleState(morale, moraleCfg): "steady" | "retreat" | "surrender"
		Consequences.ids(citizens): { EntityId }                     -- their ids, in order
	Citizens without a loyalty value count as 50 (the content start).
]]

local Consequences = {}

export type Tracker = { since: { [string]: number } }

local function loyaltyOf(c: any): number
	return c.loyalty or 50
end

local function byLoyalty(a: any, b: any): boolean
	if loyaltyOf(a) ~= loyaltyOf(b) then
		return loyaltyOf(a) < loyaltyOf(b)
	end
	return a.id < b.id
end

function Consequences.tracker(): Tracker
	return { since = {} }
end

function Consequences.sustained(tracker: Tracker, key: string, holds: boolean, now: number, seconds: number): boolean
	if not holds then
		tracker.since[key] = nil
		return false
	end
	local since = tracker.since[key]
	if since == nil then
		tracker.since[key] = now
		since = now
	end
	return now - (since :: number) >= seconds
end

function Consequences.forget(tracker: Tracker, key: string)
	tracker.since[key] = nil
end

function Consequences.aggrieved(citizen: any, obedience: number, cfg: any): boolean
	if loyaltyOf(citizen) >= cfg.loyaltyBelow or obedience >= cfg.obedienceBelow or citizen.pinned == nil then
		return false
	end
	for _, tag in cfg.memoryTags do
		if citizen.pinned[tag] == true then
			return true
		end
	end
	return false
end

function Consequences.effectiveStability(kingdom: any): number
	local stability = if kingdom.conditions then kingdom.conditions.stability or 0 else 0
	return stability - (kingdom.unrestPressure or 0)
end

function Consequences.leastLoyal(citizens: { any }, count: number): { any }
	local sorted = table.clone(citizens)
	table.sort(sorted, byLoyalty)
	local out = {}
	for i = 1, math.min(count, #sorted) do
		out[i] = sorted[i]
	end
	return out
end

function Consequences.instigator(citizens: { any }, loyaltyBelow: number): any?
	local best = nil
	for _, c in citizens do
		if loyaltyOf(c) < loyaltyBelow and (best == nil or byLoyalty(c, best)) then
			best = c
		end
	end
	return best
end

function Consequences.ids(citizens: { any }): { string }
	local out = {}
	for i, c in citizens do
		out[i] = c.id
	end
	return out
end

function Consequences.moraleState(morale: number, cfg: any): string
	if morale < cfg.surrenderBelow then
		return "surrender"
	elseif morale < cfg.retreatBelow then
		return "retreat"
	end
	return "steady"
end

return Consequences
