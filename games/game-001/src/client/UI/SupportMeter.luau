--!strict
--[[
	UI/SupportMeter — the HUD support chip (FL-0073; design crown-arena.md §8); the model is UI/SupportMeterModel. One
	tappable chip at Layout `metrics.hud.support` (under the reputation strip): a coloured tier dot, "Support" (not on
	phones), the tier name, the score and the trend arrow ("Adoring 91 ▲"). The tier is always text as well as colour.
	A tap opens the breakdown (ui.onOpen). Attributes: tier, score, trend ("up" | "down" | "steady").

	SupportMeter.new(parent) -> view
	view:render(model, metrics, ui: { onOpen, open: boolean })   view:destroy()   view.instance: TextButton "SupportMeter"
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local SupportMeter = {}
SupportMeter.__index = SupportMeter

function SupportMeter.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: GuiObject? }, SupportMeter)
end

function SupportMeter:render(model: any, m: any, ui: { [string]: any })
	self:destroy()
	local r = m.hud.support
	if r == nil then
		return
	end
	local phone = m.breakpoint == "phone"
	local button = Create("TextButton", {
		Name = "SupportMeter",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.2,
		Position = UDim2.fromOffset(r.x, r.y),
		Size = UDim2.fromOffset(r.width, r.height),
		[Create.Event.Activated] = function()
			if ui.onOpen then
				ui.onOpen()
			end
		end,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(
			if ui.open then Theme.color("gold400") else model.tier.color,
			if ui.open then 2 else 1,
			0.2
		),
		Padding = Style.padding(0, 10, 0, 8),
		List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Dot = Create("Frame", {
			Name = "Dot",
			BackgroundColor3 = model.tier.color,
			Size = UDim2.fromOffset(10, 10),
			LayoutOrder = 1,
		}, { Corner = Style.corner(999) }),
		Kicker = (not phone) and Style.text({
			text = "Support",
			size = 11,
			color = Theme.color("textSecondary"),
			weight = Enum.FontWeight.SemiBold,
			extra = {
				Name = "Kicker",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 2,
			},
		}),
		Label = Style.text({
			text = `{model.tier.name} {model.score}`,
			size = if phone then 12 else 13,
			color = Theme.color("textPrimary"),
			weight = Enum.FontWeight.Bold,
			extra = {
				Name = "Label",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 3,
			},
		}),
		Trend = Style.text({
			text = model.trend.arrow,
			size = if phone then 11 else 12,
			color = model.trend.color,
			weight = Enum.FontWeight.ExtraBold,
			extra = {
				Name = "Trend",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 4,
			},
		}),
	}) :: GuiObject
	button:SetAttribute("tier", model.tier.id)
	button:SetAttribute("score", model.score)
	button:SetAttribute(
		"trend",
		if model.trend.arrow == "▲" then "up" elseif model.trend.arrow == "▼" then "down" else "steady"
	)
	button:SetAttribute("OnboardingTarget", "HUD.Support")
	self.instance = button
	button.Parent = self._parent
end

function SupportMeter:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
end

return SupportMeter
