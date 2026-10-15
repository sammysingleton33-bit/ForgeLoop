--!strict
--[[
	Kit/Pieces — shared architecture pieces (FORGE-02, FL-0054 v0): the building language of
	blender/ART_DIRECTION.md §4 rebuilt from primitive parts (D-026: Block, Wedge, CornerWedge,
	Cylinder, Ball; nothing yields).

	Conventions
	- Wall-mounted pieces (doors, windows, frame walls) take a CFrame `cf` on the wall face: origin at the
	  bottom centre of the opening, local -Z pointing out of the wall, +Y up.
	- Roofs take a RoofSpec; the ridge runs along the spec's local X (spec.cf, default world X).
	- Kingdom colour: a piece that takes `color` + `tint` builds shade(color, tint) and stores KitTint, so
	  Kit.setKingdomColor recolours it in place. Pass the raw kingdom colour, never a pre-shaded one.
	- Kingdom emblems (D-039): every banner, flag, pennant, shield and aerial plaque carries one, built by
	  `emblem` on its field part (see "kingdom emblems" below); Kit.setKingdomColor re-forms them.
	- Jitter is deterministic (no Random): the same arguments always build the same model.
]]

local Parts = require("./Parts")
local C = Parts.C
local shade = Parts.shade
local finish = Parts.finish
local block = Parts.block
local wedge = Parts.wedge
local cornerWedge = Parts.cornerWedge
local column = Parts.column
local log = Parts.log
local ball = Parts.ball
local hueStyle = Parts.hueStyle

type Ctx = Parts.Ctx

export type Stone = { base: Color3, light: Color3, dark: Color3 }
export type Opening = { u: number, hw: number, door: boolean? }
export type RoofSpec = {
	w: number, -- length along the ridge (the wall length under it)
	d: number, -- span across the ridge (the wall depth under it)
	y: number, -- wall-top height
	rise: number, -- ridge height above y
	cf: CFrame?, -- plan frame (position + yaw only; y must be 0); ridge along its local X
	over: number?, -- eave overhang along the slope
	gable: number?, -- overhang past the gable walls
	rows: number?, -- tile courses per side
	color: Color3, -- kingdom colour when tint is set, else the material colour
	tint: number?,
	trim: Color3?, -- barge boards
	infill: Color3?, -- gable triangles (nil = none)
	infillMaterial: Enum.Material?,
	kingPost: boolean?,
	ends: number?, -- nil/0 = both gable ends, 1 = only the local +X end (dormers)
}
export type RoofInfo = { ridgeY: number, theta: number, slope: number, width: number }
export type WindowOpts = {
	w: number?,
	h: number?,
	shutters: Color3?, -- kingdom colour (tinted 0.85)
	arched: boolean?,
	frame: Color3?,
	frameMaterial: Enum.Material?,
	box: boolean?, -- flower box instead of a plain sill
	simple: boolean?, -- frame + glass + mullion + sill only
	bare: boolean?, -- frame + glass only (castle arches seen from afar)
	slit: boolean?, -- arrow slit (2 parts)
}
export type DoorOpts = {
	w: number?,
	h: number?,
	leaf: Color3?, -- raw kingdom colour when leafTint is set
	leafTint: number?,
	stone: Color3?,
	stoneLight: Color3?,
	voussoirs: number?,
	step: number?, -- stoop height below the door sill (0 = none)
	straps: boolean?, -- iron straps on the leaf (default true; the keep's door hides behind the throne's dossal)
}

local Pieces = {}

local M = Enum.Material
local PI = math.pi
local rad = math.rad

-- ------------------------------------------------------------------ palettes (ART_DIRECTION §3)

local STONE: { [string]: Stone } = {
	neutral = { base = C.stone, light = C.stoneLight, dark = C.stoneDark },
	crimson = {
		base = Color3.fromRGB(161, 146, 134),
		light = Color3.fromRGB(196, 182, 166),
		dark = Color3.fromRGB(118, 105, 96),
	},
	azure = {
		base = Color3.fromRGB(139, 149, 162),
		light = Color3.fromRGB(178, 188, 201),
		dark = Color3.fromRGB(99, 108, 121),
	},
	emerald = {
		base = Color3.fromRGB(137, 146, 124),
		light = Color3.fromRGB(173, 181, 157),
		dark = Color3.fromRGB(98, 107, 89),
	},
	gold = {
		base = Color3.fromRGB(199, 172, 128),
		light = Color3.fromRGB(226, 205, 163),
		dark = Color3.fromRGB(156, 128, 92),
	},
}

-- trim metal / emblem colour per kingdom: gold, silver, bronze, royal purple (+ ivory)
local TRIM: { [string]: Color3 } = {
	neutral = Color3.fromRGB(236, 228, 210),
	crimson = C.gold,
	azure = Color3.fromRGB(226, 232, 240),
	emerald = Color3.fromRGB(214, 160, 82),
	gold = Color3.fromRGB(112, 62, 150),
}
local IVORY = Color3.fromRGB(240, 232, 212)
-- emerald banners/flags: lighter, high-saturation tint (KitTint > 1) with a cream border
local EMERALD_LIGHT = 1.35
local POT = Color3.fromRGB(184, 98, 64)
local FLOWERS = { Color3.fromRGB(226, 72, 92), Color3.fromRGB(246, 206, 70), Color3.fromRGB(176, 108, 214) }

local function stoneFor(style: string): Stone
	return STONE[style] or STONE.neutral
end

local function trimFor(style: string): Color3
	return TRIM[style] or TRIM.neutral
end

-- Deterministic jitter in [-amp, amp].
local function jit(seed: number, amp: number): number
	local x = math.sin(seed * 12.9898 + 4.1414) * 43758.5453
	return ((x - math.floor(x)) * 2 - 1) * amp
end

-- ------------------------------------------------------------------ primitives on a CFrame

-- Cylinder whose axis is the local X of cf.
local function cyl(
	ctx: Ctx,
	name: string,
	cf: CFrame,
	length: number,
	dia: number,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, dia, dia)
	p.CFrame = cf
	return finish(p, ctx, name, color, material or M.SmoothPlastic, tint)
end

-- Disc facing along the local Z of cf (axis = Z).
local function disc(
	ctx: Ctx,
	name: string,
	cf: CFrame,
	dia: number,
	thick: number,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	return cyl(ctx, name, cf * CFrame.Angles(0, PI / 2, 0), thick, dia, color, material, tint)
end

-- Block spanning a segment (u1, v1) → (u2, v2) in the XY plane of cf (braces, rafters, ladder rails).
local function strut(
	ctx: Ctx,
	name: string,
	cf: CFrame,
	u1: number,
	v1: number,
	u2: number,
	v2: number,
	thick: number,
	depth: number,
	color: Color3,
	material: Enum.Material?,
	z: number?
)
	local du, dv = u2 - u1, v2 - v1
	local len = math.sqrt(du * du + dv * dv)
	return block(
		ctx,
		name,
		Vector3.new(len, thick, depth),
		cf * CFrame.new((u1 + u2) / 2, (v1 + v2) / 2, z or 0) * CFrame.Angles(0, 0, math.atan2(dv, du)),
		color,
		material or M.Wood
	)
end

-- Horizontal beam between two points (fences, rails).
local function beamBetween(
	ctx: Ctx,
	name: string,
	a: Vector3,
	b: Vector3,
	thick: number,
	color: Color3,
	material: Enum.Material?
)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	return block(ctx, name, Vector3.new(thick, thick, len), CFrame.lookAt(mid, b), color, material or M.Wood)
end

-- WedgePart whose right triangle lies in the XY plane of cf: right angle at a, legs to b and c (Vector2 in
-- cf's X/Y), extruded `thick` along cf's Z and centred at depth z (negative = out of the face, toward -Z).
local function triangle(
	ctx: Ctx,
	name: string,
	cf: CFrame,
	a: Vector2,
	b: Vector2,
	c: Vector2,
	z: number,
	thick: number,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	local ab, ac = b - a, c - a
	local ly, lz = ab.Magnitude, ac.Magnitude
	-- a WedgePart's right angle sits at local (-Y, +Z): its +Y leg runs to b, its -Z leg to c
	local yAxis = Vector3.new(ab.X / ly, ab.Y / ly, 0)
	local zAxis = Vector3.new(-ac.X / lz, -ac.Y / lz, 0)
	local mid = (b + c) / 2 -- the box centre is the hypotenuse midpoint
	local p = Instance.new("WedgePart")
	p.Size = Vector3.new(thick, ly, lz)
	p.CFrame = cf * CFrame.fromMatrix(Vector3.new(mid.X, mid.Y, z), yAxis:Cross(zAxis), yAxis, zAxis)
	return finish(p, ctx, name, color, material or M.SmoothPlastic, tint)
end

-- ------------------------------------------------------------------ kingdom emblems (D-033, D-039)

-- One shared builder for every emblem in the world: banners, flags, pennants, shields, the keep's aerial
-- plaques, prop banners and slot signs. The kind follows the colour (Parts.emblemKind, the same hue map as
-- the tower caps): crimson crown, azure star, emerald oak leaf, gold sun; neutral none. Large, simple
-- silhouettes from a few primitive parts (D-026), ivory on the kingdom field, except the sun: on the light
-- gold field an ivory sun has no contrast, so it is deep gold (as in the Blender bible). Every emblem part
-- differs from its field by ΔL* ≥ 25 (KitEmblems.spec).
--   crown 3: two tall wedges (outer edges upright, slopes meeting at the base centre) + a diamond whose lower
--            half fills the band; three points, notches at 2/3 of the height
--   star  5: five 36-54-90 wedges in a pinwheel; their union is exactly the regular five-pointed star
--   oak   5: compact: two stacked round lobes tapering through a diamond into a short ivory stem, and a short
--            darker midrib (from the stem to mid-leaf)
--         8: full (aerial plaques): a slim core, the tip and two lobe pairs, stem and midrib (the UI's lobed leaf);
--            the leaf in bend (tilted 35°) so it never reads as a tree
--   sun   4: compact: two squares (8 pointed rays) + a field-colour ring + the disc
--         9: full (aerial plaques): the disc + 8 separate wedge rays
local EMBLEM_IVORY = Color3.fromRGB(240, 232, 212)
local SUN_TINT = 0.42 -- the sun is shade(kingdom colour, 0.42): deep gold on the gold field
local RIB_TINT = 0.6 -- the oak's midrib and stem
local EMBLEM_GAP = 0.03 -- the first part's back face sits this far out of the field face (never coplanar)
local EMBLEM_T = 0.08 -- part thickness
-- every further part sits this much further out than the one before it (build order = stacking order), so no
-- two emblem faces are coplanar where they overlap: no z-fighting in Studio, no shading seams in renders
local EMBLEM_STEP = 0.015
local SQRT2 = math.sqrt(2)

-- Emblems are decoration: never collide, touch, catch a raycast or cast a shadow on their own field.
local function emblemPart(p: BasePart, kind: string, slot: number, accent: boolean?): BasePart
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p:SetAttribute("KitEmblem", kind)
	p:SetAttribute("KitEmblemSlot", slot)
	if accent then
		p:SetAttribute("KitEmblemAccent", true) -- detail in a field-derived shade (oak midrib, sun ring)
	end
	return p
end

-- Builds one emblem of `kind` centred on cf (local -Z out of the field face, +Y up the emblem), filling a
-- `size` box. fieldTint: the field's KitTint (the compact sun's ring repeats the field colour).
local function buildEmblem(
	ctx: Ctx,
	cf: CFrame,
	size: number,
	kind: string,
	color: Color3,
	fieldTint: number,
	detail: string,
	slot: number
): { BasePart }
	local out = {}
	local s = size
	local stack = 0
	local function z(): number -- depth of the next part: in front of every part built before it
		stack += 1
		return -(EMBLEM_GAP + EMBLEM_T / 2 + (stack - 1) * EMBLEM_STEP)
	end
	local function add(p: BasePart, accent: boolean?)
		table.insert(out, emblemPart(p, kind, slot, accent))
	end
	local function v(x: number, y: number): Vector2
		return Vector2.new(x * s, y * s)
	end
	if kind == "crown" then
		local y0, y1, y2 = -0.36, 0.26, 0.36
		for _, sx in { -1, 1 } do
			add(
				triangle(
					ctx,
					"EmblemPoint",
					cf,
					v(sx * 0.5, y0),
					v(sx * 0.5, y1),
					v(0, y0),
					z(),
					EMBLEM_T,
					EMBLEM_IVORY
				)
			)
		end
		local hd = (y2 - y0) / 2
		add(
			block(
				ctx,
				"Emblem",
				Vector3.new(hd * s * SQRT2, hd * s * SQRT2, EMBLEM_T),
				cf * CFrame.new(0, (y0 + hd) * s, z()) * CFrame.Angles(0, 0, PI / 4),
				EMBLEM_IVORY
			)
		)
	elseif kind == "star" then
		local R, r = 0.5, 0.5 * 0.381966
		local dy = -(R - R * math.cos(rad(36))) / 2 -- centre the star's box
		local function at(deg: number, radius: number): Vector2
			return Vector2.new(math.cos(rad(deg)) * radius, math.sin(rad(deg)) * radius + dy) * s
		end
		for k = 0, 4 do
			local t = 90 + 72 * k
			local tip, far = at(t, R), at(t + 144, R)
			-- right angle at the midpoint of the tip's star line; the far leg reaches the opposite inner vertex
			add(triangle(ctx, "EmblemPoint", cf, (tip + far) / 2, tip, at(t - 108, r), z(), EMBLEM_T, EMBLEM_IVORY))
		end
	elseif kind == "oak" then
		-- the leaf lies in bend (seen from the front: stem lower left, tip upper right; local +X shows on the
		-- viewer's left, so the turn is +35°). Upright, the aerial view's foreshortening made it a lollipop tree.
		-- A thin ivory stem below the leaf (a dark stem vanished on the dark field: "a blob with a line", colour-vision
		-- run 4) and a short dark midrib from the stem up the lower leaf, as on the UI's Crest.oakLeaf.
		local leaf = cf * CFrame.Angles(0, 0, rad(35))
		local full = detail == "full"
		-- { x, y, diameter } discs in leaf units (y along the leaf). Compact (flags, banners, pennants, shields: 5–25
		-- px): two stacked lobes tapering through a diamond into the stem, which reads as a leaf at 12 px (three
		-- round lobes read as a cloud or a clover). Full (the aerial plaques, 21–59 px): a slim core with the tip
		-- and two lobe pairs set out from it, so the oak's notches read from 26 px.
		local oy = if full then 0.02 else 0.045
		if full then
			add(
				block(
					ctx,
					"EmblemCore",
					Vector3.new(0.15 * s, 0.62 * s, EMBLEM_T),
					leaf * CFrame.new(0, (0.04 + oy) * s, z()),
					EMBLEM_IVORY
				)
			)
		end
		local lobes = if full
			then {
				{ 0, 0.36, 0.18 },
				{ -0.11, 0.23, 0.19 },
				{ 0.11, 0.23, 0.19 },
				{ -0.14, 0.04, 0.23 },
				{ 0.14, 0.04, 0.23 },
			}
			else { { 0, 0.22, 0.32 }, { 0, -0.02, 0.36 } }
		for i, l in lobes do
			add(
				disc(
					ctx,
					if i == 1 then "Emblem" else "EmblemLobe",
					leaf * CFrame.new(l[1] * s, (l[2] + oy) * s, z()),
					l[3] * s,
					EMBLEM_T,
					EMBLEM_IVORY
				)
			)
		end
		if not full then
			local d = 0.22 * s
			add(
				block(
					ctx,
					"EmblemBase",
					Vector3.new(d, d, EMBLEM_T),
					leaf * CFrame.new(0, (-0.2 + oy) * s, z()) * CFrame.Angles(0, 0, PI / 4),
					EMBLEM_IVORY
				)
			)
		end
		local stemL, stemY = if full then 0.26 else 0.18, if full then -0.36 else -0.38
		add(
			block(
				ctx,
				"EmblemStem",
				Vector3.new(math.max(0.055 * s, 0.1), stemL * s, EMBLEM_T),
				leaf * CFrame.new(0, (stemY + oy) * s, z()),
				EMBLEM_IVORY
			)
		)
		local ribL, ribY = if full then 0.32 else 0.3, if full then -0.12 else -0.12
		add(
			block(
				ctx,
				"EmblemRib",
				Vector3.new(math.max(0.03 * s, 0.08), ribL * s, EMBLEM_T),
				leaf * CFrame.new(0, (ribY + oy) * s, z()),
				shade(color, RIB_TINT),
				M.SmoothPlastic,
				RIB_TINT
			),
			true
		)
	elseif kind == "sun" then
		local dark = shade(color, SUN_TINT)
		if detail == "full" then
			add(disc(ctx, "Emblem", cf * CFrame.new(0, 0, z()), 0.5 * s, EMBLEM_T, dark, M.SmoothPlastic, SUN_TINT))
			local rin, R, b = 0.31, 0.5, 0.15
			for i = 0, 7 do
				local a = rad(90 + 45 * i)
				local u, w = Vector2.new(math.cos(a), math.sin(a)), Vector2.new(math.sin(a), -math.cos(a))
				local base = u * rin - w * (b / 2)
				add(
					triangle(
						ctx,
						"EmblemRay",
						cf,
						base * s,
						(base + u * (R - rin)) * s,
						(base + w * b) * s,
						z(),
						EMBLEM_T,
						dark,
						M.SmoothPlastic,
						SUN_TINT
					)
				)
			end
		else
			local Rt = 0.49
			for _, a in { 0, 45 } do
				add(
					block(
						ctx,
						"EmblemRay",
						Vector3.new(Rt * SQRT2 * s, Rt * SQRT2 * s, EMBLEM_T),
						cf * CFrame.new(0, 0, z()) * CFrame.Angles(0, 0, rad(a)),
						dark,
						M.SmoothPlastic,
						SUN_TINT
					)
				)
			end
			add(
				disc(
					ctx,
					"EmblemRing",
					cf * CFrame.new(0, 0, z()),
					2 * (0.765 * Rt + 0.01) * s,
					EMBLEM_T,
					shade(color, fieldTint),
					M.SmoothPlastic,
					fieldTint
				),
				true
			)
			add(disc(ctx, "Emblem", cf * CFrame.new(0, 0, z()), 0.54 * s, EMBLEM_T, dark, M.SmoothPlastic, SUN_TINT))
		end
	end
	return out
end

-- Kingdom emblem on a field part (banner cloth, flag, pennant, shield, plaque, sign): cf on the field's front
-- face at the emblem centre, local -Z out of the face, +Y up the emblem; size = the emblem's box. The field
-- records the slot (KitEmblemSlot, KitEmblemCF relative to the field, KitEmblemSize, KitEmblemDetail) even
-- for a neutral colour, which builds no emblem, so Kit.setKingdomColor can add, swap or remove it later.
-- Emblem parts carry KitEmblem (the kind) and KitEmblemSlot. detail "full" gives the sun its separate rays.
local function emblem(ctx: Ctx, field: BasePart, cf: CFrame, size: number, color: Color3, detail: string?): { BasePart }
	local slot = (ctx.slots or 0) + 1
	ctx.slots = slot
	field:SetAttribute("KitEmblemSlot", slot)
	field:SetAttribute("KitEmblemCF", field.CFrame:ToObjectSpace(cf))
	field:SetAttribute("KitEmblemSize", size)
	field:SetAttribute("KitEmblemDetail", detail or "compact")
	local kind = Parts.emblemKind(color)
	if kind == nil then
		return {}
	end
	local tint = field:GetAttribute("KitTint")
	return buildEmblem(
		ctx,
		cf,
		size,
		kind,
		color,
		if type(tint) == "number" then tint else 1,
		detail or "compact",
		slot
	)
end

-- ------------------------------------------------------------------ plinth, walls, timber framing

-- Stone plinth: dark core + irregular facing blocks (varied length/height/projection) on all four sides.
local function stonePlinth(
	ctx: Ctx,
	w: number,
	d: number,
	h: number,
	cx: number?,
	cz: number?,
	stone: Stone?,
	seed: number?,
	blockLen: number?
)
	local ox, oz = cx or 0, cz or 0
	local S = stone or STONE.neutral
	local sd = seed or 1
	local bl0 = blockLen or 5
	block(ctx, "Plinth", Vector3.new(w, h, d), CFrame.new(ox, h / 2, oz), S.dark, M.Cobblestone)
	local k = 0
	for side = 0, 3 do
		local alongX = side % 2 == 0
		-- side stones stop short of the corners: no overlap (and no shared top face) with the front/back stones
		local len = if alongX then w + 0.5 else d - 1.8
		local sgn = if side < 2 then -1 else 1
		local n = math.max(2, math.floor(len / bl0 + 0.5))
		local weights, total = {}, 0
		for i = 1, n do
			weights[i] = 1 + jit(sd * 31 + side * 7 + i, 0.32)
			total += weights[i]
		end
		local u = -len / 2
		for i = 1, n do
			k += 1
			local bl = len * weights[i] / total
			local bh = h + jit(sd * 17 + k, 0.14) - 0.04
			if math.abs(bh - h) < 0.02 then
				bh = h + 0.03 -- never flush with the core's top face
			end
			local out = 0.32 + jit(sd * 5 + k, 0.1)
			local col = if k % 3 == 0 then S.light elseif k % 3 == 1 then S.base else shade(S.base, 1.07)
			local size, pos
			if alongX then
				size = Vector3.new(bl - 0.14, bh, 1)
				pos = Vector3.new(ox + u + bl / 2, bh / 2, oz + sgn * (d / 2 + out - 0.5))
			else
				size = Vector3.new(1, bh, bl - 0.14)
				pos = Vector3.new(ox + sgn * (w / 2 + out - 0.5), bh / 2, oz + u + bl / 2)
			end
			block(ctx, "PlinthStone", size, CFrame.new(pos), col, M.Slate)
			u += bl
		end
	end
end

-- Quoins: alternating dressed blocks proud of a stone box's four corners.
local function quoins(
	ctx: Ctx,
	w: number,
	d: number,
	y: number,
	h: number,
	color: Color3,
	per: number?,
	cx: number?,
	cz: number?
)
	local ox, oz = cx or 0, cz or 0
	local n = per or 3
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			for k = 0, n - 1 do
				local qy = y + 0.75 + k * (h - 1.5) / math.max(1, n - 1)
				local long = (k + (if sx * sz > 0 then 1 else 0)) % 2 == 0
				local size = if long then Vector3.new(2, 1.16, 1.3) else Vector3.new(1.3, 1.16, 2)
				local pos =
					Vector3.new(ox + sx * (w / 2 + 0.15 - size.X / 2), qy, oz + sz * (d / 2 + 0.15 - size.Z / 2))
				block(ctx, "Quoin", size, CFrame.new(pos), color, M.Slate)
			end
		end
	end
end

-- Timber framing on one plaster wall: posts in the panels between openings, braces in the end
-- panels (rising toward the wall centre), a rail at sill height that stops at doors.
local function frameWall(ctx: Ctx, cf: CFrame, len: number, h: number, openings: { Opening }, railY: number?)
	local lo, hi = -len / 2 + 0.35, len / 2 - 0.35
	local ops = table.clone(openings)
	table.sort(ops, function(a, b)
		return a.u < b.u
	end)
	local free = {}
	local cur = lo
	for _, o in ops do
		local a = o.u - o.hw - 0.25
		if a - cur > 0.7 then
			table.insert(free, { cur, a })
		end
		cur = math.max(cur, o.u + o.hw + 0.25)
	end
	if hi - cur > 0.7 then
		table.insert(free, { cur, hi })
	end
	local T = C.timber
	local function post(u: number)
		block(ctx, "Post", Vector3.new(0.62, h - 1.1, 0.44), cf * CFrame.new(u, h / 2, -0.02), T, M.Wood)
	end
	local function brace(uFoot: number, uHead: number)
		strut(ctx, "Brace", cf, uFoot, 0.65, uHead, h * 0.64, 0.55, 0.36, T, M.Wood, -0.02)
	end
	for _, iv in free do
		local a, b = iv[1], iv[2]
		local wi = b - a
		local atLeft, atRight = a <= lo + 0.01, b >= hi - 0.01
		if atLeft and atRight then
			post(0)
			brace(a + 0.2, math.max(a + 1.2, -1.1))
			brace(b - 0.2, math.min(b - 1.2, 1.1))
		elseif atLeft and wi >= 1.8 then
			local reach = math.min(wi - 0.3, 3.4)
			brace(a + 0.2, a + reach)
			if wi > 5 then
				post(a + reach + 0.6)
			end
		elseif atRight and wi >= 1.8 then
			local reach = math.min(wi - 0.3, 3.4)
			brace(b - 0.2, b - reach)
			if wi > 5 then
				post(b - reach - 0.6)
			end
		elseif not atLeft and not atRight and wi >= 0.9 then
			post((a + b) / 2)
		end
	end
	-- mid rail (passes behind window frames, stops at doors)
	local ry = railY or 3
	local segs = {}
	cur = lo
	for _, o in ops do
		if o.door then
			local a = o.u - o.hw - 0.1
			if a - cur > 0.6 then
				table.insert(segs, { cur, a })
			end
			cur = o.u + o.hw + 0.1
		end
	end
	if hi - cur > 0.6 then
		table.insert(segs, { cur, hi })
	end
	for _, s in segs do
		block(ctx, "Rail", Vector3.new(s[2] - s[1], 0.5, 0.5), cf * CFrame.new((s[1] + s[2]) / 2, ry, -0.02), T, M.Wood)
	end
end

-- The four wall frames of a w × d box at (cx, cz) whose walls start at height y (local -Z = outward).
local function wallFrames(w: number, d: number, y: number, cx: number?, cz: number?)
	local ox, oz = cx or 0, cz or 0
	return {
		front = CFrame.new(ox, y, oz - d / 2),
		back = CFrame.new(ox, y, oz + d / 2) * CFrame.Angles(0, PI, 0),
		left = CFrame.new(ox - w / 2, y, oz) * CFrame.Angles(0, PI / 2, 0), -- local +X = world -Z
		right = CFrame.new(ox + w / 2, y, oz) * CFrame.Angles(0, -PI / 2, 0), -- local +X = world +Z
	}
end

-- Plaster storey with sole/top plates and corner posts (frameWall adds the panel framing).
local function timberBox(
	ctx: Ctx,
	w: number,
	d: number,
	y: number,
	h: number,
	plaster: Color3?,
	cx: number?,
	cz: number?
)
	local ox, oz = cx or 0, cz or 0
	-- walls and corner posts stop 0.03/0.02 short of the plates' faces (no coplanar faces, no z-fighting)
	block(ctx, "Walls", Vector3.new(w, h - 0.06, d), CFrame.new(ox, y + h / 2, oz), plaster or C.plaster, M.Plaster)
	block(ctx, "SolePlate", Vector3.new(w + 0.46, 0.6, d + 0.46), CFrame.new(ox, y + 0.28, oz), C.timber, M.Wood)
	block(ctx, "TopPlate", Vector3.new(w + 0.5, 0.6, d + 0.5), CFrame.new(ox, y + h - 0.3, oz), C.timber, M.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(
				ctx,
				"CornerPost",
				Vector3.new(0.72, h - 0.04, 0.72),
				CFrame.new(ox + sx * w / 2, y + h / 2, oz + sz * d / 2),
				C.timber,
				M.Wood
			)
		end
	end
end

-- ------------------------------------------------------------------ roofs

local function slopeCF(base: CFrame, yR: number, theta: number, side: number, u: number, n: number, x: number): CFrame
	-- side 1 = the local -Z slope, -1 = the +Z slope; u down the slope from the ridge, n along the normal
	local F = if side == 1 then base else base * CFrame.Angles(0, PI, 0)
	local c, s = math.cos(theta), math.sin(theta)
	return F * CFrame.new(x, yR - u * s + n * c, -u * c - n * s) * CFrame.Angles(-theta, 0, 0)
end

local function gableInfill(ctx: Ctx, r: RoofSpec, base: CFrame, ends: { number })
	local infill = r.infill
	if not infill then
		return
	end
	local s = r.d / 2
	local mat = r.infillMaterial or M.Plaster
	for _, ex in ends do
		local gx = ex * (r.w / 2 - 0.3)
		local mid = r.y + r.rise / 2
		wedge(ctx, "Gable", Vector3.new(0.6, r.rise, s), base * CFrame.new(gx, mid, -s / 2), infill, mat)
		wedge(
			ctx,
			"Gable",
			Vector3.new(0.6, r.rise, s),
			base * CFrame.new(gx, mid, s / 2) * CFrame.Angles(0, PI, 0),
			infill,
			mat
		)
		if r.kingPost then
			block(
				ctx,
				"KingPost",
				Vector3.new(0.5, r.rise - 0.3, 0.62),
				base * CFrame.new(gx + ex * 0.3, r.y + (r.rise - 0.3) / 2, 0),
				C.timber,
				M.Wood
			)
		end
	end
end

-- Tile roof: courses of slabs (each course laps over the one below), alternating shade, ridge cap,
-- barge boards on the gable ends. Kingdom tiles: pass the raw kingdom colour + tint.
local function tileRoof(ctx: Ctx, r: RoofSpec): RoofInfo
	local base = r.cf or CFrame.new()
	local s = r.d / 2
	local theta = math.atan2(r.rise, s)
	local over = r.over or 1.4
	local L = math.sqrt(s * s + r.rise * r.rise) + over
	local g = r.gable or 1
	local W = r.w + 2 * g
	local yR = r.y + r.rise
	local n = r.rows or math.max(2, math.floor(L / 2.4 + 0.5))
	local du = L / n
	local t = 0.5
	local step = 0.17
	local ends = if r.ends == 1 then { 1 } else { -1, 1 }
	local k = 0
	local function tileColor(f: number): (Color3, number?)
		if r.tint then
			return shade(r.color, r.tint * f), r.tint * f
		end
		return shade(r.color, f), nil
	end
	for _, side in { 1, -1 } do
		for i = 0, n - 1 do
			k += 1
			local lift = (n - 1 - i) * step
			local f = if i % 2 == 0 then 1 else 0.86
			local col, tint = tileColor(f)
			local xw = W + jit(k * 3.1 + r.w, 0.16)
			local xo = if r.ends == 1 then 0 else jit(k * 1.7 + r.d, 0.1)
			block(
				ctx,
				"RoofTiles",
				Vector3.new(xw, t, du + 0.45),
				slopeCF(base, yR, theta, side, (i + 0.5) * du - 0.2, t / 2 + lift, xo),
				col,
				M.ClayRoofTiles,
				tint
			)
		end
	end
	local top = (n - 1) * step + t
	local ridgeY = yR + top / math.cos(theta)
	local rc, rt = tileColor(0.62)
	block(
		ctx,
		"RidgeCap",
		Vector3.new(W + 0.5, 1.05, 1.05),
		base * CFrame.new(0, ridgeY - 0.1, 0) * CFrame.Angles(rad(45), 0, 0),
		rc,
		M.Slate,
		rt
	)
	local trim = r.trim or C.timber
	for _, ex in ends do
		for _, side in { 1, -1 } do
			block(
				ctx,
				"BargeBoard",
				Vector3.new(0.4, 1.1, L + 0.2),
				slopeCF(base, yR, theta, side, L / 2 - 0.1, top / 2 + 0.15, ex * side * (W / 2 + 0.12)),
				trim,
				M.Wood
			)
		end
	end
	gableInfill(ctx, r, base, ends)
	return { ridgeY = ridgeY, theta = theta, slope = L, width = W }
end

-- Thatch roof: thick straw slabs with a lighter upper layer, rolled eaves, rolled ridge and verges.
local function thatchRoof(ctx: Ctx, r: RoofSpec): RoofInfo
	local base = r.cf or CFrame.new()
	local s = r.d / 2
	local theta = math.atan2(r.rise, s)
	local over = r.over or 1.6
	local L = math.sqrt(s * s + r.rise * r.rise) + over
	local g = r.gable or 1.2
	local W = r.w + 2 * g
	local yR = r.y + r.rise
	local T = 1.6
	local col = r.color
	local ends = if r.ends == 1 then { 1 } else { -1, 1 }
	for _, side in { 1, -1 } do
		block(
			ctx,
			"Thatch",
			Vector3.new(W, T, L + 0.3),
			slopeCF(base, yR, theta, side, L / 2 - 0.15, T / 2, 0),
			col,
			M.Grass
		)
		local L2 = L * 0.56
		block(
			ctx,
			"ThatchLayer",
			Vector3.new(W - 0.7, 0.9, L2),
			slopeCF(base, yR, theta, side, L2 / 2 - 0.2, T + 0.3, 0),
			shade(col, 1.08),
			M.Grass
		)
		cyl(
			ctx,
			"ThatchEave",
			slopeCF(base, yR, theta, side, L - 0.45, T / 2, 0),
			W + 0.2,
			T + 0.6,
			shade(col, 0.9),
			M.Grass
		)
	end
	local ridgeY = yR + (T + 0.3) / math.cos(theta)
	cyl(ctx, "ThatchRidge", base * CFrame.new(0, ridgeY - 0.35, 0), W + 0.3, 2.3, shade(col, 0.82), M.Grass)
	for _, ex in ends do
		for _, side in { 1, -1 } do
			cyl(
				ctx,
				"ThatchVerge",
				slopeCF(base, yR, theta, side, L / 2 - 0.2, T / 2 + 0.1, ex * side * (W / 2 - 0.1))
					* CFrame.Angles(0, PI / 2, 0),
				L + 0.2,
				T + 0.4,
				shade(col, 0.95),
				M.Grass
			)
		end
	end
	gableInfill(ctx, r, base, ends)
	return { ridgeY = ridgeY, theta = theta, slope = L, width = W }
end

-- Mono-pitch (lean-to) roof: cf at the high edge against the wall (local -Z = down the slope), run
-- `depth` outward and `drop` down; courses along local X.
local function leanTo(
	ctx: Ctx,
	cf: CFrame,
	len: number,
	depth: number,
	drop: number,
	color: Color3,
	tint: number?,
	rows: number?,
	material: Enum.Material?
)
	local theta = math.atan2(drop, depth)
	local L = math.sqrt(depth * depth + drop * drop) + 0.7
	local n = rows or 2
	local du = L / n
	local c, s = math.cos(theta), math.sin(theta)
	for i = 0, n - 1 do
		local f = if i % 2 == 0 then 1 else 0.87
		local uc = (i + 0.5) * du - 0.15
		local nn = 0.25 + (n - 1 - i) * 0.15
		block(
			ctx,
			"LeanToRoof",
			Vector3.new(len, 0.5, du + 0.4),
			cf * CFrame.new(0, -uc * s + nn * c, -uc * c - nn * s) * CFrame.Angles(-theta, 0, 0),
			shade(color, (tint or 1) * f),
			material or M.ClayRoofTiles,
			if tint then tint * f else nil
		)
	end
end

-- Four-sided pyramid from CornerWedges (apex at local +X+Y-Z; a 90° turn puts it over the centre).
local function pyramidRoof(
	ctx: Ctx,
	w: number,
	h: number,
	y: number,
	color: Color3,
	tint: number?,
	cx: number?,
	cz: number?
)
	local ox, oz = cx or 0, cz or 0
	local half = w / 2
	for i = 0, 3 do
		local f = if i % 2 == 0 then 1 else 0.9
		local off = CFrame.new(ox, y + h / 2, oz) * CFrame.Angles(0, rad(90 * i), 0) * CFrame.new(half / 2, 0, half / 2)
		cornerWedge(
			ctx,
			"RoofCorner",
			Vector3.new(half, h, half),
			off * CFrame.Angles(0, rad(90), 0),
			shade(color, (tint or 1) * f),
			M.ClayRoofTiles,
			if tint then tint * f else nil
		)
	end
end

-- Legacy simple gable roof (kept for callers outside Buildings): a 3-course tile roof.
local function gableRoof(
	ctx: Ctx,
	w: number,
	d: number,
	y: number,
	rise: number,
	color: Color3,
	_dark: Color3,
	tint: number?,
	cx: number?,
	cz: number?
)
	tileRoof(ctx, {
		w = w,
		d = d,
		y = y,
		rise = rise,
		cf = CFrame.new(cx or 0, 0, cz or 0),
		color = color,
		tint = tint,
		rows = 3,
		infill = C.plaster,
	})
end

-- ------------------------------------------------------------------ towers and caps

local function finial(ctx: Ctx, x: number, y: number, z: number, color: Color3, h: number?): number
	local hh = h or 2.2
	column(ctx, "Finial", 0.16, hh, Vector3.new(x, y, z), color, M.Metal)
	ball(ctx, "FinialBall", 0.75, Vector3.new(x, y + hh, z), color, M.Metal)
	return y + hh + 0.35
end

-- Kingdom flag on a pole, with the kingdom emblem on its -Z face. style "emerald" (FORGE-00 calibration: the
-- emerald plot sits on green terrain) flies a lighter, high-saturation tint with a cream border; without
-- style the Flag is the exact kingdom colour (region markers, Kit.spec). dir (default +1) is the side the flag
-- flies to along X; scale (default 1) sizes the flag, its emblem and the finial (the keep's royal standards).
local function flagpole(
	ctx: Ctx,
	x: number,
	y: number,
	z: number,
	h: number,
	color: Color3,
	style: string?,
	dir: number?,
	scale: number?
): { BasePart }
	local d, k = dir or 1, scale or 1
	local first = #ctx.model:GetChildren()
	column(ctx, "FlagPole", 0.2 * math.max(k, 1), h, Vector3.new(x, y, z), C.woodDark, M.Wood)
	local f = if style == "emerald" then EMERALD_LIGHT else 1
	local fy = y + h - 1.2 * k
	local flag = block(
		ctx,
		"Flag",
		Vector3.new(3.4 * k, 2.0 * k, 0.15),
		CFrame.new(x + d * 1.8 * k, fy, z),
		shade(color, f),
		M.Fabric,
		f
	)
	if style == "emerald" then
		block(
			ctx,
			"FlagBorder",
			Vector3.new(3.4 * k + 0.35, 2.0 * k + 0.35, 0.1),
			CFrame.new(x + d * (1.8 * k + 0.05), fy, z),
			IVORY,
			M.Fabric
		)
	end
	emblem(ctx, flag, CFrame.new(x + d * (1.8 * k + 0.05), fy, z - 0.075), 1.6 * k, color)
	ball(ctx, "FlagFinial", 0.55 * k, Vector3.new(x, y + h + 0.2 * k, z), C.gold, M.Metal)
	-- returns the parts it built except the emblem's (Kit.setKingdomColor replaces those)
	local built = {}
	local kids = ctx.model:GetChildren()
	for i = first + 1, #kids do
		if kids[i]:GetAttribute("KitEmblem") == nil then
			table.insert(built, kids[i] :: BasePart)
		end
	end
	return built
end

-- Small pennant on a pole (ridge pennants): pole, pointed kingdom-colour flag with the emblem, gold knob. dir
-- (default +1) is the side it flies to along X; scale (default 1) sizes the cloth, its emblem and the knob.
local function pennant(
	ctx: Ctx,
	x: number,
	y: number,
	z: number,
	h: number,
	color: Color3,
	style: string?,
	dir: number?,
	scale: number?
)
	local d, k = dir or 1, scale or 1
	column(ctx, "PennantPole", 0.13 * math.max(k, 1), h, Vector3.new(x, y, z), C.woodDark, M.Wood)
	local f = if style == "emerald" then EMERALD_LIGHT else 1
	local py = y + h - 0.85 * k
	local cloth = block(
		ctx,
		"Pennant",
		Vector3.new(2.2 * k, 1.3 * k, 0.12),
		CFrame.new(x + d * 1.15 * k, py, z),
		shade(color, f),
		M.Fabric,
		f
	)
	emblem(ctx, cloth, CFrame.new(x + d * 1.05 * k, py, z - 0.06), 1.1 * k, color)
	block(
		ctx,
		"PennantTip",
		Vector3.new(0.92 * k, 0.92 * k, 0.1),
		CFrame.new(x + d * 2.25 * k, py, z) * CFrame.Angles(0, 0, rad(45)),
		shade(color, f),
		M.Fabric,
		f
	)
	if style == "emerald" then
		block(
			ctx,
			"PennantBorder",
			Vector3.new(2.2 * k + 0.3, 1.3 * k + 0.3, 0.08),
			CFrame.new(x + d * (1.15 * k + 0.05), py, z),
			IVORY,
			M.Fabric
		)
	end
	ball(ctx, "PennantKnob", 0.4 * k, Vector3.new(x, y + h + 0.1 * k, z), C.gold, M.Metal)
end

-- Stepped spire (crimson): flared eave ring + tapering cylinder tiers, alternating shade.
local function spire(
	ctx: Ctx,
	r: number,
	h: number,
	y: number,
	color: Color3,
	tint: number?,
	cx: number?,
	cz: number?,
	tiers: number?
): number
	local x, z = cx or 0, cz or 0
	local t0 = tint or 1
	column(ctx, "SpireEave", r + 0.5, 0.7, Vector3.new(x, y, z), shade(color, t0 * 0.66), M.Slate, t0 * 0.66)
	local nt = tiers or 6
	local th = h / nt
	for i = 0, nt - 1 do
		local f = if i % 2 == 0 then 1 else 0.88
		local rr = r * (1 - i / nt) ^ 1.15 + 0.22
		column(
			ctx,
			"Spire",
			rr,
			th + 0.06,
			Vector3.new(x, y + 0.6 + i * th, z),
			shade(color, t0 * f),
			M.ClayRoofTiles,
			t0 * f
		)
	end
	return y + 0.6 + h
end

local function dome(ctx: Ctx, r: number, y: number, color: Color3, tint: number?, cx: number?, cz: number?): number
	local x, z = cx or 0, cz or 0
	local t0 = tint or 1
	column(ctx, "Drum", r * 0.86, 1.3, Vector3.new(x, y, z), IVORY, M.Plaster)
	column(ctx, "DrumBand", r * 0.92, 0.45, Vector3.new(x, y + 1.1, z), TRIM.gold, M.Fabric)
	local cy = y + 1.3 + r * 0.3
	ball(ctx, "Dome", r * 2, Vector3.new(x, cy, z), shade(color, t0), M.SmoothPlastic, t0)
	ball(
		ctx,
		"DomeTip",
		r * 0.55,
		Vector3.new(x, cy + r * 1.02, z),
		shade(color, t0 * 0.85),
		M.SmoothPlastic,
		t0 * 0.85
	)
	return cy + r * 1.2
end

-- Kingdom tower cap over a tower of width w whose top is at y. Returns the apex height (top of the
-- finial or flag). flagH > 0 plants a kingdom flag on the apex instead of a finial.
local function towerCap(
	ctx: Ctx,
	style: string,
	w: number,
	y: number,
	color: Color3,
	cx: number?,
	cz: number?,
	flagH: number?
): number
	local x, z = cx or 0, cz or 0
	local top
	local metal = trimFor(style)
	if style == "crimson" then
		top = spire(ctx, w / 2 + 0.5, w * 1.85, y, color, 1, x, z, if w >= 9 then 8 elseif w >= 5 then 6 else 4)
		metal = C.gold
	elseif style == "azure" then
		block(
			ctx,
			"CapEave",
			Vector3.new(w + 1.8, 0.6, w + 1.8),
			CFrame.new(x, y + 0.3, z),
			shade(color, 0.62),
			M.Slate,
			0.62
		)
		local H = w * 1.2
		pyramidRoof(ctx, w + 1.3, H, y + 0.6, color, 1, x, z)
		top = y + 0.6 + H
	elseif style == "emerald" then
		-- timber hoarding: overhanging wooden fighting gallery with a dark beam band, low pyramid
		block(ctx, "Hoarding", Vector3.new(w + 2, 3.1, w + 2), CFrame.new(x, y + 1.85, z), C.wood, M.WoodPlanks)
		block(ctx, "HoardingBeam", Vector3.new(w + 2.4, 0.7, w + 2.4), CFrame.new(x, y + 0.35, z), C.timber, M.Wood)
		local H = w * 0.62
		pyramidRoof(ctx, w + 2.6, H, y + 3.4, color, 1, x, z)
		top = y + 3.4 + H
	elseif style == "gold" then
		top = dome(ctx, w * 0.55, y, color, 1, x, z)
		metal = C.gold
	else
		block(ctx, "CapEave", Vector3.new(w + 1.8, 0.7, w + 1.8), CFrame.new(x, y + 0.35, z), C.timber, M.Wood)
		local H = w * 0.95
		pyramidRoof(ctx, w + 1.3, H, y + 0.7, color, 0.78, x, z)
		top = y + 0.7 + H
		metal = C.iron
	end
	if flagH and flagH > 0 then
		flagpole(ctx, x, top - 0.3, z, flagH, color, style)
		return top + flagH
	end
	if w < 4 then
		return top
	end
	return finial(ctx, x, top - 0.2, z, metal)
end

-- Round tower: base flare, shaft, string course, corbel ring, arrow slits facing the given yaws.
local function roundTower(
	ctx: Ctx,
	x: number,
	z: number,
	y0: number,
	r: number,
	h: number,
	S: Stone,
	slitYaws: { number }?
): number
	column(ctx, "TowerBase", r + 0.55, 2.8, Vector3.new(x, 0, z), S.dark, M.Cobblestone)
	column(ctx, "Tower", r, h, Vector3.new(x, y0, z), S.base, M.Cobblestone)
	column(ctx, "TowerCourse", r + 0.3, 0.7, Vector3.new(x, y0 + h * 0.52, z), S.light, M.Slate)
	column(ctx, "TowerCorbel", r + 0.8, 1.4, Vector3.new(x, y0 + h - 1.4, z), S.light, M.Slate)
	for i, a in slitYaws or {} do
		local dir = Vector3.new(-math.sin(a), 0, -math.cos(a))
		local p = Vector3.new(x, y0 + h * (if i % 2 == 1 then 0.72 else 0.34), z) + dir * (r - 0.1)
		block(ctx, "ArrowSlit", Vector3.new(0.55, 2.6, 0.5), CFrame.new(p) * CFrame.Angles(0, a, 0), C.glass, M.Slate)
	end
	return y0 + h
end

-- Merlons around a w × d parapet top at height y; corner merlons sit on the corners. skip = margin
-- from each corner left free (for corner turrets).
local function crenellate(
	ctx: Ctx,
	w: number,
	d: number,
	y: number,
	color: Color3,
	cx: number?,
	cz: number?,
	o: { m: number?, h: number?, t: number?, skip: number?, gap: number?, xOnly: boolean? }?
)
	local ox, oz = cx or 0, cz or 0
	local opts = o or {}
	local m, mh, t = opts.m or 2.6, opts.h or 3, opts.t or 1.2
	local g = opts.gap or 1.8
	local skip = opts.skip or 0
	for _, side in { { w, d, 1 }, { d, w, 0 } } do
		local len, other, alongX = side[1], side[2], side[3] == 1
		local n = math.max(2, math.floor((len + g) / (m + g) + 0.5))
		local stepU = (len - m) / (n - 1)
		for i = 0, n - 1 do
			local u = -len / 2 + m / 2 + i * stepU
			local corner = i == 0 or i == n - 1
			local skipped = skip > 0 and math.abs(u) > len / 2 - skip
			if not (corner and not alongX) and not skipped and (alongX or not opts.xOnly) then
				for _, s in { -1, 1 } do
					local pos = if alongX
						then Vector3.new(ox + u, y + mh / 2, oz + s * (other / 2 - t / 2))
						else Vector3.new(ox + s * (other / 2 - t / 2), y + mh / 2, oz + u)
					local size = if alongX then Vector3.new(m, mh, t) else Vector3.new(t, mh, m)
					block(ctx, "Merlon", size, CFrame.new(pos), color, M.Slate)
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ openings

local function windowAt(ctx: Ctx, cf: CFrame, o: WindowOpts?)
	local opts: WindowOpts = o or {}
	if opts.slit then
		local hh = opts.h or 2.8
		block(
			ctx,
			"SlitFrame",
			Vector3.new(1.3, hh + 0.6, 0.36),
			cf * CFrame.new(0, hh / 2, -0.1),
			opts.frame or C.stoneLight,
			M.Slate
		)
		block(ctx, "ArrowSlit", Vector3.new(0.5, hh, 0.3), cf * CFrame.new(0, hh / 2, -0.25), C.glass, M.Slate)
		return
	end
	local W, H = opts.w or 2.6, opts.h or 3.4
	local fc = opts.frame or C.timber
	local fm = opts.frameMaterial or M.Wood
	if opts.arched then
		local hr = H - W / 2
		block(ctx, "WindowFrame", Vector3.new(W + 0.9, hr, 0.4), cf * CFrame.new(0, hr / 2, -0.1), fc, fm)
		disc(ctx, "WindowArchFrame", cf * CFrame.new(0, hr, -0.08), W + 0.9, 0.34, fc, fm)
		block(ctx, "Window", Vector3.new(W, hr - 0.04, 0.3), cf * CFrame.new(0, hr / 2, -0.24), C.glass, M.Glass)
		disc(ctx, "WindowArch", cf * CFrame.new(0, hr, -0.22), W, 0.26, C.glass, M.Glass)
	else
		block(ctx, "WindowFrame", Vector3.new(W + 0.7, H + 0.7, 0.4), cf * CFrame.new(0, H / 2, -0.1), fc, fm)
		block(ctx, "Window", Vector3.new(W, H, 0.3), cf * CFrame.new(0, H / 2, -0.24), C.glass, M.Glass)
	end
	if opts.bare then
		return
	end
	block(ctx, "Mullion", Vector3.new(0.26, H - 0.1, 0.16), cf * CFrame.new(0, H / 2, -0.44), fc, fm)
	if not opts.simple then
		block(ctx, "Transom", Vector3.new(W, 0.26, 0.13), cf * CFrame.new(0, H * 0.6, -0.44), fc, fm)
	end
	if opts.box then
		block(ctx, "FlowerBox", Vector3.new(W + 0.7, 0.8, 0.9), cf * CFrame.new(0, -0.45, -0.7), C.wood, M.WoodPlanks)
		block(ctx, "FlowerLeaves", Vector3.new(W + 0.4, 0.55, 0.7), cf * CFrame.new(0, 0.2, -0.75), C.leaf, M.Grass)
		for i, sx in { -0.28, 0.28 } do
			ball(ctx, "Flowers", 0.75, (cf * CFrame.new(sx * W, 0.45, -0.85)).Position, FLOWERS[i], M.SmoothPlastic)
		end
	else
		block(ctx, "Sill", Vector3.new(W + 1.1, 0.36, 0.85), cf * CFrame.new(0, -0.18, -0.38), C.wood, M.Wood)
	end
	local shutters = opts.shutters
	if shutters and not opts.simple then
		local sw = W * 0.55
		local hx = W / 2 + 0.35
		local a = rad(22)
		for _, sx in { -1, 1 } do
			block(
				ctx,
				"Shutter",
				Vector3.new(sw, H + 0.1, 0.24),
				cf * CFrame.new(sx * hx, H / 2, -0.32) * CFrame.Angles(0, sx * a, 0) * CFrame.new(sx * sw / 2, 0, 0),
				shade(shutters, 0.85),
				M.WoodPlanks,
				0.85
			)
		end
	end
end

-- Arched plank door (iron straps) in stone jambs + voussoir arch, with an optional stoop.
local function doorAt(ctx: Ctx, cf: CFrame, o: DoorOpts?)
	local opts: DoorOpts = o or {}
	local W, H = opts.w or 4.4, opts.h or 7.6
	local hr = H - W / 2
	local leafColor = opts.leaf or C.woodDark
	local leafTint = opts.leafTint
	if leafTint then
		leafColor = shade(leafColor, leafTint)
	end
	block(ctx, "Door", Vector3.new(W, hr, 0.36), cf * CFrame.new(0, hr / 2, -0.08), leafColor, M.WoodPlanks, leafTint)
	disc(ctx, "DoorArch", cf * CFrame.new(0, hr, -0.06), W, 0.3, leafColor, M.WoodPlanks, leafTint)
	if opts.straps ~= false then
		for _, fy in { 0.24, 0.7 } do
			block(
				ctx,
				"DoorStrap",
				Vector3.new(W * 0.84, 0.3, 0.12),
				cf * CFrame.new(0, hr * fy, -0.31),
				C.iron,
				M.Metal
			)
		end
	end
	local st, stl = opts.stone or C.stone, opts.stoneLight or C.stoneLight
	for _, sx in { -1, 1 } do
		block(
			ctx,
			"DoorJamb",
			Vector3.new(0.95, hr, 1),
			cf * CFrame.new(sx * (W / 2 + 0.47), hr / 2, -0.15),
			st,
			M.Slate
		)
	end
	local n = opts.voussoirs or 5
	local R = W / 2 + 0.47
	for i = 0, n - 1 do
		local phi = PI * (i + 0.5) / n
		local key = i * 2 == n - 1
		local tang = PI * R / n * 0.92
		block(
			ctx,
			if key then "Keystone" else "Voussoir",
			Vector3.new(tang + (if key then 0.2 else 0), if key then 1.3 else 0.98, 1.05),
			cf * CFrame.new(math.cos(phi) * R, hr + math.sin(phi) * R, -0.18) * CFrame.Angles(0, 0, phi - PI / 2),
			if i % 2 == 0 then stl else st,
			M.Slate
		)
	end
	local sh = opts.step or 0
	if sh > 0 then
		-- the stoop's top sits 0.03 under the floor (never flush with the plinth's top face)
		block(ctx, "Step", Vector3.new(W + 1.9, sh - 0.03, 1.9), cf * CFrame.new(0, -sh / 2 - 0.015, -1.0), st, M.Slate)
		if sh > 0.9 then
			block(ctx, "Step", Vector3.new(W + 2.6, sh / 2, 1.1), cf * CFrame.new(0, -sh * 0.75, -2.45), stl, M.Slate)
		end
	end
end

-- Bracket (upside-down wedge) under an overhang: cf on the wall face at the underside, local -Z outward.
local function bracket(ctx: Ctx, cf: CFrame, out: number, h: number, color: Color3?, material: Enum.Material?)
	wedge(
		ctx,
		"Bracket",
		Vector3.new(0.6, h, out),
		cf * CFrame.new(0, -h / 2, -out / 2) * CFrame.Angles(0, 0, PI),
		color or C.timber,
		material or M.Wood
	)
end

-- Gable dormer on the -Z slope of a tile roof (ridge along X): x along the ridge, y = main wall top,
-- dTop = main roof span, theta = main roof pitch.
local function dormer(
	ctx: Ctx,
	x: number,
	y: number,
	dTop: number,
	theta: number,
	color: Color3,
	tint: number?,
	plaster: Color3,
	cz: number?
)
	local oz = cz or 0
	local dw, dh = 4.2, 3.8
	local zf = oz - dTop / 2 + 0.6
	local zb = oz - dTop / 2 + dh / math.tan(theta) + 0.5
	local depth = zb - zf
	block(
		ctx,
		"Dormer",
		Vector3.new(dw, dh + 0.4, depth),
		CFrame.new(x, y - 0.2 + (dh + 0.4) / 2, (zf + zb) / 2),
		plaster,
		M.Plaster
	)
	tileRoof(ctx, {
		w = depth,
		d = dw,
		y = y + dh,
		rise = 2.1,
		cf = CFrame.new(x, 0, (zf + zb) / 2) * CFrame.Angles(0, PI / 2, 0),
		over = 0.7,
		gable = 0.5,
		rows = 2,
		color = color,
		tint = tint,
		infill = plaster,
		ends = 1,
	})
	windowAt(ctx, CFrame.new(x, y + 0.45, zf), { w = 2.2, h = 2.6, simple = true })
end

-- ------------------------------------------------------------------ heraldry

-- Hanging banner: pole, cloth with a pointed tail, the kingdom emblem as large as the cloth allows (80 % of
-- its width). y = pole height.
local function banner(
	ctx: Ctx,
	x: number,
	y: number,
	z: number,
	facing: number,
	color: Color3,
	h: number?,
	style: string?,
	width: number?
)
	local hh = h or 5
	local bw = width or 2.6
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, rad(facing), 0)
	cyl(ctx, "BannerPole", base * CFrame.new(0, 0.1, -0.45), bw + 0.9, 0.34, C.woodDark, M.Wood)
	-- emerald (on green terrain): lighter, high-saturation cloth with a cream border
	local emerald = (style or hueStyle(color)) == "emerald"
	local f = if emerald then EMERALD_LIGHT else 1
	local cloth = block(
		ctx,
		"Banner",
		Vector3.new(bw, hh, 0.2),
		base * CFrame.new(0, -hh / 2, -0.45),
		shade(color, f),
		M.Fabric,
		f
	)
	local s = bw / math.sqrt(2)
	block(
		ctx,
		"BannerTip",
		Vector3.new(s, s, 0.16),
		base * CFrame.new(0, -hh, -0.45) * CFrame.Angles(0, 0, rad(45)),
		shade(color, f),
		M.Fabric,
		f
	)
	if emerald then
		block(
			ctx,
			"BannerBorder",
			Vector3.new(bw + 0.36, hh + 0.05, 0.12),
			base * CFrame.new(0, -hh / 2 - 0.075, -0.38),
			IVORY,
			M.Fabric
		)
		block(
			ctx,
			"BannerBorder",
			Vector3.new(s + 0.26, s + 0.26, 0.08),
			base * CFrame.new(0, -hh, -0.385) * CFrame.Angles(0, 0, rad(45)),
			IVORY,
			M.Fabric
		)
	end
	-- the emblem fills the cloth under the pole (the box stays inside the cloth on short banners); it replaced
	-- the old trim band, which paid for the emblem's parts
	local es = math.min(bw * 0.8, (hh - 0.5) * 0.9)
	emblem(ctx, cloth, base * CFrame.new(0, -(hh + 0.25) / 2, -0.55), es, color)
end

-- Heater shield crest (kingdom colour + emblem) on a wall: cf at the shield centre, facing -Z.
local function crest(ctx: Ctx, cf: CFrame, size: number, color: Color3, _style: string?)
	local shield = block(
		ctx,
		"Crest",
		Vector3.new(size, size * 0.75, 0.35),
		cf * CFrame.new(0, size * 0.12, 0),
		color,
		M.SmoothPlastic,
		1
	)
	local s = size / math.sqrt(2)
	block(
		ctx,
		"CrestTip",
		Vector3.new(s, s, 0.3),
		cf * CFrame.new(0, -size * 0.25, 0) * CFrame.Angles(0, 0, rad(45)),
		color,
		M.SmoothPlastic,
		1
	)
	emblem(ctx, shield, cf * CFrame.new(0, size * 0.06, -0.175), size * 0.64, color)
end

-- Aerial heraldry plaque (colour-vision finding 3): a square kingdom field with an ivory border and the
-- full-detail emblem, for faces the overview camera sees (the keep's roof, facing up; the donjon's back).
-- cf = the field's front face centre, local -Z out of it, +Y up the emblem; size = the field's side. The
-- border reaches 0.12 behind the face it is mounted on, so it never floats; `raise` (default 0) lifts the
-- plaque that much off that face on the border block itself (a pedestal: no extra part). Returns the field.
local function emblemPlaque(ctx: Ctx, cf: CFrame, size: number, color: Color3, raise: number?): BasePart
	local r = raise or 0
	local field =
		block(ctx, "EmblemPlaque", Vector3.new(size, size, 0.2), cf * CFrame.new(0, 0, 0.1), color, M.SmoothPlastic, 1)
	block(
		ctx,
		"EmblemPlaqueBorder",
		Vector3.new(size + 0.7, size + 0.7, 0.3 + r),
		cf * CFrame.new(0, 0, 0.22 + r / 2),
		IVORY,
		M.SmoothPlastic
	)
	emblem(ctx, field, cf, size * 0.88, color, "full")
	return field
end

-- Throne on a three-step dais (G13.6) under a baldachin, against a cloth of estate (B12, FORGE-00 D-019 review).
-- cf = the dais' back-centre on the floor, local -Z = the way the throne faces; the keep puts cf 1.6 before the
-- bay face, so nothing of the throne group reaches the door, its jambs or its voussoirs.
--   - Seat "Throne" (Anchored, CanCollide) on a wooden base, gold arms, a tall kingdom-colour back with an ivory
--     edge (it reads without colour) and the kingdom emblem above the seated ruler's head.
--   - Dossal: a kingdom cloth (lighter tint) with an ivory border hung behind the throne, so the throne stands
--     against a framed cloth instead of the dark door opening.
--   - Baldachin: two posts on the dais' front corners and a gabled kingdom canopy with a gold finial,
--     THRONE_CANOPY_CLEAR studs over the seat (the seat's open-sky rule) and deep enough to cover it.
-- Every part carries the attribute KitThrone; the canopy and its finial also carry KitThroneMarker (the keep's
-- royal standards carry it too: the marker the overview camera must find from every side). Returns the Seat and
-- the dais top.
local THRONE_CANOPY_CLEAR = 8.05 -- canopy underside above the seat's top face (KitBuildings: ≥ 8)
local function throne(ctx: Ctx, cf: CFrame, color: Color3, style: string, stone: Stone?): (BasePart, number)
	local S = stone or STONE.neutral
	local first = #ctx.model:GetChildren()
	local steps = { { 5.8, 4.4 }, { 5.0, 3.6 }, { 4.4, 3.0 } } -- narrower than a 6-wide door's jambs
	for k, st in steps do
		block(
			ctx,
			"DaisStep",
			Vector3.new(st[1], 0.6, st[2]),
			cf * CFrame.new(0, 0.3 + (k - 1) * 0.6, -st[2] / 2),
			if k % 2 == 1 then S.light else S.base,
			M.Slate
		)
	end
	local top = #steps * 0.6
	local sz = -1.6
	block(ctx, "ThroneBase", Vector3.new(3.6, 1, 3.1), cf * CFrame.new(0, top + 0.53, sz), C.woodDark, M.Wood)
	local seat = Instance.new("Seat")
	seat.Shape = Enum.PartType.Block
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = cf * CFrame.new(0, top + 1.5, sz)
	seat.CanCollide = true
	finish(seat, ctx, "Throne", shade(color, 0.85), M.Fabric, 0.85)
	for _, sx in { -1, 1 } do
		block(ctx, "ThroneArm", Vector3.new(0.5, 1, 2.8), cf * CFrame.new(sx * 1.85, top + 2.4, sz), C.gold, M.Metal)
	end
	-- back (top + 1.1 .. top + 7.3) with an ivory edge 0.4 proud of its sides and top, the emblem above the head
	local back = block(
		ctx,
		"ThroneBack",
		Vector3.new(3.6, 6.2, 0.7),
		cf * CFrame.new(0, top + 4.2, sz + 0.8),
		color,
		M.Fabric,
		1
	)
	block(ctx, "ThroneEdge", Vector3.new(4.4, 6.5, 0.5), cf * CFrame.new(0, top + 4.45, sz + 1.0), IVORY, M.Fabric)
	emblem(ctx, back, cf * CFrame.new(0, top + 6.25, sz + 0.45), 1.7, color)
	-- baldachin: posts on the bottom step's front corners, canopy from just before them back over the dossal
	local f = if style == "emerald" then EMERALD_LIGHT else 1
	local cy = top + 2 + THRONE_CANOPY_CLEAR -- canopy underside
	-- posts stand on the terrace just outside the dais' front corners (inside them, an angled view saw a post cut
	-- across the seat)
	local pz, px, cw, rise = -4.25, 3.25, 7.3, 1.6
	for _, sx in { -1, 1 } do
		column(ctx, "BaldachinPost", 0.3, cy + 0.2, (cf * CFrame.new(sx * px, 0, pz)).Position, C.woodDark, M.Wood)
	end
	local zf, zb = pz - 0.4, 0.75
	local half = (zb - zf) / 2
	local zc = (zf + zb) / 2
	for _, side in { -1, 1 } do
		wedge(
			ctx,
			"BaldachinCanopy",
			Vector3.new(cw, rise, half),
			cf * CFrame.new(0, cy + rise / 2, zc + side * half / 2) * CFrame.Angles(0, if side > 0 then PI else 0, 0),
			shade(color, f),
			M.Fabric,
			f
		)
	end
	ball(ctx, "BaldachinFinial", 1.1, (cf * CFrame.new(0, cy + rise + 0.35, zc)).Position, C.gold, M.Metal)
	-- dossal: hangs behind the dais (z 0.35..0.55) under the canopy, its ivory border just behind it
	local dt = if style == "emerald" then EMERALD_LIGHT else 1.25
	local dh = cy - 0.3 - 0.35
	block(
		ctx,
		"Dossal",
		Vector3.new(5, dh, 0.2),
		cf * CFrame.new(0, 0.35 + dh / 2, 0.45),
		shade(color, dt),
		M.Fabric,
		dt
	)
	block(
		ctx,
		"DossalBorder",
		Vector3.new(5.9, dh + 0.4, 0.12),
		cf * CFrame.new(0, 0.2 + (dh + 0.4) / 2, 0.6),
		IVORY,
		M.Fabric
	)
	local children = ctx.model:GetChildren()
	for i = first + 1, #children do
		local p = children[i]
		if p:GetAttribute("KitEmblem") ~= nil then
			continue -- the back's emblem belongs to its slot (Kit.setKingdomColor replaces it)
		end
		p:SetAttribute("KitThrone", true)
		if p.Name == "BaldachinCanopy" or p.Name == "BaldachinFinial" then
			p:SetAttribute("KitThroneMarker", true)
		end
	end
	return seat, top
end

-- ------------------------------------------------------------------ chimneys

-- Chimney stack rising from y0 by h: stack, band, cap, pot.
local function chimney(ctx: Ctx, x: number, z: number, y0: number, h: number, w: number?)
	local cw = w or 2.4
	block(ctx, "Chimney", Vector3.new(cw, h, cw), CFrame.new(x, y0 + h / 2, z), C.stone, M.Cobblestone)
	block(
		ctx,
		"ChimneyBand",
		Vector3.new(cw + 0.5, 0.45, cw + 0.5),
		CFrame.new(x, y0 + h - 1, z),
		C.stoneLight,
		M.Slate
	)
	block(
		ctx,
		"ChimneyCap",
		Vector3.new(cw + 0.7, 0.5, cw + 0.7),
		CFrame.new(x, y0 + h + 0.25, z),
		C.stoneDark,
		M.Slate
	)
	column(ctx, "ChimneyPot", 0.5, 1.1, Vector3.new(x + cw * 0.18, y0 + h + 0.5, z), POT, M.SmoothPlastic)
end

-- External gable-end chimney: wide base from the ground to `shoulder`, a sloped shoulder, then the stack.
local function gableChimney(ctx: Ctx, x: number, z: number, side: number, shoulder: number, top: number)
	block(ctx, "ChimneyBase", Vector3.new(2.9, shoulder, 2.9), CFrame.new(x, shoulder / 2, z), C.stone, M.Cobblestone)
	wedge(
		ctx,
		"ChimneyShoulder",
		Vector3.new(2.9, 1.3, 0.72),
		CFrame.new(x + side * 1.09, shoulder + 0.65, z) * CFrame.Angles(0, -side * PI / 2, 0),
		C.stone,
		M.Cobblestone
	)
	chimney(ctx, x - side * 0.35, z, shoulder, top - shoulder, 2.2)
end

-- ------------------------------------------------------------------ props that dress buildings

local function barrel(ctx: Ctx, pos: Vector3, h: number?)
	local hh = h or 2.2
	column(ctx, "Barrel", 0.95, hh, pos, C.wood, M.WoodPlanks)
	column(ctx, "BarrelHoop", 1.02, 0.25, pos + Vector3.new(0, hh * 0.68, 0), C.iron, M.Metal)
end

local function crate(ctx: Ctx, cf: CFrame, s: number?)
	local ss = s or 2
	block(ctx, "Crate", Vector3.new(ss, ss, ss), cf * CFrame.new(0, ss / 2, 0), C.woodLight, M.WoodPlanks)
end

local function sack(ctx: Ctx, pos: Vector3, s: number?)
	local ss = s or 1.6
	ball(ctx, "Sack", ss, pos + Vector3.new(0, ss * 0.42, 0), C.canvas, M.Fabric)
end

-- Stack of logs lying along the local X of cf (rows from the bottom).
local function logStack(ctx: Ctx, cf: CFrame, len: number, rows: number, r: number?)
	local rr = r or 0.55
	for row = 0, rows - 1 do
		local n = rows - row + 1
		for i = 0, n - 1 do
			log(
				ctx,
				"Log",
				rr,
				len + jit(row * 5 + i, 0.4),
				cf * CFrame.new(jit(row * 3 + i, 0.25), rr + row * rr * 1.72, (i - (n - 1) / 2) * rr * 2.02),
				if (row + i) % 2 == 0 then C.bark else C.woodDark
			)
		end
	end
end

-- Fence from a to b (ground points): posts every ~4 studs and two rails.
local function fence(ctx: Ctx, a: Vector3, b: Vector3, h: number?, skipFirst: boolean?)
	local hh = h or 3
	local len = (b - a).Magnitude
	local n = math.max(1, math.floor(len / 4.2 + 0.5))
	for i = if skipFirst then 1 else 0, n do
		local p = a:Lerp(b, i / n)
		block(
			ctx,
			"FencePost",
			Vector3.new(0.45, hh, 0.45),
			CFrame.new(p + Vector3.new(0, hh / 2, 0)),
			C.woodDark,
			M.Wood
		)
	end
	for _, fy in { 0.45, 0.85 } do
		beamBetween(
			ctx,
			"FenceRail",
			a + Vector3.new(0, hh * fy, 0),
			b + Vector3.new(0, hh * fy, 0),
			0.3,
			C.wood,
			M.Wood
		)
	end
end

-- ------------------------------------------------------------------ construction

-- Scaffolding along the front (-Z) and right (+X) faces of a w × d box at (cx, cz), up to height h:
-- poles, plank decks per level, cross braces and a ladder.
local function scaffold(ctx: Ctx, w: number, d: number, h: number, cx: number?, cz: number?)
	local ox, oz = cx or 0, cz or 0
	local fz = oz - d / 2 - 1.5
	local rx = ox + w / 2 + 1.5
	local ph = h + 1.6
	local poles = {
		Vector3.new(ox - w / 2 - 1.5, 0, fz),
		Vector3.new(ox + 0.5, 0, fz),
		Vector3.new(rx, 0, fz),
		Vector3.new(rx, 0, oz + d / 2 + 1.5),
	}
	for _, p in poles do
		column(ctx, "ScaffoldPole", 0.26, ph, p, C.woodLight, M.Wood)
	end
	local levels = math.clamp(math.floor(h / 5), 1, 3)
	for i = 1, levels do
		local y = i * h / (levels + 0.35)
		block(
			ctx,
			"ScaffoldPlank",
			Vector3.new(w + 3.4, 0.3, 1.3),
			CFrame.new(ox, y, fz + 0.75),
			C.woodLight,
			M.WoodPlanks
		)
		block(
			ctx,
			"ScaffoldPlank",
			Vector3.new(1.3, 0.3, d + 3.4),
			CFrame.new(rx - 0.75, y, oz),
			C.woodLight,
			M.WoodPlanks
		)
	end
	local front = CFrame.new(0, 0, fz)
	strut(ctx, "ScaffoldBrace", front, ox - w / 2 - 1.5, 0.4, ox + 0.5, ph - 0.6, 0.22, 0.22, C.woodLight, M.Wood)
	strut(ctx, "ScaffoldBrace", front, ox + 0.5, 0.4, rx, ph - 0.6, 0.22, 0.22, C.woodLight, M.Wood, -0.25)
	-- ladder leaning on the first deck
	local ly = h / (levels + 0.35)
	local lx = ox - w / 2 + 1.2
	local ladder = CFrame.new(lx, 0, fz + 0.1) * CFrame.Angles(0, PI / 2, 0) -- local +X = world -Z
	for _, sx in { -0.55, 0.55 } do
		strut(ctx, "LadderRail", ladder, 1.8, 0, 0, ly + 1, 0.22, 0.22, C.wood, M.Wood, sx)
	end
	for i = 1, 3 do
		local f = i / 4
		block(
			ctx,
			"LadderRung",
			Vector3.new(1.1, 0.18, 0.18),
			CFrame.new(lx, f * (ly + 1), fz + 0.1 - 1.8 * (1 - f)),
			C.wood,
			M.Wood
		)
	end
end

-- Building-site material pile: logs, cut stones, a plank stack.
local function materialPile(ctx: Ctx, x: number, z: number)
	logStack(ctx, CFrame.new(x, 0, z), 4.6, 2, 0.5)
	block(ctx, "PileStone", Vector3.new(2, 1.4, 2), CFrame.new(x + 3.3, 0.7, z - 0.4), C.stoneLight, M.Slate)
	block(
		ctx,
		"PileStone",
		Vector3.new(1.6, 1.2, 1.6),
		CFrame.new(x + 3.1, 2, z - 0.3) * CFrame.Angles(0, rad(20), 0),
		C.stone,
		M.Slate
	)
	block(
		ctx,
		"PilePlanks",
		Vector3.new(4.4, 0.9, 1.6),
		CFrame.new(x + 0.3, 0.45, z + 1.9) * CFrame.Angles(0, rad(8), 0),
		C.woodLight,
		M.WoodPlanks
	)
end

-- ------------------------------------------------------------------ legacy wrappers (pre-v0 signatures)

local function door(ctx: Ctx, x: number, z: number, y: number, w: number, h: number, facing: number?)
	doorAt(ctx, CFrame.new(x, y, z) * CFrame.Angles(0, rad(facing or 0), 0), { w = w, h = h, step = 0 })
end

local function window(ctx: Ctx, x: number, y: number, z: number, facing: number, shutterColor: Color3?)
	windowAt(ctx, CFrame.new(x, y, z) * CFrame.Angles(0, rad(facing), 0), { shutters = shutterColor })
end

local function plinth(ctx: Ctx, w: number, d: number, h: number)
	stonePlinth(ctx, w + 0.8, d + 0.8, h)
end

local function timberBody(ctx: Ctx, w: number, d: number, y: number, h: number)
	timberBox(ctx, w, d, y, h)
	local f = wallFrames(w, d, y)
	frameWall(ctx, f.front, w, h, {})
	frameWall(ctx, f.left, d, h, {})
end

Pieces.STONE = STONE
Pieces.TRIM = TRIM
Pieces.IVORY = IVORY
Pieces.stoneFor = stoneFor
Pieces.trimFor = trimFor
Pieces.jit = jit
Pieces.cyl = cyl
Pieces.disc = disc
Pieces.strut = strut
Pieces.beamBetween = beamBetween
Pieces.stonePlinth = stonePlinth
Pieces.quoins = quoins
Pieces.frameWall = frameWall
Pieces.wallFrames = wallFrames
Pieces.timberBox = timberBox
Pieces.tileRoof = tileRoof
Pieces.thatchRoof = thatchRoof
Pieces.leanTo = leanTo
Pieces.pyramidRoof = pyramidRoof
Pieces.gableRoof = gableRoof
Pieces.spire = spire
Pieces.dome = dome
Pieces.finial = finial
Pieces.towerCap = towerCap
Pieces.roundTower = roundTower
Pieces.crenellate = crenellate
Pieces.windowAt = windowAt
Pieces.doorAt = doorAt
Pieces.bracket = bracket
Pieces.dormer = dormer
Pieces.triangle = triangle
Pieces.EMBLEM_IVORY = EMBLEM_IVORY
Pieces.SUN_TINT = SUN_TINT
Pieces.buildEmblem = buildEmblem
Pieces.emblem = emblem
Pieces.emblemPlaque = emblemPlaque
Pieces.banner = banner
Pieces.crest = crest
Pieces.throne = throne
Pieces.THRONE_CANOPY_CLEAR = THRONE_CANOPY_CLEAR
Pieces.flagpole = flagpole
Pieces.pennant = pennant
Pieces.chimney = chimney
Pieces.gableChimney = gableChimney
Pieces.barrel = barrel
Pieces.crate = crate
Pieces.sack = sack
Pieces.logStack = logStack
Pieces.fence = fence
Pieces.scaffold = scaffold
Pieces.materialPile = materialPile
Pieces.door = door
Pieces.window = window
Pieces.plinth = plinth
Pieces.timberBody = timberBody

return Pieces
