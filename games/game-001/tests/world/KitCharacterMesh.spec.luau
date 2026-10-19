--!nonstrict
--[[
	Kit.character mesh rigs (FL-0135, D-057): citizens built from imported Blender MeshParts (Kit/CharacterMesh), with the
	part-built rig as the automatic fallback. HEADLESS: Lune has no importer, so the pieces are fake MeshParts in a fake
	ReplicatedStorage.Forge.Assets.CitizenKit (fixtures/CharacterMeshKit.luau) sized from the data, and the data is the
	PLACEHOLDER kit (fixtures/char_kit_placeholder.rig.json: boxes sized from today's primitive rig, every feature of the
	format). When the real kit's data is committed (Kit/CharacterMeshData), every structural, budget and tint check below also
	runs on it. Nothing here says the meshes look right or import right in Studio: that is the owner's import and a render.

	Covers: the fallback (data, source, folder, piece missing/wrong/unsized, malformed data), the rig convention (Pose.JOINTS
	motors, axis-aligned joint frames, Root and pivot, flags, welds, attributes, placement from the data), determinism per
	look and pooling, the tint rules and Kit.setKingdomColor, the D-057 budgets over every look, and the converter's output.
	Pose, clearance and portraits: KitCharacterMeshPose.spec.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local process = require("@lune/process")

local Character = require("@game/ReplicatedStorage/Game/Kit/Character")
local CharacterMesh = require("@game/ReplicatedStorage/Game/Kit/CharacterMesh")
local CommittedData = require("@game/ReplicatedStorage/Game/Kit/CharacterMeshData")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Parts = require("@game/ReplicatedStorage/Game/Kit/Parts")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")

local MeshKit = require("./fixtures/CharacterMeshKit")
local Fixture = require("./fixtures/CharacterMeshFixture")

local AZURE, CRIMSON = MeshKit.AZURE, MeshKit.CRIMSON
local R = Kit.LOOK_RANGES

afterEach(function()
	MeshKit.uninstall()
end)

-- the datasets every structural check runs over: the placeholder, and the committed kit once it has pieces
local datasets: { { name: string, data: any } } = { { name = "placeholder kit", data = MeshKit.fixture() } }
if next(CommittedData.pieces) ~= nil then
	table.insert(datasets, { name = "committed kit", data = CommittedData })
end

local function meshRig(kind: string, job: string, color: Color3?, look: any?, kingdom: string?): Model
	local rig = Kit.character(kind, job, color or AZURE, look, kingdom)
	assert(
		rig:GetAttribute("KitMesh") == true,
		`{kind}/{job} fell back: {tostring(CharacterMesh.status().lastFallback)}`
	)
	return rig
end

local function primitive(kind: string, job: string, color: Color3?, look: any?, kingdom: string?): Model
	return Character.character(kind, job, color or AZURE, look, kingdom)
end

local function fallsBack(rig: Model)
	expect(rig:GetAttribute("KitMesh")).toBeNil()
	for _, p in MeshKit.parts(rig) do
		expect(p:IsA("MeshPart")).toBe(false)
	end
end

-- the joint a built part rides: a base piece is named after its motor, a mirrored extra "<id>_<joint>"
local function ridesOf(p: BasePart, def: any): string
	local name = p.Name
	if name == "LeftArm" or name == "RightArm" or name == "LeftLeg" or name == "RightLeg" then
		return name
	end
	local suffix = string.match(name, "_(%u%l+%u%l+)$")
	return suffix or def.joint
end

local function shadeOf(color: Color3, f: number): Color3
	return Parts.shade(color, f)
end

-- ------------------------------------------------------------------ fallback

describe("Kit.character falls back to the part-built rig, whole, whenever the kit is not there", function()
	local fixtureData = MeshKit.fixture()

	it("builds today's rig with the committed data when it has no pieces, whatever sits in the asset folder", function()
		local empty =
			{ schema_version = 1, unit = "stud", root_height = 3.2, joints = {}, pieces = {}, assemblies = {} }
		MeshKit.install(empty, MeshKit.assets(fixtureData)) -- a complete folder, but no data
		expect(Kit.characterMeshAvailable()).toBe(false)
		for _, c in MeshKit.cases() do
			local rig = Kit.character(c.kind, c.job, c.color, c.look, c.kingdom)
			fallsBack(rig)
			expect(MeshKit.signature(rig)).toBe(MeshKit.signature(primitive(c.kind, c.job, c.color, c.look, c.kingdom)))
		end
	end)

	it("is the committed state: valid data, and part-built rigs until it has pieces", function()
		expect(CommittedData.schema_version).toBe(1)
		expect(CommittedData.root_height).toBe(Character.ROOT_HEIGHT)
		if next(CommittedData.pieces) == nil then
			MeshKit.install(nil, MeshKit.assets(fixtureData))
			expect(Kit.characterMeshAvailable()).toBe(false)
			fallsBack(Kit.character("citizen", "farmer", AZURE))
			fallsBack(Kit.character("governor", "idle", AZURE))
			expect(next(CommittedData.assemblies)).toBeNil()
		else
			expect(next(CommittedData.assemblies)).never.toBeNil()
		end
	end)

	it("falls back without a source, without a CitizenKit folder, and with an empty one", function()
		MeshKit.install(fixtureData, nil)
		expect(Kit.characterMeshAvailable()).toBe(false)
		fallsBack(Kit.character("citizen", "farmer", AZURE))
		local noFolder = Instance.new("Folder")
		Kit.setAssetSource(noFolder)
		expect(Kit.characterMeshAvailable()).toBe(false)
		fallsBack(Kit.character("citizen", "farmer", AZURE))
		local emptyFolder = Instance.new("Folder")
		local kitFolder = Instance.new("Folder")
		kitFolder.Name = "CitizenKit"
		kitFolder.Parent = emptyFolder
		Kit.setAssetSource(emptyFolder)
		expect(Kit.characterMeshAvailable()).toBe(true) -- the folder is there; what it holds is checked per build
		fallsBack(Kit.character("citizen", "farmer", AZURE))
		expect(CharacterMesh.status().lastFallback).toContain("not in the folder")
		local status = Kit.characterMeshStatus()
		expect(status.meshBuilds).toBe(0)
		expect(status.fallbackBuilds).toBeGreaterThan(0)
		expect(#status.missing).toBe(#CharacterMesh.missingPieces(fixtureData, kitFolder))
	end)

	it("falls back per assembly: a missing piece sends only the rigs that need it to the part-built rig", function()
		MeshKit.install(fixtureData, MeshKit.assets(fixtureData, { omit = { tool_hoe_blade = true } }))
		fallsBack(Kit.character("citizen", "farmer", AZURE)) -- needs the hoe blade
		expect(CharacterMesh.status().lastFallback).toContain("tool_hoe_blade")
		expect(Kit.character("citizen", "idle", AZURE):GetAttribute("KitMesh")).toBe(true)
		expect(Kit.character("citizen", "miner", AZURE):GetAttribute("KitMesh")).toBe(true)
		expect(CharacterMesh.status().missing).toEqual({ "tool_hoe_blade" })
		-- a rig is never half mesh, half primitive
		local farmer = Kit.character("citizen", "farmer", AZURE)
		for _, p in MeshKit.parts(farmer) do
			expect(p:IsA("MeshPart")).toBe(false)
		end
	end)

	it("falls back for a piece that is not a MeshPart, has no mesh, or was imported at the wrong size", function()
		local wrongClass = Instance.new("Part")
		MeshKit.install(fixtureData, MeshKit.assets(fixtureData, { replace = { tool_hoe = wrongClass } }))
		fallsBack(Kit.character("citizen", "farmer", AZURE))
		expect(CharacterMesh.status().lastFallback).toContain("not a MeshPart")

		MeshKit.install(fixtureData, MeshKit.assets(fixtureData, { noMeshId = { tool_hoe = true } }))
		fallsBack(Kit.character("citizen", "farmer", AZURE))
		expect(CharacterMesh.status().lastFallback).toContain("no MeshId")

		local assets = MeshKit.assets(fixtureData)
		local hoe = assets.CitizenKit.tool_hoe :: MeshPart
		hoe.Size = hoe.Size + Vector3.new(0, 0.2, 0) -- more than SIZE_TOLERANCE off (a scale mistake is far more)
		MeshKit.install(fixtureData, assets)
		fallsBack(Kit.character("citizen", "farmer", AZURE))
		expect(CharacterMesh.status().lastFallback).toContain("imported size")
		hoe.Size = hoe.Size - Vector3.new(0, 0.15, 0) -- 0.05 off: within tolerance
		expect(Kit.character("citizen", "farmer", AZURE):GetAttribute("KitMesh")).toBe(true)
		hoe.Size = hoe.Size * 28 -- a unit mistake (Studio's 28 cm stud) is caught
		fallsBack(Kit.character("citizen", "farmer", AZURE))
	end)

	it("never errors on malformed data: every kind of bad kit is a fallback", function()
		local mutations: { [string]: (d: any) -> () } = {
			["pieces is a number"] = function(d)
				d.pieces = 5
			end,
			["schema 2"] = function(d)
				d.schema_version = 2
			end,
			["root height"] = function(d)
				d.root_height = 2
			end,
			["no joints"] = function(d)
				d.joints = nil
			end,
			["piece without tint"] = function(d)
				d.pieces.tool_hoe.tint = nil
			end,
			["piece with a bad bbox"] = function(d)
				d.pieces.tool_hoe.bbox_center = { 1, "x", 3 }
			end,
			["unknown piece in an assembly"] = function(d)
				d.assemblies.farmer.tool = "tool_scythe"
			end,
			["template that is a number"] = function(d)
				d.assemblies.farmer.tool = 7
			end,
			["unknown look axis"] = function(d)
				d.assemblies.farmer.hair = "hat_%look.hat%"
			end,
			["head rewired"] = function(d)
				d.joints.Head.parent = "RightArm"
			end,
			["no head piece"] = function(d)
				d.assemblies.farmer.head = nil
			end,
			["two heads"] = function(d)
				d.assemblies.farmer.head2 = "head_helm"
			end,
			["weld to nowhere"] = function(d)
				d.pieces.tool_hoe_blade.weld_to = "tool_ghost"
			end,
			["weld cycle"] = function(d)
				d.pieces.tool_hoe_blade.weld_to = "tool_hoe_blade"
			end,
			["mirror on a torso"] = function(d)
				d.pieces.torso_01.mirror = true
			end,
		}
		for name, mutate in mutations do
			local data = MeshKit.fixture()
			mutate(data)
			MeshKit.install(data, MeshKit.assets(MeshKit.fixture()))
			local ok, rig = pcall(Kit.character, "citizen", "farmer", AZURE)
			expect(ok).toBe(true)
			if ok then
				if rig:GetAttribute("KitMesh") ~= nil then
					error(`'{name}': a malformed kit still built a mesh rig`)
				end
				fallsBack(rig)
			end
			MeshKit.uninstall()
		end
	end)

	it("says why through Kit.characterMeshStatus, and counts mesh and fallback builds", function()
		MeshKit.install(fixtureData, MeshKit.assets(fixtureData, { omit = { crest_azure = true } }))
		Kit.character("citizen", "idle", AZURE)
		Kit.character("soldier", "soldier", AZURE, nil, "azure")
		Kit.character("soldier", "soldier", CRIMSON, nil, "crimson")
		local s = Kit.characterMeshStatus()
		expect(s.available).toBe(true)
		expect(s.source).toBe(true)
		expect(s.folder).toBe(true)
		expect(s.meshBuilds).toBe(2)
		expect(s.fallbackBuilds).toBe(1)
		expect(s.lastFallback).toContain("crest_azure")
		expect(s.pieces).toBe(69)
		expect(s.missing).toEqual({ "crest_azure" })
	end)

	it("treats unknown jobs as idle and aliases woodcutter/lumberjack", function()
		MeshKit.install(fixtureData, MeshKit.assets(fixtureData))
		local smith = Kit.character("citizen", "blacksmith", AZURE)
		expect(smith:GetAttribute("KitMesh")).toBe(true)
		expect(smith:GetAttribute("KitAssembly")).toBe("idle")
		expect(smith:GetAttribute("KitJob")).toBe("blacksmith")
		local renamed = MeshKit.fixture()
		renamed.assemblies.lumberjack = renamed.assemblies.woodcutter
		renamed.assemblies.woodcutter = nil
		MeshKit.install(renamed, MeshKit.assets(renamed))
		expect(Kit.character("citizen", "woodcutter", AZURE):GetAttribute("KitAssembly")).toBe("lumberjack")
		-- a unit kind is a soldier too, and its own assembly when the data has one
		MeshKit.install(fixtureData, MeshKit.assets(fixtureData))
		expect(Kit.character("soldier", "archer", AZURE, nil, "azure"):GetAttribute("KitAssembly")).toBe(
			"soldier_archer"
		)
		expect(Kit.character("soldier", "spearman", AZURE, nil, "azure"):GetAttribute("KitAssembly")).toBe("soldier")
		expect(Kit.character("soldier", "soldier", AZURE, nil, "azure"):GetAttribute("KitAssembly")).toBe("soldier")
	end)

	it("keeps Kit.characterLod, regalia and the part-built API as they were", function()
		MeshKit.install(fixtureData, MeshKit.assets(fixtureData))
		local lod = Kit.characterLod("citizen", AZURE)
		expect(#MeshKit.parts(lod)).toBe(1)
		expect(lod:GetAttribute("KitMesh")).toBeNil()
		expect(Kit.CHARACTER_ROOT_HEIGHT).toBe(3.2)
		expect(Kit.CHARACTER_MAX_PARTS).toBe(11)
		expect(#Kit.regalia(AZURE)).toBe(2)
		expect(Pose.JOINTS).toEqual({ "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "Tool" })
	end)
end)

-- ------------------------------------------------------------------ the rig convention

for _, ds in datasets do
	describe(`mesh rig convention ({ds.name}): Pose.JOINTS motors, axis-aligned joints, Root at the feet`, function()
		local data = ds.data
		local assets = MeshKit.assets(data)
		MeshKit.install(data, assets)

		local function each(fn: (rig: Model, c: any) -> ())
			MeshKit.install(data, assets)
			for _, c in MeshKit.cases() do
				fn(meshRig(c.kind, c.job, c.color, c.look, c.kingdom), c)
			end
		end

		it(
			"is a Root plus MeshParts only, within the 16-piece budget, non-colliding, massless, only the Root anchored",
			function()
				each(function(rig)
					local root = rig.PrimaryPart :: BasePart
					expect(root.Name).toBe("Root")
					expect(root.ClassName).toBe("Part")
					local n = 0
					for _, p in MeshKit.parts(rig) do
						expect(p.CanCollide).toBe(false)
						expect(p.CanTouch).toBe(false)
						expect(p.CanQuery).toBe(false)
						expect(p.Massless).toBe(true)
						expect(p.Anchored).toBe(p == root)
						if p ~= root then
							n += 1
							expect(p.ClassName).toBe("MeshPart")
							expect(p.Transparency).toBe(0)
							expect(p.Material).toBe(Enum.Material.SmoothPlastic)
							expect(p.CollisionFidelity).toBe(Enum.CollisionFidelity.Box)
							expect(p.Reflectance).toBe(0)
							for _, child in p:GetChildren() do
								expect(child:IsA("Weld") or child:IsA("Motor6D")).toBe(true) -- nothing from the import rides along
							end
						end
					end
					expect(n).toBeLessThanOrEqual(CharacterMesh.MAX_PIECES)
					expect(n).toBeGreaterThanOrEqual(7)
					for _, d in rig:GetDescendants() do
						expect(
							d:IsA("Humanoid")
								or d:IsA("Animator")
								or d:IsA("WeldConstraint")
								or d:IsA("LuaSourceContainer")
						).toBe(false)
						expect(d:IsA("Decal") or d:IsA("SurfaceAppearance")).toBe(false)
						if d:IsA("Weld") and not d:IsA("Motor6D") then
							expect(d.Name == "HairWeld" or d.Name == "AccessoryWeld" or d.Name == "PieceWeld").toBe(
								true
							)
						end
					end
				end)
			end
		)

		it(
			"joins pieces with Motor6Ds named exactly after Sim/Pose.JOINTS, Torso off the Root, in the Pose tree",
			function()
				local known = {}
				for _, j in Pose.JOINTS do
					known[j] = true
				end
				each(function(rig)
					local seen = {}
					local torso = MeshKit.child(rig, "Torso")
					for _, m in MeshKit.motors(rig) do
						local p1 = m.Part1 :: BasePart
						expect(known[m.Name]).toBe(true)
						expect(m.Name).toBe(p1.Name) -- a motor is named after the part it moves
						expect(m.Parent).toBe(m.Part0)
						expect(seen[m.Name]).toBeNil()
						seen[m.Name] = true
						-- C0 and C1 describe one world point (the rig is posed as built)
						expect((MeshKit.jointWorld(m).Position - (p1.CFrame * m.C1).Position).Magnitude).toBeLessThan(
							1e-3
						)
						-- axis-aligned joint frames: X right, Y up, -Z front, as Sim/Pose expects
						local j = MeshKit.jointWorld(m)
						expect(j.RightVector.X).toBeNear(1, 1e-6)
						expect(j.UpVector.Y).toBeNear(1, 1e-6)
						expect(j.LookVector.Z).toBeNear(-1, 1e-6)
					end
					for _, name in { "Torso", "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
						expect(seen[name]).toBe(true)
					end
					expect(MeshKit.motorOf(rig, "Torso").Part0).toBe(rig.PrimaryPart)
					for _, name in { "Head", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
						expect(MeshKit.motorOf(rig, name).Part0).toBe(torso)
					end
					if seen.Tool then
						local tool = MeshKit.motorOf(rig, "Tool")
						expect(tool.Part0 == MeshKit.child(rig, "RightArm") or tool.Part0 == torso).toBe(true)
					end
					-- every part but the Root hangs off exactly one joint or weld
					local parts, motors, welds = 0, 0, 0
					for _, d in rig:GetDescendants() do
						if d:IsA("BasePart") then
							parts += 1
						elseif d:IsA("Motor6D") then
							motors += 1
						elseif d:IsA("Weld") then
							welds += 1
						end
					end
					expect(motors + welds).toBe(parts - 1)
				end)
			end
		)

		it("keeps the Root invisible, anchored, 3.2 above the feet with the pivot at the feet", function()
			each(function(rig)
				local root = rig.PrimaryPart :: BasePart
				expect(root.Transparency).toBe(1)
				expect(root.Anchored).toBe(true)
				expect(root.CanCollide or root.CanTouch or root.CanQuery).toBe(false)
				expect(root.CFrame.Position.Y).toBeNear(Kit.CHARACTER_ROOT_HEIGHT, 1e-4)
				expect(root.CFrame.UpVector.Y).toBeNear(1, 1e-6)
				expect((root.CFrame * root.PivotOffset).Position.Y).toBeNear(0, 1e-6)
				-- EntityController's rootOffset: placing the pivot at the feet puts the Root 3.2 above them
				local feet = CFrame.new(10, 4, -7) * CFrame.Angles(0, 1.1, 0)
				local placed = feet * root.PivotOffset:Inverse()
				expect((placed.Position - (feet.Position + Vector3.new(0, 3.2, 0))).Magnitude).toBeLessThan(1e-4)
				expect(rig:GetAttribute("KitRootHeight")).toBe(Character.ROOT_HEIGHT)
				expect(rig:GetAttribute("KitMesh")).toBe(true)
			end)
		end)

		it(
			"puts joint pivots where Pose expects them: hips 2.2 up, neck at the torso top, shoulders outside it",
			function()
				each(function(rig)
					local torso = MeshKit.child(rig, "Torso")
					local torsoBottom, torsoTop = MeshKit.bounds({ torso })
					expect(MeshKit.jointWorld(MeshKit.motorOf(rig, "Torso")).Position.Y).toBeNear(2.2, 0.011) -- Pose's death fall
					expect(torsoBottom.Y).toBeNear(2.2, 0.06)
					for _, side in { "Left", "Right" } do
						local leg = MeshKit.child(rig, `{side}Leg`)
						local _, legTop = MeshKit.bounds({ leg })
						local hip = MeshKit.jointWorld(MeshKit.motorOf(rig, `{side}Leg`)).Position
						expect(hip.Y).toBeNear(legTop.Y, 0.06)
						expect(hip.X).toBeNear(leg.CFrame.Position.X, 0.15)
						local shoulder = MeshKit.jointWorld(MeshKit.motorOf(rig, `{side}Arm`)).Position
						expect(shoulder.Y).toBeGreaterThan(torsoTop.Y - 0.6)
						expect(shoulder.Y).toBeLessThan(torsoTop.Y)
						-- outside the torso's side, on the arm's centre line, so a raised arm swings clear of the head
						expect(math.abs(shoulder.X) - torso.Size.X / 2).toBeGreaterThan(0.2)
						expect(math.abs(shoulder.X) - torso.Size.X / 2).toBeLessThan(0.8)
					end
					local neck = MeshKit.jointWorld(MeshKit.motorOf(rig, "Head")).Position
					expect(neck.Y).toBeNear(torsoTop.Y, 0.1)
					expect(neck.X).toBeNear(0, 0.011)
					local headBottom = MeshKit.bounds({ MeshKit.child(rig, "Head") })
					expect(math.abs(headBottom.Y - neck.Y)).toBeLessThan(0.2)
				end)
			end
		)

		it(
			"places every MeshPart at the data's bbox centre and size, unrotated, joints where the data puts them",
			function()
				each(function(rig)
					for _, p in MeshKit.parts(rig) do
						local id = p:GetAttribute("KitPiece")
						if p ~= rig.PrimaryPart then
							local def = data.pieces[id]
							expect(def).never.toBeNil()
							local cx = def.bbox_center[1]
							if def.mirror == true and ridesOf(p, def) ~= def.joint then
								cx = -cx -- a mirror piece's second instance: mirrored x, on the opposite joint
							end
							expect(
								(p.CFrame.Position - Vector3.new(cx, def.bbox_center[2], def.bbox_center[3])).Magnitude
							).toBeLessThan(1e-3)
							expect(p.CFrame.RightVector.X).toBeNear(1, 1e-6)
							expect(p.CFrame.UpVector.Y).toBeNear(1, 1e-6)
							expect((p.Size - Vector3.new(def.size[1], def.size[2], def.size[3])).Magnitude).toBeLessThan(
								1e-4
							)
						end
					end
					for _, m in MeshKit.motors(rig) do
						local key = if m.Name == "Tool" and (m.Part0 :: BasePart).Name == "Torso"
							then "TorsoTool"
							else m.Name
						local want = data.joints[key].pos
						local at = MeshKit.jointWorld(m).Position
						expect((at - Vector3.new(want[1], want[2], want[3])).Magnitude).toBeLessThan(1e-3)
					end
				end)
			end
		)

		it(
			"welds extras rigidly to their joint's piece: Hair/HairWeld, Accessory/AccessoryWeld, the rest PieceWeld",
			function()
				each(function(rig)
					local moved: { [BasePart]: boolean } = {}
					for _, m in MeshKit.motors(rig) do
						moved[m.Part1 :: BasePart] = true
					end
					local nHair, nExtras = 0, 0
					local names = {}
					for _, p in MeshKit.parts(rig) do
						-- part names are unique (Kit.portrait and the clearance specs index by name)
						expect(names[p.Name]).toBeNil()
						names[p.Name] = true
						local welds = {}
						for _, d in p:GetChildren() do
							if d:IsA("Weld") then
								table.insert(welds, d)
							end
						end
						if p == rig.PrimaryPart or moved[p] then
							expect(#welds).toBe(0) -- a base piece is moved by its Motor6D, never also welded
						else
							nExtras += 1
							expect(#welds).toBe(1)
							local weld = welds[1]
							expect(weld.ClassName).toBe("Weld")
							expect(weld.Part1).toBe(p)
							expect(weld.Part0).never.toBe(p)
							expect(moved[weld.Part0] or not (weld.Part0.Parent == nil)).toBe(true)
							expect(weld.C1).toEqual(CFrame.new())
							local at = (weld.Part0 :: BasePart).CFrame * weld.C0 * weld.C1:Inverse()
							expect((at.Position - p.CFrame.Position).Magnitude).toBeLessThan(1e-4)
							if p.Name == "Hair" then
								nHair += 1
								expect(weld.Name).toBe("HairWeld")
								expect(weld.Part0).toBe(MeshKit.child(rig, "Head"))
								expect(p:GetAttribute("KitHeadwear")).toBe(p:GetAttribute("KitPiece"))
							elseif p.Name == "Accessory" then
								expect(weld.Name).toBe("AccessoryWeld")
								expect(weld.Part0).toBe(MeshKit.child(rig, "Head"))
								expect(p:GetAttribute("KitAccessory")).toBe(p:GetAttribute("KitPiece"))
							else
								expect(weld.Name).toBe("PieceWeld")
								expect(p:GetAttribute("KitHeadwear")).toBeNil()
								expect(p:GetAttribute("KitAccessory")).toBeNil()
							end
						end
					end
					expect(nHair).toBeLessThanOrEqual(1)
					expect(nExtras).toBeGreaterThan(0)
				end)
			end
		)

		it(
			"carries the Kit attributes the pool and the specs read: KitKind, KitJob, KitLook, KitTool, KitAssembly",
			function()
				each(function(rig, c)
					expect(rig:GetAttribute("KitKind")).toBe(c.kind)
					expect(rig:GetAttribute("KitJob")).toBe(c.job)
					local crest = if (c.kind == "soldier" or c.job == "soldier") and c.kingdom ~= nil
						then c.kingdom
						else nil
					expect(rig:GetAttribute("KitLook")).toBe(Kit.lookKey(c.look, crest))
					expect(type(rig:GetAttribute("KitAssembly"))).toBe("string")
					local tool = rig:FindFirstChild("Tool") :: BasePart?
					if tool then
						expect(tool:GetAttribute("KitTool")).toBe(tool:GetAttribute("KitPiece"))
					end
					expect(rig.Name).toBe(`{c.kind}_{c.job}`)
				end)
			end
		)

		it("stands on the ground: the lowest body point is at y = 0, the highest about a citizen tall", function()
			each(function(rig)
				local body = {}
				for _, p in MeshKit.parts(rig) do
					if
						p ~= rig.PrimaryPart
						and p.Name ~= "Tool"
						and p.Name ~= "Hair"
						and p:GetAttribute("KitSlot") ~= "tool"
					then
						table.insert(body, p)
					end
				end
				local mn, mx = MeshKit.bounds(body)
				expect(mn.Y).toBeNear(0, 0.06)
				expect(mx.Y).toBeGreaterThan(5)
				expect(mx.Y).toBeLessThan(7.2) -- a crest or hat may rise above the 5.5-stud body
			end)
		end)
	end)
end

-- ------------------------------------------------------------------ determinism, variation, pooling

describe("mesh rigs are deterministic per look and vary along the look", function()
	local data = MeshKit.fixture()
	local assets = MeshKit.assets(data)

	it("builds the same model for the same arguments, and for an omitted look and the default look", function()
		MeshKit.install(data, assets)
		for _, c in MeshKit.cases() do
			local a = MeshKit.signature(meshRig(c.kind, c.job, c.color, c.look, c.kingdom))
			local b = MeshKit.signature(meshRig(c.kind, c.job, c.color, c.look, c.kingdom))
			expect(a).toBe(b)
		end
		local a = meshRig("citizen", "idle", AZURE)
		local b = meshRig("citizen", "idle", AZURE, Kit.DEFAULT_LOOK)
		expect(MeshKit.signature(a)).toBe(MeshKit.signature(b))
		-- out-of-range and malformed looks wrap to the same model as their normalised look
		local wild = { skin = R.skin + 1, hair = 0, hairColor = -3, outfit = 2.7 }
		local tame = Kit.normalizeLook(wild)
		expect(MeshKit.signature(meshRig("citizen", "farmer", AZURE, wild))).toBe(
			MeshKit.signature(meshRig("citizen", "farmer", AZURE, tame))
		)
		local ok, bad = pcall(Kit.character, "citizen", "idle", AZURE, "not a look" :: any)
		expect(ok).toBe(true)
		expect(bad:GetAttribute("KitLook")).toBe(Kit.lookKey(nil))
	end)

	it("pools: a rig depends on the look only through Kit.lookKey, so equal keys are interchangeable", function()
		MeshKit.install(data, assets)
		local distinct: { [string]: boolean } = {}
		for seed = 1, 50 do
			local look = MeshKit.seededLook(seed)
			-- the same look written another way (each field a whole turn of its range further) has the same key ...
			local shifted = {
				skin = look.skin + R.skin,
				hair = look.hair - R.hair,
				hairColor = look.hairColor + 3 * R.hairColor,
				outfit = look.outfit + R.outfit,
			}
			expect(Kit.lookKey(shifted)).toBe(Kit.lookKey(look))
			for _, job in MeshKit.CITIZEN_JOBS do
				local a, b = meshRig("citizen", job, AZURE, look), meshRig("citizen", job, AZURE, shifted)
				expect(MeshKit.signature(a)).toBe(MeshKit.signature(b)) -- ... and builds the identical rig
				distinct[`{job}|{Kit.lookKey(look)}|{MeshKit.signature(a)}`] = true
			end
		end
		local n = 0
		for _ in distinct do
			n += 1
		end
		expect(n).toBe(300) -- 50 looks x 6 jobs: the seeded population has no repeats to hide behind
		local sigs: { [string]: boolean } = {}
		for seed = 1, 50 do
			sigs[MeshKit.signature(meshRig("citizen", "idle", AZURE, MeshKit.seededLook(seed)))] = true
		end
		local distinctRigs = 0
		for _ in sigs do
			distinctRigs += 1
		end
		expect(distinctRigs).toBeGreaterThanOrEqual(45) -- different keys give different rigs, nearly always
	end)

	it("changes the piece or the colour along every look axis", function()
		MeshKit.install(data, assets)
		local function idle(look)
			return meshRig("citizen", "idle", AZURE, look)
		end
		-- hair: every one of the look's 6 styles picks its own mesh (the data has 8 variants)
		local hairs = {}
		for h = 1, R.hair do
			local hair = idle({ skin = 1, hair = h, hairColor = 1, outfit = 1 }):FindFirstChild("Hair")
			local id = if hair then hair:GetAttribute("KitPiece") else "bald"
			expect(hairs[id]).toBeNil()
			hairs[id] = true
		end
		-- outfit: three torso meshes
		local torsos = {}
		for o = 1, R.outfit do
			torsos[idle({ skin = 1, hair = 1, hairColor = 1, outfit = o }).Torso:GetAttribute("KitPiece")] = true
		end
		local n = 0
		for _ in torsos do
			n += 1
		end
		expect(n).toBe(3)
		-- skin and hair colour: colours, no new meshes needed
		local skins, hairColors = {}, {}
		for s = 1, R.skin do
			local rig = idle({ skin = s, hair = 1, hairColor = 1, outfit = 1 })
			skins[rig.LeftArm.Color:ToHex()] = true
		end
		for h = 1, R.hairColor do
			local rig = idle({ skin = 1, hair = 1, hairColor = h, outfit = 1 })
			local hair = rig:FindFirstChild("Hair")
			if hair then
				hairColors[hair.Color:ToHex()] = true
			end
		end
		local ns, nh = 0, 0
		for _ in skins do
			ns += 1
		end
		for _ in hairColors do
			nh += 1
		end
		expect(ns).toBe(R.skin)
		expect(nh).toBe(R.hairColor)
		-- faces: the four head meshes all occur across the look space, boots both
		local faces, boots = {}, {}
		for seed = 1, 120 do
			local rig = idle(MeshKit.seededLook(seed))
			faces[rig.Head:GetAttribute("KitPiece")] = true
			boots[if rig:FindFirstChild("boot_01_LeftLeg") then "boot_01" else "boot_02"] = true
		end
		local nf = 0
		for _ in faces do
			nf += 1
		end
		expect(nf).toBe(4)
		expect(boots.boot_01 and boots.boot_02).toBe(true)
	end)

	it(
		"dresses soldiers and governors in their kingdom's armour, crest and cape (the hue picks when no kingdom is passed)",
		function()
			MeshKit.install(data, assets)
			for _, id in MeshKit.KINGDOM_IDS do
				local color = MeshKit.KINGDOM_COLORS[id]
				local soldier = meshRig("soldier", "soldier", color, nil, id)
				expect(soldier.Torso:GetAttribute("KitPiece")).toBe(`armour_{id}`)
				expect(soldier.Hair:GetAttribute("KitPiece")).toBe(`crest_{id}`)
				expect(soldier.Hair:GetAttribute("KitHeadwear")).toBe(`crest_{id}`)
				expect(soldier:GetAttribute("KitLook")).toBe(Kit.lookKey(nil, id)) -- soldiers pool by kingdom
				expect(soldier:GetAttribute("KitLook")).never.toBe(Kit.lookKey(nil))
				local governor = meshRig("governor", "governor", color, nil, nil)
				expect(governor:FindFirstChild("cape_" .. id)).never.toBeNil() -- the colour's hue picked the kingdom
				-- citizens ignore the kingdom
				expect(MeshKit.signature(meshRig("citizen", "farmer", color, nil, id))).toBe(
					MeshKit.signature(meshRig("citizen", "farmer", color, nil, nil))
				)
			end
			-- no kingdom and a grey colour: the neutral variants
			local plain = meshRig("soldier", "soldier", Kit.NEUTRAL_COLOR, nil, nil)
			expect(plain.Torso:GetAttribute("KitPiece")).toBe("armour_neutral")
			expect(plain:GetAttribute("KitLook")).toBe(Kit.lookKey(nil))
			-- an unknown kingdom id is no kingdom
			expect(meshRig("soldier", "soldier", AZURE, nil, "atlantis").Hair:GetAttribute("KitPiece")).toBe(
				"crest_azure"
			)
			expect(meshRig("soldier", "soldier", AZURE, nil, "atlantis"):GetAttribute("KitLook")).toBe(Kit.lookKey(nil))
		end
	)

	it("builds the mirror pieces on both sides: the same mesh at mirrored x on the opposite joint", function()
		MeshKit.install(data, assets)
		local rig = meshRig("citizen", "idle", AZURE)
		local left, right = rig.LeftLeg, rig.RightLeg
		expect(left:GetAttribute("KitPiece")).toBe("leg_trousers")
		expect(right:GetAttribute("KitPiece")).toBe("leg_trousers")
		expect(left.CFrame.Position.X).toBeNear(-right.CFrame.Position.X, 1e-4)
		expect(left.CFrame.Position.Y).toBeNear(right.CFrame.Position.Y, 1e-4)
		expect(left.Size).toEqual(right.Size)
		local boots = {}
		for _, p in MeshKit.parts(rig) do
			if string.sub(p.Name, 1, 5) == "boot_" then
				table.insert(boots, p)
				expect(p:GetAttribute("KitSlot")).toBe("boot")
			end
		end
		expect(#boots).toBe(2)
		expect(boots[1].CFrame.Position.X).toBeNear(-boots[2].CFrame.Position.X, 1e-4)
		-- each boot rides its own leg
		for _, boot in boots do
			local leg = if boot.CFrame.Position.X < 0 then left else right
			expect((boot:FindFirstChildWhichIsA("Weld") :: Weld).Part0).toBe(leg)
		end
	end)

	it("skips empty pieces (a bald head, no accessory) and welds hair to whichever head was picked", function()
		MeshKit.install(data, assets)
		local bald = meshRig("citizen", "idle", AZURE, { skin = 1, hair = 5, hairColor = 1, outfit = 1 })
		expect(bald:FindFirstChild("Hair")).toBeNil()
		for h = 1, R.hair do
			local rig = meshRig("citizen", "idle", AZURE, { skin = 1, hair = h, hairColor = 1, outfit = 1 })
			local hair = rig:FindFirstChild("Hair")
			if hair then
				expect((hair:FindFirstChildWhichIsA("Weld") :: Weld).Part0).toBe(rig.Head)
			end
		end
	end)
end)

-- ------------------------------------------------------------------ tints

describe(
	"mesh rig tints: skin, hair, kingdom, cloth, fixed (colour = MeshPart.Color over the baked vertex colours)",
	function()
		local data = MeshKit.fixture()
		local assets = MeshKit.assets(data)
		local P = Kit.LOOK_PALETTES

		it("paints each piece by its declared tint, from the same tables as the part-built rigs", function()
			MeshKit.install(data, assets)
			local checked = { skin = 0, hair = 0, kingdom = 0, cloth = 0, fixed = 0 }
			for _, c in MeshKit.cases() do
				local rig = meshRig(c.kind, c.job, c.color, c.look, c.kingdom)
				local l = Kit.normalizeLook(c.look)
				for _, p in MeshKit.parts(rig) do
					if p ~= rig.PrimaryPart then
						local def = data.pieces[p:GetAttribute("KitPiece")]
						checked[def.tint] += 1
						local tint = p:GetAttribute("KitTint")
						if def.tint == "skin" then
							expect(p.Color:ToHex()).toBe(P.skin[l.skin]:ToHex())
							expect(tint).toBeNil()
						elseif def.tint == "hair" then
							expect(p.Color:ToHex()).toBe(P.hairColor[l.hairColor]:ToHex())
							expect(tint).toBeNil()
						elseif def.tint == "kingdom" then
							expect(type(tint)).toBe("number")
							expect(p.Color:ToHex()).toBe(shadeOf(c.color, tint):ToHex())
							expect(tint).toBeGreaterThanOrEqual(0.5)
							expect(tint).toBeLessThanOrEqual(1.3)
						elseif def.tint == "cloth" then
							expect(p.Color:ToHex()).toBe(Character.clothColor(c.job, def.slot, l):ToHex())
							expect(tint).toBeNil()
						else
							expect(p.Color:ToHex()).toBe("ffffff")
							expect(tint).toBeNil()
						end
					end
				end
			end
			for tint, n in checked do
				if n == 0 then
					error(`no piece of tint {tint} was ever built`)
				end
			end
		end)

		it(
			"uses the part-built tint factors: citizens muted and individual, soldiers and governors exact, tint_factor honoured",
			function()
				MeshKit.install(data, assets)
				for hairColor = 1, R.hairColor do
					for skin = 1, R.skin do
						local look = { skin = skin, hair = 1, hairColor = hairColor, outfit = 1 }
						local shift = Character.tintShift(look)
						local torso = meshRig("citizen", "idle", AZURE, look).Torso
						expect(torso:GetAttribute("KitPiece")).toBe("torso_01")
						expect(torso:GetAttribute("KitTint")).toBeNear(math.clamp(0.8 + shift, 0.5, 1), 1e-9)
						local vest = meshRig(
							"citizen",
							"idle",
							AZURE,
							{ skin = skin, hair = 1, hairColor = hairColor, outfit = 3 }
						).Torso
						expect(vest:GetAttribute("KitTint")).toBeNear(math.clamp(0.9 + shift, 0.5, 1), 1e-9) -- torso_03: tint_factor 0.9
						local sleeve = meshRig("citizen", "idle", AZURE, look)
						expect(sleeve:FindFirstChild("sleeve_l")).never.toBeNil()
					end
				end
				expect(meshRig("soldier", "soldier", AZURE, nil, "azure").Torso:GetAttribute("KitTint")).toBe(1)
				expect(meshRig("soldier", "soldier", AZURE, nil, "azure").Hair:GetAttribute("KitTint")).toBe(1)
				expect(meshRig("soldier", "soldier", AZURE, nil, "azure"):FindFirstChild("sleeve_kingdom_l")).never.toBeNil()
				local sleeveK = meshRig("soldier", "soldier", AZURE, nil, "azure"):FindFirstChild("sleeve_kingdom_l")
				expect(sleeveK:GetAttribute("KitTint")).toBe(0.85) -- soldiers' sleeves
				expect(meshRig("governor", "governor", AZURE, nil, "azure").Torso:GetAttribute("KitTint")).toBe(1)
			end
		)

		it(
			"dyes cloth like the part-built jobs: the job's panel and trousers, KitAccent = job on working jobs",
			function()
				MeshKit.install(data, assets)
				for _, job in { "farmer", "woodcutter", "miner", "builder", "hauler" } do
					local rig = meshRig("citizen", job, AZURE, { skin = 1, hair = 2, hairColor = 3, outfit = 2 })
					local legs = rig.LeftLeg
					expect(legs.Color:ToHex()).toBe(Character.clothColor(job, "leg", { hairColor = 3 }):ToHex())
					expect(legs:GetAttribute("KitAccent")).toBe(job)
					local torso = rig.Torso -- torso_02 is cloth
					expect(torso.Color:ToHex()).toBe(Character.clothColor(job, "torso", { hairColor = 3 }):ToHex())
				end
				local idle = meshRig("citizen", "idle", AZURE, { skin = 1, hair = 2, hairColor = 3, outfit = 2 })
				expect(idle.LeftLeg:GetAttribute("KitAccent")).toBeNil()
				-- the dye follows the hair colour (hidden under a job hat), so jobs differ from each other and vary per individual
				local seen = {}
				for hc = 1, R.hairColor do
					seen[Character.clothColor("miner", "torso", { hairColor = hc }):ToHex()] = true
				end
				local n = 0
				for _ in seen do
					n += 1
				end
				expect(n).toBeGreaterThanOrEqual(6)
				expect(Character.clothColor("miner", "leg", nil):ToHex()).never.toBe(
					Character.clothColor("farmer", "leg", nil):ToHex()
				)
			end
		)

		it(
			"recolours a pooled rig with Kit.setKingdomColor exactly like a fresh build (same hue: same pieces)",
			function()
				MeshKit.install(data, assets)
				local other = {
					crimson = Color3.fromRGB(210, 60, 40),
					azure = Color3.fromRGB(30, 90, 190),
					emerald = Color3.fromRGB(40, 150, 90),
					gold = Color3.fromRGB(220, 170, 20),
				}
				for _, c in MeshKit.cases() do
					if c.kingdom ~= nil or c.kind == "citizen" then
						local to = if c.kingdom then other[c.kingdom] else Color3.fromRGB(50, 120, 220)
						local rig = meshRig(c.kind, c.job, c.color, c.look, c.kingdom)
						Kit.setKingdomColor(rig, to)
						local fresh = meshRig(c.kind, c.job, to, c.look, c.kingdom)
						local a, b = MeshKit.signature(rig), MeshKit.signature(fresh)
						-- the recoloured rig also records KitColor
						expect(rig:GetAttribute("KitColor")).toBe(to)
						expect(a).toBe(b)
					end
				end
			end
		)

		it("recolours only the kingdom pieces, to a different hue too: skin, hair, cloth and fixed stay", function()
			MeshKit.install(data, assets)
			local rig = meshRig("soldier", "soldier", AZURE, MeshKit.seededLook(5), "azure")
			local before = {}
			for _, p in MeshKit.parts(rig) do
				before[p] = p.Color:ToHex()
			end
			Kit.setKingdomColor(rig, MeshKit.GOLD)
			local changed = 0
			for _, p in MeshKit.parts(rig) do
				local f = p:GetAttribute("KitTint")
				if f then
					expect(p.Color:ToHex()).toBe(shadeOf(MeshKit.GOLD, f):ToHex())
					changed += 1
				else
					expect(p.Color:ToHex()).toBe(before[p])
				end
			end
			expect(changed).toBeGreaterThanOrEqual(3)
		end)

		it(
			"keeps the imported template's own look out: a green Neon template is repainted and never touched",
			function()
				MeshKit.install(data, assets)
				meshRig("citizen", "idle", AZURE)
				local template = assets.CitizenKit.torso_01 :: MeshPart
				expect(template.Color).toEqual(Color3.fromRGB(0, 255, 0)) -- cloning leaves the template alone
				expect(template.Material).toBe(Enum.Material.Neon)
				expect(template.Anchored).toBe(true)
				for _, p in MeshKit.parts(meshRig("citizen", "idle", AZURE)) do
					expect(p.Material).never.toBe(Enum.Material.Neon)
					expect(p.Color).never.toEqual(Color3.fromRGB(0, 255, 0))
				end
			end
		)
	end
)

describe("mesh rig textures: a palette texture is allowed, never required", function()
	it(
		"keeps a piece's TextureID (a shared palette) but strips a SurfaceAppearance (no PBR, D-057 (17)) and everything else it carries",
		function()
			local data = MeshKit.fixture()
			local assets = MeshKit.assets(data)
			local kit = assets.CitizenKit
			for _, id in { "torso_01", "head_01", "head_02", "head_03", "head_04", "hair_01" } do
				(kit[id] :: MeshPart).TextureID = "rbxassetid://424242" -- a shared palette atlas
			end
			local appearance = Instance.new("SurfaceAppearance")
			appearance.Parent = kit.torso_01
			for _, id in { "torso_01", "arm_l" } do
				local script = Instance.new("Script")
				script.Parent = kit[id]
				Instance.new("Attachment").Parent = kit[id]
			end
			kit.torso_01:SetAttribute("Payload", "fetch me") -- attributes and tags on the imported piece are payload too
			kit.torso_01:AddTag("RemoteLoader")
			MeshKit.install(data, assets)
			local rig = meshRig("citizen", "idle", AZURE, { skin = 1, hair = 1, hairColor = 1, outfit = 1 })
			expect(rig.Torso:GetAttribute("Payload")).toBeNil()
			expect(#rig.Torso:GetTags()).toBe(0)
			expect(rig.Torso.TextureID).toBe("rbxassetid://424242")
			expect(rig.Torso:FindFirstChildWhichIsA("SurfaceAppearance")).toBeNil()
			expect(rig.Torso:FindFirstChildWhichIsA("Script")).toBeNil()
			expect(rig.Torso:FindFirstChildWhichIsA("Attachment")).toBeNil()
			expect(rig.LeftArm:FindFirstChildWhichIsA("Script")).toBeNil()
			-- the tint rules are the same with or without a texture: Color is still the only interface
			expect(rig.Torso.Color:ToHex()).never.toBe("ffffff")
			expect(rig.Torso:GetAttribute("KitTint")).never.toBeNil()
			-- a textured and a plain piece sit together in one rig, and the plain kit builds as before
			expect(rig.Head.TextureID).toBe("rbxassetid://424242")
			MeshKit.install(data, MeshKit.assets(data))
			expect(meshRig("citizen", "idle", AZURE):GetAttribute("KitMesh")).toBe(true)
		end
	)
end)

-- ------------------------------------------------------------------ budgets (D-057 (5))

for _, ds in datasets do
	describe(`mesh rig budgets ({ds.name}): <= 16 pieces, the triangle budget, <= 20,000 per mesh`, function()
		local data = ds.data

		local function eachPlan(fn: (plan: any, label: string) -> ())
			local r = Kit.LOOK_RANGES
			local contexts = {}
			-- (unknown jobs such as blacksmith build the idle assembly, covered by "idle")
			for _, job in { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" } do
				table.insert(contexts, { "citizen", job, AZURE, nil })
			end
			for _, id in MeshKit.KINGDOM_IDS do
				table.insert(contexts, { "soldier", "soldier", MeshKit.KINGDOM_COLORS[id], id })
				table.insert(contexts, { "governor", "governor", MeshKit.KINGDOM_COLORS[id], id })
			end
			table.insert(contexts, { "soldier", "soldier", Kit.NEUTRAL_COLOR, nil })
			table.insert(contexts, { "governor", "governor", Kit.NEUTRAL_COLOR, nil })
			for skin = 1, r.skin do
				for hair = 1, r.hair do
					for hairColor = 1, r.hairColor do
						for outfit = 1, r.outfit do
							local look = { skin = skin, hair = hair, hairColor = hairColor, outfit = outfit }
							for _, c in contexts do
								local plan, why = CharacterMesh.plan(data, c[1], c[2], c[3], look, c[4])
								if plan == nil then
									error(`{c[1]}/{c[2]} {Kit.lookKey(look)}: {why}`)
								end
								fn(plan, `{c[1]}/{c[2]} {Kit.lookKey(look)} {c[4] or "-"}`)
							end
						end
					end
				end
			end
		end

		-- one pass over the whole look space (it costs seconds): the worst citizen found, and the first thing wrong
		local scanned: any = nil
		local function scan(): any
			if scanned then
				return scanned
			end
			local out = { plans = 0, pieces = 0, tris = 0, meshTris = 0, problem = nil :: string? }
			eachPlan(function(plan, label)
				out.plans += 1
				if out.problem == nil then
					local limits = CharacterMesh.BUDGET[plan.style]
					if #plan.items > CharacterMesh.MAX_PIECES then
						out.problem = `{label}: {#plan.items} pieces, the budget is {CharacterMesh.MAX_PIECES}`
					elseif plan.tris > limits.total then
						out.problem = `{label}: {plan.tris} triangles, the {plan.style} budget is {limits.total}`
					elseif limits.body and plan.bodyTris > limits.body then
						out.problem =
							`{label}: {plan.bodyTris} body triangles, the {plan.style} budget is {limits.body}`
					elseif limits.tool and plan.toolTris > limits.tool then
						out.problem =
							`{label}: {plan.toolTris} tool triangles, the {plan.style} budget is {limits.tool}`
					end
				end
				out.pieces = math.max(out.pieces, #plan.items)
				out.tris = math.max(out.tris, plan.tris)
				for _, item in plan.items do
					if out.problem == nil and (item.def.tris > CharacterMesh.MAX_MESH_TRIS or item.def.tris < 1) then
						out.problem = `{label}: {item.id} has {item.def.tris} triangles (Roblox's cap is 20,000)`
					end
					out.meshTris = math.max(out.meshTris, item.def.tris)
				end
			end)
			scanned = out
			return out
		end

		it("resolves every assembly for all 1,728 looks, in every kingdom", function()
			expect(scan().plans).toBe(1728 * 16) -- 6 citizen jobs, soldiers and governors in 4 kingdoms and neutral
		end)

		it("keeps every rig within 16 pieces and its triangle budget, every mesh under 20,000", function()
			local result = scan()
			if result.problem then
				error(result.problem)
			end
			expect(result.pieces).toBeGreaterThanOrEqual(7)
			expect(result.tris).toBeGreaterThan(0)
			expect(result.meshTris).toBeLessThanOrEqual(20000)
			expect(CharacterMesh.MAX_PIECES).toBe(16) -- D-057 (5), pinned here on purpose
			-- D-057 amendment (15): citizens 1,000 (body 900, tool 150), soldiers and rulers up to 1,500. The ONE place to change.
			expect(CharacterMesh.BUDGET.citizen).toEqual({ total = 1000, body = 900, tool = 150 })
			expect(CharacterMesh.BUDGET.soldier).toEqual({ total = 1500 })
			expect(CharacterMesh.BUDGET.governor).toEqual({ total = 1500 })
			expect(CharacterMesh.MAX_MESH_TRIS).toBe(20000)
		end)

		it("adds up what a built rig holds: a plan's triangles are the pieces' declared triangles", function()
			MeshKit.install(data, MeshKit.assets(data))
			for _, c in MeshKit.cases() do
				local plan = CharacterMesh.plan(data, c.kind, c.job, c.color, c.look, c.kingdom) :: any
				local rig = meshRig(c.kind, c.job, c.color, c.look, c.kingdom)
				local tris, n = 0, 0
				for _, p in MeshKit.parts(rig) do
					if p ~= rig.PrimaryPart then
						n += 1
						tris += data.pieces[p:GetAttribute("KitPiece")].tris
					end
				end
				expect(n).toBe(#plan.items)
				expect(tris).toBe(plan.tris)
				expect(plan.bodyTris + plan.toolTris).toBe(plan.tris)
				expect(plan.toolTris > 0).toBe(rig:FindFirstChild("Tool") ~= nil)
				expect(plan.assembly).toBe(rig:GetAttribute("KitAssembly"))
			end
		end)
	end)
end

describe("mesh rig budgets bite: plans report what a rig really holds", function()
	it("adds up triangles and pieces from the data, so a fat or crowded kit shows", function()
		local data = MeshKit.fixture()
		local look = { skin = 1, hair = 1, hairColor = 1, outfit = 1 }
		local before = CharacterMesh.plan(data, "citizen", "idle", AZURE, look) :: any
		data.pieces.torso_01.tris += 1800
		local after = CharacterMesh.plan(data, "citizen", "idle", AZURE, look) :: any
		expect(after.tris).toBe(before.tris + 1800)
		expect(after.tris).toBeGreaterThan(CharacterMesh.BUDGET.citizen.total)
		expect(after.bodyTris).toBe(before.bodyTris + 1800) -- a torso is body, not tool
		expect(after.toolTris).toBe(before.toolTris)
		local crowded = MeshKit.fixture()
		crowded.assemblies.idle.more =
			{ "hair_01", "hair_02", "hair_03", "hair_04", "hair_06", "hair_07", "hair_08", "acc_01", "acc_02" }
		expect(#(CharacterMesh.plan(crowded, "citizen", "idle", AZURE) :: any).items).toBeGreaterThan(
			CharacterMesh.MAX_PIECES
		)
	end)
end)

-- ------------------------------------------------------------------ the converter's output

describe("rig_to_luau.py output is the data the Kit reads", function()
	it("loads as the same table as the rig.json it came from (known fields; nulls absent)", function()
		local json = MeshKit.fixture()
		expect(Fixture.schema_version).toBe(json.schema_version)
		expect(Fixture.unit).toBe(json.unit)
		expect(Fixture.root_height).toBe(json.root_height)
		expect(Fixture.joints).toEqual(json.joints)
		expect(Fixture.assemblies).toEqual(json.assemblies)
		local known = {
			"joint",
			"weld_to",
			"mirror",
			"empty",
			"bbox_center",
			"size",
			"tris",
			"tint",
			"tint_factor",
			"slot",
			"tags",
		}
		local count = 0
		for id, def in json.pieces do
			count += 1
			for _, key in known do
				local want = def[key]
				if want == false then
					want = nil -- the converter leaves a false flag out
				end
				expect(Fixture.pieces[id][key]).toEqual(want)
			end
		end
		local luaCount = 0
		for _ in Fixture.pieces do
			luaCount += 1
		end
		expect(luaCount).toBe(count)
		expect(count).toBe(69)
	end)

	it("builds the same rigs from the generated module as from the JSON", function()
		local json = MeshKit.fixture()
		MeshKit.install(Fixture, MeshKit.assets(json))
		local a = MeshKit.signature(meshRig("citizen", "miner", AZURE, MeshKit.seededLook(3)))
		MeshKit.install(json, MeshKit.assets(json))
		expect(MeshKit.signature(meshRig("citizen", "miner", AZURE, MeshKit.seededLook(3)))).toBe(a)
	end)

	it("passes the converter's own self-test and the committed fixtures are current (python3 art/char_kit)", function()
		local function run(args: { string }): (boolean, string)
			local result = process.exec("python3", args)
			return result.ok, result.stdout .. result.stderr
		end
		local ok, out = run({ "games/game-001/art/char_kit/rig_to_luau.py", "--selftest" })
		if not ok then
			error(`rig_to_luau.py --selftest failed:\n{out}`)
		end
		expect(out).toContain("selftest: PASS")
		local fresh, why = run({ "games/game-001/art/char_kit/make_placeholder_rig.py", "--check" })
		if not fresh then
			error(`the placeholder rig.json is out of date: {why}`)
		end
		local luau, whyLuau = run({
			"games/game-001/art/char_kit/rig_to_luau.py",
			"--in",
			MeshKit.FIXTURE_JSON,
			"--out",
			"games/game-001/tests/world/fixtures/CharacterMeshFixture.luau",
			"--check",
		})
		if not luau then
			error(`CharacterMeshFixture.luau is out of date: {whyLuau}`)
		end
		-- and the committed CharacterMeshData matches rig.json when there is one
		local rigJson = "games/game-001/art/char_kit/rig.json"
		local fs = require("@lune/fs")
		if fs.isFile(rigJson) then
			local current, whyData = run({ "games/game-001/art/char_kit/rig_to_luau.py", "--check" })
			if not current then
				error(`Kit/CharacterMeshData.luau is out of date: {whyData}`)
			end
		end
	end)
end)
