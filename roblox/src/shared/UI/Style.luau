--!strict
--[[
	UI/Style — small builders for the decorations every component repeats, so the look stays
	consistent: rounded corners, gold trim strokes, two-stop gradients, padding, list layouts and
	themed text. Each returns an instance (unparented) for Create children lists.

		Style.corner(px)                          UICorner
		Style.stroke(color, thickness?, transparency?)  UIStroke (border)
		Style.gradient(top, bottom, transparency?)      UIGradient, vertical
		Style.padding(top, right?, bottom?, left?)      UIPadding (CSS order)
		Style.list(direction, gap, hAlign?, vAlign?)    UIListLayout sorted by LayoutOrder
		Style.text(props)                         TextLabel: { text, role = "body", weight, size,
		                                          color, xAlign = "Left", yAlign = "Center", wrap,
		                                          + any TextLabel property in `props.extra` }
		Style.shadow(radius, offset?)             a hard offset shadow frame (no blur in Roblox)
		Style.inset(radius)                       the inner faint gold rule of a panel (3 px in)
		Style.surface(top, bottom, radius, trim?) children for a panel-like surface
]]

local Create = require("./Create")
local Theme = require("./Theme")

local Style = {}

function Style.corner(px: number): Instance
	return Create("UICorner", { CornerRadius = UDim.new(0, px) })
end

function Style.stroke(color: Color3, thickness: number?, transparency: number?): Instance
	return Create("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Style.gradient(top: Color3, bottom: Color3, transparency: NumberSequence?): Instance
	return Create("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Transparency = transparency or NumberSequence.new(0),
	})
end

function Style.padding(top: number, right: number?, bottom: number?, left: number?): Instance
	local r = right or top
	return Create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, r),
		PaddingBottom = UDim.new(0, bottom or top),
		PaddingLeft = UDim.new(0, left or r),
	})
end

function Style.list(direction: "x" | "y", gap: number, hAlign: any?, vAlign: any?): Instance
	return Create("UIListLayout", {
		FillDirection = if direction == "x" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Center,
	})
end

export type TextProps = {
	text: string,
	role: string?,
	weight: any?,
	size: number?,
	color: Color3?,
	xAlign: string?,
	yAlign: string?,
	wrap: boolean?,
	extra: { [string]: any }?,
}

function Style.text(p: TextProps): Instance
	local props: { [any]: any } = {
		BackgroundTransparency = 1,
		Text = p.text,
		FontFace = Theme.font(p.role or "body", p.weight or Enum.FontWeight.SemiBold),
		TextSize = p.size or Theme.textSize("body"),
		TextColor3 = p.color or Theme.color("textPrimary"),
		TextXAlignment = (Enum.TextXAlignment :: any)[p.xAlign or "Left"],
		TextYAlignment = (Enum.TextYAlignment :: any)[p.yAlign or "Center"],
		TextWrapped = p.wrap == true,
		TextTruncate = if p.wrap then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd,
		RichText = false,
	}
	for key, value in p.extra or {} do
		props[key] = value
	end
	return Create("TextLabel", props)
end

function Style.shadow(radius: number, offset: number?): Instance
	return Create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, offset or 4),
		ZIndex = 0,
	}, { Style.corner(radius) })
end

function Style.inset(radius: number): Instance
	return Create("Frame", {
		Name = "Inset",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -6, 1, -6),
		Position = UDim2.fromOffset(3, 3),
		ZIndex = 1,
	}, { Style.corner(math.max(0, radius - 3)), Style.stroke(Theme.color("gold500"), 1, 0.8) })
end

return table.freeze(Style)
