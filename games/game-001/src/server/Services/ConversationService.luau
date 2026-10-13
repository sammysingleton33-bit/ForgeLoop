--!strict
--[[
	ConversationService — citizens' requests and the ruler's answers (CONTRACTS G13.3; FL-0079; content/SPEC.md
	§5.1–5.4, §6). Owner: FORGE-01. Content (Dialogue, Decisions, Consequences) arrives pre-parsed; nothing here
	parses text conditions.

	Remotes (G13.3; Kingdom/Remotes)
		Kingdom.Converse(entityId) -> { entityId, scenarioId, speaker: { name, occupation }, question,
		                                options: { { id, text, cost?, risks?: { { text, chance } } } } }?
			A ruler of the citizen's kingdom only. The scenario: the citizen's open request when it still
			holds, else the first eligible one (ContentQuery.eligibleScenarios on the acting ruler's ctx, SPEC
			§6.8). Opening it marks it shown (cooldowns, once_per_citizen) and fires RulerVisited (FL-0080).
			Asking again while the answer is pending returns the same showing.
		Kingdom.Choose(entityId, scenarioId, responseId) -> (ok, { reaction, effects: { { kind, text } } }?,
		                                                     reason?)
			Answers the showing that Converse opened for this ruler, once (idempotent per showing). Refusal
			reasons (stable): not_in_match, unknown_citizen, not_offered (no open showing for this ruler and
			scenario: never opened, already answered, or another ruler's), unknown_response, not_eligible (the
			scenario no longer holds; the showing closes), cost (the kingdom cannot pay; the showing stays open).
	Effects of a choice (ContentQuery.fireDecision with the ruler's and the kingdom's farm histories, so the
	bundle is already decayed; ReputationService:farmHistories):
		- cost spent and resource_effects through the treasury (txId decision:<round>:<entity>:<scenario>:<n>);
		- reputation: ReputationService:apply(ruler, decisionId, rep, response text);
		- loyalty: every listener once under its closest relation (speaker > family > friends > rivals >
		  audience), as fireDecision's `listeners` give it (decisionLoyalty with the kingdom multiplier,
		  clamped to ContentQuery.LOYALTY_CLAMP; applied as given); the speaker's chemistry drifts
		  (ContentQuery.driftChemistry);
		- kingdom conditions (Kingdom/Reputation.applyConditions); memory_tag pinned on the speaker;
		  decision.<id> remembered for the ruler;
		- consequences (after delay_s; a chance < 1 rolls the match's random): productivity (sim:addProductivity),
		  strike (the least loyal share of an occupation, sim:strike; strike on/off events), loyalty, morale /
		  happiness / stability, unlock_scenario, memory (pinned), resource_over_time (per second),
		  unrest_pressure and desertion_risk (recorded for FL-0082), cue;
		- a `reaction` event to the kingdom's members.
	Thought bubbles: every Society.requestRefreshSeconds, each ruled kingdom keeps up to Society.openRequests
	open requests: the highest-priority eligible scenario of citizens without one (thought ctx: the best
	reputation among its rulers, any ruler's decisions, SPEC §6.8). New ones go to the members as `thought`
	events; a request that stops holding closes.
	Events (G13.3) go through EntityService:sendKingdomEvent when EntityService runs (else they are dropped).
	Event flags for triggers: event.<tag> holds for Society.conversation.eventSeconds after the event
	(building_completed, keep_upgraded, soldiers_recruited, objective_captured), and event.shortage while the
	fed ratio is below Society.food.shortageBelow and that long after.
	API (server)
		ConversationService:converse(player, entityId), :choose(player, entityId, scenarioId, responseId)
		ConversationService:refresh()          -- one thought-bubble refresh (the loop calls it)
		ConversationService:step(dt)           -- consequences over time (the loop calls it)
		ConversationService:openRequests(kingdomId): { { entityId, scenarioId } }
]]

local SocietyConfig = require("@game/ReplicatedStorage/Forge/Config/Society")
local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")
local Occupations = require("@game/ReplicatedStorage/Game/Content/Occupations")
local Reputation = require("@game/ReplicatedStorage/Game/Kingdom/Reputation")
local Context = require("@game/ReplicatedStorage/Game/Sim/Context")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local People = require("@game/ReplicatedStorage/Game/Sim/People")
local Population = require("@game/ReplicatedStorage/Game/Sim/Population")

local ConversationService = {}
ConversationService.__index = ConversationService

local Def = {
	name = "ConversationService",
	dependencies = { "MatchService", "RemoteService", "ReputationService" },
}

local STEP = 1 -- seconds between consequence steps
function Def.new(env: any, registry: any)
	local self = setmetatable({}, ConversationService)
	self._env = env
	self._registry = registry
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	self._reputation = registry:get("ReputationService")
	self._running = false
	self._connections = {} :: { any }
	self:_reset(nil)
	return self
end

function ConversationService:_reset(roundId: string?)
	self._round = roundId
	self._shown = {} :: { [string]: any } -- kingdomId -> ShownHistory (SPEC §6.8: one per kingdom)
	self._open = {} :: { [string]: { { entityId: number, scenarioId: string } } }
	self._showing = {} :: { [number]: { scenarioId: string, userId: number, kingdomId: string } }
	self._decided = {} :: { [number]: { [string]: boolean } }
	self._flags = {} :: { [string]: { [string]: number } } -- kingdomId -> tag -> time it was last raised
	self._pending = {} :: { { at: number, run: () -> () } }
	self._flows = {} :: { { kingdomId: string, resource: string, perSecond: number, left: number, carry: number } }
	self._seq = 0
end

function ConversationService:_sim(): any
	local match = self._match.host.match
	if match.roundId ~= self._round then
		self:_reset(match.roundId)
	end
	return match.sim
end

function ConversationService:_now(): number
	return self._env.serverTimeNow()
end

-- ---------------------------------------------------------------- context
function ConversationService:_raise(kingdomId: string, tag: string)
	local flags = self._flags[kingdomId] or {}
	self._flags[kingdomId] = flags
	flags[tag] = self:_sim().time
end

function ConversationService:_eventTags(kingdomId: string): { string }
	local sim = self:_sim()
	local tags = {}
	for tag, at in self._flags[kingdomId] or {} do
		if sim.time - at <= SocietyConfig.conversation.eventSeconds then
			table.insert(tags, tag)
		end
	end
	table.sort(tags)
	return tags
end

-- The kingdom ctx for one ruler (Converse) or for the kingdom's thoughts (userId nil: the best values
-- among its rulers and every ruler's decisions, SPEC §6.8), and the reputation obedience is derived from.
function ConversationService:_kingdomCtx(kingdomId: string, userId: number?): (any, { [string]: number })
	local sim = self:_sim()
	local match = self._match.host.match
	local rep = if userId then self._reputation:values(userId) else self._reputation:getKingdomReputation(kingdomId)
	local ctx = Context.kingdom(sim, kingdomId, { phase = match.state, events = self:_eventTags(kingdomId), rep = rep })
	local k = sim.kingdoms[kingdomId]
	for _, ruler in if userId then { userId } else k.rulers do
		for decisionId in self._decided[ruler] or {} do
			ctx[`decision.{decisionId}`] = true
		end
	end
	return ctx, rep
end

function ConversationService:_citizenCtx(c: any, base: any, rep: { [string]: number }): any
	local traits = if c.profile then c.profile.traits else {}
	return Context.citizen(self:_sim(), c, base, { obedience = Population.obedience(traits, rep, People.CONTENT) })
end

local function citizenState(c: any): any
	return { id = c.id, occupation = if c.profile then c.profile.occupation else c.job, unlocked = c.unlocked }
end

local function find(list: { any }, predicate: (any) -> boolean): any?
	for _, item in list do
		if predicate(item) then
			return item
		end
	end
	return nil
end

-- the given name of the first living citizen among ids
local function relative(sim: any, ids: { number }?): string?
	for _, id in ids or {} do
		local other = sim.citizens[id]
		if other and other.profile then
			return other.profile.given
		end
	end
	return nil
end

-- SPEC §3 placeholders of a citizen speaking to a ruler
function ConversationService:_names(c: any, userId: number?): { [string]: string }
	local sim = self:_sim()
	local profile = c.profile
	local occupation = if profile then profile.occupation else c.job
	local player = if userId then self._env.Players:GetPlayerByUserId(userId) else nil
	local k = sim.kingdoms[c.kingdomId]
	local names: { [string]: string } = {
		name = if profile then profile.given else c.name,
		ruler = if player then player.DisplayName else "my liege",
		kingdom = k.name,
		occupation = if Occupations[occupation] then Occupations[occupation].name else occupation,
	}
	if profile then
		names.family = relative(sim, profile.family) :: any
		names.friend = relative(sim, profile.friends) :: any
		names.rival = relative(sim, profile.rivals) :: any
	end
	return names
end

-- ---------------------------------------------------------------- events
-- The G13.3 events to the kingdom's members (EntityService). Only values the wire knows go out: one bad
-- event would drop the kingdom's whole batch (EventCodec refuses it).
function ConversationService:_send(kingdomId: string, event: { [string]: any })
	if event.type == "thought" and table.find(EventCodec.ICONS, event.icon) == nil then
		event.icon = "request"
	elseif event.type == "reaction" and table.find(EventCodec.TONES, event.tone) == nil then
		event.tone = "neutral"
	elseif event.type == "kcue" and table.find(EventCodec.KINGDOM_CUES, event.cue) == nil then
		return -- outside the G13.3 cue vocabulary: the reaction's tone carries it
	elseif event.type == "strike" and event.occupation == nil then
		return
	end
	local entities = self._registry:find("EntityService")
	if entities and entities.sendKingdomEvent then
		entities:sendKingdomEvent(kingdomId, event)
	end
end

function ConversationService:_onEvent(name: string, event: any)
	local sim = self:_sim()
	if name == "BuildingCompleted" then
		local b = sim.buildings[event.buildingId]
		if b and b.kind == "keep" and event.level > 1 then
			self:_raise(event.kingdomId, "keep_upgraded")
		elseif event.level == 1 then
			self:_raise(event.kingdomId, "building_completed")
		end
	elseif name == "RecruitQueued" then
		self:_raise(event.kingdomId, "soldiers_recruited")
	elseif name == "ObjectiveCaptured" then
		self:_raise(event.kingdomId, "objective_captured")
	end
end

-- ---------------------------------------------------------------- Converse
function ConversationService:_ruled(player: any, entityId: any): (string?, any?)
	local match = self._match.host.match
	local kingdomId = match:kingdomOf(player.UserId)
	if kingdomId == nil then
		return nil, nil
	end
	local c = self:_sim().citizens[entityId]
	if c == nil or c.kingdomId ~= kingdomId then
		return kingdomId, nil
	end
	return kingdomId, c
end

function ConversationService:_payload(c: any, scenario: any, userId: number): { [string]: any }
	local names = self:_names(c, userId)
	local options = {}
	local responses = table.clone(scenario.responses)
	table.sort(responses, function(a, b)
		return a.order < b.order
	end)
	for _, response in responses do
		local option: { [string]: any } = { id = response.id, text = ContentQuery.fill(response.text, names) }
		local preview = ContentQuery.choicePreview(scenario.id, response.id)
		if preview then
			if next(preview.cost) ~= nil then
				option.cost = table.clone(preview.cost)
			end
			if #preview.risks > 0 then
				local risks = {}
				for _, risk in preview.risks do
					table.insert(risks, {
						text = ContentQuery.consequenceNotice(risk, names) or risk.id,
						chance = risk.chance,
					})
				end
				option.risks = risks
			end
		end
		table.insert(options, option)
	end
	return {
		entityId = c.id,
		scenarioId = scenario.id,
		speaker = { name = c.name, occupation = names.occupation },
		question = ContentQuery.fill(scenario.question, names),
		options = options,
	}
end

function ConversationService:converse(player: any, entityId: number): { [string]: any }?
	local kingdomId, c = self:_ruled(player, entityId)
	if kingdomId == nil or c == nil then
		return nil
	end
	local userId = player.UserId
	local base, rep = self:_kingdomCtx(kingdomId, userId)
	local ctx = self:_citizenCtx(c, base, rep)
	local showing = self._showing[entityId]
	if showing and showing.userId == userId then
		-- asked again before answering: the same showing, while it still holds
		local still = find(ContentQuery.eligibleScenarios(ctx, citizenState(c), self:_now(), nil), function(s)
			return s.id == showing.scenarioId
		end)
		if still then
			return self:_payload(c, still, userId)
		end
		self._showing[entityId] = nil
	end
	local now = self:_now()
	local shown = self._shown[kingdomId] or {}
	self._shown[kingdomId] = shown
	local eligible = ContentQuery.eligibleScenarios(ctx, citizenState(c), now, shown)
	local open = find(self._open[kingdomId] or {}, function(r)
		return r.entityId == entityId
	end)
	local scenario = (open and find(eligible, function(s)
		return s.id == open.scenarioId
	end)) or eligible[1]
	if scenario == nil then
		return nil
	end
	ContentQuery.markShown(shown, entityId, scenario.id, now)
	self:_closeRequest(kingdomId, entityId)
	self._showing[entityId] = { scenarioId = scenario.id, userId = userId, kingdomId = kingdomId }
	self._reputation:rulerVisited(userId, entityId)
	return self:_payload(c, scenario, userId)
end

-- ---------------------------------------------------------------- Choose
local function targetsOf(sim: any, speaker: any, target: string): { any }
	local k = sim.kingdoms[speaker.kingdomId]
	local out = {}
	local function add(c: any?)
		if c then
			table.insert(out, c)
		end
	end
	if target == "speaker" then
		add(speaker)
	elseif target == "family" or target == "friends" then
		for _, id in if speaker.profile then speaker.profile[target] else {} do
			add(sim.citizens[id])
		end
	else
		local occupation = string.match(target, "^occupation:(.+)$")
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			local occ = if c.profile then c.profile.occupation else c.job
			if target == "kingdom" or target == "civilians" or (occupation ~= nil and occ == occupation) then
				add(c)
			end
		end
	end
	return out
end

local function changeLoyalty(c: any, delta: number)
	c.loyalty = math.clamp((c.loyalty or 50) + delta, 0, 100)
end

function ConversationService:_applyConsequence(kingdomId: string, speaker: any, consequence: any)
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	if k == nil or not k.alive then
		return
	end
	local kind, magnitude, duration = consequence.kind, consequence.magnitude, consequence.duration_s
	local targets = targetsOf(sim, speaker, consequence.target)
	if kind == "productivity" then
		for _, c in targets do
			sim:addProductivity(c, magnitude, duration)
		end
	elseif kind == "strike" then
		table.sort(targets, function(a, b)
			if (a.loyalty or 50) ~= (b.loyalty or 50) then
				return (a.loyalty or 50) < (b.loyalty or 50)
			end
			return a.id < b.id
		end)
		local count = math.min(#targets, math.max(1, math.floor(#targets * magnitude + 0.5)))
		for i = 1, count do
			sim:strike(targets[i], duration)
		end
		local occupation = string.match(consequence.target, "^occupation:(.+)$")
		self:_send(kingdomId, { type = "strike", occupation = occupation, on = true })
		table.insert(self._pending, {
			at = sim.time + duration,
			run = function()
				self:_send(kingdomId, { type = "strike", occupation = occupation, on = false })
			end,
		})
	elseif kind == "loyalty" then
		for _, c in targets do
			changeLoyalty(c, magnitude)
		end
	elseif kind == "morale" or kind == "happiness" or kind == "stability" then
		Reputation.applyConditions(k.conditions, { [kind] = magnitude })
	elseif kind == "unlock_scenario" then
		for _, c in targets do
			c.unlocked = c.unlocked or {}
			c.unlocked[consequence.param] = true
		end
	elseif kind == "memory" then
		for _, c in targets do
			c.pinned = c.pinned or {}
			c.pinned[consequence.param or consequence.id] = true
		end
	elseif kind == "resource_over_time" then
		table.insert(self._flows, {
			kingdomId = kingdomId,
			resource = consequence.param,
			perSecond = magnitude / math.max(1, duration),
			left = duration,
			carry = 0,
		})
	elseif kind == "unrest_pressure" then
		k.unrestPressure = (k.unrestPressure or 0) + magnitude -- read by the unrest rules (FL-0082)
	elseif kind == "desertion_risk" then
		for _, c in targets do
			c.desertionRisk = (c.desertionRisk or 0) + magnitude -- soldiers (VS-2)
		end
	end
	if consequence.cue_id then
		local event: { [string]: any } = { type = "kcue", cue = consequence.cue_id }
		if consequence.target == "speaker" then
			event.id = speaker.id
		else
			event.occupation = string.match(consequence.target, "^occupation:(.+)$")
		end
		self:_send(kingdomId, event)
	end
end

-- ContentQuery DecisionListeners: the speaker, its relations, then the decision's audience ("kingdom").
local function listenerOf(citizen: any, relation: string): { [string]: any }
	local traits = if citizen.profile then citizen.profile.traits else {}
	return { citizen = citizen, relation = relation, traits = traits, chemistry = citizen.chemistry }
end

function ConversationService:_listeners(c: any, audience: string?): { { [string]: any } }
	local sim = self:_sim()
	local seen: { [number]: boolean } = { [c.id] = true }
	local out = { listenerOf(c, "speaker") }
	local profile = c.profile or {}
	for _, relation in { "family", "friends", "rivals" } do
		for _, id in profile[relation] or {} do
			local other = sim.citizens[id]
			if other and not seen[id] then
				seen[id] = true
				table.insert(out, listenerOf(other, relation))
			end
		end
	end
	if audience == "kingdom" or audience == "occupation" then
		local occupation = profile.occupation or c.job
		for _, id in sim.kingdoms[c.kingdomId].citizenIds do
			local other = sim.citizens[id]
			local occ = if other.profile then other.profile.occupation else other.job
			if not seen[id] and (audience == "kingdom" or occ == occupation) then
				seen[id] = true
				table.insert(out, listenerOf(other, "kingdom"))
			end
		end
	end
	return out
end

function ConversationService:choose(
	player: any,
	entityId: number,
	scenarioId: string,
	responseId: string
): (boolean, { [string]: any }?, string?)
	local kingdomId, c = self:_ruled(player, entityId)
	if kingdomId == nil then
		return false, nil, "not_in_match"
	end
	if c == nil then
		return false, nil, "unknown_citizen"
	end
	local userId = player.UserId
	local showing = self._showing[entityId]
	if showing == nil or showing.userId ~= userId or showing.scenarioId ~= scenarioId then
		return false, nil, "not_offered"
	end
	local scenario = ContentQuery.data.dialogue.scenarios[scenarioId]
	local response = scenario and find(scenario.responses, function(r)
		return r.id == responseId
	end)
	if scenario == nil or response == nil then
		return false, nil, "unknown_response"
	end
	local base, rep = self:_kingdomCtx(kingdomId, userId)
	local ctx = self:_citizenCtx(c, base, rep)
	if
		find(ContentQuery.eligibleScenarios(ctx, citizenState(c), self:_now(), nil), function(s)
			return s.id == scenarioId
		end) == nil
	then
		self._showing[entityId] = nil
		return false, nil, "not_eligible"
	end
	local sim = self:_sim()
	local preview = ContentQuery.choicePreview(scenarioId, responseId)
	local cost = if preview then preview.cost else {}
	if not sim:canAfford(kingdomId, cost) then
		return false, nil, "cost"
	end
	local decision = ContentQuery.data.decisions[response.decision]
	if decision == nil then
		return false, nil, "unknown_response"
	end
	local now = self:_now()
	local rulerHistory, kingdomHistory = self._reputation:farmHistories(userId, kingdomId)
	local listeners = self:_listeners(c, decision.audience)
	local effects = assert(ContentQuery.fireDecision(response.decision, rulerHistory, kingdomHistory, now, listeners))
	self._seq += 1
	local tx = `decision:{self._round}:{entityId}:{scenarioId}:{self._seq}`
	if next(cost) ~= nil and not sim:spend(kingdomId, cost, tx, `decision:{effects.id}`) then
		return false, nil, "cost"
	end
	self._showing[entityId] = nil -- answered: a second Choose for this showing is not_offered

	local names = self:_names(c, userId)
	local applied: { { kind: string, text: string } } = {}
	for resource, amount in effects.resources do
		if amount > 0 then
			sim:deposit(kingdomId, resource, amount, `{tx}:+{resource}`, `decision:{effects.id}`)
		elseif amount < 0 then
			local take = math.min(-amount, sim:balance(kingdomId, resource))
			if take > 0 then
				sim:spend(kingdomId, { [resource] = take }, `{tx}:-{resource}`, `decision:{effects.id}`)
			end
		end
	end
	self._reputation:apply(userId, effects.id, effects.rep, ContentQuery.fill(response.text, names))
	for _, heard in effects.listeners do -- decayed and clamped per relation (LOYALTY_CLAMP): applied as given
		changeLoyalty(heard.citizen, heard.loyalty)
	end
	if c.profile then
		c.chemistry = ContentQuery.driftChemistry(c.profile.chemistryBase, c.chemistry or 0, effects.speaker.chemistry)
	end
	local k = sim.kingdoms[kingdomId]
	Reputation.applyConditions(k.conditions, effects.kingdom)
	if effects.memory_tag then
		c.pinned = c.pinned or {}
		c.pinned[effects.memory_tag] = true
	end
	self._decided[userId] = self._decided[userId] or {}
	self._decided[userId][effects.id] = true
	for _, consequence in effects.consequences do
		if consequence.chance >= 1 or sim.rng:NextNumber() < consequence.chance then
			local notice = ContentQuery.consequenceNotice(consequence, names)
			if notice then
				table.insert(applied, { kind = consequence.kind, text = notice })
			end
			if consequence.delay_s > 0 then
				table.insert(self._pending, {
					at = sim.time + consequence.delay_s,
					run = function()
						if sim.citizens[c.id] then
							self:_applyConsequence(kingdomId, c, consequence)
						end
					end,
				})
			else
				self:_applyConsequence(kingdomId, c, consequence)
			end
		end
	end
	local reaction = ContentQuery.fill(response.reaction, names)
	self:_send(kingdomId, { type = "reaction", id = entityId, text = reaction, tone = response.tone or "neutral" })
	return true, { reaction = reaction, effects = applied }, nil
end

-- ---------------------------------------------------------------- thoughts and time
function ConversationService:_closeRequest(kingdomId: string, entityId: number)
	local open = self._open[kingdomId]
	if open == nil then
		return
	end
	for i = #open, 1, -1 do
		if open[i].entityId == entityId then
			table.remove(open, i)
		end
	end
end

function ConversationService:openRequests(kingdomId: string): { { entityId: number, scenarioId: string } }
	self:_sim()
	local out = {}
	for _, r in self._open[kingdomId] or {} do
		table.insert(out, { entityId = r.entityId, scenarioId = r.scenarioId })
	end
	return out
end

function ConversationService:refresh()
	local sim = self:_sim()
	local now = self:_now()
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		if not (k.alive and k.populated and #k.rulers > 0) then
			self._open[kid] = {}
			continue
		end
		local base, rep = self:_kingdomCtx(kid)
		local shown = self._shown[kid] or {}
		self._shown[kid] = shown
		local open = self._open[kid] or {}
		self._open[kid] = open
		-- close requests that no longer hold
		for i = #open, 1, -1 do
			local r = open[i]
			local c = sim.citizens[r.entityId]
			local holds = c
				and find(
					ContentQuery.eligibleScenarios(self:_citizenCtx(c, base, rep), citizenState(c), now, shown),
					function(s)
						return s.id == r.scenarioId
					end
				)
			if not holds then
				table.remove(open, i)
			end
		end
		-- open the highest-priority requests of citizens without one
		local candidates = {}
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			if self._showing[id] == nil and find(open, function(r)
				return r.entityId == id
			end) == nil then
				local scenario =
					ContentQuery.eligibleScenarios(self:_citizenCtx(c, base, rep), citizenState(c), now, shown)[1]
				if scenario then
					table.insert(candidates, { citizen = c, scenario = scenario })
				end
			end
		end
		table.sort(candidates, function(a, b)
			if a.scenario.priority ~= b.scenario.priority then
				return a.scenario.priority > b.scenario.priority
			end
			return a.citizen.id < b.citizen.id
		end)
		for _, candidate in candidates do
			if #open >= SocietyConfig.openRequests then
				break
			end
			local c, scenario = candidate.citizen, candidate.scenario
			table.insert(open, { entityId = c.id, scenarioId = scenario.id })
			self:_send(kid, {
				type = "thought",
				id = c.id,
				scenarioId = scenario.id,
				text = ContentQuery.fill(scenario.thought, self:_names(c, nil)),
				icon = scenario.icon or "request",
			})
		end
	end
end

function ConversationService:step(dt: number)
	local sim = self:_sim()
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		if k.alive and k.populated and (k.fedRatio or 1) < SocietyConfig.food.shortageBelow then
			self:_raise(kid, "shortage")
		end
	end
	local due = {}
	for i = #self._pending, 1, -1 do
		if sim.time >= self._pending[i].at then
			table.insert(due, 1, table.remove(self._pending, i))
		end
	end
	for _, job in due do
		job.run()
	end
	for i = #self._flows, 1, -1 do
		local flow = self._flows[i]
		local seconds = math.min(dt, flow.left)
		flow.left -= seconds
		flow.carry += flow.perSecond * seconds
		local whole = if flow.carry >= 0 then math.floor(flow.carry) else math.ceil(flow.carry)
		if whole ~= 0 then
			flow.carry -= whole
			self._seq += 1
			local tx = `decision-flow:{self._round}:{self._seq}`
			if whole > 0 then
				sim:deposit(flow.kingdomId, flow.resource, whole, tx, "decision:resource_over_time")
			else
				local take = math.min(-whole, sim:balance(flow.kingdomId, flow.resource))
				if take > 0 then
					sim:spend(flow.kingdomId, { [flow.resource] = take }, tx, "decision:resource_over_time")
				end
			end
		end
		if flow.left <= 0 then
			table.remove(self._flows, i)
		end
	end
end

function ConversationService:start()
	local host = self._match.host
	table.insert(
		self._connections,
		host.events:connect(function(name: string, event: any)
			self:_onEvent(name, event)
		end)
	)
	self._remotes:handle("Kingdom.Converse", function(player: any, entityId: number)
		return self:converse(player, entityId)
	end)
	self._remotes:handle(
		"Kingdom.Choose",
		function(player: any, entityId: number, scenarioId: string, responseId: string)
			return self:choose(player, entityId, scenarioId, responseId)
		end
	)
	self._running = true
	self._env.spawn(function()
		local sinceRefresh = 0
		while self._running do
			self._env.wait(STEP)
			if not self._running then
				break
			end
			local sim = self:_sim()
			if sim.active then
				self:step(STEP)
				sinceRefresh += STEP
				if sinceRefresh >= SocietyConfig.requestRefreshSeconds then
					sinceRefresh = 0
					self:refresh()
				end
			end
		end
	end)
end

function ConversationService:destroy()
	self._running = false
	for _, connection in self._connections do
		connection:disconnect()
	end
	self._connections = {}
end

return Def
