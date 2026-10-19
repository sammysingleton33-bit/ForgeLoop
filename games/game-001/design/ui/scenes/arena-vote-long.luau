-- FL-0142 scene "arena-vote-long": four rulers, two with 20-character names, cut to fit their buttons (FORGE-07 M2).
local vote = require("./_vote")

local NAMES = { [3] = "Maximiliano_The_Great", [4] = "WWWWWWWWWWWWWWWWWWWW" }

return function(ctx)
	return vote(ctx, function(world, server)
		local hud = world.client:get("KingdomHudController")
		local nameOf = hud._nameOf
		hud._nameOf = function(self, id)
			return NAMES[id] or nameOf(self, id)
		end
		server:open("crimson", { 1, 2, 3, 4 }, world.env.serverTimeNow() + 5.4)
	end)
end
