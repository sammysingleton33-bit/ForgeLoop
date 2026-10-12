--!strict
--[[
	AI Kingdoms (game-001) analytics config — owner FORGE-04 (docs/workflows/team.md, Rules).
	Read by roblox/src/server/Services/AnalyticsService.luau; documented row by row in
	analytics/schemas/events.md (names, Roblox method, CustomField01-03 mapping, emitter, budget).

	Custom fields are listed in CustomField01, 02, 03 order. Values are sent as strings and must stay
	low-cardinality (types, outcomes, phases — never ids or names): Roblox groups combinations past
	8,000 as "Other". Kingdom bus events (BuildingCompleted, ...) are PROPOSED (Experience/KingdomSignals):
	their rules stay inert until FORGE-01 declares them in Contracts/GameEvents.
]]

local actor = { role = "actor" }

return table.freeze({
	events = {
		SessionStart = {
			description = "Profile loaded (PlayerReady). Value: UTC days since first join.",
			value = "daysSinceFirstJoin",
			fields = { "visit" },
		},
		SessionEnd = {
			description = "Player left. Value: session seconds; lastActivity = last tracked event (drop-off point).",
			value = "sessionSec",
			fields = { "lastActivity" },
		},
		OnboardingCompleted = {
			description = "Last onboarding step done. Value: seconds from first step.",
			value = "durationSec",
			fields = { "flow" },
		},
		OnboardingSkipped = {
			description = "Player skipped the tutorial. Value: last completed step number.",
			value = "lastStep",
			fields = { "lastStepName", "flow" },
		},
		OnboardingHintEscalated = {
			description = "A tutorial step took longer than its nudge time (stuck point). Value: step number.",
			value = "step",
			fields = { "stepName" },
		},
		MatchEnded = {
			description = "Match results for a participant still in the server. Value: match seconds.",
			value = "durationSec",
			fields = { "won", "placement", "mode" },
		},
		PhaseReached = {
			description = "Match pacing stage reached (Experience/Pacing). Value: match minute.",
			value = "minute",
			fields = { "phase" },
		},
		IdleNudge = {
			description = "No meaningful action for the idle threshold; a contextual hint was shown. Value: idle seconds.",
			value = "idleSec",
			fields = { "phase" },
		},
		BuildingCompleted = {
			description = "Own building finished. Value: building level.",
			value = "level",
			fields = { "buildingType" },
		},
		KingdomUpgraded = {
			description = "Kingdom tier raised. Value: new tier.",
			value = "tier",
		},
		UnitsRecruited = {
			description = "Units recruited. Value: unit count.",
			value = "count",
			fields = { "unitType" },
		},
		BattleEnded = {
			description = "Battle finished, logged for attacker and defender.",
			fields = { "role", "won" },
		},
		SiegeEnded = {
			description = "Siege finished, logged for attacker and defender.",
			fields = { "role", "outcome" },
		},
		TerritoryChanged = {
			description = "Region changed hands: actor gained it, loser lost it.",
			fields = { "role" },
		},
		KingdomEventStarted = {
			description = "Major kingdom event (festival, plague, raid, ...). Value: severity 1-3.",
			value = "severity",
			fields = { "eventId" },
		},
		RewardClaimed = {
			description = "Player claimed an earned reward. Value: amount.",
			value = "amount",
			fields = { "source", "rewardKind" },
		},
		DailyRewardClaimed = {
			description = "Daily reward claimed. Value: streak day.",
			value = "streakDay",
			fields = { "graceUsed" },
		},
		QuestCompleted = {
			description = "Quest completed. Value: quest tier.",
			value = "tier",
			fields = { "questId" },
		},
		AchievementUnlocked = {
			description = "Achievement unlocked.",
			fields = { "achievementId" },
		},
		CelebrationShown = {
			description = "A celebration moment played (NotificationController:celebrate).",
			fields = { "kind" },
		},
		SettingChanged = {
			description = "Player changed a setting.",
			fields = { "key", "value" },
		},
	},
	funnels = {
		Onboarding = {
			description = "First-session tutorial (games/game-001/config/Onboarding.luau steps).",
			kind = "onboarding",
		},
		FirstMatch = {
			description = "New-player conversion through the first match.",
			kind = "once",
			steps = {
				"MatchJoined",
				"FirstConstruction",
				"FirstBuilding",
				"FirstUpgrade",
				"FirstArmy",
				"FirstCombat",
				"MatchFinished",
			},
		},
		MatchProgress = {
			description = "Every match, one session per matchId: where players drop out of a match.",
			kind = "recurring",
			steps = { "Joined", "FirstBuilding", "FirstUpgrade", "FirstArmy", "FirstCombat", "Finished" },
			sessionTtlSec = 3600,
		},
		FirstReward = {
			description = "Time to first earned reward: harvest, currency, item.",
			kind = "once",
			steps = { "FirstHarvest", "FirstCurrency", "FirstItem" },
		},
		Shop = {
			description = "One session per shop open (ShopViewed) to purchase.",
			kind = "recurring",
			steps = { "Opened", "Purchased" },
			sessionTtlSec = 900,
		},
		Return = {
			description = "Day-2 return: first session on day 0, back on the next UTC day.",
			kind = "once",
			steps = { "FirstSession", "ReturnNextDay" },
		},
	},
	track = {
		-- FirstMatch (once per player)
		{ on = "RoundStateChanged", match = { state = "Active" }, funnel = "FirstMatch", step = 1 },
		{ on = "ConstructionStarted", match = actor, funnel = "FirstMatch", step = 2 },
		{ on = "BuildingCompleted", match = actor, funnel = "FirstMatch", step = 3 },
		{ on = "BuildingUpgraded", match = actor, funnel = "FirstMatch", step = 4 },
		{ on = "UnitsRecruited", match = actor, funnel = "FirstMatch", step = 5 },
		{ on = "BattleStarted", funnel = "FirstMatch", step = 6 },
		{ on = "SiegeStarted", funnel = "FirstMatch", step = 6 },
		{ on = "RoundEnded", funnel = "FirstMatch", step = 7 },
		-- MatchProgress (every match)
		{
			on = "RoundStateChanged",
			match = { state = "Active" },
			funnel = "MatchProgress",
			step = 1,
			session = "match",
		},
		{ on = "BuildingCompleted", match = actor, funnel = "MatchProgress", step = 2, session = "match" },
		{ on = "BuildingUpgraded", match = actor, funnel = "MatchProgress", step = 3, session = "match" },
		{ on = "UnitsRecruited", match = actor, funnel = "MatchProgress", step = 4, session = "match" },
		{ on = "BattleStarted", funnel = "MatchProgress", step = 5, session = "match" },
		{ on = "SiegeStarted", funnel = "MatchProgress", step = 5, session = "match" },
		{ on = "RoundEnded", funnel = "MatchProgress", step = 6, session = "match" },
		-- FirstReward
		{ on = "ResourceProduced", match = actor, funnel = "FirstReward", step = 1 },
		{ on = "CurrencyChanged", match = { gained = true }, funnel = "FirstReward", step = 2 },
		{ on = "ItemGranted", funnel = "FirstReward", step = 3 },
		-- Shop (sessionId per shop open, FORGE-03 ShopViewed)
		{ on = "ShopViewed", funnel = "Shop", step = 1, session = "start", key = "shop" },
		{ on = "PurchaseCompleted", funnel = "Shop", step = 2, session = "continue", key = "shop" },
		-- Custom events from the bus
		{ on = "RoundEnded", event = "MatchEnded", fields = { "durationSec", "won", "placement", "mode" } },
		{ on = "BuildingCompleted", match = actor, event = "BuildingCompleted", fields = { "level", "buildingType" } },
		{ on = "KingdomUpgraded", match = actor, event = "KingdomUpgraded", fields = { "tier" } },
		{ on = "UnitsRecruited", match = actor, event = "UnitsRecruited", fields = { "count", "unitType" } },
		{ on = "BattleEnded", event = "BattleEnded", fields = { "role", "won" } },
		{ on = "SiegeEnded", event = "SiegeEnded", fields = { "role", "outcome" } },
		{ on = "TerritoryChanged", event = "TerritoryChanged", fields = { "role" } },
		{
			on = "KingdomEventStarted",
			match = actor,
			event = "KingdomEventStarted",
			fields = { "severity", "eventId" },
		},
	},
	session = { startEvent = "SessionStart", endEvent = "SessionEnd", returnFunnel = "Return" },
	limits = { perPlayerPerMinute = 30, safety = 0.8, customReserve = 0.25 },
})
