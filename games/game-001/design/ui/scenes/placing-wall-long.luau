-- FL-0129c scene "placing-wall-long": a line too long for one call: the reason, the total in red, Build wall off.
local LineDoubles = require("../../../tests/economy/doubles/LineDoubles")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { remotes = LineDoubles.REMOTES, services = { LineDoubles.service } }, function(world, _, build)
		build:startPlacement("wall")
		build:aimAt(Vector3.new(80, 0, 80))
		world:advance(0.5)
		build:confirm()
		build:aimAt(Vector3.new(80, 0, 80 + 32 * 11))
		world:advance(0.2)
	end)
end
