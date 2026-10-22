-- D-059 arena pass scene "arena-qualify": FORGE-01's coming `qualify` stage (5 s). Frostmere (30 Crown Points) and
-- Sam's Emberhold (22) qualify; the banner names both for every player, and the pill reads "Kingdoms qualify".
local arena = require("./_arena")

return function(ctx)
	return arena(ctx, function(world, server)
		world.match:setPhase("Endgame", world.env.serverTimeNow()) -- the arena runs: Endgame's clock is spent
		server:setState({
			stage = "qualify",
			endsAt = world.env.serverTimeNow() + 5,
			qualifiers = { "azure", "crimson" },
			qualifierPoints = { azure = 30, crimson = 22 },
		})
		world:advance(0.6)
	end)
end
