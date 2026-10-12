--!strict
--[[
	UI/KingdomPanel — kingdom information and building upgrades (prototype scenes "kingdom",
	"kingdom-buildings", "upgrade").
		Overview   crest, name, keep level, regions, Crown Points; the rulers; standings of all four
		           kingdoms by Crown Points (yours highlighted, AI kingdoms marked)
		Buildings  each of your buildings with level and state (construction progress), and Upgrade
		           where a next level exists
		Upgrade    the shared DetailView with the next level's costs (Build.Upgrade)

	KingdomPanel.new(parent) -> panel
	panel:render(model, metrics, ui)
		model = { tab: "overview" | "buildings" | "upgrade", banner, members, standings,
		          buildings: { Row }, upgrade: BuildModel Detail? }
			Row = { id, type, name, icon, category, level, state, progress, canUpgrade }
		ui = { onTab(id), onUpgradeOpen(buildingId), onUpgrade(detail), onBack(), onClose() }
	panel:destroy()
	Building rows are named "Building_<id>"; their Upgrade button "Upgrade".
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local DetailView = require("./DetailView")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local ProgressBar = require("@game/ReplicatedStorage/Forge/UI/Components/ProgressBar")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Tabs = require("@game/ReplicatedStorage/Forge/UI/Components/Tabs")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local KingdomPanel = {}
KingdomPanel.__index = KingdomPanel

KingdomPanel.TABS = table.freeze({
	table.freeze({ id = "overview", label = "Overview", icon = "crown" }),
	table.freeze({ id = "buildings", label = "Buildings", icon = "keep" }),
})

function KingdomPanel.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, detail = nil, rows = {} }, KingdomPanel)
end

local function section(title: string, icon: string, right: string?, order: number): Frame
	local i = Icon.new(icon, 18)
	i.LayoutOrder = 1
	local head = Create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 0,
	}, {
		Icon = i,
		Title = Style.text({
			text = title,
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = 13,
			color = Theme.color("gold300"),
			extra = { Position = UDim2.fromOffset(24, 0), Size = UDim2.fromScale(0.6, 1) },
		}),
		Right = if right
			then Style.text({
				text = right,
				weight = Enum.FontWeight.Bold,
				size = 12,
				xAlign = "Right",
				extra = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromScale(0.4, 1),
				},
			})
			else nil,
	})
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

local function scroller(name: string, parent: Instance): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = name,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color("gold600"),
		Parent = parent,
	}, {
		List = Style.list("y", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Padding = Style.padding(1, 6, 1, 1),
	})
end

function KingdomPanel:_overview(content: Instance, model: any, phone: boolean)
	local scroll = scroller("Overview", content)
	local b = model.banner
	if b and not phone then
		Create("Frame", {
			Name = "Banner",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 62),
			LayoutOrder = 1,
			Parent = scroll,
		}, {
			Crest = Crest.new(58, b.color, b.emblem),
			Titles = Create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(70, 0),
				Size = UDim2.new(1, -70, 1, 0),
			}, {
				List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				KingdomName = Style.text({
					text = b.name,
					role = "display",
					weight = Enum.FontWeight.Bold,
					size = 32,
					color = Theme.color("gold300"),
					extra = { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1 },
				}),
				Sub = Style.text({
					text = b.sub,
					weight = Enum.FontWeight.SemiBold,
					size = 12,
					color = Theme.color("textSecondary"),
					extra = { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
				}),
			}),
		})
	end
	local rulers = section("Rulers", "citizens", `{#model.members} of 4`, 2)
	for i, m in model.members do
		Create("Frame", {
			Name = "Ruler_" .. tostring(m.userId),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = i,
			Parent = rulers,
		}, {
			Avatar = Create("TextLabel", {
				Text = m.initial,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(22, 22),
				BackgroundColor3 = if b then b.color else Theme.color("azure"),
				TextColor3 = Theme.color("ink950"),
				FontFace = Theme.font("body", Enum.FontWeight.ExtraBold),
				TextSize = 11,
			}, { Corner = Style.corner(999) }),
			Label = Style.text({
				text = if m.you then `{m.name} (you)` else m.name,
				weight = Enum.FontWeight.Bold,
				size = 12,
				extra = { Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -90, 1, 0) },
			}),
			Role = Style.text({
				text = "Ruler",
				weight = Enum.FontWeight.SemiBold,
				size = 12,
				color = Theme.color("textSecondary"),
				xAlign = "Right",
				extra = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, 60, 1, 0),
				},
			}),
		})
	end
	rulers.Parent = scroll
	local standings = section("Standings", "standings", "Crown Points", 3)
	for _, s in model.standings do
		local row = Create("Frame", {
			Name = "Standing_" .. s.id,
			BackgroundColor3 = Theme.color("gold500"),
			BackgroundTransparency = if s.me then 0.84 else 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = s.rank,
			Parent = standings,
		}, {
			Corner = Style.corner(8),
			Stroke = if s.me then Style.stroke(Theme.color("gold500"), 1, 0.5) else nil,
			Rank = Style.text({
				text = tostring(s.rank),
				weight = Enum.FontWeight.Bold,
				size = 12,
				color = Theme.color("textMuted"),
				xAlign = "Center",
				extra = { Size = UDim2.new(0, 22, 1, 0) },
			}),
			Kingdom = Style.text({
				text = if s.ai then `{s.name} · AI` else s.name,
				weight = Enum.FontWeight.Bold,
				size = 12,
				extra = { Position = UDim2.fromOffset(56, 0), Size = UDim2.new(1, -150, 1, 0) },
			}),
			Regions = Style.text({
				text = `{s.regions} ⚑`,
				weight = Enum.FontWeight.Bold,
				size = 12,
				color = Theme.color("textSecondary"),
				xAlign = "Right",
				extra = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -46, 0, 0),
					Size = UDim2.new(0, 40, 1, 0),
				},
			}),
			Points = Style.text({
				text = Format.amount(s.crownPoints),
				weight = Enum.FontWeight.ExtraBold,
				size = 12,
				color = Theme.color("gold300"),
				xAlign = "Right",
				extra = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -8, 0, 0),
					Size = UDim2.new(0, 36, 1, 0),
				},
			}),
		})
		local crest = Crest.new(22, s.color, s.emblem)
		crest.AnchorPoint = Vector2.new(0, 0.5)
		crest.Position = UDim2.new(0, 26, 0.5, 0)
		crest.Parent = row
	end
	standings.Parent = scroll
end

local function centredTile(icon: string, size: number, category: string): Frame
	local t = Icon.tile(icon, size, category)
	t.AnchorPoint = Vector2.new(0, 0.5)
	t.Position = UDim2.fromScale(0, 0.5)
	return t
end

function KingdomPanel:_buildings(content: Instance, model: any, phone: boolean, ui: any)
	local scroll = scroller("Buildings", content)
	local tile = 40
	-- Phones get the full 44 px Upgrade button, so their rows are taller.
	local rowHeight = if phone then 56 else 52
	for i, r in model.buildings do
		local sub
		if r.state == "constructing" or r.state == "planned" then
			local bar = ProgressBar.new({ progress = r.progress, width = UDim.new(1, -48) })
			bar.instance.LayoutOrder = 1
			sub = Create("Frame", {
				Name = "Progress",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 2,
			}, {
				List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Bar = bar.instance,
				Value = Style.text({
					text = if r.state == "planned" then "waiting" else `{math.floor(r.progress * 100)}%`,
					weight = Enum.FontWeight.ExtraBold,
					size = 11,
					color = Theme.color("gold300"),
					extra = { Size = UDim2.new(0, 42, 1, 0), LayoutOrder = 2 },
				}),
			})
		else
			sub = Style.text({
				text = if r.state == "complete" then "Complete" else r.state,
				weight = Enum.FontWeight.SemiBold,
				size = 11,
				color = Theme.color("textSecondary"),
				extra = { Name = "State", Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
			})
		end
		local row = Create("Frame", {
			Name = "Building_" .. tostring(r.id),
			BackgroundColor3 = Theme.color("ink700"),
			Size = UDim2.new(1, 0, 0, rowHeight),
			LayoutOrder = i,
			Parent = scroll,
		}, {
			Corner = Style.corner(10),
			Stroke = Style.stroke(Theme.color("ink500"), 1),
			Padding = Style.padding(6, 8, 6, 6),
			Tile = centredTile(r.icon, tile, r.category),
			Mid = Create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(tile + 8, 0),
				Size = UDim2.new(1, -(tile + 8 + (if r.canUpgrade then 112 else 0)), 1, 0),
			}, {
				List = Style.list("y", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Title = Style.text({
					text = `{r.name}  Lv {r.level}`,
					role = "heading",
					weight = Enum.FontWeight.Bold,
					size = 13,
					color = Theme.color("parchment100"),
					extra = { Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 },
				}),
				Sub = sub,
			}),
		})
		if r.canUpgrade then
			local up = Button.new({
				text = "Upgrade",
				icon = "build",
				variant = "secondary",
				size = if phone then "regular" else "small",
				width = 104,
				onActivated = function()
					ui.onUpgradeOpen(r.id)
				end,
			})
			up.instance.Name = "Upgrade"
			up.instance.AnchorPoint = Vector2.new(1, 0.5)
			up.instance.Position = UDim2.fromScale(1, 0.5)
			up.instance.Parent = row
		end
		self.rows[r.id] = row
	end
	if #model.buildings == 0 then
		Style.text({
			text = "Your buildings appear here once the match begins.",
			size = 12,
			color = Theme.color("textMuted"),
			xAlign = "Center",
			extra = { Size = UDim2.new(1, 0, 0, 40) },
		}).Parent =
			scroll
	end
end

function KingdomPanel:render(model: any, metrics: any, ui: { [string]: any })
	self:destroy()
	local phone = metrics.breakpoint == "phone"
	local d = metrics.drawer
	local header = Create("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local selected = if model.tab == "upgrade" then "buildings" else model.tab
	self.tabs = Tabs.new({ tabs = KingdomPanel.TABS, selected = selected, compact = phone, onSelect = ui.onTab })
	self.tabs.instance.Parent = header
	local close = IconButton.new({ icon = "close", variant = "plain", size = 36, onActivated = ui.onClose })
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.fromScale(1, 0.5)
	close.instance.Name = "Close"
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
	self.rows = {}
	self.detail = nil
	if model.tab == "overview" then
		self:_overview(content, model, phone)
	elseif model.tab == "upgrade" and model.upgrade then
		self.detail = DetailView.new({
			detail = model.upgrade,
			compact = phone,
			back = "Buildings",
			onCta = ui.onUpgrade,
			onBack = ui.onBack,
		})
		self.detail.instance.Parent = content
	else
		self:_buildings(content, model, phone, ui)
	end
	self.panel.instance.Parent = self._parent
end

function KingdomPanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.detail = nil
	self.rows = {}
end

return KingdomPanel
