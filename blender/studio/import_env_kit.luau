--!nocheck
--[[
	import_env_kit — Studio COMMAND-BAR script: wraps the imported nature meshes into the Models Kit.prop looks for.   FL-0136
	Owner: FORGE-02. Procedure for the owner: games/game-001/art/IMPORT_ENVIRONMENT.md. STUDIO-UNVERIFIED: this script has
	run only under Lune against fake instance trees (tests/world/KitEnvMeshImport.spec), never in Studio.

	What it does (edit mode, Studio command bar: paste the whole file and press Enter; read the Output window):
	  1. Reads the kit's data from ReplicatedStorage.Game.Kit.EnvMeshData (a ModuleScript the project's Rojo build puts in the
	     place): the asset ids, their sizes and bbox centres. It needs it (the wrapper is built from the data).
	  2. Finds the MeshParts the FBX import created in Workspace (inside SOURCE if you set it), by asset id = mesh object name.
	  3. Wraps each in a Model named by its asset id, as a part-built stand-in is shaped (Kit/Parts.newModel): an invisible
	     anchored Root (the PrimaryPart, a footprint plate, PivotOffset to the BASE CENTRE, y = 0) and the MeshPart "Body"
	     at the data's bbox_center, anchored, no collision, massless, shadow casting. The Model goes under
	     ReplicatedStorage.Forge.Assets.EnvKit (a Folder it creates), or straight under Assets with FLAT = true. CLONES the
	     MeshParts by default (the originals stay in Workspace for you to delete); MOVE = true moves them.
	  4. Checks every prop: a MeshPart, a MeshId (Studio uploaded its mesh), the size the data says (+/- 0.1 or 0.5 %: a
	     wrong Scale Unit or axis shows here), not rotated (the wrapper places the mesh unrotated). Everything inside the
	     MeshPart is deleted from the copy and listed (D-057 (17): no PBR, so a SurfaceAppearance goes too): scripts, Sounds,
	     Decals, Textures, Attachments, values, any child; its attributes and tags too. A TextureID is reported, not removed
	     (the contract is vertex colours only).
	  5. Prints a report: counts, missing, wrong sizes, rotated, duplicates, strays, what was stripped. Triangle counts are NOT
	     available from Studio: the figures are the Blender export's (env.json `tris`, the manifest).
	  6. Asks the Kit itself: Kit.prop(id) for every id, with the folder as the asset source, and counts the props it accepts
	     (Kit/EnvMesh checks the Model against the data again) and the ones it would still build part-built, with the reason.
	  Idempotent: run it again and it replaces each wrapped Model with the same result; Models already in the folder that
	  have no new source are kept and checked. One Ctrl+Z undoes a run.

	What it never does: no network, no HttpService, no require(assetId) (the only requires are the ModuleScripts above,
	by instance), no scripts created, nothing outside ReplicatedStorage.Forge.Assets.EnvKit (or Assets, with FLAT) is
	changed, nothing is published or saved. Saving and publishing are the owner's steps.
]]

-- ------------------------------------------------------------------ settings (edit these, nothing else)
local SOURCE = nil -- the Instance the importer made, e.g. workspace:FindFirstChild("env_kit"); nil = all of Workspace
local MOVE = false -- true: move the imported MeshParts into the Models instead of cloning them
local DRY_RUN = false -- true: only report, change nothing
local FLAT = false -- true: put the Models straight under Forge.Assets instead of Forge.Assets.EnvKit
local FOLDER_NAME = "EnvKit" -- Kit/EnvMesh.FOLDER_NAME
local SIZE_TOLERANCE = 0.1 -- Kit/EnvMesh.SIZE_TOLERANCE (studs; or REL_TOLERANCE of a dimension if larger)
local REL_TOLERANCE = 0.005 -- Kit/EnvMesh.REL_TOLERANCE
local ROTATION_TOLERANCE = 0.5 -- degrees

-- ------------------------------------------------------------------ the work, with its world passed in (so a test can run it)
local function importEnvKit(world, settings)
	local say, complain = world.print, world.warn
	local lines = {}
	local function log(text)
		table.insert(lines, text)
		say(text)
	end

	local report = {
		expected = 0,
		imported = 0,
		kept = 0,
		missing = {},
		wrongSize = {},
		noMesh = {},
		rotated = {},
		duplicates = {},
		stray = {},
		textured = {},
		scriptsRemoved = 0,
		stripped = {}, -- every descendant, attribute and tag removed from a MeshPart copy
		accepted = 0, -- props the Kit accepts, of `expected` (the smoke test)
		fallbacks = {}, -- "<id>: why" for the props Kit.prop would still build part-built
		smoke = "not run",
		dryRun = settings.dryRun,
		ok = false,
	}

	-- 1. the kit's data
	local data = nil
	do
		local ok, module = pcall(function()
			return world.ReplicatedStorage.Game.Kit.EnvMeshData
		end)
		if ok and module then
			local loaded, result = pcall(world.require, module)
			if loaded and type(result) == "table" and type(result.props) == "table" then
				data = result
			else
				complain("import_env_kit: EnvMeshData did not load: " .. tostring(result))
			end
		end
	end
	if data == nil then
		complain(
			"import_env_kit: no Kit/EnvMeshData in this place (build it with Rojo from a branch that has env_to_luau.py's output). Nothing changed."
		)
		return report
	end
	local ids = {}
	for id in pairs(data.props) do
		table.insert(ids, id)
	end
	table.sort(ids)
	report.expected = #ids
	if #ids == 0 then
		log(
			"import_env_kit: Kit/EnvMeshData has no props yet (run art/env_kit/env_to_luau.py and rebuild the place). Nothing changed."
		)
		return report
	end

	-- 2. where it goes, and the candidates in Workspace (not anything already under Assets)
	local assets = nil
	do
		local ok, found = pcall(function()
			return world.ReplicatedStorage.Forge.Assets
		end)
		if ok and found then
			assets = found
		end
	end
	if assets == nil then
		complain(
			"import_env_kit: ReplicatedStorage.Forge.Assets does not exist: this is not the project's place (build it with Rojo). Nothing changed."
		)
		return report
	end
	local container = if settings.flat then assets else assets:FindFirstChild(settings.folderName)
	local root = settings.source or world.Workspace
	local candidates = {} -- id -> { MeshPart... } sorted by full name
	local meshCount = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") and not d:IsDescendantOf(assets) then
			meshCount += 1
			if data.props[d.Name] then
				candidates[d.Name] = candidates[d.Name] or {}
				table.insert(candidates[d.Name], d)
			else
				table.insert(report.stray, d.Name)
			end
		end
	end
	for _, list in pairs(candidates) do
		table.sort(list, function(a, b)
			return a:GetFullName() < b:GetFullName()
		end)
	end
	log(
		string.format(
			"import_env_kit: %d prop(s) expected, %d MeshPart(s) under %s",
			report.expected,
			meshCount,
			root:GetFullName()
		)
	)

	-- 3. check and wrap
	if not settings.dryRun then
		pcall(function()
			world.ChangeHistoryService:SetWaypoint("import_env_kit (before)")
		end)
		if container == nil then
			container = world.Instance.new("Folder")
			container.Name = settings.folderName
			container.Parent = assets
		end
	end
	local function tolerance(dimension)
		return math.max(settings.sizeTolerance, settings.relTolerance * dimension)
	end
	local function problems(part, def, name)
		local list = {}
		local okId, meshId = pcall(function()
			return part.MeshId
		end)
		if not okId or meshId == nil or meshId == "" then
			table.insert(report.noMesh, name)
			table.insert(list, "no MeshId")
		end
		local want = Vector3.new(def.size[1], def.size[2], def.size[3])
		local have = part.Size
		if
			math.abs(have.X - want.X) > tolerance(want.X)
			or math.abs(have.Y - want.Y) > tolerance(want.Y)
			or math.abs(have.Z - want.Z) > tolerance(want.Z)
		then
			table.insert(
				report.wrongSize,
				string.format(
					"%s: %.2f x %.2f x %.2f, data %.2f x %.2f x %.2f",
					name,
					have.X,
					have.Y,
					have.Z,
					want.X,
					want.Y,
					want.Z
				)
			)
			table.insert(list, "wrong size")
		end
		local cf = part.CFrame
		local floor = math.cos(math.rad(settings.rotationTolerance))
		if cf.RightVector.X < floor or cf.UpVector.Y < floor or cf.LookVector.Z > -floor then
			local okAngles, rx, ry, rz = pcall(function()
				return cf:ToEulerAnglesXYZ()
			end)
			table.insert(
				report.rotated,
				okAngles
						and string.format(
							"%s: %.1f, %.1f, %.1f degrees",
							name,
							math.deg(rx),
							math.deg(ry),
							math.deg(rz)
						)
					or name
			)
			table.insert(list, "rotated")
		end
		local okTexture, texture = pcall(function()
			return part.TextureID
		end)
		if okTexture and texture ~= nil and texture ~= "" then
			table.insert(report.textured, name)
		end
		return list
	end

	-- A Model shaped like Parts.newModel's stand-ins around the (stripped) MeshPart.
	local function wrap(id, def, mesh)
		local model = world.Instance.new("Model")
		model.Name = id
		local rootPart = world.Instance.new("Part")
		rootPart.Name = "Root"
		rootPart.Size = Vector3.new(def.size[1], 0.2, def.size[3])
		rootPart.CFrame = CFrame.new(0, 0.1, 0)
		rootPart.PivotOffset = CFrame.new(0, -0.1, 0)
		rootPart.Anchored = true
		rootPart.CanCollide = false
		rootPart.CanTouch = false
		rootPart.CanQuery = true
		rootPart.Transparency = 1
		rootPart.CastShadow = false
		rootPart.Massless = true
		rootPart.Parent = model
		mesh.Name = "Body"
		mesh.CFrame = CFrame.new(def.bbox_center[1], def.bbox_center[2], def.bbox_center[3])
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.CanTouch = false
		mesh.CanQuery = true
		mesh.Massless = true
		mesh.CastShadow = true
		mesh.Transparency = 0
		-- the physics shape of the Body: set here (the command bar has plugin rights) in the open place; scripts cannot manipulate it at
		-- runtime, so the Kit does not, and the API dump lists it as not saved: it is not in the saved .rbxm and nothing relies on it
		mesh.CollisionFidelity = Enum.CollisionFidelity.Hull
		mesh.Parent = model
		model.PrimaryPart = rootPart
		return model
	end

	-- The MeshPart of a wrapped Model that is already in the folder, if it still looks right.
	local function wrappedMesh(model)
		if not model:IsA("Model") then
			return nil
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("MeshPart") then
				return d
			end
		end
		return nil
	end

	for _, id in ipairs(ids) do
		local def = data.props[id]
		local list = candidates[id]
		local existing = container and container:FindFirstChild(id)
		if list and #list > 1 then
			table.insert(report.duplicates, string.format("%s (%d copies; took %s)", id, #list, list[1]:GetFullName()))
		end
		if list then
			local source = list[1]
			local checked = problems(source, def, id)
			if not settings.dryRun then
				local mesh = if settings.move then source else source:Clone()
				-- Nothing may ride along on a mesh (the colour is the baked vertex colour). Everything is removed from the copy and
				-- logged: scripts, PBR (SurfaceAppearance, D-057 (17)) and anything that fetches or carries a remote id or state
				-- (Sound, Decal, Texture, ParticleEmitter, Animation, ObjectValue, StringValue, Attachment, welds...). Walk before
				-- destroying: nothing is read from an instance after it was destroyed.
				for _, child in ipairs(mesh:GetChildren()) do
					local doomed = child:GetDescendants()
					table.insert(doomed, 1, child)
					for _, d in ipairs(doomed) do
						if d:IsA("LuaSourceContainer") then
							report.scriptsRemoved += 1
						end
						table.insert(report.stripped, string.format("%s %s", d.ClassName, d:GetFullName()))
					end
					child:Destroy()
				end
				for name in pairs(mesh:GetAttributes()) do
					table.insert(report.stripped, string.format("Attribute %s on %s", name, id))
					mesh:SetAttribute(name, nil)
				end
				for _, tag in ipairs(mesh:GetTags()) do
					table.insert(report.stripped, string.format("Tag %s on %s", tag, id))
					mesh:RemoveTag(tag)
				end
				local model = wrap(id, def, mesh)
				if existing then
					existing:Destroy()
				end
				model.Parent = container
			end
			report.imported += 1
			if #checked > 0 then
				complain(string.format("import_env_kit: %s: %s", id, table.concat(checked, ", ")))
			end
		elseif existing and wrappedMesh(existing) then
			local checked = problems(wrappedMesh(existing), def, id)
			if not settings.dryRun then
				-- an earlier run did not set the physics shape: the kept Body gets it now
				wrappedMesh(existing).CollisionFidelity = Enum.CollisionFidelity.Hull
			end
			report.kept += 1
			if #checked > 0 then
				complain(
					string.format(
						"import_env_kit: %s (already in %s): %s",
						id,
						container:GetFullName(),
						table.concat(checked, ", ")
					)
				)
			end
		else
			table.insert(report.missing, id)
		end
	end
	if not settings.dryRun then
		pcall(function()
			world.ChangeHistoryService:SetWaypoint("import_env_kit (after)")
		end)
		pcall(function()
			world.Selection:Set({ container })
		end)
	end

	-- 4. the report
	local function listOf(title, list, limit)
		if #list > 0 then
			table.sort(list)
			local shown = {}
			for i = 1, math.min(#list, limit or 12) do
				table.insert(shown, list[i])
			end
			log(
				string.format(
					"import_env_kit: %s (%d): %s%s",
					title,
					#list,
					table.concat(shown, "; "),
					#list > #shown and "; ..." or ""
				)
			)
		end
	end
	listOf("MISSING props", report.missing)
	listOf("WRONG SIZE", report.wrongSize)
	listOf("NO MESH (not uploaded)", report.noMesh)
	listOf("ROTATED (the wrapper places meshes unrotated: re-import with Forward -Z, Up Y)", report.rotated)
	listOf("duplicate sources", report.duplicates)
	listOf("MeshParts that are not in the kit's data (ignored)", report.stray, 8)
	listOf("TEXTURED (the contract is vertex colours only; TextureID kept as imported)", report.textured, 8)
	if #report.stripped > 0 then
		log(
			string.format(
				"import_env_kit: %d instance(s)/attribute(s)/tag(s) found on imported meshes were deleted from the copies (%d of them scripts); nothing may stay on a mesh:",
				#report.stripped,
				report.scriptsRemoved
			)
		)
		for i, line in ipairs(report.stripped) do
			if i > 12 then
				log(string.format("  ... and %d more", #report.stripped - 12))
				break
			end
			log("  stripped: " .. line)
		end
	end

	-- 5. ask the Kit itself, when the place lets the command bar load it
	if not settings.dryRun then
		local smoke = {
			pcall(function()
				local Kit = world.require(world.ReplicatedStorage.Game.Kit.Kit)
				Kit.setAssetSource(assets)
				for _, id in ipairs(ids) do
					local prop = Kit.prop(id)
					if prop:GetAttribute("KitEnvMesh") then
						report.accepted += 1
					else
						local why = Kit.envMeshStatus().rejected[id] or "not in the folder"
						table.insert(report.fallbacks, string.format("%s: %s", id, why))
					end
					prop:Destroy()
				end
				Kit.setAssetSource(nil)
				return string.format("Kit.prop accepts %d of %d props", report.accepted, #ids)
			end),
		}
		if smoke[1] then
			report.smoke = tostring(smoke[2])
			log("import_env_kit: Kit smoke test: " .. report.smoke)
			listOf("part-built still (Kit.prop rejects or lacks them)", report.fallbacks)
		else
			report.smoke = "skipped (" .. tostring(smoke[2]) .. ")"
			log("import_env_kit: Kit smoke test " .. report.smoke .. ": playtest to see the props")
		end
	end

	report.ok = #report.missing == 0 and #report.wrongSize == 0 and #report.noMesh == 0 and #report.rotated == 0
	log(
		string.format(
			"import_env_kit: %s%d imported, %d kept, %d missing of %d. Triangles: not available in Studio (see env.json / the manifest). %s",
			settings.dryRun and "DRY RUN: nothing changed. " or "",
			report.imported,
			report.kept,
			#report.missing,
			report.expected,
			report.ok and "RESULT: OK" or "RESULT: INCOMPLETE"
		)
	)
	if report.ok and not settings.dryRun then
		log(
			"import_env_kit: next: check the Output, then right-click ReplicatedStorage > Forge > Assets > "
				.. (if settings.flat then "(select the Models)" else settings.folderName)
				.. " > Save to File... (see IMPORT_ENVIRONMENT.md)"
		)
	end
	report.lines = lines
	return report
end

-- ------------------------------------------------------------------ run it (the command bar's globals)
local result = importEnvKit({
	print = print,
	warn = warn,
	require = require,
	Instance = Instance,
	Workspace = workspace,
	ReplicatedStorage = game:GetService("ReplicatedStorage"),
	ChangeHistoryService = game:GetService("ChangeHistoryService"),
	Selection = game:GetService("Selection"),
}, {
	source = SOURCE,
	move = MOVE,
	dryRun = DRY_RUN,
	flat = FLAT,
	folderName = FOLDER_NAME,
	sizeTolerance = SIZE_TOLERANCE,
	relTolerance = REL_TOLERANCE,
	rotationTolerance = ROTATION_TOLERANCE,
})

return result
