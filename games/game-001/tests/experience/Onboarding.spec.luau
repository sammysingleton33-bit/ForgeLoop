local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local FakeBus = require("../../../../roblox/tests/unit/experience/doubles/FakeBus")
local FakeRemoteService = require("../../../../roblox/tests/unit/experience/doubles/FakeRemoteService")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local AnalyticsRouter = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsRouter")
local Onboarding = require("@game/ReplicatedStorage/Forge/Experience/Onboarding")
local ExperienceRemotes = require("@game/ReplicatedStorage/Forge/Experience/Remotes")
local OnboardingConfig = require("@game/ReplicatedStorage/Forge/Config/Onboarding")
local PacingDef = require("@game/ServerScriptService/Game/Services/PacingService")
local AnalyticsDef = require("@game/ServerScriptService/Forge/Services/AnalyticsService")
local SettingsDef = require("@game/ServerScriptService/Forge/Services/SettingsService")
local OnboardingDef = require("@game/ServerScriptService/Forge/Services/OnboardingService")

local KNOWN = AnalyticsRouter.knownEvents(GameEvents)
local FLOW = OnboardingConfig.flows[1]

-- G3 KingdomService double: getKingdom(id).rulers (userIds) and getKingdomOf(player)
local function fakeKingdoms()
	local rulers = { crimson = {}, azure = {} }
	local service = {}
	function service.join(player, kingdom)
		table.insert(rulers[kingdom], player.UserId)
	end
	function service.getKingdom(_, id)
		return { id = id, rulers = table.clone(rulers[id] or {}) }
	end
	function service.getKingdomOf(_, player)
		for id, list in rulers do
			if table.find(list, player.UserId) then
				return id
			end
		end
		return nil
	end
	return service
end

describe("game-001 VS-1 onboarding config", function()
	it("is valid against the real bus, starts on KingdomJoined, first interaction within 30 s", function()
		expect(Onboarding.validate(OnboardingConfig, KNOWN)).toEqual({})
		expect(FLOW.startOn).toBe("KingdomJoined")
		local elapsed, firstInteraction = 0, nil
		for _, step in FLOW.steps do
			elapsed += step.expectSec
			firstInteraction = firstInteraction or (if step.interactive then elapsed else nil)
		end
		expect(firstInteraction).toBeLessThanOrEqual(30)
		expect(elapsed).toBeLessThanOrEqual(450) -- PACING.md firstCaptureSec target
	end)

	it("keys its idle hints by contract MatchPhase (G2) and never names a Town Hall or currency", function()
		local hints = OnboardingConfig.idleHints
		assert(hints, "game-001 has idle hints")
		for phase, text in hints do
			expect(table.find(PacingDef.PHASES, phase) ~= nil and phase ~= "Lobby" and phase ~= "Results").toBe(true)
			expect(string.find(text, "Town Hall", 1, true)).toBeNil()
			expect(string.find(text, "Crowns", 1, true)).toBeNil()
		end
	end)

	it("guides inspect -> build on a plot -> answer -> recruit -> capture (BRIEF §4, D-030)", function()
		local ids = {}
		for _, step in FLOW.steps do
			table.insert(ids, step.id)
		end
		expect(ids).toEqual({ "Spawn", "InspectCitizen", "BuildOnPlot", "AnswerCitizen", "Recruit", "Capture" })
		expect(FLOW.version).toBe(2)
	end)

	it("client-reported steps grant nothing and are whitelisted; server steps use G9 events", function()
		for _, step in FLOW.steps do
			if step.trigger.client then
				expect(table.find(OnboardingConfig.clientActions, step.trigger.client) ~= nil).toBe(true)
				expect(step.reward).toBeNil()
			end
		end
		expect(FLOW.steps[3].trigger.bus).toBe("BuildingPlaced")
		expect(FLOW.steps[3].hint.target.tag).toBe("BuildSlot") -- G13.5 plot markers
	end)
end)

describe("game-001 VS-1 onboarding with the framework services (no DataService, D-027)", function()
	local env, bus, kingdoms, registry, onboarding, p1, p2, remotes

	-- conversations ~= false adds a ConversationService stub (FORGE-01's FL-0079 is not on main yet)
	local function boot(withKingdoms, conversations)
		local defs = {
			{
				name = "RemoteService",
				new = function()
					return remotes
				end,
			},
			{
				name = "AnalyticsService",
				new = function(e, r)
					return AnalyticsDef.create(e, r, { bus = bus })
				end,
			},
			SettingsDef,
			{
				name = "OnboardingService",
				dependencies = { "SettingsService", "AnalyticsService" },
				new = function(e, r)
					return OnboardingDef.create(e, r, { bus = bus })
				end,
			},
		}
		if withKingdoms then
			table.insert(defs, {
				name = "KingdomService",
				new = function()
					return kingdoms
				end,
			})
		end
		if conversations ~= false then
			table.insert(defs, {
				name = "ConversationService",
				new = function()
					return {}
				end,
			})
		end
		registry = Loader.load(env, defs)
		onboarding = registry:get("OnboardingService")
	end

	local function steps(player)
		local out = {}
		for _, call in env.AnalyticsService:callsTo("LogOnboardingFunnelStepEvent") do
			if call.userId == player.UserId then
				table.insert(out, call.args[2])
			end
		end
		return out
	end

	local function join(player, kingdom)
		kingdoms.join(player, kingdom)
		bus.KingdomJoined:fire(player, kingdom)
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 31 })
		bus = FakeBus.new()
		kingdoms = fakeKingdoms()
		remotes = FakeRemoteService.new({ declarations = ExperienceRemotes })
		p1 = env.mock.players:add({ userId = 1101 })
		p2 = env.mock.players:add({ userId = 1102 })
	end)

	local function act(player, action)
		return (remotes:call("Experience.OnboardingAction", player, "vs1", action))
	end

	local function place(player, kingdom, id)
		bus.BuildingPlaced:fire(
			{ id = id, kingdom = kingdom, type = "house", level = 1, placedBy = player.UserId },
			player
		)
	end

	it("starts on KingdomJoined (not PlayerReady) and logs Spawn", function()
		boot(true)
		bus.PlayerReady:fire(p1)
		expect(steps(p1)).toEqual({})
		join(p1, "crimson")
		expect(steps(p1)).toEqual({ "Spawn" })
		expect(onboarding:state(p1, "vs1").stepId).toBe("InspectCitizen")
	end)

	it("runs the whole v2 slice for co-rulers with the G9 attribution rules", function()
		boot(true)
		join(p1, "crimson")
		join(p2, "crimson")
		act(p1, "CitizenInspected")
		place(p1, "crimson", 7)
		act(p1, "CitizenAnswered")
		bus.UnitsRecruited:fire(p1, "crimson", 3)
		bus.ObjectiveCaptured:fire("tower_1", "crimson")
		expect(steps(p1)).toEqual({ "Spawn", "InspectCitizen", "BuildOnPlot", "AnswerCitizen", "Recruit", "Capture" })
		expect(onboarding:state(p1, "vs1").done).toBe(true)
		-- p2 did none of it yet: p1's build is not p2's, but the kingdom's capture is remembered
		expect(steps(p2)).toEqual({ "Spawn" })
		act(p2, "CitizenInspected")
		place(p2, "crimson", 8)
		act(p2, "CitizenAnswered")
		bus.UnitsRecruited:fire(p2, "crimson", 3)
		expect(steps(p2)).toEqual({ "Spawn", "InspectCitizen", "BuildOnPlot", "AnswerCitizen", "Recruit", "Capture" })
	end)

	it("a client action completes only the current step", function()
		boot(true)
		join(p1, "crimson")
		act(p1, "CitizenAnswered") -- out of order: ignored
		expect(onboarding:state(p1, "vs1").stepId).toBe("InspectCitizen")
		act(p1, "CitizenInspected")
		expect(onboarding:state(p1, "vs1").stepId).toBe("BuildOnPlot")
		act(p1, "CitizenInspected") -- repeats do nothing
		expect(steps(p1)).toEqual({ "Spawn", "InspectCitizen" })
	end)

	it("never credits a rival kingdom's capture or build", function()
		boot(true)
		join(p1, "crimson")
		join(p2, "azure")
		act(p1, "CitizenInspected")
		place(p2, "azure", 9)
		bus.ObjectiveCaptured:fire("tower_1", "azure")
		expect(steps(p1)).toEqual({ "Spawn", "InspectCitizen" })
		expect(onboarding:state(p1, "vs1").stepId).toBe("BuildOnPlot")
		-- the rival's capture must not have been remembered for p1 either
		place(p1, "crimson", 10)
		act(p1, "CitizenAnswered")
		bus.UnitsRecruited:fire(p1, "crimson", 3)
		expect(onboarding:state(p1, "vs1").stepId).toBe("Capture")
		expect(onboarding:state(p1, "vs1").done).toBe(false)
	end)

	it("keeps progress for the session only: a rejoin after leaving starts over", function()
		boot(true)
		join(p1, "crimson")
		act(p1, "CitizenInspected")
		expect(onboarding:state(p1, "vs1").stepId).toBe("BuildOnPlot")
		expect(registry:get("SettingsService"):isPersistent()).toBe(false)
		expect(env.mock:hasLog("warn", "progress not saved")).toBe(false)
		env.mock.players:remove(p1)
		local again = env.mock.players:add({ userId = 1101 })
		bus.KingdomJoined:fire(again, "crimson")
		expect(onboarding:state(again, "vs1").stepId).toBe("InspectCitizen")
	end)

	it("without ConversationService, AnswerCitizen is passed over and not counted; the tutorial completes", function()
		boot(true, false)
		join(p1, "crimson")
		act(p1, "CitizenInspected")
		place(p1, "crimson", 11)
		expect(onboarding:state(p1, "vs1").stepId).toBe("Recruit")
		bus.UnitsRecruited:fire(p1, "crimson", 3)
		bus.ObjectiveCaptured:fire("tower_1", "crimson")
		expect(onboarding:state(p1, "vs1").done).toBe(true) -- never stuck at 4/6 (FORGE-00's #45 ruling)
		expect(steps(p1)).toEqual({ "Spawn", "InspectCitizen", "BuildOnPlot", "Recruit", "Capture" })
		local completed = 0
		for _, call in env.AnalyticsService:callsTo("LogCustomEvent") do
			completed += if call.args[1] == "OnboardingCompleted" then 1 else 0
		end
		expect(completed).toBe(1)
		expect(env.mock:hasLog("info", "a step's service is missing")).toBe(true)
	end)

	it(
		"with ConversationService but no answer reported, AnswerCitizen moves on after autoAdvanceSec, uncounted",
		function()
			boot(true)
			join(p1, "crimson")
			act(p1, "CitizenInspected")
			place(p1, "crimson", 12)
			expect(onboarding:state(p1, "vs1").stepId).toBe("AnswerCitizen")
			local answer = OnboardingConfig.flows[1].steps[4]
			expect(answer.id).toBe("AnswerCitizen")
			env.mock:advance(answer.nudgeAfterSec + 1)
			expect(onboarding:state(p1, "vs1").escalated).toBe(true) -- nudged first
			env.mock:advance(answer.autoAdvanceSec - answer.nudgeAfterSec + 1)
			expect(onboarding:state(p1, "vs1").stepId).toBe("Recruit") -- never stalls
			expect(steps(p1)).toEqual({ "Spawn", "InspectCitizen", "BuildOnPlot" }) -- the funnel counts what players did
		end
	)

	it("without KingdomService, the player's own steps still work and kingdom-wide ones credit nobody", function()
		boot(false)
		bus.KingdomJoined:fire(p1, "crimson")
		act(p1, "CitizenInspected")
		place(p1, "crimson", 1)
		act(p1, "CitizenAnswered")
		bus.UnitsRecruited:fire(p1, "crimson", 3)
		bus.ObjectiveCaptured:fire("tower_1", "crimson")
		expect(steps(p1)).toEqual({ "Spawn", "InspectCitizen", "BuildOnPlot", "AnswerCitizen", "Recruit" })
		expect(env.mock:hasLog("warn", "subjects resolver")).toBe(false)
	end)

	it("skipping logs OnboardingSkipped and no later funnel step", function()
		boot(true)
		join(p1, "crimson")
		expect((remotes:call("Experience.OnboardingSkip", p1, "vs1"))).toBe(true)
		act(p1, "CitizenInspected")
		expect(steps(p1)).toEqual({ "Spawn" })
		local skipped = false
		for _, call in env.AnalyticsService:callsTo("LogCustomEvent") do
			skipped = skipped or call.args[1] == "OnboardingSkipped"
		end
		expect(skipped).toBe(true)
	end)
end)
