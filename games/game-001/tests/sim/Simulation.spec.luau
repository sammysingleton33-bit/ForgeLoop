local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local F = require("./KingdomFixtures")
local Snapshot = require("@game/ReplicatedStorage/Game/Sim/Snapshot")

local function dist(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

describe("Kingdom/Simulation: a new kingdom", function()
	it("has a level-1 keep, a working farm, twelve citizens and the start treasury", function()
		local sim, k = F.kingdom()
		local buildings = sim:buildingsOf(k)
		expect(#buildings).toBe(2)
		expect(buildings[1].kind).toBe("keep")
		expect(buildings[1].level).toBe(1)
		expect(buildings[1].pendingLevel).toBeNil()
		expect(buildings[2].kind).toBe("farm")
		expect(buildings[2].level).toBe(1)
		expect(#k.citizenIds).toBe(12)
		expect(F.jobs(sim, k)).toEqual({ farmer = 3, woodcutter = 3, miner = 2, builder = 2, hauler = 2 })
		expect(k.popCap).toBe(12)
		expect(k.territory).toBe(130)
		expect(k.crownPoints).toBe(0)
		-- G2 ids: numbers for buildings and entities, never reused
		expect(type(k.keepId)).toBe("number")
		expect(type(k.citizenIds[1])).toBe("number")
		expect(sim:citizensOf(k)[1].kind).toBe("citizen")
		expect(sim.treasury:get(k.id)).toEqual({ food = 120, wood = 100, stone = 50, gold = 0 })
		for _, c in sim:citizensOf(k) do
			expect(c.home).toBe(k.keepId)
		end
	end)

	it("rejects a duplicate kingdom id", function()
		local sim = F.kingdom()
		expect(function()
			sim:addKingdom({ id = "crimson", x = 500, z = 500 })
		end).toThrow("unique string id")
	end)

	it("refuses an invalid catalog at construction", function()
		local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")
		local catalog = F.catalog()
		catalog.tuning.dayLength = 0
		expect(function()
			Simulation.new({ random = Random.new(1), catalog = catalog })
		end).toThrow("invalid catalog")
	end)
end)

describe("Kingdom/Simulation: production", function()
	it("a farmer harvests at the farm and delivers food to the keep", function()
		local sim, k = F.kingdom({
			nodes = false,
			tuning = { startCitizens = { farmer = 1 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		F.events(sim)
		sim:advance(60)
		local delivered = F.events(sim, "ResourceGathered")
		expect(#delivered).toBeGreaterThan(0)
		local total = 0
		for _, e in delivered do
			expect(e.resource).toBe("food")
			expect(e.amount).toBe(10) -- two harvests of 5 fill a carry of 10
			expect(e.source).toBe("citizen")
			total += e.amount
		end
		expect(sim:balance(k.id, "food")).toBe(120 + total)
		expect(F.stock(sim, k):flows().income.gathered.food).toBe(total)
		F.assertInvariants(sim)
	end)

	it("a woodcutter takes exactly what it delivers (plus what it carries) out of the tree", function()
		local sim, k = F.kingdom({
			tuning = { startCitizens = { woodcutter = 1 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		local before = 0
		for _, nid in sim.nodeOrder do
			if sim.nodes[nid].resource == "wood" then
				before += sim.nodes[nid].amount
			end
		end
		sim:advance(80)
		local after = 0
		for _, nid in sim.nodeOrder do
			if sim.nodes[nid].resource == "wood" then
				after += sim.nodes[nid].amount
			end
		end
		local c = sim:citizensOf(k)[1]
		local carried = if c.carrying then c.carrying.amount else 0
		local gathered = sim:balance(k.id, "wood") - 100
		expect(gathered).toBeGreaterThan(0)
		expect(before - after).toBe(gathered + carried)
		F.assertInvariants(sim)
	end)

	it("gatherers keep making trips instead of stopping after the first delivery", function()
		local sim = F.kingdom({
			tuning = { startCitizens = { farmer = 1, woodcutter = 1 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		sim:advance(85) -- before nightfall at 90 s
		local trips = { food = 0, wood = 0 }
		for _, e in F.events(sim, "ResourceGathered") do
			trips[e.resource] += 1
		end
		expect(trips.food).toBeGreaterThanOrEqual(4)
		expect(trips.wood).toBeGreaterThanOrEqual(3)
	end)

	it("keeps the resource balance exact over ten minutes of a busy kingdom", function()
		local sim, k = F.kingdom({ seed = 4 })
		local deliveredByRes = { food = 0, wood = 0, stone = 0, gold = 0 }
		assert(sim:placeBuilding(k, "house", 0, -35))
		for _ = 1, 60 do
			sim:advance(10)
			for _, e in F.events(sim, "ResourceGathered") do
				deliveredByRes[e.resource] += e.amount
			end
			F.assertInvariants(sim)
		end
		local flows = F.stock(sim, k):flows()
		for res, amount in deliveredByRes do
			expect((flows.income.gathered or {})[res] or 0).toBe(amount)
		end
		expect(flows.expense.meal.food).toBeGreaterThan(0)
		expect(flows.expense.construction.wood).toBe(40)
	end)

	it("never lets more gatherers claim a node than it has slots", function()
		local sim, k = F.kingdom({
			nodes = false,
			tuning = { startCitizens = { woodcutter = 6 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		local tree = sim:addNode("tree", 40, 0)
		local maxClaims = 0
		for _ = 1, 120 do
			sim:advance(0.5)
			maxClaims = math.max(maxClaims, tree.claims)
			F.assertInvariants(sim)
		end
		expect(maxClaims).toBe(tree.slots)
		-- the others found something else to do instead of queueing
		local idleOrOther = F.count(sim:citizensOf(k), function(c)
			return c.target ~= tree.id
		end)
		expect(idleOrOther).toBeGreaterThanOrEqual(4)
	end)

	it("deposits each trip once through the treasury with a dep:<entityId>:<tripSeq> txId (G5)", function()
		local sim, k = F.kingdom({
			tuning = { startCitizens = { woodcutter = 2 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		sim:advance(85)
		local deposits = {}
		for _, entry in sim.treasury:ledger(k.id) do
			if entry.kind == "deposit" then
				table.insert(deposits, entry)
			end
		end
		expect(#deposits).toBeGreaterThanOrEqual(4)
		local seen = {}
		for _, entry in deposits do
			expect(string.match(entry.txId, "^dep:%d+:%d+$")).toBeTruthy()
			expect(entry.source).toBe("citizen:woodcutter")
			expect(seen[entry.txId]).toBeNil()
			seen[entry.txId] = true
		end
		-- a replayed delivery (same txId) changes nothing
		local wood = sim:balance(k.id, "wood")
		sim.treasury:deposit(k.id, "wood", 10, deposits[1].txId, "citizen:woodcutter")
		expect(sim:balance(k.id, "wood")).toBe(wood)
		F.assertInvariants(sim)
	end)

	it("delivers to the nearest drop-off that accepts the resource (lumber camp: wood only)", function()
		local sim, k = F.kingdom({
			nodes = false,
			tuning = { startCitizens = { woodcutter = 1, farmer = 1 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		sim:addNode("tree", 100, 0)
		local camp = sim:placeBuilding(k, "lumbercamp", 88, 0)
		sim:_completeInstantly(camp)
		local keep = sim.buildings[k.keepId]
		expect(sim:nearestDropoff(k, 100, 0, "wood")).toBe(camp)
		expect(sim:nearestDropoff(k, 100, 0, "food")).toBe(keep)
		expect(sim:nearestDropoff(k, 100, 0)).toBe(camp)
		sim:advance(40)
		local woodcutter = F.count(sim:citizensOf(k), function(c)
			return c.job == "woodcutter" and math.abs(c.x - 100) < 20
		end)
		expect(woodcutter).toBe(1) -- it never walked back to the keep 100 studs away
		expect(sim:balance(k.id, "wood")).toBeGreaterThan(60)
	end)

	it("regrows a depleted tree after its regrow time, and depleted trees still block placement", function()
		local sim, k = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
		local tree = sim:addNode("tree", 0, -50)
		tree.amount = 0
		tree.depletedAt = sim.time
		local ok, err = sim:canPlace(k, "house", 0, -44)
		expect(ok).toBe(false)
		expect(err).toBe("blocked")
		sim:advance(tree.regrow - 2)
		expect(tree.amount).toBe(0)
		sim:advance(3)
		expect(tree.amount).toBe(80)
		expect(#F.events(sim, "NodeRegrown")).toBe(1)
	end)
end)

describe("Kingdom/Simulation: construction", function()
	it("placing a House spends exactly its cost and creates a site", function()
		local sim, k = F.kingdom()
		local building, err = sim:placeBuilding(k, "house", 0, -35, 501)
		expect(err).toBeNil()
		expect(building.level).toBe(0)
		expect(building.pendingLevel).toBe(1)
		expect(sim.treasury:get(k.id)).toEqual({ food = 120, wood = 60, stone = 50, gold = 0 })
		local placed = F.events(sim, "BuildingPlaced")
		expect(#placed).toBe(1)
		expect(placed[1].by).toBe(501)
		expect(placed[1].kind).toBe("house")
	end)

	it("builders finish the house, raising the population cap", function()
		local sim, k = F.kingdom()
		local house = sim:placeBuilding(k, "house", 0, -35)
		F.events(sim)
		sim:advance(60)
		expect(house.level).toBe(1)
		expect(house.pendingLevel).toBeNil()
		expect(house.hp).toBe(300)
		expect(k.popCap).toBe(16)
		expect(k.crownPoints).toBe(sim.catalog.crown.buildingLevel) -- a completed level pays Crown Points
		local done = F.events(sim, "BuildingCompleted")
		expect(#done).toBe(1)
		expect(done[1].buildingId).toBe(house.id)
		expect(#house.builders).toBe(0)
		-- the first four citizens now live in the house
		local inHouse = F.count(sim:citizensOf(k), function(c)
			return c.home == house.id
		end)
		expect(inHouse).toBe(4)
		F.assertInvariants(sim)
	end)

	it("upgrades a farm to level 2 (cost paid up front, more worker slots when done)", function()
		local sim, k = F.kingdom()
		local farm = sim:buildingsOf(k)[2]
		local ok, err = sim:startUpgrade(k, farm.id, 7)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(sim:balance(k.id, "wood")).toBe(40)
		expect(sim:balance(k.id, "stone")).toBe(30)
		expect(farm.level).toBe(1) -- still producing at level 1 while upgrading
		sim:advance(120)
		expect(farm.level).toBe(2)
		expect(sim.catalog.buildings.farm.levels[farm.level].workers).toBe(4)
		F.assertInvariants(sim)
	end)

	it("takes every level's work from Costs.building(type, level).buildSeconds (CONTRACTS G13.5)", function()
		local sim = F.kingdom()
		for kind in sim.catalog.buildings do
			for level = 1, Costs.maxLevel(kind) do
				expect(sim:workFor(kind, level)).toBe((Costs.building(kind, level) :: any).buildSeconds)
			end
		end
	end)

	it("rejects upgrades that are busy, maxed, missing, foreign or unaffordable without side effects", function()
		local sim, k = F.kingdom()
		local other = sim:addKingdom({ id = "azure", x = 400, z = 0 })
		local farm = sim:buildingsOf(k)[2]
		expect(select(2, sim:startUpgrade(k, "b999"))).toBe("not_found")
		expect(select(2, sim:startUpgrade(k, other.keepId))).toBe("not_owner")
		assert(sim:startUpgrade(k, farm.id))
		expect(select(2, sim:startUpgrade(k, farm.id))).toBe("busy")
		local before = sim.treasury:get(k.id)
		expect(select(2, sim:startUpgrade(k, k.keepId))).toBe("cannot_afford")
		expect(sim.treasury:get(k.id)).toEqual(before)
		local wall = sim:placeBuilding(k, "wall", -35, 0)
		sim:_completeInstantly(wall)
		wall.level = #sim.catalog.buildings.wall.levels -- Costs.maxLevel("wall")
		expect(select(2, sim:startUpgrade(k, wall.id))).toBe("max_level")
	end)

	it("cancelling a site refunds half its cost and releases its builders", function()
		local sim, k = F.kingdom()
		local house = sim:placeBuilding(k, "house", 0, -35)
		sim:advance(4)
		local ok, err = sim:cancelConstruction(k, house.id, 3)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(sim.buildings[house.id]).toBeNil()
		expect(sim:balance(k.id, "wood") >= 80).toBe(true) -- 60 left + 20 refund (+ any wood delivered meanwhile)
		expect(F.stock(sim, k):flows().income.refund.wood).toBe(20)
		local cancelled = F.events(sim, "ConstructionCancelled")
		expect(#cancelled).toBe(1)
		expect(cancelled[1].refund).toEqual({ wood = 20 })
		F.assertInvariants(sim)
		expect(select(2, sim:cancelConstruction(k, k.keepId))).toBe("nothing_to_cancel")
	end)

	it("cancelling an upgrade keeps the building at its current level", function()
		local sim, k = F.kingdom()
		local farm = sim:buildingsOf(k)[2]
		assert(sim:startUpgrade(k, farm.id))
		assert(sim:cancelConstruction(k, farm.id))
		expect(farm.level).toBe(1)
		expect(farm.pendingLevel).toBeNil()
		expect(sim.buildings[farm.id]).toBe(farm)
	end)

	it("rejects every invalid placement with a reason and no cost", function()
		local sim, k = F.kingdom()
		local before = sim.treasury:get(k.id)
		local function reason(kind, x, z)
			local ok, err = sim:canPlace(k, kind, x, z)
			expect(ok).toBe(false)
			return err
		end
		expect(reason("Castle", 0, -35)).toBe("unknown_building")
		expect(reason("keep", 0, -35)).toBe("not_placeable")
		expect(reason("watchtower", 0, -35)).toBe("requires_keep_level")
		expect(reason("house", 0, -200)).toBe("out_of_territory")
		expect(reason("house", 0, 0)).toBe("blocked") -- on the keep
		expect(reason("house", 0, -60)).toBe("blocked") -- on a tree
		expect(reason("house", 2000, 0)).toBe("out_of_bounds")
		F.stock(sim, k):spend({ wood = 100 })
		expect(reason("house", 0, -35)).toBe("cannot_afford")
		F.stock(sim, k):add("wood", 400)
		F.stock(sim, k):add("stone", 400)
		assert(sim:placeBuilding(k, "barracks", 0, 30))
		assert(sim:placeBuilding(k, "barracks", -30, 5))
		expect(reason("barracks", -40, 40)).toBe("limit_reached")
		expect(before.food).toBe(sim:balance(k.id, "food"))
	end)
end)

describe("Kingdom/Simulation: daily life", function()
	it("citizens sleep at night and go back to work in the morning", function()
		local sim, k = F.kingdom({ tuning = { birthInterval = 1e6 } })
		sim:advance(110) -- night is 90..120 s
		-- everyone sleeps, except citizens still finishing a delivery
		local awake = F.count(sim:citizensOf(k), function(c)
			return c.activity ~= "Sleep" and c.carrying == nil
		end)
		local sleeping = F.count(sim:citizensOf(k), function(c)
			return c.activity == "Sleep"
		end)
		expect(awake).toBe(0)
		expect(sleeping).toBeGreaterThanOrEqual(7)
		sim:advance(30) -- morning of day 2
		local stillSleeping = F.count(sim:citizensOf(k), function(c)
			return c.activity == "Sleep"
		end)
		expect(stillSleeping).toBe(0)
		local days = F.events(sim, "DayStarted")
		expect(#days).toBe(1)
		expect(days[1].day).toBe(2)
	end)

	it("hungry citizens eat from the stockpile", function()
		local sim, k = F.kingdom({ tuning = { birthInterval = 1e6 } })
		sim:advance(150)
		local meals = F.stock(sim, k):flows().expense.meal
		expect(meals).toBeTruthy()
		expect(meals.food).toBeGreaterThanOrEqual(10)
		for _, c in sim:citizensOf(k) do
			expect(c.hunger).toBeLessThan(1)
		end
	end)

	it("citizens starve to death without food, and the kingdom stays consistent", function()
		local sim, k = F.kingdom({
			nodes = false,
			tuning = {
				startCitizens = { woodcutter = 3 },
				startResources = { food = 0, wood = 0, stone = 0, gold = 0 },
				startBuildings = {},
				hungerPerDay = 4,
				birthInterval = 1e6,
			},
		})
		sim:advance(100) -- starveDeathHunger 3 at 4 per 120 s day -> 90 s
		local died = F.events(sim, "CitizenDied")
		expect(#died).toBe(3)
		for _, e in died do
			expect(e.cause).toBe("starvation")
		end
		expect(#k.citizenIds).toBe(0)
		expect(k.stats.died).toBe(3)
		F.assertInvariants(sim)
	end)

	it("grows the population when there is room and food, and never beyond the cap", function()
		local sim, k = F.kingdom({ tuning = { birthInterval = 10, birthFood = 5 } })
		F.stock(sim, k):add("food", 280)
		local house = sim:placeBuilding(k, "house", 0, -35)
		sim:_completeInstantly(house)
		sim:_recompute(k)
		expect(k.popCap).toBe(16)
		sim:advance(120)
		expect(#k.citizenIds).toBe(16)
		expect(#F.events(sim, "CitizenBorn")).toBe(4)
		expect(F.stock(sim, k):flows().expense.birth.food).toBe(20)
	end)

	it("keeps a bed free for every recruit still training (no births over the cap)", function()
		local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
		local sim, k = F.kingdom({ tuning = { birthInterval = 5, birthFood = 5 } })
		Military.install(sim)
		F.stock(sim, k):add("food", 500)
		F.stock(sim, k):add("wood", 400)
		F.stock(sim, k):add("stone", 400)
		local house = sim:placeBuilding(k, "house", 0, -35)
		sim:_completeInstantly(house)
		local barracks = sim:placeBuilding(k, "barracks", 0, 30)
		sim:_completeInstantly(barracks)
		sim:_recompute(k)
		expect(k.popCap).toBe(16)
		local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
		expect(Commands.executeFor(sim, k, nil, "Recruit", "soldier", 4)).toBe(true) -- 12 + 4 queued = 16
		for _ = 1, 40 do
			sim:advance(1)
			expect(sim:population(k) + sim:queuedUnits(k) <= k.popCap).toBe(true)
		end
		expect(#k.unitIds).toBe(4)
		expect(#F.events(sim, "CitizenBorn")).toBe(0)
	end)

	it("follows the rulers' job quotas, moving citizens through the Laborer pool", function()
		local sim, k = F.kingdom({ tuning = { birthInterval = 1e6 } })
		k.quotas.woodcutter = 5
		k.quotas.farmer = 1
		sim:advance(2)
		local counts = F.jobs(sim, k)
		expect(counts.woodcutter).toBe(5)
		expect(counts.farmer).toBe(1)
		expect(counts.miner).toBe(2)
		expect(counts.builder).toBe(2)
		expect(#F.events(sim, "CitizenReassigned")).toBeGreaterThanOrEqual(2)
	end)

	it("the alarm bell sends everyone into the keep, unloading their cargo there", function()
		local sim, k = F.kingdom({ tuning = { birthInterval = 1e6 } })
		sim:advance(40)
		k.alarm = true
		sim:advance(20)
		local keep = sim.buildings[k.keepId]
		for _, c in sim:citizensOf(k) do
			expect(c.activity).toBe("Flee")
			expect(c.carrying).toBeNil()
			expect(dist(c, keep) <= keep.footprint + 1.01).toBe(true)
		end
		k.alarm = false
		sim:advance(5)
		local fleeing = F.count(sim:citizensOf(k), function(c)
			return c.activity == "Flee"
		end)
		expect(fleeing).toBe(0)
		F.assertInvariants(sim)
	end)

	it("keeps each citizen's memory compact", function()
		local sim, k = F.kingdom()
		local c = sim:citizensOf(k)[1]
		for i = 1, 10 do
			sim:remember(c, { kind = "threat", ref = "u" .. i, x = 0, z = 0 })
		end
		expect(#c.memory).toBe(sim.catalog.tuning.memorySize)
		sim:remember(c, { kind = "threat", ref = "u10", x = 1, z = 1 })
		expect(#c.memory).toBe(sim.catalog.tuning.memorySize)
		expect(c.memory[#c.memory].x).toBe(1)
	end)
end)

describe("Kingdom/Simulation: fixed tick and staggered decisions (G4)", function()
	it("moves entities every tick and spreads routine re-planning across ticks", function()
		local sim, k = F.kingdom({
			seed = 4,
			tuning = { startCitizens = { farmer = 12, woodcutter = 12, miner = 12, hauler = 12 } },
		})
		expect(sim.catalog.tuning.tickSeconds <= 1 / 15).toBe(true) -- ≈20 Hz movement (16 Hz: exact in binary)
		expect(#k.citizenIds).toBe(48)
		sim:advance(5) -- past the opening, when everyone picks a first job at once
		local thinkAt = {}
		for _, id in k.citizenIds do
			thinkAt[id] = sim.citizens[id].thinkAt
		end
		local perTick, total, ticks = {}, 0, 0
		local interval = sim.catalog.tuning.thinkInterval
		local seconds = interval * 5
		for _ = 1, seconds / sim.catalog.tuning.tickSeconds do
			sim:step()
			ticks += 1
			local n = 0
			for _, id in k.citizenIds do
				local c = sim.citizens[id]
				if c and c.thinkAt ~= thinkAt[id] then
					thinkAt[id] = c.thinkAt
					n += 1
				end
			end
			table.insert(perTick, n)
			total += n
		end
		table.sort(perTick)
		local busiest = perTick[#perTick]
		-- 48 citizens re-plan about every `interval` s (later while carrying): ~1-2 per tick, never a crowd
		local budget = math.max(2, math.ceil(48 * sim.catalog.tuning.tickSeconds / interval * 2))
		expect(total >= 48 * 2).toBe(true)
		expect(busiest <= budget).toBe(true)
		expect(ticks).toBe(seconds * 16)
	end)
end)

describe("Kingdom/Simulation: determinism", function()
	it("same seed and same commands give the same world", function()
		local function run()
			local sim, k = F.kingdom({ seed = 11 })
			sim:advance(30)
			assert(sim:placeBuilding(k, "house", 0, -35))
			sim:advance(200)
			return Snapshot.kingdom(sim, "crimson", 1)
		end
		expect(run()).toEqual(run())
	end)

	it("advance() in small or large steps reaches the same state", function()
		local a = F.kingdom({ seed = 2 })
		local b = F.kingdom({ seed = 2 })
		for _ = 1, 400 do
			a:advance(0.25)
		end
		b:advance(100)
		expect(Snapshot.kingdom(a, "crimson", 1)).toEqual(Snapshot.kingdom(b, "crimson", 1))
		expect(a.tick).toBe(100 / a.catalog.tuning.tickSeconds) -- whole ticks, no float drift
		expect(b.tick).toBe(a.tick)
	end)

	it("does nothing while inactive and rejects bad durations", function()
		local sim = F.kingdom()
		sim.active = false
		sim:advance(60)
		expect(sim.time).toBe(0)
		expect(function()
			sim:advance(-1)
		end).toThrow()
		expect(function()
			sim:advance(0 / 0)
		end).toThrow()
	end)
end)

describe("Kingdom/Simulation: work modifiers (G13.3 consequences)", function()
	it("productivity changes add up, expire and never go below 0", function()
		local sim, k = F.kingdom()
		local c = sim.citizens[k.citizenIds[1]]
		expect(sim:productivityOf(c)).toBe(1)
		local CitizenActions = require("@game/ReplicatedStorage/Game/Sim/CitizenActions")
		local base = CitizenActions.skill(sim, c, "farm")
		sim:addProductivity(c, 0.25, 10)
		sim:addProductivity(c, -0.5, 20)
		expect(sim:productivityOf(c)).toBeNear(0.75, 1e-9)
		expect(CitizenActions.skill(sim, c, "farm")).toBeNear(base * 0.75, 1e-9) -- every work rate uses it
		sim:advance(10)
		expect(sim:productivityOf(c)).toBeNear(0.5, 1e-9)
		sim:addProductivity(c, -2, 5)
		expect(sim:productivityOf(c)).toBe(0)
		sim:advance(15)
		expect(sim:productivityOf(c)).toBe(1)
		expect(c.boosts).toBeNil()
	end)

	it("striking or walked-out citizens idle instead of working", function()
		local sim, k = F.kingdom()
		local c = sim.citizens[k.citizenIds[1]]
		sim:strike(c, 30)
		expect(sim:isStriking(c)).toBe(true)
		sim.active = true
		sim:advance(1)
		expect(c.activity == "Idle" or c.activity == "Sleep" or c.activity == "Flee").toBe(true)
		sim:advance(30)
		expect(sim:isStriking(c)).toBe(false)
		sim:addProductivity(c, -1, 10) -- a walk-out (SPEC §5.4)
		expect(sim:isStriking(c)).toBe(true)
	end)
end)
