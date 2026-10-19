-- FL-0138 scene "howto-kingdom": the Kingdom menu's Overview scrolled to its end, where the How to play button sits.
local HowToPlayDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/HowToPlayController")
local scene = require("./_world")
return function(ctx)
	return scene(ctx, { clientDefinitions = { HowToPlayDef } }, function(world, hud)
		hud:setMenu("kingdom")
		world:advance(0.1)
		local button = hud.guis.menus:FindFirstChild("HowToPlay", true)
		local scroll = button and button:FindFirstAncestorWhichIsA("ScrollingFrame")
		if scroll then
			scroll.CanvasPosition = Vector2.new(0, 10000) -- the renderer clamps to the end of the content
		end
	end)
end
