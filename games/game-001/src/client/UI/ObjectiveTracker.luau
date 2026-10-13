--!strict
--[[
	UI/ObjectiveTracker — the HUD objective tracker (FL-0060; prototype games/game-001/design/ui/army.js,
	scenes "hud" and "hud-open"): under the top-left stack (Layout `metrics.hud.objectives`), left of
	every drawer. Each objective shows its name (and number when there are several), its owner (a
	colour swatch AND the kingdom's name, "Neutral" or "Yours") and one capture bar per contesting
	kingdom with its name and percentage; mine reads "You" in gold. Tapping it expands the list.

	ObjectiveTracker.new(parent) -> tracker
	tracker:render(model: UI/ObjectiveModel Tracker, metrics, ui: { onToggle: () -> () })
	tracker:destroy()
	tracker.instance: Frame "ObjectiveTracker" (attribute `expanded`)
	tracker.hit: TextButton "Toggle" (at least 44 px tall)
	tracker.rows[id] = { frame: Frame "Objective_<id>", name, owner = { frame "Owner", label, swatch },
		bars[kingdom] = { frame: Frame "Bar_<kingdom>", bar: ProgressBar, label, pct }, status, contested }
	Only a new zone (breakpoint, position, width) rebuilds it. Pushes patch in place (FORGE-05 M1):
	rows and bars are created when they first appear and kept; values, sizes, order and visibility
	are set on the same instances.
]]

local ArmyText = require("./ArmyText")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local ObjectiveModel = require("./ObjectiveModel")
local ProgressBar = require("@game/ReplicatedStorage/Forge/UI/Components/ProgressBar")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ObjectiveTracker = {}
ObjectiveTracker.__index = ObjectiveTracker

ObjectiveTracker.INSET = 8 -- row inset from the tracker's sides
ObjectiveTracker.BAR_X = 26 -- bars and status lines start under the name
ObjectiveTracker.LABEL_WIDTH = 72
ObjectiveTracker.PCT_WIDTH = 34

function ObjectiveTracker.new(parent: Instance)
	return setmetatable({
		_parent = parent,
		_key = nil :: string?,
		instance = nil :: Frame?,
		hit = nil :: TextButton?,
		rows = {},
	}, ObjectiveTracker)
end

function ObjectiveTracker:_build(metrics: any)
	self:destroy()
	local z = metrics.hud.objectives
	self._stroke = Style.stroke(Theme.color("gold600"), 1, 0.4)
	local tracker = Create("Frame", {
		Name = "ObjectiveTracker",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.2,
		Position = UDim2.fromOffset(z.x, z.y),
		Size = UDim2.fromOffset(z.width, ObjectiveModel.MIN_HEIGHT),
		ClipsDescendants = true,
	}, {
		Corner = Style.corner(10),
		Stroke = self._stroke,
	})
	tracker:SetAttribute("OnboardingTarget", "HUD.Objectives")
	self._list = Create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color("gold600"),
		ScrollingEnabled = false,
		Parent = tracker,
	})
	self._titleText = Style.text({
		text = "",
		weight = Enum.FontWeight.ExtraBold,
		size = 10,
		color = Theme.color("gold400"),
		extra = { Name = "TitleText", Position = UDim2.fromOffset(20, 0), Size = UDim2.new(0.5, -20, 1, 0) },
	})
	self._titleHint = Style.text({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 10,
		color = Theme.color("textSecondary"),
		xAlign = "Right",
		extra = {
			Name = "Hint",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromScale(0.5, 1),
		},
	})
	local titleIcon = Icon.new("watchtower", 14)
	titleIcon.Position = UDim2.fromOffset(0, 1)
	self._title = Create("Frame", {
		Name = "Title",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(ObjectiveTracker.INSET, ObjectiveModel.PAD),
		Size = UDim2.new(1, -2 * ObjectiveTracker.INSET, 0, ObjectiveModel.TITLE),
		Visible = false,
		Parent = self._list,
	}, {
		Icon = titleIcon,
		TitleText = self._titleText,
		Hint = self._titleHint,
	})
	self._more = Style.text({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 10,
		color = Theme.color("gold400"),
		xAlign = "Right",
		extra = {
			Name = "More",
			Position = UDim2.fromOffset(ObjectiveTracker.INSET, 0),
			Size = UDim2.new(1, -2 * ObjectiveTracker.INSET, 0, ObjectiveModel.MORE),
			Visible = false,
			Parent = self._list,
		},
	})
	self.hit = Create("TextButton", {
		Name = "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = tracker,
		[Create.Event.Activated] = function()
			if self._onToggle then
				self._onToggle()
			end
		end,
	})
	self.rows = {}
	tracker.Parent = self._parent
	self.instance = tracker
end

local function swatch(color: Color3?): Frame
	return Create("Frame", {
		Name = "Swatch",
		BackgroundColor3 = color or Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(9, 9),
	}, { Corner = Style.corner(2), Stroke = Style.stroke(Theme.color("ink950"), 1) })
end

function ObjectiveTracker:_row(id: string): any
	local entry = self.rows[id]
	if entry then
		return entry
	end
	local icon = Icon.new("watchtower", 18)
	icon.Position = UDim2.fromOffset(0, 1)
	local number = Create("TextLabel", {
		Name = "Number",
		Text = "",
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(1, 2),
		BackgroundColor3 = Theme.color("ink700"),
		TextColor3 = Theme.color("gold300"),
		FontFace = Theme.font("body", Enum.FontWeight.ExtraBold),
		TextSize = 10,
	}, { Corner = Style.corner(999), Stroke = Style.stroke(Theme.color("gold600"), 1) })
	local neutralIcon = Icon.new("watchtower", 12)
	neutralIcon.Name = "NeutralIcon"
	neutralIcon.LayoutOrder = 1
	local ownerSwatch = swatch(nil)
	ownerSwatch.LayoutOrder = 1
	local ownerLabel = Style.text({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 11,
		extra = { Name = "Label", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
	})
	local ownerStroke = Style.stroke(Theme.color("ink500"), 1)
	local owner = Create("Frame", {
		Name = "Owner",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0, math.floor(ObjectiveModel.HEAD / 2)),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
	}, {
		Corner = Style.corner(999),
		Stroke = ownerStroke,
		Padding = Style.padding(0, 7, 0, 5),
		List = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		NeutralIcon = neutralIcon,
		Swatch = ownerSwatch,
		Label = ownerLabel,
	})
	local name = Style.text({
		text = "",
		role = "heading",
		weight = Enum.FontWeight.Bold,
		size = 13,
		color = Theme.color("parchment100"),
		extra = {
			Name = "ObjectiveName",
			Position = UDim2.fromOffset(24, 0),
			Size = UDim2.new(1, -24 - 84, 0, ObjectiveModel.HEAD),
		},
	})
	local status = Style.text({
		text = "",
		size = 11,
		color = Theme.color("textMuted"),
		extra = {
			Name = "Status",
			Position = UDim2.fromOffset(ObjectiveTracker.BAR_X, ObjectiveModel.HEAD + ObjectiveModel.GAP),
			Size = UDim2.new(1, -ObjectiveTracker.BAR_X, 0, ObjectiveModel.LINE),
		},
	})
	local contested = Style.text({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 11,
		color = Theme.color("amber"),
		extra = { Name = "Contested", Size = UDim2.new(1, -ObjectiveTracker.BAR_X, 0, ObjectiveModel.LINE) },
	})
	local divider = Create("Frame", {
		Name = "Divider",
		BackgroundColor3 = Theme.color("ink500"),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, -math.ceil(ObjectiveModel.ROW_GAP / 2)),
		Size = UDim2.new(1, 0, 0, 1),
	})
	local frame = Create("Frame", {
		Name = "Objective_" .. id,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -2 * ObjectiveTracker.INSET, 0, ObjectiveModel.HEAD),
		Parent = self._list,
	}, {
		Icon = icon,
		Number = number,
		ObjectiveName = name,
		Owner = owner,
		Status = status,
		Contested = contested,
		Divider = divider,
	})
	entry = {
		frame = frame,
		icon = icon,
		number = number,
		name = name,
		owner = { frame = owner, label = ownerLabel, swatch = ownerSwatch, icon = neutralIcon, stroke = ownerStroke },
		status = status,
		contested = contested,
		divider = divider,
		bars = {},
	}
	self.rows[id] = entry
	return entry
end

function ObjectiveTracker:_bar(row: any, kingdom: string): any
	local entry = row.bars[kingdom]
	if entry then
		return entry
	end
	local bar = ProgressBar.new({
		progress = 0,
		height = 8,
		width = UDim.new(
			1,
			-(ObjectiveTracker.BAR_X + 14 + ObjectiveTracker.LABEL_WIDTH + ObjectiveTracker.PCT_WIDTH + 6)
		),
	})
	bar.instance.Position = UDim2.fromOffset(ObjectiveTracker.BAR_X + 14 + ObjectiveTracker.LABEL_WIDTH, 3)
	local label = Style.text({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 11,
		color = Theme.color("textSecondary"),
		extra = {
			Name = "Label",
			Position = UDim2.fromOffset(ObjectiveTracker.BAR_X + 14, 0),
			Size = UDim2.new(0, ObjectiveTracker.LABEL_WIDTH, 1, 0),
		},
	})
	local pct = Style.text({
		text = "",
		weight = Enum.FontWeight.ExtraBold,
		size = 11,
		xAlign = "Right",
		extra = {
			Name = "Pct",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, ObjectiveTracker.PCT_WIDTH, 1, 0),
		},
	})
	local sw = swatch(nil)
	sw.Position = UDim2.fromOffset(ObjectiveTracker.BAR_X, 2)
	local frame = Create("Frame", {
		Name = "Bar_" .. kingdom,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ObjectiveModel.LINE),
		Parent = row.frame,
	}, { Swatch = sw, Label = label, Bar = bar.instance, Pct = pct })
	entry = { frame = frame, bar = bar, label = label, pct = pct, swatch = sw }
	row.bars[kingdom] = entry
	return entry
end

local GOLD_TEXT = "gold300"

function ObjectiveTracker:_paintRow(entry: any, row: any, index: number)
	local frame = entry.frame
	frame.Visible = true
	frame.Position = UDim2.fromOffset(ObjectiveTracker.INSET, row.y)
	frame.Size = UDim2.new(1, -2 * ObjectiveTracker.INSET, 0, row.height)
	frame:SetAttribute("owner", row.owner.text)
	entry.divider.Visible = index > 1
	entry.icon.Visible = row.number == nil
	entry.number.Visible = row.number ~= nil
	entry.number.Text = if row.number then tostring(row.number) else ""
	entry.name.Text = row.name
	local owner = entry.owner
	owner.label.Text = row.owner.text
	owner.label.TextColor3 = if row.owner.mine
		then Theme.color(GOLD_TEXT)
		elseif row.owner.neutral then Theme.color("textSecondary")
		else Theme.color("textPrimary")
	owner.stroke.Color = if row.owner.mine then Theme.color("gold400") else Theme.color("ink500")
	owner.icon.Visible = row.owner.neutral
	owner.swatch.Visible = not row.owner.neutral
	if row.owner.color then
		owner.swatch.BackgroundColor3 = row.owner.color
	end
	entry.status.Visible = row.status ~= nil
	entry.status.Text = row.status or ""
	local line = 0
	local shown = {}
	for i, b in row.bars do
		shown[b.kingdom] = true
		local bar = self:_bar(entry, b.kingdom)
		bar.frame.Visible = true
		bar.frame.LayoutOrder = i
		bar.frame.Position = UDim2.fromOffset(
			0,
			ObjectiveModel.HEAD + ObjectiveModel.GAP + (i - 1) * (ObjectiveModel.LINE + ObjectiveModel.GAP)
		)
		bar.frame:SetAttribute("progress", b.progress)
		bar.frame:SetAttribute("mine", b.mine)
		bar.swatch.BackgroundColor3 = b.color
		bar.label.Text = b.label
		bar.label.TextColor3 = if b.mine then Theme.color(GOLD_TEXT) else Theme.color("textSecondary")
		bar.pct.Text = b.text
		bar.pct.TextColor3 = if b.mine then Theme.color(GOLD_TEXT) else Theme.color("textPrimary")
		bar.bar:update({ progress = b.progress, color = b.color })
		local stroke = bar.bar.instance:FindFirstChild("Stroke")
		if stroke then
			(stroke :: UIStroke).Color = if b.mine then Theme.color("gold400") else Theme.color("ink500")
		end
		line = i
	end
	for kingdom, bar in entry.bars do
		if not shown[kingdom] then
			bar.frame.Visible = false
		end
	end
	line = math.max(line, if row.status then 1 else 0)
	entry.contested.Visible = row.contested
	entry.contested.Text = if row.contested then "⚔ " .. ArmyText.CONTESTED else ""
	entry.contested.Position = UDim2.fromOffset(
		ObjectiveTracker.BAR_X,
		ObjectiveModel.HEAD + ObjectiveModel.GAP + line * (ObjectiveModel.LINE + ObjectiveModel.GAP)
	)
end

function ObjectiveTracker:render(model: { [string]: any }, metrics: any, ui: { [string]: any })
	local z = metrics.hud.objectives
	local key = `{metrics.breakpoint}:{z.x}:{z.y}:{z.width}`
	if self._key ~= key or self.instance == nil or self.instance.Parent == nil then
		self:_build(metrics) -- destroys the old tracker (and its key) first
		self._key = key
	end
	self._onToggle = ui.onToggle
	local tracker = self.instance :: Frame
	tracker.Visible = model.visible == true
	tracker:SetAttribute("expanded", model.expanded == true)
	if not model.visible then
		return
	end
	tracker.Size = UDim2.fromOffset(z.width, model.height)
	self._stroke.Color = if model.expanded then Theme.color("gold400") else Theme.color("gold600")
	self._stroke.Transparency = if model.expanded then 0 else 0.4
	self._list.CanvasSize = UDim2.fromOffset(0, model.contentHeight)
	self._list.ScrollingEnabled = model.scroll == true
	-- Expanded and scrolling: only the top strip toggles, so the list can still be dragged.
	self.hit.Size = if model.scroll then UDim2.new(1, 0, 0, ObjectiveModel.MIN_HEIGHT) else UDim2.fromScale(1, 1)
	self._title.Visible = model.title ~= nil
	if model.title then
		self._titleText.Text = string.upper(model.title.text)
		self._titleHint.Text = model.title.hint
	end
	local seen = {}
	local bottom = ObjectiveModel.PAD
	for i, row in model.rows do
		seen[row.id] = true
		self:_paintRow(self:_row(row.id), row, i)
		bottom = row.y + row.height
	end
	for id, entry in self.rows do
		if not seen[id] then
			entry.frame.Visible = false
		end
	end
	self._more.Visible = model.more ~= nil
	self._more.Text = if model.more then model.more .. " ▾" else ""
	self._more.Position = UDim2.fromOffset(ObjectiveTracker.INSET, bottom + ObjectiveModel.GAP)
end

function ObjectiveTracker:bottom(): number?
	local tracker = self.instance
	if tracker == nil or not tracker.Visible then
		return nil
	end
	return tracker.Position.Y.Offset + tracker.Size.Y.Offset
end

function ObjectiveTracker:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self.hit = nil
	self.rows = {}
	self._key = nil
end

return ObjectiveTracker
