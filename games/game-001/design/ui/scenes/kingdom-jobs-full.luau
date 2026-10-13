-- FL-0065 scene "kingdom-jobs-full": no free citizens, two soldiers — every + is off and the pool
-- row says why (prototype scene of the same name).
local PopulationDoubles = require("../../../tests/economy/doubles/PopulationDoubles")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {
		remotes = PopulationDoubles.REMOTES,
		services = { PopulationDoubles.service },
	}, function(world, hud)
		local pop = world.server:get("PopulationService")
		pop:set("crimson", "hauler", 0)
		pop:set("crimson", "soldier", 2)
		world:advance(0.1)
		hud:setMenu("kingdom")
		hud:panelTab("jobs")
	end)
end
