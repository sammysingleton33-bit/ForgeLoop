-- FL-0138 scene "howto-kingdom": the Kingdom menu's Overview with the How to play button at its end.
local HowToPlayDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/HowToPlayController")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { clientDefinitions = { HowToPlayDef } }, function(world, hud)
		hud:setMenu("kingdom")
		world:advance(0.1)
	end)
end
