-- FL-0089 scene "rep-change": right after two Kingdom.Reputation pushes, the changes float on the strip.
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, {}, function(world, _, _, _, server)
		server:apply("compassion", 4, "You fed the farmers from the royal stores.")
		server:apply("fear", -2, "You pardoned the poacher.")
		world:advance(0.1)
	end)
end
