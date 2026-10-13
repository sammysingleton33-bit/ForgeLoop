-- FL-0060 scene "army-none": no soldiers yet and a neutral watchtower: Send to capture is disabled
-- with its reason (prototype scene "army-none").
local scene = require("./_army")
return function(ctx)
	return scene(ctx, { soldiers = 0 }, function(_, c)
		c.hud:setMenu("army")
	end)
end
