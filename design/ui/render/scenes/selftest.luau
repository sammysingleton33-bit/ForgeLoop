--[[
	selftest — exercises every feature the headless renderer emulates, built with plain Instance.new
	(no FORGELOOP UI modules), so a reviewer can check the renderer itself. What each region must
	look like: selftest.expect.md (same folder).

		lune run design/ui/render/snapshot.luau design/ui/render/scenes/selftest.luau phone
		node design/ui/render/render.js

	ScreenGuis: Core (CoreUISafeInsets; a Root frame of size core/s with UIScale s and 12 feature
	cards in a UIGridLayout), Fullscreen (None), DeviceSafe (DeviceSafeInsets), IgnoreInset
	(IgnoreGuiInset = true), TopBar (TopbarSafeInsets), StackLow/StackHigh (DisplayOrder), and
	Disabled (Enabled = false: must not appear).
]]

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"
local MERRIWEATHER = "rbxasset://fonts/families/Merriweather.json"
local GRENZE = "rbxasset://fonts/families/GrenzeGotisch.json"

local INK = Color3.fromRGB(24, 32, 47)
local INK_DARK = Color3.fromRGB(11, 15, 24)
local GOLD = Color3.fromRGB(214, 168, 74)
local TEXT = Color3.fromRGB(244, 236, 216)
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(217, 64, 64)
local GREEN = Color3.fromRGB(70, 180, 90)
local BLUE = Color3.fromRGB(70, 120, 220)
local YELLOW = Color3.fromRGB(240, 210, 60)
local ORANGE = Color3.fromRGB(240, 140, 40)
local CYAN = Color3.fromRGB(60, 200, 220)
local MAGENTA = Color3.fromRGB(220, 60, 200)

local function new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className :: any)
	for key, value in props or {} do
		(instance :: any)[key] = value
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	return instance
end

-- Frame with no legacy border unless asked (Instance.new gives BorderSizePixel = 1).
local function frame(props: { [string]: any }, children: { Instance }?): any
	props.BorderSizePixel = props.BorderSizePixel or 0
	return new("Frame", props, children)
end

local function text(props: { [string]: any }, children: { Instance }?, className: string?): any
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = Font.new(MONTSERRAT, Enum.FontWeight.SemiBold),
		TextSize = 11,
		TextColor3 = TEXT,
	}
	for key, value in defaults do
		if props[key] == nil then
			props[key] = value
		end
	end
	return new(className or "TextLabel", props, children)
end

local function corner(px: number, scale: number?): Instance
	return new("UICorner", { CornerRadius = UDim.new(scale or 0, px) })
end

local function stroke(color: Color3, thickness: number, transparency: number?, mode: any?): Instance
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border,
	})
end

local function list(direction: any, padding: UDim, props: { [string]: any }?): Instance
	local p = props or {}
	p.FillDirection = direction
	p.Padding = padding
	p.SortOrder = p.SortOrder or Enum.SortOrder.LayoutOrder
	return new("UIListLayout", p)
end

local function chip(name: string, color: Color3, size: UDim2, order: number?): any
	return frame({ Name = name, BackgroundColor3 = color, Size = size, LayoutOrder = order or 0 }, {
		corner(3),
		text({ Name = "Label", Text = name, Size = UDim2.fromScale(1, 1), TextSize = 10, TextColor3 = INK_DARK }),
	})
end

-- A feature card: gold-trimmed panel with a title and a Body frame (132 x 126 in a 140 x 150 cell).
local function card(index: number, title: string): (any, any)
	local body = frame({
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 20),
		Size = UDim2.new(1, -8, 1, -24),
	})
	local c = frame({ Name = `Card{index}`, BackgroundColor3 = INK, LayoutOrder = index }, {
		corner(8),
		stroke(GOLD, 1, 0.35),
		text({
			Name = "Title",
			Text = `{index} {title}`,
			Position = UDim2.fromOffset(6, 2),
			Size = UDim2.new(1, -12, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = GOLD,
			FontFace = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
		}),
		body,
	})
	return c, body
end

-- ---------------------------------------------------------------- the twelve feature cards

local function cardAnchors(): Instance
	local c, body = card(1, "Anchors / Z / clip")
	local box = frame(
		{ Name = "Box", BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, Size = UDim2.new(1, 0, 0, 70) },
		{
			frame({
				Name = "TL",
				BackgroundColor3 = RED,
				Size = UDim2.fromOffset(10, 10),
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromScale(0, 0),
			}),
			frame({
				Name = "TR",
				BackgroundColor3 = GREEN,
				Size = UDim2.fromOffset(10, 10),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
			}),
			frame({
				Name = "BL",
				BackgroundColor3 = BLUE,
				Size = UDim2.fromOffset(10, 10),
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
			}),
			frame({
				Name = "BR",
				BackgroundColor3 = YELLOW,
				Size = UDim2.fromOffset(10, 10),
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.fromScale(1, 1),
			}),
			frame({
				Name = "Center",
				BackgroundColor3 = WHITE,
				Size = UDim2.fromOffset(16, 16),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			}),
			frame({
				Name = "Rotated",
				BackgroundColor3 = ORANGE,
				Size = UDim2.fromOffset(36, 8),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 22),
				Rotation = 30,
			}),
		}
	)
	box.Parent = body
	-- scale + offset: width 0.5 * 132 + 10 = 76, x = 0.25 * 132 - 5 = 28 (centred)
	frame({
		Name = "ScaleOffsetBar",
		BackgroundColor3 = CYAN,
		Size = UDim2.new(0.5, 10, 0, 6),
		Position = UDim2.new(0.25, -5, 0, 76),
	}).Parent =
		body
	-- ZIndex: Front is created first but has the higher ZIndex, so it is drawn over Back
	frame({
		Name = "Front",
		BackgroundColor3 = GREEN,
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(16, 90),
		ZIndex = 2,
	}).Parent =
		body
	frame({
		Name = "Back",
		BackgroundColor3 = RED,
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.fromOffset(28, 100),
		ZIndex = 1,
	}).Parent =
		body
	-- ClipsDescendants: the 80 px magenta child is cut at the 50 px frame's right edge
	frame({
		Name = "Clip",
		BackgroundColor3 = INK_DARK,
		Size = UDim2.fromOffset(50, 24),
		Position = UDim2.fromOffset(70, 92),
		ClipsDescendants = true,
	}, {
		frame({
			Name = "Overflow",
			BackgroundColor3 = MAGENTA,
			Size = UDim2.fromOffset(80, 10),
			Position = UDim2.fromOffset(10, 7),
		}),
	}).Parent =
		body
	frame({ Name = "Hidden", BackgroundColor3 = RED, Size = UDim2.fromScale(1, 1), Visible = false }).Parent = body
	return c
end

local function cardListVertical(): Instance
	local c, body = card(2, "List vertical")
	new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 6),
	}).Parent =
		body
	list(Enum.FillDirection.Vertical, UDim.new(0, 4), {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}).Parent =
		body
	body.BackgroundTransparency = 0.9
	body.BackgroundColor3 = WHITE
	-- instance order C, A, Hidden, B; LayoutOrder sorts them 1, 2, 3; Position is ignored by the layout
	chip("3 · 90%", GOLD, UDim2.new(0.9, 0, 0, 18), 3).Parent = body
	local a = chip("1 · 40px", GOLD, UDim2.new(0, 40, 0, 18), 1)
	a.Position = UDim2.fromOffset(500, 500)
	a.Parent = body
	local hidden = chip("hidden", RED, UDim2.new(1, 0, 0, 18), 0)
	hidden.Visible = false
	hidden.Parent = body
	chip("2 · 60%", GOLD, UDim2.new(0.6, 0, 0, 18), 2).Parent = body
	return c
end

local function cardListHorizontal(): Instance
	local c, body = card(3, "List horizontal")
	local top = frame(
		{
			Name = "RightBottom",
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.9,
			Size = UDim2.new(1, 0, 0.5, -2),
		},
		{
			list(Enum.FillDirection.Horizontal, UDim.new(0.05, 0), {
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
			}),
		}
	)
	chip("3", ORANGE, UDim2.fromOffset(26, 30), 3).Parent = top
	chip("1", ORANGE, UDim2.fromOffset(26, 20), 1).Parent = top
	chip("2", ORANGE, UDim2.fromOffset(26, 40), 2).Parent = top
	top.Parent = body
	local bottom = frame({
		Name = "SpaceBetween",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.9,
		Position = UDim2.new(0, 0, 0.5, 2),
		Size = UDim2.new(1, 0, 0.5, -2),
	}, {
		list(Enum.FillDirection.Horizontal, UDim.new(0, 0), {
			HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	for i = 1, 3 do
		chip(`{i}`, CYAN, UDim2.fromOffset(26, 20), i).Parent = bottom
	end
	bottom.Parent = body
	return c
end

local function cardFlex(): Instance
	local c, body = card(4, "Flex / grow / wrap")
	local tabs = frame({ Name = "FillTabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20) }, {
		list(Enum.FillDirection.Horizontal, UDim.new(0, 2), { HorizontalFlex = Enum.UIFlexAlignment.Fill }),
	})
	for i, name in { "Eco", "Civ", "Mil" } do
		chip(name, GOLD, UDim2.new(0, 10, 1, 0), i).Parent = tabs
	end
	tabs.Parent = body
	local slider = frame(
		{ Name = "Grow", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 14) },
		{
			list(Enum.FillDirection.Horizontal, UDim.new(0, 4), { VerticalAlignment = Enum.VerticalAlignment.Center }),
		}
	)
	chip("-", WHITE, UDim2.fromOffset(12, 12), 1).Parent = slider
	frame({ Name = "Bar", BackgroundColor3 = CYAN, Size = UDim2.fromOffset(0, 6), LayoutOrder = 2 }, {
		new("UIFlexItem", { FlexMode = Enum.UIFlexMode.Grow }),
	}).Parent =
		slider
	chip("+", WHITE, UDim2.fromOffset(12, 12), 3).Parent = slider
	slider.Parent = body
	local wrap = frame({
		Name = "Wraps",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.9,
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 0, 60),
	}, {
		list(Enum.FillDirection.Horizontal, UDim.new(0, 4), { Wraps = true }),
	})
	for i = 1, 7 do
		chip(`{i}`, ORANGE, UDim2.fromOffset(28, 16), i).Parent = wrap
	end
	wrap.Parent = body
	-- a class the renderer does not emulate: plain box + dashed outline + class name
	new("VideoFrame", {
		Name = "Video",
		BackgroundColor3 = INK_DARK,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 110),
		Size = UDim2.new(1, 0, 0, 16),
	}).Parent =
		body
	return c
end

local function cardGrid(): Instance
	local c, body = card(5, "Grid")
	new("UIGridLayout", {
		CellSize = UDim2.new(0.3, 0, 0, 24),
		CellPadding = UDim2.new(0.04, 0, 0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		FillDirection = Enum.FillDirection.Horizontal,
	}).Parent =
		body
	for i = 7, 1, -1 do
		-- own Size is ignored: the cell size wins
		chip(`{i}`, GREEN, UDim2.fromOffset(5, 5), i).Parent = body
	end
	-- GuiObjects inside a Folder render as children of the Folder's parent (not part of the grid here)
	local inFolder = chip("in a Folder", WHITE, UDim2.new(1, 0, 0, 16), 0)
	inFolder.Position = UDim2.new(0, 0, 1, -16)
	new("Folder", { Name = "Extras" }, { inFolder }).Parent = body
	return c
end

local function cardStrokes(): Instance
	local c, body = card(6, "Corners / strokes")
	frame(
		{ Name = "Square", BackgroundColor3 = GOLD, Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(4, 4) },
		{
			stroke(WHITE, 1),
		}
	).Parent =
		body
	frame(
		{
			Name = "Round6",
			BackgroundColor3 = GOLD,
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(38, 4),
		},
		{
			corner(6),
			stroke(WHITE, 3),
		}
	).Parent =
		body
	frame(
		{ Name = "Pill", BackgroundColor3 = GOLD, Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(72, 4) },
		{
			corner(0, 0.5),
			stroke(RED, 2, 0.5),
		}
	).Parent =
		body
	frame({
		Name = "LegacyBorder",
		BackgroundColor3 = GOLD,
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.fromOffset(104, 4),
		BorderSizePixel = 3,
		BorderColor3 = WHITE,
		BorderMode = Enum.BorderMode.Outline,
	}).Parent =
		body
	text({
		Name = "Outlined",
		Text = "Outlined",
		TextSize = 16,
		TextColor3 = WHITE,
		FontFace = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold),
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 20),
	}, { stroke(INK_DARK, 1.5, 0, Enum.ApplyStrokeMode.Contextual) }).Parent =
		body
	text({
		Name = "Boxed",
		Text = "Boxed button",
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 0, 20),
	}, { corner(4), stroke(GOLD, 1) }, "TextButton").Parent =
		body
	text({
		Name = "LegacyStroke",
		Text = "TextStroke (legacy)",
		TextSize = 12,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = RED,
		Position = UDim2.fromOffset(0, 94),
		Size = UDim2.new(1, 0, 0, 20),
	}).Parent =
		body
	return c
end

local function gradientBar(name: string, y: number, color: Color3, gradient: { [string]: any }): Instance
	return frame(
		{ Name = name, BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, 16), Position = UDim2.fromOffset(0, y) },
		{
			new("UIGradient", gradient),
			text({ Name = "Label", Text = name, TextSize = 10, TextColor3 = INK_DARK, Size = UDim2.fromScale(1, 1) }),
		}
	)
end

local function cardGradients(): Instance
	local c, body = card(7, "Gradients")
	gradientBar("red to blue", 0, WHITE, { Color = ColorSequence.new(RED, BLUE) }).Parent = body
	gradientBar("vertical 90", 20, WHITE, { Color = ColorSequence.new(GOLD, INK), Rotation = 90 }).Parent = body
	gradientBar(
		"green x white-black",
		40,
		Color3.fromRGB(0, 200, 0),
		{ Color = ColorSequence.new(WHITE, Color3.new(0, 0, 0)) }
	).Parent =
		body
	gradientBar("alpha 0 to 1", 60, WHITE, {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
	}).Parent =
		body
	gradientBar("offset 0.25", 80, WHITE, { Color = ColorSequence.new(RED, BLUE), Offset = Vector2.new(0.25, 0) }).Parent =
		body
	text({
		Name = "GradientText",
		Text = "Gradient text",
		TextSize = 16,
		TextColor3 = WHITE,
		FontFace = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold),
		Position = UDim2.fromOffset(0, 100),
		Size = UDim2.new(1, 0, 0, 24),
	}, { new("UIGradient", { Color = ColorSequence.new(YELLOW, RED) }) }).Parent =
		body
	return c
end

local function boxed(props: { [string]: any }): Instance
	props.BackgroundTransparency = 0.88
	props.BackgroundColor3 = WHITE
	return text(props)
end

local function cardText(): Instance
	local c, body = card(8, "Text align / wrap")
	boxed({ Name = "Left", Text = "Left", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 14) }).Parent =
		body
	boxed({ Name = "Center", Text = "Center", Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 14) }).Parent =
		body
	boxed({
		Name = "Right",
		Text = "Right",
		TextXAlignment = Enum.TextXAlignment.Right,
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 14),
	}).Parent =
		body
	boxed({
		Name = "Top",
		Text = "Top",
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(0.5, -2, 0, 28),
	}).Parent =
		body
	boxed({
		Name = "Bottom",
		Text = "Bottom",
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Position = UDim2.new(0.5, 2, 0, 48),
		Size = UDim2.new(0.5, -2, 0, 28),
	}).Parent =
		body
	boxed({
		Name = "Truncated",
		Text = "Truncated text that cannot fit here",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 14),
	}).Parent =
		body
	boxed({
		Name = "Wrapped",
		Text = "Wrapped text continues on a second line",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(0, 96),
		Size = UDim2.new(1, 0, 0, 28),
	}).Parent =
		body
	return c
end

local function cardFonts(): Instance
	local c, body = card(9, "Fonts / rich / emoji")
	text({
		Name = "Grenze",
		Text = "Aldmere Kingdom",
		TextSize = 18,
		FontFace = Font.new(GRENZE, Enum.FontWeight.Bold),
		TextColor3 = GOLD,
		Size = UDim2.new(1, 0, 0, 22),
	}).Parent =
		body
	text({
		Name = "Merriweather",
		Text = "Merriweather 900",
		TextSize = 12,
		FontFace = Font.new(MERRIWEATHER, Enum.FontWeight.Heavy),
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 16),
	}).Parent =
		body
	text({
		Name = "Regular",
		Text = "Montserrat Regular",
		FontFace = Font.new(MONTSERRAT, Enum.FontWeight.Regular),
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 14),
	}).Parent =
		body
	text({
		Name = "Heavy",
		Text = "MONTSERRAT HEAVY",
		FontFace = Font.new(MONTSERRAT, Enum.FontWeight.Heavy),
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 14),
	}).Parent =
		body
	text({
		Name = "Rich",
		Text = 'Rich: <b>bold</b> <i>italic</i> <font color="#FF5555">red</font>',
		RichText = true,
		FontFace = Font.new(MONTSERRAT, Enum.FontWeight.Regular),
		Position = UDim2.fromOffset(0, 76),
		Size = UDim2.new(1, 0, 0, 16),
	}).Parent =
		body
	text({
		Name = "Emoji",
		Text = "⚔️ 🏰 👑 🪙 ⚒ •",
		TextSize = 14,
		Position = UDim2.fromOffset(0, 94),
		Size = UDim2.new(1, 0, 0, 18),
	}).Parent =
		body
	text({
		Name = "PlainTags",
		Text = "<b>not rich</b>",
		TextSize = 10,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		Position = UDim2.fromOffset(0, 112),
		Size = UDim2.new(1, 0, 0, 14),
	}).Parent =
		body
	return c
end

local function cardAutoSize(): Instance
	local c, body = card(10, "AutoSize / scaled")
	text({
		Name = "AutoXPill",
		Text = "Auto X",
		TextColor3 = INK_DARK,
		BackgroundTransparency = 0,
		BackgroundColor3 = GOLD,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
	}, {
		corner(0, 0.5),
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	}).Parent =
		body
	boxed({
		Name = "Scaled",
		Text = "BIG",
		TextScaled = true,
		FontFace = Font.new(MONTSERRAT, Enum.FontWeight.ExtraBold),
		Position = UDim2.fromOffset(80, 0),
		Size = UDim2.fromOffset(52, 36),
	}).Parent =
		body
	local stack = frame({
		Name = "AutoYStack",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.88,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.fromOffset(70, 0),
	}, {
		new("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),
		list(Enum.FillDirection.Vertical, UDim.new(0, 2)),
	})
	for i = 1, 3 do
		chip(`row {i}`, CYAN, UDim2.new(1, 0, 0, 10), i).Parent = stack
	end
	stack.Parent = body
	boxed({
		Name = "AutoYText",
		Text = "Auto Y: this paragraph grows to fit its wrapped lines.",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 0),
	}).Parent =
		body
	return c
end

local function cardScrolling(): Instance
	local c, body = card(11, "ScrollingFrame")
	local scroller = new("ScrollingFrame", {
		Name = "Scroller",
		BackgroundColor3 = INK_DARK,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = GOLD,
		CanvasPosition = Vector2.new(0, 30),
	}, {
		new("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 10),
		}),
		list(Enum.FillDirection.Vertical, UDim.new(0, 2)),
	})
	for i = 1, 8 do
		chip(`Row {i}`, if i % 2 == 0 then GOLD else ORANGE, UDim2.new(1, 0, 0, 18), i).Parent = scroller
	end
	scroller.Parent = body
	return c
end

local function cardConstraints(): Instance
	local c, body = card(12, "Scale / constraints")
	-- UIScale 0.5 about the anchor: the gold box is 30 x 15, centred in the 60 x 30 outline
	frame({
		Name = "ScaleRef",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(34, 18),
		Size = UDim2.fromOffset(60, 30),
	}, {
		stroke(WHITE, 1, 0.3),
	}).Parent =
		body
	frame({
		Name = "Scaled",
		BackgroundColor3 = GOLD,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(34, 18),
		Size = UDim2.fromOffset(60, 30),
	}, {
		new("UIScale", { Scale = 0.5 }),
	}).Parent =
		body
	-- UIAspectRatioConstraint 2 inside a 60 x 40 box: 60 x 30
	frame({
		Name = "AspectRef",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(70, 3),
		Size = UDim2.fromOffset(60, 40),
	}, {
		stroke(WHITE, 1, 0.3),
	}).Parent =
		body
	frame(
		{
			Name = "Aspect",
			BackgroundColor3 = CYAN,
			Position = UDim2.fromOffset(70, 3),
			Size = UDim2.fromOffset(60, 40),
		},
		{
			new("UIAspectRatioConstraint", { AspectRatio = 2 }),
		}
	).Parent =
		body
	-- CanvasGroup at 50 % group transparency
	new("CanvasGroup", {
		Name = "Group",
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		GroupTransparency = 0.5,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.fromOffset(60, 30),
	}, {
		frame({
			Name = "Red",
			BackgroundColor3 = RED,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(48, 18),
		}),
	}).Parent =
		body
	-- UISizeConstraint: Size is 100 % wide, MaxSize caps it at 50 px
	frame({
		Name = "MaxWidth",
		BackgroundColor3 = GREEN,
		Position = UDim2.fromOffset(70, 52),
		Size = UDim2.new(1, 0, 0, 10),
	}, {
		new("UISizeConstraint", { MaxSize = Vector2.new(50, math.huge) }),
	}).Parent =
		body
	-- SizeConstraint RelativeYY: 0.2 of the parent's HEIGHT on both axes -> a square
	frame({
		Name = "RelativeYY",
		BackgroundColor3 = ORANGE,
		Position = UDim2.fromOffset(70, 66),
		Size = UDim2.fromScale(0.2, 0.2),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	}).Parent =
		body
	-- UITextSizeConstraint: TextScaled would make this ~28 px; MaxTextSize caps it at 14
	boxed({
		Name = "CappedScaled",
		Text = "cap 14",
		TextScaled = true,
		Position = UDim2.fromOffset(0, 94),
		Size = UDim2.fromOffset(64, 30),
	}).Parent =
		body
	-- images: rbxassetid content cannot be fetched headless -> labelled placeholders (tinted by ImageColor3)
	new("ImageLabel", {
		Name = "Image",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "rbxassetid://1234567",
		ImageColor3 = GOLD,
		ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(70, 94),
		Size = UDim2.fromOffset(30, 30),
	}).Parent =
		body
	new("ImageButton", {
		Name = "ImageButton",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "rbxassetid://7654321",
		Position = UDim2.fromOffset(102, 94),
		Size = UDim2.fromOffset(30, 30),
	}, { corner(0, 0.5) }).Parent =
		body
	local capped = body:FindFirstChild("CappedScaled")
	new("UITextSizeConstraint", { MaxTextSize = 14 }).Parent = capped
	return c
end

-- ---------------------------------------------------------------- screen guis

local function badge(name: string, color: Color3, props: { [string]: any }): Instance
	local b = text({
		Name = name,
		Text = name,
		TextSize = 10,
		TextColor3 = WHITE,
		BackgroundTransparency = 0.15,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(110, 18),
	}, { corner(4) })
	for key, value in props do
		(b :: any)[key] = value
	end
	return b
end

return function(ctx)
	-- Root frame of size core / s with a UIScale s: fills the whole CoreUISafeInsets area
	local s = math.clamp(math.min(ctx.core.width / 890, ctx.core.height / 326), 0.5, 1.5)
	local core = new("ScreenGui", {
		Name = "Core",
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	})
	local root = frame({
		Name = "Root",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.82,
		-- UDim offsets are integers (Roblox stores int32; Lune rejects fractions): floor, as game code must
		Size = UDim2.fromOffset(math.floor(ctx.core.width / s), math.floor(ctx.core.height / s)),
	}, {
		new("UIScale", { Scale = s }),
		frame({
			Name = "MarkTL",
			BackgroundColor3 = RED,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0, 0),
		}),
		frame({
			Name = "MarkTR",
			BackgroundColor3 = GREEN,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
		}),
		frame({
			Name = "MarkBL",
			BackgroundColor3 = BLUE,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
		}),
		frame({
			Name = "MarkBR",
			BackgroundColor3 = YELLOW,
			Size = UDim2.fromOffset(8, 8),
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
		}),
	})
	local cards = frame({
		Name = "Cards",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 1, -16),
	}, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(140, 150),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	for _, build in { cardAnchors, cardListVertical, cardListHorizontal, cardFlex, cardGrid, cardStrokes } do
		build().Parent = cards
	end
	for _, build in { cardGradients, cardText, cardFonts, cardAutoSize, cardScrolling, cardConstraints } do
		build().Parent = cards
	end
	cards.Parent = root
	text({
		Name = "ScaleNote",
		Text = string.format("Core · UIScale %.3f", s),
		TextSize = 10,
		TextColor3 = INK_DARK,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(160, 10),
	}).Parent =
		root
	root.Parent = core

	local fullscreen =
		new("ScreenGui", { Name = "Fullscreen", DisplayOrder = 0, ScreenInsets = Enum.ScreenInsets.None })
	for _, edge in
		{
			{ "EdgeTop", UDim2.new(1, 0, 0, 4), UDim2.fromScale(0, 0), Vector2.new(0, 0) },
			{ "EdgeBottom", UDim2.new(1, 0, 0, 4), UDim2.fromScale(0, 1), Vector2.new(0, 1) },
			{ "EdgeLeft", UDim2.new(0, 4, 1, 0), UDim2.fromScale(0, 0), Vector2.new(0, 0) },
			{ "EdgeRight", UDim2.new(0, 4, 1, 0), UDim2.fromScale(1, 0), Vector2.new(1, 0) },
		}
	do
		frame({
			Name = edge[1],
			BackgroundColor3 = MAGENTA,
			BackgroundTransparency = 0.2,
			Size = edge[2],
			Position = edge[3],
			AnchorPoint = edge[4],
		}).Parent =
			fullscreen
	end
	badge("None (fullscreen)", MAGENTA, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -4) }).Parent =
		fullscreen

	local deviceSafe =
		new("ScreenGui", { Name = "DeviceSafe", DisplayOrder = 3, ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets })
	badge("DeviceSafeInsets", BLUE, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0) }).Parent =
		deviceSafe

	local ignoreInset = new("ScreenGui", { Name = "IgnoreInset", DisplayOrder = 3, IgnoreGuiInset = true })
	badge(
		"IgnoreGuiInset",
		Color3.fromRGB(40, 140, 140),
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 20) }
	).Parent =
		ignoreInset

	local topbar =
		new("ScreenGui", { Name = "TopBar", DisplayOrder = 2, ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets })
	frame({ Name = "Band", BackgroundColor3 = BLUE, BackgroundTransparency = 0.8, Size = UDim2.fromScale(1, 1) }).Parent =
		topbar
	text({
		Name = "BandStart",
		Text = "◀ TopbarSafeInsets",
		TextSize = 10,
		TextColor3 = INK_DARK,
		TextXAlignment = Enum.TextXAlignment.Left,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(120, 14),
	}).Parent =
		topbar
	text({
		Name = "Timer",
		Text = "12:34",
		TextSize = 18,
		FontFace = Font.new(MONTSERRAT, Enum.FontWeight.Bold),
		BackgroundTransparency = 0,
		BackgroundColor3 = INK,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 110, 1, -16),
	}, { corner(0, 0.5), stroke(GOLD, 2) }).Parent =
		topbar

	-- DisplayOrder: StackHigh (6) is listed first but must be drawn over StackLow (5)
	local stackLow =
		new("ScreenGui", { Name = "StackLow", DisplayOrder = 5, ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets })
	local low = chip("Low", RED, UDim2.fromOffset(28, 28), 0)
	low.AnchorPoint = Vector2.new(0.5, 0.5)
	low.Position = UDim2.new(0.75, 0, 0.5, 0)
	low.Parent = stackLow
	local stackHigh =
		new("ScreenGui", { Name = "StackHigh", DisplayOrder = 6, ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets })
	local high = chip("High", GREEN, UDim2.fromOffset(28, 28), 0)
	high.AnchorPoint = Vector2.new(0.5, 0.5)
	high.Position = UDim2.new(0.75, 16, 0.5, 6)
	high.Parent = stackHigh

	local disabled = new(
		"ScreenGui",
		{ Name = "Disabled", DisplayOrder = 100, Enabled = false, ScreenInsets = Enum.ScreenInsets.None }
	)
	frame({ Name = "MustNotShow", BackgroundColor3 = RED, Size = UDim2.fromScale(1, 1) }).Parent = disabled

	return { guis = { core, fullscreen, deviceSafe, ignoreInset, topbar, stackHigh, stackLow, disabled } }
end
