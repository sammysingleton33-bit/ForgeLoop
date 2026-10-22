--!strict
--[[
	Buildings (ReplicatedStorage.Forge.Config.Buildings) — game-001 building definitions. Owner: FORGE-01.

	One entry per CONTRACTS G2 BuildingType: footprint (radius, studs; Kit.footprint replaces it in the
	simulation, G6), whether rulers may place it, drop-off role (`accepts` limits it to some resources),
	limits, keep-level requirements and the gameplay stats of every level: hp, popCap (housing),
	territory, farm workers/yield, defensive attack, trainable units, bunks and trainSpeed
	(barracks), gatherBonus (lumber camp, quarry).

	One source per number (CONTRACTS G13.5): FORGE-03's Costs.luau owns every cost, build time and the
	number of levels (Costs.maxLevel). This file has stats for exactly levels 1..Costs.maxLevel(type)
	and never a cost or a time; the simulation reads those through its costs provider (Sim/Catalog).
	PROVISIONAL stats (design/living-kingdom.md §4). Read by Sim/Catalog, validated at startup.

	Gaps: placementGap is the free ground two placement shapes keep from each other; wallGap (default
	placementGap) is the gap between two line pieces, a wall or a gate next to a wall or a gate, so a chain
	of walls can touch end to end instead of leaving a hole (FORGE-03's wall chain placement).
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
					hp = 12000,
					popCap = 12,
					territory = 130,
					attack = { damage = 10, range = 40, cooldown = 1.5 },
				},
				{
					hp = 18000,
					popCap = 16,
					territory = 170,
					attack = { damage = 14, range = 45, cooldown = 1.5 },
				},
				{
					hp = 24000,
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
			-- gatherBonus: the kingdom's citizens gather what the camp accepts this much faster (the best
			-- standing camp counts; FL-0081 "each level unlocks something"). PROVISIONAL 0 / +20% / +40%.
			levels = {
				{ hp = 350, gatherBonus = 0 },
				{ hp = 500, gatherBonus = 0.2 },
				{ hp = 650, gatherBonus = 0.4 },
			},
		},
		quarry = {
			id = "quarry",
			name = "Quarry",
			footprint = 6,
			placeable = true,
			dropoff = true,
			accepts = { "stone", "gold" },
			-- gatherBonus as the lumber camp's, for stone and gold. PROVISIONAL 0 / +20% / +40%.
			levels = {
				{ hp = 350, gatherBonus = 0 },
				{ hp = 500, gatherBonus = 0.2 },
				{ hp = 650, gatherBonus = 0.4 },
			},
		},
		barracks = {
			id = "barracks",
			name = "Barracks",
			footprint = 10,
			placeable = true,
			dropoff = false,
			maxCount = 2,
			-- bunks: soldiers sleep in the barracks, never in house or keep beds (D-041); the kingdom's
			-- soldiers (living + training) fit in the bunks of its standing barracks. PROVISIONAL 4/8/12/16.
			-- trainSpeed divides the unit's trainSeconds. Level 4 veterans come with morale (FL-0082).
			levels = {
				{ hp = 1200, trains = { "soldier", "archer" }, bunks = 4, trainSpeed = 1 },
				{ hp = 1800, trains = { "soldier", "archer", "knight", "ram" }, bunks = 8, trainSpeed = 1 },
				{ hp = 2400, trains = { "soldier", "archer", "knight", "ram" }, bunks = 12, trainSpeed = 1.25 },
				{ hp = 3000, trains = { "soldier", "archer", "knight", "ram" }, bunks = 16, trainSpeed = 1.5 },
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
	wallGap = 0, -- studs kept free between two line pieces (wall / gate): they join end to end
	lineGrid = 4, -- studs the two ends of a wall line (Build.PlaceLine) snap to
	maxLineSegments = 12, -- the most wall segments one Build.PlaceLine may lay (a segment is one Kit wall piece, 32 studs)
	-- base editing (CONTRACTS G13.9 v0.4-g9j); every time is sim time
	moveCooldown = 10, -- seconds a building waits between moves (Build.Move / MoveToSlot)
	moveSettle = 30, -- seconds a moved storehouse, lumber camp or quarry takes no deliveries and gives no gather bonus
	moveLockout = 30, -- seconds a kingdom can't move anything after a war declaration or peace that involves it
	moveDamageWindow = 10, -- a building damaged this recently can't move
	moveThreatReach = 30, -- studs beyond an at-war unit's attack range that still count as under attack
	rulerClearance = 3, -- studs around a ruler's character that no placement shape may cover
	cancelRefund = 0.5, -- share of a site's paid cost returned on cancel
}
