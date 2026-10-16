-- FL-0115 scene "hud-waiting": the HUD while three citizens have an open request: the rail's "Waiting"
-- button with its count (CitizenCardController over FORGE-04's CitizenBubbleIndicatorController:count()).
local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local scene = require("./_world")

-- FORGE-04's indicator, reduced to what the rail reads (its own edge badges are its renders).
local indicatorDef = {
	name = "CitizenBubbleIndicatorController",
	new = function()
		return {
			count = function()
				return 3
			end,
			cycleRequests = function()
				return nil
			end,
		}
	end,
}

return function(ctx)
	return scene(ctx, { clientDefinitions = { CitizenCardDef, indicatorDef } }, function(world)
		world:advance(0.6)
	end)
end
