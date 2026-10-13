-- FL-0088 scene "answered": the reaction and the effect chips after choosing (the Wood pill shows the spend).
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(41)
		world:advance(0.1)
		conversation:choose("help")
		world:advance(0.4) -- the confirm step (a cost or a risk) and its short guard
		conversation:confirm()
		world:advance(0.1)
	end)
end
