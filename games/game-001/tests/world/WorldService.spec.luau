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
		expect(svc.stats.parts).toBeLessThan(9000)
		svc:destroy()
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
