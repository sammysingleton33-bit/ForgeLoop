--!strict
--[[
	Sim/Catalog — the data that defines AI Kingdoms: resources, buildings and their
	levels, citizen jobs, military units, resource nodes, Crown Point rules and simulation tuning.
	Pure data + validation; no Roblox APIs, so the simulation runs identically in Lune specs and on
	the server. Ids follow CONTRACTS G2 (building types and job ids are lowercase contract ids).
	Costs, build times and level counts are FORGE-03's Costs.luau (CONTRACTS G6, G13.5: one source per
	number). The simulation reads costs and times only through its `costs` provider; the building
	levels here carry gameplay stats only, for exactly levels 1..Costs.maxLevel(type).

	API
		Catalog.default(): Catalog              -- a fresh deep copy of the built-in catalog
		Catalog.validate(catalog): (boolean, { string })  -- every problem found, not just the first
		Catalog.RESOURCES: { string }           -- "food", "wood", "stone", "gold" (stable order)
		Catalog.levelOf(catalog, kind, level): BuildingLevel?
		Catalog.isResource(name): boolean
		Catalog.costs(catalog): Costs        -- G6 provider on Costs.luau: building(type, level) ->
		                                       { cost, buildSeconds }; unit(type) -> { cost, trainSeconds }
		                                       (a unit Costs.luau does not list yet, VS-2, falls back to
		                                       config Military's cost/trainTime)

	Conventions
		- All amounts are integers (resources never become fractional, so balances stay exact).
		- A building level's stats are totals for that level, not increments (House L2 popCap 8 means
		  a level-2 house holds 8 people). Costs.building(type, 1) is the placement price; of level
		  n > 1 the price of upgrading from n-1.
		- Distances are studs on the XZ plane; times are simulation seconds.
	Data lives in games/game-001/config (Buildings, Jobs, Military, Citizens, Kingdoms, Match);
	Catalog.default() assembles and deep-copies it, Catalog.validate checks it at startup.
]]

export type Cost = { [string]: number }

export type AttackStats = { damage: number, range: number, cooldown: number }

export type BuildingLevel = {
	hp: number,
	popCap: number?, -- population this building houses
	storage: number?, -- storage capacity per resource this building provides
	territory: number?, -- territory radius (keep only)
	workers: number?, -- worker slots (farm)
	yield: number?, -- food per harvest (farm)
	attack: AttackStats?, -- defensive fire (watchtower, keep)
	trains: { string }?, -- unit ids this level can train (barracks)
	bunks: number?, -- soldiers (living + training) this barracks sleeps (D-041; barracks)
	trainSpeed: number?, -- divides a unit's trainSeconds (barracks; default 1)
	gatherBonus: number?, -- citizens gather the resources this dropoff accepts this much faster (0.2 = +20%)
}

export type BuildingDef = {
	id: string,
	name: string,
	footprint: number, -- radius in studs: reach for citizens, units, combat and territory checks
	placeSize: Vector2?, -- placement rectangle (X width, Y depth; Sim/Footprint); nil = place the circle
	placeable: boolean, -- false for the keep (granted at kingdom creation)
	dropoff: boolean, -- citizens deliver resources here
	accepts: { string }?, -- drop-off for these resources only (nil = all)
	maxCount: number?, -- per kingdom
	requiresKeepLevel: number?,
	levels: { BuildingLevel },
}

export type JobDef = {
	id: string,
	resources: { string }, -- what this job produces (empty for builders/haulers)
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
	startCitizens: { [string]: number }, -- job -> count
	mealsChargeTreasury: boolean,
	startBuildings: { { kind: string, angle: number, distance: number } }, -- complete at match start
	needTargets: Cost, -- stock level each resource is "comfortable" at (before population scaling)
}

export type Catalog = {
	resources: { string },
	buildings: { [string]: BuildingDef },
	buildingOrder: { string },
	jobs: { [string]: JobDef },
	jobOrder: { string },
	units: { [string]: UnitDef },
	unitOrder: { string },
	nodes: { [string]: NodeDef },
	crown: { buildingLevel: number, conquest: number, unitKill: number },
	tuning: Tuning,
}

export type Costs = {
	building: (kind: string, level: number) -> { cost: Cost, buildSeconds: number }?,
	unit: (kind: string) -> { cost: Cost, trainSeconds: number }?,
}

local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local CostsConfig = require("@game/ReplicatedStorage/Forge/Config/Costs")
local CitizensConfig = require("@game/ReplicatedStorage/Forge/Config/Citizens")
local JobsConfig = require("@game/ReplicatedStorage/Forge/Config/Jobs")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local MilitaryConfig = require("@game/ReplicatedStorage/Forge/Config/Military")
local Fit = require("../Build/Fit")
local Kit = require("../Kit/Kit")
local Types = require("../Kingdom/Types")

local JOB_IDS = Types.JOB_IDS
local BUILDING_TYPES = Types.BUILDING_TYPES

local Catalog = {}

Catalog.RESOURCES = Types.RESOURCE_IDS

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

-- The default catalog is assembled from the game's config modules (owner FORGE-01; costs inside
-- them are the double of FORGE-03's Costs.luau). Each call to default() returns a fresh deep copy.
local function assemble(): Catalog
	local tuning: any = table.clone(CitizensConfig)
	tuning.tickSeconds = MatchConfig.tickSeconds
	tuning.gatherRate = JobsConfig.gatherRate
	tuning.harvestTime = JobsConfig.harvestTime
	tuning.buildRate = JobsConfig.buildRate
	tuning.carry = JobsConfig.carry
	tuning.placementGap = BuildingsConfig.placementGap
	tuning.cancelRefund = BuildingsConfig.cancelRefund
	tuning.startResources = KingdomsConfig.startResources
	tuning.startCitizens = KingdomsConfig.startCitizens
	tuning.startBuildings = KingdomsConfig.startBuildings
	return {
		resources = { "food", "wood", "stone", "gold" },
		buildingOrder = BuildingsConfig.buildingOrder,
		buildings = BuildingsConfig.buildings,
		jobOrder = JobsConfig.jobOrder,
		jobs = JobsConfig.jobs,
		unitOrder = MilitaryConfig.unitOrder,
		units = MilitaryConfig.units,
		nodes = JobsConfig.nodes,
		crown = MatchConfig.crown,
		tuning = tuning,
	}
end

-- G6: Kit.footprint is the one source for placement. Each building places as the rectangle of its
-- largest level (`placeSize`, Build/Fit.largestFootprint: upgrades never grow into a neighbour); its
-- `footprint` radius (reach for citizens, units and combat) is half the longer side of its level-1 Kit
-- footprint. A type the Kit does not know keeps the config `footprint` circle for both.
function Catalog.kitFootprints(catalog: Catalog): Catalog
	for kind, def in catalog.buildings do
		local ok, size = pcall(Kit.footprint, kind, 1)
		if ok and typeof(size) == "Vector2" then
			def.footprint = math.max(size.X, size.Y) / 2
		end
		def.placeSize = Fit.largestFootprint(kind)
	end
	return catalog
end

function Catalog.default(): Catalog
	return Catalog.kitFootprints(deepCopy(assemble()))
end

function Catalog.costs(catalog: Catalog): Costs
	return {
		building = function(kind: string, level: number)
			local price = CostsConfig.building(kind, level)
			if price == nil then
				return nil
			end
			return { cost = price.cost, buildSeconds = price.buildSeconds }
		end,
		unit = function(kind: string)
			local price = CostsConfig.unit(kind)
			if price then
				return { cost = price.cost, trainSeconds = price.trainSeconds }
			end
			local def = catalog.units[kind]
			if def == nil then
				return nil
			end
			return { cost = table.clone(def.cost), trainSeconds = def.trainTime }
		end,
	}
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
		{ "buildings", "buildingOrder", "jobs", "jobOrder", "units", "unitOrder", "nodes", "crown", "tuning" }
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
	checkOrder("jobOrder", "jobs")
	checkOrder("unitOrder", "units")

	if catalog.buildings.keep == nil then
		table.insert(errors, "buildings: a keep is required")
	elseif catalog.buildings.keep.levels[1] == nil or not isPositive(catalog.buildings.keep.levels[1].territory) then
		table.insert(errors, "buildings.keep: level 1 needs a positive territory")
	end

	for id, def in catalog.buildings do
		local where = `buildings.{tostring(id)}`
		if def.id ~= id then
			table.insert(errors, `{where}: id field must equal its key`)
		end
		if not isPositive(def.footprint) then
			table.insert(errors, `{where}: footprint must be positive`)
		end
		local size = def.placeSize
		if size ~= nil and (typeof(size) ~= "Vector2" or not isPositive(size.X) or not isPositive(size.Y)) then
			table.insert(errors, `{where}: placeSize must be a Vector2 with positive sides when set`)
		end
		if type(def.levels) ~= "table" or #def.levels == 0 then
			table.insert(errors, `{where}: needs at least one level`)
			continue
		end
		for level, stats in def.levels do
			local lw = `{where}.levels[{level}]`
			if stats.cost ~= nil or stats.work ~= nil then
				table.insert(errors, `{lw}: cost and build time belong to Costs.luau (CONTRACTS G13.5)`)
			end
			if not isNonNegInt(stats.hp) or stats.hp == 0 then
				table.insert(errors, `{lw}: hp must be a positive integer`)
			end
			if stats.bunks ~= nil and not isNonNegInt(stats.bunks) then
				table.insert(errors, `{lw}: bunks must be a non-negative integer`)
			end
			if stats.trainSpeed ~= nil and not isPositive(stats.trainSpeed) then
				table.insert(errors, `{lw}: trainSpeed must be positive`)
			end
			if stats.gatherBonus ~= nil and not (isPositive(stats.gatherBonus) or stats.gatherBonus == 0) then
				table.insert(errors, `{lw}: gatherBonus must be a number >= 0`)
			end
			if stats.trains then
				for _, unitId in stats.trains do
					if catalog.units[unitId] == nil then
						table.insert(errors, `{lw}: trains unknown unit '{tostring(unitId)}'`)
					end
				end
			end
		end
		for _, res in def.accepts or {} do
			if not Catalog.isResource(res) then
				table.insert(errors, `{where}: accepts unknown resource '{tostring(res)}'`)
			end
		end
		if id == "farm" then
			for level, stats in def.levels do
				if not isPositive(stats.workers) or not isPositive(stats.yield) then
					table.insert(errors, `{where}.levels[{level}]: farms need workers and yield`)
				end
			end
		end
	end

	for id, job in catalog.jobs do
		if job.id ~= id then
			table.insert(errors, `jobs.{tostring(id)}: id field must equal its key`)
		end
		if table.find(JOB_IDS, id) == nil or id == "idle" or id == "soldier" then
			table.insert(errors, `jobs.{tostring(id)}: not a citizen job of CONTRACTS G2`)
		end
		for _, res in job.resources or {} do
			if not Catalog.isResource(res) then
				table.insert(errors, `jobs.{tostring(id)}: unknown resource '{tostring(res)}'`)
			end
		end
	end
	if catalog.jobs.hauler == nil then
		table.insert(errors, "jobs: a hauler (the generalist pool) is required")
	end
	for id in catalog.buildings do
		if table.find(BUILDING_TYPES, id) == nil then
			table.insert(errors, `buildings.{tostring(id)}: not a building type of CONTRACTS G2`)
		end
	end
	for _, field in { "buildingLevel", "conquest", "unitKill" } do
		if not isNonNegInt(catalog.crown[field]) then
			table.insert(errors, `crown.{field} must be a non-negative integer`)
		end
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
		if catalog.jobs[occ] == nil then
			table.insert(errors, `tuning.startCitizens: unknown job '{tostring(occ)}'`)
		elseif not isNonNegInt(count) then
			table.insert(errors, `tuning.startCitizens.{occ}: count must be a non-negative integer`)
		end
	end
	return #errors == 0, errors
end

return Catalog
