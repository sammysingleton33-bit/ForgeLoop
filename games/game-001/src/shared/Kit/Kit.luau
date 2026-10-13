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
		Kit.build(type, level, stage, kingdomColor, variant?) -> Model -- Door, WorkSpot1..n, DropOff, Rally; keep: Seat "Throne"
		Kit.footprint(type, level) -> Vector2
		Kit.character(kind, job, kingdomColor, look?, kingdom?) -> Model
		                                                        -- ≤ 9 parts (Hair welded to the Head, D-032), Motor6Ds
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
	Additive (FORGE-02 area): Kit.setAssetSource(folder) (WorldService passes ReplicatedStorage.Forge.Assets),
		Kit.BUILDING_TYPES, Kit.partCount(model).
	Characters (FORGE-02): Kit.characterLod(kind, kingdomColor), Kit.CHARACTER_ROOT_HEIGHT, Kit.LOOK_RANGES,
		Kit.LOOK_PALETTES, Kit.DEFAULT_LOOK, Kit.normalizeLook(look), Kit.lookKey(look, kingdom?) (soldiers: pass
		the kingdom, the key gains ".<kingdom>"), Kit.SOLDIER_CRESTS (KingdomId → crest name).
]]

local Buildings = require("./Buildings")
local Character = require("./Character")
local Parts = require("./Parts")
local Portrait = require("./Portrait")
local Props = require("./Props")

local Kit = {}

export type BuildingType = string -- Kingdom/Types BuildingType (kept local so Kit has no cross-module require)
export type Stage = number | string

Kit.NEUTRAL_COLOR = Color3.fromRGB(208, 200, 184)
Kit.VERSION = "0.3.0"
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
Kit.character = Character.character
Kit.regalia = Character.regalia
-- G13.8 portrait (Kit/Portrait.luau has the focus contract): built by Character.character, then anchored
Kit.portrait = Portrait.portrait
Kit.portraitCamera = Portrait.camera
Kit.posePortrait = Portrait.pose
Kit.PORTRAIT_FOV = Portrait.FOV
Kit.characterLod = Character.lod -- one-part stand-in beyond 150 studs (G4), same Root height as the rig
Kit.prop = Props.prop
Kit.setAssetSource = Props.setAssetSource
Kit.regionMarkers = Props.regionMarkers
Kit.slotMarker = Props.slotMarker -- G13.5 build slot ground marker (WorldService)
Kit._hueStyle = Parts.hueStyle

local shade = Parts.shade

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

return Kit
