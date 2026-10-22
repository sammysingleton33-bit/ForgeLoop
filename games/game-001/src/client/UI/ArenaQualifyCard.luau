--!strict
--[[
	UI/ArenaQualifyCard — the banner for the Crown Arena's `qualify` stage (model: UI/ArenaQualifyModel). For every
	player, on the modal layer, with no scrim (the kingdom HUD stays usable for the five seconds):
		Title           "THE CROWN ARENA", the stage clock on the right
		Side_left/right crest, kingdom name, "30 Crown Points"; the local kingdom's side has a gold stroke
		Versus          the VS medallion between them
		Note            "Your kingdom fights for the crown" / "Two kingdoms fight for the crown"
	Desktop: top centre, under the phase pill (clear of the crest and pills top left and the rail on the right).
	Phones: a little below the middle (60 %), since the pill row reaches the middle of the top on a phone and wraps
	to two rows at 667 x 375.

	ArenaQualifyCard.new(parent) -> view
	view:render(model, metrics)   view:destroy()   view.instance: Frame "ArenaQualify"
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Crest = require("./Crest")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local ArenaQualifyCard = {}
ArenaQualifyCard.__index = ArenaQualifyCard

ArenaQualifyCard.DESKTOP = table.freeze({ width = 600, height = 132, top = 72 })
ArenaQualifyCard.PHONE = table.freeze({ width = 520, height = 120 })

function ArenaQualifyCard.new(parent: Instance)
	return setmetatable({ _parent = parent, instance = nil :: Frame? }, ArenaQualifyCard)
end

local function sideFrame(s: any, phone: boolean, name: string, right: boolean): Frame
	local frame = Create("Frame", {
		Name = name,
		AnchorPoint = if right then Vector2.new(1, 0.5) else Vector2.new(0, 0.5),
		Position = if right then UDim2.fromScale(1, 0.5) else UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0.5, if phone then -26 else -38, 1, 0),
		BackgroundColor3 = Theme.color("ink800"),
		BackgroundTransparency = 0.1,
	}, {
		Corner = Style.corner(10),
		Stroke = Style.stroke(Theme.color(if s.mine then "gold400" else "ink600"), if s.mine then 2 else 1),
		Padding = Style.padding(if phone then 6 else 8),
		List = Style.list(
			"x",
			if phone then 6 else 10,
			if right then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
			Enum.VerticalAlignment.Center
		),
	})
	local crest = Crest.new(if phone then 30 else 40, s.color, s.emblem)
	crest.LayoutOrder = if right then 2 else 1
	crest.Parent = frame
	local words = Create("Frame", {
		Name = "Words",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, if phone then -36 else -50, 1, 0),
		LayoutOrder = if right then 1 else 2,
		Parent = frame,
	}, {
		List = Style.list(
			"y",
			2,
			if right then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
			Enum.VerticalAlignment.Center
		),
	})
	local xAlign = if right then "Right" else "Left"
	Style.text({
		text = s.name,
		size = if phone then 14 else 18,
		color = Theme.color("textPrimary"),
		weight = Enum.FontWeight.ExtraBold,
		xAlign = xAlign,
		extra = { Name = "Name", Size = UDim2.new(1, 0, 0, if phone then 17 else 22), LayoutOrder = 1, Parent = words },
	})
	if s.points then
		Style.text({
			text = `{s.points} Crown Points`,
			size = if phone then 10 else 12,
			color = Theme.color("gold300"),
			weight = Enum.FontWeight.Bold,
			xAlign = xAlign,
			extra = { Name = "Points", Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Parent = words },
		})
	end
	return frame
end

function ArenaQualifyCard:render(model: any, m: any)
	self:destroy()
	local phone = m.breakpoint == "phone"
	local size = if phone then ArenaQualifyCard.PHONE else ArenaQualifyCard.DESKTOP
	local width = math.min(size.width, m.width - 16)
	local card = Create("Frame", {
		Name = "Card",
		AnchorPoint = if phone then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0),
		-- phones: below the pills, which wrap to two rows at 667 x 375
		Position = if phone then UDim2.fromScale(0.5, 0.6) else UDim2.new(0.5, 0, 0, ArenaQualifyCard.DESKTOP.top),
		Size = UDim2.fromOffset(width, size.height),
		BackgroundColor3 = Theme.color("ink950"),
		BackgroundTransparency = 0.06,
	}, {
		Corner = Style.corner(14),
		Stroke = Style.stroke(Theme.color("gold600"), 1.5),
		Padding = Style.padding(if phone then 8 else 12),
	})
	Style.text({
		text = "THE CROWN ARENA",
		size = if phone then 10 else 11,
		color = Theme.color("gold400"),
		weight = Enum.FontWeight.ExtraBold,
		xAlign = "Center",
		extra = { Name = "Title", Size = UDim2.new(1, 0, 0, 14), Parent = card },
	})
	if model.clock then
		Style.text({
			text = model.clock,
			size = if phone then 10 else 12,
			color = Theme.color("gold300"),
			weight = Enum.FontWeight.ExtraBold,
			xAlign = "Right",
			extra = { Name = "Clock", Size = UDim2.new(1, 0, 0, 14), Parent = card },
		})
	end
	local row = Create("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, 0, 1, -38),
		Parent = card,
	})
	sideFrame(model.left, phone, "Side_left", false).Parent = row
	sideFrame(model.right, phone, "Side_right", true).Parent = row
	Create("Frame", {
		Name = "Versus",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(if phone then 36 else 52, if phone then 36 else 52),
		BackgroundColor3 = Theme.color("ink800"),
		Parent = row,
	}, {
		Corner = Style.corner(999),
		Stroke = Style.stroke(Theme.color("gold400"), 2),
		Label = Style.text({
			text = "VS",
			size = if phone then 13 else 18,
			color = Theme.color("gold300"),
			weight = Enum.FontWeight.ExtraBold,
			xAlign = "Center",
			extra = { Size = UDim2.fromScale(1, 1) },
		}),
	})
	Style.text({
		text = model.note,
		size = if phone then 10 else 12,
		color = Theme.color("textSecondary"),
		weight = Enum.FontWeight.SemiBold,
		xAlign = "Center",
		extra = {
			Name = "Note",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 14),
			Parent = card,
		},
	})
	self.instance = Create("Frame", {
		Name = "ArenaQualify",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 18,
	}, {
		Card = card,
	}) :: Frame
	self.instance.Parent = self._parent
end

function ArenaQualifyCard:destroy()
	if self.instance then
		self.instance:Destroy()
		self.instance = nil
	end
end

return ArenaQualifyCard
