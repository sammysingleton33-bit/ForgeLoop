-- FL-0129c slice 2 scene "placing-gate": the aim on one of my wall pieces: "Gate · in place of this wall", the price
-- less the wall's refund, "Half the wall's price comes back", Make gate (the gate's ghost is 3D and not drawn here).
local GateDoubles = require("../../../tests/economy/doubles/GateDoubles")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { remotes = GateDoubles.REMOTES, services = { GateDoubles.service } }, function(world, _, build)
		GateDoubles.wall(world, Vector3.new(80, 0, 120), math.rad(30))
		world:advance(0.1)
		build:startPlacement("gate")
		build:aimAt(Vector3.new(80, 0, 120))
		world:advance(0.2)
	end)
end
