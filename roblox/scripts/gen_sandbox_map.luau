--[[
	gen_sandbox_map — writes the AI Kingdoms sandbox map as Rojo model files (headless; Lune).

		lune run roblox/scripts/gen_sandbox_map.luau            # (re)write games/sandbox/map/*.model.json
		lune run roblox/scripts/gen_sandbox_map.luau --check    # exit 1 if the committed files are stale

	The map is generated, not hand-edited: four kingdoms are one layout rotated in 90° steps, so a
	layout change touches one table here. Output is deterministic (sorted keys, fixed number format),
	so `--check` (run by roblox/scripts/check.sh) can prove the committed files match this script.

	Rojo trap this avoids: a "Position" property in a .model.json is accepted by `rojo build` but not
	written to the place (the part lands at the origin; Rojo 7.7.1, observed 2026-10-12). Every part
	gets an explicit CFrame instead, and check_place.luau verifies each anchor sits inside its
	kingdom's territory.

	Tags and attributes come from games/sandbox/config/Map.luau (the map contract).
	Layout (studs; +Y up; world centre = lobby plaza):
	  ground 720 x 720; plaza 64 x 64 with the lobby SpawnLocation; four roads to the kingdom gates;
	  kingdom k centred KINGDOM_DISTANCE from the centre on its axis, territory 170 x 170 with a
	  palisade and a gate facing the plaza; neutral gold mines on the four diagonals.
	Kingdom-local frame: +Z points away from the plaza (outward), the gate is at z = -85.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local Map = require("../../games/sandbox/config/Map")

local TAGS, ATTR = Map.TAGS, Map.ATTR

local function scriptDir(): string
	local source = string.gsub(debug.info(1, "s"), "^@", "")
	if string.sub(source, 1, 1) ~= "/" then
		source = process.cwd .. "/" .. source
	end
	return (string.gsub(source, "/[^/]*$", ""))
end

local ROOT = scriptDir() .. "/../.."
local OUT_DIR = ROOT .. "/games/sandbox/map"

local KINGDOM_DISTANCE = 210
local HALF = 85 -- half the kingdom territory side
local PAD_TOP = 0.4 -- territory pad surface height
local GATE_HALF = 12

-- Kingdom ids map to rotations about +Y: South 0°, East 90°, North 180°, West 270°.
local KINGDOM_TURNS = { South = 0, East = 1, North = 2, West = 3 }
local BANNER = {
	South = { 0.77, 0.16, 0.16 },
	East = { 0.16, 0.36, 0.78 },
	North = { 0.18, 0.58, 0.26 },
	West = { 0.86, 0.68, 0.14 },
}

local COLORS = {
	ground = { 0.42, 0.6, 0.3 },
	territory = { 0.38, 0.55, 0.27 },
	stone = { 0.55, 0.55, 0.53 },
	darkStone = { 0.4, 0.4, 0.4 },
	road = { 0.6, 0.57, 0.5 },
	wood = { 0.45, 0.31, 0.18 },
	planks = { 0.62, 0.47, 0.3 },
	roof = { 0.48, 0.2, 0.15 },
	leaves = { 0.24, 0.47, 0.2 },
	forestFloor = { 0.27, 0.42, 0.2 },
	soil = { 0.42, 0.3, 0.2 },
	crops = { 0.72, 0.68, 0.3 },
	plot = { 0.82, 0.74, 0.55 },
	gold = { 1, 0.78, 0.2 },
	water = { 0.25, 0.45, 0.7 },
}

-- ------------------------------------------------------------------ math (3x3 rotations, rows)
type Mat = { { number } }
type Vec = { number }

local IDENTITY: Mat = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }

local function rotY(radians: number): Mat
	local c, s = math.cos(radians), math.sin(radians)
	return { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } }
end

-- Exact matrices for quarter turns (no 6.1e-17 noise in the files).
local function quarterTurns(n: number): Mat
	local cs = ({ { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } })[n % 4 + 1]
	local c, s = cs[1], cs[2]
	return { { c, 0, s }, { 0, 1, 0 }, { -s, 0, c } }
end

-- Cylinders extend along their X axis; this stands one upright (X -> world Y).
local UPRIGHT: Mat = { { 0, -1, 0 }, { 1, 0, 0 }, { 0, 0, 1 } }

local function mul(a: Mat, b: Mat): Mat
	local out = {}
	for i = 1, 3 do
		out[i] = {}
		for j = 1, 3 do
			out[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return out
end

local function apply(m: Mat, v: Vec): Vec
	return {
		m[1][1] * v[1] + m[1][2] * v[2] + m[1][3] * v[3],
		m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] * v[3],
		m[3][1] * v[1] + m[3][2] * v[2] + m[3][3] * v[3],
	}
end

-- A frame places local coordinates into the world: world = origin + rot * local.
type Frame = { origin: Vec, rot: Mat }

local WORLD: Frame = { origin = { 0, 0, 0 }, rot = IDENTITY }

local function kingdomFrame(kingdomId: string): Frame
	local rot = quarterTurns(KINGDOM_TURNS[kingdomId])
	return { origin = apply(rot, { 0, 0, KINGDOM_DISTANCE }), rot = rot }
end

-- ------------------------------------------------------------------ instance nodes
type Node = {
	name: string,
	className: string,
	properties: { [string]: any },
	attributes: { [string]: any }?,
	children: { Node }?,
}

type PartSpec = {
	size: Vec,
	at: Vec, -- local position
	color: Vec?,
	material: string?,
	rot: Mat?, -- local rotation, applied before the frame's rotation
	className: string?,
	shape: string?,
	tags: { string }?,
	attributes: { [string]: any }?,
	invisible: boolean?, -- transparent, no collision, no queries/touches
	transparency: number?,
	canCollide: boolean?,
	properties: { [string]: any }?,
}

local function part(frame: Frame, name: string, spec: PartSpec): Node
	local position = apply(frame.rot, spec.at)
	position = { position[1] + frame.origin[1], position[2] + frame.origin[2], position[3] + frame.origin[3] }
	local rot = mul(frame.rot, spec.rot or IDENTITY)
	local properties: { [string]: any } = {
		Anchored = true,
		Size = spec.size,
		CFrame = { CFrame = { position = position, orientation = rot } },
		Color = spec.color or COLORS.stone,
		Material = spec.material or "SmoothPlastic",
		TopSurface = "Smooth",
		BottomSurface = "Smooth",
	}
	if spec.shape then
		properties.Shape = spec.shape
	end
	if spec.tags then
		properties.Tags = spec.tags
	end
	if spec.invisible then
		properties.Transparency = 1
		properties.CanCollide = false
		properties.CanQuery = false
		properties.CanTouch = false
		properties.CastShadow = false
	end
	if spec.transparency then
		properties.Transparency = spec.transparency
	end
	if spec.canCollide ~= nil then
		properties.CanCollide = spec.canCollide
	end
	for key, value in spec.properties or {} do
		properties[key] = value
	end
	return {
		name = name,
		className = spec.className or "Part",
		properties = properties,
		attributes = spec.attributes,
	}
end

local function container(className: string, name: string, children: { Node }, extra: { [string]: any }?): Node
	local node: Node = { name = name, className = className, properties = {}, children = children }
	if extra then
		node.properties = extra.properties or {}
		node.attributes = extra.attributes
	end
	return node
end

-- ------------------------------------------------------------------ decorations
local function tree(frame: Frame, children: { Node }, x: number, z: number, scale: number, baseY: number)
	local trunkHeight = 10 * scale
	table.insert(
		children,
		part(frame, "TreeTrunk", {
			shape = "Cylinder",
			size = { trunkHeight, 2.2 * scale, 2.2 * scale },
			at = { x, baseY - 0.3 + trunkHeight / 2, z }, -- sunk 0.3 so it never floats
			rot = UPRIGHT,
			color = COLORS.wood,
			material = "Wood",
		})
	)
	local crown = 9 * scale
	table.insert(
		children,
		part(frame, "TreeCrown", {
			shape = "Ball",
			size = { crown, crown, crown },
			at = { x, baseY + trunkHeight + crown * 0.3, z },
			color = COLORS.leaves,
			material = "LeafyGrass",
		})
	)
end

local function rock(frame: Frame, children: { Node }, name: string, at: Vec, size: Vec, degrees: number, color: Vec?)
	table.insert(
		children,
		part(frame, name, {
			size = size,
			at = at,
			rot = rotY(math.rad(degrees)),
			color = color or COLORS.darkStone,
			material = "Rock",
		})
	)
end

-- ------------------------------------------------------------------ kingdom
local function kingdom(kingdomId: string): Node
	local f = kingdomFrame(kingdomId)
	local banner = BANNER[kingdomId]
	local children: { Node } = {}
	local decor: { Node } = {}
	local function add(node: Node)
		table.insert(children, node)
	end
	local function kAttr(extra: { [string]: any }?): { [string]: any }
		local attrs: { [string]: any } = { [ATTR.KingdomId] = kingdomId }
		for key, value in extra or {} do
			attrs[key] = value
		end
		return attrs
	end

	-- Territory pad and palisade with a gate facing the plaza (z = -HALF).
	add(part(f, "Territory", {
		size = { HALF * 2, PAD_TOP, HALF * 2 },
		at = { 0, PAD_TOP / 2, 0 },
		color = COLORS.territory,
		material = "Grass",
	}))
	local wallH, wallT = 12, 2
	local wallY = PAD_TOP + wallH / 2
	local sideLen = HALF - GATE_HALF
	local walls = {
		{ "WallBack", { HALF * 2 + wallT, wallH, wallT }, { 0, wallY, HALF } },
		{ "WallLeft", { wallT, wallH, HALF * 2 }, { -HALF, wallY, 0 } },
		{ "WallRight", { wallT, wallH, HALF * 2 }, { HALF, wallY, 0 } },
		{ "WallFrontLeft", { sideLen, wallH, wallT }, { -(GATE_HALF + sideLen / 2), wallY, -HALF } },
		{ "WallFrontRight", { sideLen, wallH, wallT }, { GATE_HALF + sideLen / 2, wallY, -HALF } },
	}
	for _, wall in walls do
		table.insert(decor, part(f, wall[1], { size = wall[2], at = wall[3], color = COLORS.wood, material = "Wood" }))
	end
	for _, side in { -1, 1 } do
		local x = side * (GATE_HALF + 3.5)
		table.insert(
			decor,
			part(f, "GateTower", {
				size = { 7, 20, 7 },
				at = { x, PAD_TOP + 10, -HALF },
				color = COLORS.stone,
				material = "Cobblestone",
			})
		)
		table.insert(
			decor,
			part(f, "GateBanner", {
				size = { 5, 7, 0.4 },
				at = { x, PAD_TOP + 14, -HALF - 3.8 },
				color = banner,
				material = "Fabric",
			})
		)
	end

	-- Keep (the match target) with towers and a banner over the door.
	local keepZ = 50
	add(part(f, "Keep", {
		size = { 36, 16, 28 },
		at = { 0, PAD_TOP + 8, keepZ },
		color = COLORS.stone,
		material = "Cobblestone",
		tags = { TAGS.Keep },
		attributes = kAttr(),
	}))
	table.insert(
		decor,
		part(f, "KeepHall", {
			size = { 22, 12, 18 },
			at = { 0, PAD_TOP + 22, keepZ },
			color = COLORS.stone,
			material = "Cobblestone",
		})
	)
	table.insert(
		decor,
		part(f, "KeepRoof", {
			size = { 24, 1.5, 20 },
			at = { 0, PAD_TOP + 28.75, keepZ },
			color = banner,
			material = "Slate",
		})
	)
	for _, corner in { { -18, -14 }, { 18, -14 }, { -18, 14 }, { 18, 14 } } do
		table.insert(
			decor,
			part(f, "KeepTower", {
				size = { 8, 28, 8 },
				at = { corner[1], PAD_TOP + 14, keepZ + corner[2] },
				color = COLORS.darkStone,
				material = "Cobblestone",
			})
		)
		table.insert(
			decor,
			part(f, "KeepTowerCap", {
				size = { 9.5, 1.5, 9.5 },
				at = { corner[1], PAD_TOP + 28.75, keepZ + corner[2] },
				color = banner,
				material = "Slate",
			})
		)
	end
	table.insert(
		decor,
		part(f, "KeepBanner", {
			size = { 8, 10, 0.4 },
			at = { 0, PAD_TOP + 9, keepZ - 14.4 },
			color = banner,
			material = "Fabric",
		})
	)

	-- Ruler dais (ruler spawn) in front of the keep, the road from the gate to it.
	add(part(f, "RulerDais", {
		size = { 12, 1, 12 },
		at = { 0, PAD_TOP + 0.5, 26 },
		color = COLORS.stone,
		material = "Cobblestone",
		tags = { TAGS.RulerSpawn, TAGS.Spawn },
		attributes = kAttr(),
	}))
	local roadStart, roadEnd = -HALF, 20
	table.insert(
		decor,
		part(f, "Road", {
			size = { 12, 0.2, roadEnd - roadStart },
			at = { 0, PAD_TOP + 0.1, (roadStart + roadEnd) / 2 },
			color = COLORS.road,
			material = "Cobblestone",
		})
	)

	-- Economy: stockpile, villager homes, villager spawn, resource nodes, build plots, rally point.
	add(part(f, "Stockpile", {
		size = { 12, 1, 12 },
		at = { -26, PAD_TOP + 0.5, 10 },
		color = COLORS.planks,
		material = "WoodPlanks",
		tags = { TAGS.Stockpile },
		attributes = kAttr(),
	}))
	table.insert(
		decor,
		part(
			f,
			"Crate",
			{ size = { 3, 3, 3 }, at = { -29, PAD_TOP + 2.5, 7 }, color = COLORS.planks, material = "WoodPlanks" }
		)
	)
	table.insert(
		decor,
		part(
			f,
			"Crate",
			{ size = { 3, 3, 3 }, at = { -23, PAD_TOP + 2.5, 13 }, color = COLORS.planks, material = "WoodPlanks" }
		)
	)
	for i, z in { -2, 22, 46 } do
		table.insert(
			decor,
			part(
				f,
				`House{i}`,
				{ size = { 10, 7, 9 }, at = { -64, PAD_TOP + 3.5, z }, color = COLORS.planks, material = "WoodPlanks" }
			)
		)
		table.insert(
			decor,
			part(
				f,
				`House{i}Roof`,
				{ size = { 11.5, 1.2, 10.5 }, at = { -64, PAD_TOP + 7.6, z }, color = COLORS.roof, material = "Slate" }
			)
		)
		table.insert(
			decor,
			part(
				f,
				`House{i}Ridge`,
				{ size = { 7, 1.2, 6 }, at = { -64, PAD_TOP + 8.8, z }, color = COLORS.roof, material = "Slate" }
			)
		)
	end
	add(part(f, "VillagerSpawn", {
		size = { 6, 1, 6 },
		at = { -46, PAD_TOP + 0.5, 22 },
		invisible = true,
		tags = { TAGS.VillagerSpawn },
		attributes = kAttr(),
	}))

	add(part(f, "Forest", {
		size = { 30, 0.2, 30 },
		at = { 55, PAD_TOP + 0.1, 50 },
		color = COLORS.forestFloor,
		material = "LeafyGrass",
		tags = { TAGS.ResourceNode },
		attributes = kAttr({ [ATTR.Resource] = "Wood", [ATTR.NodeId] = `{kingdomId}-Wood-1` }),
	}))
	for _, t in { { -9, -9, 1 }, { 1, -11, 0.85 }, { 10, -6, 1.1 }, { -10, 4, 0.9 }, { 3, 5, 1.15 }, { 10, 10, 0.95 } } do
		tree(f, decor, 55 + t[1], 50 + t[2], t[3], PAD_TOP + 0.2)
	end

	add(part(f, "Quarry", {
		size = { 26, 0.2, 26 },
		at = { 60, PAD_TOP + 0.1, 6 },
		color = COLORS.darkStone,
		material = "Slate",
		tags = { TAGS.ResourceNode },
		attributes = kAttr({ [ATTR.Resource] = "Stone", [ATTR.NodeId] = `{kingdomId}-Stone-1` }),
	}))
	rock(f, decor, "QuarryRock", { 55, PAD_TOP + 3, 2 }, { 8, 6, 7 }, 15)
	rock(f, decor, "QuarryRock", { 65, PAD_TOP + 4, 8 }, { 9, 8, 8 }, 40)
	rock(f, decor, "QuarryRock", { 58, PAD_TOP + 2, 13 }, { 6, 4, 5 }, 70)
	rock(f, decor, "QuarryRock", { 66, PAD_TOP + 1.5, -3 }, { 5, 3, 4 }, 25, COLORS.stone)

	add(part(f, "Farm", {
		size = { 32, 0.2, 24 },
		at = { -45, PAD_TOP + 0.1, -52 },
		color = COLORS.soil,
		material = "Ground",
		tags = { TAGS.ResourceNode },
		attributes = kAttr({ [ATTR.Resource] = "Food", [ATTR.NodeId] = `{kingdomId}-Food-1` }),
	}))
	for _, dz in { -8, -4, 0, 4, 8 } do
		table.insert(
			decor,
			part(f, "CropRow", {
				size = { 29, 1.2, 2 },
				at = { -45, PAD_TOP + 0.8, -52 + dz },
				color = COLORS.crops,
				material = "LeafyGrass",
			})
		)
	end

	for i, p in { { 28, -22 }, { 28, -52 }, { -26, -20 } } do
		add(part(f, "BuildPlot", {
			size = { 16, 0.3, 16 },
			at = { p[1], PAD_TOP + 0.15, p[2] },
			color = COLORS.plot,
			material = "Sand",
			tags = { TAGS.BuildPlot },
			attributes = kAttr({ [ATTR.PlotId] = `{kingdomId}-Plot-{i}` }),
		}))
		for _, c in { { -7.5, -7.5 }, { 7.5, -7.5 }, { -7.5, 7.5 }, { 7.5, 7.5 } } do
			table.insert(
				decor,
				part(f, "PlotPost", {
					size = { 1, 3, 1 },
					at = { p[1] + c[1], PAD_TOP + 1.5, p[2] + c[2] },
					color = COLORS.wood,
					material = "Wood",
				})
			)
		end
	end

	add(part(f, "RallyPoint", {
		size = { 10, 1, 10 },
		at = { 0, PAD_TOP + 0.5, -68 },
		invisible = true,
		tags = { TAGS.RallyPoint },
		attributes = kAttr(),
	}))

	table.insert(children, container("Folder", "Decor", decor))
	return container("Model", `Kingdom_{kingdomId}`, children, {
		properties = { Tags = { TAGS.Kingdom } },
		attributes = kAttr(),
	})
end

-- ------------------------------------------------------------------ neutral world
local SIZE = 720

local function ground(): Node
	return part(WORLD, "Ground", {
		size = { SIZE, 4, SIZE },
		at = { 0, -2, 0 },
		color = COLORS.ground,
		material = "Grass",
	})
end

local function playArea(): Node
	local children = {
		part(WORLD, "Bounds", {
			size = { SIZE, 240, SIZE },
			at = { 0, 118, 0 },
			invisible = true,
			tags = { TAGS.PlayArea },
		}),
	}
	for _, edge in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local alongX = edge[1] == 0
		table.insert(
			children,
			part(WORLD, "EdgeWall", {
				size = if alongX then { SIZE, 240, 4 } else { 4, 240, SIZE },
				at = { edge[1] * (SIZE / 2 + 2), 118, edge[2] * (SIZE / 2 + 2) },
				transparency = 1,
				properties = { CastShadow = false },
			})
		)
	end
	return container("Folder", "PlayArea", children)
end

local function center(): Node
	local children: { Node } = {}
	table.insert(
		children,
		part(
			WORLD,
			"Plaza",
			{ size = { 64, 0.4, 64 }, at = { 0, 0.2, 0 }, color = COLORS.road, material = "Cobblestone" }
		)
	)
	table.insert(
		children,
		part(WORLD, "LobbySpawn", {
			className = "SpawnLocation",
			size = { 12, 1, 12 },
			at = { 0, 0.9, 0 },
			color = COLORS.stone,
			material = "Slate",
			tags = { TAGS.LobbySpawn },
			properties = { Neutral = true, Duration = 0 },
		})
	)
	-- A well beside the spawn and a banner pole at each road mouth, in that kingdom's colour.
	table.insert(
		children,
		part(WORLD, "Well", {
			shape = "Cylinder",
			size = { 3, 10, 10 },
			at = { 18, 1.9, 18 },
			rot = UPRIGHT,
			color = COLORS.stone,
			material = "Cobblestone",
		})
	)
	table.insert(
		children,
		part(WORLD, "WellWater", {
			shape = "Cylinder",
			size = { 0.2, 8, 8 },
			at = { 18, 3.3, 18 },
			rot = UPRIGHT,
			color = COLORS.water,
			material = "Glass",
			transparency = 0.3,
		})
	)
	for _, kingdomId in Map.KINGDOM_IDS do
		local f = kingdomFrame(kingdomId)
		local roadFrom, roadTo = 32 - KINGDOM_DISTANCE, -HALF -- plaza edge to gate, kingdom-local z
		table.insert(
			children,
			part(f, `Road_{kingdomId}`, {
				size = { 12, 0.2, roadTo - roadFrom },
				at = { 0, 0.1, (roadFrom + roadTo) / 2 },
				color = COLORS.road,
				material = "Cobblestone",
			})
		)
		table.insert(
			children,
			part(f, `Pole_{kingdomId}`, {
				shape = "Cylinder",
				size = { 16, 0.8, 0.8 },
				at = { 9, 8, roadFrom + 2 },
				rot = UPRIGHT,
				color = COLORS.wood,
				material = "Wood",
			})
		)
		table.insert(
			children,
			part(f, `Flag_{kingdomId}`, {
				size = { 0.3, 4, 6 },
				at = { 9, 13.5, roadFrom + 5.4 },
				color = BANNER[kingdomId],
				material = "Fabric",
			})
		)
	end
	return container("Folder", "Center", children)
end

-- Wild trees and boulders in the neutral land, from a fixed-seed generator (same files every run).
local function wilds(): Node
	local children: { Node } = {}
	local seed = 20261012
	local function rand(): number -- Park-Miller LCG in [0, 1)
		seed = (seed * 48271) % 2147483647
		return seed / 2147483647
	end
	local function blocked(x: number, z: number): boolean
		local ax, az = math.abs(x), math.abs(z)
		if ax > SIZE / 2 - 20 or az > SIZE / 2 - 20 then
			return true -- map edge
		elseif ax < 44 and az < 44 then
			return true -- plaza
		elseif ax < 18 or az < 18 then
			return true -- roads along the axes
		end
		local nearAxis, farAxis = math.min(ax, az), math.max(ax, az)
		if nearAxis < HALF + 12 and farAxis > KINGDOM_DISTANCE - HALF - 12 then
			return true -- a kingdom territory
		end
		if math.abs(ax - 120.2) < 26 and math.abs(az - 120.2) < 26 then
			return true -- a gold mine
		end
		return false
	end
	local trees, boulders, attempts = 0, 0, 0
	while (trees < 32 or boulders < 8) and attempts < 5000 do
		attempts += 1
		local x, z = (rand() - 0.5) * SIZE, (rand() - 0.5) * SIZE
		local scale = 0.8 + rand() * 0.5
		local turn = rand() * 90
		if not blocked(x, z) then
			if trees < 32 then
				trees += 1
				tree(WORLD, children, x, z, scale, 0)
			else
				boulders += 1
				rock(WORLD, children, "Boulder", { x, 1.5 * scale, z }, { 6 * scale, 4 * scale, 5 * scale }, turn)
			end
		end
	end
	assert(trees == 32 and boulders == 8, "wilds: not enough free space for the decoration")
	return container("Folder", "Wilds", children)
end

local function goldMines(): Node
	local children: { Node } = {}
	local names = { "SE", "NE", "NW", "SW" }
	for i = 0, 3 do
		local rot = rotY(math.rad(45 + 90 * i))
		local f: Frame = { origin = apply(rot, { 0, 0, 170 }), rot = rot }
		local id = names[i + 1]
		table.insert(
			children,
			part(f, `GoldMine_{id}`, {
				size = { 24, 0.2, 24 },
				at = { 0, 0.1, 0 },
				color = COLORS.darkStone,
				material = "Slate",
				tags = { TAGS.ResourceNode },
				attributes = {
					[ATTR.KingdomId] = Map.NEUTRAL,
					[ATTR.Resource] = "Gold",
					[ATTR.NodeId] = `Neutral-Gold-{id}`,
				},
			})
		)
		rock(f, children, "MineRock", { 0, 5, 4 }, { 16, 10, 12 }, 10)
		rock(f, children, "MineRock", { -6, 3.5, -2 }, { 9, 7, 8 }, 35)
		for _, v in { { 3, 7, -1.5 }, { -2, 4.5, -5.5 }, { 6, 4, 0 } } do
			table.insert(
				children,
				part(
					f,
					"GoldVein",
					{ size = { 3, 2, 3 }, at = v, rot = rotY(math.rad(30)), color = COLORS.gold, material = "Foil" }
				)
			)
		end
	end
	return container("Folder", "GoldMines", children)
end

-- ------------------------------------------------------------------ deterministic JSON
local function formatNumber(n: number): string
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	local s = string.format("%.4f", n)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	if s == "-0" then
		s = "0"
	end
	return s
end

local function isArray(t: { [any]: any }): boolean
	if next(t) == nil then
		return true
	end
	return #t > 0
end

local encode
local function encodeValue(value: any, indent: string): string
	local kind = type(value)
	if kind == "number" then
		return formatNumber(value)
	elseif kind == "boolean" then
		return tostring(value)
	elseif kind == "string" then
		return '"'
			.. string.gsub(value, '[%c"\\]', function(c)
				return string.format("\\u%04x", string.byte(c))
			end)
			.. '"'
	elseif kind == "table" then
		return encode(value, indent)
	end
	error(`cannot encode {kind}`)
end

function encode(t: { [any]: any }, indent: string): string
	local inner = indent .. "\t"
	if isArray(t) then
		local flat = true
		for _, v in t do
			if type(v) == "table" then
				flat = false
			end
		end
		local items = {}
		for _, v in t do
			table.insert(items, encodeValue(v, inner))
		end
		if flat then
			return "[" .. table.concat(items, ", ") .. "]"
		end
		return "[\n" .. inner .. table.concat(items, ",\n" .. inner) .. "\n" .. indent .. "]"
	end
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	local items = {}
	for _, k in keys do
		table.insert(items, `{encodeValue(k, inner)}: {encodeValue(t[k], inner)}`)
	end
	return "{\n" .. inner .. table.concat(items, ",\n" .. inner) .. "\n" .. indent .. "}"
end

-- Rojo model-file shape: the root has no "name" (the file name is the instance name).
local function toModelJson(node: Node, isRoot: boolean): { [string]: any }
	local out: { [string]: any } = { className = node.className }
	if not isRoot then
		out.name = node.name
	end
	if next(node.properties) ~= nil then
		out.properties = node.properties
	end
	if node.attributes and next(node.attributes) ~= nil then
		out.attributes = node.attributes
	end
	if node.children and #node.children > 0 then
		local children = {}
		for _, child in node.children do
			table.insert(children, toModelJson(child, false))
		end
		out.children = children
	end
	return out
end

-- ------------------------------------------------------------------ main
local files: { [string]: string } = {}
local roots = { ground(), playArea(), center(), goldMines(), wilds() }
for _, kingdomId in Map.KINGDOM_IDS do
	table.insert(roots, kingdom(kingdomId))
end
for _, root in roots do
	files[root.name .. ".model.json"] = encode(toModelJson(root, true), "") .. "\n"
end

local check = table.find(process.args, "--check") ~= nil
local problems = {}
local existing = {}
if fs.isDir(OUT_DIR) then
	for _, name in fs.readDir(OUT_DIR) do
		existing[name] = true
	end
elseif not check then
	fs.writeDir(OUT_DIR)
end

local names = {}
for name in files do
	table.insert(names, name)
end
table.sort(names)

for _, name in names do
	local path = OUT_DIR .. "/" .. name
	if check then
		if not existing[name] then
			table.insert(problems, `{name} is missing`)
		elseif fs.readFile(path) ~= files[name] then
			table.insert(problems, `{name} differs from the generator output`)
		end
	else
		fs.writeFile(path, files[name])
	end
end
for name in existing do
	if string.match(name, "%.model%.json$") and files[name] == nil then
		if check then
			table.insert(problems, `{name} is not produced by the generator (remove it or add it here)`)
		else
			fs.removeFile(OUT_DIR .. "/" .. name)
		end
	end
end

if check then
	if #problems > 0 then
		print("map gen: FAIL — games/sandbox/map is stale; run: lune run roblox/scripts/gen_sandbox_map.luau")
		for _, message in problems do
			print("  - " .. message)
		end
		process.exit(1)
	end
	print(`map gen: PASS — {#names} model files match the generator`)
else
	print(`map gen: wrote {#names} model files to games/sandbox/map`)
end
