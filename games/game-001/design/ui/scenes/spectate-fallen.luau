-- FL-0129 scene "spectate-fallen": Emberhold has fallen to Frostmere (FORGE-01's Match.Spectate): the
-- fallen card with Stay and Leave over FORGE-04's spectate camera (doubles/FallenDoubles).
local SpectateDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudSpectateController")
local FallenDoubles = require("../../../tests/economy/doubles/FallenDoubles")
local scene = require("./_world")

local state = {
	targets = {
		FallenDoubles.battle("azure", "Frostmere", 10, 6),
		FallenDoubles.keep("azure", "Frostmere", 20),
		FallenDoubles.keep("emerald", "Thornwood", 30),
	},
}

return function(ctx)
	return scene(ctx, {
		clientDefinitions = { SpectateDef, FallenDoubles.camera(state) },
		remotes = FallenDoubles.REMOTES,
		services = { FallenDoubles.service },
	}, function(world, _hud)
		world.match:setPhase("Conflict", world.env.serverTimeNow() + 420)
		-- the state a real spectator gets (FL-0125, #187): our kingdom not alive, Kingdom.State.mine nil
		-- (FORGE-07 L2 on #185: the renders must show what the player sees around the card)
		world.kingdoms.kingdoms.crimson.alive = false
		world.kingdoms.members[world.player.UserId] = nil
		world.kingdoms.members[2] = nil
		world.kingdoms:publish()
		world.server:get("SpectateDouble"):send(world.player, true, {
			reason = "eliminated",
			kingdomId = "crimson",
			by = "azure",
			standing = { "azure", "emerald", "gold" },
		})
		world:advance(0.4)
	end)
end
