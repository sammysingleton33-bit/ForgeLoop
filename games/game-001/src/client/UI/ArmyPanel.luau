--!strict
--[[
	UI/ArmyPanel — the army drawer (FL-0060; prototype games/game-001/design/ui/army.js, scenes "army*"):
	recruit soldiers at a barracks and send the idle ones to capture.
		phones          one column: your army (count + Send to capture), a status line, then the recruit
		                block (unit line, − count + with the costs against the treasury, Recruit CTA)
		tablet/desktop  two cards: Recruit (unit, time, upkeep, how many, costs, CTA) | Your army
		                (count, upkeep, what Send does, the target objective, Send CTA)
	Tabs: "Barracks · Lv N" (back to the barracks' upgrade panel) and "Army", or only "Army" without a
	barracks. Every CTA says why it is disabled ("Need 30 Food", "No soldiers yet").

	ArmyPanel.new(parent) -> panel
	panel:render(model: UI/ArmyModel Panel, metrics, ui: { onTab(id), onLess(), onMore(), onRecruit(),
		onSend(), onClose() })
	panel:destroy()
	panel.panel: kit Panel handle (instance "ArmyPanel")   panel.recruit / panel.send: Button handles
		(instances "Recruit" / "Send"; their faces carry the attribute `cta` = state)
	panel.less / panel.more: IconButton handles ("Less" / "More")
	panel.count, panel.soldiers, panel.status, panel.upkeep, panel.targetText: TextLabels
	panel.costs[currency]: Frame "Cost_<currency>" (children "Amount", "Have")
	ArmyPanel.key(model, metrics) -> string   the layout. Same key: values are patched on the same
		instances (FORGE-05 M1) — the count, costs, CTAs, soldier count, status and target.
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local ArmyText = require("./ArmyText")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Signature = require("./Signature")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Tabs = require("@game/ReplicatedStorage/Forge/UI/Components/Tabs")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ArmyPanel = {}
ArmyPanel.__index = ArmyPanel

local SHORT = Color3.fromRGB(255, 138, 115)
local GOOD = Color3.fromRGB(169, 229, 124)

ArmyPanel.PHONE_SEND_WIDTH = 176

function ArmyPanel.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, costs = {}, _ui = {} }, ArmyPanel)
end

function ArmyPanel.key(model: any, metrics: any): string
	local currencies = {}
	for i, c in model.costs do
		currencies[i] = c.currency
	end
	return Signature.of({
		breakpoint = metrics.breakpoint,
		drawer = metrics.drawer,
		tabs = model.tabs,
		notice = model.notice,
		unit = model.unit,
		currencies = currencies,
	})
end

local function ctaProps(cta: any): { [string]: any }
	return {
		text = cta.text,
		icon = cta.icon or false,
		variant = if cta.state == "done" then "success" else "primary",
		state = if cta.state == "disabled" then "disabled" elseif cta.state == "loading" then "loading" else "default",
	}
end

local function label(props: { [string]: any }): TextLabel
	return Style.text(props) :: TextLabel
end

local function stat(icon: string, text: string, order: number): Frame
	local i = Icon.new(icon, 16)
	i.LayoutOrder = 1
	return Create("Frame", {
		Name = "Stat",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = order,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		Padding = Style.padding(0, 8, 0, 4),
		List = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = i,
		Text = Style.text({
			text = text,
			weight = Enum.FontWeight.Bold,
			size = 11,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	})
end

local function card(name: string, size: UDim2, position: UDim2): Frame
	return Create("Frame", {
		Name = name,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = size,
		Position = position,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("gold500"), 1, 0.65),
		Gradient = Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.color("parchment200"), Theme.color("parchment200")),
			Transparency = NumberSequence.new(0.9, 0.96),
		}),
		Padding = Style.padding(10),
	})
end

local function divider(y: number): Frame
	return Create("Frame", {
		Name = "Divider",
		BackgroundColor3 = Theme.color("gold600"),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 1),
	})
end

-- "4 soldiers": the number big, the word small, side by side.
local function countRow(numberSize: number, wordSize: number, height: number): (Frame, TextLabel, TextLabel)
	local number = label({
		text = "",
		weight = Enum.FontWeight.ExtraBold,
		size = numberSize,
		yAlign = "Bottom",
		extra = {
			Name = "Soldiers",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 1,
		},
	})
	local word = label({
		text = "",
		size = wordSize,
		color = Theme.color("textSecondary"),
		yAlign = "Bottom",
		extra = {
			Name = "Word",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, -2),
			LayoutOrder = 2,
		},
	})
	local row = Create("Frame", {
		Name = "SoldierCount",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	}, {
		List = Style.list("x", 5, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom),
		Soldiers = number,
		Word = word,
	})
	return row, number, word
end

local function kicker(text: string, icon: string?): Frame
	local children: { [any]: any } = {
		List = Style.list("x", 5, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Text = Style.text({
			text = string.upper(text),
			weight = Enum.FontWeight.ExtraBold,
			size = 10,
			color = Theme.color("gold400"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	}
	if icon then
		local i = Icon.new(icon, 14)
		i.LayoutOrder = 1
		children.Icon = i
	end
	return Create("Frame", {
		Name = "Kicker",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
	}, children)
end

function ArmyPanel:_stepper(size: number)
	self.less = IconButton.new({
		icon = "minus",
		variant = "plain",
		size = size,
		onActivated = function()
			if self._ui.onLess then
				self._ui.onLess()
			end
		end,
	})
	self.less.instance.Name = "Less"
	self.more = IconButton.new({
		icon = "plus",
		variant = "plain",
		size = size,
		onActivated = function()
			if self._ui.onMore then
				self._ui.onMore()
			end
		end,
	})
	self.more.instance.Name = "More"
	self.count = label({
		text = "",
		weight = Enum.FontWeight.ExtraBold,
		size = if size >= 44 then 18 else 16,
		xAlign = "Center",
		extra = { Name = "Count", Size = UDim2.fromOffset(if size >= 44 then 36 else 40, size) },
	})
end

local function paintCost(row: Frame, c: any)
	row.BackgroundColor3 = if c.short then Theme.color("gules") else Theme.color("scrim")
	row.BackgroundTransparency = if c.short then 0.84 else 0.55
	row:SetAttribute("short", c.short)
	local amount = row:FindFirstChild("Amount") :: TextLabel?
	if amount then
		amount.Text = Format.amount(c.amount)
	end
	local have = row:FindFirstChild("Have") :: TextLabel?
	if have then
		have.Text = if c.short then `have {Format.amount(c.have)}` else `✓ {Format.amount(c.have)}`
		have.TextColor3 = if c.short then SHORT else GOOD
	end
end

-- Tablet/desktop cost row (as UI/DetailView): icon, name, amount, what you have.
local function costRow(c: any, y: number, height: number, compact: boolean): Frame
	local icon = Icon.new(c.currency, if compact then 16 else 18)
	icon.LayoutOrder = 1
	local children: { [any]: any } = {
		Corner = Style.corner(6),
		Padding = Style.padding(0, 6, 0, 6),
		List = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = icon,
		Amount = Style.text({
			text = "",
			weight = Enum.FontWeight.Bold,
			size = 12,
			xAlign = if compact then "Left" else "Right",
			extra = { Size = UDim2.new(0, if compact then 40 else 44, 1, 0), LayoutOrder = 3 },
		}),
		Have = Style.text({
			text = "",
			weight = Enum.FontWeight.Bold,
			size = 12,
			xAlign = "Right",
			extra = { Size = UDim2.new(1, if compact then -64 else -(18 + 4 + 44 + 4 + 120), 1, 0), LayoutOrder = 4 },
		}),
	}
	if not compact then
		children.CurrencyName = Style.text({
			text = c.name,
			size = 12,
			color = Theme.color("textSecondary"),
			extra = { Size = UDim2.new(0, 116, 1, 0), LayoutOrder = 2 },
		})
	end
	local row = Create("Frame", {
		Name = "Cost_" .. c.currency,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
	}, children)
	paintCost(row, c)
	return row
end

-- A transparent button that widens a 34 px kit tab to a 44 px touch target (centred on it).
local function hitArea(parent: Instance, fn: () -> ())
	Create("TextButton", {
		Name = "Hit",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, Theme.TOUCH or 44),
		ZIndex = 4,
		Parent = parent,
		[Create.Event.Activated] = fn,
	})
end
ArmyPanel.hitArea = hitArea

function ArmyPanel:_header(model: any, phone: boolean): Frame
	local header = Create("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local function chooseTab(id: string)
		if id ~= "army" and self._ui.onTab then
			self._ui.onTab(id)
		end
	end
	local tabs = Tabs.new({ tabs = model.tabs, selected = "army", compact = false, onSelect = chooseTab })
	if phone then
		for id, button in tabs.buttons do
			hitArea(button, function()
				chooseTab(id)
			end)
		end
	end
	tabs.instance.Parent = header
	local closeSize = if phone then 44 else 36
	local close = IconButton.new({
		icon = "close",
		variant = "plain",
		size = closeSize,
		onActivated = function()
			if self._ui.onClose then
				self._ui.onClose()
			end
		end,
	})
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.fromScale(1, 0.5)
	close.instance.Name = "Close"
	close.instance.Parent = header
	return header
end

function ArmyPanel:_buttons()
	self.recruit = Button.new({
		text = "",
		onActivated = function()
			if self._ui.onRecruit then
				self._ui.onRecruit()
			end
		end,
	})
	self.recruit.instance.Name = "Recruit"
	self.send = Button.new({
		text = "",
		onActivated = function()
			if self._ui.onSend then
				self._ui.onSend()
			end
		end,
	})
	self.send.instance.Name = "Send"
	self._recruitKey = nil
	self._sendKey = nil
end

function ArmyPanel:_buildPhone(model: any, content: Frame)
	local tile = Icon.tile("army", 40, "military")
	tile.Position = UDim2.fromOffset(0, 2)
	tile.Parent = content
	local k = kicker(ArmyText.YOUR_ARMY, nil)
	k.Position = UDim2.fromOffset(48, 3)
	k.Size = UDim2.new(1, -48 - ArmyPanel.PHONE_SEND_WIDTH, 0, 12)
	k.Parent = content
	local row, number, word = countRow(22, 11, 26)
	row.Position = UDim2.fromOffset(48, 16)
	row.Size = UDim2.new(1, -48 - ArmyPanel.PHONE_SEND_WIDTH - 8, 0, 26)
	row.Parent = content
	self.soldiers, self.word = number, word
	self.send.instance.Size = UDim2.fromOffset(ArmyPanel.PHONE_SEND_WIDTH, 44)
	self.send.instance.AnchorPoint = Vector2.new(1, 0)
	self.send.instance.Position = UDim2.fromScale(1, 0)
	self.send.instance.Parent = content
	self.status = label({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 12,
		extra = { Name = "Status", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 16) },
	})
	self.status.Parent = content
	divider(72).Parent = content
	if model.notice then
		self:_notice(model.notice, 80, 56).Parent = content
		return
	end
	local unit = model.unit
	local lineIcon = Icon.new(if unit then unit.icon else "militia", 16)
	lineIcon.LayoutOrder = 1
	Create("Frame", {
		Name = "UnitLine",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = content,
	}, {
		List = Style.list("x", 5, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = lineIcon,
		Title = Style.text({
			text = ArmyText.RECRUIT_LINE,
			weight = Enum.FontWeight.Bold,
			size = 12,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
		Meta = Style.text({
			text = if unit then unit.line else "",
			size = 12,
			color = Theme.color("textSecondary"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 3 },
		}),
	})
	self:_stepper(44)
	self.less.instance.Position = UDim2.fromOffset(0, 104)
	self.less.instance.Parent = content
	self.count.Position = UDim2.fromOffset(46, 104)
	self.count.Parent = content
	self.more.instance.Position = UDim2.fromOffset(84, 104)
	self.more.instance.Parent = content
	local n = math.max(1, #model.costs)
	local lineHeight = math.max(14, math.floor((44 - (n - 1) * 2) / n))
	local costs = Create("Frame", {
		Name = "Costs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(138, 104),
		Size = UDim2.new(1, -138, 0, 44),
		Parent = content,
	})
	for i, c in model.costs do
		local r = costRow(c, (i - 1) * (lineHeight + 2), lineHeight, true)
		r.Parent = costs
		self.costs[c.currency] = r
	end
	self.recruit.instance.Position = UDim2.fromOffset(0, 156)
	self.recruit.instance.Parent = content
end

function ArmyPanel:_notice(text: string, y: number, height: number): Frame
	local icon = Icon.new("barracks", 24)
	icon.LayoutOrder = 1
	return Create("Frame", {
		Name = "Notice",
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = 0.6,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		Padding = Style.padding(8, 10),
		List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = icon,
		Text = Style.text({
			text = text,
			weight = Enum.FontWeight.SemiBold,
			size = 12,
			color = Theme.color("textSecondary"),
			wrap = true,
			extra = { Size = UDim2.new(1, -32, 1, 0), LayoutOrder = 2, LineHeight = 1.15 },
		}),
	})
end

function ArmyPanel:_buildCards(model: any, content: Frame, width: number)
	local gap = 10
	local leftWidth = math.floor((width - gap) * 0.56)
	local left = card("RecruitCard", UDim2.new(0, leftWidth, 1, 0), UDim2.fromOffset(0, 0))
	local right = card("ArmyCard", UDim2.new(1, -(leftWidth + gap), 1, 0), UDim2.fromOffset(leftWidth + gap, 0))
	left.Parent = content
	right.Parent = content

	-- Recruit card
	if model.notice then
		local k = kicker(ArmyText.RECRUIT_LINE, "militia")
		k.Parent = left
		self:_notice(model.notice, 22, 64).Parent = left
	else
		local unit = model.unit or {}
		local tile = Icon.tile(unit.icon or "militia", 48, "military")
		tile.Parent = left
		label({
			text = unit.name or "",
			role = "heading",
			weight = Enum.FontWeight.Heavy,
			size = 18,
			color = Theme.color("parchment100"),
			extra = { Name = "UnitName", Position = UDim2.fromOffset(58, 4), Size = UDim2.new(1, -58, 0, 22) },
		}).Parent =
			left
		label({
			text = unit.meta or "",
			weight = Enum.FontWeight.Bold,
			size = 11,
			color = Theme.color("gold400"),
			extra = { Name = "Meta", Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -58, 0, 14) },
		}).Parent =
			left
		label({
			text = unit.description or "",
			weight = Enum.FontWeight.Medium,
			size = 12,
			color = Theme.color("textSecondary"),
			wrap = true,
			yAlign = "Top",
			extra = {
				Name = "Description",
				Position = UDim2.fromOffset(0, 56),
				Size = UDim2.new(1, 0, 0, 32),
				LineHeight = 1.15,
			},
		}).Parent =
			left
		local stats = Create("Frame", {
			Name = "Stats",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 94),
			Size = UDim2.new(1, 0, 0, 24),
			Parent = left,
		}, { List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
		if unit.each then
			stat("timer", unit.each, 1).Parent = stats
			stat("food", unit.upkeepEach, 2).Parent = stats
		end
		label({
			text = ArmyText.HOW_MANY,
			weight = Enum.FontWeight.Bold,
			size = 12,
			color = Theme.color("textSecondary"),
			extra = { Name = "HowMany", Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, -124, 0, 36) },
		}).Parent =
			left
		self:_stepper(36)
		self.less.instance.AnchorPoint = Vector2.new(1, 0)
		self.less.instance.Position = UDim2.new(1, -84, 0, 126)
		self.less.instance.Parent = left
		self.count.AnchorPoint = Vector2.new(1, 0)
		self.count.Position = UDim2.new(1, -42, 0, 126)
		self.count.Parent = left
		self.more.instance.AnchorPoint = Vector2.new(1, 0)
		self.more.instance.Position = UDim2.new(1, 0, 0, 126)
		self.more.instance.Parent = left
		for i, c in model.costs do
			local r = costRow(c, 172 + (i - 1) * 27, 24, false)
			r.Parent = left
			self.costs[c.currency] = r
		end
	end
	self.recruit.instance.AnchorPoint = Vector2.new(0, 1)
	self.recruit.instance.Position = UDim2.fromScale(0, 1)
	self.recruit.instance.Parent = left

	-- Your army card
	local k = kicker(ArmyText.YOUR_ARMY, "army")
	k.Parent = right
	local row, number, word = countRow(30, 13, 34)
	row.Position = UDim2.fromOffset(0, 18)
	row.Parent = right
	self.soldiers, self.word = number, word
	self.upkeep = label({
		text = "",
		size = 11,
		color = Theme.color("textSecondary"),
		extra = { Name = "Upkeep", Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 16) },
	})
	self.upkeep.Parent = right
	divider(76).Parent = right
	local banner = Icon.new("banner", 16)
	banner.LayoutOrder = 1
	Create("Frame", {
		Name = "SendTitle",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 20),
	}, {
		List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = banner,
		Text = Style.text({
			text = ArmyText.SEND_TITLE,
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = 14,
			color = Theme.color("gold300"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	}).Parent =
		right
	label({
		text = ArmyText.SEND_DESCRIPTION,
		weight = Enum.FontWeight.Medium,
		size = 12,
		color = Theme.color("textSecondary"),
		wrap = true,
		yAlign = "Top",
		extra = {
			Name = "SendDescription",
			Position = UDim2.fromOffset(0, 108),
			Size = UDim2.new(1, 0, 0, 32),
			LineHeight = 1.15,
		},
	}).Parent =
		right
	-- Two lines (name, then owner and my progress): the right card is ~200 px wide on tablets.
	local towerIcon = Icon.new("watchtower", 20)
	towerIcon.Position = UDim2.fromOffset(6, 10)
	self.targetName = label({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 12,
		extra = { Name = "TargetName", Position = UDim2.fromOffset(32, 4), Size = UDim2.new(1, -40, 0, 16) },
	})
	self.targetText = label({
		text = "",
		size = 11,
		color = Theme.color("textSecondary"),
		extra = { Name = "TargetText", Position = UDim2.fromOffset(32, 20), Size = UDim2.new(1, -40, 0, 15) },
	})
	self.target = Create("Frame", {
		Name = "Target",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.45,
		Position = UDim2.fromOffset(0, 146),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = right,
	}, {
		Corner = Style.corner(8),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		Icon = towerIcon,
		TargetName = self.targetName,
		TargetText = self.targetText,
	})
	self.status = label({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 12,
		extra = {
			Name = "Status",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -50),
			Size = UDim2.new(1, 0, 0, 16),
		},
	})
	self.status.Parent = right
	self.send.instance.AnchorPoint = Vector2.new(0, 1)
	self.send.instance.Position = UDim2.fromScale(0, 1)
	self.send.instance.Parent = right
end

function ArmyPanel:_patch(model: any, phone: boolean)
	if self.count then
		self.count.Text = tostring(model.count)
		if self._canLess ~= model.canLess then
			self._canLess = model.canLess
			self.less:update({ disabled = not model.canLess })
		end
		if self._canMore ~= model.canMore then
			self._canMore = model.canMore
			self.more:update({ disabled = not model.canMore })
		end
	end
	for _, c in model.costs do
		local row = self.costs[c.currency]
		if row then
			paintCost(row, c)
		end
	end
	local recruitKey = Signature.of(model.recruit)
	if recruitKey ~= self._recruitKey then
		self._recruitKey = recruitKey
		self.recruit:update(ctaProps(model.recruit))
		self.recruit.face:SetAttribute("cta", model.recruit.state)
	end
	local sendKey = Signature.of(model.send)
	if sendKey ~= self._sendKey then
		self._sendKey = sendKey
		self.send:update(ctaProps(model.send))
		self.send.face:SetAttribute("cta", model.send.state)
	end
	self.soldiers.Text = model.soldiersText
	self.word.Text = model.soldiersWord
	if self.upkeep then
		self.upkeep.Text = model.upkeep or ""
	end
	local status = model.status
	self.status.Visible = phone or not status.default
	self.status.Text = if status.tone == "ok" then "✓ " .. status.text else status.text
	self.status.TextColor3 = if status.tone == "ok" then GOOD else Theme.color("textSecondary")
	if self.target then
		self.target.Visible = model.target ~= nil
		self.targetName.Text = if model.target then model.target.name else ""
		self.targetText.Text = if model.target then model.target.text else ""
	end
end

function ArmyPanel:render(model: any, metrics: any, ui: { [string]: any })
	self._ui = ui
	local phone = metrics.breakpoint == "phone"
	local key = ArmyPanel.key(model, metrics)
	if self.panel and key == self._key then
		self:_patch(model, phone)
		return
	end
	self:destroy()
	self._key = key
	local d = metrics.drawer
	local pad = if phone then 10 else 12
	self.panel = Panel.new({
		title = if phone then nil else ArmyText.TITLE,
		header = self:_header(model, phone),
		size = UDim2.fromOffset(d.width, d.height),
		position = UDim2.fromOffset(d.x, d.y),
		padding = pad,
	})
	self.panel.instance.Name = "ArmyPanel"
	self:_buttons()
	local content = self.panel.content
	if phone then
		self:_buildPhone(model, content)
	else
		self:_buildCards(model, content, d.width - 2 * pad)
	end
	self:_patch(model, phone)
	self.panel.instance.Parent = self._parent
end

function ArmyPanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.costs = {}
	self.count = nil
	self.upkeep = nil
	self.target = nil
	self._canLess = nil
	self._canMore = nil
	self._key = nil
end

return ArmyPanel
