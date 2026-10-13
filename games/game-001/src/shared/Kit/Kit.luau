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
	Emblems (D-033, D-039; colour-vision finding 3): the same hue map picks the kingdom emblem
	(crimson crown, azure star, emerald oak leaf, gold sun; neutral none), so emblem and silhouette
	always agree. Every banner, flag, pennant, shield, prop banner and slot sign carries it, and the
	keep carries two large aerial plaques (roof, facing up; donjon back). Emblem parts carry
	KitEmblem = "crown" | "star" | "oak" | "sun" and KitEmblemSlot; the part they sit on (the field)
	carries KitEmblemSlot, KitEmblemCF (anchor relative to the field), KitEmblemSize, KitEmblemDetail.

	API (G10):
		Kit.build(type, level, stage, kingdomColor, variant?) -> Model -- Door, WorkSpot1..n, DropOff, Rally; keep: Seat "Throne"
		Kit.footprint(type, level) -> Vector2
		Kit.character(kind, job, kingdomColor, look?) -> Model  -- ≤ 9 parts (Hair welded to the Head, D-032), Motor6Ds
		                                                        -- named after the moving part (Sim/Pose.JOINTS);
		                                                        -- look: CitizenLook (G13.2), omitted = DEFAULT_LOOK
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
	Additive (FORGE-02 area): Kit.setAssetSource(folder) (WorldService passes ReplicatedStorage.Forge.Assets),
		Kit.BUILDING_TYPES, Kit.partCount(model).
	Characters (FORGE-02): Kit.characterLod(kind, kingdomColor), Kit.CHARACTER_ROOT_HEIGHT, Kit.LOOK_RANGES,
		Kit.LOOK_PALETTES, Kit.DEFAULT_LOOK, Kit.normalizeLook(look), Kit.lookKey(look).
]]

local Buildings = require("./Buildings")
local Character = require("./Character")
local Parts = require("./Parts")
local Pieces = require("./Pieces")
local Props = require("./Props")

local Kit = {}

export type BuildingType = string -- Kingdom/Types BuildingType (kept local so Kit has no cross-module require)
export type Stage = number | string

Kit.NEUTRAL_COLOR = Color3.fromRGB(208, 200, 184)
Kit.VERSION = "0.4.0" -- 0.4: kingdom emblems (D-039) on every banner, flag, pennant and shield + aerial plaques
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

Kit.footprint = Buildings.footprint
Kit.build = Buildings.build
Kit.character = Character.character
Kit.regalia = Character.regalia
Kit.characterLod = Character.lod -- one-part stand-in beyond 150 studs (G4), same Root height as the rig
Kit.prop = Props.prop
Kit.setAssetSource = Props.setAssetSource
Kit.regionMarkers = Props.regionMarkers
Kit.slotMarker = Props.slotMarker -- G13.5 build slot ground marker (WorldService)
Kit._hueStyle = Parts.hueStyle
Kit.EMBLEM_KINDS = table.freeze(table.clone(Parts.EMBLEM_KINDS)) -- hue style -> emblem kind (D-039)
Kit.emblemKind = Parts.emblemKind -- (color) -> "crown" | "star" | "oak" | "sun" | nil (neutral)

local shade = Parts.shade

-- ------------------------------------------------------------------ recolouring

-- Re-forms every emblem slot whose kind differs from the new colour's: the old parts go, the new kind is
-- built on the same anchor (the field part's KitEmblemCF, so it follows wherever the model was moved).
local function reformEmblems(model: Model, color: Color3)
	local kind = Parts.emblemKind(color)
	local fields: { [number]: BasePart } = {}
	local marks: { [number]: { BasePart } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local slot = d:GetAttribute("KitEmblemSlot")
			if type(slot) == "number" then
				if d:GetAttribute("KitEmblem") ~= nil then
					marks[slot] = marks[slot] or {}
					table.insert(marks[slot], d)
				elseif d:GetAttribute("KitEmblemCF") ~= nil then
					fields[slot] = d
				end
			end
		end
	end
	for slot, field in fields do
		local old = marks[slot]
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
