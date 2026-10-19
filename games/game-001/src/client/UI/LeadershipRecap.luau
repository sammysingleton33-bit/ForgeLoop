--!strict
--[[
	UI/LeadershipRecap — "Your reign", the leadership recap opened from the Results summary (FL-0129,
	BRIEF §2); the model is UI/RecapModel. On the modal layer, over the summary:
		Values      the six reputation values, start → end with the change ("Value_<id>", attributes
		            start, finish)
		Decisions   "Key decisions": the RecapModel.DECISIONS history lines with the biggest effect, each
		            with its value and change ("Decision_<i>"); "No decisions recorded" without any
		Citizens    "Citizens 12 → 18" and "6 more citizens than at the start" ("Citizens")
		Back        back to the results ("Back")
	Desktop/tablet: one column, 520 wide. Phones (667 × 375): two columns (values left, decisions and
	citizens right) in min(640, width - 16) × 330.

	LeadershipRecap.new(parent) -> view
	view:render(recap, metrics, ui: { onBack })   view:destroy()   view.instance: Frame "LeadershipRecap"
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local LeadershipRecap = {}
LeadershipRecap.__index = LeadershipRecap

LeadershipRecap.WIDTH = 520
-- phones: the Results summary's own box (UI/SliceSummary.PHONE), clear of the Roblox top bar
LeadershipRecap.PHONE = table.freeze({ width = 600, height = 262, row = 22 })
LeadershipRecap.ROW = 26

function LeadershipRecap.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame? }, LeadershipRecap)
end

local function heading(text: string, order: number): Instance
	return Style.text({
		text = text,
		size = 13,
		weight = Enum.FontWeight.Bold,
		color = Theme.color("gold300"),
		extra = { Name = "Heading", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = order },
	})
end

local function deltaColor(delta: number): Color3
	if delta > 0.5 then
		return Theme.color("vert")
	elseif delta < -0.5 then
		return Theme.color("gules")
	end
	return Theme.color("textMuted")
end

local function valueRow(v: any, order: number, height: number): Frame
	local row = Create("Frame", {
		Name = "Value_" .. v.id,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
	}, {
		Label = Style.text({
			text = v.name,
			size = 13,
			weight = Enum.FontWeight.SemiBold,
			color = Theme.color("textPrimary"),
			extra = { Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -150, 1, 0) },
		}),
		Values = Style.text({
			text = `{v.start} → {v.finish}`,
			size = 13,
			weight = Enum.FontWeight.SemiBold,
			color = Theme.color("textSecondary"),
			xAlign = "Right",
			extra = {
				Name = "Values",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -48, 0, 0),
				Size = UDim2.new(0, 80, 1, 0),
			},
		}),
		Delta = Style.text({
			text = v.deltaText,
			size = 13,
			weight = Enum.FontWeight.Bold,
			color = deltaColor(v.delta),
			xAlign = "Right",
			extra = {
				Name = "Delta",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 44, 1, 0),
			},
		}),
	}) :: Frame
	row:SetAttribute("start", v.start)
	row:SetAttribute("finish", v.finish)
	local icon = Icon.new(v.icon, 18)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)
	icon.Parent = row
	return row
end

local function decisionRow(d: any, index: number, order: number): Frame
	local row = Create("Frame", {
		Name = "Decision_" .. index,
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = 0.5,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, {
		Corner = Style.corner(8),
		Padding = Style.padding(6, 8),
		List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
		Text = Style.text({
			text = d.text,
			size = 12,
			weight = Enum.FontWeight.SemiBold,
			color = Theme.color("textPrimary"),
			wrap = true,
			extra = {
				Name = "Text",
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
			},
		}),
		Effect = Style.text({
			text = `{d.name} {d.deltaText}`,
			size = 11,
			weight = Enum.FontWeight.Bold,
			color = deltaColor(d.delta),
			extra = { Name = "Effect", Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
		}),
	}) :: Frame
	return row
end

local function column(name: string, props: { [string]: any }): Frame
	props.Name = name
	props.BackgroundTransparency = 1
	return Create("Frame", props, {
		List = Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	}) :: Frame
end

function LeadershipRecap:render(recap: any, metrics: any, ui: { [string]: any })
	self:destroy()
	local phone = metrics.breakpoint == "phone"
	local width = if phone then math.min(LeadershipRecap.PHONE.width, metrics.width - 16) else LeadershipRecap.WIDTH
	local nDecisions = math.max(1, #recap.decisions)
	local height = if phone
		then math.min(LeadershipRecap.PHONE.height, metrics.height - 16)
		-- title 56, heading 24, values, heading 24, decisions (~52 each), citizens 44, Back 44, pads
		else 56 + 24 + #recap.values * (LeadershipRecap.ROW + 6) + 24 + nDecisions * 52 + 44 + 12 + 44 + 24
	local panel = Panel.new({
		title = if phone then nil else "Your reign",
		size = UDim2.fromOffset(width, height),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		padding = if phone then 12 else 16,
		compact = phone,
		zIndex = 3,
	})
	local content = panel.content
	local back = Button.new({
		text = "Back to results",
		variant = "secondary",
		size = if phone then "small" else "regular",
		onActivated = function()
			if ui.onBack then
				ui.onBack()
			end
		end,
	})
	back.instance.Name = "Back"
	back.instance.AnchorPoint = Vector2.new(0, 1)
	back.instance.Position = UDim2.fromScale(0, 1)
	local left, right
	if phone then
		left = column("Left", { Size = UDim2.new(0.5, -8, 1, 0), Parent = content })
		right =
			column("Right", { Position = UDim2.new(0.5, 8, 0, 0), Size = UDim2.new(0.5, -8, 1, 0), Parent = content })
		Style.text({
			text = "Your reign · start → end",
			size = 15,
			weight = Enum.FontWeight.Bold,
			color = Theme.color("textPrimary"),
			extra = { Name = "Title", Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0, Parent = left },
		})
		back.instance.Size = UDim2.new(0.5, -8, 0, 32)
	else
		left = column("Body", { Size = UDim2.new(1, 0, 1, -56), Parent = content })
		right = left
		back.instance.Size = UDim2.new(1, 0, 0, 44)
	end
	if not phone then
		heading("Reputation, start → end", 1).Parent = left
	end
	for i, v in recap.values do
		valueRow(v, 1 + i, if phone then LeadershipRecap.PHONE.row else LeadershipRecap.ROW).Parent = left
	end
	heading("Key decisions", 20).Parent = right
	if #recap.decisions == 0 then
		Style.text({
			text = "No decisions recorded",
			size = 12,
			color = Theme.color("textMuted"),
			extra = { Name = "NoDecisions", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 21, Parent = right },
		})
	end
	for i, d in recap.decisions do
		decisionRow(d, i, 20 + i).Parent = right
	end
	if recap.citizens then
		local c = recap.citizens
		local block = Create("Frame", {
			Name = "Citizens",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 40,
			Parent = right,
		}, { List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
		block:SetAttribute("change", c.change)
		Style.text({
			text = `Citizens {c.start} → {c.finish}`,
			size = 13,
			weight = Enum.FontWeight.Bold,
			color = Theme.color("gold300"),
			extra = { Name = "Count", Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = block },
		})
		Style.text({
			text = c.text,
			size = 12,
			weight = Enum.FontWeight.SemiBold,
			color = deltaColor(c.change),
			extra = { Name = "Change", Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 2, Parent = block },
		})
	end
	back.instance.Parent = content
	self.back = back
	self.instance = Create("Frame", {
		Name = "LeadershipRecap",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, {
		Scrim = Create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.color("scrim"),
			BackgroundTransparency = 0.3,
			Size = UDim2.fromScale(1, 1),
		}),
		Panel = panel.instance,
	}) :: Frame
	self.instance.Parent = self._parent
end

function LeadershipRecap:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self.back = nil
end

return LeadershipRecap
