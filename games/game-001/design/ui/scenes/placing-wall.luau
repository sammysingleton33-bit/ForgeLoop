-- FL-0129c scene "placing-wall": the wall line, start set, the far end two pieces away: the total for both pieces,
-- "Build wall" (the pieces' ghosts are 3D and not drawn here).
local LineDoubles = require("../../../tests/economy/doubles/LineDoubles")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { remotes = LineDoubles.REMOTES, services = { LineDoubles.service } }, function(world, _, build)
		build:startPlacement("wall")
		build:aimAt(Vector3.new(80, 0, 80))
		world:advance(0.5)
		build:confirm()
		build:aimAt(Vector3.new(80, 0, 144))
		world:advance(0.2)
	end)
end
