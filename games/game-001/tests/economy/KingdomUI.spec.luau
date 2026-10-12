-- FL-0059 end to end, headless: the real KingdomHudController and BuildMenuController talk through
-- the framework RemoteService to the real TreasuryService and FORGE-01 doubles (doubles/KingdomWorld).
-- Taps are simulated with Create.fire on the buttons a player would press.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

-- FORGE-04 doubles (G4.1 InputModeController, G11 OnboardingController, interfaces §8 NotificationController).
local function inputModeDef(log)
	return {
		name = "InputModeController",
		new = function()
			local c = { mode = "explore", changed = Signal.new() }
			function c:set(mode)
				table.insert(log, mode)
				if self.mode ~= mode then
					self.mode = mode
					self.changed:fire(mode)
				end
			end
			return c
		end,
	}
end

local function onboardingDef(log)
	return {
		name = "OnboardingController",
		new = function()
			return {
				report = function(_, action)
					table.insert(log, action)
					return true
				end,
			}
		end,
	}
end

local function notificationDef(log)
	return {
		name = "NotificationController",
		new = function()
			return {
				show = function(_, spec)
					table.insert(log, spec)
				end,
			}
		end,
	}
end

local function find(root, name)
	if root == nil then
		return nil
	end
	if root.Name == name then
		return root
	end
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function texts(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" then
			table.insert(out, d.Text)
		end
	end
	return table.concat(out, " | ")
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

local function amountOf(hud, id)
	return find(hud.view.pills[id].instance, "Amount").Text
end

local function newWorld(opts)
	local o = opts or {}
	local log = { modes = {}, onboarding = {}, notices = {} }
	local defs = { KingdomHudDef, BuildMenuDef }
	if o.inputMode ~= false then
		table.insert(defs, inputModeDef(log.modes))
	end
	table.insert(defs, onboardingDef(log.onboarding))
	if o.notifications then
		table.insert(defs, notificationDef(log.notices))
	end
	o.clientDefinitions = defs
	local world = KingdomWorld.new(o)
	world.log = log
	world.hud = world.client:get("KingdomHudController")
	world.buildMenu = world.client:get("BuildMenuController")
	if not o.noPlayerGui then
		world.hud:setViewport(o.width or 1920, o.height or 1022)
	end
	world:advance(0.1)
	return world
end

describe("Kingdom HUD (desktop)", function()
	local world, hud, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = newWorld()
		hud = world.hud
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("mounts in the documented DisplayOrder bands and safe areas", function()
		expect(hud.guis.hud.DisplayOrder).toBe(10)
		expect(hud.guis.hud.ScreenInsets).toBe(Enum.ScreenInsets.CoreUISafeInsets)
		expect(hud.guis.topbar.ScreenInsets).toBe(Enum.ScreenInsets.TopbarSafeInsets)
		expect(hud.guis.menus.DisplayOrder).toBe(20)
		expect(hud.guis.modals.DisplayOrder).toBe(40)
		expect(hud.guis.notices.DisplayOrder).toBe(70)
		expect(hud.guis.hud.Parent:IsA("PlayerGui")).toBe(true)
		expect(hud.guis.hud.ResetOnSpawn).toBe(false)
		expect(hud.guis.hud.Root.Scale.Scale).toBeNear(1022 / 850, 0.001)
		expect(hud.guis.hud.Enabled).toBe(true)
	end)

	it("1. shows the kingdom, its rulers, resources and the phase from the server", function()
		local all = texts(hud.guis.hud)
		expect(all).toContain("Emberhold")
		expect(all).toContain("Keep Lv 1 · 1 region · 0 Crown Points")
		expect(all).toContain("Sam")
		expect(all).toContain("Mira")
		expect(amountOf(hud, "food")).toBe(tostring(Costs.starting.food))
		expect(amountOf(hud, "wood")).toBe(tostring(Costs.starting.wood))
		expect(amountOf(hud, "stone")).toBe(tostring(Costs.starting.stone))
		expect(texts(hud.guis.topbar)).toContain("FOUNDING")
		-- FORGE-04 onboarding targets
		expect(find(hud.guis.hud, "Pills"):GetAttribute("OnboardingTarget")).toBe("HUD.Resources")
		expect(find(hud.guis.hud, "Menu_build"):GetAttribute("OnboardingTarget")).toBe("HUD.BuildButton")
	end)

	it("follows the server: treasury pushes float a delta, Crown Points and phase update", function()
		world.treasury:deposit("crimson", "food", 25, "harvest:1", "citizen:farmer")
		world:advance(0.1)
		expect(amountOf(hud, "food")).toBe(tostring(Costs.starting.food + 25))
		expect(find(hud.view.pills.food.instance, "Delta").Text).toContain("25")
		world.kingdoms:addCrownPoints("crimson", 12)
		world.match:setPhase("Expansion", world.env.serverTimeNow() + 90)
		world:advance(0.6)
		expect(texts(hud.guis.hud)).toContain("12 Crown Points")
		expect(texts(hud.guis.topbar)).toContain("EXPANSION")
		expect(texts(hud.guis.topbar)).toContain("left")
		expect(texts(hud.guis.topbar)).never.toContain("match time")
	end)

	it("tapping a resource explains it and tells onboarding (ResourceInspected)", function()
		tap(find(hud.view.pills.food.instance, "Hit"))
		world:advance(0.1)
		expect(world.log.onboarding[1]).toBe("ResourceInspected")
		expect(texts(hud.guis.notices)).toContain(`Food: {Costs.starting.food}`)
	end)

	it("2-6. Build: select a building, see its cost, place it, and see the confirmation", function()
		local build = world.buildMenu
		tap(find(hud.guis.hud, "Menu_build"))
		expect(hud.state.menu).toBe("build")
		local menu = find(hud.guis.menus, "BuildMenu")
		expect(menu).toBeTruthy()
		tap(find(menu, "Row_farm"))
		local detail = find(hud.guis.menus, "Detail")
		local all = texts(detail)
		expect(all).toContain("Farm")
		expect(all).toContain("34 × 28 studs")
		expect(all).toContain("0:" .. string.format("%02d", Costs.building("farm", 1).buildSeconds))
		expect(find(detail, "Cost_wood")).toBeTruthy()
		expect(find(find(detail, "Cost_wood"), "Have").Text).toBe(`✓ {Costs.starting.wood}`)
		local cta = find(detail, "Cta")
		expect(find(cta, "Face"):GetAttribute("cta")).toBe("ready")
		tap(cta)
		-- Build mode: drawer closed, ghost in the world, placement bar, FORGE-04 input mode.
		expect(hud.state.menu).toBeNil()
		expect(find(hud.guis.menus, "BuildMenu")).toBeNil()
		expect(world.log.modes[#world.log.modes]).toBe("build")
		expect(build.ghost).toBeTruthy()
		expect(build.ghost.folder.Parent).toBe(world.env.Workspace)
		expect(find(hud.guis.hud, "PlacementBar")).toBeTruthy()
		expect(find(hud.guis.hud, "Queue").Visible).toBe(false)

		build:aimAt(Vector3.new(60.7, 0, 61.2))
		world:advance(0.2)
		local checks = world:callsNamed("CanPlace")
		expect(#checks).toBe(1)
		expect(checks[1].args[1]).toBe("farm")
		expect(checks[1].args[2]).toBe(Vector3.new(60, 0, 62))
		expect(checks[1].args[3]).toBe(0)
		expect(build.placing.status).toBe("ok")
		expect(build.ghost.base.Color).toBe(Color3.fromRGB(91, 174, 95))
		expect((build.ghost.base.Size - Vector3.new(34, 0.6, 28)).Magnitude).toBeLessThan(1e-3) -- Kit.footprint("farm", 1)
		local bar = find(hud.guis.hud, "PlacementBar")
		expect(find(bar, "Status"):GetAttribute("status")).toBe("ok")

		tap(find(bar, "Place"))
		world:advance(0.2)
		local places = world:callsNamed("Place")
		expect(#places).toBe(1)
		expect(places[1].args[2]).toBe(Vector3.new(60, 0, 62))
		-- Visual confirmation: the spend floats under the Wood pill, a toast, a construction chip.
		local woodLeft = Costs.starting.wood - Costs.building("farm", 1).cost.wood
		expect(amountOf(hud, "wood")).toBe(tostring(woodLeft))
		expect(find(hud.view.pills.wood.instance, "Delta").Text).toContain(
			tostring(Costs.building("farm", 1).cost.wood)
		)
		expect(texts(hud.guis.notices)).toContain("Farm placed")
		expect(build.placing).toBeNil()
		expect(build.ghost).toBeNil()
		expect(world.log.modes[#world.log.modes]).toBe("explore")
		local queue = find(hud.guis.hud, "Queue")
		expect(queue.Visible).toBe(true)
		expect(texts(queue)).toContain("waiting")
		local newId = world.build.nextId - 1
		world.build:progress(newId, 0.5)
		world:advance(0.1)
		expect(texts(find(queue, "Chip_" .. newId))).toContain("50%")
	end)

	it("a red ghost explains why and Place sends nothing", function()
		local build = world.buildMenu
		build:startPlacement("farm")
		build:aimAt(Vector3.new(500, 0, 0))
		world:advance(0.2)
		expect(build.placing.status).toBe("bad")
		expect(build.placing.reason).toBe("Outside your territory")
		expect(build.ghost.base.Color).toBe(Color3.fromRGB(217, 87, 63))
		local bar = find(hud.guis.hud, "PlacementBar")
		expect(texts(bar)).toContain("Outside your territory")
		expect(find(find(bar, "Place"), "Face"):GetAttribute("cta")).toBe("disabled")
		Create.fire(find(find(bar, "Place"), "Face"), "Activated") -- a disabled button ignores taps
		build:confirm()
		world:advance(0.2)
		expect(#world:callsNamed("Place")).toBe(0)
		build:aimAt(Vector3.new(0, 0, 10))
		world:advance(0.2)
		expect(build.placing.reason).toBe("Too close to another building")
	end)

	it("ignores a late verdict for a spot the ghost already left", function()
		world.latency = 0.1
		local build = world.buildMenu
		build:startPlacement("farm")
		build:aimAt(Vector3.new(500, 0, 0)) -- bad spot: its reply comes back after the next aim
		world:advance(0.05)
		build:aimAt(Vector3.new(100, 0, 100))
		world:advance(0.06)
		expect(build.placing.status).toBe("pending") -- the "territory" reply belonged to the old spot
		world:advance(0.5)
		expect(build.placing.status).toBe("ok")
		expect(#world:callsNamed("CanPlace")).toBe(2)
	end)

	it("rotates in 90° steps and re-checks the spot with the new rotation", function()
		local build = world.buildMenu
		build:startPlacement("farm")
		build:aimAt(Vector3.new(80, 0, 80))
		world:advance(0.2)
		tap(find(find(hud.guis.hud, "PlacementBar"), "Rotate"))
		world:advance(0.2)
		local checks = world:callsNamed("CanPlace")
		expect(checks[#checks].args[3]).toBe(1)
		expect(build.placing.rot).toBe(1)
		expect(math.abs(build.ghost.base.CFrame.LookVector.X)).toBeNear(1, 1e-6)
	end)

	it("throttles Build.CanPlace while the ghost moves and keeps the latest verdict", function()
		local build = world.buildMenu
		build:startPlacement("house")
		for i = 1, 30 do
			build:aimAt(Vector3.new(40 + i * 2, 0, 100))
		end
		world:advance(1)
		local checks = world:callsNamed("CanPlace")
		expect(#checks).toBeLessThan(4)
		expect(checks[#checks].args[2]).toBe(Vector3.new(100, 0, 100))
		expect(build.placing.status).toBe("ok")
	end)

	it("cannot start placing what the treasury cannot pay for", function()
		tap(find(hud.guis.hud, "Menu_build"))
		tap(world.buildMenu.menu.tabs.buttons.military)
		expect(world.buildMenu.state.category).toBe("military")
		tap(find(hud.guis.menus, "Row_barracks"))
		local cta = find(find(hud.guis.menus, "Detail"), "Cta")
		expect(texts(cta)).toContain("Need 20 Wood and 10 Stone")
		expect(find(cta, "Face"):GetAttribute("cta")).toBe("disabled")
		world.buildMenu:startPlacement("barracks")
		expect(world.buildMenu.placing).toBeNil()
	end)

	it("a refusal from Build.Place keeps build mode open with the reason", function()
		local build = world.buildMenu
		build:startPlacement("farm")
		build:aimAt(Vector3.new(100, 0, 100))
		world:advance(0.2)
		expect(build.placing.status).toBe("ok")
		-- The treasury is drained between the check and the tap.
		world.treasury:spend("crimson", { wood = Costs.starting.wood }, "drain", "spec")
		world:advance(0.1)
		build:confirm()
		world:advance(0.2)
		expect(build.placing).toBeTruthy()
		expect(build.placing.status).toBe("bad")
		expect(build.placing.reason).toBe("Not enough resources")
		expect(texts(hud.guis.notices)).toContain("Couldn't place the Farm")
		tap(find(find(hud.guis.hud, "PlacementBar"), "Cancel"))
		expect(build.placing).toBeNil()
		expect(world.log.modes[#world.log.modes]).toBe("explore")
	end)

	it("leaving build mode elsewhere (InputModeController) cancels placement", function()
		local build = world.buildMenu
		build:startPlacement("house")
		world.client:get("InputModeController"):set("explore")
		expect(build.placing).toBeNil()
		expect(build.ghost).toBeNil()
		build:startPlacement("house")
		tap(find(hud.guis.hud, "Menu_kingdom"))
		expect(build.placing).toBeNil()
	end)
end)

describe("Kingdom panel and keep upgrade", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("shows rulers and standings, then upgrades the keep after a large-spend confirmation", function()
		local world = newWorld({ treasury = { food = 120, wood = 300, stone = 300, gold = 0 } })
		local hud = world.hud
		world.kingdoms:addCrownPoints("azure", 20)
		world:advance(0.1)
		tap(find(hud.guis.hud, "Menu_kingdom"))
		local panel = find(hud.guis.menus, "KingdomPanel")
		local all = texts(panel)
		expect(all).toContain("Sam (you)")
		expect(all).toContain("Mira")
		expect(find(panel, "Standing_azure").LayoutOrder).toBe(1)
		expect(texts(find(panel, "Standing_emerald"))).toContain("Thornwood · AI")
		hud:panelTab("buildings")
		local keepRow = find(hud.guis.menus, "Building_1")
		expect(texts(keepRow)).toContain("Keep  Lv 1")
		tap(find(keepRow, "Upgrade"))
		local detail = find(hud.guis.menus, "Detail")
		expect(texts(detail)).toContain("Upgrade to Lv 2")
		tap(find(detail, "Cta"))
		-- 150 wood of 300 is half the stockpile: confirm first, nothing sent yet.
		expect(#world:callsNamed("Upgrade")).toBe(0)
		local modal = hud.guis.modals:FindFirstChildWhichIsA("Frame", true)
		expect(texts(hud.guis.modals)).toContain("Upgrade Keep?")
		expect(modal).toBeTruthy()
		hud:confirm()
		world:advance(0.2)
		local upgrades = world:callsNamed("Upgrade")
		expect(#upgrades).toBe(1)
		expect(upgrades[1].args[1]).toBe(1)
		expect(texts(hud.guis.notices)).toContain("Keep upgrade started")
		expect(amountOf(hud, "wood")).toBe(tostring(300 - Costs.building("keep", 2).cost.wood))
		expect(texts(find(hud.guis.hud, "Queue"))).toContain("Keep Lv 2")
		world:destroy()
	end)
end)

describe("Kingdom UI edge cases", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("stays hidden without a kingdom and appears with the treasury after a late join", function()
		local world = newWorld({ kingdom = false })
		local hud = world.hud
		expect(hud.guis.hud.Enabled).toBe(false)
		expect(hud.guis.menus.Enabled).toBe(false)
		world.kingdoms:join(world.player, "azure", nil, true) -- no Treasury.Changed push reaches us
		world:advance(0.2)
		expect(hud.guis.hud.Enabled).toBe(true)
		expect(texts(hud.guis.hud)).toContain("Frostmere")
		expect(amountOf(hud, "wood")).toBe(tostring(Costs.starting.wood))
		world:destroy()
	end)

	it("does not yield in start(): mounts once the PlayerGui appears", function()
		local world = newWorld({ noPlayerGui = true })
		local hud = world.hud
		expect(hud.guis.hud).toBeNil()
		local playerGui = world.env.newInstance("PlayerGui")
		playerGui.Parent = world.player
		world:advance(0.3)
		expect(hud.guis.hud).toBeTruthy()
		expect(hud.guis.hud.Parent).toBe(playerGui)
		world:destroy()
	end)

	it("uses NotificationController when present and works without InputModeController", function()
		local world = newWorld({ notifications = true, inputMode = false })
		local build = world.buildMenu
		build:startPlacement("house")
		build:aimAt(Vector3.new(120, 0, -60))
		world:advance(0.2)
		build:confirm()
		world:advance(0.2)
		expect(#world:callsNamed("Place")).toBe(1)
		expect(world.log.notices[1].title).toBe("House placed")
		expect(world.log.notices[1].kind).toBe("success")
		expect(world.hud.toasts:count()).toBe(0)
		world:destroy()
	end)

	it("phone: one pane at a time, a back link, and an X to cancel placing", function()
		local world = newWorld({ width = 750, height = 311 })
		local hud = world.hud
		expect(hud:metrics().breakpoint).toBe("phone")
		tap(find(hud.guis.hud, "Menu_build"))
		expect(find(hud.guis.menus, "Detail")).toBeNil()
		tap(find(hud.guis.menus, "Row_farm"))
		local detail = find(hud.guis.menus, "Detail")
		expect(find(hud.guis.menus, "BuildingList")).toBeNil()
		expect(texts(detail)).toContain("‹ Economy")
		tap(find(detail, "Back"))
		expect(find(hud.guis.menus, "BuildingList")).toBeTruthy()
		world.buildMenu:startPlacement("house")
		local cancel = find(find(hud.guis.hud, "PlacementBar"), "Cancel")
		expect(cancel:IsA("TextButton")).toBe(true) -- the icon X, not the worded button
		tap(cancel)
		expect(world.buildMenu.placing).toBeNil()
		world:destroy()
	end)
end)
