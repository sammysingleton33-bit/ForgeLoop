--!strict
--[[
	AI Kingdoms (game-001) analytics config — owner FORGE-04 (docs/workflows/team.md, game-001).
	Read by the framework AnalyticsService (roblox/src/server/Services/AnalyticsService.luau);
	every row is documented in analytics/schemas/events.md (Roblox method, CustomField01-03,
	emitter, budget).

	Custom fields are listed in CustomField01, 02, 03 order. Values are sent as strings and stay
	low-cardinality (types, outcomes, phases; never ids or names).
	FL-0063:
	- the VS-1 funnel (`VS1`, BRIEF §13) runs from the G9 events through the track rules below, with the
	  CONTRACTS G9 attribution rules in Feedback/Signals (`subjects`);
	- sessions start on KingdomJoined (VS-1 has no profiles, so nothing fires PlayerReady, D-027);
	- MatchAnalyticsService logs MatchEnded and answers `session.leftInfo` for PhaseLeft;
	- ConversationAnswered and ReputationShifted (D-030) are declared for FORGE-01's ConversationService
	  and ReputationService, which call AnalyticsService:event (interfaces §8) once they ship.
]]

local Signals = require("@game/ReplicatedStorage/Game/Feedback/Signals")

-- PhaseLeft's fields at session end (AnalyticsService calls this before SessionEnd).
local function leftInfo(player: any, ctx: any): { [string]: any }?
	local registry = ctx and ctx.registry
	local service = registry and registry:find("MatchAnalyticsService")
	return if service then service:leftInfo(player) else nil
end

return table.freeze({
	events = {
		SessionStart = {
			description = "Joined the server (session.startOn: KingdomJoined in game-001). Value: UTC days since first join.",
			value = "daysSinceFirstJoin",
			fields = { "visit" },
		},
		SessionEnd = {
			description = "Left. Value: session seconds; lastActivity = the last bus event logged for the player (drop-off point).",
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
		MatchEnded = {
			description = "Match or slice ended (G9 MatchEnded), per ruler still here. Value: match seconds. won = true / false / draw (no single winner); phase = the last playing phase (where it was decided).",
			value = "durationSec",
			fields = { "won", "phase", "mode" },
		},
		PhaseLeft = {
			description = "A ruler left during a playing phase (disconnect point). Value: minute into the match.",
			value = "minute",
			fields = { "phase" },
		},
		ConversationAnswered = {
			description = "A ruler answered a citizen's request (Kingdom.Choose ok). Value: seconds the request was open.",
			value = "secondsOpen",
			fields = { "occupation", "phase", "decision" },
		},
		ReputationShifted = {
			description = "A reputation category moved for a ruler. Value: the change, rounded (negative = down).",
			value = "delta",
			fields = { "category", "source", "phase" },
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
			inOrder = true, -- FORGE-00's #64 ruling: kingdom-wide credit never skips a player ahead
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
	-- VS1 funnel from the G9 events (who is credited: Feedback/Signals, CONTRACTS G9)
	track = {
		{ on = "KingdomJoined", funnel = "VS1", step = 1 },
		{ on = "ResourceGathered", funnel = "VS1", step = 2 },
		{ on = "BuildingPlaced", funnel = "VS1", step = 3, match = { placedBy = true } },
		{ on = "BuildingCompleted", funnel = "VS1", step = 4 },
		{ on = "UnitsRecruited", funnel = "VS1", step = 5 },
		{ on = "ObjectiveCaptured", funnel = "VS1", step = 6 },
	},
	subjects = Signals.subjects,
	session = {
		startEvent = "SessionStart",
		endEvent = "SessionEnd",
		returnFunnel = "Return",
		startOn = "KingdomJoined",
		leftEvent = "PhaseLeft",
		leftInfo = leftInfo,
	},
	limits = { perPlayerPerMinute = 30, safety = 0.8, customReserve = 0.25 },
})
