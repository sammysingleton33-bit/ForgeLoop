--!strict
--[[
	Kingdoms (ReplicatedStorage.Forge.Config.Kingdoms) — the four kingdoms and how they start. Owner: FORGE-01.

	identities: CONTRACTS G2 KingdomIds in map order (clockwise, so neighbours are adjacent), display
	names, banner colours and unique team BrickColors (Teams map one-to-one).
	start: what every kingdom begins with — citizens per job (VS-1 row 4 needs at least 12), the
	buildings granted complete at match start (angle relative to the direction toward the map centre)
	and the treasury seed used by the local Treasury double (FORGE-03 seeds the real TreasuryService).
]]

return {
	identities = {
		{ id = "crimson", name = "Crimson Kingdom", color = { 190, 40, 50 }, teamColor = "Crimson" },
		{ id = "azure", name = "Azure Kingdom", color = { 40, 110, 210 }, teamColor = "Bright blue" },
		{ id = "emerald", name = "Emerald Kingdom", color = { 40, 160, 90 }, teamColor = "Bright green" },
		{ id = "gold", name = "Gold Kingdom", color = { 225, 175, 40 }, teamColor = "Bright yellow" },
	},
	maxRulersPerKingdom = 4,
	startCitizens = { farmer = 3, woodcutter = 3, miner = 2, builder = 2, hauler = 2 },
	startBuildings = { { kind = "farm", angle = 0.6, distance = 34 } },
	startResources = { food = 120, wood = 100, stone = 50, gold = 0 },
	spacing = 260, -- generated layout: keeps on the corners of a square this far from the centre
	trees = 24, -- generated layout: trees per forest
}
