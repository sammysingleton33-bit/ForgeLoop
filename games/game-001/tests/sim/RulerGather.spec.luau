local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local RulerGather = require("@game/ReplicatedStorage/Game/Sim/RulerGather")

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

	it("only gathers on its own kingdom's land or on neutral land, never on a rival's (D-050 (3))", function()
		local sim, k = world()
		local rival = sim:addKingdom({ id = "azure", name = "Rival", x = 300, z = 0, populate = false })
		sim:addRuler(rival.id, 8)
		sim:addNode("tree", 350, 0, "azure-oak") -- 50 studs from the azure keep: azure's land
		sim:addNode("tree", 150, 0, "middle-oak") -- 150 studs from both keeps (territory 130): neutral
		F.events(sim)
		expect({ RulerGather.gather(sim, 7, "azure-oak", 350, 0) }).toEqual({ false, "not_your_node" })
		expect(RulerGather.gather(sim, 8, "azure-oak", 350, 0)).toBe(true) -- its own
		expect(RulerGather.gather(sim, 7, "middle-oak", 150, 0)).toBe(true) -- neutral for both
		sim:advance(1)
		expect(RulerGather.gather(sim, 8, "middle-oak", 150, 0)).toBe(true)
		-- land won in a capture counts as land: a region claimed by azure is azure's
		sim:claimRegion("azure", "heart", 150, 0, 40, "spec")
		sim:advance(1)
		expect({ RulerGather.gather(sim, 7, "middle-oak", 150, 0) }).toEqual({ false, "not_your_node" })
		sim:advance(1)
		expect(RulerGather.gather(sim, 8, "middle-oak", 150, 0)).toBe(true)
		-- nothing was taken from the node by a refusal
		expect(sim.nodes["azure-oak"].amount).toBe(78)
		expect(k.alive).toBe(true)
	end)

	it("a kingdom's rulers share a per-minute allowance per resource: wood 9, stone 6, gold 6, food 4", function()
		local sim, k = world()
		sim:addRuler(k.id, 9)
		sim:addNode("tree", 50, 5, "oak-2")
		sim:addNode("rock", 60, 0, "rock-1")
		sim:addNode("goldvein", 70, 0, "gold-1")
		sim:addNode("berries", 80, 0, "berry-1")
		F.events(sim)
		local function harvests(node: string, x: number, who: number): number
			local ok = 0
			for _ = 1, 12 do
				if RulerGather.gather(sim, who, node, x, 0) then
					ok += 1
				end
				sim:advance(1)
			end
			return ok
		end
		-- 2 wood a harvest, one a second: four go through (8), the fifth would make 10 > 9
		local before = sim:balance(k.id, "wood")
		expect(harvests("oak-1", 50, 7)).toBe(4)
		expect(sim:balance(k.id, "wood")).toBe(before + 8)
		-- the co-ruler has no allowance of their own
		expect(harvests("oak-2", 50, 9)).toBe(0)
		expect(sim.nodes["oak-2"].amount).toBe(80) -- the refused ones took nothing
		-- the other resources have theirs: stone and gold 1 a harvest (6), food 2 a harvest (4 = two)
		expect(harvests("rock-1", 60, 7)).toBe(6)
		expect(harvests("gold-1", 70, 9)).toBe(6)
		expect(harvests("berry-1", 80, 7)).toBe(2)
	end)

	it("the window moves on: the allowance comes back after 60 seconds, and a long run stays under the cap", function()
		local sim, k = world()
		F.events(sim)
		local start = sim:balance(k.id, "wood")
		sim.nodes["oak-1"].amount = 5000
		local took = 0
		for second = 1, 300 do
			local ok, _, result = RulerGather.gather(sim, 7, "oak-1", 50, 0)
			if ok then
				took += result.amount
			end
			if second == 4 then
				-- 4 harvests in 4 s: the minute's wood is nearly used
				expect(took).toBe(8)
			end
			sim:advance(1)
		end
		expect(sim:balance(k.id, "wood") - start >= took).toBe(true)
		-- five minutes, nine a minute: at most 45 (+ the first minute's head start of one harvest), at least 40
		expect(took <= 46).toBe(true)
		expect(took >= 40).toBe(true)
	end)
end)
