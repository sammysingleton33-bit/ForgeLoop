-- FL-0142 scene "arena-vote-voted": Sam has voted for Mira (gold), "1 of 2 voted", and may still change it.
local vote = require("./_vote")

return function(ctx)
	return vote(ctx, function(world, server, controller)
		server:open("crimson", { 1, 2 }, world.env.serverTimeNow() + 6.4)
		world:advance(0.3)
		controller:vote(2)
		world:advance(0.3)
	end)
end
