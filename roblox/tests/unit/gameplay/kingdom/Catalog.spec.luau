local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Catalog = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Catalog")

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
		a.buildings.house.levels[1].cost.wood = 1
		a.tuning.startCitizens.farmer = 99
		local b = Catalog.default()
		expect(b.buildings.house.levels[1].cost.wood).toBe(40)
		expect(b.tuning.startCitizens.farmer).toBe(3)
	end)

	it("starts every kingdom with about ten citizens", function()
		local total = 0
		for _, n in Catalog.default().tuning.startCitizens do
			total += n
		end
		expect(total).toBe(10)
	end)

	it("rejects a non-table catalog", function()
		local ok, errors = Catalog.validate(nil)
		expect(ok).toBe(false)
		expect(#errors).toBe(1)
	end)

	it("reports unknown resources and non-integer costs", function()
		local errors = errorsOf(function(c)
			c.buildings.house.levels[1].cost = { mana = 5, wood = 2.5 }
		end)
		expect(anyContains(errors, "unknown resource 'mana'")).toBe(true)
		expect(anyContains(errors, "cost of wood must be a non-negative integer")).toBe(true)
	end)

	it("requires a Keep with territory and a Laborer fallback", function()
		local errors = errorsOf(function(c)
			c.buildings.keep.levels[1].territory = 0
			c.occupations.hauler = nil
			table.remove(c.jobOrder, table.find(c.jobOrder, "hauler"))
		end)
		expect(anyContains(errors, "Keep: level 1 needs a positive territory")).toBe(true)
		expect(anyContains(errors, "hauler")).toBe(true)
	end)

	it("keeps the order lists and maps in sync", function()
		local errors = errorsOf(function(c)
			table.insert(c.buildingOrder, "Castle")
			table.remove(c.unitOrder, 1)
		end)
		expect(anyContains(errors, "'Castle' is not in buildings")).toBe(true)
		expect(anyContains(errors, "'Militia' missing from unitOrder")).toBe(true)
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
		expect(anyContains(errors, "unknown occupation 'Wizard'")).toBe(true)
		expect(anyContains(errors, "trains unknown unit 'Dragon'")).toBe(true)
	end)

	it("rejects placeable buildings that need no work and unplaceable start buildings", function()
		local errors = errorsOf(function(c)
			c.buildings.house.levels[1].work = 0
			c.tuning.startBuildings = { { kind = "keep", angle = 0, distance = 10 } }
		end)
		expect(anyContains(errors, "placeable buildings need work > 0")).toBe(true)
		expect(anyContains(errors, "unknown or unplaceable building 'Keep'")).toBe(true)
	end)

	it("levelOf and isResource answer lookups", function()
		local c = Catalog.default()
		expect(Catalog.levelOf(c, "house", 2).popCap).toBe(7)
		expect(Catalog.levelOf(c, "house", 9)).toBeNil()
		expect(Catalog.levelOf(c, "Nope", 1)).toBeNil()
		expect(Catalog.isResource("gold")).toBe(true)
		expect(Catalog.isResource("mana")).toBe(false)
		expect(Catalog.isResource(5)).toBe(false)
	end)
end)
