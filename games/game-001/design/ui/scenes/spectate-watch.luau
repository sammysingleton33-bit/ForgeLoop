-- FL-0129 scene "spectate-watch": after Stay, the Watching list (battles first, then standing keeps), the
-- camera on the second target, over FORGE-04's spectate camera (doubles/FallenDoubles).
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
		world.server:get("SpectateDouble"):send(world.player, true, {
			reason = "eliminated",
			kingdomId = "crimson",
			by = "azure",
			standing = { "azure", "emerald", "gold" },
		})
		world:advance(0.4)
		world.client:get("KingdomHudSpectateController"):stay()
		world.client:get("KingdomHudSpectateController"):select(2)
		world:advance(0.2)
	end)
end
