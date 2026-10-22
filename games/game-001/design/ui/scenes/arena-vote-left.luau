-- D-059 arena pass scene "arena-vote-left": three rulers; Sam voted for Rowan, then Rowan left. The panel says the
-- vote counts for nobody and invites a new pick (the "left" status, FORGE-07 M3 on #265, G12.6 after #285).
local VoteDoubles = require("../../../tests/economy/doubles/VoteDoubles")
local vote = require("./_vote")

return function(ctx)
	return vote(ctx, function(world, server, controller)
		local endsAt = world.env.serverTimeNow() + 7.4
		server:open("crimson", { 1, 2, 3 }, endsAt)
		world:advance(0.3)
		controller:vote(3)
		world:advance(0.3)
		-- Rowan leaves: the server drops him from the candidates and keeps Sam's spent ballot in `voted`
		world.server:get("ArenaDouble"):setState(VoteDoubles.state("crimson", { 1, 2 }, endsAt, { 1 }))
		world:advance(0.3)
	end)
end
