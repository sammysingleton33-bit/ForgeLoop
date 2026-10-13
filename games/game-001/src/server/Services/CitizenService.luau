--!strict
--[[
	CitizenService — the kingdoms' citizens as other services see them (CONTRACTS G5, G7, G8; FL-0050,
	FL-0078). Owner: FORGE-01.

	Citizens live in the kingdom simulation (MatchService's host); this service is their API.
	API (G5)
		CitizenService:getPopulation(kingdom): { total, byJob: { [JobId]: number }, cap, quotas }?
			-- citizens and soldiers (soldiers count in byJob.soldier and in total); cap = beds + barracks
			   bunks (soldiers sleep in the barracks, D-041), so it counts the same people as total; quotas = the
			   Kingdom.SetJobQuota targets per job, hauler excepted (additive to G5, for the job panel);
			   whole numbers >= 0; nil for an unknown kingdom
		CitizenService:setFedRatio(kingdom, ratio)   -- 0..1 from ProductionService's upkeep (FORGE-03)
		CitizenService:inspect(entityId): CitizenView?   -- G13.2 (a superset of G5's name, job, mood,
		                                                  intent, lastMemory?); citizens only
	G7: ProductionService is the only food consumer. Once this service runs, citizens never buy meals:
	their hunger follows the kingdom's fed ratio (fully fed: hunger falls; half fed: holds; unfed: rises;
	Sim/Simulation fedByUpkeep). Without this service the simulation keeps its own meal double.
	Remotes (G8, G13.2): Sim.Inspect(entityId) -> inspect(entityId) for a citizen of the asker's own
	kingdom, else nil. Kingdom.GetPopulation() -> getPopulation(my kingdom) (nil for a spectator);
	Kingdom.Population(population) to a kingdom's members when it changes (checked every second) and
	to each player whose kingdom changes.
	Population (G13.2, FL-0078): on start the match generates people (Sim/People) from a seed per
	world and the content library (Names, Traits, Occupations), so every citizen has a name, an
	occupation, 2-3 traits, a household, friends and rivals, chemistry, loyalty and a look.
	CitizenView = { entityId, name, occupation, job, traits, mood, loyalty, obedience, intent,
	lastMemory?, memories, family, friends, rivals (names), hasRequest, look }. mood is 0..100 (well
	fed and rested = high); intent is the current activity and why, e.g. "Gathering (best job)";
	obedience is derived (Population.obedience) from the ruler reputation `reputationOf(kingdomId)`
	(ReputationService when present, else the Content start values) and the citizen's traits;
<<<<<<< HEAD
	hasRequest is true while the citizen has an open request (ConversationService:hasRequest, its thought
	bubble; false without that service).
	Studio debug hook (G13.7 strike.start, FORGE-05's DebugPresetService):
		CitizenService:debugStrike(kingdom, occupation, on) -> (ok, message)   every citizen of the occupation
		    strikes for DEBUG_STRIKE_SECONDS (or stops); ConversationService:announceStrike sends the events
=======
	hasRequest is false until conversations (FL-0079).
	Studio debug hooks (G13.7, called by FORGE-05's DebugPresetService; each `(kingdom, ...) -> (ok, message)`):
		debugReseed(kingdom, seed)              new identities for the kingdom's living citizens (People.reseed)
		(debugStrike and debugRequest come with the conversations, FL-0079)
>>>>>>> origin/main
]]

local Population = require("@game/ReplicatedStorage/Game/Sim/Population")
local People = require("@game/ReplicatedStorage/Game/Sim/People")

local CitizenService = {}
CitizenService.__index = CitizenService

local Def = { name = "CitizenService", dependencies = { "MatchService", "RemoteService" } }

Def.DEBUG_STRIKE_SECONDS = 120 -- G13.7 strike.start

local ACTIVITY_TEXT = {
	Gather = "Gathering",
	Farm = "Farming",
	Build = "Building",
	Eat = "Eating",
	Sleep = "Sleeping",
	Flee = "Fleeing",
	Idle = "Idle",
	Talk = "Talking", -- held in a ruler's conversation (G13.8)
}

local POPULATION_EVERY = 1 -- seconds between Kingdom.Population checks

function Def.new(env: any, registry: any)
	local self = setmetatable({}, CitizenService)
	self._env = env
	self._registry = registry
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	self._sentPopulation = {} :: { [any]: string } -- player -> last Kingdom.Population signature sent
	self._running = false
	return self
end

-- The ruler reputation obedience reads (G13.2): ReputationService's when it runs, else the starts.
function CitizenService:reputationOf(kingdomId: string): { [string]: number }
	local reputation = self._registry:find("ReputationService")
	if reputation and reputation.getKingdomReputation then
		local values = reputation:getKingdomReputation(kingdomId)
		if values then
			return values
		end
	end
	return People.startReputation()
end

function CitizenService:_sim(): any
	return self._match.host.match.sim
end

function CitizenService:start()
	local match = self._match.host.match
	-- from now on (and in every new world) the upkeep feeds the citizens (G7)
	match.options.fedByUpkeep = true
	match.sim.fedByUpkeep = true
	match:setPeople(People.CONTENT) -- generated citizens in this world and every next one (G13.2)
	self._remotes:handle("Sim.Inspect", function(player: any, entityId: number)
		local mine = match:kingdomOf(player.UserId)
		local c = self:_sim().citizens[entityId]
		if mine == nil or c == nil or c.kingdomId ~= mine then
			return nil
		end
		return self:inspect(entityId)
	end)
	self._remotes:handle("Kingdom.GetPopulation", function(player: any)
		local mine = match:kingdomOf(player.UserId)
		return if mine then self:getPopulation(mine) else nil
	end)
	self._running = true
	self._env.spawn(function()
		while self._running do
			self:_pushPopulation()
			self._env.wait(POPULATION_EVERY)
		end
	end)
end

local function populationSignature(kingdomId: string, population: { [string]: any }): string
	local jobs = {}
	for job, n in population.byJob do
		table.insert(jobs, `{job}={n}`)
	end
	table.sort(jobs)
	local quotas = {}
	for job, n in population.quotas do
		table.insert(quotas, `{job}={n}`)
	end
	table.sort(quotas)
	return `{kingdomId}|{population.total}|{population.cap}|{table.concat(jobs, ",")}|{table.concat(quotas, ",")}`
end

-- Kingdom.Population to every player whose kingdom's population (or whose kingdom) changed.
function CitizenService:_pushPopulation()
	local match = self._match.host.match
	local seen = {}
	for _, player in self._env.Players:GetPlayers() do
		seen[player] = true
		local mine = match:kingdomOf(player.UserId)
		local population = if mine then self:getPopulation(mine) else nil
		local signature = if population and mine then populationSignature(mine, population) else ""
		if signature ~= (self._sentPopulation[player] or "") then
			self._sentPopulation[player] = signature
			if population then
				self._remotes:fire("Kingdom.Population", player, population)
			end
		end
	end
	for player in self._sentPopulation do
		if not seen[player] then
			self._sentPopulation[player] = nil
		end
	end
end

function CitizenService:destroy()
	self._running = false
end

-- whole numbers >= 0 on the wire (never -0 or a fraction)
local function count(n: number): number
	return math.max(0, math.floor(n)) + 0
end

function CitizenService:getPopulation(kingdomId: string): {
	total: number,
	byJob: { [string]: number },
	cap: number,
	quotas: { [string]: number },
}?
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
	local quotas = {}
	for job, n in k.quotas or {} do
		if job ~= "hauler" then -- haulers are the pool the others draw from: no quota (Sim/Commands)
			quotas[job] = count(n)
		end
	end
	-- citizens sleep in beds, soldiers in barracks bunks (D-041): cap counts both, like total
	local cap = count(sim:sleepCap(k))
	return { total = count(#k.citizenIds + #k.unitIds), byJob = byJob, cap = cap, quotas = quotas }
end

-- ---------------------------------------------------------------- Studio debug hooks (G13.7)
function CitizenService:debugReseed(kingdomId: string, seed: number): (boolean, string?)
	local sim = self:_sim()
	if sim.kingdoms[kingdomId] == nil then
		return false, `unknown kingdom {kingdomId}`
	end
	if sim.profiler == nil then
		return false, "this world has no generated population"
	end
	local reseeded = People.reseed(sim, kingdomId, seed, People.CONTENT)
	return true, `{reseeded} citizens of {kingdomId} reseeded from {seed}`
end

-- ---------------------------------------------------------------- Studio debug hooks (G13.7)
-- Every citizen of `occupation` strikes for DEBUG_STRIKE_SECONDS, or stops; the strike events go out
-- through ConversationService:announceStrike when it runs. -> (ok, message)
function CitizenService:debugStrike(kingdomId: string, occupation: string, on: boolean): (boolean, string?)
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	if k == nil then
		return false, `unknown kingdom {kingdomId}`
	end
	local changed = {}
	for _, id in k.citizenIds do
		local c = sim.citizens[id]
		local occ = if c.profile then c.profile.occupation else c.job
		if occ == occupation and sim:isStriking(c) ~= on then
			if on then
				sim:strike(c, Def.DEBUG_STRIKE_SECONDS)
			else
				c.strikeUntil = nil
			end
			table.insert(changed, c)
		end
	end
	if #changed == 0 then
		return false, `no {occupation} of {kingdomId} to {if on then "strike" else "end a strike for"}`
	end
	local conversations = self._registry:find("ConversationService")
	if conversations and conversations.announceStrike then
		conversations:announceStrike(kingdomId, changed, on)
	end
	return true, `{#changed} {occupation} {if on then `on strike for {Def.DEBUG_STRIKE_SECONDS} s` else "back at work"}`
end

function CitizenService:setFedRatio(kingdomId: string, ratio: number)
	assert(type(ratio) == "number" and ratio == ratio, "CitizenService:setFedRatio: ratio must be a number")
	local k = self:_sim().kingdoms[kingdomId]
	if k then
		k.fedRatio = math.clamp(ratio, 0, 1)
	end
end

local function namesOf(sim: any, ids: { number }?): { string }
	local out = {}
	for _, id in ids or {} do
		local other = sim.citizens[id]
		if other then
			table.insert(out, other.name)
		end
	end
	return out
end

function CitizenService:_hasRequest(c: any): boolean
	local conversations = self._registry:find("ConversationService")
	return conversations ~= nil and conversations.hasRequest ~= nil and conversations:hasRequest(c.kingdomId, c.id)
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
	local profile = c.profile
	local traits = if profile then table.clone(profile.traits) else {}
	local memories = {}
	for _, entry in c.memory or {} do
		table.insert(memories, entry.kind)
	end
	return {
		entityId = c.id,
		name = c.name,
		occupation = if profile then profile.occupation else c.job,
		job = c.job,
		traits = traits,
		mood = math.clamp(math.floor((1 - math.min(1, c.hunger)) * 100 + 0.5), 0, 100),
		loyalty = c.loyalty or 50,
		obedience = Population.obedience(traits, self:reputationOf(c.kingdomId), People.CONTENT),
		intent = if why then `{doing} ({why})` else doing,
		lastMemory = if last then last.kind else nil,
		memories = memories,
		family = namesOf(sim, profile and profile.family),
		friends = namesOf(sim, profile and profile.friends),
		rivals = namesOf(sim, profile and profile.rivals),
		hasRequest = self:_hasRequest(c),
		look = table.clone(if profile then profile.look else People.DEFAULT_LOOK),
	}
end

return Def
