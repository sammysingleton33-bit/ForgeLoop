-- FORGE-05 B1 scene "builder": the content library's builder_overworked (CitizenDoubles builds it from
-- Dialogue + ContentQuery.choicePreview): three answers, one costing 20 Food, one with a 50 % risk.
-- On a phone the third answer's risk line is below the fold here: tapping it opens the confirm step
-- (scene "citizen-confirm") instead of choosing.
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, _, _, conversation)
		conversation:open(47)
		world:advance(0.1)
	end)
end
