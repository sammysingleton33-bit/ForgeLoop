-- FL-0087 scene "building-foreign": another kingdom's barracks tapped (read-only).
local scene = require("./_plots")
return function(ctx)
	return scene(ctx, {}, function(world, _, _, upgrade)
		local id = world.build:add("azure", "barracks", 2, "complete", Vector3.new(1500, 0, 0))
		world.build:push(id)
		world:advance(0.1)
		upgrade:open(id)
	end)
end
