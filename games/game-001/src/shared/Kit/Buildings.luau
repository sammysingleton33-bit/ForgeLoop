--!strict
--[[
	Kit/Buildings — building builders by type, construction stages and footprints (CONTRACTS G6/G10).
	Each builder gets (ctx, level, kingdomColor, style, footprint); style is the kingdom silhouette cue
	picked from the colour's hue (Parts.hueStyle).
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
local gableRoof = Pieces.gableRoof
local pyramidRoof = Pieces.pyramidRoof
local towerCap = Pieces.towerCap
local crenellate = Pieces.crenellate
local door = Pieces.door
local window = Pieces.window
local banner = Pieces.banner
local flagpole = Pieces.flagpole
local plinth = Pieces.plinth
local timberBody = Pieces.timberBody
local chimney = Pieces.chimney
local scaffold = Pieces.scaffold
local materialPile = Pieces.materialPile

type Ctx = Parts.Ctx

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
}

function Buildings.footprint(buildingType: BuildingType, level: number): Vector2
	local levels = FOOTPRINTS[buildingType]
	assert(levels, `Kit.footprint: unknown building type {buildingType}`)
	return levels[math.clamp(level, 1, #levels)]
end

-- ------------------------------------------------------------------ buildings

type Builder = (ctx: Ctx, level: number, color: Color3, style: string, fp: Vector2) -> ()

local function workSpots(ctx: Ctx, spots: { Vector3 })
	for i, p in spots do
		attach(ctx, `WorkSpot{i}`, p)
	end
end

local BUILDERS: { [string]: Builder } = {}

BUILDERS.house = function(ctx, level, color, _style, fp)
	local w, d = fp.X - 2, fp.Y - 2
	local h = 9.5 + (level - 1) * 3
	plinth(ctx, w, d, 1.2)
	timberBody(ctx, w, d, 1.2, h)
	gableRoof(ctx, w, d, 1.2 + h, d * 0.55, color, shade(color, 0.6), 1)
	door(ctx, -w * 0.15, -d / 2 - 0.05, 1.2, 4.4, 7.6)
	window(ctx, w * 0.25, 1.2 + 3.4, -d / 2 - 0.05, 0, color)
	window(ctx, w / 2 + 0.05, 1.2 + 3.4, 0, -90, color)
	chimney(ctx, w * 0.3, d * 0.2, 1.2 + h, d * 0.55 + 3)
	attach(ctx, "Door", Vector3.new(-w * 0.15, 0, -d / 2 - 2))
	workSpots(ctx, { Vector3.new(w * 0.3, 0, -d / 2 - 3) })
end

BUILDERS.keep = function(ctx, level, color, style, fp)
	local w = fp.X - 8
	local h = 22 + (level - 1) * 8
	block(ctx, "Base", Vector3.new(w + 3, 2.4, w + 3), CFrame.new(0, 1.2, 0), C.stoneDark, Enum.Material.Cobblestone)
	block(ctx, "Hall", Vector3.new(w, h, w), CFrame.new(0, 2.4 + h / 2, 0), C.stone, Enum.Material.Cobblestone)
	block(
		ctx,
		"Band",
		Vector3.new(w + 0.8, 0.8, w + 0.8),
		CFrame.new(0, 2.4 + h * 0.55, 0),
		C.stoneLight,
		Enum.Material.Slate
	)
	crenellate(ctx, w + 0.6, w + 0.6, 2.4 + h, C.stoneLight)
	-- corner turrets with the kingdom cap
	local t = 3.4
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * (w / 2), sz * (w / 2)
			column(ctx, "Turret", t, h + 6, Vector3.new(x, 2.4, z), C.stoneLight, Enum.Material.Cobblestone)
			towerCap(ctx, style, t * 2, 2.4 + h + 6, color, x, z)
		end
	end
	-- central roof / tower
	if level >= 2 then
		block(
			ctx,
			"Tower",
			Vector3.new(w * 0.45, 12, w * 0.45),
			CFrame.new(0, 2.4 + h + 6, 0),
			C.stone,
			Enum.Material.Cobblestone
		)
		towerCap(ctx, style, w * 0.45, 2.4 + h + 12, color)
		flagpole(ctx, 0, 2.4 + h + 12 + w * 0.6, 0, 8, color)
	else
		pyramidRoof(ctx, w * 0.7, 7, 2.4 + h, color, 1)
		flagpole(ctx, 0, 2.4 + h + 7, 0, 7, color)
	end
	door(ctx, 0, -w / 2 - 0.05, 2.4, 6, 10)
	block(ctx, "Stairs", Vector3.new(10, 1.2, 4), CFrame.new(0, 0.6, -w / 2 - 3), C.stoneLight, Enum.Material.Slate)
	for _, sx in { -1, 1 } do
		banner(ctx, sx * 6.5, 2.4 + 11.5, -w / 2 - 0.1, 0, color, 7)
		for i = 0, 1 do
			window(ctx, sx * w * 0.3, 2.4 + 14 + i * 7, -w / 2 - 0.05, 0, nil)
		end
	end
	attach(ctx, "Door", Vector3.new(0, 0, -w / 2 - 5.5))
	workSpots(ctx, { Vector3.new(-8, 0, -w / 2 - 6), Vector3.new(8, 0, -w / 2 - 6) })
end

BUILDERS.storehouse = function(ctx, _level, color, _style, fp)
	local w, d = fp.X - 3, fp.Y - 3
	local h = 10
	plinth(ctx, w, d, 1.4)
	block(ctx, "Walls", Vector3.new(w, h, d), CFrame.new(0, 1.4 + h / 2, 0), C.woodLight, Enum.Material.WoodPlanks)
	for _, sx in { -1, 0, 1 } do
		block(
			ctx,
			"Post",
			Vector3.new(0.8, h, 0.8),
			CFrame.new(sx * (w / 2), 1.4 + h / 2, -d / 2 - 0.1),
			C.timber,
			Enum.Material.Wood
		)
	end
	gableRoof(ctx, w, d, 1.4 + h, d * 0.5, color, shade(color, 0.6), 1)
	-- big double door + hoist beam with a crate
	block(ctx, "BigDoor", Vector3.new(7, 8, 0.4), CFrame.new(0, 1.4 + 4, -d / 2 - 0.2), C.woodDark, Enum.Material.Wood)
	block(
		ctx,
		"DoorBrace",
		Vector3.new(0.4, 8, 0.5),
		CFrame.new(0, 1.4 + 4, -d / 2 - 0.3),
		C.timber,
		Enum.Material.Wood
	)
	block(
		ctx,
		"HoistBeam",
		Vector3.new(0.6, 0.6, 4),
		CFrame.new(0, 1.4 + h + 1, -d / 2 - 1.6),
		C.timber,
		Enum.Material.Wood
	)
	block(
		ctx,
		"HoistRope",
		Vector3.new(0.15, 3, 0.15),
		CFrame.new(0, 1.4 + h - 0.6, -d / 2 - 3.2),
		C.canvas,
		Enum.Material.Fabric
	)
	block(
		ctx,
		"HoistCrate",
		Vector3.new(1.8, 1.6, 1.8),
		CFrame.new(0, 1.4 + h - 2.8, -d / 2 - 3.2),
		C.wood,
		Enum.Material.WoodPlanks
	)
	for i = 0, 3 do
		ball(ctx, "Sack", 1.6, Vector3.new(-w / 2 + 1.5 + i * 1.3, 0.7, -d / 2 - 2), C.canvas, Enum.Material.Fabric)
	end
	block(
		ctx,
		"Crate",
		Vector3.new(2, 2, 2),
		CFrame.new(w / 2 - 1.5, 1, -d / 2 - 2.5),
		C.wood,
		Enum.Material.WoodPlanks
	)
	banner(ctx, w * 0.3, 1.4 + h - 0.8, -d / 2 - 0.1, 0, color, 4)
	attach(ctx, "Door", Vector3.new(0, 0, -d / 2 - 2.5))
	attach(ctx, "DropOff", Vector3.new(-3, 0, -d / 2 - 3))
	workSpots(ctx, { Vector3.new(3, 0, -d / 2 - 3) })
end

BUILDERS.farm = function(ctx, level, color, _style, fp)
	local w, d = fp.X, fp.Y
	-- field on the left two thirds: soil rows with wheat
	local fw = w * 0.62
	local fx = -w / 2 + fw / 2
	block(ctx, "Field", Vector3.new(fw, 0.5, d - 2), CFrame.new(fx, 0.25, 0), C.soil, Enum.Material.Ground)
	local rows = 6 + level
	for i = 0, rows - 1 do
		local z = -d / 2 + 2 + (i + 0.5) * (d - 4) / rows
		block(
			ctx,
			"Wheat",
			Vector3.new(fw - 2, 2.6, (d - 4) / rows * 0.6),
			CFrame.new(fx, 0.5 + 1.3, z),
			C.wheat,
			Enum.Material.Grass
		)
	end
	-- fence along the field
	for _, sz in { -1, 1 } do
		block(
			ctx,
			"FenceRail",
			Vector3.new(fw, 0.3, 0.3),
			CFrame.new(fx, 2.2, sz * (d / 2 - 0.5)),
			C.wood,
			Enum.Material.Wood
		)
		for i = 0, 4 do
			block(
				ctx,
				"FencePost",
				Vector3.new(0.4, 2.8, 0.4),
				CFrame.new(-w / 2 + i * fw / 4, 1.4, sz * (d / 2 - 0.5)),
				C.woodDark,
				Enum.Material.Wood
			)
		end
	end
	-- farmhouse on the right
	local hw, hd = w * 0.32, d * 0.5
	local hx = w / 2 - hw / 2
	block(
		ctx,
		"FarmPlinth",
		Vector3.new(hw + 0.6, 1, hd + 0.6),
		CFrame.new(hx, 0.5, -d * 0.18),
		C.stone,
		Enum.Material.Cobblestone
	)
	block(ctx, "FarmWalls", Vector3.new(hw, 8.5, hd), CFrame.new(hx, 1 + 4.25, -d * 0.18), C.plaster)
	for _, sx in { -1, 1 } do
		block(
			ctx,
			"Post",
			Vector3.new(0.6, 8.5, 0.6),
			CFrame.new(hx + sx * hw / 2, 1 + 4.25, -d * 0.18 - hd / 2),
			C.timber,
			Enum.Material.Wood
		)
	end
	gableRoof(ctx, hw, hd, 9.5, hd * 0.6, C.thatch, C.thatchDark, nil, hx, -d * 0.18)
	door(ctx, hx, -d * 0.18 - hd / 2 - 0.05, 1, 4.4, 7.6)
	block(ctx, "Haybale", Vector3.new(2.4, 2, 2.4), CFrame.new(hx, 1, d * 0.28), C.wheat, Enum.Material.Grass)
	banner(ctx, hx + hw / 2 - 0.2, 8.5, -d * 0.18 - hd / 2 - 0.1, 0, color, 3.5)
	attach(ctx, "Door", Vector3.new(hx, 0, -d * 0.18 - hd / 2 - 2))
	workSpots(
		ctx,
		{ Vector3.new(fx - fw * 0.25, 0, -d * 0.2), Vector3.new(fx + fw * 0.25, 0, d * 0.2), Vector3.new(fx, 0, 0) }
	)
end

BUILDERS.lumbercamp = function(ctx, _level, color, _style, fp)
	local w, d = fp.X - 2, fp.Y - 2
	-- open shed: posts + lean-to roof, log piles, chopping stump
	block(
		ctx,
		"ShedFloor",
		Vector3.new(w * 0.55, 0.6, d * 0.7),
		CFrame.new(-w * 0.2, 0.3, d * 0.1),
		C.woodDark,
		Enum.Material.WoodPlanks
	)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local hh = if sz > 0 then 9 else 7
			block(
				ctx,
				"ShedPost",
				Vector3.new(0.7, hh, 0.7),
				CFrame.new(-w * 0.2 + sx * w * 0.26, hh / 2, d * 0.1 + sz * d * 0.33),
				C.wood,
				Enum.Material.Wood
			)
		end
	end
	wedge(
		ctx,
		"ShedRoof",
		Vector3.new(w * 0.62, 2.4, d * 0.8),
		CFrame.new(-w * 0.2, 8.2, d * 0.1),
		color,
		Enum.Material.WoodPlanks,
		0.9
	)
	for row = 0, 2 do
		for i = 0, 3 - row do
			log(
				ctx,
				"Log",
				0.75,
				7,
				CFrame.new(w * 0.25 + (i - 1.5 + row * 0.5) * 1.5, 0.75 + row * 1.3, -d * 0.2)
					* CFrame.Angles(0, math.rad(90), 0),
				C.bark
			)
		end
	end
	column(ctx, "Stump", 1.1, 1.4, Vector3.new(w * 0.25, 0, d * 0.25), C.bark, Enum.Material.Wood)
	block(
		ctx,
		"AxeHandle",
		Vector3.new(0.25, 2.2, 0.25),
		CFrame.new(w * 0.25, 2.3, d * 0.25) * CFrame.Angles(0, 0, math.rad(20)),
		C.wood,
		Enum.Material.Wood
	)
	block(
		ctx,
		"AxeHead",
		Vector3.new(0.9, 0.6, 0.2),
		CFrame.new(w * 0.25 - 0.3, 1.5, d * 0.25),
		C.iron,
		Enum.Material.Metal
	)
	flagpole(ctx, -w / 2 + 1, 0, -d / 2 + 1, 9, color)
	attach(ctx, "Door", Vector3.new(-w * 0.2, 0, -d / 2 - 2.5))
	attach(ctx, "DropOff", Vector3.new(w * 0.25, 0, -d / 2 - 2))
	workSpots(ctx, { Vector3.new(w * 0.25 + 2, 0, d * 0.25), Vector3.new(-w * 0.2, 0, d * 0.1) })
end

BUILDERS.quarry = function(ctx, _level, color, _style, fp)
	local w, d = fp.X - 2, fp.Y - 2
	-- stepped cut stone face at the back, cut blocks, a crane
	for i = 0, 2 do
		block(
			ctx,
			"QuarryStep",
			Vector3.new(w - i * 3, 3 + i * 2.5, d * 0.35 - i * 1.5),
			CFrame.new(0, (3 + i * 2.5) / 2, d * 0.3 + i * 1.2),
			if i % 2 == 0 then C.stoneLight else C.stone,
			Enum.Material.Slate
		)
	end
	for i = 0, 3 do
		block(
			ctx,
			"CutBlock",
			Vector3.new(2.4, 1.8, 2.4),
			CFrame.new(-w * 0.3 + i * 2.8, 0.9 + (i % 2) * 1.8, -d * 0.15),
			C.stoneLight,
			Enum.Material.Slate
		)
	end
	block(ctx, "CraneMast", Vector3.new(0.8, 11, 0.8), CFrame.new(w * 0.35, 5.5, -d * 0.2), C.wood, Enum.Material.Wood)
	block(
		ctx,
		"CraneJib",
		Vector3.new(7, 0.6, 0.6),
		CFrame.new(w * 0.35 - 3, 10.5, -d * 0.2),
		C.wood,
		Enum.Material.Wood
	)
	block(
		ctx,
		"CraneRope",
		Vector3.new(0.15, 5, 0.15),
		CFrame.new(w * 0.35 - 6, 8, -d * 0.2),
		C.canvas,
		Enum.Material.Fabric
	)
	flagpole(ctx, -w / 2 + 1, 0, -d / 2 + 1, 8, color)
	attach(ctx, "Door", Vector3.new(0, 0, -d / 2 - 1))
	attach(ctx, "DropOff", Vector3.new(-w * 0.3, 0, -d / 2))
	workSpots(ctx, { Vector3.new(-w * 0.2, 0, d * 0.08), Vector3.new(w * 0.15, 0, d * 0.08) })
end

BUILDERS.barracks = function(ctx, level, color, style, fp)
	local w, d = fp.X - 2, fp.Y - 2
	local h = 10
	plinth(ctx, w, d, 1.4)
	block(ctx, "StoneFloor", Vector3.new(w, 5, d), CFrame.new(0, 1.4 + 2.5, 0), C.stone, Enum.Material.Cobblestone)
	timberBody(ctx, w, d, 6.4, h - 4)
	gableRoof(ctx, w, d, 1.4 + h + 1, d * 0.45, color, shade(color, 0.6), 1)
	door(ctx, 0, -d / 2 - 0.05, 1.4, 5.5, 8.5)
	for _, sx in { -1, 1 } do
		banner(ctx, sx * 5, 1.4 + 8.5, -d / 2 - 0.1, 0, color, 5)
		window(ctx, sx * w * 0.32, 7.6, -d / 2 - 0.05, 0, color)
	end
	-- watch turret on one end
	column(ctx, "Turret", 3, h + 8, Vector3.new(w / 2, 0, -d / 2), C.stoneLight, Enum.Material.Cobblestone)
	towerCap(ctx, style, 6, h + 8, color, w / 2, -d / 2)
	-- weapon rack + training dummy
	block(ctx, "Rack", Vector3.new(5, 0.4, 0.4), CFrame.new(-w / 2 + 3, 3, -d / 2 - 3), C.wood, Enum.Material.Wood)
	for i = 0, 3 do
		block(
			ctx,
			"Spear",
			Vector3.new(0.2, 5, 0.2),
			CFrame.new(-w / 2 + 1.2 + i * 1.2, 2.5, -d / 2 - 3.2) * CFrame.Angles(math.rad(-10), 0, 0),
			C.wood,
			Enum.Material.Wood
		)
	end
	column(ctx, "DummyPost", 0.25, 5, Vector3.new(w / 2 - 4, 0, -d / 2 - 6), C.wood, Enum.Material.Wood)
	ball(ctx, "DummyBody", 2.2, Vector3.new(w / 2 - 4, 4, -d / 2 - 6), C.wheat, Enum.Material.Grass)
	attach(ctx, "Door", Vector3.new(0, 0, -d / 2 - 2.5))
	attach(ctx, "Rally", Vector3.new(0, 0, -d / 2 - 10))
	workSpots(ctx, { Vector3.new(w / 2 - 4, 0, -d / 2 - 8) })
	if level >= 2 then
		flagpole(ctx, -w / 2 + 1, 1.4 + h + 1, 0, 8, color)
	end
end

BUILDERS.watchtower = function(ctx, level, color, style, fp)
	local w = fp.X - 4
	local h = 24 + (level - 1) * 6
	block(ctx, "Base", Vector3.new(w + 2, 2, w + 2), CFrame.new(0, 1, 0), C.stoneDark, Enum.Material.Cobblestone)
	block(ctx, "Shaft", Vector3.new(w, h, w), CFrame.new(0, 2 + h / 2, 0), C.stone, Enum.Material.Cobblestone)
	block(
		ctx,
		"Corbel",
		Vector3.new(w + 2, 1.2, w + 2),
		CFrame.new(0, 2 + h + 0.6, 0),
		C.stoneLight,
		Enum.Material.Slate
	)
	crenellate(ctx, w + 2, w + 2, 2 + h + 1.2, C.stoneLight)
	towerCap(ctx, style, w * 0.7, 2 + h + 1.2 + 2.2, color)
	door(ctx, 0, -w / 2 - 0.05, 2, 4.4, 7.6)
	banner(ctx, 0, 2 + h - 3, -w / 2 - 0.1, 0, color, 6)
	for _, f in { 90, -90, 180 } do
		local r = math.rad(f)
		window(ctx, math.sin(r) * (-w / 2 - 0.05), 2 + h * 0.55, math.cos(r) * (-w / 2 - 0.05), f, nil)
	end
	attach(ctx, "Door", Vector3.new(0, 0, -w / 2 - 2.5))
	workSpots(ctx, { Vector3.new(0, 0, -w / 2 - 4) })
end

BUILDERS.wall = function(ctx, _level, color, _style, fp)
	local w, d = fp.X, fp.Y
	local h = 18
	block(ctx, "Batter", Vector3.new(w, 3, d + 1.5), CFrame.new(0, 1.5, 0), C.stoneDark, Enum.Material.Cobblestone)
	block(ctx, "Curtain", Vector3.new(w, h, d), CFrame.new(0, 3 + h / 2, 0), C.stone, Enum.Material.Cobblestone)
	block(
		ctx,
		"Walkway",
		Vector3.new(w, 0.6, d + 0.8),
		CFrame.new(0, 3 + h + 0.3, 0),
		C.stoneLight,
		Enum.Material.Slate
	)
	crenellate(ctx, w, d + 0.8, 3 + h + 0.6, C.stoneLight)
	banner(ctx, 0, 3 + h - 1, -d / 2 - 0.1, 0, color, 6)
	attach(ctx, "Door", Vector3.new(0, 0, -d / 2 - 2))
end

BUILDERS.gate = function(ctx, _level, color, style, fp)
	local w, d = fp.X, fp.Y
	local h = 20
	local pw = (w - 14) / 2
	for _, sx in { -1, 1 } do
		local x = sx * (7 + pw / 2)
		block(
			ctx,
			"GateTower",
			Vector3.new(pw, h + 4, d),
			CFrame.new(x, (h + 4) / 2, 0),
			C.stone,
			Enum.Material.Cobblestone
		)
		crenellate(ctx, pw, d, h + 4, C.stoneLight, x, 0)
		banner(ctx, x, h - 2, -d / 2 - 0.1, 0, color, 7)
	end
	block(
		ctx,
		"Lintel",
		Vector3.new(14, h - 15, d),
		CFrame.new(0, 15 + (h - 15) / 2, 0),
		C.stone,
		Enum.Material.Cobblestone
	)
	block(ctx, "Portcullis", Vector3.new(13.6, 0.5, 0.5), CFrame.new(0, 14.6, -d / 2 + 1), C.iron, Enum.Material.Metal)
	for i = 0, 6 do
		block(
			ctx,
			"PortcullisBar",
			Vector3.new(0.4, 2.5, 0.4),
			CFrame.new(-6 + i * 2, 13.6, -d / 2 + 1),
			C.iron,
			Enum.Material.Metal
		)
	end
	towerCap(ctx, style, 10, h, color)
	attach(ctx, "Door", Vector3.new(0, 0, -d / 2 - 2))
	attach(ctx, "Rally", Vector3.new(0, 0, d / 2 + 4))
end

-- Construction stages replace the whole model (G6): 1 foundation, 2 frame, 3 walls; "complete" = full.
local function buildStage(ctx: Ctx, buildingType: string, level: number, stage: number, color: Color3, fp: Vector2)
	local w, d = fp.X - 2, fp.Y - 2
	plinth(ctx, w, d, 1.2)
	materialPile(ctx, -w / 2 + 3, -d / 2 - 3)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			column(
				ctx,
				"Stake",
				0.2,
				2,
				Vector3.new(sx * (w / 2 + 0.6), 1.2, sz * (d / 2 + 0.6)),
				C.woodLight,
				Enum.Material.Wood
			)
		end
	end
	if stage >= 2 then
		local h = (if buildingType == "keep" or buildingType == "watchtower" then 16 else 9) + (level - 1) * 3
		for i = 0, 2 do
			for _, sz in { -1, 1 } do
				block(
					ctx,
					"FramePost",
					Vector3.new(0.7, h, 0.7),
					CFrame.new(-w / 2 + i * w / 2, 1.2 + h / 2, sz * d / 2),
					C.timber,
					Enum.Material.Wood
				)
			end
		end
		block(ctx, "FrameBeam", Vector3.new(w, 0.6, 0.6), CFrame.new(0, 1.2 + h, -d / 2), C.timber, Enum.Material.Wood)
		block(ctx, "FrameBeam", Vector3.new(w, 0.6, 0.6), CFrame.new(0, 1.2 + h, d / 2), C.timber, Enum.Material.Wood)
		scaffold(ctx, w, d, h)
		if stage >= 3 then
			local wallColor = if buildingType == "keep"
					or buildingType == "watchtower"
					or buildingType == "wall"
					or buildingType == "gate"
				then C.stone
				else C.plaster
			block(
				ctx,
				"WallsPartial",
				Vector3.new(w - 0.6, h * 0.7, d - 0.6),
				CFrame.new(0, 1.2 + h * 0.35, 0),
				wallColor,
				Enum.Material.SmoothPlastic
			)
		end
	end
	flagpole(ctx, w / 2 + 2, 0, -d / 2 - 2, 6, color)
	attach(ctx, "Door", Vector3.new(0, 0, -d / 2 - 2))
	workSpots(ctx, { Vector3.new(-w / 4, 0, -d / 2 - 2.5), Vector3.new(w / 4, 0, -d / 2 - 2.5) })
	if buildingType == "storehouse" then
		attach(ctx, "DropOff", Vector3.new(-3, 0, -d / 2 - 3))
	elseif buildingType == "barracks" or buildingType == "gate" then
		attach(ctx, "Rally", Vector3.new(0, 0, -d / 2 - 10))
	end
end

function Buildings.build(buildingType: string, level: number, stage: number | string, kingdomColor: Color3): Model
	local builder = BUILDERS[buildingType]
	assert(builder, `Kit.build: unknown building type {buildingType}`)
	local fp = Buildings.footprint(buildingType, level)
	local stageName = if stage == "complete" then "complete" else tostring(stage)
	local ctx = newModel(`{buildingType}_L{level}_{stageName}`, fp)
	ctx.model:SetAttribute("KitType", buildingType)
	ctx.model:SetAttribute("KitLevel", level)
	ctx.model:SetAttribute("KitStage", stageName)
	if stage == "complete" then
		builder(ctx, level, kingdomColor, hueStyle(kingdomColor), fp)
	else
		assert(type(stage) == "number" and stage >= 1 and stage <= 3, 'Kit.build: stage must be 1..3 or "complete"')
		buildStage(ctx, buildingType, level, stage :: number, kingdomColor, fp)
	end
	return ctx.model
end

return Buildings
