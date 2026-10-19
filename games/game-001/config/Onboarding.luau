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
	- Full-match tips (FL-0137, D-053): one-step flows (`tip = true`) that start on a G9 event for the
	  rulers it is about (Feedback/Signals roles, `startMatch`): the Conflict phase opens, a rival declares
	  war on me, my keep is besieged, raiders enter my lands, my army reaches an enemy keep (the ram), and
	  Endgame starts (the Crown Arena line). Each shows once per player, ever (stored like any flow), hides
	  by itself after TIP_SEC or when its situation ends, has "Got it", and never blocks or gates play.
	  They are not the tutorial: no funnel, no reward, no completion event. Text names only what the
	  build does (war, peace, siege, raid, ram, Crown Points, the duel); no alliance wording (VS-3).
	Timing (expectSec, typical new player): first interaction ~20 s (<= 30), first build placed ~70 s
	(<= 90), first answer ~160 s, recruit ~310 s (<= 330), capture ~430 s (<= 450; PACING.md targets).
]]

local Signals = require("@game/ReplicatedStorage/Game/Feedback/Signals")

local TIP_SEC = 12 -- a tip hides by itself after this (Experience/Onboarding: at most TIP_MAX_SEC)

-- A one-step tip flow (FL-0137): shown once, when `startOn` fires with `startMatch`, for TIP_SEC or
-- until `endOn` (the situation is over or the player did the thing).
local function tip(
	id: string,
	stepId: string,
	start: { [string]: any },
	endOn: { [string]: any },
	hint: any,
	requires: string?
)
	return {
		id = id,
		version = 1,
		tip = true,
		startOn = start.event,
		startMatch = start.match,
		steps = {
			{
				id = stepId,
				trigger = { bus = endOn.event, match = endOn.match },
				hint = hint,
				requires = requires,
				expectSec = TIP_SEC,
				autoAdvanceSec = TIP_SEC,
			},
		},
	}
end

return table.freeze({
	subjects = Signals.subjects,
	clientActions = { "GoalAcknowledged", "CitizenInspected" },
	limits = { firstInteractionSec = 30 },
	-- After the tutorial: shown by OnboardingController:showIdleHint(phase) when FL-0062 detects dead
	-- air (PACING.md §6). Keyed by MatchPhase (CONTRACTS G2); text only names actions the build has
	-- (Conflict and Endgame follow the full match, D-053: war from Conflict on, the Crown Arena final).
	idleHints = {
		Founding = "Tap a citizen with a request, or build on a free plot.",
		Expansion = "Upgrade your keep from the kingdom panel.",
		Conflict = "Your kingdom can declare war from the Kingdom panel, or recruit soldiers.",
		Endgame = "Earn Crown Points: they decide who takes the crown.", -- true with or without the arena
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
						body = "Tap the marked plot, choose a House, then confirm.",
						-- the marked plot is the one nearest the ruler, a small one: a House fits, a Farm does not
						-- (OnboardingTargets.spec); any building still completes the step
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
		-- Full-match tips (FL-0137): see the header. Each ends early on the event in its second table.
		tip("tip_war_open", "WarOpen", {
			event = "MatchPhaseChanged",
			match = { phase = "Conflict" },
		}, { event = "WarChanged", match = { role = "declarer", atWar = true } }, {
			title = "Conflict: war is open",
			-- "your kingdom": only the senior ruler declares; a junior ruler's request asks them (D-054)
			body = "Your kingdom can now declare war or propose peace from the Kingdom panel.",
			target = { kind = "ui", name = "HUD.KingdomButton" }, -- FORGE-03's Kingdom menu button (#232)
		}),
		tip("tip_war_on_you", "WarOnYou", {
			event = "WarChanged",
			match = { role = "target", atWar = true },
		}, { event = "WarChanged", match = { atWar = false } }, {
			title = "A rival declared war on you",
			body = "Recruit soldiers to guard your keep, or propose peace from the Kingdom panel.",
			target = { kind = "ui", name = "HUD.KingdomButton" },
		}),
		tip("tip_siege", "DefendKeep", {
			event = "SiegeChanged",
			match = { role = "defender", on = true },
		}, { event = "SiegeChanged", match = { role = "defender", on = false } }, {
			title = "Your keep is under siege!",
			-- the marked rail button is FORGE-03's alert item (labelled Raid until it reads Siege for a siege)
			body = "Press G or tap the marked button to see it, then send soldiers to defend.",
			target = { kind = "ui", name = "HUD.RaidButton" },
		}),
		tip("tip_raid", "StopRaid", {
			event = "RaidChanged",
			match = { role = "defender", on = true },
		}, { event = "RaidChanged", match = { role = "defender", on = false } }, {
			title = "Raiders in your lands!",
			body = "Press G or tap the marked Raid button to see them, then send soldiers.",
			target = { kind = "ui", name = "HUD.RaidButton" },
		}),
		tip("tip_ram", "BringRam", {
			event = "SiegeChanged",
			match = { role = "attacker", on = true },
		}, { event = "UnitsRecruited" }, {
			title = "Your army is at their keep",
			body = "A ram breaks a keep far faster than soldiers. Train one at a level 2 Barracks.",
		}, "MilitaryService"),
		tip("tip_crown_arena", "CrownArena", {
			event = "MatchPhaseChanged",
			match = { phase = "Endgame" },
		}, { event = "MatchEnded" }, {
			title = "Endgame: the race for the crown",
			body = "When time runs out, the top 2 kingdoms by Crown Points duel in the Crown Arena.",
		}, "ArenaService"), -- FORGE-01's arena (FL-0071): until it is on the server the tip is passed over
	},
})
