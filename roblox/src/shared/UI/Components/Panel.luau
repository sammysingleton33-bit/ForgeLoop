--!strict
--[[
	Panel — the framed surface menus and drawers are built on: dark ink gradient, gold trim, a
	faint inner rule, a hard drop shadow, an optional title row with the diamond ornament.

	Props
		title: string?          display-font title (omitted on phones by the screens that use it)
		size: UDim2             position: UDim2?    anchor: Vector2?
		ornament: boolean?      gold rule with a diamond under the title (default true with a title)
		padding: number?        inner padding (default 12)
		header: Instance?       extra header content placed right of the title (tabs, close button)
		onClose: (() -> ())?    adds a close control at the top right (an X, or `closeText`)
		closeText: string?      e.g. "Skip": a small secondary button instead of the X
		compact: boolean?       phones: 8 px padding and a smaller title
		zIndex: number?
	Panel.new(props) -> handle { instance: Frame, content: Frame (put children here),
		headerSlot: Frame, update(partial), destroy() }
]]

local Button = require("./Button")
local Create = require("../Create")
local IconButton = require("./IconButton")
local Style = require("../Style")
local Theme = require("../Theme")

local Panel = {}
Panel.__index = Panel

local RADIUS = 12

function Panel.new(props: { [string]: any })
	local self = setmetatable({}, Panel)
	local pad = props.padding or (if props.compact then 8 else 12)
	local hasTitle = props.title ~= nil
	local headerHeight = if hasTitle or props.header or props.onClose then 38 else 0
	local ornament = hasTitle and props.ornament ~= false
	local top = headerHeight + (if ornament then 14 else if headerHeight > 0 then 8 else 0)

	self.headerSlot = Create("Frame", {
		Name = "HeaderSlot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, { Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	self.content = Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(pad, pad + top),
		Size = UDim2.new(1, -2 * pad, 1, -2 * pad - top),
		ZIndex = 2,
	})
	local header = nil
	if headerHeight > 0 then
		local children: { [any]: any } = {}
		if hasTitle then
			children.Title = Style.text({
				text = props.title,
				role = "display",
				weight = Enum.FontWeight.Bold,
				size = if props.compact then 21 else 26,
				color = Theme.color("gold300"),
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 1 },
			})
		end
		-- With a title, the slot takes whatever width the title leaves (UIFlexItem Fill), so header
		-- content anchored to the right (a close button) sits at the panel's right edge.
		local slotHolder = Create("Frame", {
			Name = "Slot",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(if hasTitle then 0 else 1, 1),
			LayoutOrder = 2,
		}, {
			HeaderSlot = self.headerSlot,
			Flex = if hasTitle then Create("UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill }) else nil,
		})
		children.Slot = slotHolder
		header = Create("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(pad, pad - 2),
			Size = UDim2.new(1, -2 * pad, 0, headerHeight),
			ZIndex = 2,
		}, children)
		Style.list("x", 12, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center).Parent = header
		if props.header then
			props.header.Parent = self.headerSlot
		end
	end
	local ornamentFrame = nil
	if ornament then
		ornamentFrame = Create("Frame", {
			Name = "Ornament",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(pad, pad + headerHeight + 2),
			Size = UDim2.new(1, -2 * pad, 0, 10),
			ZIndex = 2,
		}, {
			Line = Create("Frame", {
				BackgroundColor3 = Theme.color("gold600"),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(1, 0, 0, 1),
			}, {
				Create("UIGradient", {
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 1),
						NumberSequenceKeypoint.new(0.3, 0),
						NumberSequenceKeypoint.new(0.7, 0),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
			}),
			Diamond = Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(8, 8),
				Rotation = 45,
				BackgroundColor3 = Theme.color("gold400"),
			}, { Style.stroke(Theme.color("gold700"), 1) }),
		})
	end
	self.instance = Create("Frame", {
		Name = "Panel",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.size or UDim2.fromOffset(300, 200),
		Position = props.position or UDim2.new(),
		AnchorPoint = props.anchor or Vector2.zero,
		ZIndex = props.zIndex or 1,
	}, {
		Corner = Style.corner(RADIUS),
		Stroke = Style.stroke(Theme.color("gold700"), 1.5),
		Gradient = Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.color("ink700")),
				ColorSequenceKeypoint.new(0.38, Theme.color("ink800")),
				ColorSequenceKeypoint.new(1, Theme.color("ink900")),
			}),
		}),
		Inset = Style.inset(RADIUS),
		Header = header,
		Ornament = ornamentFrame,
		Content = self.content, -- member-ok: a child named "Content" in the children table, not a property
	})
	if props.onClose then
		local close
		if props.closeText then
			close = Button.new({
				text = props.closeText,
				variant = "secondary",
				size = "small",
				width = math.max(64, 12 + 8 * #props.closeText),
				onActivated = props.onClose,
			})
		else
			close = IconButton.new({ icon = "close", variant = "plain", size = 36, onActivated = props.onClose })
		end
		close.instance.Name = "Close"
		close.instance.AnchorPoint = Vector2.new(1, 0)
		close.instance.Position = UDim2.new(1, -pad, 0, pad - 1)
		close.instance.ZIndex = 3
		close.instance.Parent = self.instance
		self.close = close
	end
	return self
end

function Panel:update(partial: { [string]: any })
	if partial.size then
		self.instance.Size = partial.size
	end
	if partial.position then
		self.instance.Position = partial.position
	end
end

function Panel:destroy()
	self.instance:Destroy()
end

return Panel
