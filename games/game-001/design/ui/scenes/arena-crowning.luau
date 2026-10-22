-- D-059 arena pass scene "arena-crowning": Sam has won; the crowning stage (15 s) before Results. The arena HUD has
-- stepped back and the kingdom HUD returns; the phase pill names the stage ("Crown Arena · Crowning").
local arena = require("./_arena")

return function(ctx)
	return arena(ctx, function(world, server, D)
		world.match:setPhase("Endgame", world.env.serverTimeNow()) -- the arena runs: Endgame's clock is spent
		server:setState({
			stage = "crowning",
			endsAt = world.env.serverTimeNow() + 14,
			winner = 1,
			a = D.duellist(1, "crimson", "adoring", { weapon = "spear", armour = "light", triggers = {} }),
			b = D.duellist(7, "azure", "divided", { weapon = "mace", armour = "heavy", triggers = {} }),
		})
		world:advance(0.5)
	end)
end
