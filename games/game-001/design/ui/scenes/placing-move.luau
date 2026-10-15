-- FL-0120 scene "placing-move": moving a house (the panel's Move): the bar reads "Move House", is free
-- (no costs) and confirms with "Move here"; the spot is good (Build.CanMove).
local MoveDoubles = require("../../../tests/economy/doubles/MoveDoubles")
local scene = require("./_plots")
return function(ctx)
	return scene(ctx, { move = true }, function(world, _, _, _, build)
		local id = world.build:add("crimson", "house", 1, "complete", Vector3.new(40, 0, 40))
		world.build.buildings[id].cframe = MoveDoubles.cframe(Vector3.new(40, 0, 40), 0)
		world.build:push(id)
		world:advance(0.1)
		build:startMove(id)
		world:advance(0.2)
		build:aimAt(Vector3.new(100, 0, 100))
		world:advance(0.2)
	end)
end
