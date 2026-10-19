--[[
	Shared setup for the FL-0073 Crown Arena scenes: the arena controllers over ArenaDoubles (CONTRACTS G12.4; the
	support numbers are the doubles' stub until FORGE-01's FL-0070). Sam (user 1, Emberhold) duels Rowan's Frostmere
	champion (user 7, AI-free); `stage(world, server)` puts the arena where the scene needs it.
]]
local ArenaDoubles = require("../../../tests/economy/doubles/ArenaDoubles")
local ArenaHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaHudController")
local ArenaIntroDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArenaIntroController")
local LoadoutDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/LoadoutController")
local scene = require("./_world")

return function(ctx, stage)
	return scene(ctx, {
		clientDefinitions = { ArenaHudDef, LoadoutDef, ArenaIntroDef },
		remotes = ArenaDoubles.REMOTES,
		services = { ArenaDoubles.service },
	}, function(world, _hud)
		world.match:setPhase("Endgame", world.env.serverTimeNow() + 60)
		local server = world.server:get("ArenaDouble")
		stage(world, server, ArenaDoubles)
		world:advance(0.4)
	end)
end
