--!strict
--[[
	Kit/Crowd — Kit.crowdFigure(kingdomColor, role?, variant?): the Crown Arena's crowd (FL-0072, CONTRACTS G12.6,
	design/crown-arena.md §7; D-026 primitive Parts only, nothing yields). Owner: FORGE-02.

	An ordinary figure is at most 4 primitive Parts (Crowd.MAX_PARTS); a key citizen, a figure with a `role`, at most 8
	(Crowd.ROLE_MAX_PARTS, CONTRACTS v0.4-g11a, so the six props read). Client-only (FORGE-04's crowd director clones, seats and bobs
	it; the server never builds one): no Root, no Humanoid, no Motor6D, no script. Every part is Anchored, non-colliding,
	non-touching, non-queryable and casts no shadow; the model's PrimaryPart is the body, its pivot is on the feet (so
	figure:PivotTo(seat.WorldCFrame) stands it on a seat attachment of Kit.arena, facing the ring: the model's front is -Z)
	and Kit.CROWD_HEIGHT is its nominal height. Deterministic: the same (colour, role, variant) always builds the same figure.

	Ordinary figure (4 parts): Body (the kingdom-colour tabard: a square block or a round robe), Head (a skin-tone ball, block or
	drum), Crest (the kingdom's crest in the kingdom colour, one of the soldiers' four silhouettes by NAME (Crowd.CREST_NAMES = the
	names of Character.CRESTS: spire / square / plume / dome) but its own primitive and size: a 1.0 x 1.7 spire CornerWedge, a 1.65
	square kepi, a plume that is a 0.7 cylinder swept back (the soldiers' plume is an upright wedge fin) and a 1.5 dome ball; the
	neutral colour a flat cap; so the stand reads by shape as well as colour: D-033) and Arms (one part: a bar across the shoulders level or tilted to wave,
	one arm thrown straight up, or the arms folded at the waist).
	`variant` (default 1, wraps over 12) varies skin, height (0.82 - 1.07), width, body shape, head shape, crest size, tabard shade
	(the kingdom colour 0.84 - 1.2 times), arm pose and sleeve, so a stand is not a row of clones.

	Key citizens (role: KeyRole of G12.1) stand on the rail podium with their role prop, in up to 8 parts, each reading by silhouette
	alone (the spec hashes the front, side and top outlines); every one keeps the kingdom's crest except the captain's steel helm:
		blacksmith   Body, Head, Crest, Arms, Apron (dark leather on the chest), Handle, Hammer, Peen: a sledge over the shoulder
		healer       Body, Head, Crest, Arms, Satchel (a big pale bag at the left hip), CrossV and CrossH (a red cross on it), Strap
		captain      Body, Head (steel helm), Plume (a tall kingdom-colour plume), Arms, Cape, Sash, Sword (a scabbard at the hip)
		provisioner  Body, Head, Crest, Basket (a wide straw tray in front), HandleL, HandleR, HandleBar (the basket's bridge), Bread
		elder        Body, Head (white hair), Crest, Staff, Crossbar, Banner (the kingdom's cloth), Finial, Beard
		merchant     Body, Head, Crest, Arm (held out in front), Post, Beam, PanL, PanR: brass scales
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

Crowd.MAX_PARTS = 4 -- an ordinary figure
Crowd.ROLE_MAX_PARTS = 8 -- a key citizen (CONTRACTS v0.4-g11a)
Crowd.VARIANTS = 12
Crowd.ROLES = table.freeze({ "blacksmith", "healer", "captain", "provisioner", "elder", "merchant" })
Crowd.HEIGHT = 5.0 -- nominal standing height (the variants scale 0.82 - 1.07 of it); the crest or a prop may rise above
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
local HAFT = Color3.fromRGB(139, 90, 51)
local WHITE_HAIR = Color3.fromRGB(238, 234, 226)
local STRAW = Color3.fromRGB(178, 138, 74) -- darker than hay: never the gold kingdom
local PALE = Color3.fromRGB(236, 226, 200)
local BRASS = Color3.fromRGB(214, 160, 52) -- the scales: bright metal that no kingdom's cloth is
local LEATHER = Color3.fromRGB(88, 58, 36) -- the smith's apron
local RED_CROSS = Color3.fromRGB(204, 48, 48)
local LOAF = Color3.fromRGB(222, 176, 104)
local FINIAL = Color3.fromRGB(232, 190, 70)

-- per-variant look: skin index, height scale, body width, body shape (block = a square tabard, round = a robe), head shape
-- (ball | block | drum), crest scale, arm pose (bar = across the shoulders at `tilt` degrees, sign = which side waves; up = one arm
-- straight up on the side of tilt's sign; fold = folded at the waist), arm lift, body tint (a shade of the kingdom colour), sleeve
-- (a number = a shade of the kingdom colour, else a fixed cloth colour)
type Look = {
	skin: number,
	height: number,
	width: number,
	round: boolean,
	head: string,
	crest: number,
	arm: string,
	tilt: number,
	lift: number,
	body: number,
	sleeve: number | Color3,
}
local TAN = Color3.fromRGB(196, 158, 108)
local LOOKS: { Look } = {
	{
		skin = 1,
		height = 1.0,
		width = 1.55,
		round = false,
		head = "ball",
		crest = 1.0,
		arm = "bar",
		tilt = 0,
		lift = 0,
		body = 1,
		sleeve = 1.3,
	},
	{
		skin = 3,
		height = 0.92,
		width = 1.4,
		round = false,
		head = "ball",
		crest = 1.1,
		arm = "bar",
		tilt = 22,
		lift = 0.15,
		body = 0.9,
		sleeve = 1.25,
	},
	{
		skin = 2,
		height = 1.05,
		width = 1.2,
		round = true,
		head = "ball",
		crest = 0.95,
		arm = "bar",
		tilt = -20,
		lift = 0.15,
		body = 1.15,
		sleeve = TAN,
	},
	{
		skin = 4,
		height = 0.82,
		width = 1.7,
		round = false,
		head = "block",
		crest = 1.1,
		arm = "fold",
		tilt = 0,
		lift = 0,
		body = 0.84,
		sleeve = 0.7,
	}, -- short and stout, arms folded
	{
		skin = 1,
		height = 1.07,
		width = 1.4,
		round = false,
		head = "ball",
		crest = 1.0,
		arm = "bar",
		tilt = 34,
		lift = 0,
		body = 1.08,
		sleeve = 1.3,
	}, -- tall, cheering
	{
		skin = 5,
		height = 0.97,
		width = 1.2,
		round = true,
		head = "drum",
		crest = 1.15,
		arm = "bar",
		tilt = 20,
		lift = 0.1,
		body = 0.92,
		sleeve = TAN,
	},
	{
		skin = 3,
		height = 1.04,
		width = 1.65,
		round = false,
		head = "ball",
		crest = 0.9,
		arm = "bar",
		tilt = -24,
		lift = 0.2,
		body = 1.2,
		sleeve = 0.72,
	},
	{
		skin = 6,
		height = 0.9,
		width = 1.2,
		round = true,
		head = "ball",
		crest = 1.05,
		arm = "bar",
		tilt = -34,
		lift = 0,
		body = 1.0,
		sleeve = 1.3,
	}, -- cheering
	{
		skin = 2,
		height = 0.95,
		width = 1.5,
		round = false,
		head = "drum",
		crest = 1.0,
		arm = "up",
		tilt = 1,
		lift = 0,
		body = 1.12,
		sleeve = 1.25,
	}, -- right arm up
	{
		skin = 4,
		height = 1.02,
		width = 1.35,
		round = false,
		head = "block",
		crest = 1.15,
		arm = "up",
		tilt = -1,
		lift = 0,
		body = 0.88,
		sleeve = 0.72,
	}, -- left arm up
	{
		skin = 1,
		height = 0.88,
		width = 1.2,
		round = true,
		head = "block",
		crest = 0.95,
		arm = "fold",
		tilt = 0,
		lift = 0,
		body = 1.0,
		sleeve = 1.3,
	},
	{
		skin = 5,
		height = 1.06,
		width = 1.6,
		round = false,
		head = "drum",
		crest = 1.0,
		arm = "bar",
		tilt = 0,
		lift = 0,
		body = 0.95,
		sleeve = TAN,
	},
}
assert(#LOOKS == Crowd.VARIANTS, "one look per variant")

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

-- A plain box spec (the colour is final unless `tint` is given: then it is shade(kingdom, tint)).
local function boxSpec(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?
): Spec
	return { name = name, size = size, cf = cf, color = color, material = material, tint = tint }
end

-- A cylinder standing along Y at cf (length, diameter).
local function rodSpec(name: string, len: number, dia: number, cf: CFrame, color: Color3, material: Enum.Material): Spec
	return {
		name = name,
		shape = Enum.PartType.Cylinder,
		size = cylinderUp(len, dia),
		cf = cf * UPRIGHT,
		color = color,
		material = material,
	}
end

-- The kingdom's crest on a head centred at (0, hy, 0) of diameter hd, in the figure frame; `sc` scales the crest.
local function crestSpec(style: string, hy: number, hd: number, sc: number): Spec
	local top = hy + hd / 2
	if style == "crimson" then
		local s = Vector3.new(1.0, 1.7, 1.0) * sc
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
			size = Vector3.new(1.65, 0.85, 1.65) * sc,
			cf = CFrame.new(0, top + 0.18 * sc, 0),
			color = Color3.new(1, 1, 1),
			material = M.Metal,
			tint = 1,
		}
	elseif style == "emerald" then
		local len, d = 2.4 * sc, 0.7
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
			size = Vector3.new(1.5, 1.5, 1.5) * sc,
			cf = CFrame.new(0, top + 0.3 * sc, 0),
			color = Color3.new(1, 1, 1),
			material = M.Metal,
			tint = 1,
		}
	end
	return { -- neutral: a plain flat cap
		name = "Crest",
		size = Vector3.new(1.5, 0.4, 1.5) * sc,
		cf = CFrame.new(0, top + 0.05, 0),
		color = Color3.new(1, 1, 1),
		material = M.Fabric,
		tint = 0.7,
	}
end

-- The head: a ball, a block or a drum, all `hd` tall and centred at (0, hy, 0).
local function headSpec(kind: string, hy: number, hd: number, color: Color3, material: Enum.Material): Spec
	if kind == "block" then
		return boxSpec("Head", Vector3.new(hd * 0.9, hd, hd * 0.9), CFrame.new(0, hy, 0), color, material)
	elseif kind == "drum" then
		return rodSpec("Head", hd, hd * 0.92, CFrame.new(0, hy, 0), color, material)
	end
	return {
		name = "Head",
		shape = Enum.PartType.Ball,
		size = Vector3.new(hd, hd, hd),
		cf = CFrame.new(0, hy, 0),
		color = color,
		material = material,
	}
end

function Crowd.build(color: Color3, role: string?, variant: number?): Model
	local style = hueStyle(color)
	local v = Crowd.variantOf(variant)
	local look = LOOKS[v]
	local k = look.height
	-- a round robe is a cylinder 1.2 across (the back row's seats sit 1.2 from the stand's back wall); a block is 1.1 deep
	local bodyH, bodyW, bodyD = Crowd.BODY_HEIGHT * k, look.width, if look.round then look.width else 1.1
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
	-- a part in the kingdom's cloth, shade factor f
	local function cloth(name: string, size: Vector3, cf: CFrame, f: number): Spec
		return boxSpec(name, size, cf, kingdom(f), M.Fabric, f)
	end
	local list: { Spec } = {}
	local function add(s: Spec)
		table.insert(list, s)
	end
	-- the body is always first (the PrimaryPart): the tabard in the kingdom colour, a square block or a round robe
	if look.round then
		add({
			name = "Body",
			shape = Enum.PartType.Cylinder,
			size = cylinderUp(bodyH, bodyW),
			cf = CFrame.new(0, bodyH / 2, 0) * UPRIGHT,
			color = kingdom(look.body),
			material = M.Fabric,
			tint = look.body,
		})
	else
		add(cloth("Body", Vector3.new(bodyW, bodyH, bodyD), CFrame.new(0, bodyH / 2, 0), look.body))
	end
	local skin = SKIN[look.skin]
	local headColor = skin
	if role == "captain" then
		headColor = STEEL
	elseif role == "elder" then
		headColor = WHITE_HAIR
	end
	add(headSpec(look.head, headY, headD, headColor, if role == "captain" then M.Metal else M.SmoothPlastic))

	local function crest(): Spec
		local s = crestSpec(style, headY, headD, look.crest)
		s.color = kingdom(s.tint or 1)
		return s
	end
	local function sleeveColor(): (Color3, number?)
		local sleeve = look.sleeve
		if type(sleeve) == "number" then
			return kingdom(sleeve), sleeve
		end
		return sleeve, nil
	end
	-- the arms of an ordinary figure (one part): a bar across the shoulders, one arm straight up, or folded at the waist
	local function arms(): Spec
		local c, t = sleeveColor()
		if look.arm == "up" then
			local side = if look.tilt >= 0 then 1 else -1
			return boxSpec(
				"Arms",
				Vector3.new(0.62, 2.5, 0.7),
				CFrame.new(side * (bodyW / 2 + 0.21), shoulderY + 0.35, 0),
				c,
				M.Fabric,
				t
			)
		elseif look.arm == "fold" then
			return boxSpec(
				"Arms",
				Vector3.new(bodyW + 0.5, 0.75, 1.2),
				CFrame.new(0, bodyH * 0.5, -0.2),
				c,
				M.Fabric,
				t
			)
		end
		local w = math.min(bodyW + 0.8, 2.3) -- shoulders wider than the body, inside the arena's 2.4-stud seat spacing
		return boxSpec(
			"Arms",
			Vector3.new(w, 0.9, 0.85),
			CFrame.new(0, shoulderY + look.lift * 1.5, 0.0) * CFrame.Angles(0, 0, rad(look.tilt)),
			c,
			M.Fabric,
			t
		)
	end
	-- a key citizen's arms: always the level bar (the props are held at the sides)
	local function armsLevel(): Spec
		local c, t = sleeveColor()
		return boxSpec(
			"Arms",
			Vector3.new(math.min(bodyW + 0.8, 2.3), 0.9, 0.85),
			CFrame.new(0, shoulderY, 0),
			c,
			M.Fabric,
			t
		)
	end

	if role == nil then
		add(crest())
		add(arms())
	elseif role == "blacksmith" then
		local x = bodyW / 2 + 0.6
		local len = 4.2
		add(crest())
		add(armsLevel())
		add(boxSpec( -- a dark leather apron on the chest
			"Apron",
			Vector3.new(bodyW * 0.8, bodyH * 0.62, 0.22),
			CFrame.new(0, bodyH * 0.38, -(bodyD / 2 + 0.1)),
			LEATHER,
			M.Fabric
		))
		add(rodSpec("Handle", len, 0.55, CFrame.new(x, 1.6 + len / 2, -0.15), HAFT, M.Wood)) -- the haft, held at the right
		add(boxSpec( -- the sledge head, a chunk wider than the haft
			"Hammer",
			Vector3.new(2.2, 1.3, 1.3),
			CFrame.new(x, 1.6 + len + 0.35, -0.15),
			IRON,
			M.Metal
		))
		add(boxSpec( -- the peen: a smaller block on the head's far end
			"Peen",
			Vector3.new(0.7, 0.8, 0.8),
			CFrame.new(x + 1.4, 1.6 + len + 0.35, -0.15),
			STEEL,
			M.Metal
		))
	elseif role == "healer" then
		add(crest())
		add(armsLevel())
		-- the satchel at the left hip, a red cross on its face, a strap from the right shoulder
		local satchel = CFrame.new(-(bodyW / 2 + 0.65), 1.8, -0.15) * CFrame.Angles(0, 0, rad(10))
		add(boxSpec("Satchel", Vector3.new(1.9, 1.8, 1.1), satchel, PALE, M.Fabric))
		add(boxSpec("CrossV", Vector3.new(0.34, 1.1, 0.12), satchel * CFrame.new(0, 0, -0.58), RED_CROSS, M.Fabric))
		add(boxSpec("CrossH", Vector3.new(1.1, 0.34, 0.14), satchel * CFrame.new(0, 0, -0.6), RED_CROSS, M.Fabric)) -- 0.02 proud of CrossV: never coplanar
		add(
			boxSpec(
				"Strap",
				Vector3.new(0.36, 2.8, 0.12),
				CFrame.new(0, bodyH * 0.5, -(bodyD / 2 + 0.07)) * CFrame.Angles(0, 0, rad(-38)),
				PALE,
				M.Fabric
			)
		)
	elseif role == "captain" then
		add({ -- a tall swept plume: a wedge, its tall edge at the back of the helm
			name = "Plume",
			class = "WedgePart",
			size = Vector3.new(0.7, 3.0, 1.9),
			cf = CFrame.new(0, headY + headD / 2 + 1.3, 0.2),
			color = kingdom(1),
			material = M.Fabric,
			tint = 1,
		})
		add(armsLevel())
		add(
			cloth(
				"Cape",
				Vector3.new(bodyW + 0.2, bodyH * 0.85, 0.18),
				CFrame.new(0, bodyH * 0.55, bodyD / 2 + 0.13),
				0.7
			)
		)
		add(cloth( -- a kingdom sash across the chest
			"Sash",
			Vector3.new(0.42, 2.8, 0.12),
			CFrame.new(0, bodyH * 0.5, -(bodyD / 2 + 0.07)) * CFrame.Angles(0, 0, rad(-35)),
			1.45
		))
		add(boxSpec( -- the sword's scabbard at the left hip
			"Sword",
			Vector3.new(0.34, 2.6, 0.36),
			CFrame.new(-(bodyW / 2 + 0.3), 1.35, -0.1) * CFrame.Angles(0, 0, rad(-16)),
			STEEL,
			M.Metal
		))
	elseif role == "provisioner" then
		add(crest())
		-- a basket carried in front at the belt: a wide tray, a bridge handle over it and a loaf
		local z = -(bodyD / 2 + 1.15)
		add(rodSpec("Basket", 1.1, 2.7, CFrame.new(0, 2.0, z), STRAW, M.Wood))
		add(rodSpec("HandleL", 1.9, 0.32, CFrame.new(-1.05, 3.45, z), STRAW, M.Wood))
		add(rodSpec("HandleR", 1.9, 0.32, CFrame.new(1.05, 3.45, z), STRAW, M.Wood))
		add(boxSpec("HandleBar", Vector3.new(2.5, 0.34, 0.34), CFrame.new(0, 4.5, z), STRAW, M.Wood))
		add({
			name = "Bread",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.2, 1.2, 1.2),
			cf = CFrame.new(0, 2.95, z),
			color = LOAF,
			material = M.SmoothPlastic,
		})
	elseif role == "elder" then
		add(crest())
		local len = bodyH + headD + 2.2
		local sx = -(bodyW / 2 + 1.05)
		add(rodSpec("Staff", len, 0.55, CFrame.new(sx, len / 2, -0.2), HAFT, M.Wood)) -- a stout staff, at the left
		add(boxSpec("Crossbar", Vector3.new(2.2, 0.26, 0.26), CFrame.new(sx, len - 0.5, -0.2), HAFT, M.Wood))
		add(cloth("Banner", Vector3.new(1.8, 2.6, 0.1), CFrame.new(sx, len - 0.5 - 0.13 - 1.3, -0.2), 1)) -- the kingdom's cloth
		add({
			name = "Finial",
			shape = Enum.PartType.Ball,
			size = Vector3.new(0.7, 0.7, 0.7),
			cf = CFrame.new(sx, len + 0.2, -0.2),
			color = FINIAL,
			material = M.Metal,
		})
		add(boxSpec("Beard", Vector3.new(0.9, 1.0, 0.45), CFrame.new(0, bodyH, -0.6), WHITE_HAIR, M.Fabric))
	elseif role == "merchant" then
		add(crest())
		-- the scales held out in front, high: an arm, a post, a tilted beam and two pans directly under its ends
		local px, pz = bodyW / 2 + 0.3, -2.0
		add(
			boxSpec(
				"Arm",
				Vector3.new(0.75, 0.8, 2.0),
				CFrame.new(px, bodyH - 0.7, -1.2),
				kingdom(1.25),
				M.Fabric,
				1.25
			)
		)
		add(rodSpec("Post", 3.4, 0.5, CFrame.new(px, 2.9 + 1.7, pz), BRASS, M.Metal))
		local tilt, half = 8, 1.7
		add(
			boxSpec(
				"Beam",
				Vector3.new(half * 2, 0.5, 0.6),
				CFrame.new(px, 6.2, pz) * CFrame.Angles(0, 0, rad(tilt)),
				BRASS,
				M.Metal
			)
		)
		for _, side in { -1, 1 } do
			local ex = px + side * half * math.cos(rad(tilt))
			local ey = 6.2 + side * half * math.sin(rad(tilt))
			add(
				rodSpec(
					if side < 0 then "PanL" else "PanR",
					0.25,
					1.5,
					CFrame.new(ex, ey - 0.25 - 0.12, pz),
					BRASS,
					M.Metal
				)
			)
		end
	else
		error(`Kit.crowdFigure: unknown role {role}`)
	end

	assert(#list <= (if role then Crowd.ROLE_MAX_PARTS else Crowd.MAX_PARTS), "crowd figure over its part cap")
	local primary: BasePart? = nil
	for _, s in list do
		local p = makePart(model, s)
		if primary == nil then
			primary = p
		end
	end
	local body = primary :: BasePart
	-- pivot on the feet, upright (a round body is a cylinder turned upright, so its own frame is turned too)
	body.PivotOffset = if look.round
		then UPRIGHT:Inverse() * CFrame.new(0, -bodyH / 2, 0)
		else CFrame.new(0, -bodyH / 2, 0)
	model.PrimaryPart = body
	return model
end

return Crowd
