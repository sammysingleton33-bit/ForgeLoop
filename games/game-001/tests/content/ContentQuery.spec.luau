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
		notice = "Risk: {name} may walk out.",
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
		expect(q.choicePreview("a", "b")).toBeNil()
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
		-- loyalty columns stay raw: decisionLoyalty applies the multiplier per listener
		expect(e.speaker.loyalty).toBe(6)
		expect(e.audience_loyalty).toBe(2)
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
		expect(e.speaker).toEqual({ loyalty = 2, chemistry = 1 })
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

describe("ContentQuery.choicePreview (model decision 7)", function()
	it("returns the cost and the visible risks of one answer", function()
		local q = newQuery()
		local p = q.choicePreview("a_farmer_high", "a_farmer_high_yes")
		assert(p, "the answer exists")
		expect(p.decision).toBe("kind_act")
		expect(p.cost).toEqual({ food = 25 })
		expect(ids(p.risks)).toEqual({ "walkout_risk" })
		local harsh = q.choicePreview("a_farmer_high", "a_farmer_high_no")
		assert(harsh, "the answer exists")
		expect(harsh.cost).toEqual({})
		expect(harsh.risks).toEqual({})
		expect(q.choicePreview("a_farmer_high", "nope")).toBeNil()
		expect(q.choicePreview("nope", "a_farmer_high_yes")).toBeNil()
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

	it("startLoyalty is 50 + chemistry/4 with chemistry clamped", function()
		expect(ContentQuery.startLoyalty(0)).toBe(50)
		expect(ContentQuery.startLoyalty(nil)).toBe(50)
		expect(ContentQuery.startLoyalty(20)).toBe(55)
		expect(ContentQuery.startLoyalty(-20)).toBe(45)
		expect(ContentQuery.startLoyalty(-12)).toBe(47)
		expect(ContentQuery.startLoyalty(99)).toBe(55)
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
