--!strict
--[[
	UI/SpectateScreen — what a ruler sees after their kingdom falls (FL-0129, D-053 (3)); the model is
	UI/SpectateModel. Two pieces on the menu layer, the world visible around them:
		FallenCard     top centre: "Fallen" kicker, "<Kingdom> has fallen", "<Rival> took your keep",
		               "N kingdoms still stand", then Stay (watch) and Leave. Shown until Stay.
		WatchPanel     left, under the top-left stack: "Watching", Prev / Next (the camera's cycle),
		               one row per camera target ("Target_<i>", attribute `selected`; a tap selects
		               it), and Leave at the bottom. Without targets: "Nothing to watch yet".
	Leave asks first: the card's (or panel's) buttons turn into "Leave this server?" Leave / Cancel.
	Phones (667 × 375): the card and the panel take turns (the card first), so neither covers the
	other; the panel is 224 wide. Tablet/desktop: both can show; the panel is 300 wide.

	SpectateScreen.new(parent) -> view
	view:render(model, metrics, state, ui)   state = { card: boolean, confirmLeave: boolean }
		ui = { onStay, onLeave, onConfirmLeave, onCancelLeave, onSelect(index), onCycle(step) }
	view:destroy()   view.instance: Frame "Spectate"
	SpectateScreen.PANEL = { desktop = 300, phone = 224 }   SpectateScreen.ROW = 40
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Signature = require("./Signature")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local SpectateScreen = {}
SpectateScreen.__index = SpectateScreen

SpectateScreen.PANEL = table.freeze({ desktop = 300, phone = 224 })
SpectateScreen.CARD = table.freeze({ desktop = 420, phone = 360 })
SpectateScreen.ROW = 40

function SpectateScreen.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame?, _key = nil :: string? }, SpectateScreen)
end

local function surface(name: string, props: { [string]: any }, children: { [string]: Instance }?): Frame
	local all: { [string]: Instance } = {
		Corner = Style.corner(12),
		Stroke = Style.stroke(Theme.color("gold600"), 1),
	}
	for k, v in children or {} do
		all[k] = v
	end
	props.Name = name
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.color("ink900")
	props.BackgroundTransparency = props.BackgroundTransparency or 0.06
	return Create("Frame", props, all) :: Frame
end

local function label(text: string, size: number, color: string, weight: any, order: number, name: string)
	return Style.text({
		text = text,
		size = size,
		color = Theme.color(color),
		weight = weight,
		wrap = true,
		extra = {
			Name = name,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
		},
	})
end

-- Two buttons side by side: Stay / Leave, or (confirming) Leave / Cancel.
local function buttonRow(state: any, ui: any, order: number, withStay: boolean): Frame
	local row = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, { List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) }) :: Frame
	local function add(name: string, text: string, variant: string, order_: number, fn: () -> ())
		local slot = Create("Frame", {
			Name = "Slot_" .. name,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.5, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order_,
			Parent = row,
		})
		local b = Button.new({ text = text, variant = variant, size = "small", onActivated = fn })
		b.instance.Name = name
		b.instance.Parent = slot
	end
	if state.confirmLeave then
		add("ConfirmLeave", "Leave", "danger", 1, ui.onConfirmLeave)
		add("CancelLeave", "Cancel", "secondary", 2, ui.onCancelLeave)
	elseif withStay then
		add("Stay", "Stay and watch", "primary", 1, ui.onStay)
		add("Leave", "Leave", "secondary", 2, ui.onLeave)
	else
		local b = Button.new({ text = "Leave", variant = "secondary", size = "small", onActivated = ui.onLeave })
		b.instance.Name = "Leave"
		b.instance.Parent = row
	end
	return row
end

local function card(model: any, m: any, state: any, ui: any): Frame
	local phone = m.breakpoint == "phone"
	local width = math.min(if phone then SpectateScreen.CARD.phone else SpectateScreen.CARD.desktop, m.width - 32)
	local frame = surface("FallenCard", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if phone then 58 else 72),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		Padding = Style.padding(if phone then 10 else 14, 16),
		List = Style.list("y", if phone then 4 else 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	label(
		if model.reason == "match_full" then "Spectating" else "Fallen",
		12,
		if model.reason == "match_full" then "gold300" else "gules",
		Enum.FontWeight.Bold,
		1,
		"Kicker"
	).Parent =
		frame
	label(model.title, if phone then 17 else 20, "textPrimary", Enum.FontWeight.Bold, 2, "Title").Parent = frame
	label(model.subtitle, 13, "textSecondary", Enum.FontWeight.SemiBold, 3, "Subtitle").Parent = frame
	if model.standing then
		label(model.standing, 12, "textMuted", Enum.FontWeight.SemiBold, 4, "Standing").Parent = frame
	end
	if state.confirmLeave then
		label("Leave this server? You can join another match.", 12, "textPrimary", Enum.FontWeight.Bold, 5, "Question").Parent =
			frame
	end
	buttonRow(state, ui, 6, true).Parent = frame
	return frame
end

local function targetRow(r: any, ui: any): Frame
	local frame = Create("TextButton", {
		Name = "Target_" .. r.index,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if r.selected then Theme.color("ink600") else Theme.color("scrim"),
		BackgroundTransparency = if r.selected then 0.1 else 0.5,
		Size = UDim2.new(1, 0, 0, SpectateScreen.ROW),
		LayoutOrder = r.index,
		[Create.Event.Activated] = function()
			ui.onSelect(r.index)
		end,
	}, {
		Corner = Style.corner(8),
		Stroke = Style.stroke(if r.selected then Theme.color("gold400") else Theme.color("ink500"), 1),
		Label = Style.text({
			text = r.label,
			size = 13,
			weight = Enum.FontWeight.Bold,
			color = Theme.color("textPrimary"),
			extra = { Position = UDim2.fromOffset(42, 3), Size = UDim2.new(1, -48, 0, 18) },
		}),
		Detail = Style.text({
			text = r.detail or "",
			size = 11,
			weight = Enum.FontWeight.SemiBold,
			color = Theme.color(if r.kind == "battle" then "gules" else "textSecondary"),
			extra = { Position = UDim2.fromOffset(42, 21), Size = UDim2.new(1, -48, 0, 15) },
		}),
	}) :: any
	frame:SetAttribute("selected", r.selected)
	frame:SetAttribute("kind", r.kind)
	local crest
	if r.kind == "battle" then
		crest = Create("Frame", {
			BackgroundColor3 = Theme.color("gules"),
			BackgroundTransparency = 0.6,
			Size = UDim2.fromOffset(30, 30),
		}, { Corner = Style.corner(8) })
		local icon = Icon.new("army", 20)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Parent = crest
	else
		crest = Crest.new(30, r.color, r.emblem)
	end
	crest.Name = "Crest"
	crest.AnchorPoint = Vector2.new(0, 0.5)
	crest.Position = UDim2.new(0, 6, 0.5, 0)
	crest.Parent = frame
	return frame
end

local function panel(model: any, m: any, state: any, ui: any): Frame
	local phone = m.breakpoint == "phone"
	local width = if phone then SpectateScreen.PANEL.phone else SpectateScreen.PANEL.desktop
	local top = m.hud.bottom + 10
	-- as tall as its rows (pad + head + list + foot + pad), at most to the bottom margin, so it never
	-- reaches the construction chips with only a few targets
	local n = math.max(1, #model.rows)
	local listHeight = n * SpectateScreen.ROW + (n - 1) * 6 + 8
	local content = 10 + 38 + listHeight + 6 + (if state.confirmLeave then 62 else 34) + 10
	-- phones: stop above the construction chips (bottom centre reaches under the panel's right edge)
	local floor = if phone and m.queue then m.queue.bottom + 48 else m.margin
	local height = math.min(content, math.max(160, m.height - top - floor))
	local frame = surface("WatchPanel", {
		Position = UDim2.fromOffset(m.margin, top),
		Size = UDim2.fromOffset(width, height),
	}, { Padding = Style.padding(10, 10) })
	local head = Create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 32),
		Parent = frame,
	}, {
		Title = Style.text({
			text = "Watching",
			size = 15,
			weight = Enum.FontWeight.Bold,
			color = Theme.color("gold300"),
			extra = { Size = UDim2.new(1, -112, 1, 0) },
		}),
	})
	local prev = Button.new({
		text = "Prev",
		variant = "secondary",
		size = "small",
		width = 52,
		state = if #model.rows > 1 then "default" else "disabled",
		onActivated = function()
			ui.onCycle(-1)
		end,
	})
	prev.instance.Name = "Prev"
	prev.instance.AnchorPoint = Vector2.new(1, 0.5)
	prev.instance.Position = UDim2.new(1, -56, 0.5, 0)
	prev.instance.Parent = head
	local nextButton = Button.new({
		text = "Next",
		variant = "secondary",
		size = "small",
		width = 52,
		state = if #model.rows > 1 then "default" else "disabled",
		onActivated = function()
			ui.onCycle(1)
		end,
	})
	nextButton.instance.Name = "Next"
	nextButton.instance.AnchorPoint = Vector2.new(1, 0.5)
	nextButton.instance.Position = UDim2.fromScale(1, 0.5)
	nextButton.instance.Parent = head
	local footHeight = if state.confirmLeave then 62 else 34
	local list = Create("ScrollingFrame", {
		Name = "Targets",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -(38 + footHeight + 6)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color("gold600"),
		Parent = frame,
	}, {
		List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Padding = Style.padding(1, 5, 1, 1),
	})
	if #model.rows == 0 then
		Style.text({
			text = "Nothing to watch yet",
			size = 12,
			color = Theme.color("textMuted"),
			extra = { Name = "Empty", Size = UDim2.new(1, 0, 0, 20), Parent = list },
		})
	end
	for _, r in model.rows do
		targetRow(r, ui).Parent = list
	end
	local foot = Create("Frame", {
		Name = "Foot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, footHeight),
		Parent = frame,
	}, { List = Style.list("y", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom) })
	if state.confirmLeave then
		label("Leave this server?", 12, "textPrimary", Enum.FontWeight.Bold, 1, "Question").Parent = foot
	end
	buttonRow(state, ui, 2, false).Parent = foot
	return frame
end

function SpectateScreen:render(model: any, metrics: any, state: any, ui: any)
	local phone = metrics.breakpoint == "phone"
	local showCard = state.card
	local showPanel = not (phone and state.card)
	local key = Signature.of({
		model = model,
		breakpoint = metrics.breakpoint,
		width = metrics.width,
		height = metrics.height,
		bottom = metrics.hud.bottom,
		card = showCard,
		panel = showPanel,
		confirm = state.confirmLeave,
	})
	if key == self._key and self.instance ~= nil then
		return
	end
	self._key = key
	if self.instance then
		self.instance:Destroy()
	end
	local root = Create("Frame", {
		Name = "Spectate",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}) :: Frame
	if showPanel then
		-- the panel's Leave confirms in the panel only while the card is gone
		panel(model, metrics, { confirmLeave = state.confirmLeave and not showCard }, ui).Parent = root
	end
	if showCard then
		card(model, metrics, state, ui).Parent = root
	end
	root.Parent = self._parent
	self.instance = root
end

function SpectateScreen:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self._key = nil
end

return SpectateScreen
