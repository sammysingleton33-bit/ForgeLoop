--!strict
--[[
	Kit/Gear — duel armour, shield and weapons: Kit.armour(armour, kingdomColor) -> { Accessory }, Kit.shield(kingdomColor?) ->
	Accessory and Kit.weapon(weapon, kingdomColor?, opts?) -> Tool (FL-0072, CONTRACTS G12.1 Armour / Weapon, G12.6,
	design/crown-arena.md §5; D-026 primitive Parts only, nothing yields, no scripts). Owner: FORGE-02.

	Types are G12.1's: Armour = "light" | "medium" | "heavy", Weapon = "swordShield" | "greatsword" | "spear" | "mace".
	Every option is a sidegrade (design §5): none is the "gold" one. They differ in silhouette and in how much steel against
	cloth they show, and take the kingdom colour on the same kinds of places (plume, comb, tabard, ribbon), so appearance never
	says which is stronger. The kingdom-coloured parts carry KitTint (Kit.setKingdomColor works on an Accessory or a Tool).

	Armour = Accessories built like Kit.regalia (Character.lua): modelled in attachment space (origin = the avatar's attachment, axes
	identity, front -Z), a Handle holding an Attachment that carries the body attachment's name, the other parts welded to it,
	every part unanchored, massless, non-colliding, non-touching, non-queryable. They fit R15 and R6, which both carry
	HatAttachment, BodyFrontAttachment, BodyBackAttachment, LeftCollarAttachment and RightCollarAttachment (names from the Roblox
	attachment-point reference; the specs use stand-in avatars with those names: Studio fit is unverified).
		light    KitLightCap (Hat: leather cap, wide brim, a kingdom feather), KitLightJerkin (Front: leather vest, belt, pouch, a
		         kingdom bandolier), KitLightCloak (Back: a short kingdom cape on a mantle)   slim, no shoulders, a flying cape
		medium   KitMediumHelm (Hat: steel dome, nasal, a kingdom comb), KitMediumMail (Front: mail, a kingdom tabard, belt),
		         KitMediumPauldronLeft / Right (Collar: steel cops with a kingdom cap)    round shoulders
		heavy    KitHeavyHelm (Hat: a tall flat-topped great helm, a kingdom plume), KitHeavyPlate (Front: a deep breastplate,
		         a kingdom surcoat, two tassets), KitHeavyBack (Back: back plate), KitHeavyPauldronLeft / Right (Collar: wide
		         layered spaulders with a kingdom ridge)                              broad, boxy shoulders
	Attributes on every Accessory: KitArmour, KitPiece.

	Shield = an Accessory on the LEFT hand (Kit.shield; a Tool is one hand, and the duel poses guard with the left arm). Built like
	the armour pieces, on the attachment LeftGripAttachment, modelled in the left hand's grip frame: the frame the hand has when the
	arm points forward (+Y up, -Z forward = along the arm toward the fingers, +X right), the same frame the right hand's Tool grip
	uses. A round buckler (rim, kingdom-coloured face, iron band, boss; 4 parts, the old Tool shield's parts) sits just ahead of
	the fist and a little to the outside (-X), facing forward: raised across the chest in the guard it reads as held on the left
	forearm. With the arm HANGING the grip frame is turned (its -Z points down), so a hanging arm carries the shield flat under the
	fist: equip it with the left arm raised (the duel's ready and guard poses do). Whether LeftGripAttachment exists on R6's "Left
	Arm", and its exact frame on R15's LeftHand, is UNVERIFIED in Studio (the stand-in avatars follow the Roblox attachment
	reference). Attributes: KitPiece = "Shield", KitShield = "shield" (the value Kit.weapon("swordShield") also carries), no
	KitArmour.

	Carried goods (Kit.carried(resource) -> Model, resource = food | wood | stone | gold; visual upgrade, FORGE-04's carry pose): what a
	citizen holds in both hands while it carries a load home, readable at the start camera (zoom 70: about 0.07 studs per pixel). A Model
	of 3 or 4 part-built primitives with ONE PrimaryPart (a part of the prop, at the origin: the model's pivot is the build origin, via
	PivotOffset) and every other part welded to it; no scripts; unanchored, massless, no collide, no touch, no query. Modelled for the
	carry pose (arms forward, hands about 2.6 studs apart, chest height) about its centre: +Y up, front -Z; at most 2.6 wide (between
	the hands), 1.2 tall and 1.2 deep (it starts in front of the chest). The attacher (EntityController, FORGE-01's, under FORGE-04's
	exception) places the pivot on the Torso at CFrame.new(0, 0, -1.2) (the hands' midpoint is (0, 0.02, -1.17) in the Torso frame),
	shows it only while the citizen carries that resource and removes it otherwise. A load is the resource's own goods in its own
	colours, in the family of its node's marker (Props.NODE_MARKER_COLORS: stone ice white, gold yellow, wood orange, food red-pink)
	so it reads like its node, not the marker's glow colour copied onto the goods: the stone is pale grey-white, the gold yellow, the
	logs brown (orange is the marker's glow, not a log's), and only the food carries its marker's red-pink exactly (the apple).
	The key colour (the part with the most volume) is the basket's tan, the logs' bark brown, the stone's ice white and the bars' gold.
		food    a tan wicker basket with a darker rim, a red-pink apple (the food marker's colour) and a golden loaf (4 parts)
		wood    a bundle of three brown logs (the top one paler) tied with a pale rope band (4 parts)
		stone   a pale grey-white block with a darker grey block and a chip on it (3 parts)
		gold    a stepped stack of three yellow gold bars (the top one lighter) (3 parts)
	Attributes: KitCarried = the resource, KitPiece = "Carried".

	Weapon = a Tool with a Handle (the grip, at the origin), no scripts, RequiresHandle, not droppable. Modelled in grip space (the
	frame an equipped Tool's Grip puts on the hand: +Y up, -Z forward, +X right): the blade (or haft) rises along +Y, so an avatar
	holding it with the arm forward carries it upright. Grip = the Handle's CFrame inverse (the cylinder Handle is turned upright). The other parts are welded to the Handle; hits are resolved server-side, so no part
	touches or collides. Attributes: KitWeapon, KitHands, KitReach (the tip's height above the grip, studs); swordShield also KitShield.
		swordShield  a straight blade (1 hand). Kit.weapon("swordShield", color) still carries the round shield on the Tool, held by
		             the sword hand across the chest (10 parts: the sword's 6 and the shield's 4: the form before Kit.shield);
		             Kit.weapon("swordShield", color, { shield = false }) is the sword alone (6 parts; the same Handle, Grip and
		             KitReach) for a champion who wears Kit.shield on the left hand. KitShield = "shield" on both: "this weapon
		             goes with Kit.shield(color)". The other weapons ignore opts and carry no KitShield.
		greatsword   a long broad blade, a wide guard (2 hands)
		spear        a 9-stud shaft with a leaf head and a kingdom pennant (2 hands)
		mace         a 5-stud haft and a studded ball head (a morning star) held clear above the wearer's head, with a kingdom ribbon (1 hand)
]]

local Parts = require("./Parts")

local C = Parts.C
local shade = Parts.shade

local M = Enum.Material
local rad = math.rad

local Gear = {}

Gear.ARMOURS = table.freeze({ "light", "medium", "heavy" })
Gear.WEAPONS = table.freeze({ "swordShield", "greatsword", "spear", "mace" })
Gear.MAX_PARTS_PER_ACCESSORY = 10
Gear.MAX_PARTS_PER_WEAPON = 12
Gear.RESOURCES = table.freeze({ "food", "wood", "stone", "gold" })
Gear.MAX_PARTS_PER_CARRIED = 4
Gear.CARRIED_BOUNDS = Vector3.new(2.6, 1.2, 1.2) -- the most a carried prop may measure: between the hands, tall, deep (studs)
Gear.NEUTRAL_COLOR = Color3.fromRGB(208, 200, 184)

local STEEL = Color3.fromRGB(176, 182, 192)
local STEEL_LIGHT = Color3.fromRGB(206, 212, 222)
local STEEL_DARK = Color3.fromRGB(84, 90, 100)
local PLATE = Color3.fromRGB(112, 120, 134) -- the heavy set's blackened plate: lighter than STEEL_DARK so it reads on a dark body
local IRON = Color3.fromRGB(58, 62, 70)
local LEATHER = Color3.fromRGB(120, 78, 46)
local LEATHER_DARK = Color3.fromRGB(84, 56, 34)
local ASH = Color3.fromRGB(198, 152, 104)

type Spec = {
	name: string,
	shape: Enum.PartType?,
	class: string?, -- "WedgePart" | "CornerWedgePart"
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?, -- kingdom shade factor (the colour is then shade(kingdom, tint))
}

-- Cylinder along Y: Roblox cylinders run along X, so the size is (length, dia, dia) and the CFrame turns it up.
local UPRIGHT = CFrame.Angles(0, 0, rad(90))
local function up(len: number, dia: number): Vector3
	return Vector3.new(len, dia, dia)
end

local function ballSpec(
	name: string,
	dia: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?
): Spec
	return {
		name = name,
		shape = Enum.PartType.Ball,
		size = Vector3.new(dia, dia, dia),
		cf = cf,
		color = color,
		material = material,
		tint = tint,
	}
end

local function boxSpec(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?
): Spec
	return {
		name = name,
		shape = Enum.PartType.Block,
		size = size,
		cf = cf,
		color = color,
		material = material,
		tint = tint,
	}
end

-- a cylinder along local Y at cf (length, diameter)
local function rodSpec(
	name: string,
	len: number,
	dia: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?
): Spec
	return {
		name = name,
		shape = Enum.PartType.Cylinder,
		size = up(len, dia),
		cf = cf * UPRIGHT,
		color = color,
		material = material,
		tint = tint,
	}
end

-- a cylinder along local Z (shields) at cf
local function discSpec(
	name: string,
	dia: number,
	thick: number,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?
): Spec
	return {
		name = name,
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(thick, dia, dia),
		cf = cf * CFrame.Angles(0, rad(90), 0),
		color = color,
		material = material,
		tint = tint,
	}
end

local function wedgeSpec(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?
): Spec
	return { name = name, class = "WedgePart", size = size, cf = cf, color = color, material = material, tint = tint }
end

local function build(parent: Instance, s: Spec, kingdom: Color3, partName: string?): BasePart
	local p: BasePart
	if s.class == "WedgePart" then
		p = Instance.new("WedgePart")
	elseif s.class == "CornerWedgePart" then
		p = Instance.new("CornerWedgePart")
	else
		local part = Instance.new("Part")
		part.Shape = s.shape or Enum.PartType.Block
		p = part
	end
	p.Name = partName or s.name
	p.Size = s.size
	p.CFrame = s.cf
	p.Color = if s.tint then shade(kingdom, s.tint) else s.color
	p.Material = s.material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	if s.tint then
		p:SetAttribute("KitTint", s.tint)
	end
	p:SetAttribute("KitPart", s.name)
	p.Parent = parent
	return p
end

local function weld(handle: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = part
	w.Parent = part
end

-- An Accessory on a body attachment: the first spec is the Handle, the rest are welded to it.
local function accessory(
	armour: string?, -- nil: not armour (the shield)
	piece: string,
	attachName: string,
	specs: { Spec },
	kingdom: Color3
): Accessory
	local acc = Instance.new("Accessory")
	acc.Name = `Kit{piece}`
	if armour then
		acc:SetAttribute("KitArmour", armour)
	end
	acc:SetAttribute("KitPiece", piece)
	local handle = build(acc, specs[1], kingdom, "Handle")
	local a = Instance.new("Attachment")
	a.Name = attachName
	a.CFrame = handle.CFrame:Inverse()
	a.Parent = handle
	for i = 2, #specs do
		weld(handle, build(acc, specs[i], kingdom, nil))
	end
	return acc
end

-- ------------------------------------------------------------------ armour

-- a feather: a thin rod swept back by `tilt` degrees from `at`
local function feather(len: number, dia: number, tilt: number, at: Vector3, tint: number): Spec
	return rodSpec(
		"Feather",
		len,
		dia,
		CFrame.new(at) * CFrame.Angles(rad(tilt), 0, 0) * CFrame.new(0, len / 2, 0),
		C.cloth,
		M.Fabric,
		tint
	)
end

-- a plume: a wedge whose tall edge is at the back, so it rises and sweeps back over the helm
local function plume(size: Vector3, at: Vector3, tint: number): Spec
	return wedgeSpec("Plume", size, CFrame.new(at), C.cloth, M.Fabric, tint)
end

local function lightSet(color: Color3): { Accessory }
	local cap = accessory("light", "LightCap", "HatAttachment", {
		ballSpec("Cap", 1.7, CFrame.new(0, 0.12, 0), LEATHER, M.Fabric),
		rodSpec("Brim", 0.14, 2.35, CFrame.new(0, -0.38, 0), LEATHER_DARK, M.Fabric),
		feather(2.8, 0.34, 28, Vector3.new(0.55, 0.5, 0.35), 1),
	}, color)
	local jerkin = accessory("light", "LightJerkin", "BodyFrontAttachment", {
		boxSpec("Vest", Vector3.new(1.8, 1.55, 0.2), CFrame.new(0, 0, -0.12), LEATHER, M.Fabric),
		boxSpec("Belt", Vector3.new(2.0, 0.26, 0.3), CFrame.new(0, -0.82, -0.14), LEATHER_DARK, M.Fabric),
		boxSpec("Pouch", Vector3.new(0.55, 0.55, 0.32), CFrame.new(0.75, -1.12, -0.18), LEATHER_DARK, M.Fabric),
		boxSpec(
			"Bandolier",
			Vector3.new(0.34, 2.1, 0.12),
			CFrame.new(0.1, 0.0, -0.26) * CFrame.Angles(0, 0, rad(32)),
			C.cloth,
			M.Fabric,
			1
		),
	}, color)
	-- a long swept cape on a mantle and a tall feather: the kingdom colour in a big flying shape (so the light set is not the plain one)
	local cloak = accessory("light", "LightCloak", "BodyBackAttachment", {
		boxSpec(
			"Cape",
			Vector3.new(2.7, 2.7, 0.16),
			CFrame.new(0, -0.9, 0.34) * CFrame.Angles(rad(-12), 0, 0),
			C.cloth,
			M.Fabric,
			1
		),
		boxSpec("Mantle", Vector3.new(2.6, 0.5, 0.6), CFrame.new(0, 0.62, 0.22), C.cloth, M.Fabric, 0.78),
	}, color)
	return { cap, jerkin, cloak }
end

local function pauldron(
	armour: string,
	piece: string,
	attach: string,
	side: number,
	specs: { Spec },
	color: Color3
): Accessory
	local mirrored = {}
	for i, s in specs do
		local m = table.clone(s)
		-- offsets are written for the right shoulder (+X); the left mirrors X
		local pos = s.cf.Position
		local rx, ry, rz = s.cf:ToEulerAnglesXYZ()
		m.cf = CFrame.new(side * pos.X, pos.Y, pos.Z) * CFrame.Angles(rx, -side * ry, -side * rz)
		mirrored[i] = m
	end
	return accessory(armour, piece, attach, mirrored, color)
end

local function mediumSet(color: Color3): { Accessory }
	local helm = accessory("medium", "MediumHelm", "HatAttachment", {
		ballSpec("Helm", 1.85, CFrame.new(0, 0.05, 0), STEEL, M.Metal),
		rodSpec("Rim", 0.2, 2.0, CFrame.new(0, -0.55, 0), STEEL_DARK, M.Metal),
		boxSpec("Nasal", Vector3.new(0.22, 0.95, 0.16), CFrame.new(0, -0.35, -0.9), STEEL, M.Metal),
		boxSpec("Comb", Vector3.new(0.3, 0.5, 1.7), CFrame.new(0, 0.9, 0), C.cloth, M.Fabric, 1),
	}, color)
	local mail = accessory("medium", "MediumMail", "BodyFrontAttachment", {
		boxSpec("Mail", Vector3.new(1.95, 1.75, 0.24), CFrame.new(0, 0, -0.13), STEEL, M.Metal),
		boxSpec("Tabard", Vector3.new(1.0, 2.5, 0.16), CFrame.new(0, -0.4, -0.3), C.cloth, M.Fabric, 1),
		boxSpec("Belt", Vector3.new(2.05, 0.26, 0.32), CFrame.new(0, -0.9, -0.17), LEATHER_DARK, M.Fabric),
		boxSpec("Gorget", Vector3.new(1.3, 0.4, 0.3), CFrame.new(0, 0.78, -0.15), STEEL_DARK, M.Metal),
	}, color)
	local function cop(piece: string, attach: string, side: number): Accessory
		return pauldron("medium", piece, attach, side, {
			ballSpec("Cop", 1.3, CFrame.new(0.5, 0.5, 0), STEEL, M.Metal),
			rodSpec("Cap", 0.16, 0.9, CFrame.new(0.5, 1.1, 0), C.cloth, M.Fabric, 1),
		}, color)
	end
	return {
		helm,
		mail,
		cop("MediumPauldronLeft", "LeftCollarAttachment", -1),
		cop("MediumPauldronRight", "RightCollarAttachment", 1),
	}
end

local function heavySet(color: Color3): { Accessory }
	local helm = accessory("heavy", "HeavyHelm", "HatAttachment", {
		boxSpec("Helm", Vector3.new(1.95, 1.85, 1.95), CFrame.new(0, 0.02, 0), PLATE, M.Metal),
		boxSpec("Visor", Vector3.new(1.55, 0.22, 0.14), CFrame.new(0, 0.1, -0.99), IRON, M.Metal),
		rodSpec("Ring", 0.22, 2.15, CFrame.new(0, 0.95, 0), STEEL, M.Metal),
		plume(Vector3.new(0.75, 2.1, 1.6), Vector3.new(0, 0.9 + 1.0, 0.15), 1),
	}, color)
	local plate = accessory("heavy", "HeavyPlate", "BodyFrontAttachment", {
		boxSpec("Plate", Vector3.new(2.35, 2.0, 0.55), CFrame.new(0, -0.05, -0.2), PLATE, M.Metal),
		boxSpec("Surcoat", Vector3.new(1.05, 2.3, 0.14), CFrame.new(0, -0.3, -0.54), C.cloth, M.Fabric, 1),
		boxSpec("Belt", Vector3.new(2.4, 0.3, 0.6), CFrame.new(0, -0.98, -0.22), IRON, M.Metal),
		boxSpec("TassetLeft", Vector3.new(1.0, 0.95, 0.3), CFrame.new(-0.62, -1.55, -0.22), STEEL, M.Metal),
		boxSpec("TassetRight", Vector3.new(1.0, 0.95, 0.3), CFrame.new(0.62, -1.55, -0.22), STEEL, M.Metal),
	}, color)
	local back = accessory("heavy", "HeavyBack", "BodyBackAttachment", {
		boxSpec("BackPlate", Vector3.new(2.35, 1.95, 0.42), CFrame.new(0, 0, 0.2), PLATE, M.Metal),
		boxSpec("Spine", Vector3.new(0.3, 1.8, 0.2), CFrame.new(0, 0, 0.46), STEEL, M.Metal),
	}, color)
	local function spaulder(piece: string, attach: string, side: number): Accessory
		return pauldron("heavy", piece, attach, side, {
			boxSpec(
				"Spaulder",
				Vector3.new(1.5, 0.6, 1.5),
				CFrame.new(0.5, 0.08, 0) * CFrame.Angles(0, 0, rad(-8)),
				PLATE,
				M.Metal
			),
			boxSpec(
				"Lames",
				Vector3.new(1.25, 0.45, 1.3),
				CFrame.new(0.6, -0.4, 0) * CFrame.Angles(0, 0, rad(-8)),
				STEEL,
				M.Metal
			),
			boxSpec(
				"Ridge",
				Vector3.new(1.3, 0.2, 0.5),
				CFrame.new(0.5, 0.42, 0) * CFrame.Angles(0, 0, rad(-8)),
				C.cloth,
				M.Fabric,
				1
			),
		}, color)
	end
	return {
		helm,
		plate,
		back,
		spaulder("HeavyPauldronLeft", "LeftCollarAttachment", -1),
		spaulder("HeavyPauldronRight", "RightCollarAttachment", 1),
	}
end

function Gear.armour(armour: string, kingdomColor: Color3?): { Accessory }
	local color = kingdomColor or Gear.NEUTRAL_COLOR
	if armour == "light" then
		return lightSet(color)
	elseif armour == "medium" then
		return mediumSet(color)
	elseif armour == "heavy" then
		return heavySet(color)
	end
	error(`Kit.armour: unknown armour {armour} (light | medium | heavy)`)
end

-- ------------------------------------------------------------------ shield

-- The round shield's four parts about `c` (a disc facing -Z, thickness stacking toward -Z): a wooden rim, the kingdom-coloured
-- face, an iron band and a steel boss. The first is the Accessory's Handle; on the sword Tool (the form before Kit.shield) the
-- same parts ride the Tool's Handle.
local function roundShieldSpecs(c: CFrame): { Spec }
	return {
		discSpec("ShieldRim", 2.8, 0.28, c, LEATHER_DARK, M.Wood),
		discSpec("ShieldFace", 2.4, 0.2, c * CFrame.new(0, 0, -0.14), C.cloth, M.SmoothPlastic, 1),
		discSpec("ShieldBand", 1.4, 0.12, c * CFrame.new(0, 0, -0.24), IRON, M.Metal),
		ballSpec("ShieldBoss", 0.75, (c * CFrame.new(0, 0, -0.34)), STEEL, M.Metal),
	}
end

-- In the left hand's grip frame (the arm pointing forward: -Z along the arm toward the fingers, +X right, so the outside of the
-- left arm is -X): the disc's back face is a fist's depth ahead of the grip point, its centre a little to the outside and low, so
-- the fist holds it at its middle and it covers the forearm's front and outer side.
local SHIELD_CF = CFrame.new(-0.3, -0.25, -0.35)

function Gear.shield(kingdomColor: Color3?): Accessory
	local acc =
		accessory(nil, "Shield", "LeftGripAttachment", roundShieldSpecs(SHIELD_CF), kingdomColor or Gear.NEUTRAL_COLOR)
	acc:SetAttribute("KitShield", "shield")
	return acc
end

-- ------------------------------------------------------------------ carried goods

local BASKET = Color3.fromRGB(190, 142, 84)
local BASKET_DARK = Color3.fromRGB(138, 96, 54)
local APPLE = Color3.fromRGB(232, 40, 84) -- the food node marker's red-pink
local LOAF = Color3.fromRGB(238, 190, 86)
local BARK = Color3.fromRGB(122, 78, 44)
local LOG_PALE = Color3.fromRGB(182, 130, 78)
local ROPE = Color3.fromRGB(226, 202, 140)
local STONE_LIGHT = Color3.fromRGB(214, 220, 230) -- ice white, like the stone node marker
local STONE_MID = Color3.fromRGB(150, 156, 168)
local GOLD = Color3.fromRGB(248, 190, 24)
local GOLD_LIGHT = Color3.fromRGB(255, 224, 92)

-- the specs of one load, centred on the origin (the first one is the PrimaryPart)
local function carriedSpecs(resource: string): { Spec }
	local function log(name: string, x: number, y: number, z: number, color: Color3): Spec
		return {
			name = name,
			shape = Enum.PartType.Cylinder,
			size = up(2.4, 0.42), -- a cylinder along X: the log lies across the arms
			cf = CFrame.new(x, y, z),
			color = color,
			material = M.Wood,
		}
	end
	if resource == "wood" then
		return {
			boxSpec("Rope", Vector3.new(0.3, 0.9, 0.94), CFrame.new(0, 0, 0), ROPE, M.Fabric),
			log("LogLeft", 0, -0.2, -0.22, BARK),
			log("LogRight", 0, -0.2, 0.22, BARK),
			log("LogTop", 0, 0.18, 0, LOG_PALE),
		}
	elseif resource == "stone" then
		return {
			boxSpec(
				"StoneBlock",
				Vector3.new(1.5, 0.72, 0.9),
				CFrame.new(0, -0.12, 0) * CFrame.Angles(0, rad(8), 0),
				STONE_LIGHT,
				M.Slate
			),
			boxSpec(
				"StoneTop",
				Vector3.new(0.95, 0.46, 0.7),
				CFrame.new(-0.18, 0.34, -0.02) * CFrame.Angles(0, rad(-14), 0),
				STONE_MID,
				M.Slate
			),
			boxSpec(
				"StoneChip",
				Vector3.new(0.5, 0.34, 0.5),
				CFrame.new(0.62, 0.22, 0.08) * CFrame.Angles(0, rad(30), 0),
				STONE_LIGHT,
				M.Slate
			),
		}
	elseif resource == "gold" then
		return {
			boxSpec("BarLow", Vector3.new(1.9, 0.32, 0.8), CFrame.new(0, -0.24, 0), GOLD, M.SmoothPlastic),
			boxSpec("BarMid", Vector3.new(1.5, 0.32, 0.7), CFrame.new(0, 0.08, 0), GOLD, M.SmoothPlastic),
			boxSpec("BarTop", Vector3.new(1.0, 0.32, 0.6), CFrame.new(0, 0.4, 0), GOLD_LIGHT, M.SmoothPlastic),
		}
	elseif resource == "food" then
		return {
			boxSpec("Basket", Vector3.new(1.8, 0.5, 1.0), CFrame.new(0, -0.3, 0), BASKET, M.Wood),
			boxSpec("BasketRim", Vector3.new(1.95, 0.12, 1.12), CFrame.new(0, -0.02, 0), BASKET_DARK, M.Wood),
			ballSpec("Apple", 0.56, CFrame.new(-0.45, 0.26, 0.02), APPLE, M.SmoothPlastic),
			ballSpec("Loaf", 0.62, CFrame.new(0.4, 0.28, -0.02), LOAF, M.SmoothPlastic),
		}
	end
	error(`Kit.carried: unknown resource {resource} (food | wood | stone | gold)`)
end

-- What a citizen holds in both hands while it carries `resource`: a Model of 3 or 4 welded parts about its own centre (see the header).
function Gear.carried(resource: string): Model
	local specs = carriedSpecs(resource)
	local model = Instance.new("Model")
	model.Name = `Carried_{resource}`
	model:SetAttribute("KitCarried", resource)
	model:SetAttribute("KitPiece", "Carried")
	local primary = build(model, specs[1], Gear.NEUTRAL_COLOR, nil)
	for i = 2, #specs do
		weld(primary, build(model, specs[i], Gear.NEUTRAL_COLOR, nil))
	end
	model.PrimaryPart = primary
	primary.PivotOffset = primary.CFrame:Inverse() -- the pivot is the build origin, not the primary part's own centre
	return model
end

-- ------------------------------------------------------------------ weapons

local function swordSpecs(): ({ Spec }, number)
	return {
		rodSpec("Handle", 1.2, 0.34, CFrame.new(0, 0, 0), LEATHER, M.Fabric),
		ballSpec("Pommel", 0.55, CFrame.new(0, -0.72, 0), IRON, M.Metal),
		boxSpec("Guard", Vector3.new(1.6, 0.28, 0.4), CFrame.new(0, 0.72, 0), STEEL_DARK, M.Metal),
		boxSpec("Blade", Vector3.new(0.62, 3.7, 0.12), CFrame.new(0, 0.84 + 1.85, 0), STEEL_LIGHT, M.Metal),
		boxSpec("Fuller", Vector3.new(0.2, 3.1, 0.2), CFrame.new(0, 0.84 + 1.7, 0), STEEL_DARK, M.Metal),
		boxSpec(
			"Tip",
			Vector3.new(0.44, 0.44, 0.12),
			CFrame.new(0, 0.84 + 3.7 + 0.1, 0) * CFrame.Angles(0, 0, rad(45)),
			STEEL_LIGHT,
			M.Metal
		),
	},
		0.84 + 3.7 + 0.18
end

local function weaponSpecs(weapon: string, withShield: boolean): ({ Spec }, number, number)
	if weapon == "swordShield" then
		local specs, reach = swordSpecs()
		if withShield then
			-- the round shield rides the hand, to its inside and a little behind it: with the arm forward it lies across the chest
			for _, s in roundShieldSpecs(CFrame.new(-1.75, -0.25, 0.8)) do
				table.insert(specs, s)
			end
		end
		return specs, reach, 1
	elseif weapon == "greatsword" then
		return {
			rodSpec("Handle", 2.0, 0.4, CFrame.new(0, 0, 0), LEATHER, M.Fabric),
			ballSpec("Pommel", 0.8, CFrame.new(0, -1.2, 0), STEEL_DARK, M.Metal),
			boxSpec("Guard", Vector3.new(2.8, 0.3, 0.5), CFrame.new(0, 1.15, 0), STEEL_DARK, M.Metal),
			boxSpec("GuardTipLeft", Vector3.new(0.4, 0.5, 0.6), CFrame.new(-1.3, 1.15, 0), C.cloth, M.Fabric, 1),
			boxSpec("GuardTipRight", Vector3.new(0.4, 0.5, 0.6), CFrame.new(1.3, 1.15, 0), C.cloth, M.Fabric, 1),
			boxSpec("Blade", Vector3.new(0.66, 6.2, 0.16), CFrame.new(0, 1.3 + 3.1, 0), STEEL_LIGHT, M.Metal),
			boxSpec("Fuller", Vector3.new(0.16, 5.0, 0.2), CFrame.new(0, 1.3 + 2.8, 0), STEEL, M.Metal),
			boxSpec(
				"Tip",
				Vector3.new(0.47, 0.47, 0.16),
				CFrame.new(0, 1.3 + 6.2 + 0.1, 0) * CFrame.Angles(0, 0, rad(45)),
				STEEL_LIGHT,
				M.Metal
			),
		},
			1.3 + 6.2 + 0.34,
			2
	elseif weapon == "spear" then
		return {
			rodSpec("Handle", 1.3, 0.4, CFrame.new(0, 0, 0), LEATHER, M.Fabric),
			rodSpec("Shaft", 9.0, 0.3, CFrame.new(0, 2.5, 0), ASH, M.Wood),
			rodSpec("Ferrule", 0.9, 0.46, CFrame.new(0, 7.1, 0), IRON, M.Metal),
			wedgeSpec( -- each wedge's tall edge (its local +Z) faces the centre: together a pointed leaf
				"HeadLeft",
				Vector3.new(0.14, 2.0, 0.8),
				CFrame.new(-0.4, 8.5, 0) * CFrame.Angles(0, rad(90), 0),
				STEEL_LIGHT,
				M.Metal
			),
			wedgeSpec(
				"HeadRight",
				Vector3.new(0.14, 2.0, 0.8),
				CFrame.new(0.4, 8.5, 0) * CFrame.Angles(0, rad(-90), 0),
				STEEL_LIGHT,
				M.Metal
			),
			boxSpec("Pennant", Vector3.new(0.1, 0.8, 1.7), CFrame.new(0, 6.3, 0.9), C.cloth, M.Fabric, 1),
			ballSpec("Butt", 0.5, CFrame.new(0, -2.1, 0), IRON, M.Metal),
		},
			9.5,
			2
	elseif weapon == "mace" then
		local specs: { Spec } = {
			rodSpec("Handle", 1.1, 0.4, CFrame.new(0, 0, 0), LEATHER, M.Fabric),
			rodSpec("Haft", 4.4, 0.32, CFrame.new(0, 1.5, 0), LEATHER_DARK, M.Wood),
			ballSpec("Head", 1.4, CFrame.new(0, 4.2, 0), IRON, M.Metal),
			boxSpec(
				"Spike",
				Vector3.new(0.5, 0.5, 0.5),
				CFrame.new(0, 5.05, 0) * CFrame.Angles(0, rad(45), rad(45)),
				STEEL,
				M.Metal
			),
			boxSpec("Ribbon", Vector3.new(0.1, 1.6, 0.34), CFrame.new(0, 2.9, 0.3), C.cloth, M.Fabric, 1),
			ballSpec("Pommel", 0.5, CFrame.new(0, -0.8, 0), IRON, M.Metal),
		}
		-- four studs round the ball's equator (a morning-star mace): square rods turned 45 degrees about their own axis, so each
		-- shows an edge, and they stand clear of the ball on every side
		for i = 0, 3 do
			table.insert(
				specs,
				boxSpec(
					`Stud{i + 1}`,
					Vector3.new(0.5, 0.5, 1.0),
					CFrame.new(0, 4.2, 0)
						* CFrame.Angles(0, rad(90 * i), 0)
						* CFrame.new(0, 0, 0.95)
						* CFrame.Angles(0, 0, rad(45)),
					STEEL,
					M.Metal
				)
			)
		end
		return specs, 5.5, 1
	end
	error(`Kit.weapon: unknown weapon {weapon} (swordShield | greatsword | spear | mace)`)
end

export type WeaponOptions = {
	shield: boolean?, -- swordShield only: false = the sword alone (the shield is Kit.shield on the left hand); default true
}

function Gear.weapon(weapon: string, kingdomColor: Color3?, opts: WeaponOptions?): Tool
	local color = kingdomColor or Gear.NEUTRAL_COLOR
	local specs, reach, hands = weaponSpecs(weapon, not (opts and opts.shield == false))
	local tool = Instance.new("Tool")
	tool.Name = weapon
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("KitWeapon", weapon)
	tool:SetAttribute("KitHands", hands)
	tool:SetAttribute("KitReach", reach)
	if weapon == "swordShield" then
		tool:SetAttribute("KitShield", "shield") -- this weapon goes with a shield: on the Tool by default, Kit.shield(color) when opts.shield == false
	end
	local handle = build(tool, specs[1], color, "Handle")
	for i = 2, #specs do
		weld(handle, build(tool, specs[i], color, nil))
	end
	-- The Handle is a cylinder turned upright, so its own axes are not the grip frame (+Y up, -Z forward): Grip undoes its turn
	-- and the weapon is held exactly as modelled (blade up, front -Z).
	tool.Grip = handle.CFrame:Inverse()
	return tool
end

return Gear
