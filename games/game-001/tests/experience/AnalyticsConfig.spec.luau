local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local AnalyticsSchema = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsSchema")
local AnalyticsRouter = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsRouter")
local Subjects = require("@game/ReplicatedStorage/Forge/Experience/Subjects")
local Analytics = require("@game/ReplicatedStorage/Forge/Config/Analytics")
local OnboardingConfig = require("@game/ReplicatedStorage/Forge/Config/Onboarding")
local Onboarding = require("@game/ReplicatedStorage/Forge/Experience/Onboarding")
local AnalyticsDef = require("@game/ServerScriptService/Forge/Services/AnalyticsService")

local KNOWN = AnalyticsRouter.knownEvents(GameEvents)

describe("game-001 Analytics.luau", function()
	it("is valid for the framework adapter (schema and resolvers)", function()
		expect(AnalyticsSchema.validate(Analytics, KNOWN)).toEqual({})
		expect(Subjects.validate(Analytics.subjects, KNOWN)).toEqual({})
	end)

	it("every event Onboarding.luau and Analytics.luau listen to has a resolver (FORGE-00 review M8)", function()
		expect(Subjects.missing(Onboarding.events(OnboardingConfig), OnboardingConfig.subjects)).toEqual({})
		local listened = {}
		for _, rule in Analytics.track or {} do
			table.insert(listened, rule.on)
		end
		local session = Analytics.session or {}
		table.insert(listened, session.startOn or "PlayerReady")
		expect(Subjects.missing(listened, Analytics.subjects)).toEqual({})
	end)

	it("stays inside the documented caps and the house budget", function()
		local budget = AnalyticsSchema.budget(Analytics)
		expect(budget.events).toBeLessThanOrEqual(AnalyticsSchema.HOUSE.customEventNames)
		expect(budget.funnels).toBeLessThanOrEqual(AnalyticsSchema.HOUSE.funnels)
		expect(budget.fieldsPerEvent).toBeLessThanOrEqual(AnalyticsSchema.CAPS.customFields)
	end)

	it("declares the BRIEF §13 VS-1 funnel in order", function()
		expect(Analytics.funnels.VS1.steps).toEqual({
			"Spawn",
			"FirstGather",
			"FirstBuildPlaced",
			"FirstBuildingComplete",
			"FirstRecruit",
			"FirstCapture",
		})
	end)

	it("boots the framework AnalyticsService enabled in the game project", function()
		local env = MockEnv.new()
		local registry = Loader.load(env, { AnalyticsDef })
		expect(env.mock:hasLog("error", "analytics config invalid")).toBe(false)
		expect(registry:get("AnalyticsService")._enabled).toBe(true)
	end)
end)
