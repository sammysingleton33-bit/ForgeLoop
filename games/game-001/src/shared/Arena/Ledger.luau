--!strict
--[[
	Arena/Ledger — the leadership act ledger (CONTRACTS G12.2 `LeadershipService:record`, design `crown-arena.md` §3).
	Owner: FORGE-01. Pure and deterministic: no Roblox API, no clock (the caller passes `t`), no randomness. The server
	LeadershipService owns one Ledger per round and turns it into the conduct / valour samples SupportModel scores.

		Ledger.new(config?) -> Ledger
		Ledger.record(ledger, kingdom, userId, act, magnitude, t) -> (moment: LeadershipMoment?, reason: string?)
			act is an id of config Support `acts`; an unknown id is refused ("unknown_act"), never invented. The delta is
			the act's signed delta x magnitude (default 1, clamped 0..2). A ruler act (conduct, valour) moves that ruler's
			level, which starts at 50 and stays 0..100; a kingdom act (reputation) moves the kingdom's offset (-20..20).
			Valour gained per rolling 60 s is capped by config `valourCapPerMinute`: a gain over the cap is trimmed and
			a gain with no room left is refused ("capped"). The moment text is the act's pre-authored text, never user input.
		Ledger.level(ledger, kingdom, userId, component) -> number     ruler components: 0..100, start 50
		Ledger.offset(ledger, kingdom, component) -> number            kingdom components: -20..20, start 0
		Ledger.moments(ledger, kingdom, userId, limit) -> { LeadershipMoment }
			newest first; userId nil = the kingdom's moments for every ruler; a userId = that ruler's and the kingdom's own
	The ledger keeps the last `MAX_TOTAL` moments (oldest dropped); the levels are not affected by the trimming.
]]

local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local Types = require("./Types")

type LeadershipMoment = Types.LeadershipMoment

export type Ledger = {
	config: any,
	moments: { LeadershipMoment },
	levels: { [string]: number },
	offsets: { [string]: number },
	valour: { [string]: { { t: number, amount: number } } },
}

local Ledger = {}

Ledger.START_LEVEL = 50
Ledger.MAX_OFFSET = 20
Ledger.MAX_TOTAL = 1600
local VALOUR_WINDOW = 60

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

local function rulerKey(kingdom: string, userId: number?, component: string): string
	return `{kingdom}|{if userId then tostring(userId) else "-"}|{component}`
end

local function isRulerComponent(config: any, component: string): boolean
	local def = config.components[component]
	return def ~= nil and def.scope == "ruler"
end

function Ledger.new(config: any?): Ledger
	return {
		config = config or Support,
		moments = {},
		levels = {},
		offsets = {},
		valour = {},
	}
end

function Ledger.level(ledger: Ledger, kingdom: string, userId: number?, component: string): number
	return ledger.levels[rulerKey(kingdom, userId, component)] or Ledger.START_LEVEL
end

function Ledger.offset(ledger: Ledger, kingdom: string, component: string): number
	return ledger.offsets[`{kingdom}|{component}`] or 0
end

-- How much valour may still be gained at `t` (the cap minus the last minute's gains).
local function valourRoom(ledger: Ledger, key: string, t: number): number
	local gains = ledger.valour[key]
	local spent = 0
	if gains then
		local kept = {}
		for _, gain in gains do
			if gain.t > t - VALOUR_WINDOW then
				spent += gain.amount
				table.insert(kept, gain)
			end
		end
		ledger.valour[key] = kept
	end
	return ledger.config.valourCapPerMinute - spent
end

function Ledger.record(
	ledger: Ledger,
	kingdom: string,
	userId: number?,
	act: string,
	magnitude: number?,
	t: number
): (LeadershipMoment?, string?)
	local def = ledger.config.acts[act]
	if def == nil then
		return nil, "unknown_act"
	end
	local scale = clamp(if type(magnitude) == "number" and magnitude == magnitude then magnitude else 1, 0, 2)
	local delta = def.delta * scale
	if delta == 0 then
		return nil, "no_effect"
	end
	local component: string = def.component
	if isRulerComponent(ledger.config, component) then
		local key = rulerKey(kingdom, userId, component)
		if component == "valour" and delta > 0 then
			local room = valourRoom(ledger, key, t)
			if room <= 0 then
				return nil, "capped"
			end
			delta = math.min(delta, room)
			local gains = ledger.valour[key] or {}
			table.insert(gains, { t = t, amount = delta })
			ledger.valour[key] = gains
		end
		ledger.levels[key] = clamp((ledger.levels[key] or Ledger.START_LEVEL) + delta, 0, 100)
	else
		local key = `{kingdom}|{component}`
		ledger.offsets[key] = clamp((ledger.offsets[key] or 0) + delta, -Ledger.MAX_OFFSET, Ledger.MAX_OFFSET)
	end
	local moment: LeadershipMoment = {
		t = t,
		kingdom = kingdom,
		userId = userId,
		act = act,
		component = component :: any,
		delta = delta,
		text = def.text,
	}
	table.insert(ledger.moments, moment)
	if #ledger.moments > Ledger.MAX_TOTAL then
		table.remove(ledger.moments, 1)
	end
	return moment, nil
end

function Ledger.moments(ledger: Ledger, kingdom: string, userId: number?, limit: number): { LeadershipMoment }
	local out: { LeadershipMoment } = {}
	local count = math.max(0, math.floor(limit))
	for i = #ledger.moments, 1, -1 do
		if #out >= count then
			break
		end
		local moment = ledger.moments[i]
		if moment.kingdom == kingdom and (userId == nil or moment.userId == nil or moment.userId == userId) then
			table.insert(out, moment)
		end
	end
	return out
end

return Ledger
