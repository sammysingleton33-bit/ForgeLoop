-- FL-0088 scene "talk-4": the conversation panel asking (Kingdom.Converse payload from the doubles).
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(43)
		world:advance(0.1)
	end)
end
