-- FL-0138 scene "howto-3": How to play, card 3 of 6.
local HowToPlayDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/HowToPlayController")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { clientDefinitions = { HowToPlayDef } }, function(world)
		local help = world.client:get("HowToPlayController")
		help:open()
		for _ = 2, 3 do
			help:next()
		end
		world:advance(0.1)
	end)
end
