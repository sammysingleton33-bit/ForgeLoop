--[[
	Shared setup for the FL-0129 Results scenes: a match played on the spec world with FORGE-01's
	reputation, population and match-end doubles; the real ReputationPanelController,
	SliceSummaryController and LeadershipRecapController. `open = true` opens "Your reign".
]]
local ArmyDoubles = require("../../../tests/economy/doubles/ArmyDoubles")
local PopulationDoubles = require("../../../tests/economy/doubles/PopulationDoubles")
local RecapDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/LeadershipRecapController")
local Rep = require("../../../tests/economy/doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")
local SummaryDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/SliceSummaryController")
local scene = require("./_world")

local START = {
	values = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 50, fear = 10 },
	kingdom = { happiness = 60, stability = 60, morale = 60 },
	history = {},
}

return function(ctx, opts)
	return scene(ctx, {
		remotes = ArmyDoubles.remotes(Rep.REMOTES),
		services = { PopulationDoubles.service, Rep.service(START), ArmyDoubles.service },
		clientDefinitions = { ReputationDef, SummaryDef, RecapDef },
	}, function(world, _hud)
		local rep = world.server:get("ReputationService")
		local pop = world.server:get("PopulationService")
		world.match:setPhase("Founding", world.env.serverTimeNow() + 600)
		pop:set("crimson", "farmer", 10)
		world:advance(1.5)
		rep:apply("compassion", 9, "You opened the granary to the hungry villages.")
		world:advance(1.2)
		rep:apply("honor", -12, "You broke the truce with Frostmere.")
		world:advance(1.2)
		rep:apply("authority", 7, "You raised the tithe and nobody dared complain.")
		rep:apply("courage", 5, "You led the defence of the east gate yourself.")
		pop:set("crimson", "farmer", 14)
		world:advance(1.2)
		world.match:setPhase("Results", world.env.serverTimeNow() + 30)
		world.server:get("MilitaryService"):endMatch({
			winner = "azure",
			standings = {
				{ kingdom = "azure", crownPoints = 30 },
				{ kingdom = "crimson", crownPoints = 22 },
				{ kingdom = "emerald", crownPoints = 14 },
				{ kingdom = "gold", crownPoints = 6 },
			},
			durationSec = 1830,
		})
		world:advance(0.5)
		if opts.open then
			world.client:get("LeadershipRecapController"):open()
			world:advance(0.2)
		end
	end)
end
