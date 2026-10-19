--[[
	World preview dump (FL-0055). Exports what WorldService builds — a heightfield with surface
	materials (from WorldPlan.groundHeight and the Layout features), every prop placement, and the
	starting buildings BuildingService places at the plot anchors (Kit.build) plus the watchtower — so
	blender/scripts/render_world.py can render a top-down view and oblique views (D-019 review).

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

local KINGDOM_COLORS = {
	crimson = Color3.fromRGB(190, 40, 50),
	azure = Color3.fromRGB(40, 110, 210),
	emerald = Color3.fromRGB(35, 128, 95),
	gold = Color3.fromRGB(235, 185, 16),
}
local STEP = 6

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

local function surfaceMaterial(x: number, z: number, h: number): string
	local f = Layout.features
	local dr = WorldPlan.distToPolyline(x, z, f.river.points)
	if dr < f.river.width / 2 then
		return "Water"
	elseif dr < f.river.width / 2 + 6 then
		return "Sand"
	end
	for _, road in f.roads do
		if WorldPlan.distToPolyline(x, z, road.points) < road.width / 2 then
			return "Ground"
		end
	end
	for _, field in f.fields do
		local yaw = field.yaw or 0
		local dx, dz = x - field.center.X, z - field.center.Y
		local lx, lz = dx * math.cos(yaw) - dz * math.sin(yaw), dx * math.sin(yaw) + dz * math.cos(yaw)
		if math.abs(lx) < field.size.X / 2 and math.abs(lz) < field.size.Y / 2 then
			return "Mud"
		end
	end
	if h > 52 then
		return "Rock"
	end
	-- the same leafy floors WorldService fills (they follow the trim; FORGE_WORLD_UNTRIMMED=1: today's discs)
	local floors = WorldPlan.forestFloors(Layout, if UNTRIMMED then WorldPlan.FULL_DENSITY else nil)
	for _, floor in floors do
		if (x - floor.x) ^ 2 + (z - floor.z) ^ 2 < floor.r ^ 2 then
			return "LeafyGrass"
		end
	end
	return "Grass"
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
				out[k] = { keep = cf12(plot.anchors.keep), spawn = cf12(plot.spawn) }
			end
			return out
		end)(),
		objective = cf12(o.cframe),
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
end)
