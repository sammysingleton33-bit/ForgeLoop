local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
local Diplomacy = require("@game/ReplicatedStorage/Game/Sim/Diplomacy")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Objectives = require("@game/ReplicatedStorage/Game/Sim/Objectives")
local WorldView = require("@game/ReplicatedStorage/Game/Sim/WorldView")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

-- (i, value) for every argument, nil ones included: a list literal drops its nil entries from `for in`
local function each(...)
	local cases = table.pack(...)
	local i = 0
	return function()
		i += 1
		if i <= cases.n then
			return i, cases[i]
		end
		return nil
	end
end

local RULER, RIVAL = 101, 201

-- k1 (id "crimson") at the origin and k2 ("azure") 300 studs east, at Peace, Military installed.
-- options.citizens: start citizens per kingdom (default none, so units fight undisturbed).
-- options.birthInterval: births are off unless given. Keep level 1 houses 12 (popCap 12).
-- Territory 130 + 30: k1's threat zone reaches x = 160, k2's starts at x = 140.
-- Ids are numbers (CONTRACTS G2): units share EntityIds with citizens; targets are { kind, id }.
local function world(options: { [string]: any }?)
	local opts = options or {}
	local sim, k1 = F.kingdom({
		nodes = false,
		tuning = {
			startCitizens = opts.citizens or {},
			birthInterval = opts.birthInterval or 1e6,
			hungerPerDay = 0.001,
		},
	})
	local k2 = sim:addKingdom({ id = "azure", name = "Rival", x = 300, z = 0 })
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

local function stockUp(sim, k, amounts: { [string]: number })
	for res, amount in amounts do
		F.stock(sim, k):add(res, amount)
	end
end

describe("Kingdom/Military: recruiting", function()
	it("needs a finished barracks (no_barracks for none or a construction site), costing nothing", function()
		local sim, k1 = world()
		local stock = sim.treasury:get(k1.id)
		local ok, err = recruit(RULER, sim, "soldier", 1)
		expect(ok).toBe(false)
		expect(err).toBe("no_barracks")
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		stockUp(sim, k1, { wood = 200, stone = 100 })
		assert(sim:placeBuilding(k1, "barracks", 0, -40))
		stock = sim.treasury:get(k1.id)
		F.events(sim)
		expect(select(2, recruit(RULER, sim, "soldier", 1))).toBe("no_barracks")
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		expect(F.events(sim)).toEqual({})
	end)

	it("Knight and Ram need a level-2 barracks", function()
		local sim, k1 = world()
		stockUp(sim, k1, { food = 280, wood = 300, stone = 300, gold = 300 })
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
		local sim, k1 = world()
		addBuilding(sim, k1, "barracks", 0, -40, 1)
		for _, count in each(0, 11, 1.5, -1, 0 / 0, math.huge, "1", nil) do
			expect(select(2, recruit(RULER, sim, "soldier", count))).toBe("invalid_args")
		end
		for _, kind in each(nil, 5, {}) do
			expect(select(2, recruit(RULER, sim, kind, 1))).toBe("invalid_args")
		end
		expect(select(2, recruit(RULER, sim, "dragon", 1))).toBe("unknown_unit")
		expect(select(2, recruit(RULER, sim, "Soldier", 1))).toBe("unknown_unit")
		expect(F.events(sim)).toEqual({})
	end)

	it("soldiers sleep in barracks bunks, not beds: a kingdom with every bed taken still recruits (D-041)", function()
		local sim, k1 = world({ citizens = { farmer = 12 } })
		stockUp(sim, k1, { food = 280, wood = 300 })
		addBuilding(sim, k1, "barracks", 0, -40, 1) -- 4 bunks
		expect(k1.popCap).toBe(12)
		expect(#k1.citizenIds).toBe(12) -- every bed in the keep is taken, and no house stands
		expect((recruit(RULER, sim, "soldier", 4))).toBe(true)
		expect(sim:getPopulation(k1).cap).toBe(16) -- 12 beds + 4 bunks
		sim:advance(4 * 8)
		expect(#k1.unitIds).toBe(4)
		expect(#k1.citizenIds).toBe(12)
		expect(sim:population(k1)).toBe(16)
		local population = sim:getPopulation(k1)
		expect(population.total).toBe(16)
		expect(population.cap).toBe(16)
		expect(population.byJob.soldier).toBe(4)
		expect(select(2, recruit(RULER, sim, "soldier", 1))).toBe("recruit_cap") -- every bunk is taken
	end)

	it(
		"caps standing soldiers (living + training) at config Military.maxSoldiers, ahead of the bunks (army_cap, D-055)",
		function()
			local sim, k1 = world()
			sim.catalog.tuning.maxSoldiers = 3
			stockUp(sim, k1, { food = 400, wood = 200 })
			local barracks = addBuilding(sim, k1, "barracks", 0, -40, 1)
			barracks.level = 2 -- 8 bunks
			expect(Military.recruitCap(sim, k1)).toBe(8)
			expect(Military.armyCap(sim)).toBe(3)
			expect((recruit(RULER, sim, "soldier", 2))).toBe(true)
			local before = sim:balance(k1.id, "food")
			expect(select(2, recruit(RULER, sim, "soldier", 2))).toBe("army_cap") -- 2 queued + 2 > 3
			expect(sim:balance(k1.id, "food")).toBe(before) -- refused: nothing charged
			expect((recruit(RULER, sim, "soldier", 1))).toBe(true) -- exactly the cap
			expect(select(2, recruit(RULER, sim, "soldier", 1))).toBe("army_cap")
			sim:advance(30) -- trained: the living count against the cap the same way
			expect(#k1.unitIds).toBe(3)
			expect(select(2, recruit(RULER, sim, "soldier", 1))).toBe("army_cap")
			-- a fallen soldier frees a place
			Military.killUnit(sim, sim.units[k1.unitIds[1]], "azure")
			expect((recruit(RULER, sim, "soldier", 1))).toBe(true)
		end
	)

	it("caps soldiers (living + training) at the standing barracks' bunks (recruit_cap, D-041)", function()
		local sim, k1 = world()
		stockUp(sim, k1, { food = 400, wood = 200 })
		addBuilding(sim, k1, "barracks", 0, -40, 1) -- 4 bunks
		expect(Military.recruitCap(sim, k1)).toBe(4)
		expect(sim:bunks(k1)).toBe(4)
		assert(recruit(RULER, sim, "soldier", 3))
		local stock = sim.treasury:get(k1.id)
		expect(select(2, recruit(RULER, sim, "soldier", 2))).toBe("recruit_cap") -- would be 5
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		assert(recruit(RULER, sim, "soldier", 1)) -- exactly 4
		sim:advance(4 * 8)
		expect(#k1.unitIds).toBe(4)
		expect(select(2, recruit(RULER, sim, "soldier", 1))).toBe("recruit_cap") -- trained ones still count
		local second = addBuilding(sim, k1, "barracks", 40, -40, 2) -- + 8 bunks
		expect(Military.recruitCap(sim, k1)).toBe(12)
		assert(recruit(RULER, sim, "soldier", 1))
		second.destroyed = true
		expect(Military.recruitCap(sim, k1)).toBe(4)
	end)

	it("bunks follow the barracks level: 4 / 8 / 12 / 16 (Buildings.luau, PROVISIONAL)", function()
		local sim, k1 = world()
		local b = addBuilding(sim, k1, "barracks", 0, -40, 1)
		for level, bunks in { 4, 8, 12, 16 } do
			b.level = level
			expect(sim:bunks(k1)).toBe(bunks)
			expect(sim:getPopulation(k1).cap).toBe(k1.popCap + bunks)
		end
		b.level = 0 -- a construction site sleeps nobody
		expect(sim:bunks(k1)).toBe(0)
		expect(sim:getPopulation(k1).cap).toBe(k1.popCap)
	end)

	it("births fill the beds with citizens only: soldiers in training or trained never take one (D-041)", function()
		-- 8 citizens of 12 beds; births every 5 s with plenty of food; 4 recruits in a level 1 barracks
		local sim, k1 = world({ citizens = { farmer = 8 }, birthInterval = 5 })
		stockUp(sim, k1, { food = 880, wood = 300 })
		addBuilding(sim, k1, "barracks", 0, -40, 1)
		assert(recruit(RULER, sim, "soldier", 4))
		for _ = 1, 40 do
			sim:advance(1)
			expect(#k1.citizenIds).toBeLessThanOrEqual(k1.popCap)
			expect(#k1.unitIds + sim:queuedUnits(k1)).toBeLessThanOrEqual(sim:bunks(k1))
		end
		local born = F.count(F.events(sim, "CitizenBorn"), function(e)
			return e.kingdomId == "crimson" -- azure grows to its own cap meanwhile
		end)
		expect(born).toBe(4) -- the four free beds, whatever the barracks holds
		expect(#k1.citizenIds).toBe(12)
		expect(#k1.unitIds).toBe(4)
		expect(sim:population(k1)).toBe(16)
	end)

	it("a barracks' trainSpeed shortens training (level 3: x1.25)", function()
		local sim, k1 = world()
		stockUp(sim, k1, { wood = 100 })
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 3)
		expect(sim.catalog.buildings.barracks.levels[3].trainSpeed).toBe(1.25)
		assert(recruit(RULER, sim, "soldier", 1))
		F.events(sim)
		sim:advance(6.375) -- 8 s / 1.25 = 6.4 s
		expect(#F.events(sim, "UnitRecruited")).toBe(0)
		sim:advance(0.125)
		expect(#F.events(sim, "UnitRecruited")).toBe(1)
		expect(#barracks.queue).toBe(0)
	end)

	it("a barracks lost with recruits queued or in training refunds each of them in full (D-041)", function()
		local sim, k1 = world()
		stockUp(sim, k1, { food = 280, wood = 300 })
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 2)
		assert(recruit(RULER, sim, "soldier", 1))
		sim:advance(8.25) -- trained: a living soldier is never refunded
		expect(#k1.unitIds).toBe(1)
		assert(recruit(RULER, sim, "soldier", 3)) -- 90 food, 30 wood
		sim:advance(3)
		expect(#barracks.queue).toBe(3)
		expect(barracks.queue[1].remaining < 8).toBe(true) -- the first is in training
		local food, wood = sim:balance(k1.id, "food"), sim:balance(k1.id, "wood")
		F.events(sim)
		Military.destroyBuilding(sim, barracks, "azure")
		expect(sim:balance(k1.id, "food")).toBe(food + 90)
		expect(sim:balance(k1.id, "wood")).toBe(wood + 30)
		expect(F.stock(sim, k1):flows().income.refund).toEqual({ food = 90, wood = 30 })
		expect(#barracks.queue).toBe(0)
		sim:advance(30)
		expect(#F.events(sim, "UnitRecruited")).toBe(0) -- nothing trains in a ruin
		expect(#k1.unitIds).toBe(1)
		expect(Military.recruitCap(sim, k1)).toBe(0)
		F.assertInvariants(sim)
	end)

	it("cannot_afford leaves stock, queue and events untouched", function()
		local sim, k1 = world()
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 2) -- 8 bunks: only the price limits here
		local stock = sim.treasury:get(k1.id) -- food 120: four soldiers cost 120, five cost 150
		expect(select(2, recruit(RULER, sim, "soldier", 5))).toBe("cannot_afford")
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		expect(#barracks.queue).toBe(0)
		expect(F.events(sim)).toEqual({})
		expect(F.stock(sim, k1):flows().expense.recruit).toBeNil()
		expect(#sim.treasury:ledger(k1.id)).toBe(0) -- nothing booked at all
		expect((recruit(RULER, sim, "soldier", 4))).toBe(true)
		expect(sim:balance(k1.id, "food")).toBe(0)
	end)

	it("spends cost x count at once, booked as 'recruit', and announces the queue", function()
		local sim, k1 = world()
		stockUp(sim, k1, { wood = 100 })
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 1)
		local ok, err, result = recruit(RULER, sim, "archer", 3)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ barracksId = barracks.id, count = 3 })
		expect(sim.treasury:get(k1.id)).toEqual({ food = 30, wood = 110, stone = 50, gold = 0 })
		expect(F.stock(sim, k1):flows().expense.recruit).toEqual({ food = 90, wood = 90 })
		local ledger = sim.treasury:ledger(k1.id)
		expect(ledger[#ledger].sink).toBe("unit:archer") -- G7 spend with the unit as sink
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
		local sim, k1 = world()
		stockUp(sim, k1, { food = 280, wood = 300 })
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
		local sim, k1 = world()
		stockUp(sim, k1, { wood = 100 })
		local barracks = addBuilding(sim, k1, "barracks", 0, -40, 1)
		assert(recruit(RULER, sim, "soldier", 1))
		assert(recruit(RULER, sim, "archer", 1))
		F.events(sim)
		sim:advance(7.75)
		expect(#k1.unitIds).toBe(0)
		expect(#F.events(sim, "UnitRecruited")).toBe(0)
		sim:advance(0.25) -- soldier trainTime 8
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
		sim:advance(0.25) -- archer trainTime 10, after the soldier
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
		local sim, k1, k2 = world()
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
		local sim, k1 = world()
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
		local sim, k1, k2 = world()
		local a = unit(sim, k1, "soldier", 150, 0)
		local b = unit(sim, k2, "soldier", 153, 0)
		local intruder = unit(sim, k2, "soldier", 30, 0) -- inside k1's keep range
		sim:advance(5)
		expect(a.hp).toBe(80)
		expect(b.hp).toBe(80)
		expect(intruder.hp).toBe(80)
		expect(sim.buildings[k1.keepId].hp).toBe(sim.buildings[k1.keepId].maxHp)
		expect(#F.events(sim, "UnitKilled")).toBe(0)
		expect(k1.threats).toEqual({})
	end)

	it("at War, units kill enemy units and both sides count it", function()
		local sim, k1, k2 = world()
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
		-- each kill is worth Crown Points to the killer
		local crown = sim.catalog.crown.unitKill
		expect(crown).toBeGreaterThan(0)
		expect(k1.crownPoints).toBe(crown)
		expect(k2.crownPoints).toBe(0)
		for _, u in mine do
			expect(u.alive).toBe(true)
		end
	end)

	it("Hold units stay where they stand and only fight what is in weapon range", function()
		local sim, k1, k2 = world()
		war(sim)
		local holder = unit(sim, k1, "soldier", 150, 0)
		local bait = unit(sim, k2, "ram", 170, 0) -- inside aggro (35) but outside weapon range (5)
		sim:advance(3)
		expect(holder.x).toBe(150)
		expect(holder.z).toBe(0)
		expect(bait.hp).toBe(bait.maxHp)
		bait.x = 153 -- now in weapon range
		sim:advance(1)
		expect(holder.x).toBe(150)
		expect(bait.hp).toBeLessThan(bait.maxHp)
	end)

	it("a unit closing in from any direction reaches striking range (no floating-point stall)", function()
		local stalled = {}
		for i = 0, 35 do
			local sim, k1, k2 = world()
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
		local sim, k1, k2 = world()
		war(sim)
		local near = unit(sim, k2, "soldier", 30, 0)
		local farther = unit(sim, k2, "soldier", 0, 38)
		local outside = unit(sim, k2, "soldier", -41, 0) -- keep range is 40
		sim:advance(0.25) -- one former 4 Hz tick
		expect(near.hp).toBe(70) -- keep damage 10
		expect(farther.hp).toBe(80)
		sim:advance(1.25)
		expect(near.hp).toBe(70) -- cooldown 1.5
		sim:advance(0.25)
		expect(near.hp).toBe(60)
		expect(outside.hp).toBe(80)

		local tower = addBuilding(sim, k1, "watchtower", 80, 80, 1)
		local target = unit(sim, k2, "soldier", 80, 120) -- 40 from the tower, 144 from the keep
		sim:advance(0.25) -- one former 4 Hz tick
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
		local sim, k1, k2 = world()
		war(sim)
		local wall = addBuilding(sim, k1, "wall", 100, 0, 1)
		local ram = unit(sim, k2, "ram", 110, 0)
		sim:advance(0.25) -- one former 4 Hz tick
		expect(ram.target).toEqual({ kind = "building", id = wall.id })
		expect(wall.hp).toBe(900 - 60 * 4)
		local soldier = unit(sim, k2, "soldier", 108, 3) -- 4.5 from the wall's edge: in range
		sim:advance(3) -- ram strikes again at 3.25 (cooldown 3); soldier at 0.5, 1.5, 2.5
		expect(wall.hp).toBe(900 - 240 * 2 - 2 * 3) -- soldier siege 0.25: 8 x 0.25 = 2 a hit
		sim:advance(5.75)
		expect(sim.buildings[wall.id]).toBe(wall) -- 900 - 3 x 240 - 8 x 2 = 164 left
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
		expect(soldier.alive).toBe(true)

		-- far from any building, a ram next to an enemy soldier never strikes it
		local defender = unit(sim, k1, "soldier", 150, -150)
		local lonelyRam = unit(sim, k2, "ram", 152, -150)
		sim:advance(4)
		expect(defender.hp).toBe(80)
		expect(lonelyRam.hp).toBeLessThan(lonelyRam.maxHp)
		F.assertInvariants(sim)
	end)

	it("soft blocking: a unit chasing a target behind an enemy wall stops at the wall and breaks it first", function()
		local sim, k1, k2 = world()
		war(sim)
		local wall = addBuilding(sim, k1, "wall", 125, 0, 1)
		wall.hp = 6 -- three soldier hits (2 each against a building)
		local bait = unit(sim, k1, "ram", 110, 0) -- behind the wall; rams do not fight back
		local raider = unit(sim, k2, "soldier", 140, 0, { kind = "Move", x = 100, z = 0 })
		local blockedAt = nil
		for _ = 1, 20 do
			sim:advance(0.25) -- one former 4 Hz tick
			if
				raider.target ~= nil
				and raider.target.kind == "building"
				and raider.target.id == wall.id
				and blockedAt == nil
			then
				blockedAt = raider.x
			end
			if sim.buildings[wall.id] then
				-- never inside the wall's footprint while it stands
				expect(raider.x).toBeGreaterThanOrEqual(125 + 4 + Military.UNIT_RADIUS)
				expect(bait.hp).toBe(bait.maxHp)
			end
		end
		expect(blockedAt).toBeTruthy()
		expect(sim.buildings[wall.id]).toBeNil()
		sim:advance(5)
		expect(bait.hp).toBeLessThan(bait.maxHp) -- through the breach to the target

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
			local sim, k1, k2 = world({ citizens = { farmer = 2 } })
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
				sim:advance(0.25) -- one former 4 Hz tick
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
			expect(keep.hp).toBeLessThan(keep.maxHp) -- the raider at the keep hit the building instead
			expect(siege.alive).toBe(true)
			expect(raider.alive).toBe(true)
			F.assertInvariants(sim)
		end
	)

	it("lists enemy units inside territory (+30) as threats; citizens near one flee and remember it", function()
		local sim, k1, k2 = world({ citizens = { farmer = 3 } })
		sim:advance(10) -- farmers walk to the farm at about (28, 19)
		local farmers = sim:citizensOf(k1)
		local intruder = unit(sim, k2, "soldier", 55, 19)
		local distant = unit(sim, k2, "soldier", 170, 0) -- beyond 130 + 30
		sim:advance(0.25) -- one former 4 Hz tick
		expect(k1.threats).toEqual({}) -- at peace nobody is a threat
		war(sim)
		sim:advance(0.25) -- one former 4 Hz tick
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
		sim:advance(0.25) -- one former 4 Hz tick
		expect(k1.threats).toEqual({})
		expect(distant.alive).toBe(true)
	end)
end)

describe("Kingdom/Military: conquest", function()
	it("destroying a Keep eliminates the kingdom, removes everything it had and pays the conqueror", function()
		local sim, k1, k2 = world({ citizens = { farmer = 2 } })
		war(sim)
		local house = addBuilding(sim, k2, "house", 300, 40, 1)
		local guard = unit(sim, k2, "soldier", 420, 100)
		local ram = unit(sim, k1, "ram", 300 - 14 - 5, 0)
		local attacker = unit(sim, k1, "soldier", -40, 0, { kind = "Attack", kingdomId = "azure" })
		sim.buildings[k2.keepId].hp = 200 -- one ram blow (240)
		local k2Citizens = table.clone(k2.citizenIds)
		local k2Buildings = table.clone(k2.buildingIds)
		F.events(sim)
		sim:advance(0.25) -- one former 4 Hz tick

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
		expect(eliminated.loot).toEqual({ food = 60, wood = 50, stone = 25 }) -- half of 120/100/50/0
		expect(k2.alive).toBe(false)
		expect(k2.eliminatedBy).toBe("crimson")
		expect(k2.eliminatedAt > sim.time - 0.25 and k2.eliminatedAt <= sim.time).toBe(true) -- within the last step
		expect(k1.stats.conquered).toBe(1)
		expect(k1.crownPoints).toBe(sim.catalog.crown.conquest)
		expect(sim.treasury:get(k1.id)).toEqual({ food = 180, wood = 150, stone = 75, gold = 0 })
		expect(F.stock(sim, k1):flows().income.loot).toEqual({ food = 60, wood = 50, stone = 25 })
		expect(F.stock(sim, k2):flows().expense.plundered).toEqual({ food = 120, wood = 100, stone = 50 })
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
		local sim, k1, k2 = world()
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
		expect(k1.crownPoints).toBe(0)
		expect(sim:balance(k1.id, "food")).toBe(120)
		expect(sim.treasury:get(k2.id)).toEqual({ food = 0, wood = 0, stone = 0, gold = 0 })
		F.assertInvariants(sim)
	end)

	it("installs once", function()
		local sim = world()
		expect(function()
			Military.install(sim)
		end).toThrow("already installed")
	end)
end)

-- (x, z) of every unit Military.spawnUnit creates while `fn` runs (training spawns through it).
local function spawnedDuring(fn: () -> ()): { { x: number, z: number, id: number } }
	local spawned = {}
	local original = Military.spawnUnit
	Military.spawnUnit = function(sim, kingdom, kind, x, z)
		local u = original(sim, kingdom, kind, x, z)
		table.insert(spawned, { x = x, z = z, id = u.id })
		return u
	end
	local ok, err = pcall(fn)
	Military.spawnUnit = original
	assert(ok, err)
	return spawned
end

-- The world position of the Kit barracks' Rally attachment for a simulated barracks.
local function kitRally(b): Vector3
	local model = Kit.build("barracks", math.max(1, b.level), "complete", Kit.NEUTRAL_COLOR)
	WorldView.placeModel(model, CFrame.new(b.x, 0, b.z) * CFrame.Angles(0, b.yaw, 0))
	local root = model.PrimaryPart :: BasePart
	local rally = root:FindFirstChild("Rally") :: Attachment
	return (root.CFrame * rally.CFrame).Position
end

local function order(userId: number, sim, ...)
	return Commands.execute(sim, userId, "UnitOrder", ...)
end

local function near(u, x: number, z: number): number
	return math.sqrt((u.x - x) ^ 2 + (u.z - z) ^ 2)
end

describe("Kingdom/Military: recruiting at a chosen barracks, Rally (FL-0052)", function()
	it("trains at the barracks asked for, even when another one has a shorter queue", function()
		local sim, k1 = world()
		stockUp(sim, k1, { food = 280, wood = 300 })
		local first = addBuilding(sim, k1, "barracks", 0, -40, 1)
		local second = addBuilding(sim, k1, "barracks", 0, 40, 1)
		local _, err, a = Commands.execute(sim, RULER, "Recruit", "soldier", 2, second.id)
		expect(err).toBeNil()
		expect(a).toEqual({ barracksId = second.id, count = 2 })
		local _, _, b = Commands.execute(sim, RULER, "Recruit", "soldier", 1, second.id)
		expect(b.barracksId).toBe(second.id) -- first has the shorter queue; the id wins
		expect(#first.queue).toBe(0)
		expect(#second.queue).toBe(3)
		local _, _, c = recruit(RULER, sim, "soldier", 1) -- without an id: the shortest queue, as before
		expect(c.barracksId).toBe(first.id)
	end)

	it("refuses an unknown, foreign, non-barracks, unfinished or too-low barracks and charges nothing", function()
		local sim, k1, k2 = world()
		stockUp(sim, k1, { food = 280, wood = 300, stone = 300, gold = 300 })
		local mine = addBuilding(sim, k1, "barracks", 0, -40, 1)
		local theirs = addBuilding(sim, k2, "barracks", 300, -40, 1)
		local site = assert(sim:placeBuilding(k1, "barracks", 40, 40))
		F.events(sim)
		local stock = sim.treasury:get(k1.id)
		local cases = {
			{ "invalid_args", "soldier", 0 },
			{ "invalid_args", "soldier", 1.5 },
			{ "invalid_args", "soldier", "1" },
			{ "invalid_args", "soldier", 0 / 0 },
			{ "not_found", "soldier", 999 },
			{ "not_owner", "soldier", theirs.id },
			{ "not_barracks", "soldier", k1.keepId },
			{ "barracks_not_ready", "soldier", site.id },
			{ "requires_barracks_level", "knight", mine.id },
		}
		for _, case in cases do
			local ok, err = Commands.execute(sim, RULER, "Recruit", case[2], 1, case[3])
			expect(ok).toBe(false)
			expect(err).toBe(case[1])
		end
		mine.destroyed = true
		expect(select(2, Commands.execute(sim, RULER, "Recruit", "soldier", 1, mine.id))).toBe("not_found")
		expect(sim.treasury:get(k1.id)).toEqual(stock)
		expect(#theirs.queue).toBe(0)
		expect(F.events(sim)).toEqual({})
	end)

	it("a trained unit appears at the barracks' Kit Rally, turned with the building; the next beside it", function()
		local sim, k1 = world()
		stockUp(sim, k1, { food = 280, wood = 300 })
		local b = sim:_createBuilding(k1, "barracks", 60, -60, 0.7)
		sim:_completeInstantly(b)
		b.level = 2 -- 8 bunks for the five recruits
		sim:_recompute(k1)
		assert(Commands.execute(sim, RULER, "Recruit", "soldier", 3, b.id))
		local spawned = spawnedDuring(function()
			sim:advance(3 * 8 + 0.25)
		end)
		expect(#spawned).toBe(3)
		local rally = kitRally(b)
		expect(spawned[1].x).toBeNear(rally.X, 1e-3)
		expect(spawned[1].z).toBeNear(rally.Z, 1e-3)
		local front = Vector3.new(-math.sin(b.yaw), 0, -math.cos(b.yaw)) -- Kit models face -Z
		local toRally = Vector3.new(rally.X - b.x, 0, rally.Z - b.z)
		expect(toRally.Unit:Dot(front)).toBeNear(1, 1e-3) -- in front of the building
		-- the first one walks off to defend before the next is trained: the Rally is free again
		expect(spawned[2].x).toBeNear(rally.X, 1e-3)
		expect(spawned[2].z).toBeNear(rally.Z, 1e-3)
		-- recruits still standing on the Rally push the next ones sideways, perpendicular to the front
		for _, entry in spawned do
			local u = sim.units[entry.id]
			u.order = { kind = "Hold" }
			u.x, u.z = rally.X, rally.Z
		end
		assert(Commands.execute(sim, RULER, "Recruit", "soldier", 2, b.id))
		local fourth = spawnedDuring(function()
			sim:advance(8.25)
		end)
		expect(#fourth).toBe(1)
		local stays = sim.units[fourth[1].id]
		stays.order = { kind = "Hold" }
		stays.x, stays.z = fourth[1].x, fourth[1].z
		local fifth = spawnedDuring(function()
			sim:advance(8)
		end)
		expect(#fifth).toBe(1)
		local right = Vector3.new(fourth[1].x - rally.X, 0, fourth[1].z - rally.Z)
		local left = Vector3.new(fifth[1].x - rally.X, 0, fifth[1].z - rally.Z)
		-- (Vector3 is single precision: compare to 1e-3)
		expect(right.Magnitude).toBeNear(3, 1e-3)
		expect(left.Magnitude).toBeNear(3, 1e-3)
		expect(math.abs(right.Unit:Dot(front)) < 1e-3).toBe(true)
		expect(right.Unit:Dot(left.Unit)).toBeNear(-1, 1e-3) -- one on each side
	end)
end)

describe("Kingdom/Military: unit orders (UnitOrder, G8 Army.Command)", function()
	it("validates ids, kind and arguments without changing any unit", function()
		local sim, k1 = world()
		local u = unit(sim, k1, "soldier", 10, 30, { kind = "Defend" })
		local many = {}
		for i = 1, 51 do
			many[i] = i
		end
		local nan = 0 / 0
		local cases = {
			{ "invalid_args", "x", "move", 0, 0 },
			{ "invalid_args", nil, "move", 0, 0 },
			{ "too_many_units", many, "move", 0, 0 },
			{ "invalid_args", { 1.5 }, "move", 0, 0 },
			{ "invalid_args", { 0 }, "move", 0, 0 },
			{ "invalid_args", { 70000 }, "move", 0, 0 },
			{ "invalid_args", { [1] = u.id, [3] = u.id }, "move", 0, 0 },
			{ "invalid_args", { a = u.id }, "move", 0, 0 },
			{ "invalid_args", { u.id }, 5, 0, 0 },
			{ "unknown_order", { u.id }, "charge", 0, 0 },
			{ "unknown_order", { u.id }, "Move", 0, 0 },
			{ "invalid_args", { u.id }, "move" },
			{ "invalid_args", { u.id }, "move", nan, 0 },
			{ "invalid_args", { u.id }, "move", 0, math.huge },
			{ "invalid_args", { u.id }, "guard", 0 },
			{ "out_of_bounds", { u.id }, "move", 3900, 900 }, -- the map is ±1024 here
			{ "out_of_bounds", { u.id }, "move", 0, -1025 },
			{ "out_of_bounds", { u.id }, "guard", 1024.5, 0 },
			{ "out_of_bounds", { u.id }, "capture", -2000, 0, "tower" },
			{ "no_objective", { u.id }, "capture" }, -- no target and no objective it does not own
			{ "unknown_objective", { u.id }, "capture", nil, nil, "tower" },
			{ "invalid_args", { u.id }, "attack" },
			{ "unknown_target", { u.id }, "attack", nil, nil, "k9" },
			{ "unknown_target", { u.id }, "attack", nil, nil, "building:999" },
			{ "unknown_target", { u.id }, "attack", nil, nil, "entity:999" },
			{ "unknown_kingdom", { u.id }, "attack", nil, nil, "crimson" },
			{ "not_at_war", { u.id }, "attack", nil, nil, "azure" },
			{ "not_at_war", { u.id }, "attack", nil, nil, `building:{k1.keepId}` },
		}
		for _, case in cases do
			local ok, err = order(RULER, sim, case[2], case[3], case[4], case[5], case[6])
			expect(ok).toBe(false)
			expect(err).toBe(case[1])
		end
		expect(u.order).toEqual({ kind = "Defend" })
		expect(F.events(sim)).toEqual({})
	end)

	it("commands only the kingdom's own living units; foreign, unknown and dead ids are ignored and counted", function()
		local sim, k1, k2 = world()
		local a = unit(sim, k1, "soldier", 10, 30)
		local b = unit(sim, k1, "soldier", -10, 30)
		local foreign = unit(sim, k2, "soldier", 300, 30, { kind = "Defend" })
		local dead = unit(sim, k1, "soldier", 0, 30)
		Military.killUnit(sim, dead, nil)
		F.events(sim)
		local ok, err, result = order(RULER, sim, { a.id, foreign.id, 999, dead.id, a.id }, "move", 60, -60)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ kind = "move", count = 1, ignored = 3 })
		expect(a.order).toEqual({ kind = "Move", x = 60, z = -60 })
		expect(b.order).toEqual({ kind = "Hold" })
		expect(foreign.order).toEqual({ kind = "Defend" })
		local ordered = F.events(sim, "UnitsOrdered")
		expect(#ordered).toBe(1)
		expect(ordered[1].count).toBe(1)
		expect(ordered[1].by).toBe(RULER)
		expect(select(2, order(RULER, sim, { foreign.id }, "move", 0, 0))).toBe("no_units")
		expect(select(2, order(RIVAL, sim, { a.id, b.id }, "move", 0, 0))).toBe("no_units")
		expect(a.order).toEqual({ kind = "Move", x = 60, z = -60 })
	end)

	it("an empty list commands every idle unit: at home, holding, guarding or done moving, not busy ones", function()
		local sim, k1, k2 = world()
		local home = unit(sim, k1, "soldier", 10, 30, { kind = "Defend" })
		local holding = unit(sim, k1, "soldier", 12, 30, { kind = "Hold" })
		local guarding = unit(sim, k1, "soldier", 14, 30, { kind = "Guard", x = 14, z = 30 })
		local arrived = unit(sim, k1, "soldier", 16, 30, { kind = "Move", x = 17, z = 30 })
		local marching = unit(sim, k1, "soldier", 18, 30, { kind = "Move", x = 200, z = 30 })
		local capturing = unit(sim, k1, "soldier", 20, 30, { kind = "Capture", objectiveId = "tower", x = 0, z = 0 })
		local fighting = unit(sim, k1, "soldier", 22, 30, { kind = "Defend" })
		local enemy = unit(sim, k2, "soldier", 300, 0)
		fighting.target = { kind = "unit", id = enemy.id }
		local rival = unit(sim, k2, "soldier", 300, 10, { kind = "Defend" })
		local ok, _, result = order(RULER, sim, {}, "guard", 40, 40)
		expect(ok).toBe(true)
		expect(result).toEqual({ kind = "guard", count = 4, ignored = 0 })
		for _, u in { home, holding, guarding, arrived } do
			expect(u.order.kind).toBe("Guard")
		end
		expect(marching.order.kind).toBe("Move")
		expect(capturing.order.kind).toBe("Capture")
		expect(fighting.order.kind).toBe("Defend")
		expect(rival.order.kind).toBe("Defend") -- never another kingdom's
		expect(Military.isIdle(marching)).toBe(false)
		for _, u in { home, holding, guarding, arrived, marching, capturing, fighting } do
			u.order = { kind = "Move", x = u.x, z = u.z + 100 }
			u.target = nil
		end
		expect(select(2, order(RULER, sim, {}, "move", 0, 0))).toBe("no_units") -- nobody idle
	end)

	it("move: the units march to the point and stand spread around it", function()
		local sim, k1 = world()
		local units = {}
		for i = 1, 5 do
			table.insert(units, unit(sim, k1, "soldier", -10 + i * 4, 30, { kind = "Defend" }))
		end
		local ids = {}
		for _, u in units do
			table.insert(ids, u.id)
		end
		assert(order(RULER, sim, ids, "move", 60, -60))
		sim:advance(20)
		expect(near(units[1], 60, -60)).toBeLessThanOrEqual(2 + 1e-6) -- the first stands on the point
		for i, u in units do
			expect(near(u, 60, -60)).toBeLessThanOrEqual(3 * math.sqrt(i - 1) + 2 + 1e-6)
			expect(Military.isIdle(u)).toBe(true) -- arrived: idle again
		end
		for i = 2, #units do
			for j = 1, i - 1 do
				expect(near(units[i], units[j].x, units[j].z) > 1).toBe(true) -- not stacked
			end
		end
	end)

	it("guard: units hold the point, fight only within GUARD_RADIUS of it and return to it", function()
		local sim, k1, k2 = world()
		war(sim)
		local g = unit(sim, k1, "soldier", 150, -150, { kind = "Defend" })
		assert(order(RULER, sim, { g.id }, "guard"))
		expect(g.order).toEqual({ kind = "Guard", x = 150, z = -150 }) -- no point: where it stands
		local far = unit(sim, k2, "ram", 150 + 30, -150) -- in aggro (35) but 30 from the point (> 25)
		sim:advance(5)
		expect(near(g, 150, -150)).toBeLessThanOrEqual(1e-6)
		expect(far.hp).toBe(far.maxHp)
		local bait = unit(sim, k2, "ram", 150 + 12, -150) -- inside the guarded ground
		sim:advance(3)
		expect(near(g, bait.x, bait.z)).toBeLessThanOrEqual(5 + 1e-6)
		expect(bait.hp < bait.maxHp).toBe(true)
		bait.x = 150 + 200 -- leaves
		far.x = 150 + 200
		sim:advance(4)
		expect(near(g, 150, -150)).toBeLessThanOrEqual(1 + 1e-6)
		expect(g.order.kind).toBe("Guard")
	end)

	it("capture: units march into the objective's zone and hold it through the capture", function()
		local sim, k1 = world()
		Objectives.install(sim, { { id = "tower", x = 0, z = -200, captureSeconds = 10, crownPoints = 100 } })
		local tower = sim.objectives.list[1]
		local units = {}
		for i = 1, 3 do
			table.insert(units, unit(sim, k1, "soldier", i * 3, -40, { kind = "Defend" }))
		end
		local ok, err, result = order(RULER, sim, {}, "capture", nil, nil, "tower")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result.count).toBe(3)
		for _, u in units do
			expect(u.order.kind).toBe("Capture")
			expect(u.order.objectiveId).toBe("tower")
			expect(near(u, u.order.x, u.order.z) > 100).toBe(true) -- destination: inside the zone
			local fromCentre = math.sqrt(u.order.x ^ 2 + (u.order.z + 200) ^ 2)
			expect(fromCentre).toBeLessThanOrEqual(tower.radius * 0.8 + 1e-6) -- well inside the zone
			expect(fromCentre).toBeGreaterThanOrEqual(9 - 1e-6) -- clear of the 14 x 14 watchtower
		end
		F.events(sim)
		sim:advance(30)
		expect(tower.owner).toBe("crimson")
		local captured = F.events(sim, "ObjectiveCaptured")
		expect(#captured).toBe(1)
		expect(captured[1].kingdomId).toBe("crimson")
		expect(sim.regions[tower.regionId].kingdomId).toBe("crimson")
		sim:advance(10)
		for _, u in units do
			expect(near(u, tower.x, tower.z)).toBeLessThanOrEqual(tower.radius) -- still holding it
		end
	end)

	it("capture: once the kingdom owns the objective the order ends, each unit guards its spot (idle)", function()
		local sim, k1 = world()
		Objectives.install(sim, {
			{ id = "tower", x = 0, z = -200, captureSeconds = 10 },
			{ id = "mill", x = 200, z = -200, captureSeconds = 10 },
		})
		local tower = sim.objectives.list[1]
		local units = {}
		for i = 1, 3 do
			table.insert(units, unit(sim, k1, "soldier", i * 3, -40, { kind = "Defend" }))
		end
		assert(order(RULER, sim, {}, "capture", nil, nil, "tower"))
		local spots = {}
		for _, u in units do
			table.insert(spots, { x = u.order.x, z = u.order.z })
		end
		sim:advance(8) -- marching
		for _, u in units do
			expect(Military.isIdle(u)).toBe(false)
		end
		while tower.owner == nil and sim.time < 60 do
			sim:advance(0.25)
		end
		expect(tower.owner).toBe("crimson")
		sim:advance(0.25)
		for i, u in units do
			expect(u.order).toEqual({ kind = "Guard", x = spots[i].x, z = spots[i].z })
			expect(Military.isIdle(u)).toBe(true)
			expect(near(u, tower.x, tower.z)).toBeLessThanOrEqual(tower.radius) -- still standing on it
		end
		-- so Send-to-capture takes them on to the next objective
		local ok, err, result = order(RULER, sim, {}, "capture")
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result.count).toBe(3)
		for _, u in units do
			expect(u.order.kind).toBe("Capture")
			expect(u.order.objectiveId).toBe("mill")
		end
	end)

	it(
		"capture without a target (Send-to-capture): the nearest objective it does not own, from the units' centroid",
		function()
			local sim, k1, k2 = world()
			Objectives.install(sim, {
				{ id = "west", x = -220, z = 0 }, -- 20 from the western unit, 120 from the centroid
				{ id = "south", x = -100, z = 60 }, -- 60 from the centroid
				{ id = "held", x = -100, z = 10 }, -- nearest of all, but already the kingdom's
				{ id = "far", x = -100, z = -200 },
			})
			sim.objectives.list[3].owner = "crimson"
			local west = unit(sim, k1, "soldier", -200, 0, { kind = "Defend" })
			local east = unit(sim, k1, "soldier", 0, 0, { kind = "Defend" })
			local busy = unit(sim, k1, "soldier", -100, 0, { kind = "Move", x = -100, z = 300 }) -- not idle
			local rival = unit(sim, k2, "soldier", 300, 10, { kind = "Defend" })
			F.events(sim)
			local ok, err, result = order(RULER, sim, {}, "capture")
			expect(err).toBeNil()
			expect(ok).toBe(true)
			expect(result).toEqual({ kind = "capture", count = 2, ignored = 0 })
			for _, u in { west, east } do
				expect(u.order.kind).toBe("Capture")
				expect(u.order.objectiveId).toBe("south")
				expect(math.sqrt((u.order.x + 100) ^ 2 + (u.order.z - 60) ^ 2)).toBeLessThanOrEqual(18 * 0.8 + 1e-6)
			end
			expect(busy.order.kind).toBe("Move")
			expect(rival.order.kind).toBe("Defend")
			expect(#F.events(sim, "UnitsOrdered")).toBe(1)
			-- listed units work the same way; an objective another kingdom owns counts as not ours
			sim.objectives.list[2].owner = "azure"
			assert(order(RULER, sim, { busy.id }, "capture")) -- centroid (-100, 0): south is 60 away
			expect(busy.order.objectiveId).toBe("south")
			sim.objectives.list[2].owner = "crimson"
			assert(order(RULER, sim, { busy.id }, "capture"))
			expect(busy.order.objectiveId).toBe("west") -- 120 away; far is 200
		end
	)

	it("capture without a target when the kingdom owns every objective changes nothing (no_objective)", function()
		local sim, k1 = world()
		Objectives.install(sim, { { id = "tower", x = 0, z = -200 }, { id = "mill", x = 200, z = -200 } })
		for _, o in sim.objectives.list do
			o.owner = "crimson"
		end
		local a = unit(sim, k1, "soldier", 10, 30, { kind = "Defend" })
		local b = unit(sim, k1, "soldier", 12, 30, { kind = "Guard", x = 12, z = 30 })
		F.events(sim)
		expect({ order(RULER, sim, {}, "capture") }).toEqual({ false, "no_objective" })
		expect({ order(RULER, sim, { a.id }, "capture") }).toEqual({ false, "no_objective" })
		expect(a.order).toEqual({ kind = "Defend" })
		expect(b.order).toEqual({ kind = "Guard", x = 12, z = 30 })
		expect(F.events(sim)).toEqual({})
		-- an explicit target the kingdom owns is still allowed (reinforcing it): they guard there
		assert(order(RULER, sim, { a.id }, "capture", nil, nil, "mill"))
		expect(a.order.objectiveId).toBe("mill")
		sim:advance(0.25)
		expect(a.order.kind).toBe("Guard")
	end)

	it("a point off the map is refused (out_of_bounds) and nobody moves; units sent to the edge stay on it", function()
		local sim, k1 = world()
		local units, ids = {}, {}
		for i = 1, 6 do
			local u = unit(sim, k1, "soldier", 1000, 1000 - i * 4, { kind = "Hold" })
			table.insert(units, u)
			table.insert(ids, u.id)
		end
		F.events(sim)
		expect({ order(RULER, sim, ids, "move", 3900, 900) }).toEqual({ false, "out_of_bounds" })
		expect({ order(RULER, sim, {}, "guard", 0, 3900) }).toEqual({ false, "out_of_bounds" })
		expect(F.events(sim)).toEqual({})
		sim:advance(5)
		for i, u in units do
			expect(u.order).toEqual({ kind = "Hold" })
			expect(u.x).toBe(1000) -- nobody marched towards (3900, 900)
			expect(u.z).toBe(1000 - i * 4)
		end
		-- the corner itself is on the map; the spread around it is kept on it too
		assert(order(RULER, sim, ids, "move", sim.bounds.maxX, sim.bounds.maxZ))
		for _, u in units do
			expect(u.order.x <= sim.bounds.maxX and u.order.z <= sim.bounds.maxZ).toBe(true)
		end
		sim:advance(10)
		for _, u in units do
			expect(u.x <= sim.bounds.maxX + 1e-6 and u.z <= sim.bounds.maxZ + 1e-6).toBe(true)
		end
	end)

	it("capture: a march through enemy land breaks a wall in the way instead of standing at it", function()
		local sim, k1, k2 = world()
		war(sim)
		Objectives.install(sim, { { id = "post", x = 60, z = 0, radius = 10 } })
		local wall = addBuilding(sim, k1, "wall", 125, 0, 1) -- 65 from the post: outside the held ground
		wall.hp = 6 -- three soldier hits (2 each against a building)
		local raider = unit(sim, k2, "soldier", 140, 0, { kind = "Defend" })
		assert(order(RIVAL, sim, { raider.id }, "capture", nil, nil, "post"))
		sim:advance(15)
		expect(sim.buildings[wall.id]).toBeNil()
		expect(near(raider, 60, 0)).toBeLessThanOrEqual(10)
	end)

	it("attack: a target id is chased beyond aggro range; afterwards the units guard where they stand", function()
		local sim, k1, k2 = world()
		local u = unit(sim, k1, "soldier", 150, -150, { kind = "Defend" })
		local ram = unit(sim, k2, "ram", 150, -250) -- 100 away: far beyond aggro (35)
		ram.hp = 16 -- two hits
		expect(select(2, order(RULER, sim, { u.id }, "attack", nil, nil, `entity:{ram.id}`))).toBe("not_at_war")
		war(sim)
		assert(order(RULER, sim, { u.id }, "attack", nil, nil, `entity:{ram.id}`))
		expect(u.order).toEqual({ kind = "Attack", focus = { kind = "unit", id = ram.id } })
		sim:advance(4)
		expect(near(u, 150, -150) > 40).toBe(true) -- chasing
		sim:advance(6)
		expect(ram.alive).toBe(false)
		sim:advance(0.25)
		expect(u.order.kind).toBe("Guard")
		expect(u.order.x).toBeNear(u.x, 1e-6)
		-- a kingdom id: march on its keep (ArmyOrder Attack); a building id: that building
		local other = unit(sim, k1, "soldier", 140, -150, { kind = "Defend" })
		assert(order(RULER, sim, { other.id }, "attack", nil, nil, "azure"))
		expect(other.order).toEqual({ kind = "Attack", kingdomId = "azure" })
		assert(order(RULER, sim, { other.id }, "attack", nil, nil, `building:{k2.keepId}`))
		expect(other.order.focus).toEqual({ kind = "building", id = k2.keepId })
	end)

	it("ArmyOrder still orders every unit of the kingdom", function()
		local sim, k1 = world()
		local a = unit(sim, k1, "soldier", 10, 30, { kind = "Capture", objectiveId = "x", x = 0, z = 0 })
		local b = unit(sim, k1, "soldier", 12, 30, { kind = "Guard", x = 12, z = 30 })
		assert(Commands.execute(sim, RULER, "ArmyOrder", "Defend"))
		expect(a.order).toEqual({ kind = "Defend" })
		expect(b.order).toEqual({ kind = "Defend" })
	end)
end)
