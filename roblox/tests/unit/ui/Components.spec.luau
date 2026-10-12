local T = require("../../harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local UI = "@game/ReplicatedStorage/Forge/UI/"
local Create = require(UI .. "Create")
local Button = require(UI .. "Components/Button")
local CurrencyPill = require(UI .. "Components/CurrencyPill")
local Grid = require(UI .. "Components/Grid")
local IconButton = require(UI .. "Components/IconButton")
local ItemCard = require(UI .. "Components/ItemCard")
local Modal = require(UI .. "Components/Modal")
local Panel = require(UI .. "Components/Panel")
local ProgressBar = require(UI .. "Components/ProgressBar")
local Tabs = require(UI .. "Components/Tabs")
local Toast = require(UI .. "Components/Toast")
local MockEnv = require("../../mocks/MockEnv")
local Motion = require(UI .. "Motion")
local ToastStack = require(UI .. "ToastStack")

local function find(root, name)
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

describe("UI kit components", function()
	local previous
	beforeEach(function()
		previous = Create.useTestConnector()
	end)
	afterEach(function()
		Create.setConnector(previous)
	end)

	it("the test connector keeps handlers when Lua drops the instance and the GC runs", function()
		-- Lune hands out a new userdata for an instance once the old one is collected, so a
		-- weak-keyed handler table loses the button after a GC: Create.fire found 0 handlers in a
		-- third of full game-001 runs (KingdomUI.spec "tapping a resource").
		local parent = Instance.new("Frame")
		local fired = 0
		Create("TextButton", {
			Name = "Hit",
			Parent = parent,
			[Create.Event.Activated] = function()
				fired += 1
			end,
		})
		for _ = 1, 30 do
			local junk = {}
			for i = 1, 200000 do
				junk[i] = { i }
			end
		end
		expect(Create.fire(parent:FindFirstChild("Hit"), "Activated")).toBe(1)
		expect(fired).toBe(1)
	end)

	it("Create sets props, keyed children, refs and events; Parent last", function()
		local ref
		local fired = 0
		local parent = Instance.new("Frame")
		local button = Create("TextButton", {
			Text = "x",
			Parent = parent,
			[Create.Ref] = function(i)
				ref = i
				expect(i.Parent).toBeNil()
			end,
			[Create.Event.Activated] = function()
				fired += 1
			end,
		}, { Label = Create("TextLabel", {}), Skipped = false })
		expect(ref).toBe(button)
		expect(button.Parent).toBe(parent)
		expect(button:FindFirstChild("Label")).toBeTruthy()
		expect(Create.fire(button, "Activated")).toBe(1)
		expect(fired).toBe(1)
		-- C1: a child that is not an Instance is a mistake, not something to drop silently
		expect(function()
			Create("Frame", {}, { Oops = "text" })
		end).toThrow("not an Instance")
		-- U7: the toast stand-in can be torn down, and its pending timers then do nothing
		local env = MockEnv.new({})
		local stack = ToastStack.new(Instance.new("Frame"), Motion.new(env))
		stack:show({ title = "Built" })
		stack:destroy()
		expect(stack:count()).toBe(0)
		env.mock:advance(5)
		expect(#env.mock.threadErrors).toBe(0)
	end)

	it("Button runs onActivated only when enabled, and shows each state", function()
		local taps = 0
		local b = Button.new({
			text = "Build Farm",
			icon = "build",
			onActivated = function()
				taps += 1
			end,
		})
		Create.fire(b.face, "Activated")
		expect(taps).toBe(1)
		for _, state in { "disabled", "loading" } do
			b:update({ state = state })
			Create.fire(b.face, "Activated")
			expect(taps).toBe(1)
			expect(b.face:GetAttribute("state")).toBe(state)
		end
		b:update({ state = "default", variant = "success", text = "Construction started" })
		expect(b:text()).toBe("Construction started")
		Create.fire(b.face, "MouseButton1Down")
		expect(b.face.Position).toEqual(UDim2.fromOffset(0, 2))
		Create.fire(b.face, "MouseButton1Up")
		expect(b.face.Position).toEqual(UDim2.fromOffset(0, 0))
		expect(b.instance.Size.Y.Offset).toBe(44) -- touch target
	end)

	it("IconButton shows badge, selected, locked states and blocks taps when locked", function()
		local taps = 0
		local ib = IconButton.new({
			icon = "build",
			label = "Build",
			badge = 2,
			onActivated = function()
				taps += 1
			end,
		})
		expect(find(ib.instance, "Badge").Text).toBe("2")
		Create.fire(ib.instance, "Activated")
		ib:update({ locked = true, badge = 0 })
		Create.fire(ib.instance, "Activated")
		expect(taps).toBe(1)
		expect(find(ib.instance, "Badge")).toBeNil()
		ib:update({ locked = false, selected = true })
		expect(ib.instance:GetAttribute("selected")).toBe(true)
		expect(ib.instance.Size.X.Offset).toBeGreaterThanOrEqual(44)
	end)

	it("CurrencyPill formats amounts, caps, loading and error", function()
		local pill = CurrencyPill.new({ currency = "food", amount = 1234, cap = 5000, rate = 18 })
		expect(find(pill.instance, "Amount").Text).toContain("1.2k")
		expect(find(pill.instance, "Amount").Text).toContain("/ 5k")
		expect(find(pill.instance, "Rate").Text).toBe("+18/min")
		pill:update({ amount = 5000 })
		expect(pill.instance:GetAttribute("full")).toBe(true)
		pill:update({ compact = true })
		expect(find(pill.instance, "Amount").Text).toBe("5k")
		pill:update({ loading = true })
		expect(find(pill.instance, "Amount").Text).toBe("…")
		pill:update({ loading = false, error = true })
		expect(find(pill.instance, "Amount").Text).toBe("—")
		pill:pulse(-50)
		expect(find(pill.instance, "Delta").Text).toBe("−50")
		-- Reduced motion / no TweenService: the delta stays readable, then goes after PULSE_SEC.
		local env = MockEnv.new({})
		local still = CurrencyPill.new({ currency = "wood", amount = 50 }, Motion.new(env, { reduced = true }))
		still:pulse(-50)
		expect(find(still.instance, "Delta").TextTransparency).toBe(0)
		env.mock:advance(CurrencyPill.PULSE_SEC + 0.1)
		expect(find(still.instance, "Delta")).toBeNil()
		-- U1: without Motion nothing can schedule the removal; one float at a time, never a pile
		local bare = CurrencyPill.new({ currency = "food", amount = 5 })
		for _ = 1, 50 do
			bare:pulse(-1)
		end
		local deltas = 0
		for _, child in bare.instance:GetChildren() do
			if child.Name == "Delta" then
				deltas += 1
			end
		end
		expect(deltas).toBe(1)
		-- U2: a pill destroyed while its float is pending is left alone afterwards
		local gone = CurrencyPill.new({ currency = "wood", amount = 50 }, Motion.new(env, { reduced = true }))
		gone:pulse(-5)
		gone:destroy()
		env.mock:advance(CurrencyPill.PULSE_SEC + 0.1)
		expect(#env.mock.threadErrors).toBe(0)
	end)

	it("ProgressBar clamps progress and shows a label", function()
		local bar = ProgressBar.new({ progress = 1.7, label = "0:07" })
		expect(bar.instance:GetAttribute("progress")).toBe(1)
		bar:update({ progress = -1 })
		expect(bar.instance:GetAttribute("progress")).toBe(0)
		expect(find(bar.instance, "Label").Text).toBe("0:07")
	end)

	it("Tabs select, skip disabled and compact labels", function()
		local picked = {}
		local tabs = Tabs.new({
			tabs = {
				{ id = "economy", label = "Economy", icon = "food" },
				{ id = "civic", label = "Civic", icon = "house" },
				{ id = "military", label = "Military", icon = "army", disabled = true },
			},
			selected = "economy",
			onSelect = function(id)
				table.insert(picked, id)
			end,
		})
		Create.fire(tabs.buttons.civic, "Activated")
		Create.fire(tabs.buttons.military, "Activated")
		Create.fire(tabs.buttons.economy, "Activated")
		expect(picked).toEqual({ "civic" })
		tabs:update({ compact = true })
		expect(#tabs.buttons.civic.Row:GetChildren()).toBe(3) -- padding, list, icon: no label
	end)

	it("Panel, Modal, Toast, Grid and ItemCard build", function()
		local panel = Panel.new({ title = "Construction", size = UDim2.fromOffset(600, 400) })
		expect(panel.instance:FindFirstChild("Ornament")).toBeTruthy()
		-- The header slot fills the width the title leaves (a close button reaches the right edge).
		local slot = panel.instance:FindFirstChild("Slot", true)
		expect(slot:FindFirstChildOfClass("UIFlexItem").FlexMode).toBe(Enum.UIFlexMode.Fill)
		expect(slot.Size).toBe(UDim2.fromScale(0, 1))
		local untitled = Panel.new({ header = Instance.new("Frame"), size = UDim2.fromOffset(600, 400) })
		expect(untitled.instance:FindFirstChild("Slot", true).Size).toBe(UDim2.fromScale(1, 1))
		local confirmed, cancelled = 0, 0
		local modal = Modal.new({
			title = "Upgrade Town Hall?",
			body = "This spends most of your treasury.",
			rows = { { icon = "wood", label = "Wood", value = "150", note = "of 180" } },
			confirmText = "Upgrade",
			onConfirm = function()
				confirmed += 1
			end,
			onCancel = function()
				cancelled += 1
			end,
		})
		-- U5: a modal answers once; a double tap or a later scrim tap does nothing
		Create.fire(modal.confirm.face, "Activated")
		Create.fire(modal.confirm.face, "Activated")
		Create.fire(modal.instance.Scrim, "Activated")
		expect(confirmed).toBe(1)
		expect(cancelled).toBe(0)
		local dismissed = Modal.new({
			title = "Upgrade?",
			confirmText = "Upgrade",
			onConfirm = function()
				confirmed += 1
			end,
			onCancel = function()
				cancelled += 1
			end,
		})
		Create.fire(dismissed.instance.Scrim, "Activated")
		Create.fire(dismissed.confirm.face, "Activated")
		expect(cancelled).toBe(1)
		expect(confirmed).toBe(1)
		local toast = Toast.new({ kind = "error", title = "Couldn't start construction", body = "Need 20 more Wood" })
		expect(toast.instance:GetAttribute("kind")).toBe("error")
		local stacked = Toast.new({ kind = "achievement", title = "First building", count = 3 })
		expect(stacked.instance.Count.Text).toBe("×3")
		expect(Toast.new({ title = "once", count = 1 }).instance:FindFirstChild("Count")).toBeNil()
		local closed = 0
		local skip = Panel.new({
			title = "Welcome",
			compact = true,
			onClose = function()
				closed += 1
			end,
			closeText = "Skip",
		})
		Create.fire(skip.close.face, "Activated")
		local x = Panel.new({
			onClose = function()
				closed += 1
			end,
		})
		Create.fire(x.close.instance, "Activated")
		expect(closed).toBe(2)
		local grid = Grid.new({ empty = "No banners yet" })
		expect(grid.instance.Empty.Visible).toBe(true)
		grid:add(ItemCard.new({ name = "Oak Banner", icon = "banner", rarity = "Common", owned = true }).instance)
		expect(ItemCard.new({ name = "Odd", rarity = "Mythic" }).instance).toBeTruthy() -- U3
		grid:add(ItemCard.new({ empty = true }).instance)
		expect(grid:count()).toBe(2)
		expect(grid.instance.Empty.Visible).toBe(false)
	end)
end)
