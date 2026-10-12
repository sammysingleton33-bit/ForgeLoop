--!strict
--[[
	UI/BuildMenu — the build drawer (prototype scenes "build", "build-detail", "build-short").
	Tablet/desktop: category tabs, building list and detail side by side. Phone: one pane — the list
	(costs at a glance), tap a row for its detail, "‹ Economy" goes back.

	BuildMenu.new(parent: GuiObject) -> menu
	menu:render(view: BuildModel View, metrics: Layout Metrics, ui: {
		phoneView: "list" | "detail", onCategory(id), onSelect(type), onBack(), onPlace(detail), onClose() })
	menu:destroy()
	Rows are named "Row_<type>" and carry the attribute `buildingType`; the CTA face carries `cta`.
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local DetailView = require("./DetailView")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Tabs = require("@game/ReplicatedStorage/Forge/UI/Components/Tabs")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local BuildMenu = {}
BuildMenu.__index = BuildMenu

local SHORT = Color3.fromRGB(255, 138, 115)

function BuildMenu.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, detail = nil, rows = {} }, BuildMenu)
end

local function costChips(costs: { any }, size: number): Frame
	local frame = Create("Frame", {
		Name = "Costs",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16),
		LayoutOrder = 2,
	}, { List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	for i, c in costs do
		local icon = Icon.new(c.currency, size)
		icon.LayoutOrder = 1
		Create("Frame", {
			Name = "Chip_" .. c.currency,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			LayoutOrder = i,
			Parent = frame,
		}, {
			List = Style.list("x", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Icon = icon,
			Amount = Style.text({
				text = Format.amount(c.amount),
				weight = Enum.FontWeight.Bold,
				size = 11,
				color = if c.short then SHORT else Theme.color("textPrimary"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
			}),
		})
	end
	return frame
end

local function row(r: any, compact: boolean, onSelect: (string) -> ()): TextButton
	local tile = if compact then 34 else 40
	local button = Create("TextButton", {
		Name = "Row_" .. r.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if r.selected then Theme.color("ink600") else Theme.color("ink700"),
		Size = UDim2.new(1, 0, 0, tile + 12),
		[Create.Event.Activated] = function()
			onSelect(r.id)
		end,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(
			if r.selected then Theme.color("gold500") else Theme.color("ink500"),
			if r.selected then 1.5 else 1
		),
		Padding = Style.padding(6, 8, 6, 6),
		Tile = Icon.tile(r.icon, tile, r.category),
		Text = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(tile + 8, 0),
			Size = UDim2.new(1, -(tile + 8 + 56), 1, 0),
		}, {
			List = Style.list("y", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Title = Style.text({
				text = r.name,
				role = "heading",
				weight = Enum.FontWeight.Bold,
				size = 13,
				color = Theme.color("parchment100"),
				extra = { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 },
			}),
			Costs = costChips(r.costs, 14),
		}),
		Right = Style.text({
			text = if r.built > 0 then `{r.built} built` else "",
			weight = Enum.FontWeight.Bold,
			size = 11,
			color = Theme.color("textSecondary"),
			xAlign = "Right",
			extra = {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(56, 16),
			},
		}),
	})
	button:SetAttribute("buildingType", r.id)
	if r.selected then
		Create("Frame", {
			Name = "Accent",
			BackgroundColor3 = Theme.color("gold400"),
			Position = UDim2.fromOffset(-7, 8),
			Size = UDim2.new(0, 3, 1, -16),
			Parent = button,
		}, { Corner = Style.corner(2) })
	end
	return button
end

function BuildMenu:render(view: any, metrics: any, ui: { [string]: any })
	if self.panel then
		self.panel:destroy()
	end
	self.rows = {}
	local phone = metrics.breakpoint == "phone"
	local d = metrics.drawer
	local header = Create("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	self.tabs = Tabs.new({ tabs = view.tabs, selected = view.category, compact = phone, onSelect = ui.onCategory })
	self.tabs.instance.Parent = header
	local close = IconButton.new({ icon = "close", variant = "plain", size = 36, onActivated = ui.onClose })
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.fromScale(1, 0.5)
	close.instance.Name = "Close"
	close.instance.Parent = header
	self.close = close
	self.panel = Panel.new({
		title = if phone then nil else "Build",
		header = header,
		size = UDim2.fromOffset(d.width, d.height),
		position = UDim2.fromOffset(d.x, d.y),
		padding = if phone then 10 else 12,
	})
	self.panel.instance.Name = "BuildMenu"
	local content = self.panel.content
	local listWidth = if phone then 0 elseif metrics.breakpoint == "tablet" then 230 else 250
	local showList = not phone or ui.phoneView ~= "detail"
	local showDetail = not phone or ui.phoneView == "detail"
	if showList then
		local list = Create("ScrollingFrame", {
			Name = "BuildingList",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = if phone then UDim2.fromScale(1, 1) else UDim2.new(0, listWidth, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.color("gold600"),
			Parent = content,
		}, {
			List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
			Padding = Style.padding(1, 4, 1, 8),
		})
		for i, r in view.rows do
			local data = table.clone(r)
			data.selected = not phone and r.id == view.selected
			local button = row(data, phone, ui.onSelect)
			button.LayoutOrder = i
			button.Parent = list
			self.rows[r.id] = button
		end
	end
	self.detail = nil
	if showDetail and view.detail then
		local holder = Create("Frame", {
			Name = "DetailHolder",
			BackgroundTransparency = 1,
			Position = if phone then UDim2.new() else UDim2.fromOffset(listWidth + 10, 0),
			Size = if phone then UDim2.fromScale(1, 1) else UDim2.new(1, -(listWidth + 10), 1, 0),
			Parent = content,
		})
		local back = nil
		if phone then
			for _, tab in view.tabs do
				if tab.id == view.category then
					back = tab.label
				end
			end
		end
		self.detail = DetailView.new({
			detail = view.detail,
			compact = phone,
			back = back,
			onCta = ui.onPlace,
			onBack = ui.onBack,
		})
		self.detail.instance.Parent = holder
	end
	self.panel.instance.Parent = self._parent
end

function BuildMenu:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.detail = nil
	self.rows = {}
end

return BuildMenu
