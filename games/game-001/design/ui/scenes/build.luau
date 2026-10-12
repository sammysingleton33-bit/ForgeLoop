-- FL-0059 scene "build": the build drawer with the Farm selected (phones: its detail pane).
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, function(_, hud, build)
		hud:setMenu("build")
		build:selectBuilding("farm")
	end)
end
