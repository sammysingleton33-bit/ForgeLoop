--!strict
--[[
	Tabs — segmented tab strip (construction categories, kingdom panel sections).

	Props
		tabs: { { id: string, label: string, icon: string?, disabled: boolean? } }
		selected: string           id of the selected tab
		compact: boolean?          phones: unselected tabs show only their icon
		onSelect: ((id: string) -> ())?   not called for disabled tabs or the selected one
	Tabs.new(props) -> handle { instance: Frame, buttons: { [id]: TextButton }, update(partial), destroy() }
	The selected tab has a gold underline; disabled tabs show a lock and are dimmed.
]]

local Create = require("../Create")
local Icon = require("../Icon")
local Style = require("../Style")
local Theme = require("../Theme")

local Tabs = {}
Tabs.__index = Tabs

function Tabs.new(props: { [string]: any })
	local self = setmetatable({ _props = {}, buttons = {} }, Tabs)
	self.instance = Create("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 34),
	}, { Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	self:update(props)
	return self
end

function Tabs:update(partial: { [string]: any })
	for key, value in partial do
		self._props[key] = value
	end
	local p = self._props
	for _, button in self.buttons do
		button:Destroy()
	end
	self.buttons = {}
	for index, tab in p.tabs or {} do
		local selected = tab.id == p.selected
		local showLabel = selected or not p.compact
		local color = if tab.disabled
			then Theme.color("textMuted")
			elseif selected then Theme.color("gold300")
			else Theme.color("textSecondary")
		local button = Create("TextButton", {
			Name = "Tab_" .. tab.id,
			Text = "",
			AutoButtonColor = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 0, 34),
			BackgroundColor3 = if selected then Theme.color("ink600") else Theme.color("ink950"),
			BackgroundTransparency = if selected then 0 else 0.45,
			LayoutOrder = index,
			Active = not tab.disabled,
			[Create.Event.Activated] = function()
				if not tab.disabled and tab.id ~= self._props.selected and self._props.onSelect then
					self._props.onSelect(tab.id)
				end
			end,
			Parent = self.instance,
		}, {
			Style.corner(8),
			Style.stroke(if selected then Theme.color("gold600") else Theme.color("ink500"), 1),
		})
		button:SetAttribute("selected", selected)
		-- Content sits in its own row so the underline below is not a list item.
		local row = Create("Frame", {
			Name = "Row",
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			Parent = button,
		}, {
			Style.padding(0, 12, 0, 10),
			Style.list("x", 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
		})
		local icon = Icon.new(if tab.disabled then "lock" else tab.icon or "info", 18)
		icon.LayoutOrder = 1
		icon.Parent = row
		if showLabel then
			Style.text({
				text = tab.label,
				weight = Enum.FontWeight.Bold,
				size = 13,
				color = color,
				extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2 },
			}).Parent =
				row
		end
		if selected then
			Create("Frame", {
				Name = "Underline",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, 1),
				Size = UDim2.new(1, -16, 0, 3),
				BackgroundColor3 = Theme.color("gold400"),
				Parent = button,
			}, { Style.corner(2) })
		end
		self.buttons[tab.id] = button
	end
end

function Tabs:destroy()
	self.instance:Destroy()
end

return Tabs
