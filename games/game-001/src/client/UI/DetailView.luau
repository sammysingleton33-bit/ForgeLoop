--!strict
--[[
	UI/DetailView — the building detail pane shared by the build menu (Place) and the Kingdom
	panel (Upgrade): what it is, how long builders need, what it costs against what you have, and one
	call-to-action that says exactly why it is disabled. The CTA stays pinned at the bottom while
	the body scrolls, so it is never pushed off a phone screen.

	DetailView.new({ detail = BuildModel Detail, compact = boolean, back = string?,
	                 onCta = (detail) -> (), onBack = () -> (), onTurn = (() -> ())?,
	                 onSide = ((detail) -> ())? }) -> handle
	A plot detail with `turn` (CONTRACTS v0.4-g9h) gets a "FacingRow" under the build time: the
	facing dial "Facing" (detail.turn.facing, degrees on screen), the label ("Faces the street"…) and
	a "Turn" button, disabled with "Only this way fits" when a single turn fits the plot. Phones, whose
	drawer is too short for another row: the label is a "FacingLabel" chip beside the build time and
	"Turn" (rotate icon and dial, 76 × 44) sits left of the CTA. Either carries the attribute `turn`.
	A detail with `side = { text, icon?, state: "ready" | "disabled" }` (the upgrade panel's Move, FL-0120)
	gets a secondary button "Side" left of the CTA (DetailView.SIDE wide, 44 px tall); a tap calls
	props.onSide(detail) while it is ready. Its face carries the attribute `side` (its state).
	handle.instance: Frame (fills its parent)   handle.cta: Button handle   handle:destroy()
	handle:update(detail, { onCta?, onBack?, onTurn? })   patches what a push changes — what you have
		of each cost, the CTA's state and text, the facing — on the same instances (FORGE-05 M1: a rebuild under the
		player's finger lost the tap). Use it when DetailView.key(...) is unchanged.
	DetailView.key(detail, compact, back?) -> string   the layout: everything but `have`/`short`
		and the CTA. A different key needs a new DetailView.
	The CTA face carries the attribute `cta` (its state) for specs and Studio inspection.
]]

local Button = require("@game/ReplicatedStorage/Forge/UI/Components/Button")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local FacingDial = require("./FacingDial")
local Format = require("@game/ReplicatedStorage/Forge/UI/Format")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Signature = require("./Signature")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local DetailView = {}
DetailView.__index = DetailView

local SHORT = Color3.fromRGB(255, 138, 115)
local GOOD = Color3.fromRGB(169, 229, 124)

DetailView.COMPACT_TURN = 76 -- phones: the Turn button's width, left of the CTA
DetailView.SIDE = 112 -- the side action's width (Move), left of the CTA

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

-- What a push changes on a cost row: the balance and whether it is short.
local function paintCost(row: any, c: any)
	row.BackgroundColor3 = if c.short then Theme.color("gules") else Theme.color("scrim")
	row.BackgroundTransparency = if c.short then 0.84 else 0.55
	local have = row:FindFirstChild("Have")
	if have then
		have.Text = if c.short then `have {Format.amount(c.have)}` else `✓ {Format.amount(c.have)}`
		have.TextColor3 = if c.short then SHORT else GOOD
	end
end

local function ctaProps(cta: any): { [string]: any }
	return {
		text = cta.text,
		icon = cta.icon or false,
		variant = if cta.state == "done" then "success" else "primary",
		state = if cta.state == "disabled" then "disabled" elseif cta.state == "loading" then "loading" else "default",
	}
end

function DetailView.key(d: any, compact: boolean, back: string?): string
	local costs = {}
	for i, c in d.costs do
		costs[i] = { currency = c.currency, name = c.name, amount = c.amount }
	end
	return Signature.of({
		type = d.type,
		name = d.name,
		icon = d.icon,
		category = d.category,
		description = d.description,
		meta = d.meta,
		action = d.action,
		buildingId = d.buildingId,
		slotId = d.slotId,
		level = d.level,
		buildSeconds = d.buildSeconds,
		benefits = d.benefits,
		turnable = if d.turn then d.turn.canTurn else nil,
		side = if d.side then d.side.text ~= nil else nil,
		costs = costs,
		compact = compact,
		back = back,
	})
end

local function costRow(c: any, order: number): Frame
	local icon = Icon.new(c.currency, 18)
	icon.LayoutOrder = 1
	local row = Create("Frame", {
		Name = "Cost_" .. c.currency,
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
			text = "",
			weight = Enum.FontWeight.Bold,
			size = 12,
			xAlign = "Right",
			extra = { Size = UDim2.new(0, 66, 1, 0), LayoutOrder = 4 },
		}),
	})
	paintCost(row, c)
	return row
end

function DetailView.new(props: { [string]: any })
	local d = props.detail
	local compact = props.compact == true
	local self = setmetatable({
		key = DetailView.key(d, compact, props.back),
		costs = {},
		_detail = d,
		_onCta = props.onCta,
		_onBack = props.onBack,
		_onTurn = props.onTurn,
		_onSide = props.onSide,
	}, DetailView)
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

	if not compact and d.description then
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
		self._stats = stats
	end

	-- Plots (v0.4-g9h): the Facing row (phones: a chip and a Turn button beside the CTA, below).
	if d.turn and not compact then
		local row = self:_buildFacing(d.turn)
		row.LayoutOrder = nextOrder()
		row.Parent = body
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
		local row = costRow(c, i)
		row.Parent = costs
		self.costs[c.currency] = row
	end

	-- What this level gives / what the next one adds (FL-0087). After the costs, so phones see
	-- the price first.
	local benefits = d.benefits or {}
	if compact then
		-- Phones: what the next level adds is the line that decides an upgrade; keep it above the fold.
		local nextOnly = {}
		for _, b in benefits do
			if b.next then
				table.insert(nextOnly, b)
			end
		end
		if #nextOnly > 0 then
			benefits = nextOnly
		end
	end
	if #benefits > 0 then
		local list = Create("Frame", {
			Name = "Benefits",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = body,
		}, { List = Style.list("y", 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
		for i, b in benefits do
			Create("Frame", {
				Name = "Benefit_" .. i,
				BackgroundColor3 = if b.next then Theme.color("vert") else Theme.color("scrim"),
				BackgroundTransparency = if b.next then 0.82 else 0.55,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = i,
				Parent = list,
			}, {
				Corner = Style.corner(6),
				Stroke = if b.next then Style.stroke(Theme.color("vert"), 1, 0.55) else nil,
				Padding = Style.padding(5, 8, 5, 8),
				Label = Style.text({
					text = b.label,
					weight = Enum.FontWeight.ExtraBold,
					size = 12,
					color = if b.next then GOOD else Theme.color("textSecondary"),
					extra = { Size = UDim2.fromOffset(52, 16) },
				}),
				Text = Style.text({
					text = b.text,
					weight = Enum.FontWeight.SemiBold,
					size = 12,
					wrap = true,
					extra = {
						Position = UDim2.fromOffset(60, 0),
						Size = UDim2.new(1, -60, 0, 16),
						AutomaticSize = Enum.AutomaticSize.Y,
					},
				}),
			})
		end
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

	-- The CTA acts on the newest detail: update() may have patched it since it was built.
	local ctaSpec = ctaProps(d.cta)
	ctaSpec.onActivated = function()
		local current = self._detail
		if current.cta.state == "ready" and self._onCta then
			self._onCta(current)
		end
	end
	self.cta = Button.new(ctaSpec)
	self._ctaKey = Signature.of(d.cta)
	self.cta.instance.AnchorPoint = Vector2.new(0, 1)
	self.cta.instance.Position = UDim2.fromScale(0, 1)
	self.cta.instance.Name = "Cta"
	self.cta.face:SetAttribute("cta", d.cta.state)
	local compactTurn = if d.turn and compact then self:_buildCompactTurn(d.turn, self._stats) else nil
	if compactTurn then
		self.cta.instance.Position = UDim2.new(0, DetailView.COMPACT_TURN + 8, 1, 0)
		self.cta.instance.Size = UDim2.new(1, -(DetailView.COMPACT_TURN + 8), 0, 44)
	end
	local side = nil
	if d.side then
		self.side = Button.new({
			text = d.side.text,
			icon = d.side.icon or false,
			variant = "secondary",
			width = DetailView.SIDE,
			state = if d.side.state == "ready" then "default" else "disabled",
			onActivated = function()
				local current = self._detail
				if current.side and current.side.state == "ready" and self._onSide then
					self._onSide(current)
				end
			end,
		})
		side = self.side.instance
		side.Name = "Side"
		side.AnchorPoint = Vector2.new(0, 1)
		side.Position = UDim2.fromScale(0, 1)
		self.side.face:SetAttribute("side", d.side.state)
		self._sideKey = Signature.of(d.side)
		self.cta.instance.Position = UDim2.new(0, DetailView.SIDE + 8, 1, 0)
		self.cta.instance.Size = UDim2.new(1, -(DetailView.SIDE + 8), 0, 44)
	end

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
		Turn = compactTurn,
		Side = side,
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
				if self._onBack then
					self._onBack()
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

-- The Facing row (plots, v0.4-g9h): dial, label, and Turn.
function DetailView:_buildFacing(turn: any): Frame
	local turnButton = Button.new({
		text = "Turn",
		icon = "rotate",
		variant = "secondary",
		width = 104,
		state = if turn.canTurn then "default" else "disabled",
		onActivated = function()
			if self._onTurn then
				self._onTurn()
			end
		end,
	})
	turnButton.instance.Name = "Turn"
	turnButton.instance.AnchorPoint = Vector2.new(1, 0.5)
	turnButton.instance.Position = UDim2.fromScale(1, 0.5)
	local dial = FacingDial.new(30)
	dial.AnchorPoint = Vector2.new(0, 0.5)
	dial.Position = UDim2.fromScale(0, 0.5)
	local textWidth = -(30 + 8 + 104 + 8)
	local row = Create("Frame", {
		Name = "FacingRow",
		BackgroundColor3 = Theme.color("scrim"),
		BackgroundTransparency = 0.55,
		Size = UDim2.new(1, 0, 0, 52),
	}, {
		Corner = Style.corner(8),
		Padding = Style.padding(2, 4, 2, 8),
		Facing = dial,
		Label = Style.text({
			text = turn.label,
			weight = Enum.FontWeight.Bold,
			size = 13,
			color = Theme.color("parchment100"),
			extra = {
				Name = "Label",
				Position = UDim2.fromOffset(38, 6),
				Size = UDim2.new(1, textWidth, 0, 18),
			},
		}),
		Hint = Style.text({
			text = if turn.canTurn then "Turn to change it" else "Only this way fits",
			weight = Enum.FontWeight.SemiBold,
			size = 11,
			color = Theme.color("textSecondary"),
			extra = {
				Name = "Hint",
				Position = UDim2.fromOffset(38, 25),
				Size = UDim2.new(1, textWidth, 0, 16),
			},
		}),
		Turn = turnButton.instance,
	}) :: Frame
	self._facing, self._dial = row, dial
	self._turnLabel = row:FindFirstChild("Label") :: TextLabel
	self:_paintTurn(turn)
	return row
end

-- Phones: the drawer is too short for a row, so the label is a chip beside the build time and Turn
-- (rotate icon and dial, a 44 px target) sits left of the CTA.
function DetailView:_buildCompactTurn(turn: any, stats: Frame?): TextButton
	local chip = stat("rotate", turn.label, 2)
	chip.Name = "FacingLabel"
	chip.Parent = stats
	local icon = Icon.new("rotate", 18)
	icon.LayoutOrder = 1
	local dial = FacingDial.new(24, 2)
	local button = Create("TextButton", {
		Name = "Turn",
		Text = "",
		AutoButtonColor = false,
		Active = turn.canTurn,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(DetailView.COMPACT_TURN, 44),
		[Create.Event.Activated] = function()
			if self._onTurn and self._detail.turn and self._detail.turn.canTurn then
				self._onTurn()
			end
		end,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		Gradient = Style.gradient(Theme.color("ink600"), Theme.color("ink800")),
		List = Style.list("x", 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
		Icon = icon,
		Facing = dial,
	}) :: TextButton
	button.BackgroundTransparency = if turn.canTurn then 0 else 0.5
	self._facing, self._dial = button, dial
	self._turnLabel = chip:FindFirstChild("Text") :: TextLabel
	self:_paintTurn(turn)
	return button
end

function DetailView:_paintTurn(turn: any)
	local row = self._facing
	if row == nil then
		return
	end
	if self._turnLabel then
		self._turnLabel.Text = turn.label
	end
	row:SetAttribute("turn", turn.value)
	FacingDial.set(self._dial, turn.facing or 0)
end

function DetailView:update(
	d: any,
	handlers: { onCta: ((any) -> ())?, onBack: (() -> ())?, onTurn: (() -> ())?, onSide: ((any) -> ())? }?
)
	self._detail = d
	if handlers then
		self._onCta = handlers.onCta
		self._onBack = handlers.onBack
		self._onTurn = handlers.onTurn
		self._onSide = handlers.onSide
	end
	if d.side and self.side then
		local sideKey = Signature.of(d.side)
		if sideKey ~= self._sideKey then
			self._sideKey = sideKey
			self.side:update({
				text = d.side.text,
				icon = d.side.icon or false,
				state = if d.side.state == "ready" then "default" else "disabled",
			})
			self.side.face:SetAttribute("side", d.side.state)
		end
	end
	if d.turn then
		self:_paintTurn(d.turn)
	end
	for _, c in d.costs do
		local row = self.costs[c.currency]
		if row then
			paintCost(row, c)
		end
	end
	local ctaKey = Signature.of(d.cta)
	if ctaKey ~= self._ctaKey then
		self._ctaKey = ctaKey
		self.cta:update(ctaProps(d.cta))
		self.cta.face:SetAttribute("cta", d.cta.state)
	end
end

function DetailView:destroy()
	self.instance:Destroy()
end

return DetailView
