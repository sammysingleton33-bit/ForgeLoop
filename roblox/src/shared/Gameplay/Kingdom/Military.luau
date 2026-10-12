--!strict
--[[
	Gameplay/Kingdom/Military — recruitment, army orders, unit combat, defensive fire and conquest.

	Installed into a Simulation as a system plus two commands:
		Military.install(sim)
		Recruit(unitKind, count)           -> { barracksId, count }   errors: unknown_unit, invalid_args,
		                                      no_barracks, population_cap, cannot_afford
		ArmyOrder(order, a?, b?)           -> { order }               errors: invalid_args, not_at_war,
		                                      unknown_kingdom
			order "Defend"                  hold the territory around the keep (default for new units)
			order "Hold"                    stop where they stand, fight what comes in range
			order "Move", x, z              march to a point
			order "Attack", kingdomId       march on that kingdom's keep (requires war)

	Combat rules (deterministic, no randomness)
		- Only kingdoms at war fight (Simulation:atWar). Units pick the nearest enemy within aggro
		  range (weapon range + 30): units first, then citizens outside shelter, then buildings.
		  Siege units (attacksUnits = false) only target buildings. Targets are sticky while in reach.
		- Damage to buildings is multiplied by the unit's `siege` value (Ram x4).
		- Soft blocking: a unit whose next step would enter an enemy building's footprint attacks that
		  building instead (walls hold armies until broken). Full navigation comes with pathfinding.
		- Keeps and Towers shoot the nearest enemy unit in range (catalog `attack`).
		- Citizens sheltering in their keep (Flee or Sleep, resting) cannot be attacked.
		- A destroyed Keep eliminates its kingdom: its citizens, units and buildings are removed, the
		  conqueror loots half of its stockpile (capped by storage) and gains a conquest.
	Threats: before citizens think, each kingdom's `threats` lists enemy units inside its territory
	(+30 studs); CitizenBrain uses it to flee and remember danger.

	Events: RecruitQueued { kingdomId, unit, count, barracksId, by } · UnitRecruited { kingdomId, unitId, unit }
		ArmyOrdered { kingdomId, order, by } · UnitKilled { kingdomId, unitId, unit, byKingdomId }
		BuildingDestroyed { kingdomId, buildingId, kind, byKingdomId }
		KingdomEliminated { kingdomId, byKingdomId, loot }
	API (besides the commands)
		Military.spawnUnit(sim, kingdom, kind, x, z): Unit      -- also used by specs
		Military.destroyBuilding(sim, building, byKingdomId?), Military.eliminate(sim, kingdom, byKingdomId?)
		Military.AGGRO_EXTRA, Military.UNIT_RADIUS
]]

local Commands = require("./Commands")

local Military = {}

Military.AGGRO_EXTRA = 30
Military.UNIT_RADIUS = 1.5
local STICKY_FACTOR = 1.5
local DEFEND_RADIUS = 25
local ORDERS = { Defend = true, Hold = true, Move = true, Attack = true }

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
		id = sim:_newId("u"),
		kind = kind,
		kingdomId = kingdom.id,
		x = x,
		z = z,
		hp = def.hp,
		maxHp = def.hp,
		cooldown = 0,
		order = { kind = "Defend" } :: { [string]: any },
		targetId = nil :: string?,
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
		if b.kind == "Barracks" then
			n += #b.queue
		end
	end
	return n
end

local function recruit(sim: any, kingdom: any, by: number?, kind: any, count: any): (boolean, string?, any?)
	if type(kind) ~= "string" or not isInt(count, 1, 10) then
		return false, "invalid_args"
	end
	local def = sim.catalog.units[kind]
	if def == nil then
		return false, "unknown_unit"
	end
	local best = nil
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if b.kind == "Barracks" and not b.destroyed and b.level >= def.requiresBarracksLevel then
			if best == nil or #b.queue < #best.queue then
				best = b
			end
		end
	end
	if best == nil then
		return false, "no_barracks"
	end
	if sim:population(kingdom) + queuedCount(sim, kingdom) + count > kingdom.popCap then
		return false, "population_cap"
	end
	local total = {}
	for res, amount in def.cost do
		total[res] = amount * count
	end
	if not kingdom.stock:spend(total, "recruit") then
		return false, "cannot_afford"
	end
	for _ = 1, count do
		table.insert(best.queue, { unit = kind, remaining = def.trainTime })
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
		u.targetId = nil
	end
	sim:emit("ArmyOrdered", { kingdomId = kingdom.id, order = order, by = by })
	return true, nil, { order = order }
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
		for _, res in sim.catalog.resources do
			loot[res] = conqueror.stock:add(res, math.floor(kingdom.stock:get(res) / 2), "loot")
		end
	end
	for _, res in sim.catalog.resources do
		kingdom.stock:take(res, kingdom.stock:get(res), "plundered")
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
	if b.kind == "Keep" then
		eliminate(sim, kingdom, byKingdomId)
		return
	end
	sim:_removeBuilding(b)
	sim:emit(
		"BuildingDestroyed",
		{ kingdomId = kingdom.id, buildingId = b.id, kind = b.kind, byKingdomId = byKingdomId }
	)
end

-- ---------------------------------------------------------------- targeting
local function sheltered(sim: any, c: any): boolean
	if c.phase ~= "Rest" or (c.activity ~= "Flee" and c.activity ~= "Sleep") then
		return false
	end
	local kingdom = sim.kingdoms[c.kingdomId]
	return c.target == kingdom.keepId or c.target == nil
end

local function resolveTarget(sim: any, id: string?): (any?, string?)
	if id == nil then
		return nil, nil
	end
	local prefix = string.sub(id, 1, 1)
	if prefix == "u" then
		return sim.units[id], "unit"
	elseif prefix == "c" then
		return sim.citizens[id], "citizen"
	elseif prefix == "b" then
		local b = sim.buildings[id]
		return if b and not b.destroyed then b else nil, "building"
	end
	return nil, nil
end

local function targetRadius(target: any, kind: string?): number
	return if kind == "building" then target.footprint else 0
end

local function acquire(sim: any, u: any, def: any): (any?, string?)
	local aggro = def.range + Military.AGGRO_EXTRA
	-- sticky: keep the current target while it is valid and still within reach
	local current, currentKind = resolveTarget(sim, u.targetId)
	if current and sim:atWar(u.kingdomId, current.kingdomId) then
		local reach = aggro * STICKY_FACTOR + targetRadius(current, currentKind)
		local valid = currentKind ~= "citizen" or not sheltered(sim, current)
		if valid and dist(u.x, u.z, current.x, current.z) <= reach then
			return current, currentKind
		end
	end
	u.targetId = nil
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
				if d <= aggro and d < bestDistance then
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
				if d <= aggro and d < bestDistance and not sheltered(sim, c) then
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
				if d <= aggro and d < bestDistance then
					best, bestKind, bestDistance = b, "building", d
				end
			end
		end
	end
	if best then
		u.targetId = best.id
	end
	return best, bestKind
end

-- Moves a unit toward (x, z), stopping `stopAt` short. Returns a blocking enemy building, if any.
local function moveUnit(sim: any, u: any, def: any, x: number, z: number, stopAt: number, dt: number): any?
	local d = dist(u.x, u.z, x, z)
	if d <= stopAt then
		return nil
	end
	local stepLen = math.min(def.speed * dt, d - stopAt)
	local nx = u.x + (x - u.x) / d * stepLen
	local nz = u.z + (z - u.z) / d * stepLen
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
		return order.x, order.z, 2
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
	local index = tonumber(string.sub(u.id, 2)) or 0
	local angle = index * 2.399963 -- golden angle spreads units evenly
	local radius = 20 + (index % 3) * 4
	return kingdom.x + math.cos(angle) * radius, kingdom.z + math.sin(angle) * radius, 1
end

local function stepUnits(sim: any, dt: number)
	for _, uid in table.clone(sim.unitOrder) do
		local u = sim.units[uid]
		if u == nil or not u.alive then
			continue
		end
		local def = sim.catalog.units[u.kind]
		u.cooldown = math.max(0, u.cooldown - dt)
		local target, kind = acquire(sim, u, def)
		local engage = target ~= nil
		if target and u.order.kind == "Defend" then
			-- defenders do not chase beyond their territory
			local home = sim.kingdoms[u.kingdomId]
			engage = dist(target.x, target.z, home.x, home.z) <= home.territory + DEFEND_RADIUS
		end
		if target and kind and engage then
			local gap = dist(u.x, u.z, target.x, target.z) - targetRadius(target, kind)
			if gap <= def.range then
				if u.cooldown <= 0 then
					hit(sim, u, def, target, kind)
					u.cooldown = def.cooldown
				end
			else
				local blocker = moveUnit(sim, u, def, target.x, target.z, def.range + targetRadius(target, kind), dt)
				if blocker then
					u.targetId = blocker.id
				end
			end
		else
			local x, z, stopAt = orderDestination(sim, u)
			if x and z then
				local blocker = moveUnit(sim, u, def, x, z, stopAt, dt)
				if blocker then
					u.targetId = blocker.id
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
					local angle = #kingdom.unitIds * 2.399963
					local u = Military.spawnUnit(
						sim,
						kingdom,
						entry.unit,
						b.x + math.cos(angle) * (b.footprint + 3),
						b.z + math.sin(angle) * (b.footprint + 3)
					)
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
							table.insert(threats, { id = u.id, x = u.x, z = u.z })
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
end

-- exposed for specs and the match host
Military.destroyBuilding = destroyBuilding
Military.eliminate = eliminate

return Military
