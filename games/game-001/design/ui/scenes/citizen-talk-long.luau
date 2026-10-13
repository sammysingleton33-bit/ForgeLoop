-- FL-0088 scene "talk-long": the conversation panel asking (Kingdom.Converse payload from the doubles).
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(45)
		world:advance(0.1)
	end)
end
