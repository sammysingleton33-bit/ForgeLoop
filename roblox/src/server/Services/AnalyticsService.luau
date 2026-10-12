--!strict
--[[
	AnalyticsService (FORGE-04) — the interfaces §8 adapter over Roblox AnalyticsService.

		AnalyticsService:event(player, name, fields?) -> boolean
		AnalyticsService:funnel(player, funnel, step, stepName, opts?: { sessionId: string?, fields: {[string]: string}? }) -> boolean
		AnalyticsService:economy(player, flow: "source" | "sink", currency, amount, balance, txType, item?) -> boolean
		AnalyticsService.stats -> { sent, failed, dropped = { [reason]: number } }
	Every method returns whether a request was handed to Roblox; none of them ever throws.

	Guarantees
	- Failure isolation: each Roblox call runs in pcall; errors are counted and warned at most once
	  per WARN_INTERVAL. An invalid config disables analytics (logged as error) instead of failing the boot.
	- Rate cap: one server bucket refilled at safety × (120 + 20 × players) per minute (event-types.md),
	  custom events stop at the customReserve fraction so funnels and economy keep budget, and a
	  per-player bucket stops one player (or a remote-driven loop) from using the server's budget.
	- Declared data only: names, value fields and CustomField01-03 mappings come from
	  games/<game>/config/Analytics.luau (analytics/schemas/events.md); undeclared events or fields
	  are dropped with a one-time warning; custom field values are sent as strings.
	- Funnels: the onboarding funnel uses LogOnboardingFunnelStepEvent; recurring funnels need a
	  sessionId (Roblox ignores repeated steps without one); repeated steps of one session are not
	  re-sent (they would count against the rate limit for nothing).
	- Every call (sent or dropped) is written to env.log as "analytics <kind> <name> ..." so Studio
	  walkthroughs can check the funnel order (Roblox records nothing from Studio).
	- Economy events: only EconomyService calls economy() (§7); nothing here derives them from
	  CurrencyChanged.

	Bus wiring (start): config.track rules are applied to GameEvents. Who an event is about comes
	from Experience/Subjects: framework events have defaults, and a game passes resolvers for its own
	events in config.subjects (e.g. game-001's G9 attribution rules). PlayerReady/PlayerRemoving drive
	SessionStart/SessionEnd and the Return funnel (config.session). DataService (optional,
	registry:find) supplies core.createdAt for days since first join.
]]

local AnalyticsConfig = require("@game/ReplicatedStorage/Forge/Config/Analytics")
local AnalyticsRouter = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsRouter")
local AnalyticsSchema = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsSchema")
local Bus = require("@game/ReplicatedStorage/Forge/Experience/Bus")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Subjects = require("@game/ReplicatedStorage/Forge/Experience/Subjects")

local AnalyticsService = {}
AnalyticsService.__index = AnalyticsService

local Def = { name = "AnalyticsService", dependencies = {} }

local WARN_INTERVAL = 60
local DAY = 86400
local DEFAULT_LIMITS = { perPlayerPerMinute = 30, safety = 0.8, customReserve = 0.25 }
local FLOWS = { source = "Source", sink = "Sink" }
local TX_ENUM_NAMES = {
	IAP = true,
	Shop = true,
	Gameplay = true,
	ContextualPurchase = true,
	TimedReward = true,
	Onboarding = true,
}

export type Options = { config: any?, bus: any? }

local function isPlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function asFieldValue(value: any): string?
	local kind = type(value)
	if kind == "string" then
		return value
	elseif kind == "number" then
		if not finite(value) then
			return nil
		end
		return if value % 1 == 0 then string.format("%d", value) else tostring(value)
	elseif kind == "boolean" then
		return if value then "true" else "false"
	end
	return nil
end

function Def.create(env: any, registry: any, options: Options?)
	local opts = options or {}
	local config = opts.config or AnalyticsConfig
	local bus = opts.bus or GameEvents
	local self = setmetatable({
		_env = env,
		_registry = registry,
		_config = config,
		_bus = bus,
		_limits = table.clone(DEFAULT_LIMITS),
		_enabled = true,
		_players = {},
		_warnedOnce = {},
		_lastWarn = {},
		_connections = {},
		_rulesByEvent = {},
		_tokens = 0,
		_capacity = 0,
		_lastRefill = env.clock(),
		stats = { sent = 0, failed = 0, dropped = {} },
	}, AnalyticsService)
	for key, value in (if type(config) == "table" and type(config.limits) == "table" then config.limits else {}) do
		self._limits[key] = value
	end
	local known = AnalyticsRouter.knownEvents(bus)
	local problems = AnalyticsSchema.validate(config, known)
	for _, problem in Subjects.validate(if type(config) == "table" then config.subjects else nil, known) do
		table.insert(problems, problem)
	end
	if #problems > 0 then
		self._enabled = false
		env.log("error", "analytics config invalid; analytics disabled", { problems = table.concat(problems, "; ") })
	end
	self:_refill() -- starts full: capacity grows from 0, and the growth is credited as tokens
	return self
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

-- ------------------------------------------------------------------ lifecycle

function AnalyticsService:start()
	if not self._enabled then
		return
	end
	local env = self._env
	self._data = self._registry:find("DataService")
	if env.RunService and env.RunService:IsStudio() then
		env.log(
			"info",
			"analytics: Studio session — calls are logged here but Roblox records nothing from Studio",
			{}
		)
	end
	for _, rule in self._config.track or {} do
		self._rulesByEvent[rule.on] = self._rulesByEvent[rule.on] or {}
		table.insert(self._rulesByEvent[rule.on], rule)
	end
	local handlers = {}
	for eventName in self._rulesByEvent do
		handlers[eventName] = function(...)
			self:_onBus(eventName, table.pack(...))
		end
	end
	local readyHandler = handlers.PlayerReady
	handlers.PlayerReady = function(player, ...)
		self:_sessionStart(player)
		if readyHandler then
			readyHandler(player, ...)
		end
	end
	local connections, missing = Bus.connectAll(self._bus, handlers)
	self._connections = connections
	if #missing > 0 then
		env.log("info", "analytics: waiting for bus events not declared yet", { events = table.concat(missing, ",") })
	end
	if env.Players and env.Players.PlayerRemoving then
		table.insert(
			self._connections,
			env.Players.PlayerRemoving:Connect(function(player)
				self:_sessionEnd(player)
			end)
		)
	end
end

function AnalyticsService:destroy()
	for _, connection in self._connections do
		if connection.Disconnect then
			connection:Disconnect()
		else
			connection:disconnect()
		end
	end
	table.clear(self._connections)
end

-- ------------------------------------------------------------------ bookkeeping

function AnalyticsService:_count(reason: string)
	self.stats.dropped[reason] = (self.stats.dropped[reason] or 0) + 1
end

function AnalyticsService:_warnOnce(key: string, message: string, fields: { [string]: any }?)
	if self._warnedOnce[key] then
		return
	end
	self._warnedOnce[key] = true
	self._env.log("warn", message, fields)
end

function AnalyticsService:_warnThrottled(key: string, message: string, fields: { [string]: any }?)
	local now = self._env.clock()
	local last = self._lastWarn[key]
	if last and now - last < WARN_INTERVAL then
		return
	end
	self._lastWarn[key] = now
	self._env.log("warn", message, fields)
end

function AnalyticsService:_state(player: any)
	local state = self._players[player.UserId]
	if state == nil then
		state = {
			joinedAt = nil,
			lastActivity = "Joined",
			sessions = {},
			sentSteps = {},
			tokens = self._limits.perPlayerPerMinute,
			lastRefill = self._env.clock(),
		}
		self._players[player.UserId] = state
	end
	return state
end

function AnalyticsService:_refill()
	local env = self._env
	local now = env.clock()
	local players = if env.Players then #env.Players:GetPlayers() else 0
	local perMinute = AnalyticsSchema.CAPS.requestsPerMinuteBase
		+ AnalyticsSchema.CAPS.requestsPerMinutePerPlayer * players
	local capacity = math.max(1, math.floor(perMinute * self._limits.safety))
	if capacity > self._capacity then
		self._tokens += capacity - self._capacity -- the allowance grows with the player count
	end
	self._capacity = capacity
	self._tokens = math.min(capacity, self._tokens + (now - self._lastRefill) * capacity / 60)
	self._lastRefill = now
end

-- Takes one request from the server bucket and the player's bucket; returns a drop reason or nil.
function AnalyticsService:_admit(player: any, kind: string): string?
	self:_refill()
	local state = self:_state(player)
	local now = self._env.clock()
	local perPlayer = self._limits.perPlayerPerMinute
	state.tokens = math.min(perPlayer, state.tokens + (now - state.lastRefill) * perPlayer / 60)
	state.lastRefill = now
	local floor = if kind == "event" then self._capacity * self._limits.customReserve else 0
	if self._tokens - 1 < floor then
		return "rate"
	end
	if state.tokens < 1 then
		return "playerRate"
	end
	self._tokens -= 1
	state.tokens -= 1
	return nil
end

function AnalyticsService:_log(kind: string, name: string, fields: { [string]: any })
	self._env.log("info", `analytics {kind} {name}`, fields)
end

function AnalyticsService:_drop(kind: string, name: string, reason: string, fields: { [string]: any }): boolean
	self:_count(reason)
	fields.sent = false
	fields.reason = reason
	self:_log(kind, name, fields)
	if reason == "rate" or reason == "playerRate" then
		self:_warnThrottled(
			"rate",
			"analytics: rate cap reached; requests dropped",
			{ dropped = (self.stats.dropped.rate or 0) + (self.stats.dropped.playerRate or 0) }
		)
	end
	return false
end

function AnalyticsService:_send(kind: string, name: string, logFields: { [string]: any }, method: string, ...): boolean
	local service = self._env.AnalyticsService
	if service == nil then
		return self:_drop(kind, name, "unavailable", logFields)
	end
	local ok, err = pcall(service[method], service, ...)
	if not ok then
		self.stats.failed += 1
		logFields.sent = false
		logFields.reason = "error"
		self:_log(kind, name, logFields)
		self:_warnThrottled(
			"error",
			"analytics: AnalyticsService call failed (gameplay unaffected)",
			{ method = method, error = tostring(err), failed = self.stats.failed }
		)
		return false
	end
	self.stats.sent += 1
	logFields.sent = true
	self:_log(kind, name, logFields)
	return true
end

-- Maps declared field names to CustomField01-03 (string values); returns the map and a problem, if any.
function AnalyticsService:_customFields(declared: { string }?, given: { [string]: any }?, skip: string?, where: string)
	local out = {}
	local list = declared or {}
	for key, value in given or {} do
		if key ~= skip then
			local index = table.find(list, key)
			if index == nil then
				self:_warnOnce(
					`field:{where}:{key}`,
					`analytics: field '{key}' is not declared for {where}; dropped`,
					{}
				)
			else
				local text = asFieldValue(value)
				if text == nil then
					self:_warnOnce(
						`fieldType:{where}:{key}`,
						`analytics: field '{key}' of {where} must be a string, number or boolean`,
						{}
					)
				else
					out[AnalyticsSchema.FIELD_KEYS[index]] = text
				end
			end
		end
	end
	return out
end

-- ------------------------------------------------------------------ §8 API

function AnalyticsService:event(player: any, name: string, fields: { [string]: any }?): boolean
	local logFields: { [string]: any } = { userId = if isPlayer(player) then player.UserId else nil }
	if not self._enabled then
		return self:_drop("event", tostring(name), "disabled", logFields)
	end
	if not isPlayer(player) then
		return self:_drop("event", tostring(name), "invalid", logFields)
	end
	local decl = self._config.events[name]
	if decl == nil then
		self:_warnOnce(
			`event:{tostring(name)}`,
			`analytics: custom event '{tostring(name)}' is not declared; dropped`,
			{}
		)
		return self:_drop("event", tostring(name), "undeclared", logFields)
	end
	local value: number? = nil
	if decl.value and fields and fields[decl.value] ~= nil then
		local given = fields[decl.value]
		if finite(given) then
			value = given
		else
			self:_warnOnce(`value:{name}`, `analytics: value '{decl.value}' of {name} must be a finite number`, {})
		end
	end
	local custom = self:_customFields(decl.fields, fields, decl.value, `event {name}`)
	logFields.value = value
	for key, text in custom do
		logFields[key] = text
	end
	local reason = self:_admit(player, "event")
	if reason then
		return self:_drop("event", name, reason, logFields)
	end
	self:_state(player).lastActivity = name
	return self:_send("event", name, logFields, "LogCustomEvent", player, name, value or 1, custom)
end

function AnalyticsService:funnel(player: any, funnel: string, step: number, stepName: string, opts: any?): boolean
	local logFields: { [string]: any } = { userId = if isPlayer(player) then player.UserId else nil, step = step }
	if not self._enabled then
		return self:_drop("funnel", tostring(funnel), "disabled", logFields)
	end
	if not isPlayer(player) then
		return self:_drop("funnel", tostring(funnel), "invalid", logFields)
	end
	local decl = self._config.funnels[funnel]
	if decl == nil then
		self:_warnOnce(
			`funnel:{tostring(funnel)}`,
			`analytics: funnel '{tostring(funnel)}' is not declared; dropped`,
			{}
		)
		return self:_drop("funnel", tostring(funnel), "undeclared", logFields)
	end
	local maxStep = if decl.steps then #decl.steps else AnalyticsSchema.HOUSE.stepsPerFunnel
	if type(step) ~= "number" or step % 1 ~= 0 or step < 1 or step > maxStep then
		self:_warnOnce(
			`step:{funnel}:{tostring(step)}`,
			`analytics: {funnel} step {tostring(step)} out of 1..{maxStep}`,
			{}
		)
		return self:_drop("funnel", funnel, "invalid", logFields)
	end
	local name = if decl.steps then decl.steps[step] else stepName
	if decl.steps and stepName ~= nil and stepName ~= name then
		self:_warnOnce(
			`stepName:{funnel}:{step}`,
			`analytics: {funnel} step {step} is '{name}', got '{tostring(stepName)}'`,
			{}
		)
	end
	if type(name) ~= "string" or name == "" then
		return self:_drop("funnel", funnel, "invalid", logFields)
	end
	logFields.stepName = name
	local sessionId = if type(opts) == "table" then opts.sessionId else nil
	if decl.kind == "recurring" and (type(sessionId) ~= "string" or sessionId == "") then
		self:_warnOnce(`session:{funnel}`, `analytics: recurring funnel {funnel} needs opts.sessionId; dropped`, {})
		return self:_drop("funnel", funnel, "missingSession", logFields)
	end
	logFields.sessionId = sessionId
	local state = self:_state(player)
	local dedupeKey = `{funnel}|{if decl.kind == "recurring" then sessionId else ""}|{step}`
	if state.sentSteps[dedupeKey] then
		return self:_drop("funnel", funnel, "duplicate", logFields)
	end
	local custom =
		self:_customFields(decl.fields, if type(opts) == "table" then opts.fields else nil, nil, `funnel {funnel}`)
	for key, text in custom do
		logFields[key] = text
	end
	local reason = self:_admit(player, "funnel")
	if reason then
		return self:_drop("funnel", funnel, reason, logFields)
	end
	state.sentSteps[dedupeKey] = true
	if decl.kind == "onboarding" then
		return self:_send("funnel", funnel, logFields, "LogOnboardingFunnelStepEvent", player, step, name, custom)
	end
	return self:_send(
		"funnel",
		funnel,
		logFields,
		"LogFunnelStepEvent",
		player,
		funnel,
		if decl.kind == "recurring" then sessionId else nil,
		step,
		name,
		custom
	)
end

local function flowEnum(flow: string): any
	local name = FLOWS[flow]
	local ok, item = pcall(function()
		return (Enum :: any).AnalyticsEconomyFlowType[name]
	end)
	return if ok and item ~= nil then item else name
end

function AnalyticsService:economy(
	player: any,
	flow: string,
	currency: string,
	amount: number,
	balance: number,
	txType: string,
	item: string?
): boolean
	local logFields: { [string]: any } = {
		userId = if isPlayer(player) then player.UserId else nil,
		flow = flow,
		amount = amount,
		balance = balance,
		txType = txType,
		item = item,
	}
	if not self._enabled then
		return self:_drop("economy", tostring(currency), "disabled", logFields)
	end
	local valid = isPlayer(player)
		and FLOWS[flow] ~= nil
		and type(currency) == "string"
		and currency ~= ""
		and finite(amount)
		and amount > 0
		and finite(balance)
		and balance >= 0
		and type(txType) == "string"
		and txType ~= ""
		and (item == nil or type(item) == "string")
	if not valid then
		self:_warnOnce(
			`economyInvalid:{tostring(currency)}:{tostring(txType)}`,
			"analytics: economy event rejected (flow source|sink, amount > 0, balance >= 0, txType string)",
			{}
		)
		return self:_drop("economy", tostring(currency), "invalid", logFields)
	end
	if not TX_ENUM_NAMES[txType] then
		self:_warnOnce(`txType:{txType}`, `analytics: custom transaction type '{txType}' (cap 20 per experience)`, {})
	end
	local reason = self:_admit(player, "economy")
	if reason then
		return self:_drop("economy", currency, reason, logFields)
	end
	self:_state(player).lastActivity = `Economy{FLOWS[flow]}`
	return self:_send(
		"economy",
		currency,
		logFields,
		"LogEconomyEvent",
		player,
		flowEnum(flow),
		currency,
		amount,
		balance,
		txType,
		item
	)
end

-- ------------------------------------------------------------------ bus rules

function AnalyticsService:_lookup()
	local players = self._env.Players
	return {
		byUserId = function(userId: number): any
			return if players then players:GetPlayerByUserId(userId) else nil
		end,
		all = function(): { any }
			return if players then players:GetPlayers() else {}
		end,
		registry = self._registry,
	}
end

function AnalyticsService:_sessionIdFor(player: any, rule: any, info: { [string]: any }): string?
	if rule.session == "match" then
		local id = info.matchId
		return if type(id) == "string" and id ~= "" then id else nil
	end
	local state = self:_state(player)
	local key = rule.key or rule.funnel
	local decl = self._config.funnels[rule.funnel]
	local ttl = decl.sessionTtlSec or 900
	local now = self._env.clock()
	if rule.session == "start" then
		local id = self._env.HttpService:GenerateGUID(false)
		state.sessions[key] = { id = id, at = now }
		return id
	end
	local current = state.sessions[key]
	if current and now - current.at <= ttl then
		return current.id
	end
	return nil
end

function AnalyticsService:_applyRule(rule: any, player: any, info: { [string]: any })
	if rule.event then
		local fields = AnalyticsRouter.eventFields(rule, info)
		self:event(player, rule.event, fields)
		return
	end
	local decl = self._config.funnels[rule.funnel]
	local sessionId = nil
	if decl.kind == "recurring" then
		sessionId = self:_sessionIdFor(player, rule, info)
		if sessionId == nil then
			self:_drop("funnel", rule.funnel, "noSession", { userId = player.UserId, step = rule.step })
			return
		end
	end
	self:funnel(player, rule.funnel, rule.step, decl.steps[rule.step], { sessionId = sessionId })
end

function AnalyticsService:_onBus(eventName: string, args: { any })
	local rules = self._rulesByEvent[eventName]
	if rules == nil then
		return
	end
	local subjects, err = Subjects.resolve(eventName, args, self:_lookup(), self._config.subjects)
	if err then
		self:_warnThrottled(
			`resolver:{eventName}`,
			`analytics: subjects resolver for {eventName} failed`,
			{ error = err }
		)
	end
	for _, subject in subjects do
		self:_state(subject.player).lastActivity = eventName
		for _, rule in rules do
			if AnalyticsRouter.matches(rule, subject.info) then
				self:_applyRule(rule, subject.player, subject.info)
			end
		end
	end
end

-- ------------------------------------------------------------------ sessions and return

function AnalyticsService:_createdAt(player: any): number?
	local data = self._data
	if data == nil then
		return nil
	end
	local ok, core = pcall(data.get, data, player, "core")
	if ok and type(core) == "table" and finite(core.createdAt) then
		return core.createdAt
	end
	return nil
end

function AnalyticsService:_sessionStart(player: any)
	if not self._enabled or not isPlayer(player) then
		return
	end
	local state = self:_state(player)
	if state.joinedAt ~= nil then
		return
	end
	state.joinedAt = self._env.clock()
	local session = self._config.session or {}
	local createdAt = self:_createdAt(player)
	local days = if createdAt then math.floor(self._env.now() / DAY) - math.floor(createdAt / DAY) else nil
	if session.startEvent then
		local visit = if days == nil then "unknown" elseif days == 0 then "firstDay" else "return"
		self:event(player, session.startEvent, { daysSinceFirstJoin = days, visit = visit })
	end
	if session.returnFunnel and days ~= nil then
		local decl = self._config.funnels[session.returnFunnel]
		if days == 0 then
			self:funnel(player, session.returnFunnel, 1, decl.steps[1])
		elseif days == 1 then
			self:funnel(player, session.returnFunnel, 2, decl.steps[2])
		end
	end
end

function AnalyticsService:_sessionEnd(player: any)
	local state = if isPlayer(player) then self._players[player.UserId] else nil
	if state == nil then
		return
	end
	local session = self._config.session or {}
	if self._enabled and session.endEvent and state.joinedAt then
		local seconds = math.floor(self._env.clock() - state.joinedAt)
		self:event(player, session.endEvent, { sessionSec = seconds, lastActivity = state.lastActivity })
	end
	self._players[player.UserId] = nil
end

return Def
