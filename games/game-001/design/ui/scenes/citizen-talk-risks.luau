-- FORGE-05 M1 scene "talk-risks": a 2-answer question whose answers carry a cost the treasury can't
-- pay ("Need 25 Gold", disabled) and two risks with their chances, all shown before choosing.
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(46)
		world:advance(0.1)
	end)
end
