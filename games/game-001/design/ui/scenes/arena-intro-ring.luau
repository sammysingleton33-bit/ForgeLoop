-- D-059 arena pass scene "arena-intro-ring": the intro's last seconds, the ring shot: the versus card has stepped aside. Sam's Emberhold (Adoring, spear, Reforge with Bram, Crowd Rally)
-- against Frostmere (Divided, mace, no perks).
local arena = require("./_arena")

return function(ctx)
	return arena(ctx, function(world, server, D)
		server:setState({
			stage = "intro",
			endsAt = world.env.serverTimeNow() + 3, -- inside the ring shot (Crowd.intro.ringSec 4)
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
