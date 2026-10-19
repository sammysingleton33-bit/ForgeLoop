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
	hud:refreshTimer(timer?, metrics)        every tick; builds the pill if the HUD never was (a watcher)
	hud:setTimerNote(text?)                  one line under the pill ("TimerNote")
	hud:refreshQueue(queue, metrics, drawerOpen, hidden?)
	hud:pulse(deltas)                        float each change under its pill (visual confirmation)
	hud:addMenu({ id, icon, label, target?, order? })   another rail button (the next render rebuilds
	                                         the rail); `order` sorts it after the built-in ones
	hud:removeMenu(id)                       takes it away again
	hud:setRailBadge(id, count?)             a count bubble on that rail button; an item added with
	                                         `hideEmpty` is hidden while the count is 0 or nil (FL-0115:
	                                         "Waiting", the citizens with an open request)
	hud.pills[resourceId] -> CurrencyPill handle      hud.rail[id] -> IconButton handle
	Onboarding hooks (FORGE-04, G11): the pill row has OnboardingTarget = "HUD.Resources" and the
	Build button OnboardingTarget = "HUD.BuildButton", the Kingdom button "HUD.KingdomButton" (FL-0138 for FORGE-04's
	FL-0137 tips; the Raid rail button is "HUD.RaidButton", KingdomHudController.RAID_RAIL).
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
	table.freeze({ id = "kingdom", icon = "kingdom", label = "Kingdom", target = "HUD.KingdomButton" }),
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
		_railBadges = {} :: { [string]: number },
		_chips = {},
		menus = table.clone(KingdomHud.MENUS) :: { any },
	}, KingdomHud)
end

function KingdomHud:addMenu(item: {
	id: string,
	icon: string,
	label: string,
	target: string?,
	order: number?,
	hideEmpty: boolean?,
})
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

-- A count bubble on a rail button, kept across rail rebuilds (a breakpoint change rebuilds the rail).
function KingdomHud:setRailBadge(id: string, count: number?)
	self._railBadges[id] = count
	self:_applyBadge(id)
end

function KingdomHud:_applyBadge(id: string)
	local button = self.rail[id]
	if button == nil then
		return
	end
	local count = self._railBadges[id]
	-- 0, not nil: a nil field is no field, so update() would keep the old bubble (IconButton hides 0)
	button:update({ badge = count or 0 })
	for _, menu in self.menus do
		if menu.id == id and menu.hideEmpty then
			button.instance.Visible = count ~= nil and count > 0
		end
	end
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

-- The Crown Points gem: never a crown, which is Emberhold's emblem (D-039). Drawn (a gold diamond with
-- a light facet) until gem.png is uploaded: the 💎 glyph is a blue colour emoji on most platforms,
-- which reads as a premium currency and as Frostmere's blue (FORGE-05 L6 on #86).
function KingdomHud.gem(size: number): GuiObject
	if Icon.hasImage("gem") then
		return Icon.new("gem", size)
	end
	local gem = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
	}, {
		Stone = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.62, 0.62),
			Rotation = 45,
			BackgroundColor3 = Theme.color("gold400"),
			BorderSizePixel = 0,
		}, { Edge = Style.stroke(Theme.color("gold700"), 1) }),
		Facet = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.4),
			Size = UDim2.fromScale(0.24, 0.24),
			Rotation = 45,
			BackgroundColor3 = Theme.color("gold300"),
			BorderSizePixel = 0,
			ZIndex = 2,
		}),
	})
	gem:SetAttribute("drawn", "gem")
	return gem
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
		local gem = KingdomHud.gem(11)
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

	-- one row; a narrow phone (Layout: pills.columns 2) wraps them into a 2 × 2 grid
	local wrapped = h.pills.columns ~= nil and h.pills.columns < #Resources.ids
	local pillRow = Create("Frame", {
		Name = "Pills",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(h.pills.x, h.pills.y),
		AutomaticSize = if wrapped then Enum.AutomaticSize.None else Enum.AutomaticSize.X,
		Size = if wrapped
			then UDim2.fromOffset(
				h.pills.columns * Layout.PHONE_PILL + (h.pills.columns - 1) * Layout.PHONE_PILL_GAP,
				h.pills.height
			)
			else UDim2.fromOffset(0, Layout.PILL_HEIGHT),
		Parent = container,
	}, {
		List = if wrapped
			then Create("UIGridLayout", {
				CellSize = UDim2.fromOffset(Layout.PHONE_PILL, Layout.PILL_HEIGHT),
				CellPadding = UDim2.fromOffset(Layout.PHONE_PILL_GAP, Layout.PHONE_PILL_GAP),
				SortOrder = Enum.SortOrder.LayoutOrder,
			})
			else Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
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
		self:_applyBadge(menu.id)
	end

	self._queue = Create("Frame", {
		Name = "Queue",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		Parent = container,
	}, { List = Style.list("x", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })

	self:_buildTimer()
end

-- The phase pill in the top bar, and the note line under it (setTimerNote). Built with the HUD, or on
-- the first refreshTimer for a player who never had a kingdom HUD (a match_full watcher, FL-0129).
function KingdomHud:_buildTimer()
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
	-- The full match's phase track and what comes next (FL-0129): a third column, so the pill grows
	-- sideways in the top bar's fixed height; built empty, filled by refreshTimer, hidden on phones.
	Create("Frame", {
		Name = "Ahead",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 3,
		Visible = false,
		Parent = self._timer,
	}, {
		List = Style.list("y", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Track = Create("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, KingdomHud.TRACK_HEIGHT),
			LayoutOrder = 1,
		}, { List = Style.list("x", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) }),
		Next = Style.text({
			text = "",
			weight = Enum.FontWeight.SemiBold,
			size = 11,
			color = Theme.color("textSecondary"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 13), LayoutOrder = 2 },
		}),
	})
	self._noteLabel = Style.text({
		text = self._note or "",
		weight = Enum.FontWeight.SemiBold,
		size = 12,
		color = Theme.color("gold300"),
		xAlign = "Center",
		extra = {
			Name = "TimerNote",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, 23),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 20),
			BackgroundColor3 = Theme.color("ink950"),
			BackgroundTransparency = 0.25, -- readable over a bright sky
			Visible = false,
			Parent = self._topbar,
		},
	})
	Style.corner(999).Parent = self._noteLabel
	Style.padding(0, 10).Parent = self._noteLabel
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
	local show = timer ~= nil and timer.phase ~= ""
	if self._timer == nil then
		if not show then
			return
		end
		self:_buildTimer()
	end
	if self._noteLabel then
		self._noteLabel.Text = self._note or ""
		self._noteLabel.Visible = show and self._note ~= nil
	end
	if not show then
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
	self:_refreshAhead(timer, phone)
end

-- The phase track: one segment per phase, the ones done dim gold, the current one bright, the rest ink.
KingdomHud.TRACK_SEGMENT = 18
KingdomHud.TRACK_HEIGHT = 5
function KingdomHud:_refreshAhead(timer: any, phone: boolean)
	local ahead = self._timer and self._timer:FindFirstChild("Ahead")
	if ahead == nil then
		return
	end
	local show = not phone and timer.step ~= nil and timer.steps ~= nil
	ahead.Visible = show
	if not show then
		return
	end
	local track = ahead.Track
	for i = 1, timer.steps do
		local segment = track:FindFirstChild("Step_" .. i)
		if segment == nil then
			segment = Create("Frame", {
				Name = "Step_" .. i,
				Size = UDim2.fromOffset(KingdomHud.TRACK_SEGMENT, KingdomHud.TRACK_HEIGHT),
				BorderSizePixel = 0,
				LayoutOrder = i,
				Parent = track,
			}, { Corner = Style.corner(999) })
		end
		local state = if i < timer.step then "done" elseif i == timer.step then "now" else "ahead"
		segment.BackgroundColor3 = if state == "now"
			then Theme.color("gold400")
			elseif state == "done" then Theme.color("gold700")
			else Theme.color("ink600")
		segment:SetAttribute("state", state)
	end
	for _, child in track:GetChildren() do
		local n = tonumber(string.match(child.Name, "^Step_(%d+)$"))
		if n and n > timer.steps then
			child:Destroy()
		end
	end
	local next = if timer.next then `Next: {timer.next}` else "Last phase"
	ahead.Next.Text = if timer.nextNote then `{next} · {timer.nextNote}` else next
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
	self._timer = nil
	self._noteLabel = nil
	self._breakpoint = nil
end

-- One line under the phase pill (nil: none), e.g. "You'll join the next match" for a match_full
-- watcher (FL-0129); shown on the next refreshTimer, which runs every tick.
function KingdomHud:setTimerNote(text: string?)
	self._note = text
	if self._noteLabel then
		self._noteLabel.Text = text or ""
		self._noteLabel.Visible = text ~= nil and self._timer ~= nil and self._timer.Visible
	end
end

return KingdomHud
