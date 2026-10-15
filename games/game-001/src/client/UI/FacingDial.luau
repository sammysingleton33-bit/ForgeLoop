--!strict
--[[
	UI/FacingDial — a small round dial whose arrow shows which way a building will face on screen
	(FL-0059 rotation feedback; the user's first Studio feedback, 2026-10-13). The arrow points where
	the building's front (its door, Kit -Z) will look from the current camera: up = away from the
	camera, down = towards it (Placement.screenAngle).

		FacingDial.new(size: number, layoutOrder: number?) -> Frame "Facing" with an "Arrow" Frame (Shaft,
	                                                         HeadLeft, HeadRight) that turns
		FacingDial.set(dial: Frame, degrees: number)   turns the arrow; attribute `facing` (degrees, 0-360)
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local FacingDial = {}

-- The arrow is drawn with frames (a shaft and two head strokes), not a glyph: it centres exactly at any
-- angle, needs no font, and the snapshot renderer rotates frames faithfully (README deviation 25).
function FacingDial.new(size: number, layoutOrder: number?): Frame
	local ink = Theme.color("inkText")
	local stroke = math.max(2, math.floor(size * 0.1 + 0.5))
	local head = math.floor(size * 0.3 + 0.5)
	local top = math.floor(size * 0.2 + 0.5) -- the tip, from the dial's top edge
	local function bar(name: string, length: number, cframeFn: (Frame) -> ()): Frame
		local f = Create("Frame", {
			Name = name,
			BorderSizePixel = 0,
			BackgroundColor3 = ink,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(stroke, length),
		}) :: Frame
		cframeFn(f)
		return f
	end
	local half = size / 2
	local function at(x: number, y: number): UDim2
		return UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	end
	local arrow = Create("Frame", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Shaft = bar("Shaft", math.floor(size - 2 * top + 0.5), function(f)
			f.Position = at(half, top)
		end),
		-- the head strokes hang from the tip, 40° either side of the shaft
		HeadLeft = bar("HeadLeft", head, function(f)
			f.AnchorPoint = Vector2.new(0.5, 0)
			f.Position = at(half - math.sin(math.rad(40)) * head / 2, top + math.cos(math.rad(40)) * head / 2 - head / 2)
			f.Rotation = 40
		end),
		HeadRight = bar("HeadRight", head, function(f)
			f.AnchorPoint = Vector2.new(0.5, 0)
			f.Position = at(half + math.sin(math.rad(40)) * head / 2, top + math.cos(math.rad(40)) * head / 2 - head / 2)
			f.Rotation = -40
		end),
	})
	local dial = Create("Frame", {
		Name = "Facing",
		BackgroundColor3 = Theme.color("parchment100"),
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = layoutOrder or 0,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		Arrow = arrow,
	}) :: Frame
	FacingDial.set(dial, 0)
	return dial
end

function FacingDial.set(dial: Instance, degrees: number)
	local arrow = dial:FindFirstChild("Arrow") :: Frame?
	if arrow then
		arrow.Rotation = degrees
	end
	dial:SetAttribute("facing", degrees)
end

return table.freeze(FacingDial)
