--!strict
--[[
	Kit/EnvMeshData — the imported nature meshes (trees, bushes, rocks, resource nodes, flowers, crops) as data (FL-0136,
	D-057 (18)-(20)). GENERATED, do not edit by hand:
		python3 games/game-001/art/env_kit/env_to_luau.py
	reads games/game-001/art/env_kit/env.json (written with the Blender env kit, schema_version 1) and rewrites this file.

	This committed version has NO props on purpose: until the real kit is generated and the owner has imported env_kit.fbx
	into Studio, Kit.prop builds the part-built stand-ins for every asset id (Kit/EnvMesh accepts a Model from
	Forge.Assets only for the ids listed here, and falls back to the stand-in when a Model does not match its entry).
]]

-- stylua: ignore start
return table.freeze({
	schema_version = 1,
	unit = "stud",
	props = {},
})
-- stylua: ignore end
