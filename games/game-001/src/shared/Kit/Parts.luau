--!strict
--[[
	Kit/Parts — palette and primitive-part builders shared by every Kit module (FORGE-02, D-026:
	primitive Parts only, nothing yields). Models are built at the origin; the PrimaryPart "Root"
	carries PivotOffset so the pivot is the base centre; front faces -Z.
]]

local Parts = {}

-- slots: emblem slots handed out so far (Pieces.emblem numbers them per model; nil = none yet)
export type Ctx = { model: Model, root: BasePart, count: number, slots: number? }

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
	thatch = Color3.fromRGB(191, 163, 108), -- muted (G13 calibration): thatch must never read as the gold kingdom
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

-- Kingdom emblem per hue style (D-039): the same colour → style map as the tower caps, so the emblem and
-- the silhouette always agree. Neutral (unsaturated) colours carry no emblem.
local EMBLEM_KINDS: { [string]: string } = { crimson = "crown", azure = "star", emerald = "oak", gold = "sun" }

local function emblemKind(c: Color3): string?
	return EMBLEM_KINDS[hueStyle(c)]
end

-- ------------------------------------------------------------------ part builders

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

Parts.C = C
Parts.shade = shade
Parts.hueStyle = hueStyle
Parts.EMBLEM_KINDS = EMBLEM_KINDS
Parts.emblemKind = emblemKind
Parts.newModel = newModel
Parts.finish = finish
Parts.block = block
Parts.wedge = wedge
Parts.cornerWedge = cornerWedge
Parts.column = column
Parts.log = log
Parts.ball = ball
Parts.attach = attach

return Parts
