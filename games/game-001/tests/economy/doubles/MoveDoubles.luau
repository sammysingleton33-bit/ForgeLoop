--[[
	MoveDoubles — FORGE-01's base editing server (CONTRACTS G13.9 v0.4-g9j, FL-0119 #140) as a test double
	for FL-0120: the declarations of `Build.CanMove`, `Build.Move` and `Build.MoveToSlot` as FORGE-01's
	handoff gives them (2026-10-15-forge-01-to-forge-03-04-05-base-editing-server.md), and a server double
	on top of KingdomWorld's BuildingService double and SlotDoubles' SlotService.

		local world = KingdomWorld.new({
			remotes = MoveDoubles.remotes(SlotDoubles.TURN_REMOTES),
			services = { SlotDoubles.turnService, MoveDoubles.service },
			clientDefinitions = { ... },
		})
		world.moveRefuse = "alarm"   -- every CanMove / Move / MoveToSlot answers this code (a test hook)

	Rules, in the server's order: not_found (no such building, or destroyed), not_owner, not_movable (the
	keep), the hook, cooldown (10 s per building after an accepted move), then for a free move
	out_of_territory (|x| or |z| > 200, as the BuildingService double) and blocked (another building
	within 20 studs); for a slot move unknown_slot, not_on_plot (wall, gate), slot_occupied (another
	building's plot) and does_not_fit (Fit.fits(type, size, turn)). The same spot and facing answers true
	and changes nothing. An accepted move sets the building's position and `cframe` (the G2 view field),
	frees its old plot and takes the new one, and re-sends the building (Build.Buildings).
	Calls are recorded in world.calls as CanMove / Move / MoveToSlot with their arguments.
]]

local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local V = require("@game/ReplicatedStorage/Forge/Core/Validate")

local MoveDoubles = {}

MoveDoubles.COOLDOWN = 10

local ID = V.integer(1, 1000000)
MoveDoubles.DECLARATIONS = {
	{
		name = "Build.CanMove",
		kind = "function",
		args = { ID, V.vector3(4000), V.integer(0, 3) },
		rate = { burst = 10, perSecond = 10 },
	},
	{ name = "Build.Move", kind = "function", args = { ID, V.vector3(4000), V.integer(0, 3) }, rate = { burst = 4, perSecond = 2 } },
	{
		name = "Build.MoveToSlot",
		kind = "function",
		args = { ID, V.string(1, 32), V.optional(V.integer(0, 3)) },
		rate = { burst = 4, perSecond = 2 },
	},
}

-- `base` (e.g. SlotDoubles.TURN_REMOTES) with the move remotes appended to its Build area.
function MoveDoubles.remotes(base: { [string]: any }?): { [string]: any }
	local out = {}
	for area, decls in base or {} do
		out[area] = table.clone(decls)
	end
	out.Build = out.Build or {}
	for _, decl in MoveDoubles.DECLARATIONS do
		table.insert(out.Build, decl)
	end
	return out
end

-- The view's cframe for a position and a yaw (radians).
function MoveDoubles.cframe(position: Vector3, yaw: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, yaw, 0)
end

function MoveDoubles.service(world)
	return {
		name = "MoveService",
		dependencies = { "RemoteService", "KingdomService", "BuildingService" },
		new = function(_, registry)
			local remotes = registry:get("RemoteService")
			local kingdoms = registry:get("KingdomService")
			local build = registry:get("BuildingService")
			local svc = { movedAt = {} :: { [number]: number } }

			local function slots()
				local slotService = registry:find("SlotService")
				return if slotService then slotService else nil
			end

			-- The checks every move shares; nil when they pass.
			local function common(player, buildingId): (string?, any)
				local kingdom = kingdoms:getKingdomOf(player)
				if kingdom == nil then
					return "not_in_match", nil
				end
				local b = build.buildings[buildingId]
				if b == nil or b.state == "destroyed" then
					return "not_found", nil
				elseif b.kingdom ~= kingdom then
					return "not_owner", nil
				elseif b.type == "keep" then
					return "not_movable", nil
				elseif world.moveRefuse then
					return world.moveRefuse, nil
				end
				local last = svc.movedAt[buildingId]
				if last and world.env.clock() - last < MoveDoubles.COOLDOWN then
					return "cooldown", nil
				end
				return nil, b
			end

			local function freeCheck(buildingId, position): string?
				if math.abs(position.X) > 200 or math.abs(position.Z) > 200 then
					return "out_of_territory"
				end
				for id, other in build.positions do
					if id ~= buildingId and (other - position).Magnitude < 20 then
						return "blocked"
					end
				end
				return nil
			end

			local function release(buildingId)
				local service = slots()
				if service == nil then
					return
				end
				for _, slot in service.slots do
					if slot.occupiedBy == buildingId then
						service:occupy(slot.id, nil)
					end
				end
			end

			local function settle(b, position, yaw)
				build.positions[b.id] = position
				b.cframe = MoveDoubles.cframe(position, yaw)
				svc.movedAt[b.id] = world.env.clock()
				build:push(b.id)
			end

			local function latency()
				if world.latency > 0 then
					world.env.wait(world.latency)
				end
			end

			function svc:start()
				remotes:handle("Build.CanMove", function(player, buildingId, position, rot)
					table.insert(world.calls, { name = "CanMove", args = { buildingId, position, rot } })
					latency()
					local reason = common(player, buildingId)
					reason = reason or freeCheck(buildingId, position)
					return reason == nil, reason
				end)
				remotes:handle("Build.Move", function(player, buildingId, position, rot)
					table.insert(world.calls, { name = "Move", args = { buildingId, position, rot } })
					latency()
					local reason, b = common(player, buildingId)
					reason = reason or freeCheck(buildingId, position)
					if reason then
						return false, reason
					end
					local same = build.positions[buildingId] == position
						and b.cframe ~= nil
						and (b.cframe.LookVector - CFrame.Angles(0, rot * math.pi / 2, 0).LookVector).Magnitude < 1e-4
					if same then
						return true -- the same spot and facing: nothing changes, no cooldown
					end
					release(buildingId)
					settle(b, position, rot * math.pi / 2)
					return true
				end)
				remotes:handle("Build.MoveToSlot", function(player, buildingId, slotId, turn)
					table.insert(world.calls, { name = "MoveToSlot", args = { buildingId, slotId, turn } })
					latency()
					local reason, b = common(player, buildingId)
					if reason then
						return false, reason
					end
					local service = slots()
					local slot = service and service.slots[slotId]
					if slot == nil or slot.kingdom ~= b.kingdom then
						return false, "unknown_slot"
					elseif b.type == "wall" or b.type == "gate" then
						return false, "not_on_plot"
					elseif slot.occupiedBy ~= nil and slot.occupiedBy ~= buildingId then
						return false, "slot_occupied"
					elseif not Fit.fits(b.type, slot.size, turn) then
						return false, "does_not_fit"
					end
					release(buildingId)
					settle(b, slot.center, (turn or 0) * math.pi / 2)
					service:occupy(slotId, buildingId)
					return true
				end)
			end
			return svc
		end,
	}
end

return MoveDoubles
