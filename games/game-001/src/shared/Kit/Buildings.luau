--!strict
--[[
	Kit/Buildings — building builders by type, construction stages and footprints (CONTRACTS G6/G10).
	FL-0054 v0 (FORGE-02): art-directed part-built architecture in the language of
	blender/ART_DIRECTION.md (stone plinths, timber framing, tile/thatch roofs, arched doors, shuttered
	windows, kingdom tower caps, banners). Each builder gets (ctx, level, kingdomColor, style, footprint,
	variant); style is the kingdom silhouette cue picked from the colour's hue (Parts.hueStyle).

	Buildings.build(type, level, stage, kingdomColor, variant?) — variant (default 1, deterministic) picks
	one of the house archetypes (roof style, storeys/jetty, chimney side, door side, props); variants 5–8
	mirror 1–4. Other types ignore it.

	G13 (FL-0085): the keep seats a Seat "Throne" on a dais on its open front terrace (G13.6); keep L1–3,
	barracks L1–4, house L1–2 and farm L1–2 grow height and roof count with level (G13.5).
	FL-0086: the VS-2 types are part-built in the same language (section "G13.5 VS-2 types"): mine and
	blacksmith L1–3, market, infirmary, granary and shrine L1–2; levels grow height, roofs and props inside the
	pinned footprints. The FL-0085 stand-in attributes (KitStandIn, KitLabel) are gone.

	Part budgets (max BaseParts per model; enforced by tests/world/KitBuildings.spec.luau). World budget is
	≤ 25k parts at VS-2 (BRIEF §14). A VS-2 kingdom (keep L3, 10 houses, 3 farms, storehouse, 2 lumber
	camps, 2 quarries, 2 barracks, 2 watchtowers, 12 wall segments, a gate, one of each G13.5 type, 2 sites
	in progress) measures ≈ 4.1k parts → 4 kingdoms + 3 neutral towers ≈ 16.9k, leaving ≈ 8k for
	WorldService props and region markers. FL-0086: the six VS-2 types at their top levels measure 651–683
	per kingdom (the stand-ins 384–415; at L1 426–449), ≈ +260 per kingdom → ≈ 17.9k for 4 kingdoms, while
	WorldService alone measures ≈ 8.4k (WorldService.spec boot, seed 1): the all-built worst case is over 25k
	(reported to FORGE-00 in FL-0086). The caps are ceilings, not targets: every model at its cap would
	sum to ≈ 23.6k, so new detail goes where it reads (roofs, doors, banners), never into hidden faces. The
	FL-0086 types stay under their FL-0085 caps (no cap was raised).

		type        cap   measured (min–max over levels, variants, the 4 + 2 FORGE-01 kingdom colours, neutral)
		keep        300   182–292  (L1 182–236, L2 204–260, L3 234–292; Kit.spec: L1–L2 ≤ 260, L3 ≤ 300)
		house       170   99–162   (8 variants, L1–L2)
		farm        190   151–188
		storehouse  150   87–96
		lumbercamp  130   46–59
		quarry      130   51–64
		barracks    260   119–248  (L1–L4)
		watchtower  130   105–125
		wall         60   35–42    (per 32-stud segment)
		gate        150   92–113
		mine        110   55–104   (L1 55–66, L2 80–97, L3 86–104)
		blacksmith  150   78–144   (L1 78–83, L2 109–121, L3 131–144)
		market      150   79–144   (L1 79–90, L2 130–144)
		infirmary   150   105–145  (L1 105–110, L2 139–145)
		granary     110   54–85    (L1 54–62, L2 77–85)
		shrine       80   31–61    (L1 31–38, L2 54–61)
		stages      110   29–85    (any type, stage 1..3)
	Emblems (D-039, colour-vision finding 3) cost crown 3 / star 5 / oak 5 / sun 4 parts per banner, flag, pennant
	or shield (the keep's two aerial plaques: field + border + emblem, the sun with 9). They were paid for by
	dropping the banner trim bands, the throne-back emblem (the seated ruler hides it), the keep's L2+ turret
	banners (the roof plaque replaces them), the standard finials and the hall's low side/back arrow slits, coarser
	keep plinth facing (10-stud stones) and the barracks L4 jetty banners (the gatehouse carries its own). Keep L2
	in the emerald colours sits exactly at its 260 cap: any new keep detail needs a cut first.
	Every part stays inside Kit.footprint (sides and back strictly; the front may carry entrance steps up
	to 2 studs, short of the Door attachment) — footprints are pinned by the spec and never grow.
]]

local Parts = require("./Parts")
local C = Parts.C
local shade = Parts.shade
local hueStyle = Parts.hueStyle
local newModel = Parts.newModel
local block = Parts.block
local wedge = Parts.wedge
local column = Parts.column
local log = Parts.log
local ball = Parts.ball
local attach = Parts.attach
local Pieces = require("./Pieces")
local stoneFor = Pieces.stoneFor
local jit = Pieces.jit
local cyl = Pieces.cyl
local disc = Pieces.disc
local strut = Pieces.strut
local stonePlinth = Pieces.stonePlinth
local quoins = Pieces.quoins
local frameWall = Pieces.frameWall
local wallFrames = Pieces.wallFrames
local timberBox = Pieces.timberBox
local tileRoof = Pieces.tileRoof
local thatchRoof = Pieces.thatchRoof
local leanTo = Pieces.leanTo
local towerCap = Pieces.towerCap
local pyramidRoof = Pieces.pyramidRoof
local roundTower = Pieces.roundTower
local crenellate = Pieces.crenellate
local windowAt = Pieces.windowAt
local doorAt = Pieces.doorAt
local bracket = Pieces.bracket
local dormer = Pieces.dormer
local banner = Pieces.banner
local crest = Pieces.crest
local emblemPlaque = Pieces.emblemPlaque
local throne = Pieces.throne
local chimney = Pieces.chimney
local gableChimney = Pieces.gableChimney
local barrel = Pieces.barrel
local crate = Pieces.crate
local sack = Pieces.sack
local logStack = Pieces.logStack
local fence = Pieces.fence
local scaffold = Pieces.scaffold
local materialPile = Pieces.materialPile

type Ctx = Parts.Ctx

-- building flags and pennants take the colour's style (emerald flies the lighter tint with a cream border)
local function flagpole(ctx: Ctx, x: number, y: number, z: number, h: number, color: Color3)
	Pieces.flagpole(ctx, x, y, z, h, color, hueStyle(color))
end
local function pennant(ctx: Ctx, x: number, y: number, z: number, h: number, color: Color3)
	Pieces.pennant(ctx, x, y, z, h, color, hueStyle(color))
end
type Opening = Pieces.Opening

local M = Enum.Material
local PI = math.pi
local rad = math.rad

local Buildings = {}

-- Footprints (studs, X × Z): the single source for canPlace and the build ghost (G6).
local FOOTPRINTS: { [string]: { Vector2 } } = {
	keep = { Vector2.new(32, 32), Vector2.new(40, 40), Vector2.new(46, 46) },
	house = { Vector2.new(20, 16), Vector2.new(22, 18) },
	farm = { Vector2.new(34, 28), Vector2.new(40, 32) },
	storehouse = { Vector2.new(22, 18), Vector2.new(26, 20) },
	lumbercamp = { Vector2.new(22, 18) },
	quarry = { Vector2.new(22, 20) },
	barracks = { Vector2.new(30, 20), Vector2.new(34, 22) },
	watchtower = { Vector2.new(14, 14), Vector2.new(16, 16) },
	wall = { Vector2.new(32, 8) },
	gate = { Vector2.new(32, 12) },
	-- G13.5 VS-2 types (FL-0086: part-built; one footprint for every level)
	mine = { Vector2.new(22, 20) },
	blacksmith = { Vector2.new(22, 18) },
	market = { Vector2.new(26, 22) },
	infirmary = { Vector2.new(22, 18) },
	granary = { Vector2.new(18, 18) },
	shrine = { Vector2.new(16, 16) },
}

Buildings.PART_BUDGET = {
	keep = 300, -- L1–L2 ≤ 260 (Kit.spec hard cap); L3 ≤ 300
	house = 170,
	farm = 190,
	storehouse = 150,
	lumbercamp = 130,
	quarry = 130,
	barracks = 260,
	watchtower = 130,
	wall = 60,
	gate = 150,
	mine = 110,
	blacksmith = 150,
	market = 150,
	infirmary = 150,
	granary = 110,
	shrine = 80,
	stage = 110,
}
Buildings.HOUSE_VARIANTS = 4 -- distinct archetypes; 5..8 are their mirror images

function Buildings.footprint(buildingType: string, level: number): Vector2
	local levels = FOOTPRINTS[buildingType]
	assert(levels, `Kit.footprint: unknown building type {buildingType}`)
	return levels[math.clamp(level, 1, #levels)]
end

-- ------------------------------------------------------------------ helpers

type Builder = (ctx: Ctx, level: number, color: Color3, style: string, fp: Vector2, variant: number) -> ()

local function workSpots(ctx: Ctx, spots: { Vector3 })
	for i, p in spots do
		attach(ctx, `WorkSpot{i}`, p)
	end
end

local WHEAT_LIGHT = Color3.fromRGB(250, 222, 128)
local WHEAT_STALK = Color3.fromRGB(158, 146, 66)
local SOIL_DARK = Color3.fromRGB(104, 74, 46)
local QUARRY_STONE = { Color3.fromRGB(168, 160, 148), Color3.fromRGB(146, 139, 129), Color3.fromRGB(124, 118, 110) }
local CABBAGE = { Color3.fromRGB(96, 160, 64), Color3.fromRGB(126, 176, 78) }
local SAND = Color3.fromRGB(214, 186, 136)
local STRAW = Color3.fromRGB(208, 178, 110)
local RED_PAINT = Color3.fromRGB(196, 52, 44)
local IVORY_STONE = Color3.fromRGB(232, 226, 210)
local PLASTERS = {
	C.plaster,
	Color3.fromRGB(236, 219, 186),
	Color3.fromRGB(244, 236, 218),
	Color3.fromRGB(232, 214, 186),
}

local BUILDERS: { [string]: Builder } = {}

-- ------------------------------------------------------------------ houses

type Floor = { h: number, kind: string }
type HouseSpec = {
	w: number,
	d: number,
	plinth: number,
	floors: { Floor },
	jetty: number,
	roof: string,
	pitch: number,
	door: number, -- door side: -1 left, 1 right
	chimney: string, -- "gable" (external stack) | "ridge"
	chimneySide: number,
	dormer: boolean,
	porch: boolean,
	leanTo: boolean,
	leanDepth: number?, -- lean-to woodshed depth (default 3.6)
	props: string,
	plaster: Color3,
	seed: number,
}

-- Archetypes: 1 stone-and-timber townhouse (tile, jetty), 2 thatched cottage (porch), 3 stone cottage
-- (tile, dormer), 4 tall thatched house (lean-to woodshed). Variants 5..8 mirror 1..4.
local function houseSpec(level: number, variant: number): HouseSpec
	local arche = (variant - 1) % 4 + 1
	local mirror = math.floor((variant - 1) / 4) % 2 == 1
	local big = level >= 2
	local s: HouseSpec
	if arche == 1 then
		s = {
			w = if big then 16 else 15,
			d = if big then 12 else 11,
			plinth = 1.2,
			floors = if big
				then { { h = 10.2, kind = "stone" }, { h = 8.4, kind = "timber" } }
				else { { h = 9.6, kind = "stone" }, { h = 7.6, kind = "timber" } },
			jetty = 0.8,
			roof = "tile",
			pitch = 1.0,
			door = -1,
			chimney = "gable",
			chimneySide = -1,
			dormer = big,
			porch = false,
			leanTo = big,
			leanDepth = 1.8,
			props = "barrels",
			plaster = PLASTERS[1],
			seed = 11,
		}
	elseif arche == 2 then
		s = {
			w = if big then 16 else 14,
			d = if big then 11 else 10.4, -- thatch eaves stay inside the footprint
			plinth = 1.4,
			floors = if big
				then { { h = 10, kind = "timber" }, { h = 7.4, kind = "timber" } }
				else { { h = 10.4, kind = "timber" } },
			jetty = if big then 0.7 else 0,
			roof = "thatch",
			pitch = if big then 1.05 else 1.2,
			door = 1,
			chimney = "ridge",
			chimneySide = -1,
			dormer = false,
			porch = true,
			leanTo = false,
			props = "logs",
			plaster = PLASTERS[2],
			seed = 23,
		}
	elseif arche == 3 then
		s = {
			w = if big then 17 else 15,
			d = if big then 12 else 11,
			plinth = 1.0,
			floors = if big
				then { { h = 9.6, kind = "stone" }, { h = 7.4, kind = "timber" } }
				else { { h = 10, kind = "stone" } },
			jetty = 0,
			roof = "tile",
			pitch = 0.95,
			door = -1,
			chimney = "ridge",
			chimneySide = 1,
			dormer = true,
			porch = false,
			leanTo = false,
			props = "crates",
			plaster = PLASTERS[3],
			seed = 37,
		}
	else
		s = {
			w = if big then 13 else 12,
			d = if big then 11 else 10.4, -- thatch eaves stay inside the footprint
			plinth = 1.2,
			floors = if big
				then { { h = 9.8, kind = "timber" }, { h = 7.6, kind = "timber" } }
				else { { h = 10.2, kind = "timber" } },
			jetty = if big then 0.7 else 0,
			roof = "thatch",
			pitch = 1.1,
			door = 1,
			chimney = "gable",
			chimneySide = 1,
			dormer = false,
			porch = false,
			leanTo = true,
			leanDepth = 2.7,
			props = "yard",
			plaster = PLASTERS[4],
			seed = 53,
		}
	end
	if mirror then
		s.door = -s.door
		s.chimneySide = -s.chimneySide
	end
	return s
end

local function houseProps(ctx: Ctx, s: HouseSpec, doorX: number)
	local fz = -s.d / 2
	local out = doorX + s.door * 3.9 -- beside the door, on the house-edge side
	if s.props == "barrels" then
		barrel(ctx, Vector3.new(out, 0, fz - 1.3))
		barrel(ctx, Vector3.new(out + s.door * 1.9, 0, fz - 1.0), 1.7)
	elseif s.props == "logs" then
		local sx = -s.door
		logStack(ctx, CFrame.new(sx * (s.w / 2 + 1.25), 0, 0.5) * CFrame.Angles(0, PI / 2, 0), 7.5, 2, 0.55)
		column(ctx, "ChoppingBlock", 0.9, 1.3, Vector3.new(sx * (s.w / 2 + 1.2), 0, fz - 2.2), C.bark, M.Wood)
		block(
			ctx,
			"Axe",
			Vector3.new(0.22, 2.2, 0.22),
			CFrame.new(sx * (s.w / 2 + 1.2), 2.1, fz - 2.2) * CFrame.Angles(0, 0, rad(25)),
			C.wood,
			M.Wood
		)
	elseif s.props == "crates" then
		crate(ctx, CFrame.new(out, 0, fz - 1.6) * CFrame.Angles(0, rad(-12), 0), 2)
		crate(ctx, CFrame.new(out + s.door * 0.2, 2, fz - 1.6) * CFrame.Angles(0, rad(20), 0), 1.4)
		sack(ctx, Vector3.new(out + s.door * 2.0, 0, fz - 1.4))
		barrel(ctx, Vector3.new(out - s.door * 0.2, 0, fz - 3.1), 1.8)
	else
		barrel(ctx, Vector3.new(out, 0, fz - 1.3))
		sack(ctx, Vector3.new(out + s.door * 1.8, 0, fz - 1.1))
		sack(ctx, Vector3.new(out + s.door * 1.2, 0, fz - 2.6), 1.3)
		block(
			ctx,
			"Haybale",
			Vector3.new(2.4, 1.6, 1.6),
			CFrame.new(-s.door * (s.w / 2 - 1.8), 0.8, fz - 1.6) * CFrame.Angles(0, rad(10), 0),
			STRAW,
			M.Grass
		)
	end
end

local function buildHouse(ctx: Ctx, level: number, color: Color3, _style: string, fp: Vector2, variant: number)
	local s = houseSpec(level, variant)
	local w, d = s.w, s.d
	local doorX = s.door * (fp.X - 2) * 0.15 -- matches the Door attachment
	local csx = s.chimneySide
	local gableChim = s.chimney == "gable"
	stonePlinth(ctx, w + 0.9, d + 0.9, s.plinth, 0, 0, nil, s.seed)
	local y = s.plinth
	local topD = d
	local nf = #s.floors
	for i, fl in s.floors do
		local ground = i == 1
		local fd = d
		if not ground and s.jetty > 0 then
			fd = d + 2 * s.jetty
			block(ctx, "JettyBeam", Vector3.new(w + 0.8, 0.7, fd + 0.3), CFrame.new(0, y + 0.05, 0), C.timber, M.Wood)
			for _, bx in { -w / 2 + 0.7, w / 2 - 0.7 } do
				bracket(ctx, CFrame.new(bx, y - 0.3, -d / 2), s.jetty + 0.1, 1.3)
			end
		end
		topD = fd
		local h = fl.h
		local f = wallFrames(w, fd, y)
		local sill = if ground then 3.2 else 2.4
		local ops: { [string]: { Opening } } = { front = {}, back = {}, left = {}, right = {} }
		-- side walls: local +X of "left" is world front (-Z), of "right" world back (+Z)
		local function sideWindow(side: string, sgn: number, full: boolean)
			local blocked = (gableChim and csx == sgn) or (s.leanTo and -csx == sgn and ground)
			if blocked and ground then
				return
			end
			local u = 0
			if blocked then
				u = if side == "left" then fd * 0.27 else -fd * 0.27
			end
			windowAt(
				ctx,
				f[side] * CFrame.new(u, sill, 0),
				{ shutters = if full then color else nil, simple = not full }
			)
			table.insert(ops[side], { u = u, hw = 1.9 })
		end
		if ground then
			doorAt(ctx, f.front * CFrame.new(doorX, 0, 0), {
				leaf = color,
				leafTint = 0.72,
				step = s.plinth,
				voussoirs = 5,
			})
			table.insert(ops.front, { u = doorX, hw = 3.3, door = true })
			local wx = -s.door * w * 0.25
			windowAt(ctx, f.front * CFrame.new(wx, sill, 0), { shutters = color, box = s.props ~= "logs" })
			table.insert(ops.front, { u = wx, hw = 1.9 })
			sideWindow("left", -1, nf == 1)
			sideWindow("right", 1, nf == 1)
			local bu = s.door * w * 0.22
			windowAt(ctx, f.back * CFrame.new(bu, sill, 0), { simple = true })
			table.insert(ops.back, { u = bu, hw = 1.9 })
		else
			for _, wx in { -w * 0.25, w * 0.25 } do
				windowAt(ctx, f.front * CFrame.new(wx, sill, 0), { shutters = color })
				table.insert(ops.front, { u = wx, hw = 1.9 })
			end
			sideWindow("left", -1, true)
			sideWindow("right", 1, true)
			windowAt(ctx, f.back * CFrame.new(0, sill, 0), { simple = true })
			table.insert(ops.back, { u = 0, hw = 1.9 })
		end
		if fl.kind == "stone" then
			-- 0.03 above the floor: the door leaf and jambs stand on the floor without a shared bottom face
			block(
				ctx,
				"Walls",
				Vector3.new(w, h - 0.03, fd),
				CFrame.new(0, y + h / 2 + 0.015, 0),
				C.stone,
				M.Cobblestone
			)
			quoins(ctx, w, fd, y, h, C.stoneLight, 3)
		else
			timberBox(ctx, w, fd, y, h, s.plaster)
			local ry = sill - 0.45
			frameWall(ctx, f.front, w, h, ops.front, ry)
			frameWall(ctx, f.back, w, h, ops.back, ry)
			frameWall(ctx, f.left, fd, h, ops.left, ry)
			frameWall(ctx, f.right, fd, h, ops.right, ry)
		end
		y += h
	end
	-- roof
	local rise = topD / 2 * s.pitch
	local stoneTop = s.floors[nf].kind == "stone"
	local info
	if s.roof == "tile" then
		info = tileRoof(ctx, {
			w = w,
			d = topD,
			y = y,
			rise = rise,
			over = 1.2,
			gable = 1,
			color = color,
			tint = 0.88,
			infill = if stoneTop then C.woodLight else s.plaster,
			infillMaterial = if stoneTop then M.WoodPlanks else M.Plaster,
			kingPost = not stoneTop,
		})
	else
		info = thatchRoof(ctx, {
			w = w,
			d = topD,
			y = y,
			rise = rise,
			over = 1.3,
			gable = 1.2,
			color = C.thatch,
			infill = s.plaster,
			kingPost = true,
		})
	end
	if s.dormer then
		dormer(ctx, if nf == 1 then 0 else -s.door * 0.4, y, topD, info.theta, color, 0.88, s.plaster)
	end
	-- chimney
	if gableChim then
		gableChimney(ctx, csx * (w / 2 + 1.05), 0.6, csx, y - 1.2, info.ridgeY + 2.2)
	else
		local cx = csx * w * 0.27
		chimney(ctx, cx, topD * 0.12, y - 1, info.ridgeY + 2.6 - (y - 1))
	end
	-- porch canopy over the door
	if s.porch then
		local fz = -d / 2
		for _, sx in { -1, 1 } do
			block(
				ctx,
				"PorchPost",
				Vector3.new(0.55, s.plinth + 7.5, 0.55),
				CFrame.new(doorX + sx * 2.9, (s.plinth + 7.5) / 2, fz - 2.7),
				C.timber,
				M.Wood
			)
		end
		block(
			ctx,
			"PorchBeam",
			Vector3.new(6.6, 0.5, 0.5),
			CFrame.new(doorX, s.plinth + 7.6, fz - 2.7),
			C.timber,
			M.Wood
		)
		leanTo(ctx, CFrame.new(doorX, s.plinth + 9.1, fz - 0.1), 7.4, 3.1, 1.4, color, 0.85, 2)
	end
	-- lean-to woodshed on the side away from the chimney
	if s.leanTo then
		local ls = -csx
		local x0 = ls * w / 2
		local ld = s.leanDepth or 3.6
		local x1 = ls * (w / 2 + ld)
		block(ctx, "ShedWall", Vector3.new(0.4, 5.6, d - 1), CFrame.new(x1, 2.8, 0.2), C.wood, M.WoodPlanks)
		block(ctx, "ShedPost", Vector3.new(0.55, 6, 0.55), CFrame.new(x1, 3, -d / 2 + 0.6), C.timber, M.Wood)
		leanTo(
			ctx,
			CFrame.new(x0, s.plinth + 7.4, 0.2) * CFrame.Angles(0, -ls * PI / 2, 0),
			d - 0.2,
			ld + 0.3,
			if ld < 3 then 1.4 else 2,
			color,
			0.82,
			2
		)
		logStack(
			ctx,
			CFrame.new((x0 + x1) / 2, 0, 0) * CFrame.Angles(0, PI / 2, 0),
			d - 2.6,
			2,
			if ld < 3 then 0.5 else 0.6
		)
	end
	-- thatch houses fly a kingdom pennant on the ridge (thatch alone never says which kingdom)
	if s.roof == "thatch" then
		pennant(ctx, -csx * (w / 2 - 0.6), info.ridgeY - 0.5, 0, 4.2, color)
	end
	houseProps(ctx, s, doorX)
end

BUILDERS.house = function(ctx, level, color, style, fp, variant)
	buildHouse(ctx, level, color, style, fp, variant)
	local w, d = fp.X - 2, fp.Y - 2
	local doorX = (houseSpec(level, variant)).door * w * 0.15
	attach(ctx, "Door", Vector3.new(doorX, 0, -d / 2 - 2))
	workSpots(ctx, { Vector3.new(w * 0.3, 0, -d / 2 - 3) })
end

-- ------------------------------------------------------------------ keep

-- Keep: a broad hall (wide facade) with round corner turrets, a donjon behind, a front bay with the grand
-- door and, in front of it, an open terrace with the throne dais (G13.6) framed by kingdom standards.
-- Levels grow height and roof count: L1 5 caps; L2 + bartizans on the bay (7); L3 + side towers (9).
local KEEP_PLAQUE_LIFT = 2.4 -- the roof plaque's face clears the 2.6 merlons' sight lines from the overview camera
BUILDERS.keep = function(ctx, level, color, style, fp)
	local S = stoneFor(style)
	local lv = math.clamp(level, 1, 3)
	local h = ({ 22, 26, 30 })[lv]
	local pl = 2.4
	local tr = ({ 3.5, 4.0, 4.4 })[lv] -- corner turret radius
	-- inside the footprint (G13.5: footprints never grow): a turret plus its widest cap (the emerald
	-- hoarding roof) reaches tr + 1.3 from its axis; from the back edge to the last stair = fp + 1
	local reach = tr + 1.3
	local hw = fp.X / 2 - reach
	local hd = (fp.X - tr - 8.9) / 2
	local zc = fp.X / 2 - reach - hd
	local fz = zc - hd -- hall front face
	stonePlinth(ctx, 2 * hw + 2.6, 2 * hd + 2.6, pl, 0, zc, S, 7, 10) -- 10-stud facing stones (emblem budget)
	block(ctx, "Hall", Vector3.new(2 * hw, h, 2 * hd), CFrame.new(0, pl + h / 2, zc), S.base, M.Cobblestone)
	local courseY = pl + h * 0.55
	local topY = pl + h
	block(
		ctx,
		"StringCourse",
		Vector3.new(2 * hw + 0.7, 0.7, 2 * hd + 0.7),
		CFrame.new(0, courseY, zc),
		S.light,
		M.Slate
	)
	block(ctx, "Corbel", Vector3.new(2 * hw + 1.6, 1.3, 2 * hd + 1.6), CFrame.new(0, topY - 0.15, zc), S.light, M.Slate)
	local span = hw - tr - 0.9
	for i = -1, 1 do
		bracket(ctx, CFrame.new(i * span * 0.75, topY - 0.8, fz), 0.8, 1.4, S.light, M.Slate)
	end
	crenellate(
		ctx,
		2 * hw + 1.6,
		2 * hd + 1.6,
		topY + 0.5,
		S.light,
		0,
		zc,
		{ m = 2.6, h = 2.6, t = 1.1, gap = if lv == 1 then 1.7 else 2.1, skip = tr + 1 }
	)
	-- corner turrets with the kingdom cap
	local tH = h + ({ 7, 9, 10 })[lv]
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * hw, zc + sz * hd
			local a = math.atan2(-sx, -sz)
			roundTower(ctx, x, z, pl - 0.2, tr, tH, S, { a })
			towerCap(ctx, style, tr * 2, pl - 0.2 + tH, color, x, z)
		end
	end
	if lv >= 3 then
		-- L3: towers in the middle of each side
		for _, sx in { -1, 1 } do
			local x, z = sx * (hw + 0.6), zc + 1.5
			roundTower(ctx, x, z, pl - 0.2, 3.2, h + 3, S, { sx * -PI / 2 })
			towerCap(ctx, style, 6.4, pl - 0.2 + h + 3, color, x, z)
		end
	end
	-- donjon behind the facade with the big cap and the kingdom flag
	local cw = ({ 10.5, 12.5, 14 })[lv]
	local ch = ({ 12, 15, 18 })[lv]
	local cz = zc + hd - cw / 2 - (if lv == 1 then 1 else 2) -- L1: 1 back, so the roof plaque fits 6.7
	block(ctx, "Donjon", Vector3.new(cw, ch + 1, cw), CFrame.new(0, topY - 1 + (ch + 1) / 2, cz), S.base, M.Cobblestone)
	block(
		ctx,
		"DonjonCorbel",
		Vector3.new(cw + 1.2, 1.1, cw + 1.2),
		CFrame.new(0, topY + ch - 0.45, cz),
		S.light,
		M.Slate
	)
	local df = wallFrames(cw, cw, topY + ch * 0.3, 0, cz)
	for _, side in { "front", "left", "right" } do
		windowAt(
			ctx,
			df[side],
			{ arched = true, w = 2.4, h = 4.6, frame = S.light, frameMaterial = M.Slate, bare = true }
		)
	end
	towerCap(ctx, style, cw, topY + ch + 0.1, color, 0, cz, ({ 7, 8, 9 })[lv])
	-- aerial heraldry (colour-vision finding 3): the overview camera (40–220 studs, 38–65° down, G13.6) sees
	-- the keep's roof and caps, not its hanging banners. A large up-facing plaque on the roof in front of the
	-- donjon reads from the front and sides; a plaque on the donjon's back (windowless) face reads from behind,
	-- where the donjon hides the roof plaque. Kingdom field, ivory border, full-detail emblem.
	local roofY = topY + 0.5 -- the corbel's top is the roof deck
	local pr = ({ 6.7, 9, 10.5 })[lv]
	local zr = cz - cw / 2 - 0.4 - (pr + 0.7) / 2 -- back edge 0.4 before the donjon; L1 front at the merlons
	local lift = KEEP_PLAQUE_LIFT
	emblemPlaque(ctx, CFrame.new(0, roofY + 0.25 + lift, zr) * CFrame.Angles(PI / 2, 0, 0), pr, color, lift)
	local pb = ({ 6, 7.5, 8.5 })[lv]
	-- 2.2 under the donjon top: clear of the corbel and the cap's eave (the emerald hoarding beam overhangs
	-- 1.2) for the 45° rear views, and still above what the hall's back merlons hide
	local yb = topY + ch - 2.2 - (pb + 0.7) / 2
	emblemPlaque(ctx, CFrame.new(0, yb, cz + cw / 2 + 0.25) * CFrame.Angles(0, PI, 0), pb, color)
	-- front bay: projecting entrance block with the grand door and a crest
	local bw = ({ 10, 11, 12 })[lv]
	local bp = 1.4
	local bayTop = courseY + 6.2
	local tz0 = fz - bp -- bay face
	block(
		ctx,
		"EntranceBay",
		Vector3.new(bw, bayTop, bp + 0.2),
		CFrame.new(0, bayTop / 2, fz - bp / 2 + 0.1),
		S.base,
		M.Cobblestone
	)
	block(
		ctx,
		"BayCorbel",
		Vector3.new(bw + 0.8, 0.9, bp + 1),
		CFrame.new(0, bayTop + 0.1, fz - bp / 2),
		S.light,
		M.Slate
	)
	for i = -1, 1 do
		block(
			ctx,
			"Merlon",
			Vector3.new(2.2, 2.4, 1),
			CFrame.new(i * (bw / 2 - 1.1), bayTop + 1.75, tz0),
			S.light,
			M.Slate
		)
	end
	doorAt(ctx, CFrame.new(0, pl, tz0), { w = 6, h = 10.4, voussoirs = 7, stone = S.base, stoneLight = S.light })
	crest(ctx, CFrame.new(0, courseY + 2.6, tz0 - 0.25), 3.4, color, style)
	if lv >= 2 then
		-- bartizans (little corbelled turrets) on the bay's front corners
		for _, sx in { -1, 1 } do
			local x, z = sx * (bw / 2), tz0 + 0.4
			column(ctx, "BartizanCorbel", 1.55, 1.2, Vector3.new(x, bayTop - 1.6, z), S.light, M.Slate)
			column(ctx, "Bartizan", 1.3, 4, Vector3.new(x, bayTop - 0.4, z), S.base, M.Cobblestone)
			towerCap(ctx, style, 2.6, bayTop + 3.6, color, x, z)
		end
	end
	-- terrace with the throne dais, standards at its front corners, stairs down to the ground
	local tw = bw + 7
	local td = 5
	local tz1 = tz0 - td
	block(
		ctx,
		"Terrace",
		Vector3.new(tw, pl + 0.03, td + 0.4),
		CFrame.new(0, (pl + 0.03) / 2, tz0 - td / 2 + 0.2),
		S.light,
		M.Slate
	)
	for _, sx in { -1, 1 } do
		block(
			ctx,
			"TerraceWall",
			Vector3.new(0.9, 1.2, td),
			CFrame.new(sx * (tw / 2 - 0.47), pl + 0.6, tz0 - td / 2),
			S.base,
			M.Slate
		)
		local px, pz = sx * (tw / 2 - 0.45), tz1 + 0.5
		column(ctx, "StandardPole", 0.22, 8.4, Vector3.new(px, pl + 1.2, pz), C.woodDark, M.Wood)
		banner(ctx, px, pl + 9, pz + 0.3, 0, color, 4.2, style, 2)
	end
	local steps = { { tw - 2.4, pl * 2 / 3, 1.1 }, { tw - 1.2, pl / 3, 1.1 } }
	local z0 = tz1
	for _, st in steps do
		block(
			ctx,
			"Stair",
			Vector3.new(st[1], st[2], st[3]),
			CFrame.new(0, st[2] / 2, z0 - st[3] / 2),
			S.light,
			M.Slate
		)
		z0 -= st[3]
	end
	-- 0.4 in front of the bay face: the dais and the throne back stay clear of the door, straps and voussoirs
	throne(ctx, CFrame.new(0, pl, tz0 - 0.4), color, style, S, math.max(bayTop + 3.2, topY + 3.4) - pl)
	-- banners on the hall face between the bay and the turrets, arched windows above them
	for _, sx in { -1, 1 } do
		local bx = sx * (bw / 2 + (hw - tr - bw / 2) / 2)
		banner(ctx, bx, courseY - 0.5, fz - 0.05, 0, color, courseY - pl - 5.6, style, 2.6)
		windowAt(
			ctx,
			CFrame.new(bx, courseY + 1.2, fz),
			{ arched = true, w = 2.4, h = 4.6, frame = S.light, frameMaterial = M.Slate, bare = true }
		)
	end
	-- side and back windows (the low arrow slits went to the emblem budget; the turrets keep theirs)
	local hf = wallFrames(2 * hw, 2 * hd, 0, 0, zc)
	for _, side in { "left", "right", "back" } do
		windowAt(
			ctx,
			hf[side] * CFrame.new(if side == "back" then 0 else -2, courseY + 1.2, 0),
			{ arched = true, w = 2.4, h = 4.6, frame = S.light, frameMaterial = M.Slate, bare = true }
		)
	end
	attach(ctx, "Door", Vector3.new(0, 0, -(fp.X - 8) / 2 - 5.5))
	workSpots(ctx, { Vector3.new(-8, 0, -(fp.X - 8) / 2 - 6), Vector3.new(8, 0, -(fp.X - 8) / 2 - 6) })
end

-- ------------------------------------------------------------------ storehouse / granary

BUILDERS.storehouse = function(ctx, level, color, style, fp)
	local big = level >= 2
	-- granary raised on staddle stones, a lean-to store for goods on its -X side
	local w, d = fp.X - 7.5, fp.Y - 6
	local cx = 1.2
	local lift = 3
	local ys = lift + 0.7
	for _, ix in { -1, 0, 1 } do
		for _, iz in { -1, 1 } do
			local p = Vector3.new(cx + ix * (w / 2 - 1.1), 0, iz * (d / 2 - 1.1))
			column(ctx, "Staddle", 0.55, lift - 0.45, p, C.stone, M.Slate)
			column(ctx, "StaddleCap", 1.25, 0.5, p + Vector3.new(0, lift - 0.5, 0), C.stoneLight, M.Slate)
		end
	end
	block(ctx, "Floor", Vector3.new(w + 0.8, 0.7, d + 0.8), CFrame.new(cx, lift + 0.35, 0), C.timber, M.WoodPlanks)
	local h = if big then 9.6 else 8.6
	block(ctx, "Walls", Vector3.new(w, h - 0.06, d), CFrame.new(cx, ys + h / 2, 0), C.woodLight, M.WoodPlanks)
	block(ctx, "TopPlate", Vector3.new(w + 0.5, 0.6, d + 0.5), CFrame.new(cx, ys + h - 0.3, 0), C.timber, M.Wood)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(
				ctx,
				"CornerPost",
				Vector3.new(0.75, h - 0.04, 0.75),
				CFrame.new(cx + sx * w / 2, ys + h / 2, sz * d / 2),
				C.timber,
				M.Wood
			)
		end
	end
	local f = wallFrames(w, d, ys, cx, 0)
	frameWall(ctx, f.front, w, h, { { u = 0, hw = 4.3, door = true } }, 2.6)
	frameWall(ctx, f.right, d, h, { { u = 0, hw = 1.9 } }, 2.6)
	frameWall(ctx, f.back, w, h, {}, 2.6)
	tileRoof(ctx, {
		w = w,
		d = d,
		y = ys + h,
		rise = d / 2 * 0.95,
		cf = CFrame.new(cx, 0, 0),
		over = 1.5,
		gable = 1.1,
		color = color,
		tint = 0.88,
		infill = C.wood,
		infillMaterial = M.WoodPlanks,
	})
	-- big double doors (kingdom colour) in a timber frame, a cleated ramp up to the floor
	local fz = -d / 2
	for _, sx in { -1, 1 } do
		block(
			ctx,
			"BigDoor",
			Vector3.new(3.2, 6.6, 0.35),
			CFrame.new(cx + sx * 1.65, ys + 3.3, fz - 0.12),
			shade(color, 0.72),
			M.WoodPlanks,
			0.72
		)
		strut(
			ctx,
			"DoorBrace",
			CFrame.new(cx + sx * 1.65, ys, fz - 0.36),
			-1.3,
			0.6,
			1.3,
			6,
			0.4,
			0.14,
			C.timber,
			M.Wood
		)
	end
	block(ctx, "DoorLintel", Vector3.new(7.8, 0.8, 0.7), CFrame.new(cx, ys + 7, fz - 0.2), C.timber, M.Wood)
	local rampD = 4.2
	wedge(ctx, "Ramp", Vector3.new(6.6, ys, rampD), CFrame.new(cx, ys / 2, fz - rampD / 2), C.woodDark, M.WoodPlanks)
	for k = 1, 3 do
		local t = k / 4
		block(
			ctx,
			"RampCleat",
			Vector3.new(6.2, 0.22, 0.3),
			CFrame.new(cx, ys * (1 - t) + 0.08, fz - rampD * t),
			C.timber,
			M.Wood
		)
	end
	windowAt(ctx, f.right * CFrame.new(0, 2.8, 0), { shutters = color })
	-- hoist beam with rope and crate over the doors
	block(ctx, "HoistBeam", Vector3.new(0.6, 0.6, 3.6), CFrame.new(cx, ys + h - 1.1, fz - 1.4), C.timber, M.Wood)
	block(ctx, "HoistRope", Vector3.new(0.14, 2.2, 0.14), CFrame.new(cx, ys + h - 2.5, fz - 3), C.canvas, M.Fabric)
	crate(ctx, CFrame.new(cx, ys + h - 5, fz - 3), 1.5)
	banner(ctx, cx + w / 2 - 1.9, ys + h - 0.9, fz - 0.05, 0, color, 5, style, 2.4)
	-- lean-to store on the -X side with goods
	local lx0 = cx - w / 2
	local lx1 = lx0 - 3.6
	for _, pz in { -1, 1 } do
		block(
			ctx,
			"LeanToPost",
			Vector3.new(0.55, 6.5, 0.55),
			CFrame.new(lx1 + 0.3, 3.25, pz * (d / 2 - 0.4)),
			C.timber,
			M.Wood
		)
	end
	leanTo(ctx, CFrame.new(lx0, ys + 4.4, 0) * CFrame.Angles(0, PI / 2, 0), d + 0.6, 3.9, 2, color, 0.8, 2)
	barrel(ctx, Vector3.new(lx0 - 1.3, 0, d / 2 - 2), 2.1)
	barrel(ctx, Vector3.new(lx0 - 1.4, 0, d / 2 - 4.2), 2.1)
	crate(ctx, CFrame.new(lx0 - 1.6, 0, -0.6) * CFrame.Angles(0, rad(8), 0), 2.2)
	sack(ctx, Vector3.new(lx0 - 1.5, 2.2, -0.5), 1.4)
	-- goods by the drop-off (front left) and stacked crates (front right)
	for i, p in
		{
			Vector3.new(lx0 - 1.2, 0, fz - 1.6),
			Vector3.new(lx0 + 0.6, 0, fz - 2.0),
			Vector3.new(lx0 - 0.2, 0, fz - 3.4),
		}
	do
		sack(ctx, p, if i == 3 then 1.4 else 1.7)
	end
	sack(ctx, Vector3.new(lx0 - 0.3, 1.25, fz - 1.8), 1.4)
	crate(ctx, CFrame.new(cx + 5.2, 0, fz - 2.2) * CFrame.Angles(0, rad(10), 0), 2.2)
	crate(ctx, CFrame.new(cx + 6.6, 0, fz - 3.8) * CFrame.Angles(0, rad(-14), 0), 1.7)
	crate(ctx, CFrame.new(cx + 5.3, 2.2, fz - 2.2) * CFrame.Angles(0, rad(-20), 0), 1.5)
	local dd = fp.Y - 3
	attach(ctx, "Door", Vector3.new(0, 0, -dd / 2 - 2.5))
	attach(ctx, "DropOff", Vector3.new(-3, 0, -dd / 2 - 3))
	workSpots(ctx, { Vector3.new(3, 0, -dd / 2 - 3) })
end

-- ------------------------------------------------------------------ farm

BUILDERS.farm = function(ctx, level, color, _style, fp)
	local w, d = fp.X, fp.Y
	local fw = w * 0.62
	local fx = -w / 2 + fw / 2 + 0.4
	local fd = d - 2.4
	block(ctx, "Field", Vector3.new(fw, 0.4, fd), CFrame.new(fx, 0.2, 0), SOIL_DARK, M.Ground)
	-- wheat rows: darker stalks with lighter, slightly wider ears on top
	local rows = 6 + level
	local pitch = (fd - 1) / rows
	for i = 0, rows - 1 do
		local z = -fd / 2 + 0.5 + (i + 0.5) * pitch
		local hh = 2.2 + jit(i * 1.3, 0.3)
		local len = fw - 1.4 + jit(i * 3, 0.5)
		local xo = fx + jit(i * 7, 0.3)
		block(ctx, "Wheat", Vector3.new(len, hh, pitch * 0.56), CFrame.new(xo, 0.4 + hh / 2, z), WHEAT_STALK, M.Grass)
		-- ears: a ridged (gabled) golden top, lit on one side and shaded on the other, reads as a crop row
		local ew, eh = pitch * 0.36, 1.3
		local el = len - 0.5 + jit(i * 5, 0.3)
		local ex = xo + jit(i * 9, 0.2)
		local ey = 0.4 + hh + eh / 2 - 0.25
		local col = if i % 2 == 0 then C.wheat else WHEAT_LIGHT
		wedge(ctx, "WheatEars", Vector3.new(el, eh, ew), CFrame.new(ex, ey, z - ew / 2), col, M.Grass)
		wedge(
			ctx,
			"WheatEars",
			Vector3.new(el, eh, ew),
			CFrame.new(ex, ey, z + ew / 2) * CFrame.Angles(0, PI, 0),
			col,
			M.Grass
		)
	end
	-- sheaves (stooks) at the field edge
	for i = 0, 2 do
		local p = Vector3.new(fx + fw / 2 - 1.4, 0, -fd / 2 + 3 + i * 3.4)
		column(ctx, "Sheaf", 0.75, 2.6, p, STRAW, M.Grass)
		ball(ctx, "SheafTop", 1.3, p + Vector3.new(0, 2.6, 0), C.wheat, M.Grass)
	end
	-- fence: front (gap at the path), left, back
	local x0, x1 = -w / 2 + 0.3, fx + fw / 2 + 0.3
	local z0, z1 = -d / 2 + 0.3, d / 2 - 0.3
	fence(ctx, Vector3.new(x0, 0, z0), Vector3.new(fx + 1.5, 0, z0))
	fence(ctx, Vector3.new(fx + 5.5, 0, z0), Vector3.new(x1, 0, z0))
	fence(ctx, Vector3.new(x0, 0, z0), Vector3.new(x0, 0, z1), nil, true) -- corner posts are shared
	fence(ctx, Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1), nil, true)
	-- farmhouse: small thatched cottage on the right (door on the Door attachment)
	local hw, hd = w / 2 - 2.15 - (x1 + 1.3), 9
	local hx = w / 2 - 2.15 - hw / 2
	local hz = -d / 2 + hd / 2 + 2.2
	local doorX = w / 2 - w * 0.32 / 2
	stonePlinth(ctx, hw + 0.8, hd + 0.8, 1, hx, hz, nil, 41, 4)
	local hh = 8.4
	timberBox(ctx, hw, hd, 1, hh, PLASTERS[2], hx, hz)
	local f = wallFrames(hw, hd, 1, hx, hz)
	local du = doorX - hx
	frameWall(ctx, f.front, hw, hh, { { u = du, hw = 3.2, door = true } }, 2.6)
	frameWall(ctx, f.left, hd, hh, { { u = 0, hw = 1.8 } }, 2.6)
	frameWall(ctx, f.right, hd, hh, { { u = 0, hw = 1.8 } }, 2.6)
	frameWall(ctx, f.back, hw, hh, {}, 2.6)
	doorAt(
		ctx,
		f.front * CFrame.new(du, 0, 0),
		{ leaf = color, leafTint = 0.72, step = 1, voussoirs = 3, w = 4.2, h = 7.2 }
	)
	windowAt(ctx, f.left * CFrame.new(0, 3, 0), { w = 2.2, h = 3, shutters = color })
	windowAt(ctx, f.right * CFrame.new(0, 3, 0), { w = 2.2, h = 3, shutters = color })
	local info = thatchRoof(ctx, {
		w = hw,
		d = hd,
		y = 1 + hh,
		rise = hd / 2 * 1.2,
		cf = CFrame.new(hx, 0, hz),
		over = 1.5,
		gable = 1.1,
		color = C.thatch,
		infill = PLASTERS[2],
		kingPost = true,
	})
	chimney(ctx, hx + hw * 0.28, hz + 1, 1 + hh - 1, info.ridgeY + 2 - hh)
	-- vegetable patch behind the farmhouse: soil bed with two rows of cabbages
	local vx, vz = hx - 0.5, hz + hd / 2 + 3.4
	block(ctx, "VegBed", Vector3.new(7.4, 0.35, 3.8), CFrame.new(vx, 0.17, vz), SOIL_DARK, M.Ground)
	for r = 0, 1 do
		for i = 0, 2 do
			ball(
				ctx,
				"Cabbage",
				1.35,
				Vector3.new(vx - 2.4 + i * 2.4 + r * 0.6, 0.75, vz - 0.9 + r * 1.8),
				CABBAGE[(i + r) % 2 + 1],
				M.Grass
			)
		end
	end
	-- haystack, scarecrow, cart behind the farmhouse
	if level >= 2 then
		-- L2: a barn with big doors in its gable end and a kingdom-tile roof (ridge along Z)
		local bw, bd = 9.5, 11
		local bx, bz = hx + 0.6, d / 2 - bd / 2 - 1.2
		block(ctx, "BarnBase", Vector3.new(bw + 0.8, 0.8, bd + 0.8), CFrame.new(bx, 0.4, bz), C.stone, M.Cobblestone)
		local bh = 7.2
		block(ctx, "BarnWalls", Vector3.new(bw, bh - 0.06, bd), CFrame.new(bx, 0.8 + bh / 2, bz), C.wood, M.WoodPlanks)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				block(
					ctx,
					"BarnPost",
					Vector3.new(0.7, bh - 0.02, 0.7),
					CFrame.new(bx + sx * bw / 2, 0.8 + bh / 2, bz + sz * bd / 2),
					C.timber,
					M.Wood
				)
			end
		end
		tileRoof(ctx, {
			w = bd,
			d = bw,
			y = 0.8 + bh,
			rise = bw / 2 * 1.05,
			cf = CFrame.new(bx, 0, bz) * CFrame.Angles(0, PI / 2, 0),
			over = 1.2,
			gable = 0.8,
			rows = 3,
			color = color,
			tint = 0.88,
			infill = C.woodLight,
			infillMaterial = M.WoodPlanks,
		})
		local bf = bz - bd / 2
		for _, sx in { -1, 1 } do
			block(
				ctx,
				"BarnDoor",
				Vector3.new(2.5, 5.8, 0.3),
				CFrame.new(bx + sx * 1.3, 0.8 + 2.9, bf - 0.1),
				C.woodLight,
				M.WoodPlanks
			)
			strut(
				ctx,
				"BarnDoorBrace",
				CFrame.new(bx + sx * 1.3, 0.8, bf - 0.3),
				-1,
				0.4,
				1,
				5.4,
				0.36,
				0.12,
				C.timber,
				M.Wood
			)
		end
		block(ctx, "Haybale", Vector3.new(2.6, 1.6, 1.8), CFrame.new(bx - 3.4, 0.8, bf - 1.6), STRAW, M.Grass)
	else
		local sy = Vector3.new(hx - 1, 0, d / 2 - 5)
		column(ctx, "Haystack", 2.6, 3.4, sy, STRAW, M.Grass)
		ball(ctx, "HaystackTop", 5.2, sy + Vector3.new(0, 3.2, 0), C.wheat, M.Grass)
	end
	local sc = Vector3.new(fx - fw * 0.15, 0, d * 0.12)
	column(ctx, "ScarecrowPost", 0.2, 5.8, sc, C.wood, M.Wood)
	block(ctx, "ScarecrowArms", Vector3.new(3.6, 0.3, 0.3), CFrame.new(sc + Vector3.new(0, 4.4, 0)), C.wood, M.Wood)
	block(
		ctx,
		"ScarecrowCoat",
		Vector3.new(1.6, 2, 0.9),
		CFrame.new(sc + Vector3.new(0, 4, 0)),
		shade(color, 0.8),
		M.Fabric,
		0.8
	)
	ball(ctx, "ScarecrowHead", 1.2, sc + Vector3.new(0, 5.6, 0), C.canvas, M.Fabric)
	cyl(
		ctx,
		"ScarecrowHat",
		CFrame.new(sc + Vector3.new(0, 6.2, 0)) * CFrame.Angles(0, 0, PI / 2),
		0.5,
		1.9,
		STRAW,
		M.Grass
	)
	local cart = if level >= 2
		then CFrame.new(hx - 4.2, 0, 3.6) * CFrame.Angles(0, rad(75), 0)
		else CFrame.new(hx + 2.5, 0, d / 2 - 4) * CFrame.Angles(0, rad(-15), 0)
	block(ctx, "CartBed", Vector3.new(4.2, 1.2, 2.6), cart * CFrame.new(0, 1.9, 0), C.wood, M.WoodPlanks)
	for _, sz in { -1, 1 } do
		disc(
			ctx,
			"CartWheel",
			cart * CFrame.new(0.4, 1.3, sz * 1.45) * CFrame.Angles(0, PI / 2, 0),
			2.6,
			0.3,
			C.woodDark,
			M.Wood
		)
	end
	block(ctx, "CartLoad", Vector3.new(3.6, 1, 2.2), cart * CFrame.new(0, 2.9, 0), C.wheat, M.Grass)
	flagpole(ctx, fx + 3.5, 0, z0 - 0.2, 8, color)
	attach(ctx, "Door", Vector3.new(doorX, 0, -d * 0.18 - d * 0.25 - 2))
	local ofw = w * 0.62
	local ofx = -w / 2 + ofw / 2
	workSpots(ctx, {
		Vector3.new(ofx - ofw * 0.25, 0, -d * 0.2),
		Vector3.new(ofx + ofw * 0.25, 0, d * 0.2),
		Vector3.new(ofx, 0, 0),
	})
end

-- ------------------------------------------------------------------ lumber camp

BUILDERS.lumbercamp = function(ctx, _level, color, style, fp)
	local w, d = fp.X - 2, fp.Y - 2
	-- open-fronted shed: plank floor, posts, plank back wall, kingdom-tile lean-to roof
	local sx0, sw, sd, sz0 = -w * 0.2, w * 0.55, d * 0.7, d * 0.1
	block(ctx, "ShedFloor", Vector3.new(sw, 0.5, sd), CFrame.new(sx0, 0.25, sz0), C.woodDark, M.WoodPlanks)
	for _, px in { -1, 1 } do
		for _, pz in { -1, 1 } do
			local hh = if pz > 0 then 9.6 else 7.4
			block(
				ctx,
				"ShedPost",
				Vector3.new(0.7, hh, 0.7),
				CFrame.new(sx0 + px * (sw / 2 - 0.4), hh / 2, sz0 + pz * (sd / 2 - 0.4)),
				C.timber,
				M.Wood
			)
		end
	end
	block(
		ctx,
		"ShedBackWall",
		Vector3.new(sw - 0.6, 8.4, 0.4),
		CFrame.new(sx0, 4.6, sz0 + sd / 2 - 0.4),
		C.wood,
		M.WoodPlanks
	)
	leanTo(ctx, CFrame.new(sx0, 9.8, sz0 + sd / 2), sw + 1.4, sd + 0.8, 2.6, color, 0.85, 3)
	-- sawhorse with a log, plank stacks inside the shed
	for _, px in { -1.6, 1.6 } do
		block(
			ctx,
			"Sawhorse",
			Vector3.new(0.4, 2.2, 2),
			CFrame.new(sx0 + px, 1.6, sz0 - 1) * CFrame.Angles(rad(0), 0, 0),
			C.wood,
			M.Wood
		)
	end
	log(ctx, "SawLog", 0.6, 6, CFrame.new(sx0, 3.2, sz0 - 1), C.bark)
	block(ctx, "Planks", Vector3.new(5, 1.4, 1.6), CFrame.new(sx0 - 1, 1.2, sz0 + 3), C.woodLight, M.WoodPlanks)
	block(
		ctx,
		"Planks",
		Vector3.new(4.4, 1.0, 1.5),
		CFrame.new(sx0 - 0.8, 2.4, sz0 + 3),
		shade(C.woodLight, 0.92),
		M.WoodPlanks
	)
	-- big log pile (right front) and the chopping stump with an axe (right back)
	logStack(ctx, CFrame.new(w * 0.27, 0, -d * 0.2), 7.5, 3, 0.75)
	local st = Vector3.new(w * 0.25, 0, d * 0.25)
	column(ctx, "Stump", 1.15, 1.5, st, C.bark, M.Wood)
	disc(
		ctx,
		"StumpTop",
		CFrame.new(st + Vector3.new(0, 1.52, 0)) * CFrame.Angles(PI / 2, 0, 0),
		2.1,
		0.06,
		C.woodLight,
		M.Wood
	)
	block(
		ctx,
		"AxeHandle",
		Vector3.new(0.24, 2.4, 0.24),
		CFrame.new(st + Vector3.new(0.2, 2.5, 0)) * CFrame.Angles(0, 0, rad(-22)),
		C.wood,
		M.Wood
	)
	block(ctx, "AxeHead", Vector3.new(0.9, 0.6, 0.2), CFrame.new(st + Vector3.new(-0.15, 1.65, 0)), C.iron, M.Metal)
	for i = 0, 2 do
		block(
			ctx,
			"Firewood",
			Vector3.new(0.7, 0.7, 1.4),
			CFrame.new(st + Vector3.new(1.8 + i * 0.6, 0.35 + (i % 2) * 0.2, 0.8 - i * 0.5))
				* CFrame.Angles(0, rad(i * 35), 0),
			C.woodLight,
			M.Wood
		)
	end
	-- firewood stacked along the shed side, a hand cart with logs by the drop-off
	logStack(ctx, CFrame.new(sx0, 0, sz0 + sd / 2 + 0.6), sw - 1.6, 1, 0.5)
	local cart = CFrame.new(w * 0.38, 0, -d * 0.4) * CFrame.Angles(0, rad(25), 0)
	block(ctx, "CartBed", Vector3.new(3.6, 1, 2.4), cart * CFrame.new(0, 1.7, 0), C.wood, M.WoodPlanks)
	for _, sz in { -1, 1 } do
		disc(
			ctx,
			"CartWheel",
			cart * CFrame.new(0.3, 1.2, sz * 1.35) * CFrame.Angles(0, PI / 2, 0),
			2.4,
			0.3,
			C.woodDark,
			M.Wood
		)
	end
	for k = 0, 1 do
		log(ctx, "CartLog", 0.5, 4.4, cart * CFrame.new(0, 2.7, (k - 0.5) * 1.05), C.bark)
	end
	-- old stumps and the kingdom flag
	column(ctx, "OldStump", 0.9, 1, Vector3.new(w * 0.42, 0, d * 0.42), C.bark, M.Wood)
	column(ctx, "OldStump", 0.7, 0.8, Vector3.new(-w * 0.45, 0, -d * 0.38), C.bark, M.Wood)
	flagpole(ctx, -w / 2 + 1, 0, -d / 2 + 1, 9, color)
	banner(ctx, sx0 + sw / 2 - 1.6, 7.0, sz0 - sd / 2 + 0.05, 0, color, 3, style, 1.8)
	attach(ctx, "Door", Vector3.new(-w * 0.2, 0, -d / 2 - 2.5))
	attach(ctx, "DropOff", Vector3.new(w * 0.25, 0, -d / 2 - 2))
	workSpots(ctx, { Vector3.new(w * 0.25 + 2, 0, d * 0.25), Vector3.new(-w * 0.2, 0, d * 0.1) })
end

-- ------------------------------------------------------------------ quarry

BUILDERS.quarry = function(ctx, _level, color, style, fp)
	local w, d = fp.X - 2, fp.Y - 2
	-- stepped rock face at the back: three tiers of irregular cut blocks
	local tiers = { { 3.4, 4.2, 2.6 }, { 6.6, 3.6, 5.6 }, { 9.6, 3.2, 8.2 } }
	for ti, t in tiers do
		local hh, depth, zc = t[1], t[2], t[3]
		local n = 3
		local x = -w / 2 + 0.4 + ti * 0.04 -- each tier inset a little: no shared end faces
		for i = 1, n do
			local bw = (w - 0.8) / n + jit(ti * 7 + i, 1.2)
			if i == n then
				bw = w / 2 - 0.4 - ti * 0.04 - x
			end
			local th = hh + jit(ti * 3 + i, 0.6)
			block(
				ctx,
				"RockFace",
				Vector3.new(bw - 0.15, th, depth + jit(ti + i * 5, 0.5)),
				CFrame.new(x + bw / 2 + ti * 0.013, th / 2, zc + jit(i * 11 + ti, 0.3)),
				shade(QUARRY_STONE[ti], 1 + jit(ti * 5 + i * 3, 0.07)),
				M.Rock
			)
			x += bw
		end
	end
	-- rubble at the foot of the face and a ladder up the first tier
	for i = 0, 3 do
		ball(
			ctx,
			"Rubble",
			1.1 + (i % 2) * 0.5,
			Vector3.new(-w / 2 + 2.5 + i * 4.6, 0.6 + (i % 2) * 0.25, 0.2 + jit(i * 3, 0.4)),
			C.stoneDark,
			M.Rock
		)
	end
	local lad = CFrame.new(w * 0.1, 0, 0.5) * CFrame.Angles(0, PI / 2, 0) -- local +X = world -Z
	for _, sx in { -0.55, 0.55 } do
		strut(ctx, "LadderRail", lad, 1.2, 0, -0.1, 4.2, 0.22, 0.22, C.wood, M.Wood, sx)
	end
	for k = 1, 3 do
		local f = k / 4
		block(
			ctx,
			"LadderRung",
			Vector3.new(1.1, 0.18, 0.18),
			CFrame.new(w * 0.1, f * 4.2, 0.5 - 1.2 + f * 1.3),
			C.wood,
			M.Wood
		)
	end
	-- cut blocks ready to haul (front left, by the drop-off)
	for i, p in
		{
			Vector3.new(-6.6, 0, -4.2),
			Vector3.new(-4.0, 0, -4.6),
			Vector3.new(-5.3, 1.7, -4.3),
			Vector3.new(-7.4, 0, -1.6),
		}
	do
		block(
			ctx,
			"CutBlock",
			Vector3.new(2.4, 1.7, 2.1),
			CFrame.new(p + Vector3.new(0, 0.85, 0)) * CFrame.Angles(0, rad(i * 13 - 20), 0),
			if i % 2 == 0 then C.stoneLight else shade(C.stoneLight, 0.94),
			M.Slate
		)
	end
	-- wooden crane: mast, jib, brace, rope, hanging block
	local cx, cz = w * 0.3, -d * 0.12
	block(ctx, "CraneBase", Vector3.new(3, 0.6, 3), CFrame.new(cx, 0.3, cz), C.timber, M.Wood)
	block(ctx, "CraneMast", Vector3.new(0.8, 11.5, 0.8), CFrame.new(cx, 6.05, cz), C.wood, M.Wood)
	block(ctx, "CraneJib", Vector3.new(8, 0.6, 0.6), CFrame.new(cx - 3.4, 11.2, cz), C.wood, M.Wood)
	strut(ctx, "CraneBrace", CFrame.new(0, 0, cz), cx, 7.4, cx - 3.6, 10.9, 0.45, 0.45, C.wood, M.Wood)
	block(ctx, "CraneRope", Vector3.new(0.14, 4.6, 0.14), CFrame.new(cx - 7, 8.6, cz), C.canvas, M.Fabric)
	block(ctx, "CraneLoad", Vector3.new(1.8, 1.4, 1.8), CFrame.new(cx - 7, 5.6, cz), C.stoneLight, M.Slate)
	-- hand cart with stones
	local cart = CFrame.new(-w * 0.05, 0, -d * 0.32) * CFrame.Angles(0, rad(12), 0)
	block(ctx, "CartBed", Vector3.new(3.6, 1, 2.4), cart * CFrame.new(0, 1.7, 0), C.wood, M.WoodPlanks)
	for _, sz in { -1, 1 } do
		disc(
			ctx,
			"CartWheel",
			cart * CFrame.new(0.3, 1.2, sz * 1.35) * CFrame.Angles(0, PI / 2, 0),
			2.4,
			0.3,
			C.woodDark,
			M.Wood
		)
	end
	block(ctx, "CartStones", Vector3.new(2.8, 0.9, 1.8), cart * CFrame.new(0, 2.6, 0), C.stone, M.Slate)
	-- tool shelter with a kingdom roof (right back)
	local tx, tz = w / 2 - 2.2, d * 0.05
	for _, pz in { -1, 1 } do
		block(
			ctx,
			"ShelterPost",
			Vector3.new(0.5, 6.4, 0.5),
			CFrame.new(tx - 1.6, 3.2, tz + pz * 2.2),
			C.timber,
			M.Wood
		)
	end
	block(ctx, "ShelterWall", Vector3.new(0.4, 7.2, 5), CFrame.new(tx + 1.3, 3.6, tz), C.wood, M.WoodPlanks)
	leanTo(ctx, CFrame.new(tx + 1.4, 7.2, tz) * CFrame.Angles(0, PI / 2, 0), 5.6, 3.6, 1.4, color, 0.85, 2)
	block(ctx, "ToolRack", Vector3.new(0.3, 0.3, 3.6), CFrame.new(tx + 0.9, 3.6, tz), C.wood, M.Wood)
	for i = -1, 1 do
		block(
			ctx,
			"Pick",
			Vector3.new(0.2, 3, 0.2),
			CFrame.new(tx + 0.75, 2.2, tz + i * 1.1) * CFrame.Angles(rad(8 * i), 0, 0),
			C.wood,
			M.Wood
		)
		block(ctx, "PickHead", Vector3.new(0.25, 0.25, 1.0), CFrame.new(tx + 0.75, 0.8, tz + i * 1.1), C.iron, M.Metal)
	end
	flagpole(ctx, -w / 2 + 1, 0, -d / 2 + 1, 8, color)
	banner(ctx, cx, 9.4, cz - 0.05, 0, color, 3.4, style, 1.8)
	attach(ctx, "Door", Vector3.new(0, 0, -d / 2 - 1))
	attach(ctx, "DropOff", Vector3.new(-w * 0.3, 0, -d / 2))
	workSpots(ctx, { Vector3.new(-w * 0.2, 0, d * 0.08), Vector3.new(w * 0.15, 0, d * 0.08) })
end

-- ------------------------------------------------------------------ barracks

-- Barracks levels (G13.5, visible from the aerial camera):
--   L1 timber hall on a low plinth; L2 stone ground floor + jettied timber storey, banners, weapon racks;
--   L3 + corner tower with the kingdom cap + sand training yard (dummies, target);
--   L4 + crenellated gatehouse with crest and a big flag + a second tower.
BUILDERS.barracks = function(ctx, level, color, style, fp)
	local S = stoneFor(style)
	local lv = math.clamp(level, 1, 4)
	local w, d = if lv == 1 then fp.X - 8 else fp.X - 7, if lv == 1 then fp.Y - 9 else fp.Y - 8
	local oz = 1.5 -- pushed back: training yard in front
	local pl = if lv == 1 then 1 else 1.2
	stonePlinth(ctx, w + 0.9, d + 0.9, pl, 0, oz, if lv == 1 then nil else S, 5)
	local fzw = oz - d / 2 -- front wall
	local gw = 12
	local topY, topD
	if lv == 1 then
		-- single timber-framed storey
		local h = 8.6
		timberBox(ctx, w, d, pl, h, PLASTERS[2], 0, oz)
		local f = wallFrames(w, d, pl, 0, oz)
		local ops: { Opening } = { { u = 0, hw = 3.3, door = true } }
		for _, sx in { -1, 1 } do
			windowAt(ctx, f.front * CFrame.new(sx * 6.4, 3, 0), { shutters = color })
			table.insert(ops, { u = sx * 6.4, hw = 1.9 })
		end
		for _, side in { "left", "right" } do
			windowAt(ctx, f[side] * CFrame.new(0, 3, 0), { shutters = color })
		end
		windowAt(ctx, f.back * CFrame.new(0, 3, 0), { simple = true })
		frameWall(ctx, f.front, w, h, ops, 2.6)
		frameWall(ctx, f.left, d, h, { { u = 0, hw = 1.9 } }, 2.6)
		frameWall(ctx, f.right, d, h, { { u = 0, hw = 1.9 } }, 2.6)
		frameWall(ctx, f.back, w, h, { { u = 0, hw = 1.9 } }, 2.6)
		doorAt(ctx, CFrame.new(0, pl, fzw), { w = 4.6, h = 7.6, voussoirs = 5, step = pl })
		topY, topD = pl + h, d
	else
		local h1, h2 = 8, 6.8
		block(ctx, "Walls", Vector3.new(w, h1 - 0.03, d), CFrame.new(0, pl + h1 / 2 + 0.015, oz), S.base, M.Cobblestone)
		quoins(ctx, w, d, pl, h1, S.light, 2, 0, oz)
		local y2 = pl + h1
		local d2 = d + 1.2
		block(ctx, "JettyBeam", Vector3.new(w + 0.8, 0.7, d2 + 0.3), CFrame.new(0, y2 + 0.05, oz), C.timber, M.Wood)
		timberBox(ctx, w, d2, y2, h2, C.plaster, 0, oz)
		local f2 = wallFrames(w, d2, y2, 0, oz)
		local f1 = wallFrames(w, d, pl, 0, oz)
		local frontOps: { Opening } = {}
		local wxs = if lv >= 4 then { -gw / 2 - 2.6, gw / 2 + 2.6 } else { -10.2, -4.6, 4.6, 10.2 }
		for _, wx in wxs do
			windowAt(ctx, f2.front * CFrame.new(wx, 2.2, 0), { shutters = color })
			table.insert(frontOps, { u = wx, hw = 1.9 })
		end
		if lv >= 4 then
			table.insert(frontOps, { u = 0, hw = gw / 2 + 0.3 })
		end
		for _, side in { "left", "right" } do
			windowAt(ctx, f2[side] * CFrame.new(0, 2.2, 0), { shutters = color })
		end
		for _, bx in { -w * 0.25, w * 0.25 } do
			windowAt(ctx, f2.back * CFrame.new(bx, 2.2, 0), { simple = true })
		end
		frameWall(ctx, f2.front, w, h2, frontOps, 1.8)
		frameWall(ctx, f2.left, d2, h2, { { u = 0, hw = 1.9 } }, 1.8)
		frameWall(ctx, f2.right, d2, h2, { { u = 0, hw = 1.9 } }, 1.8)
		frameWall(ctx, f2.back, w, h2, { { u = -w * 0.25, hw = 1.9 }, { u = w * 0.25, hw = 1.9 } }, 1.8)
		-- ground floor: door (until the gatehouse takes over), arrow slits, banners from the jetty beam
		if lv < 4 then
			doorAt(ctx, CFrame.new(0, pl, fzw), {
				w = 4.6,
				h = 7.4,
				voussoirs = 5,
				stone = S.base,
				stoneLight = S.light,
				step = pl,
			})
		end
		-- banners from the jetty beam (L4: the gatehouse carries its own banners, crest and flag instead)
		if lv < 4 then
			for _, bx in { -5.4, 5.4 } do
				banner(ctx, bx, y2 - 0.45, fzw - 0.05, 0, color, 4.6, style, 2.2)
			end
		end
		for _, sx in { -1, 1 } do
			windowAt(ctx, f1.front * CFrame.new(sx * (w / 2 - 2.2), 2.4, 0), { slit = true, frame = S.light })
		end
		topY, topD = y2 + h2, d2
	end
	local info = tileRoof(ctx, {
		w = w,
		d = topD,
		y = topY,
		rise = topD / 2 * 0.9,
		cf = CFrame.new(0, 0, oz),
		over = 1.3,
		gable = 1,
		color = color,
		tint = 0.88,
		infill = C.plaster,
		kingPost = true,
	})
	chimney(ctx, -w * 0.32, oz + 2, topY - 1, info.ridgeY + 2.4 - (topY - 1))
	-- towers with the kingdom cap: back-right from L3, back-left from L4
	if lv >= 3 then
		local towers = if lv >= 4 then { 1, -1 } else { 1 }
		for _, sx in towers do
			local tx = sx * math.min(w / 2, fp.X / 2 - 4.25)
			local tz = math.min(oz + d / 2, fp.Y / 2 - 4.25)
			roundTower(ctx, tx, tz, pl, 2.9, topY + 4, S, { math.atan2(-sx, 1) })
			towerCap(ctx, style, 5.8, pl + topY + 4, color, tx, tz)
		end
	end
	-- L4 gatehouse: crenellated stone block projecting from the front, door, banners, crest, big flag
	if lv >= 4 then
		local gd = 3.4
		local gh = 19.5
		local gz = fzw - gd / 2 + 1
		block(ctx, "Gatehouse", Vector3.new(gw, gh, gd + 2), CFrame.new(0, gh / 2, gz), S.base, M.Cobblestone)
		block(ctx, "GatehouseCorbel", Vector3.new(gw + 1, 1, gd + 3), CFrame.new(0, gh - 0.1, gz), S.light, M.Slate)
		crenellate(ctx, gw + 1, gd + 3, gh + 0.4, S.light, 0, gz, { m = 2, h = 2.3, t = 0.9, gap = 1.5 })
		quoins(ctx, gw, gd + 2, 0, gh - 1, S.light, 3, 0, gz)
		local gfz = gz - (gd + 2) / 2
		doorAt(ctx, CFrame.new(0, pl, gfz), {
			w = 5.2,
			h = 8.6,
			voussoirs = 5,
			stone = S.base,
			stoneLight = S.light,
			step = pl,
		})
		for _, sx in { -1, 1 } do
			banner(ctx, sx * 4.75, gh - 2.6, gfz - 0.05, 0, color, 8.6, style, 2)
		end
		crest(ctx, CFrame.new(0, 12, gfz - 0.2), 2.8, color, style)
		windowAt(
			ctx,
			CFrame.new(0, 14.2, gfz),
			{ arched = true, w = 1.8, h = 2.4, frame = S.light, frameMaterial = M.Slate, bare = true }
		)
		flagpole(ctx, 0, gh + 0.4, gz, 11, color)
	end
	if lv <= 2 then
		-- a tall kingdom standard on the yard corner: reads "military" before the towers arrive
		flagpole(ctx, fp.X / 2 - 4, 0, fzw - 1.2, 11, color) -- the flag flies toward +X, clear of the roof
	end
	-- weapon racks (L1 one, L2+ two), dummies, archery target
	local za, zb = -fp.Y / 2 + 0.2, fzw
	if lv >= 3 then
		block(ctx, "Yard", Vector3.new(w + 4, 0.16, zb - za), CFrame.new(0, 0.08, (za + zb) / 2), SAND, M.Sand)
	end
	local racks = if lv == 1 then { -1 } else { -1, 1 }
	for _, rs in racks do
		local rx = rs * (w / 2 - 2.8)
		local rz = fzw - 1.6
		for _, px in { -1.7, 1.7 } do
			block(ctx, "RackPost", Vector3.new(0.4, 3.6, 0.4), CFrame.new(rx + px, 1.8, rz), C.timber, M.Wood)
		end
		block(ctx, "Rack", Vector3.new(4, 0.35, 0.36), CFrame.new(rx, 3.1, rz), C.wood, M.Wood)
		for i = 0, 2 do
			block(
				ctx,
				"Spear",
				Vector3.new(0.2, 5, 0.2),
				CFrame.new(rx - 1.1 + i * 1.1, 2.5, rz - 0.35) * CFrame.Angles(rad(-10), 0, 0),
				C.wood,
				M.Wood
			)
		end
		if lv >= 2 then
			disc(
				ctx,
				"RackShield",
				CFrame.new(rx + rs * 2.6, 1.3, rz) * CFrame.Angles(rad(-12), 0, 0),
				2,
				0.3,
				shade(color, 0.85),
				M.Wood,
				0.85
			)
		end
	end
	local dummies = if lv >= 3 then { 0, 3.4 } else { 0 }
	for i, dx in dummies do
		local p = Vector3.new(gw / 2 + 2.8 + dx, 0, -fp.Y / 2 + 1.8 + (i - 1) * 0.9)
		column(ctx, "DummyPost", 0.22, 4.6, p, C.wood, M.Wood)
		block(ctx, "DummyArms", Vector3.new(2.8, 0.3, 0.3), CFrame.new(p + Vector3.new(0, 3.5, 0)), C.wood, M.Wood)
		ball(ctx, "DummyBody", 1.8, p + Vector3.new(0, 3, 0), STRAW, M.Grass)
		ball(ctx, "DummyHead", 1.1, p + Vector3.new(0, 4.5, 0), C.canvas, M.Fabric)
	end
	if lv >= 3 then
		local tp = CFrame.new(-gw / 2 - 3.2, 0, -fp.Y / 2 + 1.6) * CFrame.Angles(0, rad(20), 0)
		strut(ctx, "TargetLeg", tp, -0.9, 0, 0, 3.2, 0.25, 0.25, C.wood, M.Wood, 0.4)
		strut(ctx, "TargetLeg", tp, 0.9, 0, 0, 3.2, 0.25, 0.25, C.wood, M.Wood, 0.4)
		disc(ctx, "Target", tp * CFrame.new(0, 2.6, 0), 2.8, 0.4, STRAW, M.Grass)
		disc(ctx, "TargetRing", tp * CFrame.new(0, 2.6, -0.12), 1.8, 0.3, RED_PAINT, M.Fabric)
		disc(ctx, "TargetEye", tp * CFrame.new(0, 2.6, -0.2), 0.8, 0.3, C.canvas, M.Fabric)
	end
	local dd = fp.Y - 2
	attach(ctx, "Door", Vector3.new(0, 0, -dd / 2 - 2.5))
	attach(ctx, "Rally", Vector3.new(0, 0, -dd / 2 - 10))
	workSpots(ctx, { Vector3.new((fp.X - 2) / 2 - 4, 0, -dd / 2 - 8) })
end

-- ------------------------------------------------------------------ watchtower

BUILDERS.watchtower = function(ctx, level, color, style, fp)
	local S = stoneFor(style)
	local big = level >= 2
	local w = fp.X - 4.5
	local hw = w / 2
	local h = if big then 30 else 24
	local pl = 1.8
	stonePlinth(ctx, w + 1.6, w + 1.6, pl, 0, 0, S, 3, 4)
	block(ctx, "Shaft", Vector3.new(w, h - 0.03, w), CFrame.new(0, pl + h / 2 + 0.015, 0), S.base, M.Cobblestone)
	quoins(ctx, w, w, pl, h - 1, S.light, if big then 6 else 5)
	block(ctx, "StringCourse", Vector3.new(w + 0.6, 0.6, w + 0.6), CFrame.new(0, pl + h * 0.48, 0), S.light, M.Slate)
	local gy = pl + h
	block(ctx, "Gallery", Vector3.new(w + 2.4, 1.3, w + 2.4), CFrame.new(0, gy + 0.65, 0), S.light, M.Slate)
	local tf = wallFrames(w, w, gy)
	for _, side in { "front", "back", "left", "right" } do
		for _, u in { -hw * 0.55, hw * 0.55 } do
			bracket(ctx, tf[side] * CFrame.new(u, 0, 0), 1.2, 1.6, S.light, M.Slate)
		end
	end
	-- the cap rises from inside the parapet (its eave over the merlons); emerald's hoarding replaces it
	if style ~= "emerald" then
		crenellate(ctx, w + 2.4, w + 2.4, gy + 1.3, S.light, 0, 0, { m = 1.9, h = 2.4, t = 0.9, gap = 1.4 })
	end
	towerCap(ctx, style, w + 0.4, if style == "emerald" then gy + 1.3 else gy + 2.6, color, 0, 0, 5.5)
	doorAt(ctx, CFrame.new(0, pl, -hw), {
		w = 4.4,
		h = 7.6,
		voussoirs = 5,
		stone = S.base,
		stoneLight = S.light,
		step = pl,
	})
	banner(ctx, 0, gy - 0.7, -hw - 0.05, 0, color, if big then 8 else 6.5, style, 3)
	local sf = wallFrames(w, w, pl)
	for _, side in { "left", "right", "back" } do
		windowAt(
			ctx,
			sf[side] * CFrame.new(0, h * 0.62, 0),
			{ arched = true, w = 2, h = 3.4, frame = S.light, frameMaterial = M.Slate, simple = true }
		)
		windowAt(ctx, sf[side] * CFrame.new(0, 5.5, 0), { slit = true, frame = S.light })
	end
	windowAt(ctx, sf.front * CFrame.new(0, 10.4, 0), { slit = true, frame = S.light })
	local ww = fp.X - 4
	attach(ctx, "Door", Vector3.new(0, 0, -ww / 2 - 2.5))
	workSpots(ctx, { Vector3.new(0, 0, -ww / 2 - 4) })
end

-- ------------------------------------------------------------------ wall and gate (VS-2)

BUILDERS.wall = function(ctx, _level, color, style, fp)
	local S = stoneFor(style)
	local w, d = fp.X, fp.Y - 2.8 -- batter, walkway and buttresses stay inside the 8-stud footprint
	local h = 18
	block(ctx, "Batter", Vector3.new(w, 3, d + 1.4), CFrame.new(0, 1.5, 0), S.dark, M.Cobblestone)
	for _, sz in { -1, 1 } do
		wedge(
			ctx,
			"BatterSlope",
			Vector3.new(w - 0.1, 1.2, 0.7),
			CFrame.new(0, 3.6, sz * (d / 2 + 0.35)) * CFrame.Angles(0, if sz < 0 then 0 else PI, 0),
			S.dark,
			M.Cobblestone
		)
	end
	block(ctx, "Curtain", Vector3.new(w, h, d), CFrame.new(0, 3 + h / 2, 0), S.base, M.Cobblestone)
	block(ctx, "StringCourse", Vector3.new(w - 0.1, 0.6, d + 0.6), CFrame.new(0, 3 + h * 0.55, 0), S.light, M.Slate)
	block(ctx, "Walkway", Vector3.new(w, 1, d + 1.6), CFrame.new(0, 3 + h + 0.5, 0), S.light, M.Slate)
	for _, u in { -w * 0.3, 0, w * 0.3 } do
		bracket(ctx, CFrame.new(u, 3 + h, -d / 2), 0.8, 1.3, S.light, M.Slate)
	end
	crenellate(ctx, w, d + 1.6, 3 + h + 1, S.light, 0, 0, { m = 2.6, h = 2.8, t = 1, gap = 1.8 })
	for _, sx in { -1, 1 } do
		wedge(
			ctx,
			"Buttress",
			Vector3.new(2.4, 9, 1.35),
			CFrame.new(sx * w * 0.3, 3 + 4.5, -d / 2 - 0.675),
			S.base,
			M.Cobblestone
		)
	end
	banner(ctx, 0, 3 + h - 1.2, -d / 2 - 0.05, 0, color, 7, style, 3)
	windowAt(ctx, CFrame.new(-w * 0.15, 3 + h * 0.62, -d / 2), { slit = true, frame = S.light })
	windowAt(ctx, CFrame.new(w * 0.15, 3 + h * 0.62, -d / 2), { slit = true, frame = S.light })
	attach(ctx, "Door", Vector3.new(0, 0, -fp.Y / 2 - 2))
end

BUILDERS.gate = function(ctx, _level, color, style, fp)
	local S = stoneFor(style)
	local w, d = fp.X, fp.Y - 2.4 -- towers, plinth, corbels and caps stay inside the footprint
	local h = 20
	local pass = 14
	local pw = (w - pass) / 2 - 0.6
	for _, sx in { -1, 1 } do
		local x = sx * (pass / 2 + pw / 2)
		stonePlinth(ctx, pw + 0.6, d + 0.6, 2.4, x, 0, S, 13 + sx, 6)
		block(ctx, "GateTower", Vector3.new(pw, h + 4, d), CFrame.new(x, (h + 4) / 2, 0), S.base, M.Cobblestone)
		block(ctx, "TowerCorbel", Vector3.new(pw + 1.2, 1.2, d + 1.2), CFrame.new(x, h + 4.4, 0), S.light, M.Slate)
		crenellate(ctx, pw + 1.2, d + 1.2, h + 5, S.light, x, 0, { m = 2.2, h = 2.6, t = 1, gap = 1.6 })
		towerCap(ctx, style, pw * 0.62, h + 5, color, x, 0)
		banner(ctx, x, h + 2.6, -d / 2 - 0.05, 0, color, 8, style, 3.2)
		windowAt(ctx, CFrame.new(x, 6, -d / 2), { slit = true, frame = S.light })
	end
	-- pointed arch: lintel above, spandrel wedges, voussoirs along the two chords
	block(ctx, "Lintel", Vector3.new(pass, h - 15, d - 1), CFrame.new(0, 15 + (h - 15) / 2, 0), S.base, M.Cobblestone)
	local spring = 9
	for _, sx in { -1, 1 } do
		wedge(
			ctx,
			"Spandrel",
			Vector3.new(d - 1, 15 - spring, pass / 2),
			CFrame.new(sx * pass / 4, (15 + spring) / 2, 0) * CFrame.Angles(0, sx * PI / 2, 0) * CFrame.Angles(0, 0, PI),
			S.base,
			M.Cobblestone
		)
		for i = 0, 3 do
			local t = (i + 0.5) / 4
			local px = sx * (pass / 2) * (1 - t)
			local py = spring + (15 - spring) * t
			block(
				ctx,
				if i == 3 then "Keystone" else "Voussoir",
				Vector3.new(2.3, 1.2, 1.2),
				CFrame.new(px, py + 0.35, -d / 2 + 0.4) * CFrame.Angles(0, 0, -sx * math.atan2(15 - spring, pass / 2)),
				if i % 2 == 0 then S.light else S.base,
				M.Slate
			)
		end
	end
	-- portcullis (raised), parapet over the passage, road
	for i = 0, 5 do
		block(
			ctx,
			"PortcullisBar",
			Vector3.new(0.4, 4.6, 0.4),
			CFrame.new(-5 + i * 2, 12.7, -d / 2 + 1.6),
			C.iron,
			M.Metal
		)
	end
	block(ctx, "Portcullis", Vector3.new(12, 0.45, 0.45), CFrame.new(0, 11.2, -d / 2 + 1.6), C.iron, M.Metal)
	crenellate(ctx, pass - 0.2, d, h, S.light, 0, 0, { m = 2.2, h = 2.4, t = 1, gap = 1.6, xOnly = true })
	crest(ctx, CFrame.new(0, 17.4, -d / 2 + 0.3), 3, color, style)
	block(ctx, "GateRoad", Vector3.new(pass, 0.2, fp.Y), CFrame.new(0, 0.1, 0), C.stoneDark, M.Cobblestone)
	attach(ctx, "Door", Vector3.new(0, 0, -fp.Y / 2 - 2))
	attach(ctx, "Rally", Vector3.new(0, 0, fp.Y / 2 + 4))
end

-- ------------------------------------------------------------------ G13.5 VS-2 types (FL-0086)
-- Mine (L1–3), blacksmith (L1–3), market, infirmary, granary and shrine (L1–2), design/living-kingdom.md §4.
-- The language of the G2 types (kingdom tiles, canopies, shutters and blankets with KitTint) plus the rules of
-- the FL-0086 D-019 review:
-- - identity from massing and a hero ≥ 4 studs: the headframe, the open forge with its fire and smoke, the
--   striped stalls, the open ward, the staddled granary, the focal stone or pavilion; no clutter under 1 stud;
-- - the kingdom cap from hueStyle on every level (`smallCap` on louvres, cupolas, lanterns, the mine's portal
--   crest and the turret; crimson a slender spire with the keep's gold finial); neutral, having no kingdom, gets
--   a stepped stone top, never azure's pyramid;
-- - the kingdom emblem on a plate or banner ≥ 3 studs: a light glyph on a deep kingdom field (gold keeps its
--   deep-gold sun on the light field, D-039);
-- - fire is the shared `flame` prop (Neon, ART_DIRECTION §3: crystals and fire; no lights).
-- Levels add height, roofs and props inside the pinned footprint. WorkSpot1 is the key citizen's place (the
-- miner at the adit, the smith at the anvil, the merchant at the counter, the healer at the cots, the
-- provisioner at the granary door, the elder before the altar). The shrine carries no real-world religious
-- symbol (an altar, a broad focal stone, standing stones, a cairn, braziers, the kingdom emblem; nothing forms a
-- cross).

local ADIT = Color3.fromRGB(30, 26, 24) -- a tunnel mouth, a shaft, a belfry opening
local ORE = Color3.fromRGB(84, 78, 74)
-- the mine's rock: cool grey, ≈ 25 % darker than the quarry stone, with near-black crevices
local MINE_ROCK = { Color3.fromRGB(118, 121, 128), Color3.fromRGB(101, 104, 112), Color3.fromRGB(86, 89, 97) }
local CREVICE = Color3.fromRGB(36, 38, 44)
local SPOIL = Color3.fromRGB(104, 100, 98)
local EMBER = Color3.fromRGB(255, 120, 30)
local EMBER_HOT = Color3.fromRGB(255, 214, 90)
local SMOKE = Color3.fromRGB(208, 208, 204)
local WATER = Color3.fromRGB(86, 150, 196)
local LINEN = Color3.fromRGB(246, 242, 230)
local LEATHER = Color3.fromRGB(112, 72, 46)
local STEEL = Color3.fromRGB(190, 196, 204)
local BRONZE = Color3.fromRGB(170, 116, 58)
local BURLAP = Color3.fromRGB(190, 160, 112)
local GLYPH_IRON = Color3.fromRGB(46, 48, 54)
local FLASK = Color3.fromRGB(64, 150, 128)
local CORK = Color3.fromRGB(150, 104, 60)
-- market goods and herbs: muted, so no prop reads as a kingdom colour
local PRODUCE = {
	Color3.fromRGB(206, 78, 56),
	Color3.fromRGB(232, 190, 74),
	Color3.fromRGB(122, 166, 72),
	Color3.fromRGB(222, 130, 52),
}
local CLOTHS = { Color3.fromRGB(160, 86, 74), Color3.fromRGB(92, 112, 150), Color3.fromRGB(198, 160, 84) }
local HERB_PURPLE = Color3.fromRGB(170, 140, 210)

-- a cube stood on a corner (its body diagonal vertical): a pointed tongue tapering from every side
local CORNER_UP = CFrame.fromAxisAngle(Vector3.new(-1, 0, 1).Unit, math.acos(1 / math.sqrt(3)))

-- Flame prop (forge, brazier, torch, altar): three stacked tapering tongues, orange outside with the yellow core
-- rising through the top and a small orange tip. Neon (ART_DIRECTION §3: crystals and fire); no lights.
-- pos = the base of the fire, s = its width (height ≈ 1.55 s). 3 parts.
local function flame(ctx: Ctx, pos: Vector3, s: number)
	local a1, a2, a3 = s * 0.64, s * 0.44, s * 0.26
	local y1 = a1 * 0.866
	local y2 = y1 + s * 0.36
	block(ctx, "Flame", Vector3.new(a1, a1, a1), CFrame.new(pos + Vector3.new(0, y1, 0)) * CORNER_UP, EMBER, M.Neon)
	block(
		ctx,
		"FlameCore",
		Vector3.new(a2, a2, a2),
		CFrame.new(pos + Vector3.new(0.04 * s, y2, -0.08 * s)) * CORNER_UP,
		EMBER_HOT,
		M.Neon
	)
	block(
		ctx,
		"FlameTip",
		Vector3.new(a3, a3, a3),
		CFrame.new(pos + Vector3.new(-0.05 * s, y2 + s * 0.42, -0.02 * s)) * CORNER_UP,
		EMBER,
		M.Neon
	)
end

-- Kingdom emblem plate (a D-039 field; review: ≥ 3 studs, a light glyph on a deep kingdom field): an ivory
-- border, the field in a deep shade of the kingdom colour, the emblem. Gold keeps its light field under the
-- deep-gold sun (D-039; the KitEmblems ΔL* gate) inside a timber border. cf = the plate centre on its mount
-- face, local -Z out of it. ≤ 7 parts.
local PLATE = 3.2
local function emblemPlate(ctx: Ctx, cf: CFrame, color: Color3, size: number?)
	local s = size or PLATE
	local gold = hueStyle(color) == "gold"
	local ft = if gold then 1 else 0.8
	block(
		ctx,
		"SignFrame",
		Vector3.new(s + 0.5, s + 0.5, 0.2),
		cf * CFrame.new(0, 0, -0.1),
		if gold then C.timber else Pieces.IVORY,
		M.WoodPlanks
	)
	local field = block(
		ctx,
		"SignBoard",
		Vector3.new(s, s, 0.24),
		cf * CFrame.new(0, 0, -0.17),
		shade(color, ft),
		M.SmoothPlastic,
		ft
	)
	Pieces.emblem(ctx, field, cf * CFrame.new(0, 0, -0.29), s * 0.84, color)
end

-- Kingdom cap for the VS-2 tops (review: a cap on every level, crimson a true spire) on a w-wide louvre, cupola,
-- lantern, crest or turret whose top is at y: crimson a slender three-step spire with the keep's gold finial,
-- azure a slate-eaved pyramid, emerald a timber hoarding under a low pyramid, gold a dome on an ivory drum.
-- Neutral (no kingdom) gets a stepped stone top and a stone knob, never azure's pyramid. 3–7 parts. Returns the
-- top.
local function smallCap(ctx: Ctx, style: string, w: number, y: number, color: Color3, x: number, z: number): number
	if style == "crimson" then
		column(ctx, "SpireEave", w / 2 + 0.35, 0.45, Vector3.new(x, y, z), shade(color, 0.66), M.Slate, 0.66)
		local yy = y + 0.4
		for i, k in { { 0.42, 0.95 }, { 0.27, 0.9 }, { 0.14, 0.75 } } do
			local f = if i == 2 then 0.88 else 1
			column(ctx, "Spire", w * k[1], w * k[2] + 0.05, Vector3.new(x, yy, z), shade(color, f), M.ClayRoofTiles, f)
			yy += w * k[2]
		end
		return Pieces.finial(ctx, x, yy - 0.05, z, C.gold, 1.5)
	elseif style == "azure" then
		block(
			ctx,
			"CapEave",
			Vector3.new(w + 1.0, 0.45, w + 1.0),
			CFrame.new(x, y + 0.22, z),
			shade(color, 0.62),
			M.Slate,
			0.62
		)
		local H = w * 1.45
		pyramidRoof(ctx, w + 0.6, H, y + 0.45, color, 1, x, z)
		return Pieces.finial(ctx, x, y + 0.45 + H - 0.15, z, Pieces.TRIM.azure, 1.2)
	elseif style == "emerald" then
		block(ctx, "Hoarding", Vector3.new(w + 0.9, 1.3, w + 0.9), CFrame.new(x, y + 0.65, z), C.wood, M.WoodPlanks)
		local H = w * 0.75
		pyramidRoof(ctx, w + 1.5, H, y + 1.3, color, 1, x, z)
		return Pieces.finial(ctx, x, y + 1.3 + H - 0.15, z, Pieces.TRIM.emerald, 1.0)
	elseif style == "gold" then
		local r = w * 0.55
		column(ctx, "Drum", r * 0.86, 0.8, Vector3.new(x, y, z), Pieces.IVORY, M.Plaster)
		local cy = y + 0.8 + r * 0.3
		ball(ctx, "Dome", r * 2, Vector3.new(x, cy, z), color, M.SmoothPlastic, 1)
		return Pieces.finial(ctx, x, cy + r * 0.85, z, C.gold, 1.3)
	end
	block(ctx, "StoneTop", Vector3.new(w + 0.6, 0.6, w + 0.6), CFrame.new(x, y + 0.3, z), C.stoneLight, M.Slate)
	block(ctx, "StoneTop", Vector3.new(w * 0.6, 0.6, w * 0.6), CFrame.new(x, y + 0.9, z), C.stone, M.Slate)
	ball(
		ctx,
		"StoneKnob",
		w * 0.3 + 0.3,
		Vector3.new(x, y + 1.2 + (w * 0.3 + 0.3) / 2 - 0.05, z),
		C.stoneLight,
		M.Slate
	)
	return y + 1.15 + w * 0.3 + 0.3
end

-- Hipped roof in kingdom tiles over a W × D rectangle (W ≥ D, ridge along X), eaves at y: the four corners of a
-- D-wide pyramid pulled apart along X, the gap closed by a front and a back slope (W == D: a pyramid). 4–6 parts.
-- Returns the ridge height.
local function hipRoof(
	ctx: Ctx,
	W: number,
	D: number,
	R: number,
	y: number,
	color: Color3,
	tint: number,
	cx: number,
	cz: number
): number
	local half = D / 2
	local gap = W - D
	for i = 0, 3 do
		local f = if i % 2 == 0 then 1 else 0.9
		local off = CFrame.new(cx, y + R / 2, cz) * CFrame.Angles(0, rad(90 * i), 0) * CFrame.new(half / 2, 0, half / 2)
		local shift = if off.Position.X > cx then gap / 2 else -gap / 2
		Parts.cornerWedge(
			ctx,
			"RoofHip",
			Vector3.new(half, R, half),
			CFrame.new(shift, 0, 0) * off * CFrame.Angles(0, rad(90), 0),
			shade(color, tint * f),
			M.ClayRoofTiles,
			tint * f
		)
	end
	if gap > 0.05 then
		for _, side in { -1, 1 } do
			local f = if side < 0 then 1 else 0.9
			wedge(
				ctx,
				"RoofSlope",
				Vector3.new(gap + 0.04, R, half),
				CFrame.new(cx, y + R / 2, cz + side * half / 2) * CFrame.Angles(0, if side < 0 then 0 else PI, 0),
				shade(color, tint * f),
				M.ClayRoofTiles,
				tint * f
			)
		end
	end
	return y + R
end

-- Chimney smoke: three light-grey blocks rising and drifting, each larger and paler. 3 parts.
local function smoke(ctx: Ctx, pos: Vector3)
	local y = pos.Y
	for i, s in { 1.4, 1.9, 2.5 } do
		y += s * 0.55
		block(
			ctx,
			"Smoke",
			Vector3.new(s, s * 0.85, s),
			CFrame.new(pos.X + 0.45 * (i - 1) * i, y, pos.Z + 0.2 * (i - 1))
				* CFrame.Angles(rad(12 * i), rad(37 * i), rad(9 * i)),
			shade(SMOKE, 0.92 + 0.04 * i),
			M.SmoothPlastic
		)
		y += s * 0.4
	end
end

-- Brazier: a stone post, a bronze bowl and its fire. 5 parts.
local function brazier(ctx: Ctx, pos: Vector3, h: number, post: Color3)
	column(ctx, "BrazierPost", 0.34, h, pos, post, M.Slate)
	column(ctx, "Brazier", 0.85, 0.6, pos + Vector3.new(0, h, 0), BRONZE, M.Metal)
	flame(ctx, pos + Vector3.new(0, h + 0.45, 0), 1.25)
end

-- Burlap sack: a tan block leaning a little (white balls read as eggs). 1 part.
local function burlapSack(ctx: Ctx, cf: CFrame, s: number?)
	local k = s or 1.6
	block(
		ctx,
		"Sack",
		Vector3.new(k * 0.78, k, k * 0.6),
		cf * CFrame.new(0, k / 2 + 0.03, 0) * CFrame.Angles(rad(4), 0, rad(-5)),
		BURLAP,
		M.Fabric
	)
end

-- Wheat sheaf: a straw stook with a golden head. 2 parts.
local function sheaf(ctx: Ctx, pos: Vector3)
	column(ctx, "Sheaf", 0.6, 2.4, pos, STRAW, M.Grass)
	ball(ctx, "SheafTop", 1.3, pos + Vector3.new(0, 2.5, 0), C.wheat, M.Grass)
end

-- Ore cart on rails: cf on the rail tops at the cart centre, rails along local Z. Tub, iron rim, two axles
-- (their ends read as wheels), dark ore with gold. 7 parts.
local function oreCart(ctx: Ctx, cf: CFrame)
	block(ctx, "OreCart", Vector3.new(2.2, 1.3, 2.9), cf * CFrame.new(0, 1.55, 0), C.woodDark, M.WoodPlanks)
	block(ctx, "OreCartRim", Vector3.new(2.45, 0.32, 3.15), cf * CFrame.new(0, 2.2, 0), C.iron, M.Metal)
	for _, sz in { -0.85, 0.85 } do
		cyl(ctx, "CartAxle", cf * CFrame.new(0, 0.55, sz), 2.6, 1.1, C.iron, M.Metal)
	end
	ball(ctx, "Ore", 1.5, (cf * CFrame.new(-0.35, 2.3, 0.45)).Position, ORE, M.Slate)
	ball(ctx, "GoldOre", 1.0, (cf * CFrame.new(0.45, 2.45, -0.5)).Position, C.gold, M.Metal)
	ball(ctx, "GoldOre", 0.8, (cf * CFrame.new(-0.45, 2.5, -0.7)).Position, C.gold, M.Metal)
end

-- Sheave (winding wheel) facing -Z: iron rim, timber web, hub. 3 parts.
local function sheave(ctx: Ctx, x: number, y: number, z: number, dia: number)
	disc(ctx, "Sheave", CFrame.new(x, y, z), dia, 0.4, C.iron, M.Metal)
	disc(ctx, "SheaveWeb", CFrame.new(x, y, z - 0.12), dia * 0.72, 0.32, C.woodDark, M.Wood)
	disc(ctx, "SheaveHub", CFrame.new(x, y, z - 0.3), dia * 0.24, 0.5, C.iron, M.Metal)
end

-- Infirmary cot: plank frame, linen, a kingdom blanket over the foot. cf on the floor, head toward +Z. 3 parts.
local function cot(ctx: Ctx, cf: CFrame, color: Color3)
	block(ctx, "Cot", Vector3.new(2.1, 1.0, 3.8), cf * CFrame.new(0, 0.5, 0), C.wood, M.WoodPlanks)
	block(ctx, "CotLinen", Vector3.new(1.9, 0.3, 3.6), cf * CFrame.new(0, 1.15, 0.02), LINEN, M.Fabric)
	block(
		ctx,
		"CotBlanket",
		Vector3.new(2.0, 0.34, 2.2),
		cf * CFrame.new(0, 1.2, -0.75),
		shade(color, 0.78),
		M.Fabric,
		0.78
	)
end

-- Market stall: counter, four posts, a three-stripe canopy (kingdom, linen, kingdom) sloping to the front
-- and two goods. cf on the paving at the stall centre, counter toward local -Z. 10 parts.
local function marketStall(ctx: Ctx, cf: CFrame, color: Color3, goods: number)
	block(ctx, "StallCounter", Vector3.new(4.2, 1.3, 1.2), cf * CFrame.new(0, 0.68, -1.0), C.woodLight, M.WoodPlanks)
	for _, sx in { -2.0, 2.0 } do
		block(ctx, "StallPost", Vector3.new(0.36, 4.6, 0.36), cf * CFrame.new(sx, 2.3, -1.55), C.wood, M.Wood)
		block(ctx, "StallPost", Vector3.new(0.36, 5.6, 0.36), cf * CFrame.new(sx, 2.8, 1.35), C.wood, M.Wood)
	end
	local slope = math.atan2(1.0, 2.9)
	for i = -1, 1 do
		local kingdom = i ~= 0
		block(
			ctx,
			"Canopy",
			Vector3.new(1.55, 0.24, 3.75),
			cf * CFrame.new(i * 1.5, 5.15, -0.1) * CFrame.Angles(-slope, 0, 0),
			if kingdom then color else LINEN,
			M.Fabric,
			if kingdom then 1 else nil
		)
	end
	local top = cf * CFrame.new(0, 1.3, -1.0)
	if goods == 1 then -- produce: a tray of apples and a basket of greens
		block(ctx, "ProduceTray", Vector3.new(1.9, 0.4, 0.95), top * CFrame.new(-0.9, 0.2, 0), C.woodDark, M.WoodPlanks)
		ball(ctx, "Produce", 1.15, (top * CFrame.new(1.0, 0.5, 0)).Position, PRODUCE[3], M.Grass)
		ball(ctx, "Produce", 0.95, (top * CFrame.new(-0.9, 0.75, 0)).Position, PRODUCE[1], M.SmoothPlastic)
	elseif goods == 2 then -- cloth bolts
		for k = 0, 1 do
			cyl(ctx, "ClothBolt", top * CFrame.new(-0.9 + k * 1.8, 0.4, 0), 1.6, 0.8, CLOTHS[k + 1], M.Fabric)
		end
	elseif goods == 3 then -- pottery
		column(ctx, "Pot", 0.45, 0.9, (top * CFrame.new(-1.0, 0, 0)).Position, Color3.fromRGB(184, 98, 64), M.Slate)
		ball(ctx, "Pot", 1.1, (top * CFrame.new(0.9, 0.5, 0)).Position, Color3.fromRGB(196, 122, 80), M.Slate)
	else -- grain and spice
		burlapSack(ctx, top * CFrame.new(-0.9, 0, 0), 1.1)
		ball(ctx, "Spice", 1.0, (top * CFrame.new(0.9, 0.42, 0)).Position, PRODUCE[4], M.Sand)
	end
end

-- Mine: a cliff-faced crag of cool dark rock (sloped flanks, crags, crevices, a moss cap) with a timbered adit
-- under a kingdom hood and a crest carrying the kingdom cap, rails and an ore cart with gold, a rubble spoil
-- heap. The hero is the shaft head, growing every level with its wheel always the highest thing: L1 a timber
-- A-frame, L2 a four-post headframe, L3 a taller one beside a stone winding house under the kingdom cap. The
-- kingdom plate hangs on the headframe (L1–L2) or the winding house (L3).
BUILDERS.mine = function(ctx, level, color, style, fp)
	local lv = math.clamp(level, 1, 3)
	local hz = fp.Y / 2
	local S = stoneFor(style)
	local hh = ({ 9, 11.5, 13.5 })[lv]
	-- the crag: a cliff-faced core with sloped flanks, crags breaking the skyline, crevices, moss, boulders
	local hcx, hcz, hcw, hcd = -2.6, 6.6, 8.0, 6.2
	local core = CFrame.new(hcx, hh / 2, hcz) * CFrame.Angles(0, rad(3), 0)
	block(ctx, "Rock", Vector3.new(hcw, hh, hcd), core, MINE_ROCK[2], M.Rock)
	for _, side in { -1, 1 } do
		local run = if side < 0 then 3.3 else 2.9
		wedge(
			ctx,
			"RockSlope",
			Vector3.new(hcd - 0.4, hh * 0.86, run),
			CFrame.new(hcx + side * (hcw / 2 + run / 2 - 0.1), hh * 0.43, hcz + 0.1)
				* CFrame.Angles(0, -side * PI / 2, 0),
			MINE_ROCK[if side < 0 then 1 else 3],
			M.Rock
		)
	end
	for i, c in { { -1.9, 0.6, 3.8, 0.3, 3.2, 24, 5 }, { 1.6, -0.4, 2.6, 0.2, 2.6, -18, -4 } } do
		local ch = hh * c[4]
		block(
			ctx,
			"Crag",
			Vector3.new(c[3], ch, c[5]),
			core * CFrame.new(c[1], hh / 2 + ch / 2 - 0.4, c[2]) * CFrame.Angles(rad(c[7]), rad(c[6]), rad(jit(i, 4))),
			MINE_ROCK[if i == 1 then 1 else 3],
			M.Rock
		)
	end
	for _, c in { { -3.45, 0.62, 4 }, { 3.4, 0.5, -6 } } do
		block(
			ctx,
			"Crevice",
			Vector3.new(0.5, hh * c[2], 0.3),
			core * CFrame.new(c[1], -hh / 2 + hh * c[2] / 2 + 0.6, -hcd / 2 - 0.1) * CFrame.Angles(0, 0, rad(c[3])),
			CREVICE,
			M.Slate
		)
	end
	block(ctx, "Moss", Vector3.new(5.6, 0.7, 4.6), core * CFrame.new(0.8, hh / 2 + 0.1, 0.6), C.leaf, M.Grass)
	for i, b in { { -8.3, 2.0, 3.6, 0.42, 3.0, 28 }, { 2.7, 2.3, 2.8, 0.5, 2.4, -22 } } do
		local bh = hh * b[4]
		block(
			ctx,
			"Boulder",
			Vector3.new(b[3], bh, b[5]),
			CFrame.new(b[1], bh / 2 + 0.1, b[2]) * CFrame.Angles(rad(jit(i * 3, 3)), rad(b[6]), rad(jit(i * 5, 3))),
			MINE_ROCK[i],
			M.Rock
		)
	end
	-- adit: dark mouth, two posts and a cap beam, a kingdom hood, the crest with the kingdom cap
	local ax, zf = hcx, hcz - hcd / 2 - 0.2
	block(ctx, "AditMouth", Vector3.new(4.4, 6.0, 1.3), CFrame.new(ax, 3.0, zf + 0.6), ADIT, M.Slate)
	for _, sx in { -1, 1 } do
		block(ctx, "AditPost", Vector3.new(0.8, 6.2, 0.8), CFrame.new(ax + sx * 2.6, 3.1, zf - 0.3), C.timber, M.Wood)
	end
	block(ctx, "AditCap", Vector3.new(6.8, 0.9, 1.0), CFrame.new(ax, 6.65, zf - 0.3), C.timber, M.Wood)
	leanTo(ctx, CFrame.new(ax, 8.6, zf + 0.7), 7.6, 2.8, 1.2, color, 0.85, 2)
	block(ctx, "PortalCrest", Vector3.new(1.8, 1.8, 1.4), CFrame.new(ax, 9.0, zf - 0.5), C.timber, M.Wood)
	smallCap(ctx, style, 1.8, 9.9, color, ax, zf - 0.5)
	-- rails from the mouth to the front edge on sleepers, the ore cart (L2+: a second one at the mouth)
	local rz0, rz1 = zf - 0.1, -hz + 0.25
	for _, sx in { -1.05, 1.05 } do
		block(
			ctx,
			"Rail",
			Vector3.new(0.3, 0.25, rz0 - rz1),
			CFrame.new(ax + sx, 0.375, (rz0 + rz1) / 2),
			C.iron,
			M.Metal
		)
	end
	for i = 0, 3 do
		block(
			ctx,
			"Sleeper",
			Vector3.new(2.8, 0.25, 0.6),
			CFrame.new(ax, 0.125, zf - 1.3 - i * 2.9),
			C.woodDark,
			M.Wood
		)
	end
	oreCart(ctx, CFrame.new(ax, 0.5, -4.8))
	if lv >= 2 then
		oreCart(ctx, CFrame.new(ax, 0.5, zf - 1.15))
	end
	-- spoil heap: irregular wedge rubble (front right), growing with the level
	local sk = ({ 1, 1.12, 1.24 })[lv]
	local sp = Vector3.new(6.2, 0, -5.6)
	wedge(
		ctx,
		"Spoil",
		Vector3.new(5.0 * sk, 2.4 * sk, 2.6 * sk),
		CFrame.new(sp + Vector3.new(0, 1.2 * sk, -1.3 * sk)) * CFrame.Angles(0, rad(8), 0),
		SPOIL,
		M.Ground
	)
	wedge(
		ctx,
		"Spoil",
		Vector3.new(4.4 * sk, 2.4 * sk, 2.4 * sk),
		CFrame.new(sp + Vector3.new(0.3 * sk, 1.2 * sk, 1.2 * sk)) * CFrame.Angles(0, rad(188), 0),
		shade(SPOIL, 0.9),
		M.Ground
	)
	wedge(
		ctx,
		"Spoil",
		Vector3.new(2.6 * sk, 1.6 * sk, 2.2 * sk),
		CFrame.new(sp + Vector3.new(2.3 * sk, 0.8 * sk, 0.2 * sk)) * CFrame.Angles(0, rad(-82), 0),
		shade(SPOIL, 0.95),
		M.Ground
	)
	block(
		ctx,
		"SpoilRock",
		Vector3.new(1.5, 1.1, 1.3),
		CFrame.new(sp + Vector3.new(-2.6 * sk, 0.6, -1.4 * sk)) * CFrame.Angles(0, rad(30), rad(8)),
		ORE,
		M.Rock
	)
	if lv <= 2 then
		logStack(ctx, CFrame.new(-7.6, 0, -3.8), 4.2, 1, 0.5) -- pit props
	end
	-- the shaft head
	local gx, gz = 7.1, 5.4
	block(ctx, "ShaftCollar", Vector3.new(4.6, 0.6, 4.6), CFrame.new(gx, 0.3, gz), C.timber, M.Wood)
	block(ctx, "ShaftMouth", Vector3.new(3.0, 0.64, 3.0), CFrame.new(gx, 0.32, gz), ADIT, M.Slate)
	local plateCF: CFrame
	if lv == 1 then
		-- a timber A-frame (two A's, the wheel between their apexes)
		local H = 8.4
		for _, sz in { -1.0, 1.0 } do
			for _, sx in { -1, 1 } do
				strut(
					ctx,
					"HeadframeLeg",
					CFrame.new(0, 0, gz + sz),
					gx + sx * 2.0,
					0.6,
					gx + sx * 0.3,
					H + 0.3,
					0.55,
					0.55,
					C.timber
				)
			end
		end
		block(ctx, "HeadframeTie", Vector3.new(3.4, 0.5, 0.5), CFrame.new(gx, 3.4, gz - 1.0), C.timber, M.Wood)
		sheave(ctx, gx, H, gz + 0.2, 3.0)
		block(
			ctx,
			"HoistRope",
			Vector3.new(0.25, H - 2.4, 0.25),
			CFrame.new(gx + 1.4, H / 2 + 1.2, gz + 0.2),
			C.canvas,
			M.Fabric
		)
		column(ctx, "Kibble", 0.6, 1.1, Vector3.new(gx + 1.4, 1.0, gz + 0.2), C.woodDark, M.WoodPlanks)
		plateCF = CFrame.new(gx, 4.2, gz - 1.3)
	else
		-- a four-post headframe: girts, back-stays, a brace, the deck with the wheel (L3 taller, bigger wheel)
		local H = if lv == 2 then 14.6 else 17.6
		local dia = if lv == 2 then 3.6 else 4.4
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				block(
					ctx,
					"HeadframePost",
					Vector3.new(0.7, H, 0.7),
					CFrame.new(gx + sx * 1.9, 0.6 + H / 2, gz + sz * 1.9),
					C.timber,
					M.Wood
				)
			end
			block(
				ctx,
				"HeadframeGirt",
				Vector3.new(4.3, 0.5, 0.5),
				CFrame.new(gx, 0.6 + H * 0.52, gz + sx * 1.9),
				C.timber,
				M.Wood
			)
			strut(
				ctx,
				"BackStay",
				CFrame.new(gx + sx * 1.9, 0, 0) * CFrame.Angles(0, -PI / 2, 0),
				gz + 1.7,
				0.6 + H * 0.8,
				9.45,
				0.35,
				0.55,
				0.55,
				C.timber,
				M.Wood
			)
		end
		strut(ctx, "HeadframeBrace", CFrame.new(gx, 0, gz - 2.0), -1.9, 1.0, 1.9, 0.6 + H * 0.5, 0.45, 0.4, C.timber)
		local deck = 0.6 + H + 0.6
		block(
			ctx,
			"HeadframeDeck",
			Vector3.new(4.9, 0.6, 4.9),
			CFrame.new(gx, deck - 0.3, gz),
			C.woodDark,
			M.WoodPlanks
		)
		local wy = deck + dia / 2 + 0.2
		block(
			ctx,
			"SheavePost",
			Vector3.new(0.5, wy - deck, 0.5),
			CFrame.new(gx, (deck + wy) / 2, gz + 0.55),
			C.timber,
			M.Wood
		)
		sheave(ctx, gx, wy, gz, dia)
		block(
			ctx,
			"HoistRope",
			Vector3.new(0.25, wy - 3.2, 0.25),
			CFrame.new(gx - dia / 2 + 0.2, (wy + 3.2) / 2, gz - 0.1),
			C.canvas,
			M.Fabric
		)
		column(ctx, "Kibble", 0.6, 1.1, Vector3.new(gx - dia / 2 + 0.2, 2.1, gz - 0.1), C.woodDark, M.WoodPlanks)
		plateCF = CFrame.new(gx, 0.6 + H * 0.52, gz - 2.27)
		if lv >= 3 then
			-- the stone winding house with the kingdom cap, below the wheel; the plate moves to its front
			local wx, wz, ww, wh = 7.4, 0.0, 4.2, 6.4
			block(ctx, "WindingHouse", Vector3.new(ww, wh, ww), CFrame.new(wx, wh / 2, wz), S.base, M.Cobblestone)
			quoins(ctx, ww, ww, 0, wh, S.light, 2, wx, wz)
			smallCap(ctx, style, 3.4, wh, color, wx, wz)
			plateCF = CFrame.new(wx, 3.3, wz - ww / 2 - 0.16)
		end
	end
	emblemPlate(ctx, plateCF, color)
	attach(ctx, "Door", Vector3.new(ax, 0, -hz - 1.5))
	attach(ctx, "DropOff", Vector3.new(ax + 3.8, 0, -hz + 0.8))
	workSpots(ctx, {
		Vector3.new(ax - 1.9, 0, zf - 1.8),
		Vector3.new(ax + 2.6, 0, -4.8),
		Vector3.new(gx - 3.4, 0, gz - 2.6),
	})
end

-- Blacksmith: the forge is the hero, open to the street: a timber forge shed with a kingdom gable roof (the
-- kingdom plate in its gable), the stone hearth with a glowing ember bed and the flame prop (≥ 3 × 2 studs of
-- fire), a hood and a chimney with smoke, bellows, the anvil on its stump and the quench tub out in front, a
-- hanging trade sign with an anvil glyph. Behind it on the left a small sooty stone smithy with a kingdom roof
-- and a smoke louvre under the kingdom cap. Levels follow the trade: L1 weapons (a weapon rack); L2 armour (a
-- second storey, an armour stand, shields on the rack); L3 siege tools (an armoury turret under the kingdom cap
-- replacing the louvre's, a catapult in the yard).
BUILDERS.blacksmith = function(ctx, level, color, style, fp)
	local lv = math.clamp(level, 1, 3)
	local hx, hz = fp.X / 2, fp.Y / 2
	local S = stoneFor(style)
	local soot = shade(S.base, 0.86)
	-- the smithy
	local w, d = 7.6, 6.4
	local bx, bz = -6.2, 4.2
	local pl = 0.6
	local h = if lv == 1 then 7.0 else 12.6
	block(ctx, "Plinth", Vector3.new(w + 0.6, pl, d + 0.6), CFrame.new(bx, pl / 2, bz), S.dark, M.Cobblestone)
	block(ctx, "Walls", Vector3.new(w, h, d), CFrame.new(bx, pl + h / 2, bz), soot, M.Cobblestone)
	local fzw = bz - d / 2
	block(
		ctx,
		"SmithyDoor",
		Vector3.new(2.4, 5.0, 0.3),
		CFrame.new(bx + 1.8, pl + 2.53, fzw - 0.1),
		shade(color, 0.72),
		M.WoodPlanks,
		0.72
	)
	block(ctx, "DoorLintel", Vector3.new(3.2, 0.5, 0.5), CFrame.new(bx + 1.8, pl + 5.25, fzw - 0.15), S.light, M.Slate)
	windowAt(ctx, CFrame.new(bx - 1.9, pl + 2.4, fzw), { w = 1.6, h = 2.6, shutters = color })
	if lv >= 2 then
		block(ctx, "StringCourse", Vector3.new(w + 0.6, 0.6, d + 0.6), CFrame.new(bx, pl + 6.9, bz), S.light, M.Slate)
		for _, u in { -1.9, 1.9 } do
			windowAt(ctx, CFrame.new(bx + u, pl + 8.3, fzw), { w = 1.6, h = 2.6, simple = true })
		end
	end
	local info = tileRoof(ctx, {
		w = w,
		d = d,
		y = pl + h,
		rise = d / 2 * 0.95,
		cf = CFrame.new(bx, 0, bz),
		over = 1.0,
		gable = 0.6,
		rows = 2,
		color = color,
		tint = 0.88,
		infill = soot,
		infillMaterial = M.Cobblestone,
	})
	if lv <= 2 then
		block(ctx, "Louvre", Vector3.new(1.8, 1.4, 1.8), CFrame.new(bx, info.ridgeY + 0.2, bz), C.wood, M.WoodPlanks)
		smallCap(ctx, style, 1.8, info.ridgeY + 0.9, color, bx, bz)
	end
	-- the forge shed: four posts, the front tie beam, a plank back wall, a kingdom gable roof facing the street
	local sx0, sx1 = 1.2, 9.7
	local fz0, fz1 = -2.6, 5.4
	local fx, fzc = (sx0 + sx1) / 2, (fz0 + fz1) / 2
	local sw, sd = sx1 - sx0, fz1 - fz0
	local ph = 7.0
	for _, px in { sx0 + 0.3, sx1 - 0.3 } do
		for _, pz in { fz0 + 0.3, fz1 - 0.3 } do
			block(ctx, "ShedPost", Vector3.new(0.6, ph, 0.6), CFrame.new(px, ph / 2, pz), C.timber, M.Wood)
		end
	end
	block(ctx, "ShedBeam", Vector3.new(sw - 0.2, 0.6, 0.5), CFrame.new(fx, ph + 0.3, fz0 + 0.3), C.timber, M.Wood)
	block(ctx, "ShedBackWall", Vector3.new(sw - 1.4, ph, 0.4), CFrame.new(fx, ph / 2, fz1 - 0.3), C.wood, M.WoodPlanks)
	tileRoof(ctx, {
		w = sd,
		d = sw,
		y = ph + 0.6,
		rise = sw / 2 * 0.8,
		cf = CFrame.new(fx, 0, fzc) * CFrame.Angles(0, PI / 2, 0),
		over = 0.8,
		gable = 0.6,
		rows = 2,
		color = color,
		tint = 0.88,
		infill = C.woodDark,
		infillMaterial = M.WoodPlanks,
	})
	emblemPlate(ctx, CFrame.new(fx, ph + 0.7, fz0 - 0.02), color, 3.0)
	-- the hearth: stone, a glowing ember bed and two flames, the hood, the chimney with its smoke
	local hgx, hgz = fx - 0.4, fzc + 1.1
	local T = ({ 15, 17.5, 19 })[lv]
	block(ctx, "Hearth", Vector3.new(4.2, 2.4, 2.6), CFrame.new(hgx, 1.2, hgz), S.dark, M.Cobblestone)
	block(ctx, "Embers", Vector3.new(3.4, 0.4, 2.0), CFrame.new(hgx, 2.5, hgz - 0.1), EMBER, M.Neon)
	flame(ctx, Vector3.new(hgx - 0.8, 2.6, hgz - 0.25), 1.35)
	flame(ctx, Vector3.new(hgx + 0.9, 2.6, hgz + 0.05), 1.1)
	wedge(ctx, "ForgeHood", Vector3.new(4.0, 2.0, 2.4), CFrame.new(hgx, 5.6, hgz + 0.1), S.base, M.Cobblestone)
	block(
		ctx,
		"Chimney",
		Vector3.new(2.2, T - 6.58, 2.0),
		CFrame.new(hgx, (T + 6.58) / 2, hgz + 0.3),
		soot,
		M.Cobblestone
	)
	block(ctx, "ChimneyBand", Vector3.new(2.7, 0.45, 2.5), CFrame.new(hgx, T - 1, hgz + 0.3), S.light, M.Slate)
	block(ctx, "ChimneyCap", Vector3.new(2.9, 0.5, 2.7), CFrame.new(hgx, T + 0.25, hgz + 0.3), S.dark, M.Slate)
	smoke(ctx, Vector3.new(hgx, T + 0.5, hgz + 0.3))
	block(ctx, "BellowsStand", Vector3.new(1.2, 1.4, 1.0), CFrame.new(hgx + 3.0, 0.7, hgz), C.woodDark, M.Wood)
	wedge(
		ctx,
		"Bellows",
		Vector3.new(1.0, 0.9, 2.2),
		CFrame.new(hgx + 3.0, 1.85, hgz) * CFrame.Angles(0, PI / 2, 0),
		LEATHER,
		M.Fabric
	)
	-- the anvil on its stump and the quench tub out in front of the forge
	local an = Vector3.new(fx - 0.8, 0, fz0 - 2.0)
	column(ctx, "AnvilStump", 0.9, 1.3, an, C.bark, M.Wood)
	block(ctx, "AnvilWaist", Vector3.new(0.8, 0.45, 0.55), CFrame.new(an + Vector3.new(0, 1.52, 0)), C.iron, M.Metal)
	block(ctx, "Anvil", Vector3.new(2.2, 0.65, 0.85), CFrame.new(an + Vector3.new(0.2, 2.07, 0)), C.iron, M.Metal)
	wedge(
		ctx,
		"AnvilHorn",
		Vector3.new(0.85, 0.65, 0.9),
		CFrame.new(an + Vector3.new(-1.35, 2.07, 0)) * CFrame.Angles(0, PI / 2, 0),
		C.iron,
		M.Metal
	)
	local qt = Vector3.new(fx + 3.0, 0, fz0 - 2.2)
	column(ctx, "QuenchTub", 1.0, 1.3, qt, C.wood, M.WoodPlanks)
	disc(
		ctx,
		"Water",
		CFrame.new(qt + Vector3.new(0, 1.26, 0)) * CFrame.Angles(PI / 2, 0, 0),
		1.8,
		0.05,
		WATER,
		M.Glass
	)
	-- the hanging trade sign with an iron anvil glyph, on an arm from the shed's front-left post
	local sg = CFrame.new(sx0 + 0.3, 4.9, fz0 - 1.6)
	block(ctx, "SignArm", Vector3.new(0.3, 0.3, 2.0), CFrame.new(sx0 + 0.3, 6.25, fz0 - 0.75), C.iron, M.Metal)
	block(ctx, "TradeSign", Vector3.new(3.2, 2.4, 0.25), sg, C.woodLight, M.WoodPlanks)
	block(ctx, "SignAnvil", Vector3.new(1.7, 0.5, 0.12), sg * CFrame.new(0.15, 0.35, -0.18), GLYPH_IRON, M.Metal)
	wedge(
		ctx,
		"SignAnvilHorn",
		Vector3.new(0.12, 0.5, 0.7),
		sg * CFrame.new(-1.05, 0.35, -0.19) * CFrame.Angles(0, PI / 2, 0),
		GLYPH_IRON,
		M.Metal
	)
	block(ctx, "SignAnvilWaist", Vector3.new(0.5, 0.42, 0.12), sg * CFrame.new(0.15, -0.11, -0.2), GLYPH_IRON, M.Metal)
	block(ctx, "SignAnvilBase", Vector3.new(1.2, 0.34, 0.12), sg * CFrame.new(0.15, -0.49, -0.21), GLYPH_IRON, M.Metal)
	-- the weapon rack in the yard (L2: shields hung on it), the L2 armour stand
	local rx, rz = bx + 0.8, fzw - 2.6
	for _, px in { -1.9, 1.9 } do
		block(ctx, "RackPost", Vector3.new(0.4, 3.4, 0.4), CFrame.new(rx + px, 1.7, rz), C.timber, M.Wood)
	end
	block(ctx, "Rack", Vector3.new(4.0, 0.35, 0.36), CFrame.new(rx, 3.0, rz), C.wood, M.Wood)
	for i, wpn in { { -1.2, 5.0, C.wood }, { -0.4, 5.0, C.wood }, { 0.5, 3.0, STEEL } } do
		block(
			ctx,
			if i == 3 then "Sword" else "Spear",
			Vector3.new(if i == 3 then 0.3 else 0.25, wpn[2], 0.25),
			CFrame.new(rx + wpn[1], wpn[2] / 2 - 0.05, rz - 0.4) * CFrame.Angles(rad(-9), 0, 0),
			wpn[3],
			M.Metal
		)
	end
	block(
		ctx,
		"AxeHead",
		Vector3.new(0.9, 0.7, 0.25),
		CFrame.new(rx + 1.35, 3.2, rz - 0.45) * CFrame.Angles(rad(-9), 0, 0),
		STEEL,
		M.Metal
	)
	if lv >= 2 then
		for _, sx in { -1, 1 } do
			disc(
				ctx,
				"RackShield",
				CFrame.new(rx + sx * 1.0, 1.7, rz + 0.35) * CFrame.Angles(rad(-8), 0, 0),
				1.7,
				0.3,
				shade(color, 0.85),
				M.Wood,
				0.85
			)
		end
		local ap = Vector3.new(bx - 3.0, 0, fzw - 2.2)
		column(ctx, "ArmourPost", 0.16, 4.3, ap, C.woodDark, M.Wood)
		block(ctx, "Breastplate", Vector3.new(1.7, 1.9, 0.9), CFrame.new(ap + Vector3.new(0, 3.3, 0)), STEEL, M.Metal)
		ball(ctx, "Helm", 1.05, ap + Vector3.new(0, 4.75, 0), STEEL, M.Metal)
	end
	if lv >= 3 then
		-- the armoury turret on the smithy's back-left corner with the kingdom cap
		local tr = 2.2
		local tx, tz = -hx + 3.4, bz + 1.4
		local top = roundTower(ctx, tx, tz, pl, tr, 20, S)
		smallCap(ctx, style, tr * 2, top, color, tx, tz)
		-- the catapult (siege tools): wheeled frame, A-frame and bar, the throwing arm with a stone
		local cx, cz = bx + 0.4, -hz + 2.6
		for _, sz in { -1, 1 } do
			block(ctx, "CatapultRail", Vector3.new(6.0, 0.6, 0.6), CFrame.new(cx, 1.3, cz + sz * 1.2), C.wood, M.Wood)
			for _, sx in { -1, 1 } do
				disc(
					ctx,
					"CatapultWheel",
					CFrame.new(cx + sx * 2.1, 0.9, cz + sz * 1.68),
					1.8,
					0.35,
					C.woodDark,
					M.Wood
				)
			end
			block(
				ctx,
				"CatapultUpright",
				Vector3.new(0.5, 3.4, 0.5),
				CFrame.new(cx + 0.9, 3.3, cz + sz * 1.2),
				C.wood,
				M.Wood
			)
		end
		block(ctx, "CatapultBar", Vector3.new(0.6, 0.5, 2.8), CFrame.new(cx + 0.9, 4.95, cz), C.wood, M.Wood)
		strut(ctx, "CatapultArm", CFrame.new(0, 0, cz), cx - 2.4, 1.8, cx + 1.7, 5.6, 0.45, 0.45, C.woodLight)
		ball(ctx, "CatapultStone", 1.1, Vector3.new(cx + 1.75, 6.15, cz), C.stoneLight, M.Slate)
	end
	attach(ctx, "Door", Vector3.new(fx, 0, -hz - 1.5))
	workSpots(ctx, {
		Vector3.new(an.X - 1.6, 0, an.Z - 0.4),
		Vector3.new(hgx - 2.6, 0, hgz - 2.0),
		Vector3.new(rx, 0, rz - 1.6),
	})
end

-- Market: a paved square with striped kingdom canopies over the stalls (they read from the aerial camera), a
-- well with a kingdom roof, a hand cart and goods. L1 the merchant's counting booth: serving hatch with a kingdom
-- awning and the money chest, its front gable carrying the kingdom plate, a louvre with the kingdom cap on the
-- ridge. L2 a market hall in its place: an open arcade with the trading table and chest under a jettied timber
-- storey with shutters and a large kingdom banner, a bell turret with the kingdom cap, and a fourth stall.
BUILDERS.market = function(ctx, level, color, style, fp)
	local lv = math.clamp(level, 1, 2)
	local hz = fp.Y / 2
	local S = stoneFor(style)
	local py = 0.2
	block(ctx, "Paving", Vector3.new(fp.X - 0.8, py, fp.Y - 0.8), CFrame.new(0, py / 2, 0), C.stoneLight, M.Cobblestone)
	local merchant: Vector3
	if lv == 1 then
		local bw, bd, bz = 9.4, 5.4, hz - 4.6
		block(ctx, "Plinth", Vector3.new(bw + 0.6, 0.6, bd + 0.6), CFrame.new(0, py + 0.3, bz), S.dark, M.Cobblestone)
		local y0 = py + 0.6
		local h = 7.4
		timberBox(ctx, bw, bd, y0, h, PLASTERS[2], 0, bz)
		local fzb = bz - bd / 2
		block(ctx, "Hatch", Vector3.new(4.6, 2.6, 0.3), CFrame.new(-1.2, y0 + 3.5, fzb - 0.1), ADIT, M.Wood)
		block(
			ctx,
			"HatchCounter",
			Vector3.new(5.4, 0.4, 1.2),
			CFrame.new(-1.2, y0 + 2.1, fzb - 0.6),
			C.woodLight,
			M.WoodPlanks
		)
		block(
			ctx,
			"HatchAwning",
			Vector3.new(5.4, 0.26, 2.3),
			CFrame.new(-1.2, y0 + 4.95, fzb - 1.05) * CFrame.Angles(rad(-18), 0, 0),
			shade(color, 0.85),
			M.WoodPlanks,
			0.85
		)
		block(
			ctx,
			"BoothDoor",
			Vector3.new(2.2, 5.4, 0.3),
			CFrame.new(3.2, y0 + 2.7, fzb - 0.1),
			shade(color, 0.72),
			M.WoodPlanks,
			0.72
		)
		-- the money chest on the counter: trade for gold
		block(ctx, "Chest", Vector3.new(1.3, 0.8, 0.8), CFrame.new(-2.7, y0 + 2.7, fzb - 0.6), C.woodDark, M.WoodPlanks)
		block(ctx, "ChestBand", Vector3.new(1.36, 0.25, 0.86), CFrame.new(-2.7, y0 + 2.75, fzb - 0.6), C.gold, M.Metal)
		-- the roof turns its gable to the square: the kingdom plate in it, the louvre and cap on the ridge
		local info = tileRoof(ctx, {
			w = bd,
			d = bw,
			y = y0 + h,
			rise = bw / 2 * 0.72,
			cf = CFrame.new(0, 0, bz) * CFrame.Angles(0, PI / 2, 0),
			over = 0.9,
			gable = 0.7,
			rows = 2,
			color = color,
			tint = 0.88,
			infill = PLASTERS[2],
			infillMaterial = M.Plaster,
		})
		emblemPlate(ctx, CFrame.new(0, y0 + h + 0.15, fzb - 0.26), color)
		block(ctx, "Louvre", Vector3.new(1.6, 1.3, 1.6), CFrame.new(0, info.ridgeY + 0.15, bz), C.wood, M.WoodPlanks)
		smallCap(ctx, style, 1.6, info.ridgeY + 0.8, color, 0, bz)
		merchant = Vector3.new(-1.2, 0, fzb - 2.0)
	else
		local hw, hd, bz = 15, 7, hz - 5.1
		local gh = 7.2
		local fzh = bz - hd / 2
		-- the closed back half (stores) behind the open arcade, four arcade posts carrying the storey
		block(
			ctx,
			"HallStore",
			Vector3.new(hw - 0.8, gh, hd * 0.45),
			CFrame.new(0, py + gh / 2, bz + hd * 0.25),
			S.base,
			M.Cobblestone
		)
		for _, px in { -7.1, -2.4, 2.4, 7.1 } do
			block(
				ctx,
				"ArcadePost",
				Vector3.new(0.7, gh, 0.7),
				CFrame.new(px, py + gh / 2, fzh + 0.4),
				C.timber,
				M.Wood
			)
		end
		local y2 = py + gh
		local h2 = 6.6
		block(ctx, "JettyBeam", Vector3.new(hw + 0.8, 0.7, hd + 0.3), CFrame.new(0, y2 + 0.05, bz), C.timber, M.Wood)
		timberBox(ctx, hw, hd, y2, h2, PLASTERS[2], 0, bz)
		local f2 = wallFrames(hw, hd, y2, 0, bz)
		for _, u in { -4.9, 4.9 } do
			windowAt(ctx, f2.front * CFrame.new(u, 2.0, 0), { w = 2.0, h = 3.0, shutters = color })
		end
		frameWall(ctx, f2.front, hw, h2, { { u = -4.9, hw = 1.6 }, { u = 4.9, hw = 1.6 }, { u = 0, hw = 2.3 } }, 1.6)
		banner(ctx, 0, y2 + h2 - 0.35, fzh - 0.05, 0, color, 4.6, style, 3.4)
		local info = tileRoof(ctx, {
			w = hw,
			d = hd,
			y = y2 + h2,
			rise = hd / 2 * 1.0,
			cf = CFrame.new(0, 0, bz),
			over = 1.1,
			gable = 0.8,
			color = color,
			tint = 0.88,
			infill = PLASTERS[2],
			kingPost = true,
		})
		-- bell turret astride the ridge: louvred base, the bell in a dark opening, the kingdom cap
		local tw = 3.2
		local t0 = y2 + h2 + hd / 2 * 0.45
		local t1 = info.ridgeY + 2.6
		block(ctx, "BellTurret", Vector3.new(tw, t1 - t0, tw), CFrame.new(0, (t0 + t1) / 2, bz), C.wood, M.WoodPlanks)
		block(ctx, "Belfry", Vector3.new(1.8, 1.6, 0.3), CFrame.new(0, t1 - 1.2, bz - tw / 2 - 0.1), ADIT, M.Slate)
		ball(ctx, "Bell", 1.1, Vector3.new(0, t1 - 1.3, bz - tw / 2 - 0.35), C.gold, M.Metal)
		smallCap(ctx, style, tw, t1, color, 0, bz)
		-- the merchant's table and goods under the arcade
		block(
			ctx,
			"TradeTable",
			Vector3.new(4.4, 1.3, 1.4),
			CFrame.new(-2.4 - 2.35, py + 0.65, fzh + 2.0),
			C.woodLight,
			M.WoodPlanks
		)
		block(ctx, "Chest", Vector3.new(1.3, 0.8, 0.8), CFrame.new(-5.6, py + 1.7, fzh + 2.0), C.woodDark, M.WoodPlanks)
		block(ctx, "ChestBand", Vector3.new(1.36, 0.25, 0.86), CFrame.new(-5.6, py + 1.75, fzh + 2.0), C.gold, M.Metal)
		barrel(ctx, Vector3.new(4.6, py, fzh + 2.2), 2.0)
		burlapSack(ctx, CFrame.new(6.2, py, fzh + 1.6) * CFrame.Angles(0, rad(15), 0), 1.6)
		merchant = Vector3.new(-4.75, 0, fzh - 0.4)
	end
	-- stalls round the square (L2 a fourth), the well in the middle, a hand cart and goods at the front
	local stalls = {
		{ -8.2, -4.6, 0, 1 },
		{ 8.2, -4.6, 0, 2 },
		{ -9.7, 2.2, -90, 3 },
	}
	if lv >= 2 then
		table.insert(stalls, { 9.7, 2.2, 90, 4 })
	end
	local spots = { merchant }
	for _, s in stalls do
		local scf = CFrame.new(s[1], py, s[2]) * CFrame.Angles(0, rad(s[3]), 0)
		marketStall(ctx, scf, color, s[4])
		table.insert(spots, (scf * CFrame.new(0, -py, -2.7)).Position)
	end
	local wz = -1.2
	column(ctx, "WellRing", 1.8, 1.7, Vector3.new(0, py, wz), C.stone, M.Cobblestone)
	disc(ctx, "WellWater", CFrame.new(0, py + 1.67, wz) * CFrame.Angles(PI / 2, 0, 0), 3.0, 0.05, WATER, M.Glass)
	for _, sx in { -1.6, 1.6 } do
		block(ctx, "WellPost", Vector3.new(0.36, 4.6, 0.36), CFrame.new(sx, py + 2.3, wz), C.wood, M.Wood)
	end
	block(ctx, "WellBeam", Vector3.new(3.6, 0.3, 0.3), CFrame.new(0, py + 4.1, wz), C.wood, M.Wood)
	for _, sz in { -1, 1 } do
		block(
			ctx,
			"WellRoof",
			Vector3.new(4.4, 0.3, 2.0),
			CFrame.new(0, py + 5.0, wz + sz * 0.78) * CFrame.Angles(sz * rad(32), 0, 0),
			shade(color, 0.85),
			M.WoodPlanks,
			0.85
		)
	end
	local cart = CFrame.new(4.4, py, -hz + 2.6) * CFrame.Angles(0, rad(-8), 0)
	block(ctx, "CartBed", Vector3.new(3.8, 1.0, 2.3), cart * CFrame.new(0, 1.55, 0), C.wood, M.WoodPlanks)
	for _, sz in { -1, 1 } do
		disc(ctx, "CartWheel", cart * CFrame.new(0.3, 1.1, sz * 1.3), 2.2, 0.3, C.woodDark, M.Wood)
	end
	ball(ctx, "Produce", 1.3, (cart * CFrame.new(-0.8, 2.35, 0)).Position, PRODUCE[2], M.SmoothPlastic)
	ball(ctx, "Produce", 1.2, (cart * CFrame.new(0.7, 2.3, 0.3)).Position, PRODUCE[1], M.SmoothPlastic)
	crate(ctx, CFrame.new(-4.4, py, -hz + 2.4) * CFrame.Angles(0, rad(12), 0), 1.8)
	burlapSack(ctx, CFrame.new(-2.8, py, -hz + 2.0) * CFrame.Angles(0, rad(-20), 0))
	attach(ctx, "Door", Vector3.new(0, 0, -hz - 1.5))
	workSpots(ctx, spots)
end

-- Infirmary: an open ward, not a house. A long low hall open to the front on posts, a low kingdom roof with a
-- roof lantern under the kingdom cap, a row of cots with linen and kingdom blankets in plain view, big herb
-- bundles hanging under the eaves, the kingdom plate on the centre posts; in front a walled herb garden with
-- raised beds, large white sheets on a line above its wall, and a healer's signpost with a flask glyph (not a
-- cross). L2 the ward is two open storeys: a gallery floor with a rail and three more cots.
BUILDERS.infirmary = function(ctx, level, color, style, fp)
	local lv = math.clamp(level, 1, 2)
	local hz = fp.Y / 2
	local w, d = 15.2, 6.6
	local bz = 2.4
	local fl = 0.5
	local h = if lv == 1 then 6.6 else 12.4
	local fz = bz - d / 2
	block(ctx, "WardFloor", Vector3.new(w + 0.6, fl, d + 0.6), CFrame.new(0, fl / 2, bz), C.stoneLight, M.Slate)
	-- back and side walls (plaster); the front stands open on posts under a tie beam
	block(ctx, "Walls", Vector3.new(w, h, 0.5), CFrame.new(0, fl + h / 2, bz + d / 2 - 0.25), PLASTERS[3], M.Plaster)
	local sz0, sz1 = fz + 0.6, bz + d / 2 - 0.5
	for _, sx in { -1, 1 } do
		block(
			ctx,
			"SideWall",
			Vector3.new(0.5, h, sz1 - sz0),
			CFrame.new(sx * (w / 2 - 0.25), fl + h / 2, (sz0 + sz1) / 2),
			PLASTERS[3],
			M.Plaster
		)
	end
	for _, px in { -7.3, -4.4, -1.5, 1.5, 4.4, 7.3 } do
		block(
			ctx,
			"WardPost",
			Vector3.new(0.6, h - 0.6, 0.6),
			CFrame.new(px, fl + (h - 0.6) / 2, fz + 0.3),
			C.timber,
			M.Wood
		)
	end
	block(ctx, "WardBeam", Vector3.new(w + 0.2, 0.6, 0.6), CFrame.new(0, fl + h - 0.3, fz + 0.3), C.timber, M.Wood)
	local info = tileRoof(ctx, {
		w = w,
		d = d,
		y = fl + h,
		rise = d / 2 * 0.6,
		cf = CFrame.new(0, 0, bz),
		over = 1.0,
		gable = 0.6,
		rows = 2,
		color = color,
		tint = 0.88,
		infill = PLASTERS[3],
		infillMaterial = M.Plaster,
	})
	block(ctx, "RoofLantern", Vector3.new(2.2, 1.4, 2.2), CFrame.new(0, info.ridgeY + 0.3, bz), C.wood, M.WoodPlanks)
	smallCap(ctx, style, 2.2, info.ridgeY + 1.0, color, 0, bz)
	-- the row of cots (head to the back wall); L2 a gallery floor with a rail and three more cots
	local cz = bz + d / 2 - 0.5 - 1.95
	for _, cx in { -5.8, -2.9, 2.9, 5.8 } do
		cot(ctx, CFrame.new(cx, fl, cz), color)
	end
	if lv >= 2 then
		local gy = fl + 6.2
		block(
			ctx,
			"GalleryFloor",
			Vector3.new(w - 0.6, 0.5, d - 0.4),
			CFrame.new(0, gy, bz - 0.05),
			C.woodDark,
			M.WoodPlanks
		)
		block(ctx, "GalleryRail", Vector3.new(w - 0.2, 0.4, 0.4), CFrame.new(0, gy + 1.6, fz + 0.3), C.timber, M.Wood)
		for _, cx in { -4.4, 0, 4.4 } do
			cot(ctx, CFrame.new(cx, gy + 0.25, cz), color)
		end
	end
	-- herb bundles under the eaves, the kingdom plate on the centre posts
	for i, bx in { -5.85, -2.95, 2.95, 5.85 } do
		block(
			ctx,
			"HerbBundle",
			Vector3.new(1.0, 1.8, 0.8),
			CFrame.new(bx, fl + h - 0.6 - 0.95, fz + 0.3),
			if i % 2 == 0 then C.leaf else C.leafLight,
			M.Grass
		)
	end
	emblemPlate(ctx, CFrame.new(0, fl + 4.15, fz), color)
	-- the walled herb garden with raised beds, the linen line above its wall
	local gx0, gx1, gz0, gz1 = -10.6, -3.6, -8.8, -3.4
	block(
		ctx,
		"GardenWall",
		Vector3.new(gx1 - gx0, 1.4, 0.6),
		CFrame.new((gx0 + gx1) / 2, 0.7, gz0 + 0.3),
		C.stone,
		M.Cobblestone
	)
	for _, x in { gx0 + 0.3, gx1 - 0.3 } do
		block(
			ctx,
			"GardenWall",
			Vector3.new(0.6, 1.4, gz1 - gz0 - 0.6),
			CFrame.new(x, 0.7, (gz0 + 0.6 + gz1) / 2),
			C.stone,
			M.Cobblestone
		)
	end
	for bi, bxx in { -8.6, -5.6 } do
		block(ctx, "RaisedBed", Vector3.new(2.4, 0.9, 3.6), CFrame.new(bxx, 0.45, -5.9), C.woodDark, M.WoodPlanks)
		for k = 0, 1 do
			ball(
				ctx,
				"Herb",
				1.4,
				Vector3.new(bxx, 1.45, -6.9 + k * 2.0),
				if (bi + k) % 2 == 0 then C.leafLight else HERB_PURPLE,
				M.Grass
			)
		end
	end
	for _, lx in { gx0 + 0.4, gx1 - 0.4 } do
		block(ctx, "LinePost", Vector3.new(0.4, 5.0, 0.4), CFrame.new(lx, 2.5, gz0 - 0.3), C.wood, M.Wood)
	end
	block(
		ctx,
		"Washline",
		Vector3.new(gx1 - gx0 - 0.8, 0.25, 0.25),
		CFrame.new((gx0 + gx1) / 2, 4.75, gz0 - 0.3),
		C.canvas,
		M.Fabric
	)
	for i, lx in { -8.6, -5.6 } do
		block(
			ctx,
			"Linen",
			Vector3.new(2.6, if i == 1 then 2.4 else 2.1, 0.12),
			CFrame.new(lx, 4.6 - (if i == 1 then 1.2 else 1.05), gz0 - 0.3),
			LINEN,
			M.Fabric
		)
	end
	-- the healer's signpost: a flask on linen
	local sp = Vector3.new(2.6, 0, -hz + 1.2)
	column(ctx, "SignPost", 0.2, 5.6, sp, C.woodDark, M.Wood)
	local hs = CFrame.new(sp + Vector3.new(0, 4.0, -0.33))
	block(ctx, "HealerSign", Vector3.new(3.2, 3.2, 0.25), hs, LINEN, M.WoodPlanks)
	disc(ctx, "SignFlask", hs * CFrame.new(0, -0.45, -0.17), 1.7, 0.12, FLASK, M.SmoothPlastic)
	block(ctx, "SignFlaskNeck", Vector3.new(0.5, 0.8, 0.12), hs * CFrame.new(0, 0.7, -0.17), FLASK, M.SmoothPlastic)
	block(ctx, "SignFlaskCork", Vector3.new(0.75, 0.32, 0.14), hs * CFrame.new(0, 1.2, -0.18), CORK, M.Wood)
	attach(ctx, "Door", Vector3.new(0, 0, -hz - 1.5))
	workSpots(ctx, {
		Vector3.new(-2.95, 0, fz - 1.0),
		Vector3.new(-7.1, 0, -4.2),
		Vector3.new(-7.1, 0, gz0 - 1.4),
	})
end

-- Granary dimensions per level (the builder and its construction stages share them): L1 a square tower granary,
-- L2 a barn granary wider than tall.
type GranaryDims = {
	gw: number,
	gd: number,
	cz: number,
	lift: number,
	h: number,
	nx: number,
	nz: number,
	over: number,
	cw: number,
}
local function granaryDims(level: number): GranaryDims
	if level >= 2 then
		return { gw = 13, gd = 8.4, cz = 1.4, lift = 2.6, h = 8.6, nx = 3, nz = 2, over = 1.25, cw = 2.4 }
	end
	return { gw = 8, gd = 8, cz = 1.0, lift = 2.6, h = 6.0, nx = 2, nz = 3, over = 1.25, cw = 1.8 }
end

-- Staddle stones (mushroom stones) under a granary. 2 parts each.
local function staddles(ctx: Ctx, g: GranaryDims)
	for ix = 0, g.nx - 1 do
		for iz = 0, g.nz - 1 do
			local p = Vector3.new(
				-g.gw / 2 + 1 + ix * (g.gw - 2) / (g.nx - 1),
				0,
				g.cz - g.gd / 2 + 1 + iz * (g.gd - 2) / (g.nz - 1)
			)
			column(ctx, "Staddle", 0.5, g.lift - 0.45, p, C.stone, M.Slate)
			column(ctx, "StaddleCap", 1.1, 0.45, p + Vector3.new(0, g.lift - 0.45, 0), C.stoneLight, M.Slate)
		end
	end
end

-- Granary: plank walls raised on staddle stones under a hipped kingdom roof with a low louvred vent cupola
-- carrying the kingdom cap; the door with a hoist beam over it and a sack on the rope, burlap sacks, wheat
-- sheaves, a hand cart, the kingdom plate on the front. L1 a square tower granary reached by a ladder; L2 a barn
-- granary wider than tall: a stone stair to the door, a loading door high in the front under its hoist arm,
-- kingdom vent shutters, more sacks.
BUILDERS.granary = function(ctx, level, color, style, fp)
	local lv = math.clamp(level, 1, 2)
	local hz = fp.Y / 2
	local g = granaryDims(lv)
	staddles(ctx, g)
	block(
		ctx,
		"Floor",
		Vector3.new(g.gw + 0.8, 0.6, g.gd + 0.8),
		CFrame.new(0, g.lift + 0.3, g.cz),
		C.timber,
		M.WoodPlanks
	)
	local y0 = g.lift + 0.6
	local top = y0 + g.h
	block(
		ctx,
		"Walls",
		Vector3.new(g.gw, g.h - 0.06, g.gd),
		CFrame.new(0, y0 + g.h / 2, g.cz),
		C.woodLight,
		M.WoodPlanks
	)
	block(ctx, "TopPlate", Vector3.new(g.gw + 0.5, 0.6, g.gd + 0.5), CFrame.new(0, top - 0.3, g.cz), C.timber, M.Wood)
	block(
		ctx,
		"MidRail",
		Vector3.new(g.gw + 0.3, 0.5, g.gd + 0.3),
		CFrame.new(0, y0 + g.h * 0.48, g.cz),
		C.timber,
		M.Wood
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(
				ctx,
				"CornerPost",
				Vector3.new(0.7, g.h - 0.04, 0.7),
				CFrame.new(sx * g.gw / 2, y0 + g.h / 2, g.cz + sz * g.gd / 2),
				C.timber,
				M.Wood
			)
		end
	end
	-- the hipped kingdom roof over a dark kingdom eave, the low louvred vent cupola with the kingdom cap
	block(
		ctx,
		"RoofEave",
		Vector3.new(g.gw + 0.9, 0.5, g.gd + 0.9),
		CFrame.new(0, top + 0.25, g.cz),
		shade(color, 0.6),
		M.Slate,
		0.6
	)
	local W, D = g.gw + 2 * g.over, g.gd + 2 * g.over
	local R = D * 0.48
	local ridge = hipRoof(ctx, W, D, R, top + 0.5, color, 0.88, 0, g.cz)
	local c0 = ridge - R * g.cw / D - 0.1
	local c1 = ridge + 0.9
	block(ctx, "Cupola", Vector3.new(g.cw, c1 - c0, g.cw), CFrame.new(0, (c0 + c1) / 2, g.cz), C.wood, M.WoodPlanks)
	for k = 0, 1 do
		block(
			ctx,
			"CupolaLouvre",
			Vector3.new(g.cw - 0.5, 0.25, 0.25),
			CFrame.new(0, c1 - 0.35 - k * 0.45, g.cz - g.cw / 2 - 0.1),
			ADIT,
			M.Slate
		)
	end
	smallCap(ctx, style, g.cw, c1, color, 0, g.cz)
	-- the front: the door and its lintel, the kingdom plate, the hoist over the loading door
	local fzg = g.cz - g.gd / 2
	local dx = if lv == 1 then -1.8 else -3.8
	block(
		ctx,
		"GranaryDoor",
		Vector3.new(2.2, 4.2, 0.3),
		CFrame.new(dx, y0 + 2.1, fzg - 0.1),
		shade(color, 0.72),
		M.WoodPlanks,
		0.72
	)
	block(ctx, "DoorLintel", Vector3.new(2.9, 0.5, 0.5), CFrame.new(dx, y0 + 4.45, fzg - 0.15), C.timber, M.Wood)
	emblemPlate(ctx, CFrame.new(if lv == 1 then 1.75 else -0.1, y0 + 3.2, fzg - 0.16), color)
	local hx2 = dx
	if lv >= 2 then
		hx2 = 3.6
		block(
			ctx,
			"LoadingDoor",
			Vector3.new(2.2, 2.6, 0.3),
			CFrame.new(hx2, y0 + 6.2, fzg - 0.1),
			shade(color, 0.72),
			M.WoodPlanks,
			0.72
		)
		for _, sx in { -1, 1 } do
			block(
				ctx,
				"VentShutter",
				Vector3.new(1.1, 1.3, 0.24),
				CFrame.new(sx * (g.gw / 2 - 1.2), y0 + g.h * 0.72, fzg - 0.12),
				shade(color, 0.85),
				M.WoodPlanks,
				0.85
			)
		end
	end
	block(ctx, "HoistBeam", Vector3.new(0.5, 0.5, 2.6), CFrame.new(hx2, top - 0.4, fzg - 1.0), C.timber, M.Wood)
	block(ctx, "HoistRope", Vector3.new(0.25, 2.2, 0.25), CFrame.new(hx2, top - 1.75, fzg - 2.0), C.canvas, M.Fabric)
	burlapSack(ctx, CFrame.new(hx2, top - 4.28, fzg - 2.0), 1.4)
	-- access: L1 a ladder to the door, L2 a stone stair along the wall to a landing
	if lv == 1 then
		local lz = fzg - 2.2
		for _, sx in { -0.65, 0.65 } do
			strut(
				ctx,
				"LadderRail",
				CFrame.new(dx + sx, 0, lz) * CFrame.Angles(0, PI / 2, 0),
				0,
				0,
				-1.95,
				y0 + 0.3,
				0.25,
				0.25,
				C.wood,
				M.Wood
			)
		end
		for i = 1, 2 do
			local t = i / 3
			block(
				ctx,
				"LadderRung",
				Vector3.new(1.3, 0.25, 0.25),
				CFrame.new(dx, t * (y0 + 0.3), lz + 1.95 * t),
				C.wood,
				M.Wood
			)
		end
	else
		block(
			ctx,
			"StairLanding",
			Vector3.new(2.2, y0 - 0.03, 1.7),
			CFrame.new(dx, (y0 - 0.03) / 2, fzg - 0.95),
			C.stone,
			M.Slate
		)
		wedge(
			ctx,
			"Stair",
			Vector3.new(1.7, y0 - 0.03, 2.4),
			CFrame.new(dx - 2.3, (y0 - 0.03) / 2, fzg - 0.95) * CFrame.Angles(0, PI / 2, 0),
			C.stoneLight,
			M.Slate
		)
	end
	-- burlap sacks and sheaves at the foot, a hand cart with sacks
	local sacks = { { -3.6, fzg - 2.4 }, { -4.7, fzg - 1.4 }, { 3.6, fzg - 2.6 } }
	if lv >= 2 then
		sacks = { { -6.4, fzg - 2.6 }, { 0.6, fzg - 2.2 }, { 1.8, fzg - 2.9 }, { -0.6, fzg - 3.0 } }
	end
	for i, s in sacks do
		burlapSack(ctx, CFrame.new(s[1], 0, s[2]) * CFrame.Angles(0, rad(i * 23 - 30), 0), if i == 2 then 1.4 else 1.7)
	end
	sheaf(ctx, Vector3.new(-5.6, 0, -hz + 1.6))
	sheaf(ctx, Vector3.new(-6.9, 0, -hz + 2.6))
	if lv >= 2 then
		sheaf(ctx, Vector3.new(-7.7, 0, -hz + 1.3))
	end
	local cart = CFrame.new(5.2, 0, -hz + 2.4) * CFrame.Angles(0, rad(-20), 0)
	block(ctx, "CartBed", Vector3.new(3.4, 0.9, 2.2), cart * CFrame.new(0, 1.45, 0), C.wood, M.WoodPlanks)
	for _, sz in { -1, 1 } do
		disc(ctx, "CartWheel", cart * CFrame.new(0.3, 1.0, sz * 1.25), 2.0, 0.3, C.woodDark, M.Wood)
	end
	burlapSack(ctx, cart * CFrame.new(-0.7, 1.9, 0) * CFrame.Angles(0, 0, rad(70)), 1.3)
	burlapSack(ctx, cart * CFrame.new(0.8, 1.9, 0.2), 1.3)
	attach(ctx, "Door", Vector3.new(0, 0, -hz - 1.5))
	attach(ctx, "DropOff", Vector3.new(-3.0, 0, -hz + 0.6))
	workSpots(ctx, { Vector3.new(dx + 1.8, 0, fzg - 3.2), Vector3.new(5.2, 0, -hz + 0.6) })
end

-- Granary construction stages (FL-0086 review: build toward the finished granary): 1 the staddle stones set
-- out with timber and a stone pile; 2 + the floor, corner posts and top plate; 3 + plank walls going up and the
-- hip rafters with the first kingdom tiles.
local function granaryStage(ctx: Ctx, level: number, stage: number, color: Color3, fp: Vector2)
	local g = granaryDims(math.clamp(level, 1, 2))
	block(ctx, "SiteGround", Vector3.new(g.gw + 4, 0.16, g.gd + 4), CFrame.new(0, 0.08, g.cz), C.soil, M.Ground)
	staddles(ctx, g)
	local y0 = g.lift + 0.6
	local top = y0 + g.h
	if stage >= 2 then
		block(
			ctx,
			"Floor",
			Vector3.new(g.gw + 0.8, 0.6, g.gd + 0.8),
			CFrame.new(0, g.lift + 0.3, g.cz),
			C.timber,
			M.WoodPlanks
		)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				block(
					ctx,
					"FramePost",
					Vector3.new(0.7, g.h, 0.7),
					CFrame.new(sx * g.gw / 2, y0 + g.h / 2, g.cz + sz * g.gd / 2),
					C.timber,
					M.Wood
				)
			end
		end
		block(
			ctx,
			"TopPlate",
			Vector3.new(g.gw + 0.5, 0.6, g.gd + 0.5),
			CFrame.new(0, top + 0.3, g.cz),
			C.timber,
			M.Wood
		)
	end
	if stage >= 3 then
		-- plank walls going up (front half, left side), the hip rafters to the ridge, the first kingdom tiles
		block(
			ctx,
			"WallsPartial",
			Vector3.new(g.gw * 0.55, g.h * 0.62, 0.3),
			CFrame.new(-g.gw * 0.2, y0 + g.h * 0.31, g.cz - g.gd / 2 + 0.2),
			C.woodLight,
			M.WoodPlanks
		)
		block(
			ctx,
			"WallsPartial",
			Vector3.new(0.3, g.h * 0.45, g.gd - 1.0),
			CFrame.new(-g.gw / 2 + 0.2, y0 + g.h * 0.225, g.cz),
			C.woodLight,
			M.WoodPlanks
		)
		local rise = g.gd * 0.48
		local half = (g.gw - g.gd) / 2
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				Pieces.beamBetween(
					ctx,
					"HipRafter",
					Vector3.new(sx * g.gw / 2, top + 0.6, g.cz + sz * g.gd / 2),
					Vector3.new(sx * half, top + 0.6 + rise, g.cz),
					0.45,
					C.woodLight,
					M.Wood
				)
			end
		end
		if half > 0.1 then
			block(
				ctx,
				"RidgeBeam",
				Vector3.new(2 * half + 0.4, 0.45, 0.45),
				CFrame.new(0, top + 0.6 + rise, g.cz),
				C.woodLight,
				M.Wood
			)
		end
		local theta = math.atan2(rise, g.gd / 2)
		local u = 1.4
		block(
			ctx,
			"RoofTiles",
			Vector3.new(g.gw * 0.7, 0.4, 2.2),
			CFrame.new(-g.gw * 0.1, top + 0.6 + u * math.sin(theta) + 0.25, g.cz + g.gd / 2 - u * math.cos(theta))
				* CFrame.Angles(theta, 0, 0),
			shade(color, 0.88),
			M.ClayRoofTiles,
			0.88
		)
	end
	materialPile(ctx, -3.5, -fp.Y / 2 + 2.6)
	flagpole(ctx, -fp.X / 2 + 1.0, 0, -fp.Y / 2 + 1.0, 6, color)
	local dw, dd = fp.X - 2, fp.Y - 2
	attach(ctx, "Door", Vector3.new(0, 0, -dd / 2 - 2))
	workSpots(ctx, { Vector3.new(-dw / 4, 0, -dd / 2 - 2.5), Vector3.new(dw / 4, 0, -dd / 2 - 2.5) })
end

-- Shrine: an open-air sanctuary on a stepped platform in the kingdom's stone: an altar stone with a kingdom altar
-- cloth and a fire in a bronze bowl (the flame prop), a ring of standing stones open to the front, braziers with
-- fire. L1: a broad focal stone behind the altar (≥ 14 studs with its cap) carrying the kingdom banner on its face
-- and the kingdom capstone on top, a cairn. L2: a third tier, a taller ring, a pillared pavilion over the altar
-- crowned by the kingdom tower cap and flag (neutral: a stepped stone top, not a pyramid), the banner hung inside
-- behind the fire, two more braziers.
BUILDERS.shrine = function(ctx, level, color, style, fp)
	local lv = math.clamp(level, 1, 2)
	local hz = fp.Y / 2
	local S = stoneFor(style)
	local tiers = if lv == 1 then { 10.4, 7.0 } else { 11.6, 9.0, 6.8 }
	local y = 0
	for i, tw in tiers do
		block(
			ctx,
			"ShrineStep",
			Vector3.new(tw, 0.5, tw),
			CFrame.new(0, y + 0.25, 0),
			if i % 2 == 1 then S.dark else S.light,
			M.Slate
		)
		y += 0.5
	end
	-- the altar with the kingdom cloth and its fire
	local az = -0.9
	block(ctx, "AltarStone", Vector3.new(2.6, 1.6, 1.8), CFrame.new(0, y + 0.8, az), S.base, M.Slate)
	block(ctx, "AltarSlab", Vector3.new(3.2, 0.4, 2.3), CFrame.new(0, y + 1.8, az), S.light, M.Slate)
	block(
		ctx,
		"AltarCloth",
		Vector3.new(1.8, 1.3, 0.12),
		CFrame.new(0, y + 1.0, az - 0.96),
		shade(color, 0.85),
		M.Fabric,
		0.85
	)
	column(ctx, "FireBowl", 0.7, 0.5, Vector3.new(0, y + 2.0, az), BRONZE, M.Metal)
	flame(ctx, Vector3.new(0, y + 2.4, az), 1.4)
	-- standing stones in a ring open to the front (azimuths clockwise from the front)
	local ring = if lv == 1 then 6.2 else 6.5
	local azs = if lv == 1 then { 55, 105, 180, 255, 305 } else { 60, 95, 130, 165, 195, 230, 265, 300 }
	for i, az2 in azs do
		local a = rad(az2)
		local sh = (if lv == 1 then 4.6 else 6.0) + jit(i * 7, 0.7)
		local p = Vector3.new(math.sin(a) * ring, 0, -math.cos(a) * ring)
		block(
			ctx,
			"StandingStone",
			Vector3.new(1.7, sh, 1.2),
			CFrame.new(p + Vector3.new(0, sh / 2 - 0.1, 0))
				* CFrame.Angles(0, -a, 0)
				* CFrame.Angles(rad(jit(i, 3)), 0, rad(jit(i * 3, 3))),
			if i % 2 == 0 then S.light else S.base,
			M.Slate
		)
	end
	-- braziers flanking the approach (L2: two more on the second tier's front corners)
	local front = -tiers[1] / 2 - 1.0
	local brz = { Vector3.new(-3.0, 0, front), Vector3.new(3.0, 0, front) }
	if lv >= 2 then
		table.insert(brz, Vector3.new(-3.9, 0.5, -3.9))
		table.insert(brz, Vector3.new(3.9, 0.5, -3.9))
	end
	for _, p in brz do
		brazier(ctx, p, 2.6 - p.Y, S.base)
	end
	if lv == 1 then
		-- the broad focal stone with the kingdom banner on its face and the kingdom capstone on its top
		local fz, fw, fh = 2.0, 4.2, 11.0
		block(ctx, "FocalStone", Vector3.new(fw, fh, 1.2), CFrame.new(0, y + fh / 2, fz), S.light, M.Slate)
		banner(ctx, 0, y + fh - 1.3, fz - 0.6 - 0.15 + 0.45, 0, color, 4.4, style, 3.2)
		smallCap(ctx, style, 2.4, y + fh, color, 0, fz)
		local cn = Vector3.new(-6.3, 0, -6.3)
		block(
			ctx,
			"Cairn",
			Vector3.new(2.2, 1.0, 2.0),
			CFrame.new(cn + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, rad(12), 0),
			S.base,
			M.Slate
		)
		block(
			ctx,
			"Cairn",
			Vector3.new(1.6, 0.9, 1.5),
			CFrame.new(cn + Vector3.new(0.1, 1.42, 0)) * CFrame.Angles(0, rad(-20), 0),
			S.light,
			M.Slate
		)
		ball(ctx, "Cairn", 1.1, cn + Vector3.new(0, 2.25, 0.05), S.base, M.Slate)
	else
		-- the pillared pavilion over the altar, the banner inside behind the fire, the kingdom cap and flag
		local pw = 7.0
		local ph = 6.6
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = Vector3.new(sx * (pw / 2 - 0.7), y, sz * (pw / 2 - 0.7))
				column(ctx, "PillarBase", 0.72, 0.5, p, S.base, M.Slate)
				column(ctx, "Pillar", 0.48, ph, p + Vector3.new(0, 0.5, 0), IVORY_STONE, M.Marble)
			end
		end
		local ey = y + 0.5 + ph
		block(ctx, "Entablature", Vector3.new(pw + 0.4, 1.1, pw + 0.4), CFrame.new(0, ey + 0.55, 0), S.light, M.Slate)
		banner(ctx, 0, ey - 0.2, 2.65, 0, color, 4.0, style, 3.2)
		if style == "neutral" then
			-- neutral (no kingdom): a stepped stone top and pinnacle, never azure's pyramid
			local yy = ey + 1.1
			for i, k in { 1.1, 0.8, 0.5 } do
				local s = pw * k
				block(
					ctx,
					"StoneTop",
					Vector3.new(s, 0.9, s),
					CFrame.new(0, yy + 0.45, 0),
					if i % 2 == 1 then C.stoneLight else C.stone,
					M.Slate
				)
				yy += 0.9
			end
			block(ctx, "StonePinnacle", Vector3.new(1.4, 3.2, 1.4), CFrame.new(0, yy + 1.6, 0), C.stoneLight, M.Slate)
			ball(ctx, "StoneKnob", 1.8, Vector3.new(0, yy + 3.2 + 0.85, 0), C.stone, M.Slate)
		else
			towerCap(ctx, style, pw, ey + 1.1, color, 0, 0, 5)
		end
	end
	attach(ctx, "Door", Vector3.new(0, 0, -hz - 1.5))
	workSpots(ctx, { Vector3.new(0, 0, front - 0.4) })
end

-- Building sites of the VS-2 types: the main mass each one builds toward (the crag's adit timbering, the
-- smithy and forge shed together, the booth or hall, the ward, the shrine platform), kept ≥ 10 wide so the site
-- props never overlap and inside the footprint with the scaffold. The granary builds its own stages
-- (VS2_STAGES: staddles, then floor and frame, then plank walls and the hip roof).
type Site = { w: number, d: number, cx: number, cz: number, h: number, heavy: boolean }
local VS2_SITES: { [string]: Site } = {
	mine = { w = 10, d = 6, cx = -2.6, cz = 5.2, h = 8, heavy = false },
	blacksmith = { w = 17, d = 9, cx = 0.2, cz = 2.0, h = 9, heavy = true },
	market = { w = 10, d = 6, cx = 0, cz = 5.2, h = 8, heavy = false },
	infirmary = { w = 15, d = 6.6, cx = 0, cz = 2.4, h = 7, heavy = false },
	granary = { w = 10, d = 8, cx = 0, cz = 1.0, h = 10, heavy = false },
	shrine = { w = 10, d = 10, cx = 0, cz = 0, h = 6, heavy = true },
}
local VS2_STAGES: { [string]: (ctx: Ctx, level: number, stage: number, color: Color3, fp: Vector2) -> () } = {
	granary = granaryStage,
}

-- ------------------------------------------------------------------ construction stages

-- The mass a site builds toward: (w, d, cx, cz, height, heavy stone?)
local function siteBox(
	buildingType: string,
	level: number,
	fp: Vector2
): (number, number, number, number, number, boolean)
	if buildingType == "keep" then
		return fp.X - 8, fp.X - 8, 0, 0, 16 + (level - 1) * 3, true
	elseif buildingType == "watchtower" then
		return fp.X - 4.5, fp.X - 4.5, 0, 0, 16 + (level - 1) * 3, true
	elseif buildingType == "wall" or buildingType == "gate" then
		return fp.X - 4, fp.Y - 5, 0, 0, 12, true
	elseif buildingType == "farm" then
		local hw = 0.38 * fp.X - 4.15 -- the farmhouse of BUILDERS.farm
		return hw, 9, fp.X / 2 - 2.15 - hw / 2, -fp.Y / 2 + 6.7, 8.4, false
	elseif buildingType == "house" then
		return fp.X - 5, fp.Y - 5, 0, 0, 9.5 + (level - 1) * 3, false
	elseif buildingType == "barracks" then
		return fp.X - 7, fp.Y - 8, 0, 1.5, 11, false
	elseif buildingType == "storehouse" then
		return fp.X - 5, fp.Y - 6, 0, 0, 10, false
	elseif VS2_SITES[buildingType] then
		local s = VS2_SITES[buildingType]
		return s.w, s.d, s.cx, s.cz, s.h, s.heavy
	end
	return fp.X - 6, fp.Y - 6, 0, 0, 9, false
end

-- Construction stages replace the whole model (G6): 1 foundation (stakes, strings, footings, materials),
-- 2 timber frame + scaffolding, 3 partial walls + roof frame; "complete" = the finished building.
local function buildStage(ctx: Ctx, buildingType: string, level: number, stage: number, color: Color3, fp: Vector2)
	local own = VS2_STAGES[buildingType]
	if own then
		own(ctx, level, stage, color, fp)
		return
	end
	local w, d, cx, cz, H, heavy = siteBox(buildingType, level, fp)
	local S = Pieces.STONE.neutral
	block(
		ctx,
		"SiteGround",
		Vector3.new(math.min(w + 4, fp.X - 2 * math.abs(cx)), 0.16, math.min(d + 4, fp.Y - 2 * math.abs(cz))),
		CFrame.new(cx, 0.08, cz),
		C.soil,
		M.Ground
	)
	local pl = if heavy then 1.6 else 1.2
	if stage == 1 then
		-- footings: dark core + the first facing stones on two sides
		block(ctx, "Footing", Vector3.new(w, pl * 0.6, d), CFrame.new(cx, pl * 0.3, cz), S.dark, M.Cobblestone)
		for i = 0, 2 do
			local u = -w / 2 + (i + 0.5) * w / 3
			block(
				ctx,
				"PlinthStone",
				Vector3.new(w / 3 - 0.3, pl, 1),
				CFrame.new(cx + u, pl / 2, cz - d / 2 - 0.1),
				if i % 2 == 0 then S.light else S.base,
				M.Slate
			)
		end
		block(
			ctx,
			"PlinthStone",
			Vector3.new(1, pl, d * 0.55),
			CFrame.new(cx - w / 2 - 0.1, pl / 2, cz - d * 0.2),
			S.base,
			M.Slate
		)
		-- stakes and string lines
		local corners = {}
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = Vector3.new(cx + sx * (w / 2 + 0.7), 0, cz + sz * (d / 2 + 0.7))
				column(ctx, "Stake", 0.18, 2.2, p, C.woodLight, M.Wood)
				table.insert(corners, p + Vector3.new(0, 1.7, 0))
			end
		end
		local order = { 1, 2, 4, 3, 1 }
		for i = 1, 4 do
			Pieces.beamBetween(ctx, "StringLine", corners[order[i]], corners[order[i + 1]], 0.08, C.canvas, M.Fabric)
		end
	else
		stonePlinth(ctx, w + 0.6, d + 0.6, pl, cx, cz, S, 19, if heavy then 7 else 5)
		local f = wallFrames(w, d, pl, cx, cz)
		local fh = if stage == 2 then H * 0.85 else H
		if heavy then
			-- stone courses rising with uneven tops
			local frac = if stage == 2 then 0.25 else 0.6
			for i, side in { "front", "back", "left", "right" } do
				local len = if side == "front" or side == "back" then w else d
				for k = 0, 1 do
					local hh = H * frac * (if k == 0 then 1 else 0.72) + jit(i * 5 + k, 0.5)
					local seg = len / 2
					block(
						ctx,
						"WallCourse",
						Vector3.new(seg + 0.02, hh, 1.6),
						f[side] * CFrame.new(-len / 4 + k * seg, hh / 2, 0.8),
						if k == 0 then S.base else S.light,
						M.Cobblestone
					)
				end
			end
			if stage == 3 then
				-- A-frame crane hoisting a stone
				local p = CFrame.new(cx - w / 2 + 2.5, 0, cz - d / 2 - 1.2)
				strut(ctx, "CraneLeg", p, -1.5, 0, 0, H + 3, 0.5, 0.5, C.wood, M.Wood)
				strut(ctx, "CraneLeg", p, 1.5, 0, 0, H + 3, 0.5, 0.5, C.wood, M.Wood)
				block(ctx, "CraneJib", Vector3.new(0.5, 0.5, 6), p * CFrame.new(0, H + 3, 2.4), C.wood, M.Wood)
				block(ctx, "CraneRope", Vector3.new(0.12, 4, 0.12), p * CFrame.new(0, H + 1, 5.2), C.canvas, M.Fabric)
				block(ctx, "CraneLoad", Vector3.new(1.6, 1.3, 1.6), p * CFrame.new(0, H - 1.6, 5.2), S.light, M.Slate)
			end
		else
			-- timber frame: corner and mid posts, top beams, braces
			for _, sx in { -1, 0, 1 } do
				for _, sz in { -1, 1 } do
					block(
						ctx,
						"FramePost",
						Vector3.new(0.7, fh, 0.7),
						CFrame.new(cx + sx * w / 2, pl + fh / 2, cz + sz * d / 2),
						C.timber,
						M.Wood
					)
				end
			end
			for _, sz in { -1, 1 } do
				block(
					ctx,
					"FrameBeam",
					Vector3.new(w + 0.6, 0.6, 0.6),
					CFrame.new(cx, pl + fh, cz + sz * d / 2),
					C.timber,
					M.Wood
				)
			end
			for _, sx in { -1, 1 } do
				block(
					ctx,
					"FrameBeam",
					Vector3.new(0.6, 0.6, d),
					CFrame.new(cx + sx * w / 2, pl + fh, cz),
					C.timber,
					M.Wood
				)
				strut(
					ctx,
					"FrameBrace",
					f.front,
					sx * w / 2,
					0.6,
					sx * (w / 2 - 3),
					fh * 0.6,
					0.5,
					0.4,
					C.timber,
					M.Wood
				)
			end
			if stage == 3 then
				-- partial plaster walls with uneven tops
				for i, side in { "front", "back", "left", "right" } do
					local len = if side == "front" or side == "back" then w else d
					for k = 0, 1 do
						local hh = fh * (if k == 0 then 0.62 else 0.38) + jit(i * 3 + k, 0.4)
						block(
							ctx,
							"WallsPartial",
							Vector3.new(len / 2 - 0.4, hh, 0.5),
							f[side] * CFrame.new(-len / 4 + k * len / 2, hh / 2, 0.3),
							C.plaster,
							M.Plaster
						)
					end
				end
				-- roof frame: rafter pairs + ridge beam, the first tile courses in the kingdom colour
				local rise = d / 2 * 0.95
				local top = pl + fh
				for i = 0, 2 do
					local x = cx - w / 2 + 0.4 + i * (w - 0.8) / 2
					local plane = CFrame.new(x, 0, cz) * CFrame.Angles(0, PI / 2, 0)
					strut(ctx, "Rafter", plane, -d / 2 - 0.4, top, 0, top + rise, 0.45, 0.45, C.woodLight, M.Wood)
					strut(ctx, "Rafter", plane, d / 2 + 0.4, top, 0, top + rise, 0.45, 0.45, C.woodLight, M.Wood)
				end
				block(ctx, "RidgeBeam", Vector3.new(w, 0.5, 0.5), CFrame.new(cx, top + rise, cz), C.woodLight, M.Wood)
				local theta = math.atan2(rise, d / 2)
				local L = math.sqrt((d / 2) ^ 2 + rise * rise)
				for k = 0, 1 do
					local u = L - 0.9 - k * 1.7
					block(
						ctx,
						"RoofTiles",
						Vector3.new(w * 0.45, 0.45, 2.1),
						CFrame.new(cx - w * 0.27, top + rise - u * math.sin(theta) + 0.5, cz - u * math.cos(theta))
							* CFrame.Angles(-theta, 0, 0),
						shade(color, 0.88 * (if k == 0 then 1 else 0.86)),
						M.ClayRoofTiles,
						0.88 * (if k == 0 then 1 else 0.86)
					)
				end
			end
		end
		scaffold(ctx, w, d, fh, cx, cz)
	end
	materialPile(ctx, cx - w / 2 + 2.5, cz - d / 2 - 2.6)
	-- sawhorse with a plank
	local sh = CFrame.new(cx + w / 2 - 1.5, 0, cz - d / 2 - 2.8)
	for _, px in { -1.1, 1.1 } do
		block(ctx, "Sawhorse", Vector3.new(0.3, 1.8, 1.4), sh * CFrame.new(px, 0.9, 0), C.wood, M.Wood)
	end
	block(ctx, "SawPlank", Vector3.new(3.6, 0.25, 1), sh * CFrame.new(0.3, 1.9, 0), C.woodLight, M.WoodPlanks)
	if buildingType == "farm" then
		-- the field: ploughed furrows, then green shoots, then young wheat
		local fw = fp.X * 0.62
		local fx = -fp.X / 2 + fw / 2 + 0.4
		local fd = fp.Y - 2.4
		block(ctx, "Field", Vector3.new(fw, 0.3, fd), CFrame.new(fx, 0.15, 0), C.soil, M.Ground)
		local rows = 6
		local cropH = if stage == 1 then 0.35 else if stage == 2 then 0.9 else 1.8
		local cropC = if stage == 1 then shade(C.soil, 0.8) elseif stage == 2 then C.leafLight else C.grass
		for i = 0, rows - 1 do
			block(
				ctx,
				"Crop",
				Vector3.new(fw - 1.6, cropH, fd / rows * 0.45),
				CFrame.new(fx, 0.3 + cropH / 2, -fd / 2 + (i + 0.5) * fd / rows),
				cropC,
				M.Grass
			)
		end
	end
	flagpole(ctx, cx - w / 2 - 1.4, 0, cz - d / 2 - 1.4, 6, color)
	local dw, dd = fp.X - 2, fp.Y - 2
	attach(ctx, "Door", Vector3.new(0, 0, -dd / 2 - 2))
	workSpots(ctx, { Vector3.new(-dw / 4, 0, -dd / 2 - 2.5), Vector3.new(dw / 4, 0, -dd / 2 - 2.5) })
	if buildingType == "storehouse" then
		attach(ctx, "DropOff", Vector3.new(-3, 0, -dd / 2 - 3))
	elseif buildingType == "barracks" or buildingType == "gate" then
		attach(ctx, "Rally", Vector3.new(0, 0, -dd / 2 - 10))
	end
end

function Buildings.build(
	buildingType: string,
	level: number,
	stage: number | string,
	kingdomColor: Color3,
	variant: number?
): Model
	local builder = BUILDERS[buildingType]
	assert(builder, `Kit.build: unknown building type {buildingType}`)
	local fp = Buildings.footprint(buildingType, level)
	local stageName = if stage == "complete" then "complete" else tostring(stage)
	local v = math.max(1, math.floor(variant or 1))
	local ctx = newModel(`{buildingType}_L{level}_{stageName}`, fp)
	ctx.model:SetAttribute("KitType", buildingType)
	ctx.model:SetAttribute("KitLevel", level)
	ctx.model:SetAttribute("KitStage", stageName)
	ctx.model:SetAttribute("KitVariant", v)
	if stage == "complete" then
		builder(ctx, level, kingdomColor, hueStyle(kingdomColor), fp, v)
	else
		assert(type(stage) == "number" and stage >= 1 and stage <= 3, 'Kit.build: stage must be 1..3 or "complete"')
		buildStage(ctx, buildingType, level, stage :: number, kingdomColor, fp)
	end
	return ctx.model
end

return Buildings
