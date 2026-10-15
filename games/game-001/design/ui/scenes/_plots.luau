--[[
	Shared setup for the FL-0087 snapshot scenes: the spec world (tests/economy/doubles/KingdomWorld
	with SlotDoubles) running the real KingdomHudController, PlotPickerController and
	UpgradePanelController, sized to the device's CoreUISafeInsets area; `act(world, hud, picker,
	upgrade)` drives the UI with the same calls a selection makes. `opts.turns` adds SlotDoubles'
	plot "crimson_slot5" (a real world/Layout id, so the turn ghost has a place). `opts.move` (FL-0120)
	also serves FORGE-01's move remotes (MoveDoubles, with the turn plot) and runs BuildMenuController,
	passed to `act` as its fifth argument.
]]
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local KingdomWorld = require("../../../tests/economy/doubles/KingdomWorld")
local MoveDoubles = require("../../../tests/economy/doubles/MoveDoubles")
local PlotPickerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/PlotPickerController")
local SlotDoubles = require("../../../tests/economy/doubles/SlotDoubles")
local UpgradePanelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/UpgradePanelController")

return function(ctx, opts, act)
	Create.useTestConnector()
	local definitions = { KingdomHudDef, PlotPickerDef, UpgradePanelDef }
	local remotes = if opts.turns then SlotDoubles.TURN_REMOTES else SlotDoubles.REMOTES
	-- opts.turns: SlotDoubles' extra plot with a real world/Layout id (crimson_slot5)
	local services = { if opts.turns or opts.move then SlotDoubles.turnService else SlotDoubles.service }
	if opts.move then
		table.insert(definitions, BuildMenuDef)
		remotes = MoveDoubles.remotes(SlotDoubles.TURN_REMOTES)
		table.insert(services, MoveDoubles.service)
	end
	local world = KingdomWorld.new({
		clientDefinitions = definitions,
		remotes = remotes,
		services = services,
		treasury = opts.treasury,
	})
	local hud = world.client:get("KingdomHudController")
	hud:setViewport(ctx.core.width, ctx.core.height)
	world.kingdoms:addCrownPoints("crimson", 12)
	world:advance(0.2)
	if act then
		act(
			world,
			hud,
			world.client:get("PlotPickerController"),
			world.client:get("UpgradePanelController"),
			if opts.move then world.client:get("BuildMenuController") else nil
		)
		world:advance(0.1)
	end
	local g = hud.guis
	return { guis = { g.hud, g.topbar, g.menus, g.modals, g.notices } }
end
