--!strict
--[[
	ItemCard — an item with a rarity frame (inventory, shop, reward outcomes). The rarity is always
	written as text too, never shown by colour alone.

	Props
		name: string?              icon: string?          rarity: string?  (Common..Legendary)
		owned: boolean?            check badge            locked: boolean?   lock badge, dimmed
		empty: boolean?            dashed "Empty slot"    note: string?      e.g. odds "12.50%"
		size: Vector2?             default 104 x 128      layoutOrder: number?
		onActivated: (() -> ())?
	ItemCard.new(props) -> handle { instance: TextButton, destroy() }
]]

local Create = require("../Create")
local Icon = require("../Icon")
local Style = require("../Style")
local Theme = require("../Theme")

local ItemCard = {}
ItemCard.__index = ItemCard

function ItemCard.new(props: { [string]: any })
	local self = setmetatable({}, ItemCard)
	local size = props.size or Vector2.new(104, 128)
	local children: { [any]: any } = {}
	if props.empty then
		children.Stroke = Style.stroke(Theme.color("ink500"), 1.5)
		children.Note = Style.text({
			text = "Empty slot",
			size = 11,
			color = Theme.color("textMuted"),
			xAlign = "Center",
			extra = { Size = UDim2.fromScale(1, 1) },
		})
	else
		local rarity = Theme.rarity(props.rarity or "Common")
		children.Stroke = Style.stroke(rarity, 2)
		children.Gradient = Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Theme.color("ink700"):Lerp(rarity, 0.28)),
				ColorSequenceKeypoint.new(0.7, Theme.color("ink800")),
				ColorSequenceKeypoint.new(1, Theme.color("ink800")),
			}),
		})
		local icon = Icon.new(props.icon or "info", 56)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 10)
		children.Icon = icon
		children.ItemName = Style.text({
			text = props.name or "",
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = 12,
			xAlign = "Center",
			wrap = true,
			extra = { Position = UDim2.fromOffset(4, 68), Size = UDim2.new(1, -8, 0, 30) },
		})
		children.Rarity = Create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromOffset(0, 16),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = rarity,
			Text = props.note or props.rarity or "Common",
			TextSize = 10,
			FontFace = Theme.font("body", Enum.FontWeight.ExtraBold),
			TextColor3 = Theme.color("inkText"),
		}, { Style.corner(999), Style.padding(0, 7) })
		if props.owned or props.locked then
			local badge = Icon.new(if props.locked then "lock" else "check", 20)
			badge.Position = UDim2.new(1, -26, 0, 6)
			children.Badge = badge
		end
	end
	children.Corner = Style.corner(12)
	self.instance = Create("TextButton", {
		Name = "ItemCard",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if props.empty then Theme.color("ink950") else Color3.new(1, 1, 1),
		BackgroundTransparency = if props.empty then 0.5 elseif props.locked then 0.45 else 0,
		Size = UDim2.fromOffset(size.X, size.Y),
		LayoutOrder = props.layoutOrder or 0,
		[Create.Event.Activated] = function()
			if not props.empty and not props.locked and props.onActivated then
				props.onActivated()
			end
		end,
	}, children)
	return self
end

function ItemCard:destroy()
	self.instance:Destroy()
end

return ItemCard
