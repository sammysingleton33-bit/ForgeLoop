-- FL-0087: plot picker and upgrade panel. Models (slot fit, plot menu, level benefits, D-030
-- costs) and end to end: the real KingdomHudController, PlotPickerController and
-- UpgradePanelController over the framework RemoteService against the real TreasuryService,
-- FORGE-01 doubles (doubles/KingdomWorld + doubles/SlotDoubles) and a FORGE-04 selection double.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local BuildModel = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/BuildModel")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local KingdomHudDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/KingdomHudController")
local KingdomStore = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/KingdomStore")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local KingdomWorld = require("./doubles/KingdomWorld")
local PlotPickerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/PlotPickerController")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local SlotDoubles = require("./doubles/SlotDoubles")
local SlotFit = require("@game/StarterPlayer/StarterPlayerScripts/Game/UI/SlotFit")
local UpgradePanelDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/UpgradePanelController")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

-- FORGE-04's selection signal (G13.6) as a double, modelled on the real InputModeController:
-- select(kind, id) remembers and fires; entering build mode clears a selection with
-- selected("none", "") so open panels close while placing (FORGE-05 L3).
local function inputModeDef()
	return {
		name = "InputModeController",
		new = function()
			local c = {
				mode = "explore",
				changed = Signal.new(),
				selected = Signal.new(),
				selection = { kind = "none", id = "" },
			}
			function c:select(kind, id)
				self.selection = { kind = kind, id = if id == nil then "" else id }
				self.selected:fire(kind, self.selection.id)
			end
			function c:set(mode)
				if self.mode == mode then
					return
				end
				self.mode = mode
				self.changed:fire(mode)
				if mode == "build" and self.selection.kind ~= "none" then
					self:select("none", "")
				end
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

local function texts(root)
	local out = {}
	if root == nil then
		return ""
	end
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

local function newWorld(opts)
	local o = opts or {}
	o.remotes = SlotDoubles.REMOTES
	o.services = { SlotDoubles.service }
	o.clientDefinitions = { KingdomHudDef, PlotPickerDef, UpgradePanelDef, inputModeDef() }
	local world = KingdomWorld.new(o)
	world.hud = world.client:get("KingdomHudController")
	world.picker = world.client:get("PlotPickerController")
	world.upgrade = world.client:get("UpgradePanelController")
	world.input = world.client:get("InputModeController")
	world.slots = world.server:get("SlotService")
	world.hud:setViewport(o.width or 1920, o.height or 1022)
	world:advance(0.2)
	return world
end

local function pick(world, kind, id)
	world.input:select(kind, id)
	world:advance(0.1)
end

describe("Plot models (FL-0087)", function()
	it("fits structures to FORGE-02's real slot sizes, not to a size guess (M2)", function()
		-- The world Layout's slots (S 24×20, M 36×30, L 46×40): each type's biggest footprint over its
		-- levels must fit width and depth. Checked against Layout and Kit here, not against the double.
		local sizes = WorldLayout.slotSizes
		expect(sizes.S).toBe(Vector2.new(24, 20))
		expect(sizes.M).toBe(Vector2.new(36, 30))
		expect(sizes.L).toBe(Vector2.new(46, 40))
		for _, t in SlotFit.TYPES do
			for _, size in { "S", "M", "L" } do
				local fits = true
				for level = 1, math.max(1, Costs.maxLevel(t)) do
					local fp = Kit.footprint(t, level)
					fits = fits and fp.X <= sizes[size].X and fp.Y <= sizes[size].Y
				end
				expect(SlotFit.fits({ size = size }, t)).toBe(fits)
			end
		end
		-- What that means with the D-030 footprints (house 22×18 at Lv 2, barracks 34×22, farm 40×32):
		for _, t in { "house", "lumbercamp", "quarry", "storehouse", "watchtower" } do
			expect(SlotFit.sizeOf(t)).toBe("S")
		end
		expect(SlotFit.sizeOf("barracks")).toBe("M")
		expect(SlotFit.sizeOf("farm")).toBe("L")
		expect(table.concat(SlotFit.typesFor({ size = "S" }), ",")).toBe(
			"house,lumbercamp,quarry,storehouse,watchtower"
		)
		expect(table.concat(SlotFit.typesFor({ size = "M" }), ",")).toBe(
			"house,lumbercamp,quarry,storehouse,barracks,watchtower"
		)
		expect(#SlotFit.typesFor({ size = "L" })).toBe(#SlotFit.TYPES)
		-- the server's own list wins when it sends one (proposed additive field)
		expect(table.concat(SlotFit.typesFor({ size = "S", fits = { "house" } }), ",")).toBe("house")
		expect(#SlotFit.typesFor({ size = "XL" })).toBe(0)
		-- the double's server agrees with the client for every plot type and size
		for _, t in SlotFit.TYPES do
			for _, size in { "S", "M", "L" } do
				expect(SlotDoubles.fits(size, t)).toBe(SlotFit.fits({ size = size }, t))
			end
		end
	end)

	it("builds the plot menu with costs, time, what it gives and a slot CTA", function()
		local store = KingdomStore.new()
		store:applyKingdoms({ mine = "crimson", kingdoms = { { id = "crimson", name = "Emberhold", rulers = { 1 } } } })
		store:applyTreasury({ food = 120, wood = 100, stone = 50, gold = 0 })
		local view = BuildModel.plotMenu(store, { slot = { id = "m1", size = "M" }, selected = "lumbercamp" })
		expect(view.tabs[1].label).toBe("Medium plot")
		expect(#view.rows).toBe(6) -- house, lumber camp, quarry, storehouse, barracks, watchtower
		expect(view.detail.cta.text).toBe("Build Lumber Camp here")
		expect(view.detail.action).toBe("slot")
		expect(view.detail.slotId).toBe("m1")
		expect(view.detail.meta).toBe("Economy · Medium plot")
		expect(view.detail.benefits[1].text).toBe("Woodcutters fell trees nearby")
		local large = BuildModel.plotMenu(store, { slot = { id = "l1", size = "L" }, selected = "barracks" })
		expect(large.detail.cta.state).toBe("disabled")
		expect(large.detail.cta.text).toBe("Need 20 Wood and 10 Stone")
		local pending = BuildModel.plotMenu(store, { slot = { id = "m1", size = "M" }, pending = true })
		expect(pending.detail.cta.state).toBe("loading")
		expect(BuildModel.plotMenu(store, { slot = nil })).toBeNil()
	end)

	it("shows what a building gives now and what the next level adds", function()
		local store = KingdomStore.new()
		store:applyKingdoms({ mine = "crimson", kingdoms = { { id = "crimson", name = "Emberhold", rulers = { 1 } } } })
		store:applyTreasury({ food = 0, wood = 1000, stone = 1000, gold = 0 })
		local up = BuildModel.upgradeDetail(store, { id = 9, type = "barracks", level = 1, state = "complete" })
		expect(up.benefits[1].label).toBe("Now")
		expect(up.benefits[1].text).toBe("Recruit up to 5 soldiers")
		expect(up.benefits[2].label).toBe("Lv 2")
		expect(up.benefits[2].next).toBe(true)
		expect(up.buildSeconds).toBe(18)
		local top = BuildModel.upgradeDetail(store, { id = 9, type = "barracks", level = 4, state = "complete" })
		expect(#top.benefits).toBe(1)
		expect(top.buildSeconds).toBeNil()
		expect(top.cta.text).toBe("Highest level reached")
	end)

	it("prices the D-030 levels; barracks build times are the user's 8 / 18 / 35 / 60 s", function()
		expect(Costs.maxLevel("barracks")).toBe(4)
		for level, seconds in { 8, 18, 35, 60 } do
			expect(Costs.building("barracks", level).buildSeconds).toBe(seconds)
		end
		expect(Costs.maxLevel("farm")).toBe(3)
		expect(Costs.maxLevel("lumbercamp")).toBe(3)
		expect(Costs.maxLevel("quarry")).toBe(3)
		expect(Costs.maxLevel("watchtower")).toBe(2)
		expect(Costs.building("keep", 2).cost.wood).toBe(150) -- the VS-1 path is unchanged
	end)
end)

describe("Plot picker and upgrade panel end to end (FL-0087)", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("tapping a free plot lists what fits, builds there once, then the plot opens the upgrade panel", function()
		local world = newWorld({ latency = 0.1 })
		local hud = world.hud
		pick(world, "slot", "m1")
		expect(hud.state.menu).toBe("plot")
		local picker = find(hud.guis.menus, "PlotPicker")
		expect(picker).toBeTruthy()
		expect(texts(picker)).toContain("Medium plot")
		expect(find(picker, "Row_farm")).toBeNil() -- an L structure does not fit an M plot
		tap(find(picker, "Row_lumbercamp"))
		local detail = find(hud.guis.menus, "Detail")
		expect(texts(detail)).toContain("Woodcutters fell trees nearby")
		local cta = find(detail, "Cta")
		expect(texts(cta)).toContain("Build Lumber Camp here")
		local ready = BuildModel.plotMenu(hud.store, { slot = hud.store:slot("m1"), selected = "lumbercamp" }).detail
		tap(cta)
		world.picker:place(ready) -- a second tap before the reply sends nothing
		expect(texts(find(hud.guis.menus, "Cta"))).toContain("Starting")
		world:advance(0.2)
		local calls = world:callsNamed("PlaceSlot")
		expect(#calls).toBe(1)
		expect(calls[1].args[1]).toBe("m1")
		expect(calls[1].args[2]).toBe("lumbercamp")
		expect(texts(hud.guis.notices)).toContain("Lumber Camp ordered")
		expect(hud.state.menu).toBeNil()
		expect(world.treasury:get("crimson").wood).toBe(Costs.starting.wood - Costs.building("lumbercamp", 1).cost.wood)
		-- the plot is built on now: tapping it opens the building's upgrade panel
		expect(hud.store:slot("m1").occupiedBy).toBeTruthy()
		pick(world, "slot", "m1")
		expect(hud.state.menu).toBe("upgrade")
		expect(texts(find(hud.guis.menus, "UpgradePanel"))).toContain("Finish building it first")
		world:destroy()
	end)

	it("explains a refusal from Build.PlaceSlot and keeps the picker open", function()
		local world = newWorld()
		local hud = world.hud
		pick(world, "slot", "m1")
		world.picker:select("house")
		world.treasury:spend("crimson", { wood = Costs.starting.wood }, "drain", "spec")
		world:advance(0.1)
		-- the menu now shows the shortfall; force the old detail through to reach the server
		local stale = BuildModel.plotMenu(world.hud.store, { slot = { id = "m1", size = "M" }, selected = "house" })
		expect(stale.detail.cta.state).toBe("disabled")
		world.treasury:deposit("crimson", "wood", 100, "refill", "spec")
		world:advance(0.1)
		local ready =
			BuildModel.plotMenu(world.hud.store, { slot = { id = "m1", size = "M" }, selected = "house" }).detail
		world.treasury:spend("crimson", { wood = 100 }, "drain2", "spec") -- spent before the request arrives
		world.picker:place(ready)
		world:advance(0.2)
		expect(#world:callsNamed("PlaceSlot")).toBe(1)
		expect(texts(hud.guis.notices)).toContain("Couldn't build here")
		expect(texts(hud.guis.notices)).toContain("Not enough resources")
		expect(hud.state.menu).toBe("plot")
		world:destroy()
	end)

	it("upgrades a tapped building with its next level's cost, time and benefits", function()
		local world = newWorld({ treasury = { food = 100, wood = 1000, stone = 1000, gold = 0 } })
		local hud = world.hud
		local barracks = world.build:add("crimson", "barracks", 1, "complete", Vector3.new(150, 0, 150))
		world.build:push(barracks)
		world:advance(0.1)
		-- a tap's id comes from the `BuildingId` attribute: number or string both open the panel
		pick(world, "building", tostring(barracks))
		local panel = find(hud.guis.menus, "UpgradePanel")
		local all = texts(panel)
		expect(all).toContain("Barracks · Lv 1")
		expect(all).toContain("Recruit up to 5 soldiers")
		expect(all).toContain("Recruit up to 10")
		expect(all).toContain("0:18 with builders")
		tap(find(panel, "Cta"))
		world:advance(0.2)
		local upgrades = world:callsNamed("Upgrade")
		expect(#upgrades).toBe(1)
		expect(upgrades[1].args[1]).toBe(barracks)
		expect(texts(hud.guis.notices)).toContain("Barracks upgrade started")
		world:destroy()
	end)

	it("shows another kingdom's building read-only and closes on other selections", function()
		local world = newWorld()
		local hud = world.hud
		local theirs = world.build:add("azure", "barracks", 2, "complete", Vector3.new(1500, 0, 0))
		world.build:push(theirs)
		world:advance(0.1)
		pick(world, "building", theirs)
		local panel = find(hud.guis.menus, "UpgradePanel")
		expect(texts(panel)).toContain("Frostmere · Level 2")
		expect(texts(panel)).toContain("Not your building")
		expect(find(find(panel, "Cta"), "Face"):GetAttribute("cta")).toBe("disabled")
		pick(world, "citizen", 12)
		expect(hud.state.menu).toBeNil()
		pick(world, "slot", "s1")
		expect(hud.state.menu).toBe("plot")
		expect(texts(find(hud.guis.menus, "PlotPicker"))).toContain("Watchtower")
		pick(world, "none", "")
		expect(hud.state.menu).toBeNil()
		world:destroy()
	end)

	it("L2: reopening a plot while its order is on the way never sends a second one", function()
		local world = newWorld({ latency = 0.3 })
		local hud = world.hud
		pick(world, "slot", "m1")
		local ready = BuildModel.plotMenu(hud.store, { slot = hud.store:slot("m1"), selected = "house" }).detail
		world.picker:place(ready)
		pick(world, "slot", "s1") -- look elsewhere…
		pick(world, "slot", "m1") -- …and come back before the reply
		local face = find(find(hud.guis.menus, "Cta"), "Face")
		expect(face:GetAttribute("cta")).toBe("loading")
		world.picker:place(ready)
		world:advance(0.5)
		expect(#world:callsNamed("PlaceSlot")).toBe(1)
		expect(texts(hud.guis.notices)).toContain("House ordered")
		expect(texts(hud.guis.notices)).never.toContain("Couldn't build here")
		world:destroy()
	end)

	it("names the plot in a refusal: a plot built on meanwhile is 'already built on'", function()
		local world = newWorld()
		local hud = world.hud
		pick(world, "slot", "m1")
		local ready = BuildModel.plotMenu(hud.store, { slot = hud.store:slot("m1"), selected = "house" }).detail
		world.slots.slots.m1.occupiedBy = 999 -- another ruler of the kingdom got there first (no push yet)
		world.picker:place(ready)
		world:advance(0.2)
		expect(texts(hud.guis.notices)).toContain("This plot is already built on")
		world:destroy()
	end)

	it("L3: entering build mode clears the selection and closes the picker and the upgrade panel", function()
		local world = newWorld()
		local hud = world.hud
		pick(world, "slot", "m1")
		expect(hud.state.menu).toBe("plot")
		world.input:set("build")
		world:advance(0.1)
		expect(hud.state.menu).toBeNil()
		world.input:set("explore")
		pick(world, "building", 1)
		expect(hud.state.menu).toBe("upgrade")
		world.input:set("build")
		world:advance(0.1)
		expect(hud.state.menu).toBeNil()
		world:destroy()
	end)

	it("phone: the plot list first, then the detail with a way back", function()
		local world = newWorld({ width = 750, height = 311 })
		local hud = world.hud
		pick(world, "slot", "l1")
		expect(find(hud.guis.menus, "Detail")).toBeNil()
		tap(find(hud.guis.menus, "Row_farm"))
		local detail = find(hud.guis.menus, "Detail")
		expect(texts(detail)).toContain("‹ Large plot")
		expect(texts(detail)).toContain("Build Farm here")
		world:destroy()
	end)
end)
