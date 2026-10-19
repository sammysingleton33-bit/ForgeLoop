-- FL-0073 scene "citizen-petition": Edda, a blacksmith at 72 loyalty: her arena perk at 80 and her petition with Fulfil.
local scene = require("./_petition")
return function(ctx)
	return scene(ctx, function(world, _, card)
		card:open(41)
		world:advance(0.1)
	end)
end
