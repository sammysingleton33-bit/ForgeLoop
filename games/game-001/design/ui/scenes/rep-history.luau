-- FL-0089 scene "rep-history": the History tab right after a push (newest line on top).
local scene = require("./_reputation")
return function(ctx)
	return scene(ctx, {}, function(world, _, rep, _, server)
		server:apply("compassion", 4, "You fed the farmers from the royal stores.")
		world:advance(2)
		rep:open()
		rep:selectTab("history")
	end)
end
