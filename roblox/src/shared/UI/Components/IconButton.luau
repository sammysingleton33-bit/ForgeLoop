--!strict
--[[
	IconButton — square menu button (right-edge rail, close buttons, steppers).

	Props
		icon: string              icon name
		label: string?            caption under the icon (hidden when nil, e.g. on phones)
		size: number?             side in px (default 58; never below Theme.TOUCH = 44 for rail buttons)
		selected: boolean?        gold face (the open menu)
		badge: number?            count bubble (e.g. idle citizens); hidden when nil or 0
		locked: boolean?          shows the lock icon instead and ignores taps
		disabled: boolean?        dimmed, ignores taps
		variant: "rail" | "plain" "plain" = small dark square (close, +/−)  (default "rail")
		layoutOrder: number?
		onActivated: (() -> ())?
	IconButton.new(props) -> handle { instance: TextButton, update(partial), destroy() }
]]

local Create = require("../Create")
local Icon = require("../Icon")
local Style = require("../Style")
local Theme = require("../Theme")

local IconButton = {}
IconButton.__index = IconButton

function IconButton.new(props: { [string]: any })
	local self = setmetatable({ _props = {} }, IconButton)
	self._gradient = Style.gradient(Color3.new(), Color3.new())
	self._stroke = Style.stroke(Color3.new(), 1.5)
	self.instance = Create("TextButton", {
		Name = "IconButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		[Create.Event.Activated] = function()
			local p = self._props
			if not p.locked and not p.disabled and p.onActivated then
				p.onActivated()
			end
		end,
	}, { self._gradient, self._stroke })
	self._corner = Style.corner(14)
	self._corner.Parent = self.instance
	self:update(props)
	return self
end

function IconButton:update(partial: { [string]: any })
	for key, value in partial do
		self._props[key] = value
	end
	local p = self._props
	local plain = p.variant == "plain"
	local size = p.size or (if plain then 36 else 58)
	local inst = self.instance
	inst.Size = UDim2.fromOffset(size, size)
	inst.LayoutOrder = p.layoutOrder or 0
	inst.Active = not p.locked and not p.disabled
	inst:SetAttribute("selected", p.selected == true)
	inst:SetAttribute("disabled", p.disabled == true)
	self._corner.CornerRadius = UDim.new(0, if plain then 10 else 14)
	if p.selected then
		self._gradient.Color = ColorSequence.new(Theme.hex("#F3D27C"), Theme.color("gold600"))
		self._stroke.Color = Theme.color("gold300")
	elseif plain then
		self._gradient.Color = ColorSequence.new(Theme.color("ink900"), Theme.color("ink900"))
		self._stroke.Color = Theme.color("gold700")
	else
		self._gradient.Color = ColorSequence.new(Theme.color("ink600"), Theme.color("ink800"))
		self._stroke.Color = Theme.color("gold700")
	end
	inst.BackgroundTransparency = if p.disabled then 0.55 else 0
	-- Disabled must read as disabled: under the gradient the background alone barely changed.
	if p.disabled then
		self._stroke.Color = Theme.color("ink500")
	end
	for _, child in inst:GetChildren() do
		if child.Name == "Body" or child.Name == "Badge" then
			child:Destroy()
		end
	end
	local body = Create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = inst,
	}, { Style.list("y", 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local iconSize = if plain then math.floor(size * 0.55) else math.floor(size * 0.55)
	local icon = Icon.new(if p.locked then "lock" else p.icon, iconSize)
	icon.LayoutOrder = 1
	if p.disabled then
		for _, part in { icon, table.unpack(icon:GetDescendants()) } do
			if part:IsA("ImageLabel") then
				part.ImageTransparency = 0.6
			elseif part:IsA("TextLabel") then
				part.TextTransparency = 0.6
			end
		end
	end
	icon.Parent = body
	if p.label and not plain then
		Style.text({
			text = p.label,
			weight = Enum.FontWeight.Bold,
			size = 10,
			color = if p.selected
				then Theme.color("inkText")
				elseif p.disabled then Theme.color("textMuted") -- dimmed with the icon (FORGE-05 L5 on #55)
				else Theme.color("parchment200"),
			xAlign = "Center",
			extra = { Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 2, Name = "Label" },
		}).Parent =
			body
	end
	if p.badge and p.badge > 0 then
		Create("TextLabel", {
			Name = "Badge",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 6, 0, -6),
			Size = UDim2.fromOffset(20, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Theme.color("amber"),
			Text = tostring(p.badge),
			TextSize = 11,
			FontFace = Theme.font("body", Enum.FontWeight.ExtraBold),
			TextColor3 = Theme.color("inkText"),
			ZIndex = 3,
			Parent = inst,
		}, { Style.corner(10), Style.stroke(Theme.color("ink950"), 1.5), Style.padding(0, 5) })
	end
end

function IconButton:destroy()
	self.instance:Destroy()
end

return IconButton
