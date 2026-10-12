-- FL-0089 scene "rep-build": the FL-0059 build drawer with the strip (the drawer starts below it).
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, {}, function(_, hud, _, build)
		hud:setMenu("build")
		build:selectBuilding("farm")
	end)
end
