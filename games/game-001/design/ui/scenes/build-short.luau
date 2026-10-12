-- FL-0059 scene "build-short": Military tab, Barracks unaffordable (the CTA names the shortfall).
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, function(_, hud, build)
		hud:setMenu("build")
		build:selectCategory("military")
		build:selectBuilding("barracks")
	end)
end
