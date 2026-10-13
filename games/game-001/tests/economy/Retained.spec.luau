-- FORGE-05 review M1 on PR #25: open menus must survive server pushes and ghost moves. A push that
-- changes nothing on screen (another kingdom's building) leaves every instance alone; a push that
-- changes values (treasury, construction progress, the ghost's verdict) patches them in place, so
-- the button under the player's finger, the list scroll and the confirm dialog stay put.
-- Repro numbers from the review: R3 (200 PlacementBars for 200 ghost cells), R4 (a new BuildMenu
-- and CanvasPosition 0 after 3 pushes), R5 (a new Modal after a treasury push).
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildMenuDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/BuildMenuController")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
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

describe("Follow-ups from the #41 review (FORGE-05)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("a finished building's state and level are patched or rebuilt, never left stale", function()
		local world = newWorld()
		local hud = world.hud
		-- A house at its highest level: no Upgrade button either way, so damaged keeps the layout
		-- (FORGE-05's repro).
		local top = Costs.maxLevel("house")
		local house = world.build:add("crimson", "house", top, "complete", Vector3.new(40, 0, 40))
		world.build:push(house)
		world:advance(0.1)
		tap(find(hud.guis.hud, "Menu_kingdom"))
		hud:panelTab("buildings")
		local panel = find(hud.guis.menus, "KingdomPanel")
		local row = find(panel, "Building_" .. house)
		expect(find(row, "Sub").Text).toBe("Complete")
		world.build:progress(house, 1, "damaged")
		world:advance(0.1)
		expect(find(panel, "Building_" .. house)).toBe(row) -- same layout: patched in place
		expect(find(row, "Sub").Text).toBe("Damaged")
		-- A level is part of the layout: the row is rebuilt and says the new level.
		local keep = find(panel, "Building_1")
		expect(find(keep, "Title").Text).toContain("Lv 1")
		world.build.buildings[1].level = 2
		world.build:push(1)
		world:advance(0.1)
		expect(find(find(panel, "Building_1"), "Title").Text).toContain("Lv 2")
		world:destroy()
	end)

	it("the confirm dialog follows the breakpoint and closes when a co-ruler upgrades the building", function()
		local world = newWorld({ treasury = { food = 120, wood = 300, stone = 300, gold = 0 } })
		local hud = world.hud
		tap(find(hud.guis.hud, "Menu_kingdom"))
		hud:panelTab("buildings")
		tap(find(find(hud.guis.menus, "Building_1"), "Upgrade"))
		tap(find(hud.guis.menus, "Cta"))
		local function cardWidth()
			for _, d in hud._modal.instance:GetDescendants() do
				if d:IsA("Frame") and (d.Size.X.Offset == 340 or d.Size.X.Offset == 400) then
					return d.Size.X.Offset
				end
			end
			return nil
		end
		expect(cardWidth()).toBe(400)
		hud:setViewport(844, 390)
		world:advance(0.1)
		expect(hud._modal).toBeTruthy()
		expect(cardWidth()).toBe(340) -- 400 px would not fit a 390 px tall phone's width budget
		-- Mira upgrades the keep meanwhile: the question no longer holds, so the dialog closes.
		world.build.buildings[1].level = 2
		world.build:push(1)
		world:advance(0.1)
		expect(hud._modal).toBeNil()
		expect(hud.state.confirm).toBeNil()
		-- and says why, so the vanished dialog is not a mystery (FORGE-05 #58 follow-up 6)
		local said = {}
		for _, d in hud.guis.notices:GetDescendants() do
			if d:IsA("TextLabel") then
				table.insert(said, d.Text)
			end
		end
		expect(table.concat(said, " | ")).toContain("Keep changed")
		expect(#world:callsNamed("Upgrade")).toBe(0)
		world:destroy()
	end)

	it("the confirm dialog closes, sending nothing, when its building is damaged (#58 follow-up 2)", function()
		local world = newWorld({ treasury = { food = 120, wood = 300, stone = 300, gold = 0 } })
		local hud = world.hud
		tap(find(hud.guis.hud, "Menu_kingdom"))
		hud:panelTab("buildings")
		tap(find(find(hud.guis.menus, "Building_1"), "Upgrade"))
		tap(find(hud.guis.menus, "Cta"))
		expect(hud._modal).toBeTruthy()
		local before = world.treasury:get("crimson")
		world.build:progress(1, 1, "damaged")
		world:advance(0.1)
		expect(hud._modal).toBeNil()
		expect(hud.state.confirm).toBeNil()
		hud:confirm() -- a late tap on the old dialog's button
		world:advance(0.2)
		expect(#world:callsNamed("Upgrade")).toBe(0)
		expect(world.treasury:get("crimson").wood).toBe(before.wood)
		world:destroy()
	end)

	it("Build.Slots replicating only after destroy: the picker never listens or fetches (#58 follow-up 1)", function()
		-- A HUD double whose remotes:on yields until the remote "replicates", as on a slow join.
		local release
		local disconnected, fetched, applied = 0, 0, 0
		local hudDouble = {
			rendered = Signal.new(),
			menuChanged = Signal.new(),
			state = {},
			store = {
				applySlots = function()
					applied += 1
				end,
			},
			remotes = {
				on = function(_, _name, _fn)
					release = coroutine.running()
					coroutine.yield()
					return {
						Disconnect = function()
							disconnected += 1
						end,
					}
				end,
				invoke = function()
					fetched += 1
					return {}
				end,
			},
		}
		local env = {
			spawn = function(fn)
				coroutine.wrap(fn)()
			end,
			log = function() end,
			clock = os.clock,
		}
		local registry = {
			get = function()
				return hudDouble
			end,
			find = function()
				return nil
			end,
		}
		local picker = PlotPickerDef.new(env, registry)
		picker:start()
		expect(release).toBeTruthy() -- waiting for Build.Slots
		picker:destroy()
		assert(coroutine.resume(release)) -- the remote appears now
		expect(disconnected).toBe(1) -- its connection is dropped at once
		expect(fetched).toBe(0) -- and Build.GetSlots is never called
		expect(applied).toBe(0)
	end)

	it("the plot picker stops following Build.Slots after destroy", function()
		local world = newWorld()
		world.picker:destroy()
		world.server:get("SlotService"):occupy("m1", 77)
		world:advance(0.1)
		expect(world.hud.store:slot("m1").occupiedBy).toBeNil()
		world:destroy()
	end)
end)
