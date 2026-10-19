-- FL-0129 scene "spectate-waiting": the server is full (FORGE-01's Match.Spectate reason match_full), so
-- the player was never seated. They watch with the phase pill and "You'll join the next match" under it
-- (FORGE-00, 2026-10-19); no kingdom HUD, no rail.
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
		kingdom = false,
		clientDefinitions = { SpectateDef, FallenDoubles.camera(state) },
		remotes = FallenDoubles.REMOTES,
		services = { FallenDoubles.service },
	}, function(world, _hud)
		world.match:setPhase("Expansion", world.env.serverTimeNow() + 245)
		world.server:get("SpectateDouble"):send(world.player, true, {
			reason = "match_full",
			standing = { "crimson", "azure", "emerald", "gold" },
		})
		world:advance(1.2)
		world.client:get("KingdomHudSpectateController"):stay()
		world:advance(0.2)
	end)
end
