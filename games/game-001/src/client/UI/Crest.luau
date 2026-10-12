--!strict
--[[
	UI/Crest — a kingdom's crest: a rounded shield tile in the kingdom colour with its emblem
	(HudModel.EMBLEMS) and a gold trim. Used by the HUD badge, the Kingdom panel and the standings.

		Crest.new(size, color: Color3, emblem: string) -> Frame   (Name "Crest")
		Crest.recolor(crest, color)                               after Kingdom.State changes
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local Crest = {}

local function gradient(color: Color3): ColorSequence
	return ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.3))
end

function Crest.new(size: number, color: Color3, emblem: string): Frame
	local icon = Icon.new(emblem, math.floor(size * 0.66))
	icon.Name = "Emblem"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	return Create("Frame", {
		Name = "Crest",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	}, {
		Corner = Style.corner(if size >= 40 then 12 else 6),
		Stroke = Style.stroke(Theme.color("gold500"), if size >= 40 then 2 else 1.5),
		Gradient = Create("UIGradient", { Rotation = 90, Color = gradient(color) }),
		Emblem = icon,
	})
end

function Crest.recolor(crest: Instance, color: Color3)
	local g = crest:FindFirstChild("Gradient")
	if g and g:IsA("UIGradient") then
		g.Color = gradient(color)
	end
end

return table.freeze(Crest)
