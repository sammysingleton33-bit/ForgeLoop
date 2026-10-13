--!strict
--[[
	UI/Crest — a kingdom's crest: a rounded shield tile in the kingdom colour with its emblem
	(HudModel.EMBLEMS) and a gold trim. Used by the HUD badge, the Kingdom panel and the standings.

		Crest.new(size, color: Color3, emblem: string) -> Frame   (Name "Crest")
		Crest.recolor(crest, color)                               after Kingdom.State changes
		Crest.backdrop(color) -> Color3          what the emblem sits on: the tile, or on a light tile
		                                         (gold #EBB910, D-033) an ivory roundel "Plate" with a
		                                         bronze rim, as FORGE-02's world banners do
		Crest.emblemColor(color) -> Color3       light on dark tiles, dark (bronze) on the ivory plate
		Crest.contrast(a, b) -> number           WCAG contrast ratio of two colours (1..21)
	The sun (gold's emblem) is drawn, not typed: a dark-gold sunburst (eight tapered rays and an
	ochre disc) matching FORGE-02's world design, because the ☀ glyph may render as a colour emoji
	that ignores text colour and vanished on gold (FORGE-05 on #79). An uploaded emblem image
	(UITheme icons) replaces it. Every emblem keeps at least 3:1 against what it sits on, for every
	kingdom colour (WCAG 1.4.11, graphics); the name beside a crest carries the identity too (D-033:
	never colour alone).
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local Crest = {}

-- Relative luminance (sRGB, WCAG 2).
local function luminance(c: Color3): number
	local function linear(v: number): number
		return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * linear(c.R) + 0.7152 * linear(c.G) + 0.0722 * linear(c.B)
end

function Crest.contrast(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- Light tiles (gold) put the emblem on an ivory roundel; the canonical crimson, azure and emerald
-- are dark (luminance < 0.2) and need none.
Crest.LIGHT = 0.3
Crest.PLATE = 0.82 -- the roundel's diameter, as a share of the crest

function Crest.isLight(color: Color3): boolean
	return luminance(color) > Crest.LIGHT
end

function Crest.backdrop(color: Color3): Color3
	return if Crest.isLight(color) then Theme.color("parchment100") else color
end

function Crest.emblemColor(color: Color3): Color3
	return if Crest.isLight(color) then Theme.color("gold700") else Theme.color("textPrimary")
end

local function setPlate(crest: Instance, color: Color3)
	local plate = crest:FindFirstChild("Plate")
	if Crest.isLight(color) and plate == nil then
		Create("Frame", {
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(Crest.PLATE, Crest.PLATE),
			BackgroundColor3 = Theme.color("parchment100"),
			ZIndex = 1,
			Parent = crest,
		}, {
			Corner = Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Rim = Style.stroke(Theme.color("gold700"), 1.5),
		})
	elseif not Crest.isLight(color) and plate then
		plate:Destroy()
	end
	local emblem = crest:FindFirstChild("Emblem")
	if emblem and emblem:IsA("TextLabel") then
		emblem.TextColor3 = Crest.emblemColor(color)
	end
end

-- Gold's sun, drawn: four bars through the centre (eight rays) tapering to their tips, under an
-- ochre disc. Dark gold, so it reads on the ivory roundel and on any light field.
function Crest.sunburst(size: number): Frame
	local sun = Create("Frame", {
		Name = "Emblem",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 2,
	})
	sun:SetAttribute("drawn", "sunburst")
	-- solid along the ray, fading only over its last few percent: a point, not a blur
	local taper = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.06, 0.15),
		NumberSequenceKeypoint.new(0.14, 0),
		NumberSequenceKeypoint.new(0.86, 0),
		NumberSequenceKeypoint.new(0.94, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	for i = 0, 3 do
		Create("Frame", {
			Name = "Ray_" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1.04, 0.15),
			Rotation = i * 45,
			BackgroundColor3 = Theme.color("gold700"),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = sun,
		}, { Taper = Create("UIGradient", { Transparency = taper }) })
	end
	Create("Frame", {
		Name = "Disc",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.46, 0.46),
		BackgroundColor3 = Theme.color("gold600"),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = sun,
	}, {
		Corner = Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		Edge = Style.stroke(Theme.color("gold700"), 1),
	})
	return sun
end

local function gradient(color: Color3): ColorSequence
	return ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.3))
end

function Crest.new(size: number, color: Color3, emblem: string): Frame
	local icon: GuiObject
	if emblem == "emblem_sun" and not Icon.hasImage(emblem) then
		icon = Crest.sunburst(math.floor(size * 0.66))
	else
		icon = Icon.new(emblem, math.floor(size * 0.66))
		icon.Name = "Emblem"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.ZIndex = 2
	end
	local crest = Create("Frame", {
		Name = "Crest",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	}, {
		Corner = Style.corner(if size >= 40 then 12 else 6),
		Stroke = Style.stroke(Theme.color("gold500"), if size >= 40 then 2 else 1.5),
		Gradient = Create("UIGradient", { Rotation = 90, Color = gradient(color) }),
		Emblem = icon,
	})
	setPlate(crest, color)
	return crest
end

function Crest.recolor(crest: Instance, color: Color3)
	local g = crest:FindFirstChild("Gradient")
	if g and g:IsA("UIGradient") then
		g.Color = gradient(color)
	end
	setPlate(crest, color)
end

return table.freeze(Crest)
