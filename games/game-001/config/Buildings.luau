--!strict
--[[
	Buildings (ReplicatedStorage.Forge.Config.Buildings) — game-001 building definitions. Owner: FORGE-01.

	One entry per CONTRACTS G2 BuildingType: footprint (radius, studs; Kit.footprint replaces it in the
	simulation, G6), whether rulers may place it, drop-off role (`accepts` limits it to some resources),
	limits, keep-level requirements and the gameplay stats of every level: hp, popCap (housing),
	territory, farm workers/yield, defensive attack, trainable units, recruitCap and trainSpeed
	(barracks).

	One source per number (CONTRACTS G13.5): FORGE-03's Costs.luau owns every cost, build time and the
	number of levels (Costs.maxLevel). This file has stats for exactly levels 1..Costs.maxLevel(type)
	and never a cost or a time; the simulation reads those through its costs provider (Sim/Catalog).
	PROVISIONAL stats (design/living-kingdom.md §4). Read by Sim/Catalog, validated at startup.
]]

return {
	buildingOrder = {
		"keep",
		"house",
		"farm",
		"storehouse",
		"lumbercamp",
		"quarry",
		"barracks",
		"watchtower",
		"wall",
		"gate",
	},
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
					hp = 6000,
					popCap = 12,
					territory = 130,
					attack = { damage = 10, range = 40, cooldown = 1.5 },
				},
				{
					hp = 9000,
					popCap = 16,
					territory = 170,
					attack = { damage = 14, range = 45, cooldown = 1.5 },
				},
				{
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
				{ hp = 300, popCap = 4 },
				{ hp = 450, popCap = 8 },
			},
		},
		farm = {
			id = "farm",
			name = "Farm",
			footprint = 10,
			placeable = true,
			dropoff = false,
			levels = {
				{ hp = 250, workers = 3, yield = 5 },
				{ hp = 350, workers = 4, yield = 6 },
				{ hp = 450, workers = 5, yield = 7 },
			},
		},
		storehouse = {
			id = "storehouse",
			name = "Storehouse",
			footprint = 7,
			placeable = true,
			dropoff = true,
			levels = {
				{ hp = 500 },
			},
		},
		lumbercamp = {
			id = "lumbercamp",
			name = "Lumber Camp",
			footprint = 6,
			placeable = true,
			dropoff = true,
			accepts = { "wood" },
			levels = { -- PROVISIONAL: higher levels are sturdier; their wood-rate bonus lands with FL-0081
				{ hp = 350 },
				{ hp = 500 },
				{ hp = 650 },
			},
		},
		quarry = {
			id = "quarry",
			name = "Quarry",
			footprint = 6,
			placeable = true,
			dropoff = true,
			accepts = { "stone", "gold" },
			levels = { -- PROVISIONAL: higher levels are sturdier; their stone-rate bonus lands with FL-0081
				{ hp = 350 },
				{ hp = 500 },
				{ hp = 650 },
			},
		},
		barracks = {
			id = "barracks",
			name = "Barracks",
			footprint = 10,
			placeable = true,
			dropoff = false,
			maxCount = 2,
			-- recruitCap: living soldiers plus those in training that this barracks supports (the kingdom's
			-- cap is the sum over its standing barracks); trainSpeed divides the unit's trainSeconds.
			-- Design §4: recruit cap 5 / 10 / 15 / 20; level 4 veterans come with morale (FL-0082).
			levels = {
				{ hp = 1200, trains = { "soldier", "archer" }, recruitCap = 5, trainSpeed = 1 },
				{ hp = 1800, trains = { "soldier", "archer", "knight", "ram" }, recruitCap = 10, trainSpeed = 1 },
				{ hp = 2400, trains = { "soldier", "archer", "knight", "ram" }, recruitCap = 15, trainSpeed = 1.25 },
				{ hp = 3000, trains = { "soldier", "archer", "knight", "ram" }, recruitCap = 20, trainSpeed = 1.5 },
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
					hp = 1200,
					attack = { damage = 12, range = 45, cooldown = 1.5 },
				},
				{
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
				{ hp = 900 },
				{ hp = 1600 },
				{ hp = 2400 },
			},
		},
		gate = { -- in the simulation a gate is a wall section for now (walls and gates are VS-2)
			id = "gate",
			name = "Gate",
			footprint = 6,
			placeable = true,
			dropoff = false,
			levels = {
				{ hp = 1200 },
				{ hp = 2000 },
				{ hp = 3000 },
			},
		},
	},
	placementGap = 2, -- studs kept free between footprints
	cancelRefund = 0.5, -- share of a site's paid cost returned on cancel
}
