local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

local function errorsOf(mutate: (any) -> ()): { string }
	local catalog = Catalog.default()
	mutate(catalog)
	local ok, errors = Catalog.validate(catalog)
	expect(ok).toBe(false)
	return errors
end

local function anyContains(list: { string }, needle: string): boolean
	for _, s in list do
		if string.find(s, needle, 1, true) then
			return true
		end
	end
	return false
end

describe("Kingdom/Catalog", function()
	it("ships a default catalog that validates", function()
		local ok, errors = Catalog.validate(Catalog.default())
		expect(errors).toEqual({})
		expect(ok).toBe(true)
	end)

	it("default() returns an independent deep copy", function()
		local a = Catalog.default()
		a.buildings.house.levels[1].hp = 1
		a.tuning.startCitizens.farmer = 99
		local b = Catalog.default()
		expect(b.buildings.house.levels[1].hp).toBe(300)
		expect(b.tuning.startCitizens.farmer).toBe(3)
	end)

	it("starts every kingdom with the twelve working citizens of VS-1 row 4", function()
		local total = 0
		for _, n in Catalog.default().tuning.startCitizens do
			total += n
		end
		expect(total).toBe(12)
		expect(Catalog.default().buildings.keep.levels[1].popCap).toBe(12)
	end)

	it("uses only CONTRACTS G2 ids for buildings and jobs", function()
		local c = Catalog.default()
		for id in c.buildings do
			expect(Types.is("BUILDING_TYPES", id)).toBe(true)
		end
		for id in c.jobs do
			expect(Types.is("JOB_IDS", id)).toBe(true)
		end
		local errors = errorsOf(function(bad)
			bad.buildings.castle = table.clone(bad.buildings.house)
			bad.buildings.castle.id = "castle"
			table.insert(bad.buildingOrder, "castle")
			bad.jobs.wizard = { id = "wizard", resources = {}, affinity = {} }
			table.insert(bad.jobOrder, "wizard")
		end)
		expect(anyContains(errors, "buildings.castle: not a building type")).toBe(true)
		expect(anyContains(errors, "jobs.wizard: not a citizen job")).toBe(true)
	end)

	it("reads every cost and build time from FORGE-03's Costs.luau (CONTRACTS G13.5)", function()
		local costs = Catalog.costs(Catalog.default())
		for _, kind in Types.BUILDING_TYPES do
			for level = 1, Costs.maxLevel(kind) + 1 do
				local want = Costs.building(kind, level)
				expect(costs.building(kind, level)).toEqual(
					if want then { cost = want.cost, buildSeconds = want.buildSeconds } else nil
				)
			end
		end
		local soldier = assert(Costs.unit("soldier"))
		expect(costs.unit("soldier")).toEqual({ cost = soldier.cost, trainSeconds = soldier.trainSeconds })
		local c = Catalog.default() -- Costs.luau wins over config Military for the units it lists
		c.units.soldier.cost = { gold = 999 }
		c.units.soldier.trainTime = 99
		expect(Catalog.costs(c).unit("soldier")).toEqual({ cost = soldier.cost, trainSeconds = soldier.trainSeconds })
		expect(costs.unit("dragon")).toBeNil()
	end)

	it("falls back to config Military for units Costs.luau does not list yet (VS-2)", function()
		local c = Catalog.default()
		expect(Costs.unit("knight")).toBeNil()
		expect(Catalog.costs(c).unit("knight")).toEqual({
			cost = c.units.knight.cost,
			trainSeconds = c.units.knight.trainTime,
		})
	end)

	it("has stats for exactly levels 1..Costs.maxLevel of every building type, and no cost or time", function()
		local c = Catalog.default()
		for _, kind in Types.BUILDING_TYPES do
			local def = c.buildings[kind]
			expect(def).never.toBeNil()
			expect(#def.levels).toBe(Costs.maxLevel(kind))
			for _, stats in def.levels do
				expect(stats.cost).toBeNil()
				expect(stats.work).toBeNil()
			end
		end
	end)

	it("rejects a non-table catalog", function()
		local ok, errors = Catalog.validate(nil)
		expect(ok).toBe(false)
		expect(#errors).toBe(1)
	end)

	it("rejects a cost or a build time on a building level: those belong to Costs.luau", function()
		local errors = errorsOf(function(c)
			c.buildings.house.levels[1].cost = { wood = 40 }
			c.buildings.farm.levels[2].work = 25
		end)
		expect(anyContains(errors, "house.levels[1]: cost and build time belong to Costs.luau")).toBe(true)
		expect(anyContains(errors, "farm.levels[2]: cost and build time belong to Costs.luau")).toBe(true)
	end)

	it("reports unknown resources and non-integer unit costs", function()
		local errors = errorsOf(function(c)
			c.units.archer.cost = { mana = 5, wood = 2.5 }
		end)
		expect(anyContains(errors, "unknown resource 'mana'")).toBe(true)
		expect(anyContains(errors, "cost of wood must be a non-negative integer")).toBe(true)
	end)

	it("requires a keep with territory and a hauler pool", function()
		local errors = errorsOf(function(c)
			c.buildings.keep.levels[1].territory = 0
			c.jobs.hauler = nil
			table.remove(c.jobOrder, table.find(c.jobOrder, "hauler"))
		end)
		expect(anyContains(errors, "keep: level 1 needs a positive territory")).toBe(true)
		expect(anyContains(errors, "a hauler (the generalist pool) is required")).toBe(true)
	end)

	it("keeps the order lists and maps in sync", function()
		local errors = errorsOf(function(c)
			table.insert(c.buildingOrder, "castle")
			table.remove(c.unitOrder, 1)
		end)
		expect(anyContains(errors, "'castle' is not in buildings")).toBe(true)
		expect(anyContains(errors, "'soldier' missing from unitOrder")).toBe(true)
	end)

	it("rejects farms without workers, units with zero stats and bad tuning", function()
		local errors = errorsOf(function(c)
			c.buildings.farm.levels[2].workers = 0
			c.units.archer.range = 0
			c.tuning.nightStart = 1.5
			c.tuning.dayLength = -1
			c.tuning.startCitizens.Wizard = 2
			c.buildings.barracks.levels[1].trains = { "Dragon" }
		end)
		expect(anyContains(errors, "farms need workers and yield")).toBe(true)
		expect(anyContains(errors, "units.archer: range must be positive")).toBe(true)
		expect(anyContains(errors, "nightStart")).toBe(true)
		expect(anyContains(errors, "tuning.dayLength must be positive")).toBe(true)
		expect(anyContains(errors, "unknown job 'Wizard'")).toBe(true)
		expect(anyContains(errors, "trains unknown unit 'Dragon'")).toBe(true)
	end)

	it("rejects bad barracks stats and unplaceable start buildings", function()
		local errors = errorsOf(function(c)
			c.buildings.barracks.levels[1].bunks = 2.5
			c.buildings.barracks.levels[2].trainSpeed = 0
			c.buildings.quarry.levels[2].gatherBonus = -0.1
			c.buildings.lumbercamp.levels[3].gatherBonus = "fast"
			c.tuning.startBuildings = { { kind = "keep", angle = 0, distance = 10 } }
		end)
		expect(anyContains(errors, "quarry.levels[2]: gatherBonus must be a number >= 0")).toBe(true)
		expect(anyContains(errors, "lumbercamp.levels[3]: gatherBonus must be a number >= 0")).toBe(true)
		expect(anyContains(errors, "barracks.levels[1]: bunks must be a non-negative integer")).toBe(true)
		expect(anyContains(errors, "barracks.levels[2]: trainSpeed must be positive")).toBe(true)
		expect(anyContains(errors, "unknown or unplaceable building 'keep'")).toBe(true)
	end)

	it("levelOf and isResource answer lookups", function()
		local c = Catalog.default()
		expect(Catalog.levelOf(c, "house", 2).popCap).toBe(8)
		expect(Catalog.levelOf(c, "house", 9)).toBeNil()
		expect(Catalog.levelOf(c, "Nope", 1)).toBeNil()
		expect(Catalog.isResource("gold")).toBe(true)
		expect(Catalog.isResource("mana")).toBe(false)
		expect(Catalog.isResource(5)).toBe(false)
	end)
end)
