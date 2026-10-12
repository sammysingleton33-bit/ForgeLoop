local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local CitizenBrain = require("@game/ReplicatedStorage/Game/Sim/CitizenBrain")

-- A kingdom at the origin with one woodcutter (starts at (18, 0)) and one builder (at (-18, 0)), no
-- resource nodes (each test adds its own), births off. Its farm sits at about (28, 19).
-- Ids are numbers (CONTRACTS G2): citizens and units share EntityIds, buildings have their own.
local function setup(citizens: { [string]: number }?)
	local sim, k = F.kingdom({
		nodes = false,
		tuning = { startCitizens = citizens or { woodcutter = 1, builder = 1 }, birthInterval = 1e6 },
	})
	return sim, k
end

local function citizen(sim, k, job: string)
	for _, c in sim:citizensOf(k) do
		if c.job == job then
			return c
		end
	end
	error(`no {job}`)
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, v in value do
		out[key] = deepCopy(v)
	end
	return out
end

local function night(sim)
	sim.time = sim.catalog.tuning.dayLength * sim.catalog.tuning.nightStart -- first instant of night 1
	assert(sim:isNight())
end

describe("Kingdom/CitizenBrain: emergencies", function()
	it("flees to the keep when the alarm rings, ahead of danger, night and hunger", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "woodcutter")
		k.alarm = true
		k.threats = { { id = 901, x = c.x + 5, z = c.z } }
		c.hunger = 2
		night(sim)
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Flee")
		expect(d.target).toBe(k.keepId)
		expect(d.reason).toBe("alarm")
		expect(d.score).toBe(10)
	end)

	it("flees from a threat inside fleeRadius, ahead of night and hunger, but ignores one outside it", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "woodcutter")
		local radius = sim.catalog.tuning.fleeRadius
		k.threats = { { id = 901, x = c.x, z = c.z + radius } } -- exactly on the edge counts
		c.hunger = 2
		night(sim)
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Flee")
		expect(d.target).toBe(k.keepId)
		expect(d.reason).toBe("threat")

		k.threats = { { id = 901, x = c.x, z = c.z + radius + 0.5 } }
		expect(CitizenBrain.decide(sim, c).activity).toBe("Sleep")
		k.threats = {}
		expect(CitizenBrain.decide(sim, c).activity).toBe("Sleep")
	end)

	it("sleeps at night: at home when it has one, otherwise in the keep, even when hungry", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "woodcutter")
		sim.time = sim.catalog.tuning.dayLength * sim.catalog.tuning.nightStart - 0.25
		expect(CitizenBrain.decide(sim, c).activity).toBe("Gather") -- still evening

		night(sim)
		c.hunger = 2
		c.home = 77
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Sleep")
		expect(d.target).toBe(77)
		expect(d.reason).toBe("night")
		c.home = nil
		expect(CitizenBrain.decide(sim, c).target).toBe(k.keepId)
	end)

	it("eats at eatThreshold when there is food, and works instead when the treasury has none", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "woodcutter")
		local threshold = sim.catalog.tuning.eatThreshold

		c.hunger = threshold - 0.01
		expect(CitizenBrain.decide(sim, c).activity).toBe("Gather")

		c.hunger = threshold
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Eat")
		expect(d.target).toBe(k.keepId)
		expect(d.reason).toBe("hungry")
		expect(d.score).toBeNear(1 + threshold)

		F.stock(sim, k):take("food", sim:balance(k.id, "food"))
		c.hunger = 2
		d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Gather")
		expect(d.reason).toBe("wood")
	end)
end)

describe("Kingdom/CitizenBrain: choosing work", function()
	it("a woodcutter gathers at the nearest tree with a free slot", function()
		local sim, k = setup()
		local far = sim:addNode("tree", -90, 0)
		local near = sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "woodcutter")
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Gather")
		expect(d.target).toBe(near.id)
		expect(d.reason).toBe("wood")
		-- a full tree is skipped for the next free one
		near.claims = near.slots
		expect(CitizenBrain.decide(sim, c).target).toBe(far.id)
		-- a depleted tree is not a target
		far.amount = 0
		expect(CitizenBrain.decide(sim, c).activity).toBe("Idle")
	end)

	it("a builder builds at an open site, and does other work when there is none", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "builder")
		local before = CitizenBrain.decide(sim, c)
		expect(before.activity).never.toBe("Build")
		local site = assert(sim:placeBuilding(k, "house", 0, -40))
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Build")
		expect(d.target).toBe(site.id)
		expect(d.reason).toBe("build")
		-- a site already staffed by SITE_BUILDERS others is not open
		for i = 1, 3 do
			table.insert(site.builders, 900 + i)
		end
		expect(CitizenBrain.decide(sim, c).activity).never.toBe("Build")
	end)

	it("a farmer farms at a farm with a free worker slot, and not at a full one", function()
		local sim, k = setup({ farmer = 1 })
		local farm = sim:buildingsOf(k)[2]
		expect(farm.kind).toBe("farm")
		local c = citizen(sim, k, "farmer")
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Farm")
		expect(d.target).toBe(farm.id)
		expect(d.reason).toBe("farm")
		for i = 1, 3 do
			table.insert(farm.workers, 900 + i)
		end
		expect(CitizenBrain.decide(sim, c).activity).toBe("Idle")
	end)

	it("priority 0 makes need() 0 and takes that work off the table", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "woodcutter")
		expect(CitizenBrain.decide(sim, c).activity).toBe("Gather")
		k.priorities.wood = 0
		expect(CitizenBrain.need(sim, k, "wood")).toBe(0)
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Idle")
		expect(d.target).toBeNil()
	end)

	it("has no storage ceiling: a huge balance keeps the base need, so gathering goes on", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "woodcutter")
		F.stock(sim, k):add("wood", 100000)
		expect(CitizenBrain.need(sim, k, "wood")).toBeNear(0.25)
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Gather")
		expect(d.reason).toBe("wood")
	end)

	it("a miner digs whichever of stone and gold the kingdom needs more", function()
		local sim, k = setup({ miner = 1 })
		local rock = sim:addNode("rock", 60, 0)
		local vein = sim:addNode("goldvein", -60, 0)
		local c = citizen(sim, k, "miner")
		c.x, c.z = 0, 0 -- equally far from both
		-- gold 0 of 80 (need 1) beats stone 50 of 150 (need 0.75)
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Gather")
		expect(d.target).toBe(vein.id)
		expect(d.reason).toBe("gold")
		F.stock(sim, k):add("gold", 80) -- gold at its target: need 0.25
		d = CitizenBrain.decide(sim, c)
		expect(d.target).toBe(rock.id)
		expect(d.reason).toBe("stone")
		-- a woodcutter never mines
		local sim2, k2 = setup({ woodcutter = 1 })
		sim2:addNode("rock", 60, 0)
		expect(CitizenBrain.decide(sim2, citizen(sim2, k2, "woodcutter")).activity).toBe("Idle")
	end)

	it("need() is weight x (0.25 + 0.75 x deficit) below the target", function()
		local sim, k = setup()
		local need = function(kind)
			return CitizenBrain.need(sim, k, kind)
		end
		-- wood: 100 of a 200 target -> deficit 0.5
		expect(need("wood")).toBeNear(0.625)
		k.priorities.wood = 3
		expect(need("wood")).toBeNear(1.875)
		k.priorities.wood = 2
		expect(need("wood")).toBeNear(1.25)
		k.priorities.wood = 1
		-- at or above the target the base need remains
		F.stock(sim, k):add("wood", 150)
		expect(need("wood")).toBeNear(0.25)
		-- empty: full deficit
		F.stock(sim, k):take("wood", sim:balance(k.id, "wood"))
		expect(need("wood")).toBeNear(1)
		-- gold: 0 of 80
		expect(need("gold")).toBeNear(1)
		-- "farm" is food: 120 of max(150, 2 citizens x 2 meals x 2 days) -> deficit 0.2
		expect(need("farm")).toBeNear(0.4)
		-- stone: 50 of 150
		expect(need("stone")).toBeNear(0.25 + 0.75 * (1 - 50 / 150))
		-- food's target grows with the population: two days of meals for everyone
		for _ = 1, 40 do
			sim:_spawnCitizen(k, "hauler", 0, 20)
		end
		expect(sim:needTarget(k, "food")).toBe(42 * 2 * 2) -- 168 > 150
		expect(need("farm")).toBeNear(0.25 + 0.75 * (1 - 120 / 168))
		-- build is 1 with an open site, 0 without
		expect(need("build")).toBe(0)
		F.stock(sim, k):add("wood", 40)
		assert(sim:placeBuilding(k, "house", 0, -40))
		expect(need("build")).toBe(1)
	end)

	it("a recently remembered threat near the best target lowers its score, so the citizen picks other work", function()
		local sim, k = setup()
		local tree = sim:addNode("tree", 60, 0)
		local site = assert(sim:placeBuilding(k, "house", -40, 0))
		local c = citizen(sim, k, "woodcutter")
		expect(CitizenBrain.decide(sim, c).target).toBe(tree.id)
		-- a threat remembered far from the tree changes nothing
		sim:remember(c, { kind = "threat", ref = 901, x = 0, z = 120 })
		expect(CitizenBrain.decide(sim, c).target).toBe(tree.id)
		-- a threat remembered at the tree: the woodcutter helps build instead
		sim:remember(c, { kind = "threat", ref = 902, x = tree.x, z = tree.z })
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Build")
		expect(d.target).toBe(site.id)
		-- memories fade after memorySeconds
		sim.time += sim.catalog.tuning.memorySeconds + 1
		expect(CitizenBrain.decide(sim, c).target).toBe(tree.id)
	end)

	it("the commitment bonus keeps the current target when scores are close, but not against a clear winner", function()
		local sim, k = setup()
		local tree = sim:addNode("tree", 60, 0)
		local site = assert(sim:placeBuilding(k, "house", -60, 0))
		F.stock(sim, k):add("wood", 200 - sim:balance(k.id, "wood")) -- at the target: wood need is the 0.25 base
		local c = citizen(sim, k, "woodcutter")
		c.x, c.z = 0, 0 -- equally far from the tree and the site
		-- wood 1 x 0.25 x f(60) = 0.18 against build 0.3 x 1 x f(60) = 0.21: build wins when uncommitted
		expect(CitizenBrain.decide(sim, c).target).toBe(site.id)
		c.target = tree.id
		local d = CitizenBrain.decide(sim, c)
		expect(d.target).toBe(tree.id)
		expect(d.activity).toBe("Gather")
		c.target = site.id
		expect(CitizenBrain.decide(sim, c).target).toBe(site.id)

		-- a builder (build affinity 1) is not held at a tree by the bonus
		local builder = citizen(sim, k, "builder")
		builder.x, builder.z = 0, 0
		builder.target = tree.id
		expect(CitizenBrain.decide(sim, builder).target).toBe(site.id)
	end)

	it("idles when there is nothing to do, snacking first when a little hungry and food is left", function()
		local sim, k = setup()
		local c = citizen(sim, k, "woodcutter") -- no trees, no sites
		local d = CitizenBrain.decide(sim, c)
		expect(d).toEqual({ activity = "Idle", target = nil, score = 0.05, reason = "nothing to do" })
		c.hunger = sim.catalog.tuning.eatThreshold * 0.5
		d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Eat")
		expect(d.reason).toBe("idle snack")
		F.stock(sim, k):take("food", sim:balance(k.id, "food"))
		expect(CitizenBrain.decide(sim, c).activity).toBe("Idle")
	end)

	it("decide() never mutates the world", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		assert(sim:placeBuilding(k, "house", -40, 0))
		local cases = {
			function() end,
			function(_c)
				k.alarm = true
			end,
			function(c)
				k.alarm = false
				k.threats = { { id = 901, x = c.x, z = c.z } }
			end,
			function(c)
				k.threats = {}
				c.hunger = 1
			end,
			function(c)
				c.hunger = 0
				sim:remember(c, { kind = "threat", ref = 902, x = 60, z = 0 })
			end,
		}
		for _, prepare in cases do
			for _, c in sim:citizensOf(k) do
				prepare(c)
				local before = { citizen = deepCopy(c), stock = sim.treasury:get(k.id), nodes = deepCopy(sim.nodes) }
				local buildings = deepCopy(sim.buildings)
				CitizenBrain.decide(sim, c)
				expect(deepCopy(c)).toEqual(before.citizen)
				expect(sim.treasury:get(k.id)).toEqual(before.stock)
				expect(deepCopy(sim.nodes)).toEqual(before.nodes)
				expect(deepCopy(sim.buildings)).toEqual(buildings)
			end
		end
		expect(#sim:drainEvents()).toBe(1) -- only the BuildingPlaced from setup
	end)
end)

describe("Kingdom/CitizenBrain: decisions carried out (CitizenActions)", function()
	it("a hungry citizen eats at a drop-off that takes food, never at a lumber camp or quarry", function()
		local sim, k = setup()
		for _, entry in { { "lumbercamp", 60, 0 }, { "quarry", 0, 60 } } do
			local b = sim:_createBuilding(k, entry[1], entry[2], entry[3])
			sim:_completeInstantly(b)
		end
		local keep = sim.buildings[k.keepId]
		for _, start in { { 66, 0 }, { 0, 66 } } do
			local c = citizen(sim, k, "woodcutter")
			c.x, c.z = start[1], start[2]
			c.hunger = 1
			c.done = true
			local food = sim:balance(k.id, "food")
			local ateAt = nil
			for _ = 1, 80 do
				sim:step()
				if c.hunger < 0.5 then
					ateAt = { x = c.x, z = c.z }
					break
				end
			end
			expect(ateAt).toBeTruthy()
			local d = math.sqrt((ateAt.x - keep.x) ^ 2 + (ateAt.z - keep.z) ^ 2)
			expect(d).toBeLessThanOrEqual(keep.footprint + 1 + 1e-6) -- at the keep, not the camp next door
			expect(sim:balance(k.id, "food")).toBe(food - sim.catalog.tuning.mealFood)
			expect(F.stock(sim, k):flows().expense.meal.food).toBeGreaterThan(0)
		end
	end)
end)
