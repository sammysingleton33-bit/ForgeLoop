--!strict
--[[
	Kit/WorldPlan — pure, deterministic plan of the AI Kingdoms valley from world/Layout (FL-0055).
	WorldService executes it (terrain through an adapter, props through Kit.prop) and the world
	preview (blender/scripts/render_world.py) renders the same plan, so previews match the game.

	API
		WorldPlan.terrainOps(layout) -> { Op }          -- in execution order
		WorldPlan.props(layout, dressed: { [string]: boolean }?) -> { Placement }
		WorldPlan.groundHeight(layout, x, z) -> number  -- analytic surface height (studs)
		WorldPlan.voxels(op) -> number                   -- 4-stud voxels an op touches (frame budget)
	Op = { kind: "Block" | "Ball" | "Cylinder", material: string, cframe: CFrame, size: Vector3?,
	       radius: number?, height: number?, feature: string }
	Placement = { assetId: string, cframe: CFrame, feature: string }

	Determinism: a Park–Miller PRNG (exact in doubles), never Random, so Lune specs, the preview and
	Roblox produce identical worlds.
]]

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

function WorldPlan.terrainOps(layout: any): { Op }
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
	for _, forest in f.forests do
		local fy = WorldPlan.groundHeight(layout, forest.center.X, forest.center.Y)
		cylinder("LeafyGrass", forest.center.X, fy - 1, forest.center.Y, forest.radius * 1.05, 2.5, "forest_floor")
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

function WorldPlan.props(layout: any, dressed: { [string]: boolean }?): { Placement }
	local f = layout.features
	local out: { Placement } = {}
	local occupied: { { x: number, z: number, r: number } } = {}
	local rng = prng(4242)

	-- keep-out discs: plot cores (buildings), build zones, build slots, objective, resource nodes, bridges
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

	local function clear(x: number, z: number, r: number): boolean
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

return WorldPlan
