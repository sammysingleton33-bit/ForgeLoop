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
