--!nonstrict
--[[
	Kit.prop with imported nature meshes (FL-0136, D-057 (18)-(20); Kit/EnvMesh). HEADLESS: Lune has no importer, so the
	props are fake Models of the shape blender/studio/import_env_kit.luau makes (an invisible Root + a MeshPart "Body") in a
	fake Forge.Assets, sized from the PLACEHOLDER kit (fixtures/env_placeholder.env.json: numbers measured on the part-built
	props, every field of the format). When the real kit's data is committed (Kit/EnvMeshData) the data checks below also run
	on it, against the world and the live stand-ins. Nothing here says the meshes look right or import right in Studio.

	Covers: the stand-in fallback (no data, no source, no id, wrong kind of thing, a Model that does not match its data),
	pass-through of ids the data does not list, the prepared prop (pivot at the base centre, flags, colliders, strip rules),
	rejection logged once and never an error, determinism, what WorldService assumes of a prop (placeModel, decorate, the
	whole world built with mesh props), and the converter's output and budget.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local process = require("@lune/process")

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local WorldDef = require("@game/ServerScriptService/Game/Services/WorldService")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local CommittedData = require("@game/ReplicatedStorage/Game/Kit/EnvMeshData")
local EnvMesh = require("@game/ReplicatedStorage/Game/Kit/EnvMesh")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local EnvKit = require("./fixtures/EnvMeshKit")
local Fixture = require("./fixtures/EnvMeshFixture")

local ORIGIN = CFrame.new()

afterEach(function()
	EnvKit.uninstall()
end)

local function isStandIn(model: Instance): boolean
	return model:GetAttribute("KitStandIn") == true
end

local function isMesh(model: Instance): boolean
	return model:GetAttribute("KitEnvMesh") == true
end

local function near(a: CFrame, b: CFrame, eps: number): boolean
	local ca, cb = { a:GetComponents() }, { b:GetComponents() }
	for i = 1, 12 do
		if math.abs(ca[i] - cb[i]) > eps then
			return false
		end
	end
	return true
end

local function count(model: Instance): number
	return #EnvKit.parts(model)
end

local function childNamed(model: Instance, name: string): BasePart?
	return model:FindFirstChild(name) :: BasePart?
end

-- ------------------------------------------------------------------ fallback and pass-through

describe("Kit.prop builds the stand-in unless a matching imported Model is there", function()
	local data = EnvKit.fixture()

	it(
		"is today's stand-in for every placeholder id with no source, an empty source, or a folder without the id",
		function()
			for _, id in EnvKit.ids(data) do
				EnvKit.install(data, nil)
				local bare = Kit.prop(id)
				expect(isStandIn(bare)).toBe(true)
				local reference = EnvKit.signature(bare)
				EnvKit.install(data, Instance.new("Folder")) -- a source without the id
				expect(EnvKit.signature(Kit.prop(id))).toBe(reference)
				EnvKit.install(data, EnvKit.assets(data, { omit = { [id] = true } }))
				expect(EnvKit.signature(Kit.prop(id))).toBe(reference)
				EnvKit.install(nil, Instance.new("Folder")) -- the committed data
				expect(EnvKit.signature(Kit.prop(id))).toBe(reference)
			end
			if next(CommittedData.props) == nil then
				EnvKit.install(nil, nil)
				expect(Kit.envMeshStatus().props).toBe(0)
			end
		end
	)

	it("is the committed state: valid data, and EnvMesh.has agrees with the listed ids", function()
		expect(CommittedData.schema_version).toBe(1)
		expect(CommittedData.unit).toBe("stud")
		expect(type(CommittedData.props)).toBe("table")
		EnvKit.install(nil, nil)
		expect(EnvMesh.has("tree_oak_01")).toBe(
			next(CommittedData.props) ~= nil and CommittedData.props.tree_oak_01 ~= nil
		)
	end)

	it("clones an id the data does not list exactly as before, whatever it holds", function()
		local assets = EnvKit.assets(data, { all = { dirty = true } })
		EnvKit.install({ schema_version = 1, unit = "stud", props = {} }, assets)
		local template = assets.tree_oak_01 :: Model
		local clone = Kit.prop("tree_oak_01")
		expect(isStandIn(clone)).toBe(false)
		expect(isMesh(clone)).toBe(false)
		expect(#clone:GetDescendants()).toBe(#template:GetDescendants()) -- untouched: scripts and all
		expect(clone:FindFirstChildWhichIsA("Script", true)).never.toBeNil()
		-- the old behaviour for a bare Part Model
		local folder = Instance.new("Folder")
		local plain = Instance.new("Model")
		plain.Name = "tree_oak_02"
		Instance.new("Part").Parent = plain
		plain.Parent = folder
		Kit.setAssetSource(folder)
		expect(Kit.prop("tree_oak_02").Name).toBe("tree_oak_02")
		expect(isStandIn(Kit.prop("tree_oak_02"))).toBe(false)
	end)

	it(
		"falls back for something that is not a Model, an id that is missing, and a Model that cannot be a prop",
		function()
			local bad: { [string]: any } = {
				["a bare MeshPart"] = { asMeshPart = true },
				["no PrimaryPart"] = { noRoot = true },
				["no MeshPart"] = { noMesh = true },
				["no MeshId"] = { noMeshId = true },
			}
			for name, opts in bad do
				EnvKit.install(data, EnvKit.assets(data, { all = opts }))
				for _, id in { "tree_oak_01", "bush_01", "resource_stone_01" } do
					local prop = Kit.prop(id)
					if not isStandIn(prop) then
						error(`'{name}': {id} was not the stand-in`)
					end
				end
				expect(EnvMesh.status().accepted).toBe(0)
				EnvKit.uninstall()
			end
			EnvKit.install(data, EnvKit.assets(data, { omit = { bush_01 = true } }))
			expect(isStandIn(Kit.prop("bush_01"))).toBe(true)
			expect(isMesh(Kit.prop("bush_03"))).toBe(true) -- the others are fine
		end
	)

	it("rejects a template that cannot be cloned (Archivable false clones to nil) without erroring", function()
		EnvKit.install(data, EnvKit.assets(data, {}))
		local messages = {}
		EnvMesh.setLogger(function(message)
			table.insert(messages, message)
		end)
		local ready, why = EnvMesh.accept("bush_01", nil)
		EnvMesh.setLogger(nil)
		expect(ready).toBeNil()
		expect(string.find(tostring(why), "cannot be cloned", 1, true)).never.toBeNil()
		expect(EnvMesh.status().rejected.bush_01).toBe(why)
		expect(#messages).toBe(1)
		-- an id the data does not list passes through, nil or not
		local passed, whyNot = EnvMesh.accept("prop_goods_01", nil)
		expect(passed).toBeNil()
		expect(whyNot).toBeNil()
	end)

	it("rejects a Model whose bounds are not the data's: scale, axes, a moved pivot, a missing mesh part", function()
		local bad: { [string]: any } = {
			["scaled 28x (a unit mistake)"] = { scale = Vector3.new(28, 28, 28) },
			["a little big"] = { scale = Vector3.new(1.1, 1, 1) },
			["axes swapped"] = { scale = Vector3.new(0.5, 3, 1) },
			["shifted off the base centre"] = { shift = Vector3.new(0, 3, 0) },
			["shifted sideways"] = { shift = Vector3.new(2, 0, 0) },
		}
		for name, opts in bad do
			EnvKit.install(data, EnvKit.assets(data, { all = opts }))
			local prop = Kit.prop("tree_pine_01")
			if not isStandIn(prop) then
				error(`'{name}' was accepted`)
			end
			expect(EnvMesh.status().rejected.tree_pine_01).never.toBeNil()
			EnvKit.uninstall()
		end
	end)

	it("accepts a size within the tolerance (+/- 0.1, or 0.5 % of a large dimension)", function()
		local size = data.props.tree_pine_01.size
		for _, nudge in { 0.05, -0.05, 0.09 } do
			EnvKit.install(
				data,
				EnvKit.assets(data, {
					per = {
						tree_pine_01 = {
							scale = Vector3.new(1 + nudge / size[1], 1 + nudge / size[2], 1 + nudge / size[3]),
						},
					},
				})
			)
			expect(isMesh(Kit.prop("tree_pine_01"))).toBe(true)
			EnvKit.uninstall()
		end
		EnvKit.install(
			data,
			EnvKit.assets(data, { per = { farm_field_wheat_01 = { scale = Vector3.new(1.004, 1, 1) } } })
		)
		expect(isMesh(Kit.prop("farm_field_wheat_01"))).toBe(true) -- 37 studs: 0.15 off is inside 0.5 %
		EnvKit.install(
			data,
			EnvKit.assets(data, { per = { farm_field_wheat_01 = { scale = Vector3.new(1.02, 1, 1) } } })
		)
		expect(isStandIn(Kit.prop("farm_field_wheat_01"))).toBe(true)
	end)

	it("logs a rejection once per id and never errors; Kit.envMeshStatus says why", function()
		EnvKit.install(data, EnvKit.assets(data, { per = { tree_oak_02 = { scale = Vector3.new(2, 2, 2) } } }))
		for _ = 1, 5 do
			local ok, prop = pcall(Kit.prop, "tree_oak_02")
			expect(ok).toBe(true)
			expect(isStandIn(prop)).toBe(true)
		end
		expect(#EnvKit.logs).toBe(1)
		expect(EnvKit.logs[1]).toContain("tree_oak_02")
		expect(EnvKit.logs[1]).toContain("size")
		expect(EnvKit.logs[1]).toContain("stand-in")
		expect(isMesh(Kit.prop("tree_oak_01"))).toBe(true)
		expect(#EnvKit.logs).toBe(1) -- a good prop logs nothing
		local status = Kit.envMeshStatus()
		expect(status.props).toBe(#EnvKit.ids(data))
		expect(status.rejected.tree_oak_02).toContain("size")
		expect(status.accepted).toBe(1)
		-- a second id logs its own line, once
		EnvKit.install(data, EnvKit.assets(data, { all = { noMeshId = true } }))
		Kit.prop("bush_01")
		Kit.prop("bush_03")
		Kit.prop("bush_01")
		expect(#EnvKit.logs).toBe(2)
		expect(EnvKit.logs[2]).toContain("bush_03")
	end)

	it("never errors on malformed data: a bad entry is a stand-in", function()
		local entries: { [string]: any } = {
			["not a table"] = 5,
			["no size"] = { family = "tree", bbox_center = { 0, 1, 0 } },
			["size not numbers"] = { family = "tree", size = { 1, "x", 3 }, bbox_center = { 0, 1, 0 } },
		}
		for name, entry in entries do
			local custom = { schema_version = 1, unit = "stud", props = { tree_oak_01 = entry } }
			EnvKit.install(custom, EnvKit.assets(data))
			local ok, prop = pcall(Kit.prop, "tree_oak_01")
			if not ok then
				error(`'{name}' threw: {prop}`)
			end
			expect(isStandIn(prop)).toBe(true)
			EnvKit.uninstall()
		end
	end)
end)

-- ------------------------------------------------------------------ the prepared prop

describe("an accepted mesh prop behaves like a stand-in: pivot at the base centre, flags, colliders", function()
	local data = EnvKit.fixture()

	for _, folder in { false, true } do
		it(`is a Model(assetId) with Root and Body, from Assets{if folder then ".EnvKit" else ""}`, function()
			EnvKit.install(data, EnvKit.assets(data, { folder = folder }))
			for _, id in EnvKit.ids(data) do
				local def = data.props[id]
				local prop = Kit.prop(id)
				expect(isMesh(prop)).toBe(true)
				expect(isStandIn(prop)).toBe(false)
				expect(prop.Name).toBe(id)
				expect(prop.ClassName).toBe("Model")
				local root = prop.PrimaryPart :: BasePart
				expect(root.Name).toBe("Root")
				expect(root.Transparency).toBe(1)
				expect(root.Anchored).toBe(true)
				expect(root.CanCollide).toBe(false)
				expect(root.CanTouch).toBe(false)
				-- the pivot is the base centre: PivotOffset lands the pivot on the ground under the mesh
				local pivot = root.CFrame * root.PivotOffset
				expect(near(pivot, ORIGIN, 1e-4)).toBe(true)
				local body = childNamed(prop, "Body") :: MeshPart
				expect(body.ClassName).toBe("MeshPart")
				expect(body.Anchored).toBe(true)
				expect(body.CanCollide).toBe(false)
				expect(body.CanTouch).toBe(false)
				expect(body.CanQuery).toBe(true)
				expect(body.Massless).toBe(true)
				expect(body.CastShadow).toBe(true)
				expect(body.Transparency).toBe(0)
				expect(body.Material).toBe(Enum.Material.SmoothPlastic)
				expect(body.Color:ToHex()).toBe("ffffff") -- baked vertex colours, not the template's green
				expect(body.CollisionFidelity).toBe(Enum.CollisionFidelity.Box) -- the template's own: a game script cannot write it
				local centre, size = EnvKit.drawn(prop)
				expect((size - Vector3.new(def.size[1], def.size[2], def.size[3])).Magnitude).toBeLessThan(1e-3)
				expect((centre - Vector3.new(def.bbox_center[1], def.bbox_center[2], def.bbox_center[3])).Magnitude).toBeLessThan(
					1e-3
				)
				expect(centre.Y - size.Y / 2).toBeNear(0, 1e-3) -- stands on y = 0
				-- far fewer parts than the part-built prop
				EnvKit.install(data, nil)
				local standIn = Kit.prop(id)
				EnvKit.install(data, EnvKit.assets(data, { folder = folder }))
				expect(count(prop)).toBeLessThanOrEqual(3)
				expect(count(prop)).toBeLessThan(count(standIn))
			end
		end)
	end

	it(
		"adds the invisible solid Collider the stand-ins' trunks and rocks give: family defaults, the data's override, none",
		function()
			EnvKit.install(data, EnvKit.assets(data))
			local expectedBox = {
				tree_oak_01 = { 3.4, 7, 3.4 }, -- 20 % of 19.2 is 3.84: capped at 3.4; up to the 7 studs units collide at
				tree_birch_01 = { 1.92, 7, 1.92 },
				bush_01 = { 4.2, 3, 3.96 },
				rock_boulder_m_01 = { 4.8, 5, 6.72 },
				rock_boulder_l_01 = { 10, 6, 8 }, -- the data's `collider`
				resource_stone_01 = { 12.8, 7, 8.16 },
				farm_haystack_01 = { 5.6, 6, 5.12 },
				plant_flowers_01 = false, -- `collider = false`
				farm_field_wheat_01 = false, -- a crop blocks nothing
			}
			for id, box in expectedBox do
				local prop = Kit.prop(id)
				local collider = childNamed(prop, "Collider")
				if box == false then
					expect(collider).toBeNil()
				else
					expect(collider).never.toBeNil()
					expect(collider.ClassName).toBe("Part")
					for i, axis in { "X", "Y", "Z" } do
						expect(collider.Size[axis]).toBeNear(box[i], 0.01)
					end
					expect(collider.Transparency).toBe(1)
					expect(collider.CanCollide).toBe(true)
					expect(collider.CanQuery).toBe(false) -- never catches a placement or selection raycast
					expect(collider.CanTouch).toBe(false)
					expect(collider.Anchored).toBe(true)
					expect(collider.CastShadow).toBe(false)
					expect(collider.Size.Y).toBeLessThanOrEqual(EnvMesh.SOLID_HEIGHT)
					-- standing on the ground at the base centre
					expect(collider.CFrame.Position.X).toBeNear(0, 1e-4)
					expect(collider.CFrame.Position.Z).toBeNear(0, 1e-4)
					expect(collider.CFrame.Position.Y - collider.Size.Y / 2).toBeNear(0, 1e-4)
				end
			end
			expect(EnvMesh.SOLID_HEIGHT).toBe(7) -- WorldService.COLLIDE_HEIGHT
			expect(WorldDef.new(MockEnv.new({ seed = 1 }), nil).COLLIDE_HEIGHT).toBe(EnvMesh.SOLID_HEIGHT)
		end
	)

	it(
		"deletes everything but the geometry: scripts, SurfaceAppearance, decals, welds, folders, stray parts, attributes, tags",
		function()
			local assets = EnvKit.assets(data, { all = { dirty = true } })
			EnvKit.install(data, assets)
			local template = assets.tree_oak_01 :: Model
			local before = #template:GetDescendants()
			for _, id in { "tree_oak_01", "bush_01", "resource_stone_01" } do
				local prop = Kit.prop(id)
				expect(isMesh(prop)).toBe(true)
				local names = {}
				for _, d in prop:GetDescendants() do
					table.insert(names, `{d.ClassName}:{d.Name}`)
					expect(d:IsA("BasePart")).toBe(true) -- only parts: Root, Body, Collider
					expect(#d:GetChildren()).toBe(0)
					for name in d:GetAttributes() do
						error(`{id}: {d.Name} kept the attribute {name}`)
					end
					expect(#d:GetTags()).toBe(0)
				end
				table.sort(names)
				expect(names[1]).toBe("MeshPart:Body")
				expect(names[2]).toBe("Part:Collider")
				expect(names[3]).toBe("Part:Root")
				expect(#names).toBe(3)
				expect(#prop:GetTags()).toBe(0)
				local attrs = 0
				for name in prop:GetAttributes() do
					attrs += 1
					expect(name).toBe("KitEnvMesh")
				end
				expect(attrs).toBe(1)
				expect(prop:FindFirstChildWhichIsA("LuaSourceContainer", true)).toBeNil()
			end
			expect(#template:GetDescendants()).toBe(before) -- the template in Assets is untouched
			expect(template:FindFirstChildWhichIsA("Script", true)).never.toBeNil()
		end
	)

	it("lifts a MeshPart out of a nested Model and keeps it where it was", function()
		EnvKit.install(data, EnvKit.assets(data, { all = { nested = true } }))
		local prop = Kit.prop("tree_birch_01")
		expect(isMesh(prop)).toBe(true)
		expect((childNamed(prop, "Body") :: BasePart).Parent).toBe(prop)
		expect(prop:FindFirstChild("Wrapper")).toBeNil()
		local centre = EnvKit.drawn(prop)
		expect(centre.Y).toBeNear(data.props.tree_birch_01.bbox_center[2], 1e-3)
	end)

	it("is deterministic and independent: equal calls are equal props, and the template never changes", function()
		local assets = EnvKit.assets(data, { folder = true })
		EnvKit.install(data, assets)
		for _, id in EnvKit.ids(data) do
			local a, b = Kit.prop(id), Kit.prop(id)
			expect(EnvKit.signature(a)).toBe(EnvKit.signature(b))
			expect(a).never.toBe(b)
			a.PrimaryPart.CFrame = CFrame.new(50, 0, 50);
			(childNamed(a, "Body") :: BasePart).Color = Color3.new(1, 0, 0)
			expect(EnvKit.signature(Kit.prop(id))).toBe(EnvKit.signature(b))
		end
		expect(Kit.envMeshStatus().accepted).toBeGreaterThan(#EnvKit.ids(data))
	end)

	it("keeps every stand-in as it was: the same signature with and without the mesh machinery", function()
		-- ids the data does not list build the stand-in whatever the folder holds elsewhere
		EnvKit.install(
			{ schema_version = 1, unit = "stud", props = {} },
			EnvKit.assets(data, { omit = { bush_02 = true } })
		)
		local reference = {}
		for _, id in { "bush_02", "tree_oak_04", "rock_boulder_s_01", "plant_flowers_02", "farm_field_wheat_02" } do
			reference[id] = EnvKit.signature(Kit.prop(id))
		end
		EnvKit.install(data, EnvKit.assets(data, { omit = { bush_02 = true } }))
		for id, signature in reference do
			expect(EnvKit.signature(Kit.prop(id))).toBe(signature)
			expect(isStandIn(Kit.prop(id))).toBe(true)
		end
	end)
end)

-- ------------------------------------------------------------------ what WorldService assumes

describe("WorldService places and decorates a mesh prop like a stand-in", function()
	local data = EnvKit.fixture()
	local probe = WorldDef.new(MockEnv.new({ seed = 1 }), nil)
	local placeModel, decorate = probe._placeModel, probe._decorate -- the class's private helpers, through an instance

	it("lands the pivot on the placement CFrame, moving Root, Body and Collider together", function()
		EnvKit.install(data, EnvKit.assets(data))
		local target = CFrame.new(120, 14, -40) * CFrame.Angles(0, 1.1, 0)
		for _, id in { "tree_oak_01", "resource_stone_01", "plant_flowers_01" } do
			local prop = Kit.prop(id)
			local rest = {}
			local root = prop.PrimaryPart :: BasePart
			for _, p in EnvKit.parts(prop) do
				rest[p] = root.CFrame:ToObjectSpace(p.CFrame)
			end
			placeModel(prop, target)
			expect(near(root.CFrame * root.PivotOffset, target, 1e-3)).toBe(true)
			for _, p in EnvKit.parts(prop) do
				expect(near(root.CFrame:ToObjectSpace(p.CFrame), rest[p], 1e-3)).toBe(true) -- rigid
			end
			local body = childNamed(prop, "Body") :: BasePart
			local centre = data.props[id].bbox_center
			expect(((target:Inverse() * body.CFrame).Position - Vector3.new(centre[1], centre[2], centre[3])).Magnitude).toBeLessThan(
				1e-3
			)
		end
	end)

	it("lets decorate through: CanTouch off, the footprint plate not queryable, the solid base still solid", function()
		EnvKit.install(data, EnvKit.assets(data))
		for _, id in { "tree_oak_01", "bush_01", "rock_boulder_m_01", "tree_pine_02" } do
			local prop = Kit.prop(id)
			placeModel(prop, CFrame.new(10, 3, 10))
			decorate(prop, 3)
			local root = prop.PrimaryPart :: BasePart
			expect(root.CanQuery).toBe(false)
			for _, p in EnvKit.parts(prop) do
				expect(p.CanTouch).toBe(false)
			end
			local collider = childNamed(prop, "Collider") :: BasePart
			expect(collider.CanCollide).toBe(true) -- stands at the ground: below WorldService.COLLIDE_HEIGHT
			expect((childNamed(prop, "Body") :: BasePart).CanCollide).toBe(false)
		end
	end)

	it(
		"builds the whole valley with mesh props: nodes tagged, attributes set, far fewer parts, same placements",
		function()
			local function boot(withMeshes: boolean)
				local env = MockEnv.new({ seed = 1 })
				if withMeshes then
					local forge = Instance.new("Folder")
					forge.Name = "Forge"
					forge.Parent = env.ReplicatedStorage
					local assets = EnvKit.assets(data, { folder = true })
					assets.Parent = forge
				end
				EnvMesh.setData(if withMeshes then data else nil)
				local svc = WorldDef.new(env, nil)
				svc.terrain = Terrain.recorder()
				svc:start()
				env.mock:advance(30)
				return env, svc
			end
			local envA, plain = boot(false)
			local plainParts, plainProps = plain.stats.parts, plain.stats.props
			local plainNodes = #envA.CollectionService:GetTagged("ResourceNode")
			plain:destroy()
			EnvKit.uninstall()
			local env, svc = boot(true)
			expect(svc:isReady()).toBe(true)
			expect(svc.stats.props).toBe(plainProps) -- the same placements
			expect(svc.stats.parts).toBeLessThan(plainParts)
			local nodes = env.CollectionService:GetTagged("ResourceNode")
			expect(#nodes).toBe(plainNodes)
			expect(#nodes).toBe(#Layout.resourceNodes)
			local meshNodes, standInNodes = 0, 0
			local byId = {}
			for _, n in Layout.resourceNodes do
				byId[n.id] = n
			end
			for _, node in nodes do
				local layoutNode = byId[node:GetAttribute("NodeId")]
				expect(layoutNode).never.toBeNil()
				expect(node:GetAttribute("Resource")).toBe(layoutNode.resource)
				expect(node.Name).toBe(layoutNode.id)
				expect(node.PrimaryPart).never.toBeNil()
				if data.props[layoutNode.assetId] then
					expect(isMesh(node)).toBe(true)
					meshNodes += 1
				else
					expect(isStandIn(node)).toBe(true)
					standInNodes += 1
				end
			end
			expect(meshNodes).toBeGreaterThan(0)
			expect(standInNodes).toBeGreaterThan(0) -- the placeholder does not cover every id: a mixed world
			local meshProps = 0
			for _, d in env.Workspace:GetDescendants() do
				if d:IsA("Model") and isMesh(d) then
					meshProps += 1
					expect(d:GetAttribute("Feature") ~= nil or d:GetAttribute("NodeId") ~= nil).toBe(true)
				end
			end
			expect(meshProps).toBeGreaterThan(100)
			svc:destroy()
		end
	)
end)

-- ------------------------------------------------------------------ the converter's output and the data

describe("env_to_luau.py output is the data Kit/EnvMesh reads", function()
	it("loads as the same table as the env.json it came from", function()
		local json = EnvKit.fixture()
		expect(Fixture.schema_version).toBe(json.schema_version)
		expect(Fixture.unit).toBe(json.unit)
		local known =
			{ "family", "bbox_center", "size", "tris", "tint", "standin_size", "node", "collider", "fit_note" }
		local n = 0
		for id, def in json.props do
			n += 1
			for _, key in known do
				expect(Fixture.props[id][key]).toEqual(def[key])
			end
		end
		local luaCount = 0
		for _ in Fixture.props do
			luaCount += 1
		end
		expect(luaCount).toBe(n)
		expect(n).toBe(15)
	end)

	it("builds the same props from the generated module as from the JSON", function()
		local json = EnvKit.fixture()
		EnvKit.install(Fixture, EnvKit.assets(json, { folder = true }))
		local a = EnvKit.signature(Kit.prop("rock_boulder_l_01"))
		EnvKit.install(json, EnvKit.assets(json, { folder = true }))
		expect(EnvKit.signature(Kit.prop("rock_boulder_l_01"))).toBe(a)
	end)

	it("passes the converter's self-test, and its budget and the committed fixtures are current", function()
		local function run(args: { string }): (boolean, string)
			local result = process.exec("python3", args)
			return result.ok, result.stdout .. result.stderr
		end
		local ok, out = run({ "games/game-001/art/env_kit/env_to_luau.py", "--selftest" })
		if not ok then
			error(`env_to_luau.py --selftest failed:\n{out}`)
		end
		expect(out).toContain("selftest: PASS")
		local budgetOk, budgetOut = run({ "games/game-001/art/env_kit/env_to_luau.py", "--print-budget" })
		expect(budgetOk).toBe(true)
		local budget = require("@lune/serde").decode("json", budgetOut)
		expect(budget.max_mesh_tris).toBe(EnvMesh.MAX_MESH_TRIS)
		expect(budget.families).toEqual(EnvMesh.FAMILIES)
		for family, limits in EnvMesh.BUDGET do
			expect(budget.budget[family]).toEqual({ min = limits.min, max = limits.max })
		end
		local fresh, why = run({ "games/game-001/art/env_kit/make_placeholder_env.py", "--check" })
		if not fresh then
			error(`the placeholder env.json is out of date: {why}`)
		end
		local luau, whyLuau = run({
			"games/game-001/art/env_kit/env_to_luau.py",
			"--in",
			EnvKit.FIXTURE_JSON,
			"--out",
			"games/game-001/tests/world/fixtures/EnvMeshFixture.luau",
			"--check",
		})
		if not luau then
			error(`EnvMeshFixture.luau is out of date: {whyLuau}`)
		end
		local fs = require("@lune/fs")
		if fs.isFile("games/game-001/art/env_kit/env.json") then
			local current, whyData = run({ "games/game-001/art/env_kit/env_to_luau.py", "--check" })
			if not current then
				error(`Kit/EnvMeshData.luau is out of date: {whyData}`)
			end
		end
	end)
end)

-- With real data committed: every id is one the world places, inside its family budget, drawn like the part-built prop.
local function standInBounds(id: string): (Vector3, Vector3)
	Kit.setAssetSource(nil)
	EnvMesh.setData({ schema_version = 1, unit = "stud", props = {} })
	local model = Kit.prop(id)
	EnvMesh.setData(nil)
	return EnvKit.drawn(model)
end

if next(CommittedData.props) ~= nil then
	describe("the committed env kit (Kit/EnvMeshData) against the world and the part-built props", function()
		local worldIds: { [string]: boolean } = {}
		local dressed = { crimson = true, azure = true, emerald = true, gold = true }
		for _, placement in WorldPlan.props(Layout, dressed, WorldPlan.FULL_DENSITY) do
			worldIds[placement.assetId] = true
		end
		local nodeIds: { [string]: boolean } = {}
		for _, node in Layout.resourceNodes do
			worldIds[node.assetId] = true
			nodeIds[node.assetId] = true
		end

		it("lists only ids the world places (a typo would silently build a crate)", function()
			for id in CommittedData.props do
				if not worldIds[id] then
					error(`{id} is in EnvMeshData but WorldPlan and Layout never place it`)
				end
			end
		end)

		it("marks exactly the resource-node ids as nodes", function()
			for id, def in CommittedData.props do
				expect(def.node).toBe(nodeIds[id] == true)
			end
		end)

		it("keeps every prop inside its family's triangle budget and Roblox's cap", function()
			for id, def in CommittedData.props do
				local limits = EnvMesh.BUDGET[def.family]
				assert(limits, `{id}: unknown family {def.family}`)
				if def.tris < limits.min or def.tris > limits.max then
					error(`{id}: {def.tris} triangles, the {def.family} budget is {limits.min}-{limits.max}`)
				end
				expect(def.tris).toBeLessThanOrEqual(EnvMesh.MAX_MESH_TRIS)
			end
		end)

		it("declares the stand-in size the part-built prop really has (within 5 %)", function()
			for id, def in CommittedData.props do
				local _, size = standInBounds(id)
				for i, axis in { "X", "Y", "Z" } do
					local declared = def.standin_size[i]
					if math.abs(size[axis] - declared) > 0.05 * declared + 0.1 then
						error(`{id}: standin_size {axis} is {declared}, the live stand-in draws {size[axis]}`)
					end
				end
			end
		end)

		it("fits the part-built prop it replaces: footprint, height and base (fit_note excepted)", function()
			for id, def in CommittedData.props do
				if def.fit_note == nil then
					local _, size = standInBounds(id)
					local footprint = math.max(def.size[1], def.size[3]) / math.max(size.X, size.Z)
					local height = def.size[2] / size.Y
					local lo, hi = 0.85, if def.node then 1.02 else 1.15
					if footprint < lo or footprint > hi then
						error(`{id}: footprint is {math.floor(footprint * 100)} % of the stand-in's`)
					end
					if height < 0.75 or height > 1.25 then
						error(`{id}: height is {math.floor(height * 100)} % of the stand-in's`)
					end
				end
				-- the base stands on the ground: rocks, boulders and nodes sink a little on purpose (the kit's rule and the
				-- converter's: from 1.0 stud below y = 0 up to 0.5 above it, the same window env_to_luau.py validates)
				local base = def.bbox_center[2] - def.size[2] / 2
				if base < -1.0 or base > 0.5 then
					error(`{id}: the base is at y = {base}, a prop stands on y = 0 (-1.0 to 0.5)`)
				end
			end
		end)

		it("builds an accepted prop for every listed id from a fake import of it", function()
			EnvKit.install(CommittedData, EnvKit.assets(CommittedData, { folder = true }))
			for id in CommittedData.props do
				local prop = Kit.prop(id)
				if not isMesh(prop) then
					error(`{id}: {tostring(EnvMesh.status().rejected[id])}`)
				end
			end
			-- and reports what the world still draws part-built (information, not a failure)
			local missing = 0
			for id in worldIds do
				if not CommittedData.props[id] then
					missing += 1
				end
			end
			expect(missing).toBeGreaterThanOrEqual(0)
		end)
	end)
end
