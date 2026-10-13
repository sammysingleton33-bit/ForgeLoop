-- FL-0060 scene "objectives-hud": the HUD with the objective tracker while Emberhold captures the
-- watchtower (64 %) and Frostmere has 20 % (prototype scene "hud").
local scene = require("./_army")
return function(ctx)
	return scene(ctx, {}, function(_, c)
		c.military:setProgress("watchtower", "crimson", 0.64)
		c.military:setProgress("watchtower", "azure", 0.2)
	end)
end
