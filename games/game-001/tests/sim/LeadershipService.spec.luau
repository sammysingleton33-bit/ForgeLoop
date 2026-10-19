--[[
	LeadershipService (FL-0069; CONTRACTS G12.2, design §3) on the real match: acts are recorded as pre-authored
	moments, the kingdom and the ruler are sampled every 30 s of match time, and SupportModel turns the samples into a
	score. Nothing here computes support itself: a good kingdom scores higher than a neglected one only because the
	sampled components differ.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local Reputation = require("@game/ReplicatedStorage/Game/Kingdom/Reputation")
local SupportModel = require("@game/ReplicatedStorage/Game/Arena/SupportModel")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local SimRemotes = require("@game/ReplicatedStorage/Game/Sim/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local INTERVAL = Support.sampling.intervalSeconds
local booted = {}

afterEach(function()
	local problem: string? = nil
	for _, b in booted do
		b.registry:destroy()
		for _, entry in b.env.mock.logs do
			if entry.level == "error" and problem == nil then
				problem = `server logged an error: {entry.message} {entry.fields and entry.fields.error or ""}`
			end
		end
	end
	table.clear(booted)
	if problem then
		error(problem)
	end
end)

local function boot(extra: { string }?)
	local env = MockEnv.new({
		seed = 8,
		sharedModules = {
			Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Sim = SimRemotes, Treasury = TreasuryRemotes },
		},
	})
	local names = { "RemoteService", "MatchService", "KingdomService", "CitizenService", "LeadershipService" }
	for _, name in extra or {} do
		table.insert(names, name)
	end
	local definitions = {}
	for _, name in names do
		table.insert(definitions, service(name))
	end
	local savedMode = MatchConfig.mode
	MatchConfig.mode = "slice"
	local registry = Loader.load(env, definitions)
	MatchConfig.mode = savedMode
	table.insert(booted, { registry = registry, env = env })
	registry:get("KingdomService").adapter = {
		partyOf = function()
			return nil
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
	local w = { env = env, registry = registry, service = registry:get("LeadershipService") }
	env.mock.players:add({ userId = 1 })
	env.mock:advance(1)
	w.sim = registry:get("MatchService").host.match.sim
	w.k = w.sim.kingdoms.crimson
	assert(w.sim.active and w.k.populated, "the match runs with crimson populated")
	w.k.conditions = w.k.conditions or Reputation.newConditions()
	return w
end

local function citizensOf(w): { any }
	local out = {}
	for _, id in w.k.citizenIds do
		table.insert(out, w.sim.citizens[id])
	end
	return out
end

describe("LeadershipService.record", function()
	it("records an act as a pre-authored moment and fires acted", function()
		local w = boot()
		local seen = {}
		w.service.acted:connect(function(kingdom, userId, act, component, delta)
			table.insert(seen, { kingdom, userId, act, component, delta })
		end)
		local moment = w.service:record("crimson", 1, "fedRatioKept", 1)
		assert(moment, "a moment")
		expect(moment.text).toBe(Support.acts.fedRatioKept.text)
		expect(moment.t).toBe(w.sim.time)
		expect(#seen).toBe(1)
		expect(seen[1][3]).toBe("fedRatioKept")
		expect(seen[1][4]).toBe("conduct")
		expect(seen[1][5]).toBe(Support.acts.fedRatioKept.delta)
		local moments = w.service:getMoments("crimson", 1, 5)
		expect(#moments).toBe(1)
		expect(moments[1].act).toBe("fedRatioKept")
	end)

	it("refuses an unknown act, an unknown kingdom and junk arguments, logging an unknown act once", function()
		local w = boot()
		expect(w.service:record("crimson", 1, "burnedTheTown", 1)).toBe(nil)
		expect(w.service:record("crimson", 1, "burnedTheTown", 1)).toBe(nil)
		expect(w.service:record("nowhere", 1, "fedRatioKept", 1)).toBe(nil)
		expect(w.service:record(nil :: any, 1, "fedRatioKept", 1)).toBe(nil)
		expect(w.service:record("crimson", 1, 5 :: any, 1)).toBe(nil)
		expect(#w.service:getMoments("crimson", 1, 10)).toBe(0)
		local warnings = 0
		for _, entry in w.env.mock.logs do
			if entry.level == "warn" and entry.message == "LeadershipService: unknown act" then
				warnings += 1
			end
		end
		expect(warnings).toBe(1)
	end)

	it("starts a new round with an empty ledger", function()
		local w = boot()
		w.service:record("crimson", 1, "fedRatioKept", 1)
		expect(#w.service:getMoments("crimson", 1, 5)).toBe(1)
		w.service._round = "an older round"
		expect(#w.service:getMoments("crimson", 1, 5)).toBe(0)
	end)
end)

describe("LeadershipService sampling", function()
	it("samples every kingdom's components 0..100, one series per seated ruler", function()
		local w = boot()
		w.service:sample()
		local series = w.service:samples("crimson", 1)
		expect(#series).toBe(1)
		for _, component in Support.componentOrder do
			local value = series[1].components[component]
			expect(type(value)).toBe("number")
			expect(value >= 0 and value <= 100).toBe(true)
		end
		expect(series[1].t).toBe(w.sim.time)
		expect(#w.service:samples("crimson", 99)).toBe(0) -- not a seated ruler
	end)

	it("reads happiness, stability and morale from the conditions, stability net of unrest pressure", function()
		local w = boot()
		w.k.conditions.happiness = 80
		w.k.conditions.stability = 70
		w.k.conditions.morale = 40
		w.k.unrestPressure = 15
		w.service:sample()
		local components = w.service:samples("crimson", 1)[1].components
		expect(components.happiness).toBe(80)
		expect(components.stability).toBe(55)
		expect(components.morale).toBe(40)
	end)

	it("takes no sample while the match is not running", function()
		local w = boot()
		w.sim.active = false
		w.service:sample()
		expect(#w.service:samples("crimson", 1)).toBe(0)
		w.sim.active = true
		w.service:sample()
		expect(#w.service:samples("crimson", 1)).toBe(1)
	end)

	it("clamps a stability swallowed by unrest pressure at 0", function()
		local w = boot()
		w.k.conditions.stability = 10
		w.k.unrestPressure = 100
		w.service:sample()
		expect(w.service:samples("crimson", 1)[1].components.stability).toBe(0)
	end)

	it("takes loyalty as the mean of the living citizens", function()
		local w = boot()
		local all = citizensOf(w)
		for _, c in all do
			c.loyalty = 80
		end
		all[1].loyalty = 20
		local expected = (80 * (#all - 1) + 20) / #all
		w.service:sample()
		local got = w.service:samples("crimson", 1)[1].components.loyalty
		expect(math.abs(got - expected) < 1e-6).toBe(true)
	end)

	it("leaves out the dead when it takes the mean loyalty", function()
		local w = boot()
		local all = citizensOf(w)
		for _, c in all do
			c.loyalty = 60
		end
		all[1].loyalty = 0
		all[1].alive = false
		w.service:sample()
		expect(w.service:samples("crimson", 1)[1].components.loyalty).toBe(60)
	end)

	it("counts a kingdom with no conditions as neutral for happiness, stability and morale", function()
		local w = boot()
		w.k.conditions = nil
		w.service:sample()
		local components = w.service:samples("crimson", 1)[1].components
		expect(components.happiness).toBe(50)
		expect(components.stability).toBe(50)
		expect(components.morale).toBe(50)
	end)

	it("puts the ruler's conduct and valour levels in their own series", function()
		local w = boot()
		expect(Support.acts.defendedRaid.delta ~= Support.acts.defendedOwnLand.delta).toBe(true) -- tells them apart
		w.service:record("crimson", 1, "defendedRaid", 1)
		w.service:record("crimson", 1, "defendedOwnLand", 1)
		w.service:sample()
		local components = w.service:samples("crimson", 1)[1].components
		expect(components.conduct).toBe(50 + Support.acts.defendedRaid.delta)
		expect(components.valour).toBe(50 + Support.acts.defendedOwnLand.delta)
	end)

	it("adds a kingdom reputation act as an offset to the reputation component", function()
		local w = boot()
		w.service:sample()
		local before = w.service:samples("crimson", 1)[1].components.reputation
		w.env.mock:advance(INTERVAL)
		w.service:record("crimson", nil, "keepUpgraded", 1)
		w.service:sample()
		local series = w.service:samples("crimson", 1)
		local after = series[#series].components.reputation
		expect(math.abs((after - before) - Support.acts.keepUpgraded.delta) < 1e-6).toBe(true)
	end)

	it("does not sample twice inside one interval, and does again after it", function()
		local w = boot()
		w.service:sample()
		w.service:sample()
		expect(#w.service:samples("crimson", 1)).toBe(1)
		w.env.mock:advance(INTERVAL + 1)
		w.service:sample()
		expect(#w.service:samples("crimson", 1) >= 2).toBe(true)
	end)

	it("samples by itself every interval while the match runs", function()
		local w = boot()
		w.env.mock:advance(INTERVAL * 3 + 2)
		expect(#w.service:samples("crimson", 1) >= 3).toBe(true)
		local series = w.service:samples("crimson", 1)
		for i = 2, #series do
			expect(series[i].t > series[i - 1].t).toBe(true)
		end
	end)

	it(
		"feeds SupportModel: a cared-for kingdom scores higher than a neglected one, only through the samples",
		function()
			local good = boot()
			local bad = boot()
			for _, w in { good, bad } do
				local fill = if w == good then 85 else 15
				w.k.conditions.happiness = fill
				w.k.conditions.stability = fill
				w.k.conditions.morale = fill
				for _, c in citizensOf(w) do
					c.loyalty = fill
				end
			end
			good.service:record("crimson", 1, "fedRatioKept", 2)
			bad.service:record("crimson", 1, "starvation", 2)
			for _, w in { good, bad } do
				w.service:sample()
				w.env.mock:advance(INTERVAL + 1)
				w.service:sample()
			end
			local goodScore, goodTier = SupportModel.score(good.service:samples("crimson", 1), { now = good.sim.time })
			local badScore, badTier = SupportModel.score(bad.service:samples("crimson", 1), { now = bad.sim.time })
			expect(goodScore > badScore).toBe(true)
			expect(goodTier ~= badTier or goodScore > badScore).toBe(true)
		end
	)
end)
