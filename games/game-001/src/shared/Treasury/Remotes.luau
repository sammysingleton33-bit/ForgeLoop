--!strict
--[[
	Treasury remotes (CONTRACTS G7/G8). Owned by FORGE-03; created by the framework RemoteService.

	Treasury.Changed   serverEvent to the kingdom's members   (totals: ResourceBag, deltas: ResourceBag)
	                   after every applied spend/deposit, and once when a member joins or a match starts
	Treasury.Get       function () -> ResourceBag?            the caller's kingdom treasury (nil: no kingdom)
	Treasury.GetCosts  function () -> Costs.catalogue()       buildings, units, starting stockpile, upkeep

	No client -> server remote changes a balance: spending happens inside server actions
	(Build.Place, Build.Upgrade, Army.Recruit), which re-check costs on the server.
]]

return {
	{ name = "Treasury.Changed", kind = "serverEvent" },
	{ name = "Treasury.Get", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
	{ name = "Treasury.GetCosts", kind = "function", args = {}, rate = { burst = 3, perSecond = 1 } },
}
