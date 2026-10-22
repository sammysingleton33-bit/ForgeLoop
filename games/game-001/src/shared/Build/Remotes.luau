--!strict
--[[
	Build/Remotes — remotes of the "Build" area (CONTRACTS G1/G6/G8). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Build.<Action>.

	Client -> server (validated, rate-limited per player; no CFrame crosses the wire)
		Build.CanPlace(type, position: Vector3, rot: integer(0,3)) -> (boolean, reason?)   ghost tint
		Build.Place(type, position, rot) -> (buildingId?, reason?)    charges through the treasury; placedBy
		Build.PlaceGate(wallId) -> (gateId?, reason?)   FL-0126 part 2: one of the player's kingdom's wall pieces becomes a gate, in
		                                 place and facing the same way: the wall goes (half its level-1 price comes back, as on a cancelled
		                                 site), the gate is a new site charged its level-1 price. One gate per kingdom (limit_reached). Reasons:
		                                 not_found, not_owner, not_a_wall, limit_reached, busy (the wall is being upgraded), under_attack,
		                                 blocked / out_of_territory (the gate is thicker than the wall), cannot_afford, match_not_active.
		Build.PlaceLine("wall", from: Vector3, to: Vector3) -> ({ buildingId }?, reason?)   FL-0126 part 2: a straight wall of
		                                 Kit segments from `from` to `to` (y ignored): both ends snap to the 4-stud grid, the length is
		                                 split into round(length / 32) pieces (at least one, at most 12), laid end to end and facing the
		                                 line. All or nothing: every segment passes the Place rules (blocked, out_of_territory,
		                                 out_of_bounds, ...) and the kingdom affords all of them, or nothing is built or charged.
		                                 Extra reasons: not_a_line_piece (only "wall"), too_short (under one grid step), too_long.
		Build.Upgrade(buildingId) -> (boolean, reason?)
		Build.GetBuildings() -> { Building }                           every standing building (G2 views)
		Build.PlaceSlot(slotId: string(1,32), type, turn: integer(0,3)?) -> (buildingId?, reason?)   G13.5:
		                                 builds on one of the player's kingdom's build slots, facing its street
		                                 (the slot's rot), turned `turn` quarter turns from that: yaw = slot rot +
		                                 turn x 90 degrees, in the Build.Place `rot` convention (nil = 0, today's
		                                 behaviour; CONTRACTS v0.4-g9h). The type must fit the slot at that turn
		                                 (Build/Fit.fits(type, size, turn); Fit.turns lists the turns that fit),
		                                 else does_not_fit; then the Build.Place rules
		Build.GetSlots() -> { { id, size, occupiedBy: number? } }      the asker's kingdom's slots (G13.5)
		Build.CanMove(buildingId: integer(1,1e6), position: Vector3, rot: integer(0,3)) -> (boolean, reason?)
		                                 G13.9 ghost tint: would Build.Move succeed now (nothing changes)
		Build.Move(buildingId, position, rot) -> (ok, reason?)   one of the player's kingdom's buildings (not the
		                                 keep) to free ground, facing rot x 90 degrees (absolute, as Build.Place):
		                                 atomic and in place (same id, level, hp, progress, queue, workers), free;
		                                 frees its slot. A move to the same spot and facing is a no-op (true)
		Build.MoveToSlot(buildingId, slotId: string(1,32), turn: integer(0,3)?) -> (ok, reason?)   onto a free
		                                 build slot that fits, turned `turn` quarter turns from its facing (as
		                                 Build.PlaceSlot), taking the slot in the same command; may re-seat on its
		                                 own slot. Walls and gates never go on a slot (not_on_plot)
	Server -> client
		Build.Buildings({ Building })    the buildings that changed (placed, progress, level, damage,
		                                 destroyed = state "destroyed"), to every player, at most 2 per second
		Build.Slots({ { id, size, occupiedBy: number? } })   a kingdom's slots, to its members when one is
		                                 taken or freed (and when a member arrives)
	rot turns the building in 90° steps: yaw = rot × 90° in the CFrame.Angles(0, yaw, 0) convention (Kit
	models face -Z), rebuilt on the server from the integer. Implemented by BuildingService.
	Move reasons (CanMove, Move and MoveToSlot answer with those of Place / PlaceSlot, except that limits, keep
	level and cost are never checked, a move adds no building) and also: not_found, not_movable (the keep),
	alarm (the alarm bell rings), under_attack (the building is targeted, near an at-war unit, damaged or
	burning, or a war was just declared or ended), cooldown (Buildings.moveCooldown since its last move). The
	destination must lie inside the keep's own circle, clear of the no-build areas (fields, plot roads, spawn
	pads) and of soldiers and rulers' characters (blocked). Build.Buildings re-sends a moved building and
	Build.Slots follows its slot. CONTRACTS G13.9 v0.4-g9j.
	Reasons: blocked, out_of_territory, out_of_bounds, cannot_afford, not_placeable, requires_keep_level,
	limit_reached, unknown_building, not_owner, busy, max_level, match_not_active, not_in_match;
	PlaceSlot also unknown_slot (not one of the player's kingdom's slots), not_on_plot (wall and gate never
	stand on a plot, G13.5 v0.4-g9a), slot_occupied (a building placed on the slot, or any of the kingdom's
	standing buildings over it), does_not_fit.
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local Types = require("../Kingdom/Types")

local BUILDING_ID = Validate.integer(1, 1000000)
local PLACEMENT = { Validate.enum(Types.BUILDING_TYPES), Validate.vector3(4000), Validate.integer(0, 3) }

return {
	{ name = "Build.CanPlace", kind = "function", args = PLACEMENT, rate = { burst = 10, perSecond = 10 } },
	{ name = "Build.Place", kind = "function", args = PLACEMENT, rate = { burst = 4, perSecond = 2 } },
	{
		name = "Build.PlaceGate",
		kind = "function",
		args = { BUILDING_ID },
		rate = { burst = 2, perSecond = 1 },
	},
	{
		name = "Build.PlaceLine",
		kind = "function",
		args = { Validate.enum(Types.BUILDING_TYPES), Validate.vector3(4000), Validate.vector3(4000) },
		rate = { burst = 2, perSecond = 1 },
	},
	{
		name = "Build.Upgrade",
		kind = "function",
		args = { Validate.integer(1, 1000000) },
		rate = { burst = 4, perSecond = 2 },
	},
	{ name = "Build.GetBuildings", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Build.Buildings", kind = "serverEvent" },
	{
		name = "Build.PlaceSlot",
		kind = "function",
		args = {
			Validate.string(1, 32),
			Validate.enum(Types.BUILDING_TYPES),
			Validate.optional(Validate.integer(0, 3)),
		},
		rate = { burst = 4, perSecond = 2 },
	},
	{
		name = "Build.CanMove",
		kind = "function",
		args = { BUILDING_ID, Validate.vector3(4000), Validate.integer(0, 3) },
		rate = { burst = 10, perSecond = 10 },
	},
	{
		name = "Build.Move",
		kind = "function",
		args = { BUILDING_ID, Validate.vector3(4000), Validate.integer(0, 3) },
		rate = { burst = 4, perSecond = 2 },
	},
	{
		name = "Build.MoveToSlot",
		kind = "function",
		args = { BUILDING_ID, Validate.string(1, 32), Validate.optional(Validate.integer(0, 3)) },
		rate = { burst = 4, perSecond = 2 },
	},
	{ name = "Build.GetSlots", kind = "function", args = {}, rate = { burst = 3, perSecond = 1 } },
	{ name = "Build.Slots", kind = "serverEvent" },
}
