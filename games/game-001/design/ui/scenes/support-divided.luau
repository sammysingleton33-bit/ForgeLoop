-- FL-0073 scene "support-divided": a Divided kingdom just let its people go hungry: falling trend, red moments.
local scene = require("./_support")
return function(ctx)
	return scene(ctx, { profile = "divided" }, function(world, _, sup, svc)
		local low = { happiness = 20, conduct = 15, loyalty = 30 }
		for _ = 1, 6 do
			svc:set(low)
			world:advance(50)
		end
		svc:act("starvation")
		sup:open()
	end)
end
