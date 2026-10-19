-- FL-0073 scene "citizen-perk-pledged": Lise, a healer at 88 loyalty, stands with you (Pledged) and previews 95.
local scene = require("./_petition")
return function(ctx)
	return scene(ctx, function(world, _, card)
		card:open(43)
		world:advance(0.1)
	end)
end
