--!strict
--[[
	UI/Crest — a kingdom's crest: a rounded shield tile in the kingdom colour with its emblem
	(HudModel.EMBLEMS) and a gold trim. Used by the HUD badge, the Kingdom panel and the standings.

		Crest.new(size, color: Color3, emblem: string) -> Frame   (Name "Crest")
		Crest.recolor(crest, color)                               after Kingdom.State changes
		Crest.backdrop(color) -> Color3          what the emblem sits on: the tile, or on a light tile
		                                         (gold #EBB910, D-033) a sable disc "Plate" (FORGE-05
		                                         on #79: the sun vanished on gold)
		Crest.contrast(a, b) -> number           WCAG contrast ratio of two colours (1..21)
	The emblem is light (textPrimary; a glyph may also render as a colour emoji, which ignores text
	colour, so the fix is the dark plate, not a dark emblem) and keeps at least 3:1 against its
	backdrop for every kingdom colour (WCAG 1.4.11, graphics). The name beside a crest carries the
	identity too (D-033: never colour alone).
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

-- Light tiles (gold) put the emblem on a dark plate; the canonical crimson, azure and emerald are
-- dark (luminance < 0.2) and need none.
Crest.LIGHT = 0.3
Crest.PLATE = 0.8 -- the plate's diameter, as a share of the crest

function Crest.isLight(color: Color3): boolean
	return luminance(color) > Crest.LIGHT
end

function Crest.backdrop(color: Color3): Color3
	return if Crest.isLight(color) then Theme.tincture("sable") else color
end

local function setPlate(crest: Instance, color: Color3)
	local plate = crest:FindFirstChild("Plate")
	if Crest.isLight(color) and plate == nil then
		Create("Frame", {
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(Crest.PLATE, Crest.PLATE),
			BackgroundColor3 = Theme.tincture("sable"),
			BackgroundTransparency = 0.1,
			ZIndex = 1,
			Parent = crest,
		}, { Corner = Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	elseif not Crest.isLight(color) and plate then
		plate:Destroy()
	end
end

local function gradient(color: Color3): ColorSequence
	return ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.3))
end

function Crest.new(size: number, color: Color3, emblem: string): Frame
	local icon = Icon.new(emblem, math.floor(size * 0.66))
	icon.Name = "Emblem"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ZIndex = 2
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
