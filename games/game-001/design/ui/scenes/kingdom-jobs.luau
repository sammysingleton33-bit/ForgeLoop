-- FL-0065 scene "kingdom-jobs": the Kingdom panel's Jobs tab while a woodcutter is being asked for
-- (prototype scene of the same name). Population and quotas from tests/economy/doubles/PopulationDoubles.
local PopulationDoubles = require("../../../tests/economy/doubles/PopulationDoubles")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {
		remotes = PopulationDoubles.REMOTES,
		services = { PopulationDoubles.service },
		latency = 5, -- the reply is still on its way when the snapshot is taken
	}, function(_, hud)
		hud:setMenu("kingdom")
		hud:panelTab("jobs")
		hud:changeJob("woodcutter", 1)
	end)
end
