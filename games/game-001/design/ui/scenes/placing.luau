-- FL-0059 scene "placing": build mode on a valid spot (the ghost itself is 3D and not drawn here).
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, function(world, _, build)
		build:startPlacement("farm")
		build:aimAt(Vector3.new(80, 0, 80))
		world:advance(0.2)
	end)
end
