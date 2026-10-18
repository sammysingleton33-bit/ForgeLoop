-- FL-0129 scene "kingdom-rivals-confirm": the Kingdom panel's Rivals tab in Conflict (D-053 (2)): Frostmere at war
-- with Emberhold and proposing peace (Accept / Propose peace), Greenvale at peace (Declare war), Sunreach
-- fallen; Declare war on Thornwood asks to confirm. Over doubles/DiplomacyDoubles (the diplomacy contract proposed to FORGE-01).
local DiplomacyDoubles = require("../../../tests/economy/doubles/DiplomacyDoubles")
local scene = require("./_world")

return function(ctx)
	return scene(ctx, {
		remotes = DiplomacyDoubles.remotes(nil),
		services = { DiplomacyDoubles.service },
	}, function(world, hud)
		world.match:setPhase("Conflict", world.env.serverTimeNow() + 540)
		world.kingdoms:addCrownPoints("emerald", 9)
		local gold = world.kingdoms.kingdoms.gold
		gold.alive = false
		local diplomacy = world.server:get("DiplomacyService")
		diplomacy:setWar("crimson", "azure")
		diplomacy:propose("azure", "crimson")
		world:advance(0.6)
		hud:setMenu("kingdom")
		hud:panelTab("rivals")
		world:advance(0.6)
		hud:diplomacyAction("emerald", "declareWar")
		world:advance(0.6)
	end)
end
