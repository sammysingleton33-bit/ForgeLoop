--!strict
--[[
	Match (ReplicatedStorage.Forge.Config.Match) — match mode, pacing fallback and victory. Owner: FORGE-01.

	mode: "slice" | "match" (CONTRACTS G3/G11). PROVISIONAL — the VS-1 slice rules are interim, pending the
	user's BRIEF §16.3/§16.4: Lobby 0 s, Founding starts on the first join and is untimed, the first
	ObjectiveCaptured ends the slice (MatchEnded { winner } → Results), starting citizens appear when a
	kingdom's first ruler joins and AI kingdoms stay idle. "match" is the full 30-45 minute match.
	durations: built-in phase lengths per mode (seconds; math.huge = untimed), used only when FORGE-04's
	PacingService is absent; MatchService prefers PacingService:phaseDurations(mode). Same values as config
	Pacing so the game behaves the same either way.

	PROVISIONAL — user decision pending (BRIEF §16.4): victory = last keep standing ends the match early,
	otherwise most Crown Points at the end of Endgame, equal points share the win.
	PROVISIONAL — user decision pending (BRIEF §16.2): PvP between kingdoms. Off by default (the VS-1
	minimum). When enabled: war declarations from Conflict on, peace by mutual consent, no betrayal.
]]

local UNTIMED = math.huge

return {
	mode = "slice", -- PROVISIONAL (CONTRACTS G3 VS-1 slice)
	durations = {
		slice = {
			Lobby = 0,
			Founding = UNTIMED,
			Expansion = UNTIMED,
			Conflict = UNTIMED,
			Endgame = UNTIMED,
			Results = UNTIMED,
		},
		match = { Lobby = 20, Founding = 480, Expansion = 720, Conflict = 900, Endgame = 600, Results = 30 },
	},
	minPlayers = 1,
	tickSeconds = 0.25,
	victory = { conquest = true, crownPointsAtEnd = true }, -- PROVISIONAL (BRIEF §16.4)
	pvp = { enabled = false, peaceCooldown = 120, proposalSeconds = 60 }, -- PROVISIONAL (BRIEF §16.2)
	crown = { buildingLevel = 5, conquest = 300, unitKill = 2 },
}
