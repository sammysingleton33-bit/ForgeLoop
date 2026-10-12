--[[
	Kit scene: every FL-0020 component in its states, built by the real Luau modules
	(roblox/src/client/UI). Render with the game-001 theme:
		PROJECT=games/game-001/default.project.json bash design/ui/render/shoot-luau.sh kit
	The sheet is laid out for a wide screen; use a tall custom size, e.g. DEVICES=1280x1400.
]]

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
local Style = require(UI .. "Style")
local Tabs = require(UI .. "Components/Tabs")
local Theme = require(UI .. "Theme")
local Toast = require(UI .. "Components/Toast")

local function row(parent, order: number, title: string, height: number)
	local frame = Create("Frame", {
		Name = "Row_" .. title,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height + 18),
		LayoutOrder = order,
		Parent = parent,
	}, {
		Title = Style.text({
			text = title,
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = 14,
			color = Theme.color("gold300"),
			extra = { Size = UDim2.new(1, 0, 0, 16) },
		}),
	})
	return Create("Frame", {
		Name = "Items",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, height),
		Parent = frame,
	}, { List = Style.list("x", 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
end

local function place(handle, parent, order: number)
	local inst = if typeof(handle) == "Instance" then handle else handle.instance
	inst.LayoutOrder = order
	inst.Parent = parent
	return handle
end

return function(_ctx)
	Create.useTestConnector()
	local gui = Create("ScreenGui", {
		Name = "Kit",
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true,
	})
	local sheet = Create("Frame", {
		Name = "Sheet",
		BackgroundColor3 = Theme.color("ink900"),
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	}, {
		Padding = Style.padding(16, 20),
		List = Style.list("y", 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})

	local buttons = row(sheet, 1, "Button: primary · secondary · danger · success, then disabled and loading", 48)
	place(Button.new({ text = "Build", icon = "build", width = 120 }), buttons, 1)
	place(Button.new({ text = "Upgrade", variant = "secondary", width = 120 }), buttons, 2)
	place(Button.new({ text = "Demolish", variant = "danger", width = 120 }), buttons, 3)
	place(Button.new({ text = "Done", icon = "check", variant = "success", width = 110 }), buttons, 4)
	place(Button.new({ text = "Need 20 more Wood", state = "disabled", width = 190 }), buttons, 5)
	place(Button.new({ text = "Starting…", state = "loading", width = 140 }), buttons, 6)
	place(Button.new({ text = "Small", icon = "plus", size = "small", width = 90 }), buttons, 7)

	local icons = row(sheet, 2, "IconButton: default · selected · badge · locked · disabled · plain", 62)
	place(IconButton.new({ icon = "build", label = "Build" }), icons, 1)
	place(IconButton.new({ icon = "build", label = "Build", selected = true }), icons, 2)
	place(IconButton.new({ icon = "kingdom", label = "Kingdom", badge = 2 }), icons, 3)
	place(IconButton.new({ icon = "army", label = "Army", locked = true }), icons, 4)
	place(IconButton.new({ icon = "standings", label = "Ranks", disabled = true }), icons, 5)
	place(IconButton.new({ icon = "close", variant = "plain" }), icons, 6)

	local pills = row(sheet, 3, "CurrencyPill: full · compact · spent · at cap · loading · error", 40)
	place(CurrencyPill.new({ currency = "food", amount = 136, cap = 500, rate = 18 }), pills, 1)
	place(CurrencyPill.new({ currency = "wood", amount = 85, compact = true }), pills, 2)
	local spent = place(CurrencyPill.new({ currency = "wood", amount = 35, cap = 500, rate = 18 }), pills, 3)
	spent:pulse(-50)
	place(CurrencyPill.new({ currency = "stone", amount = 300, cap = 300, rate = 4 }), pills, 4)
	place(CurrencyPill.new({ currency = "gold", loading = true, cap = 300 }), pills, 5)
	place(CurrencyPill.new({ currency = "food", error = true }), pills, 6)

	local bars = row(sheet, 4, "ProgressBar: empty · in progress · complete · storage fill", 20)
	place(ProgressBar.new({ progress = 0, label = "0:18", width = UDim.new(0, 200) }), bars, 1)
	place(ProgressBar.new({ progress = 0.45, label = "0:07", width = UDim.new(0, 200) }), bars, 2)
	place(
		ProgressBar.new({ progress = 1, label = "Ready", color = Theme.color("vert"), width = UDim.new(0, 200) }),
		bars,
		3
	)
	place(ProgressBar.new({ progress = 0.27, color = Theme.resource("food"), width = UDim.new(0, 200) }), bars, 4)

	local tabs = row(sheet, 5, "Tabs: selected · default · disabled, and compact (phone)", 36)
	place(
		Tabs.new({
			tabs = {
				{ id = "economy", label = "Economy", icon = "food" },
				{ id = "civic", label = "Civic", icon = "house" },
				{ id = "military", label = "Military", icon = "army", disabled = true },
			},
			selected = "economy",
		}),
		tabs,
		1
	)
	place(
		Tabs.new({
			tabs = {
				{ id = "economy", label = "Economy", icon = "food" },
				{ id = "civic", label = "Civic", icon = "house" },
				{ id = "military", label = "Military", icon = "army" },
			},
			selected = "economy",
			compact = true,
		}),
		tabs,
		2
	)

	local cards = row(sheet, 6, "ItemCard in a Grid: five rarities, owned, locked, empty", 136)
	local grid = Grid.new({ size = UDim2.fromOffset(1000, 136), cell = Vector2.new(104, 128) })
	grid.instance.LayoutOrder = 1
	grid.instance.Parent = cards
	local items = {
		{ "Oak Banner", "banner", "Common", true },
		{ "Lion Banner", "banner", "Uncommon" },
		{ "Dragon Banner", "banner", "Rare" },
		{ "Phoenix Crest", "crest", "Epic" },
		{ "Sun Crest", "crest", "Legendary" },
	}
	for i, it in items do
		local card = ItemCard.new({ name = it[1], icon = it[2], rarity = it[3], owned = it[4], layoutOrder = i })
		grid:add(card.instance)
	end
	grid:add(
		ItemCard.new({ name = "Dragon Banner", icon = "banner", rarity = "Rare", locked = true, layoutOrder = 6 }).instance
	)
	grid:add(ItemCard.new({ empty = true, layoutOrder = 7 }).instance)

	local toasts = row(sheet, 7, "Toast: success · info · warning · error · reward", 56)
	place(
		Toast.new({ kind = "success", title = "Quarry construction started", body = "Ready in 0:18", width = 250 }),
		toasts,
		1
	)
	place(
		Toast.new({ kind = "info", title = "Keep reached level 2", body = "Barracks unlocked", width = 220 }),
		toasts,
		2
	)
	place(Toast.new({ kind = "warning", title = "Storage full", body = "Food is at its cap", width = 200 }), toasts, 3)
	place(
		Toast.new({ kind = "error", title = "Couldn't start construction", body = "Need 20 more Wood", width = 250 }),
		toasts,
		4
	)
	place(Toast.new({ kind = "reward", title = "Royal Chest opened", body = "Lion Banner", width = 190 }), toasts, 5)

	local panels = row(sheet, 8, "Panel with title and ornament · Modal (confirm a large spend)", 230)
	local panel = Panel.new({ title = "Buildings", size = UDim2.fromOffset(320, 220) })
	Style.text({
		text = "No buildings yet. Open Build to place your first Farm.",
		size = 12,
		color = Theme.color("textMuted"),
		wrap = true,
		extra = { Size = UDim2.new(1, 0, 0, 40) },
	}).Parent =
		panel.content
	place(panel, panels, 1)
	local holder = Create("Frame", {
		Name = "ModalHolder",
		BackgroundColor3 = Theme.color("vert"),
		Size = UDim2.fromOffset(460, 230),
		ClipsDescendants = true,
	}, { Corner = Style.corner(12) })
	local modal = Modal.new({
		title = "Upgrade Keep?",
		body = "This spends a large share of your treasury.",
		rows = {
			{ icon = "wood", label = "Wood", value = "150", note = "of 180" },
			{ icon = "stone", label = "Stone", value = "150", note = "of 160" },
		},
		confirmText = "Upgrade",
		confirmIcon = "build",
		width = 380,
		onConfirm = function() end,
	})
	modal.instance.Parent = holder
	place(holder, panels, 2)

	return { guis = { gui } }
end
