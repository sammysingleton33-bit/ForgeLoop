-- FL-0073 scene "citizen-petition-short": Bran, a captain, asks for more gold than the treasury holds: Need, Fulfil off.
local scene = require("./_petition")
return function(ctx)
	return scene(ctx, function(world, _, card)
		card:open(42)
		world:advance(0.1)
	end)
end
