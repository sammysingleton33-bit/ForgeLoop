local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Commands = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Commands")
local Diplomacy = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Diplomacy")
local Military = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Military")

local RULER, RIVAL = 101, 201

-- k1 at the origin and k2 300 studs east, at Peace, Military installed, births off.
-- options.citizens: start citizens per kingdom (default none, so units fight undisturbed).
-- Territory 130 + 30: k1's threat zone reaches x = 160, k2's starts at x = 140.
local function world(options: { [string]: any }?)
	local opts = options or {}
	local sim, crimson = F.kingdom({
		nodes = false,
		tuning = { startCitizens = opts.citizens or {}, birthInterval = 1e6, hungerPerDay = 0.001 },
	})
	local azure = sim:addKingdom({ id = "azure", name = "Rival", x = 300, z = 0 })
	Military.install(sim)
	assert(sim:addRuler("crimson", RULER))
	assert(sim:addRuler("azure", RIVAL))
	F.events(sim)
	return sim, k1, k2
end

local function war(sim)
	Diplomacy.setRelation(sim, "crimson", "azure", "War")
end

-- A finished building at the given level, created without cost (scenario setup).
local function addBuilding(sim, k, kind: string, x: number, z: number, level: number?)
	local b = sim:_createBuilding(k, kind, x, z)
	sim:_completeInstantly(b)
	local stats = sim.catalog.buildings[kind].levels[level or 1]
	b.level = level or 1
	b.maxHp = stats.hp
	b.hp = stats.hp
	sim:_recompute(k)
	return b
end

local function unit(sim, k, kind: string, x: number, z: number, order: { [string]: any }?)
	local u = Military.spawnUnit(sim, k, kind, x, z)
	u.order = order or { kind = "Hold" }
	return u
end

local function recruit(userId: number, sim, kind: any, count: any)
	return Commands.execute(sim, userId, "Recruit", kind, count)
end

local function stockUp(k, amounts: { [string]: number })
	for res, amount in amounts do
		F.stock(sim, k):add(res, amount)
	end
end

describe("Kingdom/Military: recruiting", function()
	it("needs a finished barracks (no_barracks for none or a construction site), costing nothing", function()
		local sim, crimson = world()
		local stock = sim.treasury:get(k1.id)
		local ok, err = recruit(RULER, sim, "soldier", 1)
		expect(ok).toBe(false)
		expect(err).toBe("no_barracks")
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		stockUp(k1, { wood = 200, stone = 100 })
		assert(sim:placeBuilding(k1, "barracks", 0, -40))
		stock = sim.treasury:get(k1.id)
		F.events(sim)
		expect(select(2, recruit(RULER, sim, "soldier", 1))).toBe("no_barracks")
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		expect(F.events(sim)).toEqual({})
	end)

	it("Knight and Ram need a level-2 barracks", function()
		local sim, crimson = world()
		stockUp(k1, { food = 280, wood = 300, stone = 300, gold = 300 })
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 1)
		local stock = sim.treasury:get(k1.id)
		expect(select(2, recruit(RULER, sim, "knight", 1))).toBe("no_barracks")
		expect(select(2, recruit(RULER, sim, "ram", 1))).toBe("no_barracks")
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		expect((recruit(RULER, sim, "archer", 1))).toBe(true)
		barracks.level = 2
		local ok, err = recruit(RULER, sim, "knight", 1)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect((recruit(RULER, sim, "ram", 1))).toBe(true)
		expect(#barracks.queue).toBe(3)
	end)

	it("rejects bad arguments (invalid_args) and unknown units (unknown_unit)", function()
		local sim, crimson = world()
		addBuilding(sim, k1, "barracks", 0, -40, 1)
		for _, count in { 0, 11, 1.5, -1, 0 / 0, math.huge, "1", nil } do
			expect(select(2, recruit(RULER, sim, "soldier", count))).toBe("invalid_args")
		end
		for _, kind in { nil, 5, {} } do
			expect(select(2, recruit(RULER, sim, kind, 1))).toBe("invalid_args")
		end
		expect(select(2, recruit(RULER, sim, "Dragon", 1))).toBe("unknown_unit")
		expect(select(2, recruit(RULER, sim, "militia", 1))).toBe("unknown_unit")
		expect(F.events(sim)).toEqual({})
	end)

	it("counts units already queued against the population cap (population_cap)", function()
		local sim, crimson = world({ citizens = { farmer = 4 } })
		stockUp(k1, { food = 280, wood = 300 })
		addBuilding(sim, k1, "barracks", 0, -40, 1)
		expect(k1.popCap).toBe(10)
		expect((recruit(RULER, sim, "soldier", 4))).toBe(true) -- 4 citizens + 4 queued
		local stock = sim.treasury:get(k1.id)
		expect(select(2, recruit(RULER, sim, "soldier", 3))).toBe("population_cap") -- would be 11
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		expect((recruit(RULER, sim, "soldier", 2))).toBe(true) -- exactly 10
		expect(select(2, recruit(RULER, sim, "soldier", 1))).toBe("population_cap")
		sim:advance(6 * 8) -- everything trained: 4 citizens + 6 units
		expect(#k1.unitIds).toBe(6)
		expect(sim:population(k1)).toBe(10)
		expect(select(2, recruit(RULER, sim, "soldier", 1))).toBe("population_cap")
		-- KNOWN BUG (Simulation.luau, not editable here): births ignore units still in a barracks
		-- queue, so a birth during training can push population above popCap. See the report; this
		-- spec turns births off so it only covers Recruit's own check.
	end)

	it("cannot_afford leaves stock, queue and events untouched", function()
		local sim, crimson = world()
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 1)
		local stock = sim.treasury:get(k1.id) -- food 120: four militia cost 120, five cost 150
		expect(select(2, recruit(RULER, sim, "soldier", 5))).toBe("cannot_afford")
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		expect(#barracks.queue).toBe(0)
		expect(F.events(sim)).toEqual({})
		expect(F.stock(sim, k1):flows().expense.recruit).toBeNil()
		expect((recruit(RULER, sim, "soldier", 4))).toBe(true)
		expect(sim:balance(k1.id, "food")).toBe(0)
	end)

	it("spends cost x count at once, booked as 'recruit', and announces the queue", function()
		local sim, crimson = world()
		stockUp(k1, { wood = 100 })
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 1)
		local ok, err, result = recruit(RULER, sim, "archer", 3)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ barracksId = barracks.id, count = 3 })
		expect(sim.treasury:get(k1.id)).toEqual({ food = 30, wood = 110, stone = 50, gold = 0 })
		expect(F.stock(sim, k1):flows().expense.recruit).toEqual({ food = 90, wood = 90 })
		local queued = F.events(sim, "RecruitQueued")
		expect(#queued).toBe(1)
		expect(queued[1].kingdomId).toBe("crimson")
		expect(queued[1].unit).toBe("archer")
		expect(queued[1].count).toBe(3)
		expect(queued[1].barracksId).toBe(barracks.id)
		expect(queued[1].by).toBe(RULER)
		local okAudit = sim.treasury:audit(k1.id)
		expect(okAudit).toBe(true)
	end)

	it("queues on the barracks with the shortest queue", function()
		local sim, crimson = world()
		stockUp(k1, { food = 280, wood = 300 })
		local first = addBuilding(sim, k1, "barracks", 0, -40, 1)
		local second = addBuilding(sim, k1, "barracks", 0, 40, 1)
		local _, _, a = recruit(RULER, sim, "soldier", 2)
		local _, _, b = recruit(RULER, sim, "soldier", 1)
		local _, _, c = recruit(RULER, sim, "soldier", 1)
		expect(a.barracksId).toBe(first.id)
		expect(b.barracksId).toBe(second.id)
		expect(c.barracksId).toBe(second.id)
	end)

	it("trains one unit per trainTime, in queue order, then emits UnitRecruited", function()
		local sim, crimson = world()
		stockUp(k1, { wood = 100 })
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 1)
		assert(recruit(RULER, sim, "soldier", 1))
		assert(recruit(RULER, sim, "archer", 1))
		F.events(sim)
		sim:advance(7.75)
		expect(#k1.unitIds).toBe(0)
		expect(#F.events(sim, "UnitRecruited")).toBe(0)
		sim:advance(0.25) -- Militia trainTime 8
		local recruited = F.events(sim, "UnitRecruited")
		expect(#recruited).toBe(1)
		expect(recruited[1].kingdomId).toBe("crimson")
		expect(recruited[1].unit).toBe("soldier")
		local u = sim.units[recruited[1].unitId]
		expect(u.kingdomId).toBe("crimson")
		expect(u.hp).toBe(80)
		expect(u.order.kind).toBe("Defend")
		expect(#barracks.queue).toBe(1)
		sim:advance(9.75)
		expect(#F.events(sim, "UnitRecruited")).toBe(0)
		sim:advance(0.25) -- Archer trainTime 10, after the militia
		recruited = F.events(sim, "UnitRecruited")
		expect(#recruited).toBe(1)
		expect(recruited[1].unit).toBe("archer")
		expect(#k1.unitIds).toBe(2)
		expect(k1.stats.unitsTrained).toBe(2)
		expect(#barracks.queue).toBe(0)
		expect(sim:population(k1)).toBe(2)
	end)
end)

describe("Kingdom/Military: army orders", function()
	it("validates the order and its arguments without changing any unit", function()
		local sim, k1, azure = world()
		local u = unit(sim, k1, "soldier", 10, 30, { kind = "Defend" })
		local nan, inf = 0 / 0, math.huge
		local cases = {
			{ "invalid_args", "Charge" },
			{ "invalid_args", 5 },
			{ "invalid_args", nil },
			{ "invalid_args", "Move", nan, 0 },
			{ "invalid_args", "Move", 0, inf },
			{ "invalid_args", "Move", -inf, 0 },
			{ "invalid_args", "Move", 1e6, 0 },
			{ "invalid_args", "Move", "10", 0 },
			{ "invalid_args", "Move", 10 },
			{ "invalid_args", "Attack", 5 },
			{ "invalid_args", "Attack", nil },
			{ "unknown_kingdom", "Attack", "k9" },
			{ "unknown_kingdom", "Attack", "crimson" },
			{ "not_at_war", "Attack", "azure" },
		}
		for _, case in cases do
			local ok, err = Commands.execute(sim, RULER, "ArmyOrder", case[2], case[3], case[4])
			expect(ok).toBe(false)
			expect(err).toBe(case[1])
		end
		expect(u.order).toEqual({ kind = "Defend" })
		expect(F.events(sim)).toEqual({})
		war(sim)
		expect((Commands.execute(sim, RULER, "ArmyOrder", "Attack", "azure"))).toBe(true)
		Military.eliminate(sim, k2, nil)
		expect(select(2, Commands.execute(sim, RULER, "ArmyOrder", "Attack", "azure"))).toBe("unknown_kingdom")
	end)

	it("gives every unit the order, records who gave it, and units march to a Move point", function()
		local sim, crimson = world()
		local a = unit(sim, k1, "soldier", 10, 30, { kind = "Defend" })
		local b = unit(sim, k1, "archer", -10, 30, { kind = "Defend" })
		local ok, err, result = Commands.execute(sim, RULER, "ArmyOrder", "Move", 60, -60)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ order = "Move" })
		expect(a.order).toEqual({ kind = "Move", x = 60, z = -60 })
		expect(b.order).toEqual({ kind = "Move", x = 60, z = -60 })
		expect(a.order).never.toBe(b.order) -- each unit has its own copy
		local ordered = F.events(sim, "ArmyOrdered")
		expect(#ordered).toBe(1)
		expect(ordered[1].order).toBe("Move")
		expect(ordered[1].by).toBe(RULER)
		sim:advance(20)
		for _, u in { a, b } do
			expect(math.sqrt((u.x - 60) ^ 2 + (u.z + 60) ^ 2)).toBeLessThanOrEqual(2.01)
		end
	end)
end)

describe("Kingdom/Military: combat", function()
	it("units do not fight at Peace, and keeps do not shoot", function()
		local sim, k1, azure = world()
		local a = unit(sim, k1, "soldier", 150, 0)
		local b = unit(sim, k2, "soldier", 153, 0)
		local intruder = unit(sim, k2, "soldier", 30, 0) -- inside k1's keep range
		sim:advance(5)
		expect(a.hp).toBe(80)
		expect(b.hp).toBe(80)
		expect(intruder.hp).toBe(80)
		expect(sim.buildings[k1.keepId].hp).toBe(6000)
		expect(#F.events(sim, "UnitKilled")).toBe(0)
		expect(k1.threats).toEqual({})
	end)

	it("at War, units kill enemy units and both sides count it", function()
		local sim, k1, azure = world()
		war(sim)
		local mine =
			{ unit(sim, k1, "soldier", 150, 2), unit(sim, k1, "soldier", 150, -2), unit(sim, k1, "soldier", 151, 0) }
		local enemy = unit(sim, k2, "soldier", 154, 0)
		sim:advance(5)
		expect(enemy.alive).toBe(false)
		expect(sim.units[enemy.id]).toBeNil()
		expect(table.find(k2.unitIds, enemy.id)).toBeNil()
		expect(table.find(sim.unitOrder, enemy.id)).toBeNil()
		local killed = F.events(sim, "UnitKilled")
		expect(#killed).toBe(1)
		expect(killed[1]).toEqual({
			name = "UnitKilled",
			t = killed[1].t,
			kingdomId = "azure",
			unitId = enemy.id,
			unit = "soldier",
			byKingdomId = "crimson",
		})
		expect(k1.stats.unitsKilled).toBe(1)
		expect(k2.stats.unitsLost).toBe(1)
		for _, u in mine do
			expect(u.alive).toBe(true)
		end
	end)

	it("Hold units stay where they stand and only fight what is in weapon range", function()
		local sim, k1, azure = world()
		war(sim)
		local holder = unit(sim, k1, "soldier", 150, 0)
		local bait = unit(sim, k2, "ram", 170, 0) -- inside aggro (35) but outside weapon range (5)
		sim:advance(3)
		expect(holder.x).toBe(150)
		expect(holder.z).toBe(0)
		expect(bait.hp).toBe(400)
		bait.x = 153 -- now in weapon range
		sim:advance(1)
		expect(holder.x).toBe(150)
		expect(bait.hp).toBeLessThan(400)
	end)

	it("a unit closing in from any direction reaches striking range (no floating-point stall)", function()
		local stalled = {}
		for i = 0, 35 do
			local sim, k1, azure = world()
			war(sim)
			local wall = addBuilding(sim, k1, "wall", 100, 0, 1)
			local a = i * math.pi / 18
			local x, z = 100 + math.cos(a) * 20, math.sin(a) * 20
			unit(sim, k2, "soldier", x, z, { kind = "Move", x = x, z = z })
			sim:advance(5)
			if wall.hp == 900 then
				table.insert(stalled, i * 10)
			end
		end
		expect(stalled).toEqual({}) -- approach angles (degrees) whose unit never struck
	end)

	it("keeps and towers shoot the nearest enemy unit in range, on their cooldown", function()
		local sim, k1, azure = world()
		war(sim)
		local near = unit(sim, k2, "soldier", 30, 0)
		local farther = unit(sim, k2, "soldier", 0, 38)
		local outside = unit(sim, k2, "soldier", -41, 0) -- keep range is 40
		sim:step()
		expect(near.hp).toBe(70) -- keep damage 10
		expect(farther.hp).toBe(80)
		sim:advance(1.25)
		expect(near.hp).toBe(70) -- cooldown 1.5
		sim:advance(0.25)
		expect(near.hp).toBe(60)
		expect(outside.hp).toBe(80)

		local tower = addBuilding(sim, k1, "watchtower", 80, 80, 1)
		local target = unit(sim, k2, "soldier", 80, 120) -- 40 from the tower, 144 from the keep
		sim:step()
		expect(target.hp).toBe(68) -- tower damage 12
		-- a tower still under construction does not shoot
		local site = sim:_createBuilding(k1, "watchtower", -80, -80)
		local unseen = unit(sim, k2, "soldier", -80, -110)
		sim:advance(2)
		expect(site.level).toBe(0)
		expect(unseen.hp).toBe(80)
		expect(tower.level).toBe(1)
	end)

	it("a Ram deals damage x4 (siege) to buildings, destroys them, and never attacks units", function()
		local sim, k1, azure = world()
		war(sim)
		local wall = addBuilding(sim, k1, "wall", 100, 0, 1)
		local ram = unit(sim, k2, "ram", 110, 0)
		sim:step()
		expect(ram.targetId).toBe(wall.id)
		expect(wall.hp).toBe(900 - 60 * 4)
		local militia = unit(sim, k2, "soldier", 108, 3) -- 4.5 from the wall's edge: in range
		sim:advance(3) -- ram strikes again at 3.25 (cooldown 3); militia at 0.5, 1.5, 2.5
		expect(wall.hp).toBe(900 - 240 * 2 - 8 * 3) -- Militia siege 1: plain damage
		sim:advance(5.75)
		expect(sim.buildings[wall.id]).toBe(wall) -- 900 - 3 x 240 - 8 x 8 = 116 left
		sim:advance(0.25) -- the ram's fourth blow at 9.25
		expect(sim.buildings[wall.id]).toBeNil()
		expect(wall.destroyed).toBe(true)
		local destroyed = F.events(sim, "BuildingDestroyed")
		expect(#destroyed).toBe(1)
		expect(destroyed[1].kingdomId).toBe("crimson")
		expect(destroyed[1].buildingId).toBe(wall.id)
		expect(destroyed[1].kind).toBe("wall")
		expect(destroyed[1].byKingdomId).toBe("azure")
		expect(k1.alive).toBe(true)
		expect(militia.alive).toBe(true)

		-- far from any building, a ram next to an enemy soldier never strikes it
		local defender = unit(sim, k1, "soldier", 150, -150)
		local lonelyRam = unit(sim, k2, "ram", 152, -150)
		sim:advance(4)
		expect(defender.hp).toBe(80)
		expect(lonelyRam.hp).toBeLessThan(400)
		F.assertInvariants(sim)
	end)

	it("soft blocking: a unit chasing a target behind an enemy wall stops at the wall and breaks it first", function()
		local sim, k1, azure = world()
		war(sim)
		local wall = addBuilding(sim, k1, "wall", 125, 0, 1)
		wall.hp = 24 -- three militia hits
		local bait = unit(sim, k1, "ram", 110, 0) -- behind the wall; rams do not fight back
		local raider = unit(sim, k2, "soldier", 140, 0, { kind = "Move", x = 100, z = 0 })
		local blockedAt = nil
		for _ = 1, 20 do
			sim:step()
			if raider.targetId == wall.id and blockedAt == nil then
				blockedAt = raider.x
			end
			if sim.buildings[wall.id] then
				-- never inside the wall's footprint while it stands
				expect(raider.x).toBeGreaterThanOrEqual(125 + 4 + Military.UNIT_RADIUS)
				expect(bait.hp).toBe(400)
			end
		end
		expect(blockedAt).toBeTruthy()
		expect(sim.buildings[wall.id]).toBeNil()
		sim:advance(5)
		expect(bait.hp).toBeLessThan(400) -- through the breach to the target

		-- at Peace nothing blocks: the same march walks straight through a wall
		local sim2, a1, a2 = world()
		addBuilding(sim2, a1, "wall", 125, 0, 1)
		local walker = unit(sim2, a2, "soldier", 140, 0, { kind = "Move", x = 100, z = 0 })
		sim2:advance(5)
		expect(walker.x).toBeNear(102, 0.01)
	end)

	it(
		"a raider catches citizens fleeing in the open (cause raid) but cannot touch those sheltering in the keep",
		function()
			local sim, k1, azure = world({ citizens = { farmer = 2 } })
			war(sim)
			local keep = sim.buildings[k1.keepId]
			local sheltered, outside = sim:citizensOf(k1)[1], sim:citizensOf(k1)[2]
			sheltered.x, sheltered.z = keep.footprint + 1, 0
			sheltered.activity, sheltered.target, sheltered.phase, sheltered.done = "Flee", keep.id, "Rest", false
			outside.x, outside.z = 0, 100
			-- one raider stands at the sheltered citizen, another lands next to the one outside
			local siege = unit(sim, k2, "soldier", keep.footprint + 3, 0)
			local raider = unit(sim, k2, "soldier", 0, 102, { kind = "Move", x = 0, z = 102 })
			local died = {}
			for _ = 1, 40 do
				sim:step()
				for _, e in F.events(sim, "CitizenDied") do
					table.insert(died, e)
				end
			end
			expect(#died).toBe(1)
			expect(died[1].citizenId).toBe(outside.id)
			expect(died[1].cause).toBe("raid")
			expect(outside.alive).toBe(false)
			expect(sheltered.alive).toBe(true)
			expect(sheltered.hp).toBe(40)
			expect(keep.hp).toBeLessThan(6000) -- the raider at the keep hit the building instead
			expect(siege.alive).toBe(true)
			expect(raider.alive).toBe(true)
			F.assertInvariants(sim)
		end
	)

	it("lists enemy units inside territory (+30) as threats; citizens near one flee and remember it", function()
		local sim, k1, azure = world({ citizens = { farmer = 3 } })
		sim:advance(10) -- farmers walk to the farm at about (28, 19)
		local farmers = sim:citizensOf(k1)
		local intruder = unit(sim, k2, "soldier", 55, 19)
		local distant = unit(sim, k2, "soldier", 170, 0) -- beyond 130 + 30
		sim:step()
		expect(k1.threats).toEqual({}) -- at peace nobody is a threat
		war(sim)
		sim:step()
		expect(#k1.threats).toBe(1)
		expect(k1.threats[1].id).toBe(intruder.id)
		expect(k2.threats).toEqual({}) -- k1 has no units
		for _, c in farmers do
			local d = math.sqrt((c.x - intruder.x) ^ 2 + (c.z - intruder.z) ^ 2)
			if d <= sim.catalog.tuning.fleeRadius then
				expect(c.activity).toBe("Flee")
				expect(c.reason).toBe("threat")
				local remembered = false
				for _, m in c.memory do
					remembered = remembered or (m.kind == "threat" and m.ref == intruder.id)
				end
				expect(remembered).toBe(true)
			end
		end
		expect(F.count(farmers, function(c)
			return c.activity == "Flee"
		end)).toBeGreaterThan(0)
		-- once the intruder is gone the list clears on the next tick
		Diplomacy.setRelation(sim, "crimson", "azure", "Peace")
		sim:step()
		expect(k1.threats).toEqual({})
		expect(distant.alive).toBe(true)
	end)
end)

describe("Kingdom/Military: conquest", function()
	it("destroying a Keep eliminates the kingdom, removes everything it had and pays the conqueror", function()
		local sim, k1, azure = world({ citizens = { farmer = 2 } })
		war(sim)
		stockUp(k1, { wood = 290 }) -- 390 of 400: wood loot is capped at 10
		local house = addBuilding(sim, k2, "house", 300, 40, 1)
		local guard = unit(sim, k2, "soldier", 420, 100)
		local ram = unit(sim, k1, "ram", 300 - 14 - 5, 0)
		local attacker = unit(sim, k1, "soldier", -40, 0, { kind = "Attack", kingdomId = "azure" })
		sim.buildings[k2.keepId].hp = 200 -- one ram blow (240)
		local k2Citizens = table.clone(k2.citizenIds)
		local k2Buildings = table.clone(k2.buildingIds)
		F.events(sim)
		sim:step()

		local events = sim:drainEvents()
		local eliminated = nil
		for _, e in events do
			expect(e.name == "CitizenDied" or e.name == "UnitKilled" or e.name == "BuildingDestroyed").toBe(false)
			if e.name == "KingdomEliminated" then
				eliminated = e
			end
		end
		expect(eliminated).toBeTruthy()
		expect(eliminated.kingdomId).toBe("azure")
		expect(eliminated.byKingdomId).toBe("crimson")
		expect(eliminated.loot).toEqual({ food = 60, wood = 10, stone = 25, gold = 0 })
		expect(k2.alive).toBe(false)
		expect(k2.eliminatedBy).toBe("crimson")
		expect(k2.eliminatedAt).toBe(sim.time)
		expect(k1.stats.conquered).toBe(1)
		expect(sim:balance(k1.id, "wood")).toBe(400)
		expect(sim:balance(k1.id, "food")).toBe(180)
		expect(sim.treasury:get(k2.id)).toEqual({ food = 0, wood = 0, stone = 0, gold = 0 })
		expect(k2.citizenIds).toEqual({})
		expect(k2.unitIds).toEqual({})
		expect(k2.buildingIds).toEqual({})
		for _, cid in k2Citizens do
			expect(sim.citizens[cid]).toBeNil()
			expect(table.find(sim.citizenOrder, cid)).toBeNil()
		end
		for _, bid in k2Buildings do
			expect(sim.buildings[bid]).toBeNil()
			expect(table.find(sim.buildingOrder, bid)).toBeNil()
		end
		expect(house.destroyed).toBe(true)
		expect(sim.units[guard.id]).toBeNil()
		expect(table.find(sim.unitOrder, guard.id)).toBeNil()
		expect(Diplomacy.relation(sim, "crimson", "azure")).toBe("Peace")
		F.assertInvariants(sim)

		-- life goes on for the winner: its attackers return to defending, nothing else breaks
		sim:advance(2)
		expect(attacker.order.kind).toBe("Defend")
		expect(ram.alive).toBe(true)
		expect(select(2, Commands.execute(sim, RIVAL, "SetAlarm", true))).toBe("kingdom_eliminated")
		F.assertInvariants(sim)
	end)

	it("losing any other building does not eliminate; elimination without a conqueror pays nobody", function()
		local sim, k1, azure = world()
		local farm = sim:buildingsOf(k2)[2]
		Military.destroyBuilding(sim, farm, "crimson")
		expect(k2.alive).toBe(true)
		expect(#F.events(sim, "BuildingDestroyed")).toBe(1)
		Military.destroyBuilding(sim, farm, "crimson") -- already gone: no second event
		expect(#F.events(sim, "BuildingDestroyed")).toBe(0)
		Military.eliminate(sim, k2, nil)
		local eliminated = F.events(sim, "KingdomEliminated")
		expect(#eliminated).toBe(1)
		expect(eliminated[1].loot).toEqual({})
		expect(eliminated[1].byKingdomId).toBeNil()
		expect(k1.stats.conquered).toBe(0)
		expect(sim:balance(k1.id, "food")).toBe(120)
		F.assertInvariants(sim)
	end)

	it("installs once", function()
		local sim = world()
		expect(function()
			Military.install(sim)
		end).toThrow("already installed")
	end)
end)
