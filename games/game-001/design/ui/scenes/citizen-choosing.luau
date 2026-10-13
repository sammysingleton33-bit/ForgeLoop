-- FL-0088 scene "choosing": an answer picked, Kingdom.Choose in flight (every answer disabled).
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation, citizens)
		conversation:open(41)
		world:advance(0.1)
		citizens.latency = 30
		conversation:choose("help")
		world:advance(0.4) -- the confirm step (a cost or a risk) and its short guard
		conversation:confirm()
		world:advance(0.1)
	end)
end
