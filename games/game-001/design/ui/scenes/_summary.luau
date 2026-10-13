--[[
	FL-0060 slice-summary scenes: the watchtower captured, the match in Results and the G9 MatchEnded
	payload pushed through Match.Ended. `winner` is a KingdomId or false (no winner).
]]
local scene = require("./_army")
return function(ctx, winner)
	return scene(ctx, {}, function(world, c)
		local standings = {
			{ kingdom = "azure", crownPoints = 120 },
			{ kingdom = "crimson", crownPoints = 112 },
			{ kingdom = "emerald", crownPoints = 40 },
			{ kingdom = "gold", crownPoints = 0 },
		}
		if winner == "crimson" then
			standings[2].crownPoints = 212
		end
		if winner then
			c.military:setOwner("watchtower", winner)
		end
		world.match:setPhase("Results", nil)
		c.military:endMatch({ winner = winner or nil, standings = standings, durationSec = 754 })
	end)
end
