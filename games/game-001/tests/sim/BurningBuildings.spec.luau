--[[
	A building on fire halts, and heals itself afterwards (D-050 (1b), (1c); FL-0082): while Simulation:setBurning is
	on, nobody farms or builds at it, it takes no deliveries and gives no gather bonus, and the citizens working
	there stop at once; when the fire goes out it heals back to the hit points it had when it caught fire at a share
	of its maximum a second, never past that and never while burning. Rioters (Simulation:riot) are a state of
	their own, not strikers.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local Occupations = require("@game/ReplicatedStorage/Game/Content/Occupations")

local function world()
	local sim, k = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
	F.stock(sim, k):add("wood", 500)
	F.stock(sim, k):add("stone", 500)
	F.events(sim)
	return sim, k
end

local function built(sim, k, kind: string, x: number, z: number)
	local b = assert(sim:placeBuilding(k, kind, x, z))
	sim:_completeInstantly(b)
	sim:_recompute(k)
	return b
end

describe("Simulation:setBurning: a burning building halts", function()
	it("offers no farm or build work while it burns, and again when the fire is out", function()
		local sim, k = world()
		local farm = built(sim, k, "farm", 60, 0)
		local c = sim:_spawnCitizen(k, "farmer", 60, 5) -- next to the new farm: the nearest one (the start farm is further)
		expect(sim:findWorkTarget(k, "farm", c)).toBe(farm)
		local site = assert(sim:placeBuilding(k, "house", -60, 0))
		expect(sim:findWorkTarget(k, "build", c)).toBe(site)
		sim:setBurning(farm, true)
		sim:setBurning(site, true)
		expect(sim:findWorkTarget(k, "farm", c)).never.toBe(farm) -- (only the start farm is left to offer)
		expect(sim:findWorkTarget(k, "build", c)).toBeNil()
		sim:setBurning(farm, false)
		sim:setBurning(site, false)
		expect(sim:findWorkTarget(k, "farm", c)).toBe(farm)
		expect(sim:findWorkTarget(k, "build", c)).toBe(site)
	end)

	it("the citizens working there stop at once and choose again", function()
		local sim, k = world()
		local farm = built(sim, k, "farm", 60, 0)
		local worker = sim:_spawnCitizen(k, "farmer", 60, 5)
		local elsewhere = sim:_spawnCitizen(k, "farmer", 0, 20)
		for _, c in { worker, elsewhere } do
			c.activity, c.target, c.phase, c.done = "Farm", farm.id, "Work", false
		end
		elsewhere.target = "not-the-farm" -- working somewhere else
		sim:setBurning(farm, true)
		expect(worker.done).toBe(true)
		expect(elsewhere.done).toBe(false)
		sim:advance(1)
		expect(worker.target).never.toBe(farm.id)
	end)

	it("takes no deliveries and gives no gather bonus: carriers go to the next drop-off", function()
		local sim, k = world()
		local camp = built(sim, k, "lumbercamp", 40, 0)
		camp.level = 2 -- a level that speeds gathering up
		sim:_recompute(k)
		expect(k.gatherBonus.wood).toBe(0.2)
		expect(sim:nearestDropoff(k, 40, 5, "wood")).toBe(camp)
		sim:setBurning(camp, true)
		expect(k.gatherBonus.wood or 0).toBe(0)
		expect(sim:nearestDropoff(k, 40, 5, "wood")).toBe(sim.buildings[k.keepId])
		sim:setBurning(camp, false)
		expect(k.gatherBonus.wood).toBe(0.2)
		expect(sim:nearestDropoff(k, 40, 5, "wood")).toBe(camp)
	end)

	it("is idempotent, and a destroyed building is just dropped", function()
		local sim, k = world()
		local house = built(sim, k, "house", 40, 0)
		sim:setBurning(house, true, 0.01)
		sim:setBurning(house, true, 0.01)
		expect(house.hpBeforeFire).toBe(house.hp)
		house.hp = 10
		sim:setBurning(house, false, 0.01)
		sim:setBurning(house, false, 0.01)
		house.destroyed = true
		sim:advance(5)
		expect(next(sim._repairing)).toBeNil()
	end)
end)

describe("Simulation:setBurning: the building heals itself back (no permanent damage)", function()
	it(
		"climbs at regenPerSecond of the maximum to the hit points it had when it caught fire, and stops there",
		function()
			local sim, k = world()
			local house = built(sim, k, "house", 40, 0)
			house.hp = math.floor(house.maxHp * 0.8)
			local before = house.hp
			sim:setBurning(house, true)
			house.hp = math.floor(house.maxHp * 0.3) -- the fire took most of it
			sim:setBurning(house, false, 0.01)
			expect(house.burning).toBeNil()
			local low = house.hp
			sim:advance(10)
			expect(house.hp).toBeNear(low + house.maxHp * 0.01 * 10, 1.5)
			sim:advance(120)
			expect(house.hp).toBe(before) -- back to what it was, not to full
			expect(next(sim._repairing)).toBeNil()
			sim:advance(60)
			expect(house.hp).toBe(before)
		end
	)

	it("does not heal while it burns, nor when the fire left it undamaged, nor with no rate", function()
		local sim, k = world()
		local house = built(sim, k, "house", 40, 0)
		sim:setBurning(house, true)
		house.hp -= 50
		sim:advance(20)
		expect(house.hp).toBe(house.maxHp - 50) -- burning: no repair
		local other = built(sim, k, "storehouse", -40, 0)
		sim:setBurning(other, true)
		sim:setBurning(other, false, 0.01) -- nothing lost: nothing to repair
		expect(next(sim._repairing, nil)).toBeNil()
		sim:setBurning(house, false, nil) -- a service that gives no rate leaves the damage (no surprise healing)
		sim:advance(20)
		expect(house.hp).toBe(house.maxHp - 50)
	end)

	it("the repair stops if the building burns again", function()
		local sim, k = world()
		local house = built(sim, k, "house", 40, 0)
		sim:setBurning(house, true)
		house.hp = 100
		sim:setBurning(house, false, 0.01)
		sim:advance(5)
		local healed = house.hp
		expect(healed > 100).toBe(true)
		sim:setBurning(house, true)
		sim:advance(5)
		expect(house.hp).toBe(healed)
		expect(next(sim._repairing)).toBeNil()
	end)
end)

describe("Simulation:riot: rioters are a state of their own", function()
	it("stops work like a strike, for the given time, but is not a strike", function()
		local sim, k = world()
		local c = sim:_spawnCitizen(k, "farmer", 0, 20)
		expect(sim:isRioting(c)).toBe(false)
		sim:riot(c, 5)
		expect(sim:isRioting(c)).toBe(true)
		expect(sim:isStriking(c)).toBe(false) -- a strike is not a riot
		sim:advance(1)
		expect(c.activity).toBe("Idle")
		expect(c.reason).toBe("rioting")
		sim:advance(5)
		expect(sim:isRioting(c)).toBe(false)
		sim:strike(c, 5)
		expect(sim:isRioting(c)).toBe(false)
		expect(sim:isStriking(c)).toBe(true)
	end)

	it(
		"the marker EventCodec.RIOT can't be a real occupation, and a strike event carrying it survives the wire",
		function()
			expect(Occupations[EventCodec.RIOT]).toBeNil()
			local buf = EventCodec.encode(
				1,
				{ { type = "strike", occupation = EventCodec.RIOT, on = true, entityIds = { 4, 7 } } }
			)
			local batch = assert(EventCodec.decode(buf))
			expect(batch.events[1]).toEqual({ type = "strike", occupation = "riot", on = true, entityIds = { 4, 7 } })
		end
	)
end)
