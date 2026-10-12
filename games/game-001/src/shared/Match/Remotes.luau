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
	startedAtServerTime is when Founding began (simulation time 0; the G4 snapshot time base); in the
	Lobby it is when the Lobby opened. Implemented by Kingdom/MatchHost.
]]

return {
	{ name = "Match.GetState", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Match.State", kind = "serverEvent" },
	{ name = "Match.Ended", kind = "serverEvent" },
}
