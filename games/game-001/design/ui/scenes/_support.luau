--[[
	Shared setup for the FL-0073 support meter scenes (design/ui/render, PROJECT=games/game-001/default.project.json):
	the real KingdomHudController, ReputationPanelController and SupportMeterController on the spec world
	(tests/economy/doubles/KingdomWorld) with the FORGE-01 ReputationService and SupportService doubles
	(tests/economy/doubles/ReputationDoubles, SupportDoubles: the real Arena/SupportModel on fixture samples, moments
	from config Support.acts), sized to the device's CoreUISafeInsets area.

		return scene(ctx, { profile = "adoring" | "divided" | "empty" }, function(world, hud, sup, svc) ... end)
]]
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("../../../tests/economy/doubles/KingdomWorld")
local Rep = require("../../../tests/economy/doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")
local Sup = require("../../../tests/economy/doubles/SupportDoubles")
local SupportMeterDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/SupportMeterController")

local PROFILES = {
	adoring = {
		components = {
			reputation = 92,
			happiness = 90,
			stability = 88,
			morale = 90,
			loyalty = 93,
			conduct = 95,
			valour = 85,
		},
		earlier = {
			reputation = 86,
			happiness = 84,
			stability = 85,
			morale = 88,
			loyalty = 90,
			conduct = 88,
			valour = 80,
		},
		acts = { "keepUpgraded", "defendedRaid", "fedRatioKept", "objectiveDefended", "petitionFulfilled" },
	},
	divided = {
		components = {
			reputation = 58,
			happiness = 41,
			stability = 52,
			morale = 63,
			loyalty = 47,
			conduct = 38,
			valour = 55,
		},
		acts = { "keepUpgraded", "starvation", "rebuiltRaidDamage", "abandonedRegion" },
	},
	empty = { samples = false },
}

local REPUTATION = {
	values = { compassion = 62, honor = 48, competence = 55, courage = 40, authority = 70, fear = 15 },
	kingdom = { happiness = 68, stability = 54, morale = 41 },
	history = {},
}

return function(ctx, opts, act)
	Create.useTestConnector()
	local world = KingdomWorld.new({
		remotes = {
			Kingdom = table.move(
				Sup.REMOTES.Kingdom,
				1,
				#Sup.REMOTES.Kingdom,
				#Rep.REMOTES.Kingdom + 1,
				table.clone(Rep.REMOTES.Kingdom)
			),
		},
		services = { Rep.service(REPUTATION), Sup.service(PROFILES[opts.profile or "adoring"]) },
		clientDefinitions = { KingdomHudDef, ReputationDef, SupportMeterDef },
	})
	local hud = world.client:get("KingdomHudController")
	local sup = world.client:get("SupportMeterController")
	hud:setViewport(ctx.core.width, ctx.core.height)
	world.kingdoms:addCrownPoints("crimson", 12)
	world.kingdoms:addCrownPoints("azure", 20)
	world:advance(0.2)
	if act then
		act(world, hud, sup, world.server:get("SupportService"))
		world:advance(0.1)
	end
	local g = hud.guis
	return { guis = { g.hud, g.topbar, g.menus, g.modals, g.notices } }
end
