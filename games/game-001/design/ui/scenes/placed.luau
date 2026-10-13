-- FL-0059 scene "placed": right after Place: the spend floats under Wood, a toast, a new chip.
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, function(world, _, build)
		build:startPlacement("farm")
		build:aimAt(Vector3.new(80, 0, 80))
		world:advance(0.2)
		build:confirm()
		world:advance(0.2)
	end)
end
