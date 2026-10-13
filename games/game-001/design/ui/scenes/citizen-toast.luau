-- FORGE-05 L4 scene "toast": a notice while the conversation is open. On phones the sheet covers
-- the usual toast corner, so the toast sits in the band above the sheet, right of the pills.
local scene = require("./_citizen")
return function(ctx)
	return scene(ctx, function(world, hud, _, conversation)
		conversation:open(42)
		world:advance(0.1)
		hud:notify({ kind = "success", title = "Farm complete", body = "Farmers can work it now" })
		world:advance(0.1)
	end)
end
