--!strict
--[[
	AI Kingdoms (game-001) analytics config — owner FORGE-04 (docs/workflows/team.md, game-001).
	Read by the framework AnalyticsService (roblox/src/server/Services/AnalyticsService.luau);
	every row is documented in analytics/schemas/events.md (Roblox method, CustomField01-03,
	emitter, budget).

	Custom fields are listed in CustomField01, 02, 03 order. Values are sent as strings and stay
	low-cardinality (types, outcomes, phases; never ids or names).
	FL-0063:
	- the VS-1 funnel (`FirstMatch`, BRIEF §13) runs from the G9 events through the track rules below, with the
	  CONTRACTS G9 attribution rules in Feedback/Signals (`subjects`);
	- sessions start on KingdomJoined (VS-1 has no profiles, so nothing fires PlayerReady, D-027);
	- MatchAnalyticsService logs MatchEnded and answers `session.leftInfo` for PhaseLeft;
	- each FirstMatch step after Spawn also logs MilestoneReached (seconds since the session started, `milestones`);
	- ConversationAnswered (D-030) is logged from G9 CitizenAnswered by a track rule (D-044 (3), FL-0108):
	  ConversationService never calls AnalyticsService; the occupation comes from Feedback/Signals;
	- ReputationShifted (D-030) is declared for FORGE-01's ReputationService, which calls
	  AnalyticsService:event (interfaces §8).
]]

local Signals = require("@game/ReplicatedStorage/Game/Feedback/Signals")

-- MilestoneReached's extra field: the match mode (G3 MatchService.mode; "unknown" without it).
local function milestoneInfo(_player: any, ctx: any): { [string]: any }?
	local registry = ctx and ctx.registry
	local match = registry and registry:find("MatchService")
	local mode = match and match.mode
	return { mode = if type(mode) == "string" then mode else "unknown" }
end

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
		OnboardingStepPassed = {
			description = "A tutorial step the player was moved past, not did: its service is missing (unavailable) or it timed out. Value: step number. The funnel still counts it (Roblox counts skipped steps as done).",
			value = "step",
			fields = { "stepName", "via" },
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
			fields = { "occupation", "decision" }, -- no phase: keeps the combinations bounded (events.md §3)
		},
		ReputationShifted = {
			description = "A reputation category moved for a ruler. Value: the change, rounded (negative = down).",
			value = "delta",
			fields = { "category", "source", "phase" },
		},
		MilestoneReached = {
			description = "A FirstMatch step after Spawn was reached (FORGE-00 review M7). Value: whole seconds since the session started (KingdomJoined); compare its median per milestone with config/Pacing.luau.",
			value = "sinceStartSec",
			fields = { "milestone", "mode" }, -- 5 steps x 4 modes = 20 combinations
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
		FirstMatch = {
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
	-- the FirstMatch funnel and ConversationAnswered from the G9 events (who is credited: Feedback/Signals, CONTRACTS G9)
	track = {
		{ on = "KingdomJoined", funnel = "FirstMatch", step = 1 },
		{ on = "ResourceGathered", funnel = "FirstMatch", step = 2 },
		{ on = "BuildingPlaced", funnel = "FirstMatch", step = 3, match = { placedBy = true } },
		{ on = "BuildingCompleted", funnel = "FirstMatch", step = 4 },
		{ on = "UnitsRecruited", funnel = "FirstMatch", step = 5 },
		{ on = "ObjectiveCaptured", funnel = "FirstMatch", step = 6 },
		-- D-030 custom event from the G9 event (D-044 (3), FL-0108); secondsOpen is its value
		{
			on = "CitizenAnswered",
			event = "ConversationAnswered",
			fields = { "secondsOpen", "occupation", "decision" },
		},
	},
	subjects = Signals.subjects,
	-- timed FirstMatch milestones (FORGE-00 review M7): funnel steps carry no time
	milestones = { funnel = "FirstMatch", event = "MilestoneReached", info = milestoneInfo },
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
