--!strict
--[[
	Match (ReplicatedStorage.Forge.Config.Match) — match mode, pacing fallback and victory. Owner: FORGE-01.

	mode: "slice" | "match" (CONTRACTS G3/G11). "match" is the full match and the default (D-053 (1)): the
	timed phases of Pacing, starting citizens in all four kingdoms, AI governors in every kingdom without a human
	ruler. "slice" is the interim VS-1 slice (Lobby 0 s, Founding starts on the first join and is untimed, the
	first ObjectiveCaptured ends the slice (MatchEnded { winner } → Results), starting citizens appear when a
	kingdom's first ruler joins and AI kingdoms stay idle); the Studio command match.mode slice restarts the
	match in it (D-053 (7)).
	durations: built-in phase lengths per mode (seconds; math.huge = untimed), used only when FORGE-04's
	PacingService is absent; MatchService prefers PacingService:phaseDurations(mode). Same values as config
	Pacing so the game behaves the same either way.

	victory (D-053 (3), BRIEF §16.4): the last keep standing ends the match early, with no duel. Otherwise, when
	Endgame ends, the top two kingdoms by Crown Points fight the final duel in the Crown Arena (FL-0071; Match
	holds the hooks). Until the arena exists, or if it declines, the most Crown Points wins and equal points
	share the win.
	rulerMaxSpeed: the fastest a ruler's character counts as moving in the simulation (MatchHost position clamp).

	pvp (D-053 (2), BRIEF §16.2): on. War declarations from Conflict on, peace by mutual consent, no betrayal
	(alliances stay VS-3). enabled = false is the VS-1 slice minimum.
]]

local UNTIMED = math.huge

return {
	mode = "match", -- the full match is the default build (D-053 (1)); "slice" stays reachable (match.mode debug command)
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
	tickSeconds = 1 / 16, -- 16 Hz movement (CONTRACTS G4 ≈20 Hz); exact in binary, so timers never drift
	victory = { conquest = true, crownPointsAtEnd = true }, -- D-053 (3)
	pvp = { enabled = true, peaceCooldown = 120, proposalSeconds = 60 }, -- D-053 (2): war from Conflict, peace by consent
	crown = { buildingLevel = 5, conquest = 300, unitKill = 2 },
	-- the Crown Arena (FL-0071): the longest the final duel may hold the match before the Crown Points result stands
	arena = { maxSeconds = 600 },
	-- The server never trusts a ruler's reported position further than it could have walked (D-050 (6b), FL-0122):
	-- what the sim sees of a character moves toward the reported position at most this fast. The client's sprint is
	-- 24 studs/s; the rest is room for lag bursts and slopes. A teleport still arrives, but at this speed.
	rulerMaxSpeed = 40, -- studs per second
}
