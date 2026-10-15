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
	The fit check is FORGE-01's shared Build/Fit (CONTRACTS G13.5: the server's Build.PlaceSlot calls
	it too), and refusals use the server's codes (#89: unknown_slot, slot_occupied, does_not_fit), so a
	client that offers a misfit gets "does_not_fit" back. Costs from config Costs; refusals use the
	reason vocabulary of production/handoffs/2026-10-12-forge-03-to-forge-01-build-ui.md.

	Turning (CONTRACTS G13.5 v0.4-g9h), until FORGE-01's server lands:
		KingdomWorld.new({ remotes = SlotDoubles.TURN_REMOTES, services = { SlotDoubles.turnService } })
	declares `Build.PlaceSlot(slotId, type, turn?)`, records the turn (calls[i].args[3]) and refuses a
	turn whose turned footprint does not fit (does_not_fit) with SlotDoubles.fitsTurned, the contract's
	rule: odd turns swap the footprint's axes. It also adds "crimson_slot5", a medium plot with a real
	world/Layout id, so the picker's ghost has a place in the world. SlotDoubles.fitsTurned stands in
	for FORGE-01's `Fit.fits(type, size, turn)` through UI/Turns.useSeam.
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
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

SlotDoubles.TURN_REMOTES = {
	Build = {
		SlotDoubles.REMOTES.Build[1],
		SlotDoubles.REMOTES.Build[2],
		{
			name = "Build.PlaceSlot",
			kind = "function",
			args = { V.string(1, 32), V.enum(TYPES), V.optional(V.integer(0, 3)) },
			rate = { burst = 3, perSecond = 1 },
		},
	},
}

-- The v0.4-g9h fit rule: the footprint at its largest level, axes swapped for an odd turn.
function SlotDoubles.fitsTurned(buildingType: string, size: string, turn: number?): boolean
	local slot = WorldLayout.slotSizes[size]
	local footprint = Fit.largestFootprint(buildingType)
	if typeof(slot) ~= "Vector2" or footprint == nil or not Fit.fits(buildingType, size) then
		return false
	end
	if (turn or 0) % 2 == 1 then
		return footprint.Y <= slot.X and footprint.X <= slot.Y
	end
	return true
end

-- Whether a type fits a slot size, as the server sees it: the shared rule (G13.5), as PlaceSlot calls it.
function SlotDoubles.fits(size: string, buildingType: string): boolean
	return Fit.fits(buildingType, size)
end

function SlotDoubles.turnService(world)
	return SlotDoubles.service(world, { turns = true })
end

function SlotDoubles.service(world, opts: { turns: boolean? }?)
	local turns = opts ~= nil and opts.turns == true
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
			if turns then
				svc.slots.crimson_slot5 =
					{ id = "crimson_slot5", kingdom = "crimson", size = "M", center = Vector3.new(-160, 0, 160) }
			end
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
				remotes:handle("Build.PlaceSlot", function(player, slotId, buildingType, turn)
					table.insert(world.calls, { name = "PlaceSlot", args = { slotId, buildingType, turn } })
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
					if turns and not SlotDoubles.fitsTurned(buildingType, slot.size, turn) then
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
