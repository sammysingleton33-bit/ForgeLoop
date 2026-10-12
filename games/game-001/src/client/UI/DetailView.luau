--!strict
--[[
	UI/DetailView — the building detail pane shared by the build menu (Place) and the Kingdom
	panel (Upgrade): what it is, how long builders need, what it costs against what you have, and one
	call-to-action that says exactly why it is disabled. The CTA stays pinned at the bottom while
	the body scrolls, so it is never pushed off a phone screen.

	DetailView.new({ detail = BuildModel Detail, compact = boolean, back = string?,
	                 onCta = (detail) -> (), onBack = () -> () }) -> handle
	handle.instance: Frame (fills its parent)   handle.cta: Button handle   handle:destroy()
	The CTA face carries the attribute `cta` (its state) for specs and Studio inspection.
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local DetailView = {}
DetailView.__index = DetailView

local SHORT = Color3.fromRGB(255, 138, 115)
local GOOD = Color3.fromRGB(169, 229, 124)

local function stat(icon: string, text: string, order: number): Frame
	local i = Icon.new(icon, 16)
	i.LayoutOrder = 1
	return Create("Frame", {
		Name = "Stat",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = order,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
		Padding = Style.padding(0, 8, 0, 4),
		List = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = i,
		Text = Style.text({
			text = text,
			weight = Enum.FontWeight.Bold,
			size = 11,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), LayoutOrder = 2 },
		}),
	})
end

local function costRow(c: any, order: number): Frame
	local icon = Icon.new(c.currency, 18)
	icon.LayoutOrder = 1
	return Create("Frame", {
		Name = "Cost_" .. c.currency,
		BackgroundColor3 = if c.short then Theme.color("gules") else Theme.color("scrim"),
		BackgroundTransparency = if c.short then 0.84 else 0.55,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = order,
	}, {
		Corner = Style.corner(6),
		Padding = Style.padding(0, 8, 0, 6),
		List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Icon = icon,
		CurrencyName = Style.text({
			text = c.name,
			size = 12,
			color = Theme.color("textSecondary"),
			extra = { Size = UDim2.new(1, -150, 1, 0), LayoutOrder = 2 },
		}),
		Amount = Style.text({
			text = Format.amount(c.amount),
			weight = Enum.FontWeight.Bold,
			size = 12,
			xAlign = "Right",
			extra = { Size = UDim2.new(0, 44, 1, 0), LayoutOrder = 3 },
		}),
		Have = Style.text({
			text = if c.short then `have {Format.amount(c.have)}` else `✓ {Format.amount(c.have)}`,
			weight = Enum.FontWeight.Bold,
			size = 12,
			xAlign = "Right",
			color = if c.short then SHORT else GOOD,
			extra = { Size = UDim2.new(0, 66, 1, 0), LayoutOrder = 4 },
		}),
	})
end

function DetailView.new(props: { [string]: any })
	local self = setmetatable({}, DetailView)
	local d = props.detail
	local compact = props.compact == true
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local body = Create("ScrollingFrame", {
		Name = "Body",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.color("gold600"),
	}, { List = Style.list("y", 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })

	if not compact then
		Style.text({
			text = d.description,
			weight = Enum.FontWeight.Medium,
			size = 12,
			color = Theme.color("textSecondary"),
			wrap = true,
			extra = {
				Name = "Description",
				AutomaticSize = Enum.AutomaticSize.Y,
				Size = UDim2.fromScale(1, 0),
				LayoutOrder = nextOrder(),
			},
		}).Parent =
			body
	end

	if d.buildSeconds then
		local stats = Create("Frame", {
			Name = "Stats",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = nextOrder(),
			Parent = body,
		}, { List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
		stat("timer", `{Format.clock(d.buildSeconds)} with builders`, 1).Parent = stats
	end

	local costs = Create("Frame", {
		Name = "Costs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = nextOrder(),
		Parent = body,
	}, { List = Style.list("y", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	for i, c in d.costs do
		costRow(c, i).Parent = costs
	end

	local tileSize = if compact then 40 else 56
	local header = Create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, tileSize),
	}, {
		Tile = Icon.tile(d.icon, tileSize, d.category),
		Titles = Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(tileSize + 10, 0),
			Size = UDim2.new(1, -tileSize - 10, 1, 0),
		}, {
			List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
			Title = Style.text({
				text = d.name,
				role = "heading",
				weight = Enum.FontWeight.Heavy,
				size = if compact then 16 else 18,
				color = Theme.color("parchment100"),
				extra = { Size = UDim2.new(1, 0, 0, if compact then 20 else 22), LayoutOrder = 1 },
			}),
			Meta = Style.text({
				text = d.meta,
				weight = Enum.FontWeight.Bold,
				size = 11,
				color = Theme.color("gold400"),
				extra = { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2 },
			}),
		}),
	})

	local cta = d.cta
	self.cta = Button.new({
		text = cta.text,
		icon = cta.icon,
		variant = if cta.state == "done" then "success" else "primary",
		state = if cta.state == "disabled" then "disabled" elseif cta.state == "loading" then "loading" else "default",
		onActivated = function()
			if cta.state == "ready" and props.onCta then
				props.onCta(d)
			end
		end,
	})
	self.cta.instance.AnchorPoint = Vector2.new(0, 1)
	self.cta.instance.Position = UDim2.fromScale(0, 1)
	self.cta.instance.Name = "Cta"
	self.cta.face:SetAttribute("cta", cta.state)

	local backHeight = if props.back then 24 else 0
	local children: { [any]: any } = {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("gold500"), 1, 0.65),
		Gradient = Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.color("parchment200"), Theme.color("parchment200")),
			Transparency = NumberSequence.new(0.9, 0.96),
		}),
		Padding = Style.padding(if compact then 8 else 10),
		Header = header,
		Body = body,
		Cta = self.cta.instance,
	}
	header.Position = UDim2.fromOffset(0, backHeight)
	body.Position = UDim2.fromOffset(0, backHeight + tileSize + 8)
	body.Size = UDim2.new(1, 0, 1, -(backHeight + tileSize + 8 + 44 + 8))
	if props.back then
		children.Back = Create("TextButton", {
			Text = "‹ " .. props.back,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(160, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Theme.font("body", Enum.FontWeight.Bold),
			TextSize = 12,
			TextColor3 = Theme.color("gold400"),
			[Create.Event.Activated] = function()
				if props.onBack then
					props.onBack()
				end
			end,
		})
	end
	self.instance = Create("Frame", {
		Name = "Detail",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
	}, children)
	return self
end

function DetailView:destroy()
	self.instance:Destroy()
end

return DetailView
