local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Snapshot = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Snapshot")

local function dist(a, b)
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

describe("Kingdom/Simulation: a new kingdom", function()
	it("has a level-1 keep, a working farm, ten citizens and the start stock", function()
		local sim, k = F.kingdom()
		local buildings = sim:buildingsOf(k)
		expect(#buildings).toBe(2)
		expect(buildings[1].kind).toBe("Keep")
		expect(buildings[1].level).toBe(1)
		expect(buildings[1].pendingLevel).toBeNil()
		expect(buildings[2].kind).toBe("Farm")
		expect(buildings[2].level).toBe(1)
		expect(#k.citizenIds).toBe(10)
		expect(F.occupations(sim, k)).toEqual({ Farmer = 3, Woodcutter = 3, Quarrier = 2, Builder = 2 })
		expect(k.popCap).toBe(10)
		expect(k.stock:capacity()).toBe(400)
		expect(k.territory).toBe(130)
		expect(k.stock:snapshot()).toEqual({ food = 120, wood = 100, stone = 50, gold = 0 })
		for _, c in sim:citizensOf(k) do
			expect(c.home).toBe(k.keepId)
		end
	end)

	it("rejects a duplicate kingdom id", function()
		local sim = F.kingdom()
		expect(function()
			sim:addKingdom({ id = "k1", x = 500, z = 500 })
		end).toThrow("unique string id")
	end)

	it("refuses an invalid catalog at construction", function()
		local Simulation = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Simulation")
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
			tuning = { startCitizens = { Farmer = 1 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		F.events(sim)
		sim:advance(60)
		local delivered = F.events(sim, "ResourceDelivered")
		expect(#delivered).toBeGreaterThan(0)
		local total = 0
		for _, e in delivered do
			expect(e.resource).toBe("food")
			expect(e.amount).toBe(10) -- two harvests of 5 fill a carry of 10
			expect(e.wasted).toBe(0)
			total += e.amount
		end
		expect(k.stock:get("food")).toBe(120 + total)
		expect(k.stock:flows().income.gathered.food).toBe(total)
		F.assertInvariants(sim)
	end)

	it("a woodcutter takes exactly what it delivers (plus what it carries) out of the tree", function()
		local sim, k = F.kingdom({
			tuning = { startCitizens = { Woodcutter = 1 }, hungerPerDay = 0.001, birthInterval = 1e6 },
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
		local gathered = k.stock:get("wood") - 100
		expect(gathered).toBeGreaterThan(0)
		expect(before - after).toBe(gathered + carried)
		F.assertInvariants(sim)
	end)

	it("gatherers keep making trips instead of stopping after the first delivery", function()
		local sim = F.kingdom({
			tuning = { startCitizens = { Farmer = 1, Woodcutter = 1 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		sim:advance(85) -- before nightfall at 90 s
		local trips = { food = 0, wood = 0 }
		for _, e in F.events(sim, "ResourceDelivered") do
			trips[e.resource] += 1
		end
		expect(trips.food).toBeGreaterThanOrEqual(4)
		expect(trips.wood).toBeGreaterThanOrEqual(3)
	end)

	it("keeps the resource balance exact over ten minutes of a busy kingdom", function()
		local sim, k = F.kingdom({ seed = 4 })
		local deliveredByRes = { food = 0, wood = 0, stone = 0, gold = 0 }
		assert(sim:placeBuilding(k, "House", 0, -35))
		for _ = 1, 60 do
			sim:advance(10)
			for _, e in F.events(sim, "ResourceDelivered") do
				deliveredByRes[e.resource] += e.amount
			end
			F.assertInvariants(sim)
			for _, res in sim.catalog.resources do
				expect(k.stock:get(res) <= math.max(k.stock:capacity(), 120)).toBe(true)
			end
		end
		local flows = k.stock:flows()
		for res, amount in deliveredByRes do
			expect((flows.income.gathered or {})[res] or 0).toBe(amount)
		end
		expect(flows.expense.meal.food).toBeGreaterThan(0)
		expect(flows.expense.construction.wood).toBe(40)
	end)

	it("never lets more gatherers claim a node than it has slots", function()
		local sim, k = F.kingdom({
			nodes = false,
			tuning = { startCitizens = { Woodcutter = 6 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		local tree = sim:addNode("Tree", 40, 0)
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

	it("wastes deliveries above storage capacity and remembers that storage is full", function()
		local sim, k = F.kingdom({
			tuning = { startCitizens = { Woodcutter = 2 }, hungerPerDay = 0.001, birthInterval = 1e6 },
		})
		k.stock:setCapacity(105) -- 100 wood already stored
		sim:advance(90)
		local wasted = 0
		for _, e in F.events(sim, "ResourceDelivered") do
			wasted += e.wasted
		end
		expect(wasted).toBeGreaterThan(0)
		expect(k.stock:get("wood")).toBe(105)
		local remembered = F.count(sim:citizensOf(k), function(c)
			for _, m in c.memory do
				if m.kind == "storage_full" and m.ref == "wood" then
					return true
				end
			end
			return false
		end)
		expect(remembered).toBeGreaterThan(0)
		F.assertInvariants(sim)
	end)

	it("regrows a depleted tree after its regrow time, and depleted trees still block placement", function()
		local sim, k = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
		local tree = sim:addNode("Tree", 0, -50)
		tree.amount = 0
		tree.depletedAt = sim.time
		local ok, err = sim:canPlace(k, "House", 0, -44)
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
		local building, err = sim:placeBuilding(k, "House", 0, -35, 501)
		expect(err).toBeNil()
		expect(building.level).toBe(0)
		expect(building.pendingLevel).toBe(1)
		expect(k.stock:snapshot()).toEqual({ food = 120, wood = 60, stone = 50, gold = 0 })
		local placed = F.events(sim, "BuildingPlaced")
		expect(#placed).toBe(1)
		expect(placed[1].by).toBe(501)
		expect(placed[1].kind).toBe("House")
	end)

	it("builders finish the house, raising the population cap", function()
		local sim, k = F.kingdom()
		local house = sim:placeBuilding(k, "House", 0, -35)
		F.events(sim)
		sim:advance(60)
		expect(house.level).toBe(1)
		expect(house.pendingLevel).toBeNil()
		expect(house.hp).toBe(300)
		expect(k.popCap).toBe(14)
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
		expect(k.stock:get("wood")).toBe(40)
		expect(k.stock:get("stone")).toBe(30)
		expect(farm.level).toBe(1) -- still producing at level 1 while upgrading
		sim:advance(120)
		expect(farm.level).toBe(2)
		expect(sim.catalog.buildings.Farm.levels[farm.level].workers).toBe(4)
		F.assertInvariants(sim)
	end)

	it("rejects upgrades that are busy, maxed, missing, foreign or unaffordable without side effects", function()
		local sim, k = F.kingdom()
		local other = sim:addKingdom({ id = "k2", x = 400, z = 0 })
		local farm = sim:buildingsOf(k)[2]
		expect(select(2, sim:startUpgrade(k, "b999"))).toBe("not_found")
		expect(select(2, sim:startUpgrade(k, other.keepId))).toBe("not_owner")
		assert(sim:startUpgrade(k, farm.id))
		expect(select(2, sim:startUpgrade(k, farm.id))).toBe("busy")
		local before = k.stock:snapshot()
		expect(select(2, sim:startUpgrade(k, k.keepId))).toBe("cannot_afford")
		expect(k.stock:snapshot()).toEqual(before)
		local wall = sim:placeBuilding(k, "Wall", -35, 0)
		sim:_completeInstantly(wall)
		wall.level = 2
		expect(select(2, sim:startUpgrade(k, wall.id))).toBe("max_level")
	end)

	it("cancelling a site refunds half its cost and releases its builders", function()
		local sim, k = F.kingdom()
		local house = sim:placeBuilding(k, "House", 0, -35)
		sim:advance(4)
		local ok, err = sim:cancelConstruction(k, house.id, 3)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(sim.buildings[house.id]).toBeNil()
		expect(k.stock:get("wood") >= 80).toBe(true) -- 60 left + 20 refund (+ any wood delivered meanwhile)
		expect(k.stock:flows().income.refund.wood).toBe(20)
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
		local before = k.stock:snapshot()
		local function reason(kind, x, z)
			local ok, err = sim:canPlace(k, kind, x, z)
			expect(ok).toBe(false)
			return err
		end
		expect(reason("Castle", 0, -35)).toBe("unknown_building")
		expect(reason("Keep", 0, -35)).toBe("not_placeable")
		expect(reason("Tower", 0, -35)).toBe("requires_keep_level")
		expect(reason("House", 0, -200)).toBe("out_of_territory")
		expect(reason("House", 0, 0)).toBe("blocked") -- on the keep
		expect(reason("House", 0, -60)).toBe("blocked") -- on a tree
		expect(reason("House", 2000, 0)).toBe("out_of_bounds")
		k.stock:spend({ wood = 100 })
		expect(reason("House", 0, -35)).toBe("cannot_afford")
		k.stock:add("wood", 400)
		k.stock:add("stone", 400)
		assert(sim:placeBuilding(k, "Barracks", 0, 30))
		assert(sim:placeBuilding(k, "Barracks", -30, 5))
		expect(reason("Barracks", -40, 40)).toBe("limit_reached")
		expect(before.food).toBe(k.stock:get("food"))
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
		local meals = k.stock:flows().expense.meal
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
				startCitizens = { Woodcutter = 3 },
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
		k.stock:add("food", 280)
		local house = sim:placeBuilding(k, "House", 0, -35)
		sim:_completeInstantly(house)
		sim:_recompute(k)
		expect(k.popCap).toBe(14)
		sim:advance(120)
		expect(#k.citizenIds).toBe(14)
		expect(#F.events(sim, "CitizenBorn")).toBe(4)
		expect(k.stock:flows().expense.birth.food).toBe(20)
	end)

	it("follows the rulers' job quotas, moving citizens through the Laborer pool", function()
		local sim, k = F.kingdom({ tuning = { birthInterval = 1e6 } })
		k.quotas.Woodcutter = 5
		k.quotas.Farmer = 1
		sim:advance(2)
		local counts = F.occupations(sim, k)
		expect(counts.Woodcutter).toBe(5)
		expect(counts.Farmer).toBe(1)
		expect(counts.Quarrier).toBe(2)
		expect(counts.Builder).toBe(2)
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

describe("Kingdom/Simulation: determinism", function()
	it("same seed and same commands give the same world", function()
		local function run()
			local sim, k = F.kingdom({ seed = 11 })
			sim:advance(30)
			assert(sim:placeBuilding(k, "House", 0, -35))
			sim:advance(200)
			return Snapshot.kingdom(sim, "k1", 1)
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
		expect(Snapshot.kingdom(a, "k1", 1)).toEqual(Snapshot.kingdom(b, "k1", 1))
		expect(a.tick).toBe(400)
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
