-- ContentQuery (games/game-001/src/shared/Content/ContentQuery.luau) against inline fixtures shaped
-- exactly like the generated modules (content/SPEC.md §7), so these specs do not depend on the
-- current draft content. Content.spec.luau checks the real generated library.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")

local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")

local CATEGORIES = { "compassion", "honor", "competence", "courage", "authority", "fear" }

local function repVector(partial: { [string]: number }): { [string]: number }
	local out = {}
	for _, c in CATEGORIES do
		out[c] = partial[c] or 0
	end
	return out
end

local function clause(var: string, op: string, value: any)
	return { var = var, op = op, value = value }
end

local function trait(id: string, weights: { [string]: number }, opposite: string?)
	return {
		id = id,
		name = id,
		description = `{id} fixture`,
		opposite = opposite,
		weights = repVector(weights),
		obedience_bias = 0,
		productivity = 1,
		hunger_sensitivity = 1,
		gossip = 1,
		volatility = 1,
	}
end

local function decision(id: string, fields: { [string]: any })
	local d: { [string]: any } = {
		id = id,
		farm_key = id,
		repeat_decay = 1,
		repeat_window_s = 0,
		cost = {},
		resources = {},
		rep = repVector({}),
		speaker = { loyalty = 0, chemistry = 0 },
		family_loyalty = 0,
		friends_loyalty = 0,
		rivals_loyalty = 0,
		audience = "none",
		audience_loyalty = 0,
		kingdom = { happiness = 0, stability = 0, morale = 0 },
		trait_overrides = {},
		consequences = {},
	}
	for k, v in fields do
		d[k] = v
	end
	return d
end

local function consequence(id: string, kind: string, target: string, chance: number, extra: { [string]: any }?)
	local c: { [string]: any } = {
		id = id,
		kind = kind,
		target = target,
		magnitude = 0,
		duration_s = 0,
		delay_s = 0,
		chance = chance,
	}
	for k, v in extra or {} do
		c[k] = v
	end
	return c
end

local function scenario(id: string, occupation: string, priority: number, fields: { [string]: any }?)
	local s: { [string]: any } = {
		id = id,
		occupation = occupation,
		trigger = {},
		priority = priority,
		cooldown_s = 0,
		once_per_citizen = false,
		thought = `{id} thought`,
		question = `{id} question`,
		responses = {
			{ id = `{id}_yes`, order = 1, text = "Yes.", reaction = "Thanks.", decision = "kind_act" },
			{ id = `{id}_no`, order = 2, text = "No.", reaction = "Hmph.", decision = "harsh_act" },
		},
	}
	for k, v in fields or {} do
		s[k] = v
	end
	return s
end

local TRAITS = {
	kind = trait("kind", { compassion = 2, honor = 1, fear = -2 }, "cruel"),
	cruel = trait("cruel", { compassion = -1, honor = -1, courage = 1, authority = 1, fear = 2 }, "kind"),
	brave = trait("brave", { honor = 1, courage = 2, authority = 1, fear = -1 }),
	lazy = trait("lazy", { compassion = 1, competence = -1, authority = -1, fear = -1 }),
	plain = trait("plain", {}),
}

local CONSEQUENCES = {
	cheer = consequence("cheer", "cue", "speaker", 1, { cue_id = "cheer" }),
	farmers_work_up = consequence("farmers_work_up", "productivity", "occupation:farmer", 1, {
		magnitude = 0.1,
		duration_s = 60,
		notice = "Farmers work 10% faster.",
	}),
	walkout_risk = consequence("walkout_risk", "strike", "speaker", 0.25, {
		magnitude = 1,
		duration_s = 30,
		notice = "{name} may walk out for {duration}.",
	}),
	calm = consequence("calm", "unrest_pressure", "kingdom", 1, { magnitude = -4, duration_s = 60 }),
	unrest = consequence("unrest", "unrest_pressure", "kingdom", 1, { magnitude = 5, duration_s = 60 }),
	loyal_friends = consequence("loyal_friends", "loyalty", "friends", 1, { magnitude = 2 }),
	sad = consequence("sad", "happiness", "kingdom", 1, { magnitude = -3, duration_s = 60 }),
}

local DECISIONS = {
	kind_act = decision("kind_act", {
		farm_key = "handout",
		repeat_decay = 0.5,
		repeat_window_s = 600,
		cost = { food = 25 },
		resources = { gold = -5 },
		rep = repVector({ compassion = 3, authority = -1 }),
		speaker = { loyalty = 6, chemistry = 1 },
		family_loyalty = 4,
		friends_loyalty = 2,
		rivals_loyalty = -1,
		audience = "occupation",
		audience_loyalty = 2,
		kingdom = { happiness = 2, stability = 1, morale = 0 },
		trait_overrides = { lazy = 2, cruel = -3 },
		consequences = { "farmers_work_up", "walkout_risk", "cheer" },
		memory_tag = "fed_by_ruler",
	}),
	harsh_act = decision("harsh_act", {
		rep = repVector({ authority = 2, fear = 3 }),
		speaker = { loyalty = -4, chemistry = 0 },
		audience = "kingdom",
		audience_loyalty = -1,
	}),
	private_act = decision("private_act", {
		rep = repVector({ honor = 2 }),
		speaker = { loyalty = 3, chemistry = 0 },
		audience = "none",
		audience_loyalty = 0,
	}),
	broken_ref = decision("broken_ref", { consequences = { "cheer", "missing_one" } }),
	-- a kind listener reacts with 2*10 + 1*10 = 30 before reach: far above every LOYALTY_CLAMP
	big_act = decision("big_act", {
		farm_key = "big",
		repeat_decay = 0.5,
		repeat_window_s = 600,
		rep = repVector({ compassion = 10, honor = 10 }),
		speaker = { loyalty = 10, chemistry = 0 },
		family_loyalty = 6,
		audience = "kingdom",
		audience_loyalty = 4,
	}),
	gain_act = decision("gain_act", {
		rep = repVector({ compassion = 2, fear = -1 }),
		speaker = { loyalty = 2, chemistry = 2 },
		kingdom = { happiness = 3, stability = -2, morale = 4 },
		consequences = { "calm", "unrest", "loyal_friends", "sad" },
	}),
}

-- File order deliberately differs from alphabetical order and from priority order.
local ORDER = {
	"z_farmer_low",
	"m_any_high",
	"a_farmer_high",
	"b_builder",
	"d_farmer_cd",
	"c_farmer_once",
	"e_farmer_locked",
}
local SCENARIOS = {
	z_farmer_low = scenario("z_farmer_low", "farmer", 10),
	a_farmer_high = scenario("a_farmer_high", "farmer", 80, {
		trigger = { { var = "kingdom.fed_ratio", op = "<", value = 0.8 } },
		cooldown_s = 300,
	}),
	m_any_high = scenario("m_any_high", "any", 80, {
		trigger = { { var = "phase", op = "in", value = { "Founding", "Expansion" } } },
		cooldown_s = 60,
	}),
	b_builder = scenario("b_builder", "builder", 90),
	c_farmer_once = scenario("c_farmer_once", "farmer", 50, {
		trigger = { { var = "citizen.has_family", op = "=", value = true } },
		once_per_citizen = true,
	}),
	d_farmer_cd = scenario("d_farmer_cd", "farmer", 50, {
		trigger = { { var = "citizen.memory.promised", op = "=", value = false } },
		cooldown_s = 120,
	}),
	e_farmer_locked = scenario("e_farmer_locked", "farmer", 70, { locked = true, cooldown_s = 300 }),
}

local OCCUPATIONS = {
	farmer = { id = "farmer", name = "Farmer", job = "farmer", needs = {}, trait_affinity = {} },
	soldier = { id = "soldier", name = "Soldier", job = "soldier", needs = {}, trait_affinity = {} },
	captain = {
		id = "captain",
		name = "Captain",
		job = "soldier",
		key_role = "captain",
		needs = {},
		trait_affinity = {},
	},
}

local function actionRow(id: string, event: string, fields: { [string]: any }?)
	local a: { [string]: any } = {
		id = id,
		event = event,
		condition = {},
		farm_key = id,
		repeat_decay = 1,
		repeat_window_s = 0,
		rep = repVector({}),
		audience_condition = {},
		audience_loyalty = 0,
		kingdom = { happiness = 0, stability = 0, morale = 0 },
	}
	for k, v in fields or {} do
		a[k] = v
	end
	return a
end

-- Rows 1-2 are one action with two audiences (soldiers appreciate it; hungry civilians resent it).
local ACTIONS = {
	actionRow("fund_barracks", "BuildingCompleted:barracks", {
		farm_key = "barracks",
		repeat_decay = 0.5,
		repeat_window_s = 900,
		audience = "soldiers",
		audience_loyalty = 3,
		kingdom = { happiness = 0, stability = 0, morale = 3 },
	}),
	actionRow("fund_barracks", "BuildingCompleted:barracks", {
		farm_key = "barracks",
		repeat_decay = 0.5,
		repeat_window_s = 900,
		condition = { clause("kingdom.fed_ratio", "<", 0.6) },
		rep = repVector({ compassion = -1 }),
		audience = "civilians",
		audience_condition = { clause("citizen.hunger", ">=", 0.4) },
		audience_loyalty = -3,
		kingdom = { happiness = -2, stability = 0, morale = 0 },
	}),
	actionRow("any_building", "BuildingCompleted", { rep = repVector({ competence = 1 }), audience = "kingdom" }),
	actionRow(
		"visit",
		"RulerVisited",
		{ rep = repVector({ compassion = 1 }), audience = "speaker", audience_loyalty = 3 }
	),
	actionRow("farmers_cheer", "BuildingCompleted:farm", { audience = "occupation:farmer", audience_loyalty = 1 }),
	-- rows 6-7: one action, a kingdom row and a speaker row (kind listener: 12 and 20 before the clamp)
	actionRow("festival", "Festival", {
		farm_key = "festival",
		repeat_decay = 0.5,
		repeat_window_s = 600,
		rep = repVector({ compassion = 5 }),
		audience = "kingdom",
		audience_loyalty = 10,
		kingdom = { happiness = 4, stability = -1, morale = 0 },
	}),
	actionRow("festival", "Festival", {
		farm_key = "festival",
		repeat_decay = 0.5,
		repeat_window_s = 600,
		rep = repVector({ compassion = 5, fear = -2 }),
		audience = "speaker",
		audience_loyalty = 10,
	}),
	-- rows 8-9: one action whose rows add a gain and a loss to the same categories (a keep raised while starving)
	actionRow("keep_up", "BuildingUpgraded:keep", {
		farm_key = "keep_up",
		repeat_decay = 0.5,
		repeat_window_s = 600,
		rep = repVector({ authority = 2 }),
		audience = "kingdom",
		audience_loyalty = 1,
		kingdom = { happiness = 3, stability = 0, morale = 0 },
	}),
	actionRow("keep_up", "BuildingUpgraded:keep", {
		farm_key = "keep_up",
		repeat_decay = 0.5,
		repeat_window_s = 600,
		condition = { clause("kingdom.fed_ratio", "<", 0.6) },
		rep = repVector({ authority = -1 }),
		audience = "civilians",
		audience_loyalty = -2,
		kingdom = { happiness = -1, stability = 0, morale = 0 },
	}),
}
local REPUTATION = {
	categories = {},
	order = CATEGORIES,
	actions = ACTIONS,
	byEvent = {
		["BuildingCompleted:barracks"] = { 1, 2 },
		BuildingCompleted = { 3 },
		RulerVisited = { 4 },
		["BuildingCompleted:farm"] = { 5 },
		Festival = { 6, 7 },
		["BuildingUpgraded:keep"] = { 8, 9 },
	},
}

local FIXTURE = {
	dialogue = { scenarios = SCENARIOS, order = ORDER },
	decisions = DECISIONS,
	consequences = CONSEQUENCES,
	traits = TRAITS,
	occupations = OCCUPATIONS,
	reputation = REPUTATION,
}

local function newQuery()
	return ContentQuery.new(FIXTURE :: any)
end

local function ids(list: { any }): { string }
	local out = {}
	for _, s in list do
		table.insert(out, s.id)
	end
	return out
end

local REACH_EXPECTED = { speaker = 1, family = 0.6, friends = 0.4, rivals = -0.3, kingdom = 0.2 }

describe("ContentQuery.evaluate (condition language, SPEC §4)", function()
	it("treats a nil or empty trigger as always true, with or without a ctx", function()
		expect(ContentQuery.evaluate(nil, {})).toBe(true)
		expect(ContentQuery.evaluate({}, {})).toBe(true)
		expect(ContentQuery.evaluate({}, nil)).toBe(true)
	end)

	it("compares numbers with every operator, including the boundary value", function()
		local ctx = { ["kingdom.food"] = 50 }
		local cases = {
			{ "=", 50, true },
			{ "=", 49, false },
			{ "!=", 50, false },
			{ "!=", 49, true },
			{ "<", 50, false },
			{ "<", 51, true },
			{ "<=", 50, true },
			{ "<=", 49, false },
			{ ">", 50, false },
			{ ">", 49, true },
			{ ">=", 50, true },
			{ ">=", 51, false },
		}
		for _, case in cases do
			local got = ContentQuery.evaluate({ clause("kingdom.food", case[1], case[2]) }, ctx)
			if got ~= case[3] then
				error(`kingdom.food(50) {case[1]} {case[2]}: expected {case[3]}, got {got}`)
			end
		end
	end)

	it("compares fractional numbers exactly", function()
		local ctx = { ["kingdom.fed_ratio"] = 0.8 }
		expect(ContentQuery.evaluate({ clause("kingdom.fed_ratio", "<", 0.8) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("kingdom.fed_ratio", "<=", 0.8) }, ctx)).toBe(true)
		expect(ContentQuery.evaluate({ clause("kingdom.fed_ratio", ">", 0.79) }, ctx)).toBe(true)
	end)

	it("compares strings with =, != and in", function()
		local ctx = { phase = "Expansion", occupation = "farmer" }
		expect(ContentQuery.evaluate({ clause("phase", "=", "Expansion") }, ctx)).toBe(true)
		expect(ContentQuery.evaluate({ clause("phase", "=", "expansion") }, ctx)).toBe(false) -- case-sensitive
		expect(ContentQuery.evaluate({ clause("phase", "!=", "Conflict") }, ctx)).toBe(true)
		expect(ContentQuery.evaluate({ clause("phase", "!=", "Expansion") }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("phase", "in", { "Founding", "Expansion" }) }, ctx)).toBe(true)
		expect(ContentQuery.evaluate({ clause("phase", "in", { "Conflict", "Endgame" }) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("phase", "in", {}) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("occupation", "in", { "farmer" }) }, ctx)).toBe(true)
	end)

	it("never coerces between numbers and strings", function()
		local ctx = { ["kingdom.food"] = "50", ["kingdom.level.keep"] = 2, phase = "2" }
		expect(ContentQuery.evaluate({ clause("kingdom.food", "=", 50) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("kingdom.food", ">=", 10) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("kingdom.food", "<", 100) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("kingdom.level.keep", "=", "2") }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("kingdom.level.keep", "in", { "2" }) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("phase", ">", 1) }, ctx)).toBe(false)
		-- "!=" is the negation of "=" for a present value, so a type mismatch is "not equal"
		expect(ContentQuery.evaluate({ clause("kingdom.food", "!=", 50) }, ctx)).toBe(true)
	end)

	it("reads bare booleans and '!' booleans as flags (absent = false)", function()
		local yes = clause("citizen.has_family", "=", true) -- `citizen.has_family`
		local no = clause("citizen.has_family", "=", false) -- `!citizen.has_family`
		expect(ContentQuery.evaluate({ yes }, { ["citizen.has_family"] = true })).toBe(true)
		expect(ContentQuery.evaluate({ yes }, { ["citizen.has_family"] = false })).toBe(false)
		expect(ContentQuery.evaluate({ yes }, {})).toBe(false)
		expect(ContentQuery.evaluate({ no }, { ["citizen.has_family"] = true })).toBe(false)
		expect(ContentQuery.evaluate({ no }, { ["citizen.has_family"] = false })).toBe(true)
		expect(ContentQuery.evaluate({ no }, {})).toBe(true)
		expect(ContentQuery.evaluate({ clause("event.raid", "!=", true) }, {})).toBe(true)
		expect(ContentQuery.evaluate({ clause("event.raid", "!=", false) }, { ["event.raid"] = true })).toBe(true)
		-- a flag must be a real boolean: 1 is not true
		expect(ContentQuery.evaluate({ yes }, { ["citizen.has_family"] = 1 })).toBe(false)
	end)

	it("makes every non-flag clause on an absent variable false, and never errors", function()
		local absent = {
			clause("kingdom.food", "=", 0),
			clause("kingdom.food", "!=", 0),
			clause("kingdom.food", "<", 100),
			clause("kingdom.food", "<=", 100),
			clause("kingdom.food", ">", -1),
			clause("kingdom.food", ">=", -1),
			clause("phase", "in", { "Founding" }),
			clause("phase", "!=", "Founding"),
		}
		for _, c in absent do
			local ok, result = pcall(ContentQuery.evaluate, { c }, {})
			expect(ok).toBe(true)
			if result ~= false then
				error(`absent {c.var} {c.op}: expected false, got {tostring(result)}`)
			end
		end
		expect(ContentQuery.evaluate({ clause("kingdom.food", "<", 100) }, nil)).toBe(false)
	end)

	it("is false (not an error) for an unknown operator, a malformed 'in' or a NaN value", function()
		local ctx = { ["kingdom.food"] = 50, phase = "Founding", ["citizen.mood"] = 0 / 0 }
		expect(ContentQuery.evaluate({ clause("kingdom.food", "==", 50) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("kingdom.food", "~", 50) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("phase", "in", "Founding") }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("citizen.mood", "<", 60) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("citizen.mood", ">=", 60) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("citizen.mood", "=", 0 / 0) }, ctx)).toBe(false)
		expect(ContentQuery.evaluate({ clause("citizen.trait.kind", "<", true) }, ctx)).toBe(false)
	end)

	it("counts an absent kingdom.count.<type> as 0, and only that family of variables", function()
		expect(ContentQuery.evaluate({ clause("kingdom.count.blacksmith", "<", 1) }, {})).toBe(true)
		expect(ContentQuery.evaluate({ clause("kingdom.count.blacksmith", "=", 0) }, {})).toBe(true)
		expect(ContentQuery.evaluate({ clause("kingdom.count.blacksmith", ">=", 1) }, {})).toBe(false)
		expect(
			ContentQuery.evaluate({ clause("kingdom.count.blacksmith", ">=", 1) }, { ["kingdom.count.blacksmith"] = 2 })
		).toBe(true)
		expect(ContentQuery.evaluate({ clause("kingdom.food", "<", 1) }, {})).toBe(false)
		expect(ContentQuery.evaluate({ clause("kingdom.level.keep", "=", 0) }, {})).toBe(false)
	end)

	it("ANDs chained clauses: every clause must hold", function()
		local trigger = {
			clause("phase", "in", { "Founding", "Expansion" }),
			clause("kingdom.fed_ratio", "<", 0.8),
			clause("citizen.hunger", ">=", 0.3),
			clause("citizen.has_family", "=", true),
			clause("citizen.memory.promised_harvest", "=", false),
		}
		local ctx = {
			phase = "Founding",
			["kingdom.fed_ratio"] = 0.5,
			["citizen.hunger"] = 0.3,
			["citizen.has_family"] = true,
		}
		expect(ContentQuery.evaluate(trigger, ctx)).toBe(true)
		local breakers = {
			{ "phase", "Conflict" },
			{ "kingdom.fed_ratio", 0.8 },
			{ "citizen.hunger", 0.29 },
			{ "citizen.has_family", false },
			{ "citizen.memory.promised_harvest", true },
		}
		for _, b in breakers do
			local broken = table.clone(ctx)
			broken[b[1]] = b[2]
			if ContentQuery.evaluate(trigger, broken) ~= false then
				error(`changing {b[1]} to {tostring(b[2])} should make the trigger false`)
			end
		end
	end)

	it("does not change the clauses or the ctx", function()
		local trigger = { clause("phase", "in", { "Founding" }), clause("citizen.has_rival", "=", false) }
		local ctx = { phase = "Founding" }
		local triggerCopy = { clause("phase", "in", { "Founding" }), clause("citizen.has_rival", "=", false) }
		ContentQuery.evaluate(trigger, ctx)
		expect(trigger).toEqual(triggerCopy)
		expect(ctx).toEqual({ phase = "Founding" })
	end)
end)

describe("ContentQuery.eligibleScenarios", function()
	local farmerCtx = {
		occupation = "farmer",
		phase = "Founding",
		["kingdom.fed_ratio"] = 0.5,
		["citizen.has_family"] = true,
	}

	it("matches the citizen's occupation or 'any' and sorts by priority, then file order", function()
		local q = newQuery()
		local got = q.eligibleScenarios(farmerCtx, { id = 7, occupation = "farmer" }, 0, {})
		-- m_any_high and a_farmer_high tie on 80: file order puts m_ (2nd) before a_ (3rd), against
		-- the alphabet; d_ and c_ tie on 50: d_ (5th) before c_ (6th). b_builder (90) is a builder's.
		expect(ids(got)).toEqual({ "m_any_high", "a_farmer_high", "d_farmer_cd", "c_farmer_once", "z_farmer_low" })
		expect(got[1]).toBe(SCENARIOS.m_any_high) -- the shared content record, not a copy
	end)

	it("filters by trigger", function()
		local q = newQuery()
		local ctx = table.clone(farmerCtx)
		ctx["kingdom.fed_ratio"] = 0.9
		ctx.phase = "Conflict"
		ctx["citizen.has_family"] = nil
		ctx["citizen.memory.promised"] = true
		local got = q.eligibleScenarios(ctx, { id = 7, occupation = "farmer" }, 0, nil)
		expect(ids(got)).toEqual({ "z_farmer_low" })
	end)

	it("offers only 'any' scenarios to an occupation without its own, and uses ctx.occupation as fallback", function()
		local q = newQuery()
		local smith = q.eligibleScenarios({ phase = "Expansion" }, { id = 1, occupation = "blacksmith" }, 0, {})
		expect(ids(smith)).toEqual({ "m_any_high" })
		local builder = q.eligibleScenarios({ phase = "Expansion", occupation = "builder" }, { id = 2 }, 0, {})
		expect(ids(builder)).toEqual({ "b_builder", "m_any_high" })
		local nobody = q.eligibleScenarios({ phase = "Arena" }, { id = 3 }, 0, {})
		expect(nobody).toEqual({})
	end)

	it("applies cooldown_s per citizen and per scenario, eligible again exactly at the boundary", function()
		local q = newQuery()
		local history = { [7] = { a_farmer_high = 1000, m_any_high = 1000 } }
		local citizen = { id = 7, occupation = "farmer" }
		local function has(now: number, id: string): boolean
			return table.find(ids(q.eligibleScenarios(farmerCtx, citizen, now, history)), id) ~= nil
		end
		expect(has(1299, "a_farmer_high")).toBe(false) -- 299 s < 300 s
		expect(has(1300, "a_farmer_high")).toBe(true) -- 300 s >= 300 s
		expect(has(1059, "m_any_high")).toBe(false)
		expect(has(1060, "m_any_high")).toBe(true)
		expect(has(1000, "z_farmer_low")).toBe(true) -- never shown
		-- another citizen is not affected by citizen 7's history
		local other = q.eligibleScenarios(farmerCtx, { id = 8, occupation = "farmer" }, 1000, history)
		expect(table.find(ids(other), "a_farmer_high")).toBeTruthy()
	end)

	it("offers a cooldown 0 scenario again immediately", function()
		local q = newQuery()
		local history = { [7] = { z_farmer_low = 500 } }
		local got = q.eligibleScenarios(farmerCtx, { id = 7, occupation = "farmer" }, 500, history)
		expect(table.find(ids(got), "z_farmer_low")).toBeTruthy()
	end)

	it("never offers a once_per_citizen scenario twice to the same citizen", function()
		local q = newQuery()
		local history = {}
		local citizen = { id = "c-7", occupation = "farmer" }
		expect(table.find(ids(q.eligibleScenarios(farmerCtx, citizen, 0, history)), "c_farmer_once")).toBeTruthy()
		q.markShown(history, citizen.id, "c_farmer_once", 0)
		expect(history).toEqual({ ["c-7"] = { c_farmer_once = 0 } })
		for _, now in { 0, 10, 1e6 } do
			expect(table.find(ids(q.eligibleScenarios(farmerCtx, citizen, now, history)), "c_farmer_once")).toBeNil()
		end
		local fresh = { id = "c-8", occupation = "farmer" }
		expect(table.find(ids(q.eligibleScenarios(farmerCtx, fresh, 0, history)), "c_farmer_once")).toBeTruthy()
	end)

	it("keys history by the citizen id exactly (number 7 and string '7' are different citizens)", function()
		local q = newQuery()
		local history = { ["7"] = { c_farmer_once = 0 } }
		local got = q.eligibleScenarios(farmerCtx, { id = 7, occupation = "farmer" }, 0, history)
		expect(table.find(ids(got), "c_farmer_once")).toBeTruthy()
	end)

	it("returns a new list each call and is deterministic", function()
		local q = newQuery()
		local citizen = { id = 7, occupation = "farmer" }
		local a = q.eligibleScenarios(farmerCtx, citizen, 0, {})
		local b = q.eligibleScenarios(farmerCtx, citizen, 0, {})
		expect(a).never.toBe(b)
		expect(ids(a)).toEqual(ids(b))
	end)

	it("offers a locked scenario only to a citizen it was unlocked for (unlock_scenario)", function()
		local q = newQuery()
		local function offered(citizen: any, now: number, history: any): { string }
			return ids(q.eligibleScenarios(farmerCtx, citizen, now, history))
		end
		expect(table.find(offered({ id = 7, occupation = "farmer" }, 0, {}), "e_farmer_locked")).toBeNil()
		local other = { id = 7, occupation = "farmer", unlocked = { a_farmer_high = true } }
		expect(table.find(offered(other, 0, {}), "e_farmer_locked")).toBeNil()
		local unlocked = { id = 7, occupation = "farmer", unlocked = { e_farmer_locked = true } }
		expect(offered(unlocked, 0, {})).toEqual({
			"m_any_high",
			"a_farmer_high",
			"e_farmer_locked",
			"d_farmer_cd",
			"c_farmer_once",
			"z_farmer_low",
		})
		-- once unlocked it still keeps its cooldown
		expect(table.find(offered(unlocked, 100, { [7] = { e_farmer_locked = 0 } }), "e_farmer_locked")).toBeNil()
		expect(table.find(offered(unlocked, 300, { [7] = { e_farmer_locked = 0 } }), "e_farmer_locked")).toBeTruthy()
	end)

	it("works with empty data", function()
		local q = ContentQuery.new({})
		expect(q.eligibleScenarios(farmerCtx, { id = 1, occupation = "farmer" }, 0, {})).toEqual({})
		expect(q.decisionEffects("kind_act")).toBeNil()
		expect(q.actionFirings("BuildingCompleted", {})).toEqual({})
		expect(q.choicePreview("a", "b", {})).toBeNil()
		expect(q.choiceRisks("kind_act", {})).toBeNil()
	end)
end)

describe("ContentQuery.decisionEffects", function()
	it("returns the decision's bundle with resolved consequences and the risks to show", function()
		local q = newQuery()
		local e = q.decisionEffects("kind_act")
		assert(e, "kind_act exists")
		expect(e.id).toBe("kind_act")
		expect(e.farm_key).toBe("handout")
		expect(e.repeat_decay).toBe(0.5)
		expect(e.repeat_window_s).toBe(600)
		expect(e.multiplier).toBe(1)
		expect(e.cost).toEqual({ food = 25 })
		expect(e.resources).toEqual({ gold = -5 })
		expect(e.rep).toEqual(repVector({ compassion = 3, authority = -1 }))
		expect(e.rep_raw).toEqual(e.rep)
		expect(e.speaker).toEqual({ loyalty = 6, chemistry = 1 })
		expect(e.family_loyalty).toBe(4)
		expect(e.friends_loyalty).toBe(2)
		expect(e.rivals_loyalty).toBe(-1)
		expect(e.audience).toBe("occupation")
		expect(e.audience_loyalty).toBe(2)
		expect(e.kingdom).toEqual({ happiness = 2, stability = 1, morale = 0 })
		expect(e.trait_overrides).toEqual({ lazy = 2, cruel = -3 })
		expect(ids(e.consequences)).toEqual({ "farmers_work_up", "walkout_risk", "cheer" })
		expect(e.consequences[1]).toEqual(CONSEQUENCES.farmers_work_up)
		expect(ids(e.risks)).toEqual({ "walkout_risk" })
		expect(e.risks[1].chance).toBe(0.25)
		expect(e.memory_tag).toBe("fed_by_ruler")
	end)

	it("scales reputation gains by the repeat multiplier and never reduces losses", function()
		local q = newQuery()
		local e = q.decisionEffects("kind_act", 0.25)
		assert(e, "kind_act exists")
		expect(e.multiplier).toBe(0.25)
		expect(e.rep.compassion).toBeNear(0.75)
		expect(e.rep.authority).toBe(-1)
		expect(e.rep.fear).toBe(0)
		expect(e.rep_raw).toEqual(repVector({ compassion = 3, authority = -1 }))
		-- the explicit loyalty columns are decayed too (kingdomMultiplier defaults to the multiplier);
		-- losses stay whole and the raw columns are kept in loyalty_raw (review finding M1)
		expect(e.speaker.loyalty).toBe(1.5)
		expect(e.family_loyalty).toBe(1)
		expect(e.friends_loyalty).toBe(0.5)
		expect(e.rivals_loyalty).toBe(-1)
		expect(e.audience_loyalty).toBe(0.5)
		expect(e.loyalty_raw).toEqual({ speaker = 6, family = 4, friends = 2, rivals = -1, audience = 2 })
		local h = q.decisionEffects("harsh_act", 0)
		assert(h, "harsh_act exists")
		expect(h.rep).toEqual(repVector({}))
		expect(h.rep_raw).toEqual(repVector({ authority = 2, fear = 3 }))
	end)

	it("hands out fresh copies, so callers cannot change the content", function()
		local q = newQuery()
		local e = q.decisionEffects("kind_act")
		assert(e, "kind_act exists")
		e.cost.food = 1
		e.rep.compassion = 99
		e.trait_overrides.lazy = 99
		e.speaker.loyalty = 99
		e.kingdom.happiness = 99
		e.consequences[1].magnitude = 99
		local again = q.decisionEffects("kind_act")
		assert(again, "kind_act exists")
		expect(again.cost.food).toBe(25)
		expect(again.rep.compassion).toBe(3)
		expect(again.trait_overrides.lazy).toBe(2)
		expect(again.speaker.loyalty).toBe(6)
		expect(again.kingdom.happiness).toBe(2)
		expect(again.consequences[1].magnitude).toBe(0.1)
		expect(DECISIONS.kind_act.cost.food).toBe(25)
		expect(CONSEQUENCES.farmers_work_up.magnitude).toBe(0.1)
	end)

	it("returns nil for an unknown decision and errors on a dangling consequence id", function()
		local q = newQuery()
		expect(q.decisionEffects("nope")).toBeNil()
		expect(function()
			q.decisionEffects("broken_ref")
		end).toThrow("unknown consequence 'missing_one'")
		local p = q.decisionEffects("private_act")
		assert(p, "private_act exists")
		expect(p.memory_tag).toBeNil()
		expect(p.consequences).toEqual({})
		expect(p.risks).toEqual({})
	end)
end)

describe("ContentQuery anti-farming of kingdom gains (SPEC §6.5)", function()
	it("scales kingdom, chemistry and consequence gains by the kingdom multiplier, never losses", function()
		local q = newQuery()
		local e = q.decisionEffects("gain_act", 1, 0.5)
		assert(e, "gain_act exists")
		expect(e.multiplier).toBe(1)
		expect(e.kingdom_multiplier).toBe(0.5)
		expect(e.rep).toEqual(repVector({ compassion = 2, fear = -1 })) -- the ruler's own multiplier is 1
		expect(e.kingdom).toEqual({ happiness = 1.5, stability = -2, morale = 2 })
		expect(e.speaker).toEqual({ loyalty = 1, chemistry = 1 })
		expect(e.loyalty_raw.speaker).toBe(2)
		local magnitude = {}
		for _, c in e.consequences do
			magnitude[c.id] = c.magnitude
		end
		expect(magnitude).toEqual({ calm = -2, unrest = 5, loyal_friends = 1, sad = -3 }) -- relief is a gain
		expect(CONSEQUENCES.calm.magnitude).toBe(-4) -- the content itself is untouched
		expect(DECISIONS.gain_act.kingdom.happiness).toBe(3)
	end)

	it("defaults the kingdom multiplier to the ruler multiplier", function()
		local e = newQuery().decisionEffects("gain_act", 0.25)
		assert(e, "gain_act exists")
		expect(e.kingdom_multiplier).toBe(0.25)
		expect(e.kingdom.happiness).toBe(0.75)
		expect(e.kingdom.stability).toBe(-2)
		expect(e.rep.compassion).toBe(0.5)
	end)
end)

describe("ContentQuery.fireDecision (one call per choice, SPEC §6.5 and §6.8)", function()
	it("decays the ruler's reputation and the kingdom's gains separately and records both firings", function()
		local q = newQuery()
		local rulerA, rulerB, kingdom = {}, {}, {}
		local first = q.fireDecision("kind_act", rulerA, kingdom, 0)
		assert(first, "kind_act exists")
		expect(first.multiplier).toBe(1)
		expect(first.kingdom_multiplier).toBe(1)
		expect(rulerA).toEqual({ handout = { 0 } })
		expect(kingdom).toEqual({ handout = { 0 } })
		-- a co-ruler's first time: full reputation for them, but the kingdom already heard it once
		local second = q.fireDecision("kind_act", rulerB, kingdom, 10)
		assert(second, "kind_act exists")
		expect(second.multiplier).toBe(1)
		expect(second.kingdom_multiplier).toBe(0.5)
		expect(second.rep.compassion).toBe(3)
		expect(second.kingdom.happiness).toBe(1)
		expect(q.decisionLoyalty("kind_act", { "kind" }, "speaker", 0, second.kingdom_multiplier)).toBe(6)
		local third = q.fireDecision("kind_act", rulerA, kingdom, 20)
		assert(third, "kind_act exists")
		expect(third.multiplier).toBe(0.5)
		expect(third.kingdom_multiplier).toBe(0.25)
		expect(kingdom).toEqual({ handout = { 0, 10, 20 } })
		expect(q.fireDecision("nope", rulerA, kingdom, 30)).toBeNil()
		expect(rulerA.nope).toBeNil()
	end)

	it("records one firing when the same history is passed for ruler and kingdom", function()
		local q = newQuery()
		local h = {}
		q.fireDecision("kind_act", h, h, 0)
		expect(h).toEqual({ handout = { 0 } })
	end)
end)

describe("ContentQuery.choicePreview (model decision 7, CONTRACTS G13.3 option extras)", function()
	local NAMES = { name = "Agnes", ruler = "Ruler", kingdom = "Kingdom", occupation = "Farmer" }

	it("returns exactly the G13.3 option extras: cost? and risks? with filled text and the chance", function()
		local q = newQuery()
		local p = q.choicePreview("a_farmer_high", "a_farmer_high_yes", NAMES)
		assert(p, "the answer exists")
		-- no decision id and no raw consequence records: only { cost, risks }
		expect(p).toEqual({
			cost = { food = 25 },
			risks = { { text = "Agnes may walk out for 30 s.", chance = 0.25 } },
		})
		local keys = {}
		for key in p do
			table.insert(keys, key)
		end
		table.sort(keys)
		expect(keys).toEqual({ "cost", "risks" })
		-- a free answer without risks: both are omitted (nil), so the option is just { id, text }
		local harsh = q.choicePreview("a_farmer_high", "a_farmer_high_no", NAMES)
		expect(harsh).toEqual({})
		expect(q.choicePreview("a_farmer_high", "nope", NAMES)).toBeNil()
		expect(q.choicePreview("nope", "a_farmer_high_yes", NAMES)).toBeNil()
	end)

	it("hands out a fresh cost table and never the shared consequence records", function()
		local q = newQuery()
		local p = q.choicePreview("a_farmer_high", "a_farmer_high_yes", NAMES)
		assert(p and p.cost and p.risks, "the answer exists")
		p.cost.food = 1
		expect(table.isfrozen(p.cost)).toBe(false)
		expect(DECISIONS.kind_act.cost.food).toBe(25)
		expect((p.risks[1] :: any).id).toBeNil()
		expect((p.risks[1] :: any).kind).toBeNil()
	end)

	it("requires fillNames on every call, not only where a risk names someone (SPEC §6.7)", function()
		local q = newQuery()
		local message = "ContentQuery.choicePreview: fillNames is required"
		expect(function()
			q.choicePreview("a_farmer_high", "a_farmer_high_yes", nil :: any)
		end).toThrow(message)
		-- a free answer without risks, and an unknown answer, fail the same way: a forgetful server fails at once
		expect(function()
			q.choicePreview("a_farmer_high", "a_farmer_high_no", nil :: any)
		end).toThrow(message)
		expect(function()
			q.choicePreview("nope", "nope", nil :: any)
		end).toThrow(message)
		expect(q.choicePreview("a_farmer_high", "a_farmer_high_no", {})).toEqual({})
	end)

	it("leaves the cost to pay to decisionEffects: always a table, {} when free (SPEC §6.5)", function()
		local q = newQuery()
		for _, answer in { { "a_farmer_high_yes", "kind_act" }, { "a_farmer_high_no", "harsh_act" } } do
			local p = q.choicePreview("a_farmer_high", answer[1], NAMES)
			local e = q.decisionEffects(answer[2])
			assert(p and e, answer[1])
			expect(e.cost).toEqual(p.cost or {})
		end
		expect((q.decisionEffects("harsh_act") :: any).cost).toEqual({})
	end)
end)

describe("ContentQuery.choiceRisks (FORGE-00 ruling on the PR #67 review, item 2)", function()
	local NAMES = { name = "Agnes", ruler = "Ruler", kingdom = "Kingdom", occupation = "Farmer" }

	it("lists only the chance < 1 consequences, as { text, chance } with every placeholder filled", function()
		local q = newQuery()
		expect(q.choiceRisks("kind_act", NAMES)).toEqual({
			{ text = "Agnes may walk out for 30 s.", chance = 0.25 },
		})
		-- certain consequences are never risks; a decision without risks gives an empty list
		expect(q.choiceRisks("gain_act", NAMES)).toEqual({})
		expect(q.choiceRisks("harsh_act", NAMES)).toEqual({})
		expect(q.choiceRisks("nope", NAMES)).toBeNil()
	end)

	it("fills the mechanics last, so a name entry can never replace them", function()
		local q = newQuery()
		local risks = q.choiceRisks("kind_act", { name = "Agnes", duration = "a blink" })
		assert(risks, "kind_act exists")
		expect(risks[1].text).toBe("Agnes may walk out for 30 s.")
	end)

	it("errors instead of showing an unfilled placeholder or a risk without text", function()
		local q = newQuery()
		expect(function()
			q.choiceRisks("kind_act", { ruler = "Ruler" })
		end).toThrow(
			"ContentQuery.choiceRisks: risk 'walkout_risk' of decision 'kind_act' uses {name}: pass fillNames.name"
		)
		expect(function()
			q.choiceRisks("kind_act", nil :: any)
		end).toThrow("pass fillNames.name")
		local silent = ContentQuery.new({
			decisions = { d = decision("d", { consequences = { "hidden" } }) },
			consequences = { hidden = consequence("hidden", "morale", "soldiers", 0.5, { magnitude = -2 }) },
		} :: any)
		expect(function()
			silent.choiceRisks("d", NAMES)
		end).toThrow("risk 'hidden' of decision 'd' has no notice text")
		expect(ContentQuery.choiceRisks).toBeA("function")
	end)
end)

describe("ContentQuery actions (SPEC §6.9)", function()
	it("returns the rows of an event and of its bare name, filtered by condition, grouped per action", function()
		local q = newQuery()
		local fed = q.actionFirings("BuildingCompleted:barracks", { ["kingdom.fed_ratio"] = 0.9 })
		expect(#fed).toBe(2)
		expect(fed[1].id).toBe("fund_barracks")
		expect(fed[1].farm_key).toBe("barracks")
		expect(fed[1].repeat_decay).toBe(0.5)
		expect(#fed[1].rows).toBe(1)
		expect(fed[1].kingdom).toEqual({ happiness = 0, stability = 0, morale = 3 })
		expect(fed[2].id).toBe("any_building")
		expect(fed[2].rep).toEqual(repVector({ competence = 1 }))
		local starving = q.actionFirings("BuildingCompleted:barracks", { ["kingdom.fed_ratio"] = 0.5 })
		expect(#starving[1].rows).toBe(2)
		expect(starving[1].rows[2]).toBe(ACTIONS[2]) -- the shared content row
		expect(starving[1].rep).toEqual(repVector({ compassion = -1 }))
		expect(starving[1].kingdom).toEqual({ happiness = -2, stability = 0, morale = 3 })
		expect(#q.actionFirings("BuildingCompleted", {})).toBe(1)
		expect(q.actionFirings("Nothing", {})).toEqual({})
		expect(q.scaleGains(starving[1].kingdom :: any, 0.5)).toEqual({ happiness = -2, stability = 0, morale = 1.5 })
	end)

	it(
		"finds each row's audience: soldiers by job, civilians, occupation, speaker, kingdom, then the listener condition",
		function()
			local q = newQuery()
			local soldiers, civilians = ACTIONS[1] :: any, ACTIONS[2] :: any
			expect(q.inActionAudience(soldiers, { occupation = "soldier" }, {})).toBe(true)
			expect(q.inActionAudience(soldiers, { occupation = "captain" }, {})).toBe(true) -- job soldier
			expect(q.inActionAudience(soldiers, { occupation = "farmer" }, {})).toBe(false)
			local hungry = { ["citizen.hunger"] = 0.5 }
			expect(q.inActionAudience(civilians, { occupation = "farmer" }, hungry)).toBe(true)
			expect(q.inActionAudience(civilians, { occupation = "farmer" }, { ["citizen.hunger"] = 0.1 })).toBe(false)
			expect(q.inActionAudience(civilians, { occupation = "captain" }, hungry)).toBe(false)
			expect(q.inActionAudience(ACTIONS[3] :: any, { occupation = "captain" }, {})).toBe(true)
			expect(q.inActionAudience(ACTIONS[4] :: any, { occupation = "farmer", speaker = true }, {})).toBe(true)
			expect(q.inActionAudience(ACTIONS[4] :: any, { occupation = "farmer" }, {})).toBe(false)
			expect(q.inActionAudience(ACTIONS[5] :: any, { occupation = "farmer" }, {})).toBe(true)
			expect(q.inActionAudience(ACTIONS[5] :: any, { occupation = "soldier" }, {})).toBe(false)
			expect(q.inActionAudience(actionRow("nobody", "X") :: any, { occupation = "farmer" }, {})).toBe(false)
		end
	)

	it("computes a listener's loyalty with speaker or group reach, the explicit column and the multiplier", function()
		local q = newQuery()
		-- civilians row: compassion -1; a kind listener at group reach: 2 * -1 * 0.2 - 3 = -3.4
		expect(q.actionLoyalty(ACTIONS[2] :: any, { "kind" }, 0)).toBeNear(-3.4)
		expect(q.actionLoyalty(ACTIONS[2] :: any, { "kind" }, 0, 0)).toBeNear(-3.4) -- losses never decay
		-- visit row at speaker reach: 2 * 1 + 3 = 5, halved by the repeat multiplier
		expect(q.actionLoyalty(ACTIONS[4] :: any, { "kind" }, 0)).toBe(5)
		expect(q.actionLoyalty(ACTIONS[4] :: any, { "kind" }, 0, 0.5)).toBe(2.5)
		expect(q.actionLoyalty(ACTIONS[4] :: any, { "kind" }, 20)).toBeNear(7.5)
		expect(q.actionLoyalty(actionRow("nobody", "X") :: any, { "kind" }, 0)).toBe(0)
	end)
end)

describe("ContentQuery notice text (SPEC §3)", function()
	it("fills the mechanics placeholders from the consequence's own numbers", function()
		local risk = consequence("risk", "productivity", "speaker", 0.5, {
			magnitude = -0.15,
			duration_s = 45,
			notice = "Risk ({chance}): {name} is {magnitude_pct} slower for {duration}.",
		}) :: any
		expect(ContentQuery.noticeValues(risk)).toEqual({
			chance = "50%",
			magnitude = "-0.15",
			magnitude_pct = "15%",
			duration = "45 s",
		})
		expect(ContentQuery.consequenceNotice(risk, { name = "Agnes" })).toBe(
			"Risk (50%): Agnes is 15% slower for 45 s."
		)
		expect(ContentQuery.consequenceNotice(risk)).toBe("Risk (50%): {name} is 15% slower for 45 s.")
		local unrest = consequence("u", "unrest_pressure", "kingdom", 1, {
			magnitude = 5,
			duration_s = 240,
			notice = "Unrest {magnitude} for {duration}.",
		}) :: any
		expect(ContentQuery.consequenceNotice(unrest)).toBe("Unrest +5 for 4 minutes.")
		unrest.magnitude = -5
		expect(ContentQuery.consequenceNotice(unrest)).toBe("Unrest -5 for 4 minutes.")
		expect(ContentQuery.consequenceNotice(consequence("x", "cue", "speaker", 1) :: any)).toBeNil()
	end)

	it("writes durations in seconds or whole minutes", function()
		expect(ContentQuery.durationText(45)).toBe("45 s")
		expect(ContentQuery.durationText(60)).toBe("1 minute")
		expect(ContentQuery.durationText(120)).toBe("2 minutes")
		expect(ContentQuery.durationText(90)).toBe("90 s")
		expect(ContentQuery.durationText(0)).toBe("0 s")
	end)

	it("fill replaces only the keys it is given, literally", function()
		expect(ContentQuery.fill("{a} and {b}", { a = "x" })).toBe("x and {b}")
		expect(ContentQuery.fill("{a} {a}", { a = "50%" })).toBe("50% 50%")
	end)
end)

describe("ContentQuery.loyaltyDelta (model decisions 3-4)", function()
	it("exports the reach per relation as a frozen table", function()
		expect(ContentQuery.REACH).toEqual(REACH_EXPECTED)
		expect(table.isfrozen(ContentQuery.REACH)).toBe(true)
		expect(ContentQuery.CATEGORIES).toEqual(CATEGORIES)
		expect(newQuery().loyaltyDelta).toBeA("function")
	end)

	it("sums trait weight x reputation change over categories and traits", function()
		local q = newQuery()
		local dR = repVector({ compassion = 3, authority = -1 })
		-- kind: 2*3 + 0*-1 = 6
		expect(q.loyaltyDelta(dR, { "kind" }, "speaker", 0)).toBe(6)
		-- cruel: -1*3 + 1*-1 = -4
		expect(q.loyaltyDelta(dR, { "cruel" }, "speaker", 0)).toBe(-4)
		-- lazy: 1*3 + -1*-1 = 4; kind + lazy = 10; kind + cruel = 2
		expect(q.loyaltyDelta(dR, { "lazy" }, "speaker", 0)).toBe(4)
		expect(q.loyaltyDelta(dR, { "kind", "lazy" }, "speaker", 0)).toBe(10)
		expect(q.loyaltyDelta(dR, { "kind", "cruel" }, "speaker", 0)).toBe(2)
		expect(q.loyaltyDelta(dR, { "plain" }, "speaker", 0)).toBe(0)
		expect(q.loyaltyDelta(dR, {}, "speaker", 0)).toBe(0)
	end)

	it("lets different personalities react differently to the same decision", function()
		local q = newQuery()
		local fearAct = repVector({ authority = 2, fear = 3 })
		expect(q.loyaltyDelta(fearAct, { "cruel" }, "speaker", 0)).toBe(8) -- 1*2 + 2*3
		expect(q.loyaltyDelta(fearAct, { "kind" }, "speaker", 0)).toBe(-6) -- -2*3
		expect(q.loyaltyDelta(fearAct, { "brave" }, "speaker", 0)).toBe(-1) -- 1*2 - 1*3
	end)

	it("scales by reach, and rivals react inversely", function()
		local q = newQuery()
		local dR = repVector({ compassion = 5 }) -- kind: 10 at full reach
		for relation, reach in REACH_EXPECTED do
			expect(q.loyaltyDelta(dR, { "kind" }, relation :: any, 0)).toBeNear(10 * reach)
		end
		expect(q.loyaltyDelta(dR, { "kind" }, "rivals", 0)).toBeNear(-3)
	end)

	it("multiplies gains by 1 + chemistry/40 and losses by 1 - chemistry/40", function()
		local q = newQuery()
		local gain = repVector({ compassion = 5 }) -- kind: +10
		local loss = repVector({ fear = 5 }) -- kind: -10
		expect(q.loyaltyDelta(gain, { "kind" }, "speaker", 20)).toBeNear(15)
		expect(q.loyaltyDelta(loss, { "kind" }, "speaker", 20)).toBeNear(-5)
		expect(q.loyaltyDelta(gain, { "kind" }, "speaker", -20)).toBeNear(5)
		expect(q.loyaltyDelta(loss, { "kind" }, "speaker", -20)).toBeNear(-15)
		expect(q.loyaltyDelta(gain, { "kind" }, "speaker", 8)).toBeNear(12)
		expect(q.loyaltyDelta(loss, { "kind" }, "speaker", 8)).toBeNear(-8)
		expect(q.loyaltyDelta(gain, { "kind" }, "speaker", nil)).toBe(10)
		-- the sign after reach decides: a favour to the rival's rival is a loss for the rival
		expect(q.loyaltyDelta(gain, { "kind" }, "rivals", 20)).toBeNear(-3 * 0.5)
	end)

	it("clamps chemistry to -20..+20 and ignores NaN", function()
		local q = newQuery()
		local gain = repVector({ compassion = 5 })
		expect(q.loyaltyDelta(gain, { "kind" }, "speaker", 1000)).toBeNear(15)
		expect(q.loyaltyDelta(gain, { "kind" }, "speaker", -1000)).toBeNear(5)
		expect(q.loyaltyDelta(gain, { "kind" }, "speaker", 0 / 0)).toBe(10)
	end)

	it("adds the flat extra before the chemistry factor and treats missing categories as 0", function()
		local q = newQuery()
		expect(q.loyaltyDelta({ compassion = 1 }, { "kind" }, "family", 0, 3)).toBeNear(2 * 0.6 + 3)
		expect(q.loyaltyDelta({}, { "kind" }, "speaker", 20, 4)).toBeNear(6)
		expect(q.loyaltyDelta({}, { "kind" }, "speaker", 20, -4)).toBeNear(-2)
		expect(q.loyaltyDelta({ fear = 1 }, { "kind" }, "speaker", 0, 2)).toBe(0) -- -2 + 2
	end)

	it("errors on an unknown trait or relation", function()
		local q = newQuery()
		expect(function()
			q.loyaltyDelta({}, { "kind", "dragonborn" }, "speaker", 0)
		end).toThrow("unknown trait 'dragonborn'")
		expect(function()
			q.loyaltyDelta({}, { "kind" }, "cousin" :: any, 0)
		end).toThrow("unknown relation 'cousin'")
	end)
end)

describe("ContentQuery.decisionLoyalty", function()
	it("combines personality, the relation's column and trait overrides for the speaker", function()
		local q = newQuery()
		-- kind_act rep: compassion +3, authority -1; speaker_loyalty 6
		expect(q.decisionLoyalty("kind_act", { "kind" }, "speaker", 0)).toBe(12) -- 6 + 6
		-- cruel: personality -4, column 6, override -3 => -1 (a loss: chemistry 20 halves it)
		expect(q.decisionLoyalty("kind_act", { "cruel" }, "speaker", 0)).toBe(-1)
		expect(q.decisionLoyalty("kind_act", { "cruel" }, "speaker", 20)).toBeNear(-0.5)
		-- lazy: personality 4, column 6, override +2 => 12; chemistry 20 => 18
		expect(q.decisionLoyalty("kind_act", { "lazy" }, "speaker", 20)).toBeNear(18)
	end)

	it("uses the family, friends and rivals columns with their reach", function()
		local q = newQuery()
		expect(q.decisionLoyalty("kind_act", { "kind" }, "family", 0)).toBeNear(6 * 0.6 + 4)
		expect(q.decisionLoyalty("kind_act", { "kind" }, "friends", 0)).toBeNear(6 * 0.4 + 2)
		expect(q.decisionLoyalty("kind_act", { "kind" }, "rivals", 0)).toBeNear(6 * -0.3 - 1)
		expect(q.decisionLoyalty("kind_act", { "plain" }, "family", 0)).toBe(4)
	end)

	it("reaches the kingdom audience only when the decision has one", function()
		local q = newQuery()
		expect(q.decisionLoyalty("kind_act", { "kind" }, "kingdom", 0)).toBeNear(6 * 0.2 + 2)
		expect(q.decisionLoyalty("harsh_act", { "cruel" }, "kingdom", 0)).toBeNear(8 * 0.2 - 1)
		expect(q.decisionLoyalty("private_act", { "kind" }, "kingdom", 20)).toBe(0)
		expect(q.decisionLoyalty("private_act", { "kind" }, "speaker", 0)).toBe(5) -- 1*2 + 3
	end)

	it("decays a listener's net change for one decision as one value, gains only (ruling #11, SPEC §6.5)", function()
		local q = newQuery()
		-- kind_act (compassion +3, authority -1; speaker column +6) for a brave speaker: personality 1 x -1 = -1,
		-- net -1 + 6 = 5 is a gain: 5 x 0.5 = 2.5 (not 6 x 0.5 - 1 = 2, as decaying each part would give)
		expect(q.loyaltyDelta(DECISIONS.kind_act.rep, { "brave" }, "speaker", 0, 6)).toBe(5)
		expect(q.decisionLoyalty("kind_act", { "brave" }, "speaker", 0, 0.5)).toBe(2.5)
		-- a cruel speaker: personality -4, column +6, override -3: the net -1 is a loss and never decays
		-- (not 6 x 0.5 - 4 - 3 = -4)
		expect(q.decisionLoyalty("kind_act", { "cruel" }, "speaker", 0, 0.5)).toBe(-1)
		expect(q.decisionLoyalty("kind_act", { "cruel" }, "speaker", 0, 1)).toBe(-1)
	end)

	it("applies the repeat multiplier to gains only (model decision 5)", function()
		local q = newQuery()
		expect(q.decisionLoyalty("kind_act", { "kind" }, "speaker", 0, 0.5)).toBe(6)
		expect(q.decisionLoyalty("kind_act", { "kind" }, "speaker", 0, 0)).toBe(0)
		-- losses are not reduced: harsh_act for a kind speaker is -6 - 4 = -10 at any multiplier
		expect(q.decisionLoyalty("harsh_act", { "kind" }, "speaker", 0, 0.5)).toBe(-10)
		expect(q.decisionLoyalty("harsh_act", { "kind" }, "speaker", 0, 0)).toBe(-10)
	end)

	it("errors on an unknown decision or relation", function()
		local q = newQuery()
		expect(function()
			q.decisionLoyalty("nope", { "kind" }, "speaker", 0)
		end).toThrow("unknown decision 'nope'")
		expect(function()
			q.decisionLoyalty("kind_act", { "kind" }, "cousin" :: any, 0)
		end).toThrow("unknown relation 'cousin'")
	end)
end)

describe("ContentQuery.repeatMultiplier and recordFire (model decision 5)", function()
	it("is 1 for the first firing, with no history, decay 1 or window 0", function()
		expect(ContentQuery.repeatMultiplier(nil, "handout", 0, 0.5, 600)).toBe(1)
		expect(ContentQuery.repeatMultiplier({}, "handout", 0, 0.5, 600)).toBe(1)
		local history = { handout = { 0, 10 } }
		expect(ContentQuery.repeatMultiplier(history, "handout", 20, 1, 600)).toBe(1)
		expect(ContentQuery.repeatMultiplier(history, "handout", 20, 0.5, 0)).toBe(1)
		expect(ContentQuery.repeatMultiplier(history, "handout", 20, nil, nil)).toBe(1)
	end)

	it("gives the n-th firing inside the window decay^(n-1)", function()
		local history = { handout = { 0, 10, 20 } }
		expect(ContentQuery.repeatMultiplier(history, "handout", 30, 0.5, 600)).toBe(0.125)
		expect(ContentQuery.repeatMultiplier(history, "handout", 30, 0.6, 600)).toBeNear(0.216)
	end)

	it("counts only the same farm key", function()
		local history = { handout = { 0, 10 }, promise = { 5 } }
		expect(ContentQuery.repeatMultiplier(history, "promise", 20, 0.5, 600)).toBe(0.5)
		expect(ContentQuery.repeatMultiplier(history, "firm_ruling", 20, 0.5, 600)).toBe(1)
	end)

	it("forgets firings once the window has passed (now - t >= window)", function()
		local history = { handout = { 100 } }
		expect(ContentQuery.repeatMultiplier(history, "handout", 699, 0.5, 600)).toBe(0.5)
		expect(ContentQuery.repeatMultiplier(history, "handout", 700, 0.5, 600)).toBe(1)
		expect(ContentQuery.repeatMultiplier(history, "handout", 5000, 0.5, 600)).toBe(1)
		local mixed = { handout = { 0, 500, 650 } }
		expect(ContentQuery.repeatMultiplier(mixed, "handout", 700, 0.5, 600)).toBe(0.25) -- 0 expired
	end)

	it("clamps decay into [0, 1] so a repeat never amplifies a gain", function()
		local history = { handout = { 0 } }
		expect(ContentQuery.repeatMultiplier(history, "handout", 1, 1.5, 600)).toBe(1)
		expect(ContentQuery.repeatMultiplier(history, "handout", 1, -1, 600)).toBe(0)
		expect(ContentQuery.repeatMultiplier(history, "handout", 1, 0 / 0, 600)).toBe(1)
	end)

	it("decays a farmed action step by step and recovers after the window", function()
		local history = {}
		local seen = {}
		for _, now in { 0, 60, 120, 180 } do
			table.insert(seen, ContentQuery.repeatMultiplier(history, "build_house", now, 0.5, 600))
			ContentQuery.recordFire(history, "build_house", now)
		end
		expect(seen).toEqual({ 1, 0.5, 0.25, 0.125 })
		expect(history.build_house).toEqual({ 0, 60, 120, 180 })
		expect(ContentQuery.repeatMultiplier(history, "build_house", 700, 0.5, 600)).toBe(0.25) -- 120, 180 remain
		expect(ContentQuery.repeatMultiplier(history, "build_house", 780, 0.5, 600)).toBe(1)
	end)

	it("keeps at most MAX_FARM_HISTORY firings per key, newest last", function()
		local history = {}
		local max = ContentQuery.MAX_FARM_HISTORY
		for i = 1, max + 5 do
			expect(ContentQuery.recordFire(history, "k", i)).toBe(history)
		end
		expect(#history.k).toBe(max)
		expect(history.k[1]).toBe(6)
		expect(history.k[max]).toBe(max + 5)
	end)

	it("gives 0, not decay^cap, once the window holds MAX_FARM_HISTORY firings (ruling #8)", function()
		local max = ContentQuery.MAX_FARM_HISTORY
		local full, almost = {}, {}
		for i = 1, max do
			table.insert(full, i)
			if i > 1 then
				table.insert(almost, i)
			end
		end
		expect(ContentQuery.repeatMultiplier({ k = almost }, "k", max + 1, 0.8, 600)).toBe(0.8 ^ (max - 1))
		expect(ContentQuery.repeatMultiplier({ k = full }, "k", max + 1, 0.8, 600)).toBe(0)
		-- only firings inside the window count towards the cap
		expect(ContentQuery.repeatMultiplier({ k = full }, "k", max + 1, 0.8, max)).toBe(0.8 ^ (max - 1)) -- t = 1 expired
		-- decay 1 or window 0 still means no anti-farming at all
		expect(ContentQuery.repeatMultiplier({ k = full }, "k", max + 1, 1, 600)).toBe(1)
		expect(ContentQuery.repeatMultiplier({ k = full }, "k", max + 1, 0.8, 0)).toBe(1)
	end)

	it("bounds 30 minutes of one firing per second by one firing / (1 - decay) (ruling #8)", function()
		-- the review's repro: past the cap every further firing still got decay^32 (0.8^32 x 1768 firings = +7 here)
		local q = ContentQuery.new({
			reputation = {
				categories = {},
				order = CATEGORIES,
				actions = {
					actionRow("drill", "Drill", {
						farm_key = "drill",
						repeat_decay = 0.8,
						repeat_window_s = 600,
						rep = repVector({ courage = 5, fear = -1 }),
						audience = "kingdom",
						audience_loyalty = 2,
						kingdom = { happiness = 0, stability = 0, morale = 4 },
					}),
				},
				byEvent = { Drill = { 1 } },
			},
			traits = TRAITS,
		} :: any)
		local rulers, kingdom = { r = {} }, {}
		local listeners = { { citizen = 1, traits = {} } }
		local courage, fear, morale, loyalty = 0, 0, 0, 0
		for now = 0, 30 * 60 - 1 do
			local f = q.fireAction("Drill", {}, rulers, { "r" }, kingdom, now, listeners :: any)[1]
			courage += f.rulers[1].rep.courage
			fear += f.rulers[1].rep.fear
			morale += f.kingdom.morale
			loyalty += f.listeners[1].loyalty
		end
		local bound = 1 / (1 - 0.8)
		expect(courage <= 5 * bound + 1e-9).toBe(true)
		expect(morale <= 4 * bound + 1e-9).toBe(true)
		expect(loyalty <= 2 * bound + 1e-9).toBe(true)
		expect(courage).toBeGreaterThan(5 * (1 - 0.8 ^ 32) * bound - 1e-9) -- the first 32 firings still count
		expect(fear).toBe(-1 * 30 * 60) -- losses never decay
		expect(#kingdom.drill).toBe(ContentQuery.MAX_FARM_HISTORY)
	end)

	it("needs a full window for that bound: spaced firings get decay^(cap - 1) each (ruling #8 wording)", function()
		-- the review's repro: one firing every 19 s keeps 31 firings in the 600 s window, so the cap never bites
		local max = ContentQuery.MAX_FARM_HISTORY
		local history = {}
		local total, n = 0, 0
		for now = 0, 30 * 60 - 1, 19 do
			local m = ContentQuery.repeatMultiplier(history, "drill", now, 0.8, 600)
			n += 1
			if n > max then
				expect(m).toBe(0.8 ^ (max - 1)) -- small, never 0
			end
			total += 5 * m
			ContentQuery.recordFire(history, "drill", now)
		end
		expect(n).toBe(95)
		expect(total).toBeGreaterThan(5 / (1 - 0.8)) -- past one firing / (1 - decay): the bound needs a full window
		expect(total).toBeLessThan(5 / (1 - 0.8) + 5 * (n - max) * 0.8 ^ (max - 1) + 1e-9)
		expect(0.8 ^ (max - 1)).toBeLessThan(0.001) -- negligible for decay <= 0.8
	end)

	it("scaleGain scales only positive deltas", function()
		expect(ContentQuery.scaleGain(4, 0.5)).toBe(2)
		expect(ContentQuery.scaleGain(-4, 0.5)).toBe(-4)
		expect(ContentQuery.scaleGain(0, 0.5)).toBe(0)
	end)
end)

describe("ContentQuery chemistry helpers (model decisions 2 and 4)", function()
	it("applyChemistry scales gains and losses in opposite directions", function()
		expect(ContentQuery.applyChemistry(4, 20)).toBe(6)
		expect(ContentQuery.applyChemistry(-4, 20)).toBe(-2)
		expect(ContentQuery.applyChemistry(4, -20)).toBe(2)
		expect(ContentQuery.applyChemistry(-4, -20)).toBe(-6)
		expect(ContentQuery.applyChemistry(0, 20)).toBe(0)
		expect(ContentQuery.applyChemistry(4, nil)).toBe(4)
	end)

	it("driftChemistry keeps decision changes within 5 of the rolled value and within -20..20", function()
		expect(ContentQuery.CHEMISTRY_DRIFT_MAX).toBe(5)
		expect(ContentQuery.driftChemistry(0, 0, 3)).toBe(3)
		expect(ContentQuery.driftChemistry(0, 4, 3)).toBe(5)
		expect(ContentQuery.driftChemistry(0, -4, -3)).toBe(-5)
		expect(ContentQuery.driftChemistry(18, 18, 5)).toBe(20)
		expect(ContentQuery.driftChemistry(-18, -20, -1)).toBe(-20)
		expect(ContentQuery.driftChemistry(3, 3, 0 / 0)).toBe(3)
	end)

	it("scaleGains scales the positive entries of a copy", function()
		local v = { a = 4, b = -4, c = 0 }
		expect(ContentQuery.scaleGains(v, 0.5)).toEqual({ a = 2, b = -4, c = 0 })
		expect(v.a).toBe(4)
	end)

	it("startLoyalty is the integer floor(50 + chemistry/4 + 0.5) with chemistry clamped (L12)", function()
		expect(ContentQuery.startLoyalty(0)).toBe(50)
		expect(ContentQuery.startLoyalty(nil)).toBe(50)
		expect(ContentQuery.startLoyalty(20)).toBe(55)
		expect(ContentQuery.startLoyalty(-20)).toBe(45)
		expect(ContentQuery.startLoyalty(-12)).toBe(47)
		expect(ContentQuery.startLoyalty(99)).toBe(55)
		expect(ContentQuery.startLoyalty(0 / 0)).toBe(50)
		-- halves round up, like FORGE-01's generator (#46): 50.5 -> 51, 49.5 -> 50
		expect(ContentQuery.startLoyalty(2)).toBe(51)
		expect(ContentQuery.startLoyalty(-2)).toBe(50)
		expect(ContentQuery.startLoyalty(1)).toBe(50)
		expect(ContentQuery.startLoyalty(3)).toBe(51)
		expect(ContentQuery.startLoyalty(-14)).toBe(47)
		for chemistry = -20, 20 do
			local start = ContentQuery.startLoyalty(chemistry)
			if start ~= math.floor(start) or start ~= math.floor(50 + chemistry / 4 + 0.5) then
				error(
					`startLoyalty({chemistry}) = {start}, expected the integer {math.floor(50 + chemistry / 4 + 0.5)}`
				)
			end
		end
	end)
end)

describe("ContentQuery.fireDecision is applied as given (review findings M1, M3)", function()
	it("decays the explicit loyalty columns, so farming one answer cannot add up the raw column", function()
		-- FORGE-05 repro: five firings inside the window. Applied as given, the raw column summed to 5 x 6.
		local q = newQuery()
		local ruler, kingdom = {}, {}
		local speakerTotal, familyTotal, rivalsTotal = 0, 0, 0
		for i = 1, 5 do
			local e = q.fireDecision("kind_act", ruler, kingdom, i * 8)
			assert(e, "kind_act exists")
			speakerTotal += e.speaker.loyalty
			familyTotal += e.family_loyalty
			rivalsTotal += e.rivals_loyalty
			expect(e.loyalty_raw.speaker).toBe(6)
		end
		-- 6 x (1 + 1/2 + 1/4 + 1/8 + 1/16) = 11.625, not 30; a loss (rivals -1) is never decayed
		expect(speakerTotal).toBeNear(11.625)
		expect(familyTotal).toBeNear(7.75)
		expect(rivalsTotal).toBe(-5)
	end)

	it("returns each given listener's final loyalty: personality, overrides, chemistry, decay, clamp", function()
		local q = newQuery()
		local ruler, kingdom = {}, {}
		local listeners = {
			{ citizen = 7, relation = "speaker", traits = { "kind" }, chemistry = 0 },
			{ citizen = 8, relation = "family", traits = { "cruel" }, chemistry = 20 },
			{ citizen = 9, relation = "kingdom", traits = { "lazy" } },
		}
		local first = q.fireDecision("kind_act", ruler, kingdom, 0, listeners :: any)
		assert(first, "kind_act exists")
		expect(first.listeners).toEqual({
			{ citizen = 7, relation = "speaker", loyalty = 12 },
			{ citizen = 8, relation = "family", loyalty = q.decisionLoyalty("kind_act", { "cruel" }, "family", 20) },
			{ citizen = 9, relation = "kingdom", loyalty = q.decisionLoyalty("kind_act", { "lazy" }, "kingdom") },
		})
		local second = q.fireDecision("kind_act", ruler, kingdom, 10, listeners :: any)
		assert(second, "kind_act exists")
		expect(second.kingdom_multiplier).toBe(0.5)
		expect(second.listeners[1].loyalty).toBe(6) -- 12 x 0.5: the gain decays
		for i, l in second.listeners do
			local spec = listeners[i]
			local want = q.decisionLoyalty("kind_act", spec.traits, spec.relation :: any, spec.chemistry, 0.5)
			expect(l.loyalty).toBe(want)
		end
		-- without listeners the list is empty, never nil
		expect(q.fireDecision("private_act", {}, {}, 0).listeners).toEqual({})
	end)

	it("records nothing when a listener is invalid, and needs histories and traits", function()
		local q = newQuery()
		local ruler, kingdom = {}, {}
		expect(function()
			q.fireDecision("kind_act", ruler, kingdom, 0, { { citizen = 1, relation = "speaker", traits = { "x" } } })
		end).toThrow("unknown trait 'x'")
		expect(ruler).toEqual({})
		expect(kingdom).toEqual({})
		expect(function()
			q.fireDecision("kind_act", ruler, kingdom, 0, { { citizen = 1, relation = "speaker" } } :: any)
		end).toThrow("listener #1 must be a table with a traits list")
		expect(function()
			q.fireDecision("kind_act", nil :: any, kingdom, 0)
		end).toThrow("rulerHistory must be a FarmHistory table")
		expect(function()
			q.fireDecision("kind_act", ruler, nil :: any, 0)
		end).toThrow("kingdomHistory must be a FarmHistory table")
	end)

	it("checks every listener's traits and relation first, like fireAction, and records nothing", function()
		-- verification finding: an audience "none" decision returned 0 for relation kingdom before it looked at
		-- the traits, so an unknown trait was accepted and the firing recorded
		local q = newQuery()
		local ruler, kingdom = {}, {}
		expect(function()
			q.fireDecision("private_act", ruler, kingdom, 0, {
				{ citizen = 1, relation = "speaker", traits = { "kind" } },
				{ citizen = 2, relation = "kingdom", traits = { "dragonborn" } },
			})
		end).toThrow("ContentQuery.fireDecision: listener #2 has an unknown trait 'dragonborn'")
		expect(function()
			q.fireDecision("kind_act", ruler, kingdom, 0, {
				{ citizen = 1, relation = "speaker", traits = { "kind" } },
				{ citizen = 2, relation = "friends", traits = { "dragonborn" } },
			})
		end).toThrow("ContentQuery.fireDecision: listener #2 has an unknown trait 'dragonborn'")
		local cousin: any = { { citizen = 1, relation = "cousin", traits = { "kind" } } }
		expect(function()
			q.fireDecision("kind_act", ruler, kingdom, 0, cousin)
		end).toThrow("ContentQuery.fireDecision: listener #1 has an unknown relation 'cousin'")
		expect(function()
			q.fireDecision("kind_act", ruler, kingdom, 0, { { citizen = 1, traits = {} } } :: any)
		end).toThrow("listener #1 has an unknown relation 'nil'")
		expect(ruler).toEqual({})
		expect(kingdom).toEqual({})
		-- a valid kingdom listener of an audience "none" decision still gets 0
		local e = q.fireDecision("private_act", ruler, kingdom, 0, {
			{ citizen = 3, relation = "kingdom", traits = { "kind" } },
		})
		assert(e, "private_act exists")
		expect(e.listeners).toEqual({ { citizen = 3, relation = "kingdom", loyalty = 0 } })
	end)
end)

describe("ContentQuery.LOYALTY_CLAMP (FORGE-00 decision M3)", function()
	it("exports the per-decision clamp per relation as a frozen table", function()
		expect(ContentQuery.LOYALTY_CLAMP).toEqual({ speaker = 25, family = 10, friends = 10, rivals = 10, kingdom = 5 })
		expect(table.isfrozen(ContentQuery.LOYALTY_CLAMP)).toBe(true)
		expect(ContentQuery.clampLoyalty(40, "speaker")).toBe(25)
		expect(ContentQuery.clampLoyalty(-40, "rivals")).toBe(-10)
		expect(ContentQuery.clampLoyalty(3, "kingdom")).toBe(3)
		expect(ContentQuery.clampLoyalty(0 / 0, "family")).toBe(0)
		expect(function()
			ContentQuery.clampLoyalty(1, "cousin" :: any)
		end).toThrow("unknown relation 'cousin'")
	end)

	it("clamps a decision's applied change per relation, after personality, chemistry and decay", function()
		local q = newQuery()
		-- big_act for a kind listener: personality 30 x reach, plus the column
		expect(q.loyaltyDelta(DECISIONS.big_act.rep, { "kind" }, "speaker", 0, 10)).toBe(40) -- unclamped block
		expect(q.decisionLoyalty("big_act", { "kind" }, "speaker", 0)).toBe(25) -- 40
		expect(q.decisionLoyalty("big_act", { "kind" }, "speaker", 20)).toBe(25) -- 60
		expect(q.decisionLoyalty("big_act", { "kind" }, "family", 0)).toBe(10) -- 18 + 6
		expect(q.decisionLoyalty("big_act", { "kind" }, "friends", 0)).toBe(10) -- 12
		expect(q.decisionLoyalty("big_act", { "kind" }, "rivals", 0)).toBeNear(-9) -- inside the clamp
		expect(q.decisionLoyalty("big_act", { "kind", "brave" }, "rivals", 0)).toBe(-10) -- -12
		expect(q.decisionLoyalty("big_act", { "kind" }, "kingdom", 0)).toBe(5) -- 6 + 4
		-- losses are clamped too: a cruel listener, -20 + 10 = -10 at speaker reach, chemistry -20 -> -15
		expect(q.decisionLoyalty("big_act", { "cruel" }, "speaker", -20)).toBe(-15)
		expect(q.decisionLoyalty("big_act", { "cruel", "cruel", "cruel" }, "speaker", -20)).toBe(-25)
		-- the clamp comes after the decay: 40 x 0.5 = 20 stays 20 (clamping first would give 12.5)
		expect(q.decisionLoyalty("big_act", { "kind" }, "speaker", 0, 0.5)).toBe(20)
		-- the bundle's explicit columns obey the same clamp (audience 4 is inside 5)
		local e = q.decisionEffects("big_act")
		assert(e, "big_act exists")
		expect(e.speaker.loyalty).toBe(10)
		expect(e.audience_loyalty).toBe(4)
	end)
end)

describe("ContentQuery.fireAction (single anti-farming point of actions.csv, SPEC §6.9)", function()
	local function kindListener(citizen: any, speaker: boolean?)
		return { citizen = citizen, occupation = "farmer", speaker = speaker, traits = { "kind" }, chemistry = 0 }
	end

	it("decays reputation per ruler and kingdom gains per kingdom, records both, never decays losses", function()
		local q = newQuery()
		local rulers = { A = {}, B = {} }
		local kingdom = {}
		local first = q.fireAction("Festival", {}, rulers, { "A" }, kingdom, 0)
		expect(#first).toBe(1)
		local f = first[1]
		expect(f.id).toBe("festival")
		expect(f.event).toBe("Festival")
		expect(f.kingdom_multiplier).toBe(1)
		expect(f.rulers).toEqual({
			{ ruler = "A", multiplier = 1, rep = repVector({ compassion = 10, fear = -2 }) },
		})
		expect(f.rep_raw).toEqual(repVector({ compassion = 10, fear = -2 }))
		expect(f.kingdom).toEqual({ happiness = 4, stability = -1, morale = 0 })
		expect(rulers.A).toEqual({ festival = { 0 } })
		expect(rulers.B).toEqual({})
		expect(kingdom).toEqual({ festival = { 0 } })
		expect(f.rows[1]).toBe(ACTIONS[6]) -- the shared, frozen content rows
		expect(table.isfrozen(f.rows[1])).toBe(true)
		-- a co-ruler credited alone: full reputation for them, but the kingdom heard it before
		local g = q.fireAction("Festival", {}, rulers, { "B" }, kingdom, 10)[1]
		expect(g.rulers[1].ruler).toBe("B")
		expect(g.rulers[1].multiplier).toBe(1)
		expect(g.kingdom_multiplier).toBe(0.5)
		expect(g.rulers[1].rep.compassion).toBe(10)
		expect(g.kingdom).toEqual({ happiness = 2, stability = -1, morale = 0 })
		local h = q.fireAction("Festival", {}, rulers, { "A" }, kingdom, 20)[1]
		expect(h.rulers[1].multiplier).toBe(0.5)
		expect(h.kingdom_multiplier).toBe(0.25)
		expect(h.rulers[1].rep).toEqual(repVector({ compassion = 5, fear = -2 })) -- the fear loss stays whole
		expect(h.rep_raw).toEqual(repVector({ compassion = 10, fear = -2 }))
		expect(kingdom).toEqual({ festival = { 0, 10, 20 } })
		-- the raw sums of the content are untouched
		expect(q.actionFirings("Festival", {})[1].rep.compassion).toBe(10)
	end)

	it("credits every given co-ruler with reputation; kingdom and listeners apply once (ruling #3)", function()
		-- a kingdom-wide event (no attributed actor) credits every current co-ruler
		local q = newQuery()
		local rulers = { [101] = {}, [202] = {} }
		local kingdom = {}
		local listeners = { kindListener("crowd") }
		local both = q.fireAction("Festival", {}, rulers, { 101, 202 }, kingdom, 0, listeners :: any)
		expect(#both).toBe(1)
		local f = both[1]
		expect(f.rulers).toEqual({
			{ ruler = 101, multiplier = 1, rep = repVector({ compassion = 10, fear = -2 }) },
			{ ruler = 202, multiplier = 1, rep = repVector({ compassion = 10, fear = -2 }) },
		})
		-- once per firing, however many rulers are credited: not doubled
		expect(f.kingdom).toEqual({ happiness = 4, stability = -1, morale = 0 })
		expect(f.listeners).toEqual({ { citizen = "crowd", relation = "kingdom", loyalty = 5 } })
		expect(rulers[101]).toEqual({ festival = { 0 } })
		expect(rulers[202]).toEqual({ festival = { 0 } })
		expect(kingdom).toEqual({ festival = { 0 } }) -- one kingdom firing, not two
		-- per-ruler decay is independent: only 101 is credited the second time (an attributed act)
		local solo = q.fireAction("Festival", {}, rulers, { 101 }, kingdom, 10)[1]
		expect(#solo.rulers).toBe(1)
		expect(solo.rulers[1].multiplier).toBe(0.5)
		expect(rulers[202]).toEqual({ festival = { 0 } })
		local again = q.fireAction("Festival", {}, rulers, { 101, 202 }, kingdom, 20, listeners :: any)[1]
		expect(again.rulers[1]).toEqual({
			ruler = 101,
			multiplier = 0.25,
			rep = repVector({ compassion = 2.5, fear = -2 }),
		})
		expect(again.rulers[2]).toEqual({
			ruler = 202,
			multiplier = 0.5,
			rep = repVector({ compassion = 5, fear = -2 }),
		})
		expect(again.kingdom_multiplier).toBe(0.25)
		expect(again.kingdom).toEqual({ happiness = 1, stability = -1, morale = 0 })
		expect(kingdom).toEqual({ festival = { 0, 10, 20 } })
	end)

	it("applies the kingdom effects with no credited ruler, and records each history table once", function()
		local q = newQuery()
		local rulers, kingdom = { A = {} }, {}
		local f = q.fireAction("Festival", {}, rulers, {}, kingdom, 0)[1]
		expect(f.rulers).toEqual({})
		expect(f.kingdom).toEqual({ happiness = 4, stability = -1, morale = 0 })
		expect(kingdom).toEqual({ festival = { 0 } })
		expect(rulers.A).toEqual({})
		-- one table passed as a ruler's and as the kingdom's history is recorded once (as fireDecision does)
		local shared = {}
		q.fireAction("Festival", {}, { A = shared }, { "A" }, shared, 0)
		expect(shared).toEqual({ festival = { 0 } })
	end)

	it("refuses a credited ruler without a history or listed twice, and records nothing", function()
		local q = newQuery()
		local rulers, kingdom = { A = {} }, {}
		expect(function()
			q.fireAction("Festival", {}, rulers, { "A", "B" }, kingdom, 0)
		end).toThrow("ContentQuery.fireAction: credited ruler #2 'B' has no FarmHistory in rulerHistories")
		expect(function()
			q.fireAction("Festival", {}, rulers, { "A", "A" }, kingdom, 0)
		end).toThrow("ContentQuery.fireAction: credited ruler #2 'A' is listed twice")
		expect(function()
			q.fireAction("Festival", {}, nil :: any, { "A" }, kingdom, 0)
		end).toThrow("ContentQuery.fireAction: rulerHistories must be a table")
		expect(function()
			q.fireAction("Festival", {}, rulers, nil :: any, kingdom, 0)
		end).toThrow("ContentQuery.fireAction: creditedRulers must be a list of ruler keys, got nil")
		expect(rulers.A).toEqual({})
		expect(kingdom).toEqual({})
	end)

	it("gives every listener who hears a row its summed, decayed and clamped loyalty", function()
		local q = newQuery()
		local ruler, kingdom = {}, {}
		local listeners = {
			kindListener("speaker", true),
			kindListener("crowd"),
			{ citizen = "plain", occupation = "farmer", traits = { "plain" } },
		}
		local f = q.fireAction("Festival", {}, { r = ruler }, { "r" }, kingdom, 0, listeners :: any)[1]
		-- crowd: kingdom row 2*5*0.2 + 10 = 12 -> 5; speaker: 12 + (2*5 + 4... see below) clamped to 25
		-- speaker row for kind: compassion 2*5 + fear -2*-2 = 14, + 10 = 24; with the kingdom row 36 -> 25
		expect(f.listeners).toEqual({
			{ citizen = "speaker", relation = "speaker", loyalty = 25 },
			{ citizen = "crowd", relation = "kingdom", loyalty = 5 },
			{ citizen = "plain", relation = "kingdom", loyalty = 5 }, -- the column alone: 10 -> 5
		})
		local second = q.fireAction("Festival", {}, { r = ruler }, { "r" }, kingdom, 10, listeners :: any)[1]
		-- kingdom multiplier 0.5: speaker 12 x 0.5 + 24 x 0.5 = 18; crowd 6 -> 5
		expect(second.listeners[1].loyalty).toBe(18)
		expect(second.listeners[2].loyalty).toBe(5)
		-- per row, actionLoyalty applies the same clamp
		expect(q.actionLoyalty(ACTIONS[6] :: any, { "kind" }, 0)).toBe(5)
		expect(q.actionLoyalty(ACTIONS[7] :: any, { "kind" }, 0)).toBe(24)
	end)

	it("only lists listeners in the row's audience and condition, and decays only gains", function()
		local q = newQuery()
		local ruler, kingdom = {}, {}
		local hungry = { ["citizen.hunger"] = 0.5 }
		local listeners = {
			{ citizen = 1, occupation = "farmer", traits = { "kind" }, chemistry = 0, ctx = hungry },
			{ citizen = 2, occupation = "farmer", traits = { "kind" }, chemistry = 0, ctx = {} },
			{ citizen = 3, occupation = "soldier", traits = { "plain" } },
		}
		local starving = { ["kingdom.fed_ratio"] = 0.5 }
		local firings = q.fireAction(
			"BuildingCompleted:barracks",
			starving,
			{ r = ruler },
			{ "r" },
			kingdom,
			0,
			listeners :: any
		)
		expect(#firings).toBe(2)
		local barracks = firings[1]
		expect(barracks.id).toBe("fund_barracks")
		-- civilians row: kind farmer -3.4 (loss); soldiers row: +3 for the soldier
		expect(#barracks.listeners).toBe(2)
		expect(barracks.listeners[1].citizen).toBe(1)
		expect(barracks.listeners[1].loyalty).toBeNear(-3.4)
		expect(barracks.listeners[2]).toEqual({ citizen = 3, relation = "kingdom", loyalty = 3 })
		local again = q.fireAction(
			"BuildingCompleted:barracks",
			starving,
			{ r = ruler },
			{ "r" },
			kingdom,
			10,
			listeners :: any
		)
		expect(again[1].kingdom_multiplier).toBe(0.5)
		expect(again[1].listeners[1].loyalty).toBeNear(-3.4) -- a loss is never decayed
		expect(again[1].listeners[2].loyalty).toBe(1.5)
		expect(again[1].kingdom).toEqual({ happiness = -2, stability = 0, morale = 1.5 })
		-- no matching rows: nothing fires and nothing is recorded
		local before = table.clone(ruler)
		expect(q.fireAction("Nothing", {}, { r = ruler }, { "r" }, kingdom, 30, listeners :: any)).toEqual({})
		expect(ruler).toEqual(before)
	end)

	it("decays each row on its own, then sums: a loss is never decayed with a gain of the same category", function()
		-- verification finding: summing first decayed the starving row's losses together with the gains
		local q = newQuery()
		local ruler, kingdom = {}, {}
		local starving = { ["kingdom.fed_ratio"] = 0.5 }
		local hungry = {
			{ citizen = "farmer", occupation = "farmer", traits = { "plain" }, chemistry = 0 },
		}
		local rulers = { r = ruler }
		local first = q.fireAction("BuildingUpgraded:keep", starving, rulers, { "r" }, kingdom, 0, hungry :: any)[1]
		expect(first.id).toBe("keep_up")
		expect(first.rulers[1].rep.authority).toBe(1) -- 2 - 1
		expect(first.kingdom.happiness).toBe(2) -- 3 - 1
		expect(first.listeners[1].loyalty).toBe(-1) -- 1 - 2
		local second = q.fireAction("BuildingUpgraded:keep", starving, rulers, { "r" }, kingdom, 60, hungry :: any)[1]
		expect(second.rulers[1].multiplier).toBe(0.5)
		expect(second.kingdom_multiplier).toBe(0.5)
		expect(second.rulers[1].rep.authority).toBe(0) -- 2 x 0.5 - 1, not (2 - 1) x 0.5
		expect(second.kingdom.happiness).toBe(0.5) -- 3 x 0.5 - 1, not (3 - 1) x 0.5
		expect(second.listeners[1].loyalty).toBe(-1.5) -- the listener path uses the same rule
		-- the raw sums stay raw
		expect(second.rep_raw.authority).toBe(1)
		expect(second.kingdom_raw).toEqual({ happiness = 2, stability = 0, morale = 0 })
		-- a well-fed kingdom: only the gain row fires, and it decays whole
		local fed =
			q.fireAction("BuildingUpgraded:keep", { ["kingdom.fed_ratio"] = 0.9 }, rulers, { "r" }, kingdom, 120)[1]
		expect(fed.kingdom_multiplier).toBe(0.25)
		expect(fed.kingdom.happiness).toBe(0.75)
	end)

	it("errors clearly on a bad event, history, now or listener", function()
		local q = newQuery()
		expect(function()
			q.fireAction(nil :: any, {}, { r = {} }, { "r" }, {}, 0)
		end).toThrow("event must be a string")
		expect(function()
			q.fireAction("Festival", {}, { r = {} }, { "r" }, nil :: any, 0)
		end).toThrow("kingdomHistory must be a FarmHistory table")
		expect(function()
			q.fireAction("Festival", {}, { r = {} }, { "r" }, {}, nil :: any)
		end).toThrow("now must be a finite number")
		expect(function()
			q.fireAction("Festival", {}, { r = {} }, { "r" }, {}, 0, { { citizen = 1 } } :: any)
		end).toThrow("listener #1 must be a table with a traits list")
		-- an unknown trait is found before anything is recorded (two firings would otherwise record one)
		local ruler, kingdom = {}, {}
		expect(function()
			q.fireAction("BuildingCompleted:barracks", {}, { r = ruler }, { "r" }, kingdom, 0, {
				{ citizen = 1, occupation = "farmer", traits = { "kind" } },
				{ citizen = 2, occupation = "farmer", traits = { "dragonborn" } },
			})
		end).toThrow("listener #2 has an unknown trait 'dragonborn'")
		expect(ruler).toEqual({})
		expect(kingdom).toEqual({})
		expect(ContentQuery.fireAction).toBeA("function")
	end)
end)

describe("ContentQuery listeners are each citizen once (FORGE-00 ruling on the PR #67 review, item 9)", function()
	it("fireDecision refuses a citizen given under two relations, and records nothing", function()
		local q = newQuery()
		local ruler, kingdom = {}, {}
		expect(function()
			q.fireDecision("kind_act", ruler, kingdom, 0, {
				{ citizen = 7, relation = "speaker", traits = { "kind" } },
				{ citizen = 8, relation = "friends", traits = {} },
				{ citizen = 7, relation = "family", traits = { "kind" } },
			})
		end).toThrow(
			"ContentQuery.fireDecision: listener #3 repeats citizen 7 (listener #1): pass each citizen once, "
				.. "under its closest relation (speaker > family > friends > rivals > kingdom)"
		)
		expect(function()
			q.fireDecision("kind_act", ruler, kingdom, 0, { { relation = "speaker", traits = {} } } :: any)
		end).toThrow("ContentQuery.fireDecision: listener #1 has no citizen key")
		expect(ruler).toEqual({})
		expect(kingdom).toEqual({})
		-- 7 and "7" are different citizens, as in the shown-history
		local e = q.fireDecision("kind_act", ruler, kingdom, 0, {
			{ citizen = 7, relation = "speaker", traits = {} },
			{ citizen = "7", relation = "family", traits = {} },
		})
		assert(e, "kind_act exists")
		expect(#e.listeners).toBe(2)
	end)

	it("fireAction refuses a citizen given twice, and records nothing", function()
		local q = newQuery()
		local ruler, kingdom = {}, {}
		expect(function()
			q.fireAction("Festival", {}, { r = ruler }, { "r" }, kingdom, 0, {
				{ citizen = "agnes", occupation = "farmer", speaker = true, traits = {} },
				{ citizen = "agnes", occupation = "farmer", traits = {} },
			})
		end).toThrow(
			"ContentQuery.fireAction: listener #2 repeats citizen agnes (listener #1): pass each citizen once"
		)
		expect(ruler).toEqual({})
		expect(kingdom).toEqual({})
	end)
end)

describe("ContentQuery citizen keys and argument checks (review findings M2, L9)", function()
	local farmerCtx = { occupation = "farmer", phase = "Founding", ["citizen.has_family"] = true }

	it("keys the shown-history by id, else entityId, else key", function()
		local q = newQuery()
		local history = { [42] = { c_farmer_once = 0 }, ["k-9"] = { c_farmer_once = 0 } }
		local function offered(citizen: any): boolean
			return table.find(ids(q.eligibleScenarios(farmerCtx, citizen, 10, history)), "c_farmer_once") ~= nil
		end
		expect(offered({ entityId = 42, occupation = "farmer" })).toBe(false) -- CitizenView
		expect(offered({ key = "k-9", occupation = "farmer" })).toBe(false) -- Population.Citizen
		expect(offered({ entityId = 43, occupation = "farmer" })).toBe(true)
		expect(offered({ id = 1, entityId = 42, occupation = "farmer" })).toBe(true) -- id wins
		expect(ContentQuery.citizenKey({ id = 1, entityId = 2, key = 3 })).toBe(1)
		expect(ContentQuery.citizenKey({ entityId = 2, key = 3 })).toBe(2)
		expect(ContentQuery.citizenKey({ key = 3 })).toBe(3)
		expect(ContentQuery.citizenKey({})).toBeNil()
	end)

	it("refuses a history for a citizen without any key instead of ignoring the cooldowns", function()
		local q = newQuery()
		expect(function()
			q.eligibleScenarios(farmerCtx, { occupation = "farmer" }, 0, { [7] = {} })
		end).toThrow("the citizen has no id, entityId or key")
		-- without a history there is nothing to look up
		expect(#q.eligibleScenarios(farmerCtx, { occupation = "farmer" }, 0, nil)).toBeGreaterThan(0)
	end)

	it("errors clearly on a nil citizen and on a nil, NaN or infinite now", function()
		local q = newQuery()
		expect(function()
			q.eligibleScenarios(farmerCtx, nil :: any, 0, {})
		end).toThrow("citizen must be a CitizenState table, got nil")
		local bads: { any } = { 0 / 0, math.huge, -math.huge, "10" }
		for i = 0, #bads do
			local bad = bads[i] -- index 0 is nil
			local label = tostring(bad)
			local ok, err = pcall(q.eligibleScenarios, farmerCtx, { id = 1, occupation = "farmer" }, bad, {})
			if ok or not string.find(tostring(err), "now must be a finite number", 1, true) then
				error(`eligibleScenarios with now = {label} should error, got {tostring(err)}`)
			end
			for name, call in
				{
					fireDecision = function()
						q.fireDecision("kind_act", {}, {}, bad)
					end,
					markShown = function()
						q.markShown({}, 1, "c_farmer_once", bad)
					end,
					repeatMultiplier = function()
						ContentQuery.repeatMultiplier({}, "k", bad, 0.5, 600)
					end,
					recordFire = function()
						ContentQuery.recordFire({}, "k", bad)
					end,
				}
			do
				local okCall, errCall = pcall(call)
				if okCall or not string.find(tostring(errCall), "now must be a finite number", 1, true) then
					error(`{name} with now = {label} should error, got {tostring(errCall)}`)
				end
			end
		end
		expect(function()
			q.markShown({}, nil, "c_farmer_once", 0)
		end).toThrow("citizenId is nil")
		-- a missing history is an error where one is required (SPEC §7) ...
		expect(function()
			q.markShown(nil :: any, 1, "c_farmer_once", 0)
		end).toThrow("ContentQuery.markShown: history must be a ShownHistory table, got nil")
		expect(function()
			ContentQuery.recordFire(nil :: any, "k", 0)
		end).toThrow("ContentQuery.recordFire: history must be a FarmHistory table, got nil")
		-- ... and optional only in the repeatMultiplier building block, where nil means no earlier firings
		expect(ContentQuery.repeatMultiplier(nil, "k", 0, 0.5, 600)).toBe(1)
	end)
end)

describe("ContentQuery content is read-only (review finding L6)", function()
	it("freezes the data it is given, deeply, and returns only frozen shared records", function()
		local q = newQuery()
		expect(table.isfrozen(q.data)).toBe(true)
		expect(table.isfrozen(SCENARIOS)).toBe(true)
		expect(table.isfrozen(SCENARIOS.a_farmer_high.trigger[1])).toBe(true)
		expect(table.isfrozen(DECISIONS.kind_act.cost)).toBe(true)
		expect(table.isfrozen(ACTIONS[2].audience_condition[1])).toBe(true)
		local got = q.eligibleScenarios({ occupation = "farmer", phase = "Founding" }, { id = 1 }, 0, {})
		expect(#got).toBeGreaterThan(0)
		for _, record in got do
			expect(table.isfrozen(record)).toBe(true)
			expect(table.isfrozen(record.responses[1])).toBe(true)
		end
		expect(function()
			(got[1] :: any).priority = 1
		end).toThrow("readonly")
		-- a second query over the same (already frozen) tables works
		expect(ContentQuery.new(FIXTURE :: any).data.decisions).toBe(DECISIONS)
		-- what the caller owns stays writable
		local e = q.decisionEffects("kind_act")
		assert(e, "kind_act exists")
		expect(table.isfrozen(e.cost)).toBe(false)
		expect(table.isfrozen(e.consequences[1])).toBe(false)
	end)

	it("also freezes the records inside a container that was frozen only at the top, and survives cycles", function()
		-- verification finding: deepFreeze skipped frozen children, so table.freeze({ ... }) input stayed mutable
		local record = scenario("s", "any", 50)
		local reputation = table.freeze({
			categories = {},
			order = CATEGORIES,
			actions = { actionRow("visit", "RulerVisited", { audience = "speaker" }) },
			byEvent = { RulerVisited = { 1 } },
		})
		local q = ContentQuery.new({
			dialogue = table.freeze({ scenarios = { s = record }, order = { "s" } }),
			reputation = reputation,
		} :: any)
		local got = q.eligibleScenarios({}, { id = 1 }, 0, {})
		expect(#got).toBe(1)
		expect(table.isfrozen(got[1])).toBe(true)
		expect(table.isfrozen(got[1].responses[1])).toBe(true)
		expect(function()
			(got[1] :: any).priority = 999
		end).toThrow("readonly")
		expect(q.data.dialogue.scenarios.s.priority).toBe(50)
		local row = q.actionFirings("RulerVisited", {})[1].rows[1]
		expect(table.isfrozen(row)).toBe(true)
		expect(table.isfrozen(row.rep)).toBe(true)
		-- a cycle in the input is frozen once, without a stack overflow
		local a: { [string]: any } = { name = "a" }
		local b: { [string]: any } = { name = "b", back = a }
		a.next = b
		local cyclic = ContentQuery.new({ traits = { a = a } } :: any)
		expect(table.isfrozen(cyclic.data.traits.a)).toBe(true)
		expect(table.isfrozen(b)).toBe(true)
	end)

	it("lets the mechanics placeholders win over a name of the same key (review finding L8)", function()
		local risk = consequence("risk", "productivity", "speaker", 0.5, {
			magnitude = -0.15,
			duration_s = 45,
			notice = "Risk ({chance}): {name} for {duration}.",
		}) :: any
		local filled = ContentQuery.consequenceNotice(risk, { name = "Agnes", chance = "1%", duration = "a blink" })
		expect(filled).toBe("Risk (50%): Agnes for 45 s.")
	end)
end)

-- ---------------------------------------------------------------- presentation (SPEC §5.10)

-- The generated Dialogue.luau of the pytest fixture library with every presentation column in use (written by
-- tools/tests/test_content.py, which fails when it is stale): the runtime runs on the generator's real output.
local PresentationDialogue = require("./PresentationDialogue")

local function presentationQuery()
	return ContentQuery.new({ dialogue = PresentationDialogue :: any })
end

-- A deep copy of dialogue data without any presentation field (what the game sees when it ignores the tags).
local PRESENTATION_FIELDS = {
	urgency = true,
	delivery_mode = true,
	thought_bubble_s = true,
	question_emotion = true,
	question_expression = true,
	question_gesture = true,
	question_delivery = true,
	variants = true,
	emotion = true,
	expression = true,
	gesture = true,
	delivery = true,
	bubble_s = true,
	bands = true,
}
local function withoutPresentation(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		if not PRESENTATION_FIELDS[k] then
			out[k] = withoutPresentation(v)
		end
	end
	return out
end

describe("ContentQuery presentation constants (SPEC §5.10)", function()
	it("maps the cue gestures to the feedback cue vocabulary and nothing else", function()
		expect(ContentQuery.GESTURE_CUE).toEqual({
			bow = "bow",
			salute = "salute",
			step_back = "cower",
			fist_pump = "celebrate",
			cross_arms = "grumble",
		})
		expect(ContentQuery.GESTURE_CUE.nod).toBeNil()
		expect(ContentQuery.GESTURE_CUE.none).toBeNil()
		expect(table.isfrozen(ContentQuery.GESTURE_CUE)).toBe(true)
	end)

	it("sets the PROVISIONAL loyalty bands at 70 and 30", function()
		expect(ContentQuery.LOYALTY_BANDS).toEqual({ high = 70, low = 30 })
		expect(table.isfrozen(ContentQuery.LOYALTY_BANDS)).toBe(true)
	end)
end)

describe("ContentQuery.reactionFor (SPEC §5.10)", function()
	it("shows the high-loyalty reaction at loyalty >= 70, with its own tone and tags", function()
		local q = presentationQuery()
		local high = {
			text = "You never fail us, {ruler}!",
			tone = "happy",
			emotion = "joy",
			gesture = "fist_pump",
			band = "high",
		}
		expect(q.reactionFor("r_hf_share", 80)).toEqual(high)
		expect(q.reactionFor("r_hf_share", 70)).toEqual(high) -- inclusive
		expect(q.reactionFor("r_hf_share", 100)).toEqual(high)
		local reaction = q.reactionFor("r_hf_share", 80) :: any
		expect(ContentQuery.GESTURE_CUE[reaction.gesture]).toBe("celebrate")
	end)

	it("shows the low-loyalty reaction at loyalty <= 30", function()
		local q = presentationQuery()
		local low = {
			text = "Bread at last. Do not expect thanks.",
			tone = "angry",
			emotion = "contempt",
			expression = "eye_roll",
			bubble_s = 5,
			band = "low",
		}
		expect(q.reactionFor("r_hf_share", 30)).toEqual(low) -- inclusive
		expect(q.reactionFor("r_hf_share", 0)).toEqual(low)
		expect(q.reactionFor("r_hf_share", -5)).toEqual(low)
	end)

	it("shows the base reaction with its tags between the bands", function()
		local q = presentationQuery()
		local base = {
			text = "Bless you, {ruler}! We will not forget this.",
			tone = "happy",
			emotion = "gratitude",
			expression = "beam",
			gesture = "bow",
			delivery = "warm",
			bubble_s = 3.5,
			band = "base",
		}
		expect(q.reactionFor("r_hf_share", 69.9)).toEqual(base)
		expect(q.reactionFor("r_hf_share", 30.1)).toEqual(base)
		expect(q.reactionFor("r_hf_share", 50)).toEqual(base)
		expect(ContentQuery.GESTURE_CUE[base.gesture]).toBe("bow")
	end)

	it("treats a missing or non-finite loyalty as the base reaction", function()
		local q = presentationQuery()
		for _, loyalty in { 0 / 0, math.huge, -math.huge } :: { any } do -- the nil case is the call below (a nil in a table literal is skipped)
			expect((q.reactionFor("r_hf_share", loyalty) :: any).band).toBe("base")
		end
		expect((q.reactionFor("r_hf_share") :: any).band).toBe("base")
		expect((q.reactionFor("r_hf_share", "80" :: any) :: any).band).toBe("base") -- never coerces a string
	end)

	it("falls back to the base reaction when the matching band has no text", function()
		local q = presentationQuery()
		-- r_hf_ration has only a low band; r_hf_gift and r_sp_pay none (tone defaults to neutral, no tags)
		expect(q.reactionFor("r_hf_ration", 95)).toEqual({
			text = "She nods slowly. Her eyes say otherwise.",
			tone = "neutral",
			band = "base",
		})
		expect(q.reactionFor("r_hf_ration", 10)).toEqual({
			text = "Rations again. Of course.",
			tone = "sad",
			emotion = "sadness",
			band = "low",
		})
		expect(q.reactionFor("r_hf_gift", 0)).toEqual({
			text = '"Seed grain? Then we eat next season," she laughs.',
			tone = "neutral",
			band = "base",
		})
		expect(q.reactionFor("r_sp_pay", 100)).toEqual({
			text = "The yard erupts in cheers.",
			tone = "neutral",
			band = "base",
		})
	end)

	it("returns nil for an unknown response and a fresh table otherwise", function()
		local q = presentationQuery()
		expect(q.reactionFor("no_such_response", 50)).toBeNil()
		local first = q.reactionFor("r_hf_share", 80) :: any
		first.text = "changed by the caller"
		expect((q.reactionFor("r_hf_share", 80) :: any).text).toBe("You never fail us, {ruler}!")
		expect(table.isfrozen(q.data.dialogue.scenarios.s_hungry_farmer.responses[1].bands.high)).toBe(true)
	end)

	it("tolerates a scenario without a tone, tags or bands (hand-made data)", function()
		local q = ContentQuery.new({ dialogue = { scenarios = SCENARIOS, order = ORDER } })
		expect(q.reactionFor("z_farmer_low_yes", 90)).toEqual({ text = "Thanks.", tone = "neutral", band = "base" })
	end)
end)

describe("ContentQuery.questionFor (SPEC §5.10)", function()
	local LOYAL = { ["citizen.loyalty"] = 80 }

	it("asks the first variant by order whose selector matches", function()
		local q = presentationQuery()
		-- v_hf_greedy (order 1) wins over v_hf_loyal (order 2), although the CSV lists v_hf_loyal first
		expect(q.questionFor("s_hungry_farmer", { traits = { "greedy", "kind" } }, LOYAL)).toEqual({
			text = "Bare shelves, {ruler}. Share your stores and I'll remember it... at a fair price.",
			emotion = "suspicion",
			expression = "smirk",
			gesture = "lean_in",
			delivery = "sarcastic",
			variantId = "v_hf_greedy",
		})
		expect(q.questionFor("s_hungry_farmer", { traits = { "kind" } }, LOYAL)).toEqual({
			text = "{ruler}, you have never let us starve. Will the granary feed us again?",
			emotion = "hope",
			expression = "smile",
			gesture = "hand_on_heart",
			delivery = "warm",
			variantId = "v_hf_loyal",
		})
		expect((q.questionFor("s_soldier_pay", { traits = { "brave" } }, {}) :: any).variantId).toBe("v_sp_brave")
	end)

	it("asks the scenario's question with its question tags when no variant matches", function()
		local q = presentationQuery()
		local base = {
			text = "{ruler}, the granary is low and my family is hungry. Will you share the stores, or must we tighten our belts?",
			emotion = "worry",
			expression = "downcast",
			gesture = "wring_hands",
			delivery = "pleading",
		}
		expect(q.questionFor("s_hungry_farmer", { traits = { "kind" } }, { ["citizen.loyalty"] = 69 })).toEqual(base)
		expect(q.questionFor("s_hungry_farmer", {}, nil)).toEqual(base) -- no traits, no ctx
		expect(q.questionFor("s_hungry_farmer", { traits = "greedy" :: any }, {})).toEqual(base) -- not a list
		expect(q.questionFor("s_smith_tools", { traits = { "brave" } }, {})).toEqual({
			text = "My hammer is cracked, {ruler}. Good iron costs gold, but bad tools cost more.",
		})
	end)

	it("evaluates a cond: selector with the trigger rules (absent flags are false, counts are 0)", function()
		local s = scenario("s", "any", 50, {
			variants = {
				-- deliberately out of order: questionFor sorts by order
				{
					id = "v_count",
					order = 3,
					cond = { clause("kingdom.count.blacksmith", "<", 1) },
					text = "No smithy.",
				},
				{ id = "v_none", order = 1, text = "Never chosen: no selector." },
				{
					id = "v_flag",
					order = 2,
					cond = { clause("citizen.memory.promised", "=", false) },
					text = "No promise.",
				},
			},
		})
		local q = ContentQuery.new({ dialogue = { scenarios = { s = s }, order = { "s" } } })
		expect((q.questionFor("s", {}, {}) :: any).variantId).toBe("v_flag")
		expect((q.questionFor("s", {}, { ["citizen.memory.promised"] = true }) :: any).variantId).toBe("v_count")
		local base = q.questionFor("s", {}, { ["citizen.memory.promised"] = true, ["kingdom.count.blacksmith"] = 2 })
		expect(base).toEqual({ text = "s question" })
	end)

	it("returns nil for an unknown scenario and errors without a citizen table", function()
		local q = presentationQuery()
		expect(q.questionFor("no_such_scenario", {}, {})).toBeNil()
		expect(function()
			q.questionFor("s_hungry_farmer", nil :: any, {})
		end).toThrow("ContentQuery.questionFor: citizen must be a CitizenState table, got nil")
		local first = q.questionFor("s_hungry_farmer", { traits = { "greedy" } }, {}) :: any
		first.text = "changed by the caller"
		expect((q.questionFor("s_hungry_farmer", { traits = { "greedy" } }, {}) :: any).text).never.toBe(
			"changed by the caller"
		)
	end)
end)

describe("ContentQuery.presentation (SPEC §5.10)", function()
	it("gives a scenario's urgency, delivery mode and thought bubble time, nil fields when absent", function()
		local q = presentationQuery()
		expect(q.presentation("s_hungry_farmer")).toEqual({
			urgency = "high",
			delivery_mode = "direct",
			thought_bubble_s = 4.5,
		})
		expect(q.presentation("s_smith_tools")).toEqual({ urgency = "low", delivery_mode = "ambient" })
		expect(q.presentation("s_soldier_pay")).toEqual({})
		expect(q.presentation("no_such_scenario")).toBeNil()
	end)

	it("is bound to the generated content at module level", function()
		expect(ContentQuery.reactionFor).toBeA("function")
		expect(ContentQuery.questionFor).toBeA("function")
		expect(ContentQuery.presentation).toBeA("function")
		expect(ContentQuery.reactionFor("no_such_response", 50)).toBeNil()
	end)
end)

describe("ContentQuery presentation never changes gameplay (SPEC §5.10)", function()
	it("offers the same scenarios in the same order with or without the tags and variants", function()
		local tagged = presentationQuery()
		local plain = ContentQuery.new({ dialogue = withoutPresentation(PresentationDialogue) })
		expect(plain.data.dialogue.scenarios.s_hungry_farmer.variants).toBeNil()
		local ctxs = {
			{ ["kingdom.fed_ratio"] = 0.4, ["citizen.hunger"] = 0.9, occupation = "farmer" },
			{ ["kingdom.count.storehouse"] = 1, phase = "Founding", ["citizen.memory.promised_tools"] = true },
			{ ["rep.authority"] = 40, ["kingdom.gold"] = 50, ["citizen.trait.greedy"] = true, occupation = "soldier" },
		}
		for _, ctx in ctxs do
			for _, citizen in
				{
					{ id = 1, occupation = ctx.occupation },
					{ id = 2, occupation = "smith", unlocked = { s_smith_tools = true } },
				}
			do
				local a = ids(tagged.eligibleScenarios(ctx, citizen, 0, {}))
				local b = ids(plain.eligibleScenarios(ctx, citizen, 0, {}))
				expect(a).toEqual(b)
			end
		end
		-- the base question and reaction are the same text the game shows without tags
		local s = PresentationDialogue.scenarios.s_hungry_farmer
		expect((tagged.questionFor("s_hungry_farmer", {}, {}) :: any).text).toBe(s.question)
		expect((tagged.reactionFor("r_hf_share", 50) :: any).text).toBe(s.responses[1].reaction)
	end)
end)

describe("ContentQuery purity", function()
	it("uses no services, yields, clocks or randomness", function()
		local source = fs.readFile(T.root .. "/games/game-001/src/shared/Content/ContentQuery.luau")
		local code = string.gsub(source, "%-%-%[%[.-%]%]", "") -- drop the header comment
		local bannedWords = { "game:", "GetService", "workspace", "task.", "wait(", "os.time", "os.clock" }
		for _, word in { "tick(", "math.random", "Random.new", "DateTime" } do
			table.insert(bannedWords, word)
		end
		for _, banned in bannedWords do
			if string.find(code, banned, 1, true) then
				error(`ContentQuery.luau must stay pure, found '{banned}'`)
			end
		end
		expect(string.sub(source, 1, 9)).toBe("--!strict")
	end)
end)
