-- FL-0073 scene "arena-loadout": Sam (Adoring) picks a loadout: the spear, light armour, Reforge, Field Remedy and
-- the Crowd Rally; Called Warning waits behind the full set.
local arena = require("./_arena")

return function(ctx)
	return arena(ctx, function(world, server, D)
		server.support[1] = D.support("adoring", 1, "crimson")
		server:setState({
			stage = "loadout",
			endsAt = world.env.serverTimeNow() + 14,
			a = D.duellist(1, "crimson", "adoring"),
			b = D.duellist(7, "azure", "divided"),
		})
		world:advance(0.3)
		local loadout = world.client:get("LoadoutController")
		loadout:weapon("spear")
		loadout:armour("light")
		loadout:toggle("heartyRations")
		loadout:toggle("crowdRally")
	end)
end
