--!strict
--[[
	Kit/Pieces — shared architecture pieces (roofs, towers, doors, windows, banners, scaffolding).
	The same language the Blender kit uses (blender/ART_DIRECTION.md), rebuilt from primitive parts.
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

type Ctx = Parts.Ctx

local Pieces = {}

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
			-- CornerWedge apex is at local (+X, +Y, -Z); a 90° turn puts it over the pyramid centre
			off * CFrame.Angles(0, math.rad(90), 0),
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

Pieces.gableRoof = gableRoof
Pieces.pyramidRoof = pyramidRoof
Pieces.spire = spire
Pieces.dome = dome
Pieces.towerCap = towerCap
Pieces.crenellate = crenellate
Pieces.door = door
Pieces.window = window
Pieces.banner = banner
Pieces.flagpole = flagpole
Pieces.plinth = plinth
Pieces.timberBody = timberBody
Pieces.chimney = chimney
Pieces.scaffold = scaffold
Pieces.materialPile = materialPile

return Pieces
