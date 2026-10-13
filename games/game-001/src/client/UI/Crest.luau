--!strict
--[[
	UI/Crest — a kingdom's crest: a rounded shield tile in the kingdom colour with its emblem
	(HudModel.EMBLEMS) and a gold trim. Used by the HUD badge, the Kingdom panel and the standings.

		Crest.new(size, color: Color3, emblem: string) -> Frame   (Name "Crest")
		Crest.recolor(crest, color)                               after Kingdom.State changes
		Crest.backdrop(color) -> Color3          what the emblem sits on: the tile, or on a light tile
		                                         (gold #EBB910, D-033) an ivory roundel "Plate" with a
		                                         bronze rim, as FORGE-02's world banners do
		Crest.emblemColor(color) -> Color3       light on dark tiles, dark (bronze) on the ivory plate
		Crest.contrast(a, b) -> number           WCAG contrast ratio of two colours (1..21)
	Crown, oak leaf and sun are drawn, not typed, to match FORGE-02's world banners (ART_DIRECTION
	§3: crown, star, oak leaf, sun) on every platform: emoji glyphs differ per platform and ignore
	text colour (the ☀ vanished on gold, FORGE-05 on #79). The sun is eight pointed dark-gold rays
	around an ochre disc; crown and leaf take the emblem colour. The star stays a text glyph (★ takes
	TextColor3). An uploaded emblem image (UITheme icons) replaces any drawing.
		Crest.sunburst(px) / Crest.crown(px) / Crest.oakLeaf(px) -> Frame "Emblem"
		                                         (attribute `drawn`; parts with attribute `fill`)
	Every emblem keeps at least 3:1 against what it sits on, for every kingdom colour (WCAG 1.4.11,
	graphics); the name beside a crest carries the identity too (D-033: never colour alone).
]]

local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Icon = require("@game/ReplicatedStorage/Forge/UI/Icon")
local Style = require("@game/ReplicatedStorage/Forge/UI/Style")
local Theme = require("@game/ReplicatedStorage/Forge/UI/Theme")

local Crest = {}

-- Relative luminance (sRGB, WCAG 2).
local function luminance(c: Color3): number
	local function linear(v: number): number
		return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * linear(c.R) + 0.7152 * linear(c.G) + 0.0722 * linear(c.B)
end

function Crest.contrast(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

-- Light tiles (gold) put the emblem on an ivory roundel; the canonical crimson, azure and emerald
-- are dark (luminance < 0.2) and need none.
Crest.LIGHT = 0.3
Crest.PLATE = 0.82 -- the roundel's diameter, as a share of the crest

function Crest.isLight(color: Color3): boolean
	return luminance(color) > Crest.LIGHT
end

function Crest.backdrop(color: Color3): Color3
	return if Crest.isLight(color) then Theme.color("parchment100") else color
end

function Crest.emblemColor(color: Color3): Color3
	return if Crest.isLight(color) then Theme.color("gold700") else Theme.color("textPrimary")
end

local function setPlate(crest: Instance, color: Color3)
	local plate = crest:FindFirstChild("Plate")
	if Crest.isLight(color) and plate == nil then
		Create("Frame", {
			Name = "Plate",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(Crest.PLATE, Crest.PLATE),
			BackgroundColor3 = Theme.color("parchment100"),
			ZIndex = 1,
			Parent = crest,
		}, {
			Corner = Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			Rim = Style.stroke(Theme.color("gold700"), 1.5),
		})
	elseif not Crest.isLight(color) and plate then
		plate:Destroy()
	end
	local emblem = crest:FindFirstChild("Emblem")
	if emblem and emblem:IsA("TextLabel") then
		emblem.TextColor3 = Crest.emblemColor(color)
	elseif emblem then
		for _, piece in emblem:GetChildren() do
			if piece:GetAttribute("fill") then
				(piece :: Frame).BackgroundColor3 = Crest.emblemColor(color)
			end
		end
	end
end

-- Drawn emblems match FORGE-02's world banners (ART_DIRECTION §3: crown, star, oak leaf, sun). Parts
-- marked `fill` take Crest.emblemColor of the tile, so a recolour repaints them.
local function part(parent: Instance, name: string, props: { [string]: any }, round: boolean?): Frame
	local frame = Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 2,
		Position = props.Position,
		Size = props.Size,
		Rotation = props.Rotation or 0,
		BackgroundColor3 = props.BackgroundColor3,
		BackgroundTransparency = props.BackgroundTransparency or 0,
		Parent = parent,
	})
	if round then
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = frame })
	end
	return frame
end

-- A part in the emblem colour; Crest.new and Crest.recolor paint it for the tile (setPlate).
local function filled(frame: Frame): Frame
	frame.BackgroundColor3 = Theme.color("textPrimary")
	frame:SetAttribute("fill", true)
	return frame
end

local function emblemFrame(size: number, drawn: string): Frame
	local frame = Create("Frame", {
		Name = "Emblem",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 2,
	})
	frame:SetAttribute("drawn", drawn)
	return frame
end

-- A ray is a stack of bars, each narrower and reaching further out, all starting under the disc:
-- a stepped taper that ends in a point (Frames have no triangles). { outer radius, width } as shares
-- of the emblem; the disc is 0.55 of the ray radius, as on the world banners.
Crest.RAY_STEPS = table.freeze({
	{ 0.34, 0.16 },
	{ 0.37, 0.13 },
	{ 0.4, 0.1 },
	{ 0.43, 0.075 },
	{ 0.465, 0.05 },
	{ 0.5, 0.025 },
})
Crest.RAY_INNER = 0.22
Crest.DISC = 0.55

-- Gold's sun: eight pointed dark-gold rays around an ochre disc, so it reads on the ivory roundel.
function Crest.sunburst(size: number): Frame
	local sun = emblemFrame(size, "sunburst")
	for i = 0, 7 do
		local angle = i * 45
		local a = math.rad(angle)
		for k, step in Crest.RAY_STEPS do
			local outer, width = step[1], step[2]
			local mid = (outer + Crest.RAY_INNER) / 2
			part(sun, `Ray_{i}_{k}`, {
				Position = UDim2.fromScale(0.5 + mid * math.cos(a), 0.5 + mid * math.sin(a)),
				Size = UDim2.fromScale(outer - Crest.RAY_INNER, width),
				Rotation = angle,
				BackgroundColor3 = Theme.color("gold700"),
			})
		end
	end
	local disc = part(sun, "Disc", {
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(Crest.DISC, Crest.DISC),
		BackgroundColor3 = Theme.color("gold600"),
		ZIndex = 3,
	}, true)
	Style.stroke(Theme.color("gold700"), 1).Parent = disc
	return sun
end

-- Emberhold's crown: a band, a body and three points (diamonds) with a pearl on each tip.
function Crest.crown(size: number): Frame
	local crown = emblemFrame(size, "crown")
	filled(part(crown, "Band", { Position = UDim2.fromScale(0.5, 0.75), Size = UDim2.fromScale(0.72, 0.14) }))
	filled(part(crown, "Body", { Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.72, 0.24) }))
	-- a seam between body and band, in ink, so the band reads at any fill
	part(crown, "Seam", {
		Position = UDim2.fromScale(0.5, 0.675),
		Size = UDim2.fromScale(0.72, 0.03),
		BackgroundColor3 = Theme.color("ink900"),
		BackgroundTransparency = 0.45,
		ZIndex = 3,
	})
	local points = { { 0.22, 0.44, 0.2 }, { 0.5, 0.4, 0.24 }, { 0.78, 0.44, 0.2 } }
	for i, p in points do
		local x, y, side = p[1], p[2], p[3]
		filled(part(crown, `Point_{i}`, {
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(side, side),
			Rotation = 45,
		}))
		local tip = y - side * math.sqrt(2) / 2
		filled(part(crown, `Pearl_{i}`, { Position = UDim2.fromScale(x, tip), Size = UDim2.fromScale(0.1, 0.1) }, true))
	end
	return crown
end

-- Thornwood's oak leaf: rounded lobes in pairs down a slim core, a stem and an ink midrib, tilted
-- like the leaf on the world banners (upright, with its stem, it read as a tree).
Crest.LEAF_TILT = 35
local LEAF = {
	-- { name, x, y, width, height, round }: drawn upright around (0.5, 0.5), then tilted
	-- lobes wide and set out from a slim core, so the notches between them stay deep enough to
	-- read as an oak leaf at 22 px (a narrow leaf reads as a feather; FORGE-02 on #86)
	{ "Core", 0.5, 0.44, 0.16, 0.62, true },
	{ "Tip", 0.5, 0.11, 0.17, 0.17, true },
	{ "Lobe_L1", 0.38, 0.26, 0.19, 0.19, true },
	{ "Lobe_R1", 0.62, 0.26, 0.19, 0.19, true },
	{ "Lobe_L2", 0.35, 0.44, 0.23, 0.23, true },
	{ "Lobe_R2", 0.65, 0.44, 0.23, 0.23, true },
	{ "Lobe_L3", 0.37, 0.62, 0.2, 0.2, true },
	{ "Lobe_R3", 0.63, 0.62, 0.2, 0.2, true },
	{ "Base", 0.5, 0.74, 0.14, 0.14, true },
	{ "Stem", 0.5, 0.84, 0.05, 0.18, false },
}

function Crest.oakLeaf(size: number): Frame
	local leaf = emblemFrame(size, "oakleaf")
	local t = math.rad(Crest.LEAF_TILT)
	local function tilted(x: number, y: number): UDim2
		local dx, dy = x - 0.5, y - 0.5
		return UDim2.fromScale(0.5 + dx * math.cos(t) - dy * math.sin(t), 0.5 + dx * math.sin(t) + dy * math.cos(t))
	end
	for _, l in LEAF do
		filled(part(leaf, l[1], {
			Position = tilted(l[2], l[3]),
			Size = UDim2.fromScale(l[4], l[5]),
			Rotation = Crest.LEAF_TILT,
		}, l[6]))
	end
	part(leaf, "Midrib", {
		Position = tilted(0.5, 0.46),
		Size = UDim2.fromScale(0.03, 0.54),
		Rotation = Crest.LEAF_TILT,
		BackgroundColor3 = Theme.color("ink900"),
		BackgroundTransparency = 0.45,
		ZIndex = 3,
	})
	return leaf
end

local function gradient(color: Color3): ColorSequence
	return ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.3))
end

function Crest.new(size: number, color: Color3, emblem: string): Frame
	local icon: GuiObject
	local px = math.floor(size * 0.66)
	local hasImage = Icon.hasImage(emblem) -- an uploaded emblem image wins over the drawing
	if emblem == "emblem_sun" and not hasImage then
		icon = Crest.sunburst(px)
	elseif emblem == "emblem_crown" and not hasImage then
		icon = Crest.crown(px)
	elseif emblem == "emblem_oak" and not hasImage then
		icon = Crest.oakLeaf(px)
	else
		icon = Icon.new(emblem, px)
		icon.Name = "Emblem"
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.ZIndex = 2
	end
	local crest = Create("Frame", {
		Name = "Crest",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(size, size),
	}, {
		Corner = Style.corner(if size >= 40 then 12 else 6),
		Stroke = Style.stroke(Theme.color("gold500"), if size >= 40 then 2 else 1.5),
		Gradient = Create("UIGradient", { Rotation = 90, Color = gradient(color) }),
		Emblem = icon,
	})
	setPlate(crest, color)
	return crest
end

function Crest.recolor(crest: Instance, color: Color3)
	local g = crest:FindFirstChild("Gradient")
	if g and g:IsA("UIGradient") then
		g.Color = gradient(color)
	end
	setPlate(crest, color)
end

return table.freeze(Crest)
