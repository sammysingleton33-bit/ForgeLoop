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
		kingdom = { id, name, color, rulers, resources, capacity, population, popCap, territory,
		            quotas, priorities, alarm, alive, score, x, z, keepId },
		buildings = { { id, kind, x, z, level, pendingLevel?, progress (0..1), hp, maxHp, workers, builders } },
		citizens = { { id, name, occupation, activity, x, z, carrying?, carryAmount?, hunger } },
		units = { { id, kind, x, z, hp, maxHp, order } },
		relations = { [otherKingdomId] = "Peace" | "War" },
	}
	Overview = { seq, time, kingdoms = { { id, name, color, x, z, alive, population, score, rulerCount, territory } } }

	Score (documented for players and Match): population x 10 + completed building levels x 20 +
	kingdoms conquered x 300 + enemy units killed x 5 + floor(total resources gathered / 25).
]]

local Snapshot = {}

local function round1(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end

function Snapshot.score(sim: any, kingdom: any): number
	local levels = 0
	for _, bid in kingdom.buildingIds do
		local b = sim.buildings[bid]
		if not b.destroyed then
			levels += b.level
		end
	end
	local gathered = 0
	for _, amount in kingdom.stats.gathered do
		gathered += amount
	end
	return sim:population(kingdom) * 10
		+ levels * 20
		+ kingdom.stats.conquered * 300
		+ kingdom.stats.unitsKilled * 5
		+ math.floor(gathered / 25)
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
			local stats = sim.catalog.buildings[b.kind].levels[b.pendingLevel]
			progress = if stats.work > 0 then math.clamp(b.progress / stats.work, 0, 1) else 1
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
			occupation = c.occupation,
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
			resources = k.stock:snapshot(),
			capacity = k.stock:capacity(),
			population = sim:population(k),
			popCap = k.popCap,
			territory = k.territory,
			quotas = table.clone(k.quotas),
			priorities = table.clone(k.priorities),
			alarm = k.alarm,
			alive = k.alive,
			score = Snapshot.score(sim, k),
			x = k.x,
			z = k.z,
			keepId = k.keepId,
		},
		buildings = buildings,
		citizens = citizens,
		units = units,
		relations = relations,
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
			score = Snapshot.score(sim, k),
			rulerCount = #k.rulers,
			territory = k.territory,
		})
	end
	return { seq = seq, time = round1(sim.time), kingdoms = kingdoms }
end

return Snapshot
