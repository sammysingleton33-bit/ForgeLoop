--!strict
--[[
	Kit/Character — Kit.character rigs with per-citizen looks (CONTRACTS G4 rendering, G10, G13.2; D-026, D-032),
	the one-part far LOD stand-in, and ruler regalia (crown + cape accessories).

	Rig: at most Character.MAX_PARTS (9) BaseParts, no Humanoid/Animator, every part CanCollide/CanTouch/CanQuery
	false and Massless. Motor6Ds are named after the moving part and match Sim/Pose.JOINTS:
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
	about it. Part counts: 7 (bald idle citizen) to 9 (headwear + tool); working citizens (farmer, woodcutter,
	miner, builder) always 9 (hat + tool); soldiers 8 (the helm is their Head), 9 with a kingdom crest; governors 9;
	Motor6Ds = parts − 1 − welded headwear. Character.MAX_PARTS is the one cap the specs enforce; the 11-part
	variant of D-048 (two more rigid detail parts) is a later phase.

	Job silhouettes (citizen art pass after the first Studio playtest). Each working job reads without colour:
		farmer      wide straw hat (flat disc 3.4), long hoe board, lean body        KitHeadwear "strawhat"
		woodcutter  charcoal knit cap slouched back into a tall tail, big bearded axe blade, stocky   "knitcap"
		miner       squat ochre iron hat, double-sided pick bar (T), stocky          "hardhat"
		builder     white linen peaked cap (low wedge, sits on the head), big wooden mallet, broad   "buildercap"
		hauler      no job hat (hair shows), huge burlap sack on the back, broad
		idle        hair only, nothing carried, lean
	The job also owns an outfit accent: the trousers (colour, KitAccent = job) and the outfit's fixed neutral
	panel (the torso or the sleeves, whichever the outfit does not tint or leave bare) take the job's colour, so
	look.outfit still moves the kingdom tint, the bare arms and the cut, while the job accent stays. The hat
	takes the Hair slot, so the look's hair style picks a variant of it (roll tilt and shade, KitHeadwear
	unchanged) and the hair colour is hidden under it; idle and hauler citizens keep all hair styles.

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
-- The arm Motor6Ds pivot this far outside the torso's side (the arm parts stay exactly where they hang at rest): an arm raised
-- in the cheer swings about its own centre line instead of its inner edge, so it clears the 1.6-stud head (FORGE-01's pose
-- analysis: the old pivot sat about 0.4 too far in). The soldier's wider helm needs a little more.
local SHOULDER_OUT = 0.41 -- the arm's centre line (ARM.X / 2 + 0.02)
local SHOULDER_OUT_SOLDIER = 0.55
local ARM_SPLAY = math.rad(7)
local HAND_UP = 0.2 -- the hand joint sits inside the fist, this far above the arm's end
local HEAD_D = 1.6
local HEAD_Y = NECK_Y + HEAD_D / 2 - 0.06 -- head centre (4.64)

Character.ROOT_HEIGHT = 3.2 -- Root centre above the feet (Kit.CHARACTER_ROOT_HEIGHT), rig and LOD alike
Character.LOD_ROOT_HEIGHT = Character.ROOT_HEIGHT
Character.HEIGHT = 5.5 -- the body (head top); a hat, crest or tool may rise above it
Character.SHOULDER_OUT = SHOULDER_OUT -- how far outside the torso's side the arm Motor6D pivots sit (citizens, governors)
Character.SHOULDER_OUT_SOLDIER = SHOULDER_OUT_SOLDIER -- ... and the soldier's (a wider helm)
Character.MAX_PARTS = 9 -- D-032 rig cap, the one number the specs enforce (D-048 raises it to 11 in a later phase)

-- ------------------------------------------------------------------ colours

local STEEL = Color3.fromRGB(176, 182, 192)
local STEEL_DARK = Color3.fromRGB(84, 90, 100)
local BLADE = Color3.fromRGB(138, 146, 158)
local BURLAP = Color3.fromRGB(146, 108, 70) -- sack: a darker sackcloth (L .46)
local LINEN = Color3.fromRGB(226, 214, 186)
local LEATHER = Color3.fromRGB(120, 78, 46)
local STRAW = Color3.fromRGB(216, 176, 84) -- farmer's hat: straw (L .70)
local KNIT = Color3.fromRGB(52, 58, 70) -- woodcutter's cap: charcoal wool (neutral, so it never reads as a kingdom)
local HARDHAT = Color3.fromRGB(190, 118, 30) -- miner's iron hat: burnt ochre (L .50)
local COIF = Color3.fromRGB(238, 232, 216) -- builder's cap: white linen
local ASH = Color3.fromRGB(214, 190, 146) -- spear shaft: pale ash, visible against grass and soldiers' steel
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

-- Job headwear (Hair slot, welded to the Head): one bold silhouette per working job, none a ball (balls are
-- hair) and none a hair colour. Heads: top 5.44, face clear below y = +0.33 (head-centre frame). A hat sits ON
-- the head (clearance rules in the Kit spec): the head enters it by at most 0.4 above its lower face, and no
-- skin shows through its top or sides (every head point above the hat's lower face is inside the hat).
local JOB_HATS: { [string]: PartSpec } = {
	farmer = { -- wide flat straw disc: the widest thing on any citizen, a big pale circle from above
		name = "strawhat",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.42, 3.4, 3.4),
		color = STRAW,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 0.62, 0) * UPRIGHT,
	},
	woodcutter = { -- knit cap slouched back: a wedge, low over the brow and rising to a tall tail behind the head
		-- (the slope stays above the skull, so no skin shows through): the only hat taller behind than in front
		name = "knitcap",
		class = "WedgePart",
		size = Vector3.new(1.9, 1.6, 2.0),
		color = KNIT,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 1.24, 0.1), -- base 0.44 above the head centre, apex 2.04
	},
	miner = { -- squat iron hat with a rim wider than the head, ochre and glossy: a pot on the head
		name = "hardhat",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.8, 2.2, 2.2),
		color = HARDHAT,
		material = Enum.Material.Metal,
		offset = CFrame.new(0, 0.84, 0) * UPRIGHT,
	},
	builder = { -- white linen peaked cap: a low wedge, thin lip over the brow, higher crown behind. It sits ON the head
		-- (base 0.45 above the head centre) and its slope stays above the skull, so the head no longer pokes
		-- through a flat-bottomed block
		name = "buildercap",
		class = "WedgePart",
		size = Vector3.new(1.7, 0.95, 1.9),
		color = COIF,
		material = Enum.Material.Fabric,
		offset = CFrame.new(0, 0.925, 0.05),
	},
}
-- The hat takes the look's hair slot, so look.hair picks a variant of it: a roll tilt (3) and a shade (2).
local HAT_ROLLS = { 0, math.rad(9), math.rad(-9) }
local HAT_SHADES = { 1, 0.88 } -- shaded hats of different jobs never overlap in luminance (spec)

local GOVERNOR_CROWN: PartSpec = { -- gold circlet on the head, a gold disc from above; it covers the head's top
	-- (the head used to poke through its top face): bottom 0.41 above the head centre, top 0.91
	name = "crown",
	class = "Part",
	shape = Enum.PartType.Cylinder,
	size = Vector3.new(0.5, 1.52, 1.52),
	color = C.gold,
	material = Enum.Material.Metal,
	offset = CFrame.new(0, 0.66, 0) * UPRIGHT,
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
local SPIRE = Vector3.new(1.3, 2.1, 1.3) -- base 1.84 across the diagonal: a broad roof, not a stick
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
}
local JOBS: { [string]: JobStyle } = {
	idle = { width = 1.9 },
	farmer = { -- light: cream shirt or apron, olive trousers, straw hat
		width = 1.95,
		tool = "hoe",
		hat = JOB_HATS.farmer,
		panel = Color3.fromRGB(232, 222, 190),
		legs = Color3.fromRGB(98, 104, 58),
	},
	woodcutter = { -- dark: umber leather, black-brown trousers, charcoal cap, bright steel axe
		width = 2.3,
		tool = "axe",
		hat = JOB_HATS.woodcutter,
		panel = Color3.fromRGB(96, 66, 46),
		legs = Color3.fromRGB(58, 42, 32),
	},
	miner = { -- cool grey: soot panel, coal trousers, ochre hat
		width = 2.2,
		tool = "pick",
		hat = JOB_HATS.miner,
		panel = Color3.fromRGB(122, 126, 136),
		legs = Color3.fromRGB(70, 68, 72),
	},
	builder = { -- tan canvas, dusty navy trousers, white cap
		width = 2.3,
		tool = "hammer",
		hat = JOB_HATS.builder,
		panel = Color3.fromRGB(196, 158, 104),
		legs = Color3.fromRGB(52, 62, 94),
	},
	hauler = { -- sackcloth panel and russet trousers; keeps the look's hair (the sack is the signature)
		width = 2.3,
		tool = "sack",
		panel = Color3.fromRGB(156, 118, 80),
		legs = Color3.fromRGB(112, 68, 42),
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
-- Swing tools (axe, pick, hammer) are oversized heads gripped at the fist: in a swing the arm reads as the
-- handle. They are turned 40° outwards so the head shows from the front as well as from the side.
local OUT = CFrame.Angles(0, math.rad(-40), 0)

local TOOLS: { [string]: PartSpec } = {
	hoe = { -- a long broad board (the hoe/spade read: a shaft with a blade, one part): 5.4 long, 1.0 wide
		name = "hoe",
		class = "Part",
		shape = Enum.PartType.Block,
		size = Vector3.new(1.0, 5.4, 0.3),
		color = C.woodLight,
		material = Enum.Material.Wood,
		offset = GRIP * OUT * CFrame.Angles(0, 0, math.rad(-10)) * CFrame.new(0, 0.7, 0.1),
	},
	axe = { -- big bearded blade: flat top level with the fist, straight cutting edge in front, the beard hanging
		-- 2.4 below the haft; bright steel
		name = "axe",
		class = "WedgePart",
		size = Vector3.new(0.5, 2.4, 2.3),
		color = BLADE,
		material = Enum.Material.Metal,
		offset = OUT * CFrame.new(0, -0.95, -0.9) * CFrame.Angles(math.pi, 0, 0),
	},
	pick = { -- double-sided pick head: a long dark bar across the top of the arm (a T), 4.4 from tip to tip
		name = "pick",
		class = "Part",
		shape = Enum.PartType.Block,
		size = Vector3.new(0.7, 0.7, 4.4),
		color = STEEL_DARK,
		material = Enum.Material.Metal,
		offset = OUT * CFrame.new(0, -0.1, 0) * CFrame.Angles(math.rad(-12), 0, 0),
	},
	hammer = { -- big wooden mallet: a fat square head across the fist
		name = "hammer",
		class = "Part",
		shape = Enum.PartType.Block,
		size = Vector3.new(1.4, 1.35, 2.6),
		color = C.wood,
		material = Enum.Material.Wood,
		offset = OUT * CFrame.new(0, -0.45, -0.2),
	},
	sack = { -- big burlap sack on the back, seated against the shoulder blades and clear of the head and both arms
		-- (centre on the spine, 3.05 up, 1.95 behind it; joint at 0.96, 3.8, 0.575)
		name = "sack",
		class = "Part",
		shape = Enum.PartType.Ball,
		size = Vector3.new(2.7, 2.7, 2.7),
		color = BURLAP,
		material = Enum.Material.Fabric,
		offset = CFrame.new(-0.96, -0.75, 1.375),
		onBack = true,
	},
	spear = { -- 9 long and 0.4 thick in pale ash, so the line reads against grass and steel
		name = "spear",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(9.0, 0.4, 0.4),
		color = ASH,
		material = Enum.Material.Wood,
		offset = GRIP * CFrame.new(0, 2.2, 0) * UPRIGHT,
	},
	staff = {
		name = "staff",
		class = "Part",
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(5.6, 0.34, 0.34),
		color = C.gold,
		material = Enum.Material.Metal,
		offset = GRIP * CFrame.new(0, 0.7, 0) * UPRIGHT,
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

-- The job's accent on an outfit: the fixed neutral torso/sleeve colour (not a kingdom tint, not bare skin)
-- becomes the job's panel colour, and the trousers its legs colour. The kingdom tint and bare arms stay.
local function jobOutfit(outfit: Outfit, job: JobStyle): Outfit
	return {
		name = outfit.name,
		torso = if typeof(outfit.torso) == "Color3" then job.panel :: Color3 else outfit.torso,
		sleeves = if typeof(outfit.sleeves) == "Color3" then job.panel :: Color3 else outfit.sleeves,
		legs = job.legs :: Color3,
		legMaterial = outfit.legMaterial,
	}
end

-- look.hair (1..6) picks one of 6 variants of a job hat: roll 0 / +9° / −9° about the head's front axis, in
-- the full shade or 0.88 of it. The shape, size and KitHeadwear name never change.
local function hatVariant(spec: PartSpec, hairIndex: number): PartSpec
	local roll = HAT_ROLLS[(hairIndex - 1) % #HAT_ROLLS + 1]
	local tone = HAT_SHADES[((hairIndex - 1) // #HAT_ROLLS) % #HAT_SHADES + 1]
	local at = spec.offset.Position
	local color = spec.color :: Color3
	return {
		name = spec.name,
		class = spec.class,
		shape = spec.shape,
		size = spec.size,
		color = Color3.new(color.R * tone, color.G * tone, color.B * tone),
		material = spec.material,
		offset = CFrame.new(at) * CFrame.Angles(0, 0, roll) * (CFrame.new(-at) * spec.offset),
	}
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
	local accentJob: string? = nil -- the job whose accent colours the outfit (working citizens only)
	local panelTorso, panelSleeves = false, false -- where the job's panel colour landed
	if style == "soldier" then
		outfit, headwear, width, tool = SOLDIER_OUTFIT, crest, 2.15, "spear"
	elseif style == "governor" then
		outfit, headwear, width, tool = GOVERNOR_OUTFIT, GOVERNOR_CROWN, 2.2, "staff"
	else
		outfit, headwear, width, tool = OUTFITS[l.outfit], HAIR_STYLES[l.hair].spec, jobSpec.width, jobSpec.tool
		if jobSpec.legs then
			panelTorso, panelSleeves = typeof(outfit.torso) == "Color3", typeof(outfit.sleeves) == "Color3"
			outfit, accentJob = jobOutfit(outfit, jobSpec), job
		end
		if jobSpec.hat then -- the job hat takes the Hair slot; look.hair picks its variant
			headwear = hatVariant(jobSpec.hat, l.hair)
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
	local pivotOut = if style == "soldier" then SHOULDER_OUT_SOLDIER else SHOULDER_OUT
	motor(torso, larm, CFrame.new(-(width / 2 + pivotOut), SHOULDER_Y, 0))
	motor(torso, rarm, CFrame.new(width / 2 + pivotOut, SHOULDER_Y, 0))
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
