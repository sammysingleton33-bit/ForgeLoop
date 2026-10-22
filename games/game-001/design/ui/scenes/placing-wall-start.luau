-- FL-0129c scene "placing-wall-start": the wall line, picking the start (FORGE-01's Build.PlaceLine is served).
local LineDoubles = require("../../../tests/economy/doubles/LineDoubles")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { remotes = LineDoubles.REMOTES, services = { LineDoubles.service } }, function(world, _, build)
		build:startPlacement("wall")
		build:aimAt(Vector3.new(80, 0, 80))
		world:advance(0.5)
	end)
end
