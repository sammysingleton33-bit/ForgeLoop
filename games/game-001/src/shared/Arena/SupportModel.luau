--!strict
--[[
	Arena/SupportModel — the Crown Arena support score, tier, trigger offers and the duel modifiers they become
	(CONTRACTS G12.2, design §3-§4). Owner: FORGE-01. Pure and deterministic: no Roblox API, no clock, no randomness.
	LeadershipService samples the kingdom and the ruler; SupportService and DuelService call this and nothing else to
	turn those samples into support. Numbers: config Support (PROVISIONAL, inside the G12.3 caps).

		SupportModel.score(samples, ruler, config?): (score: number, tier: SupportTier, breakdown: { [component]: number })
			samples  { { t = seconds, components = { [SupportComponent] = 0..100 } } }, any order
			ruler    { now = seconds }   the time the score is read at (the last 15 minutes are counted back from it)
			The score is the weighted sum of each component's time-weighted average: the whole match carries
			`wholeMatchShare` (40 %) of the weight, the samples of the last `recentSeconds` (15 min) the rest, so one good
			deed in the final minute cannot buy support and an early mistake can be repaired. A component with no
			sample counts as 50 (neutral). Score 0..100.
		SupportModel.tierOf(score, config?): SupportTier
		SupportModel.trend(samples, ruler, config?): number    average score of the last `trendSeconds` minus the five before
		SupportModel.offers(keyCitizens, tier, config?): ({ TriggerOffer }, slots: number)
			keyCitizens  { { role, citizenId?, name?, loyalty, alive } }; a perk is offered for a living key citizen of
			loyalty >= 80 (pledged), the stronger one from 95 (empowered); the Crowd Rally only at Adoring.
			slots is the tier's slot count; the usable count is min(slots, offers).
		SupportModel.modifiers(tier, picks, config?): { Modifier }
			picks { { trigger = TriggerId, power = "pledged" | "empowered" } }; the tier's passive blessing plus each perk's
			modifiers. Errors on more picks than slots, a duplicate or unknown trigger, a perk the offers do not carry, a
			non-power pick, or a Crowd Rally below Adoring.
]]

local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local Types = require("./Types")

type SupportTier = Types.SupportTier
type TriggerOffer = Types.TriggerOffer
type Modifier = Types.Modifier

export type Sample = { t: number, components: { [string]: number } }
export type KeyCitizen = { role: string, citizenId: number?, name: string?, loyalty: number, alive: boolean }

local SupportModel = {}

local NEUTRAL = 50

local function clamp(x: number, lo: number, hi: number): number
	return math.max(lo, math.min(hi, x))
end

-- A number that is neither NaN nor infinite. The support chain never lets one through: math.min / math.max swallow a NaN
-- (the answer depends on the argument order), so a bad input would otherwise become a top or bottom score.
local function finite(x: any): boolean
	return type(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- The time-weighted average of one component (nil samples count as neutral).
local function weightedAverage(samples: { Sample }, component: string, now: number, cfg: any): number
	local sampling = cfg.sampling
	local all, recent = 0, 0
	local allSum, recentSum = 0, 0
	if not finite(now) then
		return NEUTRAL
	end
	for _, sample in samples do
		if finite(sample.t) and sample.t <= now then
			local raw = sample.components[component]
			local value = clamp(if finite(raw) then raw else NEUTRAL, 0, 100)
			all += 1
			allSum += value
			if sample.t > now - sampling.recentSeconds then
				recent += 1
				recentSum += value
			end
		end
	end
	if all == 0 then
		return NEUTRAL
	end
	local wholeAverage = allSum / all
	if recent == 0 then
		return wholeAverage
	end
	local recentAverage = recentSum / recent
	return sampling.wholeMatchShare * wholeAverage + (1 - sampling.wholeMatchShare) * recentAverage
end

function SupportModel.tierOf(score: number, config: any?): SupportTier
	local cfg = config or Support
	if not finite(score) then
		score = NEUTRAL -- a NaN is no evidence either way: the middle tier, never a top or bottom one
	end
	for _, tier in cfg.tierOrder do
		if score >= cfg.tiers[tier].min then
			return tier
		end
	end
	return cfg.tierOrder[#cfg.tierOrder]
end

function SupportModel.score(
	samples: { Sample },
	ruler: { now: number },
	config: any?
): (number, SupportTier, { [string]: number })
	local cfg = config or Support
	local breakdown: { [string]: number } = {}
	local total, weights = 0, 0
	for _, component in cfg.componentOrder do
		local weight = cfg.components[component].weight
		local value = weightedAverage(samples, component, ruler.now, cfg)
		breakdown[component] = value
		total += weight * value
		weights += weight
	end
	local score = clamp(total / weights, 0, 100) -- every average is finite (weightedAverage), so this is too
	return score, SupportModel.tierOf(score, cfg), breakdown
end

function SupportModel.trend(samples: { Sample }, ruler: { now: number }, config: any?): number
	local cfg = config or Support
	local window = cfg.trendSeconds
	local function average(from: number, to: number): number?
		local sum, n = 0, 0
		for _, sample in samples do
			if sample.t > from and sample.t <= to then
				local sampleScore = SupportModel.score({ sample }, { now = sample.t }, cfg)
				sum += sampleScore
				n += 1
			end
		end
		return if n > 0 then sum / n else nil
	end
	local recent = average(ruler.now - window, ruler.now)
	local before = average(ruler.now - 2 * window, ruler.now - window)
	if recent == nil or before == nil then
		return 0
	end
	return recent - before
end

-- A perk's `uses` is one number or per tier ({ pledged, empowered }).
local function usesOf(perk: any, power: string): number?
	local uses = perk.uses
	if type(uses) == "table" then
		return uses[power]
	end
	return uses
end

local NUMBER_WORDS = { "one", "two", "three", "four", "five" }

local function format(text: string, magnitude: number, uses: number?): string
	local shown = string.format("%d %%", math.floor(magnitude * 100 + 0.5))
	local text2 = string.gsub(text, "{magnitude}", function()
		return shown -- a function: a "%" in the text is not a capture reference
	end)
	return (string.gsub(text2, "{uses}", function()
		return NUMBER_WORDS[uses or 1] or tostring(uses)
	end))
end

function SupportModel.offers(keyCitizens: { KeyCitizen }, tier: SupportTier, config: any?): ({ TriggerOffer }, number)
	local cfg = config or Support
	local tierDef = cfg.tiers[tier]
	if tierDef == nil then
		error(`SupportModel: unknown tier '{tostring(tier)}'`, 2)
	end
	local offers: { TriggerOffer } = {}
	local byRole: { [string]: KeyCitizen } = {}
	for _, citizen in keyCitizens do
		if citizen.alive and byRole[citizen.role] == nil then
			byRole[citizen.role] = citizen -- at most one key citizen per role
		end
	end
	for _, role in cfg.roleOrder do
		local citizen = byRole[role]
		local roleDef = cfg.roles[role]
		if citizen and roleDef and citizen.loyalty >= cfg.offer.pledgedLoyalty then
			local power = if citizen.loyalty >= cfg.offer.empoweredLoyalty then "empowered" else "pledged"
			local perk = cfg.perks[roleDef.perk]
			table.insert(offers, {
				trigger = roleDef.perk,
				citizenId = citizen.citizenId,
				citizenName = citizen.name,
				role = role,
				loyalty = citizen.loyalty,
				power = power,
				condition = perk.when,
				effect = format(perk.effect, perk[power], usesOf(perk, power)),
			})
		end
	end
	if tierDef.crowdRally then
		table.insert(offers, {
			trigger = "crowdRally",
			power = "empowered",
			condition = cfg.crowdRally.when,
			effect = cfg.crowdRally.effect,
		})
	end
	return offers, tierDef.slots
end

local function perkModifiers(trigger: string, power: string, cfg: any): { Modifier }
	if trigger == "crowdRally" then
		local rally = cfg.crowdRally
		return {
			{
				source = "crowdRally",
				kind = "trigger",
				stat = "damageReduction",
				magnitude = rally.damageReduction,
				duration = rally.duration,
				condition = rally.condition,
			},
			{
				source = "crowdRally",
				kind = "trigger",
				stat = "staminaRegen",
				magnitude = rally.staminaRegen,
				duration = rally.duration,
				condition = rally.condition,
			},
		}
	end
	local perk = cfg.perks[trigger]
	if perk == nil then
		error(`SupportModel: unknown trigger '{tostring(trigger)}'`, 3)
	end
	local magnitude = if power == "pledged" or power == "empowered" then perk[power] else nil
	if type(magnitude) ~= "number" then
		error(`SupportModel: power must be "pledged" or "empowered" (got {tostring(power)})`, 3)
	end
	local source = `perk:{trigger}`
	if perk.kind == "telegraph" then
		return {
			{
				source = source,
				kind = "telegraph",
				lead = magnitude,
				uses = usesOf(perk, power),
				duration = perk.duration,
				condition = perk.condition,
			},
		}
	elseif perk.kind == "passive" then
		return { { source = source, kind = "passive", stat = perk.stat, magnitude = magnitude, slot = true } }
	end
	return {
		{
			source = source,
			kind = perk.kind,
			stat = perk.stat,
			magnitude = magnitude,
			duration = perk.duration,
			condition = perk.condition,
		},
	}
end

function SupportModel.modifiers(
	tier: SupportTier,
	picks: { { trigger: string, power: string } },
	config: any?
): { Modifier }
	local cfg = config or Support
	local tierDef = cfg.tiers[tier]
	if tierDef == nil then
		error(`SupportModel: unknown tier '{tostring(tier)}'`, 2)
	end
	if #picks > tierDef.slots then
		error(`SupportModel: {tier} has {tierDef.slots} trigger slot(s), got {#picks} perks`, 2)
	end
	local out: { Modifier } = {}
	for _, stat in { "damageReduction", "damage", "staminaRegen" } do
		local magnitude = tierDef.passive[stat]
		if magnitude then
			table.insert(out, { source = `tier:{tier}`, kind = "passive", stat = stat, magnitude = magnitude })
		end
	end
	local picked: { [string]: boolean } = {}
	for _, pick in picks do
		if type(pick.trigger) ~= "string" then
			error(`SupportModel: unknown trigger '{tostring(pick.trigger)}'`, 2)
		end
		if picked[pick.trigger] then
			error(`SupportModel: '{tostring(pick.trigger)}' is picked twice; each trigger fires once per duel`, 2)
		end
		picked[pick.trigger] = true
		if pick.trigger == "crowdRally" and not tierDef.crowdRally then
			error(`SupportModel: the Crowd Rally needs the Adoring tier (got {tier})`, 2)
		end
		for _, modifier in perkModifiers(pick.trigger, pick.power, cfg) do
			table.insert(out, modifier)
		end
	end
	return out
end

return SupportModel
