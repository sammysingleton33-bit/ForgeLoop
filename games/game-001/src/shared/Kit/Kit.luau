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
		Kit.prop(assetId) -> Model                              -- Forge.Assets mesh if registered, else stand-in
		Kit.regionMarkers(polygon, kingdomColor) -> Model
		Kit.slotMarker(size: Vector2, kingdomColor) -> Model   -- G13.5 build slot marker (Root is the query target)
		Kit.NEUTRAL_COLOR, Kit.setKingdomColor(model, color)
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
		Kit.BUILDING_TYPES, Kit.partCount(model), Kit.characterMeshAvailable(), Kit.characterMeshStatus().
	Characters (FORGE-02): Kit.characterLod(kind, kingdomColor), Kit.CHARACTER_ROOT_HEIGHT, Kit.CHARACTER_MAX_PARTS,
		Kit.JOB_HEADWEAR, Kit.JOB_TOOLS, Kit.LOOK_RANGES,
		Kit.LOOK_PALETTES, Kit.DEFAULT_LOOK, Kit.normalizeLook(look), Kit.lookKey(look, kingdom?) (soldiers: pass
		the kingdom, the key gains ".<kingdom>"), Kit.SOLDIER_CRESTS (KingdomId → crest name).
]]

local Buildings = require("./Buildings")
local Character = require("./Character")
local CharacterMesh = require("./CharacterMesh")
local Parts = require("./Parts")
local Pieces = require("./Pieces")
local Portrait = require("./Portrait")
local Props = require("./Props")

local Kit = {}

export type BuildingType = string -- Kingdom/Types BuildingType (kept local so Kit has no cross-module require)
export type Stage = number | string

Kit.NEUTRAL_COLOR = Color3.fromRGB(208, 200, 184)
Kit.VERSION = "0.5.0" -- 0.5: kingdom architecture styles (FL-0127); 0.4: kingdom emblems (D-039) on every banner, flag, pennant and shield + aerial plaques
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

Kit.footprint = Buildings.footprint
Kit.build = Buildings.build
Kit.character = CharacterMesh.character -- the imported-mesh rig when the kit is imported and complete, else Character.character's
Kit.regalia = Character.regalia
-- G13.8 portrait (Kit/Portrait.luau has the focus contract): built by Character.character, then anchored
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
