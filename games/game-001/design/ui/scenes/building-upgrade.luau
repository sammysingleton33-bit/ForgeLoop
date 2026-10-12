-- FL-0087 scene "building-upgrade": a level 1 barracks tapped, enough resources for level 2.
local scene = require("./_plots")
return function(ctx)
	return scene(ctx, { treasury = { food = 132, wood = 180, stone = 160, gold = 0 } }, function(world, _, _, upgrade)
		local id = world.build:add("crimson", "barracks", 1, "complete", Vector3.new(150, 0, 150))
		world.build:push(id)
		world:advance(0.1)
		upgrade:open(id)
	end)
end
