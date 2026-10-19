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
	-- D-055 (1): the entity budget (BRIEF §14: 300 per server, 4 x 75) holds in the full match. At most this many
	-- citizens per kingdom: births stop at it (housing still limits below it). Raised only on measured evidence.
	maxPerKingdom = 60,
	-- a birth's food from the treasury: the meal double only. With the upkeep (CitizenService), a birth
	-- costs no food and needs fedRatio >= Society.food.wellFedAtLeast and a free bed (D-045, PROVISIONAL)
	birthFood = 25,
	memorySize = 8,
	memorySeconds = 45,
	fleeRadius = 40,
	-- VS-1 reactions (CONTRACTS G5), PROVISIONAL: a ruler's visit lifts mood by visitMood for
	-- visitMoodSeconds, at most once per citizen per visitCooldown; citizens within celebrateRadius of the
	-- keep celebrate when it reaches level 2
	visitMood = 15,
	visitMoodSeconds = 180,
	visitCooldown = 180,
	celebrateRadius = 60,
	arriveRadius = 1.5,
	needTargets = { food = 150, wood = 200, stone = 150, gold = 80 },
}
