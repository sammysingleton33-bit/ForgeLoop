--!strict
--[[
	ProgressBar — construction progress, storage fill, timers.

	Props
		progress: number           0..1 (clamped)
		label: string?             centred text over the bar (e.g. "0:07", "136 / 500")
		color: Color3?             fill colour (default gold gradient)
		height: number?            px (default 10; 16 when a label is shown)
		width: UDim?               default full width
		layoutOrder: number?
	ProgressBar.new(props) -> handle { instance: Frame, update(partial), destroy() }
]]

local Create = require("../Create")
local Style = require("../Style")
local Theme = require("../Theme")

local ProgressBar = {}
ProgressBar.__index = ProgressBar

function ProgressBar.new(props: { [string]: any })
	local self = setmetatable({ _props = {} }, ProgressBar)
	self._fillGradient = Style.gradient(Theme.hex("#F6DA86"), Theme.color("gold500"))
	self._fill = Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, { Style.corner(999), self._fillGradient })
	self._label = Style.text({
		text = "",
		weight = Enum.FontWeight.ExtraBold,
		size = 10,
		color = Theme.color("parchment100"),
		xAlign = "Center",
		extra = { Name = "Label", Size = UDim2.fromScale(1, 1), ZIndex = 3 },
	})
	Create("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Theme.color("ink950"),
		Thickness = 1,
		Parent = self._label,
	})
	self.instance = Create(
		"Frame",
		{
			Name = "ProgressBar",
			BackgroundColor3 = Theme.color("scrim"),
			BackgroundTransparency = 0.25,
			ClipsDescendants = true,
		},
		{
			Corner = Style.corner(999),
			Stroke = Style.stroke(Theme.color("ink500"), 1),
			Fill = self._fill,
			Label = self._label,
		}
	)
	self:update(props)
	return self
end

function ProgressBar:update(partial: { [string]: any })
	for key, value in partial do
		self._props[key] = value
	end
	local p = self._props
	local progress = math.clamp(p.progress or 0, 0, 1)
	local height = p.height or (if p.label then 16 else 10)
	self.instance.Size = UDim2.new(p.width or UDim.new(1, 0), UDim.new(0, height))
	self.instance.LayoutOrder = p.layoutOrder or 0
	self._fill.Size = UDim2.fromScale(progress, 1)
	self._fill.Visible = progress > 0
	if p.color then
		self._fillGradient.Color = ColorSequence.new(p.color, p.color)
	else
		self._fillGradient.Color = ColorSequence.new(Theme.hex("#F6DA86"), Theme.color("gold500"))
	end
	self._label.Text = p.label or ""
	self._label.Visible = p.label ~= nil
	self.instance:SetAttribute("progress", progress)
end

function ProgressBar:destroy()
	self.instance:Destroy()
end

return ProgressBar
