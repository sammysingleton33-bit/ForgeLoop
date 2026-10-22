--!strict
--[[
	Kit — part-built medieval architecture, characters, regalia and prop stand-ins for AI Kingdoms.
	Owner: FORGE-02. Contract: games/game-001/CONTRACTS.md G10 (D-021 as amended by D-026).

	Rules (D-026, amended by D-057 for art): the part-built models are primitive Parts only (Part Block/Cylinder/Ball,
	WedgePart, CornerWedgePart); citizens (Kit.character, Kit.portrait) are Blender MeshPart rigs once the owner has imported the
	kit and the generated data is committed (Kit/CharacterMesh, else today's part-built rigs, whole); no CSG / PartOperation;
	nothing yields. Models are built at the origin with the pivot at the
	base centre (PrimaryPart "Root" + PivotOffset); front faces -Z (the Model's LookVector).

	Kingdom identity: Kit.build only receives a Color3, so the silhouette cue is picked from the
	colour's hue (red → spires, blue → pyramids, green → timber hoardings, yellow/gold → domes;
	unsaturated → neutral). Every kingdom-coloured part carries the attribute KitTint (shade
	factor), so Kit.setKingdomColor recolours trims and banners in place.
	Kingdom architecture (FL-0127, Operation Crownfall): Kit/KingdomStyle.luau is one table per hue style that Kit.build
	consults, so the kingdoms differ in more than colour, tower cap and emblem: stone, timber, plaster, thatch and crop
	palettes, roof pitch and tile courses (Emberhold steep red tile on dark stone, Frostmere snow-ridged slate-blue on
	pale stone, Thornwood moss-striped green on mossy stone and ochre daub, Sunspire low gold roofs on sandstone and
	whitewash), merlon proportions and banner tails. A style swaps colours, materials and proportions at the same part
	count and never touches Kit.footprint (tests/world/KitStyles.spec.luau); the neutral style is the original look.
	Emblems (D-033, D-039; colour-vision finding 3): the same hue map picks the kingdom emblem
	(crimson crown, azure star, emerald oak leaf, gold sun; neutral none), so emblem and silhouette
	always agree. Every banner, flag, pennant, shield, prop banner and slot sign carries it, and the
	keep carries two large aerial plaques (roof, facing up; donjon back). Emblem parts carry
	KitEmblem = "crown" | "star" | "oak" | "sun" and KitEmblemSlot; the part they sit on (the field)
	carries KitEmblemSlot, KitEmblemCF (anchor relative to the field), KitEmblemSize, KitEmblemDetail.

	API (G10):
		Kit.build(type, level, stage, kingdomColor, variant?) -> Model -- Door, WorkSpot1..n, DropOff, Rally; keep: Seat "Throne"
		Kit.footprint(type, level) -> Vector2
		Kit.character(kind, job, kingdomColor, look?, kingdom?) -> Model
		                                                        -- FL-0135 (D-057): the Blender MeshPart rig (Kit/CharacterMesh,
		                                                        -- same joints and pooling keys) when the kit data has pieces and
		                                                        -- Forge.Assets.CitizenKit holds every piece this assembly needs;
		                                                        -- otherwise the part-built rig below, whole, never a mix
		                                                        -- ≤ 11 parts: 9 (Hair welded to the Head, D-032) + at most 2 detail parts (D-048, KitDetail), Motor6Ds
		                                                        -- named after the moving part (Sim/Pose.JOINTS);
		                                                        -- look: CitizenLook (G13.2), omitted = DEFAULT_LOOK;
		                                                        -- kingdom: KingdomId (G13.2, D-033(3)): soldiers wear
		                                                        -- its helmet crest (spire, square, plume, dome) as the
		                                                        -- welded Hair, KitHeadwear "crest_<shape>"; omitted or
		                                                        -- unknown = the plain helm; others ignore it
		Kit.portrait(kind, job, kingdomColor, look?, kingdom?) -> Model
		                                                        -- G13.8 (D-036): Kit.character's rig for the same
		                                                        -- arguments, every part Anchored, motors and weld kept,
		                                                        -- + Attachment Root.PortraitFocus = the camera pose
		                                                        -- (head and shoulders, square ViewportFrame) with
		                                                        -- attributes PortraitFov (30, vertical) and
		                                                        -- PortraitDistance; model attribute KitPortrait
		Kit.portraitCamera(portrait) -> (CFrame, number)        -- camera CFrame and FieldOfView from PortraitFocus
		Kit.posePortrait(portrait, joints)                      -- places anchored parts for Sim/Pose joint transforms
		Kit.regalia(kingdomColor) -> { Accessory }              -- crown + cape
		Kit.prop(assetId) -> Model                              -- Forge.Assets mesh if registered (the FL-0136 nature meshes
		                                                        -- are checked against Kit/EnvMeshData: a mismatch is the stand-in), else stand-in
		Kit.regionMarkers(polygon, kingdomColor) -> Model
		Kit.slotMarker(size: Vector2, kingdomColor) -> Model   -- G13.5 build slot marker (Root is the query target)
		Kit.NEUTRAL_COLOR, Kit.setKingdomColor(model, color)
	War kit (FL-0128, Operation Crownfall; additive, the contract rows are in
	production/handoffs/2026-10-19-forge-02-to-forge-00-04-fl0128-war-kit.md; part-built, D-026):
		Kit.build("wall" | "gate", 1..3, ...)          -- wall 30/45/60 parts (L1 palisade, L2 stone, L3 its own outline: end piers,
		                                                  buttresses, pedestal brazier), gate 90/120/150
		                                                  (L1 timber leaves, L2 banded leaves + banners, L3 portcullis + braziers; open leaves
		                                                  swing 65 degrees into the passage; every level has a recessed Tympanum over
		                                                  the leaves (at L3 behind the portcullis bars), the passage floor is mid-tone);
		                                                  Buildings.PART_BUDGET_BY_LEVEL; footprints unchanged (32x8, 32x12)
		Kit.build("watchtower", 2, ...)                -- war-ready: hoarding galleries, braziers, banner, more merlons; <= 130
		Kit.setGateOpen(model, open)                   -- model attribute KitGateOpen (false as built); leaves and portcullis
		                                                  move by CFrame alone (no part added), relative to the Root; open, the
		                                                  portcullis is raised into the lintel; also poses leaves a damaged gate
		                                                  has parked (they come back posed)
		Kit.siege("ram", kingdomColor) -> Model        -- client entity rig, <= 45 parts, Root anchored and invisible, feet pivot,
		                                                  front -Z, ONE Motor6D "Log" (the pale log with its iron wedge head, 7 studs
		                                                  past a low pent roof; the roof alone carries the kingdom); Kit.SIEGE_KINDS
		Kit.siegePose(model, thrust 0..1)              -- sets the Log joint; Kit.siegeTransform(thrust) -> CFrame is the same
		                                                  value for a driver with its own Transform adapter
		Kit.character("soldier", "knight" | "archer", ...) -- unit kinds by job (soldier = spear (1.3x body height) and pennant, knight = sword,
		                                                  bulky, a large kingdom-coloured shield with a flat mark, a broad great helm with
		                                                  a big crest, archer = short curved bow with a string held below the chin, round
		                                                  head, no quiver); still <= 11 parts
		                                                  with the kingdom crest; any other job = the spear soldier
		Kit.applyDamage(model)                         -- reads the model attribute `Damage` (0..1) and builds or removes damage parts
		                                                  at 0.25 / 0.5 / 0.75 / 0.95 (<= 14 extra parts, none at 0; repairable);
		                                                  all of it in the model's own frame (the PrimaryPart's pivot), so a turned or
		                                                  moved building damages like one at the origin, and the parts it takes off keep
		                                                  their CFrame relative to the PrimaryPart (Kit/Damage.luau has the contract);
		                                                  Kit.damageState(d), Kit.damageFromHp(hp, maxHp), Kit.DAMAGE_THRESHOLDS
	Crown Arena (FL-0072, G12.6; Kit/Arena.luau, Crowd.luau, Gear.luau have the contracts):
		Kit.arena(kingdomA?, kingdomB?) -> Model       -- the venue: ring, two stands (72 seats each, StandA_Row<r>_Seat<s>,
		                                                  StandA_Rail<n>, StandA_Royal<n>), royal boxes, gates (GateA / GateB),
		                                                  SpawnA / SpawnB; neutral stone and timber + a DressA / DressB sub-model
		                                                  per kingdom (cap silhouette AND emblem); <= 700 parts neutral, cap 900
		Kit.arenaDress(model, kingdomA?, kingdomB?)    -- rebuild both dresses in place (ArenaService, at the Arena phase)
		Kit.crowdFigure(kingdomColor, role?, variant?) -> Model  -- <= 4 parts, client-only, feet pivot, front -Z; role: KeyRole
		Kit.armour(armour, kingdomColor) -> { Accessory }        -- "light" | "medium" | "heavy" on Hat / BodyFront / BodyBack / Collar
		Kit.carried(resource) -> Model                           -- the load a citizen carries in both hands: "food" | "wood" | "stone" | "gold" (3-4 welded parts, PrimaryPart at the pivot; Kit.CARRIED)
		Kit.shield(kingdomColor?) -> Accessory                   -- the round shield on the LEFT hand (LeftGripAttachment; 4 parts; KitShield)
		Kit.weapon(weapon, kingdomColor?, opts?) -> Tool        -- "swordShield" | "greatsword" | "spear" | "mace"; opts = { shield: boolean? }:
		                                                          -- swordShield keeps its round shield on the Tool (10 parts) unless
		                                                          -- opts.shield == false (the sword alone, 6 parts, to go with Kit.shield);
		                                                          -- swordShield carries KitShield = "shield" either way
		Kit.ARENA (dimensions, PART_BUDGET), Kit.CROWD_ROLES, CROWD_MAX_PARTS, CROWD_ROLE_MAX_PARTS, CROWD_VARIANTS, CROWD_HEIGHT, crowdPoolKey,
		Kit.ARMOURS, Kit.WEAPONS
	Additive (emblems): Kit.EMBLEM_KINDS ({ [hue style]: kind }), Kit.emblemKind(color) -> kind?
	Recolour: Kit.setKingdomColor recolours every KitTint part and re-forms every emblem to the new
		colour's kind (a neutral colour removes them; a kingdom colour adds them on a neutral model). It
		never touches other part identities. Shape cues picked at build time — tower caps, stone and trim
		metal — stay as built: to give a building another kingdom's silhouette, rebuild it with Kit.build.
		Rebuild keeps (and any building) on a kingdom change rather than recolouring: emblems cost a different
		number of parts per kingdom, so a recoloured model can exceed its part budget (an emerald keep L2
		recoloured to gold has 262 parts against 260); Kit.build always fits.
		setKingdomColor also works on a container holding several Kit models (slots pair per model).
	Additive (FORGE-02 area): Kit.setAssetSource(folder) (WorldService passes ReplicatedStorage.Forge.Assets),
		Kit.BUILDING_TYPES, Kit.partCount(model), Kit.characterMeshAvailable(), Kit.characterMeshStatus(), Kit.envMeshStatus().
	Characters (FORGE-02): Kit.characterLod(kind, kingdomColor), Kit.CHARACTER_ROOT_HEIGHT, Kit.CHARACTER_MAX_PARTS,
		Kit.JOB_HEADWEAR, Kit.JOB_TOOLS, Kit.LOOK_RANGES,
		Kit.LOOK_PALETTES, Kit.DEFAULT_LOOK, Kit.normalizeLook(look), Kit.lookKey(look, kingdom?) (soldiers: pass
		the kingdom, the key gains ".<kingdom>"), Kit.SOLDIER_CRESTS (KingdomId → crest name).
]]

local Arena = require("./Arena")
local Buildings = require("./Buildings")
local Character = require("./Character")
local Damage = require("./Damage")
local CharacterMesh = require("./CharacterMesh")
local Crowd = require("./Crowd")
local EnvMesh = require("./EnvMesh")
local Gear = require("./Gear")
local Parts = require("./Parts")
local Pieces = require("./Pieces")
local Portrait = require("./Portrait")
local Props = require("./Props")
local Siege = require("./Siege")

local Kit = {}

export type BuildingType = string -- Kingdom/Types BuildingType (kept local so Kit has no cross-module require)
export type Stage = number | string

Kit.NEUTRAL_COLOR = Color3.fromRGB(208, 200, 184)
Kit.VERSION = "0.6.2" -- 0.6.2: Kit.carried (the goods a citizen carries, FORGE-04's carry pose); 0.6.1: Kit.shield (a left-hand Accessory) and Kit.weapon opts.shield (additive, FL-0072 follow-up); 0.6: Crown Arena, crowd figures, duel gear (FL-0072); 0.5: kingdom architecture styles (FL-0127); 0.4: kingdom emblems (D-039) on every banner, flag, pennant and shield + aerial plaques
-- G2 BuildingType + the G13.5 VS-2 types (part-built stand-ins until FL-0086)
Kit.BUILDING_TYPES = {
	"keep",
	"house",
	"farm",
	"storehouse",
	"lumbercamp",
	"quarry",
	"barracks",
	"watchtower",
	"wall",
	"gate",
	"mine",
	"blacksmith",
	"market",
	"infirmary",
	"granary",
	"shrine",
}
Kit.CHARACTER_HEAD_SCALE = Character.HEAD_SCALE -- a citizen's head and what it wears are drawn this much bigger (silhouette pass 2); tools Kit.CHARACTER_TOOL_SCALE
Kit.CHARACTER_TOOL_SCALE = Character.TOOL_SCALE
Kit.CHARACTER_ROOT_HEIGHT = Character.ROOT_HEIGHT -- 3.2: Root centre above the feet, rig and LOD alike
Kit.CHARACTER_MAX_PARTS = Character.MAX_PARTS -- rig part cap the Kit specs enforce (11 = 9 + 2 detail parts, D-048)
-- Job silhouettes (art pass): job -> KitHeadwear name of its hat / KitTool name of its tool (farmer, woodcutter,
-- miner, builder wear a hat; hauler and idle keep the look's hair). Parts carrying the job's outfit colour
-- (trousers, plus the torso or sleeves the outfit leaves neutral) have KitAccent = job.
Kit.CHARACTER_BASE_PARTS = Character.BASE_PARTS -- 9: the D-032 rig; D-048 detail parts come on top
Kit.CHARACTER_MAX_DETAIL = Character.MAX_DETAIL -- 2
Kit.CHARACTER_DETAIL_ATTRIBUTE = Character.DETAIL_ATTRIBUTE -- "KitDetail" = true on every detail part (droppable beyond LOD)
Kit.JOB_HEADWEAR = Character.JOB_HEADWEAR
Kit.JOB_TOOLS = Character.JOB_TOOLS
-- Citizen looks (G13.2): 1-based index counts FORGE-01's population generator samples from, the palettes
-- behind them (skin and hairColor are Color3 lists; hair and outfit list style names), the default look,
-- and the pool key (equal keys → identical rigs). Out-of-range values wrap; Kit never errors on a look.
Kit.LOOK_RANGES = Character.LOOK_RANGES
Kit.LOOK_PALETTES = Character.LOOK_PALETTES
Kit.DEFAULT_LOOK = Character.DEFAULT_LOOK
Kit.normalizeLook = Character.normalizeLook
Kit.lookKey = Character.lookKey
-- soldier helmet crest per KingdomId (G13.2, D-033(3)): crimson "crest_spire", azure "crest_square",
-- emerald "crest_plume", gold "crest_dome" (the Hair part's KitHeadwear)
Kit.SOLDIER_CRESTS = Character.CRESTS

-- Crown Arena (FL-0072, G12.6): the venue, its kingdom dress and the numbers Layout.arena mirrors
Kit.arena = Arena.build -- (kingdomA?, kingdomB?) -> Model: neutral stone, timber and sand + each side's kingdom dress
Kit.arenaDress = Arena.dress -- (model, kingdomA?, kingdomB?): rebuild both dresses in place
Kit.ARENA = Arena
-- Crowd figures (G12.6): <= 4 primitive parts (<= 8 for a key citizen, v0.4-g11a), client-only; role props for the six key citizens
Kit.crowdFigure = Crowd.build -- (kingdomColor, role: KeyRole?, variant: number?) -> Model, feet-pivoted, front -Z
Kit.CROWD_ROLES = Crowd.ROLES
Kit.CROWD_MAX_PARTS = Crowd.MAX_PARTS
Kit.CROWD_ROLE_MAX_PARTS = Crowd.ROLE_MAX_PARTS
Kit.CROWD_VARIANTS = Crowd.VARIANTS
Kit.CROWD_HEIGHT = Crowd.HEIGHT
Kit.crowdPoolKey = Crowd.poolKey
-- Duel gear (G12.1 Armour / Weapon, G12.6): accessories in attachment space (R15 and R6) and a Tool with a Handle, no scripts
Kit.armour = Gear.armour -- (armour: "light" | "medium" | "heavy", kingdomColor) -> { Accessory }
Kit.weapon = Gear.weapon -- (weapon: "swordShield" | "greatsword" | "spear" | "mace", kingdomColor?, opts: { shield: boolean? }?) -> Tool
Kit.carried = Gear.carried -- (resource: "food" | "wood" | "stone" | "gold") -> Model: the load held in both hands (pivot at the hands' midpoint, front -Z)
Kit.CARRIED = Gear.RESOURCES
Kit.shield = Gear.shield -- (kingdomColor?) -> Accessory on LeftGripAttachment: the sword-and-shield's shield for the left hand (use with { shield = false })
Kit.ARMOURS = Gear.ARMOURS
Kit.WEAPONS = Gear.WEAPONS

Kit.footprint = Buildings.footprint
Kit.build = Buildings.build -- (type, level, stage, color, variant?): the level is clamped to 1..Kit.MAX_LEVEL[type] and KitLevel stores the clamped one
Kit.MAX_LEVEL = Buildings.MAX_LEVEL
-- FL-0128 war kit (additive): gate open/closed poses, siege engines and their pose helper
-- (model, open: boolean): leaves and portcullis by CFrame only; attribute KitGateOpen. Leaves a damaged gate has lost
-- (Kit.applyDamage) are posed too, so a repair brings them back in the current pose.
function Kit.setGateOpen(model: Model, open: boolean)
	Buildings.setGateOpen(model, open, Damage.stashed(model))
end
Kit.siege = Siege.build -- (kind "ram", kingdomColor) -> Model: client entity rig with one Motor6D "Log"
Kit.siegePose = Siege.pose -- (model, thrust 0..1): places the swinging log
Kit.siegeTransform = Siege.thrustTransform -- (thrust 0..1) -> CFrame: the Log joint's Transform (for a pose driver with its own adapter)
Kit.SIEGE_KINDS = Siege.KINDS
Kit.applyDamage = Damage.apply -- (model): builds / removes damage parts from the model attribute `Damage` (0..1)
Kit.damageState = Damage.stateOf -- (damage) -> 0..4
Kit.damageFromHp = Damage.fromHp -- (hp, maxHp) -> 1 - hp / maxHp, clamped
Kit.DAMAGE_THRESHOLDS = Damage.THRESHOLDS -- { 0.25, 0.5, 0.75, 0.95 }
Kit.character = CharacterMesh.character -- the imported-mesh rig when the kit is imported and complete, else Character.character's
Kit.regalia = Character.regalia
-- G13.8 portrait (Kit/Portrait.luau has the focus contract): built by CharacterMesh.character (the mesh rig, else Character.character), then anchored
Kit.portrait = Portrait.portrait
Kit.portraitCamera = Portrait.camera
Kit.posePortrait = Portrait.pose
Kit.PORTRAIT_FOV = Portrait.FOV
Kit.characterLod = Character.lod -- one-part stand-in beyond 150 studs (G4), same Root height as the rig
Kit.prop = Props.prop
-- Both the props and the citizen meshes (ReplicatedStorage.Forge.Assets.CitizenKit) are looked up in this folder. The
-- server's WorldService passes it when it builds the world; a client that builds rigs (EntityController, portraits) must
-- pass it too, or its citizens stay part-built (see the FL-0135 handoff to FORGE-04).
function Kit.setAssetSource(folder: Instance?)
	Props.setAssetSource(folder)
	CharacterMesh.setAssetSource(folder)
end
Kit.characterMeshAvailable = CharacterMesh.available -- () -> boolean: kit data + a CitizenKit folder are present
Kit.characterMeshStatus = CharacterMesh.status -- () -> diagnostics (pieces, missing, mesh vs fallback builds, last fallback reason)
Kit.envMeshStatus = EnvMesh.status -- () -> { props, accepted, rejected = { [assetId] = why } }: the FL-0136 nature meshes behind Kit.prop
Kit.envMeshReady = Props.meshReady -- (assetId) -> boolean: Kit.prop would build the imported mesh for this id (FL-0136 mesh-only dressing)
Kit.nodeMarker = Props.nodeMarker -- (model, resource) -> boolean: the FL-0136 resource marker (WorldService puts it on every node)
Kit.regionMarkers = Props.regionMarkers
Kit.slotMarker = Props.slotMarker -- G13.5 build slot ground marker (WorldService)
Kit._hueStyle = Parts.hueStyle
Kit.EMBLEM_KINDS = table.freeze(table.clone(Parts.EMBLEM_KINDS)) -- hue style -> emblem kind (D-039)
Kit.emblemKind = Parts.emblemKind -- (color) -> "crown" | "star" | "oak" | "sun" | nil (neutral)

local shade = Parts.shade

-- ------------------------------------------------------------------ recolouring

-- Re-forms every emblem slot whose kind differs from the new colour's: the old parts go, the new kind is
-- built on the same anchor (the field part's KitEmblemCF, so it follows wherever the model was moved).
-- Slots are numbered per Kit model, so fields and marks are paired by (owning Kit model, slot): a container
-- holding several Kit models re-forms each one's emblems.
local function reformEmblems(model: Model, color: Color3)
	local kind = Parts.emblemKind(color)
	local fields: { [Instance]: { [number]: BasePart } } = {}
	local marks: { [Instance]: { [number]: { BasePart } } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local slot = d:GetAttribute("KitEmblemSlot")
			if type(slot) == "number" then
				local owner: Instance = d:FindFirstAncestorOfClass("Model") or model
				if d:GetAttribute("KitEmblem") ~= nil then
					marks[owner] = marks[owner] or {}
					marks[owner][slot] = marks[owner][slot] or {}
					table.insert(marks[owner][slot], d)
				elseif d:GetAttribute("KitEmblemCF") ~= nil then
					fields[owner] = fields[owner] or {}
					fields[owner][slot] = d
				end
			end
		end
	end
	for owner, slots in fields do
		for slot, field in slots do
			local old = marks[owner] and marks[owner][slot]
			if (if old then old[1]:GetAttribute("KitEmblem") else nil) ~= kind then
				for _, p in old or {} do
					p:Destroy()
				end
				local rel, size = field:GetAttribute("KitEmblemCF"), field:GetAttribute("KitEmblemSize")
				if kind and typeof(rel) == "CFrame" and type(size) == "number" then
					local tint = field:GetAttribute("KitTint")
					local detail = field:GetAttribute("KitEmblemDetail")
					local ctx = { model = field.Parent :: any, root = field, count = 0 }
					Pieces.buildEmblem(
						ctx,
						field.CFrame * rel,
						size,
						kind,
						color,
						if type(tint) == "number" then tint else 1,
						if type(detail) == "string" then detail else "compact",
						slot
					)
				end
			end
		end
	end
end

function Kit.setKingdomColor(model: Model, color: Color3)
	reformEmblems(model, color)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local f = d:GetAttribute("KitTint")
			if type(f) == "number" then
				d.Color = shade(color, f)
			end
		end
	end
	-- parts a damaged model has taken off (Kit.applyDamage) come back after a repair: recolour them too
	for _, p in Damage.stashed(model) do
		local f = p:GetAttribute("KitTint")
		if type(f) == "number" then
			p.Color = shade(color, f)
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

return Kit
