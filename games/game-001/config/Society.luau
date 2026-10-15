--!strict
--[[
	Society (ReplicatedStorage.Forge.Config.Society) — living-kingdom tuning: conversations, reputation and the
	kingdom conditions (CONTRACTS G13.3, G13.4; design/living-kingdom.md §3, §5, §7). Owner: FORGE-01.

	Every number here is a PROVISIONAL balancing proposal (D-030): thresholds, rates and windows live in this file,
	never in code. Decision and action effects live in the content library (games/game-001/content), not here.

	Conversations (G13.3)
		openRequests            thought bubbles open per kingdom at a time (PROVISIONAL 3, G13.3)
		requestRefreshSeconds   how often the open-request list is refreshed
		conversationHoldSec     the longest a citizen stands still, facing the ruler, while a conversation
		                        is open (G13.8, PROVISIONAL 30)
		conversation.eventSeconds   how long an event flag (event.building_completed, event.shortage, ...)
		                        stays true for scenario triggers after the event
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
	Strikes (ConsequenceService, FL-0082; living-kingdom §5 "exploited workers") — PROVISIONAL
		strike.loyaltyBelow / obedienceBelow   a citizen counts as aggrieved below both
		strike.shareOfOccupation               share of an occupation that must be aggrieved
		strike.memoryTags                      the grievance memories (pinned memory tags, content decisions.csv
		                                       memory_tag): an aggrieved citizen carries at least one. PROVISIONAL
		                                       list: refused or half pay and broken promises; "exploited" is kept
		                                       for a dedicated content tag (FORGE-06, handoff FL-0082)
		strike.sustainSeconds                  how long the condition must hold before the strike starts
		strike.endLoyaltyAbove                 the strike ends once the strikers' mean loyalty rises above this
	Sustained consequences (ConsequenceService, FL-0082; living-kingdom §5) — PROVISIONAL. Every rule needs its
	condition to hold without a break for its sustainSeconds, so no single decision can set one off; each clears
	when its end condition is met (a margin above the trigger, so it does not flicker).
		consequences.tick                      seconds between rule checks
		consequences.shortage                  food neglected: fed ratio below fedBelow for sustainSeconds →
		                                       conditions move by `conditions` every `every` seconds, unrest pressure
		                                       rises by unrestPressure while it lasts, grumbleShare of the hungriest
		                                       citizens grumble; ends at fed ratio >= endFedAbove
		consequences.riot                      prolonged instability: stability minus unrest pressure below
		                                       stabilityBelow for sustainSeconds, plus an instigator (the least loyal
		                                       citizen, loyalty below instigatorLoyaltyBelow) → a fire on the nearest
		                                       finished building other than the keep (fireDamagePerSecond, never below
		                                       fireFloor of its hit points) and the instigator plus up to rioterShare of
		                                       citizens below rioterLoyaltyBelow stop work; ends at stability >=
		                                       endStabilityAbove or after maxSeconds, then cooldownSeconds before another
		consequences.rebellion                 VS-2/3, enabled = false in the slice. Stability below stabilityBelow, at
		                                       least disloyalShareAtLeast of citizens disloyal (loyalty below
		                                       disloyalBelow and obedience below obedienceBelow) and an instigator, for
		                                       sustainSeconds → the disloyal citizens leave the kingdom
		consequences.morale                    army morale for battles (VS-2 combat): below retreatBelow units
		                                       retreat earlier, below surrenderBelow they surrender or defect
]]

return {
	openRequests = 3, -- PROVISIONAL (G13.3)
	requestRefreshSeconds = 20,
	conversationHoldSec = 30, -- PROVISIONAL (G13.8)
	conversation = {
		eventSeconds = 180, -- PROVISIONAL
	},

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

	strike = { -- PROVISIONAL (FL-0079, FL-0082)
		loyaltyBelow = 30,
		obedienceBelow = 30,
		shareOfOccupation = 0.5,
		memoryTags = {
			"exploited",
			"pay_refused",
			"paid_half",
			"harvest_promise_broken",
			"forge_half_broken",
			"feast_broken",
		},
		sustainSeconds = 60,
		endLoyaltyAbove = 40,
	},

	consequences = { -- PROVISIONAL (FL-0082; living-kingdom §5)
		tick = 1,
		shortage = {
			fedBelow = 0.5,
			sustainSeconds = 60,
			endFedAbove = 0.6,
			every = 10,
			conditions = { happiness = -2, stability = -1 },
			unrestPressure = 5,
			grumbleShare = 0.3,
		},
		riot = {
			stabilityBelow = 20,
			sustainSeconds = 120,
			endStabilityAbove = 30,
			instigatorLoyaltyBelow = 25,
			rioterLoyaltyBelow = 35,
			rioterShare = 0.2,
			fireDamagePerSecond = 4,
			fireFloor = 0.25,
			maxSeconds = 90,
			cooldownSeconds = 180,
		},
		rebellion = {
			enabled = false, -- gated off in the VS-1 slice (VS-2/3)
			stabilityBelow = 10,
			sustainSeconds = 180,
			disloyalShareAtLeast = 0.3,
			disloyalBelow = 30,
			obedienceBelow = 30,
			cooldownSeconds = 600,
		},
		morale = { retreatBelow = 30, surrenderBelow = 15 },
	},
}
