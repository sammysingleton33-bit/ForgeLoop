local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Construction = require("@game/ReplicatedStorage/Forge/Economy/Construction")
local Currencies = require("@game/ReplicatedStorage/Forge/Economy/Currencies")

local currencies = Currencies.default()

local function kingdom(buildings, builders)
	return { buildings = buildings, builders = builders or { busy = 0, total = 2 } }
end

local START = { townhall = { uid = "b1", buildingId = "townhall", level = 1, state = "ready" } }

local function fixture(overrides)
	-- a tiny valid config; overrides patch the farm definition
	local farm = {
		id = "farm",
		kind = "building",
		name = "Farm",
		description = "d",
		icon = "farm",
		rarity = "Common",
		building = {
			category = "economy",
			maxCount = 2,
			levels = { { cost = { wood = 40 }, buildSec = 15, workers = 3, produces = { food = 6 } } },
		},
	}
	for k, v in overrides or {} do
		farm.building[k] = v
	end
	return { farm }
end

describe("Economy/Currencies", function()
	it("loads the game config and orders match resources for display", function()
		expect(currencies:ids("match")).toEqual({ "food", "wood", "stone", "gold" })
		expect(currencies:ids("profile")).toEqual({ "crowns" })
		expect(currencies:starting("match")).toEqual({ food = 100, wood = 150, stone = 50, gold = 50 })
		expect(currencies:isPaid("crowns")).toBe(false)
	end)

	it("rejects invalid currency configs, naming each problem", function()
		local base = function()
			return {
				id = "gems",
				name = "Gems",
				scope = "profile",
				icon = "gem",
				start = 0,
				cap = 100,
				robuxPurchasable = true,
				description = "d",
			}
		end
		local bad = {
			{ field = "scope", value = "season", expect = "scope" },
			{ field = "cap", value = 0, expect = "cap" },
			{ field = "start", value = 500, expect = "start is above cap" },
			{ field = "id", value = "Gems!", expect = "id must match" },
			{ field = "colour", value = "red", expect = "unknown field 'colour'" },
		}
		for _, case in bad do
			local def = base()
			def[case.field] = case.value
			local ok, problems = Currencies.validate({ def })
			expect(ok).toBe(false)
			expect(table.concat(problems, "\n")).toContain(case.expect)
		end
		local paidMatch = base()
		paidMatch.scope = "match"
		local ok, problems = Currencies.validate({ paidMatch })
		expect(ok).toBe(false)
		expect(problems[1]).toContain("cannot be robuxPurchasable")
		local okDup, dup = Currencies.validate({ base(), base() })
		expect(okDup).toBe(false)
		expect(dup[1]).toContain("duplicate")
		expect(function()
			Currencies.new({ base(), base() })
		end).toThrow("duplicate")
	end)
end)

describe("Economy/Construction", function()
	local catalog = Construction.default()

	it("validates the shipped AI Kingdoms config", function()
		expect(#catalog:buildings()).toBeGreaterThan(5)
		expect(#catalog:buildings("economy")).toBe(4)
		expect(catalog:maxLevel("townhall")).toBe(3)
		expect(#catalog:units()).toBe(3)
	end)

	it("allows a new building when affordable, unlocked and under the limit", function()
		local check = catalog:check(kingdom({ START.townhall }), { wood = 85, food = 136 }, "quarry")
		expect(check.ok).toBe(true)
		expect(check.action).toBe("build")
		expect(check.level).toBe(1)
		expect(check.cost).toEqual({ wood = 50, food = 20 })
		expect(check.buildSec).toBe(18)
		expect(check.missing).toEqual({})
	end)

	it("reports the exact shortfall when resources are missing", function()
		local check = catalog:check(kingdom({ START.townhall }), { wood = 30, food = 136 }, "quarry")
		expect(check.ok).toBe(false)
		expect(check.reason).toBe("cost")
		expect(check.missing).toEqual({ wood = 20 })
	end)

	it("reports unmet requirements and the missing resources together", function()
		local check = catalog:check(kingdom({ START.townhall }), { wood = 10 }, "goldmine")
		expect(check.reason).toBe("requirement")
		expect(check.unmet).toEqual({ { building = "townhall", level = 2 } })
		expect(check.missing).toEqual({ wood = 50, stone = 40 })
	end)

	it("counts a building under construction against the limit but not as completed", function()
		local k = kingdom({
			START.townhall,
			{ uid = "b2", buildingId = "barracks", level = 0, state = "constructing" },
		})
		local tower = catalog:check(k, { wood = 999, stone = 999 }, "watchtower")
		expect(tower.reason).toBe("requirement")
		local again = catalog:check(k, { wood = 999, stone = 999, gold = 999 }, "barracks")
		expect(again.reason).toBe("limit")
		expect(again.count).toBe(1)
		expect(again.maxCount).toBe(1)
	end)

	it("blocks when every builder is busy", function()
		local check = catalog:check(kingdom({ START.townhall }, { busy = 2, total = 2 }), { wood = 999 }, "farm")
		expect(check.reason).toBe("builders")
	end)

	it("checks upgrades against the next level of that instance", function()
		local k = kingdom({ START.townhall })
		local up = catalog:check(k, { wood = 150, stone = 100, gold = 40 }, "townhall", "b1")
		expect(up.ok).toBe(true)
		expect(up.action).toBe("upgrade")
		expect(up.level).toBe(2)
		expect(up.cost).toEqual({ wood = 150, stone = 100, gold = 40 })
		local farmUp = catalog:check(
			kingdom({ START.townhall, { uid = "f", buildingId = "farm", level = 1, state = "ready" } }),
			{ wood = 999, stone = 999 },
			"farm",
			"f"
		)
		expect(farmUp.reason).toBe("requirement")
		local busy = catalog:check(
			kingdom({ { uid = "b1", buildingId = "townhall", level = 1, state = "upgrading" } }),
			{},
			"townhall",
			"b1"
		)
		expect(busy.reason).toBe("busy")
		local maxed = catalog:check(
			kingdom({ { uid = "b1", buildingId = "townhall", level = 3, state = "ready" } }),
			{},
			"townhall",
			"b1"
		)
		expect(maxed.reason).toBe("max_level")
		expect(catalog:check(k, {}, "farm", "nope").reason).toBe("not_found")
		expect(catalog:check(k, {}, "castle").reason).toBe("unknown_building")
	end)

	it("derives production, housing and storage from completed buildings", function()
		local k = kingdom({
			START.townhall,
			{ uid = "f1", buildingId = "farm", level = 1, state = "ready", workers = 3 },
			{ uid = "f2", buildingId = "farm", level = 1, state = "ready", workers = 9 }, -- capped at 3 slots
			{ uid = "l1", buildingId = "lumbercamp", level = 1, state = "upgrading", workers = 2 },
			{ uid = "q1", buildingId = "quarry", level = 0, state = "constructing", workers = 3 },
			{ uid = "h1", buildingId = "house", level = 1, state = "ready" },
			{ uid = "s1", buildingId = "storehouse", level = 1, state = "ready" },
		})
		expect(catalog:production(k)).toEqual({ food = 36, wood = 12 })
		expect(catalog:housing(k)).toBe(10)
		expect(catalog:storageCaps(k)).toEqual({ food = 750, wood = 750, stone = 550, gold = 550 })
	end)

	it("checks unit recruitment", function()
		local k = kingdom({ START.townhall, { uid = "x", buildingId = "barracks", level = 1, state = "ready" } })
		expect(catalog:checkUnit(k, { food = 20, gold = 5 }, "militia").ok).toBe(true)
		expect(catalog:checkUnit(k, { food = 20, gold = 5 }, "knight").reason).toBe("requirement")
		expect(catalog:checkUnit(k, { food = 1 }, "militia").missing).toEqual({ food = 19, gold = 5 })
		expect(catalog:checkUnit(k, {}, "dragon").reason).toBe("unknown_unit")
	end)

	it("rejects invalid building configs, naming each problem", function()
		local cases = {
			{ { maxCount = 0 }, "maxCount" },
			{ { category = "magic" }, "category" },
			{ { levels = {} }, "levels must be a non-empty list" },
			{ { levels = { { cost = { mana = 5 }, buildSec = 5 } } }, "unknown currency 'mana'" },
			{ { levels = { { cost = { crowns = 5 }, buildSec = 5 } } }, "unknown currency 'crowns'" },
			{ { levels = { { cost = {}, buildSec = 5 } } }, "bundle is empty" },
			{ { levels = { { cost = { wood = 5 }, buildSec = 0 } } }, "buildSec" },
			{
				{ levels = { { cost = { wood = 5 }, buildSec = 5, produces = { food = 1 } } } },
				"produces needs workers",
			},
			{
				{
					levels = {
						{ cost = { wood = 5 }, buildSec = 5, requires = { { building = "castle", level = 1 } } },
					},
				},
				"unknown building 'castle'",
			},
			{
				{ levels = { { cost = { wood = 5 }, buildSec = 5, requires = { { building = "farm", level = 3 } } } } },
				"above its max level",
			},
			{ { levels = { { cost = { wood = 5 }, buildSec = 5, speed = 2 } } }, "unknown field 'speed'" },
			{ { footprint = 4 }, "unknown field 'footprint'" },
		}
		for _, case in cases do
			local ok, problems = Construction.validate(fixture(case[1]), currencies)
			expect(ok).toBe(false)
			expect(table.concat(problems, "\n")).toContain(case[2])
		end
		expect((Construction.validate(fixture(), currencies))).toBe(true)
		expect(function()
			Construction.new(fixture({ maxCount = 0 }), currencies)
		end).toThrow("maxCount")
	end)
end)
