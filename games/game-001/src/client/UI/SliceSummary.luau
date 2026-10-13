--!strict
--[[
	UI/SliceSummary — the end-of-slice summary (FL-0060; prototype games/game-001/design/ui/army.js,
	scenes "summary*"): on the modal layer (a ScreenInsets.None ScreenGui), a scrim over the whole screen
	(notch strips included) and a centred panel clear of the notches and the Roblox top bar:
		kicker      "Victory" (my kingdom won) or "Match over"
		headline    the winner's crest and name, "wins the match" / "Your kingdom wins"; or "No winner"
		duration    "Lasted 12:34"
		standings   rank (the winner with a crown), crest, name, "you" / "AI" tags, Crown Points;
		            my row highlighted with a gold border (never colour alone: the "you" tag)
		Continue    closes it (the scrim does not: the summary is never dismissed by a stray tap)
	Phones: two columns in 600 × 262 (it must fit 390 px tall minus the top bar on both sides);
	tablet/desktop: one column, 460 wide.

	SliceSummary.new(parent) -> view
	view:render(model: UI/SummaryModel Summary, metrics, ui: { onContinue: () -> () })
	view:destroy()
	view.instance: Frame "SliceSummary" (children "Scrim", "Panel")   view.continue: Button handle
		(instance "Continue")   view.rows[kingdomId]: Frame "Standing_<id>" (attributes rank, mine, winner)
	SliceSummary.size(model, metrics) -> (width, height)
]]

local ArmyText = require("./ArmyText")
local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local SliceSummary = {}
SliceSummary.__index = SliceSummary

SliceSummary.ROW = 34
SliceSummary.ROW_GAP = 4
SliceSummary.PHONE = { width = 600, height = 262, left = 236 }
SliceSummary.WIDTH = 460

local WIN = Color3.fromRGB(169, 229, 124)

function SliceSummary.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil, rows = {}, _ui = {} }, SliceSummary)
end

local function rowsHeight(n: number): number
	return math.max(0, n * (SliceSummary.ROW + SliceSummary.ROW_GAP) - SliceSummary.ROW_GAP)
end

function SliceSummary.size(model: any, metrics: any): (number, number)
	if metrics.breakpoint == "phone" then
		return math.min(SliceSummary.PHONE.width, metrics.width - 16), SliceSummary.PHONE.height
	end
	-- pad 16 + kicker/headline/duration 124 + standings header 24 + rows + 14 + CTA 44 + pad 16
	return SliceSummary.WIDTH, 16 + 124 + 24 + rowsHeight(#model.standings) + 14 + 44 + 16
end

local function text(props: { [string]: any }): TextLabel
	return Style.text(props) :: TextLabel
end

local function tag(label: string, mine: boolean, order: number): TextLabel
	local chip = text({
		text = label,
		weight = Enum.FontWeight.ExtraBold,
		size = 10,
		color = if mine then Theme.color("inkText") else Theme.color("textSecondary"),
		xAlign = "Center",
		extra = {
			Name = if mine then "YouTag" else "AiTag",
			BackgroundTransparency = 0,
			BackgroundColor3 = if mine then Theme.color("gold400") else Theme.color("ink600"),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			LayoutOrder = order,
		},
	})
	Style.corner(4).Parent = chip
	Style.padding(0, 5).Parent = chip
	return chip
end

local function standingRow(row: any, y: number): Frame
	local rank = Create("Frame", {
		Name = "Rank",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(30, SliceSummary.ROW),
		LayoutOrder = 1,
	}, {
		List = Style.list("x", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Number = Style.text({
			text = tostring(row.rank),
			weight = Enum.FontWeight.ExtraBold,
			size = 13,
			color = Theme.color("textSecondary"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 1 },
		}),
		-- the winner wears a laurel, never a crown: the crown is Emberhold's emblem (D-039)
		Laurel = if row.winner
			then (function()
				local laurel = Icon.new("laurel", 14)
				laurel.LayoutOrder = 2
				return laurel
			end)()
			else nil,
	})
	local crest = Crest.new(22, row.color, row.emblem)
	crest.LayoutOrder = 2
	local name = text({
		text = row.name,
		weight = Enum.FontWeight.Bold,
		size = 13,
		extra = {
			Name = "KingdomName",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 3,
		},
	})
	local children: { [any]: any } = {
		Corner = Style.corner(8),
		Stroke = Style.stroke(if row.mine then Theme.color("gold400") else Theme.color("ink500"), 1),
		Line = Create("Frame", {
			Name = "Line",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -70, 1, 0),
		}, {
			Padding = Style.padding(0, 0, 0, 8),
			List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Rank = rank,
			Crest = crest,
			KingdomName = name,
			YouTag = if row.mine then tag(ArmyText.YOU_TAG, true, 4) else nil,
			AiTag = if row.ai then tag(ArmyText.AI_TAG, false, 5) else nil,
		}),
		Points = text({
			text = row.points,
			weight = Enum.FontWeight.ExtraBold,
			size = 15,
			color = Theme.color("gold300"),
			xAlign = "Right",
			extra = {
				Name = "Points",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 0),
				Size = UDim2.new(0, 60, 1, 0),
			},
		}),
	}
	local frame = Create("Frame", {
		Name = "Standing_" .. row.id,
		BackgroundColor3 = if row.mine then Theme.color("gold500") else Theme.color("ink950"),
		BackgroundTransparency = if row.mine then 0.84 else 0.45,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, SliceSummary.ROW),
	}, children)
	frame:SetAttribute("rank", row.rank)
	frame:SetAttribute("mine", row.mine)
	frame:SetAttribute("winner", row.winner)
	return frame
end

local function headline(model: any, crestSize: number, nameSize: number): Frame
	local badge
	if model.winner then
		badge = Crest.new(crestSize, model.winner.color, model.winner.emblem)
	else
		badge = Crest.new(crestSize, Theme.color("ink600"), "standings")
	end
	badge.Name = "WinnerCrest"
	return Create("Frame", {
		Name = "Headline",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, crestSize),
	}, {
		WinnerCrest = badge,
		WinnerName = Style.text({
			text = model.headline,
			role = "display",
			weight = Enum.FontWeight.Bold,
			size = nameSize,
			color = Theme.color("gold300"),
			extra = {
				Position = UDim2.fromOffset(crestSize + 12, 0),
				Size = UDim2.new(1, -(crestSize + 12), 0, math.floor(crestSize * 0.62)),
				TextYAlignment = Enum.TextYAlignment.Bottom,
			},
		}),
		Sub = Style.text({
			text = model.sub,
			weight = Enum.FontWeight.Bold,
			size = 13,
			color = if model.tone == "win" then WIN else Theme.color("textPrimary"),
			extra = {
				Position = UDim2.fromOffset(crestSize + 12, math.floor(crestSize * 0.62) + 2),
				Size = UDim2.new(1, -(crestSize + 12), 0, 18),
			},
		}),
	})
end

local function kicker(model: any): Frame
	local icon = Icon.new(if model.tone == "win" then "laurel" else "standings", 14)
	icon.LayoutOrder = 1
	return Create("Frame", {
		Name = "Kicker",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
	}, {
		List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = icon,
		Text = Style.text({
			text = string.upper(model.kicker),
			weight = Enum.FontWeight.ExtraBold,
			size = 11,
			color = if model.tone == "win" then WIN else Theme.color("gold400"),
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	})
end

local function duration(textValue: string): Frame
	local icon = Icon.new("timer", 16)
	icon.LayoutOrder = 1
	return Create("Frame", {
		Name = "Duration",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		Padding = Style.padding(0, 8, 0, 4),
		List = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = icon,
		Text = Style.text({
			text = textValue,
			weight = Enum.FontWeight.Bold,
			size = 11,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	})
end

local function standingsHeader(): Frame
	local icon = Icon.new("standings", 14)
	icon.LayoutOrder = 1
	return Create("Frame", {
		Name = "StandingsHeader",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
	}, {
		Left = Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.6, 1),
		}, {
			List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Icon = icon,
			Text = Style.text({
				text = ArmyText.STANDINGS,
				role = "heading",
				weight = Enum.FontWeight.Bold,
				size = 12,
				color = Theme.color("gold300"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
			}),
		}),
		Right = Style.text({
			text = ArmyText.CROWN_POINTS,
			weight = Enum.FontWeight.Bold,
			size = 11,
			color = Theme.color("textSecondary"),
			xAlign = "Right",
			extra = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(0.4, 1),
			},
		}),
	})
end

function SliceSummary:render(model: any, metrics: any, ui: { [string]: any })
	self._ui = ui
	self:destroy()
	local phone = metrics.breakpoint == "phone"
	local width, height = SliceSummary.size(model, metrics)
	local pad = if phone then 14 else 16
	local panel = Panel.new({
		size = UDim2.fromOffset(width, height),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		padding = pad,
		zIndex = 2,
	})
	local content = panel.content
	self.continue = Button.new({
		text = ArmyText.CONTINUE,
		icon = "check",
		onActivated = function()
			if self._ui.onContinue then
				self._ui.onContinue()
			end
		end,
	})
	self.continue.instance.Name = "Continue"
	self.continue.instance.AnchorPoint = Vector2.new(0, 1)
	self.continue.instance.Position = UDim2.fromScale(0, 1)
	local left, right
	if phone then
		local leftWidth = SliceSummary.PHONE.left
		left = Create("Frame", {
			Name = "Left",
			BackgroundTransparency = 1,
			Size = UDim2.new(0, leftWidth, 1, 0),
			Parent = content,
		})
		right = Create("Frame", {
			Name = "Right",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(leftWidth + 14, 0),
			Size = UDim2.new(1, -(leftWidth + 14), 1, 0),
			Parent = content,
		})
		self.continue.instance.Size = UDim2.new(1, 0, 0, 44)
	else
		left = content
		right = Create("Frame", {
			Name = "Table",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 124),
			Size = UDim2.new(1, 0, 0, 24 + rowsHeight(#model.standings)),
			Parent = content,
		})
	end
	kicker(model).Parent = left
	local head = headline(model, if phone then 48 else 60, if phone then 28 else 34)
	head.Position = UDim2.fromOffset(0, 22)
	head.Parent = left
	if model.duration then
		local d = duration(model.duration)
		d.Position = UDim2.fromOffset(0, if phone then 80 else 92)
		d.Parent = left
	end
	self.continue.instance.Parent = left
	standingsHeader().Parent = right
	self.rows = {}
	for i, row in model.standings do
		local frame = standingRow(row, 24 + (i - 1) * (SliceSummary.ROW + SliceSummary.ROW_GAP))
		frame.Parent = right
		self.rows[row.id] = frame
	end
	self.instance = Create("Frame", {
		Name = "SliceSummary",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	}, {
		-- Blocks taps to the world and the HUD; only Continue closes the summary.
		Scrim = Create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.color("scrim"),
			BackgroundTransparency = 0.38,
			Size = UDim2.fromScale(1, 1),
		}),
		Panel = panel.instance,
	})
	self.panel = panel
	self.instance.Parent = self._parent
end

function SliceSummary:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self.rows = {}
	self.continue = nil
	self.panel = nil
end

return SliceSummary
