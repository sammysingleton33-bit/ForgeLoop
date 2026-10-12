--!strict
--[[
	Kit — part-built medieval architecture, characters, regalia and prop stand-ins for AI Kingdoms.
	Owner: FORGE-02. Contract: games/game-001/CONTRACTS.md G10 (D-021 as amended by D-026).

	Rules (D-026): primitive Parts only (Part Block/Cylinder/Ball, WedgePart, CornerWedgePart);
	no CSG / PartOperation; nothing yields. Models are built at the origin with the pivot at the
	base centre (PrimaryPart "Root" + PivotOffset); front faces -Z (the Model's LookVector).

	Kingdom identity: Kit.build only receives a Color3, so the silhouette cue is picked from the
	colour's hue (red → spires, blue → pyramids, green → timber hoardings, yellow/gold → domes;
	unsaturated → neutral). Every kingdom-coloured part carries the attribute KitTint (shade
	factor), so Kit.setKingdomColor recolours trims and banners in place.

	API (G10):
		Kit.build(type, level, stage, kingdomColor) -> Model   -- attachments Door, WorkSpot1..n, DropOff, Rally
		Kit.footprint(type, level) -> Vector2
		Kit.character(kind, job, kingdomColor) -> Model         -- ≤ 8 parts, Motor6Ds named after the moving part
		Kit.regalia(kingdomColor) -> { Accessory }              -- crown + cape
		Kit.prop(assetId) -> Model                              -- Forge.Assets mesh if registered, else stand-in
		Kit.regionMarkers(polygon, kingdomColor) -> Model
		Kit.NEUTRAL_COLOR, Kit.setKingdomColor(model, color)
	Additive (FORGE-02 area): Kit.setAssetSource(folder) (WorldService passes ReplicatedStorage.Forge.Assets),
		Kit.BUILDING_TYPES, Kit.partCount(model).
]]

local Kit = {}

export type BuildingType = string -- Kingdom/Types BuildingType (kept local so Kit has no cross-module require)
export type Stage = number | string

Kit.NEUTRAL_COLOR = Color3.fromRGB(208, 200, 184)
Kit.VERSION = "0.1.0"
Kit.BUILDING_TYPES =
	{ "keep", "house", "farm", "storehouse", "lumbercamp", "quarry", "barracks", "watchtower", "wall", "gate" }

-- Shared palette (same values as blender/lib/palette.py so meshes and parts match).
local C = {
	plaster = Color3.fromRGB(239, 227, 200),
	plasterShade = Color3.fromRGB(216, 198, 163),
	timber = Color3.fromRGB(75, 48, 32),
	wood = Color3.fromRGB(139, 90, 51),
	woodLight = Color3.fromRGB(176, 123, 74),
	woodDark = Color3.fromRGB(92, 59, 34),
	stone = Color3.fromRGB(150, 145, 136),
	stoneLight = Color3.fromRGB(184, 178, 168),
	stoneDark = Color3.fromRGB(111, 106, 99),
	thatch = Color3.fromRGB(207, 166, 81),
	thatchDark = Color3.fromRGB(169, 129, 58),
	glass = Color3.fromRGB(43, 51, 64),
	iron = Color3.fromRGB(63, 68, 75),
	gold = Color3.fromRGB(229, 181, 58),
	skin = Color3.fromRGB(242, 201, 160),
	hair = Color3.fromRGB(107, 68, 40),
	cloth = Color3.fromRGB(138, 106, 74),
	leaf = Color3.fromRGB(63, 138, 54),
	leafLight = Color3.fromRGB(99, 168, 60),
	leafDark = Color3.fromRGB(46, 107, 47),
	bark = Color3.fromRGB(107, 74, 48),
	wheat = Color3.fromRGB(230, 194, 90),
	soil = Color3.fromRGB(122, 90, 58),
	grass = Color3.fromRGB(103, 169, 58),
	canvas = Color3.fromRGB(232, 220, 192),
}

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

function Kit.footprint(buildingType: BuildingType, level: number): Vector2
	local levels = FOOTPRINTS[buildingType]
	assert(levels, `Kit.footprint: unknown building type {buildingType}`)
	return levels[math.clamp(level, 1, #levels)]
end

-- ------------------------------------------------------------------ colour helpers

local function shade(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

local function hueStyle(c: Color3): string
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r, g, b), math.min(r, g, b)
	if mx - mn < 0.18 then
		return "neutral"
	end
	if r >= g and r >= b then
		return if g > 0.55 * r then "gold" else "crimson"
	elseif g >= r and g >= b then
		return "emerald"
	end
	return "azure"
end
Kit._hueStyle = hueStyle

-- ------------------------------------------------------------------ part builders

type Ctx = { model: Model, root: BasePart, count: number }

local function newModel(name: string, footprint: Vector2): Ctx
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(footprint.X, 0.2, footprint.Y)
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.PivotOffset = CFrame.new(0, -0.1, 0)
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = true
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root
	return { model = model, root = root, count = 1 }
end

local function finish(part: BasePart, ctx: Ctx, name: string, color: Color3, material: Enum.Material, tint: number?)
	part.Name = name
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = true
	if tint then
		part:SetAttribute("KitTint", tint)
	end
	part.Parent = ctx.model
	ctx.count += 1
	return part
end

local function block(
	ctx: Ctx,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	return finish(p, ctx, name, color, material or Enum.Material.SmoothPlastic, tint)
end

local function wedge(
	ctx: Ctx,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	local p = Instance.new("WedgePart")
	p.Size = size
	p.CFrame = cf
	return finish(p, ctx, name, color, material or Enum.Material.SmoothPlastic, tint)
end

local function cornerWedge(
	ctx: Ctx,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	local p = Instance.new("CornerWedgePart")
	p.Size = size
	p.CFrame = cf
	return finish(p, ctx, name, color, material or Enum.Material.SmoothPlastic, tint)
end

-- Cylinder standing upright (Roblox cylinders run along the part's X axis).
local function column(
	ctx: Ctx,
	name: string,
	radius: number,
	height: number,
	base: Vector3,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, radius * 2, radius * 2)
	p.CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return finish(p, ctx, name, color, material or Enum.Material.SmoothPlastic, tint)
end

-- Horizontal cylinder along a direction (logs, rails).
local function log(
	ctx: Ctx,
	name: string,
	radius: number,
	length: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(length, radius * 2, radius * 2)
	p.CFrame = cf
	return finish(p, ctx, name, color, material or Enum.Material.Wood)
end

local function ball(
	ctx: Ctx,
	name: string,
	diameter: number,
	pos: Vector3,
	color: Color3,
	material: Enum.Material?,
	tint: number?
)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = CFrame.new(pos)
	return finish(p, ctx, name, color, material or Enum.Material.SmoothPlastic, tint)
end

local function attach(ctx: Ctx, name: string, pos: Vector3)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = CFrame.new(pos - Vector3.new(0, 0.1, 0)) -- relative to Root (centre at y = 0.1)
	a.Parent = ctx.root
	return a
end

-- ------------------------------------------------------------------ shared architecture pieces

-- Gable roof over a w × d box whose wall tops are at height y; ridge along X. Two wedges + ridge + eaves.
local function gableRoof(
	ctx: Ctx,
	w: number,
	d: number,
	y: number,
	rise: number,
	color: Color3,
	dark: Color3,
	tint: number?,
	cx: number?,
	cz: number?
)
	local ox, oz = cx or 0, cz or 0
	local over = 1.2
	local half = d / 2 + over
	local riseO = rise * half / (d / 2)
	local yb = y - (riseO - rise)
	-- front slope (default wedge: vertical face +Z, slope descends to -Z)
	wedge(
		ctx,
		"RoofFront",
		Vector3.new(w + 2 * over, riseO, half),
		CFrame.new(ox, yb + riseO / 2, oz - half / 2),
		color,
		Enum.Material.SmoothPlastic,
		tint
	)
	wedge(
		ctx,
		"RoofBack",
		Vector3.new(w + 2 * over, riseO, half),
		CFrame.new(ox, yb + riseO / 2, oz + half / 2) * CFrame.Angles(0, math.rad(180), 0),
		color,
		Enum.Material.SmoothPlastic,
		tint
	)
	-- ridge cap and eave boards
	block(
		ctx,
		"Ridge",
		Vector3.new(w + 2 * over + 0.4, 0.9, 0.9),
		CFrame.new(ox, yb + riseO + 0.15, oz) * CFrame.Angles(math.rad(45), 0, 0),
		dark,
		Enum.Material.SmoothPlastic,
		if tint then tint * 0.7 else nil
	)
	block(
		ctx,
		"EaveFront",
		Vector3.new(w + 2 * over, 0.5, 0.5),
		CFrame.new(ox, yb + 0.1, oz - half + 0.2),
		dark,
		Enum.Material.Wood,
		if tint then tint * 0.7 else nil
	)
	block(
		ctx,
		"EaveBack",
		Vector3.new(w + 2 * over, 0.5, 0.5),
		CFrame.new(ox, yb + 0.1, oz + half - 0.2),
		dark,
		Enum.Material.Wood,
		if tint then tint * 0.7 else nil
	)
	-- gable triangles (plaster) under the roof at both ends
	for _, sx in { -1, 1 } do
		local gx = ox + sx * (w / 2 - 0.3)
		wedge(ctx, "Gable", Vector3.new(0.6, rise, d / 2), CFrame.new(gx, y + rise / 2, oz - d / 4), C.plaster)
		wedge(
			ctx,
			"Gable",
			Vector3.new(0.6, rise, d / 2),
			CFrame.new(gx, y + rise / 2, oz + d / 4) * CFrame.Angles(0, math.rad(180), 0),
			C.plaster
		)
	end
end

-- Four-sided pyramid roof from CornerWedges (blue kingdom towers).
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
		local ang = math.rad(90 * i)
		local off = CFrame.new(ox, y + h / 2, oz) * CFrame.Angles(0, ang, 0) * CFrame.new(half / 2, 0, half / 2)
		cornerWedge(
			ctx,
			"RoofCorner",
			Vector3.new(half, h, half),
			off * CFrame.Angles(0, math.rad(180), 0),
			color,
			Enum.Material.SmoothPlastic,
			tint
		)
	end
end

-- Stepped spire from stacked cylinders (red kingdom).
local function spire(ctx: Ctx, r: number, h: number, y: number, color: Color3, tint: number?, cx: number?, cz: number?)
	local base = Vector3.new(cx or 0, y, cz or 0)
	local tiers = 5
	for i = 0, tiers - 1 do
		local t = i / tiers
		local rr = r * (1 - t) + 0.15
		column(
			ctx,
			"Spire",
			rr,
			h / tiers + 0.05,
			base + Vector3.new(0, h * t, 0),
			color,
			Enum.Material.SmoothPlastic,
			tint
		)
	end
	column(ctx, "Finial", 0.18, 2.2, base + Vector3.new(0, h, 0), C.gold, Enum.Material.Metal)
	ball(ctx, "FinialBall", 0.7, base + Vector3.new(0, h + 2.2, 0), C.gold, Enum.Material.Metal)
end

-- Dome (gold kingdom): ball half-sunk into a drum, with a finial.
local function dome(ctx: Ctx, r: number, y: number, color: Color3, tint: number?, cx: number?, cz: number?)
	local base = Vector3.new(cx or 0, y, cz or 0)
	column(
		ctx,
		"Drum",
		r * 0.95,
		0.8,
		base,
		shade(color, 0.75),
		Enum.Material.SmoothPlastic,
		if tint then tint * 0.75 else nil
	)
	ball(ctx, "Dome", r * 2, base + Vector3.new(0, 0.8 + r * 0.35, 0), color, Enum.Material.SmoothPlastic, tint)
	column(ctx, "Finial", 0.2, 1.6, base + Vector3.new(0, 0.8 + r * 1.3, 0), C.gold, Enum.Material.Metal)
	ball(ctx, "FinialBall", 0.8, base + Vector3.new(0, 0.8 + r * 1.3 + 1.7, 0), C.gold, Enum.Material.Metal)
end

-- Kingdom tower cap chosen from the colour's hue.
local function towerCap(ctx: Ctx, style: string, w: number, y: number, color: Color3, cx: number?, cz: number?)
	if style == "crimson" then
		spire(ctx, w * 0.62, w * 1.5, y, color, 1, cx, cz)
	elseif style == "azure" then
		pyramidRoof(ctx, w + 1.6, w * 0.95, y, color, 1, cx, cz)
	elseif style == "emerald" then
		-- timber hoarding (wooden fighting gallery) + low pyramid
		block(
			ctx,
			"Hoarding",
			Vector3.new(w + 1.6, 2.6, w + 1.6),
			CFrame.new(cx or 0, y + 1.3, cz or 0),
			C.woodDark,
			Enum.Material.Wood
		)
		pyramidRoof(ctx, w + 2.6, w * 0.55, y + 2.6, color, 1, cx, cz)
	elseif style == "gold" then
		dome(ctx, w * 0.55, y, color, 1, cx, cz)
	else
		pyramidRoof(ctx, w + 1.4, w * 0.7, y, shade(color, 0.85), 1, cx, cz)
	end
end

local function crenellate(ctx: Ctx, w: number, d: number, y: number, color: Color3, cx: number?, cz: number?)
	local ox, oz = cx or 0, cz or 0
	local m, g = 2.0, 1.6
	for _, side in { { w, d, 1 }, { d, w, 0 } } do
		local len, other, alongX = side[1], side[2], side[3]
		local n = math.max(2, math.floor((len + g) / (m + g)))
		local total = n * m + (n - 1) * g
		for i = 0, n - 1 do
			local u = -total / 2 + m / 2 + i * (m + g)
			for _, s in { -1, 1 } do
				local pos = if alongX == 1
					then Vector3.new(ox + u, y + 1.1, oz + s * (other / 2 - 0.5))
					else Vector3.new(ox + s * (other / 2 - 0.5), y + 1.1, oz + u)
				local size = if alongX == 1 then Vector3.new(m, 2.2, 1.2) else Vector3.new(1.2, 2.2, m)
				block(ctx, "Merlon", size, CFrame.new(pos), color, Enum.Material.Slate)
			end
		end
	end
end

local function door(ctx: Ctx, x: number, z: number, y: number, w: number, h: number, facing: number?)
	local rot = CFrame.Angles(0, math.rad(facing or 0), 0)
	local base = CFrame.new(x, y, z) * rot
	block(
		ctx,
		"Door",
		Vector3.new(w, h - w / 2, 0.4),
		base * CFrame.new(0, (h - w / 2) / 2, -0.2),
		C.woodDark,
		Enum.Material.Wood
	)
	local arch = Instance.new("Part")
	arch.Shape = Enum.PartType.Cylinder
	arch.Size = Vector3.new(0.4, w, w)
	arch.CFrame = base * CFrame.new(0, h - w / 2, -0.2) * CFrame.Angles(0, math.rad(90), 0)
	finish(arch, ctx, "DoorArch", C.woodDark, Enum.Material.Wood)
	block(
		ctx,
		"DoorFrameL",
		Vector3.new(0.7, h - w / 2, 0.7),
		base * CFrame.new(-w / 2 - 0.35, (h - w / 2) / 2, -0.25),
		C.stoneLight,
		Enum.Material.Slate
	)
	block(
		ctx,
		"DoorFrameR",
		Vector3.new(0.7, h - w / 2, 0.7),
		base * CFrame.new(w / 2 + 0.35, (h - w / 2) / 2, -0.25),
		C.stoneLight,
		Enum.Material.Slate
	)
	block(ctx, "Step", Vector3.new(w + 2, 0.4, 1.6), base * CFrame.new(0, 0.2, -0.9), C.stone, Enum.Material.Slate)
end

local function window(ctx: Ctx, x: number, y: number, z: number, facing: number, shutterColor: Color3?)
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(facing), 0)
	block(ctx, "Window", Vector3.new(2.6, 3.4, 0.3), base * CFrame.new(0, 1.7, -0.1), C.glass, Enum.Material.Glass)
	block(ctx, "WindowFrame", Vector3.new(3.3, 0.4, 0.5), base * CFrame.new(0, 3.5, -0.2), C.timber, Enum.Material.Wood)
	block(ctx, "Sill", Vector3.new(3.6, 0.35, 0.9), base * CFrame.new(0, -0.15, -0.35), C.wood, Enum.Material.Wood)
	block(ctx, "Mullion", Vector3.new(0.25, 3.4, 0.35), base * CFrame.new(0, 1.7, -0.2), C.timber, Enum.Material.Wood)
	if shutterColor then
		for _, s in { -1, 1 } do
			block(
				ctx,
				"Shutter",
				Vector3.new(1.4, 3.5, 0.25),
				base * CFrame.new(s * 2.25, 1.7, -0.6) * CFrame.Angles(0, math.rad(-s * 25), 0),
				shutterColor,
				Enum.Material.Wood,
				0.8
			)
		end
	end
end

local function banner(ctx: Ctx, x: number, y: number, z: number, facing: number, color: Color3, h: number?)
	local hh = h or 5
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(facing), 0)
	block(ctx, "BannerPole", Vector3.new(3.2, 0.3, 0.3), base * CFrame.new(0, 0, -0.4), C.woodDark, Enum.Material.Wood)
	block(
		ctx,
		"Banner",
		Vector3.new(2.6, hh, 0.2),
		base * CFrame.new(0, -hh / 2, -0.45),
		color,
		Enum.Material.Fabric,
		1
	)
	block(
		ctx,
		"BannerTrim",
		Vector3.new(2.6, 0.35, 0.25),
		base * CFrame.new(0, -hh + 0.1, -0.45),
		shade(color, 0.6),
		Enum.Material.Fabric,
		0.6
	)
	block(
		ctx,
		"BannerEmblem",
		Vector3.new(1.1, 1.1, 0.25),
		base * CFrame.new(0, -hh * 0.45, -0.5) * CFrame.Angles(0, 0, math.rad(45)),
		C.gold,
		Enum.Material.Fabric
	)
end

local function flagpole(ctx: Ctx, x: number, y: number, z: number, h: number, color: Color3)
	column(ctx, "FlagPole", 0.2, h, Vector3.new(x, y, z), C.woodDark, Enum.Material.Wood)
	block(ctx, "Flag", Vector3.new(3.4, 2.0, 0.15), CFrame.new(x + 1.8, y + h - 1.2, z), color, Enum.Material.Fabric, 1)
	ball(ctx, "FlagFinial", 0.55, Vector3.new(x, y + h + 0.2, z), C.gold, Enum.Material.Metal)
end

local function plinth(ctx: Ctx, w: number, d: number, h: number)
	block(ctx, "Plinth", Vector3.new(w + 0.8, h, d + 0.8), CFrame.new(0, h / 2, 0), C.stone, Enum.Material.Cobblestone)
end

-- Timber-frame house body: plaster walls + corner posts + beams.
local function timberBody(ctx: Ctx, w: number, d: number, y: number, h: number)
	block(ctx, "Walls", Vector3.new(w, h, d), CFrame.new(0, y + h / 2, 0), C.plaster, Enum.Material.SmoothPlastic)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			block(
				ctx,
				"Post",
				Vector3.new(0.7, h, 0.7),
				CFrame.new(sx * (w / 2), y + h / 2, sz * (d / 2)),
				C.timber,
				Enum.Material.Wood
			)
		end
	end
	for _, sz in { -1, 1 } do
		block(
			ctx,
			"Beam",
			Vector3.new(w + 0.4, 0.6, 0.5),
			CFrame.new(0, y + h - 0.3, sz * (d / 2 + 0.05)),
			C.timber,
			Enum.Material.Wood
		)
		block(
			ctx,
			"Beam",
			Vector3.new(w + 0.4, 0.6, 0.5),
			CFrame.new(0, y + 0.3, sz * (d / 2 + 0.05)),
			C.timber,
			Enum.Material.Wood
		)
	end
	for _, sx in { -1, 1 } do
		block(
			ctx,
			"Beam",
			Vector3.new(0.5, 0.6, d + 0.4),
			CFrame.new(sx * (w / 2 + 0.05), y + h - 0.3, 0),
			C.timber,
			Enum.Material.Wood
		)
	end
	-- braces on the front
	for _, sx in { -1, 1 } do
		local len = math.sqrt((w * 0.28) ^ 2 + (h * 0.55) ^ 2)
		local ang = math.atan2(h * 0.55, w * 0.28)
		block(
			ctx,
			"Brace",
			Vector3.new(len, 0.5, 0.4),
			CFrame.new(sx * (w / 2 - w * 0.14), y + h * 0.33, -d / 2 - 0.1) * CFrame.Angles(0, 0, sx * ang),
			C.timber,
			Enum.Material.Wood
		)
	end
end

local function chimney(ctx: Ctx, x: number, z: number, y0: number, h: number)
	block(ctx, "Chimney", Vector3.new(2.2, h, 2.2), CFrame.new(x, y0 + h / 2, z), C.stone, Enum.Material.Cobblestone)
	block(
		ctx,
		"ChimneyCap",
		Vector3.new(2.8, 0.5, 2.8),
		CFrame.new(x, y0 + h + 0.25, z),
		C.stoneDark,
		Enum.Material.Slate
	)
end

-- Construction scaffolding around a w × d footprint up to height h.
local function scaffold(ctx: Ctx, w: number, d: number, h: number)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			column(
				ctx,
				"ScaffoldPole",
				0.25,
				h + 1.5,
				Vector3.new(sx * (w / 2 + 1.2), 0, sz * (d / 2 + 1.2)),
				C.woodLight,
				Enum.Material.Wood
			)
		end
	end
	local levels = math.max(1, math.floor(h / 5))
	for i = 1, levels do
		local y = i * h / (levels + 0.3)
		block(
			ctx,
			"ScaffoldPlank",
			Vector3.new(w + 3, 0.3, 1.2),
			CFrame.new(0, y, -d / 2 - 1.2),
			C.woodLight,
			Enum.Material.WoodPlanks
		)
		block(
			ctx,
			"ScaffoldPlank",
			Vector3.new(1.2, 0.3, d + 3),
			CFrame.new(w / 2 + 1.2, y, 0),
			C.woodLight,
			Enum.Material.WoodPlanks
		)
	end
end

local function materialPile(ctx: Ctx, x: number, z: number)
	for i = 0, 2 do
		log(
			ctx,
			"PileLog",
			0.5,
			5,
			CFrame.new(x, 0.5 + i * 0.85, z + (i % 2) * 0.4 - 0.2) * CFrame.Angles(0, math.rad(90), 0),
			C.bark
		)
	end
	block(ctx, "PileStone", Vector3.new(2, 1.4, 2), CFrame.new(x + 3, 0.7, z), C.stoneLight, Enum.Material.Slate)
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

function Kit.build(buildingType: BuildingType, level: number, stage: Stage, kingdomColor: Color3): Model
	local builder = BUILDERS[buildingType]
	assert(builder, `Kit.build: unknown building type {buildingType}`)
	local fp = Kit.footprint(buildingType, level)
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

-- ------------------------------------------------------------------ recolouring

function Kit.setKingdomColor(model: Model, color: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local f = d:GetAttribute("KitTint")
			if type(f) == "number" then
				d.Color = shade(color, f)
			end
		end
	end
	model:SetAttribute("KitColor", color)
end

function Kit.partCount(model: Instance): number
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- ------------------------------------------------------------------ characters (≤ 8 parts)

local JOB_LOOK: { [string]: { legs: Color3, tool: string } } = {
	idle = { legs = Color3.fromRGB(110, 86, 60), tool = "none" },
	farmer = { legs = Color3.fromRGB(94, 127, 58), tool = "hoe" },
	woodcutter = { legs = Color3.fromRGB(122, 74, 42), tool = "axe" },
	miner = { legs = Color3.fromRGB(95, 102, 111), tool = "pick" },
	builder = { legs = Color3.fromRGB(139, 94, 60), tool = "hammer" },
	hauler = { legs = Color3.fromRGB(150, 130, 100), tool = "sack" },
	soldier = { legs = Color3.fromRGB(93, 102, 112), tool = "spear" },
}

local function rigPart(
	model: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	p.Parent = model
	return p
end

local function motor(part0: BasePart, part1: BasePart, jointWorld: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = part1.Name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:Inverse() * jointWorld
	m.C1 = part1.CFrame:Inverse() * jointWorld
	m.Parent = part0
	return m
end

local TOOL_SHAPES: { [string]: { size: Vector3, color: Color3, material: Enum.Material, offset: CFrame } } = {
	hoe = {
		size = Vector3.new(0.25, 4.2, 0.25),
		color = C.wood,
		material = Enum.Material.Wood,
		offset = CFrame.new(0, -0.6, -0.4),
	},
	axe = {
		size = Vector3.new(0.35, 2.6, 0.9),
		color = C.iron,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, -1.2, -0.5),
	},
	pick = {
		size = Vector3.new(0.3, 2.4, 1.6),
		color = C.iron,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, -1.2, -0.5),
	},
	hammer = {
		size = Vector3.new(0.6, 1.8, 0.6),
		color = C.iron,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, -1.1, -0.4),
	},
	sack = {
		size = Vector3.new(1.6, 1.6, 1.6),
		color = C.canvas,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 1.2, 0.9),
	},
	spear = {
		size = Vector3.new(0.22, 7.0, 0.22),
		color = C.woodDark,
		material = Enum.Material.Wood,
		offset = CFrame.new(0, 0.6, -0.4),
	},
}

function Kit.character(kind: string, job: string, kingdomColor: Color3): Model
	local look = JOB_LOOK[job] or JOB_LOOK.idle
	local model = Instance.new("Model")
	model.Name = `{kind}_{job}`
	model:SetAttribute("KitKind", kind)
	model:SetAttribute("KitJob", job)
	-- proportions: legs 2.2, torso 2.0, head 1.3 => 5.5 studs
	local root = rigPart(model, "Root", Vector3.new(2, 2, 1), CFrame.new(0, 3.2, 0), C.cloth)
	root.Anchored = true
	root.Transparency = 1
	root.PivotOffset = CFrame.new(0, -3.2, 0)
	model.PrimaryPart = root
	local tunic = if kind == "citizen" then shade(kingdomColor, 0.85):Lerp(C.cloth, 0.45) else kingdomColor
	local torso = rigPart(model, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3.2, 0), tunic, Enum.Material.Fabric)
	torso:SetAttribute("KitTint", if kind == "citizen" then 0.85 else 1)
	local head = rigPart(
		model,
		"Head",
		Vector3.new(1.3, 1.3, 1.3),
		CFrame.new(0, 4.85, 0),
		if kind == "soldier" then C.iron else C.skin,
		if kind == "soldier" then Enum.Material.Metal else Enum.Material.SmoothPlastic
	)
	local larm =
		rigPart(model, "LeftArm", Vector3.new(0.9, 2, 0.9), CFrame.new(-1.45, 3.2, 0), tunic, Enum.Material.Fabric)
	local rarm =
		rigPart(model, "RightArm", Vector3.new(0.9, 2, 0.9), CFrame.new(1.45, 3.2, 0), tunic, Enum.Material.Fabric)
	larm:SetAttribute("KitTint", 0.85)
	rarm:SetAttribute("KitTint", 0.85)
	local lleg = rigPart(
		model,
		"LeftLeg",
		Vector3.new(0.95, 2.2, 0.95),
		CFrame.new(-0.5, 1.1, 0),
		look.legs,
		Enum.Material.Fabric
	)
	local rleg = rigPart(
		model,
		"RightLeg",
		Vector3.new(0.95, 2.2, 0.95),
		CFrame.new(0.5, 1.1, 0),
		look.legs,
		Enum.Material.Fabric
	)
	motor(root, torso, CFrame.new(0, 2.2, 0))
	motor(torso, head, CFrame.new(0, 4.2, 0))
	motor(torso, larm, CFrame.new(-1.0, 4.0, 0))
	motor(torso, rarm, CFrame.new(1.0, 4.0, 0))
	motor(torso, lleg, CFrame.new(-0.5, 2.2, 0))
	motor(torso, rleg, CFrame.new(0.5, 2.2, 0))
	local toolName = if kind == "soldier" then "spear" else look.tool
	local spec = TOOL_SHAPES[toolName]
	if spec then
		local hand = CFrame.new(1.45, 2.3, 0)
		local tool = rigPart(model, "Tool", spec.size, hand * spec.offset, spec.color, spec.material)
		motor(rarm, tool, hand)
	end
	return model
end

-- ------------------------------------------------------------------ regalia (ruler crown + cape)

function Kit.regalia(kingdomColor: Color3): { Accessory }
	local crown = Instance.new("Accessory")
	crown.Name = "KitCrown"
	local band = Instance.new("Part")
	band.Name = "Handle"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.5, 1.5, 1.5)
	band.CFrame = CFrame.Angles(0, 0, math.rad(90))
	band.Color = C.gold
	band.Material = Enum.Material.Metal
	band.CanCollide = false
	band.CanTouch = false
	band.CanQuery = false
	band.Massless = true
	band.Parent = crown
	local hat = Instance.new("Attachment")
	hat.Name = "HatAttachment"
	hat.CFrame = CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, -0.35, 0)
	hat.Parent = band
	for i = 0, 3 do
		local a = math.rad(i * 90 + 45)
		local pt = Instance.new("Part")
		pt.Name = "CrownPoint"
		pt.Size = Vector3.new(0.3, 0.45, 0.3)
		pt.CFrame = band.CFrame
			* CFrame.Angles(0, 0, math.rad(-90))
			* CFrame.new(math.cos(a) * 0.65, 0.4, math.sin(a) * 0.65)
		pt.Color = if i % 2 == 0 then C.gold else kingdomColor
		pt:SetAttribute("KitTint", if i % 2 == 0 then nil else 1)
		pt.Material = Enum.Material.Metal
		pt.CanCollide = false
		pt.CanTouch = false
		pt.CanQuery = false
		pt.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = band
		weld.Part1 = pt
		weld.Parent = pt
		pt.Parent = crown
	end

	local cape = Instance.new("Accessory")
	cape.Name = "KitCape"
	local cloth = Instance.new("Part")
	cloth.Name = "Handle"
	cloth.Size = Vector3.new(2.2, 3.2, 0.2)
	cloth.Color = kingdomColor
	cloth:SetAttribute("KitTint", 1)
	cloth.Material = Enum.Material.Fabric
	cloth.CanCollide = false
	cloth.CanTouch = false
	cloth.CanQuery = false
	cloth.Massless = true
	cloth.Parent = cape
	local back = Instance.new("Attachment")
	back.Name = "BodyBackAttachment"
	back.CFrame = CFrame.new(0, 1.0, -0.15)
	back.Parent = cloth
	return { crown, cape }
end

-- ------------------------------------------------------------------ props (stand-ins until meshes import)

local assetSource: Instance? = nil

function Kit.setAssetSource(folder: Instance?)
	assetSource = folder
end

local function standIn(assetId: string): Model
	local ctx = newModel(assetId, Vector2.new(4, 4))
	ctx.model:SetAttribute("KitStandIn", true)
	local h = 0
	for i = 1, #assetId do
		h = (h * 31 + string.byte(assetId, i)) % 1000003
	end
	local rng = Random.new(h)
	if string.find(assetId, "^tree_") then
		local pine = string.find(assetId, "pine") ~= nil
		local th = if pine then rng:NextNumber(18, 26) else rng:NextNumber(10, 14)
		column(ctx, "Trunk", if pine then 0.9 else 1.3, th, Vector3.new(0, 0, 0), C.bark, Enum.Material.Wood)
		if pine then
			for i = 0, 4 do
				local r = 6.5 - i * 1.15
				column(
					ctx,
					"Tier",
					r,
					2.6,
					Vector3.new(0, 6 + i * 3.6, 0),
					if i % 2 == 0 then C.leafDark else C.leaf,
					Enum.Material.Grass
				)
			end
		else
			local colors = { C.leafDark, C.leaf, C.leafLight }
			for i = 1, 9 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = if i == 1 then 0 else rng:NextNumber(3, 6)
				local d = if i == 1 then 11 else rng:NextNumber(6, 9)
				ball(
					ctx,
					"Canopy",
					d,
					Vector3.new(math.cos(a) * r, th + rng:NextNumber(0, 5) + (if i == 1 then 3 else 0), math.sin(a) * r),
					colors[1 + (i % 3)],
					Enum.Material.Grass
				)
			end
		end
	elseif string.find(assetId, "^rock_") or string.find(assetId, "^resource_stone") then
		block(
			ctx,
			"Rock",
			Vector3.new(6, 4, 5),
			CFrame.new(0, 1.8, 0) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.15),
			C.stone,
			Enum.Material.Slate
		)
		block(
			ctx,
			"Rock",
			Vector3.new(3, 2.5, 3),
			CFrame.new(3, 1.1, 1.5) * CFrame.Angles(0.2, rng:NextNumber(0, 3), 0),
			C.stoneLight,
			Enum.Material.Slate
		)
	elseif string.find(assetId, "^resource_wood") then
		for i = 0, 2 do
			log(
				ctx,
				"Log",
				0.7,
				6,
				CFrame.new(0, 0.7 + i * 1.2, (i % 2) * 0.6) * CFrame.Angles(0, math.rad(90), 0),
				C.bark
			)
		end
	elseif string.find(assetId, "^bush") then
		ball(ctx, "Bush", 5, Vector3.new(0, 2, 0), C.leaf, Enum.Material.Grass)
		ball(ctx, "Bush", 3.6, Vector3.new(1.8, 1.6, 0.6), C.leafLight, Enum.Material.Grass)
	else
		block(ctx, "Crate", Vector3.new(2, 2, 2), CFrame.new(0, 1, 0), C.wood, Enum.Material.WoodPlanks)
		block(ctx, "CrateBand", Vector3.new(2.1, 0.3, 2.1), CFrame.new(0, 1, 0), C.woodDark, Enum.Material.Wood)
	end
	return ctx.model
end

function Kit.prop(assetId: string): Model
	if assetSource then
		local found = assetSource:FindFirstChild(assetId)
		if found and found:IsA("Model") then
			return found:Clone()
		end
	end
	return standIn(assetId)
end

-- ------------------------------------------------------------------ territory markers

function Kit.regionMarkers(polygon: { Vector2 }, kingdomColor: Color3): Model
	local ctx = newModel("RegionMarkers", Vector2.new(1, 1))
	local n = #polygon
	for i = 1, n do
		local a, b = polygon[i], polygon[(i % n) + 1]
		for _, t in { 0, 0.5 } do
			local p = a:Lerp(b, t)
			block(
				ctx,
				"MarkerBase",
				Vector3.new(1.6, 0.8, 1.6),
				CFrame.new(p.X, 0.4, p.Y),
				C.stone,
				Enum.Material.Slate
			)
			flagpole(ctx, p.X, 0.8, p.Y, 7, kingdomColor)
		end
	end
	return ctx.model
end

return Kit
