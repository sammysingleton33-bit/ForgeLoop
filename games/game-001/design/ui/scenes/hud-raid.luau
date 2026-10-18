-- FL-0129 scene "hud-raid": enemies in our lands (FORGE-04's FeedbackWarController.alert(), #183): the
-- rail shows "Raid", whose tap sends the aerial camera there. Over a double of FORGE-04's controller.
local scene = require("./_world")

local war = {
	name = "FeedbackWarController",
	new = function()
		return {
			alert = function()
				return { position = Vector3.new(0, 0, 0), kingdom = "azure", at = 0 }
			end,
			goToAlert = function()
				return true
			end,
		}
	end,
}

return function(ctx)
	return scene(ctx, { clientDefinitions = { war } }, function(world, _hud)
		world.match:setPhase("Conflict", world.env.serverTimeNow() + 540)
		world:advance(1.2)
	end)
end
