--!strict
--[[
	UI/ArenaIntroCard — the two-sided versus card before the duel (FL-0073; design crown-arena.md §7 "Intro"); the
	model is UI/ArenaIntroModel. On the modal layer, centred, with a "VS" medallion between the halves:
		Side_left / Side_right   crest, champion, kingdom, the support tier chip ("Adoring support · 91": name,
		                         colour and score, never colour alone), the loadout (weapon, armour), "Why they cheer"
		                         with up to three reasons, and the chosen perks ("Perk_<id>": icon, name, the citizen)
		Clock                    the intro countdown, top right
	Phones (667 × 375): the safe area below the Roblox top bar, tighter type; reasons wrap to two lines.

	ArenaIntroCard.new(parent) -> view
	view:render(model, metrics)   view:destroy()   view.instance: Frame "ArenaIntro"
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ArenaIntroCard = {}
ArenaIntroCard.__index = ArenaIntroCard

ArenaIntroCard.DESKTOP = table.freeze({ width = 900, height = 410 })
ArenaIntroCard.PHONE_TOP = 52

function ArenaIntroCard.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame? }, ArenaIntroCard)
end

local function line(
	value: string,
	size: number,
	color: Color3,
	weight: any,
	order: number,
	name: string,
	wrap: boolean?
)
	return Style.text({
		text = value,
		size = size,
		color = color,
		weight = weight,
		wrap = wrap,
		extra = {
			Name = name,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
		},
	})
end

local function row(name: string, order: number, gap: number): Frame
	return Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = order,
	}, { List = Style.list("x", gap, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) }) :: Frame
end

local function iconLabel(icon: string, value: string, size: number, order: number, name: string): Frame
	local f = Create("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, size + 4),
		LayoutOrder = order,
	}, { List = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) }) :: Frame
	local i = Icon.new(icon, size)
	i.LayoutOrder = 1
	i.Parent = f
	Style.text({
		text = value,
		size = size - 4,
		color = Theme.color("textPrimary"),
		weight = Enum.FontWeight.SemiBold,
		extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size), LayoutOrder = 2, Parent = f },
	})
	return f
end

local function half(c: any, phone: boolean, name: string): Frame
	local frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = c.color,
		BackgroundTransparency = 0.82,
		Size = UDim2.new(0.5, if phone then -22 else -34, 1, 0),
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(c.color, 1.5, 0.2),
		Padding = Style.padding(if phone then 8 else 14),
		List = Style.list("y", if phone then 3 else 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top),
	}) :: Frame
	frame:SetAttribute("side", c.side)
	-- crest, champion, kingdom
	local head = row("Head", 1, 8)
	head.Parent = frame
	local crest = Crest.new(if phone then 34 else 48, c.color, c.emblem)
	crest.LayoutOrder = 1
	crest.Parent = head
	local names = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, if phone then -42 else -56, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = head,
	}, { List = Style.list("y", 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	line(c.champion, if phone then 16 else 22, Theme.color("textPrimary"), Enum.FontWeight.ExtraBold, 1, "Champion").Parent =
		names
	line(c.kingdomName, if phone then 11 else 13, Theme.color("textSecondary"), Enum.FontWeight.SemiBold, 2, "Kingdom").Parent =
		names
	-- tier chip
	local tierText = if c.score then `{c.tier.name} support · {c.score}` else `{c.tier.name} support`
	local chip = Create("Frame", {
		Name = "Tier",
		BackgroundColor3 = c.tier.color,
		BackgroundTransparency = 0.7,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, if phone then 18 else 22),
		LayoutOrder = 2,
		Parent = frame,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(c.tier.color, 1),
		Padding = Style.padding(0, 8),
		Label = Style.text({
			text = tierText,
			size = if phone then 11 else 12,
			color = Theme.color("textPrimary"),
			weight = Enum.FontWeight.Bold,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) },
		}),
	})
	chip:SetAttribute("tier", c.tier.name)
	-- loadout
	local gear = row("Loadout", 3, 10)
	gear.Parent = frame
	iconLabel(c.weapon.icon, c.weapon.name, if phone then 14 else 17, 1, "Weapon").Parent = gear
	iconLabel(c.armour.icon, c.armour.name, if phone then 14 else 17, 2, "Armour").Parent = gear
	-- reasons
	line("Why they cheer", if phone then 10 else 12, Theme.color("gold300"), Enum.FontWeight.Bold, 4, "ReasonsHeading").Parent =
		frame
	local reasons = Create("Frame", {
		Name = "Reasons",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = frame,
	}, { List = Style.list("y", 2, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	if c.noReasons then
		line(c.noReasons, if phone then 10 else 12, Theme.color("textMuted"), Enum.FontWeight.SemiBold, 1, "NoReasons").Parent =
			reasons
	end
	for i, r in c.reasons do
		line(
			`• {r}`,
			if phone then 10 else 12,
			Theme.color("textPrimary"),
			Enum.FontWeight.SemiBold,
			i,
			"Reason_" .. i,
			true
		).Parent =
			reasons
	end
	-- perks
	line("Perks", if phone then 10 else 12, Theme.color("gold300"), Enum.FontWeight.Bold, 6, "PerksHeading").Parent =
		frame
	-- one perk per line: three never overflow the half, even on a phone
	local perks = Create("Frame", {
		Name = "Perks",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 7,
	}, { List = Style.list("y", if phone then 3 else 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top) })
	perks.Parent = frame
	if c.noTriggers then
		line(c.noTriggers, if phone then 10 else 12, Theme.color("textMuted"), Enum.FontWeight.SemiBold, 1, "NoPerks").Parent =
			perks
	end
	for i, t in c.triggers do
		local perk = Create("Frame", {
			Name = "Perk_" .. t.id,
			BackgroundColor3 = Theme.color("ink900"),
			BackgroundTransparency = 0.25,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, if phone then 26 else 36),
			LayoutOrder = i,
		}, {
			Corner = Style.corner(8),
			Padding = Style.padding(0, 6, 0, 4),
			List = Style.list("x", 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		})
		local m = Icon.medallion(t.icon, if phone then 20 else 28, Theme.color("ink600"))
		m.LayoutOrder = 1
		m.Parent = perk
		local words = Create("Frame", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 2,
			Parent = perk,
		}, { List = Style.list("y", 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
		Style.text({
			text = t.name,
			size = if phone then 10 else 12,
			color = Theme.color("textPrimary"),
			weight = Enum.FontWeight.Bold,
			extra = { Name = "Name", AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 1, Parent = words },
		})
		if t.citizen then
			Style.text({
				text = t.citizen,
				size = if phone then 9 else 10,
				color = Theme.color("gold300"),
				weight = Enum.FontWeight.SemiBold,
				extra = { Name = "Citizen", AutomaticSize = Enum.AutomaticSize.XY, LayoutOrder = 2, Parent = words },
			})
		end
		perk.Parent = perks
	end
	return frame
end

function ArenaIntroCard:render(model: any, m: any)
	self:destroy()
	local phone = m.breakpoint == "phone"
	local width = if phone then m.width - 16 else math.min(ArenaIntroCard.DESKTOP.width, m.width - 32)
	local height = if phone
		then m.height - ArenaIntroCard.PHONE_TOP - 8
		else math.min(ArenaIntroCard.DESKTOP.height, m.height - 96)
	local card = Create("Frame", {
		Name = "Card",
		AnchorPoint = if phone then Vector2.new(0.5, 0) else Vector2.new(0.5, 0.5),
		Position = if phone then UDim2.new(0.5, 0, 0, ArenaIntroCard.PHONE_TOP) else UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.08,
		ZIndex = 2, -- above the scrim
	}, {
		Corner = Style.corner(14),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		Padding = Style.padding(if phone then 8 else 16),
	})
	local left = half(model.left, phone, "Side_left")
	left.Parent = card
	local right = half(model.right, phone, "Side_right")
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Parent = card
	local vs = Create("Frame", {
		Name = "Versus",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(if phone then 36 else 56, if phone then 36 else 56),
		BackgroundColor3 = Theme.color("ink800"),
		Parent = card,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("gold400"), 2),
		Label = Style.text({
			text = "VS",
			size = if phone then 14 else 20,
			color = Theme.color("gold300"),
			weight = Enum.FontWeight.ExtraBold,
			xAlign = "Center",
			extra = { Size = UDim2.fromScale(1, 1) },
		}),
	})
	vs.ZIndex = 2
	if model.clock then
		Style.text({
			text = model.clock,
			size = if phone then 12 else 14,
			color = Theme.color("gold300"),
			weight = Enum.FontWeight.ExtraBold,
			xAlign = "Center",
			extra = {
				Name = "Clock",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromOffset(if phone then 36 else 56, 18),
				Parent = card,
			},
		})
	end
	self.instance = Create("Frame", {
		Name = "ArenaIntro",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 18,
	}, {
		Scrim = Create("Frame", {
			BackgroundColor3 = Theme.color("scrim"),
			BackgroundTransparency = 0.5,
			Size = UDim2.fromScale(1, 1),
		}),
		Card = card,
	}) :: Frame
	self.instance.Parent = self._parent
end

function ArenaIntroCard:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
end

return ArenaIntroCard
