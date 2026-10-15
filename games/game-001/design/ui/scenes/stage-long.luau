-- FL-0099 scene "stage-long": the long question and answers (phones scroll, with the cue).
local scene = require("./_stage")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(45)
		world:advance(0.5)
	end)
end
