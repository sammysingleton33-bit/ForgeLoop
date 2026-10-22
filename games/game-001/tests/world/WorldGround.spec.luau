--!nonstrict
--[[
	Ground and roads (visual pass 1; the owner's "too much unbroken grass" and "buildings look disconnected, not like a village").
	HEADLESS (Lune): this pins the terrain PLAN (Kit/WorldGround through WorldPlan.terrainOps), not how Studio's Terrain blends it; the
	Blender renders of tests/world/WorldDump are the look evidence (art/reviews/img/vis1-ground-*).

	The rule, and why each clause:
	  * the cover is deterministic and bounded: the same ops twice, every op a legal Terrain call, the added voxels and ops under a ceiling;
	  * the open ground of every plot's frame is varied: no material covers more than MAX_SHARE of it and both greens, Grass and LeafyGrass,
	    each cover MIN_DRIFT (the grass of old was one flat colour with 28 discs for the valley; bare earth is for work areas and far land);
	  * the START FRAME (the ruler's default camera at a kingdom's spawn: zoom 70, vertical FOV 55, pitch 42.5, 16:9) is mostly green: of the
	    ground it shows, off the field, building and slot footprints, Grass + LeafyGrass are at least MIN_GREEN, Ground + Mud (lanes, roads,
	    pads and headlands included) at most MAX_BROWN and the greys (court, kerb, rock floors) at most MAX_GREY, measured once per screen
	    sample (what the eye sees) and once per ground area;
	  * every named place is on a road or a lane (keep, storehouse, farm, lumber camp, quarry, each field, each build slot) and the
	    four kingdoms have the same lanes (per-kingdom fairness);
	  * a lane never crosses a farm field, a build slot or a starting building (it would hide it), and lanes are NOT features.roads (the
	    sim reserves roads near a keep as no-build ground: Kingdom/Layout);
	  * brown cover keeps a margin off fields and lanes (their edge stays readable) and off forest-floor cores;
	  * each keep has a cobbled court that covers no slot or building and stays near the yard; the hub plaza stays inside the radius
	    ArenaLayout assumes.
	`violations` is the rule as code; the mutants at the end prove it catches each way of breaking it.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local WorldDef = require("@game/ServerScriptService/Game/Services/WorldService")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local WorldGround = require("@game/ReplicatedStorage/Game/Kit/WorldGround")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local MAX_SHARE = 0.72 -- the largest share one material may cover of a frame's open ground
local MIN_DRIFT = 0.15 -- ... and what each of the two greens must cover (the greens carry the variety near a plot)
local MIN_GREEN, MAX_BROWN, MAX_GREY = 0.6, 0.25, 0.12 -- the start frame's shares
local START = { zoom = 70, fov = 55, pitch = 42.5 } -- RulerCameraController.DEFAULTS (overview), the owner-approved start view
local FRAME = 110 -- the plot frame: studs around the spawn (the start view and the far view's near half)
local ADDED_OPS = 5600 -- ceiling on the new ground ops (patch, apron, path, plaza, border; the whole plan had 482 ops before)
local ADDED_VOXELS = 70000 -- ceiling on the voxels of those ops (48 k now; the plan had 7.72 M before, 99 % of it the hills and the base ground)
local LANES =
	{ "keep", "storehouse", "farm", "fields", "quarry", "lumbercamp", "quarry_slot", "lumber_slot", "stone", "timber" }
local BROWN = { Ground = true, Mud = true }

local function api()
	return {
		groundHeight = WorldPlan.groundHeight,
		distToPolyline = WorldPlan.distToPolyline,
		prng = WorldPlan._prng,
		hillBalls = WorldPlan.hillBalls,
	}
end

-- ---------------------------------------------------------------- helpers

-- The surface material at (x, z): the last op that covers the point wins, as in the game (the same reading as WorldDump).
local function surfaceReader(ops)
	local gy = Layout.features.groundY or 0
	local reach = {}
	for _, op in ops do
		if op.material ~= "Air" then
			local p = op.cframe.Position
			local r
			if op.kind == "Block" then
				r = math.sqrt(op.size.X ^ 2 + op.size.Z ^ 2) / 2
			elseif op.kind == "Ball" then
				r = math.sqrt(math.max(0, op.radius ^ 2 - (gy - p.Y) ^ 2))
			else
				r = op.radius
			end
			table.insert(reach, { op = op, x = p.X, z = p.Z, r = r })
		end
	end
	local BUCKET = 48
	local buckets = {}
	for _, o in reach do
		for bz = math.floor((o.z - o.r) / BUCKET), math.floor((o.z + o.r) / BUCKET) do
			for bx = math.floor((o.x - o.r) / BUCKET), math.floor((o.x + o.r) / BUCKET) do
				local key = bz * 4096 + bx
				buckets[key] = buckets[key] or {}
				table.insert(buckets[key], o)
			end
		end
	end
	return function(x: number, z: number): string
		local found = "Grass"
		for _, o in buckets[math.floor(z / BUCKET) * 4096 + math.floor(x / BUCKET)] or {} do
			local dx, dz = x - o.x, z - o.z
			if dx * dx + dz * dz <= o.r * o.r then
				local op = o.op
				local inside = true
				if op.kind == "Block" then
					local l = op.cframe:PointToObjectSpace(Vector3.new(x, op.cframe.Position.Y, z))
					inside = math.abs(l.X) <= op.size.X / 2 and math.abs(l.Z) <= op.size.Z / 2
				end
				if inside then
					found = op.material
				end
			end
		end
		return found
	end
end

local function laneDistance(layout, x: number, z: number): (number, number)
	-- (distance from the centreline, half width) of the nearest road or lane
	local best, half = math.huge, 0
	for _, lane in WorldGround.lanes(layout) do
		local d = WorldPlan.distToPolyline(x, z, lane.points)
		if d - lane.width / 2 < best - half then
			best, half = d, lane.width / 2
		end
	end
	return best, half
end

local function sampleLane(points, step: number)
	local out = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local n = math.max(1, math.ceil((b - a).Magnitude / step))
		for k = 0, n do
			table.insert(out, a:Lerp(b, k / n))
		end
	end
	return out
end

-- The open ground of each plot's frame: grid points (4 studs) within FRAME of the spawn that are off the reserved rectangles, the roads and
-- lanes, the hills; cached per layout (the mutants reuse the layout).
local openCache = setmetatable({}, { __mode = "k" })
local function openPoints(layout, rects)
	if openCache[layout] then
		return openCache[layout]
	end
	local out = {}
	for _, kingdom in KINGDOMS do
		local sp = layout.plots[kingdom].spawn.Position
		local near = {}
		for _, r in rects do
			if r.kind ~= "zone" and (r.cf.Position - sp).Magnitude < FRAME + 60 then
				table.insert(near, r)
			end
		end
		local lanes = {}
		for _, lane in WorldGround.lanes(layout) do
			for _, p in lane.points do
				if (Vector3.new(p.X, 0, p.Y) - Vector3.new(sp.X, 0, sp.Z)).Magnitude < FRAME + 80 then
					table.insert(lanes, lane)
					break
				end
			end
		end
		local pts = {}
		for dx = -FRAME, FRAME, 4 do
			for dz = -FRAME, FRAME, 4 do
				if dx * dx + dz * dz <= FRAME * FRAME then
					local x, z = sp.X + dx, sp.Z + dz
					local open = WorldPlan.groundHeight(layout, x, z) < 0.5
					for _, r in near do
						if open and WorldPlan.rectDistance(r, x, z) < 3 then
							open = false
						end
					end
					for _, lane in lanes do
						if open and WorldPlan.distToPolyline(x, z, lane.points) < lane.width / 2 + 3 then
							open = false
						end
					end
					if open then
						table.insert(pts, Vector2.new(x, z))
					end
				end
			end
		end
		out[kingdom] = pts
	end
	openCache[layout] = out
	return out
end

-- The ground the start camera shows at each kingdom's spawn, as two sample sets off the field, building and slot footprints: `screen` (one
-- ray per cell of a 96 x 54 screen grid, so near ground weighs more, as it does to the eye) and `area` (a 3-stud grid over the same ground
-- trapezoid). Cached per layout.
local frameCache = setmetatable({}, { __mode = "k" })
local function startFrames(layout, rects)
	if frameCache[layout] then
		return frameCache[layout]
	end
	local gy = layout.features.groundY or 0
	local pitch = math.rad(START.pitch)
	local tanV = math.tan(math.rad(START.fov / 2))
	local tanH = tanV * 16 / 9
	local fwd, right, up =
		Vector3.new(0, -math.sin(pitch), -math.cos(pitch)),
		Vector3.new(1, 0, 0),
		Vector3.new(0, math.cos(pitch), -math.sin(pitch))
	local out = {}
	for _, kingdom in KINGDOMS do
		local sp = layout.plots[kingdom].spawn.Position
		local cam = Vector3.new(sp.X, sp.Y + START.zoom * math.sin(pitch), sp.Z + START.zoom * math.cos(pitch))
		local function ground(u: number, v: number): Vector2
			local dir = fwd + right * (u * tanH) + up * (v * tanV)
			local hit = cam + dir * ((gy - cam.Y) / dir.Y)
			return Vector2.new(hit.X, hit.Z)
		end
		local near = {}
		for _, r in rects do
			if r.kind ~= "zone" and (r.cf.Position - sp).Magnitude < 260 then
				table.insert(near, r)
			end
		end
		local function keep(pts)
			local kept = {}
			for _, pt in pts do
				local free = true
				for _, r in near do
					if WorldPlan.rectDistance(r, pt.X, pt.Y) <= 0 then
						free = false
						break
					end
				end
				if free then
					table.insert(kept, pt)
				end
			end
			return kept
		end
		local screen, area = {}, {}
		for iy = 0, 53 do
			for ix = 0, 95 do
				table.insert(screen, ground((ix + 0.5) / 96 * 2 - 1, 1 - (iy + 0.5) / 54 * 2))
			end
		end
		local corners = { ground(-1, -1), ground(1, -1), ground(1, 1), ground(-1, 1) }
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, c in corners do
			minX, maxX, minZ, maxZ = math.min(minX, c.X), math.max(maxX, c.X), math.min(minZ, c.Y), math.max(maxZ, c.Y)
		end
		for x = minX, maxX, 3 do
			for z = minZ, maxZ, 3 do
				local pos, neg = false, false
				for i = 1, 4 do
					local a, b = corners[i], corners[i % 4 + 1]
					local cross = (b.X - a.X) * (z - a.Y) - (b.Y - a.Y) * (x - a.X)
					pos = pos or cross > 0
					neg = neg or cross < 0
				end
				if not (pos and neg) then
					table.insert(area, Vector2.new(x, z))
				end
			end
		end
		out[kingdom] = { screen = keep(screen), area = keep(area) }
	end
	frameCache[layout] = out
	return out
end

-- Shares of green, brown and grey ground over a sample set: { green, brown, grey } in 0..1.
local function shares(read, points)
	local green, brown, grey = 0, 0, 0
	for _, pt in points do
		local m = read(pt.X, pt.Y)
		if m == "Grass" or m == "LeafyGrass" then
			green += 1
		elseif m == "Ground" or m == "Mud" then
			brown += 1
		elseif m == "Cobblestone" or m == "Rock" or m == "Slate" then
			grey += 1
		end
	end
	local n = math.max(1, #points)
	return { green = green / n, brown = brown / n, grey = grey / n }
end

-- The rule as code: the violated clauses of a plan (ops) over a layout, as strings.
local function violations(layout, ops): { string }
	local why = {}
	local function add(s: string)
		table.insert(why, s)
	end
	local rects = WorldPlan.reservedRects(layout)
	local read = surfaceReader(ops)

	-- bounded
	local added, voxels = 0, 0
	for _, op in ops do
		if
			op.feature == "patch"
			or op.feature == "apron"
			or op.feature == "path"
			or op.feature == "plaza"
			or op.feature == "border"
		then
			added += 1
			voxels += WorldPlan.voxels(op)
		end
		if WorldPlan.voxels(op) > Terrain.MAX_VOXELS_PER_CALL then
			add(`op {op.feature} is over the per-call voxel limit`)
		end
	end
	if added > ADDED_OPS then
		add(`{added} ground ops (ceiling {ADDED_OPS})`)
	end
	if voxels > ADDED_VOXELS then
		add(`{voxels} ground voxels (ceiling {ADDED_VOXELS})`)
	end

	-- varied open ground in every plot's frame
	for _, kingdom in KINGDOMS do
		local counts, total = {}, 0
		for _, pt in openPoints(layout, rects)[kingdom] do
			local m = read(pt.X, pt.Y)
			if m ~= "Water" and m ~= "Sand" and m ~= "Cobblestone" then
				counts[m] = (counts[m] or 0) + 1
				total += 1
			end
		end
		for m, n in counts do
			if n / total > MAX_SHARE then
				add(`{kingdom}: {m} covers {math.floor(100 * n / total)} % of the open ground`)
			end
		end
		-- the greens carry the variety near a plot (bare earth is for the work areas and the far land): both drifts show
		for _, m in { "Grass", "LeafyGrass" } do
			if (counts[m] or 0) / total < MIN_DRIFT then
				add(`{kingdom}: {m} covers only {math.floor(100 * (counts[m] or 0) / total)} % of the open ground`)
			end
		end
	end

	-- the start frame is mostly green
	for kingdom, frame in startFrames(layout, rects) do
		for _, mode in { "screen", "area" } do
			local sh = shares(read, frame[mode])
			if sh.green < MIN_GREEN then
				add(`start frame {kingdom} ({mode}): only {math.floor(sh.green * 100)} % green`)
			end
			if sh.brown > MAX_BROWN then
				add(`start frame {kingdom} ({mode}): {math.floor(sh.brown * 100 + 0.5)} % brown`)
			end
			if sh.grey > MAX_GREY then
				add(`start frame {kingdom} ({mode}): {math.floor(sh.grey * 100 + 0.5)} % grey`)
			end
		end
	end

	-- every named place is on a road or a lane
	local byKingdom = {}
	for _, path in layout.features.paths or {} do
		byKingdom[path.kingdom] = byKingdom[path.kingdom] or {}
		byKingdom[path.kingdom][path.name] = path
	end
	for _, kingdom in KINGDOMS do
		for _, name in LANES do
			if not (byKingdom[kingdom] and byKingdom[kingdom][name]) then
				add(`{kingdom} has no {name} lane`)
			end
		end
		local plot = layout.plots[kingdom]
		for buildingType, anchor in plot.anchors do
			local d, half = laneDistance(layout, anchor.Position.X, anchor.Position.Z)
			if d - half > 24 then
				add(`{kingdom} {buildingType} is {math.floor(d - half)} studs from a road or lane`)
			end
		end
		for _, slot in plot.buildSlots do
			local d, half = laneDistance(layout, slot.center.X, slot.center.Z)
			if d - half > 38 then
				add(`{slot.id} is {math.floor(d - half)} studs from a road or lane`)
			end
		end
	end
	-- a field is reached by a road or a lane within 36 studs, or by touching (8 studs) a reached field: the headlands chain the fields
	local reached, fieldRects = {}, {}
	for _, r in rects do
		if r.kind == "field" then
			table.insert(fieldRects, r)
		end
	end
	for i, field in layout.features.fields do
		local d, half = laneDistance(layout, field.center.X, field.center.Y)
		reached[i] = d - half <= 36
	end
	for _ = 1, #fieldRects do
		for i, r in fieldRects do
			for j, other in fieldRects do
				if reached[j] and not reached[i] then
					for _, corner in
						{ Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1) }
					do
						local p = (r.cf * CFrame.new(corner.X * r.half.X, 0, corner.Z * r.half.Y)).Position
						if WorldPlan.rectDistance(other, p.X, p.Z) <= 8 then
							reached[i] = true
						end
					end
				end
			end
		end
	end
	for i in layout.features.fields do
		if not reached[i] then
			add(`field {i} is off every road, lane and neighbouring field`)
		end
	end

	-- a lane never crosses a field, a slot or a building; lanes are not roads
	for _, path in layout.features.paths or {} do
		for _, p in sampleLane(path.points, 2) do
			for _, r in rects do
				if r.kind ~= "zone" and WorldPlan.rectDistance(r, p.X, p.Y) < 2 then
					add(`{path.kingdom} lane {path.name} runs over a {r.kind}`)
					break
				end
			end
		end
		for _, road in layout.features.roads do
			if road.points == path.points then
				add(`lane {path.name} is also a road`)
			end
		end
	end

	-- brown cover keeps a margin off the fields and the lanes: read the cover alone just outside their edges
	local cover = {}
	for _, op in ops do
		if op.feature == "patch" then
			table.insert(cover, op)
		end
	end
	local readCover = surfaceReader(cover)
	for _, r in rects do
		if r.kind == "field" then
			for _, d in { 1.5, 4 } do
				for t = -r.half.X, r.half.X, 3 do
					for _, side in { -1, 1 } do
						local a = (r.cf * CFrame.new(t, 0, side * (r.half.Y + d))).Position
						local m = readCover(a.X, a.Z)
						if BROWN[m] then
							add("brown cover beside a field")
						end
					end
				end
			end
		end
	end
	for _, lane in WorldGround.lanes(layout) do
		for _, p in sampleLane(lane.points, 6) do
			for _, dir in { Vector2.new(1, 0), Vector2.new(-1, 0), Vector2.new(0, 1), Vector2.new(0, -1) } do
				for _, d in { 1.5, 4 } do
					local q = p + dir * (lane.width / 2 + d)
					local dist = WorldPlan.distToPolyline(q.X, q.Y, lane.points)
					if dist > lane.width / 2 + 0.5 and dist < lane.width / 2 + 4.5 and BROWN[readCover(q.X, q.Y)] then
						add("brown cover beside a lane")
					end
				end
			end
		end
	end

	-- the courts
	for _, kingdom in KINGDOMS do
		local plot = layout.plots[kingdom]
		local yard = (plot.anchors.keep * CFrame.new(0, 0, -62)).Position
		local n = 0
		for _, op in ops do
			if op.feature == "plaza" and op.material == "Cobblestone" then
				local p = op.cframe.Position
				if (p.X - yard.X) ^ 2 + (p.Z - yard.Z) ^ 2 < 40 ^ 2 then
					n += 1
					for _, r in rects do
						if (r.kind == "slot" or r.kind == "building") and WorldPlan.rectDistance(r, p.X, p.Z) < 0.5 then
							add(`{kingdom} court covers a {r.kind}`)
							break
						end
					end
				end
			end
		end
		if n < 3 then
			add(`{kingdom} has no cobbled court`)
		end
	end
	local roads = layout.features.roads
	local hub = roads[1].points[#roads[1].points]
	for _, op in ops do
		if op.feature == "plaza" and op.kind == "Cylinder" then
			local p = op.cframe.Position
			local d = math.sqrt((p.X - hub.X) ^ 2 + (p.Z - hub.Y) ^ 2)
			if d < 30 and d + op.radius > 14.01 then
				add("the hub plaza reaches past 14 studs")
				break
			end
		end
	end
	return why
end

local function has(why: { string }, needle: string): boolean
	for _, s in why do
		if string.find(s, needle, 1, true) then
			return true
		end
	end
	return false
end

-- ---------------------------------------------------------------- the plan

describe("WorldGround: the ground plan", function()
	it("is deterministic and legal", function()
		local floors = WorldPlan.forestFloors(Layout)
		local a = WorldGround.cover(Layout, api(), floors)
		local b = WorldGround.cover(Layout, api(), table.clone(floors)) -- another table: not the cache
		expect(#a).toBe(#b)
		expect(#a).toBeGreaterThan(100)
		for i = 1, #a do
			expect(a[i].material).toBe(b[i].material)
			expect((a[i].cframe.Position - b[i].cframe.Position).Magnitude).toBeLessThan(1e-6)
			expect((a[i].size - b[i].size).Magnitude).toBeLessThan(1e-6)
		end
		for _, name in { "aprons", "worn", "border" } do
			local x, y = WorldGround[name](Layout, api()), WorldGround[name](Layout, api())
			expect(#x).toBe(#y)
			for i = 1, #x do
				expect((x[i].cframe.Position - y[i].cframe.Position).Magnitude).toBeLessThan(1e-6)
			end
		end
	end)

	it("keeps the ground rules (varied, connected, bounded)", function()
		local why = violations(Layout, WorldPlan.terrainOps(Layout))
		expect(table.concat(why, "; ")).toBe("")
	end)

	it("leaves the base, hills, forest floors, fields and river as they were", function()
		local counts = {}
		for _, op in WorldPlan.terrainOps(Layout) do
			counts[op.feature] = (counts[op.feature] or 0) + 1
		end
		expect(counts.ground).toBe(36)
		expect(counts.hill).toBe(112)
		expect(counts.forest_floor).toBe(10)
		expect(counts.field).toBe(12)
		expect(counts.river).toBe(14)
		expect(counts.river_bank).toBe(7)
	end)

	it("draws cover as whole voxel layers (top at groundY, aligned to the 4-stud grid)", function()
		for _, op in WorldGround.cover(Layout, api(), WorldPlan.forestFloors(Layout)) do
			local p, s = op.cframe.Position, op.size
			expect(s.Y).toBe(4)
			expect(p.Y + s.Y / 2).toBe(Layout.features.groundY or 0)
			expect((p.X - s.X / 2) % 4).toBe(0)
			expect((p.Z - s.Z / 2) % 4).toBe(0)
		end
	end)

	it("keeps cover off forest-floor cores and the river", function()
		local floors = WorldPlan.forestFloors(Layout)
		local f = Layout.features
		for _, op in WorldGround.cover(Layout, api(), floors) do
			local p, s = op.cframe.Position, op.size
			for x = p.X - s.X / 2 + 2, p.X + s.X / 2, 4 do
				for z = p.Z - s.Z / 2 + 2, p.Z + s.Z / 2, 4 do
					-- the sampler decides at a cell's centre, or far from the plots for a 2 x 2 group at its middle (up to 5.7 studs off)
					expect(WorldPlan.distToPolyline(x, z, f.river.points)).toBeGreaterThan(f.river.width / 2 + 4)
					for _, fl in floors do
						expect(math.sqrt((x - fl.x) ^ 2 + (z - fl.z) ^ 2) >= fl.r * 0.78 - 6).toBe(true)
					end
				end
			end
		end
	end)

	it("builds the terrain in frames of at most TERRAIN_OPS_PER_FRAME fills (thousands of small calls)", function()
		local env = MockEnv.new({ seed = 1 })
		local svc = WorldDef.new(env, nil)
		svc.terrain = Terrain.recorder()
		local fills, worst, total = 0, 0, 0
		local fill = svc.terrain.fill
		svc.terrain.fill = function(op)
			fills += 1
			total += 1
			fill(op)
		end
		local wait = svc._wait
		svc._wait = function(self)
			worst = math.max(worst, fills)
			fills = 0
			wait(self)
		end
		svc:start()
		env.mock:advance(60)
		expect(svc:isReady()).toBe(true)
		expect(total).toBe(#WorldPlan.terrainOps(Layout))
		expect(worst).toBeGreaterThan(0)
		expect(worst).toBeLessThanOrEqual(svc.TERRAIN_OPS_PER_FRAME)
		svc:destroy()
	end)

	it("adds lanes that are not roads (the sim's no-build ground is unchanged)", function()
		expect(#Layout.features.roads).toBe(12)
		expect(#Layout.features.paths).toBe(#LANES * 4)
		for _, path in Layout.features.paths do
			expect(path.width).toBeGreaterThanOrEqual(6)
			expect(#path.points).toBeGreaterThanOrEqual(2)
		end
	end)
end)

-- ---------------------------------------------------------------- mutants

describe("WorldGround: the checks catch each way of breaking the rule (mutants)", function()
	local ops = WorldPlan.terrainOps(Layout)

	local function without(feature: string)
		local out = {}
		for _, op in ops do
			if op.feature ~= feature then
				table.insert(out, op)
			end
		end
		return out
	end

	local function withLayout(mutate)
		local layout = table.clone(Layout)
		layout.features = table.clone(Layout.features)
		mutate(layout.features)
		return layout
	end

	it("flags a flat lawn (no cover)", function()
		local plain = {}
		for _, op in ops do
			if op.feature ~= "patch" and op.feature ~= "apron" and op.feature ~= "path" then
				table.insert(plain, op)
			end
		end
		local why = violations(Layout, plain)
		expect(has(why, "covers")).toBe(true)
	end)

	it("flags one material taking over a frame", function()
		local flat = table.clone(ops)
		local sp = Layout.plots.crimson.spawn.Position
		table.insert(flat, {
			kind = "Cylinder",
			material = "LeafyGrass",
			cframe = CFrame.new(sp.X, -1, sp.Z),
			radius = FRAME + 20,
			height = 2.4,
			feature = "patch",
		})
		expect(has(violations(Layout, flat), "crimson: LeafyGrass covers")).toBe(true)
	end)

	it("flags a kingdom without its lanes and a place off every road", function()
		local layout = withLayout(function(f)
			local kept = {}
			for _, path in f.paths do
				if
					not (
						path.kingdom == "azure"
						and (path.name == "lumbercamp" or path.name == "lumber_slot" or path.name == "timber")
					)
				then
					table.insert(kept, path)
				end
			end
			f.paths = kept
		end)
		local why = violations(layout, ops)
		expect(has(why, "azure has no lumbercamp lane")).toBe(true)
		expect(has(why, "azure lumbercamp is")).toBe(true)
	end)

	it("flags a lane over a field, a slot and a building", function()
		local plot = Layout.plots.crimson
		local slot = plot.buildSlots[1].center
		local field = Layout.features.fields[1].center
		local keep = plot.anchors.keep.Position
		local layout = withLayout(function(f)
			f.paths = table.clone(f.paths)
			for i, target in { slot, Vector2.new(field.X, field.Y), keep } do
				local x, z = target.X, target.Z or target.Y
				table.insert(f.paths, {
					kingdom = "crimson",
					name = `bad{i}`,
					width = 6,
					points = { Vector2.new(x - 6, z), Vector2.new(x + 6, z) },
				})
			end
		end)
		local why = violations(layout, ops)
		expect(has(why, "runs over a slot")).toBe(true)
		expect(has(why, "runs over a field")).toBe(true)
		expect(has(why, "runs over a building")).toBe(true)
	end)

	it("flags a lane that is also a road", function()
		local layout = withLayout(function(f)
			f.roads = table.clone(f.roads)
			table.insert(f.roads, f.paths[1])
		end)
		expect(has(violations(layout, ops), "is also a road")).toBe(true)
	end)

	it("flags a start frame that is mostly dirt or mostly paving", function()
		local sp = Layout.plots.crimson.spawn.Position
		local mud = table.clone(ops)
		table.insert(mud, {
			kind = "Cylinder",
			material = "Ground",
			cframe = CFrame.new(sp.X, -1, sp.Z - 60),
			radius = 90,
			height = 2.4,
			feature = "patch",
		})
		expect(has(violations(Layout, mud), "start frame crimson (screen):")).toBe(true)
		expect(has(violations(Layout, mud), "brown")).toBe(true)
		local paved = table.clone(ops)
		table.insert(paved, {
			kind = "Cylinder",
			material = "Cobblestone",
			cframe = CFrame.new(sp.X, -1, sp.Z - 40),
			radius = 60,
			height = 2.4,
			feature = "plaza",
		})
		expect(has(violations(Layout, paved), "grey")).toBe(true)
		local bare = table.clone(ops)
		table.insert(bare, {
			kind = "Cylinder",
			material = "Sand",
			cframe = CFrame.new(sp.X, -1, sp.Z - 60),
			radius = 120,
			height = 2.4,
			feature = "patch",
		})
		expect(has(violations(Layout, bare), "green")).toBe(true)
	end)

	it("flags brown cover on the edge of a field and of a lane", function()
		local field = Layout.features.fields[1]
		local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
		local edge = (cf * CFrame.new(0, 0, field.size.Y / 2 + 2.5)).Position
		local bad = table.clone(ops)
		table.insert(bad, {
			kind = "Cylinder",
			material = "Mud",
			cframe = CFrame.new(edge.X, -1, edge.Z),
			radius = 5,
			height = 2.4,
			feature = "patch",
		})
		expect(has(violations(Layout, bad), "brown cover beside a field")).toBe(true)
		local lane = Layout.features.paths[2]
		local mid = (lane.points[1] + lane.points[2]) / 2
		local across = (lane.points[2] - lane.points[1]).Unit
		local at = mid + Vector2.new(-across.Y, across.X) * (lane.width / 2 + 2.5)
		local bad2 = table.clone(ops)
		table.insert(bad2, {
			kind = "Cylinder",
			material = "Ground",
			cframe = CFrame.new(at.X, -1, at.Y),
			radius = 4,
			height = 2.4,
			feature = "patch",
		})
		expect(has(violations(Layout, bad2), "brown cover beside a lane")).toBe(true)
	end)

	it("flags a court over a slot and a hub plaza that grew", function()
		local plot = Layout.plots.crimson
		local slotAt = plot.buildSlots[1].center
		local bad = table.clone(ops)
		table.insert(bad, {
			kind = "Cylinder",
			material = "Cobblestone",
			cframe = CFrame.new(slotAt.X, -1, slotAt.Z),
			radius = 6,
			height = 2.4,
			feature = "plaza",
		})
		expect(has(violations(Layout, bad), "court covers a slot")).toBe(true)
		local roads = Layout.features.roads
		local hub = roads[1].points[#roads[1].points]
		local big = table.clone(ops)
		table.insert(big, {
			kind = "Cylinder",
			material = "Cobblestone",
			cframe = CFrame.new(hub.X, -1, hub.Y),
			radius = 16,
			height = 2.4,
			feature = "plaza",
		})
		expect(has(violations(Layout, big), "hub plaza")).toBe(true)
		expect(has(violations(Layout, without("plaza")), "no cobbled court")).toBe(true)
	end)

	it("flags ground ops over the ceilings", function()
		local many = table.clone(ops)
		for i = 1, ADDED_OPS do
			table.insert(many, ops[#ops - (i % 20)])
		end
		for i = 1, ADDED_OPS do
			table.insert(many, {
				kind = "Cylinder",
				material = "Ground",
				cframe = CFrame.new(i, -1, 0),
				radius = 4,
				height = 2.4,
				feature = "patch",
			})
		end
		expect(has(violations(Layout, many), "ground ops")).toBe(true)
		local fat = table.clone(ops)
		table.insert(fat, {
			kind = "Block",
			material = "Ground",
			cframe = CFrame.new(0, -2, 0),
			size = Vector3.new(500, 40, 500),
			feature = "patch",
		})
		expect(has(violations(Layout, fat), "ground voxels")).toBe(true)
	end)
end)
