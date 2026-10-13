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
	barracks L1–4, house L1–2 and farm L1–2 grow height and roof count with level (G13.5); mine, blacksmith,
	market, infirmary, granary and shrine are labelled stand-ins (attributes KitStandIn, KitLabel).

	Part budgets (max BaseParts per model; enforced by tests/world/KitBuildings.spec.luau). World budget is
	≤ 25k parts at VS-2 (BRIEF §14). A VS-2 kingdom (keep L3, 10 houses, 3 farms, storehouse, 2 lumber
	camps, 2 quarries, 2 barracks, 2 watchtowers, 12 wall segments, a gate, one of each G13.5 type, 2 sites
	in progress) measures ≈ 4.1k parts → 4 kingdoms + 3 neutral towers ≈ 16.9k, leaving ≈ 8k for
	WorldService props and region markers. The caps are ceilings, not targets: every model at its cap would
	sum to ≈ 23.6k, so new detail goes where it reads (roofs, doors, banners), never into hidden faces.

		type        cap   measured (min–max over levels, variants, the 4 + 2 FORGE-01 kingdom colours, neutral)
		keep        300   198–292  (L1 198–218, L2 230–258, L3 261–292; Kit.spec: L1–L2 ≤ 260, L3 ≤ 300)
		house       170   99–161   (8 variants, L1–L2)
		farm        190   151–183
		storehouse  150   89–94
		lumbercamp  130   48–52
		quarry      130   53–57
		barracks    260   119–252  (L1–L4)
		watchtower  130   100–122
		wall         60   37–40    (per 32-stud segment)
		gate        150   97–106
		mine/blacksmith/market/infirmary/granary/shrine   110/150/150/150/110/80   (38–108, G13.5 stand-ins)
		stages      110   29–79    (any type, stage 1..3)
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
	-- G13.5 VS-2 types (stand-ins until FL-0086)
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
	stonePlinth(ctx, 2 * hw + 2.6, 2 * hd + 2.6, pl, 0, zc, S, 7, 8)
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
	local cz = zc + hd - cw / 2 - 2
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
		ball(ctx, "StandardFinial", 0.7, Vector3.new(px, pl + 9.7, pz), C.gold, M.Metal)
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
	-- side and back windows
	local hf = wallFrames(2 * hw, 2 * hd, 0, 0, zc)
	for _, side in { "left", "right", "back" } do
		windowAt(
			ctx,
			hf[side] * CFrame.new(if side == "back" then 0 else -2, courseY + 1.2, 0),
			{ arched = true, w = 2.4, h = 4.6, frame = S.light, frameMaterial = M.Slate, bare = true }
		)
		windowAt(
			ctx,
			hf[side] * CFrame.new(if side == "back" then 0 else -2, pl + 5, 0),
			{ slit = true, frame = S.light }
		)
	end
	if lv >= 2 then
		-- banners on the front turrets
		for _, sx in { -1, 1 } do
			local tx, tz = sx * hw, zc - hd
			banner(ctx, tx + sx * 0.5 * tr, pl + tH - 3.5, tz - tr * 0.86, sx * -30, color, 6, style, 2.4)
		end
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
		local bxs = if lv >= 4 then { -gw / 2 - 2.6, gw / 2 + 2.6 } else { -5.4, 5.4 }
		for _, bx in bxs do
			banner(ctx, bx, y2 - 0.45, fzw - 0.05, 0, color, 4.6, style, 2.2)
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

-- ------------------------------------------------------------------ G13.5 VS-2 types (stand-ins until FL-0086)
-- Decent part-built stand-ins in the same language, labelled with the KitStandIn attribute. One level each.

local ORE = Color3.fromRGB(116, 98, 168)
local EMBER = Color3.fromRGB(255, 132, 44)
local WATER = Color3.fromRGB(86, 150, 196)
local LINEN = Color3.fromRGB(246, 242, 230)

local function standIn(ctx: Ctx, label: string)
	ctx.model:SetAttribute("KitStandIn", true)
	ctx.model:SetAttribute("KitLabel", label)
end

-- Hanging sign board on a bracket: cf on the wall face (local -Z out), kingdom-colour board.
local function signBoard(ctx: Ctx, cf: CFrame, color: Color3)
	block(ctx, "SignArm", Vector3.new(0.3, 0.3, 2.2), cf * CFrame.new(0, 0, -1.1), C.iron, M.Metal)
	block(
		ctx,
		"Sign",
		Vector3.new(0.2, 1.5, 1.8),
		cf * CFrame.new(0, -1.05, -1.3),
		shade(color, 0.8),
		M.WoodPlanks,
		0.8
	)
end

BUILDERS.mine = function(ctx, _level, color, style, fp)
	standIn(ctx, "mine")
	local w, d = fp.X - 2, fp.Y - 2
	-- rocky hill with the shaft entrance in its face
	local rocks = { { -4.8, 3.4, 9, 9, 7.5 }, { 3.2, 4, 9, 11, 8 }, { -0.5, 5.4, 12, 9.5, 6 }, { 6.8, 2.2, 5, 6, 5 } }
	for i, r in rocks do
		block(
			ctx,
			"Rock",
			Vector3.new(r[3], r[4], r[5]),
			CFrame.new(r[1], r[4] / 2 + 0.35, r[2])
				* CFrame.Angles(rad(jit(i * 5, 4)), rad(jit(i * 3, 7)), rad(jit(i * 7, 4))),
			shade(QUARRY_STONE[(i - 1) % 3 + 1], 0.95),
			M.Rock
		)
	end
	block(
		ctx,
		"Moss",
		Vector3.new(7, 1, 7.5),
		CFrame.new(-0.5, 10.3, 5.4) * CFrame.Angles(rad(4), rad(10), 0),
		C.leaf,
		M.Grass
	)
	local pz = -0.6
	block(ctx, "MineShaft", Vector3.new(4.2, 5.6, 0.4), CFrame.new(0, 2.8, pz - 0.05), C.glass, M.Slate)
	for _, sx in { -1, 1 } do
		block(ctx, "PortalPost", Vector3.new(0.8, 6.4, 0.8), CFrame.new(sx * 2.5, 3.2, pz - 0.4), C.timber, M.Wood)
	end
	block(ctx, "PortalLintel", Vector3.new(6.4, 0.9, 1), CFrame.new(0, 6.6, pz - 0.4), C.timber, M.Wood)
	leanTo(ctx, CFrame.new(0, 8.6, pz + 0.4), 7.4, 2.6, 1.3, color, 0.85, 2)
	-- rails and an ore cart
	for _, sx in { -0.75, 0.75 } do
		block(ctx, "Rail", Vector3.new(0.2, 0.2, 9), CFrame.new(sx, 0.3, pz - 4.6), C.iron, M.Metal)
	end
	for i = 0, 3 do
		block(ctx, "Sleeper", Vector3.new(2.4, 0.2, 0.5), CFrame.new(0, 0.1, pz - 1.2 - i * 2.2), C.woodDark, M.Wood)
	end
	local cz = pz - 5.4
	block(ctx, "OreCart", Vector3.new(2.4, 1.4, 3), CFrame.new(0, 1.5, cz), C.woodDark, M.WoodPlanks)
	for _, oz in { -0.9, 0.9 } do
		cyl(ctx, "CartAxle", CFrame.new(0, 0.6, cz + oz), 2.6, 1.1, C.iron, M.Metal)
	end
	ball(ctx, "Ore", 1.4, Vector3.new(-0.3, 2.4, cz - 0.4), C.stoneDark, M.Slate)
	ball(ctx, "OreCrystal", 1.0, Vector3.new(0.4, 2.5, cz + 0.6), ORE, M.SmoothPlastic)
	-- ore pile, lantern, picks, flag, sign
	for i, p in { Vector3.new(-6, 0, -5.5), Vector3.new(-7.2, 0, -4.3), Vector3.new(-5.6, 0.9, -4.6) } do
		ball(ctx, "OrePile", 1.8, p + Vector3.new(0, 0.7, 0), if i == 3 then ORE else C.stoneDark, M.Slate)
	end
	column(ctx, "LanternPost", 0.18, 4.4, Vector3.new(3.6, 0, pz - 1.2), C.woodDark, M.Wood)
	block(ctx, "Lantern", Vector3.new(0.7, 0.9, 0.7), CFrame.new(3.6, 4.0, pz - 1.6), EMBER, M.SmoothPlastic)
	for i = 0, 1 do
		block(
			ctx,
			"Pick",
			Vector3.new(0.2, 3, 0.2),
			CFrame.new(-3.4 + i * 0.6, 1.4, pz - 0.6) * CFrame.Angles(rad(-15), 0, rad(10 - i * 20)),
			C.wood,
			M.Wood
		)
	end
	flagpole(ctx, -w / 2 + 1.5, 0, -d / 2 + 1.5, 8, color)
	banner(ctx, -2.2, 8.2, pz - 0.95, 0, color, 2.4, style, 1.4)
	attach(ctx, "Door", Vector3.new(0, 0, -fp.Y / 2 - 1.5))
	workSpots(ctx, { Vector3.new(0, 0, pz - 1.6), Vector3.new(-4.6, 0, -6) })
end

BUILDERS.blacksmith = function(ctx, _level, color, style, fp)
	standIn(ctx, "blacksmith")
	local S = Pieces.STONE.neutral
	local w, d = fp.X - 8, fp.Y - 8
	local bx, bz = -2, 2
	local pl = 1
	stonePlinth(ctx, w + 0.8, d + 0.8, pl, bx, bz, S, 71)
	local h = 8
	block(ctx, "Walls", Vector3.new(w, h - 0.03, d), CFrame.new(bx, pl + h / 2 + 0.015, bz), C.stone, M.Cobblestone)
	quoins(ctx, w, d, pl, h, C.stoneLight, 2, bx, bz)
	local info = tileRoof(ctx, {
		w = w,
		d = d,
		y = pl + h,
		rise = d / 2 * 0.95,
		cf = CFrame.new(bx, 0, bz),
		over = 1.3,
		color = color,
		tint = 0.88,
		infill = C.woodLight,
		infillMaterial = M.WoodPlanks,
	})
	local f = wallFrames(w, d, pl, bx, bz)
	doorAt(ctx, f.front * CFrame.new(-w * 0.25, 0, 0), { leaf = color, leafTint = 0.72, step = pl, voussoirs = 5 })
	windowAt(ctx, f.left * CFrame.new(0, 3, 0), { shutters = color })
	-- open forge under a lean-to on the front right: hearth, embers, big chimney, anvil, quench barrel
	local fx, fz = bx + w * 0.22, bz - d / 2
	for _, px in { -2.6, 2.6 } do
		block(ctx, "ForgePost", Vector3.new(0.55, 6.6, 0.55), CFrame.new(fx + px, 3.3, fz - 4.2), C.timber, M.Wood)
	end
	leanTo(ctx, CFrame.new(fx, 7.8, fz), 6.8, 4.6, 1.4, color, 0.8, 2)
	block(ctx, "Hearth", Vector3.new(3.4, 2.2, 2.6), CFrame.new(fx + 1.2, 1.1, fz - 1.5), C.stoneDark, M.Cobblestone)
	block(ctx, "Embers", Vector3.new(2.4, 0.3, 1.8), CFrame.new(fx + 1.2, 2.3, fz - 1.5), EMBER, M.SmoothPlastic)
	chimney(ctx, fx + 1.2, fz + 0.6, 0, info.ridgeY + 2.6, 2.6)
	column(ctx, "AnvilStump", 0.8, 1.4, Vector3.new(fx - 1.2, 0, fz - 2.8), C.bark, M.Wood)
	block(ctx, "Anvil", Vector3.new(1.8, 0.7, 0.8), CFrame.new(fx - 1.2, 1.75, fz - 2.8), C.iron, M.Metal)
	wedge(
		ctx,
		"AnvilHorn",
		Vector3.new(0.8, 0.7, 0.9),
		CFrame.new(fx - 2.5, 1.75, fz - 2.8) * CFrame.Angles(0, PI / 2, 0),
		C.iron,
		M.Metal
	)
	barrel(ctx, Vector3.new(fx - 3.6, 0, fz - 1.4), 1.8)
	disc(ctx, "Water", CFrame.new(fx - 3.6, 1.82, fz - 1.4) * CFrame.Angles(PI / 2, 0, 0), 1.7, 0.05, WATER, M.Glass)
	-- weapons on a rack by the wall, sign
	block(ctx, "Rack", Vector3.new(3.6, 0.3, 0.3), CFrame.new(bx - w * 0.25 + 4.4, 3.4, fz - 0.4), C.wood, M.Wood)
	for i = 0, 2 do
		block(
			ctx,
			"Sword",
			Vector3.new(0.25, 3, 0.12),
			CFrame.new(bx - w * 0.25 + 3.2 + i * 1.2, 2.3, fz - 0.5),
			C.stoneLight,
			M.Metal
		)
	end
	signBoard(ctx, f.front * CFrame.new(-w * 0.25 - 3.4, 7, 0), color)
	banner(ctx, bx - w / 2 + 1.6, pl + h - 0.6, fz - 0.05, 0, color, 3.6, style, 1.8)
	attach(ctx, "Door", Vector3.new(bx - w * 0.25, 0, -fp.Y / 2 - 1.5))
	workSpots(ctx, { Vector3.new(fx - 1.2, 0, fz - 4), Vector3.new(fx + 1.2, 0, fz - 3.6) })
end

-- Market stall: four posts, counter with goods, striped canopy (kingdom colour + linen).
local function stall(ctx: Ctx, cf: CFrame, color: Color3, goods: Color3)
	for _, sx in { -1.8, 1.8 } do
		for _, sz in { -1.3, 1.3 } do
			block(ctx, "StallPost", Vector3.new(0.35, 5.6, 0.35), cf * CFrame.new(sx, 2.8, sz), C.wood, M.Wood)
		end
	end
	block(ctx, "Counter", Vector3.new(4.2, 1.6, 1.2), cf * CFrame.new(0, 0.83, -0.9), C.woodLight, M.WoodPlanks)
	for i = -1, 1 do
		ball(ctx, "Goods", 0.9, (cf * CFrame.new(i * 1.1, 1.95, -0.9)).Position, goods, M.SmoothPlastic)
	end
	for i = -1, 1 do
		local kingdom = i ~= 0
		block(
			ctx,
			"Canopy",
			Vector3.new(1.45, 0.25, 3.6),
			cf * CFrame.new(i * 1.4, 5.9, -0.2) * CFrame.Angles(rad(14), 0, 0),
			if kingdom then color else LINEN,
			M.Fabric,
			if kingdom then 1 else nil
		)
	end
end

BUILDERS.market = function(ctx, _level, color, style, fp)
	standIn(ctx, "market")
	local w, d = fp.X, fp.Y
	block(ctx, "Paving", Vector3.new(w - 1, 0.2, d - 1), CFrame.new(0, 0.1, 0), C.stoneLight, M.Cobblestone)
	local goods = { Color3.fromRGB(214, 70, 52), Color3.fromRGB(236, 196, 70), Color3.fromRGB(120, 168, 70) }
	local spots = {
		{ -7.5, 5.5, 0 },
		{ 0, 7, 0 },
		{ 7.5, 5.5, 0 },
		{ -9.5, -3, -90 },
		{ 9.5, -3, 90 },
	}
	for i, s in spots do
		stall(ctx, CFrame.new(s[1], 0.2, s[2]) * CFrame.Angles(0, rad(s[3]) + PI, 0), color, goods[(i - 1) % 3 + 1])
	end
	-- well in the middle
	column(ctx, "WellRing", 2, 1.8, Vector3.new(0, 0.2, -1), C.stone, M.Cobblestone)
	disc(ctx, "WellWater", CFrame.new(0, 2.0, -1) * CFrame.Angles(PI / 2, 0, 0), 3.2, 0.05, WATER, M.Glass)
	for _, sx in { -1.7, 1.7 } do
		block(ctx, "WellPost", Vector3.new(0.35, 4.6, 0.35), CFrame.new(sx, 2.3, -1), C.wood, M.Wood)
	end
	block(ctx, "WellBeam", Vector3.new(3.8, 0.35, 0.3), CFrame.new(0, 4.4, -1), C.wood, M.Wood)
	crate(ctx, CFrame.new(-4.5, 0.2, -6) * CFrame.Angles(0, rad(12), 0), 1.8)
	barrel(ctx, Vector3.new(4.6, 0.2, -6.4), 2)
	sack(ctx, Vector3.new(-3.2, 0.2, -6.8))
	flagpole(ctx, -w / 2 + 1.5, 0, -d / 2 + 1.5, 9, color)
	banner(ctx, 0, 6.8, 7 + 1.9, 180, color, 2.4, style, 1.6)
	attach(ctx, "Door", Vector3.new(0, 0, -fp.Y / 2 - 1.5))
	workSpots(ctx, { Vector3.new(-7.5, 0, 3), Vector3.new(0, 0, 4.5), Vector3.new(7.5, 0, 3) })
end

BUILDERS.infirmary = function(ctx, _level, color, style, fp)
	standIn(ctx, "infirmary")
	local w, d = fp.X - 5, fp.Y - 7
	local bz = 1.5
	local pl = 1.2
	stonePlinth(ctx, w + 0.9, d + 0.9, pl, 0, bz, nil, 83)
	local h = 9.2
	timberBox(ctx, w, d, pl, h, PLASTERS[3], 0, bz)
	local f = wallFrames(w, d, pl, 0, bz)
	local ops: { Opening } = { { u = 0, hw = 3.3, door = true } }
	for _, sx in { -1, 1 } do
		windowAt(ctx, f.front * CFrame.new(sx * 5.6, 3, 0), { shutters = color })
		table.insert(ops, { u = sx * 5.6, hw = 1.9 })
	end
	frameWall(ctx, f.front, w, h, ops, 2.6)
	frameWall(ctx, f.left, d, h, { { u = 0, hw = 1.9 } }, 2.6)
	frameWall(ctx, f.right, d, h, { { u = 0, hw = 1.9 } }, 2.6)
	windowAt(ctx, f.left * CFrame.new(0, 3, 0), { simple = true })
	windowAt(ctx, f.right * CFrame.new(0, 3, 0), { simple = true })
	doorAt(ctx, f.front, { leaf = color, leafTint = 0.72, step = pl, voussoirs = 5 })
	local info = tileRoof(ctx, {
		w = w,
		d = d,
		y = pl + h,
		rise = d / 2,
		cf = CFrame.new(0, 0, bz),
		color = color,
		tint = 0.88,
		infill = PLASTERS[3],
		kingPost = true,
	})
	chimney(ctx, w * 0.3, bz + 1, pl + h - 1, info.ridgeY + 2.4 - (pl + h - 1))
	-- herb garden beds (front left) and linen drying on a line (front right); a green leaf sign
	local hz = bz - d / 2 - 2.6
	block(ctx, "HerbBed", Vector3.new(5, 0.4, 2.2), CFrame.new(-w / 2 + 3, 0.2, hz), C.soil, M.Ground)
	for i = 0, 3 do
		ball(
			ctx,
			"Herb",
			1.1,
			Vector3.new(-w / 2 + 1.3 + i * 1.15, 0.8, hz + (i % 2) * 0.5 - 0.25),
			if i % 2 == 0 then C.leafLight else Color3.fromRGB(170, 140, 210),
			M.Grass
		)
	end
	for _, sx in { 4.2, 8.4 } do
		block(ctx, "LinePost", Vector3.new(0.3, 4.2, 0.3), CFrame.new(sx, 2.1, hz), C.wood, M.Wood)
	end
	block(ctx, "Washline", Vector3.new(4.2, 0.08, 0.08), CFrame.new(6.3, 3.9, hz), C.canvas, M.Fabric)
	for _, lx in { 5.2, 7.2 } do
		block(ctx, "Linen", Vector3.new(1.5, 2, 0.1), CFrame.new(lx, 2.9, hz), LINEN, M.Fabric)
	end
	signBoard(ctx, f.front * CFrame.new(-3, 7.6, 0), color)
	block(
		ctx,
		"SignLeaf",
		Vector3.new(0.9, 0.9, 0.24),
		f.front * CFrame.new(-3, 6.55, -1.3) * CFrame.Angles(0, PI / 2, rad(45)),
		C.leaf,
		M.SmoothPlastic
	)
	banner(ctx, w / 2 - 1.2, pl + h - 0.6, bz - d / 2 - 0.05, 0, color, 3.4, style, 1.8)
	attach(ctx, "Door", Vector3.new(0, 0, -fp.Y / 2 - 1.5))
	workSpots(ctx, { Vector3.new(-w / 2 + 3, 0, hz - 1.6) })
end

BUILDERS.granary = function(ctx, _level, color, style, fp)
	standIn(ctx, "granary")
	local r = math.min(fp.X, fp.Y) / 2 - 3.4
	local lift = 2.6
	for i = 0, 5 do
		local a = i * PI / 3
		local p = Vector3.new(math.cos(a) * (r - 1), 0, math.sin(a) * (r - 1))
		column(ctx, "Staddle", 0.5, lift - 0.4, p, C.stone, M.Slate)
		column(ctx, "StaddleCap", 1.1, 0.45, p + Vector3.new(0, lift - 0.45, 0), C.stoneLight, M.Slate)
	end
	column(ctx, "GranaryFloor", r + 0.4, 0.7, Vector3.new(0, lift, 0), C.timber, M.WoodPlanks)
	local y0 = lift + 0.7
	local h = 8
	column(ctx, "GranaryWall", r, h, Vector3.new(0, y0, 0), C.woodLight, M.WoodPlanks)
	column(ctx, "GranaryBand", r + 0.12, 0.7, Vector3.new(0, y0 + h * 0.62, 0), shade(color, 0.85), M.Fabric, 0.85)
	column(ctx, "GranaryBand", r + 0.12, 0.5, Vector3.new(0, y0 + 0.6, 0), C.timber, M.Wood)
	-- conical thatch roof from stacked rings
	local rings = { { r + 1.6, 1.4 }, { r + 0.6, 1.6 }, { r - 0.8, 1.6 }, { r - 2.3, 1.5 }, { 1.2, 1.4 } }
	local y = y0 + h - 0.2
	for i, ring in rings do
		column(ctx, "Thatch", ring[1], ring[2], Vector3.new(0, y, 0), shade(C.thatch, 1 + (i % 2) * 0.06), M.Grass)
		y += ring[2] - 0.25
	end
	pennant(ctx, 0, y - 0.3, 0, 3.6, color)
	-- door, ladder, sacks
	block(
		ctx,
		"GranaryDoor",
		Vector3.new(2.6, 4.4, 0.4),
		CFrame.new(0, y0 + 2.2, -r + 0.05),
		shade(color, 0.72),
		M.WoodPlanks,
		0.72
	)
	local lz = -r - 1.2
	for _, sx in { -0.65, 0.65 } do
		strut(
			ctx,
			"LadderRail",
			CFrame.new(sx, 0, lz) * CFrame.Angles(0, PI / 2, 0),
			1.6,
			0,
			-0.6,
			y0 + 0.4,
			0.22,
			0.22,
			C.wood,
			M.Wood
		)
	end
	for i = 1, 3 do
		block(
			ctx,
			"LadderRung",
			Vector3.new(1.3, 0.18, 0.18),
			CFrame.new(0, i * (y0 / 4), lz - 1.6 * (1 - i / 4) + 0.6 * i / 4),
			C.wood,
			M.Wood
		)
	end
	for i, p in { Vector3.new(-3.6, 0, -r - 1.4), Vector3.new(-4.8, 0, -r - 0.4), Vector3.new(3.8, 0, -r - 1) } do
		sack(ctx, p, if i == 2 then 1.4 else 1.7)
	end
	banner(ctx, r * 0.72, y0 + h - 1, -r * 0.72, -45, color, 3.2, style, 1.8)
	attach(ctx, "Door", Vector3.new(0, 0, -fp.Y / 2 - 1.5))
	attach(ctx, "DropOff", Vector3.new(-3, 0, -fp.Y / 2 - 1))
	workSpots(ctx, { Vector3.new(3, 0, -fp.Y / 2 - 1) })
end

BUILDERS.shrine = function(ctx, _level, color, style, fp)
	standIn(ctx, "shrine")
	-- open pavilion: stepped stone platform, four pillars, kingdom pyramid roof, an eternal flame
	local S = stoneFor(style)
	local w = math.min(fp.X, fp.Y) - 4
	block(ctx, "ShrineStep", Vector3.new(w + 2, 0.6, w + 2), CFrame.new(0, 0.3, 0), S.dark, M.Slate)
	block(ctx, "ShrinePlatform", Vector3.new(w, 0.8, w), CFrame.new(0, 1, 0), S.light, M.Slate)
	local ph = 7
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local p = Vector3.new(sx * (w / 2 - 1), 1.4, sz * (w / 2 - 1))
			column(ctx, "PillarBase", 0.9, 0.6, p, S.base, M.Slate)
			column(ctx, "Pillar", 0.6, ph, p, IVORY_STONE, M.Marble)
		end
	end
	block(ctx, "Entablature", Vector3.new(w + 0.4, 1, w + 0.4), CFrame.new(0, 1.4 + ph + 0.5, 0), S.light, M.Slate)
	pyramidRoof(ctx, w + 1.6, w * 0.55, 1.4 + ph + 1, color, 0.88)
	ball(ctx, "RoofOrb", 1.2, Vector3.new(0, 1.4 + ph + 1 + w * 0.55, 0), C.gold, M.Metal)
	-- altar stone with an eternal flame in a bronze bowl, flowers around
	block(ctx, "AltarStone", Vector3.new(2.4, 2.2, 2.4), CFrame.new(0, 2.5, 0), S.base, M.Slate)
	column(ctx, "FlameBowl", 1.2, 0.6, Vector3.new(0, 3.6, 0), Pieces.TRIM.emerald, M.Metal)
	ball(ctx, "Flame", 1.4, Vector3.new(0, 4.6, 0), EMBER, M.Neon)
	for i = 0, 3 do
		local a = i * PI / 2 + PI / 4
		ball(
			ctx,
			"Flowers",
			0.9,
			Vector3.new(math.cos(a) * 2.3, 1.75, math.sin(a) * 2.3),
			if i % 2 == 0 then Color3.fromRGB(226, 72, 92) else Color3.fromRGB(246, 206, 70),
			M.SmoothPlastic
		)
	end
	banner(ctx, 0, 1.4 + ph - 0.2, -w / 2 + 0.6, 0, color, 3, "neutral", 2)
	attach(ctx, "Door", Vector3.new(0, 0, -fp.Y / 2 - 1.5))
	workSpots(ctx, { Vector3.new(0, 0, -w / 2 - 2) })
end

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
	end
	return fp.X - 6, fp.Y - 6, 0, 0, 9, false
end

-- Construction stages replace the whole model (G6): 1 foundation (stakes, strings, footings, materials),
-- 2 timber frame + scaffolding, 3 partial walls + roof frame; "complete" = the finished building.
local function buildStage(ctx: Ctx, buildingType: string, level: number, stage: number, color: Color3, fp: Vector2)
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
