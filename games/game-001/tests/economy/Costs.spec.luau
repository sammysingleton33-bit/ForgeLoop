local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")

-- CONTRACTS G2 BuildingType, in contract order.
local BUILDING_TYPES =
	{ "keep", "house", "farm", "storehouse", "lumbercamp", "quarry", "barracks", "watchtower", "wall", "gate" }

local function isResourceBag(bag, allowEmpty: boolean, allowZero: boolean?): (boolean, string?)
	local n = 0
	for id, amount in bag do
		n += 1
		if Resources.defs[id] == nil then
			return false, `unknown resource {tostring(id)}`
		end
		if type(amount) ~= "number" or amount < (if allowZero then 0 else 1) or amount ~= math.floor(amount) then
			return false, `{id} must be a whole number > 0`
		end
	end
	if n == 0 and not allowEmpty then
		return false, "empty cost"
	end
	return true, nil
end

describe("game-001 config Resources (G2)", function()
	it("lists food, wood, stone, gold in display order with a definition each", function()
		expect(Resources.ids).toEqual({ "food", "wood", "stone", "gold" })
		for _, id in Resources.ids do
			local def = Resources.defs[id]
			expect(def.id).toBe(id)
			expect(def.name).toBeA("string")
			expect(string.match(def.color, "^#%x%x%x%x%x%x$")).toBeTruthy()
		end
	end)
end)

describe("game-001 config Costs (G6/G7 contract stub)", function()
	it("prices level 1 of every building type with known resources", function()
		for _, buildingType in BUILDING_TYPES do
			local entry = Costs.building(buildingType, 1)
			expect(entry).toBeTruthy()
			local ok, why = isResourceBag(entry.cost, buildingType == "keep")
			if not ok then
				error(`{buildingType} level 1: {why}`)
			end
			expect(entry.buildSeconds).toBeGreaterThanOrEqual(0)
			expect(Costs.maxLevel(buildingType)).toBeGreaterThanOrEqual(1)
		end
	end)

	it("prices every upgrade level with a positive cost and build time", function()
		for _, buildingType in BUILDING_TYPES do
			for level = 2, Costs.maxLevel(buildingType) do
				local entry = Costs.building(buildingType, level)
				local ok, why = isResourceBag(entry.cost, false)
				if not ok then
					error(`{buildingType} level {level}: {why}`)
				end
				expect(entry.buildSeconds).toBeGreaterThan(0)
			end
		end
		expect(Costs.building("keep", 2)).toBeTruthy() -- VS-1 row 6: the keep upgrades to level 2
	end)

	it("returns nil past the max level and for unknown types", function()
		expect(Costs.building("house", Costs.maxLevel("house") + 1)).toBeNil()
		expect(Costs.building("castle", 1)).toBeNil()
		expect(Costs.maxLevel("castle")).toBe(0)
		expect(Costs.unit("dragon")).toBeNil()
	end)

	it("prices the soldier with training time and food upkeep", function()
		local soldier = Costs.unit("soldier")
		expect((isResourceBag(soldier.cost, false))).toBe(true)
		expect(soldier.trainSeconds).toBeGreaterThan(0)
		expect(soldier.upkeepFood).toBeGreaterThanOrEqual(0)
	end)

	it("hands out fresh copies, so callers cannot change the catalogue", function()
		local a = Costs.building("house", 1)
		a.cost.wood = 1
		expect(Costs.building("house", 1).cost.wood).never.toBe(1)
		local c = Costs.catalogue()
		c.buildings.house[1].cost.wood = 1
		expect(Costs.building("house", 1).cost.wood).never.toBe(1)
		expect(function()
			(Costs :: any).starting.food = 1
		end).toThrow()
	end)

	it("exposes starting stockpiles, upkeep and a plain catalogue for Treasury.GetCosts", function()
		expect((isResourceBag(Costs.starting, true, true))).toBe(true)
		expect(Costs.upkeep.intervalSeconds).toBeGreaterThan(0)
		local c = Costs.catalogue()
		expect(c.buildings.keep[2]).toEqual(Costs.building("keep", 2))
		expect(c.units.soldier).toEqual(Costs.unit("soldier"))
		expect(c.starting).toEqual(table.clone(Costs.starting))
	end)
end)
