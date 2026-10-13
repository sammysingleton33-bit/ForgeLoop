--[[
	Kingdom/Layout generated resource nodes on the world layout (FORGE-05 finding M1): for seeds 1..20 no
	node stands within a starting building's clearance (its placement rectangle or its footprint circle
	plus placementGap and the node's radius), none reaches into a build slot (so every type that fits a
	slot can still be built on it), every kingdom keeps its wood, stone and gold, and the same seed gives
	the same nodes. The square layout (`spacing`) is unchanged.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

local SEEDS = 20

local function generate(seed: number, spacing: number?)
	local sim = Simulation.new({ random = Random.new(seed), bounds = Layout.bounds(spacing) })
	Layout.generate(sim, { spacing = spacing })
	return sim
end

-- the kingdom whose keep is nearest (generated nodes ring their own keep)
local function ownerOf(sim, node): string
	local best, bestDistance = "", math.huge
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		local d = math.sqrt((node.x - k.x) ^ 2 + (node.z - k.z) ^ 2)
		if d < bestDistance then
			best, bestDistance = kid, d
		end
	end
	return best
end

local function slotsOf(plot)
	local out = {}
	for _, slot in plot.buildSlots do
		table.insert(out, { slot = slot, size = Layout.WORLD.slotSizes[slot.size] })
	end
	return out
end

describe("Kingdom/Layout: generated nodes on the world layout (M1)", function()
	it("keeps every node clear of the keeps and starting buildings, seeds 1..20", function()
		for seed = 1, SEEDS do
			local sim = generate(seed)
			local gap = sim.catalog.tuning.placementGap
			expect(#sim.buildingOrder).toBe(4 * (1 + #KingdomsConfig.startAnchors))
			for _, bid in sim.buildingOrder do
				local b = sim.buildings[bid]
				local rect = Footprint.rect(assert(Fit.largestFootprint(b.kind)), b.x, b.z, b.yaw)
				for _, nid in sim.nodeOrder do
					local n = sim.nodes[nid]
					local d = math.sqrt((n.x - b.x) ^ 2 + (n.z - b.z) ^ 2)
					if
						d < b.footprint + n.footprint + gap
						or Footprint.overlapsCircle(rect, n.x, n.z, n.footprint, gap)
					then
						error(
							`seed {seed}: {b.kingdomId} {b.kind}: {n.kind} {n.id} at {string.format("%.1f", d)} studs`
						)
					end
				end
			end
		end
	end)

	it("keeps every node and its clearance out of every build slot: each type that fits can stand on it", function()
		for seed = 1, SEEDS do
			local sim = generate(seed)
			local gap = sim.catalog.tuning.placementGap
			for _, identity in Layout.KINGDOMS do
				for _, entry in slotsOf(Layout.WORLD.plots[identity.id]) do
					local slot, size = entry.slot, entry.size
					local cf = CFrame.new(slot.center) * CFrame.Angles(0, slot.rot, 0)
					for _, nid in sim.nodeOrder do
						local n = sim.nodes[nid]
						local l = cf:PointToObjectSpace(Vector3.new(n.x, 0, n.z))
						local margin = Layout.SLOT_MARGIN
						if math.abs(l.X) < size.X / 2 + margin and math.abs(l.Z) < size.Y / 2 + margin then
							error(`seed {seed}: {n.kind} {n.id} inside {slot.id}`)
						end
						-- the node's circle stays placementGap + SLOT_MARGIN from the slot's edge
						local ox, oz = math.max(math.abs(l.X) - size.X / 2, 0), math.max(math.abs(l.Z) - size.Y / 2, 0)
						if math.sqrt(ox * ox + oz * oz) < n.footprint + gap + margin then
							error(`seed {seed}: {n.kind} {n.id} reaches into {slot.id}`)
						end
						for _, kind in Fit.typesFor(slot.size) do
							local fp = assert(Fit.largestFootprint(kind))
							local rect = Footprint.rect(fp, slot.center.X, slot.center.Z, slot.rot)
							if Footprint.overlapsCircle(rect, n.x, n.z, n.footprint, gap) then
								error(`seed {seed}: {n.kind} {n.id} blocks a {kind} on {slot.id}`)
							end
						end
					end
				end
			end
		end
	end)

	it("leaves every kingdom its wood, stone and gold", function()
		for seed = 1, SEEDS do
			local sim = generate(seed)
			local count = {}
			for _, nid in sim.nodeOrder do
				local n = sim.nodes[nid]
				if string.sub(n.id, 1, 6) ~= "heart_" then
					local owner = ownerOf(sim, n)
					count[owner] = count[owner] or { tree = 0, rock = 0, goldvein = 0 }
					count[owner][n.kind] += 1
				end
			end
			for _, kid in sim.kingdomOrder do
				local c = count[kid]
				expect(c).toBeTruthy()
				expect(c.tree).toBeGreaterThanOrEqual(KingdomsConfig.trees * 3 / 4)
				expect(c.rock).toBeGreaterThanOrEqual(2)
				expect(c.goldvein).toBeGreaterThanOrEqual(1)
				-- and the kingdom's citizens see them
				local near = {}
				for _, nid in sim.kingdoms[kid].nearNodes do
					near[sim.nodes[nid].kind] = true
				end
				expect(near.tree and near.rock and near.goldvein).toBe(true)
			end
		end
	end)

	it("gives the same nodes for the same seed and keeps generated nodes from overlapping", function()
		for _, seed in { 1, 7 } do
			local a, b = generate(seed), generate(seed)
			expect(#a.nodeOrder).toBe(#b.nodeOrder)
			for i, nid in a.nodeOrder do
				local na, nb = a.nodes[nid], b.nodes[b.nodeOrder[i]]
				expect({ na.id, na.kind, na.x, na.z }).toEqual({ nb.id, nb.kind, nb.x, nb.z })
			end
			for i, nid in a.nodeOrder do
				local n = a.nodes[nid]
				for j = i + 1, #a.nodeOrder do
					local m = a.nodes[a.nodeOrder[j]]
					expect(math.sqrt((n.x - m.x) ^ 2 + (n.z - m.z) ^ 2) >= n.footprint + m.footprint).toBe(true)
				end
			end
		end
	end)

	it("leaves the square layout as it was: no node moved or left out", function()
		local sim = generate(3, 260)
		local perKingdom = KingdomsConfig.trees + 3 + 1
		expect(#sim.nodeOrder).toBe(4 * perKingdom + 5)
		for index, kid in sim.kingdomOrder do
			local k = sim.kingdoms[kid]
			local away = math.atan2(k.z, k.x)
			local first = (index - 1) * perKingdom + KingdomsConfig.trees
			for r = 1, 3 do
				local rock = sim.nodes[sim.nodeOrder[first + r]]
				local angle = away + math.pi / 2 + (r - 2) * 0.22
				expect(rock.kind).toBe("rock")
				expect(rock.x).toBeNear(k.x + math.cos(angle) * 85, 1e-9)
				expect(rock.z).toBeNear(k.z + math.sin(angle) * 85, 1e-9)
			end
			local gold = sim.nodes[sim.nodeOrder[first + 4]]
			expect(gold.kind).toBe("goldvein")
			expect(gold.x).toBeNear(k.x + math.cos(away - math.pi / 2) * 105, 1e-9)
		end
	end)
end)
