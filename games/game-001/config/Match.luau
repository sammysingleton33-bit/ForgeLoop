--!strict
--[[
	Match (ReplicatedStorage.Forge.Config.Match) — match pacing and victory. Owner: FORGE-01.

	phaseDurations are the default until FORGE-04's Pacing.phaseDurations() exists (G11); MatchService
	prefers Pacing when present. Crown Points per action (G3 addCrownPoints) and the simulation tick.

	PROVISIONAL — user decision pending (BRIEF §16.4): victory = last keep standing ends the match early,
	otherwise most Crown Points at the end of Endgame, equal points share the win.
	PROVISIONAL — user decision pending (BRIEF §16.2): PvP between kingdoms. Off by default (the VS-1
	minimum). When enabled: war declarations from Conflict on, peace by mutual consent, no betrayal.
]]

return {
	phaseDurations = { Founding = 480, Expansion = 720, Conflict = 900, Endgame = 600 },
	countdownSec = 10,
	resultsSec = 20,
	minPlayers = 1,
	tickSeconds = 0.25,
	victory = { conquest = true, crownPointsAtEnd = true }, -- PROVISIONAL (BRIEF §16.4)
	pvp = { enabled = false, peaceCooldown = 120, proposalSeconds = 60 }, -- PROVISIONAL (BRIEF §16.2)
	crown = { buildingLevel = 5, conquest = 300, unitKill = 2 },
}
