--!strict
--[[
	Kit/WorldPlan — pure, deterministic plan of the AI Kingdoms valley from world/Layout (FL-0055).
	WorldService executes it (terrain through an adapter, props through Kit.prop) and the world
	preview (blender/scripts/render_world.py) renders the same plan, so previews match the game.

	API
		WorldPlan.terrainOps(layout, density?) -> { Op } -- in execution order (forest floors follow the trim)
		WorldPlan.forestFloors(layout, density?) -> { { x, z, r } } -- each forest stand's leafy floor circle, fitted to its trees
		WorldPlan.props(layout, dressed: { [string]: boolean }?, density: { forest: number?, props: number? }?)
			-> { Placement }                           -- trim(clear(plan(...)), density)
		WorldPlan.plan(layout, dressed?) -> { Placement }  -- the generated dressing, before clearance: the nature is grown in clumps
		                                                   -- (generateNature, below), already legal under clear()
		WorldPlan.clear(layout, plan) -> { Placement }     -- drops dressing on the plots' reserved ground (CLEAR)
		WorldPlan.reservedRects(layout), WorldPlan.rectDistance(rect, x, z), WorldPlan.footprintRadius(assetId)
		WorldPlan.yard(layout, kingdom) -> { Placement }   -- the composed start yard of a dressed kingdom (market cross, stalls, hedges, trade); plan() adds it
		WorldPlan.yardRows(colour) -> { { id, x, z, yaw, role } } -- the same in the keep's frame (colour: red blue green yellow); WorldPlan.YARD: its anchors
		WorldPlan.trim(layout, plan, density?) -> { Placement }   -- the density pass props() ends with
		WorldPlan.density(layout, override?) -> { forest, props } -- effective knob values, clamped to 0..1
		WorldPlan.unseen(layout, x, z) -> number                  -- trim score (studs; 0 = never trimmed)
		WorldPlan.showcase(layout, x, z) -> boolean               -- the plot showcase: never thinned
		WorldPlan.viewWeight(layout, x, z) -> number      -- how much a ground point matters to the ruler camera: 3 start view, 1.6 zoomed out, 0.35
		WorldPlan.tintColor(color, tint), WorldPlan.tintModel(model, tint) -- the foliage colour shift a placement carries
		WorldPlan.groundHeight(layout, x, z) -> number  -- analytic surface height (studs)
		WorldPlan.voxels(op) -> number                   -- 4-stud voxels an op touches (frame budget)
	Op = { kind: "Block" | "Ball" | "Cylinder", material: string, cframe: CFrame, size: Vector3?,
	       radius: number?, height: number?, feature: string }
	Placement = { assetId: string, cframe: CFrame, feature: string, scale: number?, tint: number? }
		scale: size against the asset's own (nil = 1; WorldService scales the built prop about its pivot, the clearance and the trim reckon with
		it); tint: foliage colour shift -1..1 in steps of 0.5 (nil = 0).
	Dressing density (D-047, FL-0116): the knob is world/Layout `features.density` ({ forest, props }, the share
	of each kind kept; WorldPlan.FULL_DENSITY = 1 / 1 rebuilds the valley exactly as plan() + clear() make it).
	trim() removes, per kind, the least-seen share: farthest from the plot frames, approach roads and heartland
	(WorldPlan.TRIM) first. Never thinned: the plot showcase (within TRIM.showcase studs of a plot's fields,
	buildings and slots, and the farm's view behind the keep; WorldPlan.showcase); plot frames, road bands and the
	heartland for lone trees, bushes, rocks and flowers; bridges, crops and kingdom dressing always. Forests are
	thinned stand by stand, radially (the outermost trees first, all around), and only the stands that neither
	reach the showcase nor sit in view; each thinned stand's ground disc follows it (forestFloors).
	Plot clearance (user playtest 2026-10-13): no tree, bush, rock or flower within CLEAR.margin (4) studs of a
	farm field, a starting building's largest Kit footprint, a build slot, a plot build zone, a road or a village lane
	(`features.paths`: ground only, not a no-build road; the same rule as a road), measured
	with each prop's footprint and canopy radius (CLEAR.radius). Blocked trees, bushes and flowers move to the
	nearest legal spot within CLEAR.natureNudge studs instead of going; boulders against a trunk or bush go.
	Hand-placed kingdom dressing that sits inside a building, slot or field moves too (CLEAR.nudge,
	CLEAR.wallGap off walls); the gate banners are exempt and stay exactly where the plan puts them. The start yard (feature "yard", WorldPlan.yard) is not touched: it is held to stricter rules by YardCompose.spec.

	Crown Arena (FL-0072, G12.6): layout.arena = { cframe, duelRadius, spawnA, spawnB, footprint } is reserved ground like a
	plot: the generator keeps decor off its footprint (WorldPlan.arenaRect), the clearance moves or removes natural dressing within
	CLEAR.margin of it (canopies included), and the trim never thins within TRIM.arenaReach studs of it (like an objective).

	Determinism: a Park–Miller PRNG (exact in doubles), never Random, so Lune specs, the preview and
	Roblox produce identical worlds.
]]

local Buildings = require("./Buildings") -- Kit.footprint (Kit itself requires Props, which requires this module)
local WorldGround = require("./WorldGround") -- the ground cover, aprons, lanes and plazas of terrainOps (pure; takes our helpers as `api`)

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
export type Placement = {
	assetId: string,
	cframe: CFrame,
	feature: string,
	scale: number?, -- size against the asset's own (nil = 1): WorldService scales the built prop, the clearance and the trim reckon with it
	tint: number?, -- foliage colour shift -1 (shaded, cool) .. 1 (sunlit, warm) (nil = 0): WorldPlan.tintModel
}

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

-- distToPolyline(...) < limit, with a cached bounding box of the line to turn most far-off points away without walking its segments
-- (the clearance asks this of every road and lane for every candidate the generator tries)
local boxCache: { [any]: { number } } = setmetatable({}, { __mode = "k" }) :: any
local function polyWithin(pts: { Vector2 }, x: number, z: number, limit: number): boolean
	local box = boxCache[pts]
	if not box then
		box = { math.huge, -math.huge, math.huge, -math.huge }
		for _, p in pts do
			box[1], box[2] = math.min(box[1], p.X), math.max(box[2], p.X)
			box[3], box[4] = math.min(box[3], p.Y), math.max(box[4], p.Y)
		end
		boxCache[pts] = box
	end
	if x < box[1] - limit or x > box[2] + limit or z < box[3] - limit or z > box[4] + limit then
		return false
	end
	return distToPolyline(x, z, pts) < limit
end

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

	-- 4. ground cover: noise-driven patches over the open land (leafy meadow, bare and wet earth, ragged forest-floor rims), then
	-- worn pads under the fields, the starting buildings and the work yards (Kit/WorldGround)
	local api = {
		groundHeight = WorldPlan.groundHeight,
		distToPolyline = distToPolyline,
		prng = prng,
		hillBalls = hillBalls,
	}
	for _, op in WorldGround.cover(layout, api, floors) do
		table.insert(ops, op)
	end
	for _, op in WorldGround.aprons(layout, api) do
		table.insert(ops, op)
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

	-- 6. roads and the plots' lanes (dirt, ragged edges, a worn centre on the roads), the hub plaza and each keep's court
	for _, op in WorldGround.worn(layout, api) do
		table.insert(ops, op)
	end
	for _, op in WorldGround.border(layout, api) do
		table.insert(ops, op)
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
			if polyWithin(road.points, x, z, road.width / 2 + 3 + r) then
				return false
			end
		end
		for _, lane in f.paths or {} do
			if polyWithin(lane.points, x, z, lane.width / 2 + 3 + r) then
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
		prop_cross = 5.7, -- the start yard (WorldPlan.YARD): live bounds + 0.1 (YardCompose.spec measures them)
		prop_stall = 5.3,
		prop_hedge_01 = 6.0, -- 12 long
		prop_hedge_02 = 4.1, -- 6.5 long
	}),
	fallbackRadius = 15, -- an asset family missing from `radius`
	nudge = 14, -- hand-placed dressing on reserved ground moves to the nearest legal spot within this many studs (8 until the village lanes: the crimson cart sits on one)
	wallGap = 1.5, -- ... and keeps this much open ground between its outline and a building or slot wall
	natureNudge = 12, -- blocked trees, bushes and flowers move to the nearest legal spot within this many studs
	trunk = 3, -- a boulder keeps its outline this far from a tree trunk (the plan spaces props by scatter radii)
	bushGap = 2, -- ... and from a bush's centre
})
local NATURAL = { forest = true, lone_tree = true, bush = true, rocks = true, flowers = true }
-- the plan's own spacing radii per feature (WorldPlan.plan's scatter calls): two placements keep their sum apart
local SCATTER: { [string]: number } = { forest = 5, lone_tree = 5.5, bush = 2.5, rocks = 4, flowers = 2 }

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
			-- a rectangle lies within hypot(half) of its centre: farther than that plus r + m it cannot block (skips the CFrame maths)
			local centre = rect.cf.Position
			local reach = r + m + math.sqrt(rect.half.X * rect.half.X + rect.half.Y * rect.half.Y)
			local dx, dz = x - centre.X, z - centre.Z
			if dx * dx + dz * dz < reach * reach and WorldPlan.rectDistance(rect, x, z) < r + m then
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
		if polyWithin(road.points, x, z, road.width / 2 + r + m) then
			return true
		end
	end
	-- the plots' village lanes (features.paths: ground only, not no-build roads): the same rule as a road
	for _, lane in layout.features.paths or {} do
		if polyWithin(lane.points, x, z, lane.width / 2 + r + m) then
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
			local r = WorldPlan.footprintRadius(p.assetId) * (p.scale or 1)
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
	return { assetId = p.assetId, cframe = cf, feature = p.feature, scale = p.scale, tint = p.tint }
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
	local scatter, r, pos = SCATTER[p.feature], WorldPlan.footprintRadius(p.assetId) * (p.scale or 1), p.cframe.Position
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
			local r = WorldPlan.footprintRadius(p.assetId) * (p.scale or 1)
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

-- ---------------------------------------------------------------- the nature generator (visual pass 1)

-- Where the ruler camera looks (RulerCameraController overview). The ruler starts seated on the keep's throne; the focus is the yard
-- `ahead` studs in front of the throne and the camera stands `zoom` studs from it at the pitch for that zoom (38 degrees at zoom 40
-- rising to 65 at zoom 220), 16:9. The START view (FL-0147) looks back across the yard toward the keep (`back`: the throne's facing
-- turned 180 degrees): the lane network, the fields' sides and the work areas, and the land beyond them out to the horizon edge. The
-- fully zoomed-out view looks along the throne's facing and sees the stands and tree lines as the composition. A WEIGHT for where
-- nature clumps, never a rule. (blender/scripts/render_world.py and tests/world/support/StartView.luau hold the same maths.)
-- These numbers are COPIES of the controller's (RulerCameraController.DEFAULTS.overview: default = startZoom, fieldOfView, startAhead and
-- startTurn == 180 as `back`; far.zoom = maxZoom; pitch = Def.pitchFor's ramp: minZoom/maxZoom/minPitchDeg/maxPitchDeg); NatureClumps.spec
-- compares them field by field, so a change to the start view fails there until they follow it. far.ahead and far.back, aspect, near, reach
-- and throne have no counterpart in the controller.
WorldPlan.VIEW = table.freeze({
	default = table.freeze({ zoom = 70, fov = 55, ahead = 20, back = true }),
	far = table.freeze({ zoom = 220, fov = 55, ahead = 40, back = false }),
	pitch = table.freeze({ minZoom = 40, maxZoom = 220, minDeg = 38, maxDeg = 65 }), -- degrees below the horizon, linear in the zoom
	aspect = 16 / 9,
	near = 30, -- studs round the start view's ground that still count as in it
	reach = 900, -- rays that never reach the ground stop here
	throne = Vector3.new(0, 7.7, -11.8), -- the seated ruler's root in the keep's frame (the Kit's throne seat, a little above it)
})

type Poly = { Vector2 }
local viewCache: { [any]: { default: { Poly }, far: { Poly } } } = setmetatable({}, { __mode = "k" }) :: any

-- The ground a ruler camera at a keep's throne sees at screen position (sx, sy) in -1..1 (x right, y up): the ray's hit on the ground, or
-- its end where it never reaches it (the horizon).
local function groundPoint(
	keep: CFrame,
	view: { zoom: number, fov: number, ahead: number, back: boolean },
	sx: number,
	sy: number
): Vector2
	local V = WorldPlan.VIEW
	local look = keep.LookVector
	local facing = Vector3.new(look.X, 0, look.Z).Unit
	local focus = keep:PointToWorldSpace(V.throne) + facing * view.ahead
	local flat = if view.back then -facing else facing -- the way the camera looks, on the ground
	local ramp = V.pitch
	local pitch =
		math.rad(ramp.minDeg + (ramp.maxDeg - ramp.minDeg) * (view.zoom - ramp.minZoom) / (ramp.maxZoom - ramp.minZoom))
	local sp, cp = math.sin(pitch), math.cos(pitch)
	local pos = focus - flat * (view.zoom * cp) + Vector3.new(0, view.zoom * sp, 0)
	local forward = flat * cp + Vector3.new(0, -sp, 0)
	local right = flat:Cross(Vector3.yAxis)
	local up = right:Cross(forward)
	local ty = math.tan(math.rad(view.fov) / 2)
	local dir = forward + right * (sx * ty * V.aspect) + up * (sy * ty)
	local t = if dir.Y < -1e-3 then math.min(-pos.Y / dir.Y, V.reach) else V.reach
	local hit = pos + dir * t
	return Vector2.new(hit.X, hit.Z)
end

-- The ground a ruler camera sees (4 corners: top-left, top-right, bottom-right, bottom-left as the player sees them; the first two are
-- the far edge).
local function groundPolygon(keep: CFrame, view: { zoom: number, fov: number, ahead: number, back: boolean }): Poly
	return {
		groundPoint(keep, view, -1, 1),
		groundPoint(keep, view, 1, 1),
		groundPoint(keep, view, 1, -1),
		groundPoint(keep, view, -1, -1),
	}
end

local function inPoly(poly: Poly, x: number, z: number): boolean
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a.Y > z) ~= (b.Y > z) and x < (b.X - a.X) * (z - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		j = i
	end
	return inside
end

local function polyDistance(poly: Poly, x: number, z: number): number
	if inPoly(poly, x, z) then
		return 0
	end
	local closed = table.clone(poly)
	table.insert(closed, poly[1])
	return distToPolyline(x, z, closed)
end

-- How much a ground point matters to the default cameras: 3 in (or within VIEW.near studs of) a kingdom's start view, 1.6 in its
-- zoomed-out view, 0.35 elsewhere.
function WorldPlan.viewWeight(layout: any, x: number, z: number): number
	local cached = viewCache[layout]
	if not cached then
		cached = { default = {}, far = {} }
		for _, kingdom in KINGDOM_ORDER do
			local keep = layout.plots[kingdom].anchors.keep
			table.insert(cached.default, groundPolygon(keep, WorldPlan.VIEW.default))
			table.insert(cached.far, groundPolygon(keep, WorldPlan.VIEW.far))
		end
		viewCache[layout] = cached
	end
	for _, poly in cached.default do
		if polyDistance(poly, x, z) <= WorldPlan.VIEW.near then
			return 3
		end
	end
	for _, poly in cached.far do
		if inPoly(poly, x, z) then
			return 1.6
		end
	end
	return 0.35
end

-- Spacing between what the generator places. The tree/tree gap is k x (the two footprint radii, scale included): 0.48 packs a stand
-- core so the canopies touch, 0.85 leaves a lone tree its room. The other gaps are the clearance's own rules (a rock keeps
-- CLEAR.trunk off a trunk and CLEAR.bushGap off a bush: spaceRocks) and tuck bushes and flowers in under and between canopies.
local GRID_CELL = 20
local STATIC_R = { tree = 5, bush = 2.5, rock = 2, flower = 2 } -- the scatter radius staticClearance keeps off rivers, roads, keep-outs
type Spot = { x: number, z: number, f: number, kind: string }
type Grid = { [number]: { Spot } }

local function gridKey(ix: number, iz: number): number
	return (ix + 128) * 512 + (iz + 128)
end

local function gridAdd(grid: Grid, spot: Spot)
	local key = gridKey(math.floor(spot.x / GRID_CELL), math.floor(spot.z / GRID_CELL))
	local cell = grid[key]
	if not cell then
		cell = {}
		grid[key] = cell
	end
	table.insert(cell, spot)
end

local function spotGap(kind: string, f: number, other: Spot, k: number): number
	local ok, of = other.kind, other.f
	local clear = WorldPlan.CLEAR
	if kind == "tree" then
		if ok == "tree" then
			return k * (f + of)
		elseif ok == "bush" then
			return 0.45 * f + 0.6 * of
		elseif ok == "flower" then
			return 0.4 * f + 0.5 * of
		end
		return of + clear.trunk
	elseif kind == "bush" then
		if ok == "tree" then
			return 0.45 * of + 0.6 * f
		elseif ok == "bush" then
			return 0.55 * (f + of)
		elseif ok == "flower" then
			return 0.45 * f + 0.5 * of
		end
		return of + clear.bushGap
	elseif kind == "flower" then
		if ok == "tree" then
			return 0.4 * of + 0.5 * f
		elseif ok == "bush" then
			return 0.45 * of + 0.5 * f
		elseif ok == "flower" then
			return 0.6 * (f + of)
		end
		return 0.5 * f + 0.6 * of
	end
	if ok == "tree" then
		return f + clear.trunk
	elseif ok == "bush" then
		return f + clear.bushGap
	elseif ok == "flower" then
		return 0.5 * of + 0.6 * f
	end
	return 0.62 * (f + of)
end

local function gridOk(grid: Grid, kind: string, f: number, x: number, z: number, k: number): boolean
	local ix, iz = math.floor(x / GRID_CELL), math.floor(z / GRID_CELL)
	for jx = ix - 2, ix + 2 do
		for jz = iz - 2, iz + 2 do
			local cell = grid[gridKey(jx, jz)]
			if cell then
				for _, o in cell do
					local need = spotGap(kind, f, o, k)
					if (o.x - x) ^ 2 + (o.z - z) ^ 2 < need * need then
						return false
					end
				end
			end
		end
	end
	return true
end

-- A bell-ish random number (std 1) from four uniforms: only + and *, so every platform draws the same world.
local function gauss(rng: any): number
	return (rng.next() + rng.next() + rng.next() + rng.next() - 2) * 1.7320508
end

local function pickWeighted(rng: any, list: { { any } }): any
	local total = 0
	for _, e in list do
		total += e[2]
	end
	local r = rng.next() * total
	for _, e in list do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return list[#list][1]
end

-- Nature that plan() hands out is bounded by these: see the header of this section.
WorldPlan.NATURE = table.freeze({
	scale = table.freeze({ lo = 0.86, hi = 1.24 }), -- trees and bushes: a placement's size against the asset's own
	rockScale = table.freeze({
		s = table.freeze({ 1.0, 1.4 }),
		m = table.freeze({ 0.9, 1.25 }),
		l = table.freeze({ 0.82, 1.12 }),
	}),
	fringeSeeds = 3, -- groves and hedges on the fringe of each plot
	openGroves = 4,
	frameHoles = 6, -- plantings per kingdom that fill the emptiest ground of its start view
	holeGap = 40, -- studs from any other nature that make a spot a hole -- loose groves across the open land
	fieldHedge = 0.35, -- chance that an outer side of a crop field gets a hedge
	standShare = 0.7, -- of a Layout stand's `count` the generator plants (the D-047 part budget decides; dense cores read as a forest with fewer)
	tintSteps = 2, -- tint is a multiple of 1/tintSteps in -1..1 (5 steps): WorldPlan.tintColor shifts foliage by it
})

-- Foliage colour shift for a placement's tint (-1 shaded and cool .. 1 sunlit and warm): only green foliage moves (trunks, rocks,
-- blossoms and mesh parts that carry no green stay as they are), by at most about 10 % in value and 11 degrees of hue.
function WorldPlan.tintColor(c: Color3, tint: number): Color3
	if tint == 0 or not (c.G > c.R * 1.02 and c.G > c.B * 1.1) then
		return c
	end
	return Color3.new(
		math.clamp(c.R * (1 + 0.14 * tint), 0, 1),
		math.clamp(c.G * (1 + 0.06 * tint), 0, 1),
		math.clamp(c.B * (1 - 0.10 * tint), 0, 1)
	)
end

-- Recolour a built prop's foliage for its placement tint (parts only recolour; no part is added or removed).
function WorldPlan.tintModel(model: any, tint: number)
	if tint == 0 then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			d.Color = WorldPlan.tintColor(d.Color, tint)
		end
	end
end

local natureCache: { [any]: { Placement } } = setmetatable({}, { __mode = "k" }) :: any

-- The valley's trees, bushes, rocks and flowers, grown in clumps instead of scattered (the owner's P0: "trees, terrain and
-- landscaping are repetitive", "the world feels empty"). Every placement is already legal under clear(): it keeps its footprint (scale
-- included) off the plots' reserved ground and the roads, and off the river, keep-outs and the map edge as the old scatter did, so the
-- clearance moves and removes none of it. Each pass has its own PRNG stream, so tuning one never re-seats another.
--   stands      the Layout's forest stands: a dense core (canopies touching), two or three satellite clumps of one species each
--               and a few ragged singles, all inside the stand circle (the trim and the leafy floor read the stand by it);
--               "forest"
--   tree lines  runs along the river banks and the valley roads, and groves and hedges on the fringe of each plot (where the
--               start view looks), weighted by WorldPlan.viewWeight; "lone_tree"
--   rocks       groups of 2-5 of different sizes at stand borders, hill feet, river banks, road bends and plot fringes; "rocks"
--   bushes      clumps at stand fringes, field corners and road verges, and under groves; "bush"
--   flowers     drifts at field corners, road verges and stand fringes; "flowers"
local function generateNature(layout: any): { Placement }
	local cached = natureCache[layout]
	if cached then
		return cached
	end
	local f = layout.features
	local out: { Placement } = {}
	local grid: Grid = {}
	local rects = WorldPlan.reservedRects(layout)
	local staticClear = staticClearance(layout)
	local N = WorldPlan.NATURE
	local TWO_PI = 2 * math.pi

	local function legal(kind: string, fr: number, x: number, z: number, k: number): boolean
		if not gridOk(grid, kind, fr, x, z, k) then
			return false
		end
		if not staticClear(x, z, STATIC_R[kind]) then
			return false
		end
		return not blocked(layout, rects, true, fr, x, z)
	end

	-- place one asset if the spot is legal; returns its footprint radius (scale included) or nil
	local function try(
		rng: any,
		id: string,
		kind: string,
		x: number,
		z: number,
		feature: string,
		k: number,
		lo: number,
		hi: number,
		tinted: boolean
	): number?
		local scale = lo + (hi - lo) * rng.next()
		local fr = WorldPlan.footprintRadius(id) * scale
		if not legal(kind, fr, x, z, k) then
			return nil
		end
		gridAdd(grid, { x = x, z = z, f = fr, kind = kind })
		local cf = CFrame.new(x, WorldPlan.groundHeight(layout, x, z), z) * CFrame.Angles(0, rng.range(0, TWO_PI), 0)
		local tint = if tinted then rng.int(-N.tintSteps, N.tintSteps) / N.tintSteps else nil
		table.insert(
			out,
			{ assetId = id, cframe = cf, feature = feature, scale = math.floor(scale * 1000 + 0.5) / 1000, tint = tint }
		)
		return fr
	end

	local function treeId(rng: any, species: string): string
		return assetId(species, rng.int(1, SPECIES_VARIANTS[species] or 6))
	end
	local function bushId(rng: any): string
		return assetId("bush", rng.int(1, 8))
	end
	local function flowerId(rng: any): string
		return assetId("plant_flowers", rng.int(1, 6))
	end
	local function rockId(rng: any, class: string): string
		return string.format("rock_boulder_%s_%02d", class, rng.int(1, 3))
	end

	local function tryTree(rng: any, species: string, x: number, z: number, feature: string, k: number): boolean
		return try(rng, treeId(rng, species), "tree", x, z, feature, k, N.scale.lo, N.scale.hi, true) ~= nil
	end
	local function tryBush(rng: any, x: number, z: number): boolean
		return try(rng, bushId(rng), "bush", x, z, "bush", 0, 0.85, 1.2, true) ~= nil
	end
	local function tryFlower(rng: any, x: number, z: number): boolean
		return try(rng, flowerId(rng), "flower", x, z, "flowers", 0, 0.85, 1.3, false) ~= nil
	end

	-- a clump of `count` bushes or flowers round (cx, cz), Gaussian, as many as fit
	local function clump(rng: any, cx: number, cz: number, count: number, sigma: number, flowers: boolean): number
		local placed, tries = 0, 0
		while placed < count and tries < count * 12 do
			tries += 1
			local x, z = cx + gauss(rng) * sigma, cz + gauss(rng) * sigma
			local ok = if flowers then tryFlower(rng, x, z) else tryBush(rng, x, z)
			if ok then
				placed += 1
			end
		end
		return placed
	end

	-- a rock group at (x, z): the biggest rock first, the others touching it, each smaller; `dx, dz` is the way the edge runs
	local function rockGroup(rng: any, x: number, z: number, count: number, dx: number, dz: number): number
		local first = pickWeighted(rng, { { "l", 0.3 }, { "m", 0.45 }, { "s", 0.25 } })
		local placed, anchorF = 0, 0
		for i = 1, count do
			local class = if i == 1
				then first
				elseif first == "l" then pickWeighted(rng, { { "m", 0.5 }, { "s", 0.5 } })
				else "s"
			local range = N.rockScale[class]
			local id = rockId(rng, class)
			for attempt = 1, 8 do
				local px, pz = x, z
				if i == 1 and attempt > 1 then
					px, pz = x + rng.range(-5, 5), z + rng.range(-5, 5)
				elseif i > 1 then
					local lengthwise = rng.range(-1, 1)
					local across = rng.range(-0.6, 0.6)
					local reach = 0.62 * (anchorF + WorldPlan.footprintRadius(id) * range[1]) + rng.range(0, 5)
					px, pz = x + (dx * lengthwise - dz * across) * reach, z + (dz * lengthwise + dx * across) * reach
				end
				local fr = try(rng, id, "rock", px, pz, "rocks", 0, range[1], range[2], false)
				if fr then
					placed += 1
					if i == 1 then
						anchorF = fr
					end
					break
				end
			end
			if i == 1 and placed == 0 then
				return 0 -- no room for the anchor: no group
			end
		end
		return placed
	end

	-- polyline helpers for runs along the river and the roads
	local function measure(pts: { Vector2 }): ({ number }, number)
		local cum, total = { 0 }, 0
		for i = 1, #pts - 1 do
			total += (pts[i + 1] - pts[i]).Magnitude
			cum[i + 1] = total
		end
		return cum, total
	end
	local function pointAt(pts: { Vector2 }, cum: { number }, d: number): (number, number, number, number)
		for i = 1, #pts - 1 do
			if d <= cum[i + 1] or i == #pts - 1 then
				local seg = pts[i + 1] - pts[i]
				local u = math.clamp((d - cum[i]) / math.max(seg.Magnitude, 1e-6), 0, 1)
				local p = pts[i] + seg * u
				local t = seg.Unit
				return p.X, p.Y, t.X, t.Y
			end
		end
		return pts[1].X, pts[1].Y, 1, 0
	end

	local keeps: { Vector3 } = {}
	for _, kingdom in KINGDOM_ORDER do
		table.insert(keeps, layout.plots[kingdom].anchors.keep.Position)
	end
	local function nearestKeep(x: number, z: number): Vector3
		local best, bestD = keeps[1], math.huge
		for _, k in keeps do
			local d = (k.X - x) ^ 2 + (k.Z - z) ^ 2
			if d < bestD then
				best, bestD = k, d
			end
		end
		return best
	end

	-- ---- 1. forest stands
	local standTrees: { { { x: number, z: number, f: number } } } = {}
	for s, forest in f.forests do
		local rng = prng(5100 + s)
		local R, n = forest.radius, math.floor(forest.count * N.standShare + 0.5)
		local c = forest.center
		local list = {}
		standTrees[s] = list
		local core = c -- (a core leaned toward the nearest keep thinned fewer stands in the trim: the density specs pin that)
		local species: { string } = forest.species
		-- the stand's mix: one species leads (it rotates through the Layout's list), a single-species stand gets a birch accent
		local lead = species[1 + ((s + rng.int(0, 1)) % #species)]
		local mix: { { any } }
		if #species == 1 then
			mix = { { lead, 0.88 }, { "tree_birch", 0.12 } }
		else
			mix = {}
			for _, sp in species do
				table.insert(mix, { sp, if sp == lead then 0.7 else 0.3 / (#species - 1) })
			end
		end
		local function grow(
			cx: number,
			cz: number,
			sigma: number,
			count: number,
			k2: number,
			weights: { { any } },
			maxR: number
		)
			local placed, tries = 0, 0
			while placed < count and tries < count * 30 do
				tries += 1
				local x, z = cx + gauss(rng) * sigma, cz + gauss(rng) * sigma
				if (x - c.X) ^ 2 + (z - c.Y) ^ 2 <= maxR * maxR then
					local sp = pickWeighted(rng, weights)
					local id = treeId(rng, sp)
					local fr = try(rng, id, "tree", x, z, "forest", k2, N.scale.lo, N.scale.hi, true)
					if fr then
						placed += 1
						table.insert(list, { x = x, z = z, f = fr })
					end
				end
			end
		end
		local nFringe = math.max(1, math.floor(n * 0.1 + 0.5))
		local nCore = math.floor(n * 0.56 + 0.5)
		local satellites = if n >= 22 then 3 else 2
		grow(core.X, core.Y, 0.2 * R, nCore, 0.48, mix, 0.93 * R)
		local rest = n - nCore - nFringe
		local a0 = rng.range(0, TWO_PI)
		for i = 1, satellites do
			local a = a0 + (i - 1) * TWO_PI / satellites + rng.range(-0.4, 0.4)
			local d = math.min(rng.range(0.42, 0.62) * R, 0.78 * R - (core - c).Magnitude)
			local sx, sz = core.X + math.cos(a) * d, core.Y + math.sin(a) * d
			local dominant = species[rng.int(1, #species)]
			local satMix = {
				{ dominant, 0.85 },
				{ if #species == 1 then "tree_birch" else species[1 + rng.int(0, #species - 1)], 0.15 },
			}
			local each = math.floor(rest / satellites)
			local share = if i < satellites then each else rest - each * (satellites - 1)
			grow(sx, sz, rng.range(0.085, 0.12) * R, share, 0.52, satMix, 0.93 * R)
		end
		for _ = 1, nFringe do
			local a, d = rng.range(0, TWO_PI), rng.range(0.45, 0.9) * R
			grow(c.X + math.cos(a) * d, c.Y + math.sin(a) * d, 2, 1, 0.85, mix, 0.95 * R)
		end
	end

	-- the viewed-first order of candidate sites: sort descending by weight x a random draw
	local function ranked(rng: any, sites: { any }): { any }
		for _, s in sites do
			s.w *= 0.5 + rng.next()
		end
		table.sort(sites, function(a, b)
			if a.w ~= b.w then
				return a.w > b.w
			end
			return a.x < b.x
		end)
		return sites
	end

	-- ---- 2. tree lines along both banks of the river
	do
		local rng = prng(5200)
		local pts = f.river.points
		local cum, total = measure(pts)
		for _, side in { 1, -1 } do
			local sites = {}
			for _ = 1, 40 do
				local d = rng.range(20, total - 120)
				local mx, mz, tx, tz = pointAt(pts, cum, d + 55)
				local off = (f.river.width / 2 + 38) * side
				table.insert(sites, { x = d, z = 0, w = WorldPlan.viewWeight(layout, mx - tz * off, mz + tx * off) })
			end
			local taken: { number } = {}
			for _, site in ranked(rng, sites) do
				if #taken >= 2 then
					break
				end
				local near = false
				for _, t in taken do
					if math.abs(t - site.x) < 170 then
						near = true
					end
				end
				if not near then
					table.insert(taken, site.x)
					local len = rng.range(55, 95)
					local s = 0
					local birchy = rng.next() < 0.5
					while s < len do
						local px, pz, tx, tz = pointAt(pts, cum, site.x + s)
						local off = (f.river.width / 2 + 10 + 6 + rng.range(0, 9)) * side
						local x, z = px - tz * off, pz + tx * off
						if rng.next() > 0.18 then
							local sp = pickWeighted(
								rng,
								if birchy
									then { { "tree_birch", 0.6 }, { "tree_oak", 0.4 } }
									else { { "tree_oak", 0.6 }, { "tree_birch", 0.4 } }
							)
							tryTree(rng, sp, x, z, "lone_tree", 0.62)
						end
						if rng.next() < 0.45 then
							local bo = off - side * rng.range(5, 9)
							tryBush(rng, px - tz * bo + tx * 7, pz + tx * bo + tz * 7)
						end
						s += rng.range(14, 20)
					end
				end
			end
		end
	end

	-- ---- 3. hedgerows along the valley roads (the approach roads, not the plot streets or the outpost spurs)
	do
		local rng = prng(5300)
		local runs = 0
		local sites = {}
		for ri, road in f.roads do
			if not road.spur and road.width >= 12 then
				local cum, total = measure(road.points)
				for _ = 1, 14 do
					local d = rng.range(10, math.max(11, total - 100))
					local mx, mz = pointAt(road.points, cum, d + 45)
					table.insert(sites, { x = d, z = ri, w = WorldPlan.viewWeight(layout, mx, mz) })
				end
			end
		end
		local taken: { { number } } = {}
		for _, site in ranked(rng, sites) do
			if runs >= 6 then
				break
			end
			local road = f.roads[site.z]
			local near = false
			for _, t in taken do
				if t[1] == site.z and math.abs(t[2] - site.x) < 150 then
					near = true
				end
			end
			if not near then
				table.insert(taken, { site.z, site.x })
				runs += 1
				local cum = measure(road.points)
				local side = if rng.next() < 0.5 then 1 else -1
				local len = rng.range(50, 90)
				local s = 0
				while s < len do
					local px, pz, tx, tz = pointAt(road.points, cum, site.x + s)
					local sp = pickWeighted(rng, { { "tree_oak", 0.4 }, { "tree_birch", 0.55 }, { "tree_pine", 0.05 } })
					local off = (road.width / 2 + 4 + WorldPlan.footprintRadius(sp) * 1.0 + rng.range(0.5, 5)) * side
					if rng.next() > 0.15 then
						tryTree(rng, sp, px - tz * off, pz + tx * off, "lone_tree", 0.62)
					end
					if rng.next() < 0.4 then
						local bo = (road.width / 2 + 4 + 5.2 + rng.range(0, 3)) * side
						tryBush(rng, px - tz * bo + tx * 8, pz + tx * bo + tz * 8)
					end
					s += rng.range(17, 25)
				end
			end
		end
	end

	-- a grove: one species leads, n trees, a few bushes round its foot
	local function grove(rng: any, x0: number, z0: number, n: number)
		local lead = pickWeighted(rng, { { "tree_oak", 0.5 }, { "tree_birch", 0.45 }, { "tree_pine", 0.05 } })
		local mix = { { lead, 0.85 }, { "tree_birch", 0.15 } }
		local sigma = 6 + n
		local placed, tries = 0, 0
		while placed < n and tries < n * 25 do
			tries += 1
			local x, z = x0 + gauss(rng) * sigma, z0 + gauss(rng) * sigma
			if tryTree(rng, pickWeighted(rng, mix), x, z, "lone_tree", 0.55) then
				placed += 1
			end
		end
		if rng.next() < 0.45 then
			clump(rng, x0, z0, rng.int(1, 3), sigma * 1.4, false)
		end
	end

	-- ---- 4. groves and hedges on the fringe of each plot (just outside its reserved ground: the start view's frame)
	local fringeSeeds: { { x: number, z: number } } = {}
	do
		local rng = prng(5400)
		for ki, kingdom in KINGDOM_ORDER do
			local keep = keeps[ki]
			local sites = {}
			-- the start view's far edge: trees just beyond it show their crowns along the top of the frame (a backdrop), so sites in
			-- that band count 1.7 times as much
			local frame = groundPolygon(layout.plots[kingdom].anchors.keep, WorldPlan.VIEW.default)
			local farMid, nearMid = (frame[1] + frame[2]) / 2, (frame[3] + frame[4]) / 2
			local outward = (farMid - nearMid).Unit -- the way the camera looks, on the ground
			local across = Vector2.new(-outward.Y, outward.X)
			for _ = 1, 160 do
				local a, d = rng.range(0, TWO_PI), rng.range(60, 290)
				local x, z = keep.X + math.cos(a) * d, keep.Z + math.sin(a) * d
				local reserved = math.huge
				for _, rect in rects do
					reserved = math.min(reserved, WorldPlan.rectDistance(rect, x, z))
				end
				if reserved <= 52 and legal("tree", 8, x, z, 0.62) then
					local beyond = (Vector2.new(x, z) - farMid):Dot(outward)
					local backdrop = beyond >= -40
						and beyond <= 110
						and math.abs((Vector2.new(x, z) - farMid):Dot(across)) <= 180
					table.insert(sites, {
						x = x,
						z = z,
						w = WorldPlan.viewWeight(layout, x, z)
							* (1 + (30 - math.min(reserved, 30)) / 30)
							* (if backdrop then 1.7 else 1),
					})
				end
			end
			local taken = 0
			for _, site in ranked(rng, sites) do
				if taken >= N.fringeSeeds then
					break
				end
				local near = false
				for _, o in fringeSeeds do
					if (o.x - site.x) ^ 2 + (o.z - site.z) ^ 2 < 48 * 48 then
						near = true
					end
				end
				if not near then
					taken += 1
					table.insert(fringeSeeds, { x = site.x, z = site.z })
					if rng.next() < 0.75 then
						grove(rng, site.x, site.z, rng.int(3, 6))
					else
						-- a hedge: a line of bushes with a small tree here and there
						local a = rng.range(0, math.pi)
						local dx, dz = math.cos(a), math.sin(a)
						local len, s = rng.range(28, 50), 0
						while s < len do
							local x, z = site.x + dx * (s - len / 2), site.z + dz * (s - len / 2)
							local roll = rng.next()
							if roll < 0.25 then
								tryTree(rng, "tree_birch", x, z, "lone_tree", 0.62)
							elseif roll < 0.8 then
								tryBush(rng, x, z)
							else
								tryFlower(rng, x, z)
							end
							s += rng.range(7, 10)
						end
					end
				end
			end
		end
	end

	-- ---- 4b. loose groves in the open land between the kingdoms (the valley, the heartland), nearer the roads and the river
	do
		local rng = prng(5450)
		local sites = {}
		local b = f.bounds
		for _ = 1, 220 do
			local x, z = rng.range(b.min.X + 40, b.max.X - 40), rng.range(b.min.Y + 40, b.max.Y - 40)
			local inStand = false
			for _, forest in f.forests do
				if (x - forest.center.X) ^ 2 + (z - forest.center.Y) ^ 2 < (forest.radius + 25) ^ 2 then
					inStand = true
				end
			end
			if not inStand and legal("tree", 8, x, z, 0.62) then
				local edge = math.min(distToPolyline(x, z, f.river.points) - f.river.width / 2, 200)
				for _, road in f.roads do
					edge = math.min(edge, distToPolyline(x, z, road.points) - road.width / 2)
				end
				table.insert(sites, {
					x = x,
					z = z,
					w = (WorldPlan.viewWeight(layout, x, z) + 0.4) * (if edge < 70 then 1.5 else 1),
				})
			end
		end
		local taken = 0
		for _, site in ranked(rng, sites) do
			if taken >= N.openGroves then
				break
			end
			local near = false
			for _, o in fringeSeeds do
				if (o.x - site.x) ^ 2 + (o.z - site.z) ^ 2 < 80 * 80 then
					near = true
				end
			end
			if not near then
				taken += 1
				table.insert(fringeSeeds, { x = site.x, z = site.z })
				grove(rng, site.x, site.z, rng.int(3, 5))
				if rng.next() < 0.35 then
					clump(rng, site.x + rng.range(-12, 12), site.z + rng.range(-12, 12), rng.int(3, 4), 3, true)
				end
			end
		end
	end

	-- ---- 4c. fill the holes of each kingdom's start view: the screen is cut into 3 x 3 cells (the bottom tenth left out), and in each
	-- cell the legal spot farthest from any other nature is a candidate (the ground round a plot's yard is mostly reserved, so a spot
	-- may take only a flower tuft or a bush). The emptiest few get what fits: a grove, a hedge with a flower drift or a rock group with
	-- bushes where there is room, a bush clump or a flower drift where there is little. Coverage, not chance.
	do
		local rng = prng(5470)
		local function room(x: number, z: number): number -- 2: a tree fits, 1: a bush, 0: a flower tuft
			if legal("tree", 8, x, z, 0.62) then
				return 2
			end
			return if legal("bush", 5.2, x, z, 0) then 1 else 0
		end
		local function nearReserved(x: number, z: number, d: number): boolean
			for _, rect in rects do
				if WorldPlan.rectDistance(rect, x, z) <= d then
					return true
				end
			end
			return false
		end
		for _, kingdom in KINGDOM_ORDER do
			local keepCF = layout.plots[kingdom].anchors.keep
			local function at(u: number, v: number): Vector2 -- u across the screen, v up it (0..1)
				return groundPoint(keepCF, WorldPlan.VIEW.default, u * 2 - 1, v * 2 - 1)
			end
			local function gapAt(x: number, z: number): number
				local gap = math.huge
				for _, o in out do
					local q = o.cframe.Position
					gap = math.min(gap, (q.X - x) ^ 2 + (q.Z - z) ^ 2)
				end
				return math.sqrt(gap)
			end
			local holes = {}
			for band = 1, 3 do
				for col = 1, 3 do
					local best, bestGap = nil, 0
					for _ = 1, 24 do
						local p = at((col - 1 + rng.next()) / 3, 0.1 + (band - 1 + rng.next()) * 0.3)
						if legal("flower", 3.4, p.X, p.Y, 0) then
							local gap = gapAt(p.X, p.Y)
							if gap > bestGap then
								best, bestGap = p, gap
							end
						end
					end
					if best then
						table.insert(holes, { x = best.X, z = best.Y, w = bestGap })
					end
				end
			end
			table.sort(holes, function(a, b)
				if a.w ~= b.w then
					return a.w > b.w
				end
				return a.x < b.x
			end)
			local planted = 0
			for _, hole in holes do
				if planted >= N.frameHoles then
					break
				end
				if gapAt(hole.x, hole.z) > N.holeGap then -- (an earlier planting may have filled it)
					planted += 1
					local fits = room(hole.x, hole.z)
					local roll = rng.next()
					if fits == 2 and roll < 0.5 then
						grove(rng, hole.x, hole.z, rng.int(3, 5))
					elseif fits == 2 and roll < 0.75 and nearReserved(hole.x, hole.z, 45) then
						rockGroup(rng, hole.x, hole.z, rng.int(2, 4), 1, 0)
						clump(rng, hole.x + 10, hole.z + 6, rng.int(2, 3), 3, false)
					elseif fits >= 1 then
						local a = rng.range(0, math.pi)
						local dx, dz = math.cos(a), math.sin(a)
						for k = -2, 2 do
							local x, z = hole.x + dx * k * 8, hole.z + dz * k * 8
							if k % 2 == 0 then
								tryBush(rng, x, z)
							else
								tryFlower(rng, x, z)
							end
						end
						if fits == 2 then
							tryTree(rng, "tree_birch", hole.x, hole.z, "lone_tree", 0.62)
						end
					else
						clump(rng, hole.x, hole.z, rng.int(3, 4), 2.5, true)
					end
				end
			end
		end
	end

	-- ---- 5. rock groups at edges
	do
		local rng = prng(5600)
		-- stand borders: out from the stand's mass, 1 group (2 where the cameras look)
		for s, forest in f.forests do
			local list = standTrees[s]
			if #list > 0 then
				local mx, mz = 0, 0
				for _, t in list do
					mx += t.x
					mz += t.z
				end
				mx, mz = mx / #list, mz / #list
				local groups = if WorldPlan.viewWeight(layout, forest.center.X, forest.center.Y) > 1 then 2 else 1
				for _ = 1, groups do
					local a = rng.range(0, TWO_PI)
					local dx, dz = math.cos(a), math.sin(a)
					local best, bestP = nil, -math.huge
					for _, t in list do
						local p = (t.x - mx) * dx
							+ (t.z - mz) * dz
							- 0.35 * math.abs(-(t.x - mx) * dz + (t.z - mz) * dx)
						if p > bestP then
							best, bestP = t, p
						end
					end
					if best then
						local reach = best.f * 0.8 + 9
						rockGroup(rng, best.x + dx * reach, best.z + dz * reach, rng.int(2, 4), -dz, dx)
					end
				end
			end
		end
		-- hill feet: the inner hills on the side facing the nearest keep; the mountain ring now and then
		local hillIndex = 0
		for _, b in hillBalls(layout) do
			hillIndex += 1
			local cap = capRadius(b, f.groundY or 0)
			local big = cap >= 90
			if not big or (hillIndex % 3 == 0 and b.material == "Grass") then
				local k = nearestKeep(b.x, b.z)
				local dx, dz = k.X - b.x, k.Z - b.z
				local len = math.max(1, math.sqrt(dx * dx + dz * dz))
				dx, dz = dx / len, dz / len
				local a = math.atan2(dz, dx) + rng.range(-0.9, 0.9)
				local ex, ez = math.cos(a), math.sin(a)
				rockGroup(
					rng,
					b.x + ex * cap * rng.range(0.9, 1.02),
					b.z + ez * cap * rng.range(0.9, 1.02),
					rng.int(2, 5),
					-ez,
					ex
				)
			end
		end
		-- river banks
		do
			local pts = f.river.points
			local cum, total = measure(pts)
			local sites = {}
			for _ = 1, 40 do
				local d = rng.range(20, total - 20)
				local px, pz, tx, tz = pointAt(pts, cum, d)
				local side = if rng.next() < 0.5 then 1 else -1
				local off = (f.river.width / 2 + 11 + rng.range(2, 8)) * side
				table.insert(
					sites,
					{ x = px - tz * off, z = pz + tx * off, w = WorldPlan.viewWeight(layout, px, pz), tx = tx, tz = tz }
				)
			end
			local groups = 0
			for _, site in ranked(rng, sites) do
				if groups >= 6 then
					break
				end
				if rockGroup(rng, site.x, site.z, rng.int(2, 4), site.tx, site.tz) > 0 then
					groups += 1
				end
			end
		end
		-- road bends: the outside of each turn of the approach roads
		do
			local groups = 0
			for _, road in f.roads do
				if not road.spur and road.width >= 12 then
					local pts = road.points
					for i = 2, #pts - 1 do
						local d1, d2 = (pts[i] - pts[i - 1]).Unit, (pts[i + 1] - pts[i]).Unit
						if d1:Dot(d2) < 0.9 and groups < 6 and rng.next() < 0.75 then
							local out2 = (d1 - d2)
							if out2.Magnitude > 0.05 then
								out2 = out2.Unit
								local reach = road.width / 2 + 4 + 12
								if
									rockGroup(
										rng,
										pts[i].X + out2.X * reach,
										pts[i].Y + out2.Y * reach,
										rng.int(2, 4),
										d1.X,
										d1.Y
									) > 0
								then
									groups += 1
								end
							end
						end
					end
				end
			end
		end
		-- plot fringes: one group beside each grove seed of the first two seeds of each plot
		for i = 1, #fringeSeeds, 2 do
			local seed = fringeSeeds[i]
			local a = rng.range(0, TWO_PI)
			rockGroup(
				rng,
				seed.x + math.cos(a) * 14,
				seed.z + math.sin(a) * 14,
				rng.int(2, 3),
				-math.sin(a),
				math.cos(a)
			)
		end
	end

	-- ---- 6. bush clumps: stand fringes, field corners, road verges
	do
		local rng = prng(5700)
		for s in f.forests do
			local list = standTrees[s]
			if #list > 0 then
				local mx, mz = 0, 0
				for _, t in list do
					mx += t.x
					mz += t.z
				end
				mx, mz = mx / #list, mz / #list
				for _ = 1, 1 do
					local a = rng.range(0, TWO_PI)
					local dx, dz = math.cos(a), math.sin(a)
					local best, bestP = nil, -math.huge
					for _, t in list do
						local p = (t.x - mx) * dx + (t.z - mz) * dz
						if p > bestP then
							best, bestP = t, p
						end
					end
					if best then
						local reach = best.f * 0.55 + 6
						clump(rng, best.x + dx * reach, best.z + dz * reach, rng.int(2, 3), 3.5, false)
					end
				end
			end
		end
		for _, field in f.fields do
			local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
			for _, corner in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
				if rng.next() < 0.2 then
					local out3 = cf:PointToWorldSpace(
						Vector3.new(
							corner[1] * (field.size.X / 2 + 9.5 + rng.range(0, 5)),
							0,
							corner[2] * (field.size.Y / 2 + 9.5 + rng.range(0, 5))
						)
					)
					clump(rng, out3.X, out3.Z, 2, 2.8, false)
				end
			end
		end
		for _, road in f.roads do
			if not road.spur and road.width >= 12 then
				local cum, total = measure(road.points)
				for _ = 1, 2 do
					local d = rng.range(10, total - 10)
					local px, pz, tx, tz = pointAt(road.points, cum, d)
					if WorldPlan.viewWeight(layout, px, pz) > 1 then
						local side = if rng.next() < 0.5 then 1 else -1
						local off = (road.width / 2 + 4 + 5.2 + rng.range(1, 6)) * side
						clump(rng, px - tz * off, pz + tx * off, rng.int(2, 3), 3.2, false)
					end
				end
			end
		end
	end

	-- ---- 6b. field hedges: a ragged line of bushes (a birch now and then, a tuft of flowers) along the outer sides of the crop fields,
	-- the sides that face away from the keep and from a neighbouring field (the sides the field fences take), outside the margin
	do
		local rng = prng(5750)
		for _, field in f.fields do
			local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
			local keep = nearestKeep(field.center.X, field.center.Y)
			local toKeep = Vector3.new(keep.X - field.center.X, 0, keep.Z - field.center.Y).Unit
			for _, side in
				{
					{ Vector3.new(1, 0, 0), field.size.X / 2, field.size.Y },
					{ Vector3.new(-1, 0, 0), field.size.X / 2, field.size.Y },
					{ Vector3.new(0, 0, 1), field.size.Y / 2, field.size.X },
					{ Vector3.new(0, 0, -1), field.size.Y / 2, field.size.X },
				}
			do
				local normal = cf:VectorToWorldSpace(side[1])
				local mid = cf.Position + normal * (side[2] + 10)
				local beside = false
				for _, other in f.fields do
					if
						other ~= field
						and (Vector2.new(other.center.X, other.center.Y) - Vector2.new(mid.X, mid.Z)).Magnitude
							< other.size.Magnitude / 2 + 12
					then
						beside = true
					end
				end
				if normal:Dot(toKeep) <= 0.35 and not beside and rng.next() < N.fieldHedge then
					local tangent = Vector3.new(-normal.Z, 0, normal.X)
					local len = side[3] * 0.8
					local s = -len / 2
					while s <= len / 2 do
						local roll = rng.next()
						local offset = if roll < 0.72
							then 9.2 + 1.5 + rng.range(0, 2.5)
							elseif roll < 0.88 then 7.4 + 1
							else 12.5 + 1.5 + rng.range(0, 2)
						local at = cf.Position + normal * (side[2] + offset) + tangent * s
						if roll < 0.72 then
							tryBush(rng, at.X, at.Z)
						elseif roll < 0.88 then
							tryFlower(rng, at.X, at.Z)
						else
							tryTree(rng, "tree_birch", at.X, at.Z, "lone_tree", 0.62)
						end
						s += rng.range(9, 13)
					end
				end
			end
		end
	end

	-- ---- 7. flower drifts: field corners, road verges, stand fringes
	do
		local rng = prng(5800)
		for _, field in f.fields do
			local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
			if rng.next() < 0.5 then
				local cx, cz = if rng.next() < 0.5 then 1 else -1, if rng.next() < 0.5 then 1 else -1
				local at = cf:PointToWorldSpace(
					Vector3.new(
						cx * (field.size.X / 2 + 8.5 + rng.range(0, 4)),
						0,
						cz * (field.size.Y / 2 + 8.5 + rng.range(0, 4))
					)
				)
				clump(rng, at.X, at.Z, rng.int(3, 4), 3, true)
			end
		end
		for _, road in f.roads do
			if not road.spur and road.width >= 12 then
				local cum, total = measure(road.points)
				for _ = 1, 3 do
					local d = rng.range(10, total - 10)
					local px, pz, tx, tz = pointAt(road.points, cum, d)
					if WorldPlan.viewWeight(layout, px, pz) > 1 then
						local side = if rng.next() < 0.5 then 1 else -1
						local off = (road.width / 2 + 4 + 3.4 + rng.range(3, 9)) * side
						clump(rng, px - tz * off, pz + tx * off, rng.int(3, 4), 3, true)
					end
				end
			end
		end
		for s, forest in f.forests do
			local list = standTrees[s]
			if #list > 0 and WorldPlan.viewWeight(layout, forest.center.X, forest.center.Y) > 1 then
				local t = list[rng.int(1, #list)]
				local a = rng.range(0, TWO_PI)
				clump(rng, t.x + math.cos(a) * (t.f + 5), t.z + math.sin(a) * (t.f + 5), rng.int(3, 4), 3, true)
			end
		end
	end

	-- every look of every family appears at least once (the imported-mesh kit lists all of them, and the KitEnvMesh spec wants the world to
	-- place each): a variant the draws missed is taken over by the last placement of the family's most used variant. Same footprint, same
	-- spot, nothing else moves.
	do
		local families: { { prefix: string, n: number } } = {
			{ prefix = "tree_oak", n = 8 },
			{ prefix = "tree_pine", n = 6 },
			{ prefix = "tree_birch", n = 6 },
			{ prefix = "bush", n = 8 },
			{ prefix = "plant_flowers", n = 6 },
			{ prefix = "rock_boulder_s", n = 3 },
			{ prefix = "rock_boulder_m", n = 3 },
			{ prefix = "rock_boulder_l", n = 3 },
		}
		for _, fam in families do
			local byVariant: { [number]: { number } } = {}
			local total = 0
			for i, p in out do
				if string.sub(p.assetId, 1, #fam.prefix + 1) == fam.prefix .. "_" then
					local v = tonumber(string.sub(p.assetId, #fam.prefix + 2))
					if v then
						byVariant[v] = byVariant[v] or {}
						table.insert(byVariant[v], i)
						total += 1
					end
				end
			end
			if total >= fam.n then
				for v = 1, fam.n do
					if not byVariant[v] then
						local donor, donorN = 1, -1
						for w = 1, fam.n do
							local n = if byVariant[w] then #byVariant[w] else 0
							if n > donorN then
								donor, donorN = w, n
							end
						end
						local i = table.remove(byVariant[donor]) :: number -- the donor's last placement (it has at least two)
						local p = out[i]
						out[i] = {
							assetId = assetId(fam.prefix, v),
							cframe = p.cframe,
							feature = p.feature,
							scale = p.scale,
							tint = p.tint,
						}
						byVariant[v] = { i }
					end
				end
			end
		end
	end

	natureCache[layout] = out
	return out
end

-- ---------------------------------------------------------------- the start yard (visual pass 1b)

local KINGDOM_BANNER = { crimson = "red", azure = "blue", emerald = "green", gold = "yellow" }

-- The village centre the start camera looks across (FL-0147: the camera stands in the yard and looks back at the keep, so the bottom 40 %
-- of the start picture is the market square and the lanes beside it). ONE composition in the keep's frame (x right, z back; the door is
-- at z = -23, the cobbled court WorldGround.worn lays centred at z = -39, the cross street at z = -62), applied to every dressed kingdom.
-- The nav graph (Layout.nav: citizens and units walk it) runs the avenue along x = 0 from the keep door through the court to the yard
-- node (0, -62) and from there diagonally to the store (-46, -34) and the farm (58, -26): the yard keeps its pieces off those lines.
--   axis     x = 0, the open avenue from the door through the court. Pieces on the sides are mirrored about it (the stalls, the hedges)
--            or stand as a pair (the focal pair), so the yard is the same in every kingdom (rotated copies of crimson's;
--            YardCompose.spec proves it)
--   focus    a market cross (store side) and the well (farm side) flanking the door at the court's top corners
--   stalls   two market stalls at the court's lower corners, canopy in the kingdom colour, turned up the court to the focal pair
--   hedges   a hedge row along each nav diagonal, 4.5 studs off it on the court's side: the V that lines the approach to the store and
--            the farm and leads the eye from the street into the court
--   flanks   the farm's cart and a haystack in the open ground beside the farm diagonal (not mirrored)
-- The pieces are feature "yard": WorldPlan.clear and the trim leave them exactly where they are, because YardCompose.spec holds them to
-- stricter rules than the clearance's circles (by the footprint each draws): off the lanes, roads, slots, buildings and fields, off every
-- nav edge by 2 studs, and out of the door's sightline and the focal pair's ring.
WorldPlan.YARD = table.freeze({
	court = Vector2.new(0, -39), -- the court's centre (WorldGround.worn)
	door = Vector2.new(0, -23), -- the keep door
	ring = 2.5, -- studs of open ground round a focal piece
	focalAt = Vector2.new(8, -31), -- the well; the cross is its image at x = -8
	stallAt = Vector2.new(8, -48.4), -- the right-hand stall; the other is its mirror image
	apex = Vector2.new(0, -62), -- the yard node where the avenue and the two diagonals meet
	vAngle = math.rad(31.5), -- the slope of the diagonals above the cross street (store 31.3 degrees, farm 31.8)
	vOffset = 4.5, -- studs from a diagonal to the middle of its hedge row, on the court's side
	hedgeAt = table.freeze({ 26.5, 36.6 }), -- along the row from the apex: the long hedge's middle, the short hedge's middle
	cartAt = Vector2.new(38, -50.5), -- the farm's cart, parked along the diagonal
	hayAt = Vector2.new(46, -44),
})

export type YardRow = { id: string, x: number, z: number, yaw: number, role: string }

-- The yard in the keep's frame for a kingdom's banner colour (red, blue, green, yellow): { id, x, z, yaw, role }, yaw turned from the
-- keep's own facing. Fixed order, no random numbers.
function WorldPlan.yardRows(colour: string): { YardRow }
	local Y = WorldPlan.YARD
	local rows: { YardRow } = {}
	local function add(id: string, x: number, z: number, yaw: number, role: string)
		table.insert(rows, { id = id, x = x, z = z, yaw = yaw, role = role })
	end
	local function pair(id: string, x: number, z: number, yaw: number, role: string)
		add(id, x, z, yaw, role) -- the right-hand piece ...
		add(id, -x, z, -yaw, role) -- ... and its image in the avenue's axis
	end
	add(`prop_cross_{colour}_01`, -Y.focalAt.X, Y.focalAt.Y, 0, "focal")
	add("prop_well_01", Y.focalAt.X, Y.focalAt.Y, 0, "focal")
	pair(`prop_stall_{colour}_01`, Y.stallAt.X, Y.stallAt.Y, math.pi, "stall") -- facing up the court (+Z), at the focal piece above
	-- the hedge rows: farm side first (along the farm diagonal, the row's X axis on it), then the store side mirrored
	local slope = Vector2.new(math.cos(Y.vAngle), math.sin(Y.vAngle))
	local side = Vector2.new(-slope.Y, slope.X) -- toward the court
	for i, id in { "prop_hedge_01", "prop_hedge_02" } do
		local t = Y.hedgeAt[i]
		pair(id, side.X * Y.vOffset + slope.X * t, Y.apex.Y + side.Y * Y.vOffset + slope.Y * t, -Y.vAngle, "hedge")
	end
	add("prop_cart_02", Y.cartAt.X, Y.cartAt.Y, math.pi / 2 - Y.vAngle, "flank") -- handles toward the yard node
	add("farm_haystack_02", Y.hayAt.X, Y.hayAt.Y, 0, "flank")
	return rows
end

-- The yard's placements for one kingdom in the world: the rows turned with its keep.
function WorldPlan.yard(layout: any, kingdom: string): { Placement }
	local keep = layout.plots[kingdom].anchors.keep
	local keepYaw = yawOf(keep)
	local out: { Placement } = {}
	for _, row in WorldPlan.yardRows(KINGDOM_BANNER[kingdom] or "red") do
		local p = (keep * CFrame.new(row.x, 0, row.z)).Position
		local y = WorldPlan.groundHeight(layout, p.X, p.Z)
		table.insert(out, {
			assetId = row.id,
			cframe = CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, keepYaw + row.yaw, 0),
			feature = "yard",
		})
	end
	return out
end

-- The valley's dressing as generated (bridges, crops, the clumped nature, kingdom dressing), before clear().
function WorldPlan.plan(layout: any, dressed: { [string]: boolean }?): { Placement }
	local f = layout.features
	local out: { Placement } = {}
	local rng = prng(4242)

	-- bridges first
	for i, br in f.river.bridges do
		local y = WorldPlan.groundHeight(layout, br.at.X + 30, br.at.Y)
		table.insert(out, {
			assetId = assetId("bridge_stone", i),
			cframe = CFrame.new(br.at.X, y, br.at.Y) * CFrame.Angles(0, math.rad(br.yaw), 0),
			feature = "bridge",
		})
	end

	-- crops on every terrain field (wheat / cabbage rows)
	for i, field in f.fields do
		local y = WorldPlan.groundHeight(layout, field.center.X, field.center.Y)
		table.insert(out, {
			assetId = string.format("farm_field_%s_%02d", field.crop or "wheat", 1 + (i % 3)),
			cframe = CFrame.new(field.center.X, y, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0),
			feature = "crops",
		})
	end

	for _, p in generateNature(layout) do
		table.insert(out, p)
	end

	-- dressing for fully dressed kingdoms (VS-1: one dressed plot, the others blocked out)
	local function place(id: string, x: number, z: number, feature: string, yaw: number?)
		local y = WorldPlan.groundHeight(layout, x, z)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, yaw or rng.range(0, 2 * math.pi), 0)
		table.insert(out, { assetId = id, cframe = cf, feature = feature })
	end
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
				place(string.format("prop_banner_%s_%02d", banner, 1 + (i % 2)), p.X, p.Z, "dressing", yaw)
			end
			for i, off in
				{ Vector3.new(-30, 0, -10), Vector3.new(-30, 0, 6), Vector3.new(30, 0, -14), Vector3.new(-50, 0, 10) }
			do
				local p = (keep * CFrame.new(off)).Position
				local id = if i == 3
					then "farm_haystack_01"
					elseif i == 4 then "prop_cart_02"
					else assetId("prop_goods", i)
				place(id, p.X, p.Z, "dressing") -- hand-placed clear of slots, nav and roads (spec); the cart stands at (-50, 10), where clear() leaves it (the old (-76, 2) was nudged 13 studs onto a nav edge)
			end
			-- the start yard: the market square the start camera looks across (WorldPlan.yard)
			for _, p in WorldPlan.yard(layout, kingdom) do
				table.insert(out, p)
			end
		end
	end
	return out
end

-- The dressing WorldService places: the plan, cleared off the plots' reserved ground, then thinned to the
-- density knob (D-047, below).
function WorldPlan.props(layout: any, dressed: { [string]: boolean }?, density: { [string]: number }?): { Placement }
	return WorldPlan.trim(layout, WorldPlan.clear(layout, WorldPlan.plan(layout, dressed)), density)
end

-- ---------------------------------------------------------------- mesh-only dressing (FL-0136 phase 3)

-- Dressing the part-built world never had. It is placed ONLY for asset ids the Kit would build as imported meshes (`ready(id)`,
-- Kit.envMeshReady), so a world without the imported kit is exactly today's world (same placements, same parts, same pins).
-- Two kinds, both pure and deterministic (no PRNG), folded into / appended to the trimmed props:
--   * cabbage variants: a cabbage field takes farm_field_cabbage_01..03 by its kingdom (it was always _03);
--   * fences (farm_fence_NN) along the outside of each plot's crop fields: the back and flank sides, never the side that faces the
--     keep or a neighbouring field, and a segment is dropped (never nudged) when it would touch a slot, a building, a build zone,
--     a road, a worn lane, the river or the arena.
-- (Rock cliffs on the mountain rim were placed in the first round of phase 3 and dropped by FORGE-00; rock_cliff_01/02 are on the bench.)
WorldPlan.MESH_DRESSING = table.freeze({
	cabbageIds = table.freeze({ "farm_field_cabbage_01", "farm_field_cabbage_02", "farm_field_cabbage_03" }),
	fenceIds = table.freeze({ "farm_fence_01", "farm_fence_02" }),
	fenceLength = 16.5, -- the mesh's length (env.json size.x)
	fenceOffset = 2.4, -- studs from a field's edge to the fence line
	fenceFacing = 0.35, -- a side whose outward normal points this much toward the keep stays open
	fenceHalfWidth = 0.4, -- the fence's half thickness plus a little
})

local function fenceSegmentLegal(layout: any, rects: { any }, x: number, z: number): boolean
	local f = layout.features
	local hw = WorldPlan.MESH_DRESSING.fenceHalfWidth
	if x < f.bounds.min.X + 8 or x > f.bounds.max.X - 8 or z < f.bounds.min.Y + 8 or z > f.bounds.max.Y - 8 then
		return false
	end
	if distToPolyline(x, z, f.river.points) < f.river.width / 2 + 4 then
		return false
	end
	for _, road in f.roads do
		if distToPolyline(x, z, road.points) < road.width / 2 + hw + 1 then
			return false
		end
	end
	-- the plots' worn lanes (features.paths; the ground only, drawn by WorldGround): a fence stands beside them, never across them, with
	-- the same clearance as a road
	for _, lane in f.paths do
		if distToPolyline(x, z, lane.points) < lane.width / 2 + hw + 1 then
			return false
		end
	end
	for _, rect in rects do
		if rect.kind ~= "field" then
			local gap = if rect.kind == "zone" then hw else hw + WorldPlan.CLEAR.wallGap
			if WorldPlan.rectDistance(rect, x, z) < gap then
				return false
			end
		end
	end
	local arena = WorldPlan.arenaRect(layout)
	if arena and WorldPlan.rectDistance(arena, x, z) < hw + WorldPlan.CLEAR.margin then
		return false
	end
	return true
end

-- the kingdom whose keep is nearest to (x, z): 1..4 in KINGDOM_ORDER
local function plotIndexOf(layout: any, x: number, z: number): number
	local best, bestD = 1, math.huge
	for i, kingdom in KINGDOM_ORDER do
		local c = layout.plots[kingdom].anchors.keep.Position
		local d = (c.X - x) ^ 2 + (c.Z - z) ^ 2
		if d < bestD then
			best, bestD = i, d
		end
	end
	return best
end

function WorldPlan.meshDressing(layout: any, placements: { Placement }, ready: ((string) -> boolean)?): { Placement }
	local D = WorldPlan.MESH_DRESSING
	local isReady = ready or function(_: string): boolean
		return false
	end
	local f = layout.features
	local out: { Placement } = {}
	-- cabbage variants
	for _, p in placements do
		local id = p.assetId
		if p.feature == "crops" and string.sub(id, 1, 20) == "farm_field_cabbage_0" then
			local pos = p.cframe.Position
			local variant = D.cabbageIds[1 + (plotIndexOf(layout, pos.X, pos.Z) - 1) % #D.cabbageIds]
			if isReady(variant) then
				p = { assetId = variant, cframe = p.cframe, feature = p.feature }
			end
		end
		table.insert(out, p)
	end
	-- fences along the outside of the crop fields
	local fenceReady = {}
	for _, id in D.fenceIds do
		if isReady(id) then
			table.insert(fenceReady, id)
		end
	end
	if #fenceReady > 0 then
		local rects = WorldPlan.reservedRects(layout)
		local fields = f.fields
		local n = 0
		for i, field in fields do
			local fcf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
			local keep =
				layout.plots[KINGDOM_ORDER[plotIndexOf(layout, field.center.X, field.center.Y)]].anchors.keep.Position
			local toKeep = Vector3.new(keep.X - field.center.X, 0, keep.Z - field.center.Y).Unit
			-- the four sides: local normal, half extent along the normal, side length
			for _, side in
				{
					{ Vector3.new(1, 0, 0), field.size.X / 2, field.size.Y },
					{ Vector3.new(-1, 0, 0), field.size.X / 2, field.size.Y },
					{ Vector3.new(0, 0, 1), field.size.Y / 2, field.size.X },
					{ Vector3.new(0, 0, -1), field.size.Y / 2, field.size.X },
				}
			do
				local normal = fcf:VectorToWorldSpace(side[1])
				local mid = fcf.Position + normal * (side[2] + D.fenceOffset)
				local open = normal:Dot(toKeep) > D.fenceFacing
				local beside = false -- another field close on this side
				for j, other in fields do
					if j ~= i then
						local ocf = CFrame.new(other.center.X, 0, other.center.Y) * CFrame.Angles(0, other.yaw or 0, 0)
						local rect = { cf = ocf, half = other.size / 2 }
						if WorldPlan.rectDistance(rect, mid.X, mid.Z) < 8 then
							beside = true
							break
						end
					end
				end
				if not open and not beside then
					local tangent = Vector3.new(-normal.Z, 0, normal.X)
					local count = math.max(1, math.floor(side[3] / D.fenceLength + 0.5))
					local step = side[3] / count
					for k = 1, count do
						local at = mid + tangent * ((k - (count + 1) / 2) * step)
						local legal = true
						for t = -2, 2 do -- five samples along the segment
							local q = at + tangent * (t * D.fenceLength / 4)
							if not fenceSegmentLegal(layout, rects, q.X, q.Z) then
								legal = false
								break
							end
						end
						if legal then
							n += 1
							local id = fenceReady[1 + (n % #fenceReady)]
							-- the lateral nudge keeps two overlapping neighbours (30 studs / 2 = 15 < 16.5) from z-fighting
							local shift = normal * (if k % 2 == 0 then 0.3 else 0)
							local y = WorldPlan.groundHeight(layout, at.X, at.Z)
							table.insert(out, {
								assetId = id,
								cframe = CFrame.new(at.X + shift.X, y, at.Z + shift.Z)
									* CFrame.Angles(0, math.atan2(-tangent.Z, tangent.X), 0),
								feature = "fence",
							})
						end
					end
				end
			end
		end
	end
	return out
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
	laneBand = 20, -- the plots' village lanes (features.paths): studs either side; never thinned
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
	for _, lane in layout.features.paths or {} do
		attention = math.min(attention, distToPolyline(x, z, lane.points) - t.laneBand)
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

-- Ground circle of each forest stand's leafy floor (the "forest_floor" terrain op), fitted to the stand's trees: the circle round
-- the kept trees' centroid (or, when that sits far off the stand's centre, round the stand's centre) that reaches the farthest of
-- them plus FLOOR_PAD studs of canopy, never larger than the stand's full disc (its centre, 1.05 x its radius). The generator grows a
-- stand as a dense core with satellite clumps, so the dark ground sits under the trees instead of a bare disc round a few; a stand
-- the trim thinned follows what stays, and a stand with no trees keeps today's disc.
export type Floor = { x: number, z: number, r: number }
local floorCache: { [any]: { [string]: { Floor } } } = setmetatable({}, { __mode = "k" }) :: any
local FLOOR_PAD = 9

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
	local kept: { [number]: { Vector2 } } = {}
	local cleared = WorldPlan.clear(layout, WorldPlan.plan(layout, {})) -- forests do not depend on `dressed`
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
		if #trees > 0 then
			local sum = Vector2.zero
			for _, tree in trees do
				sum += tree
			end
			local centroid = sum / #trees
			local centres = { forest.center }
			if (centroid - forest.center).Magnitude <= forest.radius * 0.2 then
				table.insert(centres, 1, centroid)
			end
			local best = nil
			for _, centre in centres do
				local far = 0
				for _, tree in trees do
					far = math.max(far, (tree - centre).Magnitude)
				end
				local r = math.max(8, far + FLOOR_PAD)
				if not best or r < best.r then
					best = { x = centre.X, z = centre.Y, r = r }
				end
			end
			if best.r < floors[s].r then
				floors[s] = best
			end
		end
	end
	byKey[key] = floors
	return floors
end

return WorldPlan
