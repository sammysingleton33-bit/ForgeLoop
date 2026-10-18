-- FL-0129 scene "kingdom-rivals-ask": D-054 for a co-ruler. Mira (the second ruler) is the senior ruler,
-- so Sam's Declare war is "Ask Mira to declare war" and Frostmere's offer of peace is Mira's to accept.
-- Over doubles/DiplomacyDoubles (the diplomacy contract proposed to FORGE-01).
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
		diplomacy:setSenior(2)
		diplomacy:setWar("crimson", "azure")
		diplomacy:propose("azure", "crimson")
		world:advance(0.6)
		hud:setMenu("kingdom")
		hud:panelTab("rivals")
		world:advance(0.6)
	end)
end
