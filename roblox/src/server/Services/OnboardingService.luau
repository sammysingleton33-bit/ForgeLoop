--!strict
--[[
	OnboardingService (FORGE-04) — runs the tutorial flows of games/<game>/config/Onboarding.luau
	for every player, server-authoritatively (engine: Experience/Onboarding).

	Lifecycle per player
		PlayerReady            restore progress from experience.onboarding (SettingsService), begin the
		                       flow (auto steps), push Experience.OnboardingState to the client
		bus events             (GameEvents + kingdom signals once declared) complete or pre-satisfy steps
		Experience.OnboardingAction(flowId, action)   client-observed actions; only the current step
		Experience.OnboardingSkip(flowId)             skip: OnboardingSkipped, then no funnel step ever again
		every second           nudge escalation (OnboardingHintEscalated) and auto-advance of info steps
	On each completed step: persist (SettingsService:update "onboarding"), AnalyticsService:funnel
	("Onboarding", index, id) for the funnel flow, GameEvents.OnboardingStep(player, flow, index, id),
	the step reward through EconomyService:grant (txId "onboarding:<flow>:<step>:<userId>", idempotent),
	and a new state for the client. On the last step: OnboardingCompleted (value = seconds) and the
	flow's completeReward.

		OnboardingService:state(player, flowId?) -> snapshot?      -- Onboarding.snapshot
		OnboardingService:skip(player, flowId) -> boolean
		OnboardingService:action(player, flowId, action) -> boolean
	Never blocks play: nothing here freezes, teleports or gates the player.
]]

local AnalyticsRouter = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsRouter")
local Bus = require("@game/ReplicatedStorage/Forge/Experience/Bus")
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
		_players = {},
		_connections = {},
		_running = false,
		_enabled = true,
	}, OnboardingService)
	local problems = Onboarding.validate(config, AnalyticsRouter.knownEvents(bus))
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
	local busEvents = {}
	for _, flow in self._config.flows do
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
	local readyHandler = handlers.PlayerReady
	handlers.PlayerReady = function(player, ...)
		self:_onReady(player)
		if readyHandler then
			readyHandler(player, ...)
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

function OnboardingService:_onReady(player: any)
	if not isPlayer(player) or self._players[player.UserId] then
		return
	end
	local section = self._settings:read(player, "onboarding")
	local stored = if section and type(section.flows) == "table" then section.flows else {}
	local now = self._env.now()
	local states = {}
	self._players[player.UserId] = states
	for _, flow in self._config.flows do
		local state = Onboarding.restore(flow, stored[flow.id], now)
		states[flow.id] = state
		local transitions = Onboarding.begin(flow, state, now)
		if #transitions > 0 then
			self:_apply(player, flow, state, transitions) -- persists and pushes
		else
			self:_push(player, flow, state)
		end
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
		if flow.funnel and not state.skipped then
			self._analytics:funnel(player, FUNNEL, transition.index, transition.id)
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
	local lookup = {
		byUserId = function(userId: number): any
			return self._env.Players:GetPlayerByUserId(userId)
		end,
		all = function(): { any }
			return self._env.Players:GetPlayers()
		end,
	}
	for _, subject in AnalyticsRouter.normalize(eventName, args, lookup) do
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
