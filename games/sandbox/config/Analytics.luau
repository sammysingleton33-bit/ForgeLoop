--!strict
--[[
	Sandbox analytics config — owner FORGE-04. Genre-agnostic round game used by the integration
	place (games/sandbox). Same schema as games/game-001/config/Analytics.luau; documented in
	analytics/schemas/events.md ("Sandbox").
]]

return table.freeze({
	events = {
		SessionStart = {
			description = "Profile loaded (PlayerReady). Value: UTC days since first join.",
			value = "daysSinceFirstJoin",
			fields = { "visit" },
		},
		SessionEnd = {
			description = "Player left. Value: session seconds; lastActivity = last tracked event.",
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
			description = "A tutorial step took longer than its nudge time. Value: step number.",
			value = "step",
			fields = { "stepName" },
		},
		OnboardingStepPassed = {
			description = "A tutorial step the player was moved past (unavailable or timed out). Value: step number.",
			value = "step",
			fields = { "stepName", "via" },
		},
		RoundFinished = {
			description = "Round results for a participant. Value: seconds survived.",
			value = "survivedSec",
			fields = { "won", "placement" },
		},
		SettingChanged = {
			description = "Player changed a setting.",
			fields = { "key", "value" },
		},
		CelebrationShown = {
			description = "A celebration moment played.",
			fields = { "kind" },
		},
	},
	funnels = {
		Onboarding = { description = "Sandbox tutorial.", kind = "onboarding" },
		FirstRound = {
			description = "Ready to first finished round.",
			kind = "once",
			steps = { "Ready", "RoundStarted", "RoundFinished" },
		},
		FirstReward = {
			description = "First currency and first item.",
			kind = "once",
			steps = { "FirstCurrency", "FirstItem" },
		},
		Shop = {
			description = "One session per shop open.",
			kind = "recurring",
			steps = { "Opened", "Purchased" },
			sessionTtlSec = 900,
		},
		Return = {
			description = "Day-2 return.",
			kind = "once",
			steps = { "FirstSession", "ReturnNextDay" },
		},
	},
	track = {
		{ on = "PlayerReady", funnel = "FirstRound", step = 1 },
		{ on = "RoundStateChanged", match = { state = "Active" }, funnel = "FirstRound", step = 2 },
		{ on = "RoundEnded", funnel = "FirstRound", step = 3 },
		{ on = "CurrencyChanged", match = { gained = true }, funnel = "FirstReward", step = 1 },
		{ on = "ItemGranted", funnel = "FirstReward", step = 2 },
		{ on = "ShopViewed", funnel = "Shop", step = 1, session = "start", key = "shop" },
		{ on = "PurchaseCompleted", funnel = "Shop", step = 2, session = "continue", key = "shop" },
		{ on = "RoundEnded", event = "RoundFinished", fields = { "survivedSec", "won", "placement" } },
	},
	session = { startEvent = "SessionStart", endEvent = "SessionEnd", returnFunnel = "Return" },
	limits = { perPlayerPerMinute = 30, safety = 0.8, customReserve = 0.25 },
})
