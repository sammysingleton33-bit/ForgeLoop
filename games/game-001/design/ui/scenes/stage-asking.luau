-- FL-0099 scene "stage-asking": Edda's three answers with their costs and a risk (cinematic stage).
local scene = require("./_stage")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(41)
		world:advance(0.5)
	end)
end
