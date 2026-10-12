-- FL-0088 scene "card-quiet": a citizen with nothing pressing (Ask).
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, card)
		card:open(44)
		world:advance(0.1)
	end)
end
