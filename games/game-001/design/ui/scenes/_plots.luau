--[[
	Shared setup for the FL-0087 snapshot scenes: the spec world (tests/economy/doubles/KingdomWorld
	with SlotDoubles) running the real KingdomHudController, PlotPickerController and
	UpgradePanelController, sized to the device's CoreUISafeInsets area; `act(world, hud, picker,
	upgrade)` drives the UI with the same calls a selection makes. `opts.turns` adds SlotDoubles'
	plot "crimson_slot5" (a real world/Layout id, so the turn ghost has a place).
]]
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("../../../tests/economy/doubles/KingdomWorld")
local PlotPickerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/PlotPickerController")
local SlotDoubles = require("../../../tests/economy/doubles/SlotDoubles")
local UpgradePanelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/UpgradePanelController")

return function(ctx, opts, act)
	Create.useTestConnector()
	local world = KingdomWorld.new({
		clientDefinitions = { KingdomHudDef, PlotPickerDef, UpgradePanelDef },
		-- opts.turns: SlotDoubles' extra plot with a real world/Layout id (crimson_slot5)
		remotes = if opts.turns then SlotDoubles.TURN_REMOTES else SlotDoubles.REMOTES,
		services = { if opts.turns then SlotDoubles.turnService else SlotDoubles.service },
		treasury = opts.treasury,
	})
	local hud = world.client:get("KingdomHudController")
	hud:setViewport(ctx.core.width, ctx.core.height)
	world.kingdoms:addCrownPoints("crimson", 12)
	world:advance(0.2)
	if act then
		act(world, hud, world.client:get("PlotPickerController"), world.client:get("UpgradePanelController"))
		world:advance(0.1)
	end
	local g = hud.guis
	return { guis = { g.hud, g.topbar, g.menus, g.modals, g.notices } }
end
