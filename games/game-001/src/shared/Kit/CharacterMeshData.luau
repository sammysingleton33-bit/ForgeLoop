--!strict
--[[
	Kit/CharacterMeshData — the imported-mesh citizen kit as data (FL-0135, D-057). GENERATED, do not edit by hand:
		python3 games/game-001/art/char_kit/rig_to_luau.py
	reads games/game-001/art/char_kit/rig.json (written with the Blender kit, schema_version 1) and rewrites this file.

	This committed version has NO pieces on purpose: until the real kit is generated and the owner has imported
	citizen_kit.fbx into Studio, Kit.character builds today's part-built rigs for every citizen (Kit/CharacterMesh
	falls back whenever this table has no pieces or the asset folder lacks one).
]]

-- stylua: ignore start
return table.freeze({
	schema_version = 1,
	unit = "stud",
	root_height = 3.2,
	joints = {},
	pieces = {},
	assemblies = {},
})
-- stylua: ignore end
