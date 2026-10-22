--!strict
--[[
	Kit/WorldGround — the valley's ground cover and worn ground, as terrain ops (FORGE-02, visual pass 1; the owner's
	"too much unbroken grass" and "buildings look disconnected, not like a village"). Pure and deterministic: WorldPlan.terrainOps
	calls it and WorldService executes the ops; the world preview reads the same ops (tests/world/WorldDump).

		WorldGround.cover(layout, api, floors) -> { Op }  -- noise-driven patches of LeafyGrass / Ground / Mud over the open land
		WorldGround.aprons(layout, api) -> { Op }          -- worn pads under the fields, the starting buildings and the work yards
		WorldGround.worn(layout, api) -> { Op }            -- roads and lanes (ragged edges, worn centre), the plazas
		WorldGround.border(layout, api) -> { Op }          -- the trodden band between two kingdoms' lands
		WorldGround.lanes(layout) -> { Lane }              -- every ground line: features.roads then features.paths
	api = { groundHeight, distToPolyline, prng, hillBalls } (WorldPlan's own functions; this module requires none of WorldPlan).

	Cover is a raster of 4-stud cells, one terrain voxel each, merged into the fewest blocks; a block is one full voxel layer
	(top at groundY), so a Fill covers whole voxels (the base ground is filled the same way). The material of a cell comes from
	three value-noise fields (the meadow tone, bare earth, wet earth) whose thresholds relax with the distance from every
	plot spawn, so the ground in the plots' view is varied and the far valley sparser. Cells next to a field or a lane stay green
	(the lane and the field draw their own edge). Everything else (aprons, lanes, plazas) is a thin 2-stud op like the fields.

	Determinism: integer hash noise and the Park-Miller prng of WorldPlan; no Random, no clock.
]]

local WorldGround = {}

export type Op = {
	kind: string,
	material: string,
	cframe: CFrame,
	size: Vector3?,
	radius: number?,
	height: number?,
	feature: string,
}
export type Api = {
	groundHeight: (layout: any, x: number, z: number) -> number,
	distToPolyline: (px: number, pz: number, pts: { Vector2 }) -> number,
	prng: (seed: number) -> any,
	hillBalls: (layout: any) -> { any },
}
export type Lane = { width: number, points: { Vector2 }, kind: string }

local CELL = 4 -- one terrain voxel
local COARSE_BELOW = 0.7 -- view weight under which the cover is sampled on 8-stud cells (far from every plot)

-- Tunables (the spec reads them): the noise scales (studs per noise unit) and the thresholds, near a plot and far from every plot.
WorldGround.COVER = table.freeze({
	fullRadius = 250, -- studs from a plot spawn inside which the ground is as varied as it gets
	farRadius = 560, -- ... and beyond which it is at its sparsest
	leafy = table.freeze({ scale = 80, near = 0.72, far = 0.97 }), -- LeafyGrass where the tone noise passes the threshold
	clump = table.freeze({ scale = 32, near = 0.84, far = 0.99 }), -- ... and in smaller clumps
	bare = table.freeze({ scale = 44, near = 0.8, far = 0.98 }), -- Ground
	wet = table.freeze({ scale = 24, near = 0.78, far = 0.95 }), -- Mud inside the bare earth
	greenMargin = 7, -- studs of green kept beside a field edge or a lane (a cell is 4 studs: its edge stays 5 or more off)
})

-- ---------------------------------------------------------------- noise

-- 32-bit integer hash of a lattice point -> [0, 1). Every product stays below 2^53, so Lune and Roblox agree exactly.
local function hash(ix: number, iz: number, seed: number): number
	local h = (ix * 73856093 + iz * 19349663 + seed * 83492791) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = (h * 31153) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = (h * 52429) % 4294967296
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h / 4294967296
end

-- Smooth value noise in 0..1 (lattice hashes memoised per sampler; `detail` > 0 adds a second octave of that weight), stretched
-- back to the full range.
local function sampler(seed: number, detail: number): (number, number) -> number
	local memo: { [number]: number } = {}
	local function at(ix: number, iz: number): number
		local key = iz * 65536 + ix
		local v = memo[key]
		if not v then
			v = hash(ix, iz, seed)
			memo[key] = v
		end
		return v
	end
	local function value(x: number, z: number): number
		local ix, iz = math.floor(x), math.floor(z)
		local fx, fz = x - ix, z - iz
		fx, fz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
		local a, b = at(ix, iz), at(ix + 1, iz)
		local c, d = at(ix, iz + 1), at(ix + 1, iz + 1)
		local top, bottom = a + (b - a) * fx, c + (d - c) * fx
		return top + (bottom - top) * fz
	end
	return function(x: number, z: number): number
		local v = if detail > 0
			then value(x, z) * (1 - detail) + value(x * 2.3 + 17, z * 2.3 + 5) * detail
			else value(x, z)
		return math.clamp((v - 0.5) * (if detail > 0 then 1.55 else 1.35) + 0.5, 0, 1)
	end
end
WorldGround.sampler = sampler

-- ---------------------------------------------------------------- geometry helpers

local function segDist(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local abx, abz = bx - ax, bz - az
	local len2 = abx * abx + abz * abz
	local t = if len2 > 0 then math.clamp(((px - ax) * abx + (pz - az) * abz) / len2, 0, 1) else 0
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- CFrame at (x, y, z) whose local +Z runs along (dx, dz).
local function along(x: number, y: number, z: number, dx: number, dz: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.atan2(dx, dz), 0)
end

-- Every ground line (a polyline with a width): the roads, then the plots' lanes.
function WorldGround.lanes(layout: any): { Lane }
	local out: { Lane } = {}
	for _, road in layout.features.roads do
		table.insert(out, { width = road.width, points = road.points, kind = "road" })
	end
	for _, path in layout.features.paths or {} do
		table.insert(out, { width = path.width, points = path.points, kind = "path" })
	end
	return out
end

local function plotAnchors(layout: any): { Vector3 }
	local out = {}
	for _, kingdom in { "crimson", "azure", "emerald", "gold" } do
		table.insert(out, layout.plots[kingdom].spawn.Position)
	end
	return out
end

-- 1 inside the full radius of a plot spawn (or 120 studs of the heartland), falling to 0 at the far radius.
local function viewWeight(spawns: { Vector3 }, hub: Vector3?, x: number, z: number): number
	local c = WorldGround.COVER
	local best = math.huge
	for _, p in spawns do
		best = math.min(best, (x - p.X) ^ 2 + (z - p.Z) ^ 2)
	end
	local w = 1 - math.clamp((math.sqrt(best) - c.fullRadius) / (c.farRadius - c.fullRadius), 0, 1)
	if hub and w < 1 then
		local d = math.sqrt((x - hub.X) ^ 2 + (z - hub.Z) ^ 2)
		w = math.max(w, 1 - math.clamp((d - 110) / 160, 0, 1))
	end
	return w
end

-- ---------------------------------------------------------------- op builders

local function newBuilder(layout: any, api: Api, ops: { Op })
	local B = {}
	function B.gh(x: number, z: number): number
		return api.groundHeight(layout, x, z)
	end
	-- a disc: top 0.2 above the ground, 2.4 deep (the patches of old)
	function B.disc(material: string, x: number, z: number, r: number, feature: string)
		table.insert(ops, {
			kind = "Cylinder",
			material = material,
			cframe = CFrame.new(x, B.gh(x, z) - 1, z),
			radius = r,
			height = 2.4,
			feature = feature,
		})
	end
	-- a slab turned by `cf` (its Y is ignored): 2 deep, top 0.1 above the ground
	function B.slab(material: string, cf: CFrame, w: number, d: number, feature: string)
		local p = cf.Position
		table.insert(ops, {
			kind = "Block",
			material = material,
			cframe = CFrame.new(p.X, B.gh(p.X, p.Z) - 0.9, p.Z) * (cf - p),
			size = Vector3.new(w, 2, d),
			feature = feature,
		})
	end
	return B
end

-- A ragged blob: a core disc and satellites around it (overlapping, so the outline is irregular).
local function blob(B: any, rng: any, material: string, x: number, z: number, r: number, n: number, feature: string)
	B.disc(material, x, z, r * 0.78, feature)
	for i = 1, n do
		local a = (i - 1 + rng.range(0.1, 0.9)) * 2 * math.pi / n
		local d = r * rng.range(0.4, 0.62)
		B.disc(material, x + math.cos(a) * d, z + math.sin(a) * d, r * rng.range(0.42, 0.62), feature)
	end
end

-- A rounded rectangle turned by `cf` (centre, w x d, corner radius `rad`): two crossing slabs and four corner discs of
-- slightly different radii, so the outline is not a knife-edge rectangle.
local function rrect(B: any, rng: any, material: string, cf: CFrame, w: number, d: number, rad: number, feature: string)
	B.slab(material, cf, w - 2 * rad, d, feature)
	B.slab(material, cf, w, d - 2 * rad, feature)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = (cf * CFrame.new(sx * (w / 2 - rad), 0, sz * (d / 2 - rad))).Position
			B.disc(material, p.X, p.Z, rad * rng.range(0.92, 1.12), feature)
		end
	end
end

-- ---------------------------------------------------------------- cover

-- Cells (row-major key) that stay green: within `margin` of a field, a road or a lane.
local function greenCells(layout: any, x0: number, z0: number, nx: number, nz: number): { [number]: boolean }
	local margin = WorldGround.COVER.greenMargin
	local mask: { [number]: boolean } = {}
	local function mark(minX: number, maxX: number, minZ: number, maxZ: number, inside: (number, number) -> boolean)
		local i0, i1 = math.max(0, math.floor((minX - x0) / CELL)), math.min(nx - 1, math.ceil((maxX - x0) / CELL))
		local j0, j1 = math.max(0, math.floor((minZ - z0) / CELL)), math.min(nz - 1, math.ceil((maxZ - z0) / CELL))
		for j = j0, j1 do
			for i = i0, i1 do
				if inside(x0 + (i + 0.5) * CELL, z0 + (j + 0.5) * CELL) then
					mask[j * nx + i] = true
				end
			end
		end
	end
	for _, field in layout.features.fields do
		local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
		local reach = field.size.Magnitude / 2 + margin
		mark(
			field.center.X - reach,
			field.center.X + reach,
			field.center.Y - reach,
			field.center.Y + reach,
			function(x, z)
				local p = cf:PointToObjectSpace(Vector3.new(x, 0, z))
				return math.abs(p.X) <= field.size.X / 2 + margin and math.abs(p.Z) <= field.size.Y / 2 + margin
			end
		)
	end
	for _, lane in WorldGround.lanes(layout) do
		local reach = lane.width / 2 + margin
		for i = 1, #lane.points - 1 do
			local a, b = lane.points[i], lane.points[i + 1]
			mark(
				math.min(a.X, b.X) - reach,
				math.max(a.X, b.X) + reach,
				math.min(a.Y, b.Y) - reach,
				math.max(a.Y, b.Y) + reach,
				function(x, z)
					return segDist(x, z, a.X, a.Y, b.X, b.Y) <= reach
				end
			)
		end
	end
	return mask
end

local coverCache: { [any]: { [any]: { Op } } } = setmetatable({}, { __mode = "k" }) :: any

-- The material sampler of a layout: (x, z, green) -> material or nil (leave the ground as it is: grass, a forest floor, a hill, the
-- river). A pure function of the point, so the spec can sample it.
local function coverSampler(
	layout: any,
	api: Api,
	floors: { any },
	caps: { any }
): ((number, number, boolean) -> string?, (number, number) -> number)
	local c = WorldGround.COVER
	local f = layout.features
	local spawns = plotAnchors(layout)
	local hub = if layout.objectives[1] then layout.objectives[1].cframe.Position else nil
	local toneAt, clumpAt, bareAt, wetAt, rimAt =
		sampler(11, 0), sampler(5, 0), sampler(23, 0.15), sampler(37, 0), sampler(71, 0)
	local function weight(x: number, z: number): number
		return viewWeight(spawns, hub, x, z)
	end
	local warpA, warpB = sampler(101, 0), sampler(103, 0)
	return function(x: number, z: number, green: boolean): string?
		local far = 1 - viewWeight(spawns, hub, x, z)
		-- the noise is read through a slow warp, so no edge follows the lattice
		local wx, wz = x + (warpA(x / 55, z / 55) - 0.5) * 46, z + (warpB(x / 55 + 9, z / 55 - 4) - 0.5) * 46
		local mat = "Grass"
		if
			toneAt(wx / c.leafy.scale, wz / c.leafy.scale) > c.leafy.near + (c.leafy.far - c.leafy.near) * far
			or clumpAt(wx / c.clump.scale, wz / c.clump.scale) > c.clump.near + (c.clump.far - c.clump.near) * far
		then
			mat = "LeafyGrass"
		end
		if
			not green
			and bareAt(wx / c.bare.scale, wz / c.bare.scale) > c.bare.near + (c.bare.far - c.bare.near) * far
		then
			mat = "Ground"
			if wetAt(wx / c.wet.scale, wz / c.wet.scale) > c.wet.near + (c.wet.far - c.wet.near) * far then
				mat = "Mud"
			end
		end
		-- forest floors: leave the disc alone, eat a ragged rim of it back to grass and feather leafy ground out beyond it
		local keepGrass = false
		for _, fl in floors do
			local d2 = (x - fl.x) ^ 2 + (z - fl.z) ^ 2
			if d2 < (fl.r + 18) ^ 2 then
				local d = math.sqrt(d2)
				local rim = rimAt(x / 22, z / 22)
				if d < fl.r * 0.78 then
					return nil
				elseif d <= fl.r then
					local t = (d - fl.r * 0.78) / (fl.r * 0.22)
					if rim >= 0.15 + 0.55 * t then
						return nil
					end
					mat, keepGrass = "Grass", true -- painted over the floor's leafy ground
				elseif mat == "Grass" and rim < 0.62 * (1 - (d - fl.r) / 18) then
					mat = "LeafyGrass"
				end
			end
		end
		if mat == "Grass" and not keepGrass then
			return nil
		end
		-- not on a hill, not at the river, inside the bounds
		if x < f.bounds.min.X + 8 or x > f.bounds.max.X - 8 or z < f.bounds.min.Y + 8 or z > f.bounds.max.Y - 8 then
			return nil
		end
		for _, cap in caps do
			if (x - cap.x) ^ 2 + (z - cap.z) ^ 2 < cap.r2 then
				return nil
			end
		end
		if api.distToPolyline(x, z, f.river.points) < f.river.width / 2 + 10 then
			return nil
		end
		return mat
	end,
		weight
end

-- Where each hill rises above the flat ground: discs (centre, squared radius), grown 8 studs so a slope's foot stays green.
local function hillCaps(layout: any, api: Api): { any }
	local gy = layout.features.groundY or 0
	local caps = {}
	for _, b in api.hillBalls(layout) do
		local dy = gy - b.y
		local r2 = b.r * b.r - dy * dy
		if r2 > 0 then
			local r = math.sqrt(r2) + 8
			table.insert(caps, { x = b.x, z = b.z, r2 = r * r })
		end
	end
	return caps
end

function WorldGround.cover(layout: any, api: Api, floors: { any }): { Op }
	local byFloors = coverCache[layout]
	if not byFloors then
		byFloors = {}
		coverCache[layout] = byFloors
	end
	if byFloors[floors] then
		return byFloors[floors]
	end
	local f = layout.features
	local gy = f.groundY or 0
	local x0, z0 = math.floor(f.bounds.min.X / CELL) * CELL, math.floor(f.bounds.min.Y / CELL) * CELL
	local nx, nz = math.ceil((f.bounds.max.X - x0) / CELL), math.ceil((f.bounds.max.Y - z0) / CELL)
	local green = greenCells(layout, x0, z0, nx, nz)
	local caps = hillCaps(layout, api)
	local material, weightAt = coverSampler(layout, api, floors, caps)
	local coarseRow: { [number]: string | boolean } = {} -- far from every plot: 2 x 2 cells share one sample (8 studs)

	-- the raster, row by row; runs of one material merge down into rectangles
	local ops: { Op } = {}
	local open: { [string]: { i0: number, i1: number, j0: number, j1: number, material: string } } = {}
	local function emit(r: any)
		table.insert(ops, {
			kind = "Block",
			material = r.material,
			cframe = CFrame.new(x0 + (r.i0 + r.i1 + 1) * CELL / 2, gy - CELL / 2, z0 + (r.j0 + r.j1 + 1) * CELL / 2),
			size = Vector3.new((r.i1 - r.i0 + 1) * CELL, CELL, (r.j1 - r.j0 + 1) * CELL),
			feature = "patch",
		})
	end
	for j = 0, nz do
		if j % 2 == 0 then
			coarseRow = {}
		end
		local nextOpen: { [string]: any } = {}
		local run: { i0: number, material: string }? = nil
		local function close(i: number)
			if run then
				local key = `{run.i0}:{i - 1}:{run.material}`
				local above = open[key]
				if above then
					above.j1 = j
					nextOpen[key] = above
					open[key] = nil
				else
					nextOpen[key] = { i0 = run.i0, i1 = i - 1, j0 = j, j1 = j, material = run.material }
				end
				run = nil
			end
		end
		for i = 0, nx do
			local mat: string? = nil
			if j < nz and i < nx then
				local i0, j0 = i - i % 2, j - j % 2
				local gx, gz = x0 + (i0 + 1) * CELL, z0 + (j0 + 1) * CELL
				if weightAt(gx, gz) < COARSE_BELOW then
					local cached = coarseRow[i0]
					if cached == nil then
						local anyGreen = green[j0 * nx + i0]
							or green[j0 * nx + i0 + 1]
							or green[(j0 + 1) * nx + i0]
							or green[(j0 + 1) * nx + i0 + 1]
						cached = material(gx, gz, anyGreen == true) or false
						coarseRow[i0] = cached
					end
					mat = if cached then cached :: string else nil
				else
					mat = material(x0 + (i + 0.5) * CELL, z0 + (j + 0.5) * CELL, green[j * nx + i] == true)
				end
			end
			if run and run.material ~= mat then
				close(i)
			end
			if mat and not run then
				run = { i0 = i, material = mat }
			end
		end
		for _, r in open do
			emit(r) -- not continued by this row: finished
		end
		open = nextOpen
	end
	for _, r in open do
		emit(r)
	end
	byFloors[floors] = ops
	return ops
end

-- ---------------------------------------------------------------- worn ground

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }

-- The keep's frame helpers: a CFrame at keep-local (x, z) turned like the keep.
local function localCF(keep: CFrame, x: number, z: number, yaw: number?): CFrame
	local p = (keep * CFrame.new(x, 0, z)).Position
	return CFrame.new(p) * (keep - keep.Position) * CFrame.Angles(0, yaw or 0, 0)
end

function WorldGround.aprons(layout: any, api: Api): { Op }
	local ops: { Op } = {}
	local B = newBuilder(layout, api, ops)
	local rng = api.prng(913)
	-- the fields: a trodden headland around each, so the dark soil reads against the grass and the gaps between fields close up
	for _, field in layout.features.fields do
		local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
		rrect(B, rng, "Ground", cf, field.size.X + 7, field.size.Y + 7, 4, "apron")
	end
	for _, kingdom in KINGDOMS do
		local plot = layout.plots[kingdom]
		local keep = plot.anchors.keep
		-- the starting buildings sit in worn ground: a dirt pad turned with each, bigger than its footprint
		local pads = { -- anchor, footprint half x, half z (Buildings.footprint), margin
			{ "keep", 23, 23, 0 },
			{ "storehouse", 13, 10, 3 },
			{ "farm", 20, 16, 3 },
			{ "lumbercamp", 11, 9, 5 },
			{ "quarry", 11, 10, 5 },
		}
		for _, pad in pads do
			local anchor = plot.anchors[pad[1]]
			rrect(B, rng, "Ground", anchor, (pad[2] + pad[4]) * 2, (pad[3] + pad[4]) * 2, 5, "apron")
		end
		-- work yards: trampled mud where the woodcutters and the miners stand, and a rock floor at the quarry
		local camp = localCF(keep, -62, 48)
		blob(B, rng, "Mud", camp.Position.X, camp.Position.Z, 13, 5, "apron")
		local yard = localCF(keep, 52, 54)
		blob(B, rng, "Rock", yard.Position.X, yard.Position.Z, 14, 5, "apron")
		blob(B, rng, "Slate", yard.Position.X + 3, yard.Position.Z + 2, 7, 3, "apron")
		local stone = localCF(keep, 40, 28).Position
		blob(B, rng, "Rock", stone.X, stone.Z, 7, 3, "apron")
		local stone2 = localCF(keep, 80, 60).Position
		blob(B, rng, "Rock", stone2.X, stone2.Z, 7, 3, "apron")
		local ore = localCF(keep, 70, 34).Position
		blob(B, rng, "Slate", ore.X, ore.Z, 6, 3, "apron")
	end
	return ops
end

-- One lane: pieces of about 10 studs that follow the ground, each a little wider, narrower or off-centre than the last, ragged
-- fringe discs on the edges, rounded joints; roads add a worn darker strip down the middle.
local function trail(B: any, rng: any, lane: Lane)
	local pts, width = lane.points, lane.width
	local feature = lane.kind
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		local n = math.max(1, math.ceil(len / 10))
		local dir = (b - a) / math.max(len, 1e-6)
		local nrm = Vector2.new(-dir.Y, dir.X)
		for k = 0, n - 1 do
			local p0, p1 = a:Lerp(b, k / n), a:Lerp(b, (k + 1) / n)
			local seg = p1 - p0
			local mid = (p0 + p1) / 2 + nrm * (rng.range(-0.07, 0.07) * width)
			local w = width * rng.range(0.84, 1.1)
			B.slab("Ground", along(mid.X, 0, mid.Y, seg.X, seg.Y), w, seg.Magnitude + w * 0.5, feature)
			if rng.next() < 0.5 then
				local side = if rng.next() < 0.5 then -1 else 1
				local c = mid + nrm * (side * (w / 2 + rng.range(-0.4, 1.2)))
				B.disc("Ground", c.X, c.Y, rng.range(1.8, 3.2), feature)
			end
		end
	end
	for i = 2, #pts - 1 do
		B.disc("Ground", pts[i].X, pts[i].Y, width * 0.56, feature)
	end
	if lane.kind == "road" and width >= 10 then
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local len = (b - a).Magnitude
			local n = math.max(1, math.ceil(len / 14))
			for k = 0, n - 1 do
				if rng.next() < 0.72 then
					local p0, p1 = a:Lerp(b, k / n), a:Lerp(b, (k + 1) / n)
					local seg = p1 - p0
					local mid = (p0 + p1) / 2
					B.slab(
						"Mud",
						along(mid.X, 0, mid.Y, seg.X, seg.Y),
						3.6,
						seg.Magnitude * rng.range(0.55, 0.95),
						"road_worn"
					)
				end
			end
		end
	end
end

function WorldGround.worn(layout: any, api: Api): { Op }
	local ops: { Op } = {}
	local B = newBuilder(layout, api, ops)
	local rng = api.prng(917)
	for _, lane in WorldGround.lanes(layout) do
		trail(B, rng, lane)
	end
	-- the hub plaza (heartland): the cobbled crossroads at the end of the first road, kept inside a 14-stud radius
	local roads = layout.features.roads
	local last = roads[1].points[#roads[1].points]
	B.disc("Cobblestone", last.X, last.Y, 12.2, "plaza")
	for i = 1, 5 do
		local a = (i - 1 + rng.range(0.1, 0.9)) * 2 * math.pi / 5
		B.disc("Cobblestone", last.X + math.cos(a) * 7.5, last.Y + math.sin(a) * 7.5, rng.range(5, 6.4), "plaza")
	end
	for i = 1, 3 do
		local a = i * 2.1 + rng.next()
		B.disc("Rock", last.X + math.cos(a) * 4, last.Y + math.sin(a) * 4, rng.range(2.4, 3.6), "plaza")
	end
	-- each keep's market square: a cobbled court from the keep door to the yard crossroads, paved with darker worn stones
	for _, kingdom in KINGDOMS do
		local keep = layout.plots[kingdom].anchors.keep
		local court = localCF(keep, 0, -46)
		rrect(B, rng, "Rock", court, 33, 39, 8, "plaza") -- a darker kerb all round
		rrect(B, rng, "Cobblestone", court, 28, 34, 7, "plaza")
		for i = 1, 6 do
			local p = (court * CFrame.new(rng.range(-8, 8), 0, rng.range(-12, 12))).Position
			B.disc(if i % 3 == 0 then "Slate" else "Rock", p.X, p.Z, rng.range(1.8, 3.2), "plaza")
		end
	end
	return ops
end

-- The march between a kingdom's land and the valley: on the two sides of each home region that face the valley centre, a wobbling,
-- broken band of trodden earth with a boundary stone now and then, so the four lands read as separate from the air. Terrain only
-- (no walls); it keeps off the river, the roads and the lanes.
function WorldGround.border(layout: any, api: Api): { Op }
	local ops: { Op } = {}
	local B = newBuilder(layout, api, ops)
	local rng = api.prng(919)
	local f = layout.features
	local wobble = sampler(91, 0.3)
	local lanes = WorldGround.lanes(layout)
	local centre = layout.objectives[1].cframe.Position
	for _, kingdom in KINGDOMS do
		local poly = layout.regions[`{kingdom}_home`].polygon
		local mid = Vector2.zero
		for _, p in poly do
			mid += p
		end
		mid /= #poly
		local toCentre = Vector2.new(centre.X, centre.Z) - mid
		for i = 1, #poly do
			local a, b = poly[i], poly[i % #poly + 1]
			local edgeMid = (a + b) / 2
			local out = edgeMid - mid -- from the region's middle out through this edge
			if out.X * toCentre.X + out.Y * toCentre.Y > 0 and (math.abs(out.X) < 1 or math.abs(out.Y) < 1) then
				local len = (b - a).Magnitude
				local dir = (b - a) / len
				local nrm = Vector2.new(-dir.Y, dir.X)
				local n = math.ceil(len / 12)
				for k = 0, n - 1 do
					local t = (k + 0.5) / n
					local base = a:Lerp(b, t)
					local p = base + nrm * ((wobble(base.X / 40, base.Y / 40) - 0.5) * 22)
					local clear = api.distToPolyline(p.X, p.Y, f.river.points) > f.river.width / 2 + 14
					for _, lane in lanes do
						if clear and api.distToPolyline(p.X, p.Y, lane.points) < lane.width / 2 + 10 then
							clear = false
						end
					end
					local roll = rng.next()
					if clear and roll < 0.62 then
						B.slab("Ground", along(p.X, 0, p.Y, dir.X, dir.Y), rng.range(4.5, 7), 14, "border")
					end
					if clear and k % 4 == 2 then
						B.disc("Rock", p.X, p.Y, rng.range(2.2, 3.4), "border")
						B.disc("Slate", p.X + rng.range(-3, 3), p.Y + rng.range(-3, 3), rng.range(1.6, 2.4), "border")
					end
				end
			end
		end
	end
	return ops
end

return WorldGround
