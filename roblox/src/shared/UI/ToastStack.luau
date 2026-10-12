--!strict
--[[
	UI/ToastStack — stand-in for FORGE-04's NotificationController until it merges (interfaces §8:
	all transient toasts go through NotificationController:show). Game UI controllers use the real
	controller when registry:find("NotificationController") returns one, and this otherwise.

	ToastStack.new(parent: GuiObject, motion) -> stack
	stack:show({ title, body?, kind?, durationSec? (default 3.5) })   newest on top, at most 3
	stack:place(position: UDim2, anchor: Vector2, width: number)       follows the layout
	stack:count() -> number
]]

local Create = require("./Create")
local Style = require("./Style")
local Toast = require("./Components/Toast")

local ToastStack = {}
ToastStack.__index = ToastStack

ToastStack.MAX = 3

function ToastStack.new(parent: Instance, motion: any)
	local self = setmetatable({ _motion = motion, _items = {}, _width = 300, _order = 0 }, ToastStack)
	self.instance = Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(300, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
		Parent = parent,
	}, { List = Style.list("y", 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top) })
	return self
end

function ToastStack:place(position: UDim2, anchor: Vector2, width: number)
	self.instance.Position = position
	self.instance.AnchorPoint = anchor
	self.instance.Size = UDim2.fromOffset(width, 0)
	self._width = width
end

function ToastStack:show(spec: { title: string, body: string?, kind: string?, durationSec: number? })
	self._order -= 1
	local toast = Toast.new({
		title = spec.title,
		body = spec.body,
		kind = spec.kind,
		width = self._width,
		layoutOrder = self._order,
	})
	toast.instance.Parent = self.instance
	table.insert(self._items, 1, toast)
	while #self._items > ToastStack.MAX do
		table.remove(self._items):destroy()
	end
	self._motion:after(spec.durationSec or 3.5, function()
		local index = table.find(self._items, toast) -- nil once the stack was destroyed
		if index then
			table.remove(self._items, index)
			toast:destroy()
		end
	end)
	return toast
end

function ToastStack:count(): number
	return #self._items
end

function ToastStack:destroy()
	self._items = {}
	self.instance:Destroy()
end

return ToastStack
