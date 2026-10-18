--!strict
--[[
	Match/Remotes — remotes of the "Match" area (CONTRACTS G1/G8). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Match.<Action>.

	Client -> server
		Match.GetState() -> (phase: MatchPhase, endsAtServerTime: number?, startedAtServerTime: number)
	Server -> client
		Match.State(phase, endsAtServerTime?, startedAtServerTime)   every phase or countdown change, and to
		                                     each arriving player; endsAtServerTime nil = untimed
		Match.Ended({ winner: KingdomId?, standings: { { kingdom, crownPoints } }, durationSec })   the G9
		                                     MatchEnded payload, when the match (or the VS-1 slice) ends
		Match.Spectate(spectating: boolean, info?: { reason: "eliminated" | "match_full", kingdomId: KingdomId?,
		                                              by: KingdomId?, standing: { KingdomId } })
		                                     the player watches instead of ruling (D-053 (3)). Sent when the player's
		                                     kingdom falls ("eliminated": kingdomId = the fallen kingdom, by = who took
		                                     the keep, if known), to a player who arrives (or comes back) as a spectator
		                                     ("eliminated" for a ruler of a fallen kingdom, "match_full" when every
		                                     kingdom is full), and as Match.Spectate(false) when the player is seated
		                                     again (a new match). standing = the kingdoms still standing, in kingdom
		                                     order. Kingdom.State.mine is nil for a spectator.
	startedAtServerTime is when Founding began (simulation time 0; the G4 snapshot time base); in the
	Lobby it is when the Lobby opened. Implemented by Kingdom/MatchHost.
]]

return {
	{ name = "Match.GetState", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Match.State", kind = "serverEvent" },
	{ name = "Match.Ended", kind = "serverEvent" },
	{ name = "Match.Spectate", kind = "serverEvent" },
}
