--!strict
--[[
	Match pacing for AI Kingdoms (ReplicatedStorage.Forge.Config.Pacing). Owner FORGE-04 (team.md,
	game-001). Read by PacingService (CONTRACTS G11); MatchService pulls the phase lengths from
	PacingService:phaseDurations(mode). Design and minute-by-minute targets:
	games/game-001/design/pacing/PACING.md.

	modes[mode][phase] = seconds; math.huge = untimed (the phase ends on an event, not a timer).
	- slice: the interim VS-1 rules (CONTRACTS G3, pending the user's BRIEF §16.3/§16.4): Lobby 0 s,
	  Founding starts on the first join and is untimed, the first ObjectiveCaptured ends the slice
	  (MatchService moves to Results). Later phases are not reached in the slice; Results stays up.
	- match: the pre-D-029 split, held until FL-0096; see PACING.md §2 (Founding 0-8, Expansion 8-20,
	  Conflict 20-35, Endgame 35-45 min, no Arena: MatchPhase has none before VS-2). BRIEF §3 (D-029)
	  now times Conflict 20-32, Endgame 32-38 and the Crown Arena 38-44; the split is re-cut when
	  FL-0096 is decided or G12 freezes, whichever comes first.
	- match30: an evaluation profile, NOT the default (D-030 (6), design/living-kingdom.md §6): the
	  user prefers about 25 minutes of kingdom play and a 5-minute final phase. Founding 5, Expansion 7,
	  Conflict 8, Endgame 5, Arena 4.5 min (+ Lobby 20 s, Results 30 s: about 30 min). Arena is the
	  VS-2 phase (CONTRACTS G12). MatchService cannot select match30 yet (Match.durationsFor knows slice
	  and match only); FORGE-01 adds it when the match-length decision is made.
	targets: when a typical new player should reach each VS-1 v2 milestone (seconds after spawn; D-030
	onboarding order, PACING.md §3), ascending. Tuning goals for playtests, not rules the game enforces;
	measured from env.log timestamps until an analytics milestone event exists (FORGE-00 review M7).
	firstDepositSec is a sim health check, not a ruler action: the first citizen deposit after Founding
	(ruler gathering is optional, D-030), so it is not part of the ordered list.
	idleSec: seconds without a meaningful action (PACING.md §6) before a contextual hint, per MatchPhase
	(no Arena entry until G12 freezes). For FL-0062's dead-air detector; nothing reads it yet.
	arena: the Crown Arena's stages (G12.1 ArenaStage; design crown-arena.md §2 and the §11 defaults),
	seconds each (DRAFT until G12 freezes). vote, loadout, intro and crowning are FORGE-01's config
	Arena (voteSeconds, loadoutSeconds, introSeconds, crowningSeconds), read here so the two cannot
	drift (FORGE-00 2026-10-19: one source). qualify = the qualifiers are announced; vote = co-rulers
	pick the champion; loadout = weapon, armour and perks; intro = the versus card and the camera over
	both stands; duel = the design's expected length (120): the safety ceiling is config Arena
	duelMaxSeconds (195), and the duel's own caps end it first; crowning = the ending. The live stages
	run on ArenaService's clock and clients follow ArenaState.endsAt, not these numbers. Read by
	FORGE-03's How to Play card (the arena's length) and the Crowd config spec.
]]

local Arena = require("./Arena") -- FORGE-01's config (FL-0071)

local UNTIMED = math.huge

return table.freeze({
	modes = table.freeze({
		slice = table.freeze({
			Lobby = 0,
			Founding = UNTIMED,
			Expansion = UNTIMED,
			Conflict = UNTIMED,
			Endgame = UNTIMED,
			Results = UNTIMED,
		}),
		match = table.freeze({
			Lobby = 20, -- pre-match countdown (CONTRACTS G3: the countdown runs in Lobby with endsAt)
			Founding = 8 * 60,
			Expansion = 12 * 60,
			Conflict = 15 * 60,
			Endgame = 10 * 60,
			Results = 30,
		}),
		match30 = table.freeze({
			Lobby = 20,
			Founding = 5 * 60,
			Expansion = 7 * 60,
			Conflict = 8 * 60,
			Endgame = 5 * 60,
			Arena = 4.5 * 60,
			Results = 30,
		}),
	}),
	targets = table.freeze({
		firstDepositSec = 45,
		firstInspectSec = 30,
		firstBuildPlacedSec = 90,
		firstBuildingCompleteSec = 150,
		firstAnswerSec = 180,
		firstRecruitSec = 330,
		firstCaptureSec = 450,
	}),
	idleSec = table.freeze({ Founding = 25, Expansion = 45, Conflict = 60, Endgame = 90 }),
	limits = table.freeze({ matchMinMinutes = 30, matchMaxMinutes = 45 }),
	arena = table.freeze({
		qualify = 5,
		vote = Arena.voteSeconds, -- one source: FORGE-01's config Arena (FL-0071)
		loadout = Arena.loadoutSeconds,
		intro = Arena.introSeconds,
		duel = 120, -- the expected duel; config Arena duelMaxSeconds is the safety ceiling
		crowning = Arena.crowningSeconds,
	}),
})
