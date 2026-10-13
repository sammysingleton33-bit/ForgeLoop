--!strict
--[[
	CitizenService — the kingdoms' citizens as other services see them (CONTRACTS G5, G7, G8; FL-0050,
	FL-0078). Owner: FORGE-01.

	Citizens live in the kingdom simulation (MatchService's host); this service is their API.
	API (G5)
		CitizenService:getPopulation(kingdom): { total, byJob: { [JobId]: number }, cap }?
			-- citizens and soldiers (soldiers count in byJob.soldier and in total); nil for an unknown kingdom
		CitizenService:setFedRatio(kingdom, ratio)   -- 0..1 from ProductionService's upkeep (FORGE-03)
		CitizenService:inspect(entityId): { name, job, mood, intent, lastMemory? }?   -- citizens only
	G7: ProductionService is the only food consumer. Once this service runs, citizens never buy meals:
	their hunger follows the kingdom's fed ratio (fully fed: hunger falls; half fed: holds; unfed: rises;
	Sim/Simulation fedByUpkeep). Without this service the simulation keeps its own meal double.
	Remote (G8): Sim.Inspect(entityId) -> inspect(entityId) for a citizen of the asker's own kingdom, else nil.
	mood is 0..100 (well fed and rested = high); intent is the current activity and why, e.g.
	"Gather wood (best job)". The generated population (names, traits, loyalty, family) arrives with
	FL-0078 once the content library is merged; inspect then returns the G13.2 CitizenView superset.
]]

local CitizenService = {}
CitizenService.__index = CitizenService

local Def = { name = "CitizenService", dependencies = { "MatchService", "RemoteService" } }

local ACTIVITY_TEXT = {
	Gather = "Gathering",
	Farm = "Farming",
	Build = "Building",
	Eat = "Eating",
	Sleep = "Sleeping",
	Flee = "Fleeing",
	Idle = "Idle",
}

function Def.new(env: any, registry: any)
	local self = setmetatable({}, CitizenService)
	self._env = env
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	return self
end

function CitizenService:_sim(): any
	return self._match.host.match.sim
end

function CitizenService:start()
	local match = self._match.host.match
	-- from now on (and in every new world) the upkeep feeds the citizens (G7)
	match.options.fedByUpkeep = true
	match.sim.fedByUpkeep = true
	self._remotes:handle("Sim.Inspect", function(player: any, entityId: number)
		local mine = match:kingdomOf(player.UserId)
		local c = self:_sim().citizens[entityId]
		if mine == nil or c == nil or c.kingdomId ~= mine then
			return nil
		end
		return self:inspect(entityId)
	end)
end

function CitizenService:getPopulation(kingdomId: string): { total: number, byJob: { [string]: number }, cap: number }?
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	if k == nil then
		return nil
	end
	local byJob = {}
	for _, id in k.citizenIds do
		local c = sim.citizens[id]
		byJob[c.job] = (byJob[c.job] or 0) + 1
	end
	if #k.unitIds > 0 then
		byJob.soldier = (byJob.soldier or 0) + #k.unitIds
	end
	return { total = #k.citizenIds + #k.unitIds, byJob = byJob, cap = k.popCap }
end

function CitizenService:setFedRatio(kingdomId: string, ratio: number)
	assert(type(ratio) == "number" and ratio == ratio, "CitizenService:setFedRatio: ratio must be a number")
	local k = self:_sim().kingdoms[kingdomId]
	if k then
		k.fedRatio = math.clamp(ratio, 0, 1)
	end
end

function CitizenService:inspect(entityId: number): { [string]: any }?
	local sim = self:_sim()
	local c = sim.citizens[entityId]
	if c == nil then
		return nil
	end
	local last = c.memory and c.memory[#c.memory]
	local doing = ACTIVITY_TEXT[c.activity] or tostring(c.activity or "Idle")
	local why = c.reason or c.activityReason
	return {
		name = c.name,
		job = c.job,
		mood = math.clamp(math.floor((1 - math.min(1, c.hunger)) * 100 + 0.5), 0, 100),
		intent = if why then `{doing} ({why})` else doing,
		lastMemory = if last then last.kind else nil,
	}
end

return Def
