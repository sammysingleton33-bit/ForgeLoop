--[[
	End to end, headless: the real UIController + EconomyTreasuryService, wired through the
	MockRemotes network to the FORGE-01 doubles (KingdomService / KingdomController / RemoteService).
	Taps are simulated with Create.fire on the actual buttons the player would press.
]]
local T = require("../../harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Create = require("@game/StarterPlayer/StarterPlayerScripts/Forge/UI/Create")
local UIControllerDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/UIController")
local KingdomWorld = require("../economy/doubles/KingdomWorld")

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
	for _, d in root:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			if d.Text ~= "" then
				table.insert(out, d.Text)
			end
		end
	end
	return table.concat(out, " | ")
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = if instance:FindFirstChild("Face") then instance.Face else instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

local function label(button)
	local l = find(button, "Label")
	return if l then l.Text else ""
end

local function cta(ui)
	local menu = find(ui.guis.menus, "BuildMenu") or find(ui.guis.menus, "KingdomPanel")
	local detail = find(menu, "Detail")
	return detail and find(detail, "Face")
end

describe("AI Kingdoms UI end to end (desktop)", function()
	local world, ui, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = KingdomWorld.new({ clientDefinitions = { UIControllerDef } })
		ui = world.client:get("UIController")
		ui:setViewport(1920, 1022)
		world:advance(0)
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("mounts the HUD in the documented DisplayOrder bands and safe areas", function()
		expect(ui.guis.hud.DisplayOrder).toBe(10)
		expect(ui.guis.hud.ScreenInsets).toBe(Enum.ScreenInsets.CoreUISafeInsets)
		expect(ui.guis.topbar.ScreenInsets).toBe(Enum.ScreenInsets.TopbarSafeInsets)
		expect(ui.guis.menus.DisplayOrder).toBe(20)
		expect(ui.guis.modals.DisplayOrder).toBe(40)
		expect(ui.guis.notices.DisplayOrder).toBe(70)
		expect(ui.guis.hud.Parent:IsA("PlayerGui")).toBe(true)
		expect(ui.guis.hud.Root.Scale.Scale).toBeNear(1.2, 0.01)
	end)

	it("1. shows the kingdom's resources and citizens from the server", function()
		expect(find(ui.hud.pills.food.instance, "Amount").Text).toContain("100")
		expect(find(ui.hud.pills.wood.instance, "Amount").Text).toContain("150")
		expect(find(ui.hud.pills.wood.instance, "Amount").Text).toContain("/ 500")
		expect(find(ui.hud.pills.citizens.instance, "Amount").Text).toContain("6")
		expect(texts(ui.guis.hud)).toContain("Aldmere")
		expect(texts(ui.guis.hud)).toContain("Town Hall Lv 1")
	end)

	it("2-6. opens Build, selects a building, shows its costs, builds it and confirms visibly", function()
		tap(find(ui.guis.hud, "Menu_build"))
		expect(ui.state.menu).toBe("build")
		expect(find(ui.guis.menus, "BuildMenu")).toBeTruthy()

		tap(find(ui.guis.menus, "Row_quarry"))
		local detail = find(ui.guis.menus, "Detail")
		local shown = texts(detail)
		expect(shown).toContain("Quarry")
		expect(shown).toContain("Wood")
		expect(shown).toContain("50")
		expect(shown).toContain("✓ 150")
		expect(shown).toContain("+12/min")
		expect(cta(ui):GetAttribute("cta")).toBe("ready")
		expect(label(cta(ui))).toBe("Build Quarry")

		tap(cta(ui))
		world:advance(0)
		-- the server spent exactly the cost, once
		expect(world.treasury:balances(world.kingdomId)).toEqual({ food = 80, wood = 100, stone = 50, gold = 50 })
		-- visual confirmation: pill values + floating deltas, success CTA, paid row, toast, queue chip
		expect(find(ui.hud.pills.wood.instance, "Amount").Text).toContain("100")
		expect(find(ui.hud.pills.wood.instance, "Delta").Text).toBe("−50")
		expect(find(ui.hud.pills.food.instance, "Delta").Text).toBe("−20")
		expect(cta(ui):GetAttribute("cta")).toBe("done")
		expect(texts(find(ui.guis.menus, "Detail"))).toContain("Paid 20 Food · 50 Wood")
		expect(texts(ui.guis.notices)).toContain("Quarry construction started")
		local chip = find(ui.guis.hud, "Queue")
		expect(texts(chip)).toContain("Quarry")

		world:advance(20) -- construction completes server-side
		expect(texts(find(ui.guis.hud, "Queue"))).toBe("")
		expect(find(ui.guis.menus, "Row_quarry").Right.Text).toBe("1/3")
	end)

	it("explains shortfalls and locks, and a disabled button sends nothing", function()
		world.treasury:spend(world.kingdomId, { wood = 130 }, "drain", "test")
		world:advance(0)
		ui:openMenu("build")
		tap(find(ui.guis.menus, "Row_farm"))
		expect(cta(ui):GetAttribute("cta")).toBe("disabled")
		expect(label(cta(ui))).toBe("Need 20 more Wood")
		expect(texts(find(ui.guis.menus, "Detail"))).toContain("have 20")
		Create.fire(cta(ui), "Activated")
		world:advance(0)
		expect(world.treasury:balances(world.kingdomId).wood).toBe(20)
		tap(find(ui.guis.menus, "Row_goldmine"))
		expect(label(cta(ui))).toBe("Requires Town Hall Lv 2")
	end)

	it("reports a server refusal as an error toast without changing balances", function()
		ui:openMenu("build")
		tap(find(ui.guis.menus, "Row_quarry"))
		local BuildMenuModel = require("@game/StarterPlayer/StarterPlayerScripts/Forge/UI/Kingdom/BuildMenuModel")
		local stale = BuildMenuModel.build(ui:_input()).detail
		expect(stale.cta.state).toBe("ready")
		-- another member spends the wood between the player's look and tap: the server re-checks
		world.treasury:spend(world.kingdomId, { wood = 140 }, "race", "test")
		ui:requestBuild(stale)
		world:advance(0)
		expect(texts(ui.guis.notices)).toContain("Couldn't start construction")
		expect(texts(ui.guis.notices)).toContain("Not enough resources")
		expect(world.treasury:balances(world.kingdomId).wood).toBe(10)
	end)

	it("shows citizens and buildings, assigns workers, and upgrades with a confirmation", function()
		local _, _, uid = world.kingdom:build(world.player, "farm")
		world:advance(16)
		tap(find(ui.guis.hud, "Menu_kingdom"))
		expect(texts(ui.guis.menus)).toContain("Kingdom of Aldmere")
		expect(texts(ui.guis.menus)).toContain("Idle 6")
		tap(find(ui.guis.menus, "Tab_buildings"))
		local farmRow = find(ui.guis.menus, "Building_" .. uid)
		expect(texts(farmRow)).toContain("Farm")
		expect(find(farmRow, "Workers").Text).toBe("0/3")
		tap(find(farmRow, "Plus"))
		world:advance(0)
		expect(find(find(ui.guis.menus, "Building_" .. uid), "Workers").Text).toBe("1/3")

		world.treasury:grant(world.kingdomId, { wood = 50, stone = 60 }, "gift", "test")
		world:advance(0)
		local hallRow = find(ui.guis.menus, "Building_u1")
		tap(find(hallRow, "Upgrade"))
		expect(label(cta(ui))).toBe("Upgrade to Lv 2")
		tap(cta(ui))
		expect(find(ui.guis.modals, "Modal")).toBeTruthy() -- a large spend asks first
		tap(find(ui.guis.modals, "Modal").Panel:FindFirstChild("Content").Buttons:GetChildren()[3])
		world:advance(0)
		expect(texts(ui.guis.notices)).toContain("Town Hall upgrade started")
		expect(world.treasury:balances(world.kingdomId).stone).toBe(10)
	end)

	it("shows the match timer in the top bar from Gameplay.RoundState", function()
		world.remotes:fireAll("Gameplay.RoundState", "Active", "r1", world.env.serverTimeNow() + 872, 6)
		world:advance(0)
		local timer = find(ui.guis.topbar, "Timer")
		expect(timer.Visible).toBe(true)
		expect(texts(timer)).toContain("14:32")
		expect(texts(timer)).toContain("until the match ends")
		world:advance(2)
		expect(texts(find(ui.guis.topbar, "Timer"))).toContain("14:30")
	end)
end)

describe("AI Kingdoms UI end to end (phone)", function()
	local world, ui, previous
	beforeEach(function()
		previous = Create.useTestConnector()
		world = KingdomWorld.new({ clientDefinitions = { UIControllerDef } })
		ui = world.client:get("UIController")
		ui:setViewport(750, 311)
		world:advance(0)
	end)
	afterEach(function()
		world:destroy()
		Create.setConnector(previous)
	end)

	it("uses compact pills and a single-pane drawer: list, detail, back", function()
		expect(ui.hud.pills.citizens).toBeNil()
		expect(find(ui.guis.hud, "Population").Text).toContain("6/6")
		ui:openMenu("build")
		expect(find(ui.guis.menus, "BuildingList")).toBeTruthy()
		expect(find(ui.guis.menus, "Detail")).toBeNil()
		tap(find(ui.guis.menus, "Row_farm"))
		expect(find(ui.guis.menus, "BuildingList")).toBeNil()
		expect(find(ui.guis.menus, "Back").Text).toContain("Economy")
		tap(cta(ui))
		world:advance(0)
		expect(world.treasury:balances(world.kingdomId).wood).toBe(110)
		tap(find(ui.guis.menus, "Back"))
		expect(find(ui.guis.menus, "BuildingList")).toBeTruthy()
	end)

	it("keeps every rail button and CTA at least 44 px", function()
		for _, button in ui.hud.rail do
			expect(button.instance.Size.X.Offset).toBeGreaterThanOrEqual(44)
		end
		ui:openMenu("build")
		tap(find(ui.guis.menus, "Row_farm"))
		expect(cta(ui).Parent.Size.Y.Offset).toBeGreaterThanOrEqual(44)
	end)
end)
