local T = require("../../harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local UI = "@game/StarterPlayer/StarterPlayerScripts/Forge/UI/"
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
		}, { Label = Create("TextLabel", {}), false })
		expect(ref).toBe(button)
		expect(button.Parent).toBe(parent)
		expect(button:FindFirstChild("Label")).toBeTruthy()
		expect(Create.fire(button, "Activated")).toBe(1)
		expect(fired).toBe(1)
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
		Create.fire(modal.confirm.face, "Activated")
		Create.fire(modal.instance.Scrim, "Activated")
		expect(confirmed).toBe(1)
		expect(cancelled).toBe(1)
		local toast = Toast.new({ kind = "error", title = "Couldn't start construction", body = "Need 20 more Wood" })
		expect(toast.instance:GetAttribute("kind")).toBe("error")
		local grid = Grid.new({ empty = "No banners yet" })
		expect(grid.instance.Empty.Visible).toBe(true)
		grid:add(ItemCard.new({ name = "Oak Banner", icon = "banner", rarity = "Common", owned = true }).instance)
		grid:add(ItemCard.new({ empty = true }).instance)
		expect(grid:count()).toBe(2)
		expect(grid.instance.Empty.Visible).toBe(false)
	end)
end)
