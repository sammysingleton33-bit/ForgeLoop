--!strict
--[[
	AI Kingdoms (game-001) analytics config — owner FORGE-04 (docs/workflows/team.md, game-001).
	Read by the framework AnalyticsService (roblox/src/server/Services/AnalyticsService.luau);
	every row is documented in analytics/schemas/events.md (Roblox method, CustomField01-03,
	emitter, budget).

	Custom fields are listed in CustomField01, 02, 03 order. Values are sent as strings and stay
	low-cardinality (types, outcomes, phases; never ids or names).
	The VS-1 funnel (`VS1`) is declared here; its steps are logged from the G9 events with the G9
	attribution rules in FL-0063 (track rules + `subjects` resolvers from the game tree). Until then
	only the session events and the onboarding funnel (OnboardingService) are logged.
]]

return table.freeze({
	events = {
		SessionStart = {
			description = "Joined the server (PlayerReady). Value: UTC days since first join.",
			value = "daysSinceFirstJoin",
			fields = { "visit" },
		},
		SessionEnd = {
			description = "Left. Value: session seconds; lastActivity = last tracked event (drop-off point).",
			value = "sessionSec",
			fields = { "lastActivity" },
		},
		OnboardingCompleted = {
			description = "Last onboarding step done. Value: seconds from the first step.",
			value = "durationSec",
			fields = { "flow" },
		},
		OnboardingSkipped = {
			description = "Skipped the tutorial. Value: last completed step number.",
			value = "lastStep",
			fields = { "lastStepName", "flow" },
		},
		OnboardingHintEscalated = {
			description = "A tutorial step took longer than its nudge time (stuck point). Value: step number.",
			value = "step",
			fields = { "stepName" },
		},
		OnboardingStepPassed = {
			description = "A tutorial step the player was moved past, not did: its service is missing (unavailable) or it timed out. Value: step number. The funnel still counts it (Roblox counts skipped steps as done).",
			value = "step",
			fields = { "stepName", "via" },
		},
		MatchEnded = {
			description = "Match or slice ended (G9 MatchEnded), per member still here. Value: match seconds.",
			value = "durationSec",
			fields = { "won", "phase", "mode" },
		},
		PhaseLeft = {
			description = "Player left during a match phase (disconnect point). Value: minute into the match.",
			value = "minute",
			fields = { "phase" },
		},
		IdleHintShown = {
			description = "No meaningful action for the phase's idle threshold; a hint was shown. Value: idle seconds.",
			value = "idleSec",
			fields = { "phase" },
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
			description = "VS-1 guided first minutes (games/game-001/config/Onboarding.luau steps).",
			kind = "onboarding",
		},
		VS1 = {
			description = "BRIEF §13: spawn -> first gather -> first build placed -> first building complete -> first recruit -> first capture.",
			kind = "once",
			steps = {
				"Spawn",
				"FirstGather",
				"FirstBuildPlaced",
				"FirstBuildingComplete",
				"FirstRecruit",
				"FirstCapture",
			},
		},
		Return = {
			description = "Day-2 return: first session on day 0, back on the next UTC day.",
			kind = "once",
			steps = { "FirstSession", "ReturnNextDay" },
		},
	},
	track = {},
	session = { startEvent = "SessionStart", endEvent = "SessionEnd", returnFunnel = "Return" },
	limits = { perPlayerPerMinute = 30, safety = 0.8, customReserve = 0.25 },
})
