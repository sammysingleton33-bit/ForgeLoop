--!strict
--[[
	Toast — a transient notification card. FORGE-04's NotificationController:show builds on this
	component (interfaces §8); FORGE-03 screens call NotificationController when it exists and fall
	back to UI/ToastStack otherwise.

	Props
		kind: "info" | "success" | "warning" | "error" | "reward" | "achievement"   accent (default "info")
		title: string              body: string?
		icon: string?              default per kind (info, check, warning, cross, chest, laurel)
		count: number?             repeat badge ("×3") for stacked identical toasts (shown when > 1)
		width: number?             px (default 300)
		layoutOrder: number?
	Toast.new(props) -> handle { instance: Frame, destroy() }
	Toast.ACCENT[kind] -> colour name       Toast.ICON[kind] -> default icon name
]]

local Create = require("../Create")
local Icon = require("../Icon")
local Style = require("../Style")
local Theme = require("../Theme")

local Toast = {}
Toast.__index = Toast

-- achievement is purpure, not a second gold, so it never reads as a reward (FL-0105; #33 L2)
Toast.ACCENT = table.freeze({
	info = "azure",
	success = "vert",
	warning = "amber",
	error = "gules",
	reward = "gold400",
	achievement = "purpure",
})
Toast.ICON = table.freeze({
	info = "info",
	success = "check",
	warning = "warning",
	error = "cross",
	reward = "chest",
	achievement = "laurel",
})

function Toast.new(props: { [string]: any })
	local self = setmetatable({}, Toast)
	local kind = props.kind or "info"
	local accent = Theme.color(Toast.ACCENT[kind] or "azure")
	local textChildren: { [any]: any } = {
		Padding = Style.padding(8, 0, 8, 0),
		List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Title = Style.text({
			text = props.title,
			weight = Enum.FontWeight.ExtraBold,
			size = 13,
			wrap = true,
			extra = { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 1 },
		}),
	}
	if props.body then
		textChildren.Body = Style.text({
			text = props.body,
			weight = Enum.FontWeight.Medium,
			size = 11,
			color = Theme.color("textSecondary"),
			wrap = true,
			extra = { AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), LayoutOrder = 2 },
		})
	end
	local icon = Icon.new(props.icon or Toast.ICON[kind] or "info", 28)
	icon.Position = UDim2.new(0, 14, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	self.instance = Create("Frame", {
		Name = "Toast",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(props.width or 300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.layoutOrder or 0,
		ClipsDescendants = true,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("gold700"), 1.5),
		Gradient = Style.gradient(Theme.color("ink700"), Theme.color("ink900")),
		Accent = Create("Frame", {
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 5, 1, 0),
		}),
		Icon = icon,
		Text = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -64, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, textChildren),
	})
	if props.count and props.count > 1 then
		Create("TextLabel", {
			Name = "Count",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = accent,
			Text = `×{props.count}`,
			TextSize = 11,
			FontFace = Theme.font("body", Enum.FontWeight.ExtraBold),
			TextColor3 = Theme.color("inkText"),
			ZIndex = 3,
			Parent = self.instance,
		}, { Corner = Style.corner(999), Padding = Style.padding(0, 6) })
	end
	self.instance:SetAttribute("kind", kind)
	return self
end

function Toast:destroy()
	self.instance:Destroy()
end

return Toast
