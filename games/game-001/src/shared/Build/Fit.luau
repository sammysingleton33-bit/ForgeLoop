--!strict
--[[
	Build/Fit — which building types fit which build slot (CONTRACTS G13.5, FORGE-05 finding M2).
	Owner: FORGE-01. The one implementation of the rule: Build.PlaceSlot on the server and FORGE-03's
	plot picker both call it; nobody re-implements it. Pure; usable on server and client.

	API
		Fit.fits(buildingType, size, turn?): boolean   -- true when Kit.footprint(type, Costs.maxLevel(type))
		                                           fits inside Layout.slotSizes[size] on both axes
		                                           (slot-local X = width across the front, Y = depth);
		                                           turn = quarter turns from the slot's street facing
		                                           (nil = 0; yaw = slot rot + turn x 90 degrees, as Build.Place's
		                                           rot): an odd turn swaps the footprint's axes
		Fit.turns(buildingType, size): { number }   -- the turns 0..3 at which it fits, ascending (empty when
		                                           it does not fit at all): what a Turn control on a build
		                                           slot offers (CONTRACTS v0.4-g9h)
		Fit.typesFor(size): { BuildingType }    -- every type that fits, in Types.BUILDING_TYPES order
		                                           (a fresh table)
		Fit.SIZES: { "S", "M", "L" }
		Fit.largestFootprint(buildingType): Vector2?   -- Kit.footprint(type, Costs.maxLevel(type)); nil
		                                           without a Kit footprint or a Costs level (Sim/Catalog
		                                           places buildings with it, G6)
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

function Fit.largestFootprint(buildingType: string): Vector2?
	local maxLevel = Costs.maxLevel(buildingType)
	if maxLevel < 1 then
		return nil
	end
	local ok, size = pcall(Kit.footprint, buildingType, maxLevel)
	return if ok and typeof(size) == "Vector2" then size else nil
end

function Fit.fits(buildingType: string, size: string, turn: number?): boolean
	local slot = WorldLayout.slotSizes[size]
	if typeof(slot) ~= "Vector2" then
		return false
	end
	local footprint = Fit.largestFootprint(buildingType)
	if footprint == nil then
		return false
	end
	local quarter = math.floor(turn or 0) % 4
	local width, depth = footprint.X, footprint.Y
	if quarter % 2 == 1 then
		width, depth = depth, width -- turned a quarter: the long side runs across the slot
	end
	return width <= slot.X and depth <= slot.Y
end

function Fit.turns(buildingType: string, size: string): { number }
	local out = {}
	for turn = 0, 3 do
		if Fit.fits(buildingType, size, turn) then
			table.insert(out, turn)
		end
	end
	return out
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
