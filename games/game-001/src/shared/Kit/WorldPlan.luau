--!strict
--[[
	Kit/WorldPlan — pure, deterministic plan of the AI Kingdoms valley from world/Layout (FL-0055).
	WorldService executes it (terrain through an adapter, props through Kit.prop) and the world
	preview (blender/scripts/render_world.py) renders the same plan, so previews match the game.

	API
		WorldPlan.terrainOps(layout, density?) -> { Op } -- in execution order (forest floors follow the trim)
		WorldPlan.forestFloors(layout, density?) -> { { x, z, r } } -- each forest stand's leafy floor circle
		WorldPlan.props(layout, dressed: { [string]: boolean }?, density: { forest: number?, props: number? }?)
			-> { Placement }                           -- trim(clear(plan(...)), density)
		WorldPlan.plan(layout, dressed?) -> { Placement }  -- the generated dressing, before clearance
		WorldPlan.clear(layout, plan) -> { Placement }     -- drops dressing on the plots' reserved ground (CLEAR)
		WorldPlan.reservedRects(layout), WorldPlan.rectDistance(rect, x, z), WorldPlan.footprintRadius(assetId)
		WorldPlan.trim(layout, plan, density?) -> { Placement }   -- the density pass props() ends with
		WorldPlan.density(layout, override?) -> { forest, props } -- effective knob values, clamped to 0..1
		WorldPlan.unseen(layout, x, z) -> number                  -- trim score (studs; 0 = never trimmed)
		WorldPlan.showcase(layout, x, z) -> boolean               -- the plot showcase: never thinned
		WorldPlan.groundHeight(layout, x, z) -> number  -- analytic surface height (studs)
		WorldPlan.voxels(op) -> number                   -- 4-stud voxels an op touches (frame budget)
	Op = { kind: "Block" | "Ball" | "Cylinder", material: string, cframe: CFrame, size: Vector3?,
	       radius: number?, height: number?, feature: string }
	Placement = { assetId: string, cframe: CFrame, feature: string }
	Dressing density (D-047, FL-0116): the knob is world/Layout `features.density` ({ forest, props }, the share
	of each kind kept; WorldPlan.FULL_DENSITY = 1 / 1 rebuilds the valley exactly as plan() + clear() make it).
	trim() removes, per kind, the least-seen share: farthest from the plot frames, approach roads and heartland
	(WorldPlan.TRIM) first. Never thinned: the plot showcase (within TRIM.showcase studs of a plot's fields,
	buildings and slots, and the farm's view behind the keep; WorldPlan.showcase); plot frames, road bands and the
	heartland for lone trees, bushes, rocks and flowers; bridges, crops and kingdom dressing always. Forests are
	thinned stand by stand, radially (the outermost trees first, all around), and only the stands that neither
	reach the showcase nor sit in view; each thinned stand's ground disc follows it (forestFloors).
	Plot clearance (user playtest 2026-10-13): no tree, bush, rock or flower within CLEAR.margin (4) studs of a
	farm field, a starting building's largest Kit footprint, a build slot, a plot build zone or a road, measured
	with each prop's footprint and canopy radius (CLEAR.radius). Blocked trees, bushes and flowers move to the
	nearest legal spot within CLEAR.natureNudge studs instead of going; boulders against a trunk or bush go.
	Hand-placed kingdom dressing that sits inside a building, slot or field moves too (CLEAR.nudge,
	CLEAR.wallGap off walls); the gate banners are exempt and stay exactly where the plan puts them.

	Crown Arena (FL-0072, G12.6): layout.arena = { cframe, duelRadius, spawnA, spawnB, footprint } is reserved ground like a
	plot: the generator keeps decor off its footprint (WorldPlan.arenaRect), the clearance moves or removes natural dressing within
	CLEAR.margin of it (canopies included), and the trim never thins within TRIM.arenaReach studs of it (like an objective).

	Determinism: a Park–Miller PRNG (exact in doubles), never Random, so Lune specs, the preview and
	Roblox produce identical worlds.
]]

local Buildings = require("./Buildings") -- Kit.footprint (Kit itself requires Props, which requires this module)

local WorldPlan = {}

export type Op = {
	kind: string,
	material: string,
	cframe: CFrame,
	size: Vector3?,
	radius: number?,
	height: number?,
	feature: string,
}
export type Placement = { assetId: string, cframe: CFrame, feature: string }

local BASE_DEPTH = 24
local CHUNK = 256
local VOXEL = 4

-- ---------------------------------------------------------------- deterministic random

local function prng(seed: number)
	local state = (math.floor(seed) % 2147483646) + 1
	local r = {}
	function r.next(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	function r.range(a: number, b: number): number
		return a + (b - a) * r.next()
	end
	function r.int(a: number, b: number): number
		return math.min(b, a + math.floor((b - a + 1) * r.next()))
	end
	return r
end
WorldPlan._prng = prng

-- ---------------------------------------------------------------- geometry helpers

local function distToSegment(px: number, pz: number, a: Vector2, b: Vector2): number
	local abx, abz = b.X - a.X, b.Y - a.Y
	local len2 = abx * abx + abz * abz
	local t = if len2 > 0 then math.clamp(((px - a.X) * abx + (pz - a.Y) * abz) / len2, 0, 1) else 0
	local cx, cz = a.X + abx * t, a.Y + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

local function distToPolyline(px: number, pz: number, pts: { Vector2 }): number
	local best = math.huge
	for i = 1, #pts - 1 do
		best = math.min(best, distToSegment(px, pz, pts[i], pts[i + 1]))
	end
	return best
end
WorldPlan.distToPolyline = distToPolyline

-- CFrame at (x, y, z) whose local +Z runs along (dx, dz).
local function along(x: number, y: number, z: number, dx: number, dz: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.atan2(dx, dz), 0)
end

-- Hills as domes: a ball of radius r whose top is `top` studs above ground. Big hills (radius > 110)
-- become a deterministic cluster (central dome + satellites) so no single fill is huge.
type Ball = { x: number, y: number, z: number, r: number, material: string }

local hillCache: { [any]: { Ball } } = setmetatable({}, { __mode = "k" }) :: any

local function hillBalls(layout: any): { Ball }
	local cached = hillCache[layout]
	if cached then
		return cached
	end
	local gy = layout.features.groundY or 0
	local out: { Ball } = {}
	local function dome(x: number, z: number, r: number, top: number, material: string)
		table.insert(out, { x = x, y = gy + top - r, z = z, r = r, material = material })
	end
	for i, hill in layout.features.hills do
		local cx, cz, R, H = hill.center.X, hill.center.Y, hill.radius, hill.height
		if R <= 110 then
			dome(cx, cz, R, H, "Grass")
			if H >= 60 then -- rocky crown and a rock band on mountains
				dome(cx + (i % 3) * 4 - 4, cz + (i % 2) * 6 - 3, R * 0.55, H + 9, "Rock")
				dome(cx + ((i * 7) % 5 - 2) * 12, cz + ((i * 3) % 5 - 2) * 12, R * 0.5, H * 0.72, "Slate")
			end
		else
			local rng = prng(1000 + i)
			dome(cx, cz, 110, H, "Grass")
			for k = 0, 4 do
				local a = k * 2 * math.pi / 5 + rng.range(-0.3, 0.3)
				local d = R * rng.range(0.42, 0.62)
				dome(cx + math.cos(a) * d, cz + math.sin(a) * d, rng.range(70, 95), H * rng.range(0.45, 0.75), "Grass")
			end
			if H >= 40 then
				dome(cx + rng.range(-12, 12), cz + rng.range(-12, 12), 58, H + 6, "Rock")
			end
		end
	end
	hillCache[layout] = out
	return out
end
WorldPlan.hillBalls = hillBalls

local function capRadius(b: Ball, gy: number): number
	local dy = gy - b.y
	return math.sqrt(math.max(0, b.r * b.r - dy * dy))
end

function WorldPlan.groundHeight(layout: any, x: number, z: number): number
	local f = layout.features
	local gy = f.groundY or 0
	local h = gy
	for _, b in hillBalls(layout) do
		local d2 = (x - b.x) ^ 2 + (z - b.z) ^ 2
		if d2 < b.r * b.r then
			h = math.max(h, b.y + math.sqrt(b.r * b.r - d2))
		end
	end
	local r = f.river
	if distToPolyline(x, z, r.points) < r.width / 2 then
		h = gy - r.depth
	end
	return h
end

function WorldPlan.voxels(op: Op): number
	if op.kind == "Block" then
		local s = op.size :: Vector3
		return math.ceil(s.X / VOXEL) * math.ceil(s.Y / VOXEL) * math.ceil(s.Z / VOXEL)
	elseif op.kind == "Ball" then
		local d = math.ceil(2 * (op.radius :: number) / VOXEL)
		return d * d * d
	end
	local d = math.ceil(2 * (op.radius :: number) / VOXEL)
	return d * d * math.ceil((op.height :: number) / VOXEL)
end

-- ---------------------------------------------------------------- terrain plan

function WorldPlan.terrainOps(layout: any, density: { [string]: number }?): { Op }
	local f = layout.features
	local ops: { Op } = {}
	local function block(material: string, cf: CFrame, size: Vector3, feature: string)
		table.insert(ops, { kind = "Block", material = material, cframe = cf, size = size, feature = feature })
	end
	local function cylinder(
		material: string,
		x: number,
		y: number,
		z: number,
		radius: number,
		height: number,
		feature: string
	)
		table.insert(ops, {
			kind = "Cylinder",
			material = material,
			cframe = CFrame.new(x, y, z),
			radius = radius,
			height = height,
			feature = feature,
		})
	end
	local gy = f.groundY or 0
	local mn, mx = f.bounds.min, f.bounds.max

	-- 1. base ground in chunks (top at groundY), so no single call is huge
	local x = mn.X
	while x < mx.X do
		local w = math.min(CHUNK, mx.X - x)
		local z = mn.Y
		while z < mx.Y do
			local d = math.min(CHUNK, mx.Y - z)
			block(
				"Grass",
				CFrame.new(x + w / 2, gy - BASE_DEPTH / 2, z + d / 2),
				Vector3.new(w, BASE_DEPTH, d),
				"ground"
			)
			z += d
		end
		x += w
	end

	-- 2. hills and mountains (grass domes; mountains get rocky crowns)
	for _, b in hillBalls(layout) do
		table.insert(
			ops,
			{ kind = "Ball", material = b.material, cframe = CFrame.new(b.x, b.y, b.z), radius = b.r, feature = "hill" }
		)
	end

	-- 3. forest floors (leafy grass discs)
	local floors = WorldPlan.forestFloors(layout, density)
	for i in f.forests do
		local floor = floors[i]
		local fy = WorldPlan.groundHeight(layout, floor.x, floor.z)
		cylinder("LeafyGrass", floor.x, fy - 1, floor.z, floor.r, 2.5, "forest_floor")
	end

	-- 4. variety patches on open ground
	local rng = prng(911)
	for _ = 1, 28 do
		local px, pz = rng.range(mn.X + 40, mx.X - 40), rng.range(mn.Y + 40, mx.Y - 40)
		local material = if rng.next() < 0.6 then "LeafyGrass" else "Ground"
		local radius = if material == "Ground" then rng.range(6, 12) else rng.range(16, 34)
		local py = WorldPlan.groundHeight(layout, px, pz)
		if distToPolyline(px, pz, f.river.points) > f.river.width then
			cylinder(material, px, py - 1, pz, radius, 2.4, "patch")
		end
	end

	-- 5. farm fields (tilled soil)
	for _, field in f.fields do
		local fy = WorldPlan.groundHeight(layout, field.center.X, field.center.Y)
		block(
			"Mud",
			CFrame.new(field.center.X, fy - 0.8, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0),
			Vector3.new(field.size.X, 2, field.size.Y),
			"field"
		)
	end

	-- 6. roads: short pieces that follow the ground, dirt with a cobbled plaza at the hub
	for _, road in f.roads do
		local pts = road.points
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local len = (b - a).Magnitude
			local n = math.max(1, math.ceil(len / 16))
			for k = 0, n - 1 do
				local t0, t1 = k / n, (k + 1) / n
				local p0, p1 = a:Lerp(b, t0), a:Lerp(b, t1)
				local mid = (p0 + p1) / 2
				local my = WorldPlan.groundHeight(layout, mid.X, mid.Y)
				local seg = p1 - p0
				block(
					"Ground",
					along(mid.X, my - 0.9, mid.Y, seg.X, seg.Y),
					Vector3.new(road.width, 2, seg.Magnitude + road.width * 0.5),
					"road"
				)
			end
		end
	end
	local hubX, hubZ = f.roads[1].points[#f.roads[1].points].X, f.roads[1].points[#f.roads[1].points].Y
	cylinder("Cobblestone", hubX, WorldPlan.groundHeight(layout, hubX, hubZ) - 0.9, hubZ, 14, 2, "plaza")
	for _, kingdom in { "crimson", "azure", "emerald", "gold" } do
		local plot = layout.plots[kingdom]
		local yard = (plot.anchors.keep * CFrame.new(0, 0, -62)).Position -- the yard crossroads (Layout nav)
		cylinder("Cobblestone", yard.X, gy - 0.9, yard.Z, 11, 2, "plaza")
	end

	-- 7. river: sandy banks, carve, then water (surface 1.4 below ground)
	local r = f.river
	for i = 1, #r.points - 1 do
		local a, b = r.points[i], r.points[i + 1]
		local seg = b - a
		local mid = (a + b) / 2
		local len = seg.Magnitude
		block(
			"Sand",
			along(mid.X, gy - 1, mid.Y, seg.X, seg.Y),
			Vector3.new(r.width + 12, 2, len + r.width),
			"river_bank"
		)
		block(
			"Air",
			along(mid.X, gy + 6 - (r.depth + 6) / 2, mid.Y, seg.X, seg.Y),
			Vector3.new(r.width, r.depth + 6, len + r.width * 0.6),
			"river"
		)
		block(
			"Water",
			along(mid.X, gy - 1.4 - (r.depth - 1.4) / 2, mid.Y, seg.X, seg.Y),
			Vector3.new(r.width + 1, r.depth - 1.4, len + r.width * 0.6),
			"river"
		)
	end
	return ops
end

-- ---------------------------------------------------------------- props plan

local SPECIES_VARIANTS = { tree_oak = 8, tree_pine = 6, tree_birch = 6 }
local KINGDOM_ORDER = { "crimson", "azure", "emerald", "gold" } -- fixed order: dictionary iteration is not portable

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function assetId(prefix: string, n: number): string
	return string.format("%s_%02d", prefix, n)
end

-- The arena's footprint as a reserved rectangle (cf = the arena's frame on the ground, half = half the Kit.arena plate on X and Z),
-- or nil when the layout has none. Cached per layout (Layout is data; specs build their own).
local arenaCache: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
function WorldPlan.arenaRect(layout: any): { cf: CFrame, half: Vector2, kind: string }?
	local cached = arenaCache[layout]
	if cached == nil then
		local a = layout.arena
		cached = if a then { cf = a.cframe, half = a.footprint / 2, kind = "arena" } else false
		arenaCache[layout] = cached
	end
	return if cached then cached else nil
end

-- Where the generator may stand a prop of scatter radius r: inside the bounds, off the river, the roads and the
-- keep-out discs (plot cores, build zones, build slots, objective, resource nodes, bridges). plan() and the
-- clearance's relocation of blocked decor share it.
local function staticClearance(layout: any): (number, number, number) -> boolean
	local f = layout.features
	local keepOut: { { x: number, z: number, r: number } } = {}
	for _, plot in layout.plots do
		for _, anchor in plot.anchors do
			table.insert(keepOut, { x = anchor.Position.X, z = anchor.Position.Z, r = 30 })
		end
		for _, zone in plot.buildZones do
			table.insert(
				keepOut,
				{ x = zone.center.X, z = zone.center.Z, r = math.max(zone.size.X, zone.size.Y) * 0.6 }
			)
		end
		for _, slot in plot.buildSlots or {} do
			local size = (layout.slotSizes or {})[slot.size] or Vector2.new(46, 40)
			table.insert(keepOut, { x = slot.center.X, z = slot.center.Z, r = size.Magnitude / 2 + 1 })
		end
	end
	for _, o in layout.objectives do
		table.insert(keepOut, { x = o.cframe.Position.X, z = o.cframe.Position.Z, r = o.radius + 14 })
	end
	for _, node in layout.resourceNodes do
		table.insert(keepOut, { x = node.cframe.Position.X, z = node.cframe.Position.Z, r = 9 })
	end
	for _, br in f.river.bridges do
		table.insert(keepOut, { x = br.at.X, z = br.at.Y, r = 26 })
	end
	local arena = WorldPlan.arenaRect(layout)
	return function(x: number, z: number, r: number): boolean
		if x < f.bounds.min.X + 8 or x > f.bounds.max.X - 8 or z < f.bounds.min.Y + 8 or z > f.bounds.max.Y - 8 then
			return false
		end
		if distToPolyline(x, z, f.river.points) < f.river.width / 2 + 10 + r then
			return false
		end
		for _, road in f.roads do
			if distToPolyline(x, z, road.points) < road.width / 2 + 3 + r then
				return false
			end
		end
		for _, k in keepOut do
			if (x - k.x) ^ 2 + (z - k.z) ^ 2 < (k.r + r) ^ 2 then
				return false
			end
		end
		if arena and WorldPlan.rectDistance(arena, x, z) < r + WorldPlan.CLEAR.margin then
			return false
		end
		return true
	end
end

-- The valley's dressing as generated (bridges, crops, forests, scatter, kingdom dressing), before clear().
function WorldPlan.plan(layout: any, dressed: { [string]: boolean }?): { Placement }
	local f = layout.features
	local out: { Placement } = {}
	local occupied: { { x: number, z: number, r: number } } = {}
	local rng = prng(4242)

	local staticClear = staticClearance(layout)

	local function clear(x: number, z: number, r: number): boolean
		if not staticClear(x, z, r) then
			return false
		end
		for _, o in occupied do
			if (x - o.x) ^ 2 + (z - o.z) ^ 2 < (o.r + r) ^ 2 then
				return false
			end
		end
		return true
	end

	local function place(id: string, x: number, z: number, r: number, feature: string, yaw: number?)
		table.insert(occupied, { x = x, z = z, r = r })
		local y = WorldPlan.groundHeight(layout, x, z)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw or rng.range(0, 2 * math.pi), 0)
		table.insert(out, { assetId = id, cframe = cf, feature = feature })
	end

	local function scatter(
		n: number,
		cx: number,
		cz: number,
		radius: number,
		r: number,
		pick: () -> string,
		feature: string
	)
		local placed, tries = 0, 0
		while placed < n and tries < n * 30 do
			tries += 1
			local a, d = rng.range(0, 2 * math.pi), radius * math.sqrt(rng.next())
			local x, z = cx + math.cos(a) * d, cz + math.sin(a) * d
			if clear(x, z, r) then
				place(pick(), x, z, r, feature)
				placed += 1
			end
		end
	end

	-- bridges first (they define keep-outs for everything else)
	for i, br in f.river.bridges do
		local y = WorldPlan.groundHeight(layout, br.at.X + 30, br.at.Y)
		table.insert(out, {
			assetId = assetId("bridge_stone", i),
			cframe = CFrame.new(br.at.X, y, br.at.Y) * CFrame.Angles(0, math.rad(br.yaw), 0),
			feature = "bridge",
		})
	end

	-- crops on every terrain field (wheat / cabbage rows), hedges around them
	for i, field in f.fields do
		local y = WorldPlan.groundHeight(layout, field.center.X, field.center.Y)
		table.insert(out, {
			assetId = string.format("farm_field_%s_%02d", field.crop or "wheat", 1 + (i % 3)),
			cframe = CFrame.new(field.center.X, y, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0),
			feature = "crops",
		})
		table.insert(
			occupied,
			{ x = field.center.X, z = field.center.Y, r = math.max(field.size.X, field.size.Y) * 0.62 }
		)
	end

	-- forests
	for _, forest in f.forests do
		local species = forest.species
		local k = 0
		scatter(forest.count, forest.center.X, forest.center.Y, forest.radius, 6.5, function()
			k += 1
			local s = species[1 + (k % #species)]
			return assetId(s, rng.int(1, SPECIES_VARIANTS[s] or 6))
		end, "forest")
	end
	-- lone trees and bushes across the valley, rocks at the hill feet, flowers near plots
	scatter(60, 20, 0, 640, 6, function()
		local s = if rng.next() < 0.7 then "tree_oak" else "tree_birch"
		return assetId(s, rng.int(1, SPECIES_VARIANTS[s]))
	end, "lone_tree")
	scatter(110, 20, 0, 640, 2.5, function()
		return assetId("bush", rng.int(1, 8))
	end, "bush")
	for _, b in hillBalls(layout) do
		local cap = capRadius(b, f.groundY or 0)
		scatter(if b.r >= 70 then 5 else 3, b.x, b.z, cap * 1.05, 4, function()
			local size = ({ "s", "m", "l" })[rng.int(1, 3)]
			return string.format("rock_boulder_%s_%02d", size, rng.int(1, 3))
		end, "rocks")
	end
	for _, kingdom in KINGDOM_ORDER do
		local c = layout.plots[kingdom].anchors.keep.Position
		scatter(8, c.X, c.Z, 120, 2, function()
			return assetId("plant_flowers", rng.int(1, 6))
		end, "flowers")
	end

	-- dressing for fully dressed kingdoms (VS-1: one dressed plot, the others blocked out)
	local KINGDOM_BANNER = { crimson = "red", azure = "blue", emerald = "green", gold = "yellow" }
	for _, kingdom in KINGDOM_ORDER do
		local plot = layout.plots[kingdom]
		if dressed and dressed[kingdom] then
			local keep = plot.anchors.keep
			local yaw = yawOf(keep)
			local banner = KINGDOM_BANNER[kingdom] or "red"
			for i, off in
				{ Vector3.new(-9, 0, -96), Vector3.new(9, 0, -96), Vector3.new(-9, 0, -128), Vector3.new(9, 0, -128) }
			do
				local p = (keep * CFrame.new(off)).Position
				place(string.format("prop_banner_%s_%02d", banner, 1 + (i % 2)), p.X, p.Z, 1.5, "dressing", yaw)
			end
			local yard = (keep * CFrame.new(14, 0, -46)).Position
			place("prop_well_01", yard.X, yard.Z, 4, "dressing")
			for i, off in
				{ Vector3.new(-30, 0, -10), Vector3.new(-30, 0, 6), Vector3.new(30, 0, -14), Vector3.new(-76, 0, 2) }
			do
				local p = (keep * CFrame.new(off)).Position
				local id = if i == 3
					then "farm_haystack_01"
					elseif i == 4 then "prop_cart_02"
					else assetId("prop_goods", i)
				place(id, p.X, p.Z, 3, "dressing") -- hand-placed clear of slots, nav and roads (spec)
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- plot clearance (user playtest, 2026-10-13)

-- Farm fields, starting buildings, build slots and roads stay clear of dressing. `margin`: studs of open ground
-- between natural dressing (trees, bushes, rocks, flowers) and those areas. `radius`: horizontal footprint radius
-- (studs from the pivot, canopies included) per asset family: the Kit.prop bounds rounded up, with ~1 stud of
-- slack for trees, bushes and rocks (a canopy or rock outline varies per variant) and 0.1 for hand-placed props.
-- The PlotClearance spec checks every planned asset against its live Kit.prop bounds, so a prop that grows fails.
WorldPlan.CLEAR = table.freeze({
	margin = 4,
	radius = table.freeze({
		tree_oak = 13.5,
		tree_pine = 11.7,
		tree_birch = 8.5,
		bush = 5.2,
		plant_flowers = 3.4,
		rock_boulder_s = 5.8,
		rock_boulder_m = 7.5,
		rock_boulder_l = 13.3,
		prop_banner = 2.4, -- hand-placed kingdom dressing: live bounds + 0.1 only, so just real overlaps go
		prop_well = 5.3,
		prop_cart = 7.3,
		prop_goods = 4.8,
		farm_haystack = 4.4,
	}),
	fallbackRadius = 15, -- an asset family missing from `radius`
	nudge = 8, -- hand-placed dressing on reserved ground moves to the nearest legal spot within this many studs
	wallGap = 1.5, -- ... and keeps this much open ground between its outline and a building or slot wall
	natureNudge = 12, -- blocked trees, bushes and flowers move to the nearest legal spot within this many studs
	trunk = 3, -- a boulder keeps its outline this far from a tree trunk (the plan spaces props by scatter radii)
	bushGap = 2, -- ... and from a bush's centre
})
local NATURAL = { forest = true, lone_tree = true, bush = true, rocks = true, flowers = true }
-- the plan's own spacing radii per feature (WorldPlan.plan's scatter calls): two placements keep their sum apart
local SCATTER: { [string]: number } = { forest = 6.5, lone_tree = 6, bush = 2.5, rocks = 4, flowers = 2 }

-- Footprint radius of an asset id: the longest id prefix (dropping "_<part>" from the end) in CLEAR.radius.
function WorldPlan.footprintRadius(id: string): number
	local key = id
	while key ~= "" do
		local r = WorldPlan.CLEAR.radius[key]
		if r then
			return r
		end
		key = string.match(key, "^(.*)_[^_]*$") or ""
	end
	return WorldPlan.CLEAR.fallbackRadius
end

-- The plots' reserved ground (G10.1 Layout): farm fields, each starting building's largest Kit footprint (levels
-- upgrade in place; Kit.footprint clamps the level) at its anchor, the build slots and the build zones (plot-local
-- rectangles turned with the keep, as the sim's Kingdom/Layout reads them), as rectangles { cf, half, kind } (half = half size on X and Z).
function WorldPlan.reservedRects(layout: any): { { cf: CFrame, half: Vector2, kind: string } }
	local out = {}
	for _, field in layout.features.fields do
		local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
		table.insert(out, { cf = cf, half = field.size / 2, kind = "field" })
	end
	for _, kingdom in KINGDOM_ORDER do
		local plot = layout.plots[kingdom]
		for buildingType, anchor in plot.anchors do
			table.insert(
				out,
				{ cf = anchor, half = Buildings.footprint(buildingType, math.huge) / 2, kind = "building" }
			)
		end
		for _, slot in plot.buildSlots or {} do
			local size = (layout.slotSizes or {})[slot.size] or Vector2.new(46, 40)
			local cf = CFrame.new(slot.center) * CFrame.Angles(0, slot.rot, 0)
			table.insert(out, { cf = cf, half = size / 2, kind = "slot" })
		end
		for _, zone in plot.buildZones do
			local cf = CFrame.new(zone.center) * CFrame.Angles(0, yawOf(plot.anchors.keep), 0)
			table.insert(out, { cf = cf, half = zone.size / 2, kind = "zone" })
		end
	end
	return out
end

-- Studs from (x, z) to a reserved rectangle (0 inside).
function WorldPlan.rectDistance(rect: { cf: CFrame, half: Vector2 }, x: number, z: number): number
	local p = rect.cf:PointToObjectSpace(Vector3.new(x, rect.cf.Position.Y, z))
	local dx, dz = math.max(0, math.abs(p.X) - rect.half.X), math.max(0, math.abs(p.Z) - rect.half.Y)
	return math.sqrt(dx * dx + dz * dz)
end

-- Does a prop of footprint radius `r` at (x, z) stand on reserved ground? Natural dressing keeps `margin` off
-- everything (build zones included); hand-placed dressing keeps `margin` off fields and nothing off the zones.
local function blocked(layout: any, rects: { any }, natural: boolean, r: number, x: number, z: number): boolean
	local margin = WorldPlan.CLEAR.margin
	for _, rect in rects do
		if natural or rect.kind ~= "zone" then
			local m = if natural or rect.kind == "field" then margin else WorldPlan.CLEAR.wallGap
			if WorldPlan.rectDistance(rect, x, z) < r + m then
				return true
			end
		end
	end
	local arena = WorldPlan.arenaRect(layout)
	if arena and WorldPlan.rectDistance(arena, x, z) < r + (if natural then margin else WorldPlan.CLEAR.wallGap) then
		return true
	end
	local m = if natural then margin else 0
	for _, road in layout.features.roads do
		if distToPolyline(x, z, road.points) < road.width / 2 + r + m then
			return true
		end
	end
	return false
end

-- The nearest legal spot within CLEAR.nudge studs of (x, z) for hand-placed dressing (rings every 0.25 stud,
-- 32 directions, first legal one wins, so it is deterministic), or nil.
local function nudged(layout: any, rects: { any }, r: number, x: number, z: number): (number?, number?)
	local d = 0.25
	while d <= WorldPlan.CLEAR.nudge do
		for k = 0, 31 do
			local a = k * math.pi / 16
			local nx, nz = x + math.cos(a) * d, z + math.sin(a) * d
			if not blocked(layout, rects, false, r, nx, nz) then
				return nx, nz
			end
		end
		d += 0.25
	end
	return nil, nil
end

-- Boulders keep off tree trunks and bush bodies: the plan spaces props by their scatter radii, smaller than a
-- boulder's outline, so a rock could stand against a trunk. A rock whose outline reaches one goes.
local function spaceRocks(plan: { Placement }): { Placement }
	local trunks: { Vector3 } = {}
	local bushes: { Vector3 } = {}
	for _, p in plan do
		if p.feature == "forest" or p.feature == "lone_tree" then
			table.insert(trunks, p.cframe.Position)
		elseif p.feature == "bush" then
			table.insert(bushes, p.cframe.Position)
		end
	end
	local out: { Placement } = {}
	for _, p in plan do
		local keep = true
		if p.feature == "rocks" then
			local pos = p.cframe.Position
			local r = WorldPlan.footprintRadius(p.assetId)
			for _, t in trunks do
				if (pos.X - t.X) ^ 2 + (pos.Z - t.Z) ^ 2 < (r + WorldPlan.CLEAR.trunk) ^ 2 then
					keep = false
					break
				end
			end
			if keep then
				for _, b in bushes do
					if (pos.X - b.X) ^ 2 + (pos.Z - b.Z) ^ 2 < (r + WorldPlan.CLEAR.bushGap) ^ 2 then
						keep = false
						break
					end
				end
			end
		end
		if keep then
			table.insert(out, p)
		end
	end
	return out
end

local function moved(layout: any, p: Placement, x: number, z: number): Placement
	local cf = CFrame.new(x, WorldPlan.groundHeight(layout, x, z), z) * (p.cframe - p.cframe.Position)
	return { assetId = p.assetId, cframe = cf, feature = p.feature }
end

-- The nearest legal spot within CLEAR.natureNudge studs for a tree, bush or flower that the clearance blocked: off
-- every reserved area and road with its footprint, and where the generator itself would stand it (bounds, river,
-- keep-out discs, the spacing radii of the other placements). Rings every stud, 24 directions, first legal wins.
local function relocatedNatural(
	layout: any,
	rects: { any },
	staticClear: (number, number, number) -> boolean,
	plan: { Placement },
	p: Placement
): Placement?
	local scatter, r, pos = SCATTER[p.feature], WorldPlan.footprintRadius(p.assetId), p.cframe.Position
	local function legal(x: number, z: number): boolean
		if blocked(layout, rects, true, r, x, z) or not staticClear(x, z, scatter) then
			return false
		end
		for _, q in plan do
			local sq = SCATTER[q.feature]
			if sq and q ~= p then
				local qp = q.cframe.Position
				if (qp.X - x) ^ 2 + (qp.Z - z) ^ 2 < (sq + scatter) ^ 2 then
					return false
				end
			end
		end
		return true
	end
	local d = 1
	while d <= WorldPlan.CLEAR.natureNudge do
		for k = 0, 23 do
			local a = k * math.pi / 12
			local x, z = pos.X + math.cos(a) * d, pos.Z + math.sin(a) * d
			if legal(x, z) then
				return moved(layout, p, x, z)
			end
		end
		d += 1
	end
	return nil
end

-- The kingdom gate banners (prop_banner_<colour>_NN) stand beside the road on purpose.
local function isBanner(p: Placement): boolean
	return p.feature == "dressing" and string.sub(p.assetId, 1, 11) == "prop_banner"
end

-- Clear dressing off reserved ground. Anything blocked moves before it goes. Natural decor within CLEAR.margin of a
-- field, a starting building, a slot, a build zone or a road moves to the nearest legal spot within
-- CLEAR.natureNudge studs (rocks, and decor with no such spot, are removed); a boulder against a trunk or a bush
-- goes. Hand-placed kingdom dressing (yard props, gate banners; meant to stand in the build zones) that overlaps a
-- building, a slot or a road, or sits within the margin of a field or CLEAR.wallGap of a wall, moves to the nearest
-- legal spot within CLEAR.nudge studs (same facing). The gate banners are left exactly where the plan puts them.
-- Nothing is added, and what stays is exactly the plan.
function WorldPlan.clear(layout: any, plan: { Placement }): { Placement }
	local rects = WorldPlan.reservedRects(layout)
	local staticClear = staticClearance(layout)
	local out: { Placement } = {}
	for _, p in plan do
		local natural = NATURAL[p.feature] == true
		local placed: Placement? = p
		if isBanner(p) then
			placed = p -- gate banners flank the road by design: exactly where the plan puts them
		elseif natural or p.feature == "dressing" then
			local pos = p.cframe.Position
			local r = WorldPlan.footprintRadius(p.assetId)
			if blocked(layout, rects, natural, r, pos.X, pos.Z) then
				placed = nil
				if natural and p.feature ~= "rocks" then
					placed = relocatedNatural(layout, rects, staticClear, plan, p)
				elseif not natural then
					local nx, nz = nudged(layout, rects, r, pos.X, pos.Z)
					if nx and nz then
						placed = moved(layout, p, nx, nz)
					end
				end
			end
		end
		if placed then
			table.insert(out, placed)
		end
	end
	return spaceRocks(out)
end

-- The dressing WorldService places: the plan, cleared off the plots' reserved ground, then thinned to the
-- density knob (D-047, below).
function WorldPlan.props(layout: any, dressed: { [string]: boolean }?, density: { [string]: number }?): { Placement }
	return WorldPlan.trim(layout, WorldPlan.clear(layout, WorldPlan.plan(layout, dressed)), density)
end

-- ---------------------------------------------------------------- dressing density (D-047)

-- The plan above is the untrimmed valley. The trim only removes placements from it, never moves or adds one,
-- and draws from its own PRNG, so density 1.0 returns that plan unchanged and every trimmed world is a subset.
WorldPlan.FULL_DENSITY = table.freeze({ forest = 1, props = 1 })
-- the kinds the knob thins (each on its own) and the knob that thins them; bridges, crops and kingdom dressing
-- are never trimmed
local TRIM_KINDS = { "forest", "lone_tree", "bush", "rocks", "flowers" }
local TRIM_KNOB = { forest = "forest", lone_tree = "props", bush = "props", rocks = "props", flowers = "props" }
WorldPlan.TRIM = table.freeze({
	frameRadius = 200, -- plot framing: studs around the plot's view line; never thinned
	frameReach = 220, -- the view line runs from the plot centre (keep frame z -40) this far out of the keep's front,
	-- where the throne and the default overview camera (behind the keep, looking out) see most
	roadBand = 45, -- approach roads: studs either side of a road line; never thinned
	heartRadius = 170, -- heartland: studs around the central objective (the valley centre camera); never thinned
	outpostRadius = 70, -- the neutral outposts (FL-0127): studs around each; never thinned (a full heartland radius
	-- around three more objectives kept ~630 more parts and would eat the D-047 headroom)
	spurBand = 20, -- road spurs to the outposts (marked `spur` in the layout): studs either side; never thinned
	arenaReach = 60, -- the Crown Arena (FL-0072): studs around its footprint that are never thinned
	jitter = 90, -- studs of deterministic noise on the score, so thinning fades in instead of cutting a line
	standSpread = 1.6, -- a forest stand loses at most this times the forest cut (0.75 -> 40 %), so none goes bald
	showcase = 60, -- plot showcase: studs around a plot's fields, buildings and slots that are never thinned ...
	farmReach = 190, -- ... plus the farm's view: this far behind the keep (keep frame +Z, where the aerial and
	farmRadius = 100, -- the plot's-back-edge cameras look from), this wide on either side
	standShowcase = 0.25, -- a forest stand with more than this share of its trees in the showcase stays whole:
	-- thinning only its far side would leave it lopsided
	standSeen = 15, -- ... and so does a stand whose trees are on average closer than this (studs) to what the
	-- cameras look at: the mid-valley stands by the heartland and the plot views
})

-- The effective knob: `override` over the layout's features.density over full density, each clamped to 0..1.
function WorldPlan.density(layout: any, override: { [string]: number }?): { forest: number, props: number }
	local base = layout.features.density or WorldPlan.FULL_DENSITY
	local o = override or {}
	return {
		forest = math.clamp(o.forest or base.forest or 1, 0, 1),
		props = math.clamp(o.props or base.props or 1, 0, 1),
	}
end

-- The plot showcase: what a player sees first and longest. Within TRIM.showcase studs of a plot's crop fields,
-- starting buildings or build slots, or in the farm's view (TRIM.farmReach behind the keep, TRIM.farmRadius to
-- either side). Nothing here is thinned; the clearance still applies.
local rectCache: { [any]: { any } } = setmetatable({}, { __mode = "k" }) :: any

function WorldPlan.showcase(layout: any, x: number, z: number): boolean
	local t = WorldPlan.TRIM
	local rects = rectCache[layout]
	if not rects then
		rects = WorldPlan.reservedRects(layout)
		rectCache[layout] = rects
	end
	for _, rect in rects do
		if rect.kind ~= "zone" and WorldPlan.rectDistance(rect, x, z) <= t.showcase then
			return true
		end
	end
	for _, kingdom in KINGDOM_ORDER do
		local l = layout.plots[kingdom].anchors.keep:PointToObjectSpace(Vector3.new(x, 0, z))
		local behind = math.clamp(l.Z, 0, t.farmReach)
		if (l.X * l.X + (l.Z - behind) ^ 2) <= t.farmRadius * t.farmRadius then
			return true
		end
	end
	return false
end

-- How far (studs) a ground point lies from what the throne and overview cameras look at: 0 inside a plot frame,
-- on an approach road band or in the heartland, and largest at the map edges and between the kingdoms.
function WorldPlan.unseen(layout: any, x: number, z: number): number
	if WorldPlan.showcase(layout, x, z) then
		return 0
	end
	local t = WorldPlan.TRIM
	local attention = math.huge
	local arena = WorldPlan.arenaRect(layout)
	if arena then
		attention = WorldPlan.rectDistance(arena, x, z) - t.arenaReach
	end
	for _, kingdom in KINGDOM_ORDER do
		local keep = layout.plots[kingdom].anchors.keep
		local a, b = (keep * CFrame.new(0, 0, -40)).Position, (keep * CFrame.new(0, 0, -40 - t.frameReach)).Position
		attention =
			math.min(attention, distToPolyline(x, z, { Vector2.new(a.X, a.Z), Vector2.new(b.X, b.Z) }) - t.frameRadius)
	end
	for _, road in layout.features.roads do
		attention =
			math.min(attention, distToPolyline(x, z, road.points) - (if road.spur then t.spurBand else t.roadBand))
	end
	for _, o in layout.objectives do
		local p = o.cframe.Position
		local reach = if o.regionId == "heartland" then t.heartRadius else t.outpostRadius
		attention = math.min(attention, math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2) - reach)
	end
	return math.max(0, attention)
end

-- Index of the forest stand a tree stands in (stands do not overlap), or 0.
local function standOf(layout: any, x: number, z: number): number
	for s, forest in layout.features.forests do
		if (x - forest.center.X) ^ 2 + (z - forest.center.Y) ^ 2 <= forest.radius * forest.radius then
			return s
		end
	end
	return 0
end

-- Thin the dressing in `plan` to `density` (default: the layout's knob). Per kind, round((1 - d) * n) placements
-- go, the least seen first (highest unseen distance + jitter). Placements in a plot frame, on a road band or in the
-- heartland (unseen 0) are never removed, so a kind keeps more than d when the others run out; no forest stand
-- loses more than standSpread times the forest cut.
function WorldPlan.trim(layout: any, plan: { Placement }, density: { [string]: number }?): { Placement }
	local d = WorldPlan.density(layout, density)
	if d.forest >= 1 and d.props >= 1 then
		return plan
	end
	local t = WorldPlan.TRIM
	local noise = prng(4747) -- its own stream: the plan's PRNG is never touched
	local byKind: { [string]: { number } } = {}
	local jitter: { [number]: number } = {}
	for i, p in plan do
		if TRIM_KNOB[p.feature] then
			byKind[p.feature] = byKind[p.feature] or {}
			table.insert(byKind[p.feature], i)
			jitter[i] = noise.next() * t.jitter
		end
	end
	local dropped: { [number]: boolean } = {}
	for _, kind in TRIM_KINDS do
		local list = byKind[kind] or {}
		local cut = 1 - d[TRIM_KNOB[kind]]
		local left = math.floor(cut * #list + 0.5)
		if kind == "forest" then
			-- Stands are thinned as a whole, radially: the stands the cameras see least give up the most (at most
			-- standSpread x the cut), and inside a stand the outermost trees outside the plot showcase go first, all
			-- around, so what stays is centred on the stand and its ground disc can follow it.
			local stands: { [number]: { trees: { number }, sum: number, shown: number } } = {}
			for _, i in list do
				local pos = plan[i].cframe.Position
				local s = standOf(layout, pos.X, pos.Z)
				stands[s] = stands[s] or { trees = {}, sum = 0, shown = 0 }
				table.insert(stands[s].trees, i)
				stands[s].sum += WorldPlan.unseen(layout, pos.X, pos.Z)
				stands[s].shown += if WorldPlan.showcase(layout, pos.X, pos.Z) then 1 else 0
			end
			local order: { number } = {}
			for s, stand in stands do
				if stand.shown <= #stand.trees * t.standShowcase and stand.sum >= #stand.trees * t.standSeen then
					table.insert(order, s)
				end
			end
			table.sort(order, function(a, b)
				local sa, sb = stands[a].sum / #stands[a].trees, stands[b].sum / #stands[b].trees
				if sa ~= sb then
					return sa > sb
				end
				return a < b
			end)
			for _, s in order do
				local stand = stands[s]
				local centre = if s > 0 then layout.features.forests[s].center else Vector2.zero
				local rim: { { i: number, r: number } } = {}
				for _, i in stand.trees do
					local pos = plan[i].cframe.Position
					if not WorldPlan.showcase(layout, pos.X, pos.Z) then
						table.insert(rim, { i = i, r = (Vector2.new(pos.X, pos.Z) - centre).Magnitude })
					end
				end
				table.sort(rim, function(a, b)
					if a.r ~= b.r then
						return a.r > b.r
					end
					return a.i < b.i
				end)
				local cap = math.floor(#stand.trees * math.min(1, cut * t.standSpread) + 0.5)
				for k = 1, math.min(cap, left, #rim) do
					dropped[rim[k].i] = true
				end
				left -= math.min(cap, left, #rim)
			end
		else
			local candidates: { { i: number, score: number } } = {}
			for _, i in list do
				local pos = plan[i].cframe.Position
				local unseen = WorldPlan.unseen(layout, pos.X, pos.Z)
				if unseen > 0 then
					table.insert(candidates, { i = i, score = unseen + jitter[i] })
				end
			end
			table.sort(candidates, function(a, b)
				if a.score ~= b.score then
					return a.score > b.score
				end
				return a.i < b.i
			end)
			for _, c in candidates do
				if left <= 0 then
					break
				end
				dropped[c.i] = true
				left -= 1
			end
		end
	end
	local out: { Placement } = {}
	for i, p in plan do
		if not dropped[i] then
			table.insert(out, p)
		end
	end
	return out
end

-- Ground circle of each forest stand's leafy floor (the "forest_floor" terrain op): today's disc (the stand's
-- centre, 1.05 x its radius) or, for a stand the trim thinned, a circle centred on the kept trees' centroid reaching
-- the farthest of them plus the same 5 % pad, so the dark ground follows the stand instead of staying full size under
-- a few trees. Stands the trim left alone keep today's disc exactly.
export type Floor = { x: number, z: number, r: number }
local floorCache: { [any]: { [string]: { Floor } } } = setmetatable({}, { __mode = "k" }) :: any

function WorldPlan.forestFloors(layout: any, density: { [string]: number }?): { Floor }
	local d = WorldPlan.density(layout, density)
	local key = `{d.forest}:{d.props}`
	local byKey = floorCache[layout]
	if not byKey then
		byKey = {}
		floorCache[layout] = byKey
	end
	if byKey[key] then
		return byKey[key]
	end
	local forests = layout.features.forests
	local floors: { Floor } = {}
	for s, forest in forests do
		floors[s] = { x = forest.center.X, z = forest.center.Y, r = forest.radius * 1.05 }
	end
	if d.forest < 1 then
		local cleared = WorldPlan.clear(layout, WorldPlan.plan(layout, {})) -- forests do not depend on `dressed`
		local total: { [number]: number } = {}
		for _, p in cleared do
			if p.feature == "forest" then
				local s = standOf(layout, p.cframe.Position.X, p.cframe.Position.Z)
				total[s] = (total[s] or 0) + 1
			end
		end
		local kept: { [number]: { Vector2 } } = {}
		for _, p in WorldPlan.trim(layout, cleared, density) do
			if p.feature == "forest" then
				local pos = p.cframe.Position
				local s = standOf(layout, pos.X, pos.Z)
				kept[s] = kept[s] or {}
				table.insert(kept[s], Vector2.new(pos.X, pos.Z))
			end
		end
		for s, forest in forests do
			local trees = kept[s] or {}
			if #trees > 0 and #trees < (total[s] or 0) then
				local sum = Vector2.zero
				for _, tree in trees do
					sum += tree
				end
				-- the circle around the kept trees' centroid, or the stand's own centre when that reaches them with
				-- less ground (radial thinning keeps the centroid near the centre; a small sample can wander)
				local best = nil
				for _, centre in { sum / #trees, forest.center } do
					local far = 0
					for _, tree in trees do
						far = math.max(far, (tree - centre).Magnitude)
					end
					local r = math.max(8, far + forest.radius * 0.05)
					if not best or r < best.r then
						best = { x = centre.X, z = centre.Y, r = r }
					end
				end
				if best.r < floors[s].r then
					floors[s] = best
				end
			end
		end
	end
	byKey[key] = floors
	return floors
end

return WorldPlan
