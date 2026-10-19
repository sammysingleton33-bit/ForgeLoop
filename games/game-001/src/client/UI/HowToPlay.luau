--!strict
--[[
	UI/HowToPlay — "How to play", six short cards on the modal layer (FL-0138); the model is UI/HowToPlayModel.
		Card     a large picture tile (the card's icon), the title and the body (plain words)
		Footer   Back, the step ("2 of 6") with one dot per card, Next ("Done" on the last card); Close (X) at the top
	Desktop/tablet: 600 × 340 centred, the picture left of the text. Phones (667 × 375): min(600, width - 16) × min(262,
	height - 16), centred 4 px low so it clears the Roblox top bar, with a smaller picture. Back and Next are 44 px on every size (touch targets, L7).
	Names for specs and Studio: "HowToPlay" (attributes card = id, index); "Picture", "CardTitle", "CardBody", "Step",
	"Dot_<i>" (attribute on), buttons "Back", "Next" (face attribute last), "Close".

	HowToPlay.new(parent) -> view
	view:render(view, metrics, ui: { onBack, onNext, onClose })   view:destroy()   view.instance: Frame "HowToPlay"
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local IconButton = require("@game/ReplicatedStorage/Forge/UI/Components/IconButton")
local Panel = require("@game/ReplicatedStorage/Forge/UI/Components/Panel")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local HowToPlay = {}
HowToPlay.__index = HowToPlay

HowToPlay.SIZE = table.freeze({ width = 600, height = 340 })
-- phones: the Results recap's box (UI/LeadershipRecap.PHONE), below the Roblox top bar (58 px)
HowToPlay.PHONE = table.freeze({ width = 600, height = 262 })

function HowToPlay.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame?, back = nil :: any, next = nil :: any }, HowToPlay)
end

function HowToPlay:render(v: any, m: any, ui: { [string]: any })
	self:destroy()
	local phone = m.breakpoint == "phone"
	local box = if phone then HowToPlay.PHONE else HowToPlay.SIZE
	local width = math.min(box.width, m.width - 16)
	local height = math.min(box.height, m.height - 16)
	local card = v.card
	local close = IconButton.new({
		icon = "close",
		variant = "plain",
		size = 36,
		onActivated = function()
			if ui.onClose then
				ui.onClose()
			end
		end,
	})
	close.instance.Name = "Close"
	close.instance.AnchorPoint = Vector2.new(1, 0.5)
	close.instance.Position = UDim2.fromScale(1, 0.5)
	local header = Create("Frame", { Name = "HeaderRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Title = Style.text({
			text = "How to play",
			role = "heading",
			weight = Enum.FontWeight.Bold,
			size = if phone then 16 else 20,
			color = Theme.color("gold300"),
			extra = { Size = UDim2.new(1, -44, 1, 0) },
		}),
		Close = close.instance,
	})
	local panel = Panel.new({
		header = header,
		size = UDim2.fromOffset(width, height),
		position = if phone then UDim2.new(0.5, 0, 0.5, 4) else UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		padding = if phone then 10 else 16,
		compact = phone,
		zIndex = 3,
	})
	local content = panel.content
	-- the picture tile
	local tile = if phone then 72 else 120
	local picture = Create("Frame", {
		Name = "Picture",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.2,
		Size = UDim2.fromOffset(tile, tile),
	}, {
		Corner = Style.corner(16),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
	})
	local art = Icon.new(card.picture, math.floor(tile * 0.62))
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Parent = picture
	picture.Parent = content
	local textX = tile + (if phone then 12 else 18)
	local footer = 52
	local textBlock = Create("Frame", {
		Name = "Text",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(textX, 0),
		Size = UDim2.new(1, -textX, 1, -footer),
	}, { List = Style.list("y", if phone then 4 else 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	Style.text({
		text = card.title,
		role = "heading",
		weight = Enum.FontWeight.Bold,
		size = if phone then 16 else 22,
		color = Theme.color("textPrimary"),
		extra = { Name = "CardTitle", Size = UDim2.new(1, 0, 0, if phone then 20 else 28), LayoutOrder = 1 },
	}).Parent =
		textBlock
	Style.text({
		text = card.body,
		weight = Enum.FontWeight.SemiBold,
		size = if phone then 12 else 15,
		color = Theme.color("textSecondary"),
		wrap = true,
		yAlign = "Top",
		extra = {
			Name = "CardBody",
			Size = UDim2.new(1, 0, 1, if phone then -24 else -36),
			LayoutOrder = 2,
			LineHeight = 1.15,
		},
	}).Parent =
		textBlock
	textBlock.Parent = content
	-- footer: Back · step and dots · Next
	local back = Button.new({
		text = "Back",
		variant = "secondary",
		size = "regular",
		state = if v.first then "disabled" else "default",
		onActivated = function()
			if ui.onBack then
				ui.onBack()
			end
		end,
	})
	back.instance.Name = "Back"
	back.instance.AnchorPoint = Vector2.new(0, 1)
	back.instance.Position = UDim2.fromScale(0, 1)
	back.instance.Size = UDim2.fromOffset(if phone then 110 else 140, 44)
	back.instance.Parent = content
	local nextButton = Button.new({
		text = if v.last then "Done" else "Next",
		variant = "primary",
		size = "regular",
		onActivated = function()
			if ui.onNext then
				ui.onNext()
			end
		end,
	})
	nextButton.instance.Name = "Next"
	nextButton.instance.AnchorPoint = Vector2.new(1, 1)
	nextButton.instance.Position = UDim2.fromScale(1, 1)
	nextButton.instance.Size = UDim2.fromOffset(if phone then 110 else 140, 44)
	nextButton.face:SetAttribute("last", v.last)
	nextButton.instance.Parent = content
	local middle = Create("Frame", {
		Name = "Progress",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(120, 44),
	}, { List = Style.list("y", 4, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local dots = Create("Frame", {
		Name = "Dots",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(120, 10),
		LayoutOrder = 1,
	}, { List = Style.list("x", 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	for i, on in v.dots do
		local dot = Create("Frame", {
			Name = "Dot_" .. i,
			BackgroundColor3 = if on then Theme.color("gold400") else Theme.color("ink500"),
			Size = UDim2.fromOffset(if on then 10 else 8, if on then 10 else 8),
			LayoutOrder = i,
		}, { Corner = Style.corner(999) })
		dot:SetAttribute("on", on)
		dot.Parent = dots
	end
	dots.Parent = middle
	Style.text({
		text = v.step,
		size = 11,
		weight = Enum.FontWeight.SemiBold,
		color = Theme.color("textMuted"),
		xAlign = "Center",
		extra = { Name = "Step", Size = UDim2.fromOffset(120, 14), LayoutOrder = 2 },
	}).Parent =
		middle
	middle.Parent = content
	self.back = back
	self.next = nextButton
	self.instance = Create("Frame", {
		Name = "HowToPlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, {
		Scrim = Create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.color("scrim"),
			BackgroundTransparency = 0.3,
			Size = UDim2.fromScale(1, 1),
		}),
		Panel = panel.instance,
	}) :: Frame
	self.instance:SetAttribute("card", card.id)
	self.instance:SetAttribute("index", v.index)
	self.instance.Parent = self._parent
end

function HowToPlay:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
	self.back = nil
	self.next = nil
end

return HowToPlay
