--!strict
--[[
	Economy/Construction — building and unit economics: costs per level, upgrade requirements,
	limits, production, housing and storage. One rule set for the server (FORGE-01's
	KingdomService calls `check` before spending) and the UI (the construction menu shows exactly
	the same verdict before the player taps Build).

	Data: items of kind "building" / "unit" in Config.Items (format in that file's header).
	A KingdomView is the part of FORGE-01's kingdom snapshot these rules read:
		{ buildings: { BuildingState }, builders: { busy: number, total: number }?, citizens: { idle: number }? }
		BuildingState = { uid: string, buildingId: string, level: number,
		                  state: "constructing" | "upgrading" | "ready", workers: number? }
		`level` is the completed level (0 while first constructed). A building that is upgrading
		keeps working at its current level until the upgrade completes.

	API
		Construction.validate(items, currencies) -> (ok, problems)   building/unit sub-tables only
		Construction.new(items, currencies) -> catalog                errors listing every problem
		Construction.default() -> catalog                             Config.Items + Currencies.default()
		catalog:building(id) -> ItemDef?        catalog:buildings(category?) -> { ItemDef } (config order)
		catalog:unit(id) -> ItemDef?            catalog:units() -> { ItemDef }
		catalog:level(id, level) -> BuildingLevel?                    catalog:maxLevel(id) -> number
		catalog:count(kingdom, id) -> number    every instance, in any state (limits)
		catalog:highestLevel(kingdom, id) -> number   completed level of the best instance
		catalog:unmet(kingdom, requires) -> { Requirement }
		catalog:check(kingdom, treasury, buildingId, uid?) -> Check
			uid nil = construct a new building (level 1); uid = upgrade that instance.
			Check = { ok, action: "build" | "upgrade", buildingId, uid?, level, cost, buildSec,
			          reason: Reason?, missing: Bundle, unmet: { Requirement }, count, maxCount }
			Reason, first that applies: "unknown_building" | "not_found" | "busy" | "max_level" |
			"limit" | "requirement" | "builders" | "cost". `missing`/`unmet` are filled whenever
			they apply, even if an earlier reason won, so the UI can show every gap at once.
		catalog:checkUnit(kingdom, treasury, unitId) -> Check (action "recruit"; reasons
			"unknown_unit" | "requirement" | "cost")
		catalog:production(kingdom) -> Bundle   per minute, from workers in ready/upgrading buildings
		catalog:rate(id, level, workers) -> Bundle   per minute for one building
		catalog:housing(kingdom) -> number      citizens housed by completed buildings
		catalog:storageCaps(kingdom) -> Bundle  match currency caps: base cap + Storehouse storage
]]

local Bundle = require("./Bundle")
local Currencies = require("./Currencies")
local Items = require("@game/ReplicatedStorage/Forge/Config/Items")

type Bundle = Bundle.Bundle

export type Requirement = { building: string, level: number }
export type BuildingLevel = {
	cost: Bundle,
	buildSec: number,
	requires: { Requirement }?,
	workers: number?,
	produces: Bundle?,
	housing: number?,
	storage: number?,
}
export type BuildingState = {
	uid: string,
	buildingId: string,
	level: number,
	state: "constructing" | "upgrading" | "ready",
	workers: number?,
}
export type KingdomView = {
	buildings: { BuildingState },
	builders: { busy: number, total: number }?,
}
export type Reason =
	"unknown_building"
	| "unknown_unit"
	| "not_found"
	| "busy"
	| "max_level"
	| "limit"
	| "requirement"
	| "builders"
	| "cost"
export type Check = {
	ok: boolean,
	action: "build" | "upgrade" | "recruit",
	buildingId: string,
	uid: string?,
	level: number,
	cost: Bundle,
	buildSec: number,
	reason: Reason?,
	missing: Bundle,
	unmet: { Requirement },
	count: number,
	maxCount: number,
}

local Construction = {}
Construction.__index = Construction

Construction.CATEGORIES = table.freeze({ "economy", "civic", "military" })

local BUILDING_FIELDS = { category = true, maxCount = true, prebuilt = true, levels = true }
local LEVEL_FIELDS =
	{ cost = true, buildSec = true, requires = true, workers = true, produces = true, housing = true, storage = true }
local UNIT_FIELDS = { cost = true, trainSec = true, requires = true, housing = true }

local function isCount(n: any, allowZero: boolean?): boolean
	return Bundle.isAmount(n, allowZero) and n <= 1000000
end

local function checkRequires(requires: any, where: string, problems: { string }, ids: { [string]: any })
	if requires == nil then
		return
	end
	if type(requires) ~= "table" then
		table.insert(problems, `{where}: requires must be a list`)
		return
	end
	for i, req in requires do
		if type(req) ~= "table" or type(req.building) ~= "string" or not isCount(req.level) then
			table.insert(problems, `{where}: requires[{i}] must be {"{"} building = id, level = n >= 1 {"}"}`)
		elseif ids[req.building] == nil then
			table.insert(problems, `{where}: requires unknown building '{req.building}'`)
		elseif ids[req.building] ~= true and req.level > ids[req.building] then
			table.insert(problems, `{where}: requires {req.building} level {req.level}, above its max level`)
		end
	end
end

function Construction.validate(items: any, currencies: any): (boolean, { string })
	local problems = {}
	if type(items) ~= "table" then
		return false, { "items config must be a list" }
	end
	local match = currencies:set("match")
	-- building id -> max level (true for units, whose ids may not be required)
	local ids: { [string]: any } = {}
	for _, def in items do
		if type(def) == "table" and def.kind == "building" and type(def.building) == "table" then
			ids[def.id] = if type(def.building.levels) == "table" then #def.building.levels else 0
		end
	end
	for index, def in items do
		if type(def) ~= "table" then
			continue
		end
		local where = `item '{tostring(def.id or index)}'`
		if def.kind == "building" then
			local b = def.building
			if type(b) ~= "table" then
				table.insert(problems, `{where}: kind "building" needs a building table`)
				continue
			end
			for field in b do
				if not BUILDING_FIELDS[field] then
					table.insert(problems, `{where}: building has unknown field '{tostring(field)}'`)
				end
			end
			if table.find(Construction.CATEGORIES, b.category) == nil then
				table.insert(problems, `{where}: category must be economy, civic or military`)
			end
			if not isCount(b.maxCount) then
				table.insert(problems, `{where}: maxCount must be a whole number >= 1`)
			end
			if b.prebuilt ~= nil and type(b.prebuilt) ~= "boolean" then
				table.insert(problems, `{where}: prebuilt must be a boolean`)
			end
			if type(b.levels) ~= "table" or #b.levels == 0 then
				table.insert(problems, `{where}: levels must be a non-empty list`)
				continue
			end
			for n, level in b.levels do
				local lw = `{where} level {n}`
				if type(level) ~= "table" then
					table.insert(problems, `{lw}: must be a table`)
					continue
				end
				for field in level do
					if not LEVEL_FIELDS[field] then
						table.insert(problems, `{lw}: unknown field '{tostring(field)}'`)
					end
				end
				local freeStart = n == 1 and b.prebuilt == true
				local okCost, why = Bundle.validate(level.cost, { currencies = match, allowEmpty = freeStart })
				if not okCost then
					table.insert(problems, `{lw}: cost {why} (match currencies only)`)
				end
				if not isCount(level.buildSec, freeStart) then
					table.insert(problems, `{lw}: buildSec must be a whole number >= 1`)
				end
				for _, field in { "workers", "housing", "storage" } do
					if level[field] ~= nil and not isCount(level[field]) then
						table.insert(problems, `{lw}: {field} must be a whole number >= 1`)
					end
				end
				if level.produces ~= nil then
					local okP, whyP = Bundle.validate(level.produces, { currencies = match })
					if not okP then
						table.insert(problems, `{lw}: produces {whyP}`)
					elseif level.workers == nil then
						table.insert(problems, `{lw}: produces needs workers`)
					end
				end
				checkRequires(level.requires, lw, problems, ids)
			end
		elseif def.kind == "unit" then
			local u = def.unit
			if type(u) ~= "table" then
				table.insert(problems, `{where}: kind "unit" needs a unit table`)
				continue
			end
			for field in u do
				if not UNIT_FIELDS[field] then
					table.insert(problems, `{where}: unit has unknown field '{tostring(field)}'`)
				end
			end
			local okCost, why = Bundle.validate(u.cost, { currencies = match })
			if not okCost then
				table.insert(problems, `{where}: unit cost {why} (match currencies only)`)
			end
			if not isCount(u.trainSec) then
				table.insert(problems, `{where}: trainSec must be a whole number >= 1`)
			end
			if not isCount(u.housing) then
				table.insert(problems, `{where}: unit housing must be a whole number >= 1`)
			end
			checkRequires(u.requires, where, problems, ids)
		elseif def.building ~= nil or def.unit ~= nil then
			table.insert(problems, `{where}: building/unit tables are only allowed on those kinds`)
		end
	end
	return #problems == 0, problems
end

function Construction.new(items: { any }, currencies: any)
	local ok, problems = Construction.validate(items, currencies)
	if not ok then
		error("Construction config invalid:\n  " .. table.concat(problems, "\n  "), 2)
	end
	local buildings, units, byId = {}, {}, {}
	for _, def in items do
		if def.kind == "building" then
			table.insert(buildings, def)
			byId[def.id] = def
		elseif def.kind == "unit" then
			table.insert(units, def)
			byId[def.id] = def
		end
	end
	return setmetatable({
		_buildings = buildings,
		_units = units,
		_byId = byId,
		_currencies = currencies,
		_matchIds = currencies:ids("match"),
	}, Construction)
end

local cached = nil
function Construction.default()
	if cached == nil then
		cached = Construction.new(Items :: any, Currencies.default())
	end
	return cached
end

function Construction:building(id: string): any
	local def = self._byId[id]
	return if def and def.kind == "building" then def else nil
end

function Construction:buildings(category: string?): { any }
	local out = {}
	for _, def in self._buildings do
		if category == nil or def.building.category == category then
			table.insert(out, def)
		end
	end
	return out
end

function Construction:unit(id: string): any
	local def = self._byId[id]
	return if def and def.kind == "unit" then def else nil
end

function Construction:units(): { any }
	return table.clone(self._units)
end

function Construction:level(id: string, level: number): BuildingLevel?
	local def = self:building(id)
	return if def then def.building.levels[level] else nil
end

function Construction:maxLevel(id: string): number
	local def = self:building(id)
	return if def then #def.building.levels else 0
end

function Construction:count(kingdom: KingdomView, id: string): number
	local n = 0
	for _, b in kingdom.buildings do
		if b.buildingId == id then
			n += 1
		end
	end
	return n
end

function Construction:highestLevel(kingdom: KingdomView, id: string): number
	local best = 0
	for _, b in kingdom.buildings do
		if b.buildingId == id and b.level > best then
			best = b.level
		end
	end
	return best
end

function Construction:unmet(kingdom: KingdomView, requires: { Requirement }?): { Requirement }
	local out = {}
	for _, req in requires or {} do
		if self:highestLevel(kingdom, req.building) < req.level then
			table.insert(out, { building = req.building, level = req.level })
		end
	end
	return out
end

local function findUid(kingdom: KingdomView, uid: string): BuildingState?
	for _, b in kingdom.buildings do
		if b.uid == uid then
			return b
		end
	end
	return nil
end

function Construction:check(kingdom: KingdomView, treasury: Bundle, buildingId: string, uid: string?): Check
	local def = self:building(buildingId)
	local result: Check = {
		ok = false,
		action = if uid then "upgrade" else "build",
		buildingId = buildingId,
		uid = uid,
		level = 1,
		cost = {},
		buildSec = 0,
		reason = nil,
		missing = {},
		unmet = {},
		count = 0,
		maxCount = 0,
	}
	if def == nil then
		result.reason = "unknown_building"
		return result
	end
	result.count = self:count(kingdom, buildingId)
	result.maxCount = def.building.maxCount
	local reason: Reason? = nil
	if uid then
		local instance = findUid(kingdom, uid)
		if instance == nil or instance.buildingId ~= buildingId then
			result.reason = "not_found"
			return result
		end
		result.level = instance.level + 1
		if instance.state ~= "ready" then
			reason = "busy"
		end
	elseif result.count >= result.maxCount then
		reason = "limit"
	end
	local levels = def.building.levels
	if result.level > #levels then
		result.level = #levels
		result.reason = reason or "max_level"
		return result
	end
	local level = levels[result.level]
	result.cost = Bundle.copy(level.cost)
	result.buildSec = level.buildSec
	result.unmet = self:unmet(kingdom, level.requires)
	result.missing = Bundle.missing(treasury, level.cost)
	if reason == nil and #result.unmet > 0 then
		reason = "requirement"
	end
	local builders = kingdom.builders
	if reason == nil and builders and builders.busy >= builders.total then
		reason = "builders"
	end
	if reason == nil and next(result.missing) ~= nil then
		reason = "cost"
	end
	result.reason = reason
	result.ok = reason == nil
	return result
end

function Construction:checkUnit(kingdom: KingdomView, treasury: Bundle, unitId: string): Check
	local def = self:unit(unitId)
	local result: Check = {
		ok = false,
		action = "recruit",
		buildingId = unitId,
		level = 1,
		cost = {},
		buildSec = 0,
		reason = nil,
		missing = {},
		unmet = {},
		count = 0,
		maxCount = 0,
	}
	if def == nil then
		result.reason = "unknown_unit"
		return result
	end
	result.cost = Bundle.copy(def.unit.cost)
	result.buildSec = def.unit.trainSec
	result.unmet = self:unmet(kingdom, def.unit.requires)
	result.missing = Bundle.missing(treasury, def.unit.cost)
	if #result.unmet > 0 then
		result.reason = "requirement"
	elseif next(result.missing) ~= nil then
		result.reason = "cost"
	end
	result.ok = result.reason == nil
	return result
end

function Construction:rate(id: string, level: number, workers: number): Bundle
	local lv = self:level(id, level)
	local out = {}
	if lv and lv.produces and workers > 0 then
		local w = math.min(workers, lv.workers or 0)
		for currency, perWorker in lv.produces do
			out[currency] = perWorker * w
		end
	end
	return out
end

function Construction:production(kingdom: KingdomView): Bundle
	local total: Bundle = {}
	for _, b in kingdom.buildings do
		if b.level >= 1 and (b.state == "ready" or b.state == "upgrading") then
			total = Bundle.add(total, self:rate(b.buildingId, b.level, b.workers or 0))
		end
	end
	return total
end

function Construction:housing(kingdom: KingdomView): number
	local total = 0
	for _, b in kingdom.buildings do
		local lv = if b.level >= 1 then self:level(b.buildingId, b.level) else nil
		if lv and lv.housing then
			total += lv.housing
		end
	end
	return total
end

function Construction:storageCaps(kingdom: KingdomView): Bundle
	local extra = 0
	for _, b in kingdom.buildings do
		local lv = if b.level >= 1 then self:level(b.buildingId, b.level) else nil
		if lv and lv.storage then
			extra += lv.storage
		end
	end
	local caps = self._currencies:caps("match")
	for id, cap in caps do
		caps[id] = cap + extra
	end
	return caps
end

return Construction
