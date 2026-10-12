--!strict
--[[
	Grid — a scrolling grid of equal cells (inventory, shop, reward outcomes).

	Props
		cell: Vector2               cell size in px (default 104 x 128)
		gap: number?                px between cells (default 10)
		size: UDim2?                default fills the parent
		empty: string?              message shown when there are no items
	Grid.new(props) -> handle { instance: Frame, scroll: ScrollingFrame, add(instance), clear(), count(), destroy() }
	Items are positioned by UIGridLayout in LayoutOrder; the canvas grows with content.
]]

local Create = require("../Create")
local Style = require("../Style")
local Theme = require("../Theme")

local Grid = {}
Grid.__index = Grid

function Grid.new(props: { [string]: any })
	local self = setmetatable({ _count = 0, _props = props }, Grid)
	local cell = props.cell or Vector2.new(104, 128)
	local gap = props.gap or 10
	self._empty = Style.text({
		text = props.empty or "Nothing here yet",
		size = 12,
		color = Theme.color("textMuted"),
		xAlign = "Center",
		extra = { Size = UDim2.new(1, 0, 0, 40) },
	})
	self.scroll = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.color("gold600"),
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell.X, cell.Y),
			CellPadding = UDim2.fromOffset(gap, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Style.padding(2),
	})
	self.instance = Create("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Size = props.size or UDim2.fromScale(1, 1),
	}, { Scroll = self.scroll, Empty = self._empty })
	return self
end

function Grid:add(instance: Instance)
	self._count += 1
	instance.Parent = self.scroll
	self._empty.Visible = false
end

function Grid:clear()
	for _, child in self.scroll:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	self._count = 0
	self._empty.Visible = true
end

function Grid:count(): number
	return self._count
end

function Grid:destroy()
	self.instance:Destroy()
end

return Grid
