--!strict
--[[
	Society (ReplicatedStorage.Forge.Config.Society) — living-kingdom tuning: conversations, reputation and the
	kingdom conditions (CONTRACTS G13.3, G13.4; design/living-kingdom.md §3, §5, §7). Owner: FORGE-01.

	Every number here is a PROVISIONAL balancing proposal (D-030): thresholds, rates and windows live in this file,
	never in code. Decision and action effects live in the content library (games/game-001/content), not here.

	Conversations (G13.3)
		openRequests            thought bubbles open per kingdom at a time (PROVISIONAL 3, G13.3)
		requestRefreshSeconds   how often the open-request list is refreshed
	Reputation (G13.4, Kingdom/Reputation)
		historyLimit            history entries kept per ruler (oldest dropped first)
		historySent             entries `Kingdom.GetReputation` sends (the latest 30, G13.4)
	Kingdom conditions (G13.4: happiness, stability, morale, each 0–100, separate from reputation)
		conditionStart          values of a new kingdom
		maxConditionStep        the most one application (one decision or one event, summed) may move each condition,
		                        so no single decision can push a kingdom into rebellion (living-kingdom §3, §5)
		drift                   slow drift toward a target set by food and housing (Kingdom/Reputation.driftConditions):
			rate[c]             points per second, at most, toward the target (never overshoots)
			starved[c] / fed[c] target at fed ratio 0 / 1 (linear in between; more food → higher target)
			crowdingPenalty[c]  points taken off the target when housing is fully crowded
			housingComfort      housing ratio (population / capacity) at or below which nobody is crowded
			housingCrowded      housing ratio at which the full crowding penalty applies (linear in between)
	Reputation upkeep (ReputationService, G13.4) — PROVISIONAL
		fear.relaxPerMinute     fear points a ruler loses per minute while above its start (SPEC §6.10: fear is
		                        not one-way); nothing raises fear back by itself
		food.shortageBelow      fed ratio below which a kingdom has a FoodShortage (SPEC §8: 0.5)
		food.wellFedAtLeast     lowest fed ratio over a phase for PhaseEndedWellFed (SPEC §8: 0.9)
		pushEvery               seconds between Kingdom.Reputation checks per ruler (sent only on change)
	User rules (living-kingdom §3; enforced by Kingdom/Reputation.guardRules on top of the content rows)
		rules.fightEvents       events of fighting enemies. They never LOWER the categories in rules.fightNoLoss
		                        ("fighting enemies is not a compassion loss"; Honor: "winning battles does not lower it").
		                        Atrocities have their own events (EnemyFarmsBurned, TruceBroken) and are not listed.
		rules.fightNoLoss       categories a fight event cannot lower
		rules.peaceEvents       events of keeping or making peace. They never RAISE reputation by themselves
		                        ("peacekeeping is a strategy, not a virtue that scores by itself").
	Strikes (FL-0079, not used yet; living-kingdom §5 "exploited workers") — PROVISIONAL
		strike.loyaltyBelow / obedienceBelow   a citizen counts as aggrieved below both
		strike.shareOfOccupation               share of an occupation that must be aggrieved
		strike.memoryTag                       the exploit memory an aggrieved citizen must carry
		strike.sustainSeconds                  how long the condition must hold before the strike starts
		strike.endLoyaltyAbove                 the strike ends once the occupation's mean loyalty rises above this
]]

return {
	openRequests = 3, -- PROVISIONAL (G13.3)
	requestRefreshSeconds = 20,

	historyLimit = 50,
	historySent = 30,

	conditionStart = { happiness = 60, stability = 60, morale = 60 },
	maxConditionStep = 8,
	drift = {
		rate = { happiness = 0.05, stability = 0.03, morale = 0.05 }, -- 3 / 1.8 / 3 points per minute at most
		starved = { happiness = 20, stability = 30, morale = 25 },
		fed = { happiness = 70, stability = 70, morale = 65 },
		crowdingPenalty = { happiness = 20, stability = 15, morale = 0 },
		housingComfort = 1,
		housingCrowded = 1.5,
	},

	fear = { relaxPerMinute = 2 }, -- PROVISIONAL: 10 fear above start fades in 5 minutes
	food = { shortageBelow = 0.5, wellFedAtLeast = 0.9 },
	pushEvery = 1,

	rules = {
		fightEvents = { "EnemyAttacked", "KingdomEliminated", "ObjectiveCaptured", "RaidDefended", "WarDeclared" },
		fightNoLoss = { "compassion", "honor" },
		peaceEvents = { "PeaceMade" },
	},

	strike = { -- PROVISIONAL (FL-0079)
		loyaltyBelow = 30,
		obedienceBelow = 30,
		shareOfOccupation = 0.5,
		memoryTag = "exploited",
		sustainSeconds = 60,
		endLoyaltyAbove = 40,
	},
}
