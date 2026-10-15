--!strict
--[[
	UI/FacingDial — a small round dial whose arrow shows which way a building will face on screen
	(FL-0059 rotation feedback; the user's first Studio feedback, 2026-10-13). The arrow points where
	the building's front (its door, Kit -Z) will look from the current camera: up = away from the
	camera, down = towards it (Placement.screenAngle).

		FacingDial.new(size: number, layoutOrder: number?) -> Frame "Facing" with an "Arrow" TextLabel
		FacingDial.set(dial: Frame, degrees: number)   turns the arrow; attribute `facing` (degrees, 0-360)
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local FacingDial = {}

FacingDial.ARROW = "▲"

function FacingDial.new(size: number, layoutOrder: number?): Frame
	local dial = Create("Frame", {
		Name = "Facing",
		BackgroundColor3 = Theme.color("parchment100"),
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = layoutOrder or 0,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		Arrow = Style.text({
			text = FacingDial.ARROW,
			weight = Enum.FontWeight.Heavy,
			size = math.floor(size * 0.55),
			color = Theme.color("inkText"),
			xAlign = "Center",
			extra = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
			},
		}),
	}) :: Frame
	FacingDial.set(dial, 0)
	return dial
end

function FacingDial.set(dial: Instance, degrees: number)
	local arrow = dial:FindFirstChild("Arrow") :: TextLabel?
	if arrow then
		arrow.Rotation = degrees
	end
	dial:SetAttribute("facing", degrees)
end

return table.freeze(FacingDial)
