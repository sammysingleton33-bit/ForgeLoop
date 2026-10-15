--!strict
--[[
	Sim/Commands — every action a human (or AI) ruler can take, validated server-side.

	Commands are the only way player intent reaches the simulation. RemoteService validates argument
	types and rate-limits before a command gets here; this module re-checks everything semantic
	(ownership, territory, affordability, limits) because commands can also come from other callers
	(RulerAI, tests, admin tools). A rejected command changes nothing and returns an error code the
	client can show.

	API
		Commands.execute(sim, userId, name, ...): (boolean, string?, any?)
			-> (true, nil, result) or (false, errorCode)
		Commands.executeFor(sim, kingdom, by, name, ...)   -- same, for a kingdom directly (AI rulers)
		Commands.NAMES: { string }                         -- the built-in commands below
		Commands.install(sim, name, fn(sim, kingdom, by, ...) -> (boolean, string?, any?))
			-- per-simulation extra commands (Military, Diplomacy install theirs); duplicates error
		Commands.namesFor(sim): { string }                 -- built-ins + installed, sorted

	Commands (args)                         result on success
		PlaceBuilding(kind, x, z, yaw?)      { buildingId }        -- yaw: facing in radians (default: towards the keep)
		UpgradeBuilding(buildingId)          { buildingId, level }
		CancelConstruction(buildingId)       { buildingId }
		SetJobQuota(job, count)              { job, count }           -- 0..200; hauler is the pool (no quota)
		SetPriority(resource, weight)        { resource, weight }     -- integer 0..3
		SetAlarm(on)                         { on }                   -- citizens shelter in the keep
		(+ Recruit, ArmyOrder from Military; DeclareWar, ProposePeace, AcceptPeace from Diplomacy)

	Error codes: match_not_active, not_ruler, kingdom_eliminated, unknown_command, invalid_args,
	unknown_building, not_placeable, requires_keep_level, limit_reached, out_of_bounds,
	out_of_territory, blocked, cannot_afford, not_found, not_owner, busy, max_level,
	nothing_to_cancel, unknown_job, unknown_resource (+ those of registered commands).
	Building ids are positive integers (CONTRACTS G2); building kinds and jobs are contract ids.
]]

local Catalog = require("./Catalog")

type Handler = (sim: any, kingdom: any, by: number?, ...any) -> (boolean, string?, any?)

local Commands = {}

local MAX_COORD = 100000
local MAX_ID_LENGTH = 16

local handlers: { [string]: Handler } = {}
local names: { string } = {}

local function finite(v: any): boolean
	return type(v) == "number" and v == v and math.abs(v) < MAX_COORD
end

local function isBuildingId(v: any): boolean
	return type(v) == "number" and v == v and v >= 1 and v <= 1e9 and math.floor(v) == v
end

local function isId(v: any): boolean
	return type(v) == "string" and #v >= 1 and #v <= MAX_ID_LENGTH
end

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and math.floor(v) == v and v >= lo and v <= hi
end

local function register(name: string, fn: Handler)
	handlers[name] = fn
	table.insert(names, name)
end

function Commands.install(sim: any, name: string, fn: Handler)
	assert(type(name) == "string" and type(fn) == "function", "Commands.install(sim, name, fn)")
	sim.extraCommands = sim.extraCommands or {}
	if handlers[name] ~= nil or sim.extraCommands[name] ~= nil then
		error(`Commands.install: '{name}' already exists`, 2)
	end
	sim.extraCommands[name] = fn
end

function Commands.namesFor(sim: any): { string }
	local out = table.clone(names)
	for name in sim.extraCommands or {} do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

register("PlaceBuilding", function(sim, kingdom, by, kind, x, z, yaw)
	if not isId(kind) or not finite(x) or not finite(z) or (yaw ~= nil and not finite(yaw)) then
		return false, "invalid_args"
	end
	local building, err = sim:placeBuilding(kingdom, kind, x, z, by, yaw)
	if building == nil then
		return false, err
	end
	return true, nil, { buildingId = building.id }
end)

register("UpgradeBuilding", function(sim, kingdom, by, buildingId)
	if not isBuildingId(buildingId) then
		return false, "invalid_args"
	end
	local ok, err = sim:startUpgrade(kingdom, buildingId, by)
	if not ok then
		return false, err
	end
	return true, nil, { buildingId = buildingId, level = sim.buildings[buildingId].pendingLevel }
end)

register("CancelConstruction", function(sim, kingdom, by, buildingId)
	if not isBuildingId(buildingId) then
		return false, "invalid_args"
	end
	local ok, err = sim:cancelConstruction(kingdom, buildingId, by)
	if not ok then
		return false, err
	end
	return true, nil, { buildingId = buildingId }
end)

register("SetJobQuota", function(sim, kingdom, _by, job, count)
	if not isId(job) or not isInt(count, 0, 200) then
		return false, "invalid_args"
	end
	if sim.catalog.jobs[job] == nil or job == "hauler" then
		return false, "unknown_job"
	end
	kingdom.quotas[job] = count
	-- every accepted change counts, even to the same number: a co-ruler's panel sees it was answered (#71)
	kingdom.quotaRev = (kingdom.quotaRev or 0) + 1
	return true, nil, { job = job, count = count }
end)

register("SetPriority", function(_sim, kingdom, _by, resource, weight)
	if not isId(resource) or not isInt(weight, 0, 3) then
		return false, "invalid_args"
	end
	if not Catalog.isResource(resource) then
		return false, "unknown_resource"
	end
	kingdom.priorities[resource] = weight
	return true, nil, { resource = resource, weight = weight }
end)

register("SetAlarm", function(sim, kingdom, by, on)
	if type(on) ~= "boolean" then
		return false, "invalid_args"
	end
	if kingdom.alarm ~= on then
		kingdom.alarm = on
		sim:emit("AlarmChanged", { kingdomId = kingdom.id, on = on, by = by })
	end
	return true, nil, { on = on }
end)

function Commands.executeFor(sim: any, kingdom: any, by: number?, name: any, ...: any): (boolean, string?, any?)
	if not sim.active then
		return false, "match_not_active"
	end
	if not kingdom.alive then
		return false, "kingdom_eliminated"
	end
	local handler = nil
	if type(name) == "string" then
		handler = handlers[name] or (sim.extraCommands and sim.extraCommands[name])
	end
	if handler == nil then
		return false, "unknown_command"
	end
	return handler(sim, kingdom, by, ...)
end

function Commands.execute(sim: any, userId: number, name: any, ...: any): (boolean, string?, any?)
	local kingdom = sim:kingdomOfUser(userId)
	if kingdom == nil then
		return false, "not_ruler"
	end
	return Commands.executeFor(sim, kingdom, userId, name, ...)
end

Commands.NAMES = names

return Commands
