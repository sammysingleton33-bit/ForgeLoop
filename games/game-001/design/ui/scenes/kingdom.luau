-- FL-0059 scene "kingdom": the Kingdom panel overview (rulers, standings).
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, function(_, hud)
		hud:setMenu("kingdom")
	end)
end
