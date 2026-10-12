--!strict
--[[
	UI/SlotFit — which structures the plot picker offers on a build slot (CONTRACTS G13.5: slots
	are sized "S", "M" or "L"). A PROPOSAL until FORGE-01/FORGE-02 settle it
	(production/handoffs/2026-10-12-forge-03-to-forge-01-plots-ui.md); the server stays the
	judge (`Build.PlaceSlot` refuses a misfit with its reason).

	Rule: a type's size class is the largest side of its biggest footprint over its levels
	(`Kit.footprint`, `Costs.maxLevel`): <= 18 studs "S", <= 26 "M", larger "L". A slot takes its own
	size and every smaller one. With the D-030 footprints: S watchtower; M house, storehouse,
	lumber camp, quarry; L farm, barracks.
	When a `Build.Slots` record carries `fits: { BuildingType }` (proposed additive field), that list
	wins over the rule.

		SlotFit.TYPES                          plot-buildable types in VS-1, menu order
		SlotFit.sizeOf(type) -> "S" | "M" | "L" | nil
		SlotFit.fits(slot, type) -> boolean    slot = { size, fits? }
		SlotFit.typesFor(slot) -> { string }   TYPES that fit, in order
		SlotFit.NAMES[size] -> "Small" | "Medium" | "Large"
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local SlotFit = {}

-- Walls and gates are lines, not plots (VS-2 defence): they keep the free-placement build menu.
SlotFit.TYPES = table.freeze({ "house", "farm", "lumbercamp", "quarry", "storehouse", "barracks", "watchtower" })
SlotFit.NAMES = table.freeze({ S = "Small", M = "Medium", L = "Large" })
SlotFit.LIMITS = table.freeze({ S = 18, M = 26 })

local RANK = { S = 1, M = 2, L = 3 }

function SlotFit.sizeOf(buildingType: string): string?
	local levels = math.max(1, Costs.maxLevel(buildingType))
	local largest = 0
	for level = 1, levels do
		local ok, size = pcall(Kit.footprint, buildingType, level)
		if not ok or typeof(size) ~= "Vector2" then
			return nil
		end
		largest = math.max(largest, size.X, size.Y)
	end
	if largest <= SlotFit.LIMITS.S then
		return "S"
	elseif largest <= SlotFit.LIMITS.M then
		return "M"
	end
	return "L"
end

function SlotFit.fits(slot: any, buildingType: string): boolean
	if type(slot) ~= "table" then
		return false
	end
	if type(slot.fits) == "table" then
		return table.find(slot.fits, buildingType) ~= nil
	end
	local size = SlotFit.sizeOf(buildingType)
	local slotRank = RANK[slot.size]
	return size ~= nil and slotRank ~= nil and RANK[size] <= slotRank
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
