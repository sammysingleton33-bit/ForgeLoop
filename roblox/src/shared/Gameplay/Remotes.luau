--!strict
--[[
	Gameplay/Remotes — every client <-> server remote of the Gameplay area (interfaces §6), aggregated
	by RemoteService into ReplicatedStorage.ForgeRemotes.Gameplay.<Action>.

	Client -> server (all `function`: they return (ok: boolean, errorCode: string?, result: table?)).
	Arguments are validated by RemoteService before the handler runs; the server re-checks meaning
	(ownership, territory, cost) in Gameplay/Kingdom/Commands. Error codes are listed in Commands,
	Military and Diplomacy headers; the host adds "not_in_match" and "too_late" (ChooseKingdom).
		Gameplay.PlaceBuilding(kind, x, z)            kind = building id ("House", "Farm", ...)
		Gameplay.UpgradeBuilding(buildingId)
		Gameplay.CancelConstruction(buildingId)       refunds half the cost
		Gameplay.SetJobQuota(occupation, count)       desired citizens per occupation (0..200)
		Gameplay.SetPriority(resource, weight)        0 = never gather, 1 = normal, 3 = urgent
		Gameplay.SetAlarm(on)                         citizens shelter in the keep while on
		Gameplay.Recruit(unit, count)                 1..10 units at a barracks
		Gameplay.ArmyOrder(order, x?, z?)             "Defend" | "Hold" | "Move" (Move needs x, z)
		Gameplay.ArmyAttack(kingdomId)                march on a kingdom you are at war with
		Gameplay.Diplomacy(action, kingdomId)         "DeclareWar" | "ProposePeace" | "AcceptPeace"
		Gameplay.ChooseKingdom(kingdomId)             switch kingdom; only before the match is Active
		Gameplay.GetKingdomState()                    -> { round, kingdomId?, kingdom?, overview } (joiners)
		Gameplay.GetRoundState()                      -> { state, roundId, endsAtServerTime?, aliveCount } (§4)
	Server -> client
		Gameplay.KingdomSnapshot(snapshot)            to a kingdom's rulers, ~2 per second (Kingdom/Snapshot)
		Gameplay.KingdomOverview(overview)            to everyone, every 2 seconds
		Gameplay.KingdomEvent(event)                  notable simulation events ({ name, ... } payloads,
		                                              see Kingdom/Simulation, Military, Diplomacy headers)
		Gameplay.RoundState(state, roundId, endsAtServerTime?, aliveCount)   §4 (aliveCount = kingdoms standing)
		Gameplay.Eliminated({ userId, cause, byUserId?, aliveCount })        §4 (rulers of a fallen kingdom)
		Gameplay.RoundResult(result)                  §4 RoundResult, mode "kingdoms"
]]

local Validate = require("../Core/Validate")
local Catalog = require("./Kingdom/Catalog")

local catalog = Catalog.default()

local function keysOf(order: { string }, exclude: string?): { string }
	local out = {}
	for _, id in order do
		if id ~= exclude then
			table.insert(out, id)
		end
	end
	return out
end

local ID = Validate.string(1, 16)
local COORD = Validate.number(-4096, 4096)
local COMMAND_RATE = { burst = 6, perSecond = 2 }
local SLOW_RATE = { burst = 3, perSecond = 0.5 }

return {
	{
		name = "Gameplay.PlaceBuilding",
		kind = "function",
		args = { Validate.enum(keysOf(catalog.buildingOrder, "Keep")), COORD, COORD },
		rate = COMMAND_RATE,
	},
	{ name = "Gameplay.UpgradeBuilding", kind = "function", args = { ID }, rate = COMMAND_RATE },
	{ name = "Gameplay.CancelConstruction", kind = "function", args = { ID }, rate = COMMAND_RATE },
	{
		name = "Gameplay.SetJobQuota",
		kind = "function",
		args = { Validate.enum(keysOf(catalog.occupationOrder, "Laborer")), Validate.integer(0, 200) },
		rate = { burst = 10, perSecond = 4 },
	},
	{
		name = "Gameplay.SetPriority",
		kind = "function",
		args = { Validate.enum(keysOf(Catalog.RESOURCES)), Validate.integer(0, 3) },
		rate = { burst = 10, perSecond = 4 },
	},
	{ name = "Gameplay.SetAlarm", kind = "function", args = { Validate.boolean() }, rate = SLOW_RATE },
	{
		name = "Gameplay.Recruit",
		kind = "function",
		args = { Validate.enum(keysOf(catalog.unitOrder)), Validate.integer(1, 10) },
		rate = COMMAND_RATE,
	},
	{
		name = "Gameplay.ArmyOrder",
		kind = "function",
		args = { Validate.enum({ "Defend", "Hold", "Move" }), Validate.optional(COORD), Validate.optional(COORD) },
		rate = COMMAND_RATE,
	},
	{ name = "Gameplay.ArmyAttack", kind = "function", args = { ID }, rate = SLOW_RATE },
	{
		name = "Gameplay.Diplomacy",
		kind = "function",
		args = { Validate.enum({ "DeclareWar", "ProposePeace", "AcceptPeace" }), ID },
		rate = SLOW_RATE,
	},
	{ name = "Gameplay.ChooseKingdom", kind = "function", args = { ID }, rate = SLOW_RATE },
	{ name = "Gameplay.GetKingdomState", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Gameplay.GetRoundState", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Gameplay.KingdomSnapshot", kind = "serverEvent" },
	{ name = "Gameplay.KingdomOverview", kind = "serverEvent" },
	{ name = "Gameplay.KingdomEvent", kind = "serverEvent" },
	{ name = "Gameplay.RoundState", kind = "serverEvent" },
	{ name = "Gameplay.Eliminated", kind = "serverEvent" },
	{ name = "Gameplay.RoundResult", kind = "serverEvent" },
}
