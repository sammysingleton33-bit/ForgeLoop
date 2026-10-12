--!strict
--[[
	Sim/Replication — server-side views of simulation entities for CONTRACTS G4 (D-023).

	Citizens and soldiers are simulation entities (not Humanoids). This module turns them into the
	G4 EntityState (server API), the per-tick snapshot records (SnapshotCodec v2) and the identity
	each client needs once (EventCodec spawn: kind, job, kingdom). It derives the visible action and
	facing from what an entity is doing. Pure: no remotes, no instances.

	API
		Replication.new(): Tracker                 -- remembers last positions for facing and movement
		tracker:frame(sim, groundY?): { records: { Record }, identity: { [id]: { kind, job, kingdom } } }
		                                           -- every live entity in id order; updates facing
		Replication.entityState(sim, id): EntityState?   -- G4 EntityState (a copy)
		Replication.actionOf(sim, entity): string  -- idle | walk | work | carry | fight | flee | dead
		Replication.MOVING: { [action]: true }     -- actions whose records go out every snapshot
	Records: { id, x, y, z, yaw, action, carrying? } with y = groundY (the feet; rigs stand on it).
	Actions
		citizen  Go phase: walk (carry when loaded) · Work: work · Return: carry · Flee: flee ·
		         Rest / Sleep / Idle pause: idle
		soldier  attacked within the last second: fight · moved since the last frame: walk · else idle
	Facing (yaw, radians, Roblox CFrame.Angles(0, yaw, 0) convention): the direction of the last move;
	unchanged while standing still.
]]

local Replication = {}
Replication.__index = Replication

Replication.MOVING = table.freeze({ walk = true, carry = true, flee = true, fight = true })

local function entityOf(sim: any, id: number): (any?, string?)
	local c = sim.citizens[id]
	if c then
		return c, "citizen"
	end
	local u = sim.units[id]
	if u then
		return u, "soldier"
	end
	return nil, nil
end

function Replication.actionOf(sim: any, e: any): string
	if e.alive == false then
		return "dead"
	end
	if e.job ~= nil then -- citizen
		if e.activity == "Flee" and e.phase ~= "Rest" then
			return "flee"
		end
		if e.phase == "Return" then
			return "carry"
		end
		if e.phase == "Go" and e.activity ~= "Sleep" and e.activity ~= "Flee" then
			return if e.carrying and e.carrying.amount > 0 then "carry" else "walk"
		end
		if e.phase == "Work" then
			return "work"
		end
		return "idle"
	end
	-- soldier
	local def = sim.catalog.units[e.kind]
	if def and e.cooldown and e.cooldown > def.cooldown - 1 and e.cooldown > 0 then
		return "fight"
	end
	return if e.moving then "walk" else "idle"
end

local function jobOf(e: any): string
	return if e.job ~= nil then e.job else "soldier"
end

local function carrying(e: any): string?
	return if e.carrying and e.carrying.amount > 0 then e.carrying.resource else nil
end

function Replication.entityState(sim: any, id: number): any?
	local e, kind = entityOf(sim, id)
	if e == nil then
		return nil
	end
	local memory = {}
	for _, m in e.memory or {} do
		table.insert(memory, { event = m.kind, kingdom = m.kingdom, at = m.t })
	end
	return {
		id = id,
		kind = kind,
		kingdom = e.kingdomId,
		job = jobOf(e),
		name = e.name or `Soldier {id}`,
		position = Vector3.new(e.x, 0, e.z),
		yaw = e.yaw or 0,
		action = Replication.actionOf(sim, e),
		carrying = carrying(e),
		hp = e.hp,
		mood = if e.hunger then math.clamp(1 - e.hunger, 0, 1) else 1,
		memory = memory,
	}
end

function Replication.new()
	return setmetatable({ _last = {} :: { [number]: { x: number, z: number, yaw: number } } }, Replication)
end

function Replication:frame(sim: any, groundY: number?): { records: { any }, identity: { [number]: any } }
	local y = groundY or 0
	local records = {}
	local identity = {}
	local function add(e: any, kind: string)
		local last = self._last[e.id]
		local yaw = if last then last.yaw else 0
		local moved = false
		if last then
			local dx, dz = e.x - last.x, e.z - last.z
			if dx * dx + dz * dz > 1e-4 then
				yaw = math.atan2(-dx, -dz)
				moved = true
			end
		end
		self._last[e.id] = { x = e.x, z = e.z, yaw = yaw }
		e.yaw = yaw
		e.moving = moved
		identity[e.id] = { kind = kind, job = jobOf(e), kingdom = e.kingdomId }
		table.insert(records, {
			id = e.id,
			x = e.x,
			y = y,
			z = e.z,
			yaw = yaw,
			action = Replication.actionOf(sim, e),
			carrying = carrying(e),
		})
	end
	for _, id in sim.citizenOrder do
		add(sim.citizens[id], "citizen")
	end
	for _, id in sim.unitOrder do
		add(sim.units[id], "soldier")
	end
	for id in self._last do
		if identity[id] == nil then
			self._last[id] = nil
		end
	end
	table.sort(records, function(a, b)
		return a.id < b.id
	end)
	return { records = records, identity = identity }
end

return Replication
