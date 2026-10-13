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
		Kingdom.GetPopulation() -> { total, byJob, cap, quotas, quotaRev }?   getPopulation of the asker's kingdom (G13.2)
		Kingdom.GetReputation() -> { values, history (latest 30), kingdom: { happiness, stability, morale } }?
		                                     the asker's own reputation (G13.4); nil for a spectator
		Kingdom.Converse(entityId: integer) -> { entityId, scenarioId, speaker: { name, occupation }, question,
		                                     options: { { id, text, cost?, risks? } } }?   (G13.3) own kingdom's
		                                     citizens, rulers only; nil when the citizen has nothing to say
		                                     or the match is not in an active phase (Lobby, Results)
		Kingdom.Choose(entityId, scenarioId: string(1,48), responseId: string(1,48))
		                                  -> (ok, { reaction, effects: { { kind, text } } }?, reason?)   (G13.3)
		                                     reasons: not_in_match, unknown_citizen, phase, not_offered,
		                                     unknown_response, not_eligible, cost (ConversationService)
	Server -> client
		Kingdom.State({ kingdoms, mine })    on change (to every player) and to each arriving player
		Kingdom.Population({ total, byJob, cap, quotas, quotaRev })   to a kingdom's members on change (G13.2;
		                                       quotaRev +1 per accepted quota change, FL-0109)
		Kingdom.Reputation(same payload as GetReputation)   to the ruler when it changes (G13.4)
	Implemented by Kingdom/MatchHost; GetPopulation/Population by CitizenService; GetReputation/Reputation
	by ReputationService; Converse/Choose by ConversationService. Match phases are the "Match" area (Match/Remotes.luau).
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
	{ name = "Kingdom.GetPopulation", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
	{ name = "Kingdom.Population", kind = "serverEvent" },
	{ name = "Kingdom.GetReputation", kind = "function", args = {}, rate = { burst = 3, perSecond = 1 } },
	{
		name = "Kingdom.Converse",
		kind = "function",
		args = { Validate.integer(1, 65535) },
		rate = { burst = 4, perSecond = 2 },
	},
	{
		name = "Kingdom.Choose",
		kind = "function",
		args = { Validate.integer(1, 65535), Validate.string(1, 48), Validate.string(1, 48) },
		rate = { burst = 4, perSecond = 2 },
	},
	{ name = "Kingdom.Reputation", kind = "serverEvent" },
}
