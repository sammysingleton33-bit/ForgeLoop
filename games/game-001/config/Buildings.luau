--!strict
--[[
	Buildings (ReplicatedStorage.Forge.Config.Buildings) — game-001 building definitions. Owner: FORGE-01.

	One entry per CONTRACTS G2 BuildingType: footprint (radius, studs), whether rulers may place it,
	drop-off role (`accepts` limits it to some resources), limits, keep-level requirements and the
	stats of every level (hp, popCap, territory, farm workers/yield, defensive attack, trainable units).
	`cost` and `work` per level are the local double of FORGE-03's Costs.luau (G6); the simulation reads
	costs only through its costs provider, so Costs.luau replaces them without code changes.
	Read by Sim/Catalog, validated at startup (Catalog.validate).
]]

return {
	buildingOrder = { "keep", "house", "farm", "storehouse", "lumbercamp", "quarry", "barracks", "watchtower", "wall" },
	buildings = {
		keep = {
			id = "keep",
			name = "Keep",
			footprint = 14,
			placeable = false,
			dropoff = true,
			maxCount = 1,
			levels = {
				{
					cost = {},
					work = 0,
					hp = 6000,
					popCap = 12,
					territory = 130,
					attack = { damage = 10, range = 40, cooldown = 1.5 },
				},
				{
					cost = { wood = 150, stone = 150 },
					work = 60,
					hp = 9000,
					popCap = 16,
					territory = 170,
					attack = { damage = 14, range = 45, cooldown = 1.5 },
				},
				{
					cost = { wood = 300, stone = 300, gold = 100 },
					work = 120,
					hp = 12000,
					popCap = 20,
					territory = 210,
					attack = { damage = 18, range = 50, cooldown = 1.5 },
				},
			},
		},
		house = {
			id = "house",
			name = "House",
			footprint = 6,
			placeable = true,
			dropoff = false,
			levels = {
				{ cost = { wood = 40 }, work = 15, hp = 300, popCap = 4 },
				{ cost = { wood = 40, stone = 30 }, work = 20, hp = 450, popCap = 7 },
				{ cost = { wood = 60, stone = 60 }, work = 25, hp = 600, popCap = 10 },
			},
		},
		farm = {
			id = "farm",
			name = "Farm",
			footprint = 10,
			placeable = true,
			dropoff = false,
			levels = {
				{ cost = { wood = 50 }, work = 20, hp = 250, workers = 3, yield = 5 },
				{ cost = { wood = 60, stone = 20 }, work = 25, hp = 350, workers = 4, yield = 6 },
				{ cost = { wood = 80, stone = 60 }, work = 30, hp = 450, workers = 5, yield = 7 },
			},
		},
		storehouse = {
			id = "storehouse",
			name = "Storehouse",
			footprint = 7,
			placeable = true,
			dropoff = true,
			levels = {
				{ cost = { wood = 60 }, work = 20, hp = 500 },
				{ cost = { wood = 60, stone = 60 }, work = 30, hp = 800 },
			},
		},
		lumbercamp = {
			id = "lumbercamp",
			name = "Lumber Camp",
			footprint = 6,
			placeable = true,
			dropoff = true,
			accepts = { "wood" },
			levels = {
				{ cost = { wood = 40 }, work = 15, hp = 350 },
			},
		},
		quarry = {
			id = "quarry",
			name = "Quarry",
			footprint = 6,
			placeable = true,
			dropoff = true,
			accepts = { "stone", "gold" },
			levels = {
				{ cost = { wood = 50 }, work = 15, hp = 350 },
			},
		},
		barracks = {
			id = "barracks",
			name = "Barracks",
			footprint = 10,
			placeable = true,
			dropoff = false,
			maxCount = 2,
			levels = {
				{ cost = { wood = 120, stone = 60 }, work = 40, hp = 1200, trains = { "soldier", "archer" } },
				{
					cost = { wood = 100, stone = 120, gold = 40 },
					work = 50,
					hp = 1800,
					trains = { "soldier", "archer", "knight", "ram" },
				},
			},
		},
		watchtower = {
			id = "watchtower",
			name = "Watchtower",
			footprint = 5,
			placeable = true,
			dropoff = false,
			requiresKeepLevel = 2,
			levels = {
				{
					cost = { wood = 60, stone = 80 },
					work = 35,
					hp = 1200,
					attack = { damage = 12, range = 45, cooldown = 1.5 },
				},
				{
					cost = { stone = 120, gold = 20 },
					work = 40,
					hp = 1800,
					attack = { damage = 18, range = 55, cooldown = 1.5 },
				},
			},
		},
		wall = {
			id = "wall",
			name = "Wall",
			footprint = 4,
			placeable = true,
			dropoff = false,
			levels = {
				{ cost = { stone = 20 }, work = 10, hp = 900 },
				{ cost = { stone = 30 }, work = 12, hp = 1600 },
			},
		},
	},
	placementGap = 2, -- studs kept free between footprints
	cancelRefund = 0.5, -- share of a site's paid cost returned on cancel
}
