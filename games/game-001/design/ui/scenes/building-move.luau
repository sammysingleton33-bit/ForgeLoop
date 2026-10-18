-- FL-0120 scene "building-move": my level 1 barracks tapped while the server serves the move remotes:
-- Upgrade and, beside it, Move (CONTRACTS G13.9).
local MoveDoubles = require("../../../tests/economy/doubles/MoveDoubles")
local scene = require("./_plots")
return function(ctx)
	return scene(
		ctx,
		{ move = true, treasury = { food = 132, wood = 180, stone = 160, gold = 0 } },
		function(world, _, _, upgrade)
			local id = world.build:add("crimson", "barracks", 1, "complete", Vector3.new(150, 0, 150))
			world.build.buildings[id].cframe = MoveDoubles.cframe(Vector3.new(150, 0, 150), 0)
			world.build:push(id)
			world:advance(0.1)
			upgrade:open(id)
		end
	)
end
