-- D-059 arena pass scene "arena-duel-edge": the duel's last seconds in sudden death. Both champions are low (Sam 14 %,
-- Frostmere 21 %), the clock is urgent (0:09), and Sam's Crowd Rally has just fired; Reforge and Field Remedy are spent.
local arena = require("./_arena")

return function(ctx)
	return arena(ctx, function(world, server, D)
		server:setState({
			stage = "duel",
			endsAt = world.env.serverTimeNow() + 16.5, -- 9 s left once the earlier perks have burnt out (below)
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
			{ t = 60, kind = "triggerFired", side = "a", data = { source = "perk:reforge", trigger = "reforge" } },
			{
				t = 90,
				kind = "triggerFired",
				side = "a",
				data = { source = "perk:fieldRemedy", trigger = "fieldRemedy" },
			},
		})
		world:advance(7.5) -- past ArenaHudModel.ACTIVE_SEC: those two are spent
		server:events({
			{
				t = 180,
				kind = "snapshot",
				side = "a",
				data = {
					a = { hpShare = 0.14, staminaShare = 0.3 },
					b = { hpShare = 0.21, staminaShare = 0.6 },
					suddenDeath = true,
				},
			},
			{
				t = 181,
				kind = "triggerFired",
				side = "a",
				data = { source = "perk:crowdRally", trigger = "crowdRally" },
			},
		})
	end)
end
