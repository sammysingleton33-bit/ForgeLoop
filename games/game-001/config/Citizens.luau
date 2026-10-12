--!strict
--[[
	Citizens (ReplicatedStorage.Forge.Config.Citizens) — the daily life of AI citizens. Owner: FORGE-01.

	Day/night routine, movement, needs (hunger, meals), population growth, decision cadence and the
	compact memory (CONTRACTS G5: at most 8 entries). mealsChargeTreasury = true is the double of
	FORGE-03's upkeep (G7); set it to false once ProductionService charges upkeep.
]]

return {
	dayLength = 120, -- seconds per full day
	nightStart = 0.75, -- fraction of the day when night falls
	citizenSpeed = 12, -- studs per second
	thinkInterval = 2, -- seconds between routine utility re-evaluations
	hungerPerDay = 1,
	eatThreshold = 0.6,
	mealFood = 2,
	mealsChargeTreasury = true,
	starveDeathHunger = 3,
	birthInterval = 30,
	birthFood = 25,
	memorySize = 8,
	memorySeconds = 45,
	fleeRadius = 40,
	arriveRadius = 1.5,
	needTargets = { food = 150, wood = 200, stone = 150, gold = 80 },
}
