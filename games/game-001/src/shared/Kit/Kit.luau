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
		Kit.build(type, level, stage, kingdomColor) -> Model   -- attachments Door, WorkSpot1..n, DropOff, Rally
		Kit.footprint(type, level) -> Vector2
		Kit.character(kind, job, kingdomColor) -> Model         -- ≤ 8 parts, Motor6Ds named after the moving part
		Kit.regalia(kingdomColor) -> { Accessory }              -- crown + cape
		Kit.prop(assetId) -> Model                              -- Forge.Assets mesh if registered, else stand-in
		Kit.regionMarkers(polygon, kingdomColor) -> Model
		Kit.slotMarker(size: Vector2, kingdomColor) -> Model   -- G13.5 build slot marker (Root is the query target)
		Kit.NEUTRAL_COLOR, Kit.setKingdomColor(model, color)
	Additive (FORGE-02 area): Kit.setAssetSource(folder) (WorldService passes ReplicatedStorage.Forge.Assets),
		Kit.BUILDING_TYPES, Kit.partCount(model).
]]

local Buildings = require("./Buildings")
local Character = require("./Character")
local Parts = require("./Parts")
local Props = require("./Props")

local Kit = {}

export type BuildingType = string -- Kingdom/Types BuildingType (kept local so Kit has no cross-module require)
export type Stage = number | string

Kit.NEUTRAL_COLOR = Color3.fromRGB(208, 200, 184)
Kit.VERSION = "0.2.0"
Kit.BUILDING_TYPES =
	{ "keep", "house", "farm", "storehouse", "lumbercamp", "quarry", "barracks", "watchtower", "wall", "gate" }
Kit.CHARACTER_ROOT_HEIGHT = 3.2 -- Root part centre above the feet (PivotOffset puts the pivot at the feet)

Kit.footprint = Buildings.footprint
Kit.build = Buildings.build
Kit.character = Character.character
Kit.regalia = Character.regalia
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
