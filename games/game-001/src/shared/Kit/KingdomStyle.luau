--!strict
--[[
	Kit/KingdomStyle — one table that says how each kingdom builds (FL-0127 part 2, Operation Crownfall, D-053).

	From the overview camera (170 studs, 50° down) a kingdom has to read as its own place, and never by colour
	alone (D-033 (3)). The order of what reads: silhouette first, then colour value, then detail. Until now the
	four kingdoms differed by kingdom colour, tower cap and emblem; every wall, roof, plinth and banner was cut
	the same. This module is the single source for the rest:

		Emberhold  crimson  dark basalt stone, red tile on steep, tight roofs, tall merlons and turrets, big banners
		Frostmere  azure    pale cool stone, slate-blue tile with a snow ridge and deep eaves, long pennon banners
		Thornwood  emerald  timber and moss: ochre daub, dark oak framing, mossy stone and moss-striped green roofs
		Sunspire   gold     sandstone and whitewash, warm thatch, low flat-pitched roofs, round-tailed banners

	Keyed by `Parts.hueStyle(color)` (the same key as the tower caps and the emblem, so silhouette, emblem and
	architecture always agree); "neutral" is the Kit's original look and stays byte-for-byte what it was (outposts,
	uncaptured watchtowers, props). Pure data and pure functions: a building is a function of
	(type, level, stage, hue style, variant), nothing random, nothing yielding.

	Two ways the table reaches the builders, neither adds a part:
	- Geometry and colour decisions inside Pieces consult it through `ctx.style` (Buildings.build sets it):
	  roof pitch, overhang and gable reach, tile courses (snow, moss, ridge colour), merlon proportions, banner
	  tail shape and length, plinth accent stones, the stone family `Pieces.stoneFor` hands out, trim metal.
	- Everything else is painted in the neutral palette (`Parts.C`) and re-skinned in one pass by `paint`, so the
	  stand-ins, construction stages and any builder written later get the kingdom's materials without a call:
	  a part whose colour is a shade of a neutral palette role (stone, timber, wood, plaster, thatch) takes
	  the same shade of the kingdom's colour for that role. Kingdom-coloured parts (KitTint) are never touched, so
	  Kit.setKingdomColor still recolours exactly what it did.

	Budget rule (D-047): a style swaps colours, materials and proportions at the same part budget. It never adds
	or removes a part and never changes a footprint (Kit.footprint is pinned by the specs); tests/world/
	KitStyles.spec.luau checks that against the part counts the old look had.

	Phase B (plot surroundings) reads `ground` and `decor` from the same table.
]]

local Parts = require("./Parts")
local C = Parts.C

local M = Enum.Material

export type Stone = { base: Color3, light: Color3, dark: Color3, accent: Color3 }
export type RoofProfile = {
	tint: number, -- multiplier on the tint the builder asks for (kingdom roof colour = kingdom colour × tint)
	alt: number, -- shade of every second tile course (the Kit's original look: 0.86)
	altColor: Color3?, -- fixed colour for the second courses instead of the shaded kingdom colour (moss)
	capColor: Color3?, -- fixed colour of the course next to the ridge (snow)
	ridgeColor: Color3?, -- fixed colour of the ridge cap (default: the kingdom colour at 0.62)
	pitch: number, -- × the rise of every gable roof (tile and thatch)
	over: number, -- × the eave overhang along the slope
	gable: number, -- × the overhang past the gable walls
	material: Enum.Material,
}
export type Crop = { stalk: Color3, ear: Color3, light: Color3 }
export type BannerStyle = {
	tip: string, -- "point" (the Kit's diamond) | "long" (a stretched pennon tail) | "round" (a half-disc tail)
	length: number, -- × the cloth's hang
	tint: number, -- × the kingdom colour of the cloth (> 1 = bolder; emerald already flies 1.35)
}
export type Style = {
	id: string,
	stone: Stone,
	trim: Color3, -- finials, throne and gate metal, flame bowl
	timber: Color3,
	woodDark: Color3,
	wood: Color3,
	woodLight: Color3,
	plaster: Color3, -- the neutral plaster (239, 227, 200) takes this tone; its shades and variants follow
	thatch: Color3,
	thatchDark: Color3,
	crop: Crop, -- the field's grain: wheat stalks, ears and the lit ears (farm fields, sheaves, haystack, cart load)
	roof: RoofProfile,
	merlon: { w: number, h: number }, -- × the merlon size on keeps, walls, gates and towers (count unchanged)
	banner: BannerStyle,
	keepTurret: number, -- studs added to the keep's corner turret shafts (≤ 0: any taller shaft hides the roof plaque, KitEmblems gate)
	ground: { [string]: any }, -- Phase B: terrain palette under and around the plot
	decor: { [string]: any }, -- Phase B: the species mix near the plot
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local TRIM_NEUTRAL = rgb(236, 228, 210)

-- The Kit's original look, exactly. Every other style is a difference from this one.
local NEUTRAL: Style = {
	id = "neutral",
	stone = { base = C.stone, light = C.stoneLight, dark = C.stoneDark, accent = C.stoneLight },
	trim = TRIM_NEUTRAL,
	timber = C.timber,
	woodDark = C.woodDark,
	wood = C.wood,
	woodLight = C.woodLight,
	plaster = C.plaster,
	thatch = C.thatch,
	thatchDark = C.thatchDark,
	crop = { stalk = rgb(158, 146, 66), ear = C.wheat, light = rgb(250, 222, 128) },
	roof = { tint = 1, alt = 0.86, pitch = 1, over = 1, gable = 1, material = M.ClayRoofTiles },
	merlon = { w = 1, h = 1 },
	banner = { tip = "point", length = 1, tint = 1 },
	keepTurret = 0,
	ground = {},
	decor = {},
}

local STYLES: { [string]: Style } = {
	neutral = NEUTRAL,
	-- Emberhold: dark stone, red tile, steep and tight roofs, bold banners, tall menacing turrets
	crimson = {
		id = "crimson",
		stone = {
			base = rgb(104, 95, 92),
			light = rgb(146, 135, 128),
			dark = rgb(70, 64, 62),
			accent = rgb(50, 46, 46), -- charcoal stones in the plinths
		},
		trim = C.gold,
		timber = rgb(46, 31, 25),
		woodDark = rgb(60, 41, 31),
		wood = rgb(106, 70, 46),
		woodLight = rgb(138, 96, 64),
		plaster = rgb(224, 204, 176), -- sooty cream
		thatch = rgb(150, 126, 94),
		thatchDark = rgb(122, 98, 66),
		crop = { stalk = rgb(132, 102, 58), ear = rgb(208, 152, 72), light = rgb(228, 178, 94) }, -- dark rye
		roof = { tint = 1.06, alt = 0.8, pitch = 1.32, over = 0.8, gable = 0.8, material = M.ClayRoofTiles },
		merlon = { w = 0.82, h = 1.3 },
		banner = { tip = "point", length = 1.14, tint = 1.1 },
		keepTurret = 0,
		ground = {},
		decor = {},
	},
	-- Frostmere: pale stone, slate-blue roofs capped with snow, deep eaves, long pennon banners, stout keep
	azure = {
		id = "azure",
		stone = {
			base = rgb(198, 206, 218),
			light = rgb(232, 238, 246),
			dark = rgb(146, 156, 172),
			accent = rgb(244, 247, 250), -- snow-dusted stones
		},
		trim = rgb(226, 232, 240),
		timber = rgb(68, 62, 64),
		woodDark = rgb(82, 74, 74),
		wood = rgb(130, 110, 94),
		woodLight = rgb(166, 148, 128),
		plaster = rgb(240, 242, 245), -- cool white
		thatch = rgb(198, 192, 174),
		thatchDark = rgb(168, 162, 144),
		crop = { stalk = rgb(150, 150, 112), ear = rgb(226, 218, 176), light = rgb(244, 238, 206) }, -- pale oats
		roof = {
			tint = 0.9,
			alt = 0.88,
			capColor = rgb(242, 246, 250),
			ridgeColor = rgb(236, 241, 247),
			pitch = 1.12,
			over = 0.97,
			gable = 1.3,
			material = M.Slate,
		},
		merlon = { w = 1.14, h = 0.82 },
		banner = { tip = "long", length = 1, tint = 1 },
		keepTurret = -1.5,
		ground = {},
		decor = {},
	},
	-- Thornwood: timber and moss. Ochre daub in heavy dark framing, mossy stone, wide-eaved roofs with moss courses
	emerald = {
		id = "emerald",
		stone = {
			base = rgb(122, 134, 108),
			light = rgb(154, 168, 130),
			dark = rgb(84, 97, 74),
			accent = rgb(92, 132, 60), -- moss on the plinths
		},
		trim = rgb(214, 160, 82),
		timber = rgb(60, 41, 26),
		woodDark = rgb(76, 53, 32),
		wood = rgb(118, 82, 48),
		woodLight = rgb(148, 106, 64),
		plaster = rgb(198, 190, 148), -- wattle and daub
		thatch = rgb(130, 132, 78), -- mossy thatch
		thatchDark = rgb(100, 106, 58),
		crop = { stalk = rgb(112, 134, 58), ear = rgb(170, 184, 84), light = rgb(198, 210, 112) }, -- green barley
		roof = {
			tint = 1,
			alt = 0.86,
			altColor = rgb(78, 118, 58), -- moss courses between the kingdom-green ones
			pitch = 0.98,
			over = 0.97,
			gable = 1.5,
			material = M.ClayRoofTiles,
		},
		merlon = { w = 1.06, h = 1.0 },
		banner = { tip = "point", length = 1, tint = 1 },
		keepTurret = 0,
		ground = {},
		decor = {},
	},
	-- Sunspire: sandstone and whitewash, warm thatch, low roofs, round-tailed banners
	gold = {
		id = "gold",
		stone = {
			base = rgb(198, 170, 126),
			light = rgb(230, 210, 168),
			dark = rgb(154, 126, 90),
			accent = rgb(196, 128, 86), -- terracotta-banded stones
		},
		trim = rgb(112, 62, 150),
		timber = rgb(108, 74, 48),
		woodDark = rgb(126, 90, 58),
		wood = rgb(168, 124, 80),
		woodLight = rgb(200, 158, 106),
		plaster = rgb(250, 240, 216), -- whitewash
		thatch = rgb(210, 176, 116),
		thatchDark = rgb(184, 142, 78),
		crop = { stalk = rgb(172, 148, 58), ear = rgb(240, 198, 80), light = rgb(254, 228, 126) }, -- sun-ripe wheat
		roof = {
			tint = 0.98,
			alt = 0.84,
			ridgeColor = rgb(188, 112, 72), -- terracotta ridge
			pitch = 0.55,
			over = 0.97,
			gable = 1.3,
			material = M.ClayRoofTiles,
		},
		merlon = { w = 1.08, h = 0.8 },
		banner = { tip = "round", length = 1, tint = 1 },
		keepTurret = 0,
		ground = {},
		decor = {},
	},
}

local KingdomStyle = {}

KingdomStyle.STYLES = STYLES
KingdomStyle.NEUTRAL = NEUTRAL
-- the four kingdom hue styles, in the order the specs and the previews list them
KingdomStyle.KINGDOM_STYLES = { "crimson", "azure", "emerald", "gold" }

-- A hue style's table; neutral (or anything unknown) is the Kit's original look.
function KingdomStyle.get(style: string?): Style
	return STYLES[style or "neutral"] or NEUTRAL
end

-- ------------------------------------------------------------------ palette roles

-- The neutral palette colours a builder paints with, by role. `PLASTERS` are the three house plasters
-- Buildings.luau varies the wall tone with; they are listed so every house wall follows the kingdom's plaster.
local ROLE_REFS: { { role: string, ref: Color3 } } = {
	{ role = "stone", ref = C.stone },
	{ role = "stoneLight", ref = C.stoneLight },
	{ role = "stoneDark", ref = C.stoneDark },
	{ role = "timber", ref = C.timber },
	{ role = "woodDark", ref = C.woodDark },
	{ role = "wood", ref = C.wood },
	{ role = "woodLight", ref = C.woodLight },
	{ role = "plaster", ref = C.plaster },
	{ role = "plasterShade", ref = C.plasterShade },
	{ role = "plaster", ref = rgb(236, 219, 186) },
	{ role = "plaster", ref = rgb(244, 236, 218) },
	{ role = "plaster", ref = rgb(232, 214, 186) },
	{ role = "thatch", ref = C.thatch },
	{ role = "thatchDark", ref = C.thatchDark },
	{ role = "cropStalk", ref = rgb(158, 146, 66) }, -- Buildings.luau WHEAT_STALK
	{ role = "cropEar", ref = C.wheat },
	{ role = "cropLight", ref = rgb(250, 222, 128) }, -- Buildings.luau WHEAT_LIGHT
}
KingdomStyle.ROLE_REFS = ROLE_REFS

local MATCH_TOLERANCE = 0.0035 -- max channel error between a part's colour and k × a role's colour
-- the neutral plaster's channels, for the plaster family's per-channel gain
local PLASTER_REF = C.plaster

-- Which palette role is `c` a shade of, and by what factor (the builders shade palette colours: ×0.86, ×1.07 ...).
function KingdomStyle.roleOf(c: Color3): (string?, number)
	local bestRole, bestK, bestErr = nil, 1, MATCH_TOLERANCE
	for _, r in ROLE_REFS do
		local ref = r.ref
		local dot = c.R * ref.R + c.G * ref.G + c.B * ref.B
		local nn = ref.R * ref.R + ref.G * ref.G + ref.B * ref.B
		local k = dot / nn
		if k > 0.4 and k < 1.8 then
			local err = math.max(math.abs(c.R - k * ref.R), math.abs(c.G - k * ref.G), math.abs(c.B - k * ref.B))
			if err < bestErr then
				bestRole, bestK, bestErr = r.role, k, err
			end
		end
	end
	return bestRole, bestK
end

-- The colour a neutral-palette colour takes in a kingdom's style (c itself when it is no palette shade).
function KingdomStyle.skin(style: string?, c: Color3): Color3
	local st = STYLES[style or "neutral"]
	if not st or st == NEUTRAL then
		return c
	end
	local role, k = KingdomStyle.roleOf(c)
	if not role then
		return c
	end
	local target: Color3
	if role == "stone" then
		target = st.stone.base
	elseif role == "stoneLight" then
		target = st.stone.light
	elseif role == "stoneDark" then
		target = st.stone.dark
	elseif role == "plaster" or role == "plasterShade" then
		-- the plaster family keeps its own variation: a per-channel gain from the neutral plaster to the kingdom's
		local gain =
			Vector3.new(st.plaster.R / PLASTER_REF.R, st.plaster.G / PLASTER_REF.G, st.plaster.B / PLASTER_REF.B)
		return Color3.new(
			math.clamp(c.R * gain.X, 0, 1),
			math.clamp(c.G * gain.Y, 0, 1),
			math.clamp(c.B * gain.Z, 0, 1)
		)
	elseif role == "cropStalk" then
		target = st.crop.stalk
	elseif role == "cropEar" then
		target = st.crop.ear
	elseif role == "cropLight" then
		target = st.crop.light
	else
		target = (st :: any)[role]
	end
	return Color3.new(math.clamp(target.R * k, 0, 1), math.clamp(target.G * k, 0, 1), math.clamp(target.B * k, 0, 1))
end

-- Re-skins every untinted part of a freshly built model with the kingdom's palette. Idempotent per build (a
-- building is painted once, by Buildings.build); kingdom-coloured parts (KitTint) and emblems are left alone.
function KingdomStyle.paint(model: Instance, style: string?)
	local st = STYLES[style or "neutral"]
	if not st or st == NEUTRAL then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("KitTint") == nil then
			local c = KingdomStyle.skin(style, d.Color)
			if c ~= d.Color then
				d.Color = c
			end
		end
	end
end

-- ------------------------------------------------------------------ geometry helpers (Pieces)

-- A gable-roof spec with the kingdom's pitch, overhang and gable reach applied (the same table for neutral).
-- `over` is a factor on the eave overhang *seen from above*: a steeper roof keeps the neutral roof's plan
-- reach (× the factor), so a pitch change never pushes an eave out of the footprint.
function KingdomStyle.shapeRoof(style: string?, r: any, defaultOver: number, defaultGable: number): any
	local st = STYLES[style or "neutral"]
	if not st or st == NEUTRAL then
		return r
	end
	local p = st.roof
	local out = table.clone(r)
	local half = r.d / 2
	local slope0 = math.sqrt(half * half + r.rise * r.rise)
	local cos0 = half / slope0
	local rise = r.rise * p.pitch
	local cos1 = half / math.sqrt(half * half + rise * rise)
	out.rise = rise
	out.over = (r.over or defaultOver) * p.over * cos0 / cos1
	out.gable = (r.gable or defaultGable) * (if r.tight then math.min(p.gable, 1) else p.gable)
	-- the tile courses a roof gets follow the neutral slope, so a steeper roof stretches its courses
	-- instead of growing more of them: a style never changes the part count (D-047)
	out.rows = r.rows or math.max(2, math.floor((slope0 + (r.over or defaultOver)) / 2.4 + 0.5))
	return out
end

return KingdomStyle
