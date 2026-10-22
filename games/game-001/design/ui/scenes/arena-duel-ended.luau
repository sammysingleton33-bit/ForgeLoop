-- D-059 arena pass scene "arena-duel-ended": the blow that ends it. Sam knocks Frostmere's champion out with 12 % left;
-- the HUD's ended state before the crowning.
local arena = require("./_arena")

return function(ctx)
	return arena(ctx, function(world, server, D)
		server:setState({
			stage = "duel",
			endsAt = world.env.serverTimeNow() + 40,
			a = D.duellist(1, "crimson", "adoring", {
				weapon = "spear",
				armour = "light",
				triggers = { "reforge", "fieldRemedy", "crowdRally" },
			}),
			b = D.duellist(
				7,
				"azure",
				"divided",
				{ weapon = "mace", armour = "heavy", triggers = { "calledWarning" } }
			),
		})
		world:advance(0.2)
		server:events({
			{
				t = 150,
				kind = "snapshot",
				side = "a",
				data = { a = { hpShare = 0.12, staminaShare = 0.4 }, b = { hpShare = 0.05, staminaShare = 0.2 } },
			},
			{ t = 151, kind = "hit", side = "a", data = { hpShare = 0 } },
			{ t = 151, kind = "ended", side = "a", data = { winner = "a", reason = "ko", hpA = 0.12, hpB = 0 } },
		})
	end)
end
