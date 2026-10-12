local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local AnalyticsSchema = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsSchema")
local AnalyticsRouter = require("@game/ReplicatedStorage/Forge/Experience/AnalyticsRouter")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local SandboxAnalytics = require("@game/ReplicatedStorage/Forge/Config/Analytics")
local Subjects = require("@game/ReplicatedStorage/Forge/Experience/Subjects")
local TestAnalytics = require("./doubles/TestAnalytics")

local KNOWN = AnalyticsRouter.knownEvents(GameEvents)

local function valid()
	return {
		events = { Thing = { description = "d", value = "count", fields = { "kind" } } },
		funnels = {
			Onboarding = { description = "d", kind = "onboarding" },
			Shop = { description = "d", kind = "recurring", steps = { "Opened", "Purchased" } },
			Return = { description = "d", kind = "once", steps = { "FirstSession", "ReturnNextDay" } },
		},
		track = {
			{ on = "ShopViewed", funnel = "Shop", step = 1, session = "start" },
			{ on = "BuildingCompleted", event = "Thing", fields = { "count", "kind" } }, -- a game event (D-024)
		},
		session = { returnFunnel = "Return" },
	}
end

local function hasProblem(problems, substring)
	for _, problem in problems do
		if string.find(problem, substring, 1, true) then
			return true
		end
	end
	return false
end

describe("Experience/AnalyticsSchema", function()
	it("accepts the sandbox config and the spec config (game configs: games/<game>/tests)", function()
		expect(AnalyticsSchema.validate(SandboxAnalytics, KNOWN)).toEqual({})
		expect(AnalyticsSchema.validate(TestAnalytics.build(), KNOWN)).toEqual({})
	end)

	it("keeps a full-size config inside the documented caps and the house budget", function()
		local budget = AnalyticsSchema.budget(TestAnalytics.build())
		expect(budget.events).toBeLessThanOrEqual(AnalyticsSchema.HOUSE.customEventNames)
		expect(budget.events).toBeLessThanOrEqual(AnalyticsSchema.CAPS.customEventNames)
		expect(budget.funnels).toBeLessThanOrEqual(AnalyticsSchema.HOUSE.funnels)
		expect(budget.maxSteps).toBeLessThanOrEqual(AnalyticsSchema.CAPS.stepsPerFunnel)
		expect(budget.fieldsPerEvent).toBeLessThanOrEqual(AnalyticsSchema.CAPS.customFields)
	end)

	it("documents the Roblox caps it enforces (creator-docs af5f853)", function()
		expect(AnalyticsSchema.CAPS.customEventNames).toBe(100)
		expect(AnalyticsSchema.CAPS.funnels).toBe(10)
		expect(AnalyticsSchema.CAPS.stepsPerFunnel).toBe(100)
		expect(AnalyticsSchema.CAPS.customFields).toBe(3)
		expect(AnalyticsSchema.CAPS.currencies).toBe(5)
		expect(AnalyticsSchema.FIELD_KEYS).toEqual({ "CustomField01", "CustomField02", "CustomField03" })
	end)

	it("accepts the minimal valid config", function()
		expect(AnalyticsSchema.validate(valid(), KNOWN)).toEqual({})
	end)

	it("rejects more than 3 custom fields and value/field overlap", function()
		local config = valid()
		config.events.Thing.fields = { "a", "b", "c", "d" }
		expect(hasProblem(AnalyticsSchema.validate(config, KNOWN), "4 fields; Roblox allows 3")).toBe(true)
		config.events.Thing.fields = { "count" }
		expect(hasProblem(AnalyticsSchema.validate(config, KNOWN), "cannot be both the value and a custom field")).toBe(
			true
		)
	end)

	it("rejects bad names, missing descriptions and unknown kinds", function()
		local config = valid()
		config.events.badName = { description = "" }
		config.funnels.Weird = { description = "d", kind = "daily", steps = { "A" } }
		local problems = AnalyticsSchema.validate(config, KNOWN)
		expect(hasProblem(problems, "events.badName: event names are PascalCase")).toBe(true)
		expect(hasProblem(problems, "events.badName: description required")).toBe(true)
		expect(hasProblem(problems, "funnels.Weird: kind must be")).toBe(true)
	end)

	it("rejects a second onboarding funnel", function()
		local config = valid()
		config.funnels.Tutorial2 = { description = "d", kind = "onboarding" }
		expect(hasProblem(AnalyticsSchema.validate(config, KNOWN), "at most one onboarding funnel")).toBe(true)
	end)

	it("rejects more funnels than the house budget", function()
		local config = valid()
		for i = 1, 8 do
			config.funnels[`Extra{i}`] = { description = "d", kind = "once", steps = { "A" } }
		end
		expect(hasProblem(AnalyticsSchema.validate(config, KNOWN), "funnels exceeds the house budget")).toBe(true)
	end)

	it("rejects more custom events than the house budget", function()
		local config = valid()
		for i = 1, 61 do
			config.events[`Extra{i}`] = { description = "d" }
		end
		expect(hasProblem(AnalyticsSchema.validate(config, KNOWN), "custom events exceeds the house budget")).toBe(true)
	end)

	it("checks track rules: event names, steps, sessions and fields", function()
		local config = valid()
		config.track = {
			{ on = "BuildingCompletd", event = "Thing" }, -- typo
			{ on = "ShopViewed", funnel = "Shop", step = 3, session = "start" },
			{ on = "ShopViewed", funnel = "Shop", step = 1 },
			{ on = "PlayerReady", funnel = "Return", step = 1, session = "start" },
			{ on = "PlayerReady", funnel = "Onboarding", step = 1 },
			{ on = "PlayerReady", event = "Thing", fields = { "nope" } },
			{ on = "PlayerReady", event = "Thing", funnel = "Shop" },
		}
		local problems = AnalyticsSchema.validate(config, KNOWN)
		expect(hasProblem(problems, "track[1] (BuildingCompletd): 'on' must name")).toBe(true)
		expect(hasProblem(problems, "track[2] (ShopViewed): step must be an integer in 1..2")).toBe(true)
		expect(hasProblem(problems, "track[3] (ShopViewed): recurring funnel 'Shop' needs session")).toBe(true)
		expect(hasProblem(problems, "track[4] (PlayerReady): once funnel 'Return' takes no session")).toBe(true)
		expect(
			hasProblem(problems, "track[5] (PlayerReady): the onboarding funnel is logged by OnboardingService only")
		).toBe(true)
		expect(hasProblem(problems, "track[6] (PlayerReady): field 'nope' is not declared")).toBe(true)
		expect(hasProblem(problems, "track[7] (PlayerReady): set exactly one of funnel or event")).toBe(true)
	end)

	it("checks the session block", function()
		local config = valid()
		config.session = { startEvent = "Missing", returnFunnel = "Shop" }
		local problems = AnalyticsSchema.validate(config, KNOWN)
		expect(hasProblem(problems, "session.startEvent: unknown event 'Missing'")).toBe(true)
		expect(hasProblem(problems, "session.returnFunnel: must name a once funnel")).toBe(true)
	end)
end)

describe("Experience/Subjects and AnalyticsRouter", function()
	local function ctxWith(players)
		return {
			byUserId = function(id)
				return players[id]
			end,
			all = function()
				local out = {}
				for _, p in players do
					table.insert(out, p)
				end
				return out
			end,
		}
	end

	it("knows every declared GameEvents event, including game events (D-024)", function()
		expect(KNOWN).toContain("ShopViewed")
		expect(KNOWN).toContain("KingdomJoined")
		expect(KNOWN).never.toContain("ResourceProduced")
	end)

	it("default resolvers keep only primitive info", function()
		local player = Instance.new("Player")
		local subjects = Subjects.resolve(
			"RewardRolled",
			table.pack(player, "chest", { rarity = "Rare", itemId = "hat", qty = 1, pityTriggered = false, extra = {} }),
			ctxWith({})
		)
		expect(subjects[1].info).toEqual({
			tableId = "chest",
			rarity = "Rare",
			itemId = "hat",
			qty = 1,
			pityTriggered = false,
		})
	end)

	it("a game resolver wins over the default and its info is filtered too", function()
		local player = Instance.new("Player")
		local subjects = Subjects.resolve("ShopViewed", table.pack(player, "main"), ctxWith({}), {
			ShopViewed = function(args)
				return { { player = args[1], info = { shopId = "custom", where = Vector3.zero } } }
			end,
		})
		expect(subjects[1].info).toEqual({ shopId = "custom" })
	end)

	it("drops subjects that are not Players and returns resolver errors", function()
		local subjects, err = Subjects.resolve("ShopViewed", table.pack(nil), ctxWith({}), {
			ShopViewed = function()
				error("boom")
			end,
		})
		expect(#subjects).toBe(0)
		expect(err).toContain("boom")
		expect(#Subjects.resolve("ShopViewed", table.pack({ UserId = 1 }, "main"), ctxWith({}))).toBe(0)
		expect(#Subjects.resolve("NotAnEvent", { n = 0 }, ctxWith({}))).toBe(0)
	end)

	it("validates game resolvers against declared events", function()
		local problems = Subjects.validate({ ResourceProduced = function() end, ShopViewed = 5 }, KNOWN)
		expect(table.concat(problems, "\n")).toContain("subjects.ResourceProduced: not a declared GameEvents event")
		expect(table.concat(problems, "\n")).toContain("subjects.ShopViewed: must be a function")
	end)

	it("RoundStateChanged reaches every player; RoundEnded only participants still here", function()
		local a, b = Instance.new("Player"), Instance.new("Player")
		local players = { [1] = a, [2] = b }
		expect(#Subjects.resolve("RoundStateChanged", table.pack("Active", { roundId = "r" }), ctxWith(players))).toBe(
			2
		)
		local ended = Subjects.resolve(
			"RoundEnded",
			table.pack({
				roundId = "r",
				participants = { { userId = 1, placement = 1 }, { userId = 9, placement = 2 } },
				winners = { 1 },
			}),
			ctxWith(players)
		)
		expect(#ended).toBe(1)
		expect(ended[1].info.won).toBe(true)
	end)

	it("marks CurrencyChanged gains", function()
		local player = Instance.new("Player")
		local gain = Subjects.resolve("CurrencyChanged", table.pack(player, "Crowns", 10, 5, "match"), ctxWith({}))
		local spend = Subjects.resolve("CurrencyChanged", table.pack(player, "Crowns", 5, -5, "shop"), ctxWith({}))
		expect(gain[1].info.gained).toBe(true)
		expect(spend[1].info.gained).toBe(false)
	end)

	it("matches rules on every listed key", function()
		expect(AnalyticsRouter.matches({ match = { role = "actor", level = 2 } }, { role = "actor", level = 2 })).toBe(
			true
		)
		expect(AnalyticsRouter.matches({ match = { role = "actor", level = 2 } }, { role = "actor", level = 3 })).toBe(
			false
		)
		expect(AnalyticsRouter.matches({}, {})).toBe(true)
	end)
end)
