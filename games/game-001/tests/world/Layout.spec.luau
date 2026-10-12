local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Layout = require("@game/ReplicatedStorage/Game/World/Layout")

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local RESOURCES = { food = true, wood = true, stone = true, gold = true }
local ANCHORS = { "keep", "storehouse", "farm", "lumbercamp", "quarry" }
local LIMIT = 4000 -- snapshot quantisation (G4)

local function inBounds(p: Vector3)
	return math.abs(p.X) <= LIMIT and math.abs(p.Y) <= LIMIT and math.abs(p.Z) <= LIMIT
end

describe("Layout schema (G10.1)", function()
	it("has a plot per kingdom with spawn, region, all anchors and build zones", function()
		for _, k in KINGDOMS do
			local plot = Layout.plots[k]
			expect(plot).never.toBeNil()
			expect(typeof(plot.spawn)).toBe("CFrame")
			expect(Layout.regions[plot.regionId]).never.toBeNil()
			expect(Layout.regions[plot.regionId].kingdom).toBe(k)
			for _, a in ANCHORS do
				expect(typeof(plot.anchors[a])).toBe("CFrame")
				expect(inBounds(plot.anchors[a].Position)).toBe(true)
			end
			expect(#plot.buildZones).toBeGreaterThan(0)
			for _, z in plot.buildZones do
				expect(type(z.id)).toBe("string")
				expect(typeof(z.center)).toBe("Vector3")
				expect(typeof(z.size)).toBe("Vector2")
			end
		end
	end)

	it("keeps every position within ±4000 studs", function()
		for _, n in Layout.nav.nodes do
			expect(inBounds(n)).toBe(true)
		end
		for _, r in Layout.resourceNodes do
			expect(inBounds(r.cframe.Position)).toBe(true)
			for _, s in r.workSpots do
				expect(inBounds(s)).toBe(true)
			end
		end
		for _, o in Layout.objectives do
			expect(inBounds(o.cframe.Position)).toBe(true)
		end
	end)

	it("has valid resource nodes with unique ids, work spots and nav links", function()
		local seen = {}
		for _, r in Layout.resourceNodes do
			expect(seen[r.id]).toBeNil()
			seen[r.id] = true
			expect(RESOURCES[r.resource]).toBe(true)
			expect(type(r.assetId)).toBe("string")
			expect(r.amount).toBeGreaterThan(0)
			expect(r.regrowSec).toBeGreaterThanOrEqual(0)
			expect(#r.workSpots).toBeGreaterThan(0)
			expect(Layout.nav.nodes[r.navNode]).never.toBeNil()
		end
	end)

	it("has at least one capture objective in a known region", function()
		expect(#Layout.objectives).toBeGreaterThan(0)
		for _, o in Layout.objectives do
			expect(o.kind).toBe("capture")
			expect(o.radius).toBeGreaterThan(0)
			expect(Layout.regions[o.regionId]).never.toBeNil()
			expect(Layout.nav.nodes[o.navNode]).never.toBeNil()
		end
	end)

	it("gives every region a polygon of at least 3 points", function()
		for id, r in Layout.regions do
			expect(#r.polygon).toBeGreaterThanOrEqual(3)
			if r.kingdom ~= nil then
				expect(table.find(KINGDOMS, r.kingdom)).never.toBeNil()
			end
			expect(type(id)).toBe("string")
		end
	end)
end)

describe("Layout nav graph", function()
	it("has edges between existing, distinct nodes", function()
		for _, e in Layout.nav.edges do
			expect(#e).toBe(2)
			expect(Layout.nav.nodes[e[1]]).never.toBeNil()
			expect(Layout.nav.nodes[e[2]]).never.toBeNil()
			expect(e[1]).never.toBe(e[2])
		end
	end)

	it("connects every node to every other node (one component)", function()
		local adj = {}
		for i in Layout.nav.nodes do
			adj[i] = {}
		end
		for _, e in Layout.nav.edges do
			table.insert(adj[e[1]], e[2])
			table.insert(adj[e[2]], e[1])
		end
		local seen, queue = { [1] = true }, { 1 }
		while #queue > 0 do
			local n = table.remove(queue, 1) :: number
			for _, m in adj[n] do
				if not seen[m] then
					seen[m] = true
					table.insert(queue, m)
				end
			end
		end
		local count = 0
		for _ in seen do
			count += 1
		end
		expect(count).toBe(#Layout.nav.nodes)
	end)
end)
