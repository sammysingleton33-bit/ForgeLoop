-- FORGE-05 review M1 on PR #25: open menus must survive server pushes and ghost moves. A push that
-- changes nothing on screen (another kingdom's building) leaves every instance alone; a push that
-- changes values (treasury, construction progress, the ghost's verdict) patches them in place, so
-- the button under the player's finger, the list scroll and the confirm dialog stay put.
-- Repro numbers from the review: R3 (200 PlacementBars for 200 ghost cells), R4 (a new BuildMenu
-- and CanvasPosition 0 after 3 pushes), R5 (a new Modal after a treasury push).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomWorld = require("./doubles/KingdomWorld")
local PlotPickerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/PlotPickerController")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local SlotDoubles = require("./doubles/SlotDoubles")
local UpgradePanelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/UpgradePanelController")

local function inputModeDef()
	return {
		name = "InputModeController",
		new = function()
			local c = { mode = "explore", changed = Signal.new(), selected = Signal.new() }
			function c:set(mode)
				self.mode = mode
				self.changed:fire(mode)
			end
			return c
		end,
	}
end

local function find(root, name)
	if root == nil then
		return nil
	end
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

local function newWorld(opts)
	local o = opts or {}
	o.remotes = SlotDoubles.REMOTES
	o.services = { SlotDoubles.service }
	o.clientDefinitions = { KingdomHudDef, BuildMenuDef, PlotPickerDef, UpgradePanelDef, inputModeDef() }
	local world = KingdomWorld.new(o)
	world.hud = world.client:get("KingdomHudController")
	world.buildMenu = world.client:get("BuildMenuController")
	world.picker = world.client:get("PlotPickerController")
	world.upgrade = world.client:get("UpgradePanelController")
	world.input = world.client:get("InputModeController")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

-- Another kingdom builds far away: nothing on this player's screen changes.
local function foreignPush(world)
	local id = world.build:add("azure", "house", 1, "planned", Vector3.new(900, 0, 900))
	world.build:push(id)
	world:advance(0.1)
	world.build:progress(id, 0.4, "constructing")
	world:advance(0.1)
end

local function cta(root)
	return find(find(root, "Cta"), "Face")
end

describe("Open menus survive pushes (M1)", function()
	local world, hud, previous
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

	it("R4: the build drawer keeps its instances, scroll and CTA while the treasury changes", function()
		world = newWorld({ treasury = { food = 120, wood = 5, stone = 0, gold = 0 } })
		hud = world.hud
		tap(find(hud.guis.hud, "Menu_build"))
		tap(find(hud.guis.menus, "Row_farm"))
		local menu = find(hud.guis.menus, "BuildMenu")
		local list = find(menu, "BuildingList")
		local row = find(list, "Row_farm")
		local face = cta(menu)
		expect(face:GetAttribute("cta")).toBe("disabled")
		list.CanvasPosition = Vector2.new(0, 40)

		foreignPush(world)
		expect(find(hud.guis.menus, "BuildMenu")).toBe(menu)
		expect(cta(menu)).toBe(face)

		-- The treasury now covers the farm: same CTA face, now ready, with the new balance shown.
		world.treasury:deposit("crimson", "wood", 200, "m1:wood", "test")
		world.treasury:deposit("crimson", "stone", 100, "m1:stone", "test")
		world:advance(0.1)
		expect(find(hud.guis.menus, "BuildMenu")).toBe(menu)
		expect(find(menu, "BuildingList")).toBe(list)
		expect(find(list, "Row_farm")).toBe(row)
		expect(list.CanvasPosition).toBe(Vector2.new(0, 40))
		expect(cta(menu)).toBe(face)
		expect(face:GetAttribute("cta")).toBe("ready")
		expect(find(find(menu, "Cost_wood"), "Have").Text).toBe("✓ 205")

		-- Selecting another building swaps the detail, not the list.
		tap(find(list, "Row_quarry"))
		expect(find(hud.guis.menus, "BuildMenu")).toBe(menu)
		expect(find(menu, "BuildingList")).toBe(list)
		expect(list.CanvasPosition).toBe(Vector2.new(0, 40))
		expect(find(find(list, "Row_quarry"), "Accent")).toBeTruthy()
		expect(find(find(list, "Row_farm"), "Accent")).toBeNil()

		-- The face that stayed still answers the tap with the newest detail.
		tap(cta(menu))
		expect(world.buildMenu.placing).toBeTruthy()
		expect(world.buildMenu.placing.type).toBe("quarry")
	end)

	it("R3: the placement bar keeps its buttons while the ghost moves", function()
		world = newWorld({ treasury = { food = 120, wood = 500, stone = 500, gold = 0 } })
		hud = world.hud
		local build = world.buildMenu
		build:startPlacement("house")
		world:advance(0.1)
		local bar = find(hud.guis.hud, "PlacementBar")
		expect(bar).toBeTruthy()
		local place = find(find(bar, "Place"), "Face")
		local status = find(bar, "Status")
		for i = 1, 20 do
			build:aimAt(Vector3.new(40 + i * 2, 0, 100))
			world:advance(0.05)
		end
		world:advance(0.2)
		expect(find(hud.guis.hud, "PlacementBar")).toBe(bar)
		expect(find(find(bar, "Place"), "Face")).toBe(place)
		expect(find(bar, "Status")).toBe(status)
		expect(status:GetAttribute("status")).toBe("ok")
		expect(place:GetAttribute("cta")).toBe("ready")
		foreignPush(world)
		expect(find(hud.guis.hud, "PlacementBar")).toBe(bar)
		-- A bad spot patches the same status line and disables the same button.
		build:aimAt(Vector3.new(500, 0, 0))
		world:advance(0.2)
		expect(find(hud.guis.hud, "PlacementBar")).toBe(bar)
		expect(status:GetAttribute("status")).toBe("bad")
		expect(place:GetAttribute("cta")).toBe("disabled")
		build:aimAt(Vector3.new(100, 0, 100))
		world:advance(0.2)
		tap(place)
		world:advance(0.2)
		expect(#world:callsNamed("Place")).toBe(1)
	end)

	it("R5: the confirm dialog stays the same while the treasury changes, and still confirms", function()
		world = newWorld({ treasury = { food = 120, wood = 300, stone = 300, gold = 0 } })
		hud = world.hud
		tap(find(hud.guis.hud, "Menu_kingdom"))
		hud:panelTab("buildings")
		tap(find(find(hud.guis.menus, "Building_1"), "Upgrade"))
		tap(find(hud.guis.menus, "Cta"))
		local modal = hud._modal
		expect(modal).toBeTruthy()
		local instance = modal.instance
		world.treasury:deposit("crimson", "food", 5, "m1:food", "test")
		world:advance(0.1)
		foreignPush(world)
		expect(hud._modal).toBe(modal)
		expect(instance.Parent).toBe(hud.roots.modals)
		tap(modal.confirm.face)
		world:advance(0.2)
		expect(#world:callsNamed("Upgrade")).toBe(1)
		expect(hud._modal).toBeNil()
	end)

	it("the Kingdom panel keeps its building rows while construction progresses", function()
		world = newWorld()
		hud = world.hud
		local id = world.build:add("crimson", "house", 1, "planned", Vector3.new(40, 0, 40))
		world.build:push(id)
		world:advance(0.1)
		tap(find(hud.guis.hud, "Menu_kingdom"))
		hud:panelTab("buildings")
		local panel = find(hud.guis.menus, "KingdomPanel")
		local row = find(panel, "Building_" .. id)
		local keepUpgrade = find(find(panel, "Building_1"), "Face")
		world.build:progress(id, 0.5, "constructing")
		world:advance(0.1)
		world.build:progress(id, 0.7, "constructing")
		world:advance(0.1)
		foreignPush(world)
		expect(find(hud.guis.menus, "KingdomPanel")).toBe(panel)
		expect(find(panel, "Building_" .. id)).toBe(row)
		expect(find(row, "Value").Text).toBe("70%")
		expect(find(find(panel, "Building_1"), "Face")).toBe(keepUpgrade)
	end)

	it("FL-0087: the plot picker and the upgrade panel keep their CTA across pushes", function()
		world = newWorld({ treasury = { food = 120, wood = 5, stone = 0, gold = 0 } })
		hud = world.hud
		world.input.selected:fire("slot", "m1")
		world:advance(0.1)
		local menu = find(hud.guis.menus, "PlotPicker")
		local face = cta(menu)
		expect(face:GetAttribute("cta")).toBe("disabled")
		world.treasury:deposit("crimson", "wood", 200, "m1:wood", "test")
		world.treasury:deposit("crimson", "stone", 100, "m1:stone", "test")
		world:advance(0.1)
		foreignPush(world)
		expect(find(hud.guis.menus, "PlotPicker")).toBe(menu)
		expect(cta(menu)).toBe(face)
		expect(face:GetAttribute("cta")).toBe("ready")
		-- The face built while it was disabled acts on the patched detail.
		tap(face)
		world:advance(0.2)
		expect(#world:callsNamed("PlaceSlot")).toBe(1)

		world.input.selected:fire("building", 1)
		world:advance(0.1)
		local panel = find(hud.guis.menus, "UpgradePanel")
		local upgradeFace = cta(panel)
		world.treasury:deposit("crimson", "food", 5, "m1:food", "test")
		world:advance(0.1)
		foreignPush(world)
		expect(find(hud.guis.menus, "UpgradePanel")).toBe(panel)
		expect(cta(panel)).toBe(upgradeFace)
	end)
end)

describe("HUD lifecycle (FORGE-05 L5, L6)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("L5: after destroy the store stops following the server", function()
		local world = newWorld()
		local hud = world.hud
		local food = hud.store:balances().food
		hud:destroy()
		world.treasury:deposit("crimson", "food", 25, "l5:food", "test")
		world:advance(0.2)
		expect(hud.store:balances().food).toBe(food)
		world:destroy()
	end)

	it("L6: a PlayerGui that appears after destroy gets no HUD", function()
		local world = newWorld({ noPlayerGui = true })
		local hud = world.hud
		hud:destroy()
		local playerGui = world.env.newInstance("PlayerGui")
		playerGui.Parent = world.player
		world:advance(0.3)
		expect(hud.guis.hud).toBeNil()
		expect(#playerGui:GetChildren()).toBe(0)
		world:destroy()
	end)
end)
