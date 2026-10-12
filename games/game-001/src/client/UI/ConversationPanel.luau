--!strict
--[[
	UI/ConversationPanel — a structured conversation with a citizen (CONTRACTS G13.3; prototype scenes
	"talk-2", "talk-3", "talk-4", "talk-long", "choosing", "answered", "refused").
		asking     the speaker, their question in a speech box, 2-4 answers (full-width buttons on
		           tablet/desktop; two columns on phones), each at least 44 px tall and wrapping
		choosing   the picked answer is marked and every answer is disabled (answer once)
		answered   the reaction in the speech box and "What changed" effect chips, then Done
		refused    the reason as a sentence, then Close
	Tablet/desktop: in the drawer's place, height fitted to the text; phone: a wide sheet below the
	resource pills (UI/CitizenModel geometry). Every sentence shown is the server's except the labels
	(YOUR ANSWER, WHAT CHANGED, Done, Close) and the refusal sentences (UI/CitizenText).

	ConversationPanel.new(parent: GuiObject) -> panel
	panel:render(state, metrics, ui: { color: Color3?, onPick(optionId), onDone(), onClose() })
		state = ConversationController.state: { phase, conversation (CitizenModel Conversation),
		        picked?, outcome? (CitizenModel Outcome), error? }
	panel:destroy()
	Names: panel "Conversation"; "Question" and "Reaction" (wrapped TextLabels in "Speech" boxes);
	"Options" with buttons "Option_<id>" (attributes `option`, `state` = idle | picked | off) and
	their "Label"; "Error"; "Echo"; "Effects" with "Effect_<n>" (attributes `kind`, `tone`) and their
	"Label"; "Refusal" with "Reason"; buttons "Done" / "Close" (footer) and the header's X "Close".
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local CitizenCard = require("./CitizenCard")
local CitizenModel = require("./CitizenModel")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ConversationPanel = {}
ConversationPanel.__index = ConversationPanel

local UP = Color3.fromRGB(169, 229, 124)
local DOWN = Color3.fromRGB(255, 138, 115)
local WARN_BG = Color3.fromRGB(58, 42, 30)
local WARN_TEXT = Color3.fromRGB(246, 198, 122)
local PICKED_TOP = Color3.fromRGB(74, 64, 48)
local PICKED_BOTTOM = Color3.fromRGB(46, 42, 34)

function ConversationPanel.new(parent: Instance)
	return setmetatable({ _parent = parent, panel = nil, options = {} }, ConversationPanel)
end

local function tint(name: string): Color3
	local resource = string.match(name, "^resource:(.+)$")
	if resource then
		return Theme.resource(resource)
	end
	return Theme.color(name)
end

-- A parchment speech box with a tail pointing up at the speaker. The tail sits behind the box in a
-- holder (children draw above their parent, so a tail inside the box would show its lower stroke).
local function speech(name: string, s: string, phone: boolean, order: number): Frame
	local C = CitizenModel.CONVO
	local pad = if phone then C.phoneSpeechPad else C.speechPad
	local line = if phone then C.phoneSpeechLine else C.speechLine
	return Create("Frame", {
		Name = "Speech",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Tail = Create("Frame", {
			BackgroundColor3 = Theme.color("parchment100"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(24, C.tail),
			Size = UDim2.fromOffset(12, 12),
			Rotation = 45,
			ZIndex = 1,
		}, { Stroke = Style.stroke(Theme.color("gold600"), 1.5) }),
		Box = Create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = UDim2.fromOffset(0, C.tail),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 2,
		}, {
			Corner = Style.corner(10),
			Stroke = Style.stroke(Theme.color("gold600"), 1.5),
			Gradient = Style.gradient(Theme.color("parchment100"), Theme.color("parchment200")),
			Padding = Style.padding(pad, pad + 2),
			[name] = Style.text({
				text = s,
				role = "heading",
				weight = Enum.FontWeight.Regular,
				size = if phone then 13 else 14,
				color = Theme.color("inkText"),
				wrap = true,
				yAlign = "Top",
				extra = {
					Size = UDim2.new(1, 0, 0, line),
					AutomaticSize = Enum.AutomaticSize.Y,
					LineHeight = CitizenModel.SPEECH_LINE_HEIGHT,
					ZIndex = 2,
				},
			}),
		}),
	})
end

local function kicker(s: string, order: number): TextLabel
	return Style.text({
		text = s,
		weight = Enum.FontWeight.ExtraBold,
		size = 11,
		color = Theme.color("gold400"),
		extra = { Name = "Kicker", Size = UDim2.new(1, 0, 0, CitizenModel.CONVO.kicker), LayoutOrder = order },
	}) :: TextLabel
end

local function numberBadge(n: number, dim: boolean): Frame
	return Create("Frame", {
		Name = "Number",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(24, 24),
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("gold700"), 1.5),
		Gradient = if dim
			then Style.gradient(Theme.color("ink600"), Theme.color("ink700"))
			else Style.gradient(Theme.hex("#F6DA86"), Theme.color("gold500")),
		Digit = Style.text({
			text = tostring(n),
			weight = Enum.FontWeight.ExtraBold,
			size = 12,
			color = if dim then Theme.color("textMuted") else Theme.color("inkText"),
			xAlign = "Center",
			extra = { Size = UDim2.fromScale(1, 1) },
		}),
	})
end

function ConversationPanel:_option(o: any, state: any, width: UDim, onPick: (string) -> ()): TextButton
	local status = if state.picked == nil then "idle" elseif state.picked == o.id then "picked" else "off"
	local waiting = status == "picked" and state.phase == "choosing"
	local open = state.phase == "asking"
	local top, bottom = Theme.color("ink600"), Theme.color("ink800")
	if status == "picked" then
		top, bottom = PICKED_TOP, PICKED_BOTTOM
	elseif status == "off" then
		top, bottom = Theme.color("ink700"), Theme.color("ink800")
	end
	local children: { [any]: any } = {
		Corner = Style.corner(10),
		Stroke = Style.stroke(
			if status == "picked"
				then Theme.color("gold300")
				elseif status == "off" then Theme.color("ink500")
				else Theme.color("gold600"),
			1.5
		),
		Gradient = Style.gradient(top, bottom),
		Padding = Style.padding(8, 12, 8, 8),
		Number = numberBadge(o.index, status == "off"),
		Label = Style.text({
			text = o.text,
			weight = Enum.FontWeight.Bold,
			size = 13,
			color = if status == "off" then Theme.color("textMuted") else Theme.color("parchment100"),
			wrap = true,
			extra = {
				Position = UDim2.fromOffset(34, 0),
				Size = UDim2.new(1, -(34 + (if waiting then 24 else 0)), 0, 28),
				AutomaticSize = Enum.AutomaticSize.Y,
				LineHeight = CitizenModel.LINE_HEIGHT,
			},
		}),
	}
	if waiting then
		local icon = Icon.new("timer", 18)
		icon.AnchorPoint = Vector2.new(1, 0.5)
		icon.Position = UDim2.fromScale(1, 0.5)
		children.Waiting = icon
	end
	local button = Create("TextButton", {
		Name = "Option_" .. o.id,
		Text = "",
		AutoButtonColor = false,
		Active = open,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(width, UDim.new(0, CitizenModel.CONVO.optionMin)),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = o.index,
		[Create.Event.Activated] = function()
			if open then
				onPick(o.id)
			end
		end,
	}, children)
	button:SetAttribute("option", o.id)
	button:SetAttribute("state", status)
	self.options[o.id] = button
	return button
end

function ConversationPanel:_options(state: any, phone: boolean, onPick: (string) -> ()): Frame
	local C = CitizenModel.CONVO
	local frame = Create("Frame", {
		Name = "Options",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	}, {
		List = Style.list(
			"y",
			if phone then C.gridGap else C.optionGap,
			Enum.HorizontalAlignment.Left,
			Enum.VerticalAlignment.Top
		),
	})
	local options = state.conversation.options
	if not phone then
		for _, o in options do
			self:_option(o, state, UDim.new(1, 0), onPick).Parent = frame
		end
		return frame
	end
	-- Phones: two answers per row; a row is as tall as its taller answer (ItemLineAlignment Stretch).
	for i = 1, #options, 2 do
		local list = Style.list("x", C.gridGap, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
		list.ItemLineAlignment = Enum.ItemLineAlignment.Stretch
		local row = Create("Frame", {
			Name = "Row_" .. ((i + 1) // 2),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, C.optionMin),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = frame,
		}, { List = list })
		local half = UDim.new(0.5, -math.floor(C.gridGap / 2))
		self:_option(options[i], state, half, onPick).Parent = row
		if options[i + 1] then
			self:_option(options[i + 1], state, half, onPick).Parent = row
		end
	end
	return frame
end

local function effectChip(e: any, index: number, phone: boolean, maxWidth: number): Frame
	local C = CitizenModel.CONVO
	local height = if phone then C.phoneChip else C.chip
	local icon = Icon.new(e.icon, if phone then 18 else 20)
	icon.LayoutOrder = 1
	local label = Style.text({
		text = e.text,
		weight = Enum.FontWeight.Bold,
		size = if phone then 11 else 12,
		color = if e.tone == "up" then UP elseif e.tone == "down" then DOWN else Theme.color("textPrimary"),
		extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
	})
	-- A very long effect text truncates instead of pushing the chip out of the panel.
	Create("UISizeConstraint", { MaxSize = Vector2.new(math.max(80, maxWidth - 40), height), Parent = label })
	local chip = Create("Frame", {
		Name = "Effect_" .. index,
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.22,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		LayoutOrder = index,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(tint(e.tint), 1.5),
		Padding = Style.padding(0, 10, 0, 4),
		List = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = icon,
		Label = label,
	})
	chip:SetAttribute("kind", e.kind)
	chip:SetAttribute("tone", e.tone)
	return chip
end

local function effects(outcome: any, phone: boolean, maxWidth: number, order: number): Frame
	local C = CitizenModel.CONVO
	local list = Style.list("x", C.chipGap, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	list.Wraps = true
	local frame = Create("Frame", {
		Name = "Effects",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if phone then C.phoneChip else C.chip),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, { List = list })
	for i, e in outcome.effects do
		effectChip(e, i, phone, maxWidth).Parent = frame
	end
	return frame
end

local function echo(s: string, order: number): Frame
	return Create("Frame", {
		Name = "Echo",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		You = Style.text({
			text = "You:",
			size = 12,
			color = Theme.color("textSecondary"),
			yAlign = "Top",
			extra = { Size = UDim2.fromOffset(32, 16) },
		}),
		Answer = Style.text({
			text = s,
			weight = Enum.FontWeight.Bold,
			size = 12,
			color = Theme.color("gold300"),
			wrap = true,
			yAlign = "Top",
			extra = {
				Position = UDim2.fromOffset(32, 0),
				Size = UDim2.new(1, -32, 0, 16),
				AutomaticSize = Enum.AutomaticSize.Y,
				LineHeight = CitizenModel.LINE_HEIGHT,
			},
		}),
	})
end

local function refusal(message: string, order: number): Frame
	local icon = Icon.new("warning", 18)
	icon.Position = UDim2.fromOffset(0, 0)
	return Create("Frame", {
		Name = "Refusal",
		BackgroundColor3 = WARN_BG,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("amber"), 1.5),
		Padding = Style.padding(10, 12),
		Icon = icon,
		Reason = Style.text({
			text = message,
			weight = Enum.FontWeight.Bold,
			size = 13,
			color = WARN_TEXT,
			wrap = true,
			yAlign = "Top",
			extra = {
				Position = UDim2.fromOffset(26, 0),
				Size = UDim2.new(1, -26, 0, 18),
				AutomaticSize = Enum.AutomaticSize.Y,
				LineHeight = CitizenModel.LINE_HEIGHT,
			},
		}),
	})
end

function ConversationPanel:render(state: any, metrics: any, ui: { [string]: any })
	self:destroy()
	local C = CitizenModel.CONVO
	local phone = metrics.breakpoint == "phone"
	local rect = CitizenModel.conversationRect(metrics)
	local height = CitizenModel.conversationHeight(state, rect, phone)
	local pad = if phone then C.phonePad else C.pad
	local speaker = state.conversation.speaker
	local header = CitizenCard.header({
		initial = speaker.initial,
		name = speaker.name,
		sub = speaker.occupation,
		color = ui.color or Theme.color("gules"),
		avatar = if phone then 30 else 36,
		onClose = ui.onClose,
	})
	self.panel = Panel.new({
		header = header,
		size = UDim2.fromOffset(rect.width, height),
		position = UDim2.fromOffset(rect.x, rect.y),
		padding = pad,
	})
	local root = self.panel.instance
	root.Name = "Conversation"
	root:SetAttribute("phase", state.phase)
	root:SetAttribute("scenarioId", state.conversation.scenarioId)
	local content = self.panel.content
	local outcome = state.outcome
	local finished = (state.phase == "answered" or state.phase == "refused") and outcome ~= nil
	local footer = if finished then C.footer else 0
	local body = Create("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -footer),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color("gold600"),
		Parent = content,
	}, {
		List = Style.list("y", C.gap, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Padding = Style.padding(C.canvasTop, C.scrollGutter, 1, 0),
	})
	self.options = {}
	self.footer = nil
	if finished and state.phase == "answered" then
		if not phone and state.picked then
			for _, o in state.conversation.options do
				if o.id == state.picked then
					echo(o.text, 1).Parent = body
				end
			end
		end
		if outcome.reaction then
			speech("Reaction", outcome.reaction, phone, 2).Parent = body
		end
		if #outcome.effects > 0 then
			kicker("WHAT CHANGED", 3).Parent = body
			effects(outcome, phone, rect.width - 2 * pad - C.scrollGutter, 4).Parent = body
		end
		self.footer = Button.new({ text = "Done", icon = "check", variant = "primary", onActivated = ui.onDone })
		self.footer.instance.Name = "Done"
	elseif finished then
		refusal(outcome.message, 1).Parent = body
		self.footer = Button.new({ text = "Close", variant = "secondary", onActivated = ui.onDone })
		self.footer.instance.Name = "Close"
	else
		speech("Question", state.conversation.question, phone, 1).Parent = body
		local count = #state.conversation.options
		kicker(
			if CitizenModel.conversationOverflows(state, rect, phone)
				then `YOUR ANSWER · SCROLL FOR ALL {count}`
				else "YOUR ANSWER",
			2
		).Parent =
			body
		self:_options(state, phone, ui.onPick).Parent = body
		if state.error then
			Style.text({
				text = state.error,
				weight = Enum.FontWeight.Bold,
				size = 12,
				color = DOWN,
				wrap = true,
				extra = {
					Name = "Error",
					Size = UDim2.new(1, 0, 0, 16),
					AutomaticSize = Enum.AutomaticSize.Y,
					LineHeight = CitizenModel.LINE_HEIGHT,
					LayoutOrder = 4,
				},
			}).Parent =
				body
		end
	end
	if self.footer then
		self.footer.instance.AnchorPoint = Vector2.new(0, 1)
		self.footer.instance.Position = UDim2.fromScale(0, 1)
		self.footer.instance.Parent = content
	end
	root.Parent = self._parent
end

function ConversationPanel:destroy()
	if self.panel then
		self.panel:destroy()
		self.panel = nil
	end
	self.options = {}
	self.footer = nil
end

return ConversationPanel
