--!strict
--[[
	Kit/Crowd — Kit.crowdFigure(kingdomColor, role?, variant?): the Crown Arena's crowd (FL-0072, CONTRACTS G12.6,
	design/crown-arena.md §7; D-026 primitive Parts only, nothing yields). Owner: FORGE-02.

	One figure is at most 4 primitive Parts, client-only (FORGE-04's crowd director clones, seats and bobs it; the server
	never builds one): no Root, no Humanoid, no Motor6D, no script. Every part is Anchored, non-colliding, non-touching,
	non-queryable and casts no shadow; the model's PrimaryPart is the body, its pivot is on the feet (so
	figure:PivotTo(seat.WorldCFrame) stands it on a seat attachment of Kit.arena, facing the ring: the model's front is -Z)
	and Kit.CROWD_HEIGHT is its nominal height. Deterministic: the same (colour, role, variant) always builds the same figure.

	Generic figure (4 parts): Body (the kingdom-colour tabard, legs and torso in one block), Head (a skin-tone ball), Crest
	(the kingdom's helmet crest in the kingdom colour: spire / square / plume / dome, as the soldiers' Character.CRESTS, so the
	stand reads by shape as well as colour: D-033) and Arms (one bar across the shoulders, level or tilted to wave).
	`variant` (default 1, wraps over 8) varies skin, height, width, arm pose and sleeve shade, so a stand is not a row of clones.

	Key citizens (role: KeyRole of G12.1) stand on the rail podium with their role prop; the prop replaces the arms bar and, where it
	needs two parts, the crest. Each reads by silhouette alone (the spec hashes the front, side and top outlines):
		blacksmith   Body, Head, Handle (a long haft held at the right), Hammer (a chunky dark head on top): a T beside the head
		healer       Body, Head, Crest, Satchel (a pale box hung at the left hip)
		captain      Body, Head (steel helm), Plume (a tall kingdom-colour plume rising from the helm), Arms
		provisioner  Body, Head, Crest, Basket (a wide straw disc carried in front at the belt)
		elder        Body, Head (white hair), Crest, Staff (a thin pole taller than the figure, at the left)
		merchant     Body, Head, Post and Beam (the scales held up at the right: a thin wide balance bar over a short post)
	The kingdom-coloured parts carry KitTint, so Kit.setKingdomColor recolours a pooled figure; the crest's SHAPE follows the
	kingdom the figure was built for, so pool figures per kingdom, role and variant (Crowd.poolKey).
]]

local Parts = require("./Parts")

local C = Parts.C
local shade = Parts.shade
local hueStyle = Parts.hueStyle

local M = Enum.Material
local rad = math.rad

local Crowd = {}

Crowd.MAX_PARTS = 4
Crowd.VARIANTS = 8
Crowd.ROLES = table.freeze({ "blacksmith", "healer", "captain", "provisioner", "elder", "merchant" })
Crowd.HEIGHT = 5.0 -- nominal standing height (the variants scale 0.9 - 1.08 of it); the crest or a prop may rise above
Crowd.BODY_HEIGHT = 3.2

-- hat shape per hue style (the soldiers' crests, D-033): the neutral colour wears a plain cap
Crowd.CREST_NAMES = table.freeze({
	crimson = "crest_spire",
	azure = "crest_square",
	emerald = "crest_plume",
	gold = "crest_dome",
	neutral = "cap",
})

local SKIN: { Color3 } = { -- Character's skin palette, light to dark
	C.skin,
	Color3.fromRGB(255, 222, 196),
	Color3.fromRGB(210, 156, 112),
	Color3.fromRGB(162, 108, 70),
	Color3.fromRGB(110, 70, 44),
	Color3.fromRGB(78, 50, 34),
}
local STEEL = Color3.fromRGB(176, 182, 192)
local IRON = Color3.fromRGB(58, 62, 70)
local PEWTER = Color3.fromRGB(190, 196, 206)
local HAFT = Color3.fromRGB(139, 90, 51)
local LINEN = Color3.fromRGB(240, 232, 212)
local WHITE_HAIR = Color3.fromRGB(238, 234, 226)
local STRAW = Color3.fromRGB(178, 138, 74) -- darker than hay: never the gold kingdom
local PALE = Color3.fromRGB(236, 226, 200)

-- per-variant look: skin index, height scale, body width, arm tilt (degrees, sign = which side waves), arm lift, body tint,
-- sleeve (a number = a shade of the kingdom colour, else a fixed cloth colour)
type Look = {
	skin: number,
	height: number,
	width: number,
	tilt: number,
	lift: number,
	body: number,
	sleeve: number | Color3,
}
local TAN = Color3.fromRGB(196, 158, 108)
local LOOKS: { Look } = {
	{ skin = 1, height = 1.0, width = 1.55, tilt = 0, lift = 0, body = 1, sleeve = LINEN },
	{ skin = 3, height = 0.94, width = 1.4, tilt = 24, lift = 0.15, body = 0.88, sleeve = 1.2 },
	{ skin = 2, height = 1.05, width = 1.7, tilt = -22, lift = 0.15, body = 1, sleeve = TAN },
	{ skin = 4, height = 0.9, width = 1.45, tilt = 0, lift = 0, body = 0.88, sleeve = 0.72 },
	{ skin = 1, height = 1.08, width = 1.6, tilt = 40, lift = 0, body = 1, sleeve = LINEN }, -- cheering: an arm thrown up
	{ skin = 5, height = 0.97, width = 1.35, tilt = 20, lift = 0.1, body = 0.88, sleeve = TAN },
	{ skin = 3, height = 1.02, width = 1.65, tilt = -26, lift = 0.2, body = 1, sleeve = 1.2 },
	{ skin = 6, height = 0.92, width = 1.5, tilt = -40, lift = 0, body = 0.88, sleeve = LINEN }, -- cheering
}

function Crowd.poolKey(color: Color3, role: string?, variant: number?): string
	return `{hueStyle(color)}.{role or "crowd"}.{Crowd.variantOf(variant)}`
end

function Crowd.variantOf(variant: number?): number
	local v = variant
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return 1
	end
	return (math.floor(v) - 1) % Crowd.VARIANTS + 1
end

-- ------------------------------------------------------------------ builders

type Spec = {
	name: string,
	shape: Enum.PartType?,
	class: string?,
	size: Vector3,
	cf: CFrame, -- in the figure frame (feet on y = 0, front -Z)
	color: Color3,
	material: Enum.Material,
	tint: number?,
}

local UPRIGHT = CFrame.Angles(0, 0, rad(90)) -- cylinder axis (X) -> +Y

local function makePart(model: Model, s: Spec): BasePart
	local p: BasePart
	if s.class == "CornerWedgePart" then
		p = Instance.new("CornerWedgePart")
	elseif s.class == "WedgePart" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		part.Shape = s.shape or Enum.PartType.Block
		p = part
	end
	p.Name = s.name
	p.Size = s.size
	p.CFrame = s.cf
	p.Color = s.color
	p.Material = s.material
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if s.tint then
		p:SetAttribute("KitTint", s.tint)
	end
	p.Parent = model
	return p
end

local function cylinderUp(h: number, d: number): Vector3
	return Vector3.new(h, d, d) -- Roblox cylinders run along X; UPRIGHT turns them to Y
end

-- The kingdom's crest on a head centred at (0, hy, 0) of diameter hd, in the figure frame.
local function crestSpec(style: string, hy: number, hd: number): Spec
	local top = hy + hd / 2
	if style == "crimson" then
		local s = Vector3.new(1.0, 1.7, 1.0)
		return {
			name = "Crest",
			class = "CornerWedgePart",
			size = s,
			cf = CFrame.new(0, top + s.Y / 2 - 0.1, 0) * CFrame.Angles(0, rad(45), 0),
			color = Color3.new(1, 1, 1),
			material = M.Metal,
			tint = 1,
		}
	elseif style == "azure" then
		return { -- a square kepi: a flat-topped box, wider than the head
			name = "Crest",
			size = Vector3.new(1.65, 0.85, 1.65),
			cf = CFrame.new(0, top + 0.18, 0),
			color = Color3.new(1, 1, 1),
			material = M.Metal,
			tint = 1,
		}
	elseif style == "emerald" then
		local len, d = 2.4, 0.7
		return {
			name = "Crest",
			shape = Enum.PartType.Cylinder,
			size = cylinderUp(len, d),
			cf = CFrame.new(0, top - 0.25, -0.25) * CFrame.Angles(rad(70), 0, 0) * CFrame.new(0, len / 2, 0) * UPRIGHT,
			color = Color3.new(1, 1, 1),
			material = M.Fabric,
			tint = 1,
		}
	elseif style == "gold" then
		return {
			name = "Crest",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.5, 1.5, 1.5),
			cf = CFrame.new(0, top + 0.3, 0),
			color = Color3.new(1, 1, 1),
			material = M.Metal,
			tint = 1,
		}
	end
	return { -- neutral: a plain flat cap
		name = "Crest",
		size = Vector3.new(1.5, 0.4, 1.5),
		cf = CFrame.new(0, top + 0.05, 0),
		color = Color3.new(1, 1, 1),
		material = M.Fabric,
		tint = 0.7,
	}
end

function Crowd.build(color: Color3, role: string?, variant: number?): Model
	local style = hueStyle(color)
	local v = Crowd.variantOf(variant)
	local look = LOOKS[v]
	local k = look.height
	local bodyH, bodyW, bodyD = Crowd.BODY_HEIGHT * k, look.width, 1.1
	local headD = 1.65 * k -- a big head: a crowd reads by its heads, hats and shoulders
	local headY = bodyH + headD / 2 - 0.1
	local shoulderY = bodyH - 0.5

	local model = Instance.new("Model")
	model.Name = if role then `CrowdFigure_{role}` else "CrowdFigure"
	model:SetAttribute("KitCrowd", true)
	model:SetAttribute("KitRole", role or "none")
	model:SetAttribute("KitVariant", v)
	model:SetAttribute("KitStyle", style)
	model:SetAttribute("KitCrest", Crowd.CREST_NAMES[style])
	model:SetAttribute("KitHeight", Crowd.HEIGHT * k)

	local function kingdom(f: number): Color3
		return shade(color, f)
	end
	local list: { Spec } = {}
	local function add(s: Spec)
		table.insert(list, s)
	end
	-- the body is always first (the PrimaryPart): the tabard in the kingdom colour
	add({
		name = "Body",
		size = Vector3.new(bodyW, bodyH, bodyD),
		cf = CFrame.new(0, bodyH / 2, 0),
		color = kingdom(look.body),
		material = M.Fabric,
		tint = look.body,
	})
	local skin = SKIN[look.skin]
	local headColor = skin
	if role == "captain" then
		headColor = STEEL
	elseif role == "elder" then
		headColor = WHITE_HAIR
	end
	add({
		name = "Head",
		shape = Enum.PartType.Ball,
		size = Vector3.new(headD, headD, headD),
		cf = CFrame.new(0, headY, 0),
		color = headColor,
		material = if role == "captain" then M.Metal else M.SmoothPlastic,
	})

	local function crest(): Spec
		local s = crestSpec(style, headY, headD)
		s.color = kingdom(s.tint or 1)
		return s
	end
	local function arms(): Spec
		local w = math.min(bodyW + 0.8, 2.3) -- shoulders wider than the body, inside the arena's 2.4-stud seat spacing
		local sleeve = look.sleeve
		return {
			name = "Arms",
			size = Vector3.new(w, 0.9, 0.85),
			cf = CFrame.new(0, shoulderY + look.lift * 1.5, 0.0) * CFrame.Angles(0, 0, rad(look.tilt)),
			color = if type(sleeve) == "number" then kingdom(sleeve) else sleeve,
			material = M.Fabric,
			tint = if type(sleeve) == "number" then sleeve else nil,
		}
	end

	if role == nil then
		add(crest())
		add(arms())
	elseif role == "blacksmith" then
		local x = bodyW / 2 + 0.55
		local len = 3.8
		add({ -- the haft, held at the right: from the hip to over the head
			name = "Handle",
			shape = Enum.PartType.Cylinder,
			size = cylinderUp(len, 0.42),
			cf = CFrame.new(x, 1.6 + len / 2, -0.15) * UPRIGHT,
			color = HAFT,
			material = M.Wood,
		})
		add({ -- the sledge head, a chunk wider than the haft
			name = "Hammer",
			size = Vector3.new(1.7, 1.0, 1.0),
			cf = CFrame.new(x, 1.6 + len + 0.25, -0.15),
			color = IRON,
			material = M.Metal,
		})
	elseif role == "healer" then
		add(crest())
		add({ -- the satchel at the left hip
			name = "Satchel",
			size = Vector3.new(1.5, 1.4, 0.95),
			cf = CFrame.new(-(bodyW / 2 + 0.55), 1.7, -0.15) * CFrame.Angles(0, 0, rad(10)),
			color = PALE,
			material = M.Fabric,
		})
	elseif role == "captain" then
		add({ -- a tall swept plume: a wedge about half the figure's height, its tall edge at the back of the helm
			name = "Plume",
			class = "WedgePart",
			size = Vector3.new(0.6, 2.6, 1.7),
			cf = CFrame.new(0, headY + headD / 2 + 1.15, 0.2),
			color = kingdom(1),
			material = M.Fabric,
			tint = 1,
		})
		add(arms())
	elseif role == "provisioner" then
		add(crest())
		add({ -- a basket carried in front at the belt: a wide disc
			name = "Basket",
			shape = Enum.PartType.Cylinder,
			size = cylinderUp(1.0, 2.3),
			cf = CFrame.new(0, 2.0, -(bodyD / 2 + 0.85)) * UPRIGHT,
			color = STRAW,
			material = M.Wood,
		})
	elseif role == "elder" then
		add(crest())
		local len = bodyH + headD + 2.6
		add({ -- a staff taller than the figure, at the left
			name = "Staff",
			shape = Enum.PartType.Cylinder,
			size = cylinderUp(len, 0.38),
			cf = CFrame.new(-(bodyW / 2 + 0.6), len / 2, -0.2) * UPRIGHT,
			color = HAFT,
			material = M.Wood,
		})
	elseif role == "merchant" then
		local x = bodyW / 2 + 0.7
		add({ -- the scales' post, held at the right
			name = "Post",
			shape = Enum.PartType.Cylinder,
			size = cylinderUp(3.4, 0.32),
			cf = CFrame.new(x, 2.4 + 1.7, -0.35) * UPRIGHT,
			color = PEWTER,
			material = M.Metal,
		})
		add({ -- the balance beam: thin and wide, tilted a little
			name = "Beam",
			size = Vector3.new(3.4, 0.28, 0.4),
			cf = CFrame.new(x, 6.0, -0.35) * CFrame.Angles(0, 0, rad(9)),
			color = PEWTER,
			material = M.Metal,
		})
	else
		error(`Kit.crowdFigure: unknown role {role}`)
	end

	local primary: BasePart? = nil
	for _, s in list do
		local p = makePart(model, s)
		if primary == nil then
			primary = p
		end
	end
	local body = primary :: BasePart
	body.PivotOffset = CFrame.new(0, -bodyH / 2, 0) -- pivot on the feet
	model.PrimaryPart = body
	return model
end

return Crowd
