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
			Asking again while the answer is pending returns the same showing. Option cost? and risks? are
			ContentQuery.choicePreview(scenario, response, names) as given (G13.1 v0.4-g7: risks filled with
			this conversation's names, no "Risk" prefix); a scenario the names cannot fill returns nil and
			logs a warning, never a failed remote.
			G13.8 (additive): the result also carries look (CitizenLook), job, position (Vector3, where
			the citizen stands now) and kingdom; opening or re-asking holds the citizen for this ruler: it
			stops (intent "Talking"), faces the ruler's character and stays so for at most
			Society.conversationHoldSec. A citizen another ruler is holding returns nil.
			G13.8 v0.4-g10 (additive): the question is ContentQuery.questionFor's for this citizen (a variant by trait
			or condition, else the scenario's), picked once per showing and kept on a re-ask; `presentation` =
			{ emotion?, expression?, gesture?, delivery?, urgency?, variantId? } (Kingdom/ConversationTags: only
			SPEC §5.10 vocabulary; absent when the content has no tag).
		Kingdom.EndConversation(entityId) -> boolean   (G13.8) the panel closed: the hold ends (the showing
			stays open); own kingdom only, idempotent; false for a co-ruler's conversation
		Kingdom.Choose(entityId, scenarioId, responseId) -> (ok, { reaction, effects: { { kind, text } }, tone,
		                                                     band, emotion?, expression?, gesture?, delivery?,
		                                                     bubble_s? }?, reason?)
			G13.8 v0.4-g10: `reaction` is ContentQuery.reactionFor(responseId, loyalty)'s text, with the citizen's
			loyalty when asked (before this answer moves it): band "high" / "low" / "base", its tone and tags.
			After an answer the citizen stays held, facing the ruler, until Kingdom.EndConversation or at most
			Def.REACTION_HOLD_MAX (12 s, the UI's longest reading time) after Choose; an emergency or the ruler
			leaving still ends it at once (G13.8 v0.4-g9f).
			Answers the showing that Converse opened for this ruler, once (idempotent per showing). Refusal
			reasons (stable): not_in_match, unknown_citizen, phase (the match is not in an active phase: Lobby
			or Results; Converse returns nil then too), not_offered (no open showing for this ruler and
			scenario: never opened, already answered, or another ruler's), unknown_response (also: content the
			server cannot apply; any payment is refunded), not_eligible (the scenario no longer holds; the
			showing closes), cost (the kingdom cannot pay; the showing stays open).
	Effects of a choice (ContentQuery.fireDecision with the ruler's and the kingdom's farm histories, so the
	bundle is already decayed; ReputationService:farmHistories):
		- cost = decisionEffects(decision).cost, paid FIRST (txId decision:<round>:<entity>:<scenario>:<n>);
		  fireDecision runs only for a paid answer, so a refused payment records no firing;
		- resource_effects through the treasury;
		- reputation: ReputationService:apply(ruler, decisionId, rep, response text);
		- loyalty: every listener once under its closest relation (speaker > family > friends > rivals >
		  audience), as fireDecision's `listeners` give it (decisionLoyalty with the kingdom multiplier,
		  clamped to ContentQuery.LOYALTY_CLAMP; applied as given); the speaker's chemistry drifts
		  (ContentQuery.driftChemistry);
		- kingdom conditions (Kingdom/Reputation.applyConditions); memory_tag pinned on the speaker;
		  decision.<id> remembered for the ruler;
		- consequences (after delay_s; a chance < 1 rolls the match's random): productivity (sim:addProductivity;
		  a magnitude of -1 or below is a walk-out (D-042), sim:strike for duration_s, which no boost cancels;
		  summed productivity down to 0 also stops work), strike (the least loyal share of an occupation,
		  sim:strike), loyalty, morale / happiness / stability, unlock_scenario, memory (pinned),
		  resource_over_time (per second), unrest_pressure and desertion_risk (recorded for FL-0082), cue
		  (the speaker's id, else `entityIds`: the citizens it affected). A condition, unrest_pressure or
		  desertion_risk with duration_s > 0 is undone after it ("{magnitude} for {duration}"): exactly what
		  was applied comes off again;
		- `strike` on/off events (G13.3 v0.4-g6) listing exactly the citizens whose strike or walk-out
		  started, and later ended, one event per occupation;
		- a `reaction` event to the kingdom's members;
		- G9 CitizenAnswered(player, kingdomId, citizenId, decisionId, secondsOpen?) once, last (D-044 (3)):
		  secondsOpen is the server time since the request's bubble appeared, nil when there was none.
	Thought bubbles: every Society.requestRefreshSeconds, each ruled kingdom keeps up to Society.openRequests
	open requests: the highest-priority eligible scenario of citizens without one (thought ctx: the best
	reputation among its rulers, any ruler's decisions, SPEC §6.8). A request stays open while its showing
	waits for an answer and closes when answered (#77 N3); one that stops holding otherwise closes;
	every request still open goes to the members as a `thought` event again on each refresh (G13.3: the
	client bubble lasts Vfx.thoughtSec, so it stays up while the request is open, and a co-ruler who joins
	later sees it within one refresh); new ones are sent when they open.
	Events (G13.3) go through EntityService:sendKingdomEvent when EntityService runs (else they are dropped).
	Event flags for triggers: event.<tag> holds for Society.conversation.eventSeconds after the event
	(building_completed, keep_upgraded, soldiers_recruited, objective_captured), and event.shortage while the
	fed ratio is below Society.food.shortageBelow and that long after.
	API (server)
		ConversationService:converse(player, entityId), :choose(player, entityId, scenarioId, responseId)
		ConversationService:refresh()          -- one thought-bubble refresh (the loop calls it)
		ConversationService:step(dt)           -- consequences over time (the loop calls it)
		ConversationService:openRequests(kingdomId): { { entityId, scenarioId } }
		ConversationService:hasRequest(kingdomId, entityId): boolean   -- CitizenView.hasRequest (G13.2)
		ConversationService:announceRiot(kingdomId, citizens, on)     -- the rioters' own placard on or off (D-050 (1d))
		ConversationService:announceStrike(kingdomId, citizens, on)   -- strike events for a strike started
		                                       elsewhere (CitizenService:debugStrike); off follows when it ends
	Studio debug hook (G13.7 citizen.request, FORGE-05's DebugPresetService):
		ConversationService:debugRequest(kingdomId, entityId, scenarioId) -> (ok, message)
			entityId 0 / scenarioId "any" = the hook picks (a citizen without a request; its first eligible
			scenario). The request is forced: Converse shows it even if its trigger does not hold, Choose does
			not re-check the trigger for that showing, and refresh never closes it.
]]

local SocietyConfig = require("@game/ReplicatedStorage/Forge/Config/Society")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")
local Occupations = require("@game/ReplicatedStorage/Game/Content/Occupations")
local ConversationTags = require("@game/ReplicatedStorage/Game/Kingdom/ConversationTags")
local Reputation = require("@game/ReplicatedStorage/Game/Kingdom/Reputation")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
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
Def.REACTION_HOLD_MAX = 12 -- G13.8 v0.4-g9f: after Choose, held until EndConversation, at most this long
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

-- traits: questionFor picks a question variant by trait (SPEC §5.10); eligibility ignores them
local function citizenState(c: any): any
	return {
		id = c.id,
		occupation = if c.profile then c.profile.occupation else c.job,
		unlocked = c.unlocked,
		traits = if c.profile then c.profile.traits else nil,
	}
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
	elseif event.type == "strike" and (event.occupation == nil or #event.entityIds == 0) then
		return -- nobody's strike changed
	elseif event.entityIds and #event.entityIds > EventCodec.ID_LIST_MAX then
		event.entityIds = table.move(event.entityIds, 1, EventCodec.ID_LIST_MAX, 1, {})
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

-- The question this citizen is asked in this showing: ContentQuery.questionFor (a variant by trait or
-- condition, else the scenario's own), raw (not yet filled) so a re-ask can fill it again. `ctx` is the
-- citizen's ctx for the variants' conditions.
function ConversationService:_question(c: any, scenario: any, ctx: any): { [string]: any }
	local question = ContentQuery.questionFor(scenario.id, citizenState(c), ctx)
	if question == nil then -- cannot happen for a scenario ContentQuery gave us; stay on the plain question
		return { text = scenario.question }
	end
	return question
end

-- `question` is the showing's pinned question (Converse picks it once per showing: a re-ask must read the same
-- words even when a variant's condition has changed since, FORGE-07 FL-0110 Q3).
function ConversationService:_payload(
	c: any,
	scenario: any,
	userId: number,
	question: { [string]: any }
): { [string]: any }
	local names = self:_names(c, userId)
	local options = {}
	local responses = table.clone(scenario.responses)
	table.sort(responses, function(a, b)
		return a.order < b.order
	end)
	for _, response in responses do
		local option: { [string]: any } = { id = response.id, text = ContentQuery.fill(response.text, names) }
		-- G13.3 extras exactly as ContentQuery gives them (v0.4-g7): cost? and risks? = { { text, chance } },
		-- filled with this conversation's names; it errors on a placeholder the names do not cover
		local preview = ContentQuery.choicePreview(scenario.id, response.id, names)
		if preview then
			option.cost = preview.cost
			option.risks = preview.risks
		end
		table.insert(options, option)
	end
	local sim = self:_sim()
	local y = if sim.groundY then sim.groundY(c.x, c.z) else 0
	return {
		entityId = c.id,
		scenarioId = scenario.id,
		speaker = { name = c.name, occupation = names.occupation },
		question = ContentQuery.fill(question.text, names),
		options = options,
		-- G13.8 v0.4-g10: how the question is said (optional; nil adds no field)
		presentation = ConversationTags.question(question, (ContentQuery.presentation(scenario.id) or {}).urgency),
		-- G13.8 (additive): who the citizen is, how they look and where they stand right now
		look = if c.profile then Kit.normalizeLook(c.profile.look) else nil, -- only a validated look goes on the wire
		job = c.job,
		position = Vector3.new(c.x, y, c.z),
		kingdom = c.kingdomId,
	}
end

-- Holds the citizen for this ruler's conversation (G13.8): still, facing the ruler's character when it
-- has one, for Society.conversationHoldSec from now. Asking again extends the hold, but one showing can never
-- grant more than Society.conversationHoldMaxSec in all (D-050 (6a), FL-0122): the extension counts only the time
-- it adds, closing the panel (endConversation) gives the unused time back, and once the showing's allowance is
-- spent the ruler still gets the question but the citizen keeps working. Returns the payload for chaining.
function ConversationService:_hold(
	player: any,
	c: any,
	payload: { [string]: any },
	showing: { [string]: any }
): { [string]: any }
	local sim = self:_sim()
	local left = SocietyConfig.conversationHoldMaxSec - (showing.holdGranted or 0)
	local held = sim:isHeld(c)
	local base = if held then c.hold.untilTime else sim.time -- the hold already running ends here
	local extra = math.max(0, math.min(sim.time + SocietyConfig.conversationHoldSec - base, left))
	if extra <= 0 then
		return payload -- still held until `base`, or the allowance is spent: no new time
	end
	local ok, at = pcall(function()
		local character = player.Character
		local root = character and character.PrimaryPart
		return root and root.Position
	end)
	local face = if ok and typeof(at) == "Vector3" then at else nil
	sim:holdCitizen(c, base + extra - sim.time, face and face.X, face and face.Z, player.UserId)
	showing.holdGranted = (showing.holdGranted or 0) + extra
	return payload
end

function ConversationService:converse(player: any, entityId: number): { [string]: any }?
	local kingdomId, c = self:_ruled(player, entityId)
	local sim = self:_sim()
	if kingdomId == nil or c == nil or not sim.active then
		return nil -- outside an active phase (Lobby, Results) nobody brings the ruler a matter (#77 L3)
	end
	local userId = player.UserId
	if sim:isHeld(c) and c.hold.by ~= userId then
		return nil -- a co-ruler is talking to them right now (G13.8)
	end
	local base, rep = self:_kingdomCtx(kingdomId, userId)
	local ctx = self:_citizenCtx(c, base, rep)
	local showing = self._showing[entityId]
	if showing and showing.kingdomId == kingdomId then
		-- asked again before answering, by this ruler or a co-ruler (#107 M1): the same showing, while it
		-- still holds (a forced one always does); the ruler who asked last answers it
		local still = if showing.forced
			then ContentQuery.data.dialogue.scenarios[showing.scenarioId]
			else find(ContentQuery.eligibleScenarios(ctx, citizenState(c), self:_now(), nil), function(s)
				return s.id == showing.scenarioId
			end)
		if still then
			local ok, payload = pcall(self._payload, self, c, still, userId, showing.question)
			if ok then
				showing.userId = userId
				return self:_hold(player, c, payload, showing)
			end
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
	local forced = open ~= nil and open.forced == true
	local scenario = if forced
		then ContentQuery.data.dialogue.scenarios[open.scenarioId]
		else (open and find(eligible, function(s)
			return s.id == open.scenarioId
		end)) or eligible[1]
	if scenario == nil then
		return nil
	end
	local question = self:_question(c, scenario, ctx)
	local ok, payload = pcall(self._payload, self, c, scenario, userId, question)
	if not ok then
		-- content the server cannot show (e.g. a placeholder these names do not cover): nothing on the
		-- citizen's mind, and a warning for the content team, rather than a failed remote
		self._env.log("warn", "ConversationService: scenario cannot be shown", {
			scenario = scenario.id,
			entityId = entityId,
			error = tostring(payload),
		})
		return nil
	end
	local shownBefore = (shown[entityId] or {})[scenario.id] -- restored if the question is never answered
	ContentQuery.markShown(shown, entityId, scenario.id, now)
	-- the request stays open until it is answered (#77 N3): closing the panel without an answer leaves the
	-- thought up, and asking again shows the same question
	local entry = {
		scenarioId = scenario.id,
		userId = userId,
		kingdomId = kingdomId,
		question = question, -- pinned for the showing (a re-ask reads the same variant)
		forced = forced or nil,
		shownBefore = shownBefore,
		requestedAt = open and open.openedAt, -- nil when the citizen had no request bubble
		holdGranted = 0, -- seconds of hold this showing has taken (capped by Society.conversationHoldMaxSec)
	}
	self._showing[entityId] = entry
	self._reputation:rulerVisited(userId, entityId)
	return self:_hold(player, c, payload, entry)
end

-- Kingdom.EndConversation (G13.8): the ruler closed the panel; the citizen goes back to work. Own kingdom's
-- citizens only; idempotent (true when no conversation holds them any more); false for another kingdom's
-- citizen, a spectator, or a citizen a co-ruler is talking to. The showing stays open: asking again shows
-- the same question.
function ConversationService:endConversation(player: any, entityId: number): boolean
	local kingdomId, c = self:_ruled(player, entityId)
	if kingdomId == nil or c == nil then
		return false
	end
	local sim = self:_sim()
	if sim:isHeld(c) and c.hold.by ~= player.UserId then
		return false
	end
	local showing = self._showing[entityId]
	if showing and showing.holdGranted and sim:isHeld(c) then
		-- closing early gives the unused part of the hold back to the showing's allowance
		showing.holdGranted = math.max(0, showing.holdGranted - math.max(0, c.hold.untilTime - sim.time))
	end
	sim:releaseCitizen(c)
	return true
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

local function idsOf(citizens: { any }): { number }
	local out = table.create(#citizens)
	for i, c in citizens do
		out[i] = c.id
	end
	return out
end

local function changeLoyalty(c: any, delta: number)
	c.loyalty = math.clamp((c.loyalty or 50) + delta, 0, 100)
end

-- Runs fn once the simulation reaches now + seconds (step() drains the queue every second).
function ConversationService:_after(seconds: number, fn: () -> ())
	table.insert(self._pending, { at = self:_sim().time + seconds, run = fn })
end

function ConversationService:_applyConsequence(kingdomId: string, speaker: any, consequence: any)
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	if k == nil or not k.alive then
		return
	end
	local kind, magnitude, duration = consequence.kind, consequence.magnitude, consequence.duration_s
	local targets = targetsOf(sim, speaker, consequence.target)
	local affected = targets -- the citizens its cue shows on (a strike: only those struck)
	local wasStriking: { [any]: boolean } = {}
	for _, c in targets do
		wasStriking[c] = sim:isStriking(c)
	end
	if kind == "productivity" and magnitude <= -1 then
		-- a walk-out (D-042; SPEC §5.4 "-1 = one citizen's walk-out"): a strike for the duration that no boost
		-- cancels (builders_push +0.1 beside speaker_walkout_risk -1, #77 M1); boosts and smaller penalties
		-- keep adding up on working citizens, and still apply once the walk-out ends
		for _, c in targets do
			sim:strike(c, duration)
		end
	elseif kind == "productivity" then
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
		local struck = {}
		for i = 1, count do
			sim:strike(targets[i], duration)
			table.insert(struck, targets[i])
		end
		affected = struck
	elseif kind == "loyalty" then
		for _, c in targets do
			changeLoyalty(c, magnitude)
		end
	elseif kind == "morale" or kind == "happiness" or kind == "stability" then
		local _, applied = Reputation.applyConditions(k.conditions, { [kind] = magnitude })
		local delta = (applied :: any)[kind]
		if duration > 0 and delta ~= 0 then -- "{magnitude} for {duration}": what was applied comes off again
			self:_after(duration, function()
				if k.alive then
					Reputation.applyConditions(k.conditions, { [kind] = -delta })
				end
			end)
		end
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
		if duration > 0 then
			self:_after(duration, function()
				k.unrestPressure = (k.unrestPressure or 0) - magnitude
			end)
		end
	elseif kind == "desertion_risk" then
		for _, c in targets do
			c.desertionRisk = (c.desertionRisk or 0) + magnitude -- soldiers (VS-2)
		end
		if duration > 0 then
			self:_after(duration, function()
				for _, c in targets do
					c.desertionRisk = (c.desertionRisk or 0) - magnitude
				end
			end)
		end
	end
	if kind == "strike" or kind == "productivity" then -- a strike, or a walk-out (productivity down to 0)
		local started = {}
		for _, c in affected do
			if not wasStriking[c] and sim:isStriking(c) then
				table.insert(started, c)
			end
		end
		self:_sendStrike(kingdomId, started, true)
		self:_watchStrike(kingdomId, started, sim.time + duration)
	end
	if consequence.cue_id then
		local event: { [string]: any } = { type = "kcue", cue = consequence.cue_id }
		if consequence.target == "speaker" then
			event.id = speaker.id
		else
			event.occupation = string.match(consequence.target, "^occupation:(.+)$")
			event.entityIds = idsOf(affected) -- G13.3 v0.4-g6: the server picks who shows it
		end
		self:_send(kingdomId, event)
	end
end

-- Strike off for the citizens among `citizens` whose strike has ended by `at`; those still striking (a
-- longer strike or walk-out came on top) are checked again every second until it ends or they leave.
function ConversationService:_watchStrike(kingdomId: string, citizens: { any }, at: number)
	if #citizens == 0 then
		return
	end
	table.insert(self._pending, {
		at = at,
		run = function()
			local sim = self:_sim()
			local ended, still = {}, {}
			for _, c in citizens do
				if sim.citizens[c.id] == c then
					table.insert(if sim:isStriking(c) then still else ended, c)
				end
			end
			self:_sendStrike(kingdomId, ended, false)
			self:_watchStrike(kingdomId, still, sim.time + 1)
		end,
	})
end

-- One `strike` event marked EventCodec.RIOT listing exactly the rioters whose state changed: the client turns it
-- into a "riot" event with its own placard (D-050 (1d)). Each change goes out once per citizen.
function ConversationService:_sendRiot(kingdomId: string, citizens: { any }, on: boolean)
	local ids = {}
	for _, c in citizens do
		if (c.riotShown == true) ~= on then
			c.riotShown = on
			table.insert(ids, c.id)
		end
	end
	if #ids > 0 then
		self:_send(kingdomId, { type = "strike", occupation = EventCodec.RIOT, on = on, entityIds = ids })
	end
end

-- One `strike` event per occupation among `citizens`, listing exactly them (G13.3 v0.4-g6).
function ConversationService:_sendStrike(kingdomId: string, citizens: { any }, on: boolean)
	local byOccupation: { [string]: { number } } = {}
	local order = {}
	for _, c in citizens do
		if (c.strikeShown == true) == on then
			continue -- already shown so: each change goes out once
		end
		c.strikeShown = on
		local occupation = if c.profile then c.profile.occupation else c.job
		if byOccupation[occupation] == nil then
			byOccupation[occupation] = {}
			table.insert(order, occupation)
		end
		table.insert(byOccupation[occupation], c.id)
	end
	for _, occupation in order do
		self:_send(
			kingdomId,
			{ type = "strike", occupation = occupation, on = on, entityIds = byOccupation[occupation] }
		)
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
	if not self:_sim().active then
		return false, nil, "phase" -- Lobby or Results: the showing waits (#77 L3)
	end
	local userId = player.UserId
	local showing = self._showing[entityId]
	-- the ruler who asked last answers (a co-ruler who asks again takes the showing over, #107 M1)
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
		not showing.forced
		and find(ContentQuery.eligibleScenarios(ctx, citizenState(c), self:_now(), nil), function(s)
				return s.id == scenarioId
			end)
			== nil
	then
		self._showing[entityId] = nil
		self:_closeRequest(kingdomId, entityId)
		return false, nil, "not_eligible"
	end
	local sim = self:_sim()
	local loyaltyBefore = c.loyalty or 50 -- the citizen's loyalty when asked, before this answer moves it (reactionFor)
	local decision = ContentQuery.data.decisions[response.decision]
	local bundle = ContentQuery.decisionEffects(response.decision)
	if decision == nil or bundle == nil then
		return false, nil, "unknown_response"
	end
	-- everything that can fail is gathered before the payment (#77 L2)
	local now = self:_now()
	local rulerHistory, kingdomHistory = self._reputation:farmHistories(userId, kingdomId)
	local listeners = self:_listeners(c, decision.audience)
	-- pay first (decisionEffects cost, G13.1 v0.4-g7); only a paid answer records its firing
	local cost = bundle.cost
	self._seq += 1
	local tx = `decision:{self._round}:{entityId}:{scenarioId}:{self._seq}`
	if next(cost) ~= nil and not sim:spend(kingdomId, cost, tx, `decision:{response.decision}`) then
		return false, nil, "cost"
	end
	local fired, effects =
		pcall(ContentQuery.fireDecision, response.decision, rulerHistory, kingdomHistory, now, listeners)
	if not fired or effects == nil then
		-- content the server cannot apply: the payment goes back, and the content team gets a warning
		for resource, amount in cost do
			sim:deposit(kingdomId, resource, amount, `{tx}:refund:{resource}`, "refund")
		end
		self._env.log("warn", "ConversationService: decision cannot be applied", {
			decision = response.decision,
			entityId = entityId,
			error = tostring(effects),
		})
		return false, nil, "unknown_response"
	end
	self._showing[entityId] = nil -- answered: a second Choose for this showing is not_offered
	self:_closeRequest(kingdomId, entityId) -- and the request it came from is settled

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
	-- G13.8 v0.4-g10: the reaction is the loyalty band's (base, high or low), with its tags
	local line = ContentQuery.reactionFor(response.id, loyaltyBefore)
	local tags = ConversationTags.reaction(line)
	local reaction = ContentQuery.fill(if line then line.text else response.reaction, names)
	self:_send(kingdomId, { type = "reaction", id = entityId, text = reaction, tone = tags.tone })
	if c.hold and c.hold.by == userId then -- framed while the reaction is read: EndConversation, at most 12 s
		c.hold.untilTime = sim.time + Def.REACTION_HOLD_MAX
	end
	-- G9 (D-044 (3)): once per accepted answer, after its effects; the bus is server-only
	local secondsOpen = if showing.requestedAt then math.max(0, self:_now() - showing.requestedAt) else nil
	GameEvents.CitizenAnswered:fire(player, kingdomId, entityId, response.decision, secondsOpen)
	tags.reaction = reaction
	tags.effects = applied
	return true, tags, nil
end

-- Strike events for citizens whose strike started elsewhere (CitizenService:debugStrike): on now, and
-- off once each strike ends.
function ConversationService:announceStrike(kingdomId: string, citizens: { any }, on: boolean)
	self:_sendStrike(kingdomId, citizens, on)
	if on then
		self:_watchStrike(kingdomId, citizens, self:_sim().time + 1)
	end
end

-- The riot's own state (D-050 (1d)): the rioters' placard goes on or off; ConsequenceService calls both.
function ConversationService:announceRiot(kingdomId: string, citizens: { any }, on: boolean)
	self:_sendRiot(kingdomId, citizens, on)
end

-- ---------------------------------------------------------------- Studio debug hook (G13.7)
function ConversationService:debugRequest(kingdomId: string, entityId: number, scenarioId: string): (boolean, string?)
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	if k == nil then
		return false, `unknown kingdom {kingdomId}`
	end
	local base, rep = self:_kingdomCtx(kingdomId)
	local now = self:_now()
	local function firstEligible(c: any): any?
		return ContentQuery.eligibleScenarios(self:_citizenCtx(c, base, rep), citizenState(c), now, nil)[1]
	end
	local c, scenario
	if entityId ~= 0 then
		c = sim.citizens[entityId]
		if c == nil or c.kingdomId ~= kingdomId then
			return false, `no citizen {entityId} in {kingdomId}`
		end
	end
	if scenarioId ~= "any" then
		scenario = ContentQuery.data.dialogue.scenarios[scenarioId]
		if scenario == nil then
			return false, `unknown scenario {scenarioId}`
		end
	end
	if c == nil then
		for _, id in k.citizenIds do
			local candidate = sim.citizens[id]
			if self._showing[id] == nil and (scenario ~= nil or firstEligible(candidate) ~= nil) then
				c = candidate
				break
			end
		end
		if c == nil then
			return false, `no citizen of {kingdomId} can raise {scenarioId}`
		end
	end
	scenario = scenario or firstEligible(c)
	if scenario == nil then
		return false, `{c.name} has no eligible scenario; pass a scenarioId`
	end
	self:_closeRequest(kingdomId, c.id)
	self._open[kingdomId] = self._open[kingdomId] or {}
	self:_openRequest(kingdomId, self._open[kingdomId], c, scenario, true)
	return true, `{c.name} ({c.id}) raises {scenario.id}`
end

-- ---------------------------------------------------------------- thoughts and time
-- Opens a request and sends its thought; the record keeps the event, so every refresh can send it again.
function ConversationService:_openRequest(kingdomId: string, open: { any }, c: any, scenario: any, forced: boolean?)
	local thought = {
		type = "thought",
		id = c.id,
		scenarioId = scenario.id,
		text = ContentQuery.fill(scenario.thought, self:_names(c, nil)),
		icon = scenario.icon or "request",
	}
	table.insert(open, {
		entityId = c.id,
		scenarioId = scenario.id,
		forced = forced,
		thought = thought,
		openedAt = self:_now(), -- when the bubble appeared (CitizenAnswered secondsOpen, D-044 (3))
	})
	self:_send(kingdomId, thought)
end

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

-- True while the citizen has an open request (its thought bubble): CitizenService's CitizenView.hasRequest.
function ConversationService:hasRequest(kingdomId: string, entityId: number): boolean
	self:_sim() -- a new world (round) starts with no requests (#77 N5)
	return find(self._open[kingdomId] or {}, function(r)
		return r.entityId == entityId
	end) ~= nil
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
		-- a showing whose ruler has left this kingdom is nobody's to answer (#107 M2)
		for id, showing in self._showing do
			if
				showing.kingdomId == kid and (sim.citizens[id] == nil or table.find(k.rulers, showing.userId) == nil)
			then
				self._showing[id] = nil
				-- never answered: the question is not used up for the co-rulers who stay (G13.8)
				local stamps = shown[id]
				if stamps then
					stamps[showing.scenarioId] = showing.shownBefore
				end
			end
		end
		-- nor is a hold: a ruler who left mid-conversation frees the citizen for a co-ruler at once (G13.8)
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			if c and c.hold and table.find(k.rulers, c.hold.by) == nil then
				sim:releaseCitizen(c)
			end
		end
		-- close requests that no longer hold. One asked and not yet answered (#77 N3) stays while its matter
		-- does, judged without the shown history (asking marked it shown); when the matter has passed, its
		-- showing goes with it (#107 M2)
		for i = #open, 1, -1 do
			local r = open[i]
			local c = sim.citizens[r.entityId]
			local pending = self._showing[r.entityId] ~= nil
			local holds = c ~= nil
				and (
					r.forced
					or find(
							ContentQuery.eligibleScenarios(
								self:_citizenCtx(c, base, rep),
								citizenState(c),
								now,
								if pending then nil else shown
							),
							function(s)
								return s.id == r.scenarioId
							end
						)
						~= nil
				)
			if not holds then
				table.remove(open, i)
				local showing = self._showing[r.entityId]
				if showing and not showing.forced and showing.scenarioId == r.scenarioId then
					self._showing[r.entityId] = nil
				end
			end
		end
		-- the client's bubble lasts Vfx.thoughtSec (45 s): a request still open is sent again, which also
		-- shows it to a co-ruler who joined since (at most Society.openRequests per kingdom per refresh)
		for _, r in open do
			self:_send(kid, r.thought)
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
			self:_openRequest(kid, open, candidate.citizen, candidate.scenario)
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
	self._remotes:handle("Kingdom.EndConversation", function(player: any, entityId: number)
		return self:endConversation(player, entityId)
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
