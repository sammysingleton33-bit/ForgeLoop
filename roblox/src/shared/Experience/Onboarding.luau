--!strict
--[[
	Experience/Onboarding — the data-driven tutorial step graph (FL-0025). Pure: no services; the
	caller passes the clock. OnboardingService (server) owns progress; OnboardingController (client)
	only renders snapshots and reports client actions.

	Config (games/<game>/config/Onboarding.luau):
		{
			flows = { Flow },
			clientActions = { string },       -- every client action a step may wait for (whitelist)
			limits = { firstInteractionSec: number, firstRewardSec: number },
		}
		Flow = { id: string, version: number, funnel: boolean?, startOn: "PlayerReady",
		         steps: { Step }, completeReward: Reward? }
		Step = {
			id: string (PascalCase; the funnel step name),
			trigger: { auto: true } | { bus: string, match: { [string]: any }? } | { client: string },
			hint: { title: string, body: string?, target: Target? },
			expectSec: number,                -- design estimate, used for the 30 s / first-reward checks
			interactive: boolean?,            -- the player does something meaningful (move, tap, build)
			nudgeAfterSec: number?,           -- hint escalates (arrow pulses, OnboardingHintEscalated)
			autoAdvanceSec: number?,          -- informational steps move on by themselves (via = "timeout")
			reward: Reward?,                  -- only on bus-triggered steps (server-verified)
		}
		Target = { kind: "world", tag: string } | { kind: "ui", name: string }  -- ui: an OnboardingTarget attribute
		Reward = { currency: string, amount: number }

	Progress (persisted in experience.onboarding.flows[flowId] through SettingsService):
		{ version, completed: number, skipped: boolean, startedAt: number?, finishedAt: number?,
		  satisfied: { [stepId]: true } }
	Rules
	- Steps run in order; a later step's BUS trigger that fires early is remembered (satisfied) and that
	  step completes as soon as it becomes current, so the tutorial never asks for something already done.
	- Client actions only complete the CURRENT step (untrusted input cannot jump ahead or pre-satisfy).
	- Skipped or finished flows never change again. An unfinished flow whose config version changed
	  restarts from step 1.

	API
		Onboarding.validate(config, knownBusEvents) -> { string }
		Onboarding.restore(flow, stored, now) -> State
		Onboarding.begin(flow, state, now) -> { Transition }               -- auto steps at the start
		Onboarding.handle(flow, state, trigger, now) -> ({ Transition }, satisfiedChanged)  -- trigger = { bus, info } | { client }
		Onboarding.tick(flow, state, now) -> ({ Transition }, escalated: boolean)
		Onboarding.skip(flow, state, now) -> boolean
		Onboarding.current(flow, state) -> (index?, Step?)
		Onboarding.snapshot(flow, state) -> table                           -- what the client renders
		Onboarding.persisted(state) -> table                                -- what is stored
		Transition = { index: number, id: string, via: "auto" | "bus" | "client" | "timeout" | "satisfied", reward: Reward? }
]]

local Onboarding = {}

local NAME_PATTERN = "^[A-Z][A-Za-z0-9]*$"
local ID_PATTERN = "^[a-z][a-z0-9_]*$"

export type Transition = { index: number, id: string, via: string, reward: any? }

-- ------------------------------------------------------------------ validation

local function matchesTrigger(problems: { string }, where: string, step: any, config: any, known: { string })
	local trigger = step.trigger
	if type(trigger) ~= "table" then
		table.insert(problems, `{where}: trigger required`)
		return
	end
	local kinds = (if trigger.auto then 1 else 0) + (if trigger.bus then 1 else 0) + (if trigger.client then 1 else 0)
	if kinds ~= 1 then
		table.insert(problems, `{where}: trigger needs exactly one of auto, bus, client`)
		return
	end
	if trigger.bus then
		if not table.find(known, trigger.bus) then
			table.insert(problems, `{where}: unknown bus event '{tostring(trigger.bus)}'`)
		elseif trigger.bus == "OnboardingStep" then
			table.insert(problems, `{where}: a step cannot wait for OnboardingStep (loop)`)
		end
	end
	if trigger.client and not table.find(config.clientActions or {}, trigger.client) then
		table.insert(problems, `{where}: client action '{tostring(trigger.client)}' is not in clientActions`)
	end
	if step.reward and not trigger.bus then
		table.insert(problems, `{where}: rewards only on bus-triggered (server-verified) steps`)
	end
end

local function checkReward(problems: { string }, where: string, reward: any)
	if reward == nil then
		return
	end
	if
		type(reward) ~= "table"
		or type(reward.currency) ~= "string"
		or type(reward.amount) ~= "number"
		or reward.amount <= 0
	then
		table.insert(problems, `{where}: reward needs currency and a positive amount`)
	end
end

function Onboarding.validate(config: any, knownBusEvents: { string }): { string }
	local problems: { string } = {}
	if type(config) ~= "table" or type(config.flows) ~= "table" then
		return { "config needs a flows list" }
	end
	local limits = config.limits or {}
	local funnels = 0
	local flowIds = {}
	for f, flow in config.flows do
		local where = `flows[{f}] ({tostring(flow.id)})`
		if type(flow.id) ~= "string" or not string.match(flow.id, ID_PATTERN) then
			table.insert(problems, `{where}: id must be snake_case`)
		elseif flowIds[flow.id] then
			table.insert(problems, `{where}: duplicate flow id`)
		end
		flowIds[flow.id] = true
		if type(flow.version) ~= "number" or flow.version < 1 or flow.version % 1 ~= 0 then
			table.insert(problems, `{where}: version must be a positive integer`)
		end
		if flow.funnel then
			funnels += 1
		end
		if type(flow.steps) ~= "table" or #flow.steps == 0 then
			table.insert(problems, `{where}: steps required`)
			continue
		end
		if #flow.steps > 30 then
			table.insert(problems, `{where}: {#flow.steps} steps; keep tutorials to 30 or fewer`)
		end
		checkReward(problems, `{where} completeReward`, flow.completeReward)
		local seen = {}
		local elapsed = 0
		local firstInteraction: number? = nil
		local firstReward: number? = nil
		for s, step in flow.steps do
			local at = `{where} step {s} ({tostring(step.id)})`
			if type(step.id) ~= "string" or not string.match(step.id, NAME_PATTERN) then
				table.insert(problems, `{at}: id must be PascalCase (it is the funnel step name)`)
			elseif seen[step.id] then
				table.insert(problems, `{at}: duplicate step id`)
			end
			seen[step.id] = true
			matchesTrigger(problems, at, step, config, knownBusEvents)
			checkReward(problems, at, step.reward)
			if type(step.hint) ~= "table" or type(step.hint.title) ~= "string" or step.hint.title == "" then
				table.insert(problems, `{at}: hint.title required`)
			elseif #step.hint.title > 60 or (step.hint.body and #step.hint.body > 140) then
				table.insert(problems, `{at}: hint too long (title <= 60, body <= 140 characters; teach by doing)`)
			end
			local target = step.hint and step.hint.target
			if target ~= nil then
				local okWorld = target.kind == "world" and type(target.tag) == "string"
				local okUi = target.kind == "ui" and type(target.name) == "string"
				if not (okWorld or okUi) then
					table.insert(problems, `{at}: target must be a world tag or a ui name`)
				end
			end
			if type(step.expectSec) ~= "number" or step.expectSec <= 0 then
				table.insert(problems, `{at}: expectSec must be a positive number`)
			else
				elapsed += step.expectSec
			end
			if step.interactive and firstInteraction == nil then
				firstInteraction = elapsed
			end
			if step.reward and firstReward == nil then
				firstReward = elapsed
			end
			if step.autoAdvanceSec ~= nil and step.trigger and step.trigger.bus then
				table.insert(problems, `{at}: bus steps never auto-advance (they wait for the real action)`)
			end
		end
		if flow.funnel then
			if firstInteraction == nil then
				table.insert(problems, `{where}: no interactive step`)
			elseif limits.firstInteractionSec and firstInteraction > limits.firstInteractionSec then
				table.insert(
					problems,
					`{where}: first meaningful interaction expected at {firstInteraction} s; limit {limits.firstInteractionSec} s`
				)
			end
			if limits.firstRewardSec and (firstReward == nil or firstReward > limits.firstRewardSec) then
				table.insert(
					problems,
					`{where}: first reward expected at {tostring(firstReward)} s; limit {limits.firstRewardSec} s`
				)
			end
		end
	end
	if funnels > 1 then
		table.insert(problems, "flows: only one flow may log the onboarding funnel (funnel = true)")
	end
	return problems
end

-- ------------------------------------------------------------------ state machine

function Onboarding.restore(flow: any, stored: any, now: number): { [string]: any }
	local valid = type(stored) == "table" and type(stored.completed) == "number"
	local finished = valid and (stored.skipped == true or stored.finishedAt ~= nil)
	local state: { [string]: any }
	if valid and (finished or stored.version == flow.version) then
		state = {
			version = stored.version,
			completed = math.clamp(math.floor(stored.completed), 0, #flow.steps),
			skipped = stored.skipped == true,
			startedAt = stored.startedAt,
			finishedAt = stored.finishedAt,
			satisfied = if type(stored.satisfied) == "table" then table.clone(stored.satisfied) else {},
		}
	else
		state = { version = flow.version, completed = 0, skipped = false, satisfied = {} }
	end
	state.stepStartedAt = now
	state.escalated = false
	return state
end

function Onboarding.done(flow: any, state: any): boolean
	return state.skipped or state.finishedAt ~= nil or state.completed >= #flow.steps
end

function Onboarding.current(flow: any, state: any): (number?, any)
	if state.skipped or state.finishedAt ~= nil or state.completed >= #flow.steps then
		return nil, nil
	end
	local index = state.completed + 1
	return index, flow.steps[index]
end

local function complete(flow: any, state: any, via: string, now: number, out: { Transition })
	local index = state.completed + 1
	local step = flow.steps[index]
	state.completed = index
	state.satisfied[step.id] = nil
	state.stepStartedAt = now
	state.escalated = false
	state.startedAt = state.startedAt or now
	if state.completed >= #flow.steps then
		state.finishedAt = now
	end
	table.insert(out, { index = index, id = step.id, via = via, reward = step.reward })
end

-- Completes the current step and every following step that is already satisfied or automatic.
local function cascade(flow: any, state: any, now: number, out: { Transition })
	while true do
		local _, step = Onboarding.current(flow, state)
		if step == nil then
			return
		end
		if step.trigger.auto then
			complete(flow, state, "auto", now, out)
		elseif state.satisfied[step.id] then
			complete(flow, state, "satisfied", now, out)
		else
			return
		end
	end
end

function Onboarding.begin(flow: any, state: any, now: number): { Transition }
	local out = {}
	if Onboarding.done(flow, state) then
		return out
	end
	state.startedAt = state.startedAt or now
	cascade(flow, state, now, out)
	return out
end

local function busMatches(step: any, trigger: any): boolean
	if step.trigger.bus ~= trigger.bus then
		return false
	end
	for key, expected in step.trigger.match or {} do
		if (trigger.info or {})[key] ~= expected then
			return false
		end
	end
	return true
end

-- Returns the transitions and whether a later step became satisfied (progress worth saving).
function Onboarding.handle(flow: any, state: any, trigger: any, now: number): ({ Transition }, boolean)
	local out = {}
	local index, step = Onboarding.current(flow, state)
	if step == nil then
		return out, false
	end
	if trigger.client then
		if step.trigger.client == trigger.client then
			complete(flow, state, "client", now, out)
			cascade(flow, state, now, out)
		end
		return out, false
	end
	if trigger.bus == nil then
		return out, false
	end
	if busMatches(step, trigger) then
		complete(flow, state, "bus", now, out)
		cascade(flow, state, now, out)
		return out, false
	end
	local changed = false
	for later = (index :: number) + 1, #flow.steps do
		local future = flow.steps[later]
		if future.trigger.bus and not state.satisfied[future.id] and busMatches(future, trigger) then
			state.satisfied[future.id] = true
			changed = true
		end
	end
	return out, changed
end

function Onboarding.tick(flow: any, state: any, now: number): ({ Transition }, boolean)
	local out = {}
	local _, step = Onboarding.current(flow, state)
	if step == nil then
		return out, false
	end
	local waited = now - (state.stepStartedAt or now)
	local escalatedNow = false
	if step.nudgeAfterSec and not state.escalated and waited >= step.nudgeAfterSec then
		state.escalated = true
		escalatedNow = true
	end
	if step.autoAdvanceSec and waited >= step.autoAdvanceSec then
		complete(flow, state, "timeout", now, out)
		cascade(flow, state, now, out)
	end
	return out, escalatedNow
end

function Onboarding.skip(flow: any, state: any, now: number): boolean
	if Onboarding.done(flow, state) then
		return false
	end
	state.skipped = true
	state.skippedAt = now
	return true
end

function Onboarding.snapshot(flow: any, state: any): { [string]: any }
	local index, step = Onboarding.current(flow, state)
	return {
		flowId = flow.id,
		total = #flow.steps,
		completed = state.completed,
		step = index,
		stepId = if step then step.id else nil,
		hint = if step then step.hint else nil,
		clientAction = if step then step.trigger.client else nil, -- what the client should watch for
		escalated = state.escalated == true,
		done = Onboarding.done(flow, state),
		skipped = state.skipped == true,
	}
end

function Onboarding.persisted(state: any): { [string]: any }
	return {
		version = state.version,
		completed = state.completed,
		skipped = state.skipped,
		startedAt = state.startedAt,
		finishedAt = state.finishedAt,
		satisfied = table.clone(state.satisfied),
	}
end

return table.freeze(Onboarding)
