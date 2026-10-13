--!strict
--[[
	UI/SlotFit — which structures the plot picker offers on a build slot (CONTRACTS G13.5: slots
	are sized "S", "M" or "L"). The server stays the judge (`Build.PlaceSlot` refuses a misfit with
	its reason); this only decides what the picker lists.

	Rule (FORGE-05 review M2 on PR #34): a type fits a slot when its biggest footprint over all its
	levels (`Kit.footprint`, `Costs.maxLevel`) fits the slot's width and depth from FORGE-02's world
	Layout (`slotSizes`: S 24×20, M 36×30, L 46×40 studs; X across the slot's front, Y its depth —
	a building takes the slot's yaw, so it is not turned to fit). With the D-030 footprints:
	S house, lumber camp, quarry, storehouse, watchtower; M also barracks; L also farm.
	When a `Build.Slots` record carries `fits: { BuildingType }` (proposed additive field), that list
	wins over the rule.

		SlotFit.TYPES                          plot-buildable types in VS-1, menu order
		SlotFit.SIZES                          world Layout slotSizes { S, M, L: Vector2 }
		SlotFit.footprint(type) -> Vector2?    largest X and largest Y over its levels
		SlotFit.sizeOf(type) -> "S" | "M" | "L" | nil   the smallest slot it fits
		SlotFit.fits(slot, type) -> boolean    slot = { size, fits? }
		SlotFit.typesFor(slot) -> { string }   TYPES that fit, in order
		SlotFit.NAMES[size] -> "Small" | "Medium" | "Large"
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

local SlotFit = {}

-- Walls and gates are lines, not plots (VS-2 defence): they keep the free-placement build menu.
SlotFit.TYPES = table.freeze({ "house", "farm", "lumbercamp", "quarry", "storehouse", "barracks", "watchtower" })
SlotFit.NAMES = table.freeze({ S = "Small", M = "Medium", L = "Large" })
SlotFit.SIZES = WorldLayout.slotSizes
local ORDER = { "S", "M", "L" }

function SlotFit.footprint(buildingType: string): Vector2?
	local levels = math.max(1, Costs.maxLevel(buildingType))
	local x, y = 0, 0
	for level = 1, levels do
		local ok, size = pcall(Kit.footprint, buildingType, level)
		if not ok or typeof(size) ~= "Vector2" then
			return nil
		end
		x, y = math.max(x, size.X), math.max(y, size.Y)
	end
	return Vector2.new(x, y)
end

local function fitsSize(size: string, buildingType: string): boolean
	local slot = SlotFit.SIZES[size]
	local footprint = SlotFit.footprint(buildingType)
	return slot ~= nil and footprint ~= nil and footprint.X <= slot.X and footprint.Y <= slot.Y
end

function SlotFit.sizeOf(buildingType: string): string?
	for _, size in ORDER do
		if fitsSize(size, buildingType) then
			return size
		end
	end
	return nil
end

function SlotFit.fits(slot: any, buildingType: string): boolean
	if type(slot) ~= "table" then
		return false
	end
	if type(slot.fits) == "table" then
		return table.find(slot.fits, buildingType) ~= nil
	end
	return type(slot.size) == "string" and fitsSize(slot.size, buildingType)
end

function SlotFit.typesFor(slot: any): { string }
	local out = {}
	for _, buildingType in SlotFit.TYPES do
		if SlotFit.fits(slot, buildingType) then
			table.insert(out, buildingType)
		end
	end
	return out
end

return table.freeze(SlotFit)
