-- FL-0129c slice 2 scene "placing-gate-limit": the kingdom has its gate; the aim on another wall piece: "Your kingdom
-- has its gate already", Make gate off. The longest gate reason, for the phone bar.
local GateDoubles = require("../../../tests/economy/doubles/GateDoubles")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { remotes = GateDoubles.REMOTES, services = { GateDoubles.service } }, function(world, _, build)
		GateDoubles.wall(world, Vector3.new(80, 0, 120), 0)
		GateDoubles.wall(world, Vector3.new(80, 0, 184), 0)
		world:advance(0.1)
		build:startPlacement("gate")
		build:aimAt(Vector3.new(80, 0, 120))
		build:confirm()
		world:advance(0.3)
		build:startPlacement("gate")
		build:aimAt(Vector3.new(80, 0, 184))
		world:advance(0.2)
	end)
end
