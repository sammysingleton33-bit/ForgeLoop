-- Kingdom/Reputation (FL-0080): the pure reputation core and the kingdom conditions (CONTRACTS G13.4).
--
-- The content library (FORGE-00) is not on this branch, so the specs build a FIXTURE in exactly the generated
-- Content/Reputation shape (content/SPEC.md §7) and a small, faithful fixture of the three ContentQuery functions
-- Reputation needs (SPEC §4 condition rules, model decision 5). One test runs the same flow over the real
-- Content/Reputation and Content/ContentQuery once they exist in the tree.
local fs = require("@lune/fs")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Reputation = require("@game/ReplicatedStorage/Game/Kingdom/Reputation")
local Society = require("@game/ReplicatedStorage/Forge/Config/Society")

-- ---------------------------------------------------------------- fixture content (generated shape)

local function rep(values: { [string]: number }?): { [string]: number }
	local v = values or {}
	return {
		compassion = v.compassion or 0,
		honor = v.honor or 0,
		competence = v.competence or 0,
		courage = v.courage or 0,
		authority = v.authority or 0,
		fear = v.fear or 0,
	}
end

local function kingdom(happiness: number, stability: number, morale: number)
	return { happiness = happiness, stability = stability, morale = morale }
end

local function category(id: string, name: string, start: number)
	return { id = id, name = name, description = `{name} (fixture)`, affects = `What moves {name}.`, start = start }
end

local CONTENT = {
	categories = {
		compassion = category("compassion", "Compassion", 50),
		honor = category("honor", "Honor", 50),
		competence = category("competence", "Competence", 50),
		courage = category("courage", "Courage", 50),
		authority = category("authority", "Authority", 50),
		fear = category("fear", "Fear", 20),
	},
	order = { "compassion", "honor", "competence", "courage", "authority", "fear" },
	actions = {
		{ -- 1: construction counts only when its need holds (SPEC §5.9, model decision 5)
			id = "house_built",
			event = "BuildingCompleted:house",
			condition = { { var = "kingdom.housing_ratio", op = ">", value = 0.9 } },
			farm_key = "build_house",
			repeat_decay = 0.5,
			repeat_window_s = 600,
			rep = rep({ compassion = 1, competence = 1 }),
			audience = "civilians",
			audience_condition = {},
			audience_loyalty = 1,
			kingdom = kingdom(1, 1, 0),
			notice = "Crowded families welcome the new house.",
		},
		{ -- 2, 3: two rows of one action share one firing
			id = "farm_built",
			event = "BuildingCompleted:farm",
			condition = { { var = "kingdom.fed_ratio", op = "<", value = 0.9 } },
			farm_key = "build_farm",
			repeat_decay = 0.5,
			repeat_window_s = 600,
			rep = rep({ competence = 2 }),
			audience = "civilians",
			audience_condition = {},
			audience_loyalty = 1,
			kingdom = kingdom(1, 1, 0),
			notice = "A new farm while bellies rumble.",
		},
		{
			id = "farm_built",
			event = "BuildingCompleted:farm",
			condition = { { var = "kingdom.fed_ratio", op = "<", value = 0.9 } },
			farm_key = "build_farm",
			repeat_decay = 0.5,
			repeat_window_s = 600,
			rep = rep(),
			audience = "occupation:farmer",
			audience_condition = {},
			audience_loyalty = 1,
			kingdom = kingdom(0, 0, 0),
		},
		{ -- 4, 5: direct vs indirect (SPEC §5.9 example)
			id = "fund_barracks",
			event = "BuildingCompleted:barracks",
			condition = { { var = "kingdom.count.barracks", op = "<=", value = 2 } },
			farm_key = "build_barracks",
			repeat_decay = 0.3,
			repeat_window_s = 900,
			rep = rep({ courage = 1, authority = 1 }),
			audience = "soldiers",
			audience_condition = {},
			audience_loyalty = 3,
			kingdom = kingdom(0, 0, 3),
			notice = "Soldiers cheer their new barracks.",
		},
		{
			id = "fund_barracks",
			event = "BuildingCompleted:barracks",
			condition = { { var = "kingdom.fed_ratio", op = "<", value = 0.6 } },
			farm_key = "build_barracks",
			repeat_decay = 0.3,
			repeat_window_s = 900,
			rep = rep({ compassion = -1 }),
			audience = "civilians",
			audience_condition = { { var = "citizen.hunger", op = ">=", value = 0.4 } },
			audience_loyalty = -2,
			kingdom = kingdom(-2, 0, 0),
			notice = "Hungry citizens grumble: barracks before bread?",
		},
		{ -- 6: defeating an enemy: no compassion change (G9 KingdomEliminated)
			id = "enemy_defeated",
			event = "KingdomEliminated",
			condition = {},
			farm_key = "defeat",
			repeat_decay = 0.7,
			repeat_window_s = 600,
			rep = rep({ courage = 2, authority = 1 }),
			audience = "soldiers",
			audience_condition = {},
			audience_loyalty = 2,
			kingdom = kingdom(1, 0, 4),
			notice = "The enemy crown has fallen.",
		},
		{ -- 7: a fight row MIS-AUTHORED with losses; the fight rule must block them
			id = "enemy_attacked",
			event = "EnemyAttacked",
			condition = {},
			farm_key = "attack",
			repeat_decay = 0.6,
			repeat_window_s = 300,
			rep = rep({ compassion = -2, honor = -1, courage = 2 }),
			audience = "soldiers",
			audience_condition = {},
			audience_loyalty = 2,
			kingdom = kingdom(0, 0, 3),
			notice = "Your banners advance on the enemy.",
		},
		{ -- 8: an atrocity is not a fight event: Honor and Fear still move
			id = "enemy_farms_burned",
			event = "EnemyFarmsBurned",
			condition = {},
			farm_key = "burn_farms",
			repeat_decay = 0.5,
			repeat_window_s = 600,
			rep = rep({ honor = -2, courage = 1, fear = 3 }),
			audience = "kingdom",
			audience_condition = {},
			audience_loyalty = 0,
			kingdom = kingdom(0, 0, 1),
			notice = "Smoke rises over enemy fields.",
		},
		{ -- 9: a peace row MIS-AUTHORED with gains; the peace rule must block them
			id = "peace_made",
			event = "PeaceMade",
			condition = {},
			farm_key = "peace",
			repeat_decay = 1,
			repeat_window_s = 0,
			rep = rep({ honor = 2, compassion = 1, courage = -1 }),
			audience = "kingdom",
			audience_condition = {},
			audience_loyalty = 1,
			kingdom = kingdom(1, 1, 0),
			notice = "Peace is signed.",
		},
		{ -- 10: the visited citizen only
			id = "ruler_visit",
			event = "RulerVisited",
			condition = {},
			farm_key = "ruler_visit",
			repeat_decay = 0.5,
			repeat_window_s = 300,
			rep = rep({ compassion = 1 }),
			audience = "speaker",
			audience_condition = {},
			audience_loyalty = 3,
			kingdom = kingdom(0, 0, 0),
		},
		{ -- 11: an event without an arg matches every phase
			id = "phase_well_fed",
			event = "MatchPhaseChanged",
			condition = { { var = "kingdom.fed_ratio", op = ">=", value = 0.9 } },
			farm_key = "phase_fed",
			repeat_decay = 1,
			repeat_window_s = 60,
			rep = rep({ compassion = 1, competence = 1 }),
			audience = "civilians",
			audience_condition = {},
			audience_loyalty = 1,
			kingdom = kingdom(1, 1, 0),
			notice = "A whole season with full bellies.",
		},
		{ -- 12, 13: one harsh event whose rows together would swing stability by 20
			id = "levy_seized",
			event = "LevySeized",
			condition = {},
			farm_key = "levy",
			repeat_decay = 1,
			repeat_window_s = 0,
			rep = rep({ authority = 2, fear = 2 }),
			audience = "kingdom",
			audience_condition = {},
			audience_loyalty = -3,
			kingdom = kingdom(-10, -10, 0),
			notice = "Soldiers seize the harvest levy.",
		},
		{
			id = "levy_seized",
			event = "LevySeized",
			condition = {},
			farm_key = "levy",
			repeat_decay = 1,
			repeat_window_s = 0,
			rep = rep(),
			audience = "civilians",
			audience_condition = {},
			audience_loyalty = -2,
			kingdom = kingdom(-10, -10, 0),
		},
	},
	byEvent = {
		["BuildingCompleted:barracks"] = { 4, 5 },
		["BuildingCompleted:farm"] = { 2, 3 },
		["BuildingCompleted:house"] = { 1 },
		EnemyAttacked = { 7 },
		EnemyFarmsBurned = { 8 },
		KingdomEliminated = { 6 },
		LevySeized = { 12, 13 },
		MatchPhaseChanged = { 11 },
		PeaceMade = { 9 },
		RulerVisited = { 10 },
	},
}

-- Trait weights per category (Content/Traits `weights`, model decision 3), two opposite traits.
local TRAIT_WEIGHTS = {
	brave = rep({ honor = 1, courage = 2, authority = 1, fear = -1 }),
	timid = rep({ courage = -2, fear = 1 }),
}
local KINGDOM_REACH = 0.2 -- ContentQuery.REACH.kingdom: a public act heard by the whole audience

-- ---------------------------------------------------------------- fixture query (ContentQuery semantics)

local function clauseHolds(clause, ctx): boolean
	local actual = ctx[clause.var]
	local op, value = clause.op, clause.value
	if type(value) == "boolean" then -- a flag: absent means false
		if actual == nil then
			actual = false
		end
		if op == "=" then
			return actual == value
		elseif op == "!=" then
			return actual ~= value
		end
		return false
	end
	if actual == nil then -- any other clause on an absent variable is false
		return false
	end
	if op == "=" then
		return actual == value
	elseif op == "!=" then
		return actual ~= value
	elseif op == "in" then
		return type(value) == "table" and table.find(value, actual) ~= nil
	end
	if type(actual) ~= "number" or type(value) ~= "number" then
		return false
	end
	if op == "<" then
		return actual < value
	elseif op == "<=" then
		return actual <= value
	elseif op == ">" then
		return actual > value
	elseif op == ">=" then
		return actual >= value
	end
	return false
end

local QUERY = {
	evaluate = function(clauses, ctx): boolean
		for _, clause in clauses or {} do
			if not clauseHolds(clause, ctx or {}) then
				return false
			end
		end
		return true
	end,
	-- decay ^ (earlier firings with now − t < window): the n-th firing inside the window gets decay^(n−1)
	repeatMultiplier = function(history, farmKey: string, now: number, decay: number?, window: number?): number
		local d = math.clamp(decay or 1, 0, 1)
		local w = window or 0
		if d >= 1 or w <= 0 or history == nil or history[farmKey] == nil then
			return 1
		end
		local earlier = 0
		for _, t in history[farmKey] do
			if now - t < w then
				earlier += 1
			end
		end
		return d ^ earlier
	end,
	recordFire = function(history, farmKey: string, now: number)
		history[farmKey] = history[farmKey] or {}
		table.insert(history[farmKey], now)
		return history
	end,
}

-- ---------------------------------------------------------------- helpers

-- The flat kingdom ctx of SPEC §4 (only the variables a test sets).
local function ctxOf(values: { fed: number?, housing: number?, barracks: number? }?)
	local v = values or {}
	return {
		["kingdom.fed_ratio"] = v.fed,
		["kingdom.housing_ratio"] = v.housing,
		["kingdom.count.barracks"] = v.barracks,
	}
end

local function fire(eventName: string, arg: string?, ctx, farm, now: number, config: any?)
	return Reputation.resolveEvent(
		Reputation.actionsFor(CONTENT.actions, eventName, arg),
		ctx,
		farm,
		now,
		QUERY,
		config
	)
end

-- One listener's explicit loyalty change from one event (the audience_loyalty part).
local function heard(results, listener): number
	local total = 0
	for _, r in results do
		if Reputation.audienceMatches(r, listener, QUERY) then
			total += r.audienceLoyalty
		end
	end
	return total
end

local function applyAll(ledger, results, now: number)
	for _, r in results do
		Reputation.apply(ledger, r.id, r.rep, r.notice or r.id, now)
	end
end

local SOLDIER = { occupation = "guard", job = "soldier", ctx = { ["citizen.hunger"] = 0.5 } }
local HUNGRY_FARMER = { occupation = "farmer", job = "farmer", ctx = { ["citizen.hunger"] = 0.6 } }
local FED_FARMER = { occupation = "farmer", job = "farmer", ctx = { ["citizen.hunger"] = 0.1 } }

-- ---------------------------------------------------------------- ledger

describe("Kingdom/Reputation: ledger, clamps and history", function()
	it("starts every category at its content start (fear 20), in canonical order", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		expect(ledger.values).toEqual({
			compassion = 50,
			honor = 50,
			competence = 50,
			courage = 50,
			authority = 50,
			fear = 20,
		})
		expect(ledger.order).toEqual(CONTENT.order)
		expect(ledger.history).toEqual({})
		expect(ledger.limit).toBe(Society.historyLimit)
	end)

	it("clamps every value to 0..100 and records the applied, post-clamp delta", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		local applied = Reputation.apply(ledger, "deserter_forgiven", { compassion = 60, fear = -30 }, "Mercy.", 12.5)
		expect(ledger.values.compassion).toBe(100)
		expect(ledger.values.fear).toBe(0)
		expect(applied).toEqual({ compassion = 50, fear = -20 })
		expect(ledger.history).toEqual({
			{ t = 12.5, category = "compassion", delta = 50, text = "Mercy.", source = "deserter_forgiven" },
			{ t = 12.5, category = "fear", delta = -20, text = "Mercy.", source = "deserter_forgiven" },
		})
	end)

	it("leaves no history for zero or fully clamped changes", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		Reputation.apply(ledger, "a", { compassion = 50 }, "Up.", 1)
		local applied = Reputation.apply(ledger, "b", { compassion = 5, honor = 0 }, "Nothing moves.", 2)
		expect(applied).toEqual({})
		expect(#ledger.history).toBe(1)
		expect(ledger.values.compassion).toBe(100)
	end)

	it("keeps only the newest historyLimit entries, oldest first", function()
		local config = table.clone(Society)
		config.historyLimit = 3
		local ledger = Reputation.newLedger(CONTENT.categories, config)
		for i = 1, 5 do
			Reputation.apply(ledger, `s{i}`, { honor = 1 }, `entry {i}`, i)
		end
		expect(#ledger.history).toBe(3)
		expect(ledger.history[1].text).toBe("entry 3")
		expect(ledger.history[3].text).toBe("entry 5")
		expect(ledger.values.honor).toBe(55)
	end)

	it("never errors on unknown categories or bad amounts: ignores and reports them", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		local applied, ignored =
			Reputation.apply(ledger, "x", { compassion = 1, charisma = 5, honor = 0 / 0, fear = math.huge }, "t", 3)
		expect(applied).toEqual({ compassion = 1 })
		expect(ignored).toEqual({ "charisma", "fear", "honor" })
		expect(ledger.values.honor).toBe(50)
		expect(ledger.values.fear).toBe(20)
		expect(ledger.values.charisma).toBeNil()
		expect(#ledger.history).toBe(1)
	end)

	it("view copies the values and the latest n entries", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		for i = 1, 4 do
			Reputation.apply(ledger, "s", { courage = i }, `e{i}`, i)
		end
		local view = Reputation.view(ledger, 2)
		expect(#view.history).toBe(2)
		expect(view.history[1].text).toBe("e3")
		expect(view.history[2].text).toBe("e4")
		view.values.courage = 0
		view.history[1].delta = 99
		expect(ledger.values.courage).toBe(60)
		expect(ledger.history[3].delta).toBe(3)
		expect(#Reputation.view(ledger).history).toBe(4)
	end)
end)

-- ---------------------------------------------------------------- actions and anti-farming

describe("Kingdom/Reputation: actions and anti-farming", function()
	it("finds an event's rows in file order; a row without an arg matches every arg", function()
		local barracks = Reputation.actionsFor(CONTENT.actions, "BuildingCompleted", "barracks")
		expect(#barracks).toBe(2)
		expect(barracks[1]).toBe(CONTENT.actions[4])
		expect(barracks[2]).toBe(CONTENT.actions[5])
		expect(Reputation.actionsFor(CONTENT.actions, "BuildingCompleted", "house")[1].id).toBe("house_built")
		expect(#Reputation.actionsFor(CONTENT.actions, "BuildingCompleted", "quarry")).toBe(0)
		expect(#Reputation.actionsFor(CONTENT.actions, "BuildingCompleted")).toBe(0)
		expect(Reputation.actionsFor(CONTENT.actions, "MatchPhaseChanged", "Expansion")[1].id).toBe("phase_well_fed")
		expect(Reputation.actionsFor(CONTENT.actions, "KingdomEliminated")[1].id).toBe("enemy_defeated")
	end)

	it("the n-th firing inside the window gets decay^(n-1); outside the window it is full again", function()
		local farm = {}
		local needed = ctxOf({ housing = 0.95 })
		local multipliers, compassion, loyalty = {}, {}, {}
		for _, now in { 0, 10, 20, 605, 620 } do
			local r = fire("BuildingCompleted", "house", needed, farm, now)[1]
			table.insert(multipliers, r.multiplier)
			table.insert(compassion, r.rep.compassion)
			table.insert(loyalty, r.audienceLoyalty)
		end
		-- 0, 10, 20: 1, 0.5, 0.25 (decay 0.5). 605: t = 10 and 20 are still inside 600 s → 0.25.
		-- 620: only 605 is inside → 0.5.
		expect(multipliers).toEqual({ 1, 0.5, 0.25, 0.25, 0.5 })
		expect(compassion).toEqual({ 1, 0.5, 0.25, 0.25, 0.5 })
		expect(loyalty).toEqual({ 1, 0.5, 0.25, 0.25, 0.5 })
		local quiet = {}
		local first = fire("BuildingCompleted", "house", needed, quiet, 0)[1]
		local later = fire("BuildingCompleted", "house", needed, quiet, 600)[1]
		expect(first.multiplier).toBe(1)
		expect(later.multiplier).toBe(1) -- exactly one window later: outside
	end)

	it("losses are never reduced while the gains of the same firing decay", function()
		local farm = {}
		local underfed = ctxOf({ fed = 0.5, barracks = 1 })
		local results
		for i = 1, 3 do
			results = fire("BuildingCompleted", "barracks", underfed, farm, i)
		end
		expect(results[1].multiplier).toBeNear(0.09) -- 0.3^2
		expect(results[1].rep.courage).toBeNear(0.09)
		expect(results[1].audienceLoyalty).toBeNear(0.27)
		expect(results[2].rep.compassion).toBe(-1)
		expect(results[2].audienceLoyalty).toBe(-2)
		expect(results[2].kingdom.happiness).toBe(-2)
	end)

	it("rows of one action are one firing: one multiplier, one farm record", function()
		local farm = {}
		local hungry = ctxOf({ fed = 0.5 })
		local first = fire("BuildingCompleted", "farm", hungry, farm, 0)
		expect(#first).toBe(2)
		expect(first[1].multiplier).toBe(1)
		expect(first[2].multiplier).toBe(1)
		expect(farm.build_farm).toEqual({ 0 })
		local second = fire("BuildingCompleted", "farm", hungry, farm, 5)
		expect(second[1].multiplier).toBe(0.5)
		expect(second[2].audienceLoyalty).toBe(0.5)
		expect(farm.build_farm).toEqual({ 0, 5 })
	end)
end)

describe("Kingdom/Reputation: need conditions", function()
	it("a house counts only while housing is needed: no gain and no farm record otherwise", function()
		local farm = {}
		local house = CONTENT.actions[1]
		expect(Reputation.resolveAction(house, ctxOf({ housing = 0.5 }), farm, 0, QUERY)).toBeNil()
		expect(#fire("BuildingCompleted", "house", ctxOf({ housing = 0.9 }), farm, 1)).toBe(0) -- "> 0.9"
		expect(Reputation.resolveAction(house, ctxOf(), farm, 2, QUERY)).toBeNil() -- unknown ratio: false
		expect(farm.build_house).toBeNil()
		local r = Reputation.resolveAction(house, ctxOf({ housing = 0.95 }), farm, 3, QUERY)
		expect(r).never.toBeNil()
		expect((r :: any).multiplier).toBe(1) -- the refused builds did not count toward farming
		expect((r :: any).rep.competence).toBe(1)
		expect(farm.build_house).toEqual({ 3 })
	end)

	it("applies the resolved gain to the ledger with the notice as history text", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		applyAll(ledger, fire("BuildingCompleted", "house", ctxOf({ housing = 1.2 }), {}, 40), 40)
		expect(ledger.values.compassion).toBe(51)
		expect(ledger.values.competence).toBe(51)
		expect(ledger.history[1]).toEqual({
			t = 40,
			category = "compassion",
			delta = 1,
			text = "Crowded families welcome the new house.",
			source = "house_built",
		})
	end)
end)

-- ---------------------------------------------------------------- audiences and personality

describe("Kingdom/Reputation: audience conditions", function()
	it("barracks: soldiers gain; civilians lose only while the kingdom is underfed and they are hungry", function()
		local fed = fire("BuildingCompleted", "barracks", ctxOf({ fed = 0.8, barracks = 1 }), {}, 0)
		expect(#fed).toBe(1)
		expect(heard(fed, SOLDIER)).toBe(3)
		expect(heard(fed, HUNGRY_FARMER)).toBe(0)

		local underfed = fire("BuildingCompleted", "barracks", ctxOf({ fed = 0.5, barracks = 1 }), {}, 0)
		expect(#underfed).toBe(2)
		expect(heard(underfed, SOLDIER)).toBe(3)
		expect(heard(underfed, HUNGRY_FARMER)).toBe(-2)
		expect(heard(underfed, FED_FARMER)).toBe(0) -- the audience condition filters each listener
	end)

	it("matches soldiers, civilians, occupation:<id>, kingdom and speaker", function()
		local function matches(audience: string, listener): boolean
			return Reputation.audienceMatches({ audience = audience, audience_condition = {} }, listener, QUERY)
		end
		local visited = { occupation = "farmer", job = "farmer", speaker = true }
		local soldierKind = { kind = "soldier" }
		expect(matches("soldiers", SOLDIER)).toBe(true)
		expect(matches("soldiers", soldierKind)).toBe(true)
		expect(matches("soldiers", FED_FARMER)).toBe(false)
		expect(matches("civilians", FED_FARMER)).toBe(true)
		expect(matches("civilians", SOLDIER)).toBe(false)
		expect(matches("occupation:farmer", FED_FARMER)).toBe(true)
		expect(matches("occupation:farmer", SOLDIER)).toBe(false)
		expect(matches("occupation:farm", FED_FARMER)).toBe(false)
		expect(matches("kingdom", SOLDIER)).toBe(true)
		expect(matches("kingdom", FED_FARMER)).toBe(true)
		expect(matches("speaker", visited)).toBe(true)
		expect(matches("speaker", FED_FARMER)).toBe(false)
		expect(matches("everyone", SOLDIER)).toBe(false)
		local visit = fire("RulerVisited", nil, ctxOf(), {}, 0)
		expect(heard(visit, visited)).toBe(3)
		expect(heard(visit, HUNGRY_FARMER)).toBe(0)
	end)
end)

describe("Kingdom/Reputation: personality", function()
	it("two citizens with opposite traits react differently to the same barracks", function()
		local farm = {}
		local r = fire("BuildingCompleted", "barracks", ctxOf({ fed = 0.8, barracks = 1 }), farm, 0)[1]
		-- (Σ weight × rep) × reach + audience_loyalty: courage +1, authority +1
		-- brave: (2 + 1) × 0.2 + 3 = 3.6; timid: (−2) × 0.2 + 3 = 2.6
		local brave = Reputation.listenerLoyalty(r, { "brave" }, TRAIT_WEIGHTS, KINGDOM_REACH)
		local timid = Reputation.listenerLoyalty(r, { "timid" }, TRAIT_WEIGHTS, KINGDOM_REACH)
		expect(brave).toBeNear(3.6)
		expect(timid).toBeNear(2.6)
		expect(brave).toBeGreaterThan(timid)
		expect(Reputation.listenerLoyalty(r, {}, TRAIT_WEIGHTS, KINGDOM_REACH)).toBe(3)

		local again = fire("BuildingCompleted", "barracks", ctxOf({ fed = 0.8, barracks = 1 }), farm, 1)[1]
		expect(Reputation.listenerLoyalty(again, { "brave" }, TRAIT_WEIGHTS, KINGDOM_REACH)).toBeNear(3.6 * 0.3)
		expect(Reputation.listenerLoyalty(again, { "timid" }, TRAIT_WEIGHTS, KINGDOM_REACH)).toBeNear(2.6 * 0.3)
	end)

	it("a loss stays a full loss for every personality", function()
		local farm = {}
		local underfed = ctxOf({ fed = 0.5, barracks = 1 })
		fire("BuildingCompleted", "barracks", underfed, farm, 0)
		local loss = fire("BuildingCompleted", "barracks", underfed, farm, 1)[2]
		-- compassion −1; brave has no compassion weight, so only the explicit −2 remains
		expect(Reputation.listenerLoyalty(loss, { "brave" }, TRAIT_WEIGHTS, KINGDOM_REACH)).toBe(-2)
	end)
end)

-- ---------------------------------------------------------------- user rules

describe("Kingdom/Reputation: user rules", function()
	it("defeating an enemy leaves compassion unchanged; courage and authority rise", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		applyAll(ledger, fire("KingdomEliminated", nil, ctxOf(), {}, 10), 10)
		expect(ledger.values.compassion).toBe(50)
		expect(ledger.values.honor).toBe(50)
		expect(ledger.values.courage).toBe(52)
		expect(ledger.values.authority).toBe(51)
	end)

	it("a fight row authored with a compassion or honor loss cannot lower them", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		local results = fire("EnemyAttacked", nil, ctxOf(), {}, 10)
		expect(results[1].blocked).toEqual({ "compassion", "honor" })
		expect(results[1].rep.compassion).toBe(0)
		expect(results[1].repRaw.compassion).toBe(-2)
		applyAll(ledger, results, 10)
		expect(ledger.values.compassion).toBe(50)
		expect(ledger.values.honor).toBe(50)
		expect(ledger.values.courage).toBe(52)
	end)

	it("atrocities are not fights: burning farms still costs honor and raises fear", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		local results = fire("EnemyFarmsBurned", nil, ctxOf(), {}, 10)
		expect(results[1].blocked).toEqual({})
		applyAll(ledger, results, 10)
		expect(ledger.values.honor).toBe(48)
		expect(ledger.values.fear).toBe(23)
	end)

	it("peacekeeping is not rewarded by itself", function()
		-- No event, no change: a long quiet, fed peace drifts the kingdom conditions only.
		local ledger = Reputation.newLedger(CONTENT.categories)
		local before = Reputation.view(ledger)
		local conditions = Reputation.newConditions()
		for _ = 1, 20 do
			Reputation.driftConditions(conditions, ctxOf({ fed = 1, housing = 0.8 }), 60)
		end
		expect(Reputation.view(ledger)).toEqual(before)
		-- A peace row authored with gains raises nothing; its losses still count.
		local results = fire("PeaceMade", nil, ctxOf(), {}, 30)
		expect(results[1].blocked).toEqual({ "compassion", "honor" })
		applyAll(ledger, results, 30)
		expect(ledger.values.honor).toBe(50)
		expect(ledger.values.compassion).toBe(50)
		expect(ledger.values.courage).toBe(49)
	end)

	it("one decision never swings a condition by more than maxConditionStep", function()
		local results = fire("LevySeized", nil, ctxOf(), {}, 0)
		local delta = Reputation.kingdomDelta(results)
		expect(delta).toEqual({ happiness = -20, stability = -20, morale = 0 })
		local conditions = Reputation.newConditions()
		local _, applied = Reputation.applyConditions(conditions, delta)
		local step = Society.maxConditionStep
		expect(applied).toEqual({ happiness = -step, stability = -step, morale = 0 })
		expect(conditions.stability).toBe(Society.conditionStart.stability - step)
		local _, up = Reputation.applyConditions(conditions, { happiness = 50, morale = step / 2 })
		expect(up.happiness).toBe(step)
		expect(up.morale).toBe(step / 2)
	end)
end)

-- ---------------------------------------------------------------- kingdom conditions

describe("Kingdom/Reputation: kingdom conditions", function()
	it("start from config and stay within 0..100", function()
		local conditions = Reputation.newConditions()
		expect(conditions).toEqual(Society.conditionStart)
		conditions.morale = 97
		conditions.stability = 3
		local _, applied = Reputation.applyConditions(conditions, { morale = 6, stability = -6, happiness = 0 / 0 })
		expect(conditions.morale).toBe(100)
		expect(conditions.stability).toBe(0)
		expect(conditions.happiness).toBe(Society.conditionStart.happiness)
		expect(applied).toEqual({ happiness = 0, stability = -3, morale = 3 })
	end)

	it("drift is monotonic: more food never lowers a condition, and a fed kingdom drifts up", function()
		local previous, previousTarget = nil, nil
		for _, fed in { 0, 0.25, 0.5, 0.75, 1 } do
			local ctx = ctxOf({ fed = fed, housing = 0.8 })
			local target = Reputation.conditionTargets(ctx) :: any
			local conditions = Reputation.driftConditions(Reputation.newConditions(), ctx, 120)
			if previous then
				expect(target.happiness).toBeGreaterThan(previousTarget.happiness)
				expect(target.stability).toBeGreaterThan(previousTarget.stability)
				expect(target.morale).toBeGreaterThan(previousTarget.morale)
				for _, c in Reputation.CONDITIONS do
					expect(conditions[c]).toBeGreaterThanOrEqual(previous[c])
				end
			end
			previous, previousTarget = conditions, target
		end
		local start = Society.conditionStart
		local fed = Reputation.driftConditions(Reputation.newConditions(), ctxOf({ fed = 1 }), 60)
		expect(fed.happiness).toBeGreaterThan(start.happiness)
		local starved = Reputation.driftConditions(Reputation.newConditions(), ctxOf({ fed = 0 }), 60)
		expect(starved.happiness).toBeLessThan(start.happiness)
	end)

	it("drift is capped: at most rate × dt per call and never past the target", function()
		local rate = Society.drift.rate
		local target = Reputation.conditionTargets(ctxOf({ fed = 1, housing = 0.5 })) :: any
		expect(target.happiness).toBe(Society.drift.fed.happiness)
		local conditions = Reputation.newConditions()
		local start = conditions.happiness
		Reputation.driftConditions(conditions, ctxOf({ fed = 1, housing = 0.5 }), 10)
		expect(conditions.happiness - start).toBeLessThanOrEqual(rate.happiness * 10 + 1e-9)
		expect(conditions.happiness).toBeGreaterThan(start)
		Reputation.driftConditions(conditions, ctxOf({ fed = 1, housing = 0.5 }), 1e6)
		expect(conditions.happiness).toBe(target.happiness)
		expect(conditions.stability).toBe(target.stability)
		expect(conditions.morale).toBe(target.morale)
		conditions.happiness = 100
		Reputation.driftConditions(conditions, ctxOf({ fed = 1, housing = 0.5 }), 1e6)
		expect(conditions.happiness).toBe(target.happiness) -- from above: down to the target, not below
	end)

	it("crowding lowers the targets; an unknown fed ratio or dt <= 0 changes nothing", function()
		local roomy = Reputation.conditionTargets(ctxOf({ fed = 1, housing = 0.8 })) :: any
		local crowded = Reputation.conditionTargets(ctxOf({ fed = 1, housing = 3 })) :: any
		expect(roomy.happiness - crowded.happiness).toBe(Society.drift.crowdingPenalty.happiness)
		expect(roomy.stability - crowded.stability).toBe(Society.drift.crowdingPenalty.stability)
		expect(Reputation.conditionTargets(ctxOf({ housing = 0.8 }))).toBeNil()
		local conditions = Reputation.newConditions()
		Reputation.driftConditions(conditions, ctxOf({ housing = 3 }), 600)
		Reputation.driftConditions(conditions, ctxOf({ fed = 0 }), 0)
		Reputation.driftConditions(conditions, ctxOf({ fed = 0 }), -5)
		expect(conditions).toEqual(Society.conditionStart)
	end)
end)

describe("config Society", function()
	it("holds the G13.3 / G13.4 values and a usable drift model", function()
		expect(Society.openRequests).toBe(3)
		expect(Society.requestRefreshSeconds).toBe(20)
		expect(Society.historySent).toBe(30)
		expect(Society.historyLimit).toBeGreaterThanOrEqual(Society.historySent)
		expect(Society.maxConditionStep).toBeGreaterThan(0)
		for _, c in Reputation.CONDITIONS do
			expect(Society.conditionStart[c]).toBeA("number")
			expect(Society.drift.rate[c]).toBeGreaterThan(0)
			expect(Society.drift.fed[c]).toBeGreaterThanOrEqual(Society.drift.starved[c]) -- monotonic in food
			expect(Society.drift.crowdingPenalty[c]).toBeGreaterThanOrEqual(0) -- monotonic in housing
		end
		expect(Society.drift.housingCrowded).toBeGreaterThan(Society.drift.housingComfort)
		expect(Society.rules.fightNoLoss).toContain("compassion")
		expect(Society.rules.fightEvents).toContain("KingdomEliminated")
		expect(Society.strike.sustainSeconds).toBeGreaterThan(0)
	end)
end)

-- ---------------------------------------------------------------- real content (once FORGE-00's library is merged)

local CONTENT_DIR = T.root .. "/games/game-001/src/shared/Content"
if fs.isFile(CONTENT_DIR .. "/Reputation.luau") and fs.isFile(CONTENT_DIR .. "/ContentQuery.luau") then
	describe("Kingdom/Reputation over the generated Content/Reputation and ContentQuery", function()
		it("starts at the content values and resolves barracks, houses and attacks", function()
			local Content = require("@game/ReplicatedStorage/Game/Content/Reputation") :: any
			local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery") :: any
			local ledger = Reputation.newLedger(Content.categories)
			for _, id in Content.order do
				expect(ledger.values[id]).toBe(Content.categories[id].start)
			end
			expect(ledger.values.fear).toBe(20)

			local farm = {}
			local barracks = Reputation.actionsFor(Content.actions, "BuildingCompleted", "barracks")
			local results = Reputation.resolveEvent(barracks, {
				["kingdom.fed_ratio"] = 0.5,
				["kingdom.count.barracks"] = 1,
			}, farm, 0, ContentQuery)
			expect(#results).toBe(2)
			local soldier, hungry = 0, 0
			for _, r in results do
				if Reputation.audienceMatches(r, SOLDIER, ContentQuery) then
					soldier += r.audienceLoyalty
				end
				if Reputation.audienceMatches(r, HUNGRY_FARMER, ContentQuery) then
					hungry += r.audienceLoyalty
				end
			end
			expect(soldier).toBeGreaterThan(0)
			expect(hungry).toBeLessThan(0)

			local house = Reputation.actionsFor(Content.actions, "BuildingCompleted", "house")
			expect(#Reputation.resolveEvent(house, { ["kingdom.housing_ratio"] = 0.5 }, farm, 1, ContentQuery)).toBe(0)
			expect(farm.build_house).toBeNil()

			for _, eventName in Society.rules.fightEvents do
				for _, r in
					Reputation.resolveEvent(
						Reputation.actionsFor(Content.actions, eventName),
						{},
						farm,
						2,
						ContentQuery
					)
				do
					Reputation.apply(ledger, r.id, r.rep, r.notice or r.id, 2)
				end
			end
			expect(ledger.values.compassion).toBeGreaterThanOrEqual(Content.categories.compassion.start)
			expect(ledger.values.honor).toBeGreaterThanOrEqual(Content.categories.honor.start)
		end)
	end)
end
