--!strict
--[[
	CurrencyPill — one resource or currency in the HUD.

	Props
		currency: string           id (icon + colour from the theme)
		amount: number?            loading: boolean?   no value yet ("…"; also when amount is nil)
		cap: number?               shown as " / cap" (full pills only); at cap → amber border
		rate: number?              per minute, shown under the amount (full pills only)
		sub: string?               other text under the amount instead of a rate ("2 idle")
		subColor: Color3?          colour for `sub`
		compact: boolean?          phones: icon + amount only
		error: boolean?            unknown value ("—")
		layoutOrder: number?
	CurrencyPill.new(props, motion?) -> handle { instance, update(partial), pulse(delta), destroy() }
	pulse(delta) floats a signed number under the pill (red spend / green gain) and tints the
	border for a moment: the visual confirmation of a transaction. Uses UI/Motion when given.
]]

local Create = require("../Create")
local Format = require("../Format")
local Icon = require("../Icon")
local Style = require("../Style")
local Theme = require("../Theme")

local CurrencyPill = {}
CurrencyPill.__index = CurrencyPill

CurrencyPill.PULSE_SEC = 1.4

function CurrencyPill.new(props: { [string]: any }, motion: any?)
	local self = setmetatable({ _props = {}, _motion = motion }, CurrencyPill)
	self._stroke = Style.stroke(Theme.color("gold600"), 1.5, 0.35)
	self._amount = Style.text({
		text = "…",
		weight = Enum.FontWeight.Bold,
		size = 15,
		extra = {
			Name = "Amount",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 16),
			LayoutOrder = 1,
			RichText = true,
		},
	})
	self._rate = Style.text({
		text = "",
		weight = Enum.FontWeight.Bold,
		size = 10,
		color = Theme.color("vert"),
		extra = { Name = "Rate", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 11), LayoutOrder = 2 },
	})
	self._stack = Create("Frame", {
		Name = "Stack",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
	}, {
		List = Style.list("y", 1, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Amount = self._amount,
		Rate = self._rate,
	})
	-- The row holds the laid-out content; the pill itself has no list layout, so the floating
	-- delta (pulse) can sit outside the row instead of becoming a list item.
	self._row = Create("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
	}, {
		Padding = Style.padding(0, 10, 0, 2),
		List = Style.list("x", 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		Stack = self._stack,
	})
	self.instance = Create("Frame", {
		Name = "Pill_" .. tostring(props.currency),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutomaticSize = Enum.AutomaticSize.X,
	}, {
		Corner = Style.corner(999),
		Stroke = self._stroke,
		Gradient = Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.color("ink700"), Theme.color("ink950")),
			Transparency = NumberSequence.new(0.08, 0.1),
		}),
		Row = self._row,
	})
	self:update(props)
	return self
end

function CurrencyPill:update(partial: { [string]: any })
	for key, value in partial do
		self._props[key] = value
	end
	local p = self._props
	local compact = p.compact == true
	self.instance.Size = UDim2.fromOffset(0, if compact then 30 else 34)
	self.instance.LayoutOrder = p.layoutOrder or 0
	local medallion = self._row:FindFirstChild("Medallion")
	if medallion == nil or medallion:GetAttribute("compact") ~= compact then
		if medallion then
			medallion:Destroy()
		end
		medallion = Icon.medallion(p.currency, if compact then 24 else 28, Theme.resource(p.currency))
		medallion:SetAttribute("compact", compact)
		medallion.LayoutOrder = 1
		medallion.Parent = self._row
	end
	local text
	if p.error then
		text = "—"
	elseif p.loading or p.amount == nil then
		text = "…"
	else
		text = Format.amount(p.amount)
	end
	if not compact and p.cap and not p.error and not p.loading then
		local muted = Theme.raw.colors.textMuted
		text ..= string.format('<font size="11" color="%s"> / %s</font>', muted, Format.amount(p.cap))
	end
	self._amount.Text = text
	self._amount.TextSize = if compact then 13 else 15
	self._rate.Visible = not compact and (p.rate ~= nil or p.sub ~= nil)
	if p.sub then
		self._rate.Text = p.sub
		self._rate.TextColor3 = p.subColor or Theme.color("textSecondary")
	else
		self._rate.Text = if p.rate then Format.rate(p.rate) else ""
		self._rate.TextColor3 = if p.rate and p.rate > 0 then Theme.color("vert") else Theme.color("textMuted")
	end
	local full = p.cap ~= nil and p.amount ~= nil and not p.loading and p.amount >= p.cap
	self._stroke.Color = if full then Theme.color("amber") else Theme.color("gold600")
	self._stroke.Transparency = if full then 0 else 0.35
	self.instance:SetAttribute("amount", p.amount)
	self.instance:SetAttribute("full", full)
end

function CurrencyPill:pulse(delta: number)
	if delta == 0 then
		return
	end
	local negative = delta < 0
	-- One delta at a time: a new change replaces the previous float, so a pill without Motion
	-- (which cannot schedule the removal) never piles labels up.
	local previous = self.instance:FindFirstChild("Delta")
	if previous then
		previous:Destroy()
	end
	-- A badge on the pill's top-right corner, with its own background: under the pill it was drawn
	-- over by whatever row comes next (the rulers on tablet/desktop) and could not be read.
	local accent = if negative then Theme.color("gules") else Theme.color("vert")
	local label = Create("TextLabel", {
		Name = "Delta",
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.05,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 2, 0, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		Text = Format.signed(delta),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		FontFace = Theme.font("body", Enum.FontWeight.ExtraBold),
		TextColor3 = if negative then Theme.hex("#FF8A73") else Theme.hex("#A9E57C"),
		ZIndex = 5,
		Parent = self.instance,
	}, {
		Corner = Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Padding = Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		Stroke = Create("UIStroke", { Color = accent, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	self._stroke.Color = if negative then Theme.color("gules") else Theme.color("vert")
	self._stroke.Transparency = 0
	if self._motion then
		-- Fade only when tweens run: without them (reduced motion, no TweenService) the end state
		-- would apply at once and the player would never see the change.
		if self._motion.enabled then
			self._motion:to(
				label,
				{ Position = UDim2.new(1, 2, 0, -10), TextTransparency = 1, BackgroundTransparency = 1 },
				CurrencyPill.PULSE_SEC
			)
			-- its outline fades with it (FORGE-05, #48 review): a bare ring must not linger
			local stroke = label:FindFirstChild("Stroke")
			if stroke then
				self._motion:to(stroke, { Transparency = 1 }, CurrencyPill.PULSE_SEC)
			end
		end
		self._motion:after(CurrencyPill.PULSE_SEC, function()
			if self._destroyed or label.Parent == nil then
				return -- the pill went away, or a newer pulse replaced this float
			end
			label:Destroy()
			self:update({})
		end)
	end
end

function CurrencyPill:destroy()
	self._destroyed = true
	self.instance:Destroy()
end

return CurrencyPill
