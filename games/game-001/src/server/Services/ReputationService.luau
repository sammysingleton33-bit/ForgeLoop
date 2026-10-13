--!strict
--[[
	ReputationService — each ruler's six-category reputation, the kingdom conditions (happiness, stability,
	morale) and the citizens' loyalty reactions to the ruler's acts (CONTRACTS G13.4; FL-0080; content/SPEC.md
	§6, §8). Owner: FORGE-01.

	API (G13.4)
		ReputationService:get(userId): { values: { [Category]: number }, history: { { t, category, delta,
		                               text, source } } }      -- copies; t is server time (GetServerTimeNow)
		ReputationService:apply(userId, source, delta, text): { [Category]: number }   -- the applied amounts;
		                               delta is already decayed (ContentQuery.fireDecision); clamps 0..100
		ReputationService:getKingdomReputation(kingdomId): { [Category]: number }
			-- the highest value of each category among the kingdom's current rulers (SPEC §6.8 thoughts);
			   the content starts when it has none. CitizenService reads it for obedience.
		ReputationService:getConditions(kingdomId): { happiness, stability, morale }?
		ReputationService:fireAction(event, kingdomId, opts?)   -- one action event (SPEC §6.9), e.g.
			"RulerVisited"; opts = { rulers?: { userId } (default: every current ruler), speaker?: entityId,
			events?: { tag } (event.<tag> flags), before?: { buildingId, level } (Sim/Context) }
		ReputationService:rulerVisited(userId, entityId)        -- RulerVisited (audience speaker), for
		                                                           conversations (FL-0079); also the
		                                                           citizen's rulerVisited memory and mood
		                                                           lift (sim:rulerVisit, G5)
		ReputationService:farmHistories(userId, kingdomId): (rulerHistory, kingdomHistory)
			-- the anti-farming histories (SPEC §6.8) ConversationService hands ContentQuery.fireDecision
		ReputationService:values(userId): { [Category]: number }   -- a copy of the ruler's current values
	Remotes (G13.4): Kingdom.GetReputation() -> { values, history (latest Society.historySent), kingdom }
	for the asker (nil for a spectator); Kingdom.Reputation(the same) to a ruler when it changes.

	Action events → content (ContentQuery, one effect path for every service):
		simulation BuildingCompleted   → BuildingCompleted:<type> (level 1, credited to the ruler who placed
		                                 it) / BuildingUpgraded:<type> (credited to the ruler who started the
		                                 upgrade: UpgradeStarted.by); its conditions see the kingdom as it was
		                                 just before (Context `before`: the need the building answered)
		RecruitQueued                  → UnitsRecruited (the recruiting ruler)
		Credit (SPEC §6.9): the act's actor while they rule this kingdom; nobody when the actor has left (the
		kingdom's conditions and its citizens still react); every ruler when the act has no actor.
		ObjectiveCaptured              → ObjectiveCaptured for the captor, ObjectiveLost for the old owner
		MatchPhaseChanged              → MatchPhaseChanged:<phase> for every kingdom (event.shortage if it had
		                                 a shortage that phase), then PhaseEndedWellFed:<ended phase> when its
		                                 lowest fed ratio stayed >= Society.food.wellFedAtLeast
		fed ratio below Society.food.shortageBelow (once per dip) → FoodShortage
	Every firing comes from ContentQuery.fireAction (the single anti-farming point, #67) and is applied as
	given: its rows whose kingdom condition holds, decayed per row by the farm histories, then
		- each credited ruler (firing.rulers): reputation += guardRules(rep), decayed by its own history;
		- the kingdom, once: conditions += kingdom (decayed by the kingdom history), capped per application
		  (Kingdom/Reputation.applyConditions);
		- each citizen who hears a row: loyalty += its listener loyalty (the rows it hears summed, clamped
		  once to LOYALTY_CLAMP of its relation), then kept within 0..100.
		Farm histories: one per ruler (reputation), one per kingdom (conditions, loyalty) (SPEC §6.5, §6.8);
		one fireAction call per event (G13.1 v0.4-g7), so each history records a firing once.
	Additive: service.content = the ContentQuery query it reads (specs may pass ContentQuery.new(...)).
	Every second while the match runs: conditions drift toward their food/housing targets; a ruler's fear
	above its start fades by Society.fear.relaxPerMinute (one history entry a minute). A new world (round)
	starts fresh ledgers, histories and conditions.
]]

local SocietyConfig = require("@game/ReplicatedStorage/Forge/Config/Society")
local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")
local ReputationContent = require("@game/ReplicatedStorage/Game/Content/Reputation")
local Reputation = require("@game/ReplicatedStorage/Game/Kingdom/Reputation")
local Context = require("@game/ReplicatedStorage/Game/Sim/Context")

local ReputationService = {}
ReputationService.__index = ReputationService

local Def = { name = "ReputationService", dependencies = { "MatchService", "RemoteService" } }

local FEAR_RELAX_EVERY = 60 -- seconds between fear relaxation steps

function Def.new(env: any, registry: any)
	local self = setmetatable({}, ReputationService)
	self._env = env
	self._registry = registry
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	self._connections = {} :: { any }
	self._running = false
	self.content = ContentQuery -- the content query (specs may pass ContentQuery.new(...))
	self:_reset(nil)
	return self
end

function ReputationService:_reset(roundId: string?)
	self._round = roundId
	self._ledgers = {} :: { [number]: any }
	self._rulerFarm = {} :: { [number]: any }
	self._kingdomFarm = {} :: { [string]: any }
	self._food = {} :: { [string]: { low: number, shortage: boolean, below: boolean } }
	self._upgradedBy = {} :: { [string]: number } -- buildingId -> the ruler who started its upgrade (#68 M1)
	self._fearClock = 0
	self._sent = {} :: { [any]: string }
end

function ReputationService:_now(): number
	return self._env.serverTimeNow()
end

-- The current world; a new round starts every ledger and history over and gives kingdoms conditions.
function ReputationService:_sim(): any
	local match = self._match.host.match
	if match.roundId ~= self._round then
		self:_reset(match.roundId)
	end
	local sim = match.sim
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		if k.conditions == nil then
			k.conditions = Reputation.newConditions()
		end
		if self._food[kid] == nil then
			self._food[kid] = { low = k.fedRatio or 1, shortage = false, below = false }
		end
	end
	return sim
end

function ReputationService:_ledger(userId: number): any
	self:_sim()
	local ledger = self._ledgers[userId]
	if ledger == nil then
		ledger = Reputation.newLedger(ReputationContent.categories)
		self._ledgers[userId] = ledger
	end
	return ledger
end

-- ---------------------------------------------------------------- API
function ReputationService:get(userId: number): { values: { [string]: number }, history: { any } }
	return Reputation.view(self:_ledger(userId))
end

function ReputationService:apply(userId: number, source: string, delta: { [string]: number }, text: string)
	assert(type(userId) == "number", "ReputationService:apply: userId must be a number")
	assert(type(delta) == "table", "ReputationService:apply: delta must be a table")
	local applied, ignored = Reputation.apply(self:_ledger(userId), source, delta, text, self:_now())
	if #ignored > 0 then
		self._env.log("warn", "ReputationService: ignored reputation keys", {
			source = source,
			keys = table.concat(ignored, ","),
		})
	end
	return applied
end

function ReputationService:getKingdomReputation(kingdomId: string): { [string]: number }
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	local best: { [string]: number } = {}
	for _, userId in if k then k.rulers else {} do
		for category, value in self:_ledger(userId).values do
			best[category] = math.max(best[category] or -math.huge, value)
		end
	end
	if next(best) == nil then
		for category, def in ReputationContent.categories do
			best[category] = def.start
		end
	end
	return best
end

function ReputationService:getConditions(kingdomId: string): { [string]: number }?
	local k = self:_sim().kingdoms[kingdomId]
	return if k then table.clone(k.conditions) else nil
end

-- A delta as the History tab shows it: whole numbers as "+2" / "-1", a decayed one to one decimal ("+0.6").
local function signed(d: number): string
	local r = math.floor(math.abs(d) * 10 + 0.5) / 10
	local text = if r == math.floor(r) then string.format("%d", r) else string.format("%.1f", r)
	return (if d < 0 then "-" else "+") .. text
end

-- The history text for a firing: its rows' notice (content), else a plain line from what it changed for
-- this ruler ("Authority +1, Fear +1"). Never an action id: players read this (FORGE-05, FL-0089 check).
local function noticeOf(firing: any, rep: { [string]: any }): string
	for _, row in firing.rows do
		if row.notice and row.notice ~= "" then
			return row.notice
		end
	end
	local parts = {}
	for _, category in Reputation.CATEGORIES do
		local d = rep[category]
		if type(d) == "number" and math.floor(math.abs(d) * 10 + 0.5) > 0 then
			local def = ReputationContent.categories[category]
			table.insert(parts, `{if def and def.name then def.name else category} {signed(d)}`)
		end
	end
	return if #parts > 0 then table.concat(parts, ", ") else "Your reputation changed"
end

function ReputationService:_rulerHistory(userId: number): any
	local farm = self._rulerFarm[userId] or {}
	self._rulerFarm[userId] = farm
	return farm
end

function ReputationService:fireAction(event: string, kingdomId: string, opts: { [string]: any }?)
	local options = opts or {}
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	if k == nil or not k.alive then
		return
	end
	local match = self._match.host.match
	local ctx =
		Context.kingdom(sim, kingdomId, { phase = match.state, events = options.events, before = options.before })
	if #self.content.actionFirings(event, ctx) == 0 then
		return -- nothing applies: no listeners to build, no firing recorded
	end
	local now = self:_now()
	local rulers = options.rulers or k.rulers
	local kingdomFarm = self._kingdomFarm[kingdomId] or {}
	self._kingdomFarm[kingdomId] = kingdomFarm
	local listeners = {}
	for _, cid in k.citizenIds do
		local c = sim.citizens[cid]
		table.insert(listeners, {
			citizen = c,
			occupation = if c.profile then c.profile.occupation else c.job,
			speaker = options.speaker == cid,
			traits = if c.profile then c.profile.traits else {},
			chemistry = c.chemistry,
			ctx = Context.citizen(sim, c, ctx),
		})
	end
	-- one call per event (CONTRACTS G13.1 v0.4-g7): each credited ruler's reputation decays by its own
	-- history; the kingdom's conditions and the listeners' loyalty apply once, by the kingdom history
	local histories = {}
	for _, userId in rulers do
		histories[userId] = self:_rulerHistory(userId)
	end
	for _, firing in self.content.fireAction(event, ctx, histories, rulers, kingdomFarm, now, listeners) do
		for _, credit in firing.rulers do
			local guarded = Reputation.guardRules(event, credit.rep)
			self:apply(credit.ruler, firing.id, guarded, noticeOf(firing, guarded))
		end
		Reputation.applyConditions(k.conditions, firing.kingdom)
		for _, heard in firing.listeners do -- decayed and clamped once per listener: applied as given
			local c = heard.citizen
			if heard.loyalty ~= 0 then
				c.loyalty = math.clamp((c.loyalty or 50) + heard.loyalty, 0, 100)
			end
		end
	end
end

function ReputationService:farmHistories(userId: number, kingdomId: string): (any, any)
	self:_sim()
	local kingdom = self._kingdomFarm[kingdomId] or {}
	self._kingdomFarm[kingdomId] = kingdom
	return self:_rulerHistory(userId), kingdom
end

function ReputationService:values(userId: number): { [string]: number }
	return table.clone(self:_ledger(userId).values)
end

function ReputationService:rulerVisited(userId: number, entityId: number)
	local kingdomId = self._match.host.match:kingdomOf(userId)
	if kingdomId then
		self:fireAction("RulerVisited", kingdomId, { rulers = { userId }, speaker = entityId })
		-- the citizen remembers it and cheers up, at most once per few minutes (CONTRACTS G5 reaction)
		local sim = self:_sim()
		local c = sim.citizens[entityId]
		if c and c.kingdomId == kingdomId then
			sim:rulerVisit(c, userId)
		end
	end
end

-- ---------------------------------------------------------------- simulation events
-- The rulers an act is credited to: its actor while they still rule this kingdom; nobody when the actor
-- has left (SPEC §6.9 allows no credited ruler: the kingdom and its citizens still react, #68 L1); every
-- ruler when the act has no actor (a starting building, the AI, a debug command).
function ReputationService:_credited(kingdom: any, userId: number?): { number }
	if userId == nil then
		return kingdom.rulers
	end
	return if table.find(kingdom.rulers, userId) then { userId } else {}
end

function ReputationService:_onEvent(name: string, event: any)
	local sim = self:_sim()
	if name == "UpgradeStarted" then
		self._upgradedBy[event.buildingId] = event.by -- nil (no actor) clears an older one
	elseif name == "ConstructionCancelled" or name == "BuildingDestroyed" then
		self._upgradedBy[event.buildingId] = nil
	elseif name == "BuildingCompleted" then
		local k = sim.kingdoms[event.kingdomId]
		local b = sim.buildings[event.buildingId]
		local upgrader = self._upgradedBy[event.buildingId]
		self._upgradedBy[event.buildingId] = nil
		if k and b then
			-- a new building is the placer's; an upgrade is whoever started it (#68 M1: the keep has no placer)
			local upgrade = event.level > 1
			self:fireAction(`{if upgrade then "BuildingUpgraded" else "BuildingCompleted"}:{b.kind}`, k.id, {
				rulers = self:_credited(k, if upgrade then upgrader else b.placedBy),
				before = { buildingId = b.id, level = event.level }, -- judge the need it answered
			})
		end
	elseif name == "RecruitQueued" then
		local k = sim.kingdoms[event.kingdomId]
		if k then
			self:fireAction("UnitsRecruited", k.id, { rulers = self:_credited(k, event.by) })
		end
	elseif name == "ObjectiveCaptured" then
		self:fireAction("ObjectiveCaptured", event.kingdomId)
		if event.previousOwner and event.previousOwner ~= event.kingdomId then
			self:fireAction("ObjectiveLost", event.previousOwner)
		end
	elseif name == "MatchPhaseChanged" then
		for _, kid in sim.kingdomOrder do
			local food = self._food[kid]
			local events = if food.shortage then { "shortage" } else nil
			self:fireAction(`MatchPhaseChanged:{event.phase}`, kid, { events = events })
			if event.previous and food.low >= SocietyConfig.food.wellFedAtLeast and not food.shortage then
				self:fireAction(`PhaseEndedWellFed:{event.previous}`, kid)
			end
			local k = sim.kingdoms[kid]
			self._food[kid] = { low = k.fedRatio or 1, shortage = false, below = food.below }
		end
	end
end

-- ---------------------------------------------------------------- upkeep loop
function ReputationService:step(dt: number)
	local sim = self:_sim()
	local match = self._match.host.match
	if sim.active then
		for _, kid in sim.kingdomOrder do
			local k = sim.kingdoms[kid]
			if k.alive and k.populated then
				local fed = k.fedRatio or 1
				local food = self._food[kid]
				food.low = math.min(food.low, fed)
				if fed < SocietyConfig.food.shortageBelow then
					if not food.below then
						food.below = true
						food.shortage = true
						self:fireAction("FoodShortage", kid, { events = { "shortage" } })
					end
				else
					food.below = false
				end
				Reputation.driftConditions(k.conditions, Context.kingdom(sim, kid, { phase = match.state }), dt)
			end
		end
		self._fearClock += dt
		if self._fearClock >= FEAR_RELAX_EVERY then
			self._fearClock -= FEAR_RELAX_EVERY
			self:_relaxFear()
		end
	end
	self:_push()
end

function ReputationService:_relaxFear()
	local start = ReputationContent.categories.fear.start
	for _, ledger in self._ledgers do
		local above = ledger.values.fear - start
		if above > 0 then
			local amount = math.min(SocietyConfig.fear.relaxPerMinute, above)
			Reputation.apply(ledger, "fear_relax", { fear = -amount }, "Fear fades without new threats", self:_now())
		end
	end
end

function ReputationService:payload(userId: number): { [string]: any }?
	local match = self._match.host.match
	local kingdomId = match:kingdomOf(userId)
	if kingdomId == nil then
		return nil
	end
	local view = Reputation.view(self:_ledger(userId), SocietyConfig.historySent)
	local conditions = self:getConditions(kingdomId) :: any
	return {
		values = view.values,
		history = view.history,
		kingdom = { happiness = conditions.happiness, stability = conditions.stability, morale = conditions.morale },
	}
end

local function signature(payload: { [string]: any }): string
	local parts = {}
	for category, value in payload.values do
		table.insert(parts, `{category}={math.floor(value * 100 + 0.5)}`)
	end
	table.sort(parts)
	local last = payload.history[#payload.history]
	local k = payload.kingdom
	return `{table.concat(parts, ",")}|{#payload.history}|{if last then last.t else 0}|{math.floor(k.happiness + 0.5)},{math.floor(
		k.stability + 0.5
	)},{math.floor(k.morale + 0.5)}`
end

function ReputationService:_push()
	local seen = {}
	for _, player in self._env.Players:GetPlayers() do
		seen[player] = true
		local payload = self:payload(player.UserId)
		local sig = if payload then signature(payload) else ""
		if sig ~= (self._sent[player] or "") then
			self._sent[player] = sig
			if payload then
				self._remotes:fire("Kingdom.Reputation", player, payload)
			end
		end
	end
	for player in self._sent do
		if not seen[player] then
			self._sent[player] = nil
		end
	end
end

function ReputationService:start()
	local host = self._match.host
	table.insert(
		self._connections,
		host.events:connect(function(name: string, event: any)
			self:_onEvent(name, event)
		end)
	)
	self._remotes:handle("Kingdom.GetReputation", function(player: any)
		return self:payload(player.UserId)
	end)
	self._running = true
	local every = SocietyConfig.pushEvery
	self._env.spawn(function()
		while self._running do
			self._env.wait(every)
			if self._running then
				self:step(every)
			end
		end
	end)
end

function ReputationService:destroy()
	self._running = false
	for _, connection in self._connections do
		connection:disconnect()
	end
	self._connections = {}
end

return Def
