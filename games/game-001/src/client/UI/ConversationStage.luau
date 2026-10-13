--!strict
--[[
	UI/ConversationStage — the cinematic conversation (CONTRACTS G13.8, D-036; FL-0099): the citizen's
	portrait rises from the bottom of the screen, a speech bubble carries their words, and the ruler's
	2-4 answers sit beside it, while the kingdom stays visible behind (a bottom band dimmed at most
	StageModel.GEO.dimOpacity, nothing else covers the world). Geometry: UI/StageModel.
		asking     the question in the bubble; the answers (two per row when they fit), each with a
		           number, its text and chips: what it costs (red when the treasury is short, and
		           "Need 20 Wood" disables it) and each risk's chance ("30 %"); the full risk texts
		           are in the confirm step, which every answer with a cost or a risk goes through
		confirming the picked answer alone with its cost and every risk (UI/ConversationPanel's card),
		           Back / Choose under it; phones hide the question to keep the room
		choosing   the picked answer is marked and waits; every answer is disabled (answer once)
		answered   the citizen's reaction in the bubble, "WHAT CHANGED" consequence chips, Done with a
		           bar that runs down while the stage waits to close by itself (none with reduced
		           motion; the controller closes it after StageModel.readSeconds)
		refused    the reason as a sentence, Close
	Every sentence shown is the server's except the labels and the refusal sentences
	(UI/CitizenText), as in the panel.

	The portrait is built once per showing (UI/PortraitView) and kept across renders: it rises in
	GEO.rise seconds (Motion; reduced motion places it at once) only when a new showing appears.

	ConversationStage.new(parent: GuiObject, backdrop: GuiObject?) -> stage
		backdrop: the HUD's whole-device root (KingdomHudController roots.backdrop) for the dim band;
		without it the band goes under `parent` (clipped to the safe area)
	stage:render(state, metrics, ui) -> boolean
		false (and nothing drawn) when the portrait can't be built: the caller falls back to the panel
		state = ConversationController.state; ui = { key (the showing), figure = { look, job, kingdom },
		color: Color3?, banner: { color, emblem }?, balances?, motion (UI Motion), readSeconds?,
		onPick(optionId), onDone(), onClose(), onConfirm(), onBack() }
	stage:patch(balances)   a treasury push: repaints, in the same buttons, the answers whose "Need ..."
	                        changed and refits the height; nothing once the choice is on its way
	stage:destroy()         everything, the portrait included
	Names: "StageDim"; stage "ConversationStage" (attributes `phase`, `scenarioId`); "Portrait" (attribute
	`risen`) with "Viewport" (ViewportFrame) and "Nameplate" ("CitizenName", "CitizenSub", "Crest");
	"Column" with "Body" (scrolling: "Speech" holding "Question" or "Reaction", "Kicker", "Echo",
	"Answers" with rows "Row_<n>" of buttons "Option_<id>" (attributes `option`, `state`, `affordable`)
	holding "Number", "Label" and "Chips" ("Cost_<resource>" with "Amount" and attribute `short`;
	"Need"; "Risk_<n>" with attribute `percent`; "MoreRisks"), the confirm card "Option_<id>",
	"Effects", "Refusal", "Error"), the top-right "Close", and the footer: "Done" (with "Timer"),
	"Close" or "ConfirmBar" ("Back", "Confirm").
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local CitizenModel = require("./CitizenModel")
local CitizenText = require("./CitizenText")
local ConversationPanel = require("./ConversationPanel")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local PortraitView = require("./PortraitView")
local StageModel = require("./StageModel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ConversationStage = {}
ConversationStage.__index = ConversationStage

local P = ConversationPanel.parts
local RISK_BG = Color3.fromRGB(58, 42, 30)
local DIM_INSET = 24 -- the device's bottom inset (home bar) the backdrop band also covers

function ConversationStage.new(parent: Instance, backdrop: Instance?)
	return setmetatable({
		_parent = parent,
		_backdrop = backdrop,
		root = nil :: Frame?,
		dim = nil :: Frame?,
		portrait = nil :: any,
		holder = nil :: Frame?,
		options = {} :: { [string]: TextButton },
		_needs = {} :: { [string]: string },
		_open = {} :: { [string]: boolean },
		_key = nil :: string?,
	}, ConversationStage)
end

-- ------------------------------------------------------------------ parts

-- The citizen's words: a parchment bubble with a tail low on its left edge, toward the portrait.
local function bubble(name: string, s: string, r: any, order: number): Frame
	local G = StageModel.GEO
	local bp = r.breakpoint
	local pad = G.bubblePad[bp]
	return Create("Frame", {
		Name = "Speech",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(r.bubbleWidth, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Tail = Create("Frame", {
			BackgroundColor3 = Theme.color("parchment100"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			-- level with the last line, so it points down-left at the portrait below
			Position = UDim2.new(0, 1, 1, -math.floor(pad + G.bubbleLine[bp] / 2)),
			Size = UDim2.fromOffset(14, 14),
			Rotation = 45,
			ZIndex = 1,
		}, { Stroke = Style.stroke(Theme.color("gold600"), 1.5) }),
		Box = Create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 2,
		}, {
			Corner = Style.corner(12),
			Stroke = Style.stroke(Theme.color("gold600"), 1.5),
			Gradient = Style.gradient(Theme.color("parchment100"), Theme.color("parchment200")),
			Padding = Style.padding(pad, pad + 2),
			[name] = Style.text({
				text = s,
				role = "heading",
				weight = Enum.FontWeight.Regular,
				size = G.bubbleText[bp],
				color = Theme.color("inkText"),
				wrap = true,
				yAlign = "Top",
				extra = {
					Size = UDim2.new(1, 0, 0, G.bubbleLine[bp]),
					AutomaticSize = Enum.AutomaticSize.Y,
					LineHeight = CitizenModel.SPEECH_LINE_HEIGHT,
					ZIndex = 2,
				},
			}),
		}),
	})
end

-- One chip of an answer: an icon and a short bold text.
local function chip(name: string, icon: string, text: string, color: Color3, order: number, bg: Color3?): Frame
	local G = StageModel.GEO
	local i = Icon.new(icon, G.chipIcon)
	i.LayoutOrder = 1
	return Create("Frame", {
		Name = name,
		BackgroundColor3 = bg or Color3.new(),
		BackgroundTransparency = if bg then 0 else 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, G.chipRow),
		LayoutOrder = order,
	}, {
		Corner = Style.corner(999),
		Padding = Style.padding(0, if bg then 6 else 0, 0, if bg then 4 else 0),
		List = Style.list("x", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = i,
		Amount = Style.text({
			text = text,
			weight = Enum.FontWeight.Bold,
			size = 11,
			color = color,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	})
end

-- Cost chips, "Need ...", then one chip per risk with its chance and "+N" for risks without text.
local function chips(o: any, price: any, dim: boolean): Frame?
	local G = StageModel.GEO
	if #o.cost == 0 and not o.costUnknown and #o.risks == 0 and o.hiddenRisks == 0 then
		return nil
	end
	local list = Style.list("x", G.chipGap + 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	list.Wraps = true
	local row = Create("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, G.chipRow),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
	}, { List = list })
	local muted = Theme.color("textMuted")
	for i, c in o.cost do
		local short = price.short[c.id] == true
		local color = if short then P.DOWN elseif dim then muted else Theme.color("textPrimary")
		local cost = chip("Cost_" .. c.id, c.icon, Format.amount(c.amount), color, i)
		cost:SetAttribute("short", short)
		cost.Parent = row
	end
	if price.need then
		Style.text({
			text = price.need,
			weight = Enum.FontWeight.Bold,
			size = 11,
			color = P.DOWN,
			extra = {
				Name = "Need",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, G.chipRow),
				LayoutOrder = 20,
			},
		}).Parent =
			row
	end
	for i, risk in o.risks do
		local r = chip("Risk_" .. i, "warning", risk.label, if dim then muted else P.WARN_TEXT, 30 + i, RISK_BG)
		if risk.percent then
			r:SetAttribute("percent", risk.percent)
		end
		r.Parent = row
	end
	if o.hiddenRisks > 0 then
		chip("MoreRisks", "warning", `+{o.hiddenRisks}`, if dim then muted else P.WARN_TEXT, 50, RISK_BG).Parent = row
	end
	return row
end

-- ------------------------------------------------------------------ answers

-- An answer button. Painted by _paintAnswer, which a treasury push calls again on the same button.
function ConversationStage:_answer(
	o: any,
	state: any,
	onPick: (string) -> (),
	balances: any,
	height: number
): TextButton
	local button = Create("TextButton", {
		Name = "Option_" .. o.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, height),
		AutomaticSize = Enum.AutomaticSize.Y, -- taller than the estimate if the text needs it
		LayoutOrder = o.index,
		[Create.Event.Activated] = function()
			if self._open[o.id] then
				onPick(o.id)
			end
		end,
	})
	button:SetAttribute("option", o.id)
	self:_paintAnswer(button, o, state, balances)
	self.options[o.id] = button
	return button
end

function ConversationStage:_paintAnswer(button: TextButton, o: any, state: any, balances: any)
	local G = StageModel.GEO
	local price = CitizenModel.price(o, balances)
	local affordable = price.need == nil
	local status = if state.picked == nil then "idle" elseif state.picked == o.id then "picked" else "off"
	local waiting = status == "picked" and state.phase == "choosing"
	local open = state.phase == "asking" and affordable
	local dim = status == "off" or not affordable
	local top, bottom = Theme.color("ink600"), Theme.color("ink800")
	if status == "picked" and affordable then
		top, bottom = P.PICKED_TOP, P.PICKED_BOTTOM
	elseif dim then
		top, bottom = Theme.color("ink700"), Theme.color("ink800")
	end
	local body: { [any]: any } = {
		List = Style.list("y", G.chipGap, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Label = Style.text({
			text = o.text,
			weight = Enum.FontWeight.Bold,
			size = 13,
			color = if dim then Theme.color("textMuted") else Theme.color("parchment100"),
			wrap = true,
			yAlign = "Top",
			extra = {
				Size = UDim2.new(1, 0, 0, G.answerLine),
				AutomaticSize = Enum.AutomaticSize.Y,
				LineHeight = CitizenModel.LINE_HEIGHT,
				LayoutOrder = 1,
			},
		}),
	}
	local row = chips(o, price, dim)
	if row then
		body.Chips = row
	end
	local number = P.numberBadge(o.index, dim)
	number.AnchorPoint = Vector2.new(0, 0)
	number.Position = UDim2.fromOffset(0, -4)
	local children: { [any]: any } = {
		Corner = Style.corner(10),
		Stroke = Style.stroke(
			if status == "picked" and affordable
				then Theme.color("gold300")
				elseif dim then Theme.color("ink500")
				else Theme.color("gold600"),
			1.5
		),
		Gradient = Style.gradient(top, bottom),
		Padding = Style.padding(G.answerPadY, 12, G.answerPadY, 8),
		Number = number,
		Body = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -(34 + (if waiting then 24 else 0)), 0, G.answerLine),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, body),
	}
	if waiting then
		local icon = Icon.new("timer", 18)
		icon.AnchorPoint = Vector2.new(1, 0.5)
		icon.Position = UDim2.fromScale(1, 0.5)
		children.Waiting = icon
	end
	for _, child in button:GetChildren() do
		child:Destroy()
	end
	for name, child in children do
		child.Name = name
		child.Parent = button
	end
	button.Active = open
	button:SetAttribute("state", status)
	button:SetAttribute("affordable", affordable)
	self._open[o.id] = open
	self._needs[o.id] = price.need or ""
end

-- The answers, `r.columns` per row; a row is as tall as its tallest answer (the estimate).
function ConversationStage:_answers(state: any, r: any, onPick: (string) -> (), balances: any): Frame
	local G = StageModel.GEO
	local frame = Create("Frame", {
		Name = "Answers",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 3,
	}, { List = Style.list("y", G.answerGap, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	local options = state.conversation.options
	for i = 1, #options, r.columns do
		local tallest = 0
		for j = i, math.min(i + r.columns - 1, #options) do
			tallest = math.max(tallest, StageModel.answerHeight(options[j], r.answerWidth, balances, r.phone))
		end
		local row = Create("Frame", {
			Name = "Row_" .. ((i - 1) // r.columns + 1),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, tallest),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i,
			Parent = frame,
		}, { List = Style.list("x", G.answerGap, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
		for j = i, math.min(i + r.columns - 1, #options) do
			local holder = Create("Frame", {
				Name = "Slot_" .. j,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(r.answerWidth, tallest),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = j,
				Parent = row,
			})
			self:_answer(options[j], state, onPick, balances, tallest).Parent = holder
			self._slotOf[options[j].id] = holder
		end
	end
	return frame
end

-- ------------------------------------------------------------------ portrait

local function nameplate(state: any, r: any, banner: any): Frame
	local G = StageModel.GEO
	local bp = r.breakpoint
	local h = G.nameplate[bp]
	local speaker = state.conversation.speaker
	local crest = if banner and not r.phone then Crest.new(22, banner.color, banner.emblem) else nil
	local textX = if crest then 34 else 8
	local children: { [any]: any } = {
		Gradient = Style.gradient(
			Theme.color("ink950"),
			Theme.color("ink950"),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) })
		),
		Who = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(textX, 0),
			Size = UDim2.new(1, -(textX + 6), 1, 0),
		}, {
			List = Style.list("y", 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			CitizenName = Style.text({
				text = speaker.name,
				role = "heading",
				weight = Enum.FontWeight.Bold,
				size = if r.phone then 11 else 15,
				color = Theme.color("parchment100"),
				extra = {
					Size = UDim2.new(1, 0, 0, if r.phone then 14 else 19),
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = 1,
				},
			}),
			CitizenSub = if speaker.occupation
				then Style.text({
					text = speaker.occupation,
					weight = Enum.FontWeight.Bold,
					size = if r.phone then 10 else 11,
					color = Theme.color("gold400"),
					extra = {
						Size = UDim2.new(1, 0, 0, if r.phone then 12 else 14),
						TextTruncate = Enum.TextTruncate.AtEnd,
						LayoutOrder = 2,
					},
				})
				else nil,
		}),
	}
	if crest then
		crest.AnchorPoint = Vector2.new(0, 0.5)
		crest.Position = UDim2.new(0, 7, 0.5, 0)
		children.Crest = crest
	end
	children.Corner = Style.corner(12)
	return Create("Frame", {
		Name = "Nameplate",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, -4, 0, h),
		ZIndex = 3,
	}, children)
end

-- The framed portrait: a kingdom-tinted backdrop, the ViewportFrame and the name plate.
local function frameFor(view: any, color: Color3): Frame
	local top = color:Lerp(Theme.color("ink950"), 0.35)
	local holder = Create("Frame", {
		Name = "Portrait",
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
	}, {
		Corner = Style.corner(14),
		Stroke = Style.stroke(Theme.color("gold500"), 2),
		Gradient = Style.gradient(top, Theme.color("ink950")),
	})
	view.frame.ZIndex = 2
	view.frame.Position = UDim2.fromOffset(2, 2)
	view.frame.Size = UDim2.new(1, -4, 1, -4)
	Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = view.frame })
	view.frame.Parent = holder
	return holder
end

-- ------------------------------------------------------------------ render

function ConversationStage:render(state: any, metrics: any, ui: { [string]: any }): boolean
	local G = StageModel.GEO
	local r = StageModel.rects(metrics)
	-- The portrait first: without it there is no stage (the caller shows the panel instead).
	local rise = false
	if self._key ~= ui.key or self.portrait == nil then
		self:destroy()
		local view = PortraitView.new(ui.figure or {})
		if view == nil then
			return false
		end
		self.portrait = view
		self.holder = frameFor(view, ui.color or PortraitView.colorOf(ui.figure and ui.figure.kingdom))
		self._key = ui.key
		rise = true
	end
	self:_clear()
	local balances = ui.balances
	local height = StageModel.height(state, r, balances)
	self._state, self._rects, self._onPick, self._metrics = state, r, ui.onPick, metrics
	local root = Create("Frame", {
		Name = "ConversationStage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(r.x, r.bottom - height),
		Size = UDim2.fromOffset(r.width, height),
	})
	root:SetAttribute("phase", state.phase)
	root:SetAttribute("scenarioId", state.conversation.scenarioId)
	self.root = root
	-- The dim: a band from DIM_FADE above the stage to the bottom, at most dimOpacity dark. On the
	-- HUD's whole-device backdrop it spans the device's width (past a notch) and is anchored to the
	-- device's bottom; its top may sit up to DIM_INSET higher (the bottom inset is not known here).
	local dimTop = math.max(0, r.bottom - height - G.dimFade)
	local band = metrics.height - dimTop
	self.dim = Create("Frame", {
		Name = "StageDim",
		BackgroundColor3 = Theme.color("ink950"),
		BorderSizePixel = 0,
		AnchorPoint = if self._backdrop then Vector2.new(0, 1) else Vector2.zero,
		Position = if self._backdrop then UDim2.fromScale(0, 1) else UDim2.fromOffset(0, dimTop),
		Size = UDim2.new(1, 0, 0, if self._backdrop then band + DIM_INSET else band),
		ZIndex = 0,
	}, {
		Gradient = Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 1 - G.dimOpacity),
			}),
		}),
	})
	-- The portrait: bottom left; it rises from below the screen for a new showing.
	local holder = self.holder :: Frame
	local final = UDim2.fromOffset(0, height - r.portrait)
	holder.Size = UDim2.fromOffset(r.portrait, r.portrait)
	local plate = holder:FindFirstChild("Nameplate")
	if plate then
		plate:Destroy()
	end
	nameplate(state, r, ui.banner).Parent = holder
	holder.Parent = root
	if rise and ui.motion and ui.motion.enabled then
		holder.Position = UDim2.fromOffset(0, height - r.portrait + metrics.height)
		holder:SetAttribute("risen", false)
		ui.motion:to(holder, { Position = final }, G.rise, Enum.EasingStyle.Quint)
		ui.motion:after(G.rise, function()
			if self.holder == holder then
				holder:SetAttribute("risen", true)
			end
		end)
	else
		holder.Position = final
		holder:SetAttribute("risen", true)
	end
	-- The column: the body scrolls; the close button and the footer stay put.
	local outcome = state.outcome
	local finished = (state.phase == "answered" or state.phase == "refused") and outcome ~= nil
	local confirming = state.phase == "confirming"
	local footer = if finished or confirming then G.footer else 0
	local column = Create("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(r.body.x - r.x, 0),
		Size = UDim2.fromOffset(r.body.width, height),
		Parent = root,
	})
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
		Parent = column,
	}, {
		List = Style.list("y", G.gap6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Padding = Style.padding(0, 0, 1, r.tail),
	})
	local close = IconButton.new({
		icon = "close",
		variant = "plain",
		size = r.close,
		onActivated = ui.onClose,
	})
	close.instance.Name = "Close"
	close.instance.AnchorPoint = Vector2.new(1, 0)
	close.instance.Position = UDim2.fromScale(1, 0)
	close.instance.Parent = column
	local convo = state.conversation
	local showsBubble = StageModel.showsBubble(state, r.phone)
	-- The first row leaves room for the close button: the bubble, else a head row beside it.
	local head = nil
	if StageModel.hasHead(state, r.phone) then
		head = Create("Frame", {
			Name = "Head",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(r.bubbleWidth, r.close),
			LayoutOrder = 0,
			Parent = body,
		})
	end
	if finished and state.phase == "answered" then
		if head and not r.phone and state.picked then
			for _, o in convo.options do
				if o.id == state.picked then
					local echo = P.echo(o.text, 1)
					echo.AnchorPoint = Vector2.new(0, 0.5)
					echo.Position = UDim2.fromScale(0, 0.5)
					echo.Parent = head
				end
			end
		end
		if outcome.reaction then
			bubble("Reaction", outcome.reaction, r, 2).Parent = body
		end
		if #outcome.effects > 0 then
			if not r.phone then
				P.kicker("WHAT CHANGED", 3).Parent = body
			end
			P.effects(outcome, r.phone, r.column.width, 4).Parent = body
		end
		local done = Button.new({ text = "Done", icon = "check", variant = "primary", onActivated = ui.onDone })
		done.instance.Name = "Done"
		self.footer = done
		if ui.readSeconds and ui.motion and ui.motion.enabled then
			local bar = Create("Frame", {
				Name = "Timer",
				BackgroundColor3 = Theme.color("gold300"),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 10, 1, -3),
				Size = UDim2.new(1, -20, 0, 3),
				ZIndex = 5,
				Parent = done.instance,
			}, { Corner = Style.corner(999) })
			ui.motion:to(bar, { Size = UDim2.fromOffset(0, 3) }, ui.readSeconds, Enum.EasingStyle.Linear)
		end
	elseif finished then
		if showsBubble then
			bubble("Question", convo.question, r, 1).Parent = body
		end
		P.refusal(outcome.message, 2).Parent = body
		local done = Button.new({ text = "Close", variant = "secondary", onActivated = ui.onDone })
		done.instance.Name = "Close"
		self.footer = done
	elseif confirming then
		if showsBubble then
			bubble("Question", convo.question, r, 1).Parent = body
			P.kicker(CitizenText.CONFIRM_KICKER, 2).Parent = body
		elseif head then
			local kicker = P.kicker(CitizenText.CONFIRM_KICKER, 1)
			kicker.AnchorPoint = Vector2.new(0, 0.5)
			kicker.Position = UDim2.fromScale(0, 0.5)
			kicker.Parent = head
		end
		for _, o in convo.options do
			if o.id == state.picked then
				local card = Create("TextButton", {
					Name = "Option_" .. o.id,
					Text = "",
					AutoButtonColor = false,
					BackgroundColor3 = Color3.new(1, 1, 1),
					Size = UDim2.new(1, 0, 0, CitizenModel.CONVO.optionMin),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 3,
				})
				card:SetAttribute("option", o.id)
				local _, need = ConversationPanel.paintCard(card, o, state, balances)
				self._needs[o.id] = need
				self.options[o.id] = card
				card.Parent = body
				self:_confirmBar(ui, need == "")
			end
		end
	else
		bubble("Question", convo.question, r, 1).Parent = body
		if not r.phone or StageModel.overflows(state, r, balances) then
			self._kicker = P.kicker(self:_kickerText(state, r, balances), 2)
			self._kicker.Parent = body
		end
		self._slotOf = {}
		self:_answers(state, r, ui.onPick, balances).Parent = body
		if state.error then
			Style.text({
				text = state.error,
				weight = Enum.FontWeight.Bold,
				size = 12,
				color = P.DOWN,
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
		local f = self.footer.instance
		f.AnchorPoint = Vector2.new(1, 1)
		f.Position = UDim2.fromScale(1, 1)
		f.Size = UDim2.fromOffset(math.min(220, r.column.width), 44)
		f.Parent = column
	end
	self.dim.Parent = self._backdrop or self._parent
	root.Parent = self._parent
	return true
end

function ConversationStage:_kickerText(state: any, r: any, balances: any): string
	if StageModel.overflows(state, r, balances) then
		return `YOUR ANSWER · SCROLL FOR ALL {#state.conversation.options}`
	end
	return "YOUR ANSWER"
end

-- Back (secondary) and Choose (primary, disabled while the treasury can't pay), across the column.
function ConversationStage:_confirmBar(ui: { [string]: any }, affordable: boolean)
	local back = Button.new({ text = CitizenText.BACK, variant = "secondary", onActivated = ui.onBack })
	back.instance.Name = "Back"
	back.instance.Size = UDim2.new(0.4, -4, 0, 44)
	back.instance.LayoutOrder = 1
	local confirm = Button.new({
		text = CitizenText.CONFIRM,
		icon = "check",
		variant = "primary",
		state = if affordable then "default" else "disabled",
		onActivated = ui.onConfirm,
	})
	confirm.instance.Name = "Confirm"
	confirm.instance.Size = UDim2.new(0.6, -4, 0, 44)
	confirm.instance.LayoutOrder = 2
	self._confirmButtons = { back = back, confirm = confirm }
	local r = self._rects
	local bar = Create("Frame", {
		Name = "ConfirmBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(r.column.width, 44),
	}, { List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom) })
	back.instance.Parent = bar
	confirm.instance.Parent = bar
	local root = self.root :: Frame
	bar.Parent = root:FindFirstChild("Column")
end

-- A treasury push: only answers whose "Need ..." changed are repainted, inside the same button.
-- Nothing while the choice is on its way or done (once the server has charged, the picked answer
-- must not turn red).
function ConversationStage:patch(balances: any)
	local state = self._state
	if self.root == nil or state == nil or (state.phase ~= "asking" and state.phase ~= "confirming") then
		return
	end
	local changed = false
	for _, o in state.conversation.options do
		local button = self.options[o.id]
		local need = CitizenModel.price(o, balances).need or ""
		if button and need ~= self._needs[o.id] then
			changed = true
			if state.phase == "confirming" then
				local _, now = ConversationPanel.paintCard(button, o, state, balances)
				self._needs[o.id] = now
				if self._confirmButtons then
					self._confirmButtons.confirm:update({ state = if now == "" then "default" else "disabled" })
				end
			else
				self:_paintAnswer(button, o, state, balances)
			end
		end
	end
	if not changed then
		return
	end
	-- Refit: the rows and the stage follow the new estimate (a "Need ..." can add a chip row).
	local r = self._rects
	if state.phase == "asking" then
		local options = state.conversation.options
		for i = 1, #options, r.columns do
			local tallest = 0
			for j = i, math.min(i + r.columns - 1, #options) do
				tallest = math.max(tallest, StageModel.answerHeight(options[j], r.answerWidth, balances, r.phone))
			end
			for j = i, math.min(i + r.columns - 1, #options) do
				local button = self.options[options[j].id]
				local slot = self._slotOf and self._slotOf[options[j].id]
				if button and slot then
					button.Size = UDim2.new(1, 0, 0, tallest)
					slot.Size = UDim2.fromOffset(r.answerWidth, tallest)
					local row = slot.Parent :: Frame
					row.Size = UDim2.new(1, 0, 0, tallest)
				end
			end
		end
	end
	local height = StageModel.height(state, r, balances)
	local root = self.root :: Frame
	root.Size = UDim2.fromOffset(r.width, height)
	root.Position = UDim2.fromOffset(r.x, r.bottom - height)
	local column = root:FindFirstChild("Column") :: Frame?
	if column then
		column.Size = UDim2.fromOffset(r.body.width, height)
	end
	if self.holder then
		self.holder.Position = UDim2.fromOffset(0, height - r.portrait)
	end
	if self._kicker then
		self._kicker.Text = self:_kickerText(state, r, balances)
	end
end

-- Everything but the portrait (kept for the same showing).
function ConversationStage:_clear()
	if self.holder then
		self.holder.Parent = nil
	end
	if self.root then
		self.root:Destroy()
		self.root = nil
	end
	if self.dim then
		self.dim:Destroy()
		self.dim = nil
	end
	self.options = {}
	self._needs = {}
	self._open = {}
	self._slotOf = {}
	self._kicker = nil
	self._confirmButtons = nil
	self.footer = nil
	self._state = nil
end

function ConversationStage:destroy()
	self:_clear()
	if self.portrait then
		self.portrait:destroy()
		self.portrait = nil
	end
	if self.holder then
		self.holder:Destroy()
		self.holder = nil
	end
	self._key = nil
end

return ConversationStage
