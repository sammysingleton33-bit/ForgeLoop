--[[
	FL-0136 phase 3 (A): how much room does each resource node have? Measured on the REAL world layout (world/Layout, WorldPlan.props at the shipped
	density, the shipped starting buildings), for the part-built stand-in and for the imported mesh (K's runtime + Kit/EnvMeshData with the fake import
	models of fixture EnvMeshKit). Per node: drawn reach (the NodeKeepOut measure: horizontal reach of what Kit.prop draws around its pivot), the largest
	reach the keep-out rules (fields, zones, slots 8 studs; starting buildings 5 studs) would still allow, the nearest decor placement and the nearest other
	node (gap between outlines), and the work spots (Layout.workSpots, 5 studs from the pivot) against the drawn outline.

	  FORGE_ENV_NODEFIT=/tmp/env_nodefit.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune EnvNodeFit

	Output JSON: { nodes = { { id, assetId, resource, x, z, standin = { reach, size }, mesh = { reach, size }, allowed, limit, decor = { gap, id }, node = { gap, id },
	               spots = { distMin, distMax } } }, gap = 8, buildingGap = 5 }.
]]

local T = require("../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local EnvMesh = require("@game/ReplicatedStorage/Game/Kit/EnvMesh")
local Data = require("@game/ReplicatedStorage/Game/Kit/EnvMeshData")
local EnvKit = require("../../../games/game-001/tests/world/fixtures/EnvMeshKit")

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local GAP = 8 -- NodeKeepOut.spec: open ground between a drawn extent and a field, zone or slot
local BUILDING_GAP = 5 -- ... and a starting building's largest footprint
local STARTING = { "storehouse", "farm", "lumbercamp", "quarry" }

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- the areas NodeKeepOut.spec guards: { name, shape, gap }
local function areas(): { { name: string, shape: any, gap: number } }
	local out = {}
	for i, field in Layout.features.fields do
		table.insert(
			out,
			{ name = `field {i}`, shape = Footprint.rect(field.size, field.center.X, field.center.Y, field.yaw), gap = GAP }
		)
	end
	for _, kid in KINGDOMS do
		local plot = Layout.plots[kid]
		local yaw = yawOf(plot.anchors.keep)
		for _, zone in plot.buildZones do
			table.insert(
				out,
				{ name = zone.id, shape = Footprint.rect(zone.size, zone.center.X, zone.center.Z, yaw), gap = GAP }
			)
		end
		for _, slot in plot.buildSlots do
			table.insert(out, {
				name = slot.id,
				shape = Footprint.rect(Layout.slotSizes[slot.size], slot.center.X, slot.center.Z, slot.rot),
				gap = GAP,
			})
		end
		for _, name in STARTING do
			local anchor = plot.anchors[name]
			table.insert(out, {
				name = `{kid} {name}`,
				shape = Footprint.rect(Kit.footprint(name, 9), anchor.Position.X, anchor.Position.Z, yawOf(anchor)),
				gap = BUILDING_GAP,
			})
		end
	end
	return out
end

-- studs from (x, z) to the nearest point of a rectangle (0 inside)
local function distTo(shape: any, x: number, z: number): number
	local dx, dz = x - shape.x, z - shape.z
	local lx, lz = dx * shape.ux + dz * shape.uz, -dx * shape.uz + dz * shape.ux
	local ox, oz = math.max(math.abs(lx) - shape.hx, 0), math.max(math.abs(lz) - shape.hz, 0)
	return math.sqrt(ox * ox + oz * oz)
end

-- the NodeKeepOut measure, plus the drawn size (visible parts) in the pivot frame
local function drawn(assetId: string): (number, Vector3)
	local model = Kit.prop(assetId)
	local primary = model.PrimaryPart :: BasePart
	local toLocal = (primary.CFrame * primary.PivotOffset):Inverse()
	local reach = 0
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = toLocal * d.CFrame
			if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
				local c = cf.Position
				reach = math.max(reach, math.sqrt(c.X * c.X + c.Z * c.Z) + d.Size.X / 2)
			else
				local h = d.Size / 2
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = cf * Vector3.new(sx * h.X, 0, sz * h.Z)
						reach = math.max(reach, math.sqrt(w.X * w.X + w.Z * w.Z))
					end
				end
			end
			if d.Transparency < 0.99 then
				local h = d.Size / 2
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local w = cf * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
							mn, mx = mn:Min(w), mx:Max(w)
						end
					end
				end
			end
		end
	end
	model:Destroy()
	return reach, mx - mn
end

local function round(v: number): number
	return math.floor(v * 100 + 0.5) / 100
end

describe("FL-0136 phase 3: resource node room", function()
	it("measures every node's drawn reach, keep-out slack, decor and node neighbours, standin and mesh", function()
		local list = areas()
		local placements = WorldPlan.props(Layout, { crimson = true }, nil) -- what WorldService places (shipped density)
		local reachOf: { [string]: { standin: number, mesh: number } } = {}
		local function both(assetId: string): { standin: number, mesh: number }
			local r = reachOf[assetId]
			if r == nil then
				EnvKit.uninstall()
				local a = drawn(assetId)
				EnvKit.install(Data, EnvKit.assets(Data, { folder = true }))
				local b = drawn(assetId)
				EnvKit.uninstall()
				r = { standin = a, mesh = b }
				reachOf[assetId] = r
			end
			return r
		end
		local out = {}
		for _, n in Layout.resourceNodes do
			local p = n.cframe.Position
			local r = both(n.assetId)
			-- the stand-in's and the mesh's drawn size
			EnvKit.uninstall()
			local _, sizeS = drawn(n.assetId)
			EnvKit.install(Data, EnvKit.assets(Data, { folder = true }))
			local _, sizeM = drawn(n.assetId)
			EnvKit.uninstall()
			local allowed, limit = math.huge, ""
			for _, a in list do
				local d = distTo(a.shape, p.X, p.Z) - a.gap
				if d < allowed then
					allowed, limit = d, a.name
				end
			end
			local decor = { gap = { standin = math.huge, mesh = math.huge }, id = "" }
			for _, pl in placements do
				local q = pl.cframe.Position
				local d = math.sqrt((q.X - p.X) ^ 2 + (q.Z - p.Z) ^ 2)
				local rq = both(pl.assetId)
				local gs, gm = d - rq.standin - r.standin, d - rq.mesh - r.mesh
				if gs < decor.gap.standin then
					decor.gap.standin, decor.id = gs, pl.assetId
				end
				decor.gap.mesh = math.min(decor.gap.mesh, gm)
			end
			local nearNode = { gap = math.huge, id = "" }
			for _, m in Layout.resourceNodes do
				if m ~= n then
					local q = m.cframe.Position
					local d = math.sqrt((q.X - p.X) ^ 2 + (q.Z - p.Z) ^ 2)
					local g = d - both(m.assetId).mesh - r.mesh
					if g < nearNode.gap then
						nearNode = { gap = g, id = m.id }
					end
				end
			end
			local dmin, dmax = math.huge, 0
			for _, s in n.workSpots do
				local d = math.sqrt((s.X - p.X) ^ 2 + (s.Z - p.Z) ^ 2)
				dmin, dmax = math.min(dmin, d), math.max(dmax, d)
			end
			table.insert(out, {
				id = n.id,
				assetId = n.assetId,
				resource = n.resource,
				x = round(p.X),
				z = round(p.Z),
				standin = { reach = round(r.standin), size = { round(sizeS.X), round(sizeS.Y), round(sizeS.Z) } },
				mesh = { reach = round(r.mesh), size = { round(sizeM.X), round(sizeM.Y), round(sizeM.Z) } },
				allowed = round(allowed),
				limit = limit,
				decor = { gap = { standin = round(decor.gap.standin), mesh = round(decor.gap.mesh) }, id = decor.id },
				node = { gap = round(nearNode.gap), id = nearNode.id },
				spots = { distMin = round(dmin), distMax = round(dmax) },
			})
		end
		expect(#out).toBe(#Layout.resourceNodes)
		local o = process.env.FORGE_ENV_NODEFIT
		if o and o ~= "" then
			fs.writeFile(o, serde.encode("json", { nodes = out, gap = GAP, buildingGap = BUILDING_GAP }, false))
			print(`nodefit: {#out} nodes -> {o}`)
		end
	end)
end)
