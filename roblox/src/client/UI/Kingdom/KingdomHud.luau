--!strict
--[[
	UI/Kingdom/KingdomHud — the always-on kingdom HUD (interfaces §9 zones):
		top-left    crest + kingdom name/level plate (not on phones) and the resource pills
		            (food, wood, stone, gold; citizens as a pill, or a chip under the crest on phones)
		top bar     match timer (TopbarSafeInsets ScreenGui, centred in the free top-bar space)
		right edge  menu rail: Build, Kingdom (badge = idle citizens)
		bottom      construction queue chips, centred in the area an open drawer leaves free
	Small, edge-anchored and translucent so the kingdom stays visible.

	KingdomHud.new(root: GuiObject (scaled HUD root), topbar: GuiObject, motion) -> hud
	hud:render(model, metrics)
		model = { kingdom?, treasury?, overview?, queue: { QueueItem }, timer: { text, label? }?,
		          menu: "build" | "kingdom" | nil, onMenu: (id) -> () }
	hud:pulse(delta: Bundle)       float the change under each pill (visual confirmation)
	hud:refreshQueue(queue, metrics, drawerOpen)   progress only (every tick)
	hud.pills[currency] -> CurrencyPill handle      hud.rail[id] -> IconButton handle
]]

local Create = require("../Create")
local CurrencyPill = require("../Components/CurrencyPill")
local Format = require("../Format")
local Icon = require("../Icon")
local IconButton = require("../Components/IconButton")
local KingdomPanel = require("./KingdomPanel")
local Layout = require("../Layout")
local ProgressBar = require("../Components/ProgressBar")
local Style = require("../Style")
local Theme = require("../Theme")

local KingdomHud = {}
KingdomHud.__index = KingdomHud

KingdomHud.MENUS = table.freeze({
	{ id = "build", icon = "build", label = "Build" },
	{ id = "kingdom", icon = "kingdom", label = "Kingdom" },
})

function KingdomHud.new(root: Instance, topbar: Instance, motion: any)
	return setmetatable({
		_root = root,
		_topbar = topbar,
		_motion = motion,
		_breakpoint = nil,
		pills = {},
		rail = {},
		_queueBars = {},
	}, KingdomHud)
end

function KingdomHud:_build(metrics: any, currencyIds: { string })
	if self._container then
		self._container:Destroy()
	end
	-- Own container: the root also holds the UIScale, which must survive rebuilds.
	self._container = Create("Frame", {
		Name = "Hud",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = self._root,
	})
	local container = self._container
	self.pills = {}
	self.rail = {}
	self._queueBars = {}
	self._plate = nil
	self._population = nil
	local phone = metrics.breakpoint == "phone"
	local h = metrics.hud
	-- Kingdom badge: crest (+ population chip on phones) and the name plate.
	self._crest = KingdomPanel.crest(h.crest, "azure")
	self._crest.Position = UDim2.fromOffset(h.x, h.y)
	self._crest.Parent = container
	if phone then
		self._population = Create("TextLabel", {
			Name = "Population",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, -7),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 15),
			BackgroundColor3 = Theme.color("ink950"),
			TextSize = 10,
			FontFace = Theme.font("body", Enum.FontWeight.Bold),
			TextColor3 = Theme.resource("citizens"),
			Text = "",
			ZIndex = 3,
			Parent = self._crest,
		}, {
			Corner = Style.corner(999),
			Stroke = Style.stroke(Theme.color("gold600"), 1),
			Padding = Style.padding(0, 5),
		})
	else
		self._plate = Create("Frame", {
			Name = "Plate",
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = UDim2.fromOffset(h.x + h.crest + 10, h.y),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, h.crest),
			Parent = container,
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
	-- Resource pills.
	local pillsPos = if phone
		then UDim2.fromOffset(h.x + h.crest + 8, h.y + 2)
		else UDim2.fromOffset(h.x, h.y + h.crest + 8)
	local row = Create("Frame", {
		Name = "Pills",
		BackgroundTransparency = 1,
		Position = pillsPos,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
		Parent = container,
	}, { List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	for i, id in currencyIds do
		local pill = CurrencyPill.new({ currency = id, loading = true, compact = phone, layoutOrder = i }, self._motion)
		pill.instance.Parent = row
		self.pills[id] = pill
	end
	if not phone then
		local citizens = CurrencyPill.new({ currency = "citizens", loading = true, layoutOrder = 99 })
		citizens.instance.Parent = row
		self.pills.citizens = citizens
	end
	-- Menu rail.
	local rail = Create("Frame", {
		Name = "Rail",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -metrics.rail.right, 0.5, 0),
		Size = UDim2.fromOffset(metrics.rail.button, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = container,
	}, { List = Style.list("y", metrics.rail.gap, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
	for i, menu in KingdomHud.MENUS do
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
		button.instance.Parent = rail
		self.rail[menu.id] = button
	end
	-- Construction queue.
	self._queue = Create("Frame", {
		Name = "Queue",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		Parent = container,
	}, { List = Style.list("x", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	-- Match timer (top bar).
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
		Icon = Icon.new("timer", 28),
		Texts = Create("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 2,
		}, {
			List = Style.list("y", 1, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Time = Style.text({
				text = "",
				weight = Enum.FontWeight.ExtraBold,
				size = 18,
				color = Theme.color("gold300"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 19), LayoutOrder = 1 },
			}),
			Label = Style.text({
				text = "",
				weight = Enum.FontWeight.SemiBold,
				size = 11,
				color = Theme.color("textSecondary"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 12), LayoutOrder = 2 },
			}),
		}),
	})
	self._timer:FindFirstChild("Icon").LayoutOrder = 1
end

function KingdomHud:render(model: any, metrics: any, currencyIds: { string })
	self._onMenu = model.onMenu
	if self._breakpoint ~= metrics.breakpoint then
		self._breakpoint = metrics.breakpoint
		self:_build(metrics, currencyIds)
	end
	local phone = metrics.breakpoint == "phone"
	local k, t, o = model.kingdom, model.treasury, model.overview
	if k then
		local tincture = Theme.tincture(k.tincture or "azure")
		local gradient = self._crest:FindFirstChildOfClass("UIGradient")
		if gradient then
			gradient.Color =
				ColorSequence.new(tincture:Lerp(Color3.new(1, 1, 1), 0.15), tincture:Lerp(Color3.new(0, 0, 0), 0.3))
		end
		if self._plate then
			self._plate.KingdomName.Text = k.name
			self._plate.Sub.Text = `Town Hall Lv {k.hall or 1} · {if k.territory then k.territory.tiles else 0} tiles`
		end
	end
	for _, id in currencyIds do
		local pill = self.pills[id]
		if t then
			local rate = nil
			if o then
				for _, row in o.production do
					if row.currency == id then
						rate = row.perMinute
					end
				end
			end
			pill:update({ loading = false, amount = t.balances[id] or 0, cap = t.caps[id], rate = rate })
		else
			pill:update({ loading = true })
		end
	end
	if o then
		local c = o.citizens
		if self.pills.citizens then
			self.pills.citizens:update({
				loading = false,
				amount = c.total,
				cap = c.housing,
				sub = `{c.idle} idle`,
				subColor = if c.idle > 0 then Theme.color("amber") else Theme.color("textMuted"),
			})
		end
		if self._population then
			self._population.Text = `👥 {c.total}/{c.housing}`
		end
		self.rail.kingdom:update({ badge = c.idle })
	end
	for id, button in self.rail do
		button:update({ selected = model.menu == id })
	end
	if model.timer then
		self._timer.Visible = true
		self._timer.Texts.Time.Text = model.timer.text
		self._timer.Texts.Label.Text = if phone then "" else (model.timer.label or "")
		self._timer.Texts.Label.Visible = not phone and model.timer.label ~= nil
	else
		self._timer.Visible = false
	end
	self:refreshQueue(model.queue or {}, metrics, model.menu ~= nil)
end

function KingdomHud:refreshQueue(queue: { any }, metrics: any, drawerOpen: boolean)
	local free = Layout.freeArea(metrics, drawerOpen)
	self._queue.Position = UDim2.new(0, math.floor(free.x + free.width / 2), 1, -metrics.queue.bottom)
	local seen = {}
	for i, item in queue do
		seen[item.uid] = true
		local entry = self._queueBars[item.uid]
		if entry == nil then
			local bar = ProgressBar.new({ progress = item.progress, width = UDim.new(0, 64), layoutOrder = 3 })
			local tile = Icon.tile(item.icon, 28, item.category)
			tile.LayoutOrder = 1
			local chip = Create("Frame", {
				Name = "Chip_" .. item.uid,
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
					text = if item.upgrade then item.name .. " ↑" else item.name,
					weight = Enum.FontWeight.Bold,
					size = 12,
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
				}),
				Bar = bar.instance,
				Time = Style.text({
					text = "",
					weight = Enum.FontWeight.ExtraBold,
					size = 12,
					color = Theme.color("gold300"),
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 4 },
				}),
			})
			entry = { chip = chip, bar = bar }
			self._queueBars[item.uid] = entry
		end
		entry.chip.LayoutOrder = i
		entry.bar:update({ progress = item.progress })
		entry.chip.Time.Text = Format.clock(item.timeLeft or 0)
	end
	for uid, entry in self._queueBars do
		if not seen[uid] then
			entry.chip:Destroy()
			self._queueBars[uid] = nil
		end
	end
end

function KingdomHud:pulse(delta: { [string]: number })
	for currency, amount in delta do
		local pill = self.pills[currency]
		if pill and amount ~= 0 then
			pill:pulse(amount)
		end
	end
end

return KingdomHud
