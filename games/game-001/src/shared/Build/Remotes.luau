--!strict
--[[
	Build/Remotes — remotes of the "Build" area (CONTRACTS G1/G6/G8). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Build.<Action>.

	Client -> server (validated, rate-limited per player; no CFrame crosses the wire)
		Build.CanPlace(type, position: Vector3, rot: integer(0,3)) -> (boolean, reason?)   ghost tint
		Build.Place(type, position, rot) -> (buildingId?, reason?)    charges through the treasury; placedBy
		Build.Upgrade(buildingId) -> (boolean, reason?)
		Build.GetBuildings() -> { Building }                           every standing building (G2 views)
	Server -> client
		Build.Buildings({ Building })    the buildings that changed (placed, progress, level, damage,
		                                 destroyed = state "destroyed"), to every player, at most 2 per second
	rot turns the building in 90° steps: yaw = rot × 90° in the CFrame.Angles(0, yaw, 0) convention (Kit
	models face -Z), rebuilt on the server from the integer. Implemented by BuildingService.
	Reasons: blocked, out_of_territory, out_of_bounds, cannot_afford, not_placeable, requires_keep_level,
	limit_reached, unknown_building, not_owner, busy, max_level, match_not_active, not_in_match.
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local Types = require("../Kingdom/Types")

local PLACEMENT = { Validate.enum(Types.BUILDING_TYPES), Validate.vector3(4000), Validate.integer(0, 3) }

return {
	{ name = "Build.CanPlace", kind = "function", args = PLACEMENT, rate = { burst = 10, perSecond = 10 } },
	{ name = "Build.Place", kind = "function", args = PLACEMENT, rate = { burst = 4, perSecond = 2 } },
	{
		name = "Build.Upgrade",
		kind = "function",
		args = { Validate.integer(1, 1000000) },
		rate = { burst = 4, perSecond = 2 },
	},
	{ name = "Build.GetBuildings", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Build.Buildings", kind = "serverEvent" },
}
