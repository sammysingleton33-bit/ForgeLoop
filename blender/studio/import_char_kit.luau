--!nocheck
--[[
	import_char_kit — Studio COMMAND-BAR script: puts the imported citizen kit where Kit.character looks for it.   FL-0135
	Owner: FORGE-02. Procedure for the owner: games/game-001/art/IMPORT_CHARACTERS.md. STUDIO-UNVERIFIED: this script has
	run only under Lune against fake instance trees (tests/world/KitCharacterMeshImport.spec), never in Studio.

	What it does (edit mode, Studio command bar: paste the whole file and press Enter; read the Output window):
	  1. Reads the kit's data from ReplicatedStorage.Game.Kit.CharacterMeshData (a ModuleScript the project's Rojo build
	     puts in the place): the piece ids, their sizes. (Without it: name-only mode, every MeshPart found is taken.)
	  2. Finds the MeshParts the FBX import created in Workspace (inside SOURCE if you set it), by piece id = mesh object name.
	  3. Puts each one, named by its piece id, under ReplicatedStorage.Forge.Assets.CitizenKit (a Folder it creates if
	     needed). CLONES by default (the originals stay in Workspace for you to delete); MOVE = true moves them.
	  4. Checks every piece: it is a MeshPart, has a MeshId (Studio uploaded its mesh), has the size the data says
	     (+/- 0.1 stud: a wrong Scale Unit or axis shows here), and is not rotated (the Kit places pieces unrotated). Everything
	     inside a piece except a SurfaceAppearance (the shared palette) is deleted from the copy and listed in the report:
	     scripts (Script, LocalScript, ModuleScript) and anything that carries a remote id or state (Sound, Decal, Texture,
	     ParticleEmitter, Animation, ObjectValue, StringValue, Attachment...). report.stripped has "<ClassName> <full name>".
	  5. Prints a report: counts, missing pieces, wrong sizes, rotated pieces, duplicates, stray MeshParts. Triangle counts
	     are NOT available from Studio: the triangle figures are the Blender export's (rig.json `tris`, the manifest).
	  Idempotent: run it again and it replaces the folder's pieces with the same result; pieces already in the folder that
	  have no new source are kept and checked. One Ctrl+Z undoes a run.

	What it never does: no network, no HttpService, no require(assetId) (the only requires are the ModuleScripts above,
	by instance), no scripts created, nothing outside ReplicatedStorage.Forge.Assets.CitizenKit is changed, nothing is
	published or saved. Saving and publishing are the owner's steps.
]]

-- ------------------------------------------------------------------ settings (edit these, nothing else)
local SOURCE = nil -- the Instance the importer made, e.g. workspace:FindFirstChild("citizen_kit"); nil = all of Workspace
local MOVE = false -- true: move the imported MeshParts into CitizenKit instead of cloning them
local DRY_RUN = false -- true: only report, change nothing
local FOLDER_NAME = "CitizenKit" -- Kit/CharacterMesh.FOLDER_NAME
local SIZE_TOLERANCE = 0.1 -- Kit/CharacterMesh.SIZE_TOLERANCE
local ROTATION_TOLERANCE = 0.5 -- degrees

-- ------------------------------------------------------------------ the work, with its world passed in (so a test can run it)
local function importCitizenKit(world, settings)
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
		scriptsRemoved = 0,
		stripped = {}, -- every non-SurfaceAppearance descendant removed from a piece copy: "<ClassName> <full name>"
		layout = "unchecked",
		dryRun = settings.dryRun,
		ok = false,
	}

	-- 1. the kit's data
	local data = nil
	do
		local ok, module = pcall(function()
			return world.ReplicatedStorage.Game.Kit.CharacterMeshData
		end)
		if ok and module then
			local loaded, result = pcall(world.require, module)
			if loaded and type(result) == "table" and type(result.pieces) == "table" then
				data = result
			else
				complain("import_char_kit: CharacterMeshData did not load: " .. tostring(result))
			end
		end
	end
	local expected = {} -- id -> piece def (nil def: name-only mode)
	local ids = {}
	if data then
		for id, def in pairs(data.pieces) do
			if def.empty ~= true then
				expected[id] = def
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		report.expected = #ids
		if #ids == 0 then
			log(
				"import_char_kit: Kit/CharacterMeshData has no pieces yet (run art/char_kit/rig_to_luau.py and rebuild the place)."
			)
			return report
		end
	else
		log(
			"import_char_kit: NAME-ONLY MODE: no CharacterMeshData in this place, so sizes cannot be checked and every MeshPart found is taken."
		)
	end

	-- 2. the candidates in Workspace (not the ones already in the target folder)
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
			"import_char_kit: ReplicatedStorage.Forge.Assets does not exist: this is not the project's place (build it with Rojo). Nothing changed."
		)
		return report
	end
	local target = assets:FindFirstChild(settings.folderName)
	local root = settings.source or world.Workspace
	local candidates = {} -- id -> { MeshPart... } sorted by full name
	local meshCount = 0
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") and not (target and d:IsDescendantOf(target)) then
			meshCount += 1
			if data == nil or expected[d.Name] then
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
	if data == nil then
		for id in pairs(candidates) do
			table.insert(ids, id)
		end
		table.sort(ids)
		report.expected = #ids
	end
	log(
		string.format(
			"import_char_kit: %d piece(s) expected, %d MeshPart(s) under %s",
			report.expected,
			meshCount,
			root:GetFullName()
		)
	)

	-- 3. layout check: do the imported pieces stand at the positions the data says (relative to each other)? Information only.
	if data then
		local anchorId, anchorPart = nil, nil
		for _, id in ipairs(ids) do
			if candidates[id] then
				anchorId, anchorPart = id, candidates[id][1]
				break
			end
		end
		if anchorId then
			local total, matching = 0, 0
			local a = expected[anchorId].bbox_center
			for _, id in ipairs(ids) do
				local part = candidates[id] and candidates[id][1]
				if part then
					local c = expected[id].bbox_center
					local want = Vector3.new(c[1] - a[1], c[2] - a[2], c[3] - a[3])
					local have = part.CFrame.Position - anchorPart.CFrame.Position
					total += 1
					if (want - have).Magnitude <= 0.1 then
						matching += 1
					end
				end
			end
			report.layout = string.format(
				"%d of %d imported pieces stand where rig.json puts them (relative to %s)",
				matching,
				total,
				anchorId
			)
			log(
				"import_char_kit: layout: "
					.. report.layout
					.. (
						matching == total and ""
						or " (information only: the Kit places pieces from rig.json, not from this scene)"
					)
			)
		end
	end

	-- 4. check and place
	if not settings.dryRun then
		pcall(function()
			world.ChangeHistoryService:SetWaypoint("import_char_kit (before)")
		end)
		if target == nil then
			target = world.Instance.new("Folder")
			target.Name = settings.folderName
			target.Parent = assets
		end
	end
	local function problems(part, def)
		local list = {}
		local okId, meshId = pcall(function()
			return part.MeshId
		end)
		if not okId or meshId == nil or meshId == "" then
			table.insert(report.noMesh, part.Name)
			table.insert(list, "no MeshId")
		end
		if def then
			local want = Vector3.new(def.size[1], def.size[2], def.size[3])
			local have = part.Size
			if
				math.abs(have.X - want.X) > settings.sizeTolerance
				or math.abs(have.Y - want.Y) > settings.sizeTolerance
				or math.abs(have.Z - want.Z) > settings.sizeTolerance
			then
				table.insert(
					report.wrongSize,
					string.format(
						"%s: %.2f x %.2f x %.2f, data %.2f x %.2f x %.2f",
						part.Name,
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
							part.Name,
							math.deg(rx),
							math.deg(ry),
							math.deg(rz)
						)
					or part.Name
			)
			table.insert(list, "rotated")
		end
		return list
	end

	for _, id in ipairs(ids) do
		local list = candidates[id]
		local existing = target and target:FindFirstChild(id)
		if list and #list > 1 then
			table.insert(report.duplicates, string.format("%s (%d copies; took %s)", id, #list, list[1]:GetFullName()))
		end
		if list then
			local source = list[1]
			local checked = problems(source, expected[id])
			if not settings.dryRun then
				local piece = if settings.move then source else source:Clone()
				-- Only a SurfaceAppearance (the shared palette) may ride along on a piece. Everything else is removed from the
				-- copy and logged: scripts (Script, LocalScript, ModuleScript), and anything that fetches or carries a remote
				-- id or state (Sound, Decal, Texture, ParticleEmitter, Animation, ObjectValue, StringValue, Attachment...).
				-- walk before destroying: nothing is read from an instance after it was destroyed
				local function strip(parent: Instance)
					for _, child in ipairs(parent:GetChildren()) do
						if child:IsA("SurfaceAppearance") then
							strip(child)
						else
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
					end
				end
				strip(piece)
				-- attributes and tags on the piece itself are payload too: remove them and list what was removed
				for name in pairs(piece:GetAttributes()) do
					table.insert(report.stripped, string.format("Attribute %s on %s", name, piece:GetFullName()))
					piece:SetAttribute(name, nil)
				end
				for _, tag in ipairs(piece:GetTags()) do
					table.insert(report.stripped, string.format("Tag %s on %s", tag, piece:GetFullName()))
					piece:RemoveTag(tag)
				end
				piece.Name = id
				if existing and existing ~= piece then
					existing:Destroy()
				end
				piece.Parent = target
			end
			report.imported += 1
			if #checked > 0 then
				complain(string.format("import_char_kit: %s: %s", id, table.concat(checked, ", ")))
			end
		elseif existing and existing:IsA("MeshPart") then
			local checked = problems(existing, expected[id])
			report.kept += 1
			if #checked > 0 then
				complain(
					string.format(
						"import_char_kit: %s (already in %s): %s",
						id,
						settings.folderName,
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
			world.ChangeHistoryService:SetWaypoint("import_char_kit (after)")
		end)
		pcall(function()
			world.Selection:Set({ target })
		end)
	end

	-- 5. the report
	local function listOf(title, list, limit)
		if #list > 0 then
			table.sort(list)
			local shown = {}
			for i = 1, math.min(#list, limit or 12) do
				table.insert(shown, list[i])
			end
			log(
				string.format(
					"import_char_kit: %s (%d): %s%s",
					title,
					#list,
					table.concat(shown, "; "),
					#list > #shown and "; ..." or ""
				)
			)
		end
	end
	listOf("MISSING pieces", report.missing)
	listOf("WRONG SIZE", report.wrongSize)
	listOf("NO MESH (not uploaded)", report.noMesh)
	listOf("ROTATED (the Kit places pieces unrotated: re-import with Forward -Z, Up Y)", report.rotated)
	listOf("duplicate sources", report.duplicates)
	listOf("MeshParts that are not in the kit's data (ignored)", report.stray, 8)
	if #report.stripped > 0 then
		log(
			string.format(
				"import_char_kit: %d instance(s) found inside imported pieces were deleted from the copies (%d of them scripts); only a SurfaceAppearance may stay:",
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
	report.ok = #report.missing == 0 and #report.wrongSize == 0 and #report.noMesh == 0 and #report.rotated == 0
	log(
		string.format(
			"import_char_kit: %s%d imported, %d kept, %d missing of %d. Triangles: not available in Studio (see rig.json / the manifest). %s",
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
			"import_char_kit: next: check the Output, then right-click ReplicatedStorage > Forge > Assets > "
				.. settings.folderName
				.. " > Save to File... (see IMPORT_CHARACTERS.md)"
		)
	end

	-- 6. a smoke test through the Kit itself, when the place lets the command bar load it
	if not settings.dryRun and data then
		local smoke = {
			pcall(function()
				local Kit = world.require(world.ReplicatedStorage.Game.Kit.Kit)
				Kit.setAssetSource(assets)
				local rig = Kit.character("citizen", "farmer", Color3.fromRGB(190, 40, 50))
				local status = Kit.characterMeshStatus()
				local built = if rig:GetAttribute("KitMesh") then "MESH" else "part-built (fallback)"
				rig:Destroy()
				Kit.setAssetSource(nil)
				return string.format("Kit.character built a %s rig; missing in the folder: %d", built, #status.missing)
			end),
		}
		if smoke[1] then
			log("import_char_kit: Kit smoke test: " .. tostring(smoke[2]))
		else
			log("import_char_kit: Kit smoke test skipped (" .. tostring(smoke[2]) .. "): playtest to see the rigs")
		end
	end
	report.lines = lines
	return report
end

-- ------------------------------------------------------------------ run it (the command bar's globals)
local result = importCitizenKit({
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
	folderName = FOLDER_NAME,
	sizeTolerance = SIZE_TOLERANCE,
	rotationTolerance = ROTATION_TOLERANCE,
})

return result
