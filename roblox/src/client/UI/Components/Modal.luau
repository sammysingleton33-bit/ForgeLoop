--!strict
--[[
	Modal — a centred confirmation over a scrim. Used before large spends (an action that takes
	half or more of any resource) and always before a Robux purchase (FL-0021).

	Props
		title: string                 body: string?
		rows: { { icon: string, label: string, value: string, note: string? } }?   e.g. the costs
		confirmText: string           cancelText: string? (default "Cancel")
		confirmVariant: string?       Button variant (default "primary")
		confirmIcon: string?
		width: number?                px (default 400)
		onConfirm: () -> ()           onCancel: (() -> ())?   (also called by tapping the scrim)
	Modal.new(props) -> handle { instance: Frame (full-screen: scrim + panel), destroy() }
	Put it in a DeviceSafeInsets ScreenGui in the modals DisplayOrder band (40-59).
]]

local Button = require("./Button")
local Create = require("../Create")
local Icon = require("../Icon")
local Panel = require("./Panel")
local Style = require("../Style")
local Theme = require("../Theme")

local Modal = {}
Modal.__index = Modal

function Modal.new(props: { [string]: any })
	local self = setmetatable({}, Modal)
	local rows = props.rows or {}
	local height = 150 + #rows * 27 + (if props.body then 34 else 0)
	local panel = Panel.new({
		title = props.title,
		size = UDim2.fromOffset(props.width or 400, height),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		zIndex = 2,
	})
	local content = panel.content
	Style.list("y", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top).Parent = content
	if props.body then
		Style.text({
			text = props.body,
			size = 12,
			color = Theme.color("textSecondary"),
			wrap = true,
			extra = { Name = "Body", Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 },
		}).Parent =
			content
	end
	for i, row in rows do
		local icon = Icon.new(row.icon, 18)
		icon.LayoutOrder = 1
		Create("Frame", {
			Name = "Row" .. i,
			BackgroundColor3 = Theme.color("scrim"),
			BackgroundTransparency = 0.55,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 1 + i,
			Parent = content,
		}, {
			Style.corner(6),
			Style.padding(0, 8),
			Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			icon,
			Style.text({
				text = row.label,
				size = 12,
				color = Theme.color("textSecondary"),
				extra = { Size = UDim2.fromScale(0.5, 1), LayoutOrder = 2 },
			}),
			Style.text({
				text = row.value .. (if row.note then "  " .. row.note else ""),
				weight = Enum.FontWeight.Bold,
				size = 12,
				xAlign = "Right",
				extra = { Size = UDim2.new(0.5, -30, 1, 0), LayoutOrder = 3 },
			}),
		})
	end
	local buttons = Create("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = 100,
		Parent = content,
	}, { Style.list("x", 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local half = math.floor(((props.width or 400) - 24 - 10) / 2)
	self.cancel = Button.new({
		text = props.cancelText or "Cancel",
		variant = "secondary",
		width = half,
		layoutOrder = 1,
		onActivated = function()
			if props.onCancel then
				props.onCancel()
			end
		end,
	})
	self.cancel.instance.Parent = buttons
	self.confirm = Button.new({
		text = props.confirmText,
		icon = props.confirmIcon,
		variant = props.confirmVariant or "primary",
		width = half,
		layoutOrder = 2,
		onActivated = props.onConfirm,
	})
	self.confirm.instance.Parent = buttons
	self.instance = Create("Frame", {
		Name = "Modal",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Scrim = Create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.color("scrim"),
			BackgroundTransparency = 0.4,
			Size = UDim2.fromScale(1, 1),
			[Create.Event.Activated] = function()
				if props.onCancel then
					props.onCancel()
				end
			end,
		}),
		Panel = panel.instance,
	})
	return self
end

function Modal:destroy()
	self.instance:Destroy()
end

return Modal
