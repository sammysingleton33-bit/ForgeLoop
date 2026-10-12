--!strict
--[[
	Button — the main call-to-action (FL-0020 kit).

	Props
		text: string                 label
		icon: string?                icon name (UITheme.icons) left of the label
		variant: "primary" | "secondary" | "danger" | "success"   (default "primary")
		state: "default" | "disabled" | "loading"                 (default "default")
		size: "regular" | "small"    44 px (touch target) or 32 px tall (default "regular")
		width: number?               fixed width in px; nil = fill the parent's width
		layoutOrder: number?
		onActivated: (() -> ())?     not called while disabled or loading
	States: pressed (2 px down while held), disabled (muted, no shadow), loading (hourglass +
	label, blocks repeat taps). Variant "success" doubles as the "done" confirmation state.

	Button.new(props) -> handle { instance: Frame, face: TextButton, update(partial), destroy() }
]]

local Create = require("../Create")
local Icon = require("../Icon")
local Style = require("../Style")
local Theme = require("../Theme")

local Button = {}
Button.__index = Button

local function seq(a: string, b: string, c: string): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.hex(a)),
		ColorSequenceKeypoint.new(0.52, Theme.hex(b)),
		ColorSequenceKeypoint.new(1, Theme.hex(c)),
	})
end

local function variantStyle(variant: string, disabled: boolean)
	local c = Theme.raw.colors
	if disabled then
		return seq(c.ink700, c.ink700, c.ink800), Theme.color("textMuted"), Theme.color("ink500")
	elseif variant == "secondary" then
		return seq(c.ink600, c.ink700, c.ink800), Theme.color("parchment100"), Theme.color("gold600")
	elseif variant == "danger" then
		return seq("#E8735C", c.gules, "#A8402D"), Theme.color("parchment100"), Theme.hex("#6B2216")
	elseif variant == "success" then
		return seq("#78C57B", c.vert, "#3F8546"), Theme.color("parchment100"), Theme.hex("#24502A")
	end
	return seq("#F6DA86", c.gold500, "#B88A34"), Theme.color("inkText"), Theme.hex("#6E4F18")
end

function Button.new(props: { [string]: any })
	local self = setmetatable({ _props = {}, _pressed = false }, Button)
	local height = if props.size == "small" then 32 else 44
	self._height = height
	self.instance = Create("Frame", {
		Name = "Button",
		BackgroundTransparency = 1,
		Size = if props.width then UDim2.fromOffset(props.width, height) else UDim2.new(1, 0, 0, height),
		LayoutOrder = props.layoutOrder or 0,
	})
	self._shadow = Create("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 3),
		ZIndex = 1,
		Parent = self.instance,
	}, { Style.corner(if height < 40 then 8 else 10) })
	self._gradient = Style.gradient(Color3.new(), Color3.new())
	self._stroke = Style.stroke(Color3.new(), 1.5)
	self._content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, { Style.list("x", 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	self.face = Create("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		[Create.Event.Activated] = function()
			local p = self._props
			if p.state ~= "disabled" and p.state ~= "loading" and p.onActivated then
				p.onActivated()
			end
		end,
		[Create.Event.MouseButton1Down] = function()
			self:_setPressed(true)
		end,
		[Create.Event.MouseButton1Up] = function()
			self:_setPressed(false)
		end,
		[Create.Event.MouseLeave] = function()
			self:_setPressed(false)
		end,
		Parent = self.instance,
	}, { Style.corner(if height < 40 then 8 else 10), self._stroke, self._gradient, self._content })
	self:update(props)
	return self
end

function Button:_setPressed(pressed: boolean)
	local p = self._props
	if p.state == "disabled" or p.state == "loading" then
		pressed = false
	end
	self._pressed = pressed
	self.face.Position = UDim2.fromOffset(0, if pressed then 2 else 0)
	self._shadow.Position = UDim2.fromOffset(0, if pressed then 1 else 3)
end

function Button:update(partial: { [string]: any })
	for key, value in partial do
		self._props[key] = value
	end
	local p = self._props
	local disabled = p.state == "disabled"
	local colors, textColor, strokeColor = variantStyle(p.variant or "primary", disabled)
	self._gradient.Color = colors
	self._stroke.Color = strokeColor
	self._shadow.Visible = not disabled
	self.face.Active = not disabled and p.state ~= "loading"
	self.face:SetAttribute("state", p.state or "default")
	Create.clear(self._content)
	self._content.Parent = nil
	local small = self._height < 40
	local iconName = if p.state == "loading" then "timer" else p.icon
	if iconName then
		local icon = Icon.new(iconName, if small then 16 else 22, { color = textColor })
		icon.LayoutOrder = 1
		icon.Parent = self._content
	end
	Style.list("x", if small then 6 else 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center).Parent =
		self._content
	local label = Style.text({
		text = p.text or "",
		weight = Enum.FontWeight.ExtraBold,
		size = if small then 12 else 15,
		color = textColor,
		xAlign = "Center",
		extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, Name = "Label" },
	})
	label.Parent = self._content
	self._content.Parent = self.face
	self:_setPressed(self._pressed)
end

function Button:text(): string
	local label = self._content:FindFirstChild("Label")
	return if label then label.Text else ""
end

function Button:destroy()
	self.instance:Destroy()
end

return Button
