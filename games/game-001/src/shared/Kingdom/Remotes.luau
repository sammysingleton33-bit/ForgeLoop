--!strict
--[[
	Kingdom/Remotes — remotes of the "Kingdom" area (CONTRACTS G1/G8). Owner: FORGE-01.
	RemoteService creates them as ReplicatedStorage.ForgeRemotes.Kingdom.<Action>.

	Client -> server (validated, rate-limited per player)
		Kingdom.GetState() -> { kingdoms: { Kingdom (G2) }, mine: KingdomId? }   snapshot on request
		Kingdom.Gather(nodeId: string(1,32)) -> (true, ResourceId, amount) | (false, errorCode)
		                                     the ruler harvests a node; the server uses the character
		                                     position it sees and enforces range and cooldown
		Kingdom.SetJobQuota(job: JobId, count: integer(0,50)) -> (boolean, errorCode?)   G5 requestWorkers;
		                                     hauler is the pool, so it is not a quota job
		Kingdom.GetPopulation() -> { total, byJob, cap }?   G5 getPopulation of the asker's kingdom (G13.2)
	Server -> client
		Kingdom.State({ kingdoms, mine })    on change (to every player) and to each arriving player
		Kingdom.Population({ total, byJob, cap })   to a kingdom's members on change (G13.2)
	Implemented by Kingdom/MatchHost; GetPopulation/Population by CitizenService. Match phases are the "Match" area (Match/Remotes.luau).
]]

local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local Catalog = require("../Sim/Catalog")

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

return {
	{ name = "Kingdom.GetState", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{
		name = "Kingdom.Gather",
		kind = "function",
		args = { Validate.string(1, 32) },
		rate = { burst = 4, perSecond = 2 },
	},
	{
		name = "Kingdom.SetJobQuota",
		kind = "function",
		args = { Validate.enum(keysOf(catalog.jobOrder, "hauler")), Validate.integer(0, 50) },
		rate = { burst = 10, perSecond = 4 },
	},
	{ name = "Kingdom.State", kind = "serverEvent" },
	{ name = "Kingdom.GetPopulation", kind = "function", rate = { burst = 3, perSecond = 1 } },
	{ name = "Kingdom.Population", kind = "serverEvent" },
}
