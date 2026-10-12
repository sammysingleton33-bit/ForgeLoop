-- FL-0088 scene "card": the citizen card of Edda (she has something to say: Talk).
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, card)
		card:open(41)
		world:advance(0.1)
	end)
end
