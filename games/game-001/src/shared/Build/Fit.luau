--!strict
--[[
	Build/Fit — which building types fit which build slot (CONTRACTS G13.5, FORGE-05 finding M2).
	Owner: FORGE-01. The one implementation of the rule: Build.PlaceSlot on the server and FORGE-03's
	plot picker both call it; nobody re-implements it. Pure; usable on server and client.

	API
		Fit.fits(buildingType, size): boolean   -- true when Kit.footprint(type, Costs.maxLevel(type))
		                                           fits inside Layout.slotSizes[size] on both axes
		                                           (slot-local X = width across the front, Y = depth)
		Fit.typesFor(size): { BuildingType }    -- every type that fits, in Types.BUILDING_TYPES order
		                                           (a fresh table)
		Fit.SIZES: { "S", "M", "L" }
	The rule is purely physical: slots never grow, so a type must fit at its largest level. Which of
	the fitting types a menu offers (placeable, unlocked, phase) is the caller's choice. Unknown types,
	types without a Kit footprint or a Costs level, and unknown sizes fit nothing.
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")
local Kit = require("../Kit/Kit")
local Types = require("../Kingdom/Types")

local Fit = {}

Fit.SIZES = table.freeze({ "S", "M", "L" })

local function largestFootprint(buildingType: string): Vector2?
	local maxLevel = Costs.maxLevel(buildingType)
	if maxLevel < 1 then
		return nil
	end
	local ok, size = pcall(Kit.footprint, buildingType, maxLevel)
	return if ok and typeof(size) == "Vector2" then size else nil
end

function Fit.fits(buildingType: string, size: string): boolean
	local slot = WorldLayout.slotSizes[size]
	if typeof(slot) ~= "Vector2" then
		return false
	end
	local footprint = largestFootprint(buildingType)
	return footprint ~= nil and footprint.X <= slot.X and footprint.Y <= slot.Y
end

function Fit.typesFor(size: string): { string }
	local out = {}
	for _, buildingType in Types.BUILDING_TYPES do
		if Fit.fits(buildingType, size) then
			table.insert(out, buildingType)
		end
	end
	return out
end

return table.freeze(Fit)
