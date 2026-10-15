--!strict
--[[
	Kit/Character — Kit.character rigs with per-citizen looks (CONTRACTS G4 rendering, G10, G13.2; D-026, D-032),
	the one-part far LOD stand-in, and ruler regalia (crown + cape accessories).

	Rig: at most Character.MAX_PARTS (11 = BASE_PARTS 9 + MAX_DETAIL 2, D-048) BaseParts, no Humanoid/Animator,
	every part CanCollide/CanTouch/CanQuery false and Massless. Motor6Ds are named after the moving part and match Sim/Pose.JOINTS:
		Root   anchored, invisible, centre ROOT_HEIGHT (3.2) above the feet; PivotOffset puts the pivot at the feet
		└ Torso      Motor6D "Torso" at the hips (2.2): walk bob, work lean, the death fall
		  ├ Head     Motor6D at the neck
		  │ └ Hair   welded headwear: a Weld from the Head, never a Motor6D, no pose work. Citizens: hair, beard,
		  │          hood, or (working jobs) the job's hat; bald idle/hauler citizens have none; governors: the gold
		  │          crown; soldiers given a kingdom: the kingdom helmet crest (below). Attribute KitHeadwear.
		  ├ LeftArm / RightArm   Motor6Ds at the shoulders (arms hang splayed 7°)
		  │            RightArm └ Tool   Motor6D inside the right fist (hoe, axe, pick, hammer, spear, staff)
		  ├ LeftLeg / RightLeg   Motor6Ds at the hips
		  └ Tool     the hauler's sack only: Motor6D "Tool" from the Torso at the right shoulder blade
	Every joint frame is axis-aligned with the model (+X right, +Y up, -Z front), as Pose expects: Transform rotates
	about it. Base part counts (D-032): 7 (bald idle citizen) to 9 (headwear + tool); working citizens (farmer,
	woodcutter, miner, builder) always 9 (hat + tool); soldiers 8 (the helm is their Head), 9 with a kingdom crest;
	governors 9. D-048 detail parts come on top: working citizens, the hauler, soldiers and governors carry exactly 2
	(11 parts at most; soldiers without a kingdom 10), idle citizens none. Motor6Ds = base parts − 1 − welded
	headwear/accessory (a detail part never has one). Character.MAX_PARTS is the one cap the specs enforce.

	Detail parts (D-048, FL-0118 phase 2). Rigid parts welded to the Head or the Tool by a Weld "DetailWeld" (never a
	Motor6D, so Sim/Pose.JOINTS and the root height are unchanged), named Detail1, Detail2, with the attribute
	KitDetail = true (Character.DETAIL_ATTRIBUTE; the client may drop them beyond the rig's LOD distance: the base rig
	is complete without them) and KitDetailKind = the part's name. Nothing new on the wire: they derive from the kind
	and the job the client already has. Each hand Tool is now only the HANDLE (a cylinder); its head is a detail:
		farmer      Detail1 strawcrown (kingdom-red crown over the straw brim, Head)   Detail2 hoeblade (steel wedge, Tool)
		woodcutter  Detail1 pompom (kingdom-red, on the beanie, Head)                  Detail2 axehead (bearded steel, Tool)
		miner       Detail1 lamp (bright block on the pot, Head)                       Detail2 pickhead (dark iron bar, Tool)
		builder     Detail1 visor (with the cream drum: a hard hat, Head)              Detail2 mallet (wood head, Tool)
		hauler      Detail1 strap (kingdom-red, across the chest)                      Detail2 tie (the sack's neck); both Tool
		soldier     Detail1 spearhead (pale steel)                                     Detail2 pennant (kingdom-red); both Tool
		governor    Detail1 velvetcap (kingdom-red, over the crown disc, Head)         Detail2 orb (gold, on the staff, Tool)

	Job silhouettes (citizen art pass after the first Studio playtest). Each working job reads without colour:
		farmer      wide straw hat (flat disc 3.1), long hoe with a steel blade, lean body   KitHeadwear "strawhat"
		woodcutter  small charcoal knit beanie (a ball sitting high), axe with a bearded steel head, stocky   "knitcap"
		miner       small dark iron pot (1.9) with a lamp, pick with a double-sided iron bar (T), stocky   "hardhat"
		builder     cream hard hat (a drum with a visor detail, sits on the head), wooden mallet, broad  "buildercap"
		hauler      no job hat (hair shows), big burlap sack low on the back, broad
		idle        hair, nothing carried, lean; the free 9th part is a headband or scarf (Accessory, KitAccessory)
	The job also owns an outfit accent: the trousers (colour, KitAccent = job) and the outfit's fixed neutral
	panel (the torso or the sleeves, whichever the outfit does not tint or leave bare) take the job's colour, so
	look.outfit still moves the kingdom tint, the bare arms and the cut, while the job accent stays. The hat
	takes the Hair slot, so the look's hair style picks a variant of it (roll tilt and shade, KitHeadwear
	unchanged) and the hair colour is hidden under it; idle and hauler citizens keep all hair styles. The hidden hair
	colour dyes the clothes instead (see `individual`): shirt tone, trousers and panel, and whether neutral sleeves
	take the job panel (odd) or the kingdom tint (even).

Soldier kingdom crest (CONTRACTS G13.2, D-033(3)): Kit.character(kind, job, kingdomColor, look?, kingdom?)
	takes an optional KingdomId. A soldier given one wears a crest on the helm in the kingdom's tower style, so
	friend and foe read apart without colour: crimson a tall pointed spire (CornerWedgePart turned 45°, point at
	the front), azure a wide flat square plate overhanging the helm (Block), emerald a plume swept up and back
	(Cylinder), gold a round dome knob (Ball). One primitive each, welded to the Head as `Hair` (D-032, so still
	≤ 9 parts) with KitHeadwear "crest_spire" | "crest_square" | "crest_plume" | "crest_dome" and the kingdom
	colour (KitTint 1). Without a kingdom, or with an unknown one, soldiers keep the plain helm (8 parts);
	citizens and governors ignore it. Character.CRESTS maps KingdomId → crest name.

	Looks (G13.2): CitizenLook = { skin, hair, hairColor, outfit }, 1-based indices into LOOK_RANGES. Any value
	is accepted: non-numbers, NaN and ±inf fall back to the default index; other numbers are floored and
	wrapped into range, so the same look always builds the same model. The default look (nil) has short brown
	hair. Soldiers wear a steel great helm as their Head and ignore the look; governors take only the skin tone
	(crown, ermine and kingdom robe are fixed). The kingdom colour stays visible from above in every outfit: on
	the torso, the sleeves, or the hood.
	Kingdom-coloured parts are exactly shade(kingdomColor, KitTint), so Kit.setKingdomColor recolours a
	pooled rig to the same look as a fresh build. Rigs with different looks differ in part shapes, so pool
	them by Character.lookKey(look) as well (also stored as the model attribute KitLook). A soldier's crest
	shape follows its kingdom, which recolouring cannot change: pool soldiers by kingdom too. Their KitLook is
	Character.lookKey(look, kingdom), which ends in ".<kingdom>" when a crest was built.
]]

local Parts = require("./Parts")
local C = Parts.C
local shade = Parts.shade

local Character = {}

export type CitizenLook = { skin: number, hair: number, hairColor: number, outfit: number }
type Paint = Color3 | number | string -- fixed colour | kingdom shade factor (KitTint) | "skin" | "hair"

-- ------------------------------------------------------------------ proportions (feet at y = 0)

local LEG = Vector3.new(0.95, 2.2, 1.0)
local HIP_Y = LEG.Y -- 2.2: Pose's death fall drops the hips by 1.7 to lay the body on its back
local TORSO_H, TORSO_D = 1.7, 1.15
local NECK_Y = HIP_Y + TORSO_H -- 3.9
local ARM = Vector3.new(0.78, 1.7, 0.82)
local SHOULDER_Y = NECK_Y - 0.4
local ARM_SPLAY = math.rad(7)
local HAND_UP = 0.2 -- the hand joint sits inside the fist, this far above the arm's end
local HEAD_D = 1.6
local HEAD_Y = NECK_Y + HEAD_D / 2 - 0.06 -- head centre (4.64)

Character.ROOT_HEIGHT = 3.2 -- Root centre above the feet (Kit.CHARACTER_ROOT_HEIGHT), rig and LOD alike
Character.LOD_ROOT_HEIGHT = Character.ROOT_HEIGHT
Character.HEIGHT = 5.5 -- the body (head top); a hat, crest or tool may rise above it
Character.BASE_PARTS = 9 -- D-032: Root, Torso, Head, 2 arms, 2 legs, Tool, welded headwear
Character.MAX_DETAIL = 2 -- D-048: at most 2 rigid detail parts (headwear or tool), welded to the Head or the Tool
Character.MAX_PARTS = Character.BASE_PARTS + Character.MAX_DETAIL -- the one cap the specs enforce (11)
Character.DETAIL_ATTRIBUTE = "KitDetail" -- true on every detail part, so the client may drop them beyond the LOD distance

-- ------------------------------------------------------------------ colours

local STEEL = Color3.fromRGB(176, 182, 192)
local STEEL_DARK = Color3.fromRGB(84, 90, 100)
local BLADE = Color3.fromRGB(138, 146, 158)
local BURLAP = Color3.fromRGB(146, 108, 70) -- sack: a darker sackcloth (L .46)
local LINEN = Color3.fromRGB(226, 214, 186)
local LEATHER = Color3.fromRGB(120, 78, 46)
local STRAW = Color3.fromRGB(200, 156, 64) -- farmer's hat: straw (L .62; palette L .58-.67)
local KNIT = Color3.fromRGB(52, 58, 70) -- woodcutter's cap: charcoal wool (neutral, so it never reads as a kingdom)
local HARDHAT = Color3.fromRGB(168, 104, 34) -- miner's iron pot: dark burnt ochre (L .44; palette L .38-.44)
local COIF = Color3.fromRGB(240, 214, 160) -- builder's cloth cap: warm cream (L .85; palette L .83-.87)
local ASH = Color3.fromRGB(214, 190, 146) -- spear shaft: pale ash, visible against grass and soldiers' steel
local WOOD_PALE = Color3.fromRGB(198, 152, 104) -- hammer handle
local ERMINE = Color3.fromRGB(242, 238, 228)
local FACE_TEXTURE = "rbxasset://textures/face.png" -- Roblox's built-in classic face (engine content, no upload)

local SKIN: { Color3 } = { -- light to dark; 1 is the Kit default (the lightest but one)
	C.skin, -- 1 (242, 201, 160)
	Color3.fromRGB(255, 222, 196),
	Color3.fromRGB(210, 156, 112),
	Color3.fromRGB(162, 108, 70),
	Color3.fromRGB(110, 70, 44),
	Color3.fromRGB(78, 50, 34),
}

local HAIR_COLORS: { Color3 } = {
	Color3.fromRGB(92, 58, 32), -- 1 brown (default)
	Color3.fromRGB(36, 28, 24), -- black
	Color3.fromRGB(150, 94, 48), -- chestnut
	Color3.fromRGB(222, 178, 92), -- blond
	Color3.fromRGB(178, 74, 34), -- ginger
	Color3.fromRGB(206, 204, 198), -- grey
	Color3.fromRGB(62, 42, 30), -- dark brown
	Color3.fromRGB(242, 224, 166), -- flaxen
}

type PartSpec = {
	name: string,
	class: string, -- "Part" | "WedgePart" | "CornerWedgePart"
	shape: Enum.PartType?,
	size: Vector3,
	color: Paint,
	material: Enum.Material,
	offset: CFrame, -- relative to the joint frame (head centre for headwear, hand for tools)
	onBack: boolean?, -- tool jointed to the Root (sack) instead of the right hand
	details: { PartSpec }?, -- tools: rigid parts welded to the Tool, offsets in the joint frame like `offset`
	palette: { Color3 }?, -- job hats: three colour variants of one value band (look.hair picks one; `color` is the first)
}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis (X) → +Y

-- Headwear slot (welded to the Head). Sizes keep the face (front of the head below y ≈ +0.33) clear and the
-- top ≤ 5.65 studs. Bald has no part.
type HairStyle = { name: string, spec: PartSpec? }
local HAIR_STYLES: { HairStyle } = {
	{ -- 1 short bowl cut (default)
		name = "short",
		spec = {
			name = "short",
			class = "Part",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.66, 1.66, 1.66),
			color = "hair",
			material = Enum.Material.SmoothPlastic,
			offset = CFrame.new(0, 0.13, 0.13),
		},
	},
	{ name = "bald" }, -- 2 the classic bare head; the skin tone shows from above
	{ -- 3 long hair: a bigger mass set low and back, over the ears and down to the shoulders
		name = "long",
		spec = {
			name = "long",
			class = "Part",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.87, 1.87, 1.87),
			color = "hair",
			material = Enum.Material.SmoothPlastic,
			offset = CFrame.new(0, -0.05, 0.29),
		},
	},
	{ -- 4 bald with a full beard
		name = "beard",
		spec = {
			name = "beard",
			class = "WedgePart",
			size = Vector3.new(1.14, 0.76, 0.52),
			color = "hair",
			material = Enum.Material.SmoothPlastic,
			offset = CFrame.new(0, -0.48, -0.5) * CFrame.Angles(0, math.pi, 0),
		},
	},
	{ -- 5 hood in the kingdom colour
		name = "hood",
		spec = {
			name = "hood",
			class = "Part",
			shape = Enum.PartType.Ball,
			size = Vector3.new(1.83, 1.83, 1.83),
			color = 0.72,
			material = Enum.Material.Fabric,
			offset = CFrame.new(0, 0.08, 0.3),
		},
	},
	{ -- 6 curls: a big round mass set high (the straw hat is the farmer's job headwear now, not a hair style)
		name = "curls",
		spec = {
			name = "curls",
			class = "Part",
			shape = Enum.PartType.Ball,
			size = Vector3.new(2.05, 2.05, 2.05),
			color = "hair",
			material = Enum.Material.SmoothPlastic,
			offset = CFrame.new(0, 0.22, 0.1),
		},
	},
}

-- Job headwear (Hair slot, welded to the Head): one bold silhouette per working job, none in a hair colour (the
-- woodcutter's beanie is the only ball, in charcoal; hair balls are brown, black, blond, ginger, grey or flaxen). Heads: top 5.44, face clear below y = +0.33 (head-centre frame). A hat sits ON
-- the head (clearance rules in the Kit spec): the head enters it by at most 0.4 above its lower face, and no
-- skin shows through its top or sides (every head point above the hat's lower face is inside the hat).
local JOB_HATS: { [string]: PartSpec } = {
	farmer = { -- wide flat straw disc: the widest thing on any citizen, a big pale circle from above
		name = "strawhat",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.42, 3.1, 3.1),
		color = STRAW,
		palette = { STRAW, Color3.fromRGB(214, 170, 60), Color3.fromRGB(178, 146, 92) },
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 0.62, 0) * UPRIGHT,
	},
	woodcutter = { -- knit beanie: a small dark ball sitting high on the head (the old wedge slab was oversized and read
		-- as a chimney). Its rim runs above the eyes (the covered cap starts 0.4 above the head centre) and meets the
		-- head at a clean angle (53°, spec); it is charcoal against hair's browns and blacks
		name = "knitcap",
		class = "Part",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.5, 1.5, 1.5),
		color = KNIT,
		palette = { KNIT, Color3.fromRGB(40, 52, 84), Color3.fromRGB(44, 64, 50) },
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 0.7, 0.05),
	},
	miner = { -- squat iron hat with a rim wider than the head, ochre and glossy: a pot on the head
		name = "hardhat",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.7, 1.9, 1.9),
		color = HARDHAT,
		palette = { HARDHAT, Color3.fromRGB(160, 84, 40), Color3.fromRGB(140, 106, 40) },
		material = Enum.Material.Metal,
		offset = CFrame.new(0, 0.79, 0) * UPRIGHT, -- base 0.44; 1.9 across against the farmer's 3.1
	},
	builder = { -- cream hard hat crown: a squat drum sitting ON the head (base 0.44 above the head centre); its visor
		-- is a head detail part (HEAD_DETAILS.builder), so with it the hat reads as a hard hat, not a paper cap
		name = "buildercap",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.75, 1.8, 1.8),
		color = COIF,
		palette = { COIF, Color3.fromRGB(246, 224, 140), Color3.fromRGB(244, 208, 170) },
		material = Enum.Material.SmoothPlastic,
		offset = CFrame.new(0, 0.815, 0) * UPRIGHT,
	},
}
-- look.hair (1..6) -> a colour of the job's palette (3) and a roll tilt about the head (3): six distinct hats, each
-- colour and each tilt used twice. The palettes stay inside one value band per job, so jobs still separate in grayscale.
local HAT_VARIANTS = {
	{ colour = 1, roll = 0 },
	{ colour = 2, roll = math.rad(9) },
	{ colour = 3, roll = math.rad(-9) },
	{ colour = 1, roll = math.rad(9) },
	{ colour = 2, roll = math.rad(-9) },
	{ colour = 3, roll = 0 },
}

-- Head detail parts (D-048): one rigid part welded to the Head per working job, named Detail<n>, KitDetail = true.
-- Offsets are from the head centre and follow the hat's roll. They carry the readable extras of each hat: the
-- farmer's kingdom-coloured crown over the straw brim, the woodcutter's kingdom pompom, the miner's lamp, the
-- builder's visor. Kingdom colour on top of the head also keeps it visible from the air under a wide hat.
local LAMP = Color3.fromRGB(255, 226, 140)
local HEAD_DETAILS: { [string]: PartSpec } = {
	farmer = {
		name = "strawcrown",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.55, 1.5, 1.5),
		color = 0.8,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 1.1, 0) * UPRIGHT,
	},
	woodcutter = {
		name = "pompom",
		class = "Part",
		shape = Enum.PartType.Ball,
		size = Vector3.new(0.75, 0.75, 0.75),
		color = 0.85,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 1.5, 0.05),
	},
	miner = {
		name = "lamp",
		class = "Part",
		shape = Enum.PartType.Block,
		size = Vector3.new(0.5, 0.4, 0.35),
		color = LAMP,
		material = Enum.Material.SmoothPlastic,
		offset = CFrame.new(0, 0.8, -1.05),
	},
	builder = {
		name = "visor",
		class = "WedgePart",
		size = Vector3.new(1.3, 0.16, 0.9),
		color = COIF,
		material = Enum.Material.SmoothPlastic,
		offset = CFrame.new(0, 0.56, -1.2) * CFrame.Angles(math.rad(-8), 0, 0),
	},
}

local GOVERNOR_CROWN: PartSpec = { -- gold circlet on the head, a gold disc from above; it covers the head's top
	-- (the head used to poke through its top face): 1.9 across (a wide gold disc from the air), bottom 0.42 above the
	-- head centre, top 1.02
	name = "crown",
	class = "Part",
	shape = Enum.PartType.Cylinder,
	size = Vector3.new(0.6, 1.9, 1.9),
	color = C.gold,
	material = Enum.Material.Metal,
	offset = CFrame.new(0, 0.72, 0) * UPRIGHT,
}
local GOVERNOR_CAP: PartSpec =
	{ -- velvet cap in the kingdom colour over the crown disc (the regalia's cap): red from above
		name = "velvetcap",
		class = "Part",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.4, 1.4, 1.4),
		color = 0.9,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 1.1, 0),
	}

local GREAT_HELM: PartSpec = { -- soldier's Head: a steel great helm (a steel square from above)
	name = "greathelm",
	class = "Part",
	shape = Enum.PartType.Block,
	size = Vector3.new(1.45, 1.6, 1.45),
	color = STEEL,
	material = Enum.Material.Metal,
	offset = CFrame.new(0, 0.8, 0), -- from the neck
}

-- Soldier kingdom crests (G13.2, D-033(3)): one primitive welded on top of the helm, offsets from the helm
-- centre (its top is at +0.8). They differ in outline, not only colour (Blender grayscale review, art/reviews/
-- kit-characters.md): the spire is tallest and pointed, the square low and wider than the helm, the plume a
-- narrow tail swept back past the helm, the dome a round knob wider than its seat.
local HELM_TOP = GREAT_HELM.size.Y / 2
local SPIRE = Vector3.new(1.0, 1.6, 1.0) -- base 1.41 across the diagonal, 1.55 above the helm: a low crest, not a gnome's hat
local PLUME_LEN, PLUME_D, PLUME_TILT = 2.5, 0.7, math.rad(70) -- a near-horizontal tail
local CRESTS: { [string]: PartSpec } = {
	crimson = { -- tall spire (2.05 above the helm): a CornerWedge turned 45°, its point over the front corner;
		-- the base overhangs the helm a little at the corners, like the crimson towers' spires
		name = "crest_spire",
		class = "CornerWedgePart",
		size = SPIRE,
		color = 1,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, HELM_TOP + SPIRE.Y / 2 - 0.05, 0) * CFrame.Angles(0, math.rad(45), 0),
	},
	azure = { -- square: a flat plate overhanging the helm by 0.25 on every side (the azure tower's square eave)
		name = "crest_square",
		class = "Part",
		shape = Enum.PartType.Block,
		size = Vector3.new(1.95, 0.48, 1.95),
		color = 1,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, HELM_TOP + 0.24 - 0.02, 0),
	},
	emerald = { -- plume: a horsehair tail from the front of the helm top, swept back 70° and 1.4 past its back
		name = "crest_plume",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(PLUME_LEN, PLUME_D, PLUME_D),
		color = 1,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, HELM_TOP - 0.1, -0.3)
			* CFrame.Angles(PLUME_TILT, 0, 0)
			* CFrame.new(0, PLUME_LEN / 2, 0)
			* UPRIGHT,
	},
	gold = { -- dome: a 1.3 ball set 0.4 above the helm top, so it bulges over a narrower seat (an onion dome)
		name = "crest_dome",
		class = "Part",
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.3, 1.3, 1.3),
		color = 1,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, HELM_TOP + 0.4, 0),
	},
}
Character.CRESTS = table.freeze({
	crimson = CRESTS.crimson.name,
	azure = CRESTS.azure.name,
	emerald = CRESTS.emerald.name,
	gold = CRESTS.gold.name,
})

type Outfit = { name: string, torso: Paint, sleeves: Paint, legs: Paint, legMaterial: Enum.Material? }

-- The kingdom colour (a number = KitTint) is on the torso, the sleeves or both, so it reads from above.
local OUTFITS: { Outfit } = {
	{ name = "tunic", torso = 0.8, sleeves = LINEN, legs = Color3.fromRGB(110, 86, 60) }, -- 1 default
	{ name = "sleeveless", torso = 0.85, sleeves = "skin", legs = Color3.fromRGB(78, 58, 40) },
	{ name = "vest", torso = LEATHER, sleeves = 0.8, legs = Color3.fromRGB(88, 90, 98) },
	{ name = "apron", torso = C.canvas, sleeves = 0.72, legs = Color3.fromRGB(104, 70, 44) },
	{ name = "robe", torso = 0.66, sleeves = 0.66, legs = 0.5 },
	{ name = "jerkin", torso = 1, sleeves = Color3.fromRGB(72, 62, 54), legs = Color3.fromRGB(150, 128, 96) },
}

local SOLDIER_OUTFIT: Outfit =
	{ name = "tabard", torso = 1, sleeves = 0.85, legs = STEEL_DARK, legMaterial = Enum.Material.Metal }
local GOVERNOR_OUTFIT: Outfit = { name = "regal", torso = 1, sleeves = ERMINE, legs = 0.55 }

Character.LOOK_RANGES = table.freeze({
	skin = #SKIN,
	hair = #HAIR_STYLES,
	hairColor = #HAIR_COLORS,
	outfit = #OUTFITS,
})
Character.LOOK_PALETTES = table.freeze({
	skin = table.freeze(table.clone(SKIN)),
	hairColor = table.freeze(table.clone(HAIR_COLORS)),
	hair = table.freeze((function()
		local names = {}
		for i, h in HAIR_STYLES do
			names[i] = h.name
		end
		return names
	end)()),
	outfit = table.freeze((function()
		local names = {}
		for i, o in OUTFITS do
			names[i] = o.name
		end
		return names
	end)()),
})
Character.DEFAULT_LOOK = table.freeze({ skin = 1, hair = 1, hairColor = 1, outfit = 1 })

-- ------------------------------------------------------------------ jobs and tools

-- Per job: body width (stocky jobs read heavier, lean ones lighter), tool, hat, and the outfit accent (see the
-- header): `panel` replaces the outfit's fixed neutral torso/sleeve colour, `legs` its trousers.
type JobStyle = {
	width: number,
	tool: string?,
	hat: PartSpec?,
	panel: Color3?,
	legs: Color3?,
	panels: { Color3 }?, -- three panel colours of one value band (hair colour picks one; `panel` is the first)
	legsSet: { Color3 }?, -- likewise for the trousers
}
local JOBS: { [string]: JobStyle } = {
	idle = { width = 1.9 },
	farmer = { -- light: cream shirt or apron, olive trousers, straw hat
		width = 1.95,
		tool = "hoe",
		hat = JOB_HATS.farmer,
		panel = Color3.fromRGB(232, 222, 190),
		legs = Color3.fromRGB(98, 104, 58),
		panels = { Color3.fromRGB(232, 222, 190), Color3.fromRGB(214, 224, 196), Color3.fromRGB(236, 214, 176) },
		legsSet = { Color3.fromRGB(98, 104, 58), Color3.fromRGB(86, 108, 66), Color3.fromRGB(84, 100, 84) },
	},
	woodcutter = { -- dark: umber leather, black-brown trousers, charcoal beanie, bright steel axe
		width = 2.3,
		tool = "axe",
		hat = JOB_HATS.woodcutter,
		panel = Color3.fromRGB(96, 66, 46),
		legs = Color3.fromRGB(58, 42, 32),
		panels = { Color3.fromRGB(96, 66, 46), Color3.fromRGB(84, 70, 66), Color3.fromRGB(110, 66, 44) },
		legsSet = { Color3.fromRGB(58, 42, 32), Color3.fromRGB(50, 46, 48), Color3.fromRGB(70, 40, 36) },
	},
	miner = { -- cool grey: soot panel, coal trousers, dark ochre pot
		width = 2.2,
		tool = "pick",
		hat = JOB_HATS.miner,
		panel = Color3.fromRGB(122, 126, 136),
		legs = Color3.fromRGB(70, 68, 72),
		panels = { Color3.fromRGB(122, 126, 136), Color3.fromRGB(132, 124, 116), Color3.fromRGB(110, 122, 140) },
		legsSet = { Color3.fromRGB(70, 68, 72), Color3.fromRGB(62, 70, 84), Color3.fromRGB(74, 76, 64) },
	},
	builder = { -- tan canvas, dusty navy trousers, cream cap
		width = 2.3,
		tool = "hammer",
		hat = JOB_HATS.builder,
		panel = Color3.fromRGB(196, 158, 104),
		legs = Color3.fromRGB(52, 62, 94),
		panels = { Color3.fromRGB(196, 158, 104), Color3.fromRGB(186, 170, 120), Color3.fromRGB(206, 160, 90) },
		legsSet = { Color3.fromRGB(52, 62, 94), Color3.fromRGB(60, 58, 100), Color3.fromRGB(84, 84, 100) },
	},
	hauler = { -- sackcloth panel and russet trousers; keeps the look's hair (the sack is the signature)
		width = 2.3,
		tool = "sack",
		panel = Color3.fromRGB(156, 118, 80),
		legs = Color3.fromRGB(112, 68, 42),
		panels = { Color3.fromRGB(156, 118, 80), Color3.fromRGB(146, 122, 92), Color3.fromRGB(164, 112, 76) },
		legsSet = { Color3.fromRGB(112, 68, 42), Color3.fromRGB(96, 72, 52), Color3.fromRGB(122, 76, 50) },
	},
}
Character.JOB_HEADWEAR = table.freeze((function()
	local out: { [string]: string } = {}
	for job, hat in JOB_HATS do
		out[job] = hat.name
	end
	return out
end)())
Character.JOB_TOOLS = table.freeze((function()
	local out: { [string]: string } = {}
	for job, style in JOBS do
		if style.tool then
			out[job] = style.tool
		end
	end
	return out
end)())

local GRIP = CFrame.new(0, 0, -0.55) -- in front of the fist, so a held shaft clears the arm

-- Hand tools (D-048): the Tool part is the HANDLE (a cylinder held in front of the fist, leaning out a few degrees);
-- its head is a detail part welded to it (`details`, offsets in the joint frame, KitDetail = true). The heads sit at
-- head height beside the body, so a tool reads as a tool from the air. Handle colours and head shapes differ per job.
local LEAN = CFrame.Angles(0, 0, math.rad(-6)) -- the top leans outwards (+X), away from the body
-- the hoe leans out 14 degrees: its handle clears the straw brim of every hat roll in every pose (0.04 or more with the
-- brim's bounding box, 0.15 or more with the exact disc)
local HOE_LEAN = CFrame.Angles(0, 0, math.rad(-14))
local LEAN_HAMMER = CFrame.Angles(0, 0, math.rad(-15)) -- the mallet leans further: its head swings past the face at work (cheek clearance 0.15)
local TOOLS: { [string]: PartSpec } = {
	hoe = { -- 5.2 long pale-wood handle, a steel blade angled down at its top
		name = "hoe",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(5.2, 0.38, 0.38),
		color = C.woodLight,
		material = Enum.Material.Wood,
		offset = GRIP * HOE_LEAN * CFrame.new(0, 0.8, 0) * UPRIGHT,
		details = {
			{
				name = "hoeblade",
				class = "WedgePart",
				size = Vector3.new(1.1, 0.34, 1.3),
				color = BLADE,
				material = Enum.Material.Metal,
				offset = GRIP * HOE_LEAN * CFrame.new(0, 3.35, -0.6) * CFrame.Angles(math.rad(-22), 0, 0),
			},
		},
	},
	axe = { -- 3.9 long wooden haft, a big bearded steel head (flat top level with the haft's end, cutting edge in front)
		name = "axe",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(3.9, 0.42, 0.42),
		color = C.wood,
		material = Enum.Material.Wood,
		offset = GRIP * LEAN * CFrame.new(0, 0.9, 0) * UPRIGHT,
		details = {
			{
				name = "axehead",
				class = "WedgePart",
				size = Vector3.new(0.5, 1.7, 1.9),
				color = BLADE,
				material = Enum.Material.Metal,
				offset = GRIP * LEAN * CFrame.new(0, 2.0, -0.8) * CFrame.Angles(math.pi, 0, 0),
			},
		},
	},
	pick = { -- 4.55 long dark handle, a double-sided iron bar across its top (a T), turned 40° so it shows from front and side;
		-- the bar sits high (its centre 3.4 above the grip) so it swings over the pot, never through it (0.28 clear)
		name = "pick",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(4.55, 0.4, 0.4),
		color = C.woodDark,
		material = Enum.Material.Wood,
		offset = GRIP * LEAN * CFrame.new(0, 1.225, 0) * UPRIGHT,
		details = {
			{
				name = "pickhead",
				class = "Part",
				shape = Enum.PartType.Block,
				size = Vector3.new(0.45, 0.5, 3.6),
				color = STEEL_DARK,
				material = Enum.Material.Metal,
				offset = GRIP * LEAN * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, math.rad(40), 0),
			},
		},
	},
	hammer = { -- 3.0 long pale handle, a fat wooden mallet head across its top
		name = "hammer",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(3.0, 0.42, 0.42),
		color = WOOD_PALE,
		material = Enum.Material.Wood,
		offset = GRIP * LEAN_HAMMER * CFrame.new(0, 0.5, 0) * UPRIGHT,
		details = {
			{
				name = "mallet",
				class = "Part",
				shape = Enum.PartType.Block,
				size = Vector3.new(1.2, 1.15, 2.0),
				color = C.wood,
				material = Enum.Material.Wood,
				offset = GRIP * LEAN_HAMMER * CFrame.new(0, 2.0, 0) * CFrame.Angles(0, math.rad(40), 0),
			},
		},
	},
	sack = { -- big burlap sack on the back, seated against the shoulder blades and clear of the head and both arms
		-- (centre 0.1 right of the spine, 2.8 up, 2.1 behind it; joint at 0.96, 3.8, 0.575). Its details: a
		-- kingdom-coloured strap across the chest (so it reads from the front) and the tied neck of the sack
		name = "sack",
		class = "Part",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.7, 2.7, 2.7),
		color = BURLAP,
		material = Enum.Material.Fabric,
		offset = CFrame.new(-0.86, -1.0, 1.525),
		onBack = true,
		details = {
			{
				name = "strap",
				class = "Part",
				shape = Enum.PartType.Block,
				size = Vector3.new(0.34, 2.7, 0.26),
				color = 0.85,
				material = Enum.Material.Fabric,
				offset = CFrame.new(-0.96, -0.72, -1.3) * CFrame.Angles(0, 0, math.rad(-38)),
			},
			{
				name = "tie",
				class = "Part",
				shape = Enum.PartType.Ball,
				size = Vector3.new(0.85, 0.85, 0.85),
				color = Color3.fromRGB(112, 80, 52),
				material = Enum.Material.Fabric,
				offset = CFrame.new(-0.86, 0.4, 1.525),
			},
		},
	},
	spear = { -- 9 long pale ash shaft, a steel spearhead and a kingdom pennant streaming from it
		name = "spear",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(9.0, 0.4, 0.4),
		color = ASH,
		material = Enum.Material.Wood,
		offset = GRIP * CFrame.new(0, 2.2, 0) * UPRIGHT,
		details = {
			{
				name = "spearhead",
				class = "CornerWedgePart",
				size = Vector3.new(0.75, 1.9, 0.75),
				color = STEEL,
				material = Enum.Material.Metal,
				offset = GRIP * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, math.rad(45), 0),
			},
			{
				name = "pennant",
				class = "Part",
				shape = Enum.PartType.Block,
				size = Vector3.new(1.2, 0.1, 0.8),
				color = 0.9,
				material = Enum.Material.Fabric,
				offset = GRIP * CFrame.new(0.7, 5.5, 0) * CFrame.Angles(0, 0, math.rad(-12)),
			},
		},
	},
	staff = { -- thick gold staff with a gold orb on top
		name = "staff",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(6.4, 0.5, 0.5), -- thicker and longer: the key character's tool still shows from the air
		color = C.gold,
		material = Enum.Material.Metal,
		offset = GRIP * CFrame.new(0, 1.1, 0) * UPRIGHT,
		details = {
			{
				name = "orb",
				class = "Part",
				shape = Enum.PartType.Ball,
				size = Vector3.new(0.9, 0.9, 0.9),
				color = C.gold,
				material = Enum.Material.Metal,
				offset = GRIP * CFrame.new(0, 4.55, 0),
			},
		},
	},
}

-- ------------------------------------------------------------------ looks

local function index(v: any, n: number, default: number): number
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return (math.floor(v) - 1) % n + 1
end

-- Any input → a valid CitizenLook (never errors; deterministic).
function Character.normalizeLook(look: any): CitizenLook
	local d = Character.DEFAULT_LOOK
	if type(look) ~= "table" then
		return { skin = d.skin, hair = d.hair, hairColor = d.hairColor, outfit = d.outfit }
	end
	local r = Character.LOOK_RANGES
	return {
		skin = index(look.skin, r.skin, d.skin),
		hair = index(look.hair, r.hair, d.hair),
		hairColor = index(look.hairColor, r.hairColor, d.hairColor),
		outfit = index(look.outfit, r.outfit, d.outfit),
	}
end

local function crestOf(kingdom: any): PartSpec?
	return if type(kingdom) == "string" then CRESTS[kingdom] else nil
end

-- Pool key: equal keys build identical rigs (for a given kind, job and kingdom colour). A soldier's crest
-- follows its kingdom (G13.2), so pass the kingdom for soldiers: a known KingdomId appends ".<kingdom>"
-- ("1.1.1.1.crimson"). Without one (or an unknown one) the key is the plain look key.
function Character.lookKey(look: any, kingdom: string?): string
	local l = Character.normalizeLook(look)
	local key = `{l.skin}.{l.hair}.{l.hairColor}.{l.outfit}`
	return if crestOf(kingdom) then `{key}.{kingdom}` else key
end

-- ------------------------------------------------------------------ builders

local function rigPart(
	model: Model,
	name: string,
	class: string,
	shape: Enum.PartType?,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?
): BasePart
	local p: BasePart
	if class == "Part" then
		local part = Instance.new("Part")
		part.Shape = shape or Enum.PartType.Block
		p = part
	elseif class == "WedgePart" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("CornerWedgePart")
	end
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = true
	if tint then
		p:SetAttribute("KitTint", tint)
	end
	p.Parent = model
	return p
end

local function motor(part0: BasePart, part1: BasePart, jointWorld: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = part1.Name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = part0.CFrame:Inverse() * jointWorld
	m.C1 = part1.CFrame:Inverse() * jointWorld
	m.Parent = part0
	return m
end

local function paint(p: Paint, kingdomColor: Color3, skin: Color3, hair: Color3): (Color3, number?)
	if type(p) == "number" then
		return shade(kingdomColor, p), p
	elseif p == "skin" then
		return skin, nil
	elseif p == "hair" then
		return hair, nil
	end
	return p :: Color3, nil
end

local function specPart(
	model: Model,
	name: string,
	spec: PartSpec,
	cf: CFrame,
	kingdomColor: Color3,
	skin: Color3,
	hair: Color3
): BasePart
	local color, tint = paint(spec.color, kingdomColor, skin, hair)
	return rigPart(model, name, spec.class, spec.shape, spec.size, cf, color, spec.material, tint)
end

-- look.hair (1..6) picks one of 6 variants of a job hat: a colour of its palette and a roll tilt (HAT_VARIANTS).
-- The shape, size and KitHeadwear name never change.
local function hatVariant(spec: PartSpec, hairIndex: number): PartSpec
	local v = HAT_VARIANTS[(hairIndex - 1) % #HAT_VARIANTS + 1]
	local palette = spec.palette :: { Color3 }
	return {
		name = spec.name,
		class = spec.class,
		shape = spec.shape,
		size = spec.size,
		color = palette[v.colour],
		material = spec.material,
		offset = CFrame.Angles(0, 0, v.roll) * spec.offset, -- a jaunty tilt about the head, not about the hat's own centre
	}
end

-- Per-individual variation, from the look alone (nothing new on the wire, G13.2): the hair colour is hidden under a
-- working citizen's hat, so it is free to dye the clothes.
--  * shirt tone: the kingdom tint factor moves a little (KitTint stays exact, so recolouring still matches);
--  * working jobs: the job's trousers and neutral panel are dyed lighter or darker;
--  * working jobs: an odd hair colour keeps the job panel on neutral sleeves, an even one tints those sleeves with
--    the kingdom colour (red shoulders from above; the hat covers the head and much of the chest).
-- The default look (hair colour 1, skin 1) changes nothing.
local TINT_SHIFT = { 0, -0.1, 0.08, -0.16, 0.12, -0.05, 0.05, -0.12 }
local DYE = { 1, 0.94, 1.06, 0.9, 1.1, 0.97, 1.03, 0.92 }
local SLEEVE_TINT = 0.78

local function shiftTint(p: Paint, shift: number): Paint
	return if type(p) == "number" then math.clamp(p + shift, 0.5, 1) else p
end

local function dyed(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

local function individual(outfit: Outfit, l: CitizenLook): Outfit
	local shift = TINT_SHIFT[(l.hairColor + l.skin - 2) % #TINT_SHIFT + 1]
	return {
		name = outfit.name,
		torso = shiftTint(outfit.torso, shift),
		sleeves = shiftTint(outfit.sleeves, shift),
		legs = shiftTint(outfit.legs, shift),
		legMaterial = outfit.legMaterial,
	}
end

-- The job's accent on an outfit (see the header): the fixed neutral torso/sleeve colour (not a kingdom tint, not
-- bare skin) becomes the dyed panel colour and the trousers the dyed legs colour. `sleevesTinted`: neutral sleeves
-- take the kingdom tint instead of the panel.
local function jobOutfit(outfit: Outfit, job: JobStyle, l: CitizenLook, sleevesTinted: boolean): Outfit
	local panels, legsSet = job.panels :: { Color3 }, job.legsSet :: { Color3 }
	local dye = DYE[l.hairColor]
	local panel = dyed(panels[(l.hairColor - 1) % #panels + 1], dye)
	return {
		name = outfit.name,
		torso = if typeof(outfit.torso) == "Color3" then panel else outfit.torso,
		sleeves = if typeof(outfit.sleeves) ~= "Color3"
			then outfit.sleeves
			elseif sleevesTinted then SLEEVE_TINT
			else panel,
		legs = dyed(legsSet[(l.hairColor - 1) % #legsSet + 1], dye),
		legMaterial = outfit.legMaterial,
	}
end

-- Idle citizens carry nothing, so the 9th part is free for one accessory welded to the Head (a headband or a
-- scarf in one of a few colours; about two looks in three wear one). Part "Accessory", attribute KitAccessory.
type Accessory = { kind: string, size: Vector3, offset: CFrame, color: Paint }
local HEADBAND_SIZE, HEADBAND_AT = Vector3.new(0.22, 1.6, 1.6), CFrame.new(0, 0.4, 0) * UPRIGHT
local SCARF_SIZE, SCARF_AT = Vector3.new(0.35, 1.5, 1.5), CFrame.new(0, -0.64, 0) * UPRIGHT
local INDIGO = Color3.fromRGB(60, 72, 120)
local RUST = Color3.fromRGB(170, 84, 52)
local ACCESSORIES: { Accessory | boolean } = {
	false, -- 1 none (the default look)
	{ kind = "headband", size = HEADBAND_SIZE, offset = HEADBAND_AT, color = 0.72 }, -- 2 kingdom headband
	{ kind = "scarf", size = SCARF_SIZE, offset = SCARF_AT, color = LINEN }, -- 3 cream scarf
	false, -- 4 none
	{ kind = "headband", size = HEADBAND_SIZE, offset = HEADBAND_AT, color = INDIGO }, -- 5 indigo headband
	{ kind = "scarf", size = SCARF_SIZE, offset = SCARF_AT, color = RUST }, -- 6 rust scarf
}
local function accessoryOf(l: CitizenLook): Accessory?
	local a = ACCESSORIES[(l.outfit + 2 * l.hair + 3 * l.skin) % #ACCESSORIES + 1]
	return if type(a) == "table" then a else nil
end

-- ------------------------------------------------------------------ characters (≤ 9 parts)

-- kingdom (G13.2): a KingdomId; only soldiers use it (their helmet crest). nil/unknown = the plain helm.
function Character.character(
	kind: string,
	job: string,
	kingdomColor: Color3,
	look: CitizenLook?,
	kingdom: string?
): Model
	local l = Character.normalizeLook(look)
	local style = if kind == "governor"
		then "governor"
		elseif kind == "soldier" or job == "soldier" then "soldier"
		else "citizen"
	local skin, hairColor = SKIN[l.skin], HAIR_COLORS[l.hairColor]
	local jobSpec = JOBS[job] or JOBS.idle
	local crest = if style == "soldier" then crestOf(kingdom) else nil
	local outfit: Outfit, headwear: PartSpec?, width: number, tool: string?
	local hatRoll = 0 -- the working hat's tilt about the head: its head details follow it
	local accentJob: string? = nil -- the job whose accent colours the outfit (working citizens only)
	local panelTorso, panelSleeves = false, false -- where the job's panel colour landed
	if style == "soldier" then
		outfit, headwear, width, tool = SOLDIER_OUTFIT, crest, 2.15, "spear"
	elseif style == "governor" then
		outfit, headwear, width, tool = GOVERNOR_OUTFIT, GOVERNOR_CROWN, 2.4, "staff"
	else
		outfit, headwear, width, tool =
			individual(OUTFITS[l.outfit], l), HAIR_STYLES[l.hair].spec, jobSpec.width, jobSpec.tool
		if jobSpec.legs then
			local sleevesTinted = l.hairColor % 2 == 0
			panelTorso = typeof(outfit.torso) == "Color3"
			panelSleeves = typeof(outfit.sleeves) == "Color3" and not sleevesTinted
			outfit, accentJob = jobOutfit(outfit, jobSpec, l, sleevesTinted), job
		end
		if jobSpec.hat then -- the job hat takes the Hair slot; look.hair picks its variant
			headwear = hatVariant(jobSpec.hat, l.hair)
			hatRoll = HAT_VARIANTS[(l.hair - 1) % #HAT_VARIANTS + 1].roll
		end
	end

	local model = Instance.new("Model")
	model.Name = `{kind}_{job}`
	model:SetAttribute("KitKind", kind)
	model:SetAttribute("KitJob", job)
	model:SetAttribute("KitLook", Character.lookKey(l, if crest then kingdom else nil))
	model:SetAttribute("KitRootHeight", Character.ROOT_HEIGHT)

	-- Root: anchored, invisible; BulkMoveTo moves it, everything else hangs off the Torso motor
	local root = rigPart(
		model,
		"Root",
		"Part",
		Enum.PartType.Block,
		Vector3.new(2, 2, 1),
		CFrame.new(0, Character.ROOT_HEIGHT, 0),
		C.cloth,
		Enum.Material.SmoothPlastic
	)
	root.Anchored = true
	root.Transparency = 1
	root.CastShadow = false
	root.PivotOffset = CFrame.new(0, -Character.ROOT_HEIGHT, 0)
	model.PrimaryPart = root

	local torsoColor, torsoTint = paint(outfit.torso, kingdomColor, skin, hairColor)
	local torso = rigPart(
		model,
		"Torso",
		"Part",
		Enum.PartType.Block,
		Vector3.new(width, TORSO_H, if style == "citizen" then TORSO_D else TORSO_D + 0.05),
		CFrame.new(0, HIP_Y + TORSO_H / 2, 0),
		torsoColor,
		Enum.Material.Fabric,
		torsoTint
	)
	motor(root, torso, CFrame.new(0, HIP_Y, 0))

	local headCF = CFrame.new(0, HEAD_Y, 0)
	local neck = CFrame.new(0, NECK_Y, 0)
	local head
	if style == "soldier" then
		head = specPart(model, "Head", GREAT_HELM, neck * GREAT_HELM.offset, kingdomColor, skin, hairColor)
	else
		head = rigPart(
			model,
			"Head",
			"Part",
			Enum.PartType.Ball,
			Vector3.new(HEAD_D, HEAD_D, HEAD_D),
			headCF,
			skin,
			Enum.Material.SmoothPlastic
		)
		local face = Instance.new("Decal")
		face.Name = "Face"
		face.Face = Enum.NormalId.Front
		face.Texture = FACE_TEXTURE
		face.Parent = head
	end
	motor(torso, head, neck)

	if headwear then
		-- offsets are from the head centre (citizens, governors) or the helm centre (soldiers' crests)
		local headFrame = head.CFrame
		local hair = specPart(model, "Hair", headwear, headFrame * headwear.offset, kingdomColor, skin, hairColor)
		hair:SetAttribute("KitHeadwear", headwear.name)
		local weld = Instance.new("Weld")
		weld.Name = "HairWeld"
		weld.Part0 = head
		weld.Part1 = hair
		weld.C0 = headFrame:Inverse() * hair.CFrame
		weld.C1 = CFrame.new()
		weld.Parent = hair
	end
	local accessory = if style == "citizen" and jobSpec.tool == nil then accessoryOf(l) else nil
	if accessory then
		local headFrame = head.CFrame
		local color, tint = paint(accessory.color, kingdomColor, skin, hairColor)
		local part = rigPart(
			model,
			"Accessory",
			"Part",
			Enum.PartType.Cylinder,
			accessory.size,
			headFrame * accessory.offset,
			color,
			Enum.Material.Fabric,
			tint
		)
		part:SetAttribute("KitAccessory", accessory.kind)
		local weld = Instance.new("Weld")
		weld.Name = "AccessoryWeld"
		weld.Part0 = head
		weld.Part1 = part
		weld.C0 = headFrame:Inverse() * part.CFrame
		weld.C1 = CFrame.new()
		weld.Parent = part
	end

	-- D-048 detail parts: rigid, welded to the Head or the Tool (never a Motor6D), flagged KitDetail so the client may
	-- drop them beyond the rig's LOD distance. At most Character.MAX_DETAIL per rig; named Detail1, Detail2.
	local details = 0
	local function addDetail(spec: PartSpec, parent: BasePart, frame: CFrame)
		details += 1
		assert(details <= Character.MAX_DETAIL, "too many detail parts")
		local part = specPart(model, `Detail{details}`, spec, frame * spec.offset, kingdomColor, skin, hairColor)
		part:SetAttribute(Character.DETAIL_ATTRIBUTE, true)
		part:SetAttribute("KitDetailKind", spec.name) -- "hoeblade", "axehead", "lamp", "strap", ...
		local weld = Instance.new("Weld")
		weld.Name = "DetailWeld"
		weld.Part0 = parent
		weld.Part1 = part
		weld.C0 = parent.CFrame:Inverse() * part.CFrame
		weld.C1 = CFrame.new()
		weld.Parent = part
	end
	local headDetail = if style == "governor"
		then GOVERNOR_CAP
		elseif style == "citizen" and jobSpec.hat then HEAD_DETAILS[job]
		else nil
	if headDetail then
		addDetail(headDetail, head, head.CFrame * CFrame.Angles(0, 0, hatRoll))
	end

	-- arms hang splayed a few degrees (friendlier silhouette, tools clear the legs)
	local armColor, armTint = paint(outfit.sleeves, kingdomColor, skin, hairColor)
	local armMaterial = if outfit.sleeves == "skin" then Enum.Material.SmoothPlastic else Enum.Material.Fabric
	local armX = width / 2 + ARM.X / 2 + 0.02
	local dropX, dropY = armX - width / 2, -(ARM.Y / 2 - (NECK_Y - SHOULDER_Y)) -- shoulder → arm centre
	local lShoulder = CFrame.new(-width / 2, SHOULDER_Y, 0)
	local rShoulder = CFrame.new(width / 2, SHOULDER_Y, 0)
	local larm = rigPart(
		model,
		"LeftArm",
		"Part",
		Enum.PartType.Block,
		ARM,
		lShoulder * CFrame.Angles(0, 0, -ARM_SPLAY) * CFrame.new(-dropX, dropY, 0),
		armColor,
		armMaterial,
		armTint
	)
	local rarm = rigPart(
		model,
		"RightArm",
		"Part",
		Enum.PartType.Block,
		ARM,
		rShoulder * CFrame.Angles(0, 0, ARM_SPLAY) * CFrame.new(dropX, dropY, 0),
		armColor,
		armMaterial,
		armTint
	)
	motor(torso, larm, lShoulder)
	motor(torso, rarm, rShoulder)
	if accentJob then -- KitAccent = job on every part that carries the job's accent colour
		if panelTorso then
			torso:SetAttribute("KitAccent", accentJob)
		end
		if panelSleeves then
			larm:SetAttribute("KitAccent", accentJob)
			rarm:SetAttribute("KitAccent", accentJob)
		end
	end

	local legColor, legTint = paint(outfit.legs, kingdomColor, skin, hairColor)
	local legMaterial = outfit.legMaterial or Enum.Material.Fabric
	for _, side in { -1, 1 } do
		local leg = rigPart(
			model,
			if side < 0 then "LeftLeg" else "RightLeg",
			"Part",
			Enum.PartType.Block,
			LEG,
			CFrame.new(side * 0.5, LEG.Y / 2, 0),
			legColor,
			legMaterial,
			legTint
		)
		if accentJob then
			leg:SetAttribute("KitAccent", accentJob)
		end
		motor(torso, leg, CFrame.new(side * 0.5, HIP_Y, 0))
	end

	local spec = if tool then TOOLS[tool] else nil
	if spec then
		local hand = rarm.CFrame * CFrame.new(0, -ARM.Y / 2 + HAND_UP, 0)
		local joint = if spec.onBack
			then CFrame.new(armX - 0.6, NECK_Y - 0.1, TORSO_D / 2)
			else CFrame.new(hand.Position)
		local part = specPart(model, "Tool", spec, joint * spec.offset, kingdomColor, skin, hairColor)
		part:SetAttribute("KitTool", spec.name)
		motor(if spec.onBack then torso else rarm, part, joint)
		for _, detail in spec.details or {} do
			addDetail(detail, part, joint)
		end
	end
	return model
end

-- ------------------------------------------------------------------ far LOD (one part, CONTRACTS G4)

function Character.lod(kind: string, kingdomColor: Color3): Model
	local tint = if kind == "citizen" then 0.8 else 1
	local model = Instance.new("Model")
	model.Name = `{kind}_lod`
	model:SetAttribute("KitKind", kind)
	model:SetAttribute("KitRootHeight", Character.LOD_ROOT_HEIGHT)
	-- one Block, centred at the rig's Root height with its feet on the ground (so 6.4 tall), identity rotation
	local root = rigPart(
		model,
		"Root",
		"Part",
		Enum.PartType.Block,
		Vector3.new(1.5, 2 * Character.LOD_ROOT_HEIGHT, 1.0),
		CFrame.new(0, Character.LOD_ROOT_HEIGHT, 0),
		shade(kingdomColor, tint),
		Enum.Material.SmoothPlastic,
		tint
	)
	root.Anchored = true
	root.CastShadow = false
	root.PivotOffset = CFrame.new(0, -Character.LOD_ROOT_HEIGHT, 0)
	model.PrimaryPart = root
	return model
end

-- ------------------------------------------------------------------ regalia (ruler crown + cape)

local function accessoryPart(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	tint: number?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	if tint then
		p:SetAttribute("KitTint", tint)
	end
	p.Parent = parent
	return p
end

local function weldTo(handle: BasePart, part: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = part
	w.Parent = part
end

-- Regalia are modelled in attachment space: the origin is the avatar's HatAttachment (top of the head)
-- or BodyBackAttachment (centre of the back), which R6 and R15 both carry with identity orientation.
function Character.regalia(kingdomColor: Color3): { Accessory }
	local crown = Instance.new("Accessory")
	crown.Name = "KitCrown"
	local band = accessoryPart(
		crown,
		"Handle",
		Enum.PartType.Cylinder,
		Vector3.new(0.5, 1.5, 1.5),
		CFrame.new(0, 0.15, 0) * UPRIGHT,
		C.gold,
		Enum.Material.Metal
	)
	local hat = Instance.new("Attachment")
	hat.Name = "HatAttachment"
	hat.CFrame = band.CFrame:Inverse()
	hat.Parent = band
	for i = 0, 4 do
		local a = math.rad(i * 72)
		local pt = accessoryPart(
			crown,
			"CrownPoint",
			Enum.PartType.Block,
			Vector3.new(0.32, 0.5, 0.32),
			CFrame.new(math.sin(a) * 0.6, 0.58, -math.cos(a) * 0.6) * CFrame.Angles(0, -a + math.rad(45), 0),
			C.gold,
			Enum.Material.Metal
		)
		weldTo(band, pt)
	end
	local jewel = accessoryPart(
		crown,
		"Jewel",
		Enum.PartType.Ball,
		Vector3.new(0.34, 0.34, 0.34),
		CFrame.new(0, 0.18, -0.74),
		kingdomColor,
		Enum.Material.SmoothPlastic,
		1
	)
	weldTo(band, jewel)
	local cap = accessoryPart( -- velvet cap in the kingdom colour: the crown reads from above too
		crown,
		"Cap",
		Enum.PartType.Ball,
		Vector3.new(1.3, 1.3, 1.3),
		CFrame.new(0, 0.3, 0),
		kingdomColor,
		Enum.Material.Fabric,
		1
	)
	weldTo(band, cap)

	local cape = Instance.new("Accessory")
	cape.Name = "KitCape"
	-- hangs from just below the shoulder line (R6 shoulders ≈ +1.0, R15 ≈ +0.6 above BodyBackAttachment) and
	-- flares 9° backwards so walking legs clip it less
	local drape = CFrame.new(0, 0.85, 0.14) * CFrame.Angles(math.rad(-9), 0, 0) * CFrame.new(0, -1.65, 0)
	local cloth = accessoryPart(
		cape,
		"Handle",
		Enum.PartType.Block,
		Vector3.new(2.5, 3.3, 0.18),
		drape,
		kingdomColor,
		Enum.Material.Fabric,
		1
	)
	local back = Instance.new("Attachment")
	back.Name = "BodyBackAttachment"
	back.CFrame = cloth.CFrame:Inverse()
	back.Parent = cloth
	local trims: { { name: string, shape: Enum.PartType, size: Vector3, at: CFrame } } = {
		{
			name = "Hem",
			shape = Enum.PartType.Block,
			size = Vector3.new(2.54, 0.24, 0.24),
			at = CFrame.new(0, -1.55, 0),
		},
		{
			name = "Yoke",
			shape = Enum.PartType.Block,
			size = Vector3.new(2.54, 0.16, 0.22),
			at = CFrame.new(0, 1.57, 0),
		},
		{ -- gold disc on the back, between the shoulder blades
			name = "Emblem",
			shape = Enum.PartType.Cylinder,
			size = Vector3.new(0.1, 0.95, 0.95),
			at = CFrame.new(0, 0.7, 0.12) * CFrame.Angles(0, math.rad(90), 0),
		},
	}
	for _, t in trims do
		weldTo(cloth, accessoryPart(cape, t.name, t.shape, t.size, drape * t.at, C.gold, Enum.Material.Metal))
	end
	return { crown, cape }
end

return Character
