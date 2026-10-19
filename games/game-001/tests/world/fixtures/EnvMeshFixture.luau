--!strict
--[[
	Kit/EnvMeshData — the imported nature meshes as data (FL-0136, D-057 (18)-(20)). GENERATED, do not edit by hand:
		python3 games/game-001/art/env_kit/env_to_luau.py
	source games/game-001/tests/world/fixtures/env_placeholder.env.json  sha256 fcc9236e45ae0c4c58c1ff1d7f8acb340a8a5c043fca7644fe4a05eeba2763b5
	15 props (6 also resource nodes).
	Kit/EnvMesh.luau reads it; Kit.prop uses a Forge.Assets Model for these ids only when it matches, else the stand-in.
]]

-- stylua: ignore start
return table.freeze({
	schema_version = 1,
	unit = "stud",
	props = {
		bush_01 = { family = "bush", bbox_center = { -0.2, 2.4, 0.3 }, size = { 7, 4.8, 6.6 }, tris = 160, tint = "fixed", standin_size = { 7.4, 5.2, 6.9 }, node = false },
		bush_03 = { family = "bush", bbox_center = { 0.3, 2.6, 0 }, size = { 6.2, 5.2, 6.4 }, tris = 180, tint = "fixed", standin_size = { 6.1, 5.5, 6.7 }, node = true },
		farm_field_wheat_01 = { family = "crop", bbox_center = { 0, 1.15, 0 }, size = { 37, 2.3, 27 }, tris = 1200, tint = "fixed", standin_size = { 38, 2.4, 28 }, node = false },
		farm_haystack_01 = { family = "haystack", bbox_center = { 0.4, 3, 0 }, size = { 7, 6, 6.4 }, tris = 150, tint = "fixed", standin_size = { 7.3, 6.2, 6.2 }, node = false },
		plant_flowers_01 = { family = "flower", bbox_center = { 0.1, 1.4, -0.2 }, size = { 4, 2.8, 3.1 }, tris = 90, tint = "fixed", standin_size = { 4.1, 3, 3 }, node = false, collider = false },
		resource_ore_03 = { family = "rock", bbox_center = { 0.6, 3.9, -0.5 }, size = { 10.8, 7.8, 9.6 }, tris = 280, tint = "fixed", standin_size = { 11.4, 8.1, 9.9 }, node = true },
		resource_stone_01 = { family = "rock", bbox_center = { 0.5, 3.7, -0.4 }, size = { 16, 7.4, 10.2 }, tris = 240, tint = "fixed", standin_size = { 16.8, 7.8, 10.7 }, node = true },
		rock_boulder_l_01 = { family = "rock", bbox_center = { -1, 4.4, 0 }, size = { 17, 8.8, 13.6 }, tris = 260, tint = "fixed", standin_size = { 18, 9.1, 14.3 }, node = false, collider = { 10, 6, 8 } },
		rock_boulder_m_01 = { family = "rock", bbox_center = { 0.2, 2.5, 0.8 }, size = { 6, 5, 8.4 }, tris = 120, tint = "fixed", standin_size = { 6.2, 5.3, 8.9 }, node = false },
		tree_birch_01 = { family = "tree", bbox_center = { -1.5, 10.5, 0.2 }, size = { 9.6, 21, 8.8 }, tris = 520, tint = "fixed", standin_size = { 10.1, 22.2, 8.1 }, node = false },
		tree_oak_01 = { family = "tree", bbox_center = { -1, 12, 0.4 }, size = { 17.6, 24, 19.2 }, tris = 780, tint = "fixed", standin_size = { 18.9, 25.5, 21 }, node = true },
		tree_oak_02 = { family = "tree", bbox_center = { -0.2, 11.75, -0.4 }, size = { 16, 23.5, 16.4 }, tris = 720, tint = "fixed", standin_size = { 16.3, 24.6, 16.9 }, node = false },
		tree_oak_03 = { family = "tree", bbox_center = { 0.5, 16, 0 }, size = { 17, 32, 17 }, tris = 800, tint = "fixed", standin_size = { 20.8, 25.5, 22.7 }, node = true, fit_note = "a tall, narrow lone oak: the role is a landmark, so it is taller and thinner than the part-built dome" },
		tree_pine_01 = { family = "tree", bbox_center = { 0, 14.4, 0.1 }, size = { 15, 28.8, 15.2 }, tris = 620, tint = "fixed", standin_size = { 16.4, 29.6, 16.4 }, node = false },
		tree_pine_02 = { family = "tree", bbox_center = { 0.1, 15.5, 0 }, size = { 15.6, 31, 15.6 }, tris = 640, tint = "fixed", standin_size = { 16.4, 32.3, 16.4 }, node = true },
	},
})
-- stylua: ignore end
