--!strict
--[[
	OnboardingService (FORGE-04) — runs the tutorial flows of games/<game>/config/Onboarding.luau
	for every player, server-authoritatively (engine: Experience/Onboarding).

	Lifecycle per player and flow
		flow.startOn (default PlayerReady; game-001: KingdomJoined)
		                       restore progress from experience.onboarding (SettingsService: persistent
		                       with DataService, session-only without it, D-027), begin the flow (auto
		                       steps), push Experience.OnboardingState to the client
		bus events             complete or pre-satisfy steps; who an event is about comes from
		                       Experience/Subjects (framework defaults + the config's `subjects`
		                       resolvers for game events, e.g. game-001's G9 attribution rules)
		Experience.OnboardingAction(flowId, action)   client-observed actions; only the current step
		Experience.OnboardingSkip(flowId)             skip: OnboardingSkipped, then no funnel step ever again
		every second           nudge escalation (OnboardingHintEscalated) and auto-advance of info steps
		                       (and of client steps that set autoAdvanceSec, so nothing stalls)
		a step's `requires`    a service missing from this server (registry:find at start) passes that step
		                       over (via "unavailable"), e.g. AnswerCitizen before ConversationService exists
	On each completed step: persist (SettingsService:update "onboarding"), AnalyticsService:funnel
	("Onboarding", index, id) for the funnel flow, GameEvents.OnboardingStep(player, flow, index, id),
	the step reward through EconomyService:grant (txId "onboarding:<flow>:<step>:<userId>", idempotent),
	and a new state for the client. On the last step: OnboardingCompleted (value = seconds) and the
	flow's completeReward.
	A step passed over (via "unavailable") or an interactive step that timed out is still logged as its
	funnel step: Roblox counts a skipped intermediate step as completed anyway, so leaving it out would
	change nothing. It is also logged as OnboardingStepPassed (value = step; stepName, via), so the
	dashboard can tell players who did the step from players who were moved past it.

		OnboardingService:state(player, flowId?) -> snapshot?      -- Onboarding.snapshot
		OnboardingService:skip(player, flowId) -> boolean
		OnboardingService:action(player, flowId, action) -> boolean
	Never blocks play: nothing here freezes, teleports or gates the player.
]]

local AnalyticsRouter = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsRouter")
local Bus = require("@game/ReplicatedStorage/Forge/Experience/Bus")
local Subjects = require("@game/ReplicatedStorage/Forge/Experience/Subjects")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Onboarding = require("@game/ReplicatedStorage/Forge/Experience/Onboarding")
local OnboardingConfig = require("@game/ReplicatedStorage/Forge/Config/Onboarding")

local OnboardingService = {}
OnboardingService.__index = OnboardingService

local Def = { name = "OnboardingService", dependencies = { "SettingsService", "AnalyticsService" } }

local FUNNEL = "Onboarding"
local TICK_SEC = 1

local function isPlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end

function Def.create(env: any, registry: any, options: { config: any?, bus: any? }?)
	local opts = options or {}
	local config = opts.config or OnboardingConfig
	local bus = opts.bus or GameEvents
	local self = setmetatable({
		_env = env,
		_registry = registry,
		_settings = registry:get("SettingsService"),
		_analytics = registry:get("AnalyticsService"),
		_config = config,
		_bus = bus,
		_flows = {},
		_unavailable = {} :: { [string]: { [string]: boolean } }, -- flowId -> steps passed over here
		_players = {},
		_connections = {},
		_running = false,
		_enabled = true,
	}, OnboardingService)
	local known = AnalyticsRouter.knownEvents(bus)
	local problems = Onboarding.validate(config, known)
	local subjects = if type(config) == "table" then config.subjects else nil
	for _, problem in Subjects.validate(subjects, known) do
		table.insert(problems, problem)
	end
	if #problems == 0 then
		for _, name in Subjects.missing(Onboarding.events(config), subjects) do
			table.insert(problems, `subjects: no resolver for '{name}', so the steps waiting for it never complete`)
		end
	end
	if #problems > 0 then
		self._enabled = false
		env.log("error", "onboarding config invalid; onboarding disabled", { problems = table.concat(problems, "; ") })
	else
		for _, flow in config.flows do
			self._flows[flow.id] = flow
		end
	end
	return self
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

-- ------------------------------------------------------------------ lifecycle

function OnboardingService:start()
	if not self._enabled then
		return
	end
	local env = self._env
	self._remotes = self._registry:find("RemoteService")
	self._economy = self._registry:find("EconomyService")
	if self._remotes then
		self._remotes:handle("Experience.OnboardingAction", function(player, flowId, action)
			self:action(player, flowId, action)
		end)
		self._remotes:handle("Experience.OnboardingSkip", function(player, flowId)
			self:skip(player, flowId)
		end)
	else
		env.log("warn", "OnboardingService: RemoteService not loaded; client actions and skip inactive", {})
	end
	for _, flow in self._config.flows do
		self._unavailable[flow.id] = Onboarding.unavailable(flow, function(name)
			return self._registry:find(name) ~= nil
		end)
		for stepId in self._unavailable[flow.id] do
			env.log("info", "onboarding: a step's service is missing; the step is passed over", {
				flow = flow.id,
				step = stepId,
			})
		end
	end
	local busEvents = {}
	for _, flow in self._config.flows do
		busEvents[flow.startOn or "PlayerReady"] = true
		for _, step in flow.steps do
			if step.trigger.bus then
				busEvents[step.trigger.bus] = true
			end
		end
	end
	local handlers = {}
	for eventName in busEvents do
		handlers[eventName] = function(...)
			self:_onBus(eventName, table.pack(...))
		end
	end
	local connections, missing = Bus.connectAll(self._bus, handlers)
	self._connections = connections
	if #missing > 0 then
		env.log(
			"info",
			"onboarding: steps waiting for bus events not declared yet",
			{ events = table.concat(missing, ",") }
		)
	end
	if env.Players and env.Players.PlayerRemoving then
		table.insert(
			self._connections,
			env.Players.PlayerRemoving:Connect(function(player)
				self._players[player.UserId] = nil
			end)
		)
	end
	self._running = true
	env.spawn(function()
		while self._running do
			env.wait(TICK_SEC)
			if self._running then
				self:_tick()
			end
		end
	end)
end

function OnboardingService:destroy()
	self._running = false
	for _, connection in self._connections do
		if connection.Disconnect then
			connection:Disconnect()
		else
			connection:disconnect()
		end
	end
	table.clear(self._connections)
end

-- ------------------------------------------------------------------ per-player state

-- Starts (or resumes) one flow for a player: restore stored progress, run auto steps, tell the client.
function OnboardingService:_begin(player: any, flow: any)
	if not isPlayer(player) or player.Parent == nil then
		return -- a start event for a player who already left would leave a state no PlayerRemoving clears (#22)
	end
	local states = self._players[player.UserId]
	if states == nil then
		states = {}
		self._players[player.UserId] = states
	end
	if states[flow.id] then
		return
	end
	local section = self._settings:read(player, "onboarding")
	local stored = if section and type(section.flows) == "table" then section.flows else {}
	local now = self._env.now()
	local state = Onboarding.restore(flow, stored[flow.id], now)
	states[flow.id] = state
	state.unavailable = self._unavailable[flow.id]
	local transitions = Onboarding.begin(flow, state, now)
	if #transitions > 0 then
		self:_apply(player, flow, state, transitions) -- persists and pushes
	else
		self:_push(player, flow, state)
	end
end

function OnboardingService:_stateOf(player: any, flowId: string): (any, any)
	local states = if isPlayer(player) then self._players[player.UserId] else nil
	local flow = self._flows[flowId]
	if states == nil or flow == nil then
		return nil, nil
	end
	return flow, states[flowId]
end

function OnboardingService:_persist(player: any, flow: any, state: any)
	local ok = self._settings:update(player, "onboarding", function(section)
		section.flows = section.flows or {}
		section.flows[flow.id] = Onboarding.persisted(state)
	end)
	if not ok then
		self._env.log(
			"warn",
			"onboarding: progress not saved (profile not loaded?)",
			{ userId = player.UserId, flow = flow.id }
		)
	end
end

function OnboardingService:_push(player: any, flow: any, state: any)
	if self._remotes then
		self._remotes:fire("Experience.OnboardingState", player, Onboarding.snapshot(flow, state))
	end
end

function OnboardingService:_grant(player: any, flow: any, stepId: string, reward: any)
	if reward == nil then
		return
	end
	local economy = self._economy
	if economy == nil then
		self._env.log("warn", "onboarding: reward not granted (EconomyService not loaded)", {
			userId = player.UserId,
			flow = flow.id,
			step = stepId,
		})
		return
	end
	local txId = `onboarding:{flow.id}:{stepId}:{player.UserId}`
	local ok, granted = pcall(economy.grant, economy, player, reward.currency, reward.amount, txId, "Onboarding")
	if not ok or granted ~= true then
		self._env.log("warn", "onboarding: reward grant failed", { txId = txId, error = tostring(granted) })
	end
end

-- Records transitions: persistence, funnel, bus event, rewards, completion; then pushes state.
function OnboardingService:_apply(player: any, flow: any, state: any, transitions: { any })
	if #transitions == 0 then
		return
	end
	for _, transition in transitions do
		local step = flow.steps[transition.index]
		local passed = transition.via == "unavailable" or (transition.via == "timeout" and step and step.interactive)
		if flow.funnel and not state.skipped then
			self._analytics:funnel(player, FUNNEL, transition.index, transition.id)
			if passed then
				self._analytics:event(player, "OnboardingStepPassed", {
					step = transition.index,
					stepName = transition.id,
					via = transition.via,
				})
			end
		end
		if Bus.declared(self._bus, "OnboardingStep") then
			self._bus.OnboardingStep:fire(player, flow.id, transition.index, transition.id)
		end
		self._env.log("info", "onboarding step", {
			userId = player.UserId,
			flow = flow.id,
			step = transition.index,
			stepId = transition.id,
			via = transition.via,
		})
		self:_grant(player, flow, transition.id, transition.reward)
	end
	if state.finishedAt ~= nil and not state.reportedFinish then
		state.reportedFinish = true
		local duration = math.max(0, math.floor((state.finishedAt or 0) - (state.startedAt or state.finishedAt or 0)))
		self._analytics:event(player, "OnboardingCompleted", { durationSec = duration, flow = flow.id })
		self:_grant(player, flow, "Complete", flow.completeReward)
	end
	self:_persist(player, flow, state)
	self:_push(player, flow, state)
end

-- ------------------------------------------------------------------ inputs

function OnboardingService:_onBus(eventName: string, args: { any })
	local players = self._env.Players
	local ctx = {
		byUserId = function(userId: number): any
			return players:GetPlayerByUserId(userId)
		end,
		all = function(): { any }
			return players:GetPlayers()
		end,
		registry = self._registry,
	}
	local subjects, err = Subjects.resolve(eventName, args, ctx, self._config.subjects)
	if err then
		self._env.log("warn", `onboarding: subjects resolver for {eventName} failed`, { error = err })
	end
	for _, subject in subjects do
		for _, flow in self._config.flows do
			if (flow.startOn or "PlayerReady") == eventName then
				self:_begin(subject.player, flow)
			end
		end
		local states = self._players[subject.player.UserId]
		if states then
			for flowId, state in states do
				local flow = self._flows[flowId]
				local transitions, satisfied =
					Onboarding.handle(flow, state, { bus = eventName, info = subject.info }, self._env.now())
				if #transitions > 0 then
					self:_apply(subject.player, flow, state, transitions)
				elseif satisfied then
					self:_persist(subject.player, flow, state)
				end
			end
		end
	end
end

function OnboardingService:action(player: any, flowId: any, action: any): boolean
	if type(flowId) ~= "string" or type(action) ~= "string" then
		return false
	end
	if not table.find(self._config.clientActions or {}, action) then
		return false
	end
	local flow, state = self:_stateOf(player, flowId)
	if flow == nil then
		return false
	end
	local transitions = Onboarding.handle(flow, state, { client = action }, self._env.now())
	self:_apply(player, flow, state, transitions)
	return #transitions > 0
end

function OnboardingService:skip(player: any, flowId: any): boolean
	if type(flowId) ~= "string" then
		return false
	end
	local flow, state = self:_stateOf(player, flowId)
	if flow == nil or not Onboarding.skip(flow, state, self._env.now()) then
		return false
	end
	local lastStep = flow.steps[state.completed]
	self._analytics:event(player, "OnboardingSkipped", {
		lastStep = state.completed,
		lastStepName = if lastStep then lastStep.id else "None",
		flow = flow.id,
	})
	self._env.log("info", "onboarding skipped", { userId = player.UserId, flow = flow.id, lastStep = state.completed })
	self:_persist(player, flow, state)
	self:_push(player, flow, state)
	return true
end

function OnboardingService:_tick()
	local now = self._env.now()
	for userId, states in self._players do
		local player = self._env.Players:GetPlayerByUserId(userId)
		if player then
			for flowId, state in states do
				local flow = self._flows[flowId]
				state.stepStartedAt = state.stepStartedAt or now
				local transitions, escalated = Onboarding.tick(flow, state, now)
				if escalated then
					local index, step = Onboarding.current(flow, state)
					self._analytics:event(player, "OnboardingHintEscalated", { step = index, stepName = step.id })
					self:_push(player, flow, state)
				end
				self:_apply(player, flow, state, transitions)
			end
		end
	end
end

function OnboardingService:state(player: any, flowId: string?): any
	local id = flowId or (self._config.flows[1] and self._config.flows[1].id)
	local flow, state = self:_stateOf(player, id)
	return if flow then Onboarding.snapshot(flow, state) else nil
end

return Def
