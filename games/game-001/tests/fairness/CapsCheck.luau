--!strict
--[[
	CapsCheck — checks one duellist's support modifiers against CONTRACTS G12.3 (FL-0076, FORGE-05).

	The harness runs it on every setup before a duel (as DuelService must run Caps.check, G12.2), and
	Caps.spec runs it on the design numbers and on deliberately over-cap sets. It is the reference the
	real src/shared/Arena/Caps.luau (FORGE-01, FL-0071) is compared with once that lands.

		CapsCheck.check(modifiers: { Modifier }, contract?) -> { string }   -- problems; empty = within caps

	Modifier (proposed to FORGE-01 for G12.2, which names the type but does not define it):
		{ source: string,                 -- "tier:adoring", "perk:reforge", "crowdRally", "fineWares"
		  kind: "passive" | "trigger" | "heal" | "telegraph",
		  stat: string?,                  -- passive and trigger: damageReduction | damage | staminaRegen
		  magnitude: number?,             -- fraction (+6 % = 0.06); heal: fraction of max HP
		  duration: number?,              -- seconds; trigger, heal and telegraph
		  condition: string?,             -- "hpBelow:0.5", "staminaOut", "opponentHeavy", "hype"
		  earliest: number?,              -- earliest duel second it may fire; nil = the engine's quiet start
		  lead: number?,                  -- telegraph: seconds earlier the opponent's heavy is shown
		  uses: number?,                  -- telegraph: heavy attacks covered
		  slot: boolean?,                 -- passive that takes a trigger slot (Fine Wares)
		  affectsOpponent: boolean? }     -- always forbidden (§6.6)
	One trigger with two effects (Crowd Rally: damage reduction and stamina regeneration) is two
	modifiers with the same source; it counts once against the trigger cap. The same source twice on
	the same stat is an error. Trigger, heal and telegraph modifiers always take a slot.
]]

local CapsContract = require("./CapsContract")

export type Modifier = {
	source: string,
	kind: string,
	stat: string?,
	magnitude: number?,
	duration: number?,
	condition: string?,
	earliest: number?,
	lead: number?,
	uses: number?,
	slot: boolean?,
	affectsOpponent: boolean?,
}

local EPSILON = 1e-9
local ACTIVE = { trigger = true, heal = true, telegraph = true }

local CapsCheck = {}

local function pct(x: number): string
	return string.format("%.1f %%", x * 100)
end

local function isFinite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function CapsCheck.check(modifiers: { Modifier }, contract: any?): { string }
	local caps = contract or CapsContract
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
				takeSlot(name)
			end
		elseif ACTIVE[m.kind] then
			local effect = `{name}|{m.kind}|{tostring(m.stat)}`
			if seenEffect[effect] then
				problem(`{name}: listed twice; each trigger fires at most once per duel`)
			end
			seenEffect[effect] = true
			takeSlot(name)
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

return CapsCheck
