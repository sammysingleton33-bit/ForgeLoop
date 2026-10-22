--[[
	World preview dump (FL-0055). Exports what WorldService builds — a heightfield with surface
	materials (from WorldPlan.groundHeight and the Layout features), every prop placement, and the
	starting buildings BuildingService places at the plot anchors (Kit.build) plus the watchtower — so
	blender/scripts/render_world.py can render a top-down view and oblique views (D-019 review).

	The surface materials are read from WorldPlan.terrainOps themselves (the last op that covers a point decides, as in the game), so
	a new terrain feature shows in the preview without a second copy of its rules. The dump also carries the world/Lighting preset
	(`lighting`) for the preview's sun, haze and colour grade, and citizens at work around the plots (FORGE_WORLD_CITIZENS=sim, the default, is the sim's real start (30 s, seed 11: support/StartCitizens); 12 is the start of a kingdom as a ring set
	(config/Kingdoms.luau: farmer 3, woodcutter 3, miner 2, builder 2, hauler 2); 40 is a mid-game kingdom; 0 leaves them out) so the views at the default gameplay camera show how readable they are. FORGE_WORLD_STEP=<studs> sets the heightfield grid
	(6 by default; 3 for the camera views).

	Always: asserts the dump is consistent. With FORGE_WORLD_DUMP=<path.json>: writes it.
	  FORGE_WORLD_DUMP=/tmp/world.json lune run roblox/tests/harness/run.luau \
	    --project games/game-001/default.project.json --specs games/game-001/tests/world WorldDump
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local StartView = require("./support/StartView")
local LightingPreset = require("@game/ReplicatedStorage/Game/World/Lighting")
local StartCitizens = require("./support/StartCitizens")

local KINGDOM_COLORS = {
	crimson = Color3.fromRGB(190, 40, 50),
	azure = Color3.fromRGB(40, 110, 210),
	emerald = Color3.fromRGB(35, 128, 95),
	gold = Color3.fromRGB(235, 185, 16),
}
local STEP = tonumber(process.env.FORGE_WORLD_STEP or "") or 6

local function r3(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function cf12(cf: CFrame): { number }
	local c = { cf:GetComponents() }
	for i, v in c do
		c[i] = r3(v)
	end
	return c
end

local function partsOf(model: Instance)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			table.insert(out, {
				name = d.Name,
				class = d.ClassName,
				shape = if d:IsA("Part") then (d :: Part).Shape.Name else d.ClassName,
				size = { r3(d.Size.X), r3(d.Size.Y), r3(d.Size.Z) },
				cframe = cf12(d.CFrame),
				color = { r3(d.Color.R), r3(d.Color.G), r3(d.Color.B) },
				material = d.Material.Name,
				transparency = d.Transparency,
			})
		end
	end
	return out
end

-- FORGE_WORLD_UNTRIMMED=1 dumps the generator's own plan (no clearance, no trim): the "before" of the D-047 trim
local UNTRIMMED = process.env.FORGE_WORLD_UNTRIMMED == "1"

-- The surface material at (x, z): the terrain ops run in order and the last one that covers the point decides (a Block or a Cylinder
-- covers what lies inside its footprint, a Ball what its cap covers at ground level; Air only carves, Water is the river). This is
-- the game's own plan, so the preview shows every feature the plan has.
type OpReach = { op: any, cx: number, cz: number, reach: number }
local OPS: { OpReach } = {}
do
	local gy = Layout.features.groundY or 0
	for _, op in WorldPlan.terrainOps(Layout, if UNTRIMMED then WorldPlan.FULL_DENSITY else nil) do
		if op.material ~= "Air" then
			local p = op.cframe.Position
			local reach = 0
			if op.kind == "Block" then
				local sz = op.size :: Vector3
				reach = math.sqrt(sz.X * sz.X + sz.Z * sz.Z) / 2
			elseif op.kind == "Ball" then
				local dy = gy - p.Y
				reach = math.sqrt(math.max(0, (op.radius :: number) ^ 2 - dy * dy))
				op = { kind = "Disc", material = op.material, cframe = op.cframe, radius = reach }
			else
				reach = op.radius :: number
			end
			table.insert(OPS, { op = op, cx = p.X, cz = p.Z, reach = reach })
		end
	end
end

local function covers(o: OpReach, x: number, z: number): boolean
	local dx, dz = x - o.cx, z - o.cz
	if dx * dx + dz * dz > o.reach * o.reach then
		return false
	end
	local op = o.op
	if op.kind == "Block" then
		local l = op.cframe:PointToObjectSpace(Vector3.new(x, op.cframe.Position.Y, z))
		local sz = op.size :: Vector3
		return math.abs(l.X) <= sz.X / 2 and math.abs(l.Z) <= sz.Z / 2
	end
	return true -- a disc (ball cap) or a cylinder: inside its radius, which the reach test above already settled
end

-- The ops are bucketed on a grid (BUCKET studs), each bucket holding the ops that reach it in plan order, so a point only tests
-- its own bucket (the plan has thousands of ops; every heightfield point used to test them all).
local BUCKET = 48
local BUCKETS: { [number]: { OpReach } } = {}
local function bucketKey(bx: number, bz: number): number
	return bz * 4096 + bx
end
for _, o in OPS do
	for bz = math.floor((o.cz - o.reach) / BUCKET), math.floor((o.cz + o.reach) / BUCKET) do
		for bx = math.floor((o.cx - o.reach) / BUCKET), math.floor((o.cx + o.reach) / BUCKET) do
			local key = bucketKey(bx, bz)
			local list = BUCKETS[key]
			if not list then
				list = {}
				BUCKETS[key] = list
			end
			table.insert(list, o)
		end
	end
end

local function surfaceMaterial(x: number, z: number, _h: number): string
	local found = "Grass"
	local list = BUCKETS[bucketKey(math.floor(x / BUCKET), math.floor(z / BUCKET))]
	if list then
		for _, o in list do
			if covers(o, x, z) then
				found = o.op.material
			end
		end
	end
	return found
end

-- world/Lighting as plain JSON (Color3 -> { r, g, b } 0..255): the preview's sun, haze and colour grade follow it
local function plain(v: any): any
	if typeof(v) == "Color3" then
		return { math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5) }
	elseif type(v) == "table" then
		local out = {}
		for k, x in v do
			out[k] = plain(x)
		end
		return out
	end
	return v
end

-- Citizens at work around a plot, for the default-camera views: { job, anchor, how many, ring radius } per kingdom. "12" is the
-- start of a kingdom (config/Kingdoms.luau: farmer 3, woodcutter 3, miner 2, builder 2, hauler 2: the first view the owner judges),
-- "40" a mid-game kingdom. Farmers stand at the crop fields, woodcutters at the lumber camp, miners at the quarry, haulers at the
-- storehouse, builders and idle ones in the keep's yard. Deterministic (the golden angle, never random).
local CITIZEN_SETS = {
	["12"] = {
		{ "farmer", "farm", 3, 12 },
		{ "woodcutter", "lumbercamp", 3, 10 },
		{ "miner", "quarry", 2, 10 },
		{ "builder", "keep", 2, 26 },
		{ "hauler", "storehouse", 2, 12 },
	},
	["40"] = {
		{ "farmer", "farm", 9, 16 },
		{ "woodcutter", "lumbercamp", 8, 14 },
		{ "miner", "quarry", 6, 12 },
		{ "builder", "keep", 6, 28 },
		{ "hauler", "storehouse", 6, 16 },
		{ "idle", "keep", 5, 22 },
	},
}

-- The real start: FORGE-04's sim, seed 11, 30 s after the start (support/StartCitizens): every row is a citizen on its work slot or
-- walking the navigation graph, at the sim's own position and yaw (farmers stand in the farm's fields, woodcutters at the trees, ...
-- so no clearance search is wanted: a part-footprint test puts 9 of 52 rows "inside" the farms, which is where farmers work). Poses
-- stay the rest pose (the job's tool in the fist); "carry" rows (gold's hauler only) are drawn as "walk" until Kit.carried lands.
local function citizensFromSim(kingdom: string, color: Color3, assets: any, placements: any)
	for _, row in StartCitizens.rows() do
		if row[1] == kingdom then
			local job: string = row[2]
			local id = `citizen_{job}_{kingdom}`
			if not assets[id] then
				assets[id] = partsOf(Kit.character("citizen", job, color))
			end
			local x, z = row[3], row[4]
			local cf = CFrame.new(x, WorldPlan.groundHeight(Layout, x, z), z) * CFrame.Angles(0, row[5], 0)
			table.insert(placements, { assetId = id, cframe = cf12(cf), feature = "citizen" })
		end
	end
end

local function citizensAround(set: string, kingdom: string, color: Color3, assets: any, placements: any)
	local plot = Layout.plots[kingdom]
	local n = 0
	for _, job in CITIZEN_SETS[set] do
		local anchor = plot.anchors[job[2]]
		if anchor then
			local id = `citizen_{job[1]}_{kingdom}`
			if not assets[id] then
				assets[id] = partsOf(Kit.character("citizen", job[1], color))
			end
			for _ = 1, job[3] do
				n += 1
				local angle = (n * 2.39996) % (2 * math.pi) -- the golden angle: spread, never lined up
				local reach = job[4] * (0.55 + 0.45 * ((n * 7) % 5) / 4)
				local p = anchor.Position + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
				local y = WorldPlan.groundHeight(Layout, p.X, p.Z)
				local cf = CFrame.new(p.X, y, p.Z) * CFrame.Angles(0, (n * 1.7) % (2 * math.pi), 0)
				table.insert(placements, { assetId = id, cframe = cf12(cf), feature = "citizen" })
			end
		end
	end
end

local function dump()
	local f = Layout.features
	local x0, z0 = f.bounds.min.X, f.bounds.min.Y
	local nx = math.floor((f.bounds.max.X - x0) / STEP) + 1
	local nz = math.floor((f.bounds.max.Y - z0) / STEP) + 1
	local heights, materials = {}, {}
	for j = 0, nz - 1 do
		for i = 0, nx - 1 do
			local x, z = x0 + i * STEP, z0 + j * STEP
			local h = WorldPlan.groundHeight(Layout, x, z)
			table.insert(heights, r3(h))
			table.insert(materials, surfaceMaterial(x, z, h))
		end
	end
	local assets = {}
	local placements = {}
	local planned = if UNTRIMMED
		then WorldPlan.plan(Layout, { crimson = true })
		else WorldPlan.props(Layout, { crimson = true })
	for _, p in planned do
		if not assets[p.assetId] then
			assets[p.assetId] = partsOf(Kit.prop(p.assetId))
		end
		table.insert(placements, { assetId = p.assetId, cframe = cf12(p.cframe), feature = p.feature })
	end
	for _, node in Layout.resourceNodes do
		if not assets[node.assetId] then
			assets[node.assetId] = partsOf(Kit.prop(node.assetId))
		end
		local pos = node.cframe.Position
		local y = WorldPlan.groundHeight(Layout, pos.X, pos.Z)
		local cf = CFrame.new(pos.X, y, pos.Z) * (node.cframe - pos)
		table.insert(placements, { assetId = node.assetId, cframe = cf12(cf), feature = "resource" })
	end
	-- starting buildings (BuildingService, G6) and the neutral watchtower (ObjectiveService), for preview
	for kingdom, color in KINGDOM_COLORS do
		for _, bt in { "keep", "storehouse", "farm", "lumbercamp", "quarry" } do
			local id = `{bt}_{kingdom}`
			assets[id] = partsOf(Kit.build(bt, 1, "complete", color))
			table.insert(
				placements,
				{ assetId = id, cframe = cf12(Layout.plots[kingdom].anchors[bt]), feature = "building" }
			)
		end
	end
	local citizenSet = process.env.FORGE_WORLD_CITIZENS or "sim"
	if citizenSet == "sim" then
		for kingdom, color in KINGDOM_COLORS do
			citizensFromSim(kingdom, color, assets, placements)
		end
	elseif CITIZEN_SETS[citizenSet] then
		for kingdom, color in KINGDOM_COLORS do
			citizensAround(citizenSet, kingdom, color, assets, placements)
		end
	end
	-- build slot markers (WorldService, G13.5) and, on crimson, a few slots built up to preview a grown town
	local SAMPLE = { [1] = { "house", 1 }, [2] = { "house", 2 }, [3] = { "house", 1 }, [5] = { "barracks", 2 } }
	for kingdom, color in KINGDOM_COLORS do
		for i, slot in Layout.plots[kingdom].buildSlots do
			local size = Layout.slotSizes[slot.size]
			local id = `slot_{slot.size}_{kingdom}`
			if not assets[id] then
				assets[id] = partsOf(Kit.slotMarker(size, color))
			end
			local y = WorldPlan.groundHeight(Layout, slot.center.X, slot.center.Z)
			local cf = CFrame.new(slot.center.X, y, slot.center.Z) * CFrame.Angles(0, slot.rot, 0)
			table.insert(placements, { assetId = id, cframe = cf12(cf), feature = "slot" })
			local sample = SAMPLE[i]
			if kingdom == "crimson" and sample then
				local bid = `{sample[1]}{sample[2]}_{kingdom}_{i}`
				assets[bid] = partsOf(Kit.build(sample[1], sample[2], "complete", color, i))
				table.insert(placements, { assetId = bid, cframe = cf12(cf), feature = "slot_building" })
			end
		end
	end
	assets.watchtower_neutral = partsOf(Kit.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR))
	-- the neutral tower of every objective (FORGE-01's ObjectiveService builds them in the game: the watchtower and, since
	-- FL-0127, the three outposts; the preview shows them all)
	for _, obj in Layout.objectives do
		local op = obj.cframe.Position
		local ty = WorldPlan.groundHeight(Layout, op.X, op.Z)
		table.insert(placements, {
			assetId = "watchtower_neutral",
			cframe = cf12(CFrame.new(op.X, ty, op.Z) * (obj.cframe - op)),
			feature = "objective",
		})
	end
	local o = Layout.objectives[1]
	-- the Crown Arena (WorldService builds it neutral; the preview dresses it for crimson against azure, as at the Arena phase,
	-- unless FORGE_WORLD_ARENA=neutral)
	local arena = Layout.arena
	if arena then
		local neutral = process.env.FORGE_WORLD_ARENA == "neutral"
		assets.crown_arena =
			partsOf(if neutral then Kit.arena() else Kit.arena(KINGDOM_COLORS.crimson, KINGDOM_COLORS.azure))
		local ap = arena.cframe.Position
		local ay = WorldPlan.groundHeight(Layout, ap.X, ap.Z)
		table.insert(placements, {
			assetId = "crown_arena",
			cframe = cf12(CFrame.new(ap.X, ay, ap.Z) * (arena.cframe - ap)),
			feature = "arena",
		})
	end
	return {
		heightfield = { x0 = x0, z0 = z0, step = STEP, nx = nx, nz = nz, heights = heights, materials = materials },
		waterY = -1.4,
		assets = assets,
		placements = placements,
		plots = (function()
			local out = {}
			for k, plot in Layout.plots do
				out[k] = {
					keep = cf12(plot.anchors.keep),
					spawn = cf12(plot.spawn),
					throne = cf12(StartView.root(Kit, Layout, k)),
				}
			end
			return out
		end)(),
		objective = cf12(o.cframe),
		lighting = plain(LightingPreset),
	}
end

describe("World preview dump", function()
	it("exports a consistent heightfield, placements and assets", function()
		local d = dump()
		local hf = d.heightfield
		expect(#hf.heights).toBe(hf.nx * hf.nz)
		expect(#hf.materials).toBe(hf.nx * hf.nz)
		local nAssets = 0
		for _ in d.assets do
			nAssets += 1
		end
		expect(nAssets).toBeGreaterThan(20)
		for _, p in d.placements do
			expect(d.assets[p.assetId]).never.toBeNil()
		end
		local out = process.env.FORGE_WORLD_DUMP
		if out and out ~= "" then
			fs.writeFile(out, serde.encode("json", d, false))
			print(`world dump: {#d.placements} placements, {nAssets} assets, {hf.nx}x{hf.nz} heightfield -> {out}`)
		end
	end)
	it("stands the sim's citizens (13 per kingdom, the five citizen jobs) at its own positions", function()
		local d = dump()
		if process.env.FORGE_WORLD_CITIZENS ~= nil and process.env.FORGE_WORLD_CITIZENS ~= "sim" then
			return
		end
		local perKingdom, jobs = {}, { farmer = true, woodcutter = true, miner = true, builder = true, hauler = true }
		for _, p in d.placements do
			if p.feature == "citizen" then
				local job, kingdom = string.match(p.assetId, "^citizen_(%a+)_(%a+)$")
				expect(jobs[job]).toBe(true)
				perKingdom[kingdom] = (perKingdom[kingdom] or 0) + 1
			end
		end
		for _, kingdom in { "crimson", "azure", "emerald", "gold" } do
			expect(perKingdom[kingdom]).toBe(13)
		end
	end)
end)
