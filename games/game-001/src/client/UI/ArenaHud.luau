--!strict
--[[
	UI/ArenaHud — the duel HUD (FL-0073; design crown-arena.md §4-§5); the model is UI/ArenaHudModel. One strip at
	the top of the modal layer, under the Roblox top bar, so the bottom of the screen stays free for FORGE-04's duel
	buttons (InputModeArenaController.touchArea) and the crowd captions band (y 0.72-0.86):
		Side_left / Side_right   crest, name, the support tier chip (name and colour), the HP bar ("Hp", attribute
		                         `share`; red under 25 %, with "72%"), the stamina bar ("Stamina", attribute `share`;
		                         faded and empty until a snapshot), and the perk icons ("Perk_<id>", attribute `state`:
		                         armed dim, active gold with a glow, spent crossed out)
		Clock                    time left (red in the last 15 s), "Sudden death" when it applies
		Hints                    a champion on keyboard or gamepad: "Left click Light · R Heavy · …" under the strip
	The local champion is on the left (side a for a spectator); the right side is mirrored.
	ArenaHud.TOP (px from the top) and ArenaHud.height(metrics) give FORGE-04 the strip's bottom edge.

	ArenaHud.new(parent) -> view
	view:render(model, metrics)   view:destroy()   view.instance: Frame "ArenaHud"
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ArenaHud = {}
ArenaHud.__index = ArenaHud

ArenaHud.TOP = table.freeze({ desktop = 60, phone = 52 })
ArenaHud.WIDTH = 980
ArenaHud.CLOCK = table.freeze({ desktop = 84, phone = 56 })

-- The strip's height: name row, HP, stamina, perks, gaps and padding.
function ArenaHud.height(m: any): number
	return if m.breakpoint == "phone" then 70 else 96
end

function ArenaHud.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame? }, ArenaHud)
end

local function bar(name: string, share: number?, color: Color3, height: number, label: string?, flip: boolean): Frame
	local frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.1,
		Size = UDim2.new(1, 0, 0, height),
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("ink500"), 1),
	}) :: Frame
	frame:SetAttribute("share", share)
	if share ~= nil then
		Create("Frame", {
			Name = "Fill",
			AnchorPoint = Vector2.new(if flip then 1 else 0, 0),
			Position = UDim2.fromScale(if flip then 1 else 0, 0),
			Size = UDim2.fromScale(math.clamp(share, 0, 1), 1),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = frame,
		}, { Corner = Style.corner(999) })
	end
	if label then
		Style.text({
			text = label,
			size = math.max(9, height - 3),
			color = Theme.color("parchment100"),
			weight = Enum.FontWeight.ExtraBold,
			xAlign = "Center",
			extra = { Name = "Label", Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = frame },
		})
	end
	return frame
end

local function perkIcon(t: any, size: number, order: number): Frame
	local active = t.state == "active"
	local spent = t.state == "spent"
	local frame = Create("Frame", {
		Name = "Perk_" .. t.id,
		BackgroundColor3 = if active then Theme.color("gold500") else Theme.color("ink800"),
		BackgroundTransparency = if spent then 0.5 else 0,
		Size = UDim2.fromOffset(size, size),
		LayoutOrder = order,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(
			if active then Theme.color("gold300") else Theme.color("ink500"),
			if active then 2 else 1
		),
	}) :: Frame
	frame:SetAttribute("state", t.state)
	local icon = Icon.new(t.icon, math.floor(size * 0.7))
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	if spent and icon:IsA("TextLabel") then
		icon.TextTransparency = 0.6
	elseif spent and icon:IsA("ImageLabel") then
		icon.ImageTransparency = 0.6
	end
	icon.Parent = frame
	if spent then
		-- crossed out: the trigger fired and is done (shape, not colour alone)
		Create("Frame", {
			Name = "Spent",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = -45,
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Theme.color("textMuted"),
			BorderSizePixel = 0,
			Parent = frame,
		})
	end
	return frame
end

local function side(s: any, phone: boolean, width: number, flip: boolean, name: string): Frame
	local align = if flip then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left
	local frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = Theme.color("ink900"),
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(width, ArenaHud.height({ breakpoint = if phone then "phone" else "desktop" })),
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(s.color, 1.5, 0.15),
		Padding = Style.padding(if phone then 5 else 8, if phone then 8 else 10),
		List = Style.list("y", if phone then 3 else 5, align, Enum.VerticalAlignment.Top),
	}) :: Frame
	frame:SetAttribute("side", s.side)
	-- name row
	local head = Create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if phone then 16 else 22),
		LayoutOrder = 1,
		Parent = frame,
	}, { List = Style.list("x", 6, align, Enum.VerticalAlignment.Center) })
	local crest = Crest.new(if phone then 16 else 22, s.color, s.emblem or "crest")
	crest.LayoutOrder = if flip then 3 else 1
	crest.Parent = head
	Style.text({
		text = s.name,
		size = if phone then 12 else 15,
		color = Theme.color("textPrimary"),
		weight = Enum.FontWeight.ExtraBold,
		extra = {
			Name = "Name",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 2,
			Parent = head,
		},
	})
	local chip = Create("Frame", {
		Name = "Tier",
		BackgroundColor3 = s.tier.color,
		BackgroundTransparency = 0.7,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, if phone then 14 else 18),
		LayoutOrder = if flip then 1 else 3,
		Parent = head,
	}, {
		Corner = Style.corner(999),
		Padding = Style.padding(0, 6),
		Label = Style.text({
			text = s.tier.name,
			size = if phone then 9 else 11,
			color = Theme.color("textPrimary"),
			weight = Enum.FontWeight.Bold,
			extra = { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) },
		}),
	})
	chip:SetAttribute("tier", s.tier.name)
	-- bars
	local hp = bar(
		"Hp",
		s.hp,
		if s.low then Theme.color("gules") else Theme.color("vert"),
		if phone then 11 else 15,
		s.hpText,
		flip
	)
	hp.LayoutOrder = 2
	hp.Parent = frame
	local stamina = bar("Stamina", s.stamina, Theme.color("gold400"), if phone then 5 else 7, nil, flip)
	if s.stamina == nil then
		stamina.BackgroundTransparency = 0.6 -- not known yet (no snapshot): an empty, faded bar
	end
	stamina.LayoutOrder = 3
	stamina.Parent = frame
	-- perks
	local perks = Create("Frame", {
		Name = "Perks",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, if phone then 18 else 24),
		LayoutOrder = 4,
		Parent = frame,
	}, { List = Style.list("x", 4, align, Enum.VerticalAlignment.Center) })
	for i, t in s.triggers do
		perkIcon(t, if phone then 18 else 24, i).Parent = perks
	end
	if #s.triggers == 0 then
		Style.text({
			text = "No perks",
			size = if phone then 9 else 11,
			color = Theme.color("textMuted"),
			weight = Enum.FontWeight.SemiBold,
			extra = {
				Name = "NoPerks",
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Parent = perks,
			},
		})
	end
	return frame
end

function ArenaHud:render(model: any, m: any)
	self:destroy()
	local phone = m.breakpoint == "phone"
	local width = math.min(ArenaHud.WIDTH, m.width - 16)
	local clockW = if phone then ArenaHud.CLOCK.phone else ArenaHud.CLOCK.desktop
	local sideW = math.floor((width - clockW - 12) / 2)
	local strip = Create("Frame", {
		Name = "ArenaHud",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if phone then ArenaHud.TOP.phone else ArenaHud.TOP.desktop),
		Size = UDim2.fromOffset(width, ArenaHud.height(m)),
		ZIndex = 15,
	}) :: Frame
	side(model.left, phone, sideW, false, "Side_left").Parent = strip
	local right = side(model.right, phone, sideW, true, "Side_right")
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = UDim2.fromScale(1, 0)
	right.Parent = strip
	local clock = Create("Frame", {
		Name = "Clock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(clockW, if phone then 40 else 52),
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.1,
		Parent = strip,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		List = Style.list("y", 0, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	clock:SetAttribute("urgent", model.urgent)
	Style.text({
		text = model.clock or "",
		size = if phone then 16 else 22,
		color = Theme.color(if model.urgent then "gules" else "gold300"),
		weight = Enum.FontWeight.ExtraBold,
		xAlign = "Center",
		extra = { Name = "Time", Size = UDim2.new(1, 0, 0, if phone then 20 else 26), LayoutOrder = 1, Parent = clock },
	})
	Style.text({
		text = if model.suddenDeath then "Sudden death" else "Duel",
		size = if phone then 8 else 10,
		color = Theme.color(if model.suddenDeath then "gules" else "textSecondary"),
		weight = Enum.FontWeight.Bold,
		xAlign = "Center",
		extra = { Name = "Note", Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 2, Parent = clock },
	})
	-- the control hints (the champion, keyboard or gamepad; ArenaHudController decides when): one line under the
	-- strip. Never on touch, so a phone's strip bottom (y 122) stays clear of FORGE-04's captions (from y 135).
	if model.hints then
		Create("Frame", {
			Name = "Hints",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, ArenaHud.height(m) + 6),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			BackgroundColor3 = Theme.color("ink950"),
			BackgroundTransparency = 0.2,
			Parent = strip,
		}, {
			Corner = Style.corner(999),
			Padding = Style.padding(0, 12),
			Label = Style.text({
				text = model.hints,
				size = if phone then 11 else 13,
				color = Theme.color("parchment100"),
				weight = Enum.FontWeight.SemiBold,
				extra = { Name = "Text", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) },
			}),
		})
	end
	self.instance = strip
	strip.Parent = self._parent
end

function ArenaHud:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
end

return ArenaHud
