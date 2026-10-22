-- FL-0142 scene "arena-vote": Emberhold's two rulers choose their champion; nobody has voted yet.
local vote = require("./_vote")

return function(ctx)
	return vote(ctx, function(world, server)
		server:open("crimson", { 1, 2 }, world.env.serverTimeNow() + 8.4)
	end)
end
