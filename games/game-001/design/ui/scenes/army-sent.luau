-- FL-0060 scene "army-sent": right after Send to capture: the button reads "Sent" for the cooldown,
-- the status line confirms it and a toast says so (prototype scene "army-sent"). On phones the toast
-- starts below the objective tracker.
local scene = require("./_army")
return function(ctx)
	return scene(ctx, {}, function(_, c)
		c.military:setProgress("watchtower", "crimson", 0.64)
		c.military:setProgress("watchtower", "azure", 0.2)
		c.hud:setMenu("army")
		c.army:setCount(3)
		c.army:send()
	end)
end
