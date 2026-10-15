-- The back key in FORGE-03's drawers (FORGE-04's InputModeController:onBack, #130; handoff
-- 2026-10-13-forge-04-to-forge-03-back-key): the real KingdomHudController, BuildMenuController and
-- FORGE-04's real InputModeController over KingdomWorld. One press, one step: a phone detail goes back
-- to its list, the kingdom panel's building detail to its tab, else the drawer closes; topmost wins.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local InputModeDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InputModeController")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")

local function newWorld(width, height, defs)
	local world = KingdomWorld.new({ clientDefinitions = defs or { KingdomHudDef, BuildMenuDef, InputModeDef } })
	world.hud = world.client:get("KingdomHudController")
	world.build = if defs then nil else world.client:get("BuildMenuController")
	world.input = world.client:get("InputModeController")
	world.hud:setViewport(width or 1920, height or 1022)
	world:advance(0.5) -- past the input mode's settle time
	return world
end

local function handlers(world)
	return #world.input._backHandlers
end

describe("Back key in the drawers (#130)", function()
	local world, previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		if world then
			world:destroy()
			world = nil
		end
		Create.setConnector(previous)
	end)

	it("closes the open drawer, one registration while any drawer shows, none when closed", function()
		world = newWorld()
		local hud, input = world.hud, world.input
		expect(input:back()).toBe(false) -- nothing open: not taken
		expect(handlers(world)).toBe(0)
		hud:setMenu("build")
		expect(handlers(world)).toBe(1)
		hud:setMenu("kingdom") -- another drawer: still one
		expect(handlers(world)).toBe(1)
		expect(input:back()).toBe(true)
		expect(hud.state.menu).toBeNil()
		expect(handlers(world)).toBe(0)
		expect(input:back()).toBe(false)
		hud:setMenu("build")
		hud:setMenu("build") -- the same id again closes it (the rail toggle): released too
		expect(handlers(world)).toBe(0)
	end)

	it("steps back inside a panel first: the kingdom panel's building detail, a phone build detail", function()
		world = newWorld()
		local hud, input = world.hud, world.input
		hud:setMenu("kingdom")
		hud:openUpgrade(1)
		expect(input:back()).toBe(true)
		expect(hud.state.menu).toBe("kingdom")
		expect(hud.state.panel.upgradeId).toBeNil()
		expect(input:back()).toBe(true)
		expect(hud.state.menu).toBeNil()
		-- desktop shows list and detail side by side: back closes at once
		hud:setMenu("build")
		world.build:selectBuilding("house")
		expect(input:back()).toBe(true)
		expect(hud.state.menu).toBeNil()
		world:destroy()
		-- phone: one pane at a time
		world = newWorld(844, 390)
		hud, input = world.hud, world.input
		expect(hud:metrics().breakpoint).toBe("phone")
		hud:setMenu("build")
		world.build:selectBuilding("house")
		expect(world.build.state.phoneView).toBe("detail")
		expect(input:back()).toBe(true)
		expect(world.build.state.phoneView).toBe("list")
		expect(hud.state.menu).toBe("build")
		expect(input:back()).toBe(true)
		expect(hud.state.menu).toBeNil()
	end)

	it("topmost wins: a handler registered over the drawer goes first, the drawer's after its release", function()
		world = newWorld()
		local hud, input = world.hud, world.input
		local below = 0
		local releaseBelow = input:onBack(function()
			below += 1
			return true
		end)
		hud:setMenu("build")
		local above = 0
		local releaseAbove = input:onBack(function()
			above += 1
			return true
		end)
		expect(input:back()).toBe(true)
		expect(above).toBe(1)
		expect(hud.state.menu).toBe("build")
		releaseAbove()
		expect(input:back()).toBe(true) -- the drawer, above the one registered before it opened
		expect(hud.state.menu).toBeNil()
		expect(below).toBe(0)
		expect(input:back()).toBe(true)
		expect(below).toBe(1)
		releaseBelow()
	end)

	it("a step that errors still closes the drawer; destroy releases the handler", function()
		world = newWorld()
		local hud, input = world.hud, world.input
		hud:setBackStep("kingdom", function()
			error("boom")
		end)
		hud:setMenu("kingdom")
		expect(input:back()).toBe(true)
		expect(hud.state.menu).toBeNil()
		hud:setMenu("build")
		expect(handlers(world)).toBe(1)
		world:destroy()
		-- the HUD alone (no other controller closes a menu on its way out)
		world = newWorld(nil, nil, { KingdomHudDef, InputModeDef })
		world.hud:setMenu("kingdom")
		expect(handlers(world)).toBe(1)
		world.hud:destroy()
		expect(handlers(world)).toBe(0)
	end)
end)
