-- FL-0060 scene "army-nobarracks": the rail opens the drawer before the kingdom has a barracks
-- (prototype scene "army-nobarracks").
local scene = require("./_army")
return function(ctx)
	return scene(ctx, { soldiers = 0, barracks = false }, function(_, c)
		c.hud:setMenu("army")
	end)
end
