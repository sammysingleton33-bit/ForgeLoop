--!strict
--[[
	Army/Remotes — remotes of the "Army" area (CONTRACTS G1/G8). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Army.<Action>.

	Client -> server (validated, rate-limited per player)
		Army.Recruit(barracksId: integer, unitType: "soldier", count: integer(1,10)) -> (boolean, reason?)
		                                 trains at that barracks; charged Costs.unit × count through the
		                                 treasury; the soldiers appear at the barracks' Rally when trained
		Army.Command(unitIds: { integer } (≤ 50), kind: "move" | "attack" | "capture" | "guard",
		             targetPos: Vector3?, targetId: string(1,32)?)        event, no answer
		                                 unitIds = {} means every idle soldier of the caller's kingdom (the
		                                 VS-1 Send-to-capture button is ({}, "capture") with no targetId);
		                                 targetPos for move and guard, inside the map (sim.bounds);
		                                 targetId for attack (KingdomId, "building:<id>" or "entity:<id>")
		                                 and, optionally, capture: an objective id, or none = the objective
		                                 nearest the soldiers that the kingdom does not own (if it owns them
		                                 all, nothing changes). An event: refusals are not sent back
		Army.GetObjectives() -> ObjectiveService:list()
	Server -> client
		Army.Objectives({ { id, kind = "capture", position: Vector3, radius, owner: KingdomId?,
		                    progress: { [KingdomId]: number } } })   every objective, to every player,
		                                 when an owner or progress changes, at most 2 per second;
		                                 progress 0..1 rounded to 0.01
	Army.Recruit reasons: not_in_match, match_not_active, kingdom_eliminated, not_found, not_owner,
	not_barracks, barracks_not_ready, recruit_cap (no free bunk: soldiers sleep in the barracks, never in
	house beds, D-041; population_cap is no longer sent), cannot_afford (and, unreachable for
	"soldier" through this remote's validation: requires_barracks_level, invalid_args, unknown_unit). Army.Command
	refusals (Sim/Military UnitOrder: no_units, no_objective, out_of_bounds, unknown_objective,
	unknown_target, unknown_kingdom, not_at_war, ...) stay on the server.
	Handoff: production/handoffs/2026-10-13-forge-01-to-forge-03-army-refusal-codes.md.
	Implemented by MilitaryService and ObjectiveService.
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")

local UNIT_TYPES = { "soldier" } -- G8 enum{"soldier"}; archer, knight and ram are VS-2
local ORDER_KINDS = { "move", "attack", "capture", "guard" }
local MAX_UNITS = 50
local MAX_ENTITY_ID = 65535 -- G2 EntityId (u16 on the wire)

return {
	{
		name = "Army.Recruit",
		kind = "function",
		args = { Validate.integer(1, 1000000), Validate.enum(UNIT_TYPES), Validate.integer(1, 10) },
		rate = { burst = 4, perSecond = 2 },
	},
	{
		name = "Army.Command",
		kind = "event",
		args = {
			Validate.array(Validate.integer(1, MAX_ENTITY_ID), MAX_UNITS),
			Validate.enum(ORDER_KINDS),
			Validate.optional(Validate.vector3(4000)),
			Validate.optional(Validate.string(1, 32)),
		},
		rate = { burst = 6, perSecond = 3 },
	},
	{ name = "Army.GetObjectives", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Army.Objectives", kind = "serverEvent" },
}
