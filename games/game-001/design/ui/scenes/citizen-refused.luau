-- FL-0088 scene "refused": Kingdom.Choose said no; the reason as a sentence.
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation, citizens)
		citizens.refuse = "not_eligible"
		conversation:open(41)
		world:advance(0.1)
		conversation:choose("bread")
		world:advance(0.1)
	end)
end
