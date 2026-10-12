--!strict
--[[
	UI/Icon — icons by name (UITheme.icons). Uses the uploaded image when the theme has an asset id,
	otherwise the glyph fallback in a TextLabel, so screens never show a broken image.

		Icon.new(name, size, { color: Color3? }?) -> GuiObject     square, centred
		Icon.medallion(name, size, color) -> Frame                 round tinted badge holding the icon
		Icon.tile(name, size, category) -> Frame                   rounded category tile (buildings)
		Icon.hasImage(name) -> boolean
]]

local Create = require("./Create")
local Style = require("./Style")
local Theme = require("./Theme")

local Icon = {}

function Icon.hasImage(name: string): boolean
	local icon = Theme.icon(name)
	return icon.image ~= nil and icon.image ~= ""
end

function Icon.new(name: string, size: number, opts: { color: Color3? }?): GuiObject
	local icon = Theme.icon(name)
	if icon.image ~= "" then
		return Create("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = icon.image,
			ImageColor3 = if opts and opts.color then opts.color else Color3.new(1, 1, 1),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(size, size),
		})
	end
	return Create("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Text = icon.glyph,
		TextSize = math.floor(size * 0.78),
		FontFace = Theme.font("body", Enum.FontWeight.Bold),
		TextColor3 = if opts and opts.color then opts.color else Theme.color("textPrimary"),
		Size = UDim2.fromOffset(size, size),
	})
end

local function darken(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

function Icon.medallion(name: string, size: number, color: Color3): Frame
	local inner = Icon.new(name, math.floor(size * 0.78))
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	return Create("Frame", {
		Name = "Medallion",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	}, {
		Style.corner(size),
		Style.stroke(Theme.color("ink950"), 1.5),
		Style.gradient(color, darken(color, 0.6)),
		inner,
	})
end

function Icon.tile(name: string, size: number, category: string): Frame
	local top, bottom = Theme.category(category)
	local inner = Icon.new(name, size - 8)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	return Create("Frame", {
		Name = "Tile",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	}, {
		Style.corner(9),
		Style.stroke(Theme.color("ink950"), 1.5),
		Style.gradient(top, bottom),
		inner,
	})
end

return table.freeze(Icon)
