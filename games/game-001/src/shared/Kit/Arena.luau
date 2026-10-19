--!strict
--[[
	Kit/Arena — the Crown Arena venue (FL-0072, CONTRACTS G12.6, design/crown-arena.md §1, §7; D-026 primitive Parts
	only, nothing yields; D-053 the match ends here). Owner: FORGE-02.

	Kit.arena(kingdomA?, kingdomB?) -> Model. Built once by WorldService (server world); the crowd is client-only.
	Local frame (the Kit convention): pivot = the ring's centre on the ground, Root = the footprint plate. Two stands face each
	other across the ring on the Z axis (Stand A at -Z, Stand B at +Z), the two champion gates close the X axis (Gate A at -X,
	Gate B at +X). Everything is mirrored through the centre: stand/gate A is stand/gate B turned 180° about Y.

	Plan (studs)                         ring floor radius 23 (sand + a painted line at the duel radius 21), apron slab 74 x 73
	  stands     z = 24.2 .. 35.4       a rail podium (key citizens) and 4 rows, each 1.5 higher than the last; 24 seat places
	                                     a row, the 6 in front of the royal box left empty -> 72 seats a stand, 6 rail places
	  royal box  x = -6.4 .. 6.4        a tribune over rows 2-4 on the stand's centre line, a pavilion on four posts with the
	                                     kingdom's tower cap and flag, three chairs, the kingdom plaque on its face
	  gates      |x| = 29.5 .. 36.5    gatehouse of two crenellated towers (kingdom caps and banners) round an 8.8-wide passage
	  braziers   8, banners and standards on the stands, gates and corners, a kingdom rug and emblem under each champion

	Attachments (all on Root, CFrames in the model frame: -Z of the attachment looks at the ring centre, so a figure placed
	with figure:PivotTo(attachment.WorldCFrame) faces the ring and stands on the seat):
	  StandA_Row<r>_Seat<s>     r = 1 (front, lowest) .. 4 (back, highest); s = 1 .. 18 from the viewer's left (looking at the
	                            ring) to the right; the royal-box gap is skipped, so the numbers stay contiguous. 72 a stand.
	                            Attributes: Stand ("A" | "B"), Row, Seat.
	  StandA_Rail<n>            n = 1 .. 6 on the rail podium, left to right, for the key citizens (KeyRole order of G12.1:
	                            blacksmith, healer, captain, provisioner, elder, merchant). Attributes: Stand, Rail.
	  StandA_Royal<n>           n = 1 .. 3 the royal box's chairs; StandA_RoyalBox its centre (deck level).
	  GateA, GateB              where a champion appears: on the gate threshold, looking at the ring.
	  SpawnA, SpawnB            the champions' start marks, 3 studs above the ring floor, looking at each other (= Layout.arena
	                            spawnA / spawnB). Centre: the ring's centre on the floor.
	  (the same names with B for the opposite stand)

	Kingdom dress. The structure is neutral stone, timber and sand. Everything that carries a kingdom (rug and emblem under
	the champion, royal pavilion cap, flag and plaque, chairs, gate caps and banners, standards and banners on the stand)
	lives in two sub-models, DressA and DressB, built for one colour each: Kit.arena(colorA, colorB) builds them, and
	Kit.arenaDress(model, colorA, colorB) rebuilds them in place when the two kingdoms are known (ArenaService, server).
	A neutral colour builds the neutral dress (no emblems, the plain timber caps). Each dress is the kingdom's silhouette
	(spire / pyramid / hoarding / dome caps, D-033) AND its emblem (D-039): never colour alone. The dress parts carry KitTint and
	KitSide = "A" | "B"; Kit.setKingdomColor(model:FindFirstChild("DressA"), color) also recolours one side in place.

	Part budget: the task asked for 1,500, D-047's 27k world ceiling leaves about 1,000, so the target is 700 and the hard cap 900
	(Arena.PART_BUDGET); the spec pins the count for every kingdom pair.
]]

local Parts = require("./Parts")
local KingdomStyle = require("./KingdomStyle")
local Pieces = require("./Pieces")

local C = Parts.C
local shade = Parts.shade
local hueStyle = Parts.hueStyle
local newModel = Parts.newModel
local block = Parts.block
local wedge = Parts.wedge
local column = Parts.column
local ball = Parts.ball

type Ctx = Parts.Ctx

local M = Enum.Material
local PI = math.pi

local Arena = {}

-- ------------------------------------------------------------------ dimensions (model frame, studs)

Arena.PART_BUDGET = table.freeze({ target = 700, cap = 900 })
Arena.FOOTPRINT = Vector2.new(75, 74) -- Root plate: X (gate axis) x Z (stand axis); every part stays inside
Arena.RING_RADIUS = 23 -- the sand disc
Arena.DUEL_RADIUS = 21 -- the painted line; Layout.arena.duelRadius
Arena.SPAWN_X = 13 -- |x| of the champions' marks
Arena.SLAB_TOP = 0.8 -- the apron slab's top above the ground
Arena.SKIRT_RUN = 3.0 -- the ground blend: a sloped skirt this wide round the apron, and a short sand path at each gate
Arena.PATH_LEN = 1.5
Arena.GROUND_REACH = 4.0 -- the blend reaches at most this far past the Root plate (WorldPlan keeps decor 4 studs off the plate)
Arena.FLOOR_TOP = 1.12 -- the ring floor's top: where champions stand
Arena.SPAWN_HEIGHT = 3 -- spawn marks, above the floor (like the plots' spawns above the ground)
Arena.STAND_HALF = 29 -- rows span x in [-29, 29]
Arena.SEAT_ROWS = 4
Arena.SEATS_PER_ROW = 24 -- places a row before the royal gap; 18 seats remain (6 in front of the box)
Arena.SEAT_SPACING = 2.4
Arena.ROYAL_HALF = 6.4 -- the royal box spans x in [-6.4, 6.4]
Arena.RAIL_SEATS = 6
Arena.GATE_Z = 29.5 -- the gate towers' ring-side face (distance from the centre)

local SLAB_TOP = Arena.SLAB_TOP
local FLOOR_TOP = Arena.FLOOR_TOP
local PODIUM_Z0, PODIUM_D, PODIUM_TOP = 24.2, 2.2, 2.2
local ROW_Z0, ROW_D, ROW_RISE = 26.4, 2.0, 1.5
local WALL_Z0 = ROW_Z0 + ROW_D * Arena.SEAT_ROWS -- 34.4: the stand's back wall starts
local HALF = Arena.STAND_HALF
local ROYAL_FACE = 28.35 -- the royal tribune's ring-side face (0.05 in front of row 2's, never coplanar)
local ROYAL_BACK = 34.2
local DECK_Y = 8.5 -- the royal deck: over row 4's plank (top 8.4), never coplanar with it
local POST_H = 6.4
local ROOF_Y = DECK_Y + POST_H -- 14.8: the pavilion roof slab's underside
local GATE_PASS = 4.4 -- half width of the gate passage
local TOWER_W, TOWER_D, TOWER_H = 7, 7, 18 -- gate towers (square, like the Kit gate)
local TOWER_X = GATE_PASS + TOWER_W / 2 -- 7.9: tower centre across the passage
local TOWER_Z = Arena.GATE_Z + TOWER_D / 2 -- 33: tower centre from the ring centre
local TOWER_TOP = SLAB_TOP + TOWER_H + 0.6 -- 19.4: top of the corbel
local WALL_TOP = 6.6 -- the gate end walls and the corner platforms

local IVORY = Pieces.IVORY
local NEUTRAL = Color3.fromRGB(208, 200, 184) -- Kit.NEUTRAL_COLOR (Kit.luau requires this module)
local SAND = Color3.fromRGB(230, 200, 146) -- pale: reads against grass, never as the gold kingdom
local SAND_EDGE = Color3.fromRGB(200, 168, 118)
local EMBER = Color3.fromRGB(255, 132, 44)
local FLAME = Color3.fromRGB(255, 226, 120)
local FLAME_MID = Color3.fromRGB(255, 176, 56)

local function rowTop(k: number): number
	return PODIUM_TOP + ROW_RISE * k
end

-- Seat x positions across a row (viewer's left to right), the royal-box gap skipped.
local function seatXs(): { number }
	local out = {}
	local n = Arena.SEATS_PER_ROW
	for i = 1, n do
		local x = (i - (n + 1) / 2) * Arena.SEAT_SPACING
		if math.abs(x) > Arena.ROYAL_HALF + 0.6 then
			table.insert(out, x)
		end
	end
	return out
end
Arena.SEATS_PER_STAND = #seatXs() * Arena.SEAT_ROWS -- 72

local RAIL_X = { -16.2, -10.2, -4.2, 4.2, 10.2, 16.2 }
local ROYAL_X = { -3, 0, 3 }

-- ------------------------------------------------------------------ frames and helpers

-- Stand B is built at +Z facing the ring (-Z); every side is that turned about Y. Gates: the same, +Z outward.
local FRAME_STAND = { A = CFrame.Angles(0, PI, 0), B = CFrame.new() }
local FRAME_GATE = { A = CFrame.Angles(0, -PI / 2, 0), B = CFrame.Angles(0, PI / 2, 0) }

-- A hanging banner's cloth hang, shortened so that the cloth, its kingdom-style length (KingdomStyle banner.length) and its tail
-- (a long pennon hangs a full cloth-width below the cloth, the others about half) stay at or above the ground: the same hang the
-- arena used before the kingdom styles must not reach below y = 0 now that Frostmere's tail and Emberhold's hang are longer.
local function fitHang(style: string, y: number, h: number, width: number): number
	local banner = KingdomStyle.get(style).banner
	local tail = if banner.tip == "long" then width * 1.05 else width * 0.5
	return math.min(h, math.max(1, (y - 0.15 - tail) / banner.length))
end

-- Yaw (degrees, Pieces.banner's `facing`) that turns a banner's front (-Z) to the direction d on the XZ plane.
local function facingOf(d: Vector3): number
	return math.deg(math.atan2(-d.X, -d.Z))
end

-- A box in a frame F: size and centre in the frame's coordinates.
local function box(
	ctx: Ctx,
	F: CFrame,
	name: string,
	cx: number,
	cy: number,
	cz: number,
	sx: number,
	sy: number,
	sz: number,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	return block(ctx, name, Vector3.new(sx, sy, sz), F * CFrame.new(cx, cy, cz), color, material, tint)
end

-- Box with its bottom on y0 (height sy) in a frame F.
local function boxOn(
	ctx: Ctx,
	F: CFrame,
	name: string,
	cx: number,
	y0: number,
	cz: number,
	sx: number,
	sy: number,
	sz: number,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	return box(ctx, F, name, cx, y0 + sy / 2, cz, sx, sy, sz, color, material, tint)
end

local function pole(
	ctx: Ctx,
	F: CFrame,
	name: string,
	r: number,
	x: number,
	y0: number,
	z: number,
	h: number,
	color: Color3
)
	return column(ctx, name, r, h, F:PointToWorldSpace(Vector3.new(x, y0, z)), color, M.Wood)
end

local function attachAt(ctx: Ctx, name: string, cf: CFrame, attributes: { [string]: any }?): Attachment
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = ctx.root.CFrame:ToObjectSpace(cf) -- Root sits at y = 0.1 (Parts.newModel)
	for k, v in attributes or {} do
		a:SetAttribute(k, v)
	end
	a.Parent = ctx.root
	return a
end

-- ------------------------------------------------------------------ neutral structure

-- warm travertine, not the cold grey of the keeps: the venue is sunlit and unsaturated, so the two kingdoms' colours carry it
local S = {
	base = Color3.fromRGB(193, 180, 152),
	light = Color3.fromRGB(226, 215, 188),
	dark = Color3.fromRGB(143, 130, 108),
}

local function buildFloor(ctx: Ctx)
	local fp = Arena.FOOTPRINT
	block(
		ctx,
		"Apron",
		Vector3.new(fp.X - 1, SLAB_TOP, fp.Y - 1),
		CFrame.new(0, SLAB_TOP / 2, 0),
		S.light,
		M.Cobblestone
	)
	local o = Vector3.new(0, SLAB_TOP, 0)
	column(ctx, "RingBand", Arena.RING_RADIUS + 1.6, 0.1, o, S.dark, M.Slate)
	column(ctx, "Sand", Arena.RING_RADIUS + 0.4, 0.2, o, SAND_EDGE, M.Sand)
	column(ctx, "RingLine", Arena.DUEL_RADIUS + 0.55, 0.26, o, IVORY, M.SmoothPlastic)
	column(ctx, "SandInner", Arena.DUEL_RADIUS - 0.55, 0.32, o, SAND, M.Sand)
	-- the centre mark: stone dais, ivory ring, dark eye
	column(ctx, "Dais", 5, 0.38, o, S.light, M.Slate)
	column(ctx, "DaisRing", 3.8, 0.44, o, IVORY, M.SmoothPlastic)
	column(ctx, "DaisEye", 1.8, 0.5, o, S.dark, M.Slate)
end

-- The ground blend (FL-0072 review: the plinth sat raw on the grass): a skirt of wedges sloping from the apron's top to the ground
-- on all four sides, and at each gate a sand ramp and a short flat path in the passage's width. 10 parts, none above SLAB_TOP.
-- A wedge's tall wall is its local +Z, so each is turned to put that wall against the apron.
local function buildGround(ctx: Ctx)
	local fp = Arena.FOOTPRINT
	local ax, az = (fp.X - 1) / 2, (fp.Y - 1) / 2 -- the apron's half extents
	local run = Arena.SKIRT_RUN
	local pathHalf = GATE_PASS - 0.2
	local function skirt(length: number, cf: CFrame)
		wedge(ctx, "Skirt", Vector3.new(length, SLAB_TOP, run), cf, S.base, M.Cobblestone)
	end
	-- the stand sides (+Z and -Z of the plan), each the full apron length
	skirt(2 * ax, CFrame.new(0, SLAB_TOP / 2, -(az + run / 2 - 0.05)))
	skirt(2 * ax, CFrame.new(0, SLAB_TOP / 2, az + run / 2 - 0.05) * CFrame.Angles(0, PI, 0))
	-- the gate sides (+X and -X): two skirts either side of the path, the sand ramp between them
	local len = az - pathHalf
	for _, sx in { -1, 1 } do
		local turn = CFrame.Angles(0, -sx * PI / 2, 0)
		local x = sx * (ax + run / 2 - 0.05)
		for _, sz in { -1, 1 } do
			skirt(len, CFrame.new(x, SLAB_TOP / 2, sz * (pathHalf + len / 2)) * turn)
		end
		wedge(
			ctx,
			"PathRamp",
			Vector3.new(2 * pathHalf, SLAB_TOP, run),
			CFrame.new(x, SLAB_TOP / 2, 0) * turn,
			SAND_EDGE,
			M.Sand
		)
		block(
			ctx,
			"PathSlab",
			Vector3.new(Arena.PATH_LEN, 0.12, 2 * pathHalf),
			CFrame.new(sx * (ax + run + Arena.PATH_LEN / 2), 0.06, 0),
			SAND_EDGE,
			M.Sand
		)
	end
end

local function buildStand(ctx: Ctx, F: CFrame)
	local hw = 2 * HALF
	-- the rail podium in front of the first row: where the key citizens stand
	boxOn(
		ctx,
		F,
		"Podium",
		0,
		SLAB_TOP,
		PODIUM_Z0 + PODIUM_D / 2,
		hw,
		PODIUM_TOP - SLAB_TOP,
		PODIUM_D,
		S.light,
		M.Slate
	)
	boxOn(ctx, F, "Parapet", 0, PODIUM_TOP, PODIUM_Z0 + 0.25, hw, 0.5, 0.5, IVORY, M.Slate)
	for k = 1, Arena.SEAT_ROWS do
		local top = rowTop(k)
		local z0 = ROW_Z0 + ROW_D * (k - 1)
		boxOn(
			ctx,
			F,
			"Row",
			0,
			SLAB_TOP,
			z0 + ROW_D / 2,
			hw,
			top - SLAB_TOP,
			ROW_D,
			if k % 2 == 1 then S.base else S.light,
			M.Cobblestone
		)
		-- a plank walkway along the row: the crowd stands on it
		boxOn(ctx, F, "RowPlank", 0, top, z0 + ROW_D / 2, hw - 1.2, 0.2, 1.1, C.wood, M.WoodPlanks)
	end
	-- back wall, coping and buttresses
	local wallTop = rowTop(Arena.SEAT_ROWS) + 2.2
	boxOn(ctx, F, "BackWall", 0, SLAB_TOP, WALL_Z0 + 0.5, hw + 4, wallTop - SLAB_TOP, 1.0, S.base, M.Cobblestone)
	boxOn(ctx, F, "Coping", 0, wallTop, WALL_Z0 + 0.5, hw + 5, 0.5, 1.8, S.light, M.Slate)
	for _, x in { -25, -17, -9, 9, 17, 25 } do
		boxOn(
			ctx,
			F,
			"Buttress",
			x,
			SLAB_TOP,
			WALL_Z0 + 1.0 + 0.6,
			1.6,
			wallTop - SLAB_TOP - 0.6,
			1.2,
			S.dark,
			M.Cobblestone
		)
	end
	-- the end wedges cap each end of the tiers (a slope 0.25 over every step's lip)
	local rise = ROW_RISE / ROW_D -- 0.75
	local depth = WALL_Z0 - PODIUM_Z0
	for _, sx in { -1, 1 } do
		wedge(
			ctx,
			"EndWedge",
			Vector3.new(2, rise * depth, depth),
			F * CFrame.new(sx * (HALF + 1), SLAB_TOP + rise * depth / 2, PODIUM_Z0 + depth / 2),
			S.dark,
			M.Cobblestone
		)
	end
	-- the corner platforms close the plan behind the end wedges (braziers and standards stand on them)
	for _, sx in { -1, 1 } do
		boxOn(ctx, F, "Corner", sx * 34, SLAB_TOP, 30.3, 6, WALL_TOP - SLAB_TOP, 12.2, S.base, M.Cobblestone)
	end
end

-- The royal tribune over rows 2-4 on the centre line: stone block, parapet and four posts. The pavilion roof and cap, the
-- flag, the plaque and the chairs are the kingdom's (dress).
local function buildTribune(ctx: Ctx, F: CFrame)
	local hw = Arena.ROYAL_HALF
	local depth = ROYAL_BACK - ROYAL_FACE
	boxOn(ctx, F, "Tribune", 0, 3.0, ROYAL_FACE + depth / 2, 2 * hw, DECK_Y - 3.0, depth, S.base, M.Cobblestone)
	boxOn(ctx, F, "RoyalParapet", 0, DECK_Y, ROYAL_FACE + 0.3, 2 * hw, 1.0, 0.6, S.light, M.Slate)
	for _, sx in { -1, 1 } do
		boxOn(ctx, F, "RoyalSide", sx * (hw - 0.3), DECK_Y, ROYAL_FACE + 3.4, 0.6, 0.8, 5.0, S.light, M.Slate)
		for _, z in { ROYAL_FACE + 1.5, ROYAL_BACK - 0.9 } do
			pole(ctx, F, "RoyalPost", 0.4, sx * (hw - 0.7), DECK_Y, z, POST_H, C.woodDark)
		end
	end
end

-- Gatehouse on the +Z side of a gate frame G: two square towers round the passage, a lintel with crenellations, a raised
-- portcullis, and the walls that run to the stands. Kingdom caps, banners and the crest are dress.
local function merlon(ctx: Ctx, G: CFrame, cx: number, y0: number, cz: number, sx: number, sz: number, color: Color3)
	boxOn(ctx, G, "Merlon", cx, y0, cz, sx, 2.2, sz, color, M.Slate)
end

local function buildGate(ctx: Ctx, G: CFrame)
	local z0 = Arena.GATE_Z
	for _, sx in { -1, 1 } do
		local cx = sx * TOWER_X
		boxOn(ctx, G, "GateTower", cx, SLAB_TOP, TOWER_Z, TOWER_W, TOWER_H, TOWER_D, S.base, M.Cobblestone)
		boxOn(ctx, G, "TowerCorbel", cx, TOWER_TOP - 1.0, TOWER_Z, TOWER_W + 0.8, 1.0, TOWER_D + 0.8, S.light, M.Slate)
		-- a stone band midway up
		boxOn(ctx, G, "TowerCourse", cx, 8.6, TOWER_Z, TOWER_W + 0.4, 0.6, TOWER_D + 0.4, S.light, M.Slate)
		-- merlons round the top, the middle one on each side, the corners covered by the long rows
		for _, u in { -2.3, 0, 2.3 } do
			for _, dz in { -1, 1 } do
				merlon(ctx, G, cx + u, TOWER_TOP, TOWER_Z + dz * 3.5, 1.8, 0.8, S.light)
			end
		end
		for _, dx in { -1, 1 } do
			merlon(ctx, G, cx + dx * 3.5, TOWER_TOP, TOWER_Z, 0.8, 1.8, S.light)
		end
	end
	-- lintel over the passage, crenellated front and back
	local lintelY0 = 9.0
	boxOn(ctx, G, "Lintel", 0, lintelY0, TOWER_Z, 2 * GATE_PASS, 4.6, TOWER_D, S.base, M.Cobblestone)
	boxOn(ctx, G, "LintelCornice", 0, lintelY0 - 0.6, z0 + 0.3, 2 * GATE_PASS, 0.6, 0.6, S.light, M.Slate)
	for _, u in { -2.6, 0, 2.6 } do
		for _, dz in { -1, 1 } do
			merlon(ctx, G, u, lintelY0 + 4.6, TOWER_Z + dz * 3.0, 1.8, 1.0, S.light)
		end
	end
	-- raised portcullis at the passage's outer end: five spikes hanging from the lintel (a champion's head clears them)
	for i = 0, 4 do
		boxOn(
			ctx,
			G,
			"PortcullisBar",
			-3.2 + i * 1.6,
			lintelY0 - 1.9,
			z0 + TOWER_D - 1.2,
			0.35,
			1.9,
			0.35,
			C.iron,
			M.Metal
		)
	end
	boxOn(
		ctx,
		G,
		"PortcullisRail",
		0,
		lintelY0 - 1.0,
		z0 + TOWER_D - 1.2,
		2 * GATE_PASS - 0.4,
		0.3,
		0.3,
		C.iron,
		M.Metal
	)
	-- end walls from the towers to the stands, and their copings
	for _, sx in { -1, 1 } do
		boxOn(ctx, G, "EndWall", sx * 17.8, SLAB_TOP, 32.5, 12.8, WALL_TOP - SLAB_TOP, 5, S.base, M.Cobblestone)
		boxOn(ctx, G, "EndCoping", sx * 17.8, WALL_TOP, 32.5, 12.8, 0.4, 5.6, S.light, M.Slate)
		for _, u in { -4.5, 0, 4.5 } do
			merlon(ctx, G, sx * 17.8 + u, WALL_TOP + 0.4, 30.4, 2.2, 0.9, S.light)
		end
	end
end

-- A brazier: stone foot, iron bowl, a flame of three stacked balls (ember, orange, bright tip). x, y0, z in the model frame.
local function brazier(ctx: Ctx, x: number, y0: number, z: number)
	column(ctx, "BrazierFoot", 0.75, 1.8, Vector3.new(x, y0, z), S.dark, M.Cobblestone)
	column(ctx, "BrazierBowl", 1.35, 0.55, Vector3.new(x, y0 + 1.8, z), C.iron, M.Metal)
	ball(ctx, "Flame", 1.9, Vector3.new(x, y0 + 2.7, z), EMBER, M.Neon)
	ball(ctx, "FlameMid", 1.3, Vector3.new(x, y0 + 3.55, z), FLAME_MID, M.SmoothPlastic)
	ball(ctx, "FlameTip", 0.7, Vector3.new(x, y0 + 4.3, z), FLAME, M.SmoothPlastic)
end

-- ------------------------------------------------------------------ kingdom dress

-- A kingdom's cap on a tower or the royal roof. Emerald's is an overhanging timber hoarding under a FLAT kingdom roof (not the
-- Kit's low pyramid, which read like azure's pyramid at 170 studs: the review), so the four caps are a spire, a pyramid, a flat
-- slab and a dome. The others are the Kit's.
local function kingdomCap(
	ctx: Ctx,
	style: string,
	w: number,
	y: number,
	color: Color3,
	x: number,
	z: number,
	flagH: number?
)
	if style ~= "emerald" then
		return Pieces.towerCap(ctx, style, w, y, color, x, z, flagH)
	end
	block(ctx, "HoardingBeam", Vector3.new(w + 2.8, 0.6, w + 2.8), CFrame.new(x, y + 0.3, z), C.timber, M.Wood)
	block(ctx, "Hoarding", Vector3.new(w + 2.4, 3.1, w + 2.4), CFrame.new(x, y + 1.85, z), C.wood, M.WoodPlanks)
	block(
		ctx,
		"HoardingRoof",
		Vector3.new(w + 3.6, 0.7, w + 3.6),
		CFrame.new(x, y + 3.75, z),
		shade(color, 1.2),
		M.SmoothPlastic,
		1.2
	)
	local top = y + 4.1
	if flagH and flagH > 0 then
		Pieces.flagpole(ctx, x, top - 0.3, z, flagH, color, style)
		return top + flagH
	end
	ball(ctx, "HoardingFinial", 0.7, Vector3.new(x, top + 0.2, z), C.gold, M.Metal)
	return top + 0.6
end

-- One side's kingdom parts, in their own sub-model so they can be rebuilt on their own. A neutral colour gives the neutral dress.
local function buildDress(model: Model, root: BasePart, side: string, color: Color3)
	local dress = Instance.new("Model")
	dress.Name = `Dress{side}`
	local ctx: Ctx = { model = dress, root = root, count = 0, slots = 0 }
	local style = hueStyle(color)
	local F, G = FRAME_STAND[side], FRAME_GATE[side]
	local toRing = F:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local hw = Arena.ROYAL_HALF
	local depth = ROYAL_BACK - ROYAL_FACE
	local zc = ROYAL_FACE + depth / 2 + 0.3

	-- royal pavilion: a kingdom-cloth roof on the posts with the kingdom's cap and flag, a valance over the front, the plaque on
	-- the tribune
	box(ctx, F, "RoyalRoof", 0, ROOF_Y + 0.35, zc, 2 * hw + 1.4, 0.7, depth + 0.6, shade(color, 0.9), M.Fabric, 0.9)
	local capAt = F:PointToWorldSpace(Vector3.new(0, 0, zc))
	kingdomCap(ctx, style, 4.6, ROOF_Y + 0.7, color, capAt.X, capAt.Z, 3.5)
	local roofFront = ROYAL_FACE - 0.1
	box(ctx, F, "RoyalValance", 0, ROOF_Y - 0.6, roofFront, 2 * hw + 1.4, 1.2, 0.2, shade(color, 0.85), M.Fabric, 0.85)
	Pieces.emblemPlaque(ctx, F * CFrame.new(0, 6.9, ROYAL_FACE - 0.25), 4.4, color)
	for _, x in ROYAL_X do
		boxOn(ctx, F, "ChairSeat", x, DECK_Y, ROYAL_BACK - 2.6, 1.8, 0.85, 1.6, C.woodDark, M.Wood)
		boxOn(ctx, F, "ChairBack", x, DECK_Y + 0.85, ROYAL_BACK - 1.6, 1.8, 2.4, 0.35, shade(color, 0.9), M.Fabric, 0.9)
	end

	-- the stand's colour: a band of kingdom cloth on each step's riser (rows 2-4 stop short of the tribune)
	for k = 1, Arena.SEAT_ROWS do
		local z0 = ROW_Z0 + ROW_D * (k - 1)
		local y = rowTop(k) - ROW_RISE / 2
		if k == 1 then
			box(ctx, F, "RiserBand", 0, y, z0 - 0.06, 2 * HALF - 0.6, ROW_RISE - 0.3, 0.12, color, M.Fabric, 1)
		else
			local x0, x1 = hw + 0.4, HALF - 0.3
			for _, sx in { -1, 1 } do
				box(
					ctx,
					F,
					"RiserBand",
					sx * (x0 + x1) / 2,
					y,
					z0 - 0.06,
					x1 - x0,
					ROW_RISE - 0.3,
					0.12,
					color,
					M.Fabric,
					1
				)
			end
		end
	end

	-- hanging banners on the back wall, facing out into the valley
	local out = F:VectorToWorldSpace(Vector3.new(0, 0, 1))
	for _, x in { -21, -13, 13, 21 } do
		local p = F:PointToWorldSpace(Vector3.new(x, 0, WALL_Z0 + 1.0 - 0.1))
		Pieces.banner(ctx, p.X, 9.9, p.Z, facingOf(out), color, fitHang(style, 9.9, 7.5, 4.0), style, 4.0)
	end

	-- the champion's rug under the spawn mark: kingdom field, ivory border, emblem; emblem-up looks at the opponent
	local sx = if side == "A" then -1 else 1
	local up = Vector3.new(-sx, 0, 0)
	local rug = CFrame.fromMatrix(
		Vector3.new(sx * Arena.SPAWN_X, FLOOR_TOP + 0.3, 0),
		Vector3.new(up.Z, 0, -up.X),
		up,
		Vector3.new(0, -1, 0)
	)
	Pieces.emblemPlaque(ctx, rug, 7.4, color)

	-- the champion's gate: a kingdom cap on each tower, a banner on each tower face and the crest over the passage
	for _, tx in { -1, 1 } do
		local at = G:PointToWorldSpace(Vector3.new(tx * TOWER_X, 0, TOWER_Z))
		kingdomCap(ctx, style, 4.2, TOWER_TOP + 0.03, color, at.X, at.Z) -- 0.03 clear of the merlons' bottoms (never coplanar)
		local face = G:PointToWorldSpace(Vector3.new(tx * TOWER_X, 0, Arena.GATE_Z + 0.1))
		Pieces.banner(
			ctx,
			face.X,
			17.4,
			face.Z,
			facingOf(G:VectorToWorldSpace(Vector3.new(0, 0, -1))),
			color,
			7.5,
			style,
			3.0
		)
	end
	Pieces.crest(ctx, G * CFrame.new(0, 11.4, Arena.GATE_Z - 0.175), 3.4, color, style)

	-- standards on the stand's two corner platforms, facing the ring
	for _, cx in { -1, 1 } do
		local at = F:PointToWorldSpace(Vector3.new(cx * 34, WALL_TOP + 10.6, 27.0))
		Pieces.banner(ctx, at.X, at.Y, at.Z, facingOf(toRing), color, 6.5, style, 3.0)
	end

	for _, d in dress:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("KitSide", side)
		end
	end
	dress.Parent = model
end

-- ------------------------------------------------------------------ build

local function buildAttachments(ctx: Ctx)
	local xs = seatXs()
	for _, side in { "A", "B" } do
		local F = FRAME_STAND[side]
		for r = 1, Arena.SEAT_ROWS do
			local z = ROW_Z0 + ROW_D * (r - 1) + ROW_D / 2
			for s, x in xs do
				attachAt(
					ctx,
					`Stand{side}_Row{r}_Seat{s}`,
					F * CFrame.new(x, rowTop(r) + 0.2, z),
					{ Stand = side, Row = r, Seat = s }
				)
			end
		end
		for n, x in RAIL_X do
			attachAt(
				ctx,
				`Stand{side}_Rail{n}`,
				F * CFrame.new(x, PODIUM_TOP, PODIUM_Z0 + 1.35),
				{ Stand = side, Rail = n }
			)
		end
		for n, x in ROYAL_X do
			attachAt(
				ctx,
				`Stand{side}_Royal{n}`,
				F * CFrame.new(x, DECK_Y + 0.85, ROYAL_BACK - 2.6),
				{ Stand = side, Royal = n }
			)
		end
		attachAt(
			ctx,
			`Stand{side}_RoyalBox`,
			F * CFrame.new(0, DECK_Y, (ROYAL_FACE + ROYAL_BACK) / 2),
			{ Stand = side }
		)
		attachAt(ctx, `Gate{side}`, FRAME_GATE[side] * CFrame.new(0, SLAB_TOP, Arena.GATE_Z + 2.2), { Side = side })
		local sx = if side == "A" then -1 else 1
		attachAt(
			ctx,
			`Spawn{side}`,
			CFrame.new(sx * Arena.SPAWN_X, FLOOR_TOP + Arena.SPAWN_HEIGHT, 0) * CFrame.Angles(0, sx * PI / 2, 0),
			{ Side = side }
		)
	end
	attachAt(ctx, "Centre", CFrame.new(0, FLOOR_TOP, 0))
end

local function addDressAttributes(model: Model, colorA: Color3, colorB: Color3)
	model:SetAttribute("KitColorA", colorA)
	model:SetAttribute("KitColorB", colorB)
end

-- Kit.arena(colorA?, colorB?): the venue with each stand and gate dressed for its kingdom (default: neutral).
function Arena.build(colorA: Color3?, colorB: Color3?): Model
	local ca, cb = colorA or NEUTRAL, colorB or NEUTRAL
	local ctx = newModel("arena", Arena.FOOTPRINT)
	local model = ctx.model
	model:SetAttribute("KitType", "arena")
	model:SetAttribute("ArenaDuelRadius", Arena.DUEL_RADIUS)
	model:SetAttribute("ArenaSeatsPerStand", Arena.SEATS_PER_STAND)
	buildFloor(ctx)
	buildGround(ctx)
	for _, side in { "A", "B" } do
		buildStand(ctx, FRAME_STAND[side])
		buildTribune(ctx, FRAME_STAND[side])
		buildGate(ctx, FRAME_GATE[side])
	end
	for _, p in { { 34, 30.2 }, { -34, 30.2 }, { 34, -30.2 }, { -34, -30.2 } } do
		brazier(ctx, p[1], WALL_TOP, p[2])
	end
	for _, p in { { 27.6, 6.6 }, { 27.6, -6.6 }, { -27.6, 6.6 }, { -27.6, -6.6 } } do
		brazier(ctx, p[1], SLAB_TOP, p[2])
	end
	for _, side in { "A", "B" } do
		local F = FRAME_STAND[side]
		for _, cx in { -1, 1 } do
			pole(ctx, F, "StandardPole", 0.3, cx * 34, WALL_TOP, 27.0, 11.2, C.woodDark)
		end
	end
	buildAttachments(ctx)
	buildDress(model, ctx.root, "A", ca)
	buildDress(model, ctx.root, "B", cb)
	addDressAttributes(model, ca, cb)
	return model
end

-- Kit.arenaDress(model, colorA?, colorB?): rebuild both sides' dress in place (the kingdoms are known at the Arena phase).
function Arena.dress(model: Model, colorA: Color3?, colorB: Color3?)
	local ca, cb = colorA or NEUTRAL, colorB or NEUTRAL
	local root = model.PrimaryPart :: BasePart
	for _, side in { "A", "B" } do
		local old = model:FindFirstChild(`Dress{side}`)
		if old then
			old:Destroy()
		end
	end
	buildDress(model, root, "A", ca)
	buildDress(model, root, "B", cb)
	-- buildDress builds in the Kit's frame (the pivot at the origin); the model may stand elsewhere (WorldService places the
	-- CrownArena about (141, 0, -27)), so move the new dress to where the model's pivot is now, and give it the decoration physics
	-- WorldService gave the rest of the model (it records them as KitDecorBase and KitCollideHeight): nothing touchable, and the
	-- parts above the collide height walk-through. Without those attributes (Kit previews, specs) the dress keeps the Kit's physics.
	local pivot = root.CFrame * root.PivotOffset
	local moved = pivot ~= CFrame.identity -- a model still in the Kit's frame keeps its dress exactly as built
	local base, collideHeight = model:GetAttribute("KitDecorBase"), model:GetAttribute("KitCollideHeight")
	local decorate = type(base) == "number" and type(collideHeight) == "number"
	for _, side in { "A", "B" } do
		local dress = model:FindFirstChild(`Dress{side}`)
		if dress then
			for _, d in dress:GetDescendants() do
				if d:IsA("BasePart") then
					if moved then
						d.CFrame = pivot * d.CFrame
					end
					if decorate then
						d.CanTouch = false
						if d.CFrame.Position.Y - d.Size.Y / 2 > (base :: number) + (collideHeight :: number) then
							d.CanCollide = false
						end
					end
				end
			end
		end
	end
	addDressAttributes(model, ca, cb)
end

return Arena
