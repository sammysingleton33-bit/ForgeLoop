--[[
	FL-0108 (2/2): ConversationAnswered end to end. FORGE-01's real ConversationService, CitizenService and
	match fire G9 CitizenAnswered on an accepted Kingdom.Choose (FL-0107); the framework AnalyticsService
	with game-001's config/Analytics.luau logs it through its track rule, with the occupation that
	Feedback/Signals reads from CitizenService:inspect (G13.2). ConversationService never calls
	AnalyticsService (D-044 (3)).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local SimRemotes = require("@game/ReplicatedStorage/Game/Sim/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")
local AnalyticsDef = require("@game/ServerScriptService/Forge/Services/AnalyticsService")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local booted = {}

local function boot()
	local env = MockEnv.new({
		seed = 12,
		sharedModules = {
			Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Sim = SimRemotes, Treasury = TreasuryRemotes },
		},
	})
	local definitions = { AnalyticsDef }
	for _, name in
		{
			"RemoteService",
			"MatchService",
			"KingdomService",
			"CitizenService",
			"ReputationService",
			"ConversationService",
			"TreasuryService",
			"ProductionService",
		}
	do
		table.insert(definitions, service(name))
	end
	local registry = Loader.load(env, definitions)
	table.insert(booted, { registry = registry, env = env })
	registry:get("KingdomService").adapter = {
		partyOf = function(player)
			return if player.UserId <= 2 then "party" else nil -- users 1 and 2 rule crimson together
		end,
		load = function()
			return nil
		end,
		pivot = function() end,
		attach = function() end,
		onDied = function()
			return nil
		end,
		respawnDelay = function()
			return 5
		end,
	}
	local conversations = registry:get("ConversationService")
	conversations._send = function() end -- no EntityService here: the G13.3 events go nowhere
	return env, conversations, registry
end

afterEach(function()
	for _, b in booted do
		b.registry:destroy()
	end
	table.clear(booted)
	GameEvents.disconnectAll()
end)

-- a hungry crimson farmer whose farmer_hungry_grain request holds (as FORGE-01's ConversationService.spec)
local function hungryFarmer(registry)
	local sim = registry:get("MatchService").host.match.sim
	local k = sim.kingdoms.crimson
	local farmer
	for _, id in k.citizenIds do
		local c = sim.citizens[id]
		if c.profile.occupation == "farmer" then
			farmer = farmer or c
			if #c.profile.family > 0 then
				farmer = c
				break
			end
		end
	end
	if #farmer.profile.family == 0 then
		local other = sim.citizens[k.citizenIds[#k.citizenIds]]
		table.insert(farmer.profile.family, other.id)
		table.insert(other.profile.family, farmer.id)
	end
	registry:get("CitizenService"):setFedRatio("crimson", 0.6)
	farmer.hunger = 0.5
	for _, resource in { "food", "wood", "stone" } do
		sim:deposit("crimson", resource, 300, `test:{resource}`, "test")
	end
	return farmer
end

describe("ConversationAnswered from G9 CitizenAnswered, real producer (FL-0108)", function()
	it("an accepted answer logs one ConversationAnswered for the ruler who gave it", function()
		local env, conversations, registry = boot()
		local players = {}
		for i = 1, 2 do
			players[i] = env.mock.players:add({ userId = i, displayName = `Ruler{i}` })
		end
		env.mock:advance(1)
		local farmer = hungryFarmer(registry)
		conversations:refresh() -- the request bubble appears now
		env.mock:advance(5)
		assert(conversations:converse(players[2], farmer.id))
		assert(conversations:choose(players[2], farmer.id, "farmer_hungry_grain", "farmer_hungry_grain_open_store"))
		local function logged()
			local out = {}
			for _, call in env.AnalyticsService:callsTo("LogCustomEvent") do
				if call.args[1] == "ConversationAnswered" then
					table.insert(out, call)
				end
			end
			return out
		end
		local answered = logged()
		expect(#answered).toBe(1)
		expect(answered[1].userId).toBe(2) -- the co-ruler who did not answer gets nothing
		expect(answered[1].args[2]).toBeNear(5, 0.6) -- secondsOpen
		expect(answered[1].args[3]).toEqual({ CustomField01 = "farmer", CustomField02 = "grain_open_store" })
		-- a refused repeat fires no G9 event, so nothing more is logged
		local again =
			conversations:choose(players[2], farmer.id, "farmer_hungry_grain", "farmer_hungry_grain_open_store")
		expect(again).toBe(false)
		expect(#logged()).toBe(1)
		expect(env.mock.threadErrors).toEqual({})
	end)
end)
