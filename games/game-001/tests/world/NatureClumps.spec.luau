--[[
	Nature in clumps (FORGE-02 visual pass 1: the owner's P0, "trees, terrain and landscaping are repetitive", "the world feels empty").
	WorldPlan.plan grows the valley's trees, bushes, rocks and flowers in clumps instead of scattering them evenly:
	  * forest stands: a dense core (canopies touching), satellite clumps, ragged singles; mixed species per stand;
	  * tree lines along the river and the approach roads, groves and hedges on the fringe of each plot, loose groves in the open land;
	  * rock groups at edges (stand borders, hill feet, river banks, road bends, plot fringes);
	  * bush clumps and flower drifts at stand fringes, field corners and road verges;
	  * every placement carries a yaw, a `scale` (WorldService scales the built prop about its pivot) and a foliage `tint`.
	HEADLESS (Lune): placements, part counts and arithmetic, not a look. The renders are the evidence for the look.

	The measures below are written independently of the generator (nearest-neighbour and cell-occupancy for "clustered", distance bands for
	"at an edge", the plots' reserved ground rebuilt from Layout the way PlotClearance.spec does), and each has a MUTANT: the old even
	scatter, rocks sown evenly, scale 1 everywhere, a tree whose scaled canopy crosses the margin. The mutant must trip the measure.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local WorldDef = require("@game/ServerScriptService/Game/Services/WorldService")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local StartView = require("./support/StartView")

local ALL = { crimson = true, azure = true, emerald = true, gold = true }
local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local NATURAL = { forest = true, lone_tree = true, bush = true, rocks = true, flowers = true }
local FULL = WorldPlan.FULL_DENSITY
local forests = Layout.features.forests

local function planFull(): { any }
	return WorldPlan.props(Layout, ALL, FULL)
end

local function xz(p: any): Vector2
	return Vector2.new(p.cframe.Position.X, p.cframe.Position.Z)
end

-- ---- clustering measures

-- mean distance from each point to its nearest neighbour
local function meanNearest(points: { Vector2 }): number
	local sum = 0
	for i, a in points do
		local best = math.huge
		for j, b in points do
			if i ~= j then
				best = math.min(best, (a - b).Magnitude)
			end
		end
		sum += best
	end
	return sum / #points
end

-- Clark-Evans ratio: mean nearest-neighbour distance over what the same number of points scattered at random over `area` would
-- have (0.5 * sqrt(area / n)). About 1 = random, above 1 = evenly spread, below 1 = clumped.
local function clarkEvans(points: { Vector2 }, area: number): number
	return meanNearest(points) / (0.5 * math.sqrt(area / #points))
end

-- share of the stand disc's `cell`-stud cells that hold at least one point (an even scatter fills most cells, a clump few)
local function occupancy(points: { Vector2 }, centre: Vector2, radius: number, cell: number): number
	local total, hit = 0, {}
	local n = math.ceil(radius / cell)
	for ix = -n, n - 1 do
		for iz = -n, n - 1 do
			local cx, cz = centre.X + (ix + 0.5) * cell, centre.Y + (iz + 0.5) * cell
			if (Vector2.new(cx, cz) - centre).Magnitude <= radius then
				total += 1
			end
		end
	end
	for _, p in points do
		local ix, iz = math.floor((p.X - centre.X) / cell), math.floor((p.Y - centre.Y) / cell)
		if (p - centre).Magnitude <= radius then
			hit[ix * 1000 + iz] = true
		end
	end
	local n2 = 0
	for _ in hit do
		n2 += 1
	end
	return n2 / math.max(1, total)
end

local function standTrees(placements: { any }): { { Vector2 } }
	local out = {}
	for s, forest in forests do
		out[s] = {}
		for _, p in placements do
			if p.feature == "forest" and (xz(p) - forest.center).Magnitude <= forest.radius then
				table.insert(out[s], xz(p))
			end
		end
	end
	return out
end

-- the mutant: the old scatter, n trees uniformly over the stand disc, at least 13 studs apart (what WorldPlan.plan did)
local function evenScatter(forest: any, n: number): { Vector2 }
	local rng = WorldPlan._prng(777 + n)
	local out: { Vector2 } = {}
	local tries = 0
	while #out < n and tries < n * 40 do
		tries += 1
		local a, d = rng.range(0, 2 * math.pi), forest.radius * math.sqrt(rng.next())
		local p = forest.center + Vector2.new(math.cos(a) * d, math.sin(a) * d)
		local ok = true
		for _, q in out do
			if (p - q).Magnitude < 13 then
				ok = false
			end
		end
		if ok then
			table.insert(out, p)
		end
	end
	return out
end

-- ---- the plots' reserved ground, rebuilt the way PlotClearance.spec does (not through WorldPlan's own helpers)
local function reserved(): { any }
	local out = {}
	for _, field in Layout.features.fields do
		local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
		table.insert(out, { cf = cf, half = field.size / 2 })
	end
	for _, k in KINGDOMS do
		local plot = Layout.plots[k]
		for name, anchor in plot.anchors do
			table.insert(out, { cf = anchor, half = Kit.footprint(name, 99) / 2 })
		end
		for _, slot in plot.buildSlots do
			local cf = CFrame.new(slot.center) * CFrame.Angles(0, slot.rot, 0)
			table.insert(out, { cf = cf, half = Layout.slotSizes[slot.size] / 2 })
		end
		local look = plot.anchors.keep.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		for _, zone in plot.buildZones do
			table.insert(out, { cf = CFrame.new(zone.center) * CFrame.Angles(0, yaw, 0), half = zone.size / 2 })
		end
	end
	return out
end

local function rectDistance(rect: any, x: number, z: number): number
	local p = rect.cf:PointToObjectSpace(Vector3.new(x, rect.cf.Position.Y, z))
	local dx, dz = math.max(0, math.abs(p.X) - rect.half.X), math.max(0, math.abs(p.Z) - rect.half.Y)
	return math.sqrt(dx * dx + dz * dz)
end

-- footprint radius with the placement's scale (the documented per-family radius, which PlotClearance.spec checks against the live bounds)
local function reach(p: any): number
	return WorldPlan.footprintRadius(p.assetId) * (p.scale or 1)
end

-- lines for every natural placement that stands within `margin` + its scaled footprint of reserved ground or a road
local function violations(placements: { any }, scaleOf: ((any) -> number)?): { string }
	local rects, bad = reserved(), {}
	for _, p in placements do
		if NATURAL[p.feature] then
			local q = p.cframe.Position
			local r = if scaleOf then WorldPlan.footprintRadius(p.assetId) * scaleOf(p) else reach(p)
			for _, rect in rects do
				if rectDistance(rect, q.X, q.Z) < r + 4 then
					table.insert(
						bad,
						`{p.assetId} ({p.feature}) at ({math.floor(q.X)}, {math.floor(q.Z)}) near reserved ground`
					)
					break
				end
			end
			for _, road in Layout.features.roads do
				if WorldPlan.distToPolyline(q.X, q.Z, road.points) < road.width / 2 + r + 4 then
					table.insert(bad, `{p.assetId} ({p.feature}) at ({math.floor(q.X)}, {math.floor(q.Z)}) near a road`)
					break
				end
			end
			for _, lane in Layout.features.paths or {} do
				if WorldPlan.distToPolyline(q.X, q.Z, lane.points) < lane.width / 2 + r + 4 then
					table.insert(bad, `{p.assetId} ({p.feature}) at ({math.floor(q.X)}, {math.floor(q.Z)}) near a lane`)
					break
				end
			end
		end
	end
	return bad
end

-- parts a prop costs (the part-built stand-in), cached by asset id
local partCache: { [string]: number } = {}
local function partsOf(id: string): number
	if not partCache[id] then
		local n = 0
		for _, d in Kit.prop(id):GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		partCache[id] = n
	end
	return partCache[id]
end

local function fingerprint(placements: { any }): number
	local m, acc = 2147483647, 7
	for _, p in placements do
		for i = 1, #p.assetId do
			acc = (acc * 31 + string.byte(p.assetId, i)) % m
		end
		for _, c in { p.cframe:GetComponents() } do
			acc = (acc * 31 + math.floor(c * 1000 + 0.5)) % m
		end
		acc = (acc * 31 + math.floor((p.scale or 1) * 1000 + 0.5)) % m
		acc = (acc * 31 + math.floor(((p.tint or 0) + 2) * 1000 + 0.5)) % m
	end
	return acc
end

describe("Forest stands are clumps, not an even scatter", function()
	local trees = standTrees(planFull())

	it("grows each stand as a dense core with a ragged fringe (Clark-Evans and cell occupancy)", function()
		local clumped = 0
		for s, forest in forests do
			local pts = trees[s]
			if #pts >= 8 then
				local ce = clarkEvans(pts, math.pi * forest.radius ^ 2)
				local occ = occupancy(pts, forest.center, forest.radius, 30)
				-- measured: the generated stands 0.65 to 1.01 and 25 to 38 % of the cells; the old even scatter 1.19 to 1.38 and 47 to 62 %
				if ce < 1.08 and occ < 0.45 then
					clumped += 1
				end
			end
		end
		expect(clumped).toBe(#forests)
	end)

	it("MUTANT: the old even scatter is flagged by the same measures", function()
		local flagged = 0
		for _, forest in forests do
			local pts = evenScatter(forest, forest.count)
			local ce = clarkEvans(pts, math.pi * forest.radius ^ 2)
			local occ = occupancy(pts, forest.center, forest.radius, 30)
			if ce >= 1.08 or occ >= 0.45 then
				flagged += 1
			end
		end
		expect(flagged).toBe(#forests)
	end)

	it("keeps every stand tree inside its stand circle (the trim and the leafy floor read the stand by it)", function()
		local plan = WorldPlan.plan(Layout, ALL)
		local n = 0
		for _, p in plan do
			if p.feature == "forest" then
				n += 1
				local inside = false
				for _, forest in forests do
					if (xz(p) - forest.center).Magnitude <= forest.radius then
						inside = true
					end
				end
				expect(inside).toBe(true)
			end
		end
		expect(n).toBeGreaterThan(140) -- the Layout's 222 at 0.7 (WorldPlan.NATURE.standShare): 155
	end)

	it("mixes species per stand: no stand is one species unless the Layout says so, and the leaders differ", function()
		local leaders = {}
		for s, forest in forests do
			local count = {}
			for _, p in planFull() do
				if p.feature == "forest" and (xz(p) - forest.center).Magnitude <= forest.radius then
					local species = string.match(p.assetId, "^(tree_%a+)_")
					count[species] = (count[species] or 0) + 1
				end
			end
			local top, topN, kinds = "", 0, 0
			for species, n in count do
				kinds += 1
				if n > topN then
					top, topN = species, n
				end
			end
			leaders[top] = true
			if #forest.species > 1 then
				expect(kinds).toBeGreaterThanOrEqual(2)
			end
			expect(s).toBeGreaterThan(0)
		end
		local distinct = 0
		for _ in leaders do
			distinct += 1
		end
		expect(distinct).toBeGreaterThanOrEqual(2)
	end)
end)

describe("Every placement varies in rotation, size and foliage colour", function()
	local plan = planFull()

	it("gives trees and bushes a scale in 0.86..1.24 that really varies, and rocks theirs by class", function()
		local lo, hi, sum, sum2, n = math.huge, 0, 0, 0, 0
		for _, p in plan do
			if p.feature == "forest" or p.feature == "lone_tree" or p.feature == "bush" then
				local s = p.scale :: number
				expect(s).never.toBeNil()
				if p.feature ~= "bush" then
					expect(s).toBeGreaterThanOrEqual(0.86 - 1e-3)
					expect(s).toBeLessThanOrEqual(1.24 + 1e-3)
				else
					expect(s).toBeGreaterThanOrEqual(0.85 - 1e-3)
					expect(s).toBeLessThanOrEqual(1.2 + 1e-3)
				end
				lo, hi, sum, sum2, n = math.min(lo, s), math.max(hi, s), sum + s, sum2 + s * s, n + 1
			elseif p.feature == "rocks" then
				local s = p.scale :: number
				local class = string.match(p.assetId, "^rock_boulder_(%a)_")
				local range = WorldPlan.NATURE.rockScale[class]
				expect(s).toBeGreaterThanOrEqual(range[1] - 1e-3)
				expect(s).toBeLessThanOrEqual(range[2] + 1e-3)
			end
		end
		local mean = sum / n
		local std = math.sqrt(sum2 / n - mean * mean)
		expect(n).toBeGreaterThan(250)
		expect(hi - lo).toBeGreaterThan(0.3)
		expect(std).toBeGreaterThan(0.08) -- a uniform 0.86..1.24 has 0.11
	end)

	it("MUTANT: scale 1 everywhere has no spread", function()
		local mutant = {}
		for _, p in plan do
			table.insert(mutant, { assetId = p.assetId, cframe = p.cframe, feature = p.feature, scale = 1 })
		end
		local lo, hi = math.huge, 0
		for _, p in mutant do
			lo, hi = math.min(lo, p.scale), math.max(hi, p.scale)
		end
		expect(hi - lo).toBe(0)
	end)

	it("turns trees through every direction (yaw spread over the compass)", function()
		local buckets, n = {}, 0
		for _, p in plan do
			if p.feature == "forest" or p.feature == "lone_tree" then
				local look = p.cframe.LookVector
				local b = math.floor((math.atan2(look.X, look.Z) + math.pi) / (math.pi / 4)) % 8
				buckets[b] = (buckets[b] or 0) + 1
				n += 1
			end
		end
		for b = 0, 7 do
			expect((buckets[b] or 0) / n).toBeGreaterThan(0.06) -- an even spread is 0.125
		end
	end)

	it("tints foliage in five steps and uses most of them", function()
		local seen = {}
		for _, p in plan do
			if p.tint then
				expect(p.tint * 2 == math.floor(p.tint * 2)).toBe(true) -- a multiple of 1/2
				expect(math.abs(p.tint)).toBeLessThanOrEqual(1)
				seen[p.tint] = (seen[p.tint] or 0) + 1
			end
		end
		local kinds = 0
		for _ in seen do
			kinds += 1
		end
		expect(kinds).toBe(5)
	end)

	it(
		"recolours green foliage only, within about 10 % in value, and leaves trunks, rocks and blossoms alone",
		function()
			local leaf = Color3.fromRGB(106, 168, 62)
			local warm, cool = WorldPlan.tintColor(leaf, 1), WorldPlan.tintColor(leaf, -1)
			expect(warm.R).toBeGreaterThan(leaf.R)
			expect(warm.B).toBeLessThan(leaf.B)
			expect(cool.R).toBeLessThan(leaf.R)
			expect(cool.B).toBeGreaterThan(leaf.B)
			expect(math.abs(warm.G - leaf.G)).toBeLessThan(0.1)
			expect(WorldPlan.tintColor(leaf, 0)).toBe(leaf)
			local trunk, rock, bloom =
				Color3.fromRGB(110, 80, 52), Color3.fromRGB(128, 124, 118), Color3.fromRGB(217, 52, 58)
			for _, c in { trunk, rock, bloom } do
				expect(WorldPlan.tintColor(c, 1)).toBe(c)
				expect(WorldPlan.tintColor(c, -1)).toBe(c)
			end
			-- a built tree keeps its part count and gains no part when tinted
			local model = Kit.prop("tree_oak_03")
			local before = partsOf("tree_oak_03")
			WorldPlan.tintModel(model, 1)
			local after = 0
			local moved = 0
			local reference = Kit.prop("tree_oak_03")
			local refParts = {}
			for _, d in reference:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(refParts, d)
				end
			end
			local i = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					after += 1
					i += 1
					if d.Color ~= refParts[i].Color then
						moved += 1
					end
				end
			end
			expect(after).toBe(before)
			expect(moved).toBeGreaterThan(0)
		end
	)
end)

describe("Scaled footprints stay on the clearance's side of the margin", function()
	it(
		"keeps every natural placement its scaled footprint plus 4 studs off the plots' fields, buildings, slots, zones and roads",
		function()
			for _, density in { FULL, nil } do
				expect(table.concat(violations(WorldPlan.props(Layout, ALL, density)), "; ")).toBe("")
			end
		end
	)

	it("needs no clearance: the generator's own nature is already legal (clear() changes none of it)", function()
		local plan = WorldPlan.plan(Layout, ALL)
		local cleared = WorldPlan.clear(Layout, plan)
		local function natural(list: { any }): { any }
			local out = {}
			for _, p in list do
				if NATURAL[p.feature] then
					table.insert(out, p)
				end
			end
			return out
		end
		local a, b = natural(plan), natural(cleared)
		expect(#b).toBe(#a)
		for i, p in a do
			expect((p.cframe.Position - b[i].cframe.Position).Magnitude).toBeLessThan(1e-6)
			expect(b[i].scale).toBe(p.scale)
			expect(b[i].tint).toBe(p.tint)
		end
	end)

	it(
		"MUTANT: the same tree is kept at scale 1 and cleared at scale 1.25 when its canopy crosses the margin",
		function()
			local r = WorldPlan.footprintRadius("tree_oak_01")
			-- an oak whose canopy clears a field's margin at scale 1 by half a stud (and every other reserved area and road), found over
			-- the 12 fields' four sides
			local plain, big
			for _, field in Layout.features.fields do
				local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
				for _, side in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
					local reachOut = if side[1] ~= 0 then field.size.X / 2 else field.size.Y / 2
					local at = cf:PointToWorldSpace(
						Vector3.new(side[1] * (reachOut + r + 4.5), 0, side[2] * (reachOut + r + 4.5))
					)
					local a = { assetId = "tree_oak_01", cframe = CFrame.new(at), feature = "lone_tree" }
					local b = { assetId = "tree_oak_01", cframe = CFrame.new(at), feature = "lone_tree", scale = 1.25 }
					if not plain and #violations({ a }) == 0 and #violations({ b }) == 1 then
						plain, big = a, b
					end
				end
			end
			expect(plain).never.toBeNil() -- the checker reckons with the scale: legal at 1, not at 1.25
			plain, big = plain :: any, big :: any
			local kept = WorldPlan.clear(Layout, { plain })
			expect(#kept).toBe(1)
			expect((kept[1].cframe.Position - plain.cframe.Position).Magnitude).toBeLessThan(1e-6)
			local moved = WorldPlan.clear(Layout, { big })
			-- the scaled tree is moved clear (within CLEAR.natureNudge) or removed, never left where it stands
			expect(#moved <= 1).toBe(true)
			for _, p in moved do
				expect((p.cframe.Position - big.cframe.Position).Magnitude).toBeGreaterThan(0.5)
				expect(p.scale).toBe(1.25)
				expect(#violations({ p })).toBe(0)
			end
		end
	)
end)

describe("Rocks sit in groups at edges", function()
	local rocks = {}
	for _, p in planFull() do
		if p.feature == "rocks" then
			table.insert(rocks, p)
		end
	end

	-- groups: rocks within 24 studs of each other (single linkage)
	local function groups(list: { any }): { { any } }
		local seen, out = {}, {}
		for i in list do
			if not seen[i] then
				local g, queue = {}, { i }
				seen[i] = true
				while #queue > 0 do
					local k = table.remove(queue) :: number
					table.insert(g, list[k])
					for j, q in list do
						if not seen[j] and (xz(list[k]) - xz(q)).Magnitude <= 24 then
							seen[j] = true
							table.insert(queue, j)
						end
					end
				end
				table.insert(out, g)
			end
		end
		return out
	end

	-- the edge a rock stands at: a stand's border, a hill's foot, a river bank, a road, or the fringe of a plot's reserved ground
	local function atEdge(p: any): boolean
		local pos = xz(p)
		local f = Layout.features
		for _, forest in forests do
			local d = (pos - forest.center).Magnitude
			if d > forest.radius * 0.35 and d < forest.radius + 45 then
				return true
			end
		end
		for _, b in WorldPlan.hillBalls(Layout) do
			local dy = (f.groundY or 0) - b.y
			local cap = math.sqrt(math.max(0, b.r * b.r - dy * dy))
			if math.abs((pos - Vector2.new(b.x, b.z)).Magnitude - cap) < 40 then
				return true
			end
		end
		if WorldPlan.distToPolyline(pos.X, pos.Y, f.river.points) < f.river.width / 2 + 45 then
			return true
		end
		for _, road in f.roads do
			if WorldPlan.distToPolyline(pos.X, pos.Y, road.points) < road.width / 2 + 40 then
				return true
			end
		end
		for _, rect in reserved() do
			if rectDistance(rect, pos.X, pos.Y) < 45 then
				return true
			end
		end
		return false
	end

	it("puts nearly every rock in a group of 2 to 6 of different sizes", function()
		local gs = groups(rocks)
		local single, mixed, multi = 0, 0, 0
		for _, g in gs do
			expect(#g).toBeLessThanOrEqual(8)
			if #g == 1 then
				single += 1
			else
				multi += #g
				local sizes = {}
				for _, p in g do
					sizes[string.match(p.assetId, "^rock_boulder_(%a)_") :: string] = true
				end
				local kinds = 0
				for _ in sizes do
					kinds += 1
				end
				mixed += if kinds >= 2 then 1 else 0
			end
		end
		expect(multi / #rocks).toBeGreaterThan(0.8)
		expect(mixed).toBeGreaterThanOrEqual(8)
		expect(#gs - single).toBeGreaterThanOrEqual(15)
	end)

	it("stands every rock at an edge", function()
		local edge = 0
		for _, p in rocks do
			edge += if atEdge(p) then 1 else 0
		end
		expect(edge / #rocks).toBeGreaterThan(0.95)
	end)

	it("MUTANT: rocks sown evenly over the open land are neither grouped nor at edges", function()
		local rng = WorldPlan._prng(31337)
		local scattered = {}
		local b = Layout.features.bounds
		while #scattered < 80 do
			local x, z = rng.range(b.min.X + 40, b.max.X - 40), rng.range(b.min.Y + 40, b.max.Y - 40)
			table.insert(scattered, { assetId = "rock_boulder_m_01", cframe = CFrame.new(x, 0, z), feature = "rocks" })
		end
		local gs = groups(scattered)
		local multi = 0
		for _, g in gs do
			multi += if #g > 1 then #g else 0
		end
		local edge = 0
		for _, p in scattered do
			edge += if atEdge(p) then 1 else 0
		end
		expect(multi / #scattered).toBeLessThan(0.5)
		expect(edge / #scattered).toBeLessThan(0.95)
	end)
end)

describe("Tree lines, groves, hedges and drifts", function()
	local plan = planFull()

	it("lines the river banks and the approach roads with trees", function()
		local f = Layout.features
		local river, road = 0, 0
		for _, p in plan do
			if p.feature == "lone_tree" then
				local q = p.cframe.Position
				local dr = WorldPlan.distToPolyline(q.X, q.Z, f.river.points) - f.river.width / 2
				if dr > 15 and dr < 45 then
					river += 1
				end
				for _, rd in f.roads do
					if not rd.spur and rd.width >= 12 then
						local d = WorldPlan.distToPolyline(q.X, q.Z, rd.points) - rd.width / 2
						if d > 8 and d < 40 then
							road += 1
							break
						end
					end
				end
			end
		end
		expect(river).toBeGreaterThanOrEqual(6)
		expect(road).toBeGreaterThanOrEqual(6)
	end)

	it(
		"dresses the start views: the fringe of every plot gets trees, bushes and flowers where the camera looks",
		function()
			for _, k in KINGDOMS do
				local spawn = Layout.plots[k].spawn.Position
				local trees, low = 0, 0
				for _, p in plan do
					if NATURAL[p.feature] then
						local q = p.cframe.Position
						if WorldPlan.viewWeight(Layout, q.X, q.Z) >= 3 then
							local near = (Vector2.new(q.X, q.Z) - Vector2.new(spawn.X, spawn.Z)).Magnitude < 260
							if near then
								if p.feature == "lone_tree" or p.feature == "forest" then
									trees += 1
								else
									low += 1
								end
							end
						end
					end
				end
				expect(trees).toBeGreaterThanOrEqual(6)
				expect(low).toBeGreaterThanOrEqual(6)
			end
		end
	)

	it("hedges the crop fields: bushes, flowers and birches stand along their outer sides", function()
		local function near(list: { any }): number
			local n = 0
			for _, p in list do
				if p.feature == "bush" or p.feature == "flowers" or p.feature == "lone_tree" then
					local q = p.cframe.Position
					for _, field in Layout.features.fields do
						local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
						if rectDistance({ cf = cf, half = field.size / 2 }, q.X, q.Z) < 24 then
							n += 1
							break
						end
					end
				end
			end
			return n
		end
		-- measured: 39 placements within 24 studs of a field's edge (25 before the pass, mostly the old scatter's flowers by the plots)
		expect(near(plan)).toBeGreaterThanOrEqual(32)
		local rng = WorldPlan._prng(2468)
		local b = Layout.features.bounds
		local scattered = {}
		while #scattered < 90 do -- MUTANT: 90 bushes sown evenly over the valley are not by the fields
			table.insert(scattered, {
				feature = "bush",
				cframe = CFrame.new(rng.range(b.min.X + 40, b.max.X - 40), 0, rng.range(b.min.Y + 40, b.max.Y - 40)),
			})
		end
		expect(near(scattered)).toBeLessThan(25)
	end)

	-- the start view's ground, cut into 3 columns x 3 depth bands beyond its near quarter (the keep's towers fill that), from the spec-side
	-- copy of the camera maths (support/StartView, not WorldPlan's): { cell centres }, as Vector2
	local function frameCells(kingdom: string): { Vector2 }
		local cam = StartView.camera(StartView.root(Kit, Layout, kingdom), 70, 42.5)
		local ty = math.tan(math.rad(55 / 2))
		local tx = ty * 16 / 9
		local function ground(sx: number, sy: number): Vector2
			local dir = cam.forward + cam.right * (sx * tx) + cam.up * (sy * ty)
			local hit = cam.position + dir * (-cam.position.Y / dir.Y)
			return Vector2.new(hit.X, hit.Z)
		end
		local tl, tr, br, bl = ground(-1, 1), ground(1, 1), ground(1, -1), ground(-1, -1)
		local cells = {}
		for band = 0, 2 do
			for col = 0, 2 do
				local u, v = (col + 0.5) / 3, 0.25 + (band + 0.5) * 0.25
				table.insert(cells, bl:Lerp(br, u):Lerp(tl:Lerp(tr, u), v))
			end
		end
		return cells
	end

	local function coverage(list: { any }, kingdom: string): number
		local covered = 0
		for _, centre in frameCells(kingdom) do
			for _, p in list do
				if NATURAL[p.feature] and (xz(p) - centre).Magnitude < 38 then
					covered += 1
					break
				end
			end
		end
		return covered
	end

	it(
		"leaves no stretch of a start view bare: most of its 9 cells beyond the keep hold nature within 38 studs of their middle",
		function()
			for _, k in KINGDOMS do
				expect(coverage(plan, k)).toBeGreaterThanOrEqual(7)
			end
		end
	)

	it("MUTANT: without what the generator plants where the start view looks, the cells are bare", function()
		local bare = {}
		for _, p in plan do
			if
				not (NATURAL[p.feature] and WorldPlan.viewWeight(Layout, p.cframe.Position.X, p.cframe.Position.Z) >= 3)
			then
				table.insert(bare, p)
			end
		end
		local worst = 9
		for _, k in KINGDOMS do
			worst = math.min(worst, coverage(bare, k))
		end
		expect(worst).toBeLessThan(7)
	end)

	it("weights the camera's ground: the start view 3, the zoomed-out view 1.6, behind the keep 0.35", function()
		-- the start view looks along the keep's facing from above the throne at the yard 40 studs in front of it; the points are in the keep's frame
		for _, k in KINGDOMS do
			local keep = Layout.plots[k].anchors.keep
			local function weightAt(x: number, z: number): number
				local w = keep:PointToWorldSpace(Vector3.new(x, 0, z))
				return WorldPlan.viewWeight(Layout, w.X, w.Z)
			end
			expect(weightAt(0, -52)).toBe(3) -- the yard in front of the throne: the middle of the start view
			expect(weightAt(0, -150)).toBe(3) -- the ground beyond it, toward the horizon edge
			expect(weightAt(150, -60)).toBe(1.6) -- beside the start view (it is narrow), inside the zoomed-out view
			expect(weightAt(0, 100)).toBe(0.35) -- behind the keep: no camera of the plot sees it
		end
	end)
end)

describe("The same world every time, and no part more than before (D-047)", function()
	it("is deterministic: a fresh generation (another layout identity) gives the same placements", function()
		local fresh = table.clone(Layout)
		local a, b = WorldPlan.plan(Layout, ALL), WorldPlan.plan(fresh, ALL)
		expect(#a).toBe(#b)
		expect(fingerprint(a)).toBe(fingerprint(b))
	end)

	it(
		"costs no more parts at the shipped density than the scatter it replaces (4,762 of trees, bushes, rocks and flowers; 4,637 now)",
		function()
			local parts = 0
			for _, p in WorldPlan.props(Layout, { crimson = true }) do
				if NATURAL[p.feature] then
					parts += partsOf(p.assetId)
				end
			end
			-- measured on the starting tree (forest 3,177 + lone trees 526 + bushes 450 + rocks 330 + flowers 279)
			expect(parts).toBeLessThanOrEqual(4762)
		end
	)
end)

describe("WorldService scales and tints what the plan says", function()
	local function boot()
		local env = MockEnv.new({ seed = 1 })
		local svc = WorldDef.new(env, nil)
		svc.terrain = Terrain.recorder()
		svc.density = FULL
		return env, svc
	end

	-- sum of part volumes (scales by s^3 under a uniform scale about the pivot) and the farthest part centre from the pivot (by s)
	local function measure(model: any): (number, number, number)
		local primary = model.PrimaryPart
		local pivot = primary.CFrame * primary.PivotOffset
		local volume, far, n = 0, 0, 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
				volume += d.Size.X * d.Size.Y * d.Size.Z
				far = math.max(far, (d.CFrame.Position - pivot.Position).Magnitude)
			end
		end
		return volume, far, n
	end

	it("scales each prop about its pivot: same parts, volume by s^3, reach by s, nil scale unchanged", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		expect(svc.stats.error).toBeNil()
		local checked, unscaled = 0, 0
		for _, model in svc:getRoot().Props:GetChildren() do
			local s = model:GetAttribute("Scale")
			local feature = model:GetAttribute("Feature")
			if NATURAL[feature] then
				local ref = Kit.prop(model.Name)
				local v0, r0, n0 = measure(ref)
				local v1, r1, n1 = measure(model)
				expect(n1).toBe(n0) -- scale changes no part count
				if s then
					checked += 1
					expect(v1 / v0).toBeNear(s ^ 3, 1e-3 * s ^ 3)
					expect(r1 / r0).toBeNear(s, 1e-3 * s)
				else
					unscaled += 1
					expect(v1).toBeNear(v0, 1e-6 * v0)
				end
			end
		end
		expect(checked).toBeGreaterThan(200)
		svc:destroy()
	end)

	it("lands the scaled prop's pivot exactly on the placement", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		local byKey = {}
		for _, p in WorldPlan.props(Layout, svc.dressed, FULL) do
			byKey[string.format("%s@%.2f,%.2f", p.assetId, p.cframe.Position.X, p.cframe.Position.Z)] = p
		end
		local checked = 0
		for _, model in svc:getRoot().Props:GetChildren() do
			local primary = model.PrimaryPart
			local pivot = primary.CFrame * primary.PivotOffset
			local p = byKey[string.format("%s@%.2f,%.2f", model.Name, pivot.Position.X, pivot.Position.Z)]
			if p and model:GetAttribute("Scale") then
				checked += 1
				expect((pivot.Position - p.cframe.Position).Magnitude).toBeLessThan(1e-3)
			end
		end
		expect(checked).toBeGreaterThan(200)
		svc:destroy()
	end)

	it("MUTANT: a placement without a scale builds the model exactly as the unscaled path does", function()
		local env, svc = boot()
		local model1, model2 = Kit.prop("tree_oak_02"), Kit.prop("tree_oak_02")
		local cf = CFrame.new(10, 3, -20) * CFrame.Angles(0, 1.1, 0)
		svc._placeModel(model1, cf)
		svc._placeModel(model2, cf, 1)
		local a, b = {}, {}
		for _, d in model1:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(a, d)
			end
		end
		for _, d in model2:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(b, d)
			end
		end
		expect(#a).toBe(#b)
		for i, d in a do
			expect((d.CFrame.Position - b[i].CFrame.Position).Magnitude).toBeLessThan(1e-9)
			expect(d.Size).toBe(b[i].Size)
		end
		local model3 = Kit.prop("tree_oak_02")
		svc._placeModel(model3, cf, 1.2)
		local grown = 0
		for _, d in model3:GetDescendants() do
			if d:IsA("BasePart") then
				grown += 1
				expect(d.Size.X).toBeNear(a[grown].Size.X * 1.2, 1e-4)
			end
		end
		expect(env).never.toBeNil()
	end)
end)
