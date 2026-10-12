local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local RulerGather = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/RulerGather")

local function world()
	local sim, k = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
	local tree = sim:addNode("tree", 50, 0, "oak-1")
	sim:addRuler(k.id, 7)
	F.events(sim)
	return sim, k, tree
end

describe("Kingdom/RulerGather", function()
	it("harvests a node in range into the treasury, once per cooldown", function()
		local sim, k, tree = world()
		local wood = sim:balance(k.id, "wood")
		local ok, err, result = RulerGather.gather(sim, 7, "oak-1", 45, 0)
		expect(err).toBeNil()
		expect(ok).toBe(true)
		expect(result).toEqual({ resource = "wood", amount = 2 })
		expect(sim:balance(k.id, "wood")).toBe(wood + 2)
		expect(tree.amount).toBe(78)
		local gathered = F.events(sim, "ResourceGathered")
		expect(#gathered).toBe(1)
		expect(gathered[1].source).toBe("ruler")
		expect(gathered[1].userId).toBe(7)
		expect({ RulerGather.gather(sim, 7, "oak-1", 45, 0) }).toEqual({ false, "cooldown" })
		sim:advance(1)
		expect(RulerGather.gather(sim, 7, "oak-1", 45, 0)).toBe(true)
		expect(sim:balance(k.id, "wood")).toBe(wood + 4) -- distinct txIds: both deposits count
		expect(sim.treasury:audit(k.id)).toBe(true)
	end)

	it("rejects calls out of range, on unknown or empty nodes, and from non-rulers", function()
		local sim, _, tree = world()
		expect({ RulerGather.gather(sim, 7, "oak-1", 0, 0) }).toEqual({ false, "too_far" })
		expect({ RulerGather.gather(sim, 7, "nope", 50, 0) }).toEqual({ false, "unknown_node" })
		expect({ RulerGather.gather(sim, 7, 42, 50, 0) }).toEqual({ false, "unknown_node" })
		expect({ RulerGather.gather(sim, 99, "oak-1", 50, 0) }).toEqual({ false, "not_ruler" })
		tree.amount = 0
		expect({ RulerGather.gather(sim, 7, "oak-1", 50, 0) }).toEqual({ false, "depleted" })
		sim.active = false
		expect({ RulerGather.gather(sim, 7, "oak-1", 50, 0) }).toEqual({ false, "match_not_active" })
	end)

	it("takes only what is left and marks the node depleted", function()
		local sim, k, tree = world()
		tree.amount = 1
		local ok, _, result = RulerGather.gather(sim, 7, "oak-1", 50, 0)
		expect(ok).toBe(true)
		expect(result.amount).toBe(1)
		expect(tree.amount).toBe(0)
		expect(tree.depletedAt).toBe(sim.time)
		expect(#F.events(sim, "NodeDepleted")).toBe(1)
		expect(sim:balance(k.id, "wood")).toBe(101)
	end)
end)
