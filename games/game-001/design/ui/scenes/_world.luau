--[[
	Shared setup for the FL-0059 Luau snapshot scenes (design/ui/render, PROJECT=games/game-001/
	default.project.json): the real KingdomHudController and BuildMenuController on the spec world
	(tests/economy/doubles/KingdomWorld: real RemoteService + TreasuryService, FORGE-01 doubles),
	sized to the device's CoreUISafeInsets area. `act(world, hud, build)` drives the UI to a state
	with the same calls a tap makes.
]]
local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("../../../tests/economy/doubles/KingdomWorld")

return function(ctx, opts, act)
	Create.useTestConnector()
	local definitions = { KingdomHudDef, BuildMenuDef }
	for _, def in opts.clientDefinitions or {} do -- extra controllers for a scene (e.g. FORGE-04's)
		table.insert(definitions, def)
	end
	local world = KingdomWorld.new({
		clientDefinitions = definitions,
		treasury = opts.treasury,
		remotes = opts.remotes, -- extra doubles for a scene (e.g. PopulationDoubles)
		services = opts.services,
		latency = opts.latency,
		kingdom = opts.kingdom, -- false: the player is never seated (a match_full watcher)
	})
	local hud = world.client:get("KingdomHudController")
	local build = world.client:get("BuildMenuController")
	hud:setViewport(ctx.core.width, ctx.core.height)
	world.kingdoms:addCrownPoints("crimson", 12)
	world.kingdoms:addCrownPoints("azure", 20)
	world:advance(0.2)
	-- A house under construction, as in the prototype (opts.bare: the match's first second, nothing built yet).
	if not opts.bare then
		local houseId = world.build:add("crimson", "house", 1, "constructing", Vector3.new(-60, 0, 60))
		world.build:progress(houseId, 0.45)
	end
	world:advance(0.1)
	if act then
		act(world, hud, build)
	end
	local g = hud.guis
	local guis = { g.hud, g.topbar, g.menus, g.modals, g.notices }
	for _, extra in opts.extraGuis or {} do -- e.g. "ForgeNotifications" (NotificationController)
		local gui = world.client:get("KingdomHudController").roots.hud
		gui = gui and gui:FindFirstAncestorOfClass("PlayerGui")
		local found = gui and gui:FindFirstChild(extra)
		if found then
			table.insert(guis, found)
		end
	end
	return { guis = guis }
end
