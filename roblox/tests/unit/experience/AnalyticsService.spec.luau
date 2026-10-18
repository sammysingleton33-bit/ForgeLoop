local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local FakeBus = require("./doubles/FakeBus")
local FakeDataService = require("./doubles/FakeDataService")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local AnalyticsDef = require("@game/ServerScriptService/Forge/Services/AnalyticsService")
local TestAnalytics = require("./doubles/TestAnalytics")

local function boot(env, options)
	local defs = {
		{
			name = "AnalyticsService",
			new = function(e, registry)
				return AnalyticsDef.create(e, registry, options)
			end,
		},
	}
	if options and options.data then
		table.insert(defs, {
			name = "DataService",
			new = function()
				return options.data
			end,
		})
	end
	local registry = Loader.load(env, defs)
	return registry:get("AnalyticsService"), registry
end

local function analyticsLogs(env)
	local out = {}
	for _, entry in env.mock.logs do
		if string.sub(entry.message, 1, 10) == "analytics " then
			table.insert(out, entry)
		end
	end
	return out
end

describe("AnalyticsService adapter (§8)", function()
	local env, service, player, roblox

	beforeEach(function()
		GameEvents.disconnectAll()
		env = MockEnv.new({ seed = 3 })
		roblox = env.AnalyticsService
		player = env.mock.players:add({ userId = 101 })
		service = boot(env, { config = TestAnalytics.build(), bus = FakeBus.new() })
	end)

	describe("event()", function()
		it("maps the value field and CustomField01-03 in declared order, as strings", function()
			expect(
				service:event(
					player,
					"MatchEnded",
					{ durationSec = 1800, won = true, placement = 2, mode = "kingdoms" }
				)
			).toBe(true)
			local call = roblox:callsTo("LogCustomEvent")[1]
			expect(call.args[1]).toBe("MatchEnded")
			expect(call.args[2]).toBe(1800)
			expect(call.args[3]).toEqual({ CustomField01 = "true", CustomField02 = "2", CustomField03 = "kingdoms" })
		end)

		it("sends value 1 for counter events", function()
			service:event(player, "AchievementUnlocked", { achievementId = "first_farm" })
			local call = roblox:callsTo("LogCustomEvent")[1]
			expect(call.args[2]).toBe(1)
			expect(call.args[3]).toEqual({ CustomField01 = "first_farm" })
		end)

		it("drops undeclared events and warns once", function()
			expect(service:event(player, "NotAnEvent", {})).toBe(false)
			expect(service:event(player, "NotAnEvent", {})).toBe(false)
			expect(#roblox.calls).toBe(0)
			expect(service.stats.dropped.undeclared).toBe(2)
			local warns = 0
			for _, entry in env.mock.logs do
				if entry.level == "warn" and string.find(entry.message, "'NotAnEvent' is not declared", 1, true) then
					warns += 1
				end
			end
			expect(warns).toBe(1)
		end)

		it("drops undeclared fields but still sends the event", function()
			service:event(player, "BuildingCompleted", { level = 2, buildingType = "Farm", playerName = "x" })
			local call = roblox:callsTo("LogCustomEvent")[1]
			expect(call.args[3]).toEqual({ CustomField01 = "Farm" })
			expect(env.mock:hasLog("warn", "field 'playerName' is not declared")).toBe(true)
		end)

		it("rejects a non-Player first argument without throwing", function()
			expect(service:event({ UserId = 1 }, "SessionStart", {})).toBe(false)
			expect(service.stats.dropped.invalid).toBe(1)
		end)
	end)

	describe("funnel()", function()
		it("routes the onboarding funnel to LogOnboardingFunnelStepEvent", function()
			expect(service:funnel(player, "Onboarding", 1, "Arrive")).toBe(true)
			local call = roblox:callsTo("LogOnboardingFunnelStepEvent")[1]
			expect(call.args[1]).toBe(1)
			expect(call.args[2]).toBe("Arrive")
		end)

		it("sends once funnels without a session id and uses the configured step name", function()
			service:funnel(player, "FirstMatch", 3, "Wrong")
			local call = roblox:callsTo("LogFunnelStepEvent")[1]
			expect(call.args[1]).toBe("FirstMatch")
			expect(call.args[2]).toBeNil()
			expect(call.args[3]).toBe(3)
			expect(call.args[4]).toBe("FirstBuilding")
			expect(env.mock:hasLog("warn", "FirstMatch step 3 is 'FirstBuilding'")).toBe(true)
		end)

		it("drops recurring funnel steps without a sessionId", function()
			expect(service:funnel(player, "Shop", 1, "Opened")).toBe(false)
			expect(service.stats.dropped.missingSession).toBe(1)
			expect(service:funnel(player, "Shop", 1, "Opened", { sessionId = "s1" })).toBe(true)
			expect(roblox:callsTo("LogFunnelStepEvent")[1].args[2]).toBe("s1")
		end)

		it("does not re-send a step of the same session, but does for a new session", function()
			service:funnel(player, "Shop", 1, "Opened", { sessionId = "s1" })
			service:funnel(player, "Shop", 1, "Opened", { sessionId = "s1" })
			service:funnel(player, "Shop", 1, "Opened", { sessionId = "s2" })
			expect(#roblox:callsTo("LogFunnelStepEvent")).toBe(2)
			expect(service.stats.dropped.duplicate).toBe(1)
		end)

		it("rejects steps outside 1..#steps", function()
			expect(service:funnel(player, "Return", 3, "Nope")).toBe(false)
			expect(service:funnel(player, "Return", 0, "Nope")).toBe(false)
			expect(service:funnel(player, "Unknown", 1, "X")).toBe(false)
			expect(#roblox.calls).toBe(0)
		end)
	end)

	describe("economy()", function()
		it("passes the flow enum, currency, amount, balance, txType and sku", function()
			expect(service:economy(player, "source", "Coins", 50, 150, "Gameplay", "match_reward")).toBe(true)
			local call = roblox:callsTo("LogEconomyEvent")[1]
			expect(call.args[1]).toBe(Enum.AnalyticsEconomyFlowType.Source)
			expect(call.args[2]).toBe("Coins")
			expect(call.args[3]).toBe(50)
			expect(call.args[4]).toBe(150)
			expect(call.args[5]).toBe("Gameplay")
			expect(call.args[6]).toBe("match_reward")
		end)

		it("rejects non-positive amounts, negative balances and unknown flows", function()
			expect(service:economy(player, "source", "Coins", 0, 10, "Gameplay")).toBe(false)
			expect(service:economy(player, "sink", "Coins", 5, -1, "Shop")).toBe(false)
			expect(service:economy(player, "gift", "Coins", 5, 1, "Shop")).toBe(false)
			expect(#roblox.calls).toBe(0)
		end)

		it("warns about custom transaction types (20 per experience)", function()
			service:economy(player, "sink", "Coins", 5, 10, "Banquet")
			expect(env.mock:hasLog("warn", "custom transaction type 'Banquet'")).toBe(true)
			expect(#roblox.calls).toBe(1)
		end)
	end)

	describe("failure isolation", function()
		it("never throws when Roblox errors, counts failures and warns once per interval", function()
			roblox:setMode("throw", "HTTP 500 [mock]")
			for _ = 1, 5 do
				expect(service:event(player, "SessionStart", { daysSinceFirstJoin = 0 })).toBe(false)
			end
			expect(service.stats.failed).toBe(5)
			local warns = 0
			for _, entry in env.mock.logs do
				if entry.level == "warn" and string.find(entry.message, "call failed", 1, true) then
					warns += 1
				end
			end
			expect(warns).toBe(1)
			env.wait(61)
			service:event(player, "SessionStart", { daysSinceFirstJoin = 0 })
			local after = 0
			for _, entry in env.mock.logs do
				if entry.level == "warn" and string.find(entry.message, "call failed", 1, true) then
					after += 1
				end
			end
			expect(after).toBe(2)
		end)

		it("is a no-op when AnalyticsService is unavailable", function()
			local bare = MockEnv.new()
			bare.AnalyticsService = nil
			local p = bare.mock.players:add({ userId = 7 })
			local s = boot(bare, { config = TestAnalytics.build(), bus = FakeBus.new() })
			expect(s:event(p, "SessionStart", {})).toBe(false)
			expect(s.stats.dropped.unavailable).toBe(1)
		end)

		it("disables itself (no throw) when the config is invalid", function()
			local broken = TestAnalytics.build()
			broken.funnels = { Bad = { kind = "nope", description = "x" } }
			local s = boot(env, { config = broken, bus = FakeBus.new() })
			expect(env.mock:hasLog("error", "analytics config invalid")).toBe(true)
			expect(s:event(player, "SessionStart", {})).toBe(false)
			expect(s.stats.dropped.disabled).toBe(1)
		end)
	end)

	describe("rate cap (120 + 20 x CCU per minute, event-types.md; per server: its players' share)", function()
		it("sizes the server bucket from its players' share, so servers together stay under the cap (L8)", function()
			local function capacityWith(count)
				local e = MockEnv.new({ seed = 30 + count })
				for i = 1, count do
					e.mock.players:add({ userId = 900 + i })
				end
				local s = boot(e, { config = TestAnalytics.build(), bus = FakeBus.new() })
				return s._capacity
			end
			expect(capacityWith(0)).toBe(20) -- the floor: one player's share
			expect(capacityWith(1)).toBe(20)
			expect(capacityWith(2)).toBe(32) -- floor(0.8 x 20 x 2)
			expect(capacityWith(16)).toBe(256)
			-- FORGE-00's example: 4 full 16-player servers need 4 x 256 = 1024 <= 120 + 20 x 64 = 1400
			expect(4 * capacityWith(16) <= 120 + 20 * 64).toBe(true)
		end)

		it("caps one player at perPlayerPerMinute and refills over time", function()
			for i = 2, 4 do -- 4 players: the server allows 64 a minute, custom events 48
				env.mock.players:add({ userId = 100 + i })
			end
			local sent = 0
			for _ = 1, 40 do
				if service:event(player, "AchievementUnlocked", { achievementId = "a" }) then
					sent += 1
				end
			end
			expect(sent).toBe(30)
			expect(service.stats.dropped.playerRate).toBe(10)
			env.wait(30)
			expect(service:event(player, "AchievementUnlocked", { achievementId = "a" })).toBe(true)
		end)

		it("keeps a reserve for funnels when custom events exhaust the server budget", function()
			local players = { player }
			for i = 2, 10 do
				table.insert(players, env.mock.players:add({ userId = 100 + i }))
			end
			-- 10 players: floor(200 * 0.8) = 160 per minute; custom events stop at 160 * 0.75 = 120
			local sent = 0
			for _, p in players do
				for _ = 1, 25 do
					if service:event(p, "AchievementUnlocked", { achievementId = "a" }) then
						sent += 1
					end
				end
			end
			expect(sent).toBe(120)
			expect(service.stats.dropped.rate).toBe(130)
			expect(service:funnel(players[10], "FirstMatch", 1, "MatchJoined")).toBe(true)
			expect(env.mock:hasLog("warn", "rate cap reached")).toBe(true)
		end)
	end)

	describe("env.log trail", function()
		it("writes every call, sent or dropped, in order", function()
			service:funnel(player, "Onboarding", 1, "Arrive")
			service:funnel(player, "Onboarding", 2, "MoveRuler")
			service:funnel(player, "Shop", 1, "Opened")
			local logs = analyticsLogs(env)
			expect(#logs).toBe(3)
			expect(logs[1].message).toBe("analytics funnel Onboarding")
			expect(logs[1].fields.step).toBe(1)
			expect(logs[1].fields.sent).toBe(true)
			expect(logs[2].fields.stepName).toBe("MoveRuler")
			expect(logs[3].fields.sent).toBe(false)
			expect(logs[3].fields.reason).toBe("missingSession")
		end)
	end)
end)

describe("AnalyticsService bus wiring", function()
	local env, bus, player, roblox, service, members

	beforeEach(function()
		GameEvents.disconnectAll()
		env = MockEnv.new({ seed = 4 })
		roblox = env.AnalyticsService
		bus = FakeBus.new({ extra = { "TestDuel" } })
		player = env.mock.players:add({ userId = 201 })
		local second = env.mock.players:add({ userId = 202 }) -- second ruler (defender in duel specs)
		members = { crimson = { player, second }, azure = {} }
		service = boot(env, {
			config = TestAnalytics.build({
				membersOf = function(kingdom)
					return members[kingdom] or {}
				end,
				matchId = function()
					return "m7"
				end,
				duel = true,
			}),
			bus = bus,
		})
	end)

	local function funnelSteps(name)
		local steps = {}
		for _, call in roblox:callsTo("LogFunnelStepEvent") do
			if call.args[1] == name then
				table.insert(
					steps,
					{ userId = call.userId, session = call.args[2], step = call.args[3], name = call.args[4] }
				)
			end
		end
		return steps
	end

	it("gives each shop open its own session id and continues it on purchase", function()
		bus.ShopViewed:fire(player, "main", nil)
		bus.PurchaseCompleted:fire(player, "product", 123, 50)
		bus.ShopViewed:fire(player, "main", "banner_gold")
		local steps = funnelSteps("Shop")
		expect(#steps).toBe(3)
		expect(steps[1].step).toBe(1)
		expect(steps[2].step).toBe(2)
		expect(steps[2].session).toBe(steps[1].session)
		expect(steps[3].session).never.toBe(steps[1].session)
	end)

	it("drops a purchase step with no open shop session (no fake conversions)", function()
		bus.PurchaseCompleted:fire(player, "product", 123, 50)
		expect(#funnelSteps("Shop")).toBe(0)
		expect(service.stats.dropped.noSession).toBe(1)
	end)

	it("expires a shop session after sessionTtlSec", function()
		bus.ShopViewed:fire(player, "main", nil)
		env.wait(901)
		bus.PurchaseCompleted:fire(player, "product", 1, 10)
		expect(#funnelSteps("Shop")).toBe(1)
	end)

	it("logs MatchEnded per participant still in the server, with won/placement", function()
		bus.RoundEnded:fire({
			roundId = "m1",
			mode = "kingdoms",
			startedAt = 1000,
			endedAt = 3400,
			participants = {
				{ userId = 201, placement = 1, eliminations = 2, survivedSec = 2400 },
				{ userId = 202, placement = 2, eliminations = 0, survivedSec = 2400 },
				{ userId = 999, placement = 3, eliminations = 0, survivedSec = 100 },
			},
			winners = { 201 },
		})
		local ended = {}
		for _, call in roblox:callsTo("LogCustomEvent") do
			if call.args[1] == "MatchEnded" then
				ended[call.userId] = call.args
			end
		end
		expect(ended[201][2]).toBe(2400)
		expect(ended[201][3]).toEqual({ CustomField01 = "true", CustomField02 = "1", CustomField03 = "kingdoms" })
		expect(ended[202][3].CustomField01).toBe("false")
		expect(ended[999]).toBeNil()
		local finished = funnelSteps("MatchProgress")
		expect(#finished).toBe(2)
		expect(finished[1].session).toBe("m1")
	end)

	it("runs the match funnel per match from game events through config resolvers", function()
		bus.RoundStateChanged:fire("Active", { roundId = "m7", endsAt = nil })
		bus.BuildingCompleted:fire({ id = 1, kingdom = "crimson", type = "farm", level = 1 }, player)
		bus.UnitsRecruited:fire(player, "crimson", 3)
		local steps = {}
		for _, s in funnelSteps("MatchProgress") do
			if s.userId == 201 then
				table.insert(steps, s.name)
			end
		end
		expect(steps).toEqual({ "Joined", "FirstBuilding", "FirstArmy" })
		local first = {}
		for _, s in funnelSteps("FirstMatch") do
			if s.userId == 201 then
				table.insert(first, s.name)
			end
		end
		expect(first).toEqual({ "MatchJoined", "FirstBuilding", "FirstArmy" })
	end)

	it("credits every current member of the kingdom, and nobody else, for a completion", function()
		local outsider = env.mock.players:add({ userId = 203 })
		bus.BuildingCompleted:fire({ id = 2, kingdom = "crimson", type = "house", level = 1 }, nil)
		local credited = {}
		for _, s in funnelSteps("FirstMatch") do
			credited[s.userId] = s.name
		end
		expect(credited[201]).toBe("FirstBuilding")
		expect(credited[202]).toBe("FirstBuilding")
		expect(credited[outsider.UserId]).toBeNil()
	end)

	it("isolates a resolver that errors (no calls, no crash)", function()
		members = nil -- membersOf now indexes nil and errors inside the resolver
		bus.BuildingCompleted:fire({ id = 3, kingdom = "crimson", type = "farm", level = 1 }, player)
		expect(#funnelSteps("FirstMatch")).toBe(0)
		expect(service.stats.failed).toBe(0)
		expect(env.mock:hasLog("warn", "subjects resolver for BuildingCompleted failed")).toBe(true)
	end)

	it("logs both sides of a two-party event with who won", function()
		local defender = env.mock.players:get(202)
		bus.TestDuel:fire(player, defender, defender)
		local byUser = {}
		for _, call in roblox:callsTo("LogCustomEvent") do
			if call.args[1] == "BattleEnded" then
				byUser[call.userId] = call.args[3]
			end
		end
		expect(byUser[201]).toEqual({ CustomField01 = "actor", CustomField02 = "false" })
		expect(byUser[202]).toEqual({ CustomField01 = "defender", CustomField02 = "true" })
	end)

	it("works on the real GameEvents bus (game events are declared there, D-024)", function()
		local real = MockEnv.new({ seed = 5 })
		local p = real.mock.players:add({ userId = 301 })
		local s = boot(real, { config = TestAnalytics.build() })
		GameEvents.ShopViewed:fire(p, "main", nil)
		expect(#real.AnalyticsService:callsTo("LogFunnelStepEvent")).toBe(1)
		expect(s.stats.failed).toBe(0)
		expect(real.mock:hasLog("error", "analytics")).toBe(false)
	end)

	it("does not double-count once-funnel steps within a session", function()
		bus.ResourceGathered:fire(player, "crimson", "food", 3, "ruler")
		bus.ResourceGathered:fire(player, "crimson", "food", 3, "ruler")
		bus.ResourceGathered:fire(nil, "crimson", "wood", 5, "citizen") -- citizens: no player credit
		expect(#funnelSteps("FirstReward")).toBe(1)
	end)
end)

describe("AnalyticsService sessions", function()
	local env, bus, roblox, data

	local function loadCore(player, createdAt)
		data:load(player, { core = { version = 1, data = { createdAt = createdAt } } })
	end

	beforeEach(function()
		GameEvents.disconnectAll()
		env = MockEnv.new({ seed = 6, startTime = 1700000000 })
		roblox = env.AnalyticsService
		bus = FakeBus.new()
		data = FakeDataService.new()
		data:registerNamespace("core", {
			version = 1,
			defaults = function()
				return { createdAt = 0 }
			end,
		})
	end)

	it("logs SessionStart (days since first join), the Return funnel, and SessionEnd with the last activity", function()
		local player = env.mock.players:add({ userId = 401 })
		loadCore(player, 1700000000 - 86400)
		boot(env, {
			config = TestAnalytics.build({
				membersOf = function()
					return { env.mock.players:get(401) }
				end,
			}),
			bus = bus,
			data = data,
		})
		bus.PlayerReady:fire(player)
		local start = roblox:callsTo("LogCustomEvent")[1]
		expect(start.args[1]).toBe("SessionStart")
		expect(start.args[2]).toBe(1)
		expect(start.args[3]).toEqual({ CustomField01 = "return" })
		local ret = roblox:callsTo("LogFunnelStepEvent")[1]
		expect(ret.args[1]).toBe("Return")
		expect(ret.args[3]).toBe(2)
		expect(ret.args[4]).toBe("ReturnNextDay")
		bus.BuildingCompleted:fire({ id = 9, kingdom = "crimson", type = "farm", level = 1 }, player)
		env.wait(125)
		env.mock.players:remove(player)
		local last = roblox.calls[#roblox.calls]
		expect(last.args[1]).toBe("SessionEnd")
		expect(last.args[2]).toBe(125)
		expect(last.args[3]).toEqual({ CustomField01 = "BuildingCompleted" })
	end)

	it("starts on config.session.startOn, logs leftInfo's event before SessionEnd, and keeps the drop-off", function()
		local config = TestAnalytics.build()
		config.events.Left = { description = "left mid-match", value = "minute", fields = { "phase" } }
		local asked = {}
		config.session = {
			startEvent = "SessionStart",
			endEvent = "SessionEnd",
			startOn = "ShopViewed", -- any declared bus event whose first argument is the player
			leftEvent = "Left",
			leftInfo = function(player, ctx)
				table.insert(asked, { userId = player.UserId, hasRegistry = ctx.registry ~= nil })
				return { phase = "Conflict", minute = 7 }
			end,
		}
		local player = env.mock.players:add({ userId = 406 })
		local never = env.mock.players:add({ userId = 409 }) -- never starts a session
		boot(env, { config = config, bus = bus })
		bus.PlayerReady:fire(player)
		expect(#roblox:callsTo("LogCustomEvent")).toBe(0) -- PlayerReady no longer starts it
		bus.ShopViewed:fire(player, "main", nil)
		bus.ShopViewed:fire(player, "main", nil)
		local starts = 0
		for _, call in roblox:callsTo("LogCustomEvent") do
			starts += if call.args[1] == "SessionStart" then 1 else 0
		end
		expect(starts).toBe(1)
		env.mock.players:remove(player)
		local calls = roblox:callsTo("LogCustomEvent")
		expect(calls[#calls - 1].args[1]).toBe("Left")
		expect(calls[#calls - 1].args[2]).toBe(7)
		expect(calls[#calls - 1].args[3]).toEqual({ CustomField01 = "Conflict" })
		expect(calls[#calls].args[1]).toBe("SessionEnd")
		expect(calls[#calls].args[3]).toEqual({ CustomField01 = "ShopViewed" }) -- not "Left"
		env.mock.players:remove(never)
		expect(asked).toEqual({ { userId = 406, hasRegistry = true } }) -- no session, no leftInfo
	end)

	it("a leftInfo that errors or returns nil logs only SessionEnd", function()
		local config = TestAnalytics.build()
		config.events.Left = { description = "left mid-match", value = "minute", fields = { "phase" } }
		config.session = {
			startEvent = "SessionStart",
			endEvent = "SessionEnd",
			leftEvent = "Left",
			leftInfo = function(player)
				if player.UserId == 407 then
					error("boom")
				end
				return nil
			end,
		}
		local a = env.mock.players:add({ userId = 407 })
		local b = env.mock.players:add({ userId = 408 })
		boot(env, { config = config, bus = bus })
		bus.PlayerReady:fire(a)
		bus.PlayerReady:fire(b)
		env.mock.players:remove(a)
		env.mock.players:remove(b)
		local names = {}
		for _, call in roblox:callsTo("LogCustomEvent") do
			table.insert(names, call.args[1])
		end
		expect(names).toEqual({ "SessionStart", "SessionStart", "SessionEnd", "SessionEnd" })
		expect(env.mock:hasLog("warn", "session.leftInfo failed")).toBe(true)
	end)

	it("milestones: each later step of the funnel logs seconds since the session started (FORGE-00 M7)", function()
		local config = TestAnalytics.build()
		config.events.Milestone =
			{ description = "timed step", value = "sinceStartSec", fields = { "milestone", "mode" } }
		config.session = { startEvent = "SessionStart", endEvent = "SessionEnd", startOn = "ShopViewed" }
		local asked = 0
		config.milestones = {
			funnel = "FirstMatch",
			event = "Milestone",
			info = function(_, ctx)
				asked += 1
				-- info never overrides the value or the step name
				return { mode = if ctx.registry ~= nil then "match30" else "none", milestone = "spoofed" }
			end,
		}
		local player = env.mock.players:add({ userId = 407 })
		local service = boot(env, { config = config, bus = bus })
		expect(service:funnel(player, "FirstMatch", 2, "FirstConstruction")).toBe(true) -- no session yet: no time
		bus.ShopViewed:fire(player, "main", nil) -- the session starts
		env.wait(42.6)
		expect(service:funnel(player, "FirstMatch", 1, "MatchJoined")).toBe(true) -- step 1 is the start: no time
		expect(service:funnel(player, "FirstMatch", 3, "FirstBuilding")).toBe(true)
		expect(service:funnel(player, "FirstMatch", 3, "FirstBuilding")).toBe(false) -- a repeat is not sent
		env.wait(30)
		expect(service:funnel(player, "FirstMatch", 4, "FirstUpgrade")).toBe(true)
		expect(service:funnel(player, "FirstReward", 2, "FirstCurrency")).toBe(true) -- another funnel: no time
		local timed = {}
		for _, call in roblox:callsTo("LogCustomEvent") do
			if call.args[1] == "Milestone" then
				table.insert(timed, { value = call.args[2], fields = call.args[3] })
			end
		end
		expect(timed).toEqual({
			{ value = 42, fields = { CustomField01 = "FirstBuilding", CustomField02 = "match30" } },
			{ value = 72, fields = { CustomField01 = "FirstUpgrade", CustomField02 = "match30" } },
		})
		expect(asked).toBe(2)
		env.mock.players:remove(player)
		local calls = roblox:callsTo("LogCustomEvent")
		expect(calls[#calls].args[1]).toBe("SessionEnd")
		expect(calls[#calls].args[3]).toEqual({ CustomField01 = "ShopViewed" }) -- the drop-off is not "Milestone"
	end)

	it("a track rule on an event no resolver covers disables analytics at boot (FORGE-00 M8)", function()
		local config = TestAnalytics.build()
		table.insert(config.track, { on = "KingdomJoined", funnel = "FirstMatch", step = 1 })
		config.subjects = config.subjects or {}
		config.subjects.KingdomJoined = nil
		local service = boot(env, { config = config, bus = bus })
		expect(env.mock:hasLog("error", "analytics config invalid; analytics disabled")).toBe(true)
		local problems = ""
		for _, entry in env.mock.logs do
			if entry.level == "error" and entry.fields and entry.fields.problems then
				problems = entry.fields.problems
			end
		end
		expect(string.find(problems, "subjects: no resolver for 'KingdomJoined'", 1, true) ~= nil).toBe(true)
		local player = env.mock.players:add({ userId = 410 })
		expect(service:event(player, "SettingChanged", { key = "music", value = 1 })).toBe(false)
		-- the same config with a resolver boots
		local fixed = TestAnalytics.build()
		table.insert(fixed.track, { on = "KingdomJoined", funnel = "FirstMatch", step = 1 })
		fixed.subjects = fixed.subjects or {}
		fixed.subjects.KingdomJoined = function(args)
			return { { player = args[1], info = { kingdom = args[2] } } }
		end
		local ok = boot(env, { config = fixed, bus = bus })
		expect(ok:event(player, "SettingChanged", { key = "music", value = 1 })).toBe(true)
	end)

	it("milestones: an info function that errors still logs the time, warned once", function()
		local config = TestAnalytics.build()
		config.events.Milestone = { description = "timed step", value = "sinceStartSec", fields = { "milestone" } }
		config.session = { startEvent = "SessionStart", endEvent = "SessionEnd", startOn = "ShopViewed" }
		config.milestones = {
			funnel = "FirstMatch",
			event = "Milestone",
			info = function()
				error("boom")
			end,
		}
		local player = env.mock.players:add({ userId = 408 })
		local service = boot(env, { config = config, bus = bus })
		bus.ShopViewed:fire(player, "main", nil)
		env.wait(5)
		service:funnel(player, "FirstMatch", 2, "FirstConstruction")
		local timed = {}
		for _, call in roblox:callsTo("LogCustomEvent") do
			if call.args[1] == "Milestone" then
				table.insert(timed, { value = call.args[2], fields = call.args[3] })
			end
		end
		expect(timed).toEqual({ { value = 5, fields = { CustomField01 = "FirstConstruction" } } })
		expect(env.mock:hasLog("warn", "milestones.info failed")).toBe(true)
	end)

	it("first-day players log Return step 1 (FirstSession)", function()
		local player = env.mock.players:add({ userId = 403 })
		loadCore(player, 1700000000 - 60)
		boot(env, {
			config = TestAnalytics.build({
				membersOf = function()
					return { env.mock.players:get(401) }
				end,
			}),
			bus = bus,
			data = data,
		})
		bus.PlayerReady:fire(player)
		expect(roblox:callsTo("LogCustomEvent")[1].args[3]).toEqual({ CustomField01 = "firstDay" })
		local steps = roblox:callsTo("LogFunnelStepEvent")
		expect(#steps).toBe(1)
		expect(steps[1].args[4]).toBe("FirstSession")
	end)

	it("logs no Return step for later days, and visit 'unknown' without DataService", function()
		local late = env.mock.players:add({ userId = 404 })
		loadCore(late, 1700000000 - 3 * 86400)
		boot(env, {
			config = TestAnalytics.build({
				membersOf = function()
					return { env.mock.players:get(401) }
				end,
			}),
			bus = bus,
			data = data,
		})
		bus.PlayerReady:fire(late)
		expect(#roblox:callsTo("LogFunnelStepEvent")).toBe(0)
		GameEvents.disconnectAll()
		local env2 = MockEnv.new({ seed = 7 })
		local bus2 = FakeBus.new()
		local anon = env2.mock.players:add({ userId = 405 })
		boot(env2, { config = TestAnalytics.build(), bus = bus2 })
		bus2.PlayerReady:fire(anon)
		expect(env2.AnalyticsService:callsTo("LogCustomEvent")[1].args[3]).toEqual({ CustomField01 = "unknown" })
		expect(#env2.AnalyticsService:callsTo("LogFunnelStepEvent")).toBe(0)
	end)
end)
