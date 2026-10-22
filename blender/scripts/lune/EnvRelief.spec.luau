--[[
	FL-0136 phase 2: the part-count relief of the nature meshes, measured on the REAL WorldService (MockEnv, recorded terrain), with and without mesh props.

	NEEDS worker K's runtime (branch forge/02-blender-fl0136-envrt: Kit/EnvMesh, tests/world/fixtures/EnvMeshKit): it builds the same fake Models the Studio import
	makes (an invisible Root, a MeshPart Body, K's collider rule) from Kit/EnvMeshData, so the count is what the Kit would build in a world whose Forge.Assets holds the kit.
	Run it in a tree that has that branch and my env.json converted to EnvMeshData (the copy script is in env-mesh.md "Part-count relief"):

	  FORGE_ENV_RELIEF=/tmp/env_relief.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune EnvRelief

	Output JSON: { runs = { shipped | full = { plain = { parts, props, byFamily }, mesh = { parts, props, byFamily } } } }, byFamily = { family = { n, parts } }.
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
local EnvMesh = require("@game/ReplicatedStorage/Game/Kit/EnvMesh")
local Data = require("@game/ReplicatedStorage/Game/Kit/EnvMeshData")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local EnvKit = require("../../../games/game-001/tests/world/fixtures/EnvMeshKit")

local FAMILIES = {
	{ "tree_oak", "oak" },
	{ "tree_pine", "pine" },
	{ "tree_birch", "birch" },
	{ "bush", "bush" },
	{ "plant_flowers", "flowers" },
	{ "rock_boulder", "boulders" },
	{ "resource_", "resource nodes" },
	{ "farm_field", "crops" },
	{ "farm_haystack", "haystack" },
	{ "farm_fence", "fences" },
}

local function family(id: string): string
	for _, f in FAMILIES do
		if string.sub(id, 1, #f[1]) == f[1] then
			return f[2]
		end
	end
	return "other"
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
	local original = Kit.prop
	local by: { [string]: { n: number, parts: number } } = {}
	local meshModels = 0
	Kit.prop = function(id: string)
		local m = original(id)
		local f = family(id)
		by[f] = by[f] or { n = 0, parts = 0 }
		by[f].n += 1
		by[f].parts += Kit.partCount(m)
		if m:GetAttribute("KitEnvMesh") == true then
			meshModels += 1
		end
		return m
	end
	svc:start()
	env.mock:advance(30)
	Kit.prop = original
	expect(svc.stats.error).toBeNil()
	local out = {
		parts = svc.stats.parts,
		arenaParts = svc.stats.arenaParts,
		props = svc.stats.props,
		byFamily = by,
		meshModels = meshModels,
	}
	svc:destroy()
	EnvKit.uninstall()
	return out
end

describe("FL-0136 part-count relief", function()
	it("builds the world with and without the mesh kit at the shipped density and at 1.0", function()
		local runs = {
			shipped = { plain = run(false, nil), mesh = run(true, nil) },
			full = { plain = run(false, WorldPlan.FULL_DENSITY), mesh = run(true, WorldPlan.FULL_DENSITY) },
		}
		expect(runs.full.plain.parts - runs.full.plain.arenaParts).toBe(6841) -- the dressing, the pinned figure of WorldService.spec (8,347 before the nature pass of visual upgrade 1: 1,506 parts lighter); the arena is counted apart
		expect(runs.full.mesh.parts).toBeLessThan(runs.full.plain.parts)
		local o = process.env.FORGE_ENV_RELIEF
		if o and o ~= "" then
			fs.writeFile(o, serde.encode("json", { runs = runs }, false))
			print(
				`relief: shipped {runs.shipped.plain.parts} -> {runs.shipped.mesh.parts}, density 1.0 {runs.full.plain.parts} -> {runs.full.mesh.parts} -> {o}`
			)
		end
	end)
end)
