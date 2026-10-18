--!strict
--[[
	UI/RivalsList — the Kingdom panel's Rivals tab: war and peace with each rival kingdom (FL-0129,
	Operation Crownfall, D-053 (2)). Rows come from UI/DiplomacyModel.

		RivalsList.build(parent, view, phone, ui) -> ScrollingFrame "Rivals"
			ui = { onAction(kingdomId, actionId), onConfirm(kingdomId), onCancel(), confirm: KingdomId? }
			One row per rival ("Rival_<id>"): crest, name, a relation chip ("Relation", attribute
			`relation`), "#rank · N Crown Points", a time-bound note ("Note") and the actions ("Action_<id>",
			attribute `enabled`; a disabled action's reason is the "Reason" line). Declare war asks first:
			while ui.confirm is that rival, the row shows "Declare war on <name>?" with "Confirm" and
			"Cancel" instead. A co-ruler (D-054, view.senior set) asks instead: "Ask <senior> to
			declare war", then "Ask <senior> to declare war on <name>?".
		RivalsList.key(view, phone, confirm) -> string   what changes the rows' structure (rebuild);
		                                         countdowns and scores are patched by paint (no flicker)
		RivalsList.paint(body, view)             patches the texts that tick: notes, reasons, points
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Signature = require("./Signature")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local RivalsList = {}

-- The relation chip's colour: war red, peace green, truce amber, fallen grey (UITheme tinctures).
RivalsList.CHIP = table.freeze({
	war = "gules",
	peace = "vert",
	truce = "amber",
	fallen = "textMuted",
})

function RivalsList.key(view: any, phone: boolean, confirm: string?): string
	local rows = {}
	for i, r in view.rows do
		local actions = {}
		for j, a in r.actions do
			actions[j] = { id = a.id, enabled = a.enabled, variant = a.variant }
		end
		rows[i] = { id = r.id, relation = r.relation, note = r.note ~= nil, actions = actions }
	end
	return Signature.of({ tab = "rivals", rows = rows, phone = phone, confirm = confirm, senior = view.senior })
end

-- Phones (the 260 px drawer): "pts" for "Crown Points", so rank and score fit beside the chip.
local function score(r: any, phone: boolean?): string
	local rank = if r.rank then `#{r.rank} · ` else ""
	return `{rank}{Format.amount(r.crownPoints)} {if phone then "pts" else "Crown Points"}`
end

-- The head's text column: the crest's 44 px on the left, the chip's widest ("At peace") on the right.
local function textWidth(phone: boolean): UDim
	return UDim.new(1, if phone then -122 else -140)
end

-- Desktop: 132 px buttons in a row. Phones: two half-width slots ("Slot_<id>") so "Accept peace" and
-- "Propose peace" both fit the narrow drawer (FL-0129 phone pass); the button fills its slot.
local function actionButton(
	action: any,
	phone: boolean,
	order: number,
	parent: Instance,
	onActivated: () -> (),
	alone: boolean?
)
	local button = Button.new({
		text = action.label,
		variant = action.variant,
		state = if action.enabled then "default" else "disabled",
		size = "small",
		-- a co-ruler's "Ask <senior> to declare war" (D-054) needs more room than "Declare war"
		width = if phone then nil elseif action.ask then 240 else 132,
		layoutOrder = order,
		onActivated = onActivated,
	})
	button.instance.Name = "Action_" .. action.id
	button.instance:SetAttribute("enabled", action.enabled)
	if phone then
		Create("Frame", {
			Name = "Slot_" .. action.id,
			BackgroundTransparency = 1,
			Size = if alone and action.ask then UDim2.fromScale(1, 0) else UDim2.new(0.5, -4, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = parent,
		})
		button.instance.Parent = parent:FindFirstChild("Slot_" .. action.id)
	else
		button.instance.Parent = parent
	end
	return button
end

local function line(frame: Instance, name: string, text: string, order: number, color: string, bold: boolean)
	return Style.text({
		text = text,
		weight = if bold then Enum.FontWeight.Bold else Enum.FontWeight.SemiBold,
		size = if bold then 12 else 11,
		color = Theme.color(color),
		wrap = true,
		extra = {
			Name = name,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			Parent = frame,
		},
	})
end

local function row(r: any, phone: boolean, ui: any, order: number, senior: string?): Frame
	local chipColor = Theme.color(RivalsList.CHIP[r.relation] or "textMuted")
	local frame = Create("Frame", {
		Name = "Rival_" .. r.id,
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = if r.alive then 0.5 else 0.75,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(if r.relation == "war" then chipColor else Theme.color("ink500"), 1),
		Padding = Style.padding(8, 10),
		List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	})
	local head = Create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 1,
		Parent = frame,
	}, {
		Name = Style.text({
			text = r.name,
			weight = Enum.FontWeight.Bold,
			size = 14,
			color = if r.alive then Theme.color("textPrimary") else Theme.color("textMuted"),
			extra = { Position = UDim2.fromOffset(44, 0), Size = UDim2.new(textWidth(phone), UDim.new(0, 18)) },
		}),
		Score = Style.text({
			text = score(r, phone),
			weight = Enum.FontWeight.SemiBold,
			size = 11,
			color = Theme.color("textSecondary"),
			extra = { Position = UDim2.fromOffset(44, 19), Size = UDim2.new(textWidth(phone), UDim.new(0, 15)) },
		}),
		Relation = Create("Frame", {
			Name = "Relation",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = chipColor,
			BackgroundTransparency = 0.78,
		}, {
			Corner = Style.corner(999),
			Stroke = Style.stroke(chipColor, 1),
			Padding = Style.padding(0, if phone then 8 else 10),
			Label = Style.text({
				text = r.status,
				weight = Enum.FontWeight.Bold,
				size = if phone then 11 else 12,
				color = Theme.color("textPrimary"),
				xAlign = "Center",
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) },
			}),
		}),
	})
	head.Relation:SetAttribute("relation", r.relation)
	local crest = Crest.new(34, r.color, r.emblem)
	crest.AnchorPoint = Vector2.new(0, 0.5)
	crest.Position = UDim2.fromScale(0, 0.5)
	crest.Parent = head
	if r.note then
		Style.text({
			text = r.note,
			weight = Enum.FontWeight.Bold,
			size = 12,
			color = Theme.color("gold300"),
			extra = { Name = "Note", Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2, Parent = frame },
		})
	end
	if #r.actions == 0 then
		return frame
	end
	local confirming = ui.confirm == r.id
	if confirming then
		local question = if senior then `Ask {senior} to declare war on {r.name}?` else `Declare war on {r.name}?`
		line(frame, "Question", question, 3, "textPrimary", true)
	end
	local actions = Create("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 4,
		Parent = frame,
	}, { List = Style.list("x", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	if confirming then
		actionButton(
			{ id = "confirm", label = "Confirm", variant = "danger", enabled = true },
			phone,
			1,
			actions,
			function()
				ui.onConfirm(r.id)
			end
		)
		actionButton(
			{ id = "cancel", label = "Cancel", variant = "secondary", enabled = true },
			phone,
			2,
			actions,
			function()
				ui.onCancel()
			end
		)
		return frame
	end
	local reason: string? = nil
	for i, action in r.actions do
		actionButton(action, phone, i, actions, function()
			ui.onAction(r.id, action.id)
		end, #r.actions == 1)
		if not action.enabled and action.reason and reason == nil then
			reason = action.reason
		end
	end
	if reason then
		-- Its own line under the buttons: beside them it was cut off on phones.
		line(frame, "Reason", reason, 5, "textSecondary", false)
	end
	return frame
end

function RivalsList.build(parent: Instance, view: any, phone: boolean, ui: any): ScrollingFrame
	local scroll = Create("ScrollingFrame", {
		Name = "Rivals",
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
	if #view.rows == 0 then
		Style.text({
			text = "No rival kingdoms",
			size = 12,
			color = Theme.color("textMuted"),
			extra = { Name = "Empty", Size = UDim2.new(1, 0, 0, 20), Parent = scroll },
		})
	end
	for i, r in view.rows do
		row(r, phone, ui, i, view.senior).Parent = scroll
	end
	return scroll
end

function RivalsList.paint(body: Instance, view: any, phone: boolean?)
	for _, r in view.rows do
		local frame = body:FindFirstChild("Rival_" .. r.id)
		if frame then
			local score_ = frame:FindFirstChild("Head") and frame.Head:FindFirstChild("Score")
			if score_ then
				score_.Text = score(r, phone)
			end
			local note = frame:FindFirstChild("Note")
			if note and r.note then
				note.Text = r.note
			end
			local reasonLabel = frame:FindFirstChild("Reason")
			if reasonLabel then
				for _, action in r.actions do
					if not action.enabled and action.reason then
						reasonLabel.Text = action.reason
						break
					end
				end
			end
		end
	end
end

return table.freeze(RivalsList)
