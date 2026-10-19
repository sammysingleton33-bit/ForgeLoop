-- FL-0129 scene "kingdom-rivals-asked": D-054 for the senior ruler. Mira asked for war on Thornwood
-- (FORGE-01's diplomacy.asks): the row says "Mira asks for war · m:ss" until it is answered or runs out,
-- and the Kingdom rail button counts it. Over doubles/DiplomacyDoubles.
local DiplomacyDoubles = require("../../../tests/economy/doubles/DiplomacyDoubles")
local scene = require("./_world")

return function(ctx)
	return scene(ctx, {
		remotes = DiplomacyDoubles.remotes(nil),
		services = { DiplomacyDoubles.service },
	}, function(world, hud)
		world.match:setPhase("Conflict", world.env.serverTimeNow() + 540)
		world.kingdoms:addCrownPoints("emerald", 9)
		local diplomacy = world.server:get("DiplomacyService")
		diplomacy:setSenior(1)
		diplomacy:setWar("crimson", "azure")
		diplomacy:askFrom(2, "Mira", "emerald", 1)
		world:advance(0.6)
		hud:setMenu("kingdom")
		hud:panelTab("rivals")
		world:advance(0.6)
	end)
end
