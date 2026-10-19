--!nonstrict
--[[
	Mesh-only dressing (FL-0136 phase 3 (B), FORGE-00 decision 2: fences, cabbage variants and cliffs as dressing within the D-047 part
	ceiling). WorldPlan.meshDressing adds, ONLY for asset ids the Kit would build as imported meshes (Kit.envMeshReady):
	  * cabbage variants: a cabbage field takes farm_field_cabbage_01..03 by its kingdom (it was always _03);
	  * fences (farm_fence_01/02) along the outside of each plot's crop fields, never the side that faces the keep or a neighbouring field;
	  * rock cliffs (rock_cliff_01/02) on the flat ground just inside the foot of the mountain ring.
	HEADLESS (Lune): fake import Models of the real kit's data; nothing here says it looks right or imports right in Studio.

	Why mesh-only: a part-built cabbage field is 65 parts, a fence 7 to 8 and a cliff 4, so as stand-ins they would add about 1,000 parts to a
	world that sits at the D-047 ceiling, while as meshes they cost 2 to 3 parts each (Root, Body and, for fences and cliffs, the Collider); and the
	world without the imported kit (today's, every Lune spec, a Studio place before the import) must stay exactly what it is, pins included.

	The checks below are written independently of the implementation (Footprint shapes from the layout, the way NodeKeepOut.spec builds them),
	and the mutants show they catch a fence on a slot, a fence on the river, a cliff on a road and so on.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local WorldDef = require("@game/ServerScriptService/Game/Services/WorldService")
local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local Data = require("@game/ReplicatedStorage/Game/Kit/EnvMeshData")
local EnvMesh = require("@game/ReplicatedStorage/Game/Kit/EnvMesh")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local EnvKit = require("./fixtures/EnvMeshKit")

afterEach(function()
	EnvKit.uninstall()
end)

local D = WorldPlan.MESH_DRESSING
local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local DRESSED = { crimson = true } -- what WorldService dresses (VS-1)
local DRESSING_IDS = {
	"farm_fence_01",
	"farm_fence_02",
	"farm_field_cabbage_01",
	"farm_field_cabbage_02",
	"rock_cliff_01",
	"rock_cliff_02",
}

local function allReady(_: string): boolean
	return true
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- the dressing a world with the kit gets: the extra and the renumbered placements, against the base list
local function dressed(density: { [string]: number }?): ({ any }, { any })
	local base = WorldPlan.props(Layout, DRESSED, density)
	return base, WorldPlan.meshDressing(Layout, base, allReady)
end

local function byFeature(list: { any }): { [string]: number }
	local out = {}
	for _, p in list do
		out[p.feature] = (out[p.feature] or 0) + 1
	end
	return out
end

local function yawKey(p: any): string
	local c = { p.cframe:GetComponents() }
	for i, v in c do
		c[i] = string.format("%.3f", v)
	end
	return `{p.assetId}@{table.concat(c, ",")}`
end

-- ---- the world's reserved ground, built the way NodeKeepOut.spec builds it (not through WorldPlan's own helpers)

local shapeCache: { { name: string, kind: string, shape: any } }? = nil
local function shapes(): { { name: string, kind: string, shape: any } }
	if shapeCache then
		return shapeCache
	end
	local out = {}
	for i, field in Layout.features.fields do
		table.insert(out, {
			name = `field {i}`,
			kind = "field",
			shape = Footprint.rect(field.size, field.center.X, field.center.Y, field.yaw),
		})
	end
	for _, kid in KINGDOMS do
		local plot = Layout.plots[kid]
		local keepYaw = yawOf(plot.anchors.keep)
		for _, zone in plot.buildZones do
			table.insert(out, {
				name = zone.id,
				kind = "zone",
				shape = Footprint.rect(zone.size, zone.center.X, zone.center.Z, keepYaw),
			})
		end
		for _, slot in plot.buildSlots do
			table.insert(out, {
				name = slot.id,
				kind = "slot",
				shape = Footprint.rect(Layout.slotSizes[slot.size], slot.center.X, slot.center.Z, slot.rot),
			})
		end
		for name, anchor in plot.anchors do
			table.insert(out, {
				name = `{kid} {name}`,
				kind = "building",
				shape = Footprint.rect(Kit.footprint(name, 9), anchor.Position.X, anchor.Position.Z, yawOf(anchor)),
			})
		end
	end
	local arena = Layout.arena
	table.insert(out, {
		name = "arena",
		kind = "arena",
		shape = Footprint.rect(arena.footprint, arena.cframe.Position.X, arena.cframe.Position.Z, 0),
	})
	shapeCache = out
	return out
end

-- why a fence placement is not legal ("" = legal): off every slot, zone, building and the arena (the fields it hugs excepted), clear of the roads
-- and the river, inside the bounds
local function fenceViolations(p: any): string
	local pos = p.cframe.Position
	local fence = Footprint.rect(Vector2.new(D.fenceLength, 2 * D.fenceHalfWidth), pos.X, pos.Z, yawOf(p.cframe))
	for _, area in shapes() do
		if area.kind ~= "field" and Footprint.overlaps(fence, area.shape, 0.1) then
			return `a fence at ({math.floor(pos.X)}, {math.floor(pos.Z)}) touches {area.name}`
		end
	end
	local f = Layout.features
	for t = -2, 2 do
		local x = pos.X + math.cos(-yawOf(p.cframe)) * t * D.fenceLength / 4
		local z = pos.Z + math.sin(-yawOf(p.cframe)) * t * D.fenceLength / 4
		if WorldPlan.distToPolyline(x, z, f.river.points) < f.river.width / 2 then
			return `a fence at ({math.floor(x)}, {math.floor(z)}) is in the river`
		end
		for _, road in f.roads do
			if WorldPlan.distToPolyline(x, z, road.points) < road.width / 2 + D.fenceHalfWidth then
				return `a fence at ({math.floor(x)}, {math.floor(z)}) is on a road`
			end
		end
		if x < f.bounds.min.X or x > f.bounds.max.X or z < f.bounds.min.Y or z > f.bounds.max.Y then
			return "a fence is outside the valley"
		end
	end
	return ""
end

-- the distance from a point to the nearest crop field's edge
local function fieldGap(x: number, z: number): number
	local best = math.huge
	for _, area in shapes() do
		if area.kind == "field" then
			local s = area.shape
			local dx, dz = x - s.x, z - s.z
			local lx, lz = dx * s.ux + dz * s.uz, -dx * s.uz + dz * s.ux
			local ox, oz = math.max(math.abs(lx) - s.hx, 0), math.max(math.abs(lz) - s.hz, 0)
			best = math.min(best, math.sqrt(ox * ox + oz * oz))
		end
	end
	return best
end

-- why a cliff placement is not legal: inside the bounds with the world's margin, off the river, the roads, the plots' cores, the nodes, the arena
local function cliffViolations(p: any, others: { any }?): string
	local pos = p.cframe.Position
	local f, r = Layout.features, D.cliffRadius
	if
		pos.X < f.bounds.min.X + 8
		or pos.X > f.bounds.max.X - 8
		or pos.Z < f.bounds.min.Y + 8
		or pos.Z > f.bounds.max.Y - 8
	then
		return "a cliff is on the valley's edge"
	end
	if WorldPlan.distToPolyline(pos.X, pos.Z, f.river.points) < f.river.width / 2 + r then
		return "a cliff is in the river"
	end
	for _, road in f.roads do
		if WorldPlan.distToPolyline(pos.X, pos.Z, road.points) < road.width / 2 + r then
			return "a cliff is on a road"
		end
	end
	for _, kid in KINGDOMS do
		for _, anchor in Layout.plots[kid].anchors do
			if
				(Vector3.new(pos.X, 0, pos.Z) - Vector3.new(anchor.Position.X, 0, anchor.Position.Z)).Magnitude
				< 30 + r
			then
				return `a cliff is on the {kid} plot`
			end
		end
	end
	for _, n in Layout.resourceNodes do
		local q = n.cframe.Position
		if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(q.X, 0, q.Z)).Magnitude < 9 + r then
			return `a cliff is on {n.id}`
		end
	end
	for _, area in shapes() do
		if area.kind == "arena" and Footprint.overlapsCircle(area.shape, pos.X, pos.Z, r, 0) then
			return "a cliff is on the arena"
		end
	end
	if math.abs(WorldPlan.groundHeight(Layout, pos.X, pos.Z) - (f.groundY or 0)) > 0.3 then
		return "a cliff stands on a slope"
	end
	for _, q in others or {} do
		local c = q.cframe.Position
		local min = r + WorldPlan.footprintRadius(q.assetId) * 0.6
		if q ~= p and (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(c.X, 0, c.Z)).Magnitude < min then
			return `a cliff is on a {q.assetId}`
		end
	end
	return ""
end

describe("a world without the imported kit is exactly today's world", function()
	it("returns the base placements untouched when no id is ready (nil, none, or no asset source)", function()
		local base = WorldPlan.props(Layout, DRESSED, nil)
		local function same(out: { any })
			expect(#out).toBe(#base)
			for i, p in base do
				expect(yawKey(out[i])).toBe(yawKey(p))
			end
		end
		same(WorldPlan.meshDressing(Layout, base, nil))
		same(WorldPlan.meshDressing(Layout, base, function(_: string): boolean
			return false
		end))
		same(WorldPlan.meshDressing(Layout, base, Kit.envMeshReady)) -- no asset source: nothing is ready
	end)

	it("Kit.envMeshReady is false for every dressing id without the kit, and true with it, silently", function()
		for _, id in DRESSING_IDS do
			expect(Kit.envMeshReady(id)).toBe(false)
		end
		EnvKit.install(Data, EnvKit.assets(Data, { folder = true }))
		local before = EnvMesh.status()
		for _, id in DRESSING_IDS do
			expect(Kit.envMeshReady(id)).toBe(true)
		end
		local after = EnvMesh.status()
		expect(after.accepted).toBe(before.accepted) -- asking builds nothing and counts nothing
		expect(next(after.rejected)).toBeNil()
		expect(#EnvKit.logs).toBe(0)
	end)

	it(
		"is false for an id whose import does not match its data (it would be a stand-in), and for an id the data does not list",
		function()
			EnvKit.install(
				Data,
				EnvKit.assets(Data, {
					folder = true,
					per = { farm_fence_01 = { scale = Vector3.new(2, 1, 1) } },
					omit = { rock_cliff_02 = true },
				})
			)
			expect(Kit.envMeshReady("farm_fence_01")).toBe(false)
			expect(Kit.envMeshReady("rock_cliff_02")).toBe(false)
			expect(Kit.envMeshReady("farm_fence_02")).toBe(true)
			expect(Kit.envMeshReady("tree_nonexistent_01")).toBe(false)
			-- a world that can build only some of them places only those
			local base = WorldPlan.props(Layout, DRESSED, nil)
			local out = WorldPlan.meshDressing(Layout, base, Kit.envMeshReady)
			for _, p in out do
				expect(p.assetId).never.toBe("farm_fence_01")
				expect(p.assetId).never.toBe("rock_cliff_02")
			end
		end
	)

	it("a world built without the kit has no fence, no cliff and only the _03 cabbage", function()
		local env = MockEnv.new({ seed = 1 })
		local svc = WorldDef.new(env, nil)
		svc.terrain = Terrain.recorder()
		svc:start()
		env.mock:advance(30)
		expect(svc.stats.error).toBeNil()
		for _, model in svc:getRoot():FindFirstChild("Props"):GetChildren() do
			expect(model:GetAttribute("Feature")).never.toBe("fence")
			expect(model:GetAttribute("Feature")).never.toBe("cliff")
			expect(model.Name).never.toBe("farm_field_cabbage_01")
			expect(model.Name).never.toBe("farm_field_cabbage_02")
		end
		expect(svc.stats.props).toBe(416)
		svc:destroy()
	end)
end)

describe("the dressing with the kit", function()
	it("renumbers the cabbage fields by kingdom and leaves every wheat field alone", function()
		local base, out = dressed(nil)
		local changed = {}
		for i, p in base do
			if out[i].assetId ~= p.assetId then
				changed[out[i].assetId] = (changed[out[i].assetId] or 0) + 1
				expect(p.assetId).toBe("farm_field_cabbage_03")
				expect(out[i].feature).toBe("crops")
				expect((out[i].cframe.Position - p.cframe.Position).Magnitude).toBe(0)
			end
		end
		expect(changed.farm_field_cabbage_01).toBe(2) -- crimson and gold
		expect(changed.farm_field_cabbage_02).toBe(1) -- azure; emerald keeps _03
		local seen = {}
		for _, p in out do
			if string.sub(p.assetId, 1, 17) == "farm_field_wheat_" then
				seen[p.assetId] = true
			end
		end
		expect(seen.farm_field_wheat_01 and seen.farm_field_wheat_02 and not seen.farm_field_wheat_03).toBe(true) -- today's wheat, the growth stages stay on the bench
	end)

	it(
		"adds the fences and cliffs the proposal measured: 48 fences, 12 cliffs at the shipped density; 48 and 11 at 1.0",
		function()
			local base, out = dressed(nil)
			local f = byFeature(out)
			expect(f.fence).toBe(48)
			expect(f.cliff).toBe(12)
			expect(#out - #base).toBe(60)
			local base1, out1 = dressed(WorldPlan.FULL_DENSITY)
			local f1 = byFeature(out1)
			expect(f1.fence).toBe(48)
			expect(f1.cliff).toBe(11) -- one rim site is taken by a tree at the untrimmed density
			expect(#out1 - #base1).toBe(59)
			-- only the planned ids, both fences and both cliffs in use, nothing of the base is moved or dropped
			local want = { farm_fence_01 = true, farm_fence_02 = true, rock_cliff_01 = true, rock_cliff_02 = true }
			for i = #base + 1, #out do
				expect(want[out[i].assetId]).toBe(true)
			end
			for i, p in base do
				expect(out[i].cframe == p.cframe or out[i].feature == "crops").toBe(true)
			end
		end
	)

	it("fences the same 12 segments on every plot (the plots stay rotated copies of each other)", function()
		local _, out = dressed(nil)
		local perPlot = { 0, 0, 0, 0 }
		for _, p in out do
			if p.feature == "fence" then
				local best, bestD = 1, math.huge
				for i, kid in KINGDOMS do
					local c = Layout.plots[kid].anchors.keep.Position
					local d = (c - p.cframe.Position).Magnitude
					if d < bestD then
						best, bestD = i, d
					end
				end
				perPlot[best] += 1
			end
		end
		for i = 1, 4 do
			expect(perPlot[i]).toBe(12)
		end
	end)

	for _, density in { "shipped", "full" } do
		it(`keeps every fence legal and hugging a crop field ({density} density)`, function()
			local _, out = dressed(if density == "full" then WorldPlan.FULL_DENSITY else nil)
			local n = 0
			for _, p in out do
				if p.feature == "fence" then
					n += 1
					local why = fenceViolations(p)
					expect(why).toBe("")
					local pos = p.cframe.Position
					local gap = fieldGap(pos.X, pos.Z)
					expect(gap).toBeGreaterThan(D.fenceOffset - 0.6)
					expect(gap).toBeLessThan(D.fenceOffset + 1.2) -- a fence is a field's own dressing, not a wall somewhere else
				end
			end
			expect(n).toBe(48)
		end)

		it(`keeps every cliff legal, flat-footed and clear of the other props ({density} density)`, function()
			local _, out = dressed(if density == "full" then WorldPlan.FULL_DENSITY else nil)
			local n = 0
			for _, p in out do
				if p.feature == "cliff" then
					n += 1
					expect(cliffViolations(p, out)).toBe("")
				end
			end
			expect(n).toBeGreaterThanOrEqual(11)
		end)
	end

	it("keeps the fences off the resource nodes' drawn extent and out of the farm lanes", function()
		EnvKit.install(Data, EnvKit.assets(Data, { folder = true }))
		local _, out = dressed(nil)
		for _, n in Layout.resourceNodes do
			local model = Kit.prop(n.assetId)
			local primary = model.PrimaryPart :: BasePart
			local toLocal = (primary.CFrame * primary.PivotOffset):Inverse()
			local reach = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					local cf = toLocal * d.CFrame
					local h = d.Size / 2
					for _, sx in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local w = cf * Vector3.new(sx * h.X, 0, sz * h.Z)
							reach = math.max(reach, math.sqrt(w.X * w.X + w.Z * w.Z))
						end
					end
				end
			end
			local p = n.cframe.Position
			for _, q in out do
				if q.feature == "fence" then
					local pos = q.cframe.Position
					local fence =
						Footprint.rect(Vector2.new(D.fenceLength, 2 * D.fenceHalfWidth), pos.X, pos.Z, yawOf(q.cframe))
					expect(Footprint.overlapsCircle(fence, p.X, p.Z, reach, 0)).toBe(false)
				end
			end
		end
	end)

	it(
		"keeps the fences off the nav edges between a plot's farm, quarry and keep (nothing a citizen walks is fenced across)",
		function()
			local _, out = dressed(nil)
			local nodes, edges = Layout.nav.nodes, Layout.nav.edges
			for _, e in edges do
				local a, b = nodes[e[1]], nodes[e[2]]
				for _, q in out do
					if q.feature == "fence" then
						local pos = q.cframe.Position
						local fence = Footprint.rect(
							Vector2.new(D.fenceLength, 2 * D.fenceHalfWidth),
							pos.X,
							pos.Z,
							yawOf(q.cframe)
						)
						for t = 0, 20 do
							local x, z = a.X + (b.X - a.X) * t / 20, a.Z + (b.Z - a.Z) * t / 20
							expect(Footprint.overlapsCircle(fence, x, z, 0.5, 0)).toBe(false)
						end
					end
				end
			end
		end
	)
end)

describe("a world built with the kit", function()
	local function boot(density: { [string]: number }?)
		local env = MockEnv.new({ seed = 1 })
		local forge = Instance.new("Folder")
		forge.Name = "Forge"
		forge.Parent = env.ReplicatedStorage
		EnvKit.assets(Data, { folder = true }).Parent = forge
		EnvKit.install(Data, nil)
		local svc = WorldDef.new(env, nil)
		svc.terrain = Terrain.recorder()
		svc.density = density
		svc:start()
		env.mock:advance(30)
		expect(svc.stats.error).toBeNil()
		return svc
	end

	it("places the dressing as imported meshes, 2 to 3 parts each, inside the D-047 headroom", function()
		local svc = boot(nil)
		local parts, n = 0, { fence = 0, cliff = 0 }
		local cabbages = {}
		for _, model in svc:getRoot():FindFirstChild("Props"):GetChildren() do
			local feature = model:GetAttribute("Feature")
			if feature == "fence" or feature == "cliff" then
				n[feature] += 1
				parts += Kit.partCount(model)
				expect(model:GetAttribute("KitEnvMesh")).toBe(true)
				expect(Kit.partCount(model)).toBe(3) -- Root, Body, Collider
			elseif feature == "crops" and string.sub(model.Name, 1, 19) == "farm_field_cabbage_" then
				cabbages[model.Name] = (cabbages[model.Name] or 0) + 1
				expect(Kit.partCount(model)).toBe(2) -- Root, Body
			end
		end
		expect(n.fence).toBe(48)
		expect(n.cliff).toBe(12)
		expect(parts).toBe(180) -- 144 + 36
		expect(parts).toBeLessThan(200)
		expect(cabbages.farm_field_cabbage_01).toBe(2)
		expect(cabbages.farm_field_cabbage_02).toBe(1)
		expect(cabbages.farm_field_cabbage_03).toBe(1)
		svc:destroy()
	end)

	it("costs far fewer parts than the part-built world it replaces, dressing included", function()
		local plain = WorldDef.new(MockEnv.new({ seed = 1 }), nil)
		EnvKit.uninstall()
		local env = MockEnv.new({ seed = 1 })
		plain = WorldDef.new(env, nil)
		plain.terrain = Terrain.recorder()
		plain:start()
		env.mock:advance(30)
		local meshed = boot(nil)
		expect(meshed.stats.parts).toBeLessThan(plain.stats.parts / 2)
		plain:destroy()
		meshed:destroy()
	end)
end)

describe("the checks catch each way of breaking the rule (mutants)", function()
	local function firstFence(): any
		local _, out = dressed(nil)
		for _, p in out do
			if p.feature == "fence" then
				return p
			end
		end
		error("no fence")
	end

	local function moved(p: any, x: number, z: number): any
		return {
			assetId = p.assetId,
			cframe = CFrame.new(x, 0, z) * (p.cframe - p.cframe.Position),
			feature = p.feature,
		}
	end

	it("flags a fence on a build slot, on a road and in the river", function()
		local p = firstFence()
		expect(fenceViolations(p)).toBe("")
		local slot = Layout.plots.crimson.buildSlots[1]
		expect(fenceViolations(moved(p, slot.center.X, slot.center.Z))).never.toBe("")
		local road = Layout.features.roads[1].points[1]
		expect(fenceViolations(moved(p, road.X, road.Y))).never.toBe("")
		local river = Layout.features.river.points[3]
		expect(fenceViolations(moved(p, river.X, river.Y))).never.toBe("")
	end)

	it("flags a fence on a building or in a build zone", function()
		local p = firstFence()
		local keep = Layout.plots.crimson.anchors.keep.Position
		expect(fenceViolations(moved(p, keep.X, keep.Z))).never.toBe("")
		local zone = Layout.plots.azure.buildZones[1]
		expect(fenceViolations(moved(p, zone.center.X, zone.center.Z))).never.toBe("")
	end)

	it("flags a cliff on a road, in the river, on a plot, on a node and on the valley's edge", function()
		local _, out = dressed(nil)
		local cliff
		for _, p in out do
			if p.feature == "cliff" then
				cliff = p
				break
			end
		end
		expect(cliffViolations(cliff, out)).toBe("")
		local road = Layout.features.roads[1].points[2]
		expect(cliffViolations(moved(cliff, road.X, road.Y), out)).never.toBe("")
		local river = Layout.features.river.points[2]
		expect(cliffViolations(moved(cliff, river.X, river.Y), out)).never.toBe("")
		local keep = Layout.plots.gold.anchors.keep.Position
		expect(cliffViolations(moved(cliff, keep.X, keep.Z), out)).never.toBe("")
		local node = Layout.resourceNodes[1].cframe.Position
		expect(cliffViolations(moved(cliff, node.X, node.Z), out)).never.toBe("")
		expect(cliffViolations(moved(cliff, Layout.features.bounds.max.X, 0), out)).never.toBe("")
	end)

	it("flags a cliff set on a tree or against another cliff", function()
		local _, out = dressed(nil)
		local cliffs, tree = {}, nil
		for _, p in out do
			if p.feature == "cliff" then
				table.insert(cliffs, p)
			elseif p.feature == "forest" and tree == nil then
				tree = p
			end
		end
		expect(cliffViolations(moved(cliffs[1], tree.cframe.Position.X, tree.cframe.Position.Z), out)).never.toBe("")
		local near = cliffs[2].cframe.Position
		expect(cliffViolations(moved(cliffs[1], near.X + 3, near.Z), out)).never.toBe("")
	end)

	it("a fence moved off its field is no longer hugging one", function()
		local p = firstFence()
		local pos = p.cframe.Position
		expect(fieldGap(pos.X, pos.Z)).toBeLessThan(D.fenceOffset + 1.2)
		expect(fieldGap(pos.X + 30, pos.Z + 30)).toBeGreaterThan(D.fenceOffset + 1.2)
	end)
end)
