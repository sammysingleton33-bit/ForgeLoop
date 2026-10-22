--!strict
--[[
	DesignSupport — the PROVISIONAL support numbers of design/crown-arena.md §3 (tiers) and §4 (key
	citizen perks) as modifier lists for the fairness harness (FL-0076, FORGE-05).

	A test fixture, not game config: when FORGE-01's config `Support.luau` lands (FL-0071) the harness
	reads that file instead, and Caps.spec checks both. Until then this is what "the design" means in
	the fairness report.

		DesignSupport.TIER_ORDER, DesignSupport.TIERS[tier] = { passive, slots, crowdRally }
		DesignSupport.PERK_ORDER, DesignSupport.VS2_PERKS
		DesignSupport.modifiers(tier, perks: { string }, power: "pledged" | "empowered") -> { Modifier }
			errors on an unknown tier or perk, more perks than slots, or the Crowd Rally below Adoring
		DesignSupport.perkSets(tier, pool: { string }) -> { { string } }
			every set of exactly min(slots, usable pool) distinct perks; { {} } when the tier has no slots
]]

local DesignSupport = {}

DesignSupport.TIER_ORDER = table.freeze({ "adoring", "loyal", "divided", "restless", "hostile" })

DesignSupport.TIERS = table.freeze({
	adoring = { passive = { damageReduction = 0.02, staminaRegen = 0.02 }, slots = 3, crowdRally = true },
	loyal = { passive = { damageReduction = 0.01, staminaRegen = 0.01 }, slots = 3, crowdRally = false },
	divided = { passive = {}, slots = 2, crowdRally = false },
	restless = { passive = {}, slots = 1, crowdRally = false },
	hostile = { passive = {}, slots = 0, crowdRally = false },
})

-- [power] = magnitude; §4 table, "Pledged (loyalty 80-94) / Empowered (95-100)".
local PERKS = {
	reforge = {
		kind = "trigger",
		stat = "damageReduction",
		pledged = 0.06,
		empowered = 0.10,
		duration = 6,
		condition = "hpBelow:0.5",
	},
	fieldRemedy = { kind = "heal", pledged = 0.05, empowered = 0.08, duration = 4, condition = "hpBelow:0.35" },
	calledWarning = {
		kind = "telegraph",
		pledged = 0.15,
		empowered = 0.25,
		duration = 8,
		uses = { pledged = 2, empowered = 2 },
		condition = "opponentHeavy",
	},
	heartyRations = {
		kind = "trigger",
		stat = "staminaRegen",
		pledged = 0.06,
		empowered = 0.10,
		duration = 8,
		condition = "staminaOut",
	},
	rallyingHymn = {
		kind = "trigger",
		stat = "damage",
		pledged = 0.03,
		empowered = 0.05,
		duration = 5,
		condition = "hype",
	},
	fineWares = { kind = "passive", stat = "damageReduction", pledged = 0.02, empowered = 0.03 },
}

DesignSupport.PERK_ORDER = table.freeze({
	"reforge",
	"fieldRemedy",
	"calledWarning",
	"heartyRations",
	"rallyingHymn",
	"fineWares",
	"crowdRally",
})
DesignSupport.VS2_PERKS = table.freeze({ "reforge", "fieldRemedy", "calledWarning", "heartyRations" })

local function perkModifiers(name: string, power: string): { any }
	if name == "crowdRally" then
		-- §3: when HP first drops below 20 %: damage reduction +5 % and stamina regeneration +10 % for 5 s
		return {
			{
				source = "crowdRally",
				kind = "trigger",
				stat = "damageReduction",
				magnitude = 0.05,
				duration = 5,
				condition = "hpBelow:0.2",
			},
			{
				source = "crowdRally",
				kind = "trigger",
				stat = "staminaRegen",
				magnitude = 0.10,
				duration = 5,
				condition = "hpBelow:0.2",
			},
		}
	end
	local perk = PERKS[name]
	if perk == nil then
		error(`DesignSupport: unknown perk '{name}'`, 3)
	end
	local magnitude = (perk :: any)[power]
	if type(magnitude) ~= "number" then
		error(`DesignSupport: power must be "pledged" or "empowered" (got {tostring(power)})`, 3)
	end
	local source = `perk:{name}`
	if perk.kind == "telegraph" then
		return {
			{
				source = source,
				kind = "telegraph",
				lead = magnitude,
				uses = if type(perk.uses) == "table" then perk.uses[power] else perk.uses,
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

function DesignSupport.modifiers(tier: string, perks: { string }?, power: string?): { any }
	local def = DesignSupport.TIERS[tier]
	if def == nil then
		error(`DesignSupport: unknown tier '{tostring(tier)}'`, 2)
	end
	local list = perks or {}
	if #list > def.slots then
		error(`DesignSupport: {tier} has {def.slots} trigger slot(s), got {#list} perks`, 2)
	end
	local out = {}
	for _, stat in { "damageReduction", "damage", "staminaRegen" } do
		local magnitude = def.passive[stat]
		if magnitude then
			table.insert(out, { source = `tier:{tier}`, kind = "passive", stat = stat, magnitude = magnitude })
		end
	end
	for _, name in list do
		if name == "crowdRally" and not def.crowdRally then
			error(`DesignSupport: the Crowd Rally needs the Adoring tier (got {tier})`, 2)
		end
		for _, m in perkModifiers(name, power or "empowered") do
			table.insert(out, m)
		end
	end
	return out
end

function DesignSupport.perkSets(tier: string, pool: { string }): { { string } }
	local def = DesignSupport.TIERS[tier]
	if def == nil then
		error(`DesignSupport: unknown tier '{tostring(tier)}'`, 2)
	end
	local usable = {}
	for _, name in pool do
		if name ~= "crowdRally" or def.crowdRally then
			table.insert(usable, name)
		end
	end
	local size = math.min(def.slots, #usable)
	local sets: { { string } } = {}
	local current: { string } = {}
	local function pick(from: number)
		if #current == size then
			table.insert(sets, table.clone(current))
			return
		end
		for i = from, #usable do
			table.insert(current, usable[i])
			pick(i + 1)
			table.remove(current)
		end
	end
	pick(1)
	return sets
end

return DesignSupport
