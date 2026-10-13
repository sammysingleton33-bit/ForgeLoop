--[[
	SlotDoubles — FORGE-01's plot construction (CONTRACTS G13.5) as a test double for FL-0087:
	remote declarations for `Build.Slots`, `Build.GetSlots` and `Build.PlaceSlot`, and a server
	double that answers them on top of KingdomWorld's BuildingService double and the real
	TreasuryService.

		local world = KingdomWorld.new({
			remotes = SlotDoubles.REMOTES,
			services = { SlotDoubles.service },
			clientDefinitions = { ... },
		})
		world.server:get("SlotService"):occupy("m1", buildingId)

	Plots of crimson (the local player's kingdom): m1 M, s1 S, l1 L, m2 M (built on: a house).
	The double's own fit check, written apart from the client's UI/SlotFit: the biggest footprint
	over the type's levels must fit the slot's width and depth from FORGE-02's world Layout
	(`slotSizes`), so a client that offers a misfit gets "does_not_fit" back (the server's codes, #89). Costs from config Costs; refusals use the
	reason vocabulary of production/handoffs/2026-10-12-forge-03-to-forge-01-build-ui.md.
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local V = require("@game/ReplicatedStorage/Forge/Core/Validate")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

local SlotDoubles = {}

local TYPES =
	{ "keep", "house", "farm", "storehouse", "lumbercamp", "quarry", "barracks", "watchtower", "wall", "gate" }

SlotDoubles.REMOTES = {
	Build = {
		{ name = "Build.Slots", kind = "serverEvent" },
		{ name = "Build.GetSlots", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
		{
			name = "Build.PlaceSlot",
			kind = "function",
			args = { V.string(1, 32), V.enum(TYPES) },
			rate = { burst = 3, perSecond = 1 },
		},
	},
}

-- Whether a type fits a slot size, as the double's server sees it.
function SlotDoubles.fits(size: string, buildingType: string): boolean
	local slot = WorldLayout.slotSizes[size]
	if slot == nil then
		return false
	end
	for level = 1, math.max(1, Costs.maxLevel(buildingType)) do
		local ok, footprint = pcall(Kit.footprint, buildingType, level)
		if not ok or typeof(footprint) ~= "Vector2" or footprint.X > slot.X or footprint.Y > slot.Y then
			return false
		end
	end
	return true
end

function SlotDoubles.service(world)
	return {
		name = "SlotService",
		dependencies = { "RemoteService", "TreasuryService", "KingdomService", "BuildingService" },
		new = function(_, registry)
			local remotes = registry:get("RemoteService")
			local treasury = registry:get("TreasuryService")
			local kingdoms = registry:get("KingdomService")
			local build = registry:get("BuildingService")
			local svc = {
				slots = {
					m1 = { id = "m1", kingdom = "crimson", size = "M", center = Vector3.new(60, 0, 60) },
					s1 = { id = "s1", kingdom = "crimson", size = "S", center = Vector3.new(-60, 0, 60) },
					l1 = { id = "l1", kingdom = "crimson", size = "L", center = Vector3.new(60, 0, -60) },
					m2 = { id = "m2", kingdom = "crimson", size = "M", center = Vector3.new(-100, 0, 100) },
				},
			}
			function svc:list(kingdom)
				local out = {}
				for _, slot in self.slots do
					if slot.kingdom == kingdom then
						table.insert(out, { id = slot.id, size = slot.size, occupiedBy = slot.occupiedBy })
					end
				end
				return out
			end
			function svc:publish(kingdom)
				for _, player in world.env.Players:GetPlayers() do
					if kingdoms:getKingdomOf(player) == kingdom then
						remotes:fire("Build.Slots", player, self:list(kingdom))
					end
				end
			end
			function svc:occupy(slotId, buildingId)
				local slot = self.slots[slotId]
				slot.occupiedBy = buildingId
				self:publish(slot.kingdom)
			end
			function svc:start()
				-- m2 holds a house already.
				local house = build:add("crimson", "house", 1, "complete", self.slots.m2.center)
				self.slots.m2.occupiedBy = house
				remotes:handle("Build.GetSlots", function(player)
					local kingdom = kingdoms:getKingdomOf(player)
					return if kingdom then self:list(kingdom) else {}
				end)
				remotes:handle("Build.PlaceSlot", function(player, slotId, buildingType)
					table.insert(world.calls, { name = "PlaceSlot", args = { slotId, buildingType } })
					if world.latency > 0 then
						world.env.wait(world.latency) -- the round trip (KingdomWorld option `latency`)
					end
					local kingdom = kingdoms:getKingdomOf(player)
					local slot = self.slots[slotId]
					if kingdom == nil then
						return nil, "not_in_match"
					elseif slot == nil or slot.kingdom ~= kingdom then
						return nil, "unknown_slot"
					elseif slot.occupiedBy then
						return nil, "slot_occupied"
					end
					if not SlotDoubles.fits(slot.size, buildingType) then
						return nil, "does_not_fit"
					end
					local entry = Costs.building(buildingType, 1)
					if not treasury:spend(kingdom, entry.cost, `slot:{slotId}:{buildingType}`, "construction") then
						return nil, "cannot_afford"
					end
					local id = build:add(kingdom, buildingType, 1, "planned", slot.center)
					build.buildings[id].placedBy = player.UserId
					build:push(id)
					self:occupy(slotId, id)
					return id
				end)
			end
			return svc
		end,
	}
end

return SlotDoubles
