--!strict
--[[
	Arena/Caps — the Crown Arena fairness caps (CONTRACTS G12.3, design §6). Owner: FORGE-01.

	The numbers below are the contract's. They change only with a DECISIONS entry (FORGE-05's tests/fairness/Caps.spec
	keeps them equal to the CONTRACTS table and asserts this file agrees with its own reference checker).

		Caps.NUMBERS                                   the caps as data (fractions: 0.05 = +5 %)
		Caps.problems(modifiers): { string }           every broken cap, as a sentence; empty = within the caps
		                                               (also: an active effect needs a condition the model can evaluate)
		Caps.check(modifiers): (boolean, string?)      true, or false with the first problem (G12.2)

	A Modifier is one support effect (Arena/Types). One trigger with two effects (Crowd Rally: damage reduction and
	stamina regeneration) is two modifiers with the same `source`; it takes one slot. DuelService runs `check` on every
	duellist's modifiers before a duel; a refusal is logged and the modifier dropped, never applied.
]]

local Types = require("./Types")

type Modifier = Types.Modifier

local Caps = {}

Caps.NUMBERS = table.freeze({
	passivePerStat = 0.05, -- tier blessing + Fine Wares on one stat
	passiveCombined = 0.08, -- all passive bonuses added up
	maxTriggers = 3, -- perks + Crowd Rally per duel, each fires at most once
	triggerMaxSeconds = 8,
	triggerMaxMagnitude = 0.10, -- damage reduction, damage, stamina regeneration
	totalPerStat = 0.15, -- passive + the strongest active trigger on one stat, at any moment
	healPerDuel = 0.10, -- of max HP
	healPerTrigger = 0.08,
	quietStartSeconds = 10,
	stats = table.freeze({ "damageReduction", "damage", "staminaRegen" }),
})

local EPSILON = 1e-9
local ACTIVE = { trigger = true, heal = true, telegraph = true }

-- The trigger conditions DuelModel knows how to evaluate: an HP threshold (a share of max HP, 0 < x <= 1), the
-- latches the model sets itself, and the opponent's heavy attack.
local FIXED_CONDITIONS = { staminaOut = true, hype = true, opponentHeavy = true }

local function validCondition(condition: any): boolean
	if type(condition) ~= "string" then
		return false
	end
	if FIXED_CONDITIONS[condition] then
		return true
	end
	local threshold = string.match(condition, "^hpBelow:([%d%.]+)$")
	local share = if threshold then tonumber(threshold) else nil
	return share ~= nil and share > 0 and share <= 1
end

local function pct(x: number): string
	return string.format("%.1f %%", x * 100)
end

local function isFinite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Caps.problems(modifiers: { Modifier }): { string }
	local caps = Caps.NUMBERS
	local problems: { string } = {}
	local function problem(text: string)
		table.insert(problems, text)
	end
	if type(modifiers) ~= "table" then
		return { "modifiers must be a list" }
	end

	local knownStat = {}
	for _, stat in caps.stats do
		knownStat[stat] = true
	end
	local passive: { [string]: number } = {}
	local strongestTrigger: { [string]: number } = {}
	local passiveTotal, healTotal = 0, 0
	local slotSources: { [string]: boolean } = {}
	local slotCount = 0
	local seenEffect: { [string]: boolean } = {}
	local slottedPassive: { [string]: boolean } = {}
	local function takeSlot(source: string)
		if not slotSources[source] then
			slotSources[source] = true
			slotCount += 1
		end
	end

	for i, m in modifiers do
		local name = if type(m) == "table" and type(m.source) == "string" then m.source else `#{i}`
		if type(m) ~= "table" then
			problem(`{name}: not a modifier table`)
			continue
		end
		if m.affectsOpponent then
			problem(`{name}: support never acts on the opponent (§6.6)`)
		end
		local magnitude = m.magnitude
		if m.kind ~= "telegraph" then
			if not isFinite(magnitude) then
				problem(`{name}: magnitude must be a finite number`)
				continue
			elseif (magnitude :: number) < 0 then
				problem(
					`{name}: negative magnitude {pct(magnitude :: number)}; weak support never goes below baseline (§6.7)`
				)
				continue
			end
		end
		local mag = magnitude or 0

		if m.kind == "passive" then
			if not knownStat[m.stat or ""] then
				problem(`{name}: unknown stat '{tostring(m.stat)}'`)
				continue
			end
			passive[m.stat :: string] = (passive[m.stat :: string] or 0) + mag
			passiveTotal += mag
			if m.slot then
				if slotSources[name] then
					problem(`{name}: listed twice; a slotted passive counts once per duel`)
				end
				slottedPassive[name] = true
				takeSlot(name)
			end
		elseif ACTIVE[m.kind] then
			local effect = `{name}|{m.kind}|{tostring(m.stat)}`
			if seenEffect[effect] then
				problem(`{name}: listed twice; each trigger fires at most once per duel`)
			end
			seenEffect[effect] = true
			if slottedPassive[name] then -- the same refusal whichever of the two comes first
				problem(`{name}: listed twice; a slotted passive counts once per duel`)
			end
			takeSlot(name)
			if not validCondition(m.condition) then
				problem(`{name}: needs a known condition (hpBelow:<share>, staminaOut, hype or opponentHeavy)`)
			end
			if not isFinite(m.duration) or (m.duration :: number) <= 0 then
				problem(`{name}: duration must be a positive number of seconds`)
			elseif (m.duration :: number) > caps.triggerMaxSeconds + EPSILON then
				problem(`{name}: lasts {m.duration} s; cap {caps.triggerMaxSeconds} s`)
			end
			if m.earliest ~= nil and m.earliest < caps.quietStartSeconds then
				problem(`{name}: may fire at {m.earliest} s; no trigger in the first {caps.quietStartSeconds} s`)
			end
			if m.kind == "trigger" then
				if not knownStat[m.stat or ""] then
					problem(`{name}: unknown stat '{tostring(m.stat)}'`)
				elseif mag > caps.triggerMaxMagnitude + EPSILON then
					problem(`{name}: +{pct(mag)} on {m.stat}; cap +{pct(caps.triggerMaxMagnitude)}`)
				else
					strongestTrigger[m.stat :: string] = math.max(strongestTrigger[m.stat :: string] or 0, mag)
				end
			elseif m.kind == "heal" then
				if mag > caps.healPerTrigger + EPSILON then
					problem(`{name}: heals {pct(mag)} of max HP; cap {pct(caps.healPerTrigger)} per trigger`)
				end
				healTotal += mag
			end
		else
			problem(`{name}: unknown kind '{tostring(m.kind)}'`)
		end
	end

	if slotCount > caps.maxTriggers then
		problem(`{slotCount} support triggers; cap {caps.maxTriggers} per duel`)
	end
	for _, stat in caps.stats do
		local p = passive[stat] or 0
		if p > caps.passivePerStat + EPSILON then
			problem(`passive +{pct(p)} on {stat}; cap +{pct(caps.passivePerStat)} per stat`)
		end
		local total = p + (strongestTrigger[stat] or 0)
		if total > caps.totalPerStat + EPSILON then
			problem(`{stat} can reach +{pct(total)} (passive + strongest trigger); cap +{pct(caps.totalPerStat)}`)
		end
	end
	if passiveTotal > caps.passiveCombined + EPSILON then
		problem(`passive bonuses add up to +{pct(passiveTotal)}; cap +{pct(caps.passiveCombined)} combined`)
	end
	if healTotal > caps.healPerDuel + EPSILON then
		problem(`support heals {pct(healTotal)} of max HP per duel; cap {pct(caps.healPerDuel)}`)
	end
	return problems
end

function Caps.check(modifiers: { Modifier }): (boolean, string?)
	local problems = Caps.problems(modifiers)
	if #problems == 0 then
		return true, nil
	end
	return false, problems[1]
end

return Caps
