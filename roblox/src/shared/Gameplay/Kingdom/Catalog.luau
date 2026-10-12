--!strict
--[[
	Gameplay/Kingdom/Catalog — the data that defines AI Kingdoms: resources, buildings and their
	levels, citizen occupations, military units and simulation tuning. Pure data + validation; no
	Roblox APIs, so the simulation runs identically in Lune specs and on the server.

	API
		Catalog.default(): Catalog              -- a fresh deep copy of the built-in catalog
		Catalog.validate(catalog): (boolean, { string })  -- every problem found, not just the first
		Catalog.RESOURCES: { string }           -- "food", "wood", "stone", "gold" (stable order)
		Catalog.levelOf(catalog, kind, level): BuildingLevel?
		Catalog.isResource(name): boolean

	Conventions
		- All amounts are integers (resources never become fractional, so balances stay exact).
		- A building level's stats are totals for that level, not increments (House L2 popCap 7 means
		  a level-2 house holds 7 people). `cost`/`work` of level 1 is the placement price; of
		  level n > 1 the price of upgrading from n-1.
		- Distances are studs on the XZ plane; times are simulation seconds.
	Game-specific overrides will come from games/<game>/config/Buildings.luau etc. once FORGE-00
	assigns those files (handoff 2026-10-12-forge-01-to-forge-00-ai-kingdoms-ownership).
]]

export type Cost = { [string]: number }

export type AttackStats = { damage: number, range: number, cooldown: number }

export type BuildingLevel = {
	cost: Cost,
	work: number, -- builder-seconds to finish this level
	hp: number,
	popCap: number?, -- population this building houses
	storage: number?, -- storage capacity per resource this building provides
	territory: number?, -- territory radius (Keep only)
	workers: number?, -- worker slots (Farm)
	yield: number?, -- food per harvest (Farm)
	attack: AttackStats?, -- defensive fire (Tower, Keep)
	trains: { string }?, -- unit ids this level can train (Barracks)
}

export type BuildingDef = {
	id: string,
	name: string,
	footprint: number, -- radius in studs used for placement overlap checks
	placeable: boolean, -- false for the Keep (granted at kingdom creation)
	dropoff: boolean, -- citizens deliver resources here
	maxCount: number?, -- per kingdom
	requiresKeepLevel: number?,
	levels: { BuildingLevel },
}

export type OccupationDef = {
	id: string,
	name: string,
	resource: string?, -- what this occupation produces (nil for builders/laborers)
	affinity: { [string]: number }, -- activity kind -> skill multiplier for utility scoring
}

export type UnitDef = {
	id: string,
	name: string,
	cost: Cost,
	trainTime: number,
	hp: number,
	damage: number,
	range: number,
	cooldown: number,
	speed: number,
	siege: number, -- damage multiplier against buildings
	attacksUnits: boolean,
	requiresBarracksLevel: number,
}

export type NodeDef = {
	id: string,
	resource: string,
	amount: number,
	footprint: number,
	slots: number,
	regrow: number?, -- seconds until a depleted node is full again (trees); nil = never
}

export type Tuning = {
	tickSeconds: number,
	dayLength: number, -- seconds per full day
	nightStart: number, -- fraction of the day when night starts
	citizenSpeed: number,
	carry: number,
	gatherRate: { [string]: number }, -- resource units per second while working a node
	harvestTime: number, -- seconds per farm harvest
	buildRate: number, -- work units per second per builder
	thinkInterval: number, -- seconds between routine utility re-evaluations
	hungerPerDay: number,
	eatThreshold: number,
	mealFood: number,
	starveDeathHunger: number, -- hunger at which a citizen dies
	birthInterval: number,
	birthFood: number,
	memorySize: number,
	memorySeconds: number,
	fleeRadius: number,
	arriveRadius: number,
	placementGap: number,
	cancelRefund: number, -- fraction of a site's cost refunded on cancel
	startResources: Cost,
	startCitizens: { [string]: number }, -- occupation -> count
	startBuildings: { { kind: string, angle: number, distance: number } }, -- complete at match start
	needTargets: Cost, -- stock level each resource is "comfortable" at (before population scaling)
}

export type Catalog = {
	resources: { string },
	buildings: { [string]: BuildingDef },
	buildingOrder: { string },
	occupations: { [string]: OccupationDef },
	occupationOrder: { string },
	units: { [string]: UnitDef },
	unitOrder: { string },
	nodes: { [string]: NodeDef },
	tuning: Tuning,
}

local Catalog = {}

Catalog.RESOURCES = table.freeze({ "food", "wood", "stone", "gold" })

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local DEFAULT: Catalog = {
	resources = { "food", "wood", "stone", "gold" },
	buildingOrder = { "Keep", "House", "Farm", "Storehouse", "Barracks", "Tower", "Wall" },
	buildings = {
		Keep = {
			id = "Keep",
			name = "Keep",
			footprint = 14,
			placeable = false,
			dropoff = true,
			maxCount = 1,
			levels = {
				{
					cost = {},
					work = 0,
					hp = 6000,
					popCap = 10,
					storage = 400,
					territory = 130,
					attack = { damage = 10, range = 40, cooldown = 1.5 },
				},
				{
					cost = { wood = 150, stone = 150 },
					work = 60,
					hp = 9000,
					popCap = 14,
					storage = 800,
					territory = 170,
					attack = { damage = 14, range = 45, cooldown = 1.5 },
				},
				{
					cost = { wood = 300, stone = 300, gold = 100 },
					work = 120,
					hp = 12000,
					popCap = 18,
					storage = 1500,
					territory = 210,
					attack = { damage = 18, range = 50, cooldown = 1.5 },
				},
			},
		},
		House = {
			id = "House",
			name = "House",
			footprint = 6,
			placeable = true,
			dropoff = false,
			levels = {
				{ cost = { wood = 40 }, work = 15, hp = 300, popCap = 4 },
				{ cost = { wood = 40, stone = 30 }, work = 20, hp = 450, popCap = 7 },
				{ cost = { wood = 60, stone = 60 }, work = 25, hp = 600, popCap = 10 },
			},
		},
		Farm = {
			id = "Farm",
			name = "Farm",
			footprint = 10,
			placeable = true,
			dropoff = false,
			levels = {
				{ cost = { wood = 50 }, work = 20, hp = 250, workers = 3, yield = 5 },
				{ cost = { wood = 60, stone = 20 }, work = 25, hp = 350, workers = 4, yield = 6 },
				{ cost = { wood = 80, stone = 60 }, work = 30, hp = 450, workers = 5, yield = 7 },
			},
		},
		Storehouse = {
			id = "Storehouse",
			name = "Storehouse",
			footprint = 7,
			placeable = true,
			dropoff = true,
			levels = {
				{ cost = { wood = 60 }, work = 20, hp = 500, storage = 300 },
				{ cost = { wood = 60, stone = 60 }, work = 30, hp = 800, storage = 600 },
			},
		},
		Barracks = {
			id = "Barracks",
			name = "Barracks",
			footprint = 10,
			placeable = true,
			dropoff = false,
			maxCount = 2,
			levels = {
				{ cost = { wood = 120, stone = 60 }, work = 40, hp = 1200, trains = { "Militia", "Archer" } },
				{
					cost = { wood = 100, stone = 120, gold = 40 },
					work = 50,
					hp = 1800,
					trains = { "Militia", "Archer", "Knight", "Ram" },
				},
			},
		},
		Tower = {
			id = "Tower",
			name = "Watchtower",
			footprint = 5,
			placeable = true,
			dropoff = false,
			requiresKeepLevel = 2,
			levels = {
				{
					cost = { wood = 60, stone = 80 },
					work = 35,
					hp = 1200,
					attack = { damage = 12, range = 45, cooldown = 1.5 },
				},
				{
					cost = { stone = 120, gold = 20 },
					work = 40,
					hp = 1800,
					attack = { damage = 18, range = 55, cooldown = 1.5 },
				},
			},
		},
		Wall = {
			id = "Wall",
			name = "Wall",
			footprint = 4,
			placeable = true,
			dropoff = false,
			levels = {
				{ cost = { stone = 20 }, work = 10, hp = 900 },
				{ cost = { stone = 30 }, work = 12, hp = 1600 },
			},
		},
	},
	occupationOrder = { "Farmer", "Woodcutter", "Quarrier", "Miner", "Builder", "Laborer" },
	occupations = {
		Farmer = { id = "Farmer", name = "Farmer", resource = "food", affinity = { farm = 1, build = 0.3 } },
		Woodcutter = {
			id = "Woodcutter",
			name = "Woodcutter",
			resource = "wood",
			affinity = { wood = 1, build = 0.3 },
		},
		Quarrier = { id = "Quarrier", name = "Quarrier", resource = "stone", affinity = { stone = 1, build = 0.3 } },
		Miner = { id = "Miner", name = "Miner", resource = "gold", affinity = { gold = 1, build = 0.3 } },
		Builder = {
			id = "Builder",
			name = "Builder",
			affinity = { build = 1, wood = 0.35, stone = 0.35, farm = 0.25 },
		},
		Laborer = {
			id = "Laborer",
			name = "Laborer",
			affinity = { build = 0.6, wood = 0.6, stone = 0.6, farm = 0.6, gold = 0.4 },
		},
	},
	unitOrder = { "Militia", "Archer", "Knight", "Ram" },
	units = {
		Militia = {
			id = "Militia",
			name = "Militia",
			cost = { food = 30, wood = 10 },
			trainTime = 8,
			hp = 80,
			damage = 8,
			range = 5,
			cooldown = 1,
			speed = 14,
			siege = 1,
			attacksUnits = true,
			requiresBarracksLevel = 1,
		},
		Archer = {
			id = "Archer",
			name = "Archer",
			cost = { food = 30, wood = 30 },
			trainTime = 10,
			hp = 50,
			damage = 7,
			range = 35,
			cooldown = 1.5,
			speed = 13,
			siege = 0.5,
			attacksUnits = true,
			requiresBarracksLevel = 1,
		},
		Knight = {
			id = "Knight",
			name = "Knight",
			cost = { food = 50, gold = 40 },
			trainTime = 14,
			hp = 180,
			damage = 14,
			range = 6,
			cooldown = 1.2,
			speed = 20,
			siege = 1,
			attacksUnits = true,
			requiresBarracksLevel = 2,
		},
		Ram = {
			id = "Ram",
			name = "Battering Ram",
			cost = { wood = 120, stone = 20 },
			trainTime = 20,
			hp = 400,
			damage = 60,
			range = 7,
			cooldown = 3,
			speed = 6,
			siege = 4,
			attacksUnits = false,
			requiresBarracksLevel = 2,
		},
	},
	nodes = {
		Tree = { id = "Tree", resource = "wood", amount = 80, footprint = 3, slots = 2, regrow = 240 },
		Rock = { id = "Rock", resource = "stone", amount = 200, footprint = 4, slots = 3 },
		GoldVein = { id = "GoldVein", resource = "gold", amount = 300, footprint = 4, slots = 3 },
	},
	tuning = {
		tickSeconds = 0.25,
		dayLength = 120,
		nightStart = 0.75,
		citizenSpeed = 12,
		carry = 10,
		gatherRate = { wood = 0.8, stone = 0.5, gold = 0.35 },
		harvestTime = 6,
		buildRate = 1,
		thinkInterval = 2,
		hungerPerDay = 1,
		eatThreshold = 0.6,
		mealFood = 2,
		starveDeathHunger = 3,
		birthInterval = 30,
		birthFood = 25,
		memorySize = 4,
		memorySeconds = 45,
		fleeRadius = 40,
		arriveRadius = 1.5,
		placementGap = 2,
		cancelRefund = 0.5,
		startResources = { food = 120, wood = 100, stone = 50, gold = 0 },
		startCitizens = { Farmer = 3, Woodcutter = 3, Quarrier = 2, Builder = 2 },
		-- angle is relative to the direction from the keep toward the map centre (radians)
		startBuildings = { { kind = "Farm", angle = 0.6, distance = 34 } },
		needTargets = { food = 150, wood = 200, stone = 150, gold = 80 },
	},
}

function Catalog.default(): Catalog
	return deepCopy(DEFAULT)
end

function Catalog.isResource(name: any): boolean
	return type(name) == "string" and table.find(Catalog.RESOURCES, name) ~= nil
end

function Catalog.levelOf(catalog: Catalog, kind: string, level: number): BuildingLevel?
	local def = catalog.buildings[kind]
	if def == nil then
		return nil
	end
	return def.levels[level]
end

local function isNonNegInt(v: any): boolean
	return type(v) == "number" and v == v and v >= 0 and v < math.huge and math.floor(v) == v
end

local function isPositive(v: any): boolean
	return type(v) == "number" and v == v and v > 0 and v < math.huge
end

local function checkCost(errors: { string }, where: string, cost: any)
	if type(cost) ~= "table" then
		table.insert(errors, `{where}: cost must be a table`)
		return
	end
	for res, amount in cost do
		if not Catalog.isResource(res) then
			table.insert(errors, `{where}: unknown resource '{tostring(res)}'`)
		elseif not isNonNegInt(amount) then
			table.insert(errors, `{where}: cost of {res} must be a non-negative integer`)
		end
	end
end

function Catalog.validate(catalog: any): (boolean, { string })
	local errors: { string } = {}
	if type(catalog) ~= "table" then
		return false, { "catalog must be a table" }
	end
	for _, field in
		{ "buildings", "buildingOrder", "occupations", "occupationOrder", "units", "unitOrder", "nodes", "tuning" }
	do
		if type(catalog[field]) ~= "table" then
			table.insert(errors, `missing table '{field}'`)
		end
	end
	if #errors > 0 then
		return false, errors
	end

	local function checkOrder(orderName: string, mapName: string)
		local seen = {}
		for _, id in catalog[orderName] do
			if catalog[mapName][id] == nil then
				table.insert(errors, `{orderName}: '{tostring(id)}' is not in {mapName}`)
			end
			if seen[id] then
				table.insert(errors, `{orderName}: '{tostring(id)}' listed twice`)
			end
			seen[id] = true
		end
		for id in catalog[mapName] do
			if not seen[id] then
				table.insert(errors, `{mapName}: '{tostring(id)}' missing from {orderName}`)
			end
		end
	end
	checkOrder("buildingOrder", "buildings")
	checkOrder("occupationOrder", "occupations")
	checkOrder("unitOrder", "units")

	if catalog.buildings.Keep == nil then
		table.insert(errors, "buildings: a Keep is required")
	elseif catalog.buildings.Keep.levels[1] == nil or not isPositive(catalog.buildings.Keep.levels[1].territory) then
		table.insert(errors, "buildings.Keep: level 1 needs a positive territory")
	end

	for id, def in catalog.buildings do
		local where = `buildings.{tostring(id)}`
		if def.id ~= id then
			table.insert(errors, `{where}: id field must equal its key`)
		end
		if not isPositive(def.footprint) then
			table.insert(errors, `{where}: footprint must be positive`)
		end
		if type(def.levels) ~= "table" or #def.levels == 0 then
			table.insert(errors, `{where}: needs at least one level`)
			continue
		end
		for level, stats in def.levels do
			local lw = `{where}.levels[{level}]`
			checkCost(errors, lw, stats.cost)
			if not isNonNegInt(stats.hp) or stats.hp == 0 then
				table.insert(errors, `{lw}: hp must be a positive integer`)
			end
			if type(stats.work) ~= "number" or stats.work < 0 or stats.work ~= stats.work then
				table.insert(errors, `{lw}: work must be a non-negative number`)
			elseif def.placeable and stats.work == 0 then
				table.insert(errors, `{lw}: placeable buildings need work > 0`)
			end
			if stats.trains then
				for _, unitId in stats.trains do
					if catalog.units[unitId] == nil then
						table.insert(errors, `{lw}: trains unknown unit '{tostring(unitId)}'`)
					end
				end
			end
		end
		if id == "Farm" then
			for level, stats in def.levels do
				if not isPositive(stats.workers) or not isPositive(stats.yield) then
					table.insert(errors, `{where}.levels[{level}]: farms need workers and yield`)
				end
			end
		end
	end

	for id, occ in catalog.occupations do
		if occ.id ~= id then
			table.insert(errors, `occupations.{tostring(id)}: id field must equal its key`)
		end
		if occ.resource ~= nil and not Catalog.isResource(occ.resource) then
			table.insert(errors, `occupations.{tostring(id)}: unknown resource '{tostring(occ.resource)}'`)
		end
	end
	if catalog.occupations.Laborer == nil then
		table.insert(errors, "occupations: a Laborer (fallback occupation) is required")
	end

	for id, unit in catalog.units do
		local where = `units.{tostring(id)}`
		if unit.id ~= id then
			table.insert(errors, `{where}: id field must equal its key`)
		end
		checkCost(errors, where, unit.cost)
		for _, field in { "trainTime", "hp", "damage", "range", "cooldown", "speed", "siege" } do
			if not isPositive(unit[field]) then
				table.insert(errors, `{where}: {field} must be positive`)
			end
		end
	end

	for id, node in catalog.nodes do
		if not Catalog.isResource(node.resource) then
			table.insert(errors, `nodes.{tostring(id)}: unknown resource`)
		end
		if not isNonNegInt(node.amount) or node.amount == 0 then
			table.insert(errors, `nodes.{tostring(id)}: amount must be a positive integer`)
		end
		if not isNonNegInt(node.slots) or node.slots == 0 then
			table.insert(errors, `nodes.{tostring(id)}: slots must be a positive integer`)
		end
		if node.regrow ~= nil and not isPositive(node.regrow) then
			table.insert(errors, `nodes.{tostring(id)}: regrow must be positive when set`)
		end
	end

	local t = catalog.tuning
	for _, field in
		{
			"tickSeconds",
			"dayLength",
			"citizenSpeed",
			"carry",
			"harvestTime",
			"buildRate",
			"thinkInterval",
			"hungerPerDay",
			"mealFood",
			"starveDeathHunger",
			"birthInterval",
			"memorySize",
			"memorySeconds",
			"arriveRadius",
		}
	do
		if not isPositive(t[field]) then
			table.insert(errors, `tuning.{field} must be positive`)
		end
	end
	if type(t.nightStart) ~= "number" or t.nightStart <= 0 or t.nightStart >= 1 then
		table.insert(errors, "tuning.nightStart must be in (0, 1)")
	end
	if not isNonNegInt(t.carry) then
		table.insert(errors, "tuning.carry must be an integer")
	end
	checkCost(errors, "tuning.startResources", t.startResources)
	for i, entry in t.startBuildings or {} do
		local def = catalog.buildings[entry.kind]
		if def == nil or not def.placeable then
			table.insert(errors, `tuning.startBuildings[{i}]: unknown or unplaceable building '{tostring(entry.kind)}'`)
		end
		if type(entry.angle) ~= "number" or not isPositive(entry.distance) then
			table.insert(errors, `tuning.startBuildings[{i}]: angle and positive distance required`)
		end
	end
	for occ, count in t.startCitizens or {} do
		if catalog.occupations[occ] == nil then
			table.insert(errors, `tuning.startCitizens: unknown occupation '{tostring(occ)}'`)
		elseif not isNonNegInt(count) then
			table.insert(errors, `tuning.startCitizens.{occ}: count must be a non-negative integer`)
		end
	end
	return #errors == 0, errors
end

return Catalog
