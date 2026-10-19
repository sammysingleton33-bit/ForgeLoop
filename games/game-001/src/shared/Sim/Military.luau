--!strict
--[[
	Sim/Military — recruitment, army orders, unit combat, defensive fire and conquest.

	Installed into a Simulation as a system plus three commands:
		Military.install(sim)
		Recruit(unitKind, count, barracksId?) -> { barracksId, count }   errors: unknown_unit, invalid_args,
		                                      no_barracks, army_cap (the kingdom already has config
		                                      Military.maxSoldiers standing soldiers, living + training, D-055),
		                                      recruit_cap (no free bunks: soldiers sleep in the
		                                      barracks, D-041), cannot_afford; with a
		                                      barracksId also not_found, not_owner, not_barracks,
		                                      barracks_not_ready (still being built), requires_barracks_level
		                                      (that level does not train the unit). Without one: the standing
		                                      barracks with the shortest queue that trains the unit.
		ArmyOrder(order, a?, b?)           -> { order }               every unit of the kingdom; errors:
		                                      invalid_args, not_at_war, unknown_kingdom
			order "Defend"                  hold the territory around the keep (default for new units)
			order "Hold"                    stop where they stand, fight what comes in range
			order "Move", x, z              march to a point
			order "Attack", kingdomId       march on that kingdom's keep (requires war)
		UnitOrder(unitIds, kind, x?, z?, targetId?) -> { kind, count, ignored }   CONTRACTS G8 Army.Command
			unitIds  up to MAX_ORDER_UNITS EntityIds; ids that are not this kingdom's living units are
			         ignored (counted in `ignored`); empty = every idle unit of the kingdom (Defend, Hold
			         or Guard and not fighting, or a Move that has arrived)
			"move", x, z              march to the point (several units spread around it)
			"attack", targetId        a KingdomId (march on its keep), "building:<id>" or "entity:<id>"
			                          (chase that enemy wherever it goes; afterwards guard where they stand)
			"capture", targetId?      an objective id, or none: the objective nearest the units' centroid
			                          that the kingdom does not own (the VS-1 Send-to-capture button). March
			                          into its zone, around its tower, and hold there (Sim/Objectives counts
			                          them), fighting only near the zone; once the kingdom owns the objective
			                          each unit guards its spot in the zone (a Guard order: idle again)
			"guard", x?, z?           hold and defend the point (default: where each unit stands); they
			                          fight within GUARD_RADIUS of it and return
			A point (x, z) must lie inside sim.bounds (the map); units spread around one stay on the map.
			errors: invalid_args, too_many_units, unknown_order, out_of_bounds, no_units, unknown_objective,
			no_objective (capture without a target when the kingdom owns every objective), unknown_target,
			unknown_kingdom, not_at_war (also for one's own target)

	Combat rules (deterministic, no randomness)
		- Only kingdoms at war fight (Simulation:atWar). Units pick the nearest enemy within aggro
		  range (weapon range + 30): units first, then citizens outside shelter, then buildings.
		  Siege units (attacksUnits = false) only target buildings. Targets are sticky while in reach.
		  Defend, Guard and Capture units only take targets on the ground they hold (territory + 25,
		  GUARD_RADIUS around the point, the zone + 25); an attack order's focus is chased at any range.
		- A unit out of weapon range closes in and strikes in the same tick once in range, so a target
		  that keeps moving away (a fleeing citizen) can still be caught. Hold units never move: they
		  only strike what is already within weapon range.
		- Damage to buildings is multiplied by the unit's `siege` value (Ram x4).
		- Soft blocking: a unit whose next step would enter an enemy building's footprint attacks that
		  building instead (walls hold armies until broken). Full navigation comes with pathfinding.
		- Keeps and Towers shoot the nearest enemy unit in range (catalog `attack`).
		- Citizens sheltering in their keep (Flee or Sleep, resting) cannot be attacked.
		- A destroyed Keep eliminates its kingdom: its citizens, units and buildings are removed, the
		  conqueror loots half of its treasury and gains a conquest (Crown Points: Catalog.crown.conquest).
		- Each enemy unit killed is worth Catalog.crown.unitKill Crown Points.
	Threats: before citizens think, each kingdom's `threats` lists enemy units inside its territory
	(+30 studs); CitizenBrain uses it to flee and remember danger.

	Rally: a trained unit appears at its barracks' Rally, the Kit barracks attachment at local
	(0, 0, -depth/2 - 10) (in front, along the building's yaw), spread sideways in rows of RALLY_ROW.

	Events: RecruitQueued { kingdomId, unit, count, barracksId, by } · UnitRecruited { kingdomId, unitId, unit }
		ArmyOrdered { kingdomId, order, by } · UnitsOrdered { kingdomId, kind, count, by }
		UnitKilled { kingdomId, unitId, unit, byKingdomId }
		BuildingDestroyed { kingdomId, buildingId, kind, byKingdomId }
		KingdomEliminated { kingdomId, byKingdomId, loot }
		SiegeChanged / RaidChanged (Sim/WarWatch): one event per start and per end of a siege on the keep / enemies inside the territory
	API (besides the commands)
		Military.spawnUnit(sim, kingdom, kind, x, z): Unit      -- also used by specs
		Military.rallyPoint(barracks, slot): (x, z)             -- slot 0 = the Rally itself, then sideways
		Military.isIdle(unit): boolean                          -- what an empty UnitOrder selects
		Military.destroyBuilding(sim, building, byKingdomId?), Military.eliminate(sim, kingdom, byKingdomId?)
		Military.AGGRO_EXTRA, Military.UNIT_RADIUS, Military.MAX_ORDER_UNITS, Military.GUARD_RADIUS
]]

local Kit = require("../Kit/Kit")
local Commands = require("./Commands")
local Nav = require("./Nav")
local WarWatch = require("./WarWatch")

local Military = {}

Military.AGGRO_EXTRA = 30
Military.UNIT_RADIUS = 1.5
Military.MAX_ORDER_UNITS = 50 -- CONTRACTS G8 Army.Command array(integer, 50)
Military.GUARD_RADIUS = 25
local STICKY_FACTOR = 1.5
local DEFEND_RADIUS = 25
-- moveUnit stops exactly at weapon range; floating-point error can leave that a hair outside it
local REACH_EPSILON = 1e-6
local ORDERS = { Defend = true, Hold = true, Move = true, Attack = true }
local UNIT_ORDERS = { move = true, attack = true, capture = true, guard = true }
local MOVE_STOP = 2 -- a Move order stops this far from its point
local SPREAD = 3 -- studs between units sent to one point (sunflower spiral)
local GOLDEN_ANGLE = 2.399963
local RALLY_AHEAD = 10 -- Kit barracks Rally: local (0, 0, -depth/2 - 10), depth = footprint Y - 2
local RALLY_ROW = 7 -- units side by side at the Rally before a second row starts
local MAX_ENTITY_ID = 65535 -- G2 EntityId (u16 on the wire)
local CAPTURE_REACH = 0.8 -- capturers stand at most this fraction of the zone radius from its centre
-- capturers stand clear of the objective's Kit watchtower (half its longer side + 2 studs)
local TOWER_FOOTPRINT = Kit.footprint("watchtower", 1)
local TOWER_CLEARANCE = math.max(TOWER_FOOTPRINT.X, TOWER_FOOTPRINT.Y) / 2 + 2

local function dist(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v == v and math.floor(v) == v and v >= lo and v <= hi
end

local function finite(v: any): boolean
	return type(v) == "number" and v == v and math.abs(v) < 100000
end

function Military.spawnUnit(sim: any, kingdom: any, kind: string, x: number, z: number)
	local def = sim.catalog.units[kind]
	assert(def ~= nil, `spawnUnit: unknown unit '{kind}'`)
	local unit = {
		id = sim:newEntityId(),
		entityKind = "soldier",
		kind = kind,
		kingdomId = kingdom.id,
		x = x,
		z = z,
		hp = def.hp,
		maxHp = def.hp,
		cooldown = 0,
		order = { kind = "Defend" } :: { [string]: any },
		target = nil :: { kind: string, id: number }?,
		alive = true,
	}
	sim.units[unit.id] = unit
	table.insert(sim.unitOrder, unit.id)
	table.insert(kingdom.unitIds, unit.id)
	return unit
end

local function queuedCount(sim: any, kingdom: any): number
	local n = 0
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if b.kind == "barracks" then
			n += #b.queue
		end
	end
	return n
end

-- Bunks (D-041): soldiers (living + training) fit in the kingdom's standing barracks (Simulation:bunks)
local function recruitCap(sim: any, kingdom: any): number
	return sim:bunks(kingdom)
end

Military.recruitCap = recruitCap

-- D-055 (1): the most standing soldiers a kingdom may have, bunks aside (config Military.maxSoldiers)
local function armyCap(sim: any): number
	return sim.catalog.tuning.maxSoldiers or math.huge
end

Military.armyCap = armyCap

-- A standing barracks whose level trains `kind`: at least the unit's requiresBarracksLevel and, when the
-- level lists `trains` (Buildings.luau), named there.
local function trainsAt(sim: any, b: any, kind: string, def: any): boolean
	if b.kind ~= "barracks" or b.destroyed or b.level < 1 or b.level < def.requiresBarracksLevel then
		return false
	end
	local trains = sim.catalog.buildings.barracks.levels[b.level].trains
	return trains == nil or table.find(trains, kind) ~= nil
end

-- The barracks a Recruit trains at: the one asked for (it must be the kingdom's, standing and able to
-- train the unit), else the standing one with the shortest queue.
local function pickBarracks(sim: any, kingdom: any, kind: string, def: any, barracksId: number?): (any?, string?)
	if barracksId ~= nil then
		local b, err = sim:_ownedBuilding(kingdom, barracksId)
		if b == nil then
			return nil, err
		end
		if b.kind ~= "barracks" then
			return nil, "not_barracks"
		end
		if b.level < 1 then
			return nil, "barracks_not_ready"
		end
		if not trainsAt(sim, b, kind, def) then
			return nil, "requires_barracks_level"
		end
		return b, nil
	end
	local best = nil
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if trainsAt(sim, b, kind, def) and (best == nil or #b.queue < #best.queue) then
			best = b
		end
	end
	if best == nil then
		return nil, "no_barracks"
	end
	return best, nil
end

local function recruit(
	sim: any,
	kingdom: any,
	by: number?,
	kind: any,
	count: any,
	barracksId: any
): (boolean, string?, any?)
	if type(kind) ~= "string" or not isInt(count, 1, 10) then
		return false, "invalid_args"
	end
	if barracksId ~= nil and not isInt(barracksId, 1, 1e9) then
		return false, "invalid_args"
	end
	local def = sim.catalog.units[kind]
	if def == nil then
		return false, "unknown_unit"
	end
	local best, refused = pickBarracks(sim, kingdom, kind, def, barracksId)
	if best == nil then
		return false, refused
	end
	if #kingdom.unitIds + queuedCount(sim, kingdom) + count > armyCap(sim) then
		return false, "army_cap" -- D-055: the army this server can carry
	end
	if #kingdom.unitIds + queuedCount(sim, kingdom) + count > recruitCap(sim, kingdom) then
		return false, "recruit_cap"
	end
	local price = sim.costs.unit(kind)
	if price == nil then
		return false, "unknown_unit"
	end
	local total = {}
	for res, amount in price.cost do
		total[res] = amount * count
	end
	sim.recruitSeq = (sim.recruitSeq or 0) + 1
	if not sim:spend(kingdom.id, total, `recruit:{best.id}:{sim.recruitSeq}`, `unit:{kind}`) then
		return false, "cannot_afford"
	end
	local speed = sim.catalog.buildings.barracks.levels[best.level].trainSpeed or 1
	for _ = 1, count do
		table.insert(best.queue, { unit = kind, remaining = price.trainSeconds / speed })
	end
	sim:emit("RecruitQueued", { kingdomId = kingdom.id, unit = kind, count = count, barracksId = best.id, by = by })
	return true, nil, { barracksId = best.id, count = count }
end

local function armyOrder(sim: any, kingdom: any, by: number?, order: any, a: any, b: any): (boolean, string?, any?)
	if type(order) ~= "string" or not ORDERS[order] then
		return false, "invalid_args"
	end
	local newOrder: { [string]: any } = { kind = order }
	if order == "Move" then
		if not finite(a) or not finite(b) then
			return false, "invalid_args"
		end
		newOrder.x, newOrder.z = a, b
	elseif order == "Attack" then
		if type(a) ~= "string" then
			return false, "invalid_args"
		end
		local target = sim.kingdoms[a]
		if target == nil or not target.alive or a == kingdom.id then
			return false, "unknown_kingdom"
		end
		if not sim:atWar(kingdom.id, a) then
			return false, "not_at_war"
		end
		newOrder.kingdomId = a
	end
	for _, uid in kingdom.unitIds do
		local u = sim.units[uid]
		u.order = table.clone(newOrder)
		u.target = nil
	end
	sim:emit("ArmyOrdered", { kingdomId = kingdom.id, order = order, by = by })
	return true, nil, { order = order }
end

-- ---------------------------------------------------------------- unit orders (G8 Army.Command)
local function objectiveOf(sim: any, id: any): any?
	for _, o in (sim.objectives and sim.objectives.list) or {} do
		if o.id == id then
			return o
		end
	end
	return nil
end

-- The objective nearest the units' centroid that `kingdomId` does not own (the first listed on a tie).
local function nearestUnowned(sim: any, kingdomId: string, units: { any }): any?
	local cx, cz = 0, 0
	for _, u in units do
		cx += u.x
		cz += u.z
	end
	cx, cz = cx / #units, cz / #units
	local best, bestDistance = nil, math.huge
	for _, o in (sim.objectives and sim.objectives.list) or {} do
		if o.owner ~= kingdomId then
			local d = dist(cx, cz, o.x, o.z)
			if d < bestDistance then
				best, bestDistance = o, d
			end
		end
	end
	return best
end

local function onMap(sim: any, x: number, z: number): boolean
	local b = sim.bounds
	return x >= b.minX and x <= b.maxX and z >= b.minZ and z <= b.maxZ
end

-- (x, z) moved onto the map (sim.bounds) if it lies outside
local function clampToMap(sim: any, x: number, z: number): (number, number)
	local b = sim.bounds
	return math.clamp(x, b.minX, b.maxX), math.clamp(z, b.minZ, b.maxZ)
end

-- Not busy: at home (Defend), holding or guarding without a fight, or done with a Move. (A Capture
-- turns into a Guard once the kingdom owns the objective: stepUnits.)
function Military.isIdle(u: any): boolean
	if not u.alive or u.target ~= nil then
		return false
	end
	local order = u.order
	if order.kind == "Defend" or order.kind == "Hold" or order.kind == "Guard" then
		return true
	end
	return order.kind == "Move" and dist(u.x, u.z, order.x, order.z) <= MOVE_STOP + REACH_EPSILON
end

-- The i-th (0-based) of several units sent to one point: a sunflower spiral starting `inner` studs out
-- (0: on the point itself), at most `outer` out.
local function spread(x: number, z: number, i: number, inner: number, outer: number): (number, number)
	local r = math.min(inner + SPREAD * math.sqrt(i), outer)
	if r <= 0 then
		return x, z
	end
	return x + math.cos(i * GOLDEN_ANGLE) * r, z + math.sin(i * GOLDEN_ANGLE) * r
end

-- A UnitOrder unit list: (ids, nil) or (nil, error). Up to MAX_ORDER_UNITS positive integers.
local function idList(value: any): ({ number }?, string?)
	if type(value) ~= "table" then
		return nil, "invalid_args"
	end
	local n = 0
	for key, id in value do
		n += 1
		if n > Military.MAX_ORDER_UNITS then
			return nil, "too_many_units"
		end
		if type(key) ~= "number" or not isInt(id, 1, MAX_ENTITY_ID) then
			return nil, "invalid_args"
		end
	end
	if n ~= #value then
		return nil, "invalid_args"
	end
	return value, nil
end

-- The units a UnitOrder moves: the kingdom's living ones among `ids` (others are counted as ignored),
-- or every idle one when `ids` is empty.
local function orderedUnits(sim: any, kingdom: any, ids: { number }): ({ any }, number)
	local units, ignored = {}, 0
	if #ids == 0 then
		for _, uid in kingdom.unitIds do
			local u = sim.units[uid]
			if u and Military.isIdle(u) then
				table.insert(units, u)
			end
		end
		return units, 0
	end
	local seen: { [number]: boolean } = {}
	for _, uid in ids do
		if seen[uid] then
			continue
		end
		seen[uid] = true
		local u = sim.units[uid]
		if u and u.alive and u.kingdomId == kingdom.id then
			table.insert(units, u)
		else
			ignored += 1
		end
	end
	return units, ignored
end

-- An attack target: a KingdomId, "building:<id>" or "entity:<id>". Returns (kingdomId, focus?) or
-- (nil, nil, error). Only enemies at war qualify.
local function attackTarget(sim: any, kingdom: any, targetId: any): (string?, { kind: string, id: number }?, string?)
	if type(targetId) ~= "string" then
		return nil, nil, "invalid_args"
	end
	local target = sim.kingdoms[targetId]
	if target then
		if not target.alive or targetId == kingdom.id then
			return nil, nil, "unknown_kingdom"
		end
		if not sim:atWar(kingdom.id, targetId) then
			return nil, nil, "not_at_war"
		end
		return targetId, nil, nil
	end
	local prefix, digits = string.match(targetId, "^(%a+):(%d+)$")
	local id = tonumber(digits)
	local record, kind = nil, nil
	if prefix == "building" and id then
		local b = sim.buildings[id]
		if b and not b.destroyed then
			record, kind = b, "building"
		end
	elseif prefix == "entity" and id then
		if sim.units[id] then
			record, kind = sim.units[id], "unit"
		elseif sim.citizens[id] then
			record, kind = sim.citizens[id], "citizen"
		end
	end
	if record == nil or kind == nil then
		return nil, nil, "unknown_target"
	end
	if not sim:atWar(kingdom.id, record.kingdomId) then
		return nil, nil, "not_at_war"
	end
	return nil, { kind = kind, id = record.id }, nil
end

local function unitOrder(
	sim: any,
	kingdom: any,
	by: number?,
	unitIds: any,
	kind: any,
	x: any,
	z: any,
	targetId: any
): (boolean, string?, any?)
	local ids, err = idList(unitIds)
	if ids == nil then
		return false, err
	end
	if type(kind) ~= "string" then
		return false, "invalid_args"
	end
	if not UNIT_ORDERS[kind] then
		return false, "unknown_order"
	end
	local hasPoint = x ~= nil or z ~= nil
	if hasPoint and (not finite(x) or not finite(z)) then
		return false, "invalid_args"
	end
	if hasPoint and not onMap(sim, x, z) then
		return false, "out_of_bounds"
	end
	if targetId ~= nil and type(targetId) ~= "string" then
		return false, "invalid_args"
	end
	-- the order for the i-th commanded unit (0-based)
	local orderFor: (u: any, i: number) -> { [string]: any }
	local objective: any? = nil -- capture: the objective to take
	if kind == "move" then
		if not hasPoint then
			return false, "invalid_args"
		end
		orderFor = function(_u, i)
			local px, pz = clampToMap(sim, spread(x, z, i, 0, math.huge))
			return { kind = "Move", x = px, z = pz }
		end
	elseif kind == "guard" then
		orderFor = function(u, i)
			if not hasPoint then
				return { kind = "Guard", x = u.x, z = u.z }
			end
			local px, pz = clampToMap(sim, spread(x, z, i, 0, math.huge))
			return { kind = "Guard", x = px, z = pz }
		end
	elseif kind == "capture" then
		if targetId ~= nil then
			objective = objectiveOf(sim, targetId)
			if objective == nil then
				return false, "unknown_objective"
			end
		end
		orderFor = function(_u, i)
			-- around the tower that stands on the point (ObjectiveService), well inside the zone
			local o = objective :: any
			local outer = o.radius * CAPTURE_REACH
			local px, pz = spread(o.x, o.z, i, math.min(TOWER_CLEARANCE, outer), outer)
			return { kind = "Capture", objectiveId = o.id, x = px, z = pz }
		end
	else
		local targetKingdom, focus, refused = attackTarget(sim, kingdom, targetId)
		if refused then
			return false, refused
		end
		orderFor = function(_u, _i)
			return { kind = "Attack", kingdomId = targetKingdom, focus = focus and table.clone(focus) }
		end
	end
	local units, ignored = orderedUnits(sim, kingdom, ids)
	if #units == 0 then
		return false, "no_units"
	end
	if kind == "capture" and objective == nil then
		-- no target (Send-to-capture): the nearest objective the kingdom does not hold; none = no change
		objective = nearestUnowned(sim, kingdom.id, units)
		if objective == nil then
			return false, "no_objective"
		end
	end
	for i, u in units do
		u.order = orderFor(u, i - 1)
		u.target = if u.order.focus then table.clone(u.order.focus) else nil
	end
	sim:emit("UnitsOrdered", { kingdomId = kingdom.id, kind = kind, count = #units, by = by })
	return true, nil, { kind = kind, count = #units, ignored = ignored }
end

-- ---------------------------------------------------------------- deaths and destruction
local function killUnit(sim: any, u: any, byKingdomId: string?)
	if not u.alive then
		return
	end
	u.alive = false
	local owner = sim.kingdoms[u.kingdomId]
	local i = table.find(owner.unitIds, u.id)
	if i then
		table.remove(owner.unitIds, i)
	end
	local j = table.find(sim.unitOrder, u.id)
	if j then
		table.remove(sim.unitOrder, j)
	end
	sim.units[u.id] = nil
	owner.stats.unitsLost += 1
	if byKingdomId and sim.kingdoms[byKingdomId] then
		sim.kingdoms[byKingdomId].stats.unitsKilled += 1
		sim:addCrownPoints(byKingdomId, sim.catalog.crown.unitKill, "kill")
	end
	sim:emit("UnitKilled", { kingdomId = owner.id, unitId = u.id, unit = u.kind, byKingdomId = byKingdomId })
end

local function eliminate(sim: any, kingdom: any, byKingdomId: string?)
	kingdom.alive = false
	kingdom.eliminatedAt = sim.time
	kingdom.eliminatedBy = byKingdomId
	kingdom.alarm = false
	kingdom.threats = {}
	local loot = {}
	local conqueror = byKingdomId and sim.kingdoms[byKingdomId]
	if conqueror then
		conqueror.stats.conquered += 1
		sim:addCrownPoints(conqueror.id, sim.catalog.crown.conquest, `conquest:{kingdom.id}`)
		for _, res in sim.catalog.resources do
			local amount = math.floor(sim:balance(kingdom.id, res) / 2)
			if amount > 0 then
				sim:deposit(conqueror.id, res, amount, `loot:{kingdom.id}:{res}`, "loot")
				loot[res] = amount
			end
		end
	end
	for _, res in sim.catalog.resources do
		local left = sim:balance(kingdom.id, res)
		if left > 0 then
			sim:spend(kingdom.id, { [res] = left }, `plunder:{kingdom.id}:{res}`, "plunder")
		end
	end
	-- remove everything the kingdom had, without per-entity events (one KingdomEliminated instead)
	for _, cid in table.clone(kingdom.citizenIds) do
		local c = sim.citizens[cid]
		sim:releaseClaim(c)
		c.alive = false
		sim.citizens[cid] = nil
		local j = table.find(sim.citizenOrder, cid)
		if j then
			table.remove(sim.citizenOrder, j)
		end
	end
	table.clear(kingdom.citizenIds)
	for _, uid in table.clone(kingdom.unitIds) do
		local u = sim.units[uid]
		u.alive = false
		sim.units[uid] = nil
		local j = table.find(sim.unitOrder, uid)
		if j then
			table.remove(sim.unitOrder, j)
		end
	end
	table.clear(kingdom.unitIds)
	for _, bid in table.clone(kingdom.buildingIds) do
		local b = sim.buildings[bid]
		b.destroyed = true
		sim.buildings[bid] = nil
		local j = table.find(sim.buildingOrder, bid)
		if j then
			table.remove(sim.buildingOrder, j)
		end
	end
	table.clear(kingdom.buildingIds)
	for _, other in sim.kingdomOrder do
		if other ~= kingdom.id then
			sim.relations[sim:relationKey(other, kingdom.id)] = "Peace"
		end
	end
	sim:emit("KingdomEliminated", { kingdomId = kingdom.id, byKingdomId = byKingdomId, loot = loot })
end

local function destroyBuilding(sim: any, b: any, byKingdomId: string?)
	if b.destroyed then
		return
	end
	local kingdom = sim.kingdoms[b.kingdomId]
	if b.kind == "keep" then
		eliminate(sim, kingdom, byKingdomId)
		return
	end
	sim:_removeBuilding(b)
	sim:emit("BuildingDestroyed", {
		kingdomId = kingdom.id,
		buildingId = b.id,
		kind = b.kind,
		byKingdomId = byKingdomId,
		building = sim:viewOf(b), -- G2 view with state "destroyed" (GameEvents.BuildingDestroyed)
	})
end

-- ---------------------------------------------------------------- targeting
local function sheltered(sim: any, c: any): boolean
	if c.phase ~= "Rest" or (c.activity ~= "Flee" and c.activity ~= "Sleep") then
		return false
	end
	local kingdom = sim.kingdoms[c.kingdomId]
	return c.target == kingdom.keepId or c.target == nil
end

-- Targets are { kind, id }: units and citizens share the EntityId space, buildings have their own.
local function resolveTarget(sim: any, target: { kind: string, id: number }?): (any?, string?)
	if target == nil then
		return nil, nil
	end
	if target.kind == "unit" then
		return sim.units[target.id], "unit"
	elseif target.kind == "citizen" then
		return sim.citizens[target.id], "citizen"
	elseif target.kind == "building" then
		local b = sim.buildings[target.id]
		return if b and not b.destroyed then b else nil, "building"
	end
	return nil, nil
end

local function targetRadius(target: any, kind: string?): number
	return if kind == "building" then target.footprint else 0
end

type Leash = { x: number, z: number, r: number }

-- A target position lies on the ground a unit holds (no leash: anywhere).
local function inside(held: Leash?, t: any): boolean
	return held == nil or dist(t.x, t.z, held.x, held.z) <= held.r
end

-- The unit's target: the sticky one, else the nearest enemy in aggro range on the ground it holds.
local function acquire(sim: any, u: any, def: any, held: Leash?): (any?, string?)
	local aggro = def.range + Military.AGGRO_EXTRA
	-- an attack order's focus is the target whenever nothing else (a blocking wall) is; siege units
	-- (attacksUnits = false) can only focus on buildings
	local focus = u.order.focus
	if focus and focus.kind ~= "building" and not def.attacksUnits then
		focus = nil
	end
	if u.target == nil and focus then
		u.target = { kind = focus.kind, id = focus.id }
	end
	-- sticky: keep the current target while it is valid and still within reach (the focus at any range);
	-- a wall in the way is fought wherever it stands, or the unit would never get past it
	local current, currentKind = resolveTarget(sim, u.target)
	if current and sim:atWar(u.kingdomId, current.kingdomId) then
		local reach = aggro * STICKY_FACTOR + targetRadius(current, currentKind)
		local valid = currentKind ~= "citizen" or not sheltered(sim, current)
		local focused = focus ~= nil and focus.kind == currentKind and focus.id == current.id
		local onGround = (u.target :: any).blocker == true or inside(held, current)
		if valid and onGround and (focused or dist(u.x, u.z, current.x, current.z) <= reach) then
			return current, currentKind
		end
	end
	u.target = nil
	local best, bestKind, bestDistance = nil, nil, math.huge
	for _, kid in sim.kingdomOrder do
		local enemy = sim.kingdoms[kid]
		if not enemy.alive or not sim:atWar(u.kingdomId, kid) then
			continue
		end
		if def.attacksUnits then
			for _, uid in enemy.unitIds do
				local e = sim.units[uid]
				local d = dist(u.x, u.z, e.x, e.z)
				if d <= aggro and d < bestDistance and inside(held, e) then
					best, bestKind, bestDistance = e, "unit", d
				end
			end
		end
	end
	if best == nil and def.attacksUnits then
		for _, kid in sim.kingdomOrder do
			local enemy = sim.kingdoms[kid]
			if not enemy.alive or not sim:atWar(u.kingdomId, kid) then
				continue
			end
			for _, cid in enemy.citizenIds do
				local c = sim.citizens[cid]
				local d = dist(u.x, u.z, c.x, c.z)
				if d <= aggro and d < bestDistance and not sheltered(sim, c) and inside(held, c) then
					best, bestKind, bestDistance = c, "citizen", d
				end
			end
		end
	end
	if best == nil then
		for _, kid in sim.kingdomOrder do
			local enemy = sim.kingdoms[kid]
			if not enemy.alive or not sim:atWar(u.kingdomId, kid) then
				continue
			end
			for _, bid in enemy.buildingIds do
				local b = sim.buildings[bid]
				local d = dist(u.x, u.z, b.x, b.z) - b.footprint
				if d <= aggro and d < bestDistance and inside(held, b) then
					best, bestKind, bestDistance = b, "building", d
				end
			end
		end
	end
	if best then
		u.target = { kind = bestKind :: string, id = best.id }
	end
	return best, bestKind
end

-- Moves a unit toward (x, z), stopping `stopAt` short. Returns a blocking enemy building, if any.
local function moveUnit(sim: any, u: any, def: any, x: number, z: number, stopAt: number, dt: number): any?
	local d = dist(u.x, u.z, x, z)
	if d <= stopAt then
		return nil
	end
	local wx, wz = Nav.waypoint(sim, u, x, z) -- long marches follow roads and bridges (Sim/Nav)
	local nx, nz
	if wx ~= x or wz ~= z then
		local dw = dist(u.x, u.z, wx, wz)
		local f = if dw > 0 then math.min(1, def.speed * dt / dw) else 0
		nx, nz = u.x + (wx - u.x) * f, u.z + (wz - u.z) * f
	else
		local stepLen = math.min(def.speed * dt, d - stopAt)
		nx = u.x + (x - u.x) / d * stepLen
		nz = u.z + (z - u.z) / d * stepLen
	end
	for _, kid in sim.kingdomOrder do
		local enemy = sim.kingdoms[kid]
		if enemy.alive and sim:atWar(u.kingdomId, kid) then
			for _, bid in enemy.buildingIds do
				local b = sim.buildings[bid]
				if dist(nx, nz, b.x, b.z) < b.footprint + Military.UNIT_RADIUS then
					return b
				end
			end
		end
	end
	u.x, u.z = nx, nz
	return nil
end

local function hit(sim: any, u: any, def: any, target: any, kind: string)
	if kind == "unit" then
		target.hp -= def.damage
		if target.hp <= 0 then
			killUnit(sim, target, u.kingdomId)
		end
	elseif kind == "citizen" then
		target.hp -= def.damage
		if target.hp <= 0 then
			sim:killCitizen(target, "raid")
		end
	else
		target.hp -= math.floor(def.damage * def.siege + 0.5)
		target.damagedAt = sim.time -- a building hit lately can't be moved out of reach (G13.9)
		WarWatch.keepHit(sim, target, u.kingdomId)
		if target.hp <= 0 then
			destroyBuilding(sim, target, u.kingdomId)
		end
	end
end

local function orderDestination(sim: any, u: any): (number?, number?, number)
	local kingdom = sim.kingdoms[u.kingdomId]
	local order = u.order
	if order.kind == "Hold" then
		return nil, nil, 0
	elseif order.kind == "Move" then
		return order.x, order.z, MOVE_STOP
	elseif order.kind == "Guard" then
		return order.x, order.z, 1
	elseif order.kind == "Capture" then
		if objectiveOf(sim, order.objectiveId) then
			return order.x, order.z, 1 -- a spot inside the zone; Sim/Objectives counts the unit there
		end
		u.order = { kind = "Guard", x = u.x, z = u.z }
		return nil, nil, 0
	elseif order.kind == "Attack" and order.focus then
		-- the focus is out of sight (a sheltered citizen) or gone: go to it, or guard where they stand
		local focus, focusKind = resolveTarget(sim, order.focus)
		if focus and sim:atWar(u.kingdomId, focus.kingdomId) then
			return focus.x, focus.z, targetRadius(focus, focusKind) + 2
		end
		u.order = { kind = "Guard", x = u.x, z = u.z }
		return nil, nil, 0
	elseif order.kind == "Attack" then
		local target = sim.kingdoms[order.kingdomId]
		if target and target.alive and sim:atWar(u.kingdomId, target.id) then
			local keep = sim.buildings[target.keepId]
			if keep then
				return keep.x, keep.z, keep.footprint + 2
			end
		end
		u.order = { kind = "Defend" }
	end
	-- Defend: a loose ring around the keep, slot from the unit's id (stable when others die)
	local index = u.id
	local angle = index * 2.399963 -- golden angle spreads units evenly
	local radius = 20 + (index % 3) * 4
	return kingdom.x + math.cos(angle) * radius, kingdom.z + math.sin(angle) * radius, 1
end

-- The ground a unit holds: it only takes targets inside it. nil = no limit (Move, Attack, Hold).
local function leash(sim: any, u: any): Leash?
	local order = u.order
	if order.kind == "Defend" then
		local home = sim.kingdoms[u.kingdomId]
		return { x = home.x, z = home.z, r = home.territory + DEFEND_RADIUS }
	elseif order.kind == "Guard" then
		return { x = order.x, z = order.z, r = Military.GUARD_RADIUS }
	elseif order.kind == "Capture" then
		local o = objectiveOf(sim, order.objectiveId)
		if o then
			return { x = o.x, z = o.z, r = o.radius + DEFEND_RADIUS }
		end
	end
	return nil
end

local function stepUnits(sim: any, dt: number)
	for _, uid in table.clone(sim.unitOrder) do
		local u = sim.units[uid]
		if u == nil or not u.alive then
			continue
		end
		local def = sim.catalog.units[u.kind]
		u.cooldown = math.max(0, u.cooldown - dt)
		local order = u.order
		if order.kind == "Capture" then
			-- the capture is done once the kingdom owns the objective: guard the spot in the zone (idle,
			-- so a later Send-to-capture can take the unit on to the next objective)
			local o = objectiveOf(sim, order.objectiveId)
			if o and o.owner == u.kingdomId then
				u.order = { kind = "Guard", x = order.x, z = order.z }
			end
		end
		-- defenders, guards and capturers only fight on the ground they hold (acquire skips the rest)
		local target, kind = acquire(sim, u, def, leash(sim, u))
		if target and kind then
			local gap = dist(u.x, u.z, target.x, target.z) - targetRadius(target, kind)
			if gap > def.range + REACH_EPSILON and u.order.kind ~= "Hold" then
				-- close in, then strike in the same tick if that brought the target into range: checking
				-- range only before moving lets any target that steps away each tick (a fleeing
				-- citizen) stay out of reach forever
				local blocker = moveUnit(sim, u, def, target.x, target.z, def.range + targetRadius(target, kind), dt)
				if blocker then
					u.target = { kind = "building", id = blocker.id, blocker = true }
				else
					gap = dist(u.x, u.z, target.x, target.z) - targetRadius(target, kind)
				end
			end
			if gap <= def.range + REACH_EPSILON then
				if u.cooldown <= 0 then
					hit(sim, u, def, target, kind)
					u.cooldown = def.cooldown
				end
			elseif u.order.kind == "Hold" then
				u.target = nil -- holding units do not chase; look for something in range next tick
			end
		else
			local x, z, stopAt = orderDestination(sim, u)
			if x and z then
				local blocker = moveUnit(sim, u, def, x, z, stopAt, dt)
				if blocker then
					u.target = { kind = "building", id = blocker.id, blocker = true }
				end
			end
		end
	end
end

local function stepDefences(sim: any, dt: number)
	for _, bid in table.clone(sim.buildingOrder) do
		local b = sim.buildings[bid]
		if b == nil or b.destroyed or b.level < 1 then
			continue
		end
		local stats = sim.catalog.buildings[b.kind].levels[b.level]
		local attack = stats.attack
		if attack == nil then
			continue
		end
		b.cooldown = math.max(0, b.cooldown - dt)
		if b.cooldown > 0 then
			continue
		end
		local best, bestDistance = nil, math.huge
		for _, kid in sim.kingdomOrder do
			local enemy = sim.kingdoms[kid]
			if enemy.alive and sim:atWar(b.kingdomId, kid) then
				for _, uid in enemy.unitIds do
					local e = sim.units[uid]
					local d = dist(b.x, b.z, e.x, e.z)
					if d <= attack.range and d < bestDistance then
						best, bestDistance = e, d
					end
				end
			end
		end
		if best then
			best.hp -= attack.damage
			b.cooldown = attack.cooldown
			if best.hp <= 0 then
				killUnit(sim, best, b.kingdomId)
			end
		end
	end
end

-- Where a barracks' `slot`-th waiting recruit stands: slot 0 is the Kit barracks Rally (local
-- (0, 0, -depth/2 - 10), depth = Kit footprint Y - 2, turned by the building's yaw as Kit models are:
-- CFrame.Angles(0, yaw, 0), front = -Z); later slots alternate right and left of it, RALLY_ROW to a row,
-- the second row one step further out.
function Military.rallyPoint(b: any, slot: number): (number, number)
	local depth = Kit.footprint(b.kind, math.max(1, b.level)).Y - 2
	local column = slot % RALLY_ROW
	local row = (slot // RALLY_ROW) % 2
	local side = if column % 2 == 1 then 1 else -1
	local lx = side * math.ceil(column / 2) * SPREAD
	local lz = -(depth / 2 + RALLY_AHEAD + row * SPREAD)
	local c, s = math.cos(b.yaw or 0), math.sin(b.yaw or 0)
	return b.x + c * lx + s * lz, b.z - s * lx + c * lz
end

-- The first Rally slot no living unit of the kingdom stands on (cycling when all are taken).
local function freeRallySlot(sim: any, kingdom: any, b: any): number
	local slots = 2 * RALLY_ROW
	for slot = 0, slots - 1 do
		local x, z = Military.rallyPoint(b, slot)
		local taken = false
		for _, uid in kingdom.unitIds do
			local u = sim.units[uid]
			if u and dist(u.x, u.z, x, z) < Military.UNIT_RADIUS then
				taken = true
				break
			end
		end
		if not taken then
			return slot
		end
	end
	return kingdom.stats.unitsTrained % slots
end

local function stepTraining(sim: any, dt: number)
	for _, kid in sim.kingdomOrder do
		local kingdom = sim.kingdoms[kid]
		if not kingdom.alive then
			continue
		end
		for _, bid in kingdom.buildingIds do
			local b = sim.buildings[bid]
			local entry = b.queue[1]
			if entry and not b.destroyed then
				entry.remaining -= dt
				if entry.remaining <= 0 then
					table.remove(b.queue, 1)
					local x, z = Military.rallyPoint(b, freeRallySlot(sim, kingdom, b))
					local u = Military.spawnUnit(sim, kingdom, entry.unit, x, z)
					kingdom.stats.unitsTrained += 1
					sim:emit("UnitRecruited", { kingdomId = kingdom.id, unitId = u.id, unit = u.kind })
				end
			end
		end
	end
end

local function refreshThreats(sim: any)
	for _, kid in sim.kingdomOrder do
		local kingdom = sim.kingdoms[kid]
		local threats = {}
		if kingdom.alive then
			local radius = kingdom.territory + Military.AGGRO_EXTRA
			for _, otherId in sim.kingdomOrder do
				local other = sim.kingdoms[otherId]
				if other.alive and sim:atWar(kid, otherId) then
					for _, uid in other.unitIds do
						local u = sim.units[uid]
						if dist(u.x, u.z, kingdom.x, kingdom.z) <= radius then
							table.insert(threats, { id = u.id, x = u.x, z = u.z, kingdomId = otherId })
						end
					end
				end
			end
		end
		kingdom.threats = threats
	end
end

function Military.install(sim: any)
	assert(not sim._militaryInstalled, "Military.install: already installed")
	sim._militaryInstalled = true
	Commands.install(sim, "Recruit", recruit)
	Commands.install(sim, "ArmyOrder", armyOrder)
	Commands.install(sim, "UnitOrder", unitOrder)
	sim:addSystem({
		beforeCitizens = function(s: any, _dt: number)
			refreshThreats(s)
		end,
		afterCitizens = function(s: any, dt: number)
			stepTraining(s, dt)
			stepUnits(s, dt)
			stepDefences(s, dt)
		end,
	})
	WarWatch.install(sim) -- after the units: it reads this tick's hits and threats
end

-- exposed for specs and the match host
Military.destroyBuilding = destroyBuilding
Military.killUnit = killUnit
Military.eliminate = eliminate

return Military
