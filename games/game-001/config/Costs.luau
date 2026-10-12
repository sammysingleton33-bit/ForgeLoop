--!strict
--[[
	Costs (ReplicatedStorage.Forge.Config.Costs). Owned by FORGE-03 (team.md, game-001).
	CONTRACTS G6/G7. **Hour-0 contract stub: the signatures are final, the numbers are
	placeholders** (taken from FORGE-01's simulation double so both sides agree). The VS-1 balance
	sheet replaces them in FL-0058 (`games/game-001/design/economy.md`).

	Costs.building(type, level) -> { cost: ResourceBag, buildSeconds: number }?
		Cost to place (level 1) or to upgrade to `level`. nil when that level does not exist (max
		level reached). Starting buildings (keep level 1) cost nothing: BuildingService places them.
		buildSeconds = builder-seconds of work (several builders work in parallel).
	Costs.unit(unitType) -> { cost: ResourceBag, trainSeconds: number, upkeepFood: number }?
		upkeepFood = food per minute while the unit lives. nil for an unknown unit type.
	Costs.maxLevel(type) -> number                0 for an unknown building type
	Costs.starting -> ResourceBag                 each kingdom's stockpile when Founding starts
	Costs.upkeep -> { citizenFood: number, intervalSeconds: number }
		ProductionService (the only food consumer, G7) charges citizenFood per citizen and each
		unit's upkeepFood once per intervalSeconds.
	Costs.catalogue() -> { buildings = { [type] = { [level] = entry } }, units = { [unitType] = entry },
		starting = ResourceBag, upkeep = ... }   plain data for the `Treasury.GetCosts` remote

	Every returned table is a fresh copy: callers may keep or change it.
]]

export type ResourceBag = { [string]: number }
export type BuildingCost = { cost: ResourceBag, buildSeconds: number }
export type UnitCost = { cost: ResourceBag, trainSeconds: number, upkeepFood: number }

-- PROVISIONAL (D-030 catalogue, design/living-kingdom.md §4; balance sheet design/economy.md):
-- level 1 is the VS-1 path (house 40 wood, farm 50 wood, barracks 120 wood + 60 stone, keep L2
-- 150 wood + 150 stone); higher levels follow the D-030 level ranges. Barracks build/upgrade times
-- are the user's proposal 8 / 18 / 35 / 60 s. Times are builder-seconds: BuildingService scales them
-- by the builders on site.
local BUILDINGS: { [string]: { BuildingCost } } = {
	keep = {
		{ cost = {}, buildSeconds = 0 }, -- starting building
		{ cost = { wood = 150, stone = 150 }, buildSeconds = 60 },
		{ cost = { wood = 250, stone = 300, gold = 60 }, buildSeconds = 120 },
	},
	house = {
		{ cost = { wood = 40 }, buildSeconds = 20 },
		{ cost = { wood = 40, stone = 30 }, buildSeconds = 30 },
	},
	farm = {
		{ cost = { wood = 50 }, buildSeconds = 25 },
		{ cost = { wood = 60, stone = 20 }, buildSeconds = 35 },
		{ cost = { wood = 80, stone = 40 }, buildSeconds = 45 },
	},
	storehouse = {
		{ cost = { wood = 60 }, buildSeconds = 30 },
	},
	lumbercamp = {
		{ cost = { wood = 40 }, buildSeconds = 25 },
		{ cost = { wood = 50, stone = 20 }, buildSeconds = 30 },
		{ cost = { wood = 70, stone = 40 }, buildSeconds = 40 },
	},
	quarry = {
		{ cost = { wood = 60 }, buildSeconds = 30 },
		{ cost = { wood = 70, stone = 10 }, buildSeconds = 35 },
		{ cost = { wood = 90, stone = 30 }, buildSeconds = 45 },
	},
	barracks = {
		{ cost = { wood = 120, stone = 60 }, buildSeconds = 8 },
		{ cost = { wood = 100, stone = 80 }, buildSeconds = 18 },
		{ cost = { wood = 150, stone = 120, gold = 20 }, buildSeconds = 35 },
		{ cost = { wood = 200, stone = 180, gold = 50 }, buildSeconds = 60 },
	},
	watchtower = {
		{ cost = { wood = 60, stone = 80 }, buildSeconds = 40 },
		{ cost = { wood = 60, stone = 100 }, buildSeconds = 40 },
	},
	wall = {
		{ cost = { stone = 20 }, buildSeconds = 15 },
		{ cost = { stone = 40 }, buildSeconds = 20 },
		{ cost = { stone = 60, gold = 10 }, buildSeconds = 25 },
	},
	gate = {
		{ cost = { wood = 40, stone = 30 }, buildSeconds = 25 },
		{ cost = { wood = 40, stone = 60 }, buildSeconds = 30 },
		{ cost = { wood = 60, stone = 90, gold = 10 }, buildSeconds = 35 },
	},
}

local UNITS: { [string]: UnitCost } = {
	soldier = { cost = { food = 30, wood = 10 }, trainSeconds = 8, upkeepFood = 1 },
}

local Costs = {}

Costs.starting = table.freeze({ food = 120, wood = 100, stone = 50, gold = 0 }) :: ResourceBag
Costs.upkeep = table.freeze({ citizenFood = 1, intervalSeconds = 60 })

local function copyBuilding(entry: BuildingCost): BuildingCost
	return { cost = table.clone(entry.cost), buildSeconds = entry.buildSeconds }
end

local function copyUnit(entry: UnitCost): UnitCost
	return { cost = table.clone(entry.cost), trainSeconds = entry.trainSeconds, upkeepFood = entry.upkeepFood }
end

function Costs.building(buildingType: string, level: number): BuildingCost?
	local levels = BUILDINGS[buildingType]
	local entry = levels and levels[level]
	return if entry then copyBuilding(entry) else nil
end

function Costs.unit(unitType: string): UnitCost?
	local entry = UNITS[unitType]
	return if entry then copyUnit(entry) else nil
end

function Costs.maxLevel(buildingType: string): number
	local levels = BUILDINGS[buildingType]
	return if levels then #levels else 0
end

function Costs.catalogue(): { [string]: any }
	local buildings = {}
	for buildingType, levels in BUILDINGS do
		local copy = {}
		for level, entry in levels do
			copy[level] = copyBuilding(entry)
		end
		buildings[buildingType] = copy
	end
	local units = {}
	for unitType, entry in UNITS do
		units[unitType] = copyUnit(entry)
	end
	return {
		buildings = buildings,
		units = units,
		starting = table.clone(Costs.starting),
		upkeep = table.clone(Costs.upkeep),
	}
end

return table.freeze(Costs)
