--!strict
--[[
	UI/LoadoutPicker — the loadout and perk picker before the duel (FL-0073; design crown-arena.md §4-§5); the model
	is UI/LoadoutModel. One panel on the modal layer, centred, over a light scrim:
		Header      "Choose your loadout", the support tier as a chip (name and colour, never colour alone), the
		            countdown ("Clock", red in the last 5 s)
		Weapons     four tiles ("Weapon_<id>", attribute `selected`): icon, name, what it is good at
		Armour      three tiles ("Armour_<id>")
		Sidegrades  "Every weapon and armour is a sidegrade: none is stronger overall."
		Perks       "Perks 2 of 3", one card per offer ("Offer_<trigger>", attributes `selected`, `locked`): name,
		            Pledged / Empowered, the citizen and their loyalty, the effect, "When: <condition>"; a locked
		            card (every slot taken) says "Slots full: drop a perk first". No offers: the model's reason.
		Footer      the status line and Ready ("Ready")
	Every tile and card is a TextButton (mouse, touch, and gamepad selection; ≥ 44 px tall).
	Desktop / tablet: 860 × 540, two columns. Phones (667 × 375): the whole safe area below the Roblox top bar
	(LoadoutPicker.PHONE_TOP), two columns, the perk list scrolls.

	LoadoutPicker.new(parent) -> view
	view:render(model, metrics, ui)   ui = { onWeapon(id), onArmour(id), onTrigger(trigger), onReady() }
	view:setClock(clock?, urgent?)   the countdown alone, in place
	view:destroy()   view.instance: Frame "LoadoutPicker"   view:first() -> the first weapon tile (gamepad focus)
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local LoadoutPicker = {}
LoadoutPicker.__index = LoadoutPicker

LoadoutPicker.DESKTOP = table.freeze({ width = 860, height = 600, left = 400 })
LoadoutPicker.PHONE_TOP = 52 -- below the Roblox top bar buttons
LoadoutPicker.TILE = table.freeze({ desktop = 64, phone = 46, armour = 46 })
LoadoutPicker.OFFER = table.freeze({ desktop = 90, phone = 72 })

function LoadoutPicker.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame?, _first = nil :: GuiObject? }, LoadoutPicker)
end

local function text(
	value: string,
	size: number,
	color: Color3,
	weight: any,
	props: { [string]: any }?,
	wrap: boolean?
): Instance
	return Style.text({ text = value, size = size, color = color, weight = weight, wrap = wrap, extra = props or {} })
end

local function heading(value: string, order: number, phone: boolean): Instance
	return text(value, if phone then 11 else 13, Theme.color("gold300"), Enum.FontWeight.Bold, {
		Name = "Heading",
		Size = UDim2.new(1, 0, 0, if phone then 14 else 18),
		LayoutOrder = order,
	})
end

local function selectStroke(selected: boolean): Instance
	return Style.stroke(if selected then Theme.color("gold400") else Theme.color("ink500"), if selected then 2 else 1)
end

-- A weapon or armour tile.
local function tile(r: any, size: Vector2, phone: boolean, order: number, prefix: string, fn: (string) -> ()): GuiObject
	local button = Create("TextButton", {
		Name = prefix .. r.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if r.selected then Theme.color("ink600") else Theme.color("ink800"),
		Size = UDim2.fromOffset(size.X, size.Y),
		LayoutOrder = order,
		[Create.Event.Activated] = function()
			fn(r.id)
		end,
	}, {
		Corner = Style.corner(8),
		Stroke = selectStroke(r.selected),
		Label = text(
			if phone then r.short or r.name else r.name,
			if phone then 12 else 14,
			Theme.color("textPrimary"),
			Enum.FontWeight.Bold,
			{
				Name = "Label",
				Position = UDim2.fromOffset(if phone then 34 else 44, if phone then 4 else 8),
				Size = UDim2.new(1, if phone then -38 else -50, 0, if phone then 16 else 18),
			}
		),
		Blurb = text(
			(if phone then r.shortBlurb else nil) or r.blurb or "",
			if phone then 10 else 11,
			Theme.color("textSecondary"),
			Enum.FontWeight.SemiBold,
			{
				Name = "Blurb",
				Position = UDim2.fromOffset(if phone then 34 else 44, if phone then 20 else 28),
				Size = UDim2.new(1, if phone then -38 else -50, 0, if phone then 24 else 30),
				TextYAlignment = Enum.TextYAlignment.Top,
			},
			true
		),
	}) :: GuiObject
	button:SetAttribute("selected", r.selected)
	local icon = Icon.new(r.icon, if phone then 22 else 28)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, if phone then 6 else 10, 0.5, 0)
	icon.Parent = button
	if r.selected then
		local check = Icon.new("check", 14, { color = Theme.color("gold300") })
		check.Name = "Check"
		check.AnchorPoint = Vector2.new(1, 0)
		check.Position = UDim2.new(1, -4, 0, 4)
		check.Parent = button
	end
	return button
end

local function grid(name: string, cell: Vector2, order: number): Frame
	return Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Grid = Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
end

local function offerCard(o: any, phone: boolean, order: number, fn: (string) -> ()): GuiObject
	local h = if phone then LoadoutPicker.OFFER.phone else LoadoutPicker.OFFER.desktop
	local left = if phone then 40 else 50
	local who = o.citizen
	if who and o.loyalty then
		who = `{who} · loyalty {o.loyalty}`
	elseif o.crowd then
		who = "Your whole stand"
	end
	local card = Create("TextButton", {
		Name = "Offer_" .. o.trigger,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if o.selected then Theme.color("ink600") else Theme.color("ink800"),
		BackgroundTransparency = if o.locked then 0.35 else 0,
		Size = UDim2.new(1, -8, 0, h),
		LayoutOrder = order,
		[Create.Event.Activated] = function()
			fn(o.trigger)
		end,
	}, {
		Corner = Style.corner(8),
		Stroke = selectStroke(o.selected),
		Title = text(
			if o.power then `{o.name} · {o.power}` else o.name,
			if phone then 12 else 14,
			Theme.color(if o.locked then "textMuted" else "textPrimary"),
			Enum.FontWeight.Bold,
			{
				Name = "Title",
				Position = UDim2.fromOffset(left, if phone then 4 else 6),
				Size = UDim2.new(1, -left - 26, 0, if phone then 15 else 18),
			}
		),
		Who = text(who or "", if phone then 10 else 11, Theme.color("gold300"), Enum.FontWeight.SemiBold, {
			Name = "Who",
			Position = UDim2.fromOffset(left, if phone then 19 else 24),
			Size = UDim2.new(1, -left - 8, 0, 13),
		}),
		Effect = text(o.effect, if phone then 10 else 12, Theme.color("textPrimary"), Enum.FontWeight.SemiBold, {
			Name = "Effect",
			Position = UDim2.fromOffset(left, if phone then 32 else 40),
			TextYAlignment = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, -left - 8, 0, if phone then 24 else 30),
		}, true),
		When = text(
			if o.locked then "Slots full: drop a perk first" else `When: {o.condition}`,
			if phone then 10 else 11,
			Theme.color(if o.locked then "amber" else "textSecondary"),
			Enum.FontWeight.SemiBold,
			{
				Name = "When",
				Position = UDim2.fromOffset(left, if phone then 56 else 71),
				Size = UDim2.new(1, -left - 8, 0, 13),
			}
		),
	}) :: GuiObject
	card:SetAttribute("selected", o.selected)
	card:SetAttribute("locked", o.locked)
	local medallion =
		Icon.medallion(o.icon, if phone then 30 else 36, Theme.color(if o.crowd then "gold500" else "ink600"))
	medallion.AnchorPoint = Vector2.new(0, 0.5)
	medallion.Position = UDim2.new(0, 6, 0.5, 0)
	medallion.Parent = card
	if o.selected then
		local check = Icon.new("check", 16, { color = Theme.color("gold300") })
		check.Name = "Check"
		check.AnchorPoint = Vector2.new(1, 0)
		check.Position = UDim2.new(1, -6, 0, 6)
		check.Parent = card
	end
	return card
end

function LoadoutPicker:render(model: any, m: any, ui: { [string]: any })
	self:destroy()
	local phone = m.breakpoint == "phone"
	local width, height
	if phone then
		width = m.width - 16
		height = m.height - LoadoutPicker.PHONE_TOP - 8
	else
		width = math.min(LoadoutPicker.DESKTOP.width, m.width - 32)
		height = math.min(LoadoutPicker.DESKTOP.height, m.height - 96)
	end
	local panel = Panel.new({
		title = if phone then nil else "Choose your loadout",
		size = UDim2.fromOffset(width, height),
		position = if phone then UDim2.new(0.5, 0, 0, LoadoutPicker.PHONE_TOP) else UDim2.fromScale(0.5, 0.5),
		anchor = if phone then Vector2.new(0.5, 0) else Vector2.new(0.5, 0.5),
		compact = phone,
		zIndex = 3,
	})
	local content = panel.content
	local inner = width - (if phone then 16 else 24)
	local leftWidth = if phone then math.floor(inner * 0.46) else LoadoutPicker.DESKTOP.left
	local gap = if phone then 8 else 16

	-- header: (phone title), tier chip, clock
	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if phone then 22 else 26),
		Parent = content,
	}, { List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	if phone then
		text("Choose your loadout", 15, Theme.color("textPrimary"), Enum.FontWeight.Bold, {
			Name = "Title",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			LayoutOrder = 1,
			Parent = header,
		})
	end
	local chip = Create("Frame", {
		Name = "Tier",
		BackgroundColor3 = model.tier.color,
		BackgroundTransparency = 0.75,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		LayoutOrder = 2,
		Parent = header,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(model.tier.color, 1),
		Padding = Style.padding(0, 8),
		Label = text(
			if model.tier.blessing
				then `{model.tier.name} support · {model.tier.blessing}`
				else `{model.tier.name} support`,
			11,
			model.tier.color,
			Enum.FontWeight.Bold,
			{ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) }
		),
	})
	chip:SetAttribute("tier", model.tier.id)
	if model.clock then
		local clock = text(
			model.clock,
			if phone then 15 else 18,
			Theme.color(if model.urgent then "gules" else "gold300"),
			Enum.FontWeight.ExtraBold,
			{
				Name = "Clock",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(60, if phone then 22 else 26),
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = content,
			}
		)
		clock:SetAttribute("urgent", model.urgent)
	end

	local top = if phone then 26 else 34
	local footer = if phone then 50 else 58 -- Ready (44) and a gap above it
	-- left column: weapons, armour, the sidegrade line
	local left = Create("Frame", {
		Name = "Gear",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(0, leftWidth, 1, -top - footer),
		Parent = content,
	}, { List = Style.list("y", if phone then 4 else 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local tileH = if phone then LoadoutPicker.TILE.phone else LoadoutPicker.TILE.desktop
	heading("Weapon", 1, phone).Parent = left
	local weapons = grid("Weapons", Vector2.new(math.floor((leftWidth - 6) / 2), tileH), 2)
	weapons.Parent = left
	self._first = nil
	for i, r in model.weapons do
		local t = tile(r, Vector2.new(0, 0), phone, i, "Weapon_", ui.onWeapon)
		t.Parent = weapons
		if i == 1 then
			self._first = t
		end
	end
	heading("Armour", 3, phone).Parent = left
	-- phones: three across with the short name; desktop: one full-width row each, with what it is good at
	local armour = grid(
		"Armour",
		if phone
			then Vector2.new(math.floor((leftWidth - 12) / 3), tileH)
			else Vector2.new(leftWidth, LoadoutPicker.TILE.armour),
		4
	)
	armour.Parent = left
	for i, r in model.armour do
		local t = tile(r, Vector2.new(0, 0), phone, i, "Armour_", ui.onArmour)
		if phone then
			t:FindFirstChild("Blurb"):Destroy()
			t:FindFirstChild("Label").Position = UDim2.fromOffset(30, 0)
			t:FindFirstChild("Label").Size = UDim2.new(1, -32, 1, 0)
		else
			t:FindFirstChild("Label").Position = UDim2.fromOffset(44, 6)
			t:FindFirstChild("Blurb").Position = UDim2.fromOffset(44, 25)
			t:FindFirstChild("Blurb").Size = UDim2.new(1, -50, 0, 16)
		end
		t.Parent = armour
	end
	text(model.sidegrades, if phone then 10 else 11, Theme.color("textMuted"), Enum.FontWeight.SemiBold, {
		Name = "Sidegrades",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = left,
	}, true)

	-- right column: the perks
	local right = Create("Frame", {
		Name = "Perks",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(leftWidth + gap, top),
		Size = UDim2.new(1, -leftWidth - gap, 1, -top - footer),
		Parent = content,
	})
	local slots = heading(model.slotsText, 0, phone)
	slots.Name = "Slots"
	slots.Parent = right
	local list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, if phone then 18 else 24),
		Size = UDim2.new(1, 0, 1, if phone then -18 else -24),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = right,
	}, { List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	for i, o in model.offers do
		offerCard(o, phone, i, ui.onTrigger).Parent = list
	end
	if model.noOffers then
		text(model.noOffers, 12, Theme.color("textSecondary"), Enum.FontWeight.SemiBold, {
			Name = "NoOffers",
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = list,
		}, true)
	end

	-- footer: status and Ready
	local readyWidth = if phone then 150 else 200
	if model.status then
		text(
			model.status,
			if phone then 11 else 12,
			Theme.color(if model.sent then "vert" else "textSecondary"),
			Enum.FontWeight.SemiBold,
			{
				Name = "Status",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, if phone then -12 else -14),
				Size = UDim2.new(1, -readyWidth - 12, 0, 18),
				Parent = content,
			}
		)
	end
	local ready = Button.new({
		text = model.confirm.label,
		variant = if model.sent then "success" else "primary",
		state = if model.confirm.enabled then "default" else "loading",
		width = readyWidth,
		onActivated = ui.onReady,
	})
	ready.instance.Name = "Ready"
	ready.instance.AnchorPoint = Vector2.new(1, 1)
	ready.instance.Position = UDim2.fromScale(1, 1)
	ready.instance.Parent = content

	self.instance = Create("Frame", {
		Name = "LoadoutPicker",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, {
		Scrim = Create("Frame", {
			BackgroundColor3 = Theme.color("scrim"),
			BackgroundTransparency = 0.45,
			Size = UDim2.fromScale(1, 1),
		}),
		Panel = panel.instance,
	}) :: Frame
	self.instance.Parent = self._parent
end

-- The countdown alone changed: patch it in place.
function LoadoutPicker:setClock(clock: string?, urgent: boolean?)
	local label = if self.instance then self.instance:FindFirstChild("Clock", true) else nil
	if label and label:IsA("TextLabel") then
		label.Text = clock or ""
		label.TextColor3 = Theme.color(if urgent then "gules" else "gold300")
		label:SetAttribute("urgent", urgent == true)
	end
end

function LoadoutPicker:first(): GuiObject?
	return self._first
end

function LoadoutPicker:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self._first = nil
end

return LoadoutPicker
