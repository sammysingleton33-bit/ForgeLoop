--!strict
--[[
	UI/KingdomHud — the always-on AI Kingdoms HUD (interfaces §9 zones; prototype scene "hud"):
		top-left    crest + kingdom name plate ("Keep Lv 1 · 1 region · 12 Crown Points"; phones: the
		            Crown Points sit on the crest), resource pills (food, wood, stone, gold) and,
		            below them, the rulers of the kingdom (not on phones)
		top bar     phase and match clock (a TopbarSafeInsets ScreenGui, centred in the free space)
		right edge  menu rail: Build, Kingdom (+ items controllers add: Army, FL-0060)
		bottom      construction chips, centred in the area an open drawer leaves free
	Small, edge-anchored and translucent so the kingdom stays visible.

	KingdomHud.new(root (scaled HUD root), topbar, motion) -> hud
	hud:render(model, metrics)
		model = { banner: HudModel Banner?, members: { Member }, balances: ResourceBag?,
		          timer: HudModel timer?, queue: { Chip }, menu: string?, hideQueue: boolean?,
		          onMenu: (id) -> (), onPill: (resourceId) -> () }
	hud:refreshTimer(timer?, metrics)        every tick
	hud:refreshQueue(queue, metrics, drawerOpen, hidden?)
	hud:pulse(deltas)                        float each change under its pill (visual confirmation)
	hud:addMenu({ id, icon, label, target?, order? })   another rail button (the next render rebuilds
	                                         the rail); `order` sorts it after the built-in ones
	hud:removeMenu(id)                       takes it away again
	hud.pills[resourceId] -> CurrencyPill handle      hud.rail[id] -> IconButton handle
	Onboarding hooks (FORGE-04, G11): the pill row has OnboardingTarget = "HUD.Resources" and the
	Build button OnboardingTarget = "HUD.BuildButton".
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local CurrencyPill = require("@game/ReplicatedStorage/Forge/UI/Components/CurrencyPill")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Layout = require("./Layout")
local ProgressBar = require("@game/ReplicatedStorage/Forge/UI/Components/ProgressBar")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local KingdomHud = {}
KingdomHud.__index = KingdomHud

KingdomHud.MENUS = table.freeze({
	table.freeze({ id = "build", icon = "build", label = "Build", target = "HUD.BuildButton" }),
	table.freeze({ id = "kingdom", icon = "kingdom", label = "Kingdom" }),
})

function KingdomHud.new(root: Instance, topbar: Instance, motion: any)
	return setmetatable({
		_root = root,
		_topbar = topbar,
		_motion = motion,
		_breakpoint = nil :: string?,
		_kingdomId = nil :: string?,
		pills = {},
		rail = {},
		_chips = {},
		menus = table.clone(KingdomHud.MENUS) :: { any },
	}, KingdomHud)
end

function KingdomHud:addMenu(item: { id: string, icon: string, label: string, target: string?, order: number? })
	for _, menu in self.menus do
		if menu.id == item.id then
			return
		end
	end
	table.insert(self.menus, table.freeze(table.clone(item)))
	local function order(menu: any, index: number): number
		return menu.order or index
	end
	local indexed = {}
	for i, menu in self.menus do
		indexed[i] = { menu = menu, key = order(menu, i), i = i }
	end
	table.sort(indexed, function(a, b)
		if a.key ~= b.key then
			return a.key < b.key
		end
		return a.i < b.i
	end)
	for i, entry in indexed do
		self.menus[i] = entry.menu
	end
	self._breakpoint = nil -- rebuild the rail on the next render
end

function KingdomHud:removeMenu(id: string)
	for i, menu in self.menus do
		if menu.id == id then
			table.remove(self.menus, i)
			self._breakpoint = nil -- rebuild the rail on the next render
			return
		end
	end
end

local function plate(): Frame
	return Create("Frame", {
		Name = "Plate",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 52),
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("gold600"), 1, 0.4),
		Gradient = Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.color("ink800"), Theme.color("ink950")),
			Transparency = NumberSequence.new(0.12, 0.16),
		}),
		Padding = Style.padding(5, 12, 6, 12),
		List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		KingdomName = Style.text({
			text = "",
			role = "display",
			weight = Enum.FontWeight.Bold,
			size = 26,
			color = Theme.color("gold300"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 24), LayoutOrder = 1 },
		}),
		Sub = Style.text({
			text = "",
			weight = Enum.FontWeight.SemiBold,
			size = 12,
			color = Theme.color("textSecondary"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), LayoutOrder = 2 },
		}),
	})
end

function KingdomHud:_build(metrics: any, banner: any)
	if self._container then
		self._container:Destroy()
	end
	-- Own container: the root also holds the UIScale, which must survive rebuilds.
	local container = Create("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = self._root,
	})
	self._container = container
	self.pills = {}
	self.rail = {}
	self._chips = {}
	self._plate = nil
	self._points = nil
	self._members = nil
	local phone = metrics.breakpoint == "phone"
	local h = metrics.hud

	self._crest = Crest.new(h.crest, banner.color, banner.emblem)
	self._crest.Position = UDim2.fromOffset(h.x, h.y)
	self._crest.Parent = container
	if phone then
		local gem = Icon.new("gem", 11) -- Crown Points: never a crown, Emberhold's emblem (D-039)
		gem.LayoutOrder = 1
		self._points = Create("Frame", {
			Name = "CrownPoints",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -7),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 15),
			BackgroundColor3 = Theme.color("ink950"),
			ZIndex = 3,
			Parent = self._crest,
		}, {
			Corner = Style.corner(999),
			Stroke = Style.stroke(Theme.color("gold600"), 1),
			Padding = Style.padding(0, 5, 0, 3),
			List = Style.list("x", 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
			Gem = gem,
			Value = Style.text({
				text = "",
				weight = Enum.FontWeight.Bold,
				size = 10,
				color = Theme.color("gold300"),
				extra = {
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					LayoutOrder = 2,
					ZIndex = 3,
				},
			}),
		})
	else
		self._plate = plate()
		self._plate.Position = UDim2.fromOffset(h.x + h.crest + 10, h.y)
		self._plate.Parent = container
	end

	local pillRow = Create("Frame", {
		Name = "Pills",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(h.pills.x, h.pills.y),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, Layout.PILL_HEIGHT),
		Parent = container,
	}, { List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	pillRow:SetAttribute("OnboardingTarget", "HUD.Resources")
	for i, id in Resources.ids do
		local pill = CurrencyPill.new({
			currency = id,
			loading = true,
			compact = phone,
			sub = if phone then nil else Resources.defs[id].name,
			subColor = Theme.color("textMuted"),
			layoutOrder = i,
		}, self._motion)
		-- A transparent hit area over the pill (the pill's own layout lives in its Row child).
		Create("TextButton", {
			Name = "Hit",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Parent = pill.instance,
			[Create.Event.Activated] = function()
				if self._onPill then
					self._onPill(id)
				end
			end,
		})
		pill.instance.Parent = pillRow
		self.pills[id] = pill
	end

	if h.members then
		self._members = Create("Frame", {
			Name = "Members",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(h.members.x, h.members.y),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, Layout.MEMBERS_HEIGHT),
			Parent = container,
		}, { List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	end

	local rail = Create("Frame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -metrics.rail.right, 0.5, 0),
		Size = UDim2.fromOffset(metrics.rail.button, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = container,
	}, { List = Style.list("y", metrics.rail.gap, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	for i, menu in self.menus do
		local button = IconButton.new({
			icon = menu.icon,
			label = if phone then nil else menu.label,
			size = metrics.rail.button,
			layoutOrder = i,
			onActivated = function()
				if self._onMenu then
					self._onMenu(menu.id)
				end
			end,
		})
		button.instance.Name = "Menu_" .. menu.id
		if menu.target then
			button.instance:SetAttribute("OnboardingTarget", menu.target)
		end
		button.instance.Parent = rail
		self.rail[menu.id] = button
	end

	self._queue = Create("Frame", {
		Name = "Queue",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		Parent = container,
	}, { List = Style.list("x", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })

	Create.clear(self._topbar)
	self._timer = Create("Frame", {
		Name = "Timer",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = self._topbar,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		Gradient = Style.gradient(Theme.color("ink700"), Theme.color("ink950")),
		Padding = Style.padding(0, 14, 0, 6),
		List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Texts = Create("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 2,
		}, {
			List = Style.list("y", 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Phase = Style.text({
				text = "",
				weight = Enum.FontWeight.ExtraBold,
				size = 11,
				color = Theme.color("gold400"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 13), LayoutOrder = 1 },
			}),
			ClockRow = Create("Frame", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 19),
				LayoutOrder = 2,
			}, {
				List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom),
				Clock = Style.text({
					text = "",
					weight = Enum.FontWeight.ExtraBold,
					size = 17,
					color = Theme.color("gold300"),
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 1 },
				}),
				Label = Style.text({
					text = "",
					weight = Enum.FontWeight.SemiBold,
					size = 11,
					color = Theme.color("textSecondary"),
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), LayoutOrder = 2 },
				}),
			}),
		}),
	})
	local hourglass = Icon.new("timer", 28)
	hourglass.LayoutOrder = 1
	hourglass.Parent = self._timer
end

local function memberChip(member: any, color: Color3, order: number): Frame
	return Create("Frame", {
		Name = "Member_" .. tostring(member.userId),
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.18,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, Layout.MEMBERS_HEIGHT),
		LayoutOrder = order,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(if member.you then Theme.color("gold400") else Theme.color("gold600"), 1, 0.3),
		Padding = Style.padding(0, 8, 0, 3),
		List = Style.list("x", 5, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Avatar = Create("TextLabel", {
			Text = member.initial,
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = color,
			TextColor3 = Theme.color("ink950"),
			FontFace = Theme.font("body", Enum.FontWeight.ExtraBold),
			TextSize = 9,
			LayoutOrder = 1,
		}, { Corner = Style.corner(999) }),
		Label = Style.text({
			text = member.name,
			weight = Enum.FontWeight.Bold,
			size = 11,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
		You = if member.you
			then Style.text({
				text = "you",
				weight = Enum.FontWeight.ExtraBold,
				size = 11,
				color = Theme.color("gold400"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 3 },
			})
			else nil,
	})
end

function KingdomHud:render(model: any, metrics: any)
	self._onMenu = model.onMenu
	self._onPill = model.onPill
	local banner = model.banner
	if banner == nil then
		return
	end
	if self._breakpoint ~= metrics.breakpoint or self._kingdomId ~= banner.id then
		self._breakpoint = metrics.breakpoint
		self._kingdomId = banner.id
		self:_build(metrics, banner)
	end
	Crest.recolor(self._crest, banner.color)
	if self._plate then
		self._plate.KingdomName.Text = banner.name
		self._plate.Sub.Text = banner.sub
	end
	if self._points then
		self._points.Value.Text = Format.amount(banner.crownPoints)
	end
	for _, id in Resources.ids do
		local pill = self.pills[id]
		if model.balances then
			pill:update({ loading = false, amount = model.balances[id] or 0 })
		else
			pill:update({ loading = true })
		end
	end
	if self._members then
		Create.clear(self._members)
		Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = self._members
		for i, member in model.members do
			memberChip(member, banner.color, i).Parent = self._members
		end
	end
	for id, button in self.rail do
		button:update({ selected = model.menu == id })
	end
	self:refreshTimer(model.timer, metrics)
	self:refreshQueue(model.queue or {}, metrics, model.menu ~= nil, model.hideQueue)
end

function KingdomHud:refreshTimer(timer: any, metrics: any)
	if self._timer == nil then
		return
	end
	if timer == nil or timer.phase == "" then
		self._timer.Visible = false
		return
	end
	local phone = metrics.breakpoint == "phone"
	self._timer.Visible = true
	local texts = self._timer.Texts
	texts.Phase.Text = string.upper(timer.phase)
	local row = texts.ClockRow
	row.Visible = timer.clock ~= nil
	row.Clock.Text = timer.clock or ""
	row.Label.Text = if phone then "" else timer.label or ""
	row.Label.Visible = not phone and timer.label ~= nil
end

function KingdomHud:refreshQueue(queue: { any }, metrics: any, drawerOpen: boolean, hidden: boolean?)
	if self._queue == nil then
		return
	end
	local free = Layout.freeArea(metrics, drawerOpen)
	self._queue.Position = UDim2.new(0, math.floor(free.x + free.width / 2), 1, -metrics.queue.bottom)
	self._queue.Visible = not hidden
	local seen = {}
	for i, item in queue do
		seen[item.id] = true
		local entry = self._chips[item.id]
		if entry == nil then
			local bar = ProgressBar.new({ progress = item.progress, width = UDim.new(0, 64), layoutOrder = 3 })
			local tile = Icon.tile(item.icon, 28, item.category)
			tile.LayoutOrder = 1
			local chip = Create("Frame", {
				Name = "Chip_" .. tostring(item.id),
				BackgroundColor3 = Color3.new(1, 1, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 36),
				LayoutOrder = i,
				Parent = self._queue,
			}, {
				Corner = Style.corner(999),
				Stroke = Style.stroke(Theme.color("gold700"), 1.5),
				Gradient = Create("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Theme.color("ink700"), Theme.color("ink950")),
					Transparency = NumberSequence.new(0.06, 0.08),
				}),
				Padding = Style.padding(0, 12, 0, 4),
				List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Tile = tile,
				Label = Style.text({
					text = if item.level > 1 then `{item.name} Lv {item.level}` else item.name,
					weight = Enum.FontWeight.Bold,
					size = 12,
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
				}),
				Bar = bar.instance,
				State = Style.text({
					text = "",
					weight = Enum.FontWeight.ExtraBold,
					size = 12,
					color = Theme.color("gold300"),
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 4 },
				}),
			})
			entry = { chip = chip, bar = bar }
			self._chips[item.id] = entry
		end
		entry.chip.LayoutOrder = i
		entry.bar:update({ progress = item.progress })
		entry.chip.State.Text = if item.waiting then "waiting" else `{math.floor(item.progress * 100)}%`
	end
	for id, entry in self._chips do
		if not seen[id] then
			entry.chip:Destroy()
			self._chips[id] = nil
		end
	end
end

function KingdomHud:pulse(deltas: { [string]: number })
	for currency, amount in deltas do
		local pill = self.pills[currency]
		if pill and amount ~= 0 then
			pill:pulse(amount)
		end
	end
end

function KingdomHud:destroy()
	if self._container then
		self._container:Destroy()
		self._container = nil
	end
	Create.clear(self._topbar)
	self._breakpoint = nil
end

return KingdomHud
