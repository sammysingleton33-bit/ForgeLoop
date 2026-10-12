--!strict
--[[
	Kingdom/Remotes — remotes of the "Kingdom" area (CONTRACTS G1/G3/G8). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Kingdom.<Action>.

	Client -> server (functions return (ok: boolean, errorCode: string?, result: table?) unless noted)
		Kingdom.GetState() -> { phase, endsAtServerTime?, roundId, kingdomId?, kingdom?, overview }
		                                     snapshot for joiners and after a reconnect (no ok/err)
		Kingdom.Choose(kingdomId)            switch kingdom; Lobby only (too_late afterwards)
		Kingdom.Gather(nodeId)               ruler harvests a resource node (G8); the server uses the
		                                     character position it sees, range + cooldown enforced
		Kingdom.SetJobQuota(job, count)      desired citizens per job (G5 requestWorkers); hauler is the pool
		Kingdom.SetPriority(resource, weight) 0 = never gather, 1 = normal, 3 = urgent
		Kingdom.SetAlarm(on)                 citizens shelter in the keep while on
	Server -> client
		Kingdom.Snapshot(snapshot)           to the kingdom's rulers, ~2 per second and right after their
		                                     commands (Sim/Snapshot.kingdom)
		Kingdom.Overview(overview)           to everyone every 2 s (Sim/Snapshot.overview)
		Kingdom.Event(event)                 notable events: kingdom-scoped ones to its rulers; wars,
		                                     conquests, captures, day/night and the match end to everyone
		Kingdom.Phase(phase, endsAtServerTime?)  MatchPhase (G2) on every change; Lobby carries the
		                                     countdown deadline (moves to the Match area once assigned)
	Building and army commands (G8 Build.*, Army.*) are declared by their own areas.
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local Catalog = require("../Sim/Catalog")
local Types = require("./Types")

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

local SLOW_RATE = { burst = 3, perSecond = 0.5 }
local MANAGE_RATE = { burst = 10, perSecond = 4 }

return {
	{ name = "Kingdom.GetState", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Kingdom.Choose", kind = "function", args = { Validate.enum(Types.KINGDOM_IDS) }, rate = SLOW_RATE },
	{
		name = "Kingdom.Gather",
		kind = "function",
		args = { Validate.string(1, 32) },
		rate = { burst = 4, perSecond = 2 },
	},
	{
		name = "Kingdom.SetJobQuota",
		kind = "function",
		args = { Validate.enum(keysOf(catalog.jobOrder, "hauler")), Validate.integer(0, 200) },
		rate = MANAGE_RATE,
	},
	{
		name = "Kingdom.SetPriority",
		kind = "function",
		args = { Validate.enum(Types.RESOURCE_IDS), Validate.integer(0, 3) },
		rate = MANAGE_RATE,
	},
	{ name = "Kingdom.SetAlarm", kind = "function", args = { Validate.boolean() }, rate = SLOW_RATE },
	{ name = "Kingdom.Snapshot", kind = "serverEvent" },
	{ name = "Kingdom.Overview", kind = "serverEvent" },
	{ name = "Kingdom.Event", kind = "serverEvent" },
	{ name = "Kingdom.Phase", kind = "serverEvent" },
}
