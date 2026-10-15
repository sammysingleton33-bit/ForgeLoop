local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Def = require("@game/ServerScriptService/Game/Services/WorldService")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")

local function boot()
	local env = MockEnv.new({ seed = 1 })
	local svc = Def.new(env, nil)
	svc.terrain = Terrain.recorder()
	return env, svc
end

local function tagged(env, tag: string)
	return env.CollectionService:GetTagged(tag)
end

describe("WorldService (G10)", function()
	it("builds across frames and fires ready once", function()
		local env, svc = boot()
		local fired = 0
		svc.ready:connect(function()
			fired += 1
		end)
		svc:start()
		expect(svc:isReady()).toBe(false) -- nothing finishes in the first frame
		env.mock:advance(30)
		expect(svc:isReady()).toBe(true)
		expect(fired).toBe(1)
		expect(svc.stats.terrainOps).toBeGreaterThan(20)
		expect(svc.stats.props).toBeGreaterThan(100)
		svc:destroy()
	end)

	it("records one bounded Fill* call per terrain op and applies colours and water", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		local fills, colours, water = 0, 0, 0
		for _, call in svc.terrain.calls do
			if string.sub(call.method, 1, 4) == "Fill" then
				fills += 1
				expect(Terrain.voxels(call.op)).toBeLessThanOrEqual(Terrain.MAX_VOXELS_PER_CALL)
			elseif call.method == "SetMaterialColor" then
				colours += 1
			elseif call.method == "SetWater" then
				water += 1
			end
		end
		expect(fills).toBe(#WorldPlan.terrainOps(Layout))
		expect(colours).toBeGreaterThan(5)
		expect(water).toBe(1)
	end)

	it("tags resource nodes, build zones and the objective with their Layout ids", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		local nodes = tagged(env, "ResourceNode")
		expect(#nodes).toBe(#Layout.resourceNodes)
		local ids = {}
		for _, n in nodes do
			ids[n:GetAttribute("NodeId")] = true
		end
		for _, n in Layout.resourceNodes do
			expect(ids[n.id]).toBe(true)
		end
		local zones = 0
		for _, k in { "crimson", "azure", "emerald", "gold" } do
			zones += #Layout.plots[k].buildZones
		end
		expect(#tagged(env, "BuildZone")).toBe(zones)
		for _, z in tagged(env, "BuildZone") do
			expect(type(z:GetAttribute("ZoneId"))).toBe("string")
		end
		local objectives = tagged(env, "ObjectiveZone")
		expect(#objectives).toBe(#Layout.objectives)
		expect(objectives[1]:GetAttribute("ObjectiveId")).toBe(Layout.objectives[1].id)
		expect(objectives[1]:GetAttribute("Radius")).toBe(Layout.objectives[1].radius)
		expect(#tagged(env, "KingdomPlot")).toBe(4)
	end)

	it("never builds buildings (BuildingService does)", function()
		local env, svc = boot()
		local original = Kit.build
		local calls = 0
		Kit.build = function(...)
			calls += 1
			return original(...)
		end
		svc:start()
		env.mock:advance(30)
		Kit.build = original
		expect(calls).toBe(0)
	end)

	it("applies the lighting preset", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		expect(env.Lighting.ClockTime).toBeNear(svc.lighting.lighting.ClockTime, 1e-3)
		expect(env.Lighting:FindFirstChildOfClass("Atmosphere")).never.toBeNil()
		expect(env.Lighting:FindFirstChildOfClass("ColorCorrectionEffect")).never.toBeNil()
	end)

	it("is deterministic: two builds place the same props", function()
		local a = WorldPlan.props(Layout, { crimson = true })
		local b = WorldPlan.props(Layout, { crimson = true })
		expect(#a).toBe(#b)
		for i = 1, #a do
			expect(a[i].assetId).toBe(b[i].assetId)
			expect((a[i].cframe.Position - b[i].cframe.Position).Magnitude).toBeLessThan(1e-6)
		end
	end)
end)

describe("WorldPlan (FL-0055)", function()
	it("keeps props off rivers, roads, anchors, build zones and the objective", function()
		local f = Layout.features
		for _, p in WorldPlan.props(Layout, { crimson = true }) do
			local x, z = p.cframe.Position.X, p.cframe.Position.Z
			if p.feature ~= "bridge" and p.feature ~= "dressing" then
				expect(WorldPlan.distToPolyline(x, z, f.river.points)).toBeGreaterThan(f.river.width / 2)
				for _, road in f.roads do
					expect(WorldPlan.distToPolyline(x, z, road.points)).toBeGreaterThan(road.width / 2)
				end
				for _, k in { "crimson", "azure", "emerald", "gold" } do
					for _, anchor in Layout.plots[k].anchors do
						local d = Vector2.new(anchor.Position.X - x, anchor.Position.Z - z).Magnitude
						expect(d).toBeGreaterThan(20)
					end
				end
			end
		end
	end)

	it("puts plots, anchors and spawns on flat ground", function()
		for _, k in { "crimson", "azure", "emerald", "gold" } do
			local plot = Layout.plots[k]
			for _, anchor in plot.anchors do
				expect(WorldPlan.groundHeight(Layout, anchor.Position.X, anchor.Position.Z)).toBeNear(0, 0.5)
			end
			expect(WorldPlan.groundHeight(Layout, plot.spawn.Position.X, plot.spawn.Position.Z)).toBeNear(0, 0.5)
		end
	end)

	it(
		"puts every gameplay point (nav, nodes, work spots, objective, zones) on flat ground at its Layout height",
		function()
			local bad = {}
			local function check(label: string, p: Vector3)
				local g = WorldPlan.groundHeight(Layout, p.X, p.Z)
				if math.abs(g - p.Y) > 0.5 then
					table.insert(bad, `{label} at ({math.floor(p.X)}, {math.floor(p.Z)}): ground {g}, layout y {p.Y}`)
				end
			end
			local decks = {}
			for _, br in Layout.features.river.bridges do
				decks[br.navNodes[2]] = br.deckY
			end
			for i, n in Layout.nav.nodes do
				if decks[i] then
					expect(n.Y).toBeNear(decks[i], 1e-3) -- on the bridge deck, above the river
				else
					check(`nav {i}`, n)
				end
			end
			for _, r in Layout.resourceNodes do
				check(r.id, r.cframe.Position)
				for j, s in r.workSpots do
					check(`{r.id} spot {j}`, s)
				end
			end
			for _, o in Layout.objectives do
				check(o.id, o.cframe.Position)
			end
			for _, k in { "crimson", "azure", "emerald", "gold" } do
				for _, z in Layout.plots[k].buildZones do
					check(z.id, z.center)
				end
			end
			expect(table.concat(bad, "; ")).toBe("")
		end
	)

	it("dresses only the requested kingdoms", function()
		local none, one = 0, 0
		for _, p in WorldPlan.props(Layout, {}) do
			if p.feature == "dressing" then
				none += 1
			end
		end
		for _, p in WorldPlan.props(Layout, { crimson = true }) do
			if p.feature == "dressing" then
				one += 1
			end
		end
		expect(none).toBe(0)
		expect(one).toBeGreaterThan(6)
	end)
end)

describe("WorldService robustness (FORGE-05 review of #28)", function()
	it("builds one world when start() is called twice", function()
		local env, svc = boot()
		local fired = 0
		svc.ready:connect(function()
			fired += 1
		end)
		svc:start()
		svc:start()
		env.mock:advance(30)
		local worlds = 0
		for _, c in env.Workspace:GetChildren() do
			if c.Name == "World" then
				worlds += 1
			end
		end
		expect(worlds).toBe(1)
		expect(fired).toBe(1)
		svc:destroy()
	end)

	it("still fires ready, once, and logs an error when the build fails", function()
		local env, svc = boot()
		local original = Kit.prop
		Kit.prop = function()
			error("boom")
		end
		local fired = 0
		svc.ready:connect(function()
			fired += 1
		end)
		svc:start()
		env.mock:advance(30)
		Kit.prop = original
		expect(fired).toBe(1)
		expect(svc:isReady()).toBe(true)
		expect(type(svc.stats.error)).toBe("string")
		expect(env.mock:hasLog("error", "WorldService build failed")).toBe(true)
		svc:destroy()
	end)

	it("stops building and removes the world when destroyed mid-build", function()
		local env, svc = boot()
		local fired = 0
		svc.ready:connect(function()
			fired += 1
		end)
		svc:start()
		env.mock:advance(0.05) -- a few frames in: terrain done, models in progress
		svc:destroy()
		env.mock:advance(30)
		expect(fired).toBe(0)
		expect(env.Workspace:FindFirstChild("World")).toBeNil()
		expect(#env.mock.threadErrors).toBe(0)
	end)

	it("makes invisible zone parts non-queryable (placement and selection raycasts pass through)", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		for _, tag in { "BuildZone", "ObjectiveZone", "KingdomPlot" } do
			local parts = tagged(env, tag)
			expect(#parts).toBeGreaterThan(0)
			for _, p in parts do
				expect(p.CanQuery).toBe(false)
			end
		end
		svc:destroy()
	end)

	it("never lets decoration fire Touched or catch raycasts with its plate, and lets units under canopies", function()
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		local root = svc:getRoot()
		local high, highCollide = 0, 0
		for _, folder in { "Props", "ResourceNodes" } do
			for _, d in root:FindFirstChild(folder):GetDescendants() do
				if d:IsA("BasePart") then
					expect(d.CanTouch).toBe(false)
					local model = d:FindFirstAncestorOfClass("Model")
					if d == model.PrimaryPart then
						expect(d.CanQuery).toBe(false) -- invisible footprint plate
					end
					local base = model.PrimaryPart.CFrame.Position.Y - model.PrimaryPart.Size.Y / 2
					if
						model:GetAttribute("Feature") ~= "bridge"
						and d.CFrame.Position.Y - d.Size.Y / 2 > base + svc.COLLIDE_HEIGHT + 0.01
					then
						high += 1
						if d.CanCollide then
							highCollide += 1
						end
					end
				end
			end
		end
		expect(high).toBeGreaterThan(100) -- canopies exist
		expect(highCollide).toBe(0)
		svc:destroy()
	end)

	it("creates at most partsPerFrame parts (plus one model) per frame and keeps the world under budget", function()
		local env, svc = boot()
		local largest = 0
		local originalProp = Kit.prop
		Kit.prop = function(id)
			local m = originalProp(id)
			largest = math.max(largest, Kit.partCount(m))
			return m
		end
		local worst, last = 0, 0
		local originalWait = svc._wait
		svc._wait = function(self)
			local root = self:getRoot()
			local n = root and #root:GetDescendants() or 0
			worst = math.max(worst, n - last)
			last = n
			originalWait(self)
		end
		svc:start()
		env.mock:advance(30)
		Kit.prop = originalProp
		expect(svc:isReady()).toBe(true)
		-- descendants include attachments and folders, so allow a little slack over the part budget
		expect(worst).toBeLessThanOrEqual(svc.partsPerFrame + largest + 80)
		-- D-047 / FL-0116: about 6,100 with the trimmed dressing (8,245 untrimmed); restoring the density knob after a
		-- phone test means raising this with it, since the 27k all-built ceiling depends on it
		expect(svc.stats.parts).toBeLessThan(6400)
		svc:destroy()
	end)
end)

-- Order-sensitive fingerprint of placements: asset ids and all 12 CFrame components to 1e-3.
local function fingerprint(placements: { any }): number
	local m, acc = 2147483647, 7
	for _, p in placements do
		for i = 1, #p.assetId do
			acc = (acc * 31 + string.byte(p.assetId, i)) % m
		end
		for _, c in { p.cframe:GetComponents() } do
			acc = (acc * 31 + math.floor(c * 1000 + 0.5)) % m
		end
	end
	return acc
end

local function samePlacement(a: any, b: any): boolean
	if a.assetId ~= b.assetId or a.feature ~= b.feature then
		return false
	end
	local ca, cb = { a.cframe:GetComponents() }, { b.cframe:GetComponents() }
	for i = 1, 12 do
		if ca[i] ~= cb[i] then
			return false
		end
	end
	return true
end

local function placementKey(p: any): string
	local q = p.cframe.Position
	return string.format("%s@%.3f,%.3f,%.3f", p.assetId, q.X, q.Y, q.Z)
end

describe("Dressing density knob (D-047)", function()
	local ALL = { crimson = true, azure = true, emerald = true, gold = true }
	local TRIMMABLE = { forest = true, lone_tree = true, bush = true, rocks = true, flowers = true }

	it(
		"rebuilds the untrimmed valley exactly at density 1.0 (the plan pinned from main d78d9cb, minus the clearance)",
		function()
			-- re-pin only when the world itself changes on purpose: the generated plan, then the cleared plan
			local plan = WorldPlan.plan(Layout, { crimson = true })
			expect(#plan).toBe(618)
			expect(fingerprint(plan)).toBe(1099084135) -- main d78d9cb's props, before the plot clearance and the trim
			local cleared = WorldPlan.clear(Layout, plan)
			local one = WorldPlan.props(Layout, { crimson = true }, WorldPlan.FULL_DENSITY)
			expect(#one).toBe(603)
			expect(fingerprint(one)).toBe(2016544125)
			expect(#cleared).toBe(#one)
			for i, p in one do
				expect(samePlacement(p, cleared[i])).toBe(true) -- density 1.0 adds nothing to the clearance
			end
			local all = WorldPlan.props(Layout, ALL, WorldPlan.FULL_DENSITY)
			expect(#all).toBe(624)
			expect(fingerprint(all)).toBe(1343259299)
			local env, svc = boot()
			svc.density = WorldPlan.FULL_DENSITY
			svc:start()
			env.mock:advance(30)
			expect(svc.stats.error).toBeNil()
			expect(svc.stats.props).toBe(603)
			expect(svc.stats.parts).toBe(8245)
			svc:destroy()
		end
	)

	it("only removes dressing: the trimmed plan is an ordered subset of the full one", function()
		for _, dressed in { { crimson = true }, ALL } do
			local full = WorldPlan.props(Layout, dressed, WorldPlan.FULL_DENSITY)
			local trimmed = WorldPlan.props(Layout, dressed)
			expect(#trimmed).toBeLessThan(#full)
			local j, bad = 1, {}
			for _, p in full do
				local q = trimmed[j]
				if q and samePlacement(p, q) then
					j += 1
				elseif not TRIMMABLE[p.feature] then
					table.insert(bad, `{p.assetId} ({p.feature}) removed`)
				end
			end
			expect(table.concat(bad, "; ")).toBe("")
			expect(j).toBe(#trimmed + 1) -- every kept placement found, unmoved and in order
		end
	end)

	it(
		"never thins bridges, crops or kingdom dressing, even far from every camera, and thins the rest there",
		function()
			local far = CFrame.new(-480, 0, 60) -- clear of every plot frame, road band and the heartland
			expect(WorldPlan.unseen(Layout, -480, 60)).toBeGreaterThan(0)
			local plan = {}
			for _, feature in { "bridge", "crops", "dressing", "forest", "lone_tree", "bush", "rocks", "flowers" } do
				table.insert(plan, { assetId = "x_01", cframe = far, feature = feature })
			end
			local out = WorldPlan.trim(Layout, plan, { forest = 0, props = 0 }) -- everything the knob may thin goes
			local kept = {}
			for _, p in out do
				kept[p.feature] = true
			end
			expect(#out).toBe(3)
			expect(kept.bridge and kept.crops and kept.dressing).toBe(true)
		end
	)

	it("keeps plot framing, approach roads and the heartland, and thins the map edges first", function()
		local full = WorldPlan.props(Layout, { crimson = true }, WorldPlan.FULL_DENSITY)
		local kept = {}
		for _, p in WorldPlan.props(Layout, { crimson = true }) do
			kept[placementKey(p)] = true
		end
		local f = Layout.features
		local centres = {}
		for _, k in { "crimson", "azure", "emerald", "gold" } do
			table.insert(centres, (Layout.plots[k].anchors.keep * CFrame.new(0, 0, -40)).Position)
		end
		-- the overview camera's focus box: the regions' box plus its 40-stud margin
		local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
		for _, region in Layout.regions do
			for _, v in region.polygon do
				minX, minZ = math.min(minX, v.X - 40), math.min(minZ, v.Y - 40)
				maxX, maxZ = math.max(maxX, v.X + 40), math.max(maxZ, v.Y + 40)
			end
		end
		local bad = {}
		local edge, inside = { n = 0, cut = 0 }, { n = 0, cut = 0 }
		for _, p in full do
			if TRIMMABLE[p.feature] then
				local pos = p.cframe.Position
				local gone = not kept[placementKey(p)]
				local near = false
				for _, c in centres do
					near = near or Vector2.new(pos.X - c.X, pos.Z - c.Z).Magnitude < 150
				end
				for r = 1, 4 do -- the four approach roads (plot gate to hub)
					near = near or WorldPlan.distToPolyline(pos.X, pos.Z, f.roads[r].points) < 30
				end
				for _, o in Layout.objectives do
					local q = o.cframe.Position
					near = near or Vector2.new(pos.X - q.X, pos.Z - q.Z).Magnitude < 120
				end
				if gone and near then
					table.insert(bad, `{p.assetId} ({p.feature}) at ({math.floor(pos.X)}, {math.floor(pos.Z)})`)
				end
				local out = pos.X < minX or pos.X > maxX or pos.Z < minZ or pos.Z > maxZ
				local bucket = if out then edge else inside
				bucket.n += 1
				bucket.cut += if gone then 1 else 0
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
		expect(edge.n).toBeGreaterThan(0)
		expect(edge.cut / edge.n).toBeGreaterThan(2 * inside.cut / inside.n)
	end)

	it("thins each kind to its knob and no forest stand by more than 1.6 times the forest cut", function()
		local d = WorldPlan.density(Layout)
		local full = WorldPlan.props(Layout, { crimson = true }, WorldPlan.FULL_DENSITY)
		local kept = {}
		for _, p in WorldPlan.props(Layout, { crimson = true }) do
			kept[placementKey(p)] = true
		end
		local n, k = {}, {}
		local standN, standK = {}, {}
		for _, p in full do
			if TRIMMABLE[p.feature] then
				local here = if kept[placementKey(p)] then 1 else 0
				n[p.feature] = (n[p.feature] or 0) + 1
				k[p.feature] = (k[p.feature] or 0) + here
				if p.feature == "forest" then
					local pos = p.cframe.Position
					for s, forest in Layout.features.forests do
						if (Vector2.new(pos.X, pos.Z) - forest.center).Magnitude <= forest.radius then
							standN[s] = (standN[s] or 0) + 1
							standK[s] = (standK[s] or 0) + here
						end
					end
				end
			end
		end
		expect(k.forest / n.forest).toBeNear(d.forest, 0.01)
		for _, kind in { "lone_tree", "bush", "rocks", "flowers" } do
			expect(k[kind] / n[kind]).toBeGreaterThanOrEqual(d.props - 0.01) -- more where the framing protects
		end
		local stands = 0
		for s, total in standN do
			local loss = (total - standK[s]) / total
			expect(loss).toBeLessThanOrEqual(math.min(1, (1 - d.forest) * 1.6) + 0.5 / total)
			stands += 1
		end
		expect(stands).toBe(#Layout.features.forests)
	end)
end)

describe("Kingdom colours come from config Kingdoms (D-033)", function()
	it("colours every slot marker pennant with its kingdom's canonical colour", function()
		local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
		local expected = {}
		for _, identity in KingdomsConfig.identities do
			local c = identity.color
			expected[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
		end
		local env, svc = boot()
		svc:start()
		env.mock:advance(30)
		local checked = 0
		for _, root in env.CollectionService:GetTagged("BuildSlot") do
			local want = expected[root:GetAttribute("Kingdom")]
			expect(want).never.toBeNil()
			for _, d in root.Parent:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Pennant" then
					expect(
						(Vector3.new(d.Color.R, d.Color.G, d.Color.B) - Vector3.new(want.R, want.G, want.B)).Magnitude
					).toBeLessThan(1e-3)
					checked += 1
				end
			end
		end
		expect(checked).toBeGreaterThan(100)
		svc:destroy()
	end)
end)
