-- FL-0129c slice 2 scene "placing-gate-pick": the gate, no wall piece under the aim yet: "Gate: pick a wall piece",
-- the price less the wall's refund, "Point at one of your wall pieces", Make gate off.
local GateDoubles = require("../../../tests/economy/doubles/GateDoubles")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { remotes = GateDoubles.REMOTES, services = { GateDoubles.service } }, function(world, _, build)
		GateDoubles.wall(world, Vector3.new(80, 0, 120), 0)
		world:advance(0.1)
		build:startPlacement("gate")
		build:aimAt(Vector3.new(80, 0, 60))
		world:advance(0.2)
	end)
end
