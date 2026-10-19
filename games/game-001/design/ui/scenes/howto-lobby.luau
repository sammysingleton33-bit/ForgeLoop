-- FL-0138 scene "howto-lobby": the Lobby countdown with the How to play rail button.
local HowToPlayDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/HowToPlayController")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { clientDefinitions = { HowToPlayDef } }, function(world)
		world.match:setPhase("Lobby", world.env.serverTimeNow() + 20)
		world:advance(0.3)
	end)
end
