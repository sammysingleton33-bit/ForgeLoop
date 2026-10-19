-- FL-0073 scene "arena-intro": the versus card. Sam's Emberhold (Adoring, spear, Reforge with Bram, Crowd Rally)
-- against Frostmere (Divided, mace, no perks).
local arena = require("./_arena")

return function(ctx)
	return arena(ctx, function(world, server, D)
		server:setState({
			stage = "intro",
			endsAt = world.env.serverTimeNow() + 12,
			a = D.duellist(1, "crimson", "adoring", {
				weapon = "spear",
				armour = "light",
				triggers = { "reforge", "fieldRemedy", "crowdRally" },
				triggerCitizens = {
					reforge = { name = "Bram", role = "blacksmith" },
					fieldRemedy = { name = "Mira", role = "healer" },
				},
			}),
			b = D.duellist(7, "azure", "divided", {
				weapon = "mace",
				armour = "heavy",
				triggers = { "calledWarning" },
				reasons = { "Held the bridge against Emberhold's raid", "Built a second granary" },
			}),
		})
	end)
end
