--!strict
--[[
	Gameplay/Kingdom/Snapshot — read-only, remote-safe views of the simulation for clients.

	Snapshots are plain tables of strings, numbers and booleans (array or string keys only), so they
	survive RemoteEvent serialisation unchanged and never alias live simulation tables: a client (or a
	buggy consumer) cannot mutate kingdom state through them. Positions are rounded to 0.1 stud.

	API
		Snapshot.kingdom(sim, kingdomId, seq): KingdomSnapshot?   -- full detail for that kingdom's rulers
		Snapshot.overview(sim, seq): Overview                     -- public summary of every kingdom
		Snapshot.score(sim, kingdom): number                      -- also used by Match for time victory

	KingdomSnapshot = {
		seq, time, day, dayFraction, night,
		kingdom = { id, name, color, rulers, isAI, resources, population, popCap, territory,
		            quotas, priorities, alarm, alive, crownPoints, x, z, keepId },
		buildings = { { id, kind, x, z, level, pendingLevel?, progress (0..1), hp, maxHp, workers, builders } },
		citizens = { { id, name, job, activity, x, z, carrying?, carryAmount?, hunger } },
		units = { { id, kind, x, z, hp, maxHp, order } },
		relations = { [otherKingdomId] = "Peace" | "War" },
		objectives = { { id, x, z, radius, owner?, progress = { [kingdomId] = 0..1 }, contested } },
	}
	Overview = { seq, time, kingdoms = { { id, name, color, x, z, alive, population, crownPoints, rulerCount,
	           territory } }, objectives }

	Score = the kingdom's Crown Points (KingdomService:addCrownPoints, G3): completed building levels,
	captured and held objectives, conquests and enemy units killed (Catalog.crown).
]]

local Snapshot = {}

local function round1(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end

function Snapshot.score(_sim: any, kingdom: any): number
	return kingdom.crownPoints
end

local function objectives(sim: any): { any }
	local out = {}
	for _, o in (sim.objectives and sim.objectives.list) or {} do
		table.insert(out, {
			id = o.id,
			x = round1(o.x),
			z = round1(o.z),
			radius = o.radius,
			owner = o.owner,
			progress = table.clone(o.progress),
			contested = o.contested,
		})
	end
	return out
end

function Snapshot.kingdom(sim: any, kingdomId: string, seq: number): { [string]: any }?
	local k = sim.kingdoms[kingdomId]
	if k == nil then
		return nil
	end
	local buildings = {}
	for _, bid in k.buildingIds do
		local b = sim.buildings[bid]
		local progress = 0
		if b.pendingLevel ~= nil then
			local work = sim:workFor(b.kind, b.pendingLevel)
			progress = if work > 0 then math.clamp(b.progress / work, 0, 1) else 1
		end
		table.insert(buildings, {
			id = b.id,
			kind = b.kind,
			x = round1(b.x),
			z = round1(b.z),
			level = b.level,
			pendingLevel = b.pendingLevel,
			progress = math.floor(progress * 1000 + 0.5) / 1000,
			hp = b.hp,
			maxHp = b.maxHp,
			workers = #b.workers,
			builders = #b.builders,
		})
	end
	local citizens = {}
	for _, cid in k.citizenIds do
		local c = sim.citizens[cid]
		table.insert(citizens, {
			id = c.id,
			name = c.name,
			job = c.job,
			activity = c.activity,
			x = round1(c.x),
			z = round1(c.z),
			carrying = if c.carrying then c.carrying.resource else nil,
			carryAmount = if c.carrying then c.carrying.amount else nil,
			hunger = math.floor(c.hunger * 100 + 0.5) / 100,
		})
	end
	local units = {}
	for _, uid in k.unitIds do
		local u = sim.units[uid]
		table.insert(units, {
			id = u.id,
			kind = u.kind,
			x = round1(u.x),
			z = round1(u.z),
			hp = u.hp,
			maxHp = u.maxHp,
			order = u.order.kind,
		})
	end
	local relations = {}
	for _, other in sim.kingdomOrder do
		if other ~= k.id then
			relations[other] = sim.relations[sim:relationKey(k.id, other)] or "Peace"
		end
	end
	return {
		seq = seq,
		time = round1(sim.time),
		day = sim:day(),
		dayFraction = math.floor(sim:dayFraction() * 1000) / 1000,
		night = sim:isNight(),
		kingdom = {
			id = k.id,
			name = k.name,
			color = table.clone(k.color),
			rulers = table.clone(k.rulers),
			isAI = #k.rulers == 0,
			resources = sim.treasury:get(k.id),
			population = sim:population(k),
			popCap = k.popCap,
			territory = k.territory,
			quotas = table.clone(k.quotas),
			priorities = table.clone(k.priorities),
			alarm = k.alarm,
			alive = k.alive,
			crownPoints = k.crownPoints,
			x = k.x,
			z = k.z,
			keepId = k.keepId,
		},
		buildings = buildings,
		citizens = citizens,
		units = units,
		relations = relations,
		objectives = objectives(sim),
	}
end

function Snapshot.overview(sim: any, seq: number): { [string]: any }
	local kingdoms = {}
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		table.insert(kingdoms, {
			id = k.id,
			name = k.name,
			color = table.clone(k.color),
			x = k.x,
			z = k.z,
			alive = k.alive,
			population = sim:population(k),
			crownPoints = k.crownPoints,
			rulerCount = #k.rulers,
			territory = k.territory,
		})
	end
	return { seq = seq, time = round1(sim.time), kingdoms = kingdoms, objectives = objectives(sim) }
end

return Snapshot
