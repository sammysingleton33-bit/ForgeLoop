--[[
	Kingdom/Layout: farm zones and build areas stay clear of generated trees and rocks (user playtest 2026-10-13:
	"farms in the starting kingdom contain trees and rocks"). For seeds 1..20 on the world layout:
	  - no generated node touches a crop field (the farm zones: world features.fields) or a plot build zone
	    (front yard and flanks), with the same clearance a build slot gets, measured from what is drawn (the
	    larger of its footprint and its box's half-diagonal, Sim/NodeStyle: a boulder's corners reach past its
	    footprint circle), and no corner of a drawn node stands on one;
	  - every kingdom still has its whole forest, quarry and gold vein, within a woodcutter's reach;
	  - the plots are still rotated copies of each other for the zone keep-out: the nodes of two kingdoms
	    differ only by their rotation (fairness, #62 M-1 stays true).
	The world's decor props (WorldPlan) were already kept out of both and are checked here too.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local NodeStyle = require("@game/ReplicatedStorage/Game/Sim/NodeStyle")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")

local SEEDS = 20
local WORLD = Layout.WORLD

local function generate(seed: number)
	local sim = Simulation.new({ random = Random.new(seed), bounds = Layout.bounds() })
	Layout.generate(sim)
	return sim
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- { name, shape } for every crop field and build zone of the world
local function areas(): { { name: string, shape: any } }
	local out = {}
	for i, field in WORLD.features.fields do
		table.insert(out, {
			name = `field {i}`,
			shape = Footprint.rect(field.size, field.center.X, field.center.Y, field.yaw),
		})
	end
	for kid, plot in WORLD.plots do
		local yaw = yawOf(plot.anchors.keep)
		for _, zone in plot.buildZones do
			table.insert(out, {
				name = `{kid} zone {zone.id}`,
				shape = Footprint.rect(zone.size, zone.center.X, zone.center.Z, yaw),
			})
		end
	end
	return out
end

describe("Kingdom/Layout: farm zones and build areas are free of generated nodes", function()
	it("has the areas the rule is about: 12 crop fields and 3 build zones in each of the 4 plots", function()
		local list = areas()
		expect(#WORLD.features.fields).toBe(12)
		expect(#list).toBe(12 + 4 * 3)
	end)

	it(
		"keeps every generated node (trees, rocks, gold) clear of every crop field and build zone, seeds 1..20",
		function()
			local list = areas()
			for seed = 1, SEEDS do
				local sim = generate(seed)
				local gap = sim.catalog.tuning.placementGap + Layout.SLOT_MARGIN
				for _, nid in sim.nodeOrder do
					local n = sim.nodes[nid]
					-- what a node reaches is the larger of its footprint circle and its drawn box
					local reach = math.max(n.footprint, NodeStyle.radius(n.kind))
					for _, area in list do
						if Footprint.overlapsCircle(area.shape, n.x, n.z, reach, gap) then
							error(`seed {seed}: {n.kind} at ({math.floor(n.x)}, {math.floor(n.z)}) reaches {area.name}`)
						end
					end
				end
			end
		end
	)

	it("no corner of a drawn node stands on a crop field or build zone, seeds 1..20", function()
		local list = areas()
		for seed = 1, SEEDS do
			local sim = generate(seed)
			for _, nid in sim.nodeOrder do
				local n = sim.nodes[nid]
				local size = NodeStyle.STYLE[n.kind].size
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local cx, cz = n.x + sx * size[1] / 2, n.z + sz * size[3] / 2
						for _, area in list do
							if Footprint.overlapsCircle(area.shape, cx, cz, 0.01, 0) then
								error(`seed {seed}: a {n.kind} corner stands in {area.name}`)
							end
						end
					end
				end
			end
		end
	end)

	it("the drawn extent is the box's half-diagonal and reaches past a boulder's footprint circle", function()
		local sim = generate(1)
		expect(math.abs(NodeStyle.radius("tree") - math.sqrt(8)) < 1e-9).toBe(true)
		expect(math.abs(NodeStyle.radius("rock") - math.sqrt(32)) < 1e-9).toBe(true)
		expect(math.abs(NodeStyle.radius("goldvein") - math.sqrt(24.5)) < 1e-9).toBe(true)
		expect(NodeStyle.radius("berries")).toBe(0) -- no look, no extent
		-- the drawn corners of a rock and a gold vein reach past their footprint circles: the reason for the rule
		expect(NodeStyle.radius("rock") > sim.catalog.nodes.rock.footprint).toBe(true)
		expect(NodeStyle.radius("goldvein") > sim.catalog.nodes.goldvein.footprint).toBe(true)
	end)

	it("leaves each kingdom its whole forest, quarry and gold vein, within reach of its keep, seeds 1..20", function()
		for seed = 1, SEEDS do
			local sim = generate(seed)
			for _, kid in sim.kingdomOrder do
				local k = sim.kingdoms[kid]
				local count = { tree = 0, rock = 0, goldvein = 0 }
				local farthest = 0
				for _, nid in sim.nodeOrder do
					local n = sim.nodes[nid]
					local d = math.sqrt((n.x - k.x) ^ 2 + (n.z - k.z) ^ 2)
					if d < 160 and count[n.kind] ~= nil then -- this kingdom's own ring; the centre is further out
						count[n.kind] += 1
						farthest = math.max(farthest, d)
					end
				end
				expect(`{seed} {kid} trees {count.tree}`).toBe(`{seed} {kid} trees {KingdomsConfig.trees}`)
				expect(count.rock).toBe(3)
				expect(count.goldvein).toBe(1)
				expect(farthest < 150).toBe(true)
			end
		end
	end)

	it("the plots stay fair: the same seed gives each kingdom the same number of nodes", function()
		for seed = 1, SEEDS do
			local sim = generate(seed)
			local per = {}
			for _, nid in sim.nodeOrder do
				local n = sim.nodes[nid]
				local owner, best = "", math.huge
				for _, kid in sim.kingdomOrder do
					local k = sim.kingdoms[kid]
					local d = (n.x - k.x) ^ 2 + (n.z - k.z) ^ 2
					if d < best then
						owner, best = kid, d
					end
				end
				if best < 160 ^ 2 then
					per[owner] = (per[owner] or 0) + 1
				end
			end
			local first = per[sim.kingdomOrder[1]]
			for _, kid in sim.kingdomOrder do
				expect(`{seed} {kid} {per[kid]}`).toBe(`{seed} {kid} {first}`)
			end
		end
	end)

	-- FORGE-02's per-plot resource nodes (world/Layout.lua resourceNodes: Kit models drawn by WorldService, not
	-- sim nodes) stand on crop fields, build zones and slots: the boulders on fields 3/6/9/12, the berry
	-- bushes in the east yards, the gold veins beside slot 10. They are FORGE-02's data (handoff
	-- 2026-10-15-forge-01-to-forge-02-00-world-resource-nodes); this only stops a NEW node from joining them.
	-- Delete an id from KNOWN when FORGE-02 has moved it (a fixed node passes either way).
	local KNOWN = {}
	for _, kid in { "crimson", "azure", "emerald", "gold" } do
		for _, name in { "stone1", "stone2", "food1", "food2", "gold1" } do
			KNOWN[`{kid}_{name}`] = true
		end
	end
	local NODE_REACH = 9 -- Kit/WorldPlan keeps its decor 9 studs from a resource node: its own estimate of a node's size

	it("no further world resource node (Kit model) joins those already standing on a field, zone or slot", function()
		local list = areas()
		for _, kid in KingdomsConfig.identities do
			local plot = WORLD.plots[kid.id]
			for _, slot in plot.buildSlots do
				local size = WORLD.slotSizes[slot.size]
				table.insert(list, {
					name = `{kid.id} slot {slot.id}`,
					shape = Footprint.rect(size, slot.center.X, slot.center.Z, slot.rot),
				})
			end
		end
		for _, node in WORLD.resourceNodes do
			if string.sub(node.id, 1, 6) == "heart_" or KNOWN[node.id] then
				continue
			end
			local p = node.cframe.Position
			for _, area in list do
				if Footprint.overlapsCircle(area.shape, p.X, p.Z, NODE_REACH, 0) then
					error(`world node {node.id} ({node.resource}) stands within {NODE_REACH} studs of {area.name}`)
				end
			end
		end
	end)

	it("the world's decor (trees, rocks, bushes) also stays out of the crop fields and build zones", function()
		local list = areas()
		for _, prop in WorldPlan.props(WORLD, { crimson = true }) do
			local f = prop.feature
			if f == "forest" or f == "lone_tree" or f == "rocks" or f == "bush" then
				local pos = prop.cframe.Position
				for _, area in list do
					-- radius 0 never overlaps (touching is not overlapping): a hair of radius makes it a point test
					if Footprint.overlapsCircle(area.shape, pos.X, pos.Z, 0.01, 0) then
						error(`{prop.assetId} ({f}) stands inside {area.name}`)
					end
				end
			end
		end
	end)
end)
