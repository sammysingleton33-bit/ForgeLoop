-- FL-0073 scene "arena-duel": 47 s into the duel. Sam is at 38 % HP with half stamina; Reforge has just fired,
-- Field Remedy and the Crowd Rally are armed; Frostmere is at 64 % and out of stamina.
local arena = require("./_arena")

return function(ctx)
	return arena(ctx, function(world, server, D)
		server:setState({
			stage = "duel",
			endsAt = world.env.serverTimeNow() + 73,
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
				t = 46,
				kind = "snapshot",
				side = "a",
				data = { a = { hpShare = 0.38, staminaShare = 0.5 }, b = { hpShare = 0.64, staminaShare = 0.2 } },
			},
			{ t = 46.5, kind = "staminaOut", side = "b" },
			{ t = 47, kind = "triggerFired", side = "a", data = { source = "perk:reforge" } },
		})
	end)
end
