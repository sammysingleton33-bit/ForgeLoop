-- FL-0060 scene "army-short": 5 soldiers to recruit cost 150 Food; the treasury has 132 (prototype
-- scene "army-short"): the CTA says what is missing.
local scene = require("./_army")
return function(ctx)
	return scene(ctx, {}, function(_, c)
		c.military:setProgress("watchtower", "crimson", 0.64)
		c.military:setProgress("watchtower", "azure", 0.2)
		c.hud:setMenu("army")
		c.army:setCount(5)
	end)
end
