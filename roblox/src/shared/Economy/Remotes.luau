--!strict
--[[
	Economy remotes (interfaces §6). Owned by FORGE-03; aggregated by FORGE-01's RemoteService.

	Economy.Treasury     serverEvent  (snapshot: TreasurySnapshot, change: TreasuryChange?)
	                     sent to every member of a kingdom whenever its treasury changes or opens.
	Economy.GetTreasury  function     () -> TreasurySnapshot?   the caller's kingdom treasury, nil if none
	                     (players who join mid-match, and the UI after a respawn)

	TreasurySnapshot = { kingdomId: string, balances: Bundle, caps: Bundle, version: number }
	                   `version` increases with every change: clients keep the highest they have seen.
	TreasuryChange   = { txId: string, reason: string, delta: Bundle (signed), overflow: Bundle }
	                   `reason` is the sink/source tag ("build:quarry", "production", "caps", ...).
	No client→server remote changes balances: spending happens inside server actions
	(FORGE-01's Gameplay.Build / Upgrade / Recruit), never on a client's word.
]]

return {
	{ name = "Economy.Treasury", kind = "serverEvent" },
	{ name = "Economy.GetTreasury", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
}
