--!strict
--[[
	LeadershipService — the Crown Arena's support inputs, recorded as the match is played (FL-0069; CONTRACTS G12.2,
	design `crown-arena.md` §3). Owner: FORGE-01. Server-authoritative: producers (BuildingService, ProductionService,
	MilitaryService, ...) call `record` through `registry:find("LeadershipService")` and never compute support
	themselves; the score is computed only by Arena/SupportModel from what this service samples.

		LeadershipService:record(kingdom, userId?, act, magnitude?): LeadershipMoment?
			act is an id of config Support `acts`; an unknown act, a capped valour gain or a kingdom that is not in the
			match is refused (nil) and logged at most once per act. Fires `acted`.
		LeadershipService:getMoments(kingdom, userId?, limit): { LeadershipMoment }      newest first (Arena/Ledger)
		LeadershipService:samples(kingdom, userId?): { { t, components } }
			one sample per `Support.sampling.intervalSeconds` of match time, oldest first, all seven components 0..100
			(SupportModel.score reads exactly this). userId picks which ruler's conduct and valour are in it.
		LeadershipService:sample()                      -- one round (the loop calls it; specs call it directly)
		LeadershipService.acted: Signal<(kingdom, userId?, act, component, delta)>
			(the G12.5 `LeadershipAct` event is fired on the GameEvents bus once FORGE-05 declares it)

	Acts the service records by itself from the simulation (thresholds in config Support `rules`), for every ruler
	seated in the kingdom (the "no ruler" series for an AI-held one), checked at each sample: starvation (fed ratio below
	the bar for more than 60 s, once per episode), fedRatioKept (fed ratio never under 0.9 through a whole Expansion,
	Conflict or Endgame, recorded when the phase changes) and overConscription (soldiers above 35 % of soldiers +
	citizens for more than 60 s, once per episode). Phase edges are seen at sample resolution (30 s).

	Components sampled: reputation = mean of ReputationService's kingdom categories (config reputationCategories) plus
	the kingdom's reputation act offset; happiness / stability / morale = the kingdom's conditions (stability minus
	unrest pressure); loyalty = the mean loyalty of the kingdom's living citizens; conduct / valour = the ruler's
	ledger level. A missing source counts as neutral (50). The clock is the simulation's own (`sim.time`), so the
	service is deterministic: the same event log gives the same ledger. A new round starts every ledger over.
	Dependencies: MatchService. Optional (registry:find): ReputationService.
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local Ledger = require("@game/ReplicatedStorage/Game/Arena/Ledger")
local Consequences = require("@game/ReplicatedStorage/Game/Sim/Consequences")

local LeadershipService = {}
LeadershipService.__index = LeadershipService

local Def = { name = "LeadershipService", dependencies = { "MatchService" } }

local NEUTRAL = 50
local MAX_SAMPLES = 400 -- 3 h at the 30 s interval: more than any match, bounds the memory anyway

local function clamp100(x: number): number
	return math.max(0, math.min(100, x))
end

function Def.new(env: any, registry: any)
	local self = setmetatable({}, LeadershipService)
	self._env = env
	self._registry = registry
	self._match = registry:get("MatchService")
	self.config = Support -- specs may swap in a table of their own
	self.acted = Signal.new()
	self._running = false
	self:_reset(nil)
	return self
end

function LeadershipService:_reset(round: any)
	self._round = round
	self._ledger = Ledger.new(self.config)
	self._samples = {} :: { [string]: { any } } -- "kingdom|userId" -> samples
	self._lastSampleAt = -math.huge
	self._warned = {} :: { [string]: boolean }
	self._watch = {} :: { [string]: any } -- kingdom -> what the act rules have seen so far
end

function LeadershipService:_sim(): any
	local match = self._match.host.match
	if match.roundId ~= self._round then
		self:_reset(match.roundId) -- a new world: every ledger starts over
	end
	return match.sim
end

local function sampleKey(kingdom: string, userId: number?): string
	return `{kingdom}|{if userId then tostring(userId) else "-"}`
end

-- ---------------------------------------------------------------- API
function LeadershipService:record(kingdom: string, userId: number?, act: string, magnitude: number?): any
	local sim = self:_sim()
	if type(kingdom) ~= "string" or type(act) ~= "string" then
		return nil
	end
	local k = sim.kingdoms[kingdom]
	if k == nil then
		return nil
	end
	local moment, reason = Ledger.record(self._ledger, kingdom, userId, act, magnitude, sim.time)
	if moment == nil then
		if reason == "unknown_act" and not self._warned[act] then
			self._warned[act] = true
			self._env.log("warn", "LeadershipService: unknown act", { act = act })
		end
		return nil
	end
	self.acted:fire(kingdom, userId, act, moment.component, moment.delta)
	return moment
end

function LeadershipService:getMoments(kingdom: string, userId: number?, limit: number): { any }
	self:_sim()
	return Ledger.moments(self._ledger, kingdom, userId, limit)
end

function LeadershipService:samples(kingdom: string, userId: number?): { any }
	self:_sim()
	return self._samples[sampleKey(kingdom, userId)] or {}
end

-- ---------------------------------------------------------------- sampling
function LeadershipService:_reputation(kingdom: string): number
	local reputation = self._registry:find("ReputationService")
	local mean = NEUTRAL
	if reputation and reputation.getKingdomReputation then
		local values = reputation:getKingdomReputation(kingdom)
		local total, count = 0, 0
		for _, category in self.config.reputationCategories do
			local value = values[category]
			if type(value) == "number" then
				total += value
				count += 1
			end
		end
		if count > 0 then
			mean = total / count
		end
	end
	return clamp100(mean + Ledger.offset(self._ledger, kingdom, "reputation"))
end

local function meanLoyalty(sim: any, k: any): number
	local total, count = 0, 0
	for _, id in k.citizenIds do
		local c = sim.citizens[id]
		if c and c.alive ~= false then
			total += c.loyalty or NEUTRAL
			count += 1
		end
	end
	return if count > 0 then total / count else NEUTRAL
end

function LeadershipService:_kingdomComponents(sim: any, kingdom: string, k: any): { [string]: number }
	local conditions = k.conditions
	return {
		reputation = self:_reputation(kingdom),
		happiness = clamp100(if conditions then conditions.happiness or NEUTRAL else NEUTRAL),
		stability = clamp100(if conditions then Consequences.effectiveStability(k) else NEUTRAL),
		morale = clamp100(if conditions then conditions.morale or NEUTRAL else NEUTRAL),
		loyalty = clamp100(meanLoyalty(sim, k)),
	}
end

-- Records `act` for every ruler seated in the kingdom (the unseated series when an AI holds it).
function LeadershipService:_recordRulers(kingdom: string, k: any, act: string)
	if #k.rulers == 0 then
		self:record(kingdom, nil, act, 1)
		return
	end
	for _, userId in k.rulers do
		self:record(kingdom, userId, act, 1)
	end
end

-- The acts the simulation's own state decides (config Support `rules`); see the header.
function LeadershipService:_watchKingdom(kingdom: string, k: any, now: number)
	local rules = self.config.rules
	local w = self._watch[kingdom]
	if w == nil then
		w = { t = now, lowFor = 0, starving = false, soldiersFor = 0, conscripting = false, phase = nil, phaseMin = 1 }
		self._watch[kingdom] = w
	end
	local dt = now - w.t
	w.t = now
	local fed = k.fedRatio or 1

	if fed < rules.starvation.below then
		w.lowFor += dt
		if not w.starving and w.lowFor > rules.starvation.seconds then
			w.starving = true
			self:_recordRulers(kingdom, k, "starvation")
		end
	else
		w.lowFor = 0
		w.starving = false
	end

	local phase = self._match:getPhase()
	if w.phase ~= phase then
		if w.phase ~= nil and rules.fedKept.phases[w.phase] and w.phaseMin >= rules.fedKept.atLeast then
			self:_recordRulers(kingdom, k, "fedRatioKept")
		end
		w.phase = phase
		w.phaseMin = fed
	else
		w.phaseMin = math.min(w.phaseMin, fed)
	end

	local soldiers, citizens = #k.unitIds, #k.citizenIds
	local share = if soldiers + citizens > 0 then soldiers / (soldiers + citizens) else 0
	if share > rules.conscription.soldierShareAbove then
		w.soldiersFor += dt
		if not w.conscripting and w.soldiersFor > rules.conscription.seconds then
			w.conscripting = true
			self:_recordRulers(kingdom, k, "overConscription")
		end
	else
		w.soldiersFor = 0
		w.conscripting = false
	end
end

function LeadershipService:_store(kingdom: string, userId: number?, sample: any)
	local key = sampleKey(kingdom, userId)
	local list = self._samples[key]
	if list == nil then
		list = {}
		self._samples[key] = list
	end
	table.insert(list, sample)
	if #list > MAX_SAMPLES then
		table.remove(list, 1)
	end
end

function LeadershipService:sample()
	local sim = self:_sim()
	if not sim.active then
		return
	end
	local now = sim.time
	if now - self._lastSampleAt < self.config.sampling.intervalSeconds - 1e-6 then
		return
	end
	self._lastSampleAt = now
	for _, kingdom in sim.kingdomOrder do
		local k = sim.kingdoms[kingdom]
		if k.alive and k.populated then
			self:_watchKingdom(kingdom, k, now)
			local shared = self:_kingdomComponents(sim, kingdom, k)
			-- one series per seated ruler; an AI-held kingdom has one for the "no ruler" key
			local rulers: { any } = if #k.rulers > 0 then table.clone(k.rulers) else { false }
			for _, ruler in rulers do
				local userId: number? = if ruler then ruler else nil
				local components = table.clone(shared)
				components.conduct = Ledger.level(self._ledger, kingdom, userId, "conduct")
				components.valour = Ledger.level(self._ledger, kingdom, userId, "valour")
				self:_store(kingdom, userId, { t = now, components = components })
			end
		end
	end
end

-- ---------------------------------------------------------------- lifecycle
function LeadershipService:start()
	self._running = true
	self._env.spawn(function()
		while self._running do
			self._env.wait(self.config.sampling.intervalSeconds)
			if self._running then
				local ok, err = pcall(self.sample, self)
				if not ok then
					self._env.log("error", "LeadershipService: sample failed", { error = tostring(err) })
				end
			end
		end
	end)
end

function LeadershipService:destroy()
	self._running = false
end

return Def
