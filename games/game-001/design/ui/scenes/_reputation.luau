--[[
	Shared setup for the FL-0089 Luau snapshot scenes (design/ui/render, PROJECT=games/game-001/
	default.project.json): the real KingdomHudController, BuildMenuController and
	ReputationPanelController on the spec world (tests/economy/doubles/KingdomWorld) plus the
	FORGE-01 ReputationService double (tests/economy/doubles/ReputationDoubles), sized to the
	device's CoreUISafeInsets area. Same starting state as the FL-0059 scenes (_world.luau).

		return scene(ctx, { profile = "balanced" | "fear" | "empty", content = false? }, function(world, hud, rep, build) ... end)

	Category prose comes from FORGE-00's content library (Content/Reputation, FL-0083) by default;
	`content = false` shows the fallback with no provider (no prose).
]]
local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("../../../tests/economy/doubles/KingdomWorld")
local Rep = require("../../../tests/economy/doubles/ReputationDoubles")
local ReputationDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/ReputationPanelController")

local PROFILES = {
	balanced = {
		values = { compassion = 62, honor = 48, competence = 55, courage = 40, authority = 70, fear = 15 },
		kingdom = { happiness = 68, stability = 54, morale = 41 },
		history = {
			{ ago = 4000, category = "courage", delta = 3, text = "You led the defence of the watchtower." },
			{ ago = 1500, category = "fear", delta = 3, text = "You had the thief flogged in the square." },
			{ ago = 700, category = "competence", delta = 2, text = "The new farm feeds twelve families." },
			{ ago = 420, category = "honor", delta = -5, text = "You broke your promise to the miners." },
			{ ago = 190, category = "authority", delta = 2, text = "You settled the millers' quarrel yourself." },
			{
				ago = 40,
				category = "compassion",
				delta = 4,
				text = "You gave grain from the royal stores to the hungry farmers.",
			},
		},
	},
	fear = {
		values = { compassion = 12, honor = 31, competence = 58, courage = 66, authority = 81, fear = 88 },
		kingdom = { happiness = 22, stability = 18, morale = 74 },
		history = {
			{
				ago = 900,
				category = "authority",
				delta = 3,
				text = "The striking quarrymen went back to work under guard.",
			},
			{ ago = 300, category = "compassion", delta = -3, text = "You turned the beggars away from the gate." },
			{ ago = 25, category = "fear", delta = 6, text = "You burned the rebels' farms." },
			{ ago = 25, category = "honor", delta = -4, text = "You burned the rebels' farms." },
		},
	},
	empty = {
		values = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 50, fear = 0 },
		kingdom = { happiness = 50, stability = 50, morale = 50 },
		history = {},
	},
}

return function(ctx, opts, act)
	Create.useTestConnector()
	local world = KingdomWorld.new({
		remotes = Rep.REMOTES,
		services = { Rep.service(PROFILES[opts.profile or "balanced"]) },
		clientDefinitions = { KingdomHudDef, BuildMenuDef, ReputationDef },
	})
	local hud = world.client:get("KingdomHudController")
	local build = world.client:get("BuildMenuController")
	local rep = world.client:get("ReputationPanelController")
	hud:setViewport(ctx.core.width, ctx.core.height)
	world.kingdoms:addCrownPoints("crimson", 12)
	world.kingdoms:addCrownPoints("azure", 20)
	world:advance(0.2)
	local houseId = world.build:add("crimson", "house", 1, "constructing", Vector3.new(-60, 0, 60))
	world.build:progress(houseId, 0.45)
	world:advance(0.1)
	if opts.content == false then
		rep:setCategoryText(nil)
	end
	if act then
		act(world, hud, rep, build, world.server:get("ReputationService"))
	end
	local g = hud.guis
	return { guis = { g.hud, g.topbar, g.menus, g.modals, g.notices } }
end
