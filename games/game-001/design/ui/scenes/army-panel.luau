-- FL-0060 scene "army-panel": the army drawer from the rail, 4 soldiers, 3 to recruit, enough
-- resources; the watchtower half captured (prototype scene "army").
local scene = require("./_army")
return function(ctx)
	return scene(ctx, {}, function(_, c)
		c.military:setProgress("watchtower", "crimson", 0.64)
		c.military:setProgress("watchtower", "azure", 0.2)
		c.hud:setMenu("army")
		c.army:setCount(3)
	end)
end
