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

-- Kingdom flag on a pole. style "emerald" (FORGE-00 calibration: the emerald plot sits on green terrain)
-- flies a lighter, high-saturation tint with a cream border; without style the Flag is the exact kingdom
-- colour (region markers, Kit.spec).
local function flagpole(ctx: Ctx, x: number, y: number, z: number, h: number, color: Color3, style: string?)
	column(ctx, "FlagPole", 0.2, h, Vector3.new(x, y, z), C.woodDark, M.Wood)
	local f = if style == "emerald" then EMERALD_LIGHT else 1
	block(ctx, "Flag", Vector3.new(3.4, 2.0, 0.15), CFrame.new(x + 1.8, y + h - 1.2, z), shade(color, f), M.Fabric, f)
	if style == "emerald" then
		block(ctx, "FlagBorder", Vector3.new(3.75, 2.35, 0.1), CFrame.new(x + 1.85, y + h - 1.2, z), IVORY, M.Fabric)
	end
	ball(ctx, "FlagFinial", 0.55, Vector3.new(x, y + h + 0.2, z), C.gold, M.Metal)
end

-- Small pennant on a pole (ridge pennants): pole, pointed kingdom-colour flag, gold knob.
local function pennant(ctx: Ctx, x: number, y: number, z: number, h: number, color: Color3, style: string?)
	column(ctx, "PennantPole", 0.13, h, Vector3.new(x, y, z), C.woodDark, M.Wood)
	local f = if style == "emerald" then EMERALD_LIGHT else 1
	block(
		ctx,
		"Pennant",
		Vector3.new(2.2, 1.3, 0.12),
		CFrame.new(x + 1.15, y + h - 0.85, z),
		shade(color, f),
		M.Fabric,
		f
	)
	block(
		ctx,
		"PennantTip",
		Vector3.new(0.92, 0.92, 0.1),
		CFrame.new(x + 2.25, y + h - 0.85, z) * CFrame.Angles(0, 0, rad(45)),
		shade(color, f),
		M.Fabric,
		f
	)
	if style == "emerald" then
		block(ctx, "PennantBorder", Vector3.new(2.5, 1.6, 0.08), CFrame.new(x + 1.2, y + h - 0.85, z), IVORY, M.Fabric)
	end
	ball(ctx, "PennantKnob", 0.4, Vector3.new(x, y + h + 0.1, z), C.gold, M.Metal)
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
	for _, fy in { 0.24, 0.7 } do
		block(ctx, "DoorStrap", Vector3.new(W * 0.84, 0.3, 0.12), cf * CFrame.new(0, hr * fy, -0.31), C.iron, M.Metal)
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

-- Kingdom emblem on a cloth/shield, centred on cf (facing -Z): crown, star, oak leaf, sun disc.
local function emblem(ctx: Ctx, cf: CFrame, size: number, style: string)
	local col = trimFor(style)
	if style == "crimson" then
		block(ctx, "Emblem", Vector3.new(size, size * 0.34, 0.12), cf * CFrame.new(0, -size * 0.22, 0), col, M.Fabric)
		-- crown: band + a wide three-point top (a long bar rotated 45° reads as the peaks at banner scale)
		block(
			ctx,
			"EmblemPoint",
			Vector3.new(size * 0.5, size * 0.5, 0.1),
			cf * CFrame.new(0, size * 0.06, 0) * CFrame.Angles(0, 0, rad(45)),
			col,
			M.Fabric
		)
	elseif style == "azure" then
		for _, a in { 0, 45 } do
			block(
				ctx,
				"Emblem",
				Vector3.new(size * 0.6, size * 0.6, if a == 0 then 0.12 else 0.1),
				cf * CFrame.Angles(0, 0, rad(a)),
				col,
				M.Fabric
			)
		end
	elseif style == "emerald" then
		block(
			ctx,
			"Emblem",
			Vector3.new(size * 0.6, size * 0.6, 0.12),
			cf * CFrame.new(0, size * 0.1, 0) * CFrame.Angles(0, 0, rad(45)),
			col,
			M.Fabric
		)
		block(
			ctx,
			"EmblemStem",
			Vector3.new(size * 0.12, size * 0.5, 0.1),
			cf * CFrame.new(0, -size * 0.38, 0),
			col,
			M.Fabric
		)
	elseif style == "gold" then
		block(
			ctx,
			"EmblemRays",
			Vector3.new(size * 0.66, size * 0.66, 0.1),
			cf * CFrame.Angles(0, 0, rad(45)),
			col,
			M.Fabric
		)
		disc(ctx, "Emblem", cf * CFrame.new(0, 0, -0.06), size * 0.62, 0.12, IVORY, M.Fabric)
	else
		block(
			ctx,
			"Emblem",
			Vector3.new(size * 0.5, size * 0.5, 0.12),
			cf * CFrame.Angles(0, 0, rad(45)),
			col,
			M.Fabric
		)
	end
end

-- Hanging banner: pole, cloth with a pointed tail, dark trim band, kingdom emblem. y = pole height.
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
	-- emerald (on green terrain): lighter, high-saturation cloth with a cream border and cream trim
	local emerald = (style or hueStyle(color)) == "emerald"
	local f = if emerald then EMERALD_LIGHT else 1
	block(ctx, "Banner", Vector3.new(bw, hh, 0.2), base * CFrame.new(0, -hh / 2, -0.45), shade(color, f), M.Fabric, f)
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
		block(ctx, "BannerTrim", Vector3.new(bw + 0.04, 0.42, 0.24), base * CFrame.new(0, -0.6, -0.45), IVORY, M.Fabric)
	else
		block(
			ctx,
			"BannerTrim",
			Vector3.new(bw + 0.04, 0.42, 0.24),
			base * CFrame.new(0, -0.6, -0.45),
			shade(color, 0.55),
			M.Fabric,
			0.55
		)
	end
	emblem(ctx, base * CFrame.new(0, -hh * 0.48, -0.6), bw * 0.62, style or "neutral")
end

-- Heater shield crest (kingdom colour + emblem) on a wall: cf at the shield centre, facing -Z.
local function crest(ctx: Ctx, cf: CFrame, size: number, color: Color3, style: string)
	block(
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
	emblem(ctx, cf * CFrame.new(0, 0, -0.24), size * 0.55, style)
end

-- Throne on a three-step dais (G13.6). cf = the dais' back-centre on the floor, local -Z = the way the
-- throne faces. Seat "Throne" (Anchored, CanCollide) with a tall kingdom-colour back and gold trim. The back
-- stands 0.35 in front of cf (clear of a door leaf and its straps behind it). canopyY (height above cf)
-- adds a baldachin: two tall posts, a kingdom-cloth gabled canopy and a gold finial (5 parts),
-- high above the seat so the throne spot reads from behind and from high aerial angles while the seat stays
-- open to oblique views. Every part carries the attribute KitThrone. Returns the Seat and the dais top.
local function throne(
	ctx: Ctx,
	cf: CFrame,
	color: Color3,
	style: string,
	stone: Stone?,
	canopyY: number?
): (BasePart, number)
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
	block(
		ctx,
		"DaisCarpet",
		Vector3.new(4, 0.1, 3.2),
		cf * CFrame.new(0, top + 0.05, sz),
		shade(color, 0.7),
		M.Fabric,
		0.7
	)
	block(ctx, "ThroneBase", Vector3.new(3.6, 1, 3.1), cf * CFrame.new(0, top + 0.53, sz), C.woodDark, M.Wood)
	local seat = Instance.new("Seat")
	seat.Shape = Enum.PartType.Block
	seat.Size = Vector3.new(3, 1, 3)
	seat.CFrame = cf * CFrame.new(0, top + 1.5, sz)
	seat.CanCollide = true
	finish(seat, ctx, "Throne", shade(color, 0.85), M.Fabric, 0.85)
	for _, sx in { -1, 1 } do
		block(ctx, "ThroneArm", Vector3.new(0.5, 1, 2.8), cf * CFrame.new(sx * 1.85, top + 2.4, sz), C.gold, M.Metal)
		ball(ctx, "ThroneFinial", 0.85, (cf * CFrame.new(sx * 1.8, top + 7.35, sz + 0.8)).Position, C.gold, M.Metal)
	end
	-- back: rear face 0.45 in front of cf (the keep puts cf 0.4 before the bay face: clear of door and voussoirs)
	block(ctx, "ThroneBack", Vector3.new(3.6, 5.5, 0.7), cf * CFrame.new(0, top + 3.85, sz + 0.8), color, M.Fabric, 1)
	block(ctx, "ThroneTrim", Vector3.new(4.1, 0.5, 0.9), cf * CFrame.new(0, top + 6.85, sz + 0.7), C.gold, M.Metal)
	emblem(ctx, cf * CFrame.new(0, top + 4.6, sz + 0.37), 1.8, style)
	if canopyY then
		local f = if style == "emerald" then EMERALD_LIGHT else 1
		local pz, cw, rise = -4.0, 8.2, 1.7
		for _, sx in { -1, 1 } do
			column(
				ctx,
				"BaldachinPost",
				0.22,
				canopyY + 0.2,
				(cf * CFrame.new(sx * 3.6, 0, pz)).Position,
				C.woodDark,
				M.Wood
			)
		end
		local zf, zb = pz - 0.45, 0.35 -- canopy from just past the posts back over the bay's merlons
		local half = (zb - zf) / 2
		local zc = (zf + zb) / 2
		wedge(
			ctx,
			"BaldachinCanopy",
			Vector3.new(cw, rise, half),
			cf * CFrame.new(0, canopyY + rise / 2, zc - half / 2),
			shade(color, f),
			M.Fabric,
			f
		)
		wedge(
			ctx,
			"BaldachinCanopy",
			Vector3.new(cw, rise, half),
			cf * CFrame.new(0, canopyY + rise / 2, zc + half / 2) * CFrame.Angles(0, PI, 0),
			shade(color, f),
			M.Fabric,
			f
		)
		ball(ctx, "BaldachinFinial", 1.1, (cf * CFrame.new(0, canopyY + rise + 0.35, zc)).Position, C.gold, M.Metal)
	end
	local children = ctx.model:GetChildren()
	for i = first + 1, #children do
		children[i]:SetAttribute("KitThrone", true)
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
Pieces.emblem = emblem
Pieces.banner = banner
Pieces.crest = crest
Pieces.throne = throne
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
