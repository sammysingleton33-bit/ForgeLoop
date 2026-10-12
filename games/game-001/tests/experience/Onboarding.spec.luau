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

	it("guides gather -> build -> recruit -> capture (BRIEF §4)", function()
		local ids = {}
		for _, step in FLOW.steps do
			table.insert(ids, step.id)
		end
		expect(ids).toEqual({ "Spawn", "Gather", "PlaceBuilding", "BuildingComplete", "Recruit", "Capture" })
	end)
end)

describe("game-001 VS-1 onboarding with the framework services (no DataService, D-027)", function()
	local env, bus, kingdoms, registry, onboarding, p1, p2, remotes

	local function boot(withKingdoms)
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

	it("starts on KingdomJoined (not PlayerReady) and logs Spawn", function()
		boot(true)
		bus.PlayerReady:fire(p1)
		expect(steps(p1)).toEqual({})
		join(p1, "crimson")
		expect(steps(p1)).toEqual({ "Spawn" })
		expect(onboarding:state(p1, "vs1").stepId).toBe("Gather")
	end)

	it("runs the whole slice for co-rulers with the G9 attribution rules", function()
		boot(true)
		join(p1, "crimson")
		join(p2, "crimson")
		bus.ResourceGathered:fire(nil, "crimson", "wood", 5, "citizen") -- citizens: not the ruler's gather
		expect(steps(p1)).toEqual({ "Spawn" })
		bus.ResourceGathered:fire(p1, "crimson", "wood", 3, "ruler")
		bus.BuildingPlaced:fire({ id = 7, kingdom = "crimson", type = "house", level = 1, placedBy = p1.UserId }, p1)
		bus.BuildingCompleted:fire({ id = 7, kingdom = "crimson", type = "house", level = 1, placedBy = p1.UserId }, p1)
		bus.UnitsRecruited:fire(p1, "crimson", 3)
		bus.ObjectiveCaptured:fire("tower_1", "crimson")
		expect(steps(p1)).toEqual({ "Spawn", "Gather", "PlaceBuilding", "BuildingComplete", "Recruit", "Capture" })
		expect(onboarding:state(p1, "vs1").done).toBe(true)
		-- p2 only gathered nothing yet: the completion and the capture are remembered for later
		expect(steps(p2)).toEqual({ "Spawn" })
		bus.ResourceGathered:fire(p2, "crimson", "stone", 2, "ruler")
		bus.BuildingPlaced:fire({ id = 8, kingdom = "crimson", type = "farm", level = 1, placedBy = p2.UserId }, p2)
		expect(steps(p2)).toEqual({ "Spawn", "Gather", "PlaceBuilding", "BuildingComplete" })
	end)

	it("never credits a rival kingdom's capture or build", function()
		boot(true)
		join(p1, "crimson")
		join(p2, "azure")
		bus.ResourceGathered:fire(p1, "crimson", "wood", 3, "ruler")
		bus.BuildingPlaced:fire({ id = 9, kingdom = "azure", type = "house", level = 1, placedBy = p2.UserId }, p2)
		bus.ObjectiveCaptured:fire("tower_1", "azure")
		expect(steps(p1)).toEqual({ "Spawn", "Gather" })
		expect(onboarding:state(p1, "vs1").stepId).toBe("PlaceBuilding")
		-- the rival's capture must not have been remembered for p1 either
		bus.BuildingPlaced:fire({ id = 10, kingdom = "crimson", type = "farm", level = 1, placedBy = p1.UserId }, p1)
		bus.BuildingCompleted:fire({ id = 10, kingdom = "crimson", type = "farm", level = 1 }, p1)
		bus.UnitsRecruited:fire(p1, "crimson", 3)
		expect(onboarding:state(p1, "vs1").stepId).toBe("Capture")
		expect(onboarding:state(p1, "vs1").done).toBe(false)
	end)

	it("keeps progress for the session only: a rejoin after leaving starts over", function()
		boot(true)
		join(p1, "crimson")
		bus.ResourceGathered:fire(p1, "crimson", "wood", 3, "ruler")
		expect(onboarding:state(p1, "vs1").stepId).toBe("PlaceBuilding")
		expect(registry:get("SettingsService"):isPersistent()).toBe(false)
		expect(env.mock:hasLog("warn", "progress not saved")).toBe(false)
		env.mock.players:remove(p1)
		local again = env.mock.players:add({ userId = 1101 })
		bus.KingdomJoined:fire(again, "crimson")
		expect(onboarding:state(again, "vs1").stepId).toBe("Gather")
	end)

	it("without KingdomService, kingdom-wide steps credit nobody but nothing breaks", function()
		boot(false)
		bus.KingdomJoined:fire(p1, "crimson")
		bus.ResourceGathered:fire(p1, "crimson", "wood", 3, "ruler")
		bus.BuildingPlaced:fire({ id = 1, kingdom = "crimson", type = "house", level = 1, placedBy = p1.UserId }, p1)
		bus.BuildingCompleted:fire({ id = 1, kingdom = "crimson", type = "house", level = 1 }, p1)
		expect(steps(p1)).toEqual({ "Spawn", "Gather", "PlaceBuilding" })
		expect(env.mock:hasLog("warn", "subjects resolver")).toBe(false)
	end)

	it("skipping logs OnboardingSkipped and no later funnel step", function()
		boot(true)
		join(p1, "crimson")
		expect((remotes:call("Experience.OnboardingSkip", p1, "vs1"))).toBe(true)
		bus.ResourceGathered:fire(p1, "crimson", "wood", 3, "ruler")
		expect(steps(p1)).toEqual({ "Spawn" })
		local skipped = false
		for _, call in env.AnalyticsService:callsTo("LogCustomEvent") do
			skipped = skipped or call.args[1] == "OnboardingSkipped"
		end
		expect(skipped).toBe(true)
	end)
end)
