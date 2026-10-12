-- PolicyService, AnalyticsService and CollectionService mocks.
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")

describe("MockPolicyService", function()
	it("answers the permissive default and per-player overrides (ArePaidRandomItemsRestricted)", function()
		local env = MockEnv.new()
		local free = env.mock.players:add({ userId = 1 })
		local restricted = env.mock.players:add({ userId = 2 })
		env.PolicyService:setPolicy(2, { ArePaidRandomItemsRestricted = true })
		expect(env.PolicyService:GetPolicyInfoForPlayerAsync(free).ArePaidRandomItemsRestricted).toBe(false)
		expect(env.PolicyService:GetPolicyInfoForPlayerAsync(restricted).ArePaidRandomItemsRestricted).toBe(true)
		expect(env.PolicyService:GetPolicyInfoForPlayerAsync(restricted).AllowedExternalLinkReferences).toEqual({})
		expect(env.PolicyService.calls).toEqual({ 1, 2, 2 })
	end)

	it("fails like the async web call can (failNext, failFor) and rejects non-players", function()
		local env = MockEnv.new()
		local player = env.mock.players:add({ userId = 3 })
		env.PolicyService:failNext(1)
		expect(function()
			env.PolicyService:GetPolicyInfoForPlayerAsync(player)
		end).toThrow("HTTP 500")
		expect(env.PolicyService:GetPolicyInfoForPlayerAsync(player).AreAdsAllowed).toBe(true)
		env.PolicyService:failFor(3, "Players not found")
		expect(function()
			env.PolicyService:GetPolicyInfoForPlayerAsync(player)
		end).toThrow("Players not found")
		env.PolicyService:clearFailures()
		expect(function()
			env.PolicyService:GetPolicyInfoForPlayerAsync({ UserId = 3 })
		end).toThrow("Instance was not a player")
	end)

	it("returns a copy each time", function()
		local env = MockEnv.new()
		local player = env.mock.players:add({ userId = 4 })
		local policy = env.PolicyService:GetPolicyInfoForPlayerAsync(player)
		policy.AreAdsAllowed = false
		expect(env.PolicyService:GetPolicyInfoForPlayerAsync(player).AreAdsAllowed).toBe(true)
	end)
end)

describe("MockAnalyticsService", function()
	it("records calls with their arguments", function()
		local env = MockEnv.new()
		local player = env.mock.players:add({ userId = 1 })
		env.AnalyticsService:LogCustomEvent(player, "RoundWon", 1, { CustomField01 = "sandbox" })
		env.AnalyticsService:LogOnboardingFunnelStepEvent(player, 1, "Spawned")
		expect(#env.AnalyticsService.calls).toBe(2)
		local custom = env.AnalyticsService:callsTo("LogCustomEvent")[1]
		expect(custom.userId).toBe(1)
		expect(custom.args[1]).toBe("RoundWon")
		expect(custom.args[3]).toEqual({ CustomField01 = "sandbox" })
	end)

	it("throw mode errors (callers must isolate analytics) and noop mode drops calls", function()
		local env = MockEnv.new()
		local player = env.mock.players:add({ userId = 1 })
		env.AnalyticsService:setMode("throw", "analytics outage")
		expect(function()
			env.AnalyticsService:LogEconomyEvent(
				player,
				Enum.AnalyticsEconomyFlowType.Source,
				"Coins",
				5,
				5,
				"Gameplay"
			)
		end).toThrow("analytics outage")
		env.AnalyticsService:setMode("noop")
		env.AnalyticsService:LogCustomEvent(player, "Ignored")
		expect(#env.AnalyticsService.calls).toBe(0)
	end)

	it("requires a Player as the first argument", function()
		local env = MockEnv.new()
		expect(function()
			env.AnalyticsService:LogCustomEvent(nil, "NoPlayer")
		end).toThrow("argument 1 must be a Player")
	end)
end)

describe("MockCollectionService", function()
	it("tags instances in the DataModel and finds them with GetTagged", function()
		local env = MockEnv.new()
		local cs = env.CollectionService
		local spawnA = Instance.new("Part")
		spawnA.Parent = env.Workspace
		local loose = Instance.new("Part") -- not in the DataModel
		cs:AddTag(spawnA, "ForgeSpawn")
		cs:AddTag(loose, "ForgeSpawn")
		expect(cs:HasTag(spawnA, "ForgeSpawn")).toBe(true)
		local tagged = cs:GetTagged("ForgeSpawn")
		expect(#tagged).toBe(1)
		expect(tagged[1] == spawnA).toBe(true)
		expect(cs:GetTags(spawnA)).toEqual({ "ForgeSpawn" })
		expect(cs:GetAllTags()).toEqual({ "ForgeSpawn" })
	end)

	it("fires added/removed signals for tag changes inside the DataModel", function()
		local env = MockEnv.new()
		local cs = env.CollectionService
		local events = {}
		cs:GetInstanceAddedSignal("ForgeFloodProbe"):Connect(function(inst)
			table.insert(events, "added " .. inst.Name)
		end)
		cs:GetInstanceRemovedSignal("ForgeFloodProbe"):Connect(function(inst)
			table.insert(events, "removed " .. inst.Name)
		end)
		local probe = Instance.new("Part")
		probe.Name = "Probe1"
		probe.Parent = env.Workspace
		cs:AddTag(probe, "ForgeFloodProbe")
		cs:AddTag(probe, "ForgeFloodProbe") -- already tagged: no second event
		cs:RemoveTag(probe, "ForgeFloodProbe")
		expect(events).toEqual({ "added Probe1", "removed Probe1" })
		expect(#cs:GetTagged("ForgeFloodProbe")).toBe(0)
	end)
end)
