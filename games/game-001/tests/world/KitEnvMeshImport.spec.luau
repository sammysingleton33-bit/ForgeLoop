--!nonstrict
--[[
	blender/studio/import_env_kit.luau (FL-0136, D-057 (18)-(20)): the Studio command-bar script that wraps the imported
	nature meshes into Models under ReplicatedStorage.Forge.Assets.EnvKit. HEADLESS and UNVERIFIED IN STUDIO: the script's
	source is loaded into Lune with luau.load and run against FAKE instance trees (a Workspace of MeshParts, a
	ReplicatedStorage with the project's Forge.Assets and Game.Kit.EnvMeshData), the nearest thing to the importer this
	machine has. Nothing here says the real Bulk Import produces what the fake does (names, sizes, rotation, MeshIds): that
	is the owner's first run, and the script's report is how it will tell.

	Covers: the happy path end to end into the real Kit (Kit.prop accepts every Model the script made), the shape of the
	wrapper, idempotence, moving vs cloning, FLAT, the strip rules, every problem it reports (missing, wrong size, no mesh,
	rotated, textured, duplicates, strays), dry run, a place that is not the project's, and the promises in its header
	(no network, no asset-id require, no scripts created).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local EnvMesh = require("@game/ReplicatedStorage/Game/Kit/EnvMesh")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local EnvKit = require("./fixtures/EnvMeshKit")

local SCRIPT_PATH = "blender/studio/import_env_kit.luau"
local SOURCE_TEXT = fs.readFile(SCRIPT_PATH)
-- the script without its comments: what it DOES, as opposed to what its header says it does not
local CODE_TEXT = string.gsub(string.gsub(SOURCE_TEXT, "%-%-%[%[.-%]%]", ""), "%-%-[^\n]*", "")

afterEach(function()
	EnvKit.uninstall()
end)

type Place = {
	Workspace: Folder,
	ReplicatedStorage: Folder,
	assets: Folder?,
	scene: Model,
	dataModule: ModuleScript?,
	values: { [Instance]: any },
}

-- A fake place: Workspace with the imported scene (one MeshPart per id, laid out on a grid as Blender leaves them),
-- ReplicatedStorage with Forge.Assets and Game.Kit.{EnvMeshData, Kit}. opts: omit, noDataModule, noAssets, per = { [id] = fn(part) }.
local function newPlace(data: any, opts: any?): Place
	local o = opts or {}
	local workspace = Instance.new("Folder")
	workspace.Name = "Workspace"
	local rs = Instance.new("Folder")
	rs.Name = "ReplicatedStorage"
	local values: { [Instance]: any } = {}
	local game = Instance.new("Folder")
	game.Name = "Game"
	game.Parent = rs
	local kitFolder = Instance.new("Folder")
	kitFolder.Name = "Kit"
	kitFolder.Parent = game
	local dataModule: ModuleScript? = nil
	if not o.noDataModule then
		dataModule = Instance.new("ModuleScript")
		dataModule.Name = "EnvMeshData"
		dataModule.Parent = kitFolder
		values[dataModule] = data
	end
	local kitModule = Instance.new("ModuleScript")
	kitModule.Name = "Kit"
	kitModule.Parent = kitFolder
	values[kitModule] = Kit
	local assets: Folder? = nil
	if not o.noAssets then
		local forge = Instance.new("Folder")
		forge.Name = "Forge"
		forge.Parent = rs
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = forge
	end
	local scene = Instance.new("Model")
	scene.Name = "env_kit"
	scene.Parent = workspace
	for n, id in EnvKit.ids(data) do
		if not (o.omit and o.omit[id]) then
			local def = data.props[id]
			local part = Instance.new("MeshPart")
			part.Name = id
			part.MeshId = `rbxassetid://{700000 + n}`
			part.Size = Vector3.new(def.size[1], def.size[2], def.size[3])
			part.CFrame = CFrame.new(n * 40, def.size[2] / 2, 0) -- the Blender scene's layout is not the data's: the wrapper must not care
			part.Anchored = true
			part.Parent = scene
			if o.per and o.per[id] then
				o.per[id](part)
			end
		end
	end
	return {
		Workspace = workspace,
		ReplicatedStorage = rs,
		assets = assets,
		scene = scene,
		dataModule = dataModule,
		values = values,
	}
end

-- Runs the script's source over the fake place. `edits` replaces text in the settings block (MOVE, DRY_RUN, FLAT, SOURCE).
local function runScript(place: Place, edits: { [string]: string }?): (any, { string }, { string })
	local printed, warned = {}, {}
	local text = SOURCE_TEXT
	for from, to in edits or {} do
		local replaced, n = string.gsub(text, from, function()
			return to
		end)
		assert(n == 1, `settings line '{from}' is not in the script exactly once`)
		text = replaced
	end
	local fakeGame = {
		GetService = function(_, name)
			if name == "ReplicatedStorage" then
				return place.ReplicatedStorage
			end
			return { SetWaypoint = function() end, Set = function() end } -- ChangeHistoryService, Selection
		end,
	}
	local chunk = luau.load(text, {
		debugName = "import_env_kit",
		environment = {
			game = fakeGame,
			workspace = place.Workspace,
			print = function(line)
				table.insert(printed, tostring(line))
			end,
			warn = function(line)
				table.insert(warned, tostring(line))
			end,
			require = function(module)
				local v = place.values[module]
				assert(v ~= nil, "require of something that is not a known ModuleScript")
				return v
			end,
			Instance = Instance,
			Vector3 = Vector3,
			Color3 = Color3,
			CFrame = CFrame,
		},
	})
	local report = chunk()
	return report, printed, warned
end

local function folderOf(place: Place): Instance?
	return if place.assets then place.assets:FindFirstChild("EnvKit") else nil
end

local function count(parent: Instance?): number
	return if parent then #parent:GetChildren() else 0
end

local function joined(lines: { string }): string
	return table.concat(lines, "\n")
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

describe("import_env_kit.luau: the Studio import script, against fake trees", function()
	local data = EnvKit.fixture()
	local N = #EnvKit.ids(data)

	it(
		"wraps each imported MeshPart in a Model(assetId) with an invisible Root at the base centre, under Assets.EnvKit",
		function()
			EnvMesh.setData(data)
			local place = newPlace(data)
			local report, printed, warned = runScript(place)
			expect(report.ok).toBe(true)
			expect(report.expected).toBe(N)
			expect(report.imported).toBe(N)
			expect(report.missing).toEqual({})
			expect(#warned).toBe(0)
			local folder = folderOf(place) :: Instance
			expect(folder.ClassName).toBe("Folder")
			expect(count(folder)).toBe(N)
			for _, id in EnvKit.ids(data) do
				local def = data.props[id]
				local model = folder:FindFirstChild(id) :: Model
				expect(model).never.toBeNil()
				expect(model.ClassName).toBe("Model")
				expect(#model:GetChildren()).toBe(2)
				local root = model.PrimaryPart :: BasePart
				expect(root.Name).toBe("Root")
				expect(root.ClassName).toBe("Part")
				expect(root.Transparency).toBe(1)
				expect(root.Anchored).toBe(true)
				expect(root.CanCollide).toBe(false)
				expect(root.CanTouch).toBe(false)
				expect(root.Massless).toBe(true)
				expect(near(root.CFrame * root.PivotOffset, CFrame.new(), 1e-4)).toBe(true) -- the pivot is the base centre
				expect(root.Size.X).toBeNear(def.size[1], 1e-3)
				expect(root.Size.Z).toBeNear(def.size[3], 1e-3)
				local body = model:FindFirstChild("Body") :: MeshPart
				expect(body.ClassName).toBe("MeshPart")
				expect(body.Anchored).toBe(true)
				expect(body.CanCollide).toBe(false)
				expect(body.CanTouch).toBe(false)
				expect(body.Massless).toBe(true)
				expect(body.CastShadow).toBe(true)
				expect((body.Size - Vector3.new(def.size[1], def.size[2], def.size[3])).Magnitude).toBeLessThan(1e-4)
				expect(
					(body.CFrame.Position - Vector3.new(def.bbox_center[1], def.bbox_center[2], def.bbox_center[3])).Magnitude
				).toBeLessThan(1e-4)
				expect(body.MeshId).never.toBe("")
			end
			expect(count(place.scene)).toBe(N) -- cloned: the originals stay in Workspace to delete
			expect(joined(printed)).toContain("RESULT: OK")
			expect(joined(printed)).toContain("Triangles: not available in Studio")
			expect(report.accepted).toBe(N) -- the Kit's own smoke test
			expect(joined(printed)).toContain(`Kit.prop accepts {N} of {N} props`)
		end
	)

	it(
		"makes Kit.prop build the mesh props from the folder it made, and the stand-ins when the folder is removed",
		function()
			local place = newPlace(data)
			runScript(place)
			EnvKit.install(data, place.assets)
			for _, id in EnvKit.ids(data) do
				local prop = Kit.prop(id)
				if prop:GetAttribute("KitEnvMesh") ~= true then
					error(`{id}: {tostring(EnvMesh.status().rejected[id])}`)
				end
				local def = data.props[id]
				local centre, size = EnvKit.drawn(prop)
				expect((size - Vector3.new(def.size[1], def.size[2], def.size[3])).Magnitude).toBeLessThan(1e-3)
				expect(centre.Y - size.Y / 2).toBeNear(0, 1e-3)
			end -- revert, as the owner procedure says: delete the EnvKit folder
			(folderOf(place) :: Instance):Destroy()
			expect(Kit.prop("tree_oak_01"):GetAttribute("KitStandIn")).toBe(true)
		end
	)

	it("puts the Models straight under Assets with FLAT = true, and Kit.prop finds them there too", function()
		local place = newPlace(data)
		local report = runScript(place, { ["local FLAT = false"] = "local FLAT = true" })
		expect(report.ok).toBe(true)
		expect(folderOf(place)).toBeNil()
		expect(count(place.assets)).toBe(N)
		EnvKit.install(data, place.assets)
		expect(Kit.prop("bush_01"):GetAttribute("KitEnvMesh")).toBe(true)
	end)

	it("is idempotent: a second run leaves the same folder, not a second copy", function()
		local place = newPlace(data)
		runScript(place)
		local first = {}
		for _, child in (folderOf(place) :: Instance):GetChildren() do
			first[child.Name] = true
		end
		local report = runScript(place)
		expect(report.ok).toBe(true)
		local folder = folderOf(place) :: Instance
		expect(count(folder)).toBe(N)
		expect(count(place.assets)).toBe(1) -- one EnvKit folder, not two
		for _, child in folder:GetChildren() do
			expect(first[child.Name]).toBe(true) -- the same ids, each replaced rather than added again
		end
	end)

	it(
		"moves the meshes instead with MOVE = true, and a re-run with the scene gone keeps and checks the Models",
		function()
			local place = newPlace(data)
			local report = runScript(place, { ["local MOVE = false"] = "local MOVE = true" })
			expect(report.ok).toBe(true)
			expect(count(place.scene)).toBe(0)
			expect(count(folderOf(place))).toBe(N)
			local again, printed = runScript(place)
			expect(again.imported).toBe(0)
			expect(again.kept).toBe(N)
			expect(again.ok).toBe(true)
			expect(joined(printed)).toContain("RESULT: OK")
		end
	)

	it(
		"finds meshes nested in the importer's sub-models, takes SOURCE when set, and reports duplicate sources",
		function()
			local function withDecoy()
				local place = newPlace(data)
				local other = Instance.new("Model")
				other.Name = "other"
				other.Parent = place.Workspace
				local decoy = Instance.new("MeshPart")
				decoy.Name = "bush_01"
				decoy.MeshId = "rbxassetid://1"
				decoy.Size = Vector3.new(9, 9, 9)
				decoy.Parent = other
				return place
			end
			local wide = runScript(withDecoy())
			expect(#wide.duplicates).toBe(1)
			expect(wide.duplicates[1]).toContain("bush_01 (2 copies")
			expect(wide.ok).toBe(true) -- the first by full name is the scene's, which has the right size
			local narrow = runScript(
				withDecoy(),
				{ ["local SOURCE = nil"] = 'local SOURCE = workspace:FindFirstChild("env_kit")' }
			)
			expect(#narrow.duplicates).toBe(0)
			expect(narrow.ok).toBe(true)
			-- nested
			local place = newPlace(data)
			local group = Instance.new("Model")
			group.Name = "group"
			group.Parent = place.scene
			for _, child in place.scene:GetChildren() do
				if child:IsA("MeshPart") then
					child.Parent = group
				end
			end
			expect(runScript(place).imported).toBe(N)
		end
	)

	it("lists what is missing and says INCOMPLETE; the Kit smoke test shows the part-built remainder", function()
		EnvMesh.setData(data)
		local place = newPlace(data, { omit = { tree_oak_01 = true, bush_03 = true } })
		local report, printed = runScript(place)
		expect(report.ok).toBe(false)
		expect(report.missing).toEqual({ "bush_03", "tree_oak_01" })
		expect(report.imported).toBe(N - 2)
		expect(joined(printed)).toContain("MISSING props (2): bush_03; tree_oak_01")
		expect(joined(printed)).toContain("RESULT: INCOMPLETE")
		expect(report.accepted).toBe(N - 2)
		expect(#report.fallbacks).toBe(2)
		expect(joined(printed)).toContain("tree_oak_01: not in the folder")
		expect(folderOf(place):FindFirstChild("tree_oak_01")).toBeNil()
	end)

	it("flags a wrong size, a missing mesh, a rotated mesh and a texture, and keeps going", function()
		EnvMesh.setData(data)
		local place = newPlace(data, {
			per = {
				tree_oak_02 = function(part)
					part.Size = part.Size * 28
				end,
				bush_01 = function(part)
					part.MeshId = ""
				end,
				rock_boulder_m_01 = function(part)
					part.CFrame = part.CFrame * CFrame.Angles(math.rad(90), 0, 0)
				end,
				plant_flowers_01 = function(part)
					part.TextureID = "rbxassetid://424242"
				end,
			},
		})
		local report, printed, warned = runScript(place)
		expect(report.ok).toBe(false)
		expect(#report.wrongSize).toBe(1)
		expect(report.wrongSize[1]).toContain("tree_oak_02")
		expect(report.noMesh).toEqual({ "bush_01" })
		expect(#report.rotated).toBe(1)
		expect(report.rotated[1]).toContain("rock_boulder_m_01")
		expect(report.textured).toEqual({ "plant_flowers_01" })
		expect(joined(warned)).toContain("tree_oak_02: wrong size")
		expect(joined(warned)).toContain("bush_01: no MeshId")
		expect(joined(warned)).toContain("rock_boulder_m_01: rotated")
		expect(joined(printed)).toContain("TEXTURED")
		expect(joined(printed)).toContain("RESULT: INCOMPLETE")
		expect(report.imported).toBe(N) -- placed anyway; the Kit refuses what it cannot use
		-- the Kit's smoke test agrees: the wrong-size and the no-mesh props are part-built still
		expect(report.accepted).toBeLessThan(N)
		local fallbackText = joined(report.fallbacks)
		expect(fallbackText).toContain("tree_oak_02")
		expect(fallbackText).toContain("bush_01")
	end)

	it("accepts a size within the tolerance (0.1 stud, or 0.5 % of a large dimension)", function()
		local place = newPlace(data, {
			per = {
				tree_pine_01 = function(part)
					part.Size = part.Size + Vector3.new(0.09, 0.09, 0.09)
				end,
				farm_field_wheat_01 = function(part)
					part.Size = part.Size * Vector3.new(1.004, 1, 1)
				end,
			},
		})
		expect(runScript(place).ok).toBe(true)
		local over = newPlace(data, {
			per = {
				tree_pine_01 = function(part)
					part.Size = part.Size + Vector3.new(0.3, 0, 0)
				end,
			},
		})
		expect(runScript(over).ok).toBe(false)
	end)

	it(
		"strips everything but the geometry from the copy and lists it: scripts, PBR, decals, children, attributes, tags",
		function()
			EnvMesh.setData(data)
			local place = newPlace(data, {
				per = {
					tree_oak_01 = function(part)
						Instance.new("Script").Parent = part
						Instance.new("SurfaceAppearance").Parent = part
						Instance.new("Decal").Parent = part
						local nest = Instance.new("Folder")
						nest.Name = "Nest"
						nest.Parent = part
						Instance.new("ModuleScript").Parent = nest
						Instance.new("Attachment").Parent = part
						part:SetAttribute("Imported", "yes")
						part:SetAttribute("Layer", 3)
						part:AddTag("Stale")
					end,
				},
			})
			local report, printed = runScript(place)
			expect(report.ok).toBe(true)
			expect(report.scriptsRemoved).toBe(2)
			expect(#report.stripped).toBe(9) -- 6 instances + 2 attributes + 1 tag
			local text = joined(report.stripped)
			for _, needle in
				{
					"Script ",
					"SurfaceAppearance ",
					"Decal ",
					"Folder ",
					"ModuleScript ",
					"Attachment ",
					"Attribute Imported",
					"Attribute Layer",
					"Tag Stale",
				}
			do
				expect(text).toContain(needle)
			end
			expect(joined(printed)).toContain("stripped:")
			local model = folderOf(place):FindFirstChild("tree_oak_01") :: Model
			for _, d in model:GetDescendants() do
				expect(d:IsA("BasePart")).toBe(true) -- Root and Body only
				for name in d:GetAttributes() do
					error(`{d.Name} kept the attribute {name}`)
				end
				expect(#d:GetTags()).toBe(0)
				expect(#d:GetChildren()).toBe(0)
			end
			expect(#model:GetDescendants()).toBe(2)
			-- the original in Workspace is untouched (the script clones)
			local original = place.scene:FindFirstChild("tree_oak_01") :: MeshPart
			expect(#original:GetDescendants()).toBe(6)
			expect(original:GetAttribute("Imported")).toBe("yes")
			-- and the runtime accepts the result
			EnvKit.install(data, place.assets)
			expect(Kit.prop("tree_oak_01"):GetAttribute("KitEnvMesh")).toBe(true)
		end
	)

	it("ignores MeshParts that are not in the kit and counts them", function()
		local place = newPlace(data)
		local stray = Instance.new("MeshPart")
		stray.Name = "prop_barrel_01"
		stray.Parent = place.scene
		local report = runScript(place)
		expect(report.stray).toEqual({ "prop_barrel_01" })
		expect(folderOf(place):FindFirstChild("prop_barrel_01")).toBeNil()
	end)

	it("changes nothing in a dry run", function()
		local place = newPlace(data)
		local report, printed = runScript(place, { ["local DRY_RUN = false"] = "local DRY_RUN = true" })
		expect(report.dryRun).toBe(true)
		expect(report.imported).toBe(N)
		expect(folderOf(place)).toBeNil()
		expect(count(place.scene)).toBe(N)
		expect(joined(printed)).toContain("DRY RUN: nothing changed")
	end)

	it("stops without the data or the project's Assets, and says so when the data has no props yet", function()
		local noData = newPlace(data, { noDataModule = true })
		local stopped, _, warned = runScript(noData)
		expect(stopped.ok).toBe(false)
		expect(stopped.imported).toBe(0)
		expect(joined(warned)).toContain("no Kit/EnvMeshData")
		expect(folderOf(noData)).toBeNil()

		local foreign = newPlace(data, { noAssets = true })
		local halted, _, complaints = runScript(foreign)
		expect(halted.imported).toBe(0)
		expect(joined(complaints)).toContain("not the project's place")
		expect(count(foreign.scene)).toBe(N)

		local empty = newPlace(data)
		empty.values[empty.dataModule :: ModuleScript] = { schema_version = 1, unit = "stud", props = {} }
		local report, printed = runScript(empty)
		expect(report.ok).toBe(false)
		expect(joined(printed)).toContain("has no props yet")
		expect(folderOf(empty)).toBeNil()
	end)
end)

describe("import_env_kit.luau keeps its promises: no network, no asset-id require, no scripts created", function()
	it("never mentions the services and calls that reach outside the place", function()
		for _, banned in
			{
				"HttpService",
				"HttpGet",
				"RequestAsync",
				"InsertService",
				"MarketplaceService",
				"LoadAsset",
				"AssetService",
				"DataStoreService",
				"MessagingService",
				"TeleportService",
				"SetAsync",
				"loadstring",
				"getfenv",
			}
		do
			expect(string.find(CODE_TEXT, banned, 1, true)).toBeNil()
		end
	end)

	it("requires only ModuleScript instances found by path, never an id or a string", function()
		for call in string.gmatch(CODE_TEXT, "world%.require%(([^)]*)%)") do
			expect(string.find(call, "rbxassetid", 1, true)).toBeNil()
			expect(string.match(call, '^%s*"')).toBeNil()
			expect(string.match(call, "^%s*%d")).toBeNil()
		end
		expect(string.find(CODE_TEXT, "rbxassetid", 1, true)).toBeNil()
		local n = 0
		for _ in string.gmatch(CODE_TEXT, "world%.require") do
			n += 1
		end
		expect(n).toBe(2) -- the data (pcall(world.require, module)) and the Kit, both by instance
		expect(string.find(CODE_TEXT, "pcall(world.require, module)", 1, true)).never.toBeNil()
	end)

	it("creates no scripts: the Instance.new calls make a Folder, the Model and its Root Part only", function()
		local made = {}
		for class in string.gmatch(CODE_TEXT, 'Instance%.new%("(%w+)"%)') do
			table.insert(made, class)
		end
		table.sort(made)
		expect(made).toEqual({ "Folder", "Model", "Part" })
		expect(string.find(CODE_TEXT, "%.Source%s*=")).toBeNil()
	end)

	it("changes nothing outside ReplicatedStorage.Forge.Assets.EnvKit (checked on a run)", function()
		local data = EnvKit.fixture()
		local place = newPlace(data)
		local before = #place.Workspace:GetDescendants() + #place.ReplicatedStorage:GetDescendants()
		runScript(place)
		local added = #(folderOf(place) :: Instance):GetDescendants() + 1
		expect(#place.Workspace:GetDescendants() + #place.ReplicatedStorage:GetDescendants()).toBe(before + added)
		expect(count(place.scene)).toBe(#EnvKit.ids(data))
	end)
end)
