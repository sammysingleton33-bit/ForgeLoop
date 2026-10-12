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
	- match: the full 30-45 minute match of BRIEF §3 (Founding 0-8, Expansion 8-20, Conflict 20-35,
	  Endgame 35-45 min). Victory may end Endgame early; victory rules are the user's (§16.4).
	targets: when a typical new player should reach each VS-1 milestone (seconds after spawn). They
	are tuning goals for playtests and analytics (FL-0063), not rules the game enforces.
]]

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
	}),
	targets = table.freeze({
		firstGatherSec = 45,
		firstBuildPlacedSec = 90,
		firstBuildingCompleteSec = 150,
		firstRecruitSec = 330,
		firstCaptureSec = 450,
	}),
	limits = table.freeze({ matchMinMinutes = 30, matchMaxMinutes = 45 }),
})
