--!strict
--[[
	UI/KingdomPanel — kingdom information and building upgrades (prototype scenes "kingdom",
	"kingdom-buildings", "upgrade").
		Overview   crest, name, keep level, regions, Crown Points; the rulers; standings of all four
		           kingdoms by Crown Points (yours highlighted, AI kingdoms marked)
		Buildings  each of your buildings with level and state (construction progress), and Upgrade
		           where a next level exists
		Upgrade    the shared DetailView with the next level's costs (Build.Upgrade)
		Jobs       (FL-0065) workers per job with − / + (Kingdom.SetJobQuota), the free pool (haulers)
		           and soldiers, from UI/JobModel; prototype scenes "kingdom-jobs", "kingdom-jobs-full"
		Rivals     (FL-0129) war and peace with each rival kingdom (UI/RivalsList, UI/DiplomacyModel);
		           only when model.tabs lists it (the server serves the diplomacy remote)

	KingdomPanel.new(parent) -> panel
	panel:render(model, metrics, ui)
		model = { tab: "overview" | "buildings" | "upgrade" | "jobs" | "rivals", banner, members, standings,
		          buildings: { Row }, upgrade: BuildModel Detail?, jobs: JobModel View?,
		          tabs: { Tab }? (default KingdomPanel.TABS), rivals: DiplomacyModel View?, confirm: KingdomId? }
			Row = { id, type, name, icon, category, level, state, progress, canUpgrade }
		ui = { onTab(id), onUpgradeOpen(buildingId), onUpgrade(detail), onBack(), onClose(),
		       onJob(jobId, delta: 1 | -1), onDiplomacy(kingdomId, actionId), onConfirmWar(kingdomId),
		       onCancelWar() }
	panel:destroy()
	Building rows are named "Building_<id>"; their Upgrade button "Upgrade". Job rows "Job_<id>" (plus
	"Job_free" and "Job_soldier") carry the attribute `count`; their buttons "Minus" / "Plus".
	Renders keep their instances (FORGE-05 M1): the frame is rebuilt for another breakpoint or tab,
	a tab's content only when its layout changes (a building added, a level gained, the overview's
	text); construction progress and the upgrade CTA are patched in place, and a rebuilt list keeps
	its scroll.
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local DetailView = require("./DetailView")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local RivalsList = require("./RivalsList")
local ProgressBar = require("@game/ReplicatedStorage/Forge/UI/Components/ProgressBar")
local Signature = require("./Signature")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Tabs = require("@game/ReplicatedStorage/Forge/UI/Components/Tabs")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local KingdomPanel = {}
KingdomPanel.__index = KingdomPanel

KingdomPanel.TABS = table.freeze({
	-- the banner, not a crown: the crown is Emberhold's emblem (D-039; FORGE-05 L5 on #86)
	table.freeze({ id = "overview", label = "Overview", icon = "banner" }),
	table.freeze({ id = "buildings", label = "Buildings", icon = "keep" }),
	table.freeze({ id = "jobs", label = "Jobs", icon = "citizens" }),
})
-- The Rivals tab (FL-0129): added to model.tabs by the controller when the server serves diplomacy.
KingdomPanel.RIVALS_TAB = table.freeze({ id = "rivals", label = "Rivals", icon = "army" })

function KingdomPanel.new(parent: Instance)
	return setmetatable(
		{ _parent = parent, panel = nil, detail = nil, rows = {}, bars = {}, _ui = {}, _scroll = {} },
		KingdomPanel
	)
end

local function building(r: any): boolean
	return r.state == "constructing" or r.state == "planned"
end

-- A building row's layout; progress and the state's wording are patched (paintRow).
local function rowsKey(rows: { any }, phone: boolean): string
	local out = {}
	for i, r in rows do
		out[i] = {
			id = r.id,
			name = r.name,
			icon = r.icon,
			category = r.category,
			level = r.level,
			building = building(r),
			canUpgrade = r.canUpgrade,
		}
	end
	return Signature.of({ tab = "buildings", rows = out, phone = phone })
end

-- A finished building's state in words (the server's codes are never shown raw).
local STATES = { complete = "Complete", damaged = "Damaged", repairing = "Repairing" }
local function stateText(state: string): string
	return STATES[state] or (string.upper(string.sub(state, 1, 1)) .. string.sub(state, 2))
end

local function progressText(r: any): string
	return if r.state == "planned" then "waiting" else `{math.floor(r.progress * 100)}%`
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

function KingdomPanel:_overview(content: Instance, model: any, phone: boolean): Instance
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
	return scroll
end

local function centredTile(icon: string, size: number, category: string): Frame
	local t = Icon.tile(icon, size, category)
	t.AnchorPoint = Vector2.new(0, 0.5)
	t.Position = UDim2.fromScale(0, 0.5)
	return t
end

function KingdomPanel:_buildings(content: Instance, model: any, phone: boolean): Instance
	local scroll = scroller("Buildings", content)
	local tile = 40
	-- Phones get the full 44 px Upgrade button, so their rows are taller.
	local rowHeight = if phone then 56 else 52
	for i, r in model.buildings do
		local sub
		if building(r) then
			local bar = ProgressBar.new({ progress = r.progress, width = UDim.new(1, -48) })
			bar.instance.LayoutOrder = 1
			self.bars[r.id] = bar
			sub = Create("Frame", {
				Name = "Progress",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				LayoutOrder = 2,
			}, {
				List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
				Bar = bar.instance,
				Value = Style.text({
					text = progressText(r),
					weight = Enum.FontWeight.ExtraBold,
					size = 11,
					color = Theme.color("gold300"),
					extra = { Size = UDim2.new(0, 42, 1, 0), LayoutOrder = 2 },
				}),
			})
		else
			sub = Style.text({
				text = stateText(r.state),
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
					if self._ui.onUpgradeOpen then
						self._ui.onUpgradeOpen(r.id)
					end
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
	return scroll
end

-- Construction progress on rows built for the same layout.
-- ------------------------------------------------------------------ jobs (FL-0065)

local function jobsKey(jobs: any, phone: boolean): string
	local ids = {}
	for i, r in jobs.rows do
		ids[i] = r.id
	end
	return Signature.of({ tab = "jobs", rows = ids, phone = phone })
end

local function jobRow(
	id: string,
	icon: string,
	category: string,
	name: string,
	phone: boolean,
	controls: boolean
): Frame
	local tile = if phone then 34 else 40
	-- room on the right: − count + (150 px), or only the count for the pool and soldiers rows
	-- the count sits 50 px from the right (between − and +) in every row, so count-only rows keep
	-- that column clear too (FORGE-05 L1 on #55: it overlapped the subtitle on phones)
	local right = if controls then 150 else 100
	return Create("Frame", {
		Name = "Job_" .. id,
		BackgroundColor3 = Theme.color("ink700"),
		Size = UDim2.new(1, 0, 0, if phone then 56 else 58),
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		Padding = Style.padding(6, 8, 6, 6),
		Tile = centredTile(icon, tile, category),
		Mid = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(tile + 10, 0),
			Size = UDim2.new(1, -(tile + 10 + right), 1, 0),
		}, {
			List = Style.list("y", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Title = Style.text({
				text = name,
				role = "heading",
				weight = Enum.FontWeight.Bold,
				size = 14,
				color = Theme.color("parchment100"),
				extra = { Size = UDim2.new(1, 0, 0, 17), LayoutOrder = 1 },
			}),
			Sub = Style.text({
				text = "",
				weight = Enum.FontWeight.SemiBold,
				size = 11,
				color = Theme.color("textSecondary"),
				extra = { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
			}),
		}),
		Count = Style.text({
			text = "",
			weight = Enum.FontWeight.ExtraBold,
			size = 20,
			color = Theme.color("parchment100"),
			xAlign = "Center",
			extra = {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -50, 0.5, 0),
				Size = UDim2.fromOffset(44, 24),
			},
		}),
	})
end

function KingdomPanel:_jobs(content: Instance, jobs: any, phone: boolean): Instance
	local scroll = scroller("Jobs", content)
	self.jobRows = {}
	self.jobSummary = Style.text({
		text = "",
		weight = Enum.FontWeight.SemiBold,
		size = 12,
		color = Theme.color("textSecondary"),
		extra = { Name = "JobSummary", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = -1 },
	})
	self.jobSummary.Parent = scroll
	for i, r in jobs.rows do
		local row = jobRow(r.id, r.icon, "economy", r.name, phone, true)
		row.LayoutOrder = i
		local id = r.id
		local minus = IconButton.new({
			icon = "minus",
			variant = "plain",
			size = 44,
			onActivated = function()
				if self._ui.onJob then
					self._ui.onJob(id, -1)
				end
			end,
		})
		minus.instance.Name = "Minus"
		minus.instance.AnchorPoint = Vector2.new(1, 0.5)
		minus.instance.Position = UDim2.new(1, -98, 0.5, 0)
		minus.instance.Parent = row
		local plus = IconButton.new({
			icon = "plus",
			variant = "plain",
			size = 44,
			onActivated = function()
				if self._ui.onJob then
					self._ui.onJob(id, 1)
				end
			end,
		})
		plus.instance.Name = "Plus"
		plus.instance.AnchorPoint = Vector2.new(1, 0.5)
		plus.instance.Position = UDim2.fromScale(1, 0.5)
		plus.instance.Parent = row
		row.Parent = scroll
		self.jobRows[id] = { row = row, minus = minus, plus = plus }
	end
	local n = #jobs.rows
	-- The free pool first: it is what + draws from, so its count and "None free" stay in view.
	self.jobPool = jobRow("free", "citizens", "civic", "Free citizens", phone, false)
	self.jobPool.LayoutOrder = 0
	self.jobPool.BackgroundColor3 = Theme.color("ink800")
	self.jobPool.Parent = scroll
	self.jobSoldiers = jobRow("soldier", "army", "military", "Soldiers", phone, false)
	self.jobSoldiers.LayoutOrder = n + 2
	self.jobSoldiers.BackgroundColor3 = Theme.color("ink800")
	self.jobSoldiers.Parent = scroll
	return scroll
end

-- "–" until the server has sent counts (L2): a 0 would read as "nobody".
local function setCount(row: Instance, count: number, known: boolean)
	local label = row:FindFirstChild("Count") :: TextLabel?
	if label then
		label.Text = if known then tostring(count) else "–"
	end
	row:SetAttribute("count", if known then count else nil)
end

-- An IconButton rebuilds its icon on update: only when its state really changes (L6).
local function setDisabled(entry: any, key: string, disabled: boolean)
	if entry[key .. "Off"] ~= disabled then
		entry[key .. "Off"] = disabled
		entry[key]:update({ disabled = disabled })
	end
end

local function setSub(row: Instance, text: string, highlight: boolean)
	local mid = row:FindFirstChild("Mid")
	local sub = mid and mid:FindFirstChild("Sub") :: TextLabel?
	if sub then
		sub.Text = text
		sub.TextColor3 = if highlight then Theme.color("gold300") else Theme.color("textSecondary")
	end
end

-- What a push or a request changes: counts, notes, which buttons work, the summary line.
function KingdomPanel:_paintJobs(jobs: any)
	local s = jobs.summary
	self.jobSummary.Text = if jobs.known
		then `{s.total} citizens · homes for {if s.cap then s.cap else "?"} · {s.free} free`
		else "Counting your citizens…"
	for _, r in jobs.rows do
		local entry = self.jobRows[r.id]
		if entry then
			setCount(entry.row, r.count, jobs.known)
			setSub(entry.row, r.note or r.sub, r.note ~= nil)
			setDisabled(entry, "minus", not r.canRemove)
			setDisabled(entry, "plus", not r.canAdd)
		end
	end
	setCount(self.jobPool, jobs.pool.count, jobs.known)
	setSub(self.jobPool, jobs.pool.text, false)
	setCount(self.jobSoldiers, jobs.soldiers.count, jobs.known)
	setSub(self.jobSoldiers, "Train them at the barracks", false)
end

function KingdomPanel:_paintRows(rows: { any })
	for _, r in rows do
		local bar = self.bars[r.id]
		local row = self.rows[r.id]
		if bar and building(r) then
			bar:update({ progress = r.progress })
			local value = row and row:FindFirstChild("Value", true)
			if value then
				value.Text = progressText(r)
			end
		elseif row and not building(r) then
			-- complete ↔ damaged keeps the row's layout: patch the words (FORGE-05, #41 review)
			local mid = row:FindFirstChild("Mid")
			local label = mid and mid:FindFirstChild("Sub")
			if label and label:IsA("TextLabel") then
				label.Text = stateText(r.state)
			end
		end
	end
end

function KingdomPanel:_frame(model: any, metrics: any)
	self:_teardown()
	local phone = metrics.breakpoint == "phone"
	local d = metrics.drawer
	local header = Create("Frame", {
		Name = "HeaderRow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	})
	local selected = if model.tab == "upgrade" then "buildings" else model.tab
	local tabs = model.tabs or KingdomPanel.TABS
	if phone and #tabs > #KingdomPanel.TABS then
		-- Four tabs and Close do not fit the phone drawer's header with the selected tab's label
		-- (FL-0129 phone pass, 667x375): icons only; the selected tab keeps its gold frame and underline.
		local iconsOnly = {}
		for i, tab in tabs do
			iconsOnly[i] = { id = tab.id, label = "", icon = tab.icon, disabled = tab.disabled }
		end
		tabs = iconsOnly
	end
	self.tabs = Tabs.new({
		tabs = tabs,
		selected = selected,
		compact = phone,
		onSelect = function(id)
			if self._ui.onTab then
				self._ui.onTab(id)
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
	self.panel = Panel.new({
		title = if phone then nil else "Kingdom",
		header = header,
		size = UDim2.fromOffset(d.width, d.height),
		position = UDim2.fromOffset(d.x, d.y),
		padding = if phone then 10 else 12,
	})
	self.panel.instance.Name = "KingdomPanel"
	self.panel.instance.Parent = self._parent
end

function KingdomPanel:_clearBody()
	if self._body then
		if self._body:IsA("ScrollingFrame") then
			self._scroll[self._body.Name] = self._body.CanvasPosition
		end
		self._body:Destroy()
	end
	self._body, self._bodyKey, self.detail = nil, nil, nil
	self.rows, self.bars = {}, {}
end

function KingdomPanel:_setBody(body: Instance, key: string)
	if body:IsA("ScrollingFrame") then
		local scroll = self._scroll[body.Name]
		if scroll then
			body.CanvasPosition = scroll
		end
	end
	self._body, self._bodyKey = body, key
end

function KingdomPanel:render(model: any, metrics: any, ui: { [string]: any })
	self._ui = ui
	local phone = metrics.breakpoint == "phone"
	local frameKey = Signature.of({
		breakpoint = metrics.breakpoint,
		drawer = metrics.drawer,
		tab = if model.tab == "upgrade" then "buildings" else model.tab,
		tabs = #(model.tabs or KingdomPanel.TABS),
	})
	if self.panel == nil or frameKey ~= self._frameKey then
		self:_frame(model, metrics)
		self._frameKey = frameKey
	end
	local content = self.panel.content
	if model.tab == "overview" then
		local key = Signature.of({
			tab = "overview",
			banner = model.banner,
			members = model.members,
			standings = model.standings,
			phone = phone,
		})
		if key ~= self._bodyKey then
			self:_clearBody()
			self:_setBody(self:_overview(content, model, phone), key)
		end
	elseif model.tab == "upgrade" and model.upgrade then
		local handlers = {
			onCta = function(detail)
				if self._ui.onUpgrade then
					self._ui.onUpgrade(detail)
				end
			end,
			onBack = function()
				if self._ui.onBack then
					self._ui.onBack()
				end
			end,
		}
		local key = "upgrade:" .. DetailView.key(model.upgrade, phone, "Buildings")
		if key == self._bodyKey and self.detail then
			self.detail:update(model.upgrade, handlers)
		else
			self:_clearBody()
			self.detail = DetailView.new({
				detail = model.upgrade,
				compact = phone,
				back = "Buildings",
				onCta = handlers.onCta,
				onBack = handlers.onBack,
			})
			self.detail.instance.Parent = content
			self:_setBody(self.detail.instance, key)
		end
	elseif model.tab == "rivals" and model.rivals then
		local key = RivalsList.key(model.rivals, phone, model.confirm)
		if key ~= self._bodyKey then
			self:_clearBody()
			self:_setBody(
				RivalsList.build(content, model.rivals, phone, {
					confirm = model.confirm,
					onAction = function(kingdomId, actionId)
						if self._ui.onDiplomacy then
							self._ui.onDiplomacy(kingdomId, actionId)
						end
					end,
					onConfirm = function(kingdomId)
						if self._ui.onConfirmWar then
							self._ui.onConfirmWar(kingdomId)
						end
					end,
					onCancel = function()
						if self._ui.onCancelWar then
							self._ui.onCancelWar()
						end
					end,
				}),
				key
			)
		end
		RivalsList.paint(self._body, model.rivals, phone)
	elseif model.tab == "jobs" and model.jobs then
		local key = jobsKey(model.jobs, phone)
		if key ~= self._bodyKey then
			self:_clearBody()
			self:_setBody(self:_jobs(content, model.jobs, phone), key)
		end
		self:_paintJobs(model.jobs)
	else
		local key = rowsKey(model.buildings, phone)
		if key ~= self._bodyKey then
			self:_clearBody()
			self:_setBody(self:_buildings(content, model, phone), key)
		end
		self:_paintRows(model.buildings)
	end
end

function KingdomPanel:_teardown()
	self:_clearBody()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self._frameKey = nil
end

function KingdomPanel:destroy()
	if self.panel == nil then
		return
	end
	self:_teardown()
	self._scroll = {}
end

return KingdomPanel
