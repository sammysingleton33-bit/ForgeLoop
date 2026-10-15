-- FL-0099 scene "stage-confirm": the risky answer in the confirm step (every risk in full, Back / Choose).
local scene = require("./_stage")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(41)
		world:advance(0.5)
		conversation:choose("work")
		world:advance(0.1)
	end)
end
