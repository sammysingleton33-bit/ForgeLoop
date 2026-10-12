local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local CitizenBrain = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/CitizenBrain")

-- A kingdom at the origin with one Woodcutter (starts at (18, 0)) and one Builder (at (-18, 0)), no
-- resource nodes (each test adds its own), births off. Its farm sits at about (28, 19).
local function setup(citizens: { [string]: number }?)
	local sim, k = F.kingdom({
		nodes = false,
		tuning = { startCitizens = citizens or { woodcutter = 1, builder = 1 }, birthInterval = 1e6 },
	})
	return sim, k
end

local function citizen(sim, k, occupation: string)
	for _, c in sim:citizensOf(k) do
		if c.job == occupation then
			return c
		end
	end
	error(`no {occupation}`)
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
		k.threats = { { id = "u1", x = c.x + 5, z = c.z } }
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
		k.threats = { { id = "u1", x = c.x, z = c.z + radius } } -- exactly on the edge counts
		c.hunger = 2
		night(sim)
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Flee")
		expect(d.target).toBe(k.keepId)
		expect(d.reason).toBe("threat")

		k.threats = { { id = "u1", x = c.x, z = c.z + radius + 0.5 } }
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
		c.home = "b77"
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Sleep")
		expect(d.target).toBe("b77")
		expect(d.reason).toBe("night")
		c.home = nil
		expect(CitizenBrain.decide(sim, c).target).toBe(k.keepId)
	end)

	it("eats at eatThreshold when there is food, and works instead when the stockpile is empty", function()
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
	it("a Woodcutter gathers at the nearest tree with a free slot", function()
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

	it("a Builder builds at an open site, and does other work when there is none", function()
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
			table.insert(site.builders, "c9" .. i)
		end
		expect(CitizenBrain.decide(sim, c).activity).never.toBe("Build")
	end)

	it("a Farmer farms at a farm with a free worker slot, and not at a full one", function()
		local sim, k = setup({ farmer = 1 })
		local farm = sim:buildingsOf(k)[2]
		local c = citizen(sim, k, "farmer")
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("farm")
		expect(d.target).toBe(farm.id)
		for i = 1, 3 do
			table.insert(farm.workers, "c9" .. i)
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

	it("a full store makes need() 0, so nobody gathers what cannot be stored", function()
		local sim, k = setup()
		sim:addNode("tree", 60, 0)
		local c = citizen(sim, k, "woodcutter")
		F.stock(sim, k):add("wood", F.stock(sim, k):capacity())
		expect(sim:balance(k.id, "wood")).toBe(F.stock(sim, k):capacity())
		expect(CitizenBrain.need(sim, k, "wood")).toBe(0)
		expect(CitizenBrain.decide(sim, c).activity).toBe("Idle")
	end)

	it("need() is weight x (0.25 + 0.75 x deficit) below the target (capped by storage)", function()
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
		-- at or above the target (but below capacity) the base need remains
		F.stock(sim, k):add("wood", 150)
		expect(need("wood")).toBeNear(0.25)
		-- empty: full deficit
		F.stock(sim, k):take("wood", sim:balance(k.id, "wood"))
		expect(need("wood")).toBeNear(1)
		-- gold: 0 of 80
		expect(need("gold")).toBeNear(1)
		-- "farm" is food: 120 of max(150, 2 citizens x 2 meals x 2 days) -> deficit 0.2
		expect(need("farm")).toBeNear(0.4)
		-- the target never exceeds storage: capacity 150 makes stone's target 150 (50 stored)
		F.stock(sim, k):setCapacity(150)
		expect(need("stone")).toBeNear(0.25 + 0.75 * (1 - 50 / 150))
		-- build is 1 with an open site, 0 without
		expect(need("build")).toBe(0)
		F.stock(sim, k):setCapacity(400)
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
		sim:remember(c, { kind = "threat", ref = "u1", x = 0, z = 120 })
		expect(CitizenBrain.decide(sim, c).target).toBe(tree.id)
		-- a threat remembered at the tree: the woodcutter helps build instead
		sim:remember(c, { kind = "threat", ref = "u2", x = tree.x, z = tree.z })
		local d = CitizenBrain.decide(sim, c)
		expect(d.activity).toBe("Build")
		expect(d.target).toBe(site.id)
		-- memories fade after memorySeconds
		sim.time += sim.catalog.tuning.memorySeconds + 1
		expect(CitizenBrain.decide(sim, c).target).toBe(tree.id)
	end)

	it("remembering that storage was full damps gathering that resource", function()
		local sim, k = setup()
		local tree = sim:addNode("tree", 60, 0)
		local site = assert(sim:placeBuilding(k, "house", -40, 0))
		local c = citizen(sim, k, "woodcutter")
		expect(CitizenBrain.decide(sim, c).target).toBe(tree.id)
		sim:remember(c, { kind = "storage_full", ref = "stone" }) -- another resource: no effect
		expect(CitizenBrain.decide(sim, c).target).toBe(tree.id)
		sim:remember(c, { kind = "storage_full", ref = "wood" })
		expect(CitizenBrain.decide(sim, c).target).toBe(site.id)
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

		-- a Builder (build affinity 1) is not held at a tree by the bonus
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
				k.threats = { { id = "u1", x = c.x, z = c.z } }
			end,
			function(c)
				k.threats = {}
				c.hunger = 1
			end,
			function(c)
				c.hunger = 0
				sim:remember(c, { kind = "threat", ref = "u2", x = 60, z = 0 })
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
