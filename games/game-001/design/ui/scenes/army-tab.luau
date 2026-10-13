-- FL-0060 scene "army-tab": my barracks tapped in the world: its upgrade panel (FL-0087) now has an
-- Army tab (prototype scene "upgrade-tab").
local scene = require("./_army")
return function(ctx)
	return scene(ctx, {}, function(_, c)
		c.military:setProgress("watchtower", "crimson", 0.64)
		c.military:setProgress("watchtower", "azure", 0.2)
		c.upgrade:open(c.barracksId)
	end)
end
