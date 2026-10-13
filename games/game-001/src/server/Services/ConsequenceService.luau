--!strict
--[[
	ConsequenceService — the sustained kingdom consequences (FL-0082; living-kingdom §5, CONTRACTS G13.3/G13.4).
	Owner: FORGE-01. Server-authoritative: the rules read the simulation's real state (loyalty, obedience,
	memories, fed ratio, kingdom conditions) and every threshold comes from config Society (`strike`,
	`consequences`, all PROVISIONAL). The checks are pure (Sim/Consequences); this service applies the effects.

	Every rule needs its condition to hold without a break for its sustainSeconds, so no single decision is ever
	enough; each clears at its own end condition (a margin above the trigger) and starts its wait over.
	Rules, checked every consequences.tick seconds while the match is active, per living, populated kingdom:
		strike     an occupation where at least strike.shareOfOccupation of its citizens are aggrieved (loyalty
		           and obedience below the bars, carrying a grievance memory) → those citizens stop work until the
		           strikers' own mean loyalty rises above strike.endLoyaltyAbove. Strike events and the
		           strike_placard cue go out through ConversationService (G13.3 `strike`, v0.4-g6 entityIds).
		shortage   fed ratio below shortage.fedBelow → kingdom conditions move by shortage.conditions every
		           shortage.every seconds, unrest pressure rises by shortage.unrestPressure while it lasts, the
		           hungriest share grumble; ends at fed ratio >= endFedAbove.
		riot       stability minus unrest pressure below riot.stabilityBelow, and an instigator (the least loyal
		           citizen below instigatorLoyaltyBelow) → fire on the nearest finished building other than the
		           keep (hit points down by fireDamagePerSecond, never below fireFloor of its maximum; the building
		           carries `burning`, which WorldView shows as the Burning attribute) and the instigator plus up to
		           rioterShare of the disloyal stop work. Ends at stability >= endStabilityAbove or after
		           maxSeconds, then waits cooldownSeconds before another riot can start.
		rebellion  VS-2/3, consequences.rebellion.enabled = false in the slice: never checked. When enabled:
		           stability below stabilityBelow, at least disloyalShareAtLeast disloyal, and an instigator → the
		           disloyal citizens leave the kingdom (CitizenDied cause "rebelled"), then a cooldown.
	Cues use the G13.3 vocabulary only: strike_placard (strikers), grumble (hungry citizens, rioters), and at
	each start a cue with no entity ids, which shows on the HUD or the keep (G13.3).
	API
		ConsequenceService:step()                          -- one round of checks (the loop calls it)
		ConsequenceService:active(kingdomId): { strike: { [occupation]: { EntityId } }, shortage: boolean,
		                                       riot: { buildingId, instigator: EntityId, rioters }? }
		ConsequenceService:moraleState(kingdomId): "steady" | "retreat" | "surrender"
			-- army morale for battles (VS-2 combat; consequences.morale thresholds on the kingdom's morale)
		ConsequenceService:debugUnrest(kingdomId, seconds): (ok, message?)
			-- Studio only (command consequence.unrest <seconds>, preset vs1.riot; G13.7)
		ConsequenceService.changed: Signal<(kingdomId, rule, on: boolean, info)>   -- every start and end
			rule = "strike" | "shortage" | "riot" | "rebellion"; info carries the occupation, entity ids or
			building. Server-side: FORGE-04's notices need a G9 event (handoff 2026-10-13 FL-0082).
	Dependencies: MatchService. Optional (registry:find): CitizenService (obedience via reputationOf),
	ConversationService (strike events), EntityService (cues).
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local SocietyConfig = require("@game/ReplicatedStorage/Forge/Config/Society")
local Consequences = require("@game/ReplicatedStorage/Game/Sim/Consequences")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local People = require("@game/ReplicatedStorage/Game/Sim/People")
local Population = require("@game/ReplicatedStorage/Game/Sim/Population")
local Reputation = require("@game/ReplicatedStorage/Game/Kingdom/Reputation")

local ConsequenceService = {}
ConsequenceService.__index = ConsequenceService

local Def = { name = "ConsequenceService", dependencies = { "MatchService" } }

local DEBUG_PRESSURE = 100 -- debugUnrest: enough to hold effective stability below every riot bar

-- The running service, for the Studio debug command (registered once per process, like MatchService).
local active: any = nil

local function registerDebugCommands()
	for _, command in DebugCommands.list() do
		if command.name == "consequence.unrest" then
			return
		end
	end
	DebugCommands.register({
		name = "consequence.unrest",
		label = "Unrest in your kingdom for <seconds>: a riot after the sustained wait",
		args = { Validate.integer(30, 900) },
		run = function(player: any, seconds: number): string?
			if active == nil then
				return "no consequence service is running"
			end
			local kingdoms = active._registry:find("KingdomService")
			local kingdomId = if kingdoms then kingdoms:getKingdomOf(player) else nil
			if kingdomId == nil then
				return "you are not in a kingdom"
			end
			local _, message = active:debugUnrest(kingdomId, seconds)
			return message
		end,
	})
	DebugCommands.registerPreset({
		name = "vs1.riot",
		label = "FL-0082: five minutes of unrest, a riot after two",
		steps = { { "consequence.unrest", 300 } },
	})
end

function Def.new(env: any, registry: any)
	local self = setmetatable({}, ConsequenceService)
	self._env = env
	self._registry = registry
	self._match = registry:get("MatchService")
	self.changed = Signal.new()
	self.config = SocietyConfig -- specs may swap in a table of their own
	self._running = false
	self:_reset(nil)
	return self
end

function ConsequenceService:_reset(round: any)
	self._round = round
	self._state = {} :: { [string]: any }
end

function ConsequenceService:_sim(): any
	local match = self._match.host.match
	if match.roundId ~= self._round then
		self:_reset(match.roundId) -- a new world: every rule starts over
	end
	return match.sim
end

function ConsequenceService:_kingdomState(kid: string): any
	local state = self._state[kid]
	if state == nil then
		state = {
			tracker = Consequences.tracker(),
			strikes = {}, -- occupation -> the citizens it struck
			shortage = nil, -- { nextAt, pressure }
			riot = nil, -- { building, instigator, rioters, endsAt }
			riotCooldownUntil = -math.huge,
			rebellionCooldownUntil = -math.huge,
		}
		self._state[kid] = state
	end
	return state
end

function ConsequenceService:_now(): number
	return self:_sim().time
end

-- ---------------------------------------------------------------- outputs
function ConsequenceService:_cue(kid: string, cue: string, citizens: { any }?)
	if table.find(EventCodec.KINGDOM_CUES, cue) == nil then
		return
	end
	local event: { [string]: any } = { type = "kcue", cue = cue }
	if citizens then
		if #citizens == 0 then
			return
		end
		local ids = {}
		for i = 1, math.min(#citizens, EventCodec.ID_LIST_MAX) do
			ids[i] = citizens[i].id
		end
		event.entityIds = ids
	end
	local entities = self._registry:find("EntityService")
	if entities and entities.sendKingdomEvent then
		entities:sendKingdomEvent(kid, event)
	end
end

-- Off work for the next two checks; refreshed every check while the consequence lasts, so it ends by
-- itself shortly after the consequence does.
function ConsequenceService:_holdOffWork(citizens: { any })
	local sim = self:_sim()
	for _, c in citizens do
		if sim.citizens[c.id] == c then
			sim:strike(c, self.config.consequences.tick * 2)
		end
	end
end

function ConsequenceService:_announceStrike(kid: string, citizens: { any })
	local conversations = self._registry:find("ConversationService")
	if conversations and conversations.announceStrike then
		conversations:announceStrike(kid, citizens, true) -- the "off" goes out when each strike ends
	end
end

-- ---------------------------------------------------------------- inputs
function ConsequenceService:_citizens(k: any): { any }
	local sim = self:_sim()
	local out = {}
	for _, id in k.citizenIds do
		local c = sim.citizens[id]
		if c and c.alive ~= false then
			table.insert(out, c)
		end
	end
	return out
end

function ConsequenceService:_obedienceOf(kid: string): (any) -> number
	local citizens = self._registry:find("CitizenService")
	local rep = if citizens and citizens.reputationOf then citizens:reputationOf(kid) else People.startReputation()
	return function(c: any): number
		local traits = if c.profile then c.profile.traits else {}
		return Population.obedience(traits, rep, People.CONTENT)
	end
end

-- ---------------------------------------------------------------- rules
local function sortedKeys(map: { [string]: any }): { string }
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

function ConsequenceService:_strikes(kid: string, k: any, state: any, now: number)
	local cfg = self.config.strike
	local obedienceOf = self:_obedienceOf(kid)
	local byOccupation: { [string]: { any } } = {}
	local order = {}
	for _, c in self:_citizens(k) do
		local occupation = if c.profile then c.profile.occupation else c.job
		if byOccupation[occupation] == nil then
			byOccupation[occupation] = {}
			table.insert(order, occupation)
		end
		table.insert(byOccupation[occupation], c)
	end
	table.sort(order)
	for _, occupation in order do
		local members = byOccupation[occupation]
		local key = `strike:{occupation}`
		if state.strikes[occupation] then
			continue -- a strike in progress (below)
		end
		local aggrieved = {}
		for _, c in members do
			if Consequences.aggrieved(c, obedienceOf(c), cfg) then
				table.insert(aggrieved, c)
			end
		end
		local holds = #aggrieved > 0 and #aggrieved >= math.ceil(#members * cfg.shareOfOccupation)
		if Consequences.sustained(state.tracker, key, holds, now, cfg.sustainSeconds) then
			local strikers = Consequences.leastLoyal(aggrieved, #aggrieved)
			state.strikes[occupation] = strikers -- held off work by the loop below, this same check
			self:_announceStrike(kid, strikers)
			self:_cue(kid, "strike_placard", strikers)
			self.changed:fire(kid, "strike", true, { occupation = occupation, entityIds = Consequences.ids(strikers) })
		end
	end
	local sim = self:_sim()
	for _, occupation in sortedKeys(state.strikes) do
		local still, total = {}, 0
		for _, c in state.strikes[occupation] do
			if sim.citizens[c.id] == c then
				table.insert(still, c)
				total += c.loyalty or 50
			end
		end
		if #still == 0 or total / #still > cfg.endLoyaltyAbove then
			-- won back (the strikers' own mean loyalty) or nobody left: the holds run out within two checks
			state.strikes[occupation] = nil
			Consequences.forget(state.tracker, `strike:{occupation}`)
			self.changed:fire(kid, "strike", false, { occupation = occupation })
		else
			state.strikes[occupation] = still
			self:_holdOffWork(still)
		end
	end
end

function ConsequenceService:_shortage(kid: string, k: any, state: any, now: number)
	local cfg = self.config.consequences.shortage
	local fed = k.fedRatio or 1
	local shortage = state.shortage
	if shortage then
		if fed >= cfg.endFedAbove then
			k.unrestPressure = (k.unrestPressure or 0) - shortage.pressure
			state.shortage = nil
			Consequences.forget(state.tracker, "shortage")
			self.changed:fire(kid, "shortage", false, {})
		elseif now >= shortage.nextAt then
			shortage.nextAt = now + cfg.every
			Reputation.applyConditions(k.conditions, cfg.conditions)
		end
		return
	end
	if Consequences.sustained(state.tracker, "shortage", fed < cfg.fedBelow, now, cfg.sustainSeconds) then
		state.shortage = { nextAt = now + cfg.every, pressure = cfg.unrestPressure }
		k.unrestPressure = (k.unrestPressure or 0) + cfg.unrestPressure
		Reputation.applyConditions(k.conditions, cfg.conditions)
		local citizens = self:_citizens(k)
		table.sort(citizens, function(a, b)
			if (a.hunger or 0) ~= (b.hunger or 0) then
				return (a.hunger or 0) > (b.hunger or 0)
			end
			return a.id < b.id
		end)
		local hungry = table.move(citizens, 1, math.ceil(#citizens * cfg.grumbleShare), 1, {})
		self:_cue(kid, "grumble", hungry)
		self:_cue(kid, "grumble") -- the HUD/keep notice
		self.changed:fire(kid, "shortage", true, { entityIds = Consequences.ids(hungry) })
	end
end

function ConsequenceService:_riotTarget(k: any, instigator: any): any?
	local sim = self:_sim()
	local best, bestDistance = nil, math.huge
	for _, bid in k.buildingIds do
		local b = sim.buildings[bid]
		if b and not b.destroyed and b.level >= 1 and b.id ~= k.keepId then
			local d = (b.x - instigator.x) ^ 2 + (b.z - instigator.z) ^ 2
			if d < bestDistance or (d == bestDistance and best and b.id < best.id) then
				best, bestDistance = b, d
			end
		end
	end
	return best
end

function ConsequenceService:_endRiot(kid: string, state: any, now: number)
	local riot = state.riot
	riot.building.burning = nil
	state.riot = nil
	state.riotCooldownUntil = now + self.config.consequences.riot.cooldownSeconds
	Consequences.forget(state.tracker, "riot")
	self.changed:fire(kid, "riot", false, { buildingId = riot.building.id })
end

function ConsequenceService:_riot(kid: string, k: any, state: any, now: number)
	local cfg = self.config.consequences.riot
	local tick = self.config.consequences.tick
	local stability = Consequences.effectiveStability(k)
	local riot = state.riot
	if riot then
		local b = riot.building
		if stability >= cfg.endStabilityAbove or now >= riot.endsAt or b.destroyed then
			self:_endRiot(kid, state, now)
			return
		end
		local floor = math.ceil((b.maxHp or b.hp) * cfg.fireFloor)
		b.hp = math.max(math.min(b.hp, floor), b.hp - cfg.fireDamagePerSecond * tick)
		self:_holdOffWork(riot.rioters)
		return
	end
	local holds = now >= state.riotCooldownUntil and stability < cfg.stabilityBelow
	if not Consequences.sustained(state.tracker, "riot", holds, now, cfg.sustainSeconds) then
		return
	end
	local citizens = self:_citizens(k)
	local instigator = Consequences.instigator(citizens, cfg.instigatorLoyaltyBelow)
	local building = if instigator then self:_riotTarget(k, instigator) else nil
	if instigator == nil or building == nil then
		return -- unrest without anyone to lead it, or nothing to burn: no riot (the condition keeps holding)
	end
	local disloyal = {}
	for _, c in citizens do
		if c ~= instigator and (c.loyalty or 50) < cfg.rioterLoyaltyBelow then
			table.insert(disloyal, c)
		end
	end
	local rioters = Consequences.leastLoyal(disloyal, math.floor(#citizens * cfg.rioterShare))
	table.insert(rioters, 1, instigator)
	building.burning = true
	state.riot = { building = building, instigator = instigator, rioters = rioters, endsAt = now + cfg.maxSeconds }
	self:_holdOffWork(rioters)
	self:_announceStrike(kid, rioters)
	self:_cue(kid, "grumble", rioters)
	self:_cue(kid, "cower") -- the HUD/keep alarm
	self.changed:fire(kid, "riot", true, {
		buildingId = building.id,
		instigator = instigator.id,
		entityIds = Consequences.ids(rioters),
	})
end

function ConsequenceService:_rebellion(kid: string, k: any, state: any, now: number)
	local cfg = self.config.consequences.rebellion
	if not cfg.enabled then
		return -- gated off (the VS-1 slice): never even tracked
	end
	local citizens = self:_citizens(k)
	if #citizens == 0 then
		return
	end
	local obedienceOf = self:_obedienceOf(kid)
	local disloyal = {}
	for _, c in citizens do
		if (c.loyalty or 50) < cfg.disloyalBelow and obedienceOf(c) < cfg.obedienceBelow then
			table.insert(disloyal, c)
		end
	end
	local holds = now >= state.rebellionCooldownUntil
		and Consequences.effectiveStability(k) < cfg.stabilityBelow
		and #disloyal / #citizens >= cfg.disloyalShareAtLeast
		and Consequences.instigator(disloyal, cfg.disloyalBelow) ~= nil
	if not Consequences.sustained(state.tracker, "rebellion", holds, now, cfg.sustainSeconds) then
		return
	end
	local sim = self:_sim()
	local ids = Consequences.ids(disloyal)
	for _, c in disloyal do
		sim:killCitizen(c, "rebelled")
	end
	state.rebellionCooldownUntil = now + cfg.cooldownSeconds
	Consequences.forget(state.tracker, "rebellion")
	self:_cue(kid, "cower")
	self.changed:fire(kid, "rebellion", true, { entityIds = ids })
end

-- ---------------------------------------------------------------- API
function ConsequenceService:step()
	local sim = self:_sim()
	if not sim.active then
		return
	end
	local now = sim.time
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		if k.alive and k.populated then
			local state = self:_kingdomState(kid)
			self:_strikes(kid, k, state, now)
			if k.conditions then -- ReputationService keeps them (G13.4); without them only strikes apply
				self:_shortage(kid, k, state, now)
				self:_riot(kid, k, state, now)
				self:_rebellion(kid, k, state, now)
			end
		end
	end
end

function ConsequenceService:active(kingdomId: string): { [string]: any }
	self:_sim()
	local state = self._state[kingdomId]
	local out = { strike = {}, shortage = false, riot = nil :: any }
	if state == nil then
		return out
	end
	for occupation, struck in state.strikes do
		out.strike[occupation] = Consequences.ids(struck)
	end
	out.shortage = state.shortage ~= nil
	if state.riot then
		out.riot = {
			buildingId = state.riot.building.id,
			instigator = state.riot.instigator.id,
			rioters = Consequences.ids(state.riot.rioters),
		}
	end
	return out
end

function ConsequenceService:moraleState(kingdomId: string): string
	local k = self:_sim().kingdoms[kingdomId]
	local morale = if k and k.conditions then k.conditions.morale or 0 else 0
	return Consequences.moraleState(morale, self.config.consequences.morale)
end

-- Studio debug hook (G13.7, the consequence.unrest command): the kingdom's least loyal citizen drops to
-- loyalty 0 (the instigator) and DEBUG_PRESSURE unrest pressure holds for `seconds`, so the riot rule sees
-- sustained instability. The rule itself is unchanged: the riot still waits riot.sustainSeconds.
function ConsequenceService:debugUnrest(kingdomId: string, seconds: number): (boolean, string?)
	local k = self:_sim().kingdoms[kingdomId]
	if k == nil or not k.alive or not k.populated then
		return false, `no living, populated kingdom {tostring(kingdomId)}`
	end
	local citizens = self:_citizens(k)
	if #citizens == 0 then
		return false, "the kingdom has no citizens"
	end
	Consequences.leastLoyal(citizens, 1)[1].loyalty = 0
	k.unrestPressure = (k.unrestPressure or 0) + DEBUG_PRESSURE
	self._env.spawn(function()
		self._env.wait(seconds)
		k.unrestPressure = (k.unrestPressure or 0) - DEBUG_PRESSURE -- this kingdom record, even after a new world
	end)
	local wait = self.config.consequences.riot.sustainSeconds
	return true, `unrest for {seconds} s in {kingdomId}: a riot starts in about {wait} s`
end

function ConsequenceService:start()
	self._running = true
	active = self
	registerDebugCommands()
	self._env.spawn(function()
		while self._running do
			self._env.wait(self.config.consequences.tick)
			if self._running then
				local ok, err = pcall(self.step, self)
				if not ok then
					self._env.log("error", "ConsequenceService: step failed", { error = tostring(err) })
				end
			end
		end
	end)
end

function ConsequenceService:destroy()
	self._running = false
	if active == self then
		active = nil
	end
end

return Def
