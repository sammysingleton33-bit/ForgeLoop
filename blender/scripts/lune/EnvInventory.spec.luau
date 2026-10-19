--[[
	FL-0136 phase 2: inventory of the nature and crop props the world really places, and the part-count relief a mesh prop would give.
	Read-only over the game. Runs the real WorldService (MockEnv, recorded terrain) at the shipped density and at density 1.0
	(WorldPlan.FULL_DENSITY, the untrimmed valley, D-047) with Kit.prop wrapped, so every placement is counted by asset id and family
	together with the parts its stand-in costs. Also dumps every placed stand-in (parts, sizes, frames) for blender/lib/kitparts.py.

	  FORGE_ENV_INVENTORY=/tmp/env_inventory.json lune run roblox/tests/harness/run.luau \
	    --project games/game-001/default.project.json --specs blender/scripts/lune EnvInventory

	Output JSON: { version, runs = { default | full = { parts, props, nodes, slots, byId = { id = { n, partsEach, features } } } },
	               plan = { id = n } (cleared plan at FULL_DENSITY, dressed = all four kingdoms), nodes = { id = n }, clear = { prefix = r },
	               subjects = { id = { parts, attachments } } }
]]

local T = require("../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local MockEnv = require("../../../roblox/tests/mocks/MockEnv")
local Def = require("@game/ServerScriptService/Game/Services/WorldService")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")

local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function serialise(model: Instance)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = { d.CFrame:GetComponents() }
			for i, v in cf do
				cf[i] = round(v)
			end
			table.insert(parts, {
				name = d.Name,
				class = d.ClassName,
				shape = if d.ClassName == "Part" then (d :: Part).Shape.Name else d.ClassName,
				size = { round(d.Size.X), round(d.Size.Y), round(d.Size.Z) },
				cframe = cf,
				color = { round(d.Color.R), round(d.Color.G), round(d.Color.B) },
				material = d.Material.Name,
				transparency = d.Transparency,
				canCollide = d.CanCollide,
			})
		end
	end
	return { name = model.Name, parts = parts, partCount = #parts }
end

-- run the real world once; count every Kit.prop call by id (and the parts it costs) while it builds
local function run(density: { [string]: number }?)
	local env = MockEnv.new({ seed = 1 })
	local svc = Def.new(env, nil)
	svc.terrain = Terrain.recorder()
	svc.density = density
	local original = Kit.prop
	local byId: { [string]: any } = {}
	Kit.prop = function(id: string)
		local m = original(id)
		local e = byId[id]
		if not e then
			e = { n = 0, partsEach = Kit.partCount(m) }
			byId[id] = e
		end
		e.n += 1
		return m
	end
	svc:start()
	env.mock:advance(30)
	Kit.prop = original
	expect(svc.stats.error).toBeNil()
	local out = { parts = svc.stats.parts, props = svc.stats.props, byId = byId }
	svc:destroy()
	return out
end

describe("FL-0136 inventory of placed nature and crops", function()
	it("counts every placed asset id and its parts at the shipped density and at 1.0", function()
		local shipped = run(nil)
		local full = run(WorldPlan.FULL_DENSITY)
		-- features per id from the plans themselves
		local function featuresOf(plan: { any }): { [string]: { [string]: number } }
			local f: { [string]: { [string]: number } } = {}
			for _, p in plan do
				f[p.assetId] = f[p.assetId] or {}
				f[p.assetId][p.feature] = (f[p.assetId][p.feature] or 0) + 1
			end
			return f
		end
		local dressedNow = { crimson = true } -- WorldService.DRESSED
		local fShipped = featuresOf(WorldPlan.props(Layout, dressedNow, WorldPlan.density(Layout)))
		local fFull = featuresOf(WorldPlan.props(Layout, dressedNow, WorldPlan.FULL_DENSITY))
		for id, e in shipped.byId do
			e.features = fShipped[id]
		end
		for id, e in full.byId do
			e.features = fFull[id]
		end
		local plan = {}
		for _, p in WorldPlan.props(Layout, { crimson = true, azure = true, emerald = true, gold = true }, WorldPlan.FULL_DENSITY) do
			plan[p.assetId] = (plan[p.assetId] or 0) + 1
		end
		local nodes = {}
		for _, n in Layout.resourceNodes do
			nodes[n.assetId] = (nodes[n.assetId] or 0) + 1
		end
		local ids = {}
		for id in plan do
			ids[id] = true
		end
		for id in nodes do
			ids[id] = true
		end
		for id in shipped.byId do
			ids[id] = true
		end
		for id in full.byId do
			ids[id] = true
		end
		-- ids the world does not place today but the Props stand-ins and KitProps.spec know (spares in the mesh kit)
		local placed = {}
		for id in ids do
			placed[id] = true
		end
		for _, id in {
			"resource_wood_01", "resource_wood_02", "rock_cliff_01", "rock_cliff_02", "resource_ore_01", "resource_ore_02",
			"resource_ore_05", "resource_ore_06", "farm_fence_01", "farm_fence_02", "farm_field_wheat_03",
			"farm_field_cabbage_01", "farm_field_cabbage_02",
		} do
			ids[id] = true
		end
		local subjects = {}
		for id in ids do
			local entry = serialise(Kit.prop(id))
			entry.placed = placed[id] == true
			subjects[id] = entry
		end
		local clear = {}
		for k, v in WorldPlan.CLEAR.radius do
			clear[k] = v
		end
		expect(full.props).toBe(616)
		expect(full.parts).toBe(8309) -- the pinned figure of WorldService.spec (density 1.0, crimson dressed)
		local o = process.env.FORGE_ENV_INVENTORY
		if o and o ~= "" then
			fs.writeFile(
				o,
				serde.encode("json", {
					version = Kit.VERSION,
					runs = { default = shipped, full = full },
					plan = plan,
					nodes = nodes,
					clear = clear,
					subjects = subjects,
					slots = #Layout.plots.crimson.buildSlots * 4,
				}, false)
			)
			print(`env inventory: shipped parts {shipped.parts} (props {shipped.props}), full parts {full.parts} (props {full.props}), {#Layout.resourceNodes} nodes -> {o}`)
		end
	end)
end)
