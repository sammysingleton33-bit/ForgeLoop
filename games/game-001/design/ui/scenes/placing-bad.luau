-- FL-0059 scene "placing-bad": the server refused the spot (outside the territory).
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, function(world, _, build)
		build:startPlacement("farm")
		build:rotate()
		build:aimAt(Vector3.new(500, 0, 0))
		world:advance(0.2)
	end)
end
