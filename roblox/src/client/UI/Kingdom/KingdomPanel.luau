--!strict
--[[
	UI/Kingdom/KingdomPanel — kingdom information and citizen/building management.
	Tabs: Overview (crest, name, Town Hall level, territory, citizens by job, production and
	storage per resource) and Buildings (each building with its level, construction progress,
	worker steppers and Upgrade). Upgrade opens the shared DetailView with the next level's costs.

	KingdomPanel.new(parent) -> panel
	panel:render(model, metrics, ui)
		model = { tab: "overview" | "buildings" | "upgrade", overview = KingdomPanelModel.overview,
		          buildings = KingdomPanelModel.buildings rows, upgrade = BuildMenuModel Detail? }
		ui = { onTab(id), onWorkers(uid, count), onUpgradeOpen(uid), onUpgrade(detail), onBack(), onClose() }
	panel:refreshProgress(rows)   updates construction bars in place (called every tick; no rebuild,
	                              so a finger on a stepper never loses its button)
	panel:destroy()
]]

local Button = require("../Components/Button")
local Create = require("../Create")
local DetailView = require("./DetailView")
local Format = require("../Format")
local Icon = require("../Icon")
local IconButton = require("../Components/IconButton")
local Panel = require("../Components/Panel")
local ProgressBar = require("../Components/ProgressBar")
local Style = require("../Style")
local Tabs = require("../Components/Tabs")
local Theme = require("../Theme")

local KingdomPanel = {}
KingdomPanel.__index = KingdomPanel

function KingdomPanel.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, bars = {}, steppers = {} }, KingdomPanel)
end

local function crest(size: number, tincture: string): Frame
	local icon = Icon.new("crown", math.floor(size * 0.66))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	local base = Theme.tincture(tincture)
	return Create("Frame", {
		Name = "Crest",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	}, {
		Corner = Style.corner(12),
		Stroke = Style.stroke(Theme.color("gold500"), 2),
		Gradient = Style.gradient(base:Lerp(Color3.new(1, 1, 1), 0.15), base:Lerp(Color3.new(0, 0, 0), 0.3)),
		Icon = icon,
	})
end
KingdomPanel.crest = crest

local function section(title: string, icon: string, right: string?, order: number): Frame
	local i = Icon.new(icon, 18)
	i.LayoutOrder = 1
	local head = Create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 0,
	}, {
		List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = i,
		Title = Style.text({
			text = title,
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = 13,
			color = Theme.color("gold300"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	})
	if right then
		Style.text({
			text = right,
			weight = Enum.FontWeight.Bold,
			size = 12,
			xAlign = "Right",
			extra = { Name = "Right", Size = UDim2.new(1, -150, 1, 0), LayoutOrder = 3 },
		}).Parent =
			head
	end
	return Create("Frame", {
		Name = "Section_" .. title,
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		Padding = Style.padding(8, 10),
		List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Head = head,
	})
end

function KingdomPanel:_overview(content: Instance, o: any, phone: boolean)
	local scroll = Create("ScrollingFrame", {
		Name = "Overview",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color("gold600"),
		Parent = content,
	}, { List = Style.list("y", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	if not phone then
		local sub = `Town Hall Lv {o.hall} · {o.tiles} territory tiles`
		if o.rank and o.kingdoms then
			sub ..= ` · Rank {o.rank} of {o.kingdoms}`
		end
		Create("Frame", {
			Name = "Banner",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 60),
			LayoutOrder = 1,
			Parent = scroll,
		}, {
			Crest = crest(56, o.tincture),
			Titles = Create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(68, 0),
				Size = UDim2.new(1, -68, 1, 0),
			}, {
				List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				KingdomName = Style.text({
					text = "Kingdom of " .. o.name,
					role = "display",
					weight = Enum.FontWeight.Bold,
					size = 30,
					color = Theme.color("gold300"),
					extra = { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 1 },
				}),
				Sub = Style.text({
					text = sub,
					weight = Enum.FontWeight.SemiBold,
					size = 12,
					color = Theme.color("textSecondary"),
					extra = { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
				}),
			}),
		})
	end
	local c = o.citizens
	local citizens = section("Citizens", "citizens", `{c.total} / {c.housing} housed`, 2)
	citizens.Parent = scroll
	local housing = math.max(1, c.housing, c.total)
	local seg = Create("Frame", {
		Name = "Jobs",
		BackgroundColor3 = Theme.color("scrim"),
		Size = UDim2.new(1, 0, 0, 12),
		ClipsDescendants = true,
		LayoutOrder = 1,
		Parent = citizens,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		List = Style.list("x", 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	local legend = Create("Frame", {
		Name = "Legend",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 2,
		Parent = citizens,
	}, { List = Style.list("x", 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	for i, part in
		{ { "Working", c.working, "vert" }, { "Building", c.building, "gold500" }, { "Idle", c.idle, "amber" } }
	do
		Create("Frame", {
			Name = part[1],
			BackgroundColor3 = Theme.color(part[3]),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(part[2] / housing, 1),
			LayoutOrder = i,
			Parent = seg,
		})
		Style.text({
			text = `{part[1]} {part[2]}`,
			weight = Enum.FontWeight.SemiBold,
			size = 11,
			color = if part[1] == "Idle" and part[2] > 0 then Theme.color("amber") else Theme.color("textSecondary"),
			extra = {
				Name = "Legend" .. part[1],
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = i,
			},
		}).Parent =
			legend
	end
	local production = section("Production & storage", "storehouse", nil, 3)
	production.Parent = scroll
	for i, row in o.production do
		local icon = Icon.new(row.currency, 20)
		icon.LayoutOrder = 1
		local bar = ProgressBar.new({
			progress = if row.cap > 0 then row.amount / row.cap else 0,
			color = Theme.resource(row.currency),
			width = UDim.new(1, -170),
			layoutOrder = 3,
		})
		Create("Frame", {
			Name = "Resource_" .. row.currency,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = i,
			Parent = production,
		}, {
			List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Icon = icon,
			Rate = Style.text({
				text = if row.perMinute > 0 then Format.rate(row.perMinute) else "—",
				weight = Enum.FontWeight.ExtraBold,
				size = 12,
				color = if row.perMinute > 0 then Theme.hex("#A9E57C") else Theme.color("textMuted"),
				extra = { Size = UDim2.new(0, 64, 1, 0), LayoutOrder = 2 },
			}),
			Bar = bar.instance,
			Storage = Style.text({
				text = `{Format.amount(row.amount)} / {Format.amount(row.cap)}`,
				size = 11,
				color = Theme.color("textSecondary"),
				xAlign = "Right",
				extra = { Size = UDim2.new(0, 70, 1, 0), LayoutOrder = 4 },
			}),
		})
	end
end

function KingdomPanel:_buildings(content: Instance, rows: { any }, phone: boolean, ui: any)
	local scroll = Create("ScrollingFrame", {
		Name = "Buildings",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color("gold600"),
		Parent = content,
	}, {
		List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Padding = Style.padding(1, 4, 1, 1),
	})
	local tile = if phone then 34 else 40
	for i, row in rows do
		local sub
		if row.progress ~= nil then
			local bar = ProgressBar.new({ progress = row.progress, width = UDim.new(1, -40), layoutOrder = 1 })
			self.bars[row.uid] = bar
			sub = Create("Frame", {
				Name = "Progress",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = 2,
			}, {
				List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Bar = bar.instance,
				Time = Style.text({
					text = Format.clock(row.timeLeft or 0),
					weight = Enum.FontWeight.ExtraBold,
					size = 11,
					color = Theme.color("gold300"),
					extra = { Size = UDim2.new(0, 34, 1, 0), LayoutOrder = 2 },
				}),
			})
		else
			local parts = {}
			for _, r in row.rate do
				table.insert(parts, `{Format.rate(r.perMinute)}`)
			end
			if row.housing then
				table.insert(parts, `Houses {row.housing}`)
			end
			if row.storage then
				table.insert(parts, `+{row.storage} storage`)
			end
			if row.slots > 0 and #row.rate == 0 then
				table.insert(parts, "No workers")
			end
			sub = Style.text({
				text = if #parts > 0 then table.concat(parts, " · ") else "Ready",
				weight = Enum.FontWeight.SemiBold,
				size = 11,
				color = Theme.color("textSecondary"),
				extra = { Name = "Sub", Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
			})
		end
		local controls = Create("Frame", {
			Name = "Controls",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 36),
		}, { List = Style.list("x", 4, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center) })
		local controlsWidth = 0
		if row.slots > 0 and row.state ~= "constructing" then
			local minus = IconButton.new({
				icon = "minus",
				variant = "plain",
				size = 32,
				disabled = not row.canRemove,
				layoutOrder = 1,
				onActivated = function()
					ui.onWorkers(row.uid, row.workers - 1)
				end,
			})
			minus.instance.Name = "Minus"
			minus.instance.Parent = controls
			Style.text({
				text = `{row.workers}/{row.slots}`,
				weight = Enum.FontWeight.ExtraBold,
				size = 13,
				xAlign = "Center",
				extra = { Name = "Workers", Size = UDim2.fromOffset(36, 32), LayoutOrder = 2 },
			}).Parent =
				controls
			local plus = IconButton.new({
				icon = "plus",
				variant = "plain",
				size = 32,
				disabled = not row.canAdd,
				layoutOrder = 3,
				onActivated = function()
					ui.onWorkers(row.uid, row.workers + 1)
				end,
			})
			plus.instance.Name = "Plus"
			plus.instance.Parent = controls
			self.steppers[row.uid] = { minus = minus, plus = plus }
			controlsWidth += 112
		end
		if row.canUpgrade then
			local up = Button.new({
				text = if phone then "" else row.upgradeText,
				icon = "build",
				variant = "secondary",
				size = "small",
				width = if phone then 36 else 96,
				layoutOrder = 4,
				onActivated = function()
					ui.onUpgradeOpen(row.uid)
				end,
			})
			up.instance.Name = "Upgrade"
			up.instance.Parent = controls
			controlsWidth += if phone then 40 else 100
		end
		local button = Create("Frame", {
			Name = "Building_" .. row.uid,
			BackgroundColor3 = Theme.color("ink700"),
			Size = UDim2.new(1, 0, 0, tile + 12),
			LayoutOrder = i,
			Parent = scroll,
		}, {
			Corner = Style.corner(10),
			Stroke = Style.stroke(Theme.color("ink500"), 1),
			Padding = Style.padding(6, 8, 6, 6),
			Tile = Icon.tile(row.icon, tile, row.category),
			Text = Create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(tile + 8, 0),
				Size = UDim2.new(1, -(tile + 8 + controlsWidth), 1, 0),
			}, {
				List = Style.list("y", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Title = Style.text({
					text = if row.level >= 1 then `{row.name}  Lv {row.level}` else row.name,
					role = "heading",
					weight = Enum.FontWeight.Bold,
					size = 13,
					color = Theme.color("parchment100"),
					extra = { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 },
				}),
				Sub = sub,
			}),
			Controls = controls,
		})
		button:SetAttribute("uid", row.uid)
	end
	if #rows == 0 then
		Style.text({
			text = "No buildings yet. Open Build to place your first Farm.",
			size = 12,
			color = Theme.color("textMuted"),
			xAlign = "Center",
			wrap = true,
			extra = { Size = UDim2.new(1, 0, 0, 40) },
		}).Parent =
			scroll
	end
end

function KingdomPanel:render(model: any, metrics: any, ui: { [string]: any })
	if self.panel then
		self.panel:destroy()
	end
	self.bars = {}
	self.steppers = {}
	local phone = metrics.breakpoint == "phone"
	local d = metrics.drawer
	local header = Create("Frame", { Name = "HeaderRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local tabs = Tabs.new({
		tabs = {
			{ id = "overview", label = "Overview", icon = "crown" },
			{ id = "buildings", label = "Buildings", icon = "townhall" },
		},
		selected = if model.tab == "upgrade" then "buildings" else model.tab,
		compact = phone,
		onSelect = ui.onTab,
	})
	tabs.instance.Parent = header
	self.tabs = tabs
	local close = IconButton.new({ icon = "close", variant = "plain", size = 36, onActivated = ui.onClose })
	close.instance.Name = "Close"
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.fromScale(1, 0.5)
	close.instance.Parent = header
	self.panel = Panel.new({
		title = if phone then nil else "Kingdom",
		header = header,
		size = UDim2.fromOffset(d.width, d.height),
		position = UDim2.fromOffset(d.x, d.y),
		padding = if phone then 10 else 12,
	})
	self.panel.instance.Name = "KingdomPanel"
	local content = self.panel.content
	if model.tab == "overview" then
		self:_overview(content, model.overview, phone)
	elseif model.tab == "upgrade" and model.upgrade then
		self.detail = DetailView.new({
			detail = model.upgrade,
			compact = phone,
			back = "Buildings",
			paid = model.upgradePaid,
			progress = model.upgradeProgress,
			onCta = ui.onUpgrade,
			onBack = ui.onBack,
		})
		self.detail.instance.Parent = content
	else
		self:_buildings(content, model.buildings, phone, ui)
	end
	self.panel.instance.Parent = self._parent
end

function KingdomPanel:refreshProgress(rows: { any })
	for _, row in rows do
		local bar = self.bars[row.uid]
		if bar and row.progress then
			bar:update({ progress = row.progress })
			local time = bar.instance.Parent and bar.instance.Parent:FindFirstChild("Time")
			if time then
				time.Text = Format.clock(row.timeLeft or 0)
			end
		end
	end
end

function KingdomPanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
end

return KingdomPanel
