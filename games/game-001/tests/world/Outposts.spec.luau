--[[
	The neutral outposts (FL-0127 part 1, Operation Crownfall): three capture points (outpost_n, outpost_s, outpost_w) besides the
	central watchtower, placed in world/Layout.luau for FORGE-01's FL-0126, which gives them config rows (territory radius, Crown
	Points, capture time) and builds their neutral towers. The world only places them: an objective needs a position and facing,
	a radius for the zone, a region for ownership, a nav node, and a clear surrounding.

	Fairness: four kingdoms and three outposts cannot be symmetric, so the rule is a band: every kingdom has a neutral objective
	330-365 studs away and a second one within 520 (the west kingdoms get the west-bank outpost to balance the river they must
	cross to reach the watchtower).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")

local OUTPOSTS = { "outpost_n", "outpost_s", "outpost_w" }
local KINGDOMS = { "crimson", "azure", "emerald", "gold" }

local function objective(id: string): any
	for _, o in Layout.objectives do
		if o.id == id then
			return o
		end
	end
	error(`no objective {id}`)
end

local function flat(p: Vector3): Vector2
	return Vector2.new(p.X, p.Z)
end

local function inside(polygon: { Vector2 }, p: Vector2): boolean
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for _, v in polygon do
		minX, minZ = math.min(minX, v.X), math.min(minZ, v.Y)
		maxX, maxZ = math.max(maxX, v.X), math.max(maxZ, v.Y)
	end
	return p.X >= minX and p.X <= maxX and p.Y >= minZ and p.Y <= maxZ
end

describe("Neutral outposts (FL-0127 part 1)", function()
	it("has the watchtower and three outposts, each a capture point with a radius, a region and a nav node", function()
		expect(#Layout.objectives).toBe(1 + #OUTPOSTS)
		local ids = {}
		for _, o in Layout.objectives do
			expect(ids[o.id]).toBeNil()
			ids[o.id] = true
			expect(o.kind).toBe("capture")
			expect(o.radius).toBeGreaterThan(0)
			expect(Layout.nav.nodes[o.navNode]).never.toBeNil()
			local region = Layout.regions[o.regionId]
			expect(region).never.toBeNil()
			expect(region.kingdom).toBeNil() -- neutral ground
			expect(inside(region.polygon, flat(o.cframe.Position))).toBe(true)
		end
		expect(ids.watchtower).toBe(true)
		for _, id in OUTPOSTS do
			expect(ids[id]).toBe(true)
		end
	end)

	it("stands every outpost on its own region, a hundred studs and more from any other objective", function()
		for i, a in Layout.objectives do
			for j, b in Layout.objectives do
				if i < j then
					expect((flat(a.cframe.Position) - flat(b.cframe.Position)).Magnitude).toBeGreaterThan(300)
					expect(a.regionId).never.toBe(b.regionId)
				end
			end
		end
	end)

	it("keeps each outpost clear of forest stands, hills, the river, plots and the map edge", function()
		local f = Layout.features
		for _, id in OUTPOSTS do
			local p = flat(objective(id).cframe.Position)
			local r = objective(id).radius
			for _, forest in f.forests do
				expect((p - forest.center).Magnitude).toBeGreaterThan(forest.radius + r + 6)
			end
			for _, hill in f.hills do
				if hill.center ~= nil and hill.radius ~= nil then
					expect((p - hill.center).Magnitude).toBeGreaterThan(hill.radius + r + 20)
				end
			end
			expect(WorldPlan.distToPolyline(p.X, p.Y, f.river.points)).toBeGreaterThan(f.river.width / 2 + r + 40)
			for _, k in KINGDOMS do
				local keep = Layout.plots[k].anchors.keep.Position
				expect((p - flat(keep)).Magnitude).toBeGreaterThan(250) -- well outside the plot frame (the plots are ~150 across)
			end
			expect(p.X).toBeGreaterThan(f.bounds.min.X + 150)
			expect(p.X).toBeLessThan(f.bounds.max.X - 150)
			expect(p.Y).toBeGreaterThan(f.bounds.min.Y + 150)
			expect(p.Y).toBeLessThan(f.bounds.max.Y - 150)
		end
	end)

	it("is fair enough: every kingdom has a neutral objective 330-365 studs away and a second within 520", function()
		for _, k in KINGDOMS do
			local keep = flat(Layout.plots[k].anchors.keep.Position)
			local ds = {}
			for _, o in Layout.objectives do
				table.insert(ds, (flat(o.cframe.Position) - keep).Magnitude)
			end
			table.sort(ds)
			expect(`{k} nearest {ds[1] >= 330 and ds[1] <= 365}`).toBe(`{k} nearest true`)
			expect(`{k} second {ds[2] <= 520}`).toBe(`{k} second true`)
		end
	end)

	it("connects every outpost to the road and nav network (a path from each kingdom's gate)", function()
		local adjacency: { [number]: { number } } = {}
		for _, e in Layout.nav.edges do
			adjacency[e[1]] = adjacency[e[1]] or {}
			adjacency[e[2]] = adjacency[e[2]] or {}
			table.insert(adjacency[e[1]], e[2])
			table.insert(adjacency[e[2]], e[1])
		end
		for _, k in KINGDOMS do
			local gate = nil
			-- the gate node is the one 110 studs in front of the keep
			local best = math.huge
			local target = (Layout.plots[k].anchors.keep * CFrame.new(0, 0, -110)).Position
			for i, n in Layout.nav.nodes do
				local d = (Vector3.new(n.X, 0, n.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude
				if d < best then
					best, gate = d, i
				end
			end
			expect(best).toBeLessThan(1)
			local seen = { [gate :: number] = true }
			local queue = { gate :: number }
			local qi = 1
			while qi <= #queue do
				local n = queue[qi]
				qi += 1
				for _, m in adjacency[n] or {} do
					if not seen[m] then
						seen[m] = true
						table.insert(queue, m)
					end
				end
			end
			for _, o in Layout.objectives do
				expect(`{k} reaches {o.id}: {seen[o.navNode] == true}`).toBe(`{k} reaches {o.id}: true`)
			end
		end
	end)

	it("ends a road spur at each outpost, marked as a spur", function()
		for _, id in OUTPOSTS do
			local p = flat(objective(id).cframe.Position)
			local ends = 0
			for _, road in Layout.features.roads do
				local last = road.points[#road.points]
				if road.spur and (last - p).Magnitude < 1 then
					ends += 1
				end
			end
			expect(ends).toBeGreaterThan(0)
		end
	end)

	it("keeps the scattered decor out of every objective's keep-out (radius + 14)", function()
		local dressed = { crimson = true, azure = true, emerald = true, gold = true }
		for _, pl in WorldPlan.props(Layout, dressed, WorldPlan.FULL_DENSITY) do
			local q = pl.cframe.Position
			for _, o in Layout.objectives do
				local d = (flat(o.cframe.Position) - Vector2.new(q.X, q.Z)).Magnitude
				if d < o.radius + 14 then
					error(`{pl.assetId} stands {math.floor(d)} studs from {o.id}`)
				end
			end
		end
	end)
end)
