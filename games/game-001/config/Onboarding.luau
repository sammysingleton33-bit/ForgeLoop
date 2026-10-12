--!strict
--[[
	AI Kingdoms (game-001) VS-1 onboarding — owner FORGE-04. Engine: the framework OnboardingService
	(roblox/src/server/Services/OnboardingService.luau, FL-0025); this file is FL-0062's step list.
	BRIEF §4 "First two minutes guided": gather -> build -> recruit -> capture.

	- Starts on G9 `KingdomJoined` (D-027), not PlayerReady.
	- Every step after the first waits for a G9 event, attributed by Feedback/Signals (CONTRACTS G9):
	  the ruler's own gather, the build the player placed (placedBy), any completion and the capture
	  for every member of the kingdom. A step done early (a co-ruler finished the building first)
	  completes the moment it comes up.
	- Hints are one line and point at world objects by WorldService's tags (G10: ResourceNode,
	  BuildZone, ObjectiveZone; the nearest one is marked) or at HUD controls by their OnboardingTarget
	  attribute (FORGE-03's BuildMenu and ArmyPanel; handoff).
	- Session-only progress when DataService is absent (D-027). No rewards: VS-1 has no meta currency;
	  the first reward is the first gather itself (+N on the treasury).
	Timing (expectSec, typical new player) against PACING.md targets: first gather ~25 s (target <= 45),
	build placed ~70 s (<= 90), complete ~130 s (<= 150), recruit ~300 s (<= 330), capture ~420 s (<= 450).
]]

local Signals = require("@game/ReplicatedStorage/Game/Feedback/Signals")

return table.freeze({
	subjects = Signals.subjects,
	clientActions = { "GoalAcknowledged" },
	limits = { firstInteractionSec = 30 },
	-- After the tutorial: shown by OnboardingController:showIdleHint(phase) when FL-0062 detects dead
	-- air (PACING.md §6). Keyed by MatchPhase (CONTRACTS G2); text only names VS-1 actions.
	idleHints = {
		Founding = "Gather from a tree or rock, or place a House or Farm.",
		Expansion = "Upgrade your keep from the kingdom panel.",
		Conflict = "Recruit soldiers at the Barracks and send them to a tower.",
		Endgame = "Hold your towers: every capture counts.",
	},
	flows = {
		{
			id = "vs1",
			version = 1,
			funnel = true,
			startOn = "KingdomJoined",
			steps = {
				{
					id = "Spawn",
					trigger = { auto = true },
					hint = { title = "Welcome, ruler. Your citizens are already at work." },
					expectSec = 2,
				},
				{
					id = "Gather",
					trigger = { bus = "ResourceGathered", match = { source = "ruler" } },
					hint = {
						title = "Gather from a tree or rock",
						body = "Walk up and tap or click it. Every bit fills the treasury.",
						target = { kind = "world", tag = "ResourceNode" },
					},
					expectSec = 23,
					interactive = true,
					nudgeAfterSec = 20,
				},
				{
					id = "PlaceBuilding",
					trigger = { bus = "BuildingPlaced", match = { placedBy = true } },
					hint = {
						title = "Build a House or a Farm",
						body = "Open Build, choose one, place it on open ground.",
						target = { kind = "ui", name = "HUD.BuildButton" },
					},
					expectSec = 45,
					interactive = true,
					nudgeAfterSec = 30,
				},
				{
					id = "BuildingComplete",
					trigger = { bus = "BuildingCompleted" },
					hint = {
						title = "Your builders are on their way",
						body = "Watch it rise. Gather more wood while you wait.",
						target = { kind = "world", tag = "BuildZone" },
					},
					expectSec = 60,
				},
				{
					id = "Recruit",
					trigger = { bus = "UnitsRecruited" },
					hint = {
						title = "Build a Barracks, then recruit 3 soldiers",
						body = "Soldiers cost food and wood from the treasury.",
						target = { kind = "ui", name = "HUD.Recruit" },
					},
					expectSec = 170,
					interactive = true,
					nudgeAfterSec = 60,
				},
				{
					id = "Capture",
					trigger = { bus = "ObjectiveCaptured" },
					hint = {
						title = "Send your soldiers to the watchtower",
						body = "Press Send to capture and hold the ring until the bar fills.",
						target = { kind = "world", tag = "ObjectiveZone" },
					},
					expectSec = 120,
					interactive = true,
					nudgeAfterSec = 45,
				},
			},
		},
	},
})
