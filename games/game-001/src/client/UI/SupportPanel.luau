--!strict
--[[
	UI/SupportPanel — the support breakdown in the menu drawer (FL-0073; design crown-arena.md §3, §8 "Tapping it opens
	a breakdown per component with the latest moments that moved it"); the model is UI/SupportMeterModel.
		Summary     "Adoring support · 91" (tier chip: name, score, colour), the trend ("Rising +3 in 5 min"), the next
		            tier ("9 points to Adoring"), the arena it buys ("Blessing +1% · 3 perk slots in the arena")
		Components  one row per component in config order ("Component_<id>", attribute `value`): icon, name, its share
		            of the score ("20 %"), a bar and the value 0-100
		Moments     "What moved it": the latest moments, newest first ("Moment_<i>": text, component, signed delta in
		            green or red); none yet says so
	The drawer scrolls; phones (Layout drawer, single pane) use the same order with smaller type and no title.

	SupportPanel.new(parent) -> view
	view:render(model, metrics, ui: { onClose })   view:destroy()   view.instance: Frame (the Panel) "SupportPanel"
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local SupportPanel = {}
SupportPanel.__index = SupportPanel

function SupportPanel.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame?, panel = nil :: any }, SupportPanel)
end

local function line(
	value: string,
	size: number,
	color: Color3,
	weight: any,
	order: number,
	name: string,
	wrap: boolean?
)
	return Style.text({
		text = value,
		size = size,
		color = color,
		weight = weight,
		wrap = wrap,
		extra = { Name = name, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order },
	})
end

-- One line per component: icon, name, bar, share of the score, value.
local function componentRow(c: any, phone: boolean, order: number): Frame
	local h = if phone then 24 else 26
	local nameW = if phone then 96 else 124
	local left = if phone then 22 else 26
	local row = Create("Frame", {
		Name = "Component_" .. c.id,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 0, h),
		LayoutOrder = order,
	}) :: Frame
	row:SetAttribute("value", c.value)
	local icon = Icon.new(c.icon, if phone then 16 else 18)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Parent = row
	Style.text({
		text = c.name,
		size = if phone then 12 else 13,
		color = Theme.color("textPrimary"),
		weight = Enum.FontWeight.SemiBold,
		extra = {
			Name = "Label",
			Position = UDim2.fromOffset(left, 0),
			Size = UDim2.new(0, nameW, 1, 0),
			Parent = row,
		},
	})
	Create("Frame", {
		Name = "Bar",
		BackgroundColor3 = Theme.color("ink950"),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, left + nameW + 6, 0.5, 0),
		Size = UDim2.new(1, -(left + nameW + 6 + 84), 0, 6),
		Parent = row,
	}, {
		Corner = Style.corner(999),
		Fill = Create("Frame", {
			BackgroundColor3 = Theme.color("gold500"),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(c.bar, 1),
		}, { Corner = Style.corner(999) }),
	})
	Style.text({
		text = `{c.weight} %`,
		size = 11,
		color = Theme.color("textMuted"),
		weight = Enum.FontWeight.SemiBold,
		xAlign = "Right",
		extra = {
			Name = "Weight",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -38, 0, 0),
			Size = UDim2.new(0, 40, 1, 0),
			Parent = row,
		},
	})
	Style.text({
		text = if c.value then tostring(c.value) else "–",
		size = if phone then 12 else 13,
		color = Theme.color("gold300"),
		weight = Enum.FontWeight.ExtraBold,
		xAlign = "Right",
		extra = {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 32, 1, 0),
			Parent = row,
		},
	})
	return row
end

-- A little air above a section heading.
local function gap(order: number): Frame
	return Create("Frame", {
		Name = "Gap" .. order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 4),
		LayoutOrder = order,
	}) :: Frame
end

-- Fixed height (two short lines: the pre-authored text and its component), so nothing depends on nested AutomaticSize.
local function momentRow(mo: any, phone: boolean, index: number, order: number): Frame
	local row = Create("Frame", {
		Name = "Moment_" .. index,
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = 0.5,
		Size = UDim2.new(1, -6, 0, if phone then 36 else 40),
		LayoutOrder = order,
	}, {
		Corner = Style.corner(8),
	}) :: Frame
	Style.text({
		text = mo.text,
		size = if phone then 11 else 12,
		color = Theme.color("textPrimary"),
		weight = Enum.FontWeight.SemiBold,
		extra = {
			Name = "Text",
			Position = UDim2.fromOffset(8, if phone then 3 else 4),
			Size = UDim2.new(1, -60, 0, if phone then 16 else 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		},
	})
	Style.text({
		text = mo.component,
		size = 10,
		color = Theme.color("textMuted"),
		weight = Enum.FontWeight.SemiBold,
		extra = {
			Name = "Component",
			Position = UDim2.fromOffset(8, if phone then 19 else 22),
			Size = UDim2.new(1, -60, 0, 14),
			Parent = row,
		},
	})
	Style.text({
		text = mo.deltaText,
		size = if phone then 13 else 14,
		color = Theme.color(if mo.positive then "vert" else "gules"),
		weight = Enum.FontWeight.ExtraBold,
		xAlign = "Right",
		extra = {
			Name = "Delta",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(38, 18),
			Parent = row,
		},
	})
	return row
end

function SupportPanel:render(model: any, m: any, ui: { [string]: any })
	self:destroy()
	local phone = m.breakpoint == "phone"
	local d = m.drawer
	local panel = Panel.new({
		title = if phone then nil else "Support",
		size = UDim2.fromOffset(d.width, d.height),
		position = UDim2.fromOffset(d.x, d.y),
		compact = phone,
		onClose = ui.onClose,
		zIndex = 2,
	})
	panel.instance.Name = "SupportPanel"
	local scroll = Create("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panel.content,
	}, { List = Style.list("y", if phone then 6 else 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

	-- summary
	local chip = Create("Frame", {
		Name = "Tier",
		BackgroundColor3 = model.tier.color,
		BackgroundTransparency = 0.72,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, if phone then 22 else 26),
		LayoutOrder = 1,
		Parent = scroll,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(model.tier.color, 1),
		Padding = Style.padding(0, 10),
		Label = Style.text({
			text = `{model.tier.name} support · {model.score}`,
			size = if phone then 13 else 15,
			color = Theme.color("textPrimary"),
			weight = Enum.FontWeight.ExtraBold,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) },
		}),
	})
	chip:SetAttribute("tier", model.tier.id)
	line(model.trend.text, if phone then 11 else 12, model.trend.color, Enum.FontWeight.Bold, 2, "Trend").Parent =
		scroll
	if model.nextTier then
		line(
			model.nextTier,
			if phone then 11 else 12,
			Theme.color("textSecondary"),
			Enum.FontWeight.SemiBold,
			3,
			"NextTier"
		).Parent =
			scroll
	end
	local arena = if model.blessing then `{model.blessing} · {model.slotsText}` else model.slotsText
	line(arena, if phone then 11 else 12, Theme.color("gold300"), Enum.FontWeight.SemiBold, 4, "Arena", true).Parent =
		scroll

	-- components
	gap(9).Parent = scroll
	line(
		"What it is made of",
		if phone then 11 else 13,
		Theme.color("gold300"),
		Enum.FontWeight.Bold,
		10,
		"ComponentsHeading"
	).Parent =
		scroll
	for i, c in model.components do
		componentRow(c, phone, 10 + i).Parent = scroll
	end

	-- moments
	gap(29).Parent = scroll
	line("What moved it", if phone then 11 else 13, Theme.color("gold300"), Enum.FontWeight.Bold, 30, "MomentsHeading").Parent =
		scroll
	if model.noMoments then
		line(
			model.noMoments,
			if phone then 11 else 12,
			Theme.color("textMuted"),
			Enum.FontWeight.SemiBold,
			31,
			"NoMoments"
		).Parent =
			scroll
	end
	for i, mo in model.moments do
		momentRow(mo, phone, i, 31 + i).Parent = scroll
	end

	self.panel = panel
	self.instance = panel.instance
	panel.instance.Parent = self._parent
end

function SupportPanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.instance = nil
end

return SupportPanel
