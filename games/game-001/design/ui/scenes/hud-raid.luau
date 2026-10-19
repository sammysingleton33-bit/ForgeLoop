-- FL-0129 scene "hud-raid": enemies in our lands (FORGE-04's FeedbackWarController.alert(), #183): the
-- rail shows "Raid", whose tap sends the aerial camera there. The rail's worst case (FORGE-07 L1 on
-- #182): Build, Kingdom, Army (ArmyDoubles serve the army remotes), Raid and Waiting (three citizens
-- with a request, over FORGE-04's indicator), so the phone render shows all five buttons at once.
local ArmyDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArmyPanelController")
local ArmyDoubles = require("../../../tests/economy/doubles/ArmyDoubles")
local CitizenCardDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/CitizenCardController")
local PopulationDoubles = require("../../../tests/economy/doubles/PopulationDoubles")
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

-- FORGE-04's indicator, reduced to what the rail reads.
local indicator = {
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
	return scene(ctx, {
		clientDefinitions = { ArmyDef, CitizenCardDef, indicator, war },
		remotes = ArmyDoubles.remotes(nil),
		services = { PopulationDoubles.service, ArmyDoubles.service },
	}, function(world, _hud)
		world.match:setPhase("Conflict", world.env.serverTimeNow() + 540)
		world:advance(1.2)
	end)
end
