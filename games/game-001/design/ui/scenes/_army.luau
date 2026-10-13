--[[
	Shared setup for the FL-0060 snapshot scenes (army drawer, objective tracker, slice summary): the
	spec world (tests/economy/doubles/KingdomWorld) with the FORGE-01 doubles for the army, objectives
	and match end (ArmyDoubles), the population (PopulationDoubles) and reputation (ReputationDoubles,
	so the HUD stack is the real one), running the real KingdomHudController, UpgradePanelController,
	ReputationPanelController, ObjectivePanelController, ArmyPanelController and
	SliceSummaryController, sized to the device's CoreUISafeInsets area.

		return scene(ctx, { treasury?, soldiers? (default 4), barracks? (default true) },
			function(world, c) ... end)   -- c = { hud, army, objectives, summary, upgrade, military }

	Starting state (as the FL-0059 / FL-0089 scenes): Emberhold (crimson, 12 Crown Points), Frostmere
	20, a house under construction (45 %), a finished barracks Lv 1 and the neutral watchtower.
]]
local ArmyDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ArmyPanelController")
local ArmyDoubles = require("../../../tests/economy/doubles/ArmyDoubles")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("../../../tests/economy/doubles/KingdomWorld")
local ObjectiveDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ObjectivePanelController")
local PopulationDoubles = require("../../../tests/economy/doubles/PopulationDoubles")
local Rep = require("../../../tests/economy/doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")
local SummaryDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/SliceSummaryController")
local UpgradePanelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/UpgradePanelController")

local BALANCED = {
	values = { compassion = 62, honor = 48, competence = 55, courage = 40, authority = 70, fear = 15 },
	kingdom = { happiness = 68, stability = 54, morale = 41 },
	history = {},
}

return function(ctx, opts, act)
	Create.useTestConnector()
	local world = KingdomWorld.new({
		remotes = ArmyDoubles.remotes(Rep.REMOTES),
		services = { PopulationDoubles.service, Rep.service(BALANCED), ArmyDoubles.service },
		clientDefinitions = {
			KingdomHudDef,
			UpgradePanelDef,
			ReputationDef,
			ObjectiveDef,
			ArmyDef,
			SummaryDef,
		},
		treasury = opts.treasury or { food = 132, wood = 110, stone = 50, gold = 0 },
	})
	local c = {
		hud = world.client:get("KingdomHudController"),
		army = world.client:get("ArmyPanelController"),
		objectives = world.client:get("ObjectivePanelController"),
		summary = world.client:get("SliceSummaryController"),
		upgrade = world.client:get("UpgradePanelController"),
		military = world.server:get("MilitaryService"),
	}
	c.hud:setViewport(ctx.core.width, ctx.core.height)
	world.kingdoms:addCrownPoints("crimson", 12)
	world.kingdoms:addCrownPoints("azure", 20)
	world.server:get("PopulationService"):set("crimson", "soldier", if opts.soldiers == nil then 4 else opts.soldiers)
	world:advance(0.2)
	local houseId = world.build:add("crimson", "house", 1, "constructing", Vector3.new(-60, 0, 60))
	world.build:progress(houseId, 0.45)
	if opts.barracks ~= false then
		c.barracksId = world.build:add("crimson", "barracks", 1, "complete", Vector3.new(150, 0, 150))
		world.build:push(c.barracksId)
	end
	world:advance(0.1)
	if act then
		act(world, c)
		world:advance(0.1)
	end
	local g = c.hud.guis
	return { guis = { g.hud, g.topbar, g.menus, g.modals, g.notices } }
end
