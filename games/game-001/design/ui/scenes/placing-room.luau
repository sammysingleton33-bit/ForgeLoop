-- FORGE-05 M-2 on #62 scene "placing-room": the real server's refusal for a spot too close to a
-- neighbour or a tree (Simulation:canPlace "blocked": the largest level plus the placement gap must
-- stay clear). The double answers that code here; the bar words it.
local scene = require("./_world")
return function(ctx)
	return scene(ctx, {}, function(world, _, build)
		world.build.canPlace = function()
			return false, "blocked"
		end
		build:startPlacement("farm")
		build:aimAt(Vector3.new(30, 0, 30))
		world:advance(0.2)
	end)
end
