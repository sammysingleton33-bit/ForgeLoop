--[[
	FL-0136 phase 3 (B): the mesh-only dressing (WorldPlan.meshDressing: cabbage variants, field fences, rim cliffs) measured on the REAL world: the extra
	placements (for blender/scripts/envnature_scenes.py), the parts and triangles with and without the imported meshes, at the shipped density and at 1.0.
	Needs the kit data (Kit/EnvMeshData, the real env.json) and the fixture's fake import models (K's runtime), like EnvRelief.

	  FORGE_ENV_DRESSING=/tmp/env_dressing.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune EnvDressing

	Output JSON: { runs = { shipped | full = { plain = { parts, arenaParts, props }, mesh = { parts, arenaParts, props, byFeature = { feature = { n, parts, tris } } } } },
	               extra = { shipped | full = [{ id, x, z, yaw, feature }] } (the placements meshDressing adds or renumbers), counts = { feature = n } }
]]

local T = require("../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local MockEnv = require("../../../roblox/tests/mocks/MockEnv")
local WorldDef = require("@game/ServerScriptService/Game/Services/WorldService")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local EnvMesh = require("@game/ReplicatedStorage/Game/Kit/EnvMesh")
local Data = require("@game/ReplicatedStorage/Game/Kit/EnvMeshData")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local EnvKit = require("../../../games/game-001/tests/world/fixtures/EnvMeshKit")

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function round(v: number): number
	return math.floor(v * 100 + 0.5) / 100
end

local nodeAssets: { [string]: string } = {}
for _, n in Layout.resourceNodes do
	nodeAssets[n.id] = n.assetId
end

local function run(withMeshes: boolean, density: { [string]: number }?)
	local env = MockEnv.new({ seed = 1 })
	if withMeshes then
		local forge = Instance.new("Folder")
		forge.Name = "Forge"
		forge.Parent = env.ReplicatedStorage
		EnvKit.assets(Data, { folder = true }).Parent = forge
	end
	EnvMesh.setData(if withMeshes then Data else nil)
	local svc = WorldDef.new(env, nil)
	svc.terrain = Terrain.recorder()
	svc.density = density
	local byFeature: { [string]: { n: number, parts: number, tris: number } } = {}
	local original = Kit.prop
	Kit.prop = function(id: string)
		local m = original(id)
		return m
	end
	svc:start()
	env.mock:advance(30)
	Kit.prop = original
	expect(svc.stats.error).toBeNil()
	-- per feature: from the placed models in Workspace.World.Props
	local props = svc:getRoot():FindFirstChild("Props")
	for _, model in props:GetChildren() do
		local feature = model:GetAttribute("Feature") or "?"
		local e = byFeature[feature]
		if e == nil then
			e = { n = 0, parts = 0, tris = 0 }
			byFeature[feature] = e
		end
		e.n += 1
		e.parts += Kit.partCount(model)
		local def = Data.props[model.Name]
		if def and model:GetAttribute("KitEnvMesh") == true then
			e.tris += def.tris
		end
	end
	-- the resource nodes (each carries its marker: 2 parts), by resource
	for _, model in svc:getRoot():FindFirstChild("ResourceNodes"):GetChildren() do
		local feature = `node:{model:GetAttribute("Resource")}`
		local e = byFeature[feature]
		if e == nil then
			e = { n = 0, parts = 0, tris = 0 }
			byFeature[feature] = e
		end
		e.n += 1
		e.parts += Kit.partCount(model)
		local assetOf = nodeAssets[model:GetAttribute("NodeId")]
		if assetOf and Data.props[assetOf] and model:GetAttribute("KitEnvMesh") == true then
			e.tris += Data.props[assetOf].tris
		end
	end
	local out = { parts = svc.stats.parts, arenaParts = svc.stats.arenaParts, props = svc.stats.props, byFeature = byFeature }
	svc:destroy()
	EnvKit.uninstall()
	return out
end

describe("FL-0136 phase 3: mesh-only dressing", function()
	it("measures the dressing with and without the imported meshes at the shipped density and at 1.0", function()
		local runs = {
			shipped = { plain = run(false, nil), mesh = run(true, nil) },
			full = { plain = run(false, WorldPlan.FULL_DENSITY), mesh = run(true, WorldPlan.FULL_DENSITY) },
		}
		-- a world without the kit places exactly today's props
		expect(runs.shipped.plain.props).toBe(416)
		expect(runs.full.plain.props).toBe(615)
		local extra = { shipped = {}, full = {} }
		local counts = {}
		for label, density in { shipped = WorldPlan.density(Layout), full = WorldPlan.FULL_DENSITY } do
			local base = WorldPlan.props(Layout, { crimson = true }, density)
			local dressed = WorldPlan.meshDressing(Layout, base, function(id)
				return Data.props[id] ~= nil
			end)
			-- the renumbered cabbage fields and the added fences and cliffs
			for i, p in dressed do
				local was = base[i]
				if was == nil or was.assetId ~= p.assetId then
					local pos = p.cframe.Position
					table.insert(extra[label], {
						id = p.assetId,
						x = round(pos.X),
						z = round(pos.Z),
						yaw = round(yawOf(p.cframe)),
						feature = p.feature,
					})
					if label == "shipped" then
						counts[p.feature] = (counts[p.feature] or 0) + 1
					end
				end
			end
		end
		local o = process.env.FORGE_ENV_DRESSING
		if o and o ~= "" then
			fs.writeFile(o, serde.encode("json", { runs = runs, extra = extra, counts = counts }, false))
			print(`dressing: shipped {runs.shipped.plain.parts} -> {runs.shipped.mesh.parts} parts, full {runs.full.plain.parts} -> {runs.full.mesh.parts} -> {o}`)
		end
	end)
end)
