-- FORGE-05 B1 scene "confirm": the risky answer of builder_overworked tapped: the confirm step shows
-- that answer whole with its 50 % risk, and Back / Choose pinned under it. Nothing is sent yet.
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(47)
		world:advance(0.1)
		conversation:choose("builder_overworked_push_on")
		world:advance(0.1)
	end)
end
