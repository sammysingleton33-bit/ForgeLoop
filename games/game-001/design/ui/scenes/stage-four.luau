-- FL-0099 scene "stage-four": four answers (two rows of two), no costs.
local scene = require("./_stage")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(43)
		world:advance(0.5)
	end)
end
