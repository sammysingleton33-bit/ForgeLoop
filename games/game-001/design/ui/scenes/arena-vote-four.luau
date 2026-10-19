-- FL-0142 scene "arena-vote-four": the widest case, four seated rulers in one row; one has voted.
local vote = require("./_vote")

return function(ctx)
	return vote(ctx, function(world, server)
		server:open("crimson", { 1, 2, 3, 4 }, world.env.serverTimeNow() + 4.4)
		local st = world.server:get("ArenaDouble").state
		st.vote.a.voted = { 3 }
		world.server:get("ArenaDouble"):setState(st)
	end)
end
