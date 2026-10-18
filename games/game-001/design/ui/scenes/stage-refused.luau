-- FL-0099 scene "stage-refused": the server refuses the answer (the reason as a sentence, Close).
local scene = require("./_stage")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation, citizens)
		conversation:open(43)
		world:advance(0.5)
		citizens.refuse = "not_eligible"
		conversation:choose("thornbury")
		world:advance(0.3)
	end)
end
