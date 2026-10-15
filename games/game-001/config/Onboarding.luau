--!strict
--[[
	AI Kingdoms (game-001) VS-1 onboarding v2 — owner FORGE-04 (FL-0092; D-030). Engine: the framework
	OnboardingService (roblox/src/server/Services/OnboardingService.luau, FL-0025).
	BRIEF §4 "First minutes guided": inspect a citizen -> build on a plot -> answer a citizen ->
	recruit -> capture. The player rules from the throne in the aerial view (G13.6); gathering by
	the ruler is optional in VS-1, so it is no longer a step.

	- Starts on G9 `KingdomJoined` (D-027), not PlayerReady.
	- Server-verified steps wait for G9 events, attributed by Feedback/Signals (CONTRACTS G9): the
	  build the player placed (placedBy), recruits, and the capture for every member of the kingdom.
	  A step done early (a co-ruler captured first) completes the moment it comes up.
	- Client-reported steps (clientActions) complete only the current step and grant nothing; G11
	  (D-044 (4)) allows them only for UI moments with no server event:
	    CitizenInspected  InputModeController reports it when a citizen is selected (G13.6, FL-0090)
	- AnswerCitizen follows the server: G9 CitizenAnswered (ConversationService, FL-0107), credited to
	  the answering ruler by Feedback/Signals (FL-0108). A client can no longer report it.
	- Hints are one line and point at WorldService's tags (BuildSlot, G13.5; ObjectiveZone, G10;
	  the nearest one is marked) or at HUD controls by their OnboardingTarget attribute (FORGE-03).
	  Requests are marked by the citizens' own "!" bubbles (FL-0091), so that step needs no arrow.
	- A step whose system is not on this server yet is passed over (`requires`, via "unavailable"):
	  AnswerCitizen needs ConversationService (FL-0079), Recruit MilitaryService and Capture
	  ObjectiveService (FL-0052). So the tutorial never waits for a system that is not there; the
	  funnel still counts the step (Roblox counts skipped steps as done) and OnboardingStepPassed
	  records that the player was moved past it.
	- Recruit's nudge waits out the planned Barracks and stockpile wait (nudgeAfterSec >= expectSec),
	  so OnboardingHintEscalated there means stuck, not "still saving up" (FORGE-00 PACING review M5).
	- Session-only progress when DataService is absent (D-027). No rewards: VS-1 has no meta currency.
	Timing (expectSec, typical new player): first interaction ~20 s (<= 30), first build placed ~70 s
	(<= 90), first answer ~160 s, recruit ~310 s (<= 330), capture ~430 s (<= 450; PACING.md targets).
]]

local Signals = require("@game/ReplicatedStorage/Game/Feedback/Signals")

return table.freeze({
	subjects = Signals.subjects,
	clientActions = { "GoalAcknowledged", "CitizenInspected" },
	limits = { firstInteractionSec = 30 },
	-- After the tutorial: shown by OnboardingController:showIdleHint(phase) when FL-0062 detects dead
	-- air (PACING.md §6). Keyed by MatchPhase (CONTRACTS G2); text only names VS-1 actions.
	idleHints = {
		Founding = "Tap a citizen with a request, or build on a free plot.",
		Expansion = "Upgrade your keep from the kingdom panel.",
		Conflict = "Recruit soldiers at the Barracks and send them to a tower.",
		Endgame = "Hold your towers: every capture counts.",
	},
	flows = {
		{
			id = "vs1",
			version = 2,
			funnel = true,
			startOn = "KingdomJoined",
			steps = {
				{
					id = "Spawn",
					trigger = { auto = true },
					hint = {
						title = "Welcome, ruler. Your kingdom awaits.",
						body = "Pan with WASD or drag, zoom with the wheel or a pinch.",
					},
					expectSec = 2,
				},
				{
					id = "InspectCitizen",
					trigger = { client = "CitizenInspected" },
					hint = {
						title = "Tap a citizen to see what they think",
						body = "Their card shows their job, mood and loyalty.",
					},
					expectSec = 18,
					interactive = true,
					nudgeAfterSec = 20,
				},
				{
					id = "BuildOnPlot",
					trigger = { bus = "BuildingPlaced", match = { placedBy = true } },
					hint = {
						title = "Build on a free plot",
						body = "Tap a plot marker, choose a House or a Farm, then confirm.",
						target = { kind = "world", tag = "BuildSlot" }, -- Build.PlaceSlot is served (FL-0081)
					},
					expectSec = 50,
					interactive = true,
					nudgeAfterSec = 30,
				},
				{
					id = "AnswerCitizen",
					trigger = { bus = "CitizenAnswered" }, -- G9, the answering ruler (FL-0108)
					-- conversations are FORGE-01's ConversationService (FL-0079): without it the step is
					-- passed over; with it, the tutorial still moves on after autoAdvanceSec (no stall)
					requires = "ConversationService",
					autoAdvanceSec = 120,
					hint = {
						title = 'A citizen with "!" has a request',
						body = "Tap them and choose an answer. Every choice changes your kingdom.",
					},
					expectSec = 90,
					interactive = true,
					nudgeAfterSec = 45,
				},
				{
					id = "Recruit",
					trigger = { bus = "UnitsRecruited" },
					hint = {
						title = "Build a Barracks, then recruit 3 soldiers",
						body = "Soldiers cost food and wood from the treasury.",
						target = { kind = "ui", name = "HUD.ArmyButton" }, -- the Army rail button (FL-0060)
					},
					requires = "MilitaryService",
					expectSec = 150,
					interactive = true,
					nudgeAfterSec = 180,
				},
				{
					id = "Capture",
					trigger = { bus = "ObjectiveCaptured" },
					hint = {
						title = "Send your soldiers to the watchtower",
						body = "Press Send to capture and hold the ring until the bar fills.",
						target = { kind = "world", tag = "ObjectiveZone" },
					},
					requires = "ObjectiveService",
					expectSec = 120,
					interactive = true,
					nudgeAfterSec = 45,
				},
			},
		},
	},
})
