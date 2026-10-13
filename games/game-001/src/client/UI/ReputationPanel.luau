--!strict
--[[
	UI/ReputationPanel — the reputation screen in the menu drawer (FL-0089; prototype
	games/game-001/design/ui/reputation.js, scenes "screen", "screen-detail", "history",
	"conditions", "fear", "empty", "no-content"). Three tabs:
		Reputation  the six categories with bars and numbers. Tablet/desktop: list + detail of the
		            selected one; phones: a 2 × 3 grid, a tap opens the detail with a back link.
		            Detail: value, band word, bar, "About" and "What affects it" (only when the
		            content library gives them — never invented here), its latest changes.
		History     every change the server sent (latest 30), newest first: signed delta, the cause
		            in plain words, the category, and how long ago.
		Kingdom     happiness, stability and army morale (bars, numbers, band words); separate
		            from reputation.
	Touch targets: rows ≥ 44 px on phones; phone tabs and the back link get 44 px hit areas;
	the close button is 44 px on phones.

	ReputationPanel.new(parent) -> panel
	panel:render(model, metrics, ui)
		model = { tab: "values" | "history" | "kingdom", selected: Category, phoneView: "list" | "detail",
		          known: boolean, categories: { Row }, history: { HistoryRow }, conditions: { Condition } }
		          (rows from UI/ReputationModel)
		ui = { onTab(id), onSelect(id), onBack(), onClose() }
	panel:refreshTimes(now)     rewrites every "… ago" label in place (no rebuild, scroll kept)
	panel:destroy()
	Names: "ReputationPanel"; tabs "Tab_<id>" (kit Tabs); "Category_<id>" rows; "CategoryDetail"
	("Back", "Value", "Band", "About", "Affects", "Recent"); "History" list of "History_<n>" rows
	(n = 1 newest; children "Delta", "Text", "Ago"); "Empty"; "Condition_<id>" ("Value", "Band").
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local ProgressBar = require("@game/ReplicatedStorage/Forge/UI/Components/ProgressBar")
local ReputationModel = require("./ReputationModel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Tabs = require("@game/ReplicatedStorage/Forge/UI/Components/Tabs")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ReputationPanel = {}
ReputationPanel.__index = ReputationPanel

ReputationPanel.TABS = table.freeze({
	table.freeze({ id = "values", label = "Reputation", icon = "crest" }),
	table.freeze({ id = "history", label = "History", icon = "timer" }),
	table.freeze({ id = "kingdom", label = "Kingdom", icon = "kingdom" }),
})

local TOUCH = 44
local GOOD = "#A9E57C"
local BAD = "#FF8A73"

function ReputationPanel.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, _times = {} }, ReputationPanel)
end

-- ------------------------------------------------------------------ small builders

local function tile(icon: string, size: number, color: Color3): Frame
	local inner = Icon.new(icon, size - 8)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	return Create("Frame", {
		Name = "Tile",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	}, {
		Corner = Style.corner(9),
		Stroke = Style.stroke(Theme.color("ink950"), 1.5),
		Gradient = Style.gradient(color:Lerp(Theme.color("ink700"), 0.45), color:Lerp(Theme.color("ink950"), 0.75)),
		Icon = inner,
	})
end

local function bandColor(band: string?): Color3
	if band == "Low" then
		return Theme.color("gules")
	elseif band == "High" then
		return Theme.color("vert")
	end
	return Theme.color("amber")
end

local function bandText(band: string?): Color3
	if band == "Low" then
		return Theme.hex(BAD)
	elseif band == "High" then
		return Theme.hex(GOOD)
	end
	return Theme.color("amber")
end

local function scroller(name: string, parent: Instance, gap: number?, padding: Instance?): ScrollingFrame
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
		List = Style.list("y", gap or 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Padding = padding or Style.padding(1, 6, 1, 1),
	}) :: ScrollingFrame
end

-- A transparent button that widens a small control's touch area to 44 px tall (centred on it).
local function hitArea(parent: Instance, fn: () -> ())
	Create("TextButton", {
		Name = "Hit",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, TOUCH),
		ZIndex = 4,
		Parent = parent,
		[Create.Event.Activated] = fn,
	})
end

local function deltaChip(row: { [string]: any }): Frame
	return Create("Frame", {
		Name = "Delta",
		BackgroundColor3 = if row.positive then Theme.color("vert") else Theme.color("gules"),
		BackgroundTransparency = 0.84,
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.fromOffset(0, 2),
		Size = UDim2.fromOffset(40, 24),
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(if row.positive then Theme.color("vert") else Theme.color("gules"), 1, 0.3),
		Padding = Style.padding(0, 6),
		Label = Style.text({
			text = row.deltaText,
			weight = Enum.FontWeight.ExtraBold,
			size = 13,
			color = if row.positive then Theme.hex(GOOD) else Theme.hex(BAD),
			xAlign = "Center",
			extra = { Size = UDim2.new(0, 28, 1, 0) },
		}),
	})
end

function ReputationPanel:_historyRow(row: { [string]: any }, index: number, fresh: boolean): Frame
	local category = Theme.color(row.color)
	local ago = Style.text({
		text = " · " .. row.ago,
		weight = Enum.FontWeight.Bold,
		size = 10,
		color = Theme.color("textMuted"),
		extra = { Name = "Ago", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 3 },
	})
	table.insert(self._times, { label = ago, t = row.t })
	local icon = Icon.new(row.icon, 12)
	icon.LayoutOrder = 1
	return Create("Frame", {
		Name = "History_" .. tostring(index),
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = index,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(if fresh then Theme.color("gold500") else Theme.color("ink500"), 1),
		Padding = Style.padding(6, 8),
		Delta = deltaChip(row),
		Mid = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(50, 0),
			Size = UDim2.new(1, -50, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
			Text = Style.text({
				text = if row.text ~= "" then row.text else row.name,
				size = 12,
				wrap = true,
				yAlign = "Top",
				extra = { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 },
			}),
			Meta = Create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 14),
				LayoutOrder = 2,
			}, {
				List = Style.list("x", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Icon = icon,
				Category = Style.text({
					text = row.name,
					weight = Enum.FontWeight.Bold,
					size = 10,
					color = category,
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
				}),
				Ago = ago,
			}),
		}),
	})
end

local function emptyNote(text: string, order: number): TextLabel
	return Style.text({
		text = text,
		size = 12,
		wrap = true,
		color = Theme.color("textMuted"),
		xAlign = "Center",
		extra = { Name = "Empty", Size = UDim2.new(1, 0, 0, 44), LayoutOrder = order },
	}) :: TextLabel
end

-- ------------------------------------------------------------------ Reputation tab

-- size.Y >= 48 and wide (tablet/desktop list): 32 px tile, 13 px name; phone grid cells (narrow):
-- 26 px tile, 12 px name, so "Competence" fits the 156 px cell.
local function categoryRow(r: { [string]: any }, selected: boolean, size: Vector2, onSelect: () -> ()): TextButton
	local color = Theme.color(r.color)
	local narrow = size.X < 200
	local tileSize = if narrow then 26 else 32
	local valueWidth = if narrow then 28 else 34
	local left = tileSize + (if narrow then 6 else 8)
	local bar = ProgressBar.new({ progress = (r.value or 0) / ReputationModel.MAX, color = color, height = 6 })
	bar.instance.AnchorPoint = Vector2.new(0, 1)
	bar.instance.Position = UDim2.new(0, left, 1, -2)
	bar.instance.Size = UDim2.new(1, -left, 0, 6)
	local row = Create("TextButton", {
		Name = "Category_" .. r.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if selected then Theme.color("ink600") else Theme.color("ink700"),
		Size = UDim2.fromOffset(size.X, size.Y),
		[Create.Event.Activated] = onSelect,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(
			if selected then Theme.color("gold500") else Theme.color("ink500"),
			if selected then 1.5 else 1
		),
		Padding = Style.padding(6, 8, 6, 6),
		Tile = (function()
			local t = tile(r.icon, tileSize, color)
			t.AnchorPoint = Vector2.new(0, 0.5)
			t.Position = UDim2.fromScale(0, 0.5)
			return t
		end)(),
		RowName = Style.text({
			text = r.name,
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = if narrow then 12 else 13,
			color = Theme.color("parchment100"),
			extra = { Position = UDim2.fromOffset(left, 0), Size = UDim2.new(1, -(left + valueWidth), 0, 18) },
		}),
		Value = Style.text({
			text = r.label,
			weight = Enum.FontWeight.ExtraBold,
			size = if narrow then 14 else 15,
			xAlign = "Right",
			extra = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(valueWidth, 18),
			},
		}),
		Bar = bar.instance,
	}) :: TextButton
	row:SetAttribute("selected", selected)
	row:SetAttribute("value", r.value)
	return row
end

function ReputationPanel:_detail(parent: Instance, r: { [string]: any }, phone: boolean, ui: any)
	local color = Theme.color(r.color)
	local frame = Create("Frame", {
		Name = "CategoryDetail",
		BackgroundColor3 = Theme.color("parchment200"),
		BackgroundTransparency = 0.92,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("gold500"), 1, 0.65),
	})
	local scroll = scroller("Scroll", frame, 8, Style.padding(10, 12, 10, 10))
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	if phone then
		local back = Create("TextButton", {
			Name = "Back",
			Text = "‹ Reputation",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.font("body", Enum.FontWeight.Bold),
			TextSize = 12,
			TextColor3 = Theme.color("gold400"),
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = nextOrder(),
			Parent = scroll,
			[Create.Event.Activated] = ui.onBack,
		})
		hitArea(back, ui.onBack)
	end
	local tileSize = if phone then 36 else 44
	Create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tileSize),
		LayoutOrder = nextOrder(),
		Parent = scroll,
	}, {
		Tile = tile(r.icon, tileSize, color),
		Titles = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(tileSize + 10, 0),
			Size = UDim2.new(1, -(tileSize + 10 + 70), 1, 0),
		}, {
			List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Title = Style.text({
				text = r.name,
				role = "heading",
				weight = Enum.FontWeight.Heavy,
				size = if phone then 16 else 18,
				color = Theme.color("parchment100"),
				extra = { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 1 },
			}),
			Band = Style.text({
				text = r.band or "",
				weight = Enum.FontWeight.Bold,
				size = 11,
				color = Theme.color("gold400"),
				extra = { Size = UDim2.new(1, 0, 0, 13), LayoutOrder = 2 },
			}),
		}),
		Big = Create("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 70, 1, 0),
		}, {
			List = Style.list("y", 0, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center),
			Value = Style.text({
				text = r.label,
				weight = Enum.FontWeight.ExtraBold,
				size = 24,
				xAlign = "Right",
				extra = { Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1 },
			}),
			Of = Style.text({
				text = `of {ReputationModel.MAX}`,
				weight = Enum.FontWeight.Bold,
				size = 11,
				color = Theme.color("gold400"),
				xAlign = "Right",
				extra = { Size = UDim2.new(1, 0, 0, 13), LayoutOrder = 2 },
			}),
		}),
	})
	local bar = ProgressBar.new({
		progress = (r.value or 0) / ReputationModel.MAX,
		color = color,
		height = 10,
		layoutOrder = nextOrder(),
	})
	bar.instance.Parent = scroll
	local function paragraph(name: string, heading: string, body: string)
		Create("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = scroll,
		}, {
			List = Style.list("y", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
			Heading = Style.text({
				text = heading,
				role = "heading",
				weight = Enum.FontWeight.Bold,
				size = 12,
				color = Theme.color("gold300"),
				extra = { Size = UDim2.new(1, 0, 0, 15), LayoutOrder = 1 },
			}),
			Body = Style.text({
				text = body,
				weight = Enum.FontWeight.Medium,
				size = 12,
				wrap = true,
				yAlign = "Top",
				color = Theme.color("textSecondary"),
				extra = { Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 },
			}),
		})
	end
	-- Content library text only (Content/Reputation.categories); nothing is shown without it.
	if r.description then
		paragraph("About", "About", r.description)
	end
	if r.affects then
		paragraph("Affects", "What affects it", r.affects)
	end
	local headIcon = Icon.new("timer", 14)
	headIcon.LayoutOrder = 1
	Create("Frame", {
		Name = "RecentHead",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = nextOrder(),
		Parent = scroll,
	}, {
		List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = headIcon,
		Title = Style.text({
			text = "Recent changes",
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = 12,
			color = Theme.color("gold300"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	})
	local recent = Create("Frame", {
		Name = "Recent",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = scroll,
	}, { List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	for i, row in r.recent do
		self:_historyRow(row, i, false).Parent = recent
	end
	if #r.recent == 0 then
		emptyNote("No changes yet.", 1).Parent = recent
	end
end

function ReputationPanel:_values(content: Instance, model: any, phone: boolean, ui: any, metrics: any)
	local rows = model.categories
	local selected = rows[1]
	for _, r in rows do
		if r.id == model.selected then
			selected = r
		end
	end
	local pad = if phone then 10 else 12
	local contentHeight = metrics.drawer.height - 2 * pad - (if phone then 46 else 52)
	if phone then
		if model.phoneView == "detail" then
			self:_detail(content, selected, true, ui)
			return
		end
		local width = metrics.drawer.width - 2 * pad
		local cell = Vector2.new(math.floor((width - 6) / 2), 48)
		local grid = Create("Frame", { Name = "Categories", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
		for i, r in rows do
			local row = categoryRow(r, false, cell, function()
				ui.onSelect(r.id)
			end)
			row.Position = UDim2.fromOffset(((i - 1) % 2) * (cell.X + 6), ((i - 1) // 2) * (cell.Y + 6))
			row.Parent = grid
		end
		Style.text({
			text = "Tap a value to see what changes it.",
			size = 11,
			color = Theme.color("textMuted"),
			xAlign = "Center",
			extra = {
				Name = "Hint",
				Position = UDim2.fromOffset(0, 3 * cell.Y + 2 * 6 + 8),
				Size = UDim2.new(1, 0, 0, 14),
			},
		}).Parent =
			grid
		grid.Parent = content
		return
	end
	local listWidth = if metrics.breakpoint == "tablet" then 230 else 250
	local rowHeight = math.clamp(math.floor((contentHeight - 5 * 6) / 6), 40, 52)
	local list = Create("Frame", {
		Name = "Categories",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, listWidth, 1, 0),
		Parent = content,
	}, { List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	for i, r in rows do
		local row = categoryRow(r, r.id == selected.id, Vector2.new(listWidth, rowHeight), function()
			ui.onSelect(r.id)
		end)
		row.LayoutOrder = i
		row.Parent = list
	end
	local right = Create("Frame", {
		Name = "DetailPane",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(listWidth + 10, 0),
		Size = UDim2.new(1, -(listWidth + 10), 1, 0),
		Parent = content,
	})
	self:_detail(right, selected, false, ui)
end

-- ------------------------------------------------------------------ History and Kingdom tabs

function ReputationPanel:_history(content: Instance, model: any)
	local scroll = scroller("History", content)
	if not model.known then
		emptyNote("Waiting for the server…", 1).Parent = scroll
		return
	end
	for i, row in model.history do
		self:_historyRow(row, i, i == 1 and model.fresh == true).Parent = scroll
	end
	if #model.history == 0 then
		emptyNote("Nothing has changed yet. What you decide and do as ruler shows up here.", 1).Parent = scroll
	end
end

function ReputationPanel:_kingdom(content: Instance, model: any, phone: boolean)
	local scroll = scroller("Conditions", content)
	Style.text({
		text = "How your kingdom is doing. These are separate from your reputation.",
		size = 11,
		wrap = true,
		color = Theme.color("textSecondary"),
		extra = { Name = "Caption", Size = UDim2.new(1, 0, 0, if phone then 28 else 16), LayoutOrder = 0 },
	}).Parent =
		scroll
	for i, c in model.conditions do
		local medallion = Icon.medallion(c.icon, 36, Theme.color("ink600"))
		medallion.AnchorPoint = Vector2.new(0, 0.5)
		medallion.Position = UDim2.fromScale(0, 0.5)
		local bar = ProgressBar.new({
			progress = (c.value or 0) / ReputationModel.MAX,
			color = bandColor(c.band),
			height = 8,
		})
		bar.instance.AnchorPoint = Vector2.new(0, 1)
		bar.instance.Position = UDim2.new(0, 46, 1, 0)
		bar.instance.Size = UDim2.new(1, -46, 0, 8)
		local row = Create("Frame", {
			Name = "Condition_" .. c.id,
			BackgroundColor3 = Theme.color("ink700"),
			Size = UDim2.new(1, 0, 0, 56),
			LayoutOrder = i,
			Parent = scroll,
		}, {
			Corner = Style.corner(10),
			Stroke = Style.stroke(Theme.color("ink500"), 1),
			Padding = Style.padding(8, 10, 9, 8),
			Medallion = medallion,
			Top = Create("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(46, 0),
				Size = UDim2.new(1, -46 - 40, 0, 22),
			}, {
				List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Title = Style.text({
					text = c.name,
					role = "heading",
					weight = Enum.FontWeight.Bold,
					size = 14,
					color = Theme.color("parchment100"),
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 1 },
				}),
				Band = Style.text({
					text = c.band or "",
					weight = Enum.FontWeight.Bold,
					size = 11,
					color = bandText(c.band),
					extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
				}),
			}),
			Value = Style.text({
				text = c.label,
				weight = Enum.FontWeight.ExtraBold,
				size = 18,
				xAlign = "Right",
				extra = {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(40, 22),
				},
			}),
			Bar = bar.instance,
		})
		row:SetAttribute("value", c.value)
	end
end

-- ------------------------------------------------------------------ panel

function ReputationPanel:render(model: { [string]: any }, metrics: any, ui: { [string]: any })
	self:destroy()
	local phone = metrics.breakpoint == "phone"
	local d = metrics.drawer
	local header = Create("Frame", { Name = "HeaderRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	self.tabs = Tabs.new({ tabs = ReputationPanel.TABS, selected = model.tab, compact = phone, onSelect = ui.onTab })
	if phone then
		-- The kit tabs are 34 px tall: on phones each gets a 44 px hit area (same look).
		for id, button in self.tabs.buttons do
			hitArea(button, function()
				if id ~= model.tab then
					ui.onTab(id)
				end
			end)
		end
	end
	self.tabs.instance.Parent = header
	local close = IconButton.new({
		icon = "close",
		variant = "plain",
		size = if phone then TOUCH else 36,
		onActivated = ui.onClose,
	})
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.fromScale(1, 0.5)
	close.instance.Name = "Close"
	close.instance.Parent = header
	self.panel = Panel.new({
		title = if phone then nil else "Reputation",
		header = header,
		size = UDim2.fromOffset(d.width, d.height),
		position = UDim2.fromOffset(d.x, d.y),
		padding = if phone then 10 else 12,
	})
	self.panel.instance.Name = "ReputationPanel"
	self._times = {}
	local content = self.panel.content
	if model.tab == "history" then
		self:_history(content, model)
	elseif model.tab == "kingdom" then
		self:_kingdom(content, model, phone)
	else
		self:_values(content, model, phone, ui, metrics)
	end
	self.panel.instance.Parent = self._parent
end

function ReputationPanel:refreshTimes(now: number)
	for _, entry in self._times do
		entry.label.Text = " · " .. ReputationModel.ago(entry.t, now)
	end
end

function ReputationPanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self._times = {}
end

return ReputationPanel
