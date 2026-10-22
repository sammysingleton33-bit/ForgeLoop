--[[
	GateDoubles — FORGE-01's Build.PlaceGate (FL-0126 part 2 slice 2, #306; handoff 2026-10-22-forge-01-to-all-place-line
	"Slice 2") for FL-0129c slice 2's specs and scenes. Written from the handoff, not from UI/GatePick.

		GateDoubles.REMOTES    { Build = { Build.PlaceGate(wallId: integer) } }
		                       (pass as KingdomWorld.new({ remotes = GateDoubles.REMOTES, services = { GateDoubles.service } }))
		GateDoubles.service    (world) -> server Def "GateDouble" (needs KingdomWorld's BuildingService):
			svc.calls          { wallId } every Build.PlaceGate that reached the server
			svc.answer         nil = the rules below; { nil, reason } = refuse with that reason; "drop" = no answer
			Rules: the building exists and stands (not_found), is the player's kingdom's (not_owner), is a wall
			(not_a_wall); the kingdom has no gate yet (limit_reached); balance + floor(wall price / 2) covers the gate's
			level-1 price per resource (cannot_afford). Then the refund is paid, the price spent, the wall destroyed and
			a gate site (state "planned") added where it stood, facing as it did; both pushed; answers the gate's id.
			The gate's ground (blocked / out_of_territory) is not modelled: use svc.answer for those.
		GateDoubles.wall(world, position, yaw?) -> id
			a level-1 wall piece of the player's kingdom at `position`, turned `yaw` radians (its long side along the
			local X axis, as Simulation:placeLine lays them), with the G2 `cframe` the real snapshot carries; pushed.
]]

local BuildingsConfig = require("@game/ReplicatedStorage/Forge/Config/Buildings")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local GateDoubles = {}

GateDoubles.REMOTES = {
	Build = {
		{
			name = "Build.PlaceGate",
			kind = "function",
			args = { Validate.integer(1, 1000000) },
			rate = { burst = 2, perSecond = 1 },
		},
	},
}

local function place(build, kingdom, buildingType, position, yaw, state, level)
	local id = build:add(kingdom, buildingType, level, state, position)
	build.buildings[id].cframe = CFrame.new(position.X, 0, position.Z) * CFrame.Angles(0, yaw or 0, 0)
	build:push(id)
	return id
end

function GateDoubles.wall(world, position: Vector3, yaw: number?): number
	return place(world.build, world.kingdomId, "wall", position, yaw, "complete", 1)
end

function GateDoubles.service(_world)
	return {
		name = "GateDouble",
		dependencies = { "RemoteService", "BuildingService", "TreasuryService", "KingdomService" },
		new = function(_env, registry)
			local remotes = registry:get("RemoteService")
			local build = registry:get("BuildingService")
			local treasury = registry:get("TreasuryService")
			local kingdoms = registry:get("KingdomService")
			local svc = { calls = {}, answer = nil }
			function svc:start()
				remotes:handle("Build.PlaceGate", function(player, wallId)
					table.insert(self.calls, wallId)
					if self.answer == "drop" then
						return nil
					elseif type(self.answer) == "table" then
						return self.answer[1], self.answer[2]
					end
					local kingdom = kingdoms:getKingdomOf(player)
					local wall = build.buildings[wallId]
					if kingdom == nil then
						return nil, "not_in_match"
					elseif wall == nil or wall.state == "destroyed" then
						return nil, "not_found"
					elseif wall.kingdom ~= kingdom then
						return nil, "not_owner"
					elseif wall.type ~= "wall" then
						return nil, "not_a_wall"
					end
					for _, b in build.buildings do
						if b.kingdom == kingdom and b.type == "gate" and b.state ~= "destroyed" then
							return nil, "limit_reached"
						end
					end
					local price = Costs.building("gate", 1).cost
					local refund = {}
					for res, amount in Costs.building("wall", 1).cost do
						refund[res] = math.floor(amount * (BuildingsConfig.cancelRefund or 0.5))
					end
					local have = treasury:get(kingdom)
					for res, amount in price do
						if (have[res] or 0) + (refund[res] or 0) < amount then
							return nil, "cannot_afford"
						end
					end
					for res, amount in refund do
						if amount > 0 then
							treasury:deposit(kingdom, res, amount, `refund:gate:{wallId}:{res}`, "refund")
						end
					end
					assert(
						treasury:spend(kingdom, price, `gate:{wallId}`, "construction"),
						"gate price after the check"
					)
					wall.state = "destroyed"
					build:push(wallId)
					local look = wall.cframe.LookVector
					local position = build.positions[wallId]
					return place(build, kingdom, "gate", position, math.atan2(-look.X, -look.Z), "planned", 1)
				end)
			end
			return svc
		end,
	}
end

return GateDoubles
