--!nonstrict
--[[
	blender/studio/import_char_kit.luau (FL-0135, D-057): the Studio command-bar script that puts the imported citizen kit
	under ReplicatedStorage.Forge.Assets.CitizenKit. HEADLESS and UNVERIFIED IN STUDIO: the script's source is loaded into
	Lune with luau.load and run against FAKE instance trees (a Workspace of MeshParts, a ReplicatedStorage with the project's
	Forge.Assets and Game.Kit.CharacterMeshData), which is the nearest thing to the importer this machine has. Nothing here says
	the real Bulk Import produces what the fake does (names, sizes, rotation, MeshIds): that is the owner's first run, and the
	script's report is how it will tell.

	Covers: the happy path end to end into the real Kit (the folder the script builds makes Kit.character return the mesh rig),
	idempotence, moving vs cloning, every problem it reports (missing, wrong size, no mesh, rotated, duplicates, strays,
	scripts), name-only mode, dry run, a place that is not the project's, and the promises in its header (no network, no
	asset-id require, no scripts created).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local CharacterMesh = require("@game/ReplicatedStorage/Game/Kit/CharacterMesh")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local MeshKit = require("./fixtures/CharacterMeshKit")

local SCRIPT_PATH = "blender/studio/import_char_kit.luau"
local SOURCE_TEXT = fs.readFile(SCRIPT_PATH)
-- the script without its comments: what it DOES, as opposed to what its header says it does not
local CODE_TEXT = string.gsub(string.gsub(SOURCE_TEXT, "%-%-%[%[.-%]%]", ""), "%-%-[^\n]*", "")

afterEach(function()
	MeshKit.uninstall()
end)

-- A fake place: Workspace with the imported scene, ReplicatedStorage with Forge.Assets and Game.Kit.CharacterMeshData.
type Place = {
	Workspace: Folder,
	ReplicatedStorage: Folder,
	assets: Folder?,
	scene: Model,
	dataModule: ModuleScript?,
	kitModule: ModuleScript,
	data: any,
	values: { [Instance]: any },
}

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
		dataModule.Name = "CharacterMeshData"
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
	-- the importer's scene: a Model named after the FBX with one MeshPart per mesh object
	local scene = Instance.new("Model")
	scene.Name = "citizen_kit"
	scene.Parent = workspace
	local n = 0
	for id, def in data.pieces do
		if def.empty ~= true and not (o.omit and o.omit[id]) then
			n += 1
			local part = Instance.new("MeshPart")
			part.Name = id
			part.MeshId = `rbxassetid://{500000 + n}`
			part.Size = Vector3.new(def.size[1], def.size[2], def.size[3])
			part.CFrame = CFrame.new(def.bbox_center[1], def.bbox_center[2], def.bbox_center[3])
			part.Anchored = true
			part.Parent = if o.nested
				then (function()
					local sub = scene:FindFirstChild("mesh_group") or Instance.new("Model")
					sub.Name = "mesh_group"
					sub.Parent = scene
					return sub
				end)()
				else scene
		end
	end
	return {
		Workspace = workspace,
		ReplicatedStorage = rs,
		assets = assets,
		scene = scene,
		dataModule = dataModule,
		kitModule = kitModule,
		data = data,
		values = values,
	}
end

-- Runs the script's source over the fake place. `edits` replaces text in the settings block (MOVE, DRY_RUN, SOURCE).
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
		debugName = "import_char_kit",
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
			Enum = Enum, -- the command bar has it: the import sets CollisionFidelity
		},
	})
	local report = chunk()
	return report, printed, warned
end

local function folderOf(place: Place): Instance?
	return if place.assets then place.assets:FindFirstChild("CitizenKit") else nil
end

local function count(parent: Instance?): number
	return if parent then #parent:GetChildren() else 0
end

local function joined(lines: { string }): string
	return table.concat(lines, "\n")
end

describe("import_char_kit.luau: the Studio import script, against fake trees", function()
	local data = MeshKit.fixture()
	local EXPECTED = 67 -- the placeholder kit's pieces with a mesh

	it("moves nothing it should not: clones the scene's pieces into Forge.Assets.CitizenKit by piece id", function()
		local place = newPlace(data)
		local report, printed, warned = runScript(place)
		expect(report.ok).toBe(true)
		expect(report.expected).toBe(EXPECTED)
		expect(report.imported).toBe(EXPECTED)
		expect(report.missing).toEqual({})
		expect(#warned).toBe(0)
		local folder = folderOf(place) :: Instance
		expect(folder.ClassName).toBe("Folder")
		expect(count(folder)).toBe(EXPECTED)
		for id, def in data.pieces do
			if def.empty ~= true then
				local piece = folder:FindFirstChild(id) :: MeshPart
				expect(piece).never.toBeNil()
				expect(piece.ClassName).toBe("MeshPart")
				expect(piece.CollisionFidelity).toBe(Enum.CollisionFidelity.Box) -- set by the import (it runs with plugin rights), never by the Kit
				expect((piece.Size - Vector3.new(def.size[1], def.size[2], def.size[3])).Magnitude).toBeLessThan(1e-4)
				expect(piece.Parent).toBe(folder)
			else
				expect(folder:FindFirstChild(id)).toBeNil() -- empty pieces have no mesh and are never expected
			end
		end
		expect(count(place.scene)).toBe(EXPECTED) -- cloned: the originals are still there to delete
		expect(joined(printed)).toContain("RESULT: OK")
		expect(joined(printed)).toContain("Triangles: not available in Studio")
		expect(joined(printed)).toContain("67 of 67 imported pieces stand where rig.json puts them")
	end)

	it(
		"makes the real Kit build mesh rigs from the folder it made, and part-built ones when the folder is removed",
		function()
			local place = newPlace(data)
			local report, printed = runScript(place)
			expect(report.ok).toBe(true)
			-- the script's own smoke test ran the Kit with the committed data (no pieces): honest about the fallback
			expect(joined(printed)).toContain("Kit smoke test")
			MeshKit.install(data, place.assets)
			local rig = Kit.character("citizen", "farmer", MeshKit.AZURE)
			expect(rig:GetAttribute("KitMesh")).toBe(true)
			expect(#CharacterMesh.status().missing).toBe(0); -- revert, as the owner procedure says: delete the CitizenKit folder
			(folderOf(place) :: Instance):Destroy()
			expect(Kit.character("citizen", "farmer", MeshKit.AZURE):GetAttribute("KitMesh")).toBeNil()
		end
	)

	it("reports the Kit smoke test as a mesh build when the place's data has the pieces", function()
		CharacterMesh.setData(data)
		local place = newPlace(data)
		local _, printed = runScript(place)
		expect(joined(printed)).toContain("Kit.character built a MESH rig")
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
		expect(count(folder)).toBe(EXPECTED)
		for _, child in folder:GetChildren() do
			expect(first[child.Name]).toBe(true)
		end
		expect(count(place.assets)).toBe(1) -- one CitizenKit folder, not two
	end)

	it("moves the pieces instead with MOVE = true, and a re-run with the scene gone keeps and checks them", function()
		local place = newPlace(data)
		local report = runScript(place, { ["local MOVE = false"] = "local MOVE = true" })
		expect(report.ok).toBe(true)
		expect(count(place.scene)).toBe(0)
		expect(count(folderOf(place))).toBe(EXPECTED)
		-- pieces an earlier run left without the physics shape get it on the re-run (the kept ones, not only the imported)
		for _, piece in (folderOf(place) :: Instance):GetChildren() do
			(piece :: MeshPart).CollisionFidelity = Enum.CollisionFidelity.Default
		end
		local again, printed = runScript(place)
		expect(again.imported).toBe(0)
		expect(again.kept).toBe(EXPECTED)
		expect(again.ok).toBe(true)
		expect(joined(printed)).toContain("RESULT: OK")
		for _, piece in (folderOf(place) :: Instance):GetChildren() do
			expect((piece :: MeshPart).CollisionFidelity).toBe(Enum.CollisionFidelity.Box)
		end
	end)

	it("finds pieces nested in the importer's sub-models", function()
		local place = newPlace(data, { nested = true })
		local report = runScript(place)
		expect(report.imported).toBe(EXPECTED)
		expect(report.ok).toBe(true)
		expect(count(folderOf(place))).toBe(EXPECTED) -- flat in CitizenKit, whatever the importer's nesting
	end)

	it("takes SOURCE when it is set, and reports duplicate sources when it is not", function()
		local function placeWithDecoy()
			local place = newPlace(data)
			local other = Instance.new("Model")
			other.Name = "other"
			other.Parent = place.Workspace
			local decoy = Instance.new("MeshPart")
			decoy.Name = "head_01"
			decoy.MeshId = "rbxassetid://1"
			decoy.Size = Vector3.new(9, 9, 9)
			decoy.Parent = other
			return place
		end
		local wide = runScript(placeWithDecoy())
		expect(#wide.duplicates).toBe(1)
		expect(wide.duplicates[1]).toContain("head_01 (2 copies")
		expect(wide.ok).toBe(true) -- the first by full name is the scene's, which has the right size
		local narrow = runScript(
			placeWithDecoy(),
			{ ["local SOURCE = nil"] = 'local SOURCE = workspace:FindFirstChild("citizen_kit")' }
		)
		expect(#narrow.duplicates).toBe(0)
		expect(narrow.ok).toBe(true)
	end)

	it("lists what is missing and says INCOMPLETE", function()
		local place = newPlace(data, { omit = { tool_hoe = true, crest_gold = true } })
		local report, printed, warned = runScript(place)
		expect(report.ok).toBe(false)
		expect(report.missing).toEqual({ "crest_gold", "tool_hoe" })
		expect(report.imported).toBe(EXPECTED - 2)
		expect(joined(printed)).toContain("MISSING pieces (2): crest_gold; tool_hoe")
		expect(joined(printed)).toContain("RESULT: INCOMPLETE")
		expect(folderOf(place):FindFirstChild("tool_hoe")).toBeNil()
		-- and the Kit falls back for exactly the rigs that need them
		MeshKit.install(data, place.assets)
		expect(Kit.character("citizen", "farmer", MeshKit.AZURE):GetAttribute("KitMesh")).toBeNil()
		expect(Kit.character("citizen", "idle", MeshKit.AZURE):GetAttribute("KitMesh")).toBe(true)
		expect(#warned).toBe(0)
	end)

	it("flags a wrong size (a unit or axis mistake), a missing mesh, and a rotated piece, and keeps going", function()
		local place = newPlace(data)
		local scene = place.scene;
		(scene:FindFirstChild("torso_01") :: MeshPart).Size = Vector3.new(2.1 * 28, 1.7 * 28, 1.15 * 28);
		(scene:FindFirstChild("head_02") :: MeshPart).MeshId = ""
		local hat = scene:FindFirstChild("hat_miner") :: MeshPart
		hat.CFrame = hat.CFrame * CFrame.Angles(math.rad(90), 0, 0)
		local report, printed, warned = runScript(place)
		expect(report.ok).toBe(false)
		expect(#report.wrongSize).toBe(1)
		expect(report.wrongSize[1]).toContain("torso_01")
		expect(report.noMesh).toEqual({ "head_02" })
		expect(#report.rotated).toBe(1)
		expect(report.rotated[1]).toContain("hat_miner")
		expect(joined(warned)).toContain("torso_01: wrong size")
		expect(joined(warned)).toContain("head_02: no MeshId")
		expect(joined(warned)).toContain("hat_miner: rotated")
		expect(joined(printed)).toContain("RESULT: INCOMPLETE")
		expect(report.imported).toBe(EXPECTED) -- the pieces are placed anyway; the Kit itself refuses what it cannot use
		MeshKit.install(data, place.assets)
		expect(
			Kit.character("citizen", "idle", MeshKit.AZURE, { skin = 1, hair = 1, hairColor = 1, outfit = 1 })
				:GetAttribute("KitMesh")
		).toBeNil()
	end)

	it(
		"strips everything from a piece, a SurfaceAppearance included (D-057 (13), (17)), and lists what it stripped",
		function()
			local place = newPlace(data)
			local piece = place.scene:FindFirstChild("tool_axe")
			local keep = Instance.new("SurfaceAppearance")
			keep.Name = "Palette"
			keep.Parent = piece
			piece:SetAttribute("Payload", "fetch me") -- attributes and tags on the piece itself are stripped from the copy
			piece:AddTag("RemoteLoader")
			local hidden: { Instance } = {}
			for _, class in
				{ "ModuleScript", "LocalScript", "Sound", "Decal", "ObjectValue", "StringValue", "Attachment" }
			do
				local d = Instance.new(class)
				d.Name = `Hidden{class}`
				d.Parent = piece
				table.insert(hidden, d)
			end
			local nested = Instance.new("Folder") -- a folder hiding a script: both go, once each
			nested.Name = "Pack"
			nested.Parent = piece
			local inner = Instance.new("Script")
			inner.Name = "Inner"
			inner.Parent = nested
			local report = runScript(place)
			local copy = folderOf(place):FindFirstChild("tool_axe") :: Instance
			expect(copy:FindFirstChild("Palette")).toBeNil() -- no PBR: the SurfaceAppearance goes too
			expect(copy:GetAttribute("Payload")).toBeNil()
			expect(#copy:GetTags()).toBe(0)
			expect(piece:GetAttribute("Payload")).toBe("fetch me") -- the original is untouched
			expect(#copy:GetDescendants()).toBe(0)
			expect(#report.stripped).toBe(#hidden + 1 + 2 + 2) -- the seven, the SurfaceAppearance, the folder and the script inside it, the attribute and the tag
			expect(report.scriptsRemoved).toBe(3) -- ModuleScript, LocalScript, Script
			local listed = table.concat(report.stripped, "\n")
			for _, d in hidden do
				expect(string.find(listed, d.ClassName, 1, true)).never.toBeNil()
			end
			for _, d in hidden do
				expect(piece:FindFirstChild(d.Name)).never.toBeNil() -- the original in the scene is untouched
			end
		end
	)

	it("ignores MeshParts that are not in the kit, deletes scripts found inside pieces, and counts both", function()
		local place = newPlace(data)
		local stray = Instance.new("MeshPart")
		stray.Name = "tree_pine_01"
		stray.Parent = place.scene
		local script = Instance.new("Script")
		script.Name = "Hidden"
		script.Parent = place.scene:FindFirstChild("tool_axe")
		local report = runScript(place)
		expect(report.stray).toEqual({ "tree_pine_01" })
		expect(report.scriptsRemoved).toBe(1)
		expect(folderOf(place):FindFirstChild("tree_pine_01")).toBeNil()
		for _, d in (folderOf(place) :: Instance):GetDescendants() do
			expect(d:IsA("LuaSourceContainer")).toBe(false)
		end
		expect(place.scene:FindFirstChild("tool_axe"):FindFirstChild("Hidden")).never.toBeNil() -- the original is untouched
	end)

	it("changes nothing in a dry run, on kept pieces either", function()
		local imported = newPlace(data)
		runScript(imported, { ["local MOVE = false"] = "local MOVE = true" }) -- imported and moved: the scene is gone, the pieces are kept
		for _, piece in (folderOf(imported) :: Instance):GetChildren() do
			(piece :: MeshPart).CollisionFidelity = Enum.CollisionFidelity.Default
		end
		local kept = runScript(imported, { ["local DRY_RUN = false"] = "local DRY_RUN = true" })
		expect(kept.kept).toBe(EXPECTED)
		for _, piece in (folderOf(imported) :: Instance):GetChildren() do
			expect((piece :: MeshPart).CollisionFidelity).toBe(Enum.CollisionFidelity.Default) -- a dry run sets nothing
		end

		local place = newPlace(data)
		local report, printed = runScript(place, { ["local DRY_RUN = false"] = "local DRY_RUN = true" })
		expect(report.dryRun).toBe(true)
		expect(report.imported).toBe(EXPECTED)
		expect(folderOf(place)).toBeNil()
		expect(count(place.scene)).toBe(EXPECTED)
		expect(joined(printed)).toContain("DRY RUN: nothing changed")
	end)

	it(
		"works by name alone when the place has no CharacterMeshData, and stops when it is not the project's place",
		function()
			local named = newPlace(data, { noDataModule = true })
			local report, printed = runScript(named)
			expect(joined(printed)).toContain("NAME-ONLY MODE")
			expect(report.imported).toBe(EXPECTED)
			expect(count(folderOf(named))).toBe(EXPECTED)

			local foreign = newPlace(data, { noAssets = true })
			local stopped, _, warned = runScript(foreign)
			expect(stopped.ok).toBe(false)
			expect(stopped.imported).toBe(0)
			expect(joined(warned)).toContain("not the project's place")
			expect(count(foreign.scene)).toBe(EXPECTED)
		end
	)

	it("says so when the data has no pieces yet, and touches nothing", function()
		local empty = { schema_version = 1, root_height = 3.2, joints = {}, pieces = {}, assemblies = {} }
		local place = newPlace(MeshKit.fixture())
		place.values[place.dataModule :: ModuleScript] = empty
		local report, printed = runScript(place)
		expect(report.ok).toBe(false)
		expect(joined(printed)).toContain("has no pieces yet")
		expect(folderOf(place)).toBeNil()
	end)
end)

describe("import_char_kit.luau keeps its promises: no network, no asset-id require, no scripts created", function()
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
		expect(n).toBe(2) -- the data module and the Kit, both by instance
	end)

	it("creates no scripts: the only Instance.new in it makes the CitizenKit Folder", function()
		local made = {}
		for class in string.gmatch(CODE_TEXT, 'Instance%.new%("(%w+)"%)') do
			table.insert(made, class)
		end
		expect(made).toEqual({ "Folder" })
		expect(string.find(CODE_TEXT, "%.Source%s*=")).toBeNil()
	end)

	it("changes nothing outside ReplicatedStorage.Forge.Assets.CitizenKit (checked on a run)", function()
		local place = newPlace(MeshKit.fixture())
		local before = #place.Workspace:GetDescendants() + #place.ReplicatedStorage:GetDescendants()
		runScript(place)
		-- only the CitizenKit folder and its pieces are new; the Workspace scene and the rest of ReplicatedStorage are as they were
		local added = #(folderOf(place) :: Instance):GetDescendants() + 1
		expect(#place.Workspace:GetDescendants() + #place.ReplicatedStorage:GetDescendants()).toBe(before + added)
		expect(count(place.scene)).toBe(67)
	end)
end)
