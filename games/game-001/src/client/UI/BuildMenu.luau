--!strict
--[[
	UI/BuildMenu — the build drawer (prototype scenes "build", "build-detail", "build-short").
	Tablet/desktop: category tabs, building list and detail side by side. Phone: one pane — the list
	(costs at a glance), tap a row for its detail, "‹ Economy" goes back.

	BuildMenu.new(parent: GuiObject) -> menu
	menu:render(view: BuildModel View, metrics: Layout Metrics, ui: {
		phoneView: "list" | "detail", title: string? (default "Build"), name: string? (panel Name, default
		"BuildMenu"), onCategory(id), onSelect(type), onBack(),
		onPlace(detail), onClose() })
	menu:destroy()
	Rows are named "Row_<type>" and carry the attribute `buildingType`; the CTA face carries `cta`.

	Renders keep their instances (FORGE-05 M1 on PR #25): the panel is rebuilt only when the frame
	changes (breakpoint, drawer size, tab, phone pane), the list only when its rows change (another
	tab), the detail only when it shows another building (DetailView.key). Everything a push
	changes — costs you can or can't cover, "N built", the selected row, the CTA — is patched in
	place, so a tap in progress lands and the list keeps its scroll.
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local DetailView = require("./DetailView")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Signature = require("./Signature")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Tabs = require("@game/ReplicatedStorage/Forge/UI/Components/Tabs")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local BuildMenu = {}
BuildMenu.__index = BuildMenu

local SHORT = Color3.fromRGB(255, 138, 115)

function BuildMenu.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, detail = nil, rows = {}, _ui = {}, _scroll = {} }, BuildMenu)
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
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
			}),
		})
	end
	return frame
end

-- What a push or a selection changes on a row: highlight, "N built", which costs are short.
local function paintRow(button: any, r: any)
	button.BackgroundColor3 = if r.selected then Theme.color("ink600") else Theme.color("ink700")
	local stroke = button:FindFirstChild("Stroke")
	if stroke then
		stroke.Color = if r.selected then Theme.color("gold500") else Theme.color("ink500")
		stroke.Thickness = if r.selected then 1.5 else 1
	end
	local accent = button:FindFirstChild("Accent")
	if r.selected and accent == nil then
		Create("Frame", {
			Name = "Accent",
			BackgroundColor3 = Theme.color("gold400"),
			Position = UDim2.fromOffset(-7, 8),
			Size = UDim2.new(0, 3, 1, -16),
			Parent = button,
		}, { Corner = Style.corner(2) })
	elseif not r.selected and accent then
		accent:Destroy()
	end
	local right = button:FindFirstChild("Right")
	if right then
		right.Text = if r.built > 0 then `{r.built} built` else ""
	end
	local text = button:FindFirstChild("Text")
	local costs = text and text:FindFirstChild("Costs")
	for _, c in r.costs do
		local chip = costs and costs:FindFirstChild("Chip_" .. c.currency)
		local amount = chip and chip:FindFirstChild("Amount")
		if amount then
			amount.TextColor3 = if c.short then SHORT else Theme.color("textPrimary")
		end
	end
end

local function row(r: any, compact: boolean, onSelect: (string) -> ()): TextButton
	local tile = if compact then 34 else 40
	local button = Create("TextButton", {
		Name = "Row_" .. r.id,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, tile + 12),
		[Create.Event.Activated] = function()
			onSelect(r.id)
		end,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
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
			text = "",
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
	paintRow(button, r)
	return button
end

-- The rows' layout: which buildings, in which order, with which prices. Not what you have.
local function listKey(rows: { any }, phone: boolean): string
	local out = {}
	for i, r in rows do
		local costs = {}
		for j, c in r.costs do
			costs[j] = { currency = c.currency, amount = c.amount }
		end
		out[i] = { id = r.id, name = r.name, icon = r.icon, category = r.category, costs = costs }
	end
	return Signature.of({ rows = out, phone = phone })
end

function BuildMenu:_frame(view: any, metrics: any, ui: { [string]: any })
	self:_teardown()
	local phone = metrics.breakpoint == "phone"
	local d = metrics.drawer
	local header = Create("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	self.tabs = Tabs.new({
		tabs = view.tabs,
		selected = view.category,
		compact = phone,
		onSelect = function(id)
			if self._ui.onCategory then
				self._ui.onCategory(id)
			end
		end,
	})
	self.tabs.instance.Parent = header
	local close = IconButton.new({
		icon = "close",
		variant = "plain",
		size = 36,
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
	self.close = close
	self.panel = Panel.new({
		title = if phone then nil else ui.title or "Build",
		header = header,
		size = UDim2.fromOffset(d.width, d.height),
		position = UDim2.fromOffset(d.x, d.y),
		padding = if phone then 10 else 12,
	})
	self.panel.instance.Name = ui.name or "BuildMenu"
	self._category = view.category
	self._listWidth = if phone then 0 elseif metrics.breakpoint == "tablet" then 230 else 250
	self.panel.instance.Parent = self._parent
end

function BuildMenu:_list(view: any, phone: boolean)
	local key = listKey(view.rows, phone) .. (view.empty or "")
	if self.list == nil or key ~= self._listKey then
		if self.list then
			self._scroll[self._category] = self.list.CanvasPosition
			self.list:Destroy()
		end
		self.rows = {}
		local list = Create("ScrollingFrame", {
			Name = "BuildingList",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = if phone then UDim2.fromScale(1, 1) else UDim2.new(0, self._listWidth, 1, 0),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Theme.color("gold600"),
		}, {
			List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
			Padding = Style.padding(1, 4, 1, 8),
		})
		local onSelect = function(id: string)
			if self._ui.onSelect then
				self._ui.onSelect(id)
			end
		end
		for i, r in view.rows do
			local data = table.clone(r)
			data.selected = false
			local button = row(data, phone, onSelect)
			button.LayoutOrder = i
			button.Parent = list
			self.rows[r.id] = button
		end
		if #view.rows == 0 and view.empty then
			-- e.g. the server's `fits` for this plot is empty: say so instead of an empty drawer
			Style.text({
				text = view.empty,
				weight = Enum.FontWeight.SemiBold,
				size = 12,
				color = Theme.color("textSecondary"),
				wrap = true,
				extra = { Name = "Empty", Size = UDim2.new(1, -8, 0, 36) },
			}).Parent =
				list
		end
		list.Parent = self.panel.content
		-- Back from a phone detail, or the same tab rebuilt: where the player left the list.
		local scroll = self._scroll[view.category]
		if scroll then
			list.CanvasPosition = scroll
		end
		self.list = list
		self._listKey = key
	end
	for _, r in view.rows do
		local button = self.rows[r.id]
		if button then
			local data = table.clone(r)
			data.selected = not phone and r.id == view.selected
			paintRow(button, data)
		end
	end
end

function BuildMenu:_detail(view: any, phone: boolean)
	local handlers = {
		onCta = function(detail)
			if self._ui.onPlace then
				self._ui.onPlace(detail)
			end
		end,
		onBack = function()
			if self._ui.onBack then
				self._ui.onBack()
			end
		end,
	}
	if view.detail == nil then
		if self._holder then
			self._holder:Destroy()
		end
		self._holder, self.detail = nil, nil
		return
	end
	local back = nil
	if phone then
		for _, tab in view.tabs do
			if tab.id == view.category then
				back = tab.label
			end
		end
	end
	if self.detail and self.detail.key == DetailView.key(view.detail, phone, back) then
		self.detail:update(view.detail, handlers)
		return
	end
	if self._holder then
		self._holder:Destroy()
	end
	local width = self._listWidth
	local holder = Create("Frame", {
		Name = "DetailHolder",
		BackgroundTransparency = 1,
		Position = if phone then UDim2.new() else UDim2.fromOffset(width + 10, 0),
		Size = if phone then UDim2.fromScale(1, 1) else UDim2.new(1, -(width + 10), 1, 0),
	})
	self.detail = DetailView.new({
		detail = view.detail,
		compact = phone,
		back = back,
		onCta = handlers.onCta,
		onBack = handlers.onBack,
	})
	self.detail.instance.Parent = holder
	holder.Parent = self.panel.content
	self._holder = holder
end

function BuildMenu:render(view: any, metrics: any, ui: { [string]: any })
	self._ui = ui
	local phone = metrics.breakpoint == "phone"
	local frameKey = Signature.of({
		breakpoint = metrics.breakpoint,
		drawer = metrics.drawer,
		title = ui.title,
		name = ui.name,
		pane = if phone then ui.phoneView else nil,
		tabs = view.tabs,
		category = view.category,
	})
	if self.panel == nil or frameKey ~= self._frameKey then
		self:_frame(view, metrics, ui)
		self._frameKey = frameKey
	end
	if not phone or ui.phoneView ~= "detail" then
		self:_list(view, phone)
	end
	if not phone or ui.phoneView == "detail" then
		self:_detail(view, phone)
	end
end

-- Drops the instances but remembers the list scroll per tab (a phone's list → detail → list).
function BuildMenu:_teardown()
	if self.list and self._category then
		self._scroll[self._category] = self.list.CanvasPosition
	end
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.list, self._listKey = nil, nil
	self._holder, self.detail = nil, nil
	self._frameKey = nil
	self.rows = {}
end

function BuildMenu:destroy()
	if self.panel == nil then
		return
	end
	self:_teardown()
	self._scroll = {}
end

return BuildMenu
