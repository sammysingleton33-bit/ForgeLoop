-- FL-0099 scene "stage-answered": the reaction and five consequence chips, Done with its timer.
local scene = require("./_stage")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(41)
		world:advance(0.5)
		conversation:choose("help")
		world:advance(0.5)
		conversation:confirm()
		world:advance(0.3)
	end)
end
