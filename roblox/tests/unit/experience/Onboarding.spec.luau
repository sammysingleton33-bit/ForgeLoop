local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local FakeBus = require("./doubles/FakeBus")
local FakeDataService = require("./doubles/FakeDataService")
local FakeRemoteService = require("./doubles/FakeRemoteService")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local AnalyticsRouter = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsRouter")
local Onboarding = require("@game/ReplicatedStorage/Forge/Experience/Onboarding")
local ExperienceRemotes = require("@game/ReplicatedStorage/Forge/Experience/Remotes")
local AnalyticsDef = require("@game/ServerScriptService/Forge/Services/AnalyticsService")
local SettingsDef = require("@game/ServerScriptService/Forge/Services/SettingsService")
local OnboardingDef = require("@game/ServerScriptService/Forge/Services/OnboardingService")
local SandboxOnboarding = require("@game/ReplicatedStorage/Forge/Config/Onboarding")
local TestOnboarding = require("./doubles/TestOnboarding")
local TestAnalytics = require("./doubles/TestAnalytics")

local CONFIG = TestOnboarding.config
local KNOWN = AnalyticsRouter.knownEvents(FakeBus.new({ extra = TestOnboarding.EXTRA_EVENTS }))
local FLOW = CONFIG.flows[1]

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function problemsOf(mutate)
	local config = deepCopy(CONFIG)
	mutate(config)
	return table.concat(Onboarding.validate(config, KNOWN), "\n")
end

describe("Experience/Onboarding config rules", function()
	it("accepts the spec flow and the sandbox flow (game flows: games/<game>/tests)", function()
		expect(Onboarding.validate(CONFIG, KNOWN)).toEqual({})
		expect(Onboarding.validate(SandboxOnboarding, AnalyticsRouter.knownEvents(GameEvents))).toEqual({})
	end)

	it("the spec flow: first meaningful interaction within 30 s, first reward within 3 minutes", function()
		local elapsed, firstInteraction, firstReward = 0, nil, nil
		for _, step in FLOW.steps do
			elapsed += step.expectSec
			firstInteraction = firstInteraction or (if step.interactive then elapsed else nil)
			firstReward = firstReward or (if step.reward then elapsed else nil)
		end
		expect(firstInteraction).toBeLessThanOrEqual(30)
		expect(firstReward).toBeLessThanOrEqual(180)
		expect(elapsed).toBeLessThanOrEqual(300)
	end)

	it("the onboarding steps fit the analytics funnel budget", function()
		expect(#FLOW.steps).toBeLessThanOrEqual(30)
		expect(TestAnalytics.build().funnels.Onboarding.kind).toBe("onboarding")
	end)

	it("rejects a flow whose first interaction comes too late", function()
		expect(problemsOf(function(c)
			c.flows[1].steps[1].expectSec = 40
		end)).toContain("first meaningful interaction expected at 48 s; limit 30 s")
	end)

	it("rejects rewards on client-triggered steps (untrusted input)", function()
		expect(problemsOf(function(c)
			c.flows[1].steps[2].reward = { currency = "Coins", amount = 5 }
		end)).toContain("rewards only on bus-triggered (server-verified) steps")
	end)

	it("rejects idle hints that are not phase -> 1-140 characters", function()
		expect(problemsOf(function(c)
			c.idleHints = { Expansion = string.rep("x", 141) }
		end)).toContain("idleHints[Expansion]: text must be 1-140 characters")
		expect(problemsOf(function(c)
			c.idleHints = "Build more"
		end)).toContain("idleHints must be a table of phase -> text")
	end)

	it("rejects an unknown start event", function()
		expect(problemsOf(function(c)
			c.flows[1].startOn = "KingdomJoind"
		end)).toContain("startOn 'KingdomJoind' is not a declared bus event")
	end)

	it("rejects unknown bus events, unlisted client actions and auto-advancing bus steps", function()
		local text = problemsOf(function(c)
			c.flows[1].steps[5].trigger = { bus = "CitizenTaskChangd" }
			c.flows[1].steps[2].trigger = { client = "Teleported" }
			c.flows[1].steps[6].autoAdvanceSec = 5
		end)
		expect(text).toContain("unknown bus event 'CitizenTaskChangd'")
		expect(text).toContain("client action 'Teleported' is not in clientActions")
		expect(text).toContain("bus steps never auto-advance")
	end)

	it("rejects long hints, bad ids, duplicate steps and two funnel flows", function()
		local text = problemsOf(function(c)
			c.flows[1].steps[3].hint.title = string.rep("x", 61)
			c.flows[1].steps[4].id = "check_resources"
			c.flows[1].steps[5].id = "MoveRuler"
			local second = deepCopy(c.flows[1])
			second.id = "again"
			table.insert(c.flows, second)
		end)
		expect(text).toContain("hint too long")
		expect(text).toContain("id must be PascalCase")
		expect(text).toContain("duplicate step id")
		expect(text).toContain("only one flow may log the onboarding funnel")
	end)
end)

describe("Experience/Onboarding step graph", function()
	local function fresh()
		local state = Onboarding.restore(FLOW, nil, 0)
		Onboarding.begin(FLOW, state, 0)
		return state
	end

	it("begins by completing the automatic first step", function()
		local state = Onboarding.restore(FLOW, nil, 0)
		local transitions = Onboarding.begin(FLOW, state, 0)
		expect(#transitions).toBe(1)
		expect(transitions[1].id).toBe("Arrive")
		expect(transitions[1].via).toBe("auto")
		expect((Onboarding.current(FLOW, state))).toBe(2)
	end)

	it("client actions only complete the current step", function()
		local state = fresh()
		expect(#Onboarding.handle(FLOW, state, { client = "ResourceInspected" }, 1)).toBe(0)
		expect(#Onboarding.handle(FLOW, state, { client = "RulerMoved" }, 1)).toBe(1)
		expect(state.completed).toBe(2)
	end)

	it("a later bus step done early completes as soon as it becomes current", function()
		local state = fresh()
		Onboarding.handle(FLOW, state, { client = "RulerMoved" }, 1)
		Onboarding.handle(FLOW, state, { client = "ReachedTarget" }, 2)
		Onboarding.handle(FLOW, state, { client = "ResourceInspected" }, 3)
		local early, changed = Onboarding.handle(
			FLOW,
			state,
			{ bus = "ConstructionStarted", info = { role = "actor", buildingType = "Farm" } },
			4
		)
		expect(#early).toBe(0)
		expect(changed).toBe(true)
		local both = Onboarding.handle(FLOW, state, { bus = "CitizenTaskChanged", info = { role = "actor" } }, 5)
		expect(#both).toBe(2)
		expect(both[1].id).toBe("AssignCitizen")
		expect(both[2].id).toBe("PlaceFarm")
		expect(both[2].via).toBe("satisfied")
	end)

	it("bus matches must agree on every field (a rival's farm does not count)", function()
		local state = fresh()
		state.completed = 5 -- PlaceFarm is current
		local rival = Onboarding.handle(
			FLOW,
			state,
			{ bus = "ConstructionStarted", info = { role = "defender", buildingType = "Farm" } },
			1
		)
		local mill = Onboarding.handle(
			FLOW,
			state,
			{ bus = "ConstructionStarted", info = { role = "actor", buildingType = "Mill" } },
			1
		)
		expect(#rival + #mill).toBe(0)
	end)

	it("escalates once after nudgeAfterSec and auto-advances informational steps", function()
		local state = fresh()
		local _, escalated = Onboarding.tick(FLOW, state, 11)
		expect(escalated).toBe(false)
		_, escalated = Onboarding.tick(FLOW, state, 12)
		expect(escalated).toBe(true)
		_, escalated = Onboarding.tick(FLOW, state, 30)
		expect(escalated).toBe(false)
		state.completed = 3
		state.stepStartedAt = 100
		local moved = Onboarding.tick(FLOW, state, 120)
		expect(moved[1].id).toBe("CheckResources")
		expect(moved[1].via).toBe("timeout")
	end)

	it("skip ends the flow; skipped and finished flows never change again", function()
		local state = fresh()
		expect(Onboarding.skip(FLOW, state, 5)).toBe(true)
		expect(Onboarding.skip(FLOW, state, 6)).toBe(false)
		expect(#Onboarding.handle(FLOW, state, { client = "RulerMoved" }, 7)).toBe(0)
		local restored = Onboarding.restore(FLOW, Onboarding.persisted(state), 8)
		expect(restored.skipped).toBe(true)
		expect(#Onboarding.begin(FLOW, restored, 8)).toBe(0)
	end)

	it("restores unfinished progress of the same version, restarts it after a version change", function()
		local stored = { version = 1, completed = 4, skipped = false, startedAt = 10, satisfied = { PlaceFarm = true } }
		local same = Onboarding.restore(FLOW, stored, 50)
		expect(same.completed).toBe(4)
		expect(same.satisfied.PlaceFarm).toBe(true)
		local newer = table.clone(FLOW)
		newer.version = 2
		expect(Onboarding.restore(newer, stored, 50).completed).toBe(0)
		local finished = { version = 1, completed = 9, skipped = false, startedAt = 1, finishedAt = 9 }
		expect(Onboarding.restore(newer, finished, 50).finishedAt).toBe(9)
		expect(Onboarding.restore(FLOW, { completed = 99, version = 1 }, 0).completed).toBe(#FLOW.steps)
	end)
end)

describe("OnboardingService", function()
	local env, bus, data, remotes, economy, registry, service, player

	local function boot(withEnv, withData, withRemotes)
		economy = { grants = {} }
		function economy.grant(_, p, currency, amount, txId, source)
			if economy.grants[txId] then
				return true -- idempotent per txId (interfaces §7)
			end
			economy.grants[txId] = { userId = p.UserId, currency = currency, amount = amount, source = source }
			return true
		end
		return Loader.load(withEnv, {
			{
				name = "DataService",
				new = function()
					return withData
				end,
			},
			{
				name = "RemoteService",
				new = function()
					return withRemotes
				end,
			},
			{
				name = "EconomyService",
				new = function()
					return economy
				end,
			},
			{
				name = "AnalyticsService",
				new = function(e, r)
					return AnalyticsDef.create(e, r, { config = TestAnalytics.build(), bus = bus })
				end,
			},
			SettingsDef,
			{
				name = "OnboardingService",
				dependencies = { "SettingsService", "AnalyticsService" },
				new = function(e, r)
					return OnboardingDef.create(e, r, { config = CONFIG, bus = bus })
				end,
			},
		})
	end

	local function onboardingSteps(e)
		local out = {}
		for _, call in e.AnalyticsService:callsTo("LogOnboardingFunnelStepEvent") do
			table.insert(out, call.args[2])
		end
		return out
	end

	local function act(action)
		return remotes:call("Experience.OnboardingAction", player, "first_session", action)
	end

	local function walkToFarm()
		act("RulerMoved")
		act("ReachedTarget")
		act("ResourceInspected")
		bus.CitizenTaskChanged:fire(player, { matchId = "m1", kingdomId = "k1", citizenId = "c1", task = "Farmer" })
		bus.ConstructionStarted:fire(
			player,
			{ matchId = "m1", kingdomId = "k1", buildingId = "b1", buildingType = "Farm" }
		)
	end

	beforeEach(function()
		GameEvents.disconnectAll()
		env = MockEnv.new({ seed = 21 })
		bus = FakeBus.new({ extra = TestOnboarding.EXTRA_EVENTS })
		data = FakeDataService.new()
		remotes = FakeRemoteService.new({ declarations = ExperienceRemotes })
		registry = boot(env, data, remotes)
		service = registry:get("OnboardingService")
		player = env.mock.players:add({ userId = 901 })
		data:load(player, nil)
		bus.PlayerReady:fire(player)
	end)

	it("logs step 1 at join, fires OnboardingStep and tells the client the next step", function()
		expect(onboardingSteps(env)).toEqual({ "Arrive" })
		local state = remotes:sentTo("Experience.OnboardingState", player)
		local last = state[#state].args[1]
		expect(last.stepId).toBe("MoveRuler")
		expect(last.clientAction).toBe("RulerMoved")
		expect(last.hint.title).toBe("Walk to the landmark")
	end)

	it("a full first session logs every funnel step in order, the completion event and the rewards", function()
		local stepEvents = {}
		bus.OnboardingStep:connect(function(p, flow, index, name)
			table.insert(stepEvents, { p, flow, index, name })
		end)
		walkToFarm()
		bus.ResourceProduced:fire(
			player,
			{ matchId = "m1", kingdomId = "k1", resource = "Food", amount = 3, total = 3 }
		)
		bus.BuildingUpgraded:fire(player, { matchId = "m1", kingdomId = "k1", buildingType = "Hall", level = 2 })
		act("GoalAcknowledged")
		expect(onboardingSteps(env)).toEqual({
			"Arrive",
			"MoveRuler",
			"FindKingdom",
			"CheckResources",
			"AssignCitizen",
			"PlaceFarm",
			"FirstHarvest",
			"UpgradeHall",
			"NextGoal",
		})
		expect(#stepEvents).toBe(8)
		expect(stepEvents[8]).toEqual({ player, "first_session", 9, "NextGoal" })
		local completed = nil
		for _, call in env.AnalyticsService:callsTo("LogCustomEvent") do
			if call.args[1] == "OnboardingCompleted" then
				completed = call.args
			end
		end
		expect(completed).never.toBeNil()
		expect(completed[3]).toEqual({ CustomField01 = "first_session" })
		expect(economy.grants["onboarding:first_session:FirstHarvest:901"].amount).toBe(25)
		expect(economy.grants["onboarding:first_session:FirstHarvest:901"].source).toBe("Onboarding")
		expect(economy.grants["onboarding:first_session:Complete:901"].amount).toBe(50)
		expect(service:state(player).done).toBe(true)
		-- the env.log trail a Studio walkthrough checks, in order
		local trail = {}
		for _, entry in env.mock.logs do
			if entry.message == "analytics funnel Onboarding" then
				table.insert(trail, entry.fields.step)
			end
		end
		expect(trail).toEqual({ 1, 2, 3, 4, 5, 6, 7, 8, 9 })
	end)

	it("skipping logs OnboardingSkipped with the last step and no funnel step afterwards", function()
		act("RulerMoved")
		expect((remotes:call("Experience.OnboardingSkip", player, "first_session"))).toBe(true)
		local skipped = nil
		for _, call in env.AnalyticsService:callsTo("LogCustomEvent") do
			if call.args[1] == "OnboardingSkipped" then
				skipped = call.args
			end
		end
		expect(skipped[2]).toBe(2)
		expect(skipped[3]).toEqual({ CustomField01 = "MoveRuler", CustomField02 = "first_session" })
		act("ReachedTarget")
		bus.CitizenTaskChanged:fire(player, { matchId = "m1", kingdomId = "k1", citizenId = "c1", task = "Farmer" })
		expect(onboardingSteps(env)).toEqual({ "Arrive", "MoveRuler" })
		expect(next(economy.grants)).toBeNil()
		local stored = data:get(player, "experience").onboarding.flows.first_session
		expect(stored.skipped).toBe(true)
	end)

	it("persists progress and resumes it on another server without re-logging steps", function()
		walkToFarm()
		local stored = data:unload(player)
		expect(stored.experience.data.onboarding.flows.first_session.completed).toBe(6)
		GameEvents.disconnectAll()
		local env2 = MockEnv.new({ seed = 22 })
		bus = FakeBus.new({ extra = TestOnboarding.EXTRA_EVENTS })
		local data2 = FakeDataService.new()
		local remotes2 = FakeRemoteService.new({ declarations = ExperienceRemotes })
		local registry2 = boot(env2, data2, remotes2)
		local again = env2.mock.players:add({ userId = 901 })
		data2:load(again, stored)
		bus.PlayerReady:fire(again)
		expect(#env2.AnalyticsService:callsTo("LogOnboardingFunnelStepEvent")).toBe(0)
		expect(registry2:get("OnboardingService"):state(again).stepId).toBe("FirstHarvest")
		bus.ResourceProduced:fire(again, { matchId = "m2", kingdomId = "k9", resource = "Food", amount = 1, total = 1 })
		local steps = env2.AnalyticsService:callsTo("LogOnboardingFunnelStepEvent")
		expect(#steps).toBe(1)
		expect(steps[1].args[1]).toBe(7)
	end)

	it("ignores client actions that are not whitelisted, not current, or for another flow", function()
		expect((remotes:call("Experience.OnboardingAction", player, "first_session", "Teleported"))).toBe(true) -- accepted by the remote
		expect(service:action(player, "first_session", "Teleported")).toBe(false)
		expect(service:action(player, "first_session", "GoalAcknowledged")).toBe(false)
		expect(service:action(player, "other_flow", "RulerMoved")).toBe(false)
		expect(service:state(player).stepId).toBe("MoveRuler")
		expect((remotes:call("Experience.OnboardingAction", player, "first_session", string.rep("x", 49)))).toBe(false)
	end)

	it("escalates a stuck step (analytics + client) and auto-advances the resources step", function()
		env.mock:advance(13)
		local escalations = 0
		for _, call in env.AnalyticsService:callsTo("LogCustomEvent") do
			if call.args[1] == "OnboardingHintEscalated" then
				escalations += 1
				expect(call.args[2]).toBe(2)
			end
		end
		expect(escalations).toBe(1)
		local pushes = remotes:sentTo("Experience.OnboardingState", player)
		expect(pushes[#pushes].args[1].escalated).toBe(true)
		act("RulerMoved")
		act("ReachedTarget")
		env.mock:advance(21)
		expect(service:state(player).stepId).toBe("AssignCitizen")
	end)

	it("logs a warning, not an error, when EconomyService is missing for a reward", function()
		GameEvents.disconnectAll()
		local env3 = MockEnv.new({ seed = 23 })
		bus = FakeBus.new({ extra = TestOnboarding.EXTRA_EVENTS })
		local data3 = FakeDataService.new()
		local registry3 = Loader.load(env3, {
			{
				name = "DataService",
				new = function()
					return data3
				end,
			},
			{
				name = "AnalyticsService",
				new = function(e, r)
					return AnalyticsDef.create(e, r, { config = TestAnalytics.build(), bus = bus })
				end,
			},
			SettingsDef,
			{
				name = "OnboardingService",
				dependencies = { "SettingsService", "AnalyticsService" },
				new = function(e, r)
					return OnboardingDef.create(e, r, { config = CONFIG, bus = bus })
				end,
			},
		})
		local p = env3.mock.players:add({ userId = 902 })
		data3:load(p, nil)
		bus.PlayerReady:fire(p)
		local s = registry3:get("OnboardingService")
		s:action(p, "first_session", "RulerMoved")
		s:action(p, "first_session", "ReachedTarget")
		s:action(p, "first_session", "ResourceInspected")
		bus.CitizenTaskChanged:fire(p, { matchId = "m", kingdomId = "k", citizenId = "c", task = "Farmer" })
		bus.ConstructionStarted:fire(p, { matchId = "m", kingdomId = "k", buildingType = "Farm" })
		bus.ResourceProduced:fire(p, { matchId = "m", kingdomId = "k", resource = "Food", amount = 1, total = 1 })
		expect(env3.mock:hasLog("warn", "reward not granted (EconomyService not loaded)")).toBe(true)
		expect(env3.mock:hasLog("warn", "RemoteService not loaded")).toBe(true)
		expect(s:state(p).stepId).toBe("UpgradeHall")
	end)
end)
