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
local Ledger = require("@game/ReplicatedStorage/Game/Arena/Ledger")
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

local function boot(extra: { string }?, config: any?)
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
	if config then
		w.service.config = config
		w.service._ledger = Ledger.new(config)
	end
	w.interval = (config or Support).sampling.intervalSeconds
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

	it("refuses a ruler act with no ruler named, logging it once per kingdom and act", function()
		local w = boot()
		expect(w.service:record("crimson", nil, "fedRatioKept", 1)).toBeNil()
		expect(w.service:record("crimson", nil, "fedRatioKept", 1)).toBeNil()
		expect(w.service:record("crimson", nil, "starvation", 1)).toBeNil() -- another act: its own line
		w.sim.kingdoms.azure.rulers = { 2 }
		expect(w.service:record("azure", nil, "fedRatioKept", 1)).toBeNil() -- another kingdom: its own line
		local warnings = 0
		for _, entry in w.env.mock.logs do
			if entry.level == "warn" and entry.message == "LeadershipService: ruler act without a ruler" then
				warnings += 1
			end
		end
		expect(warnings).toBe(3)
	end)

	it("refuses an act for a ruler who is not seated in that kingdom, logging it once", function()
		local w = boot()
		expect(w.service:record("crimson", 99, "fedRatioKept", 1)).toBe(nil)
		expect(w.service:record("crimson", 99, "starvation", 1)).toBe(nil)
		expect(#w.service:getMoments("crimson", 99, 10)).toBe(0)
		local other = w.service:record("azure", 1, "fedRatioKept", 1) -- seated in crimson, not in azure
		expect(other).toBe(nil)
		local warnings = 0
		for _, entry in w.env.mock.logs do
			if entry.level == "warn" and entry.message == "LeadershipService: act for a ruler who is not seated" then
				warnings += 1
			end
		end
		expect(warnings).toBe(2) -- one per kingdom and ruler
		expect(w.service:record("crimson", 1, "fedRatioKept", 1) ~= nil).toBe(true) -- a seated ruler still records
		expect(w.service:record("crimson", nil, "keepUpgraded", 1) ~= nil).toBe(true) -- the kingdom itself too
	end)

	it("starts a new round with an empty ledger", function()
		local w = boot()
		w.service:record("crimson", 1, "fedRatioKept", 1)
		expect(#w.service:getMoments("crimson", 1, 5)).toBe(1)
		w.service._round = "an older round"
		expect(#w.service:getMoments("crimson", 1, 5)).toBe(0)
	end)
end)

describe("LeadershipService fixes", function()
	it(
		"refuses a ruler act with no ruler named while a ruler is seated, but takes it for an AI-held kingdom",
		function()
			local w = boot()
			expect(w.service:record("crimson", nil, "fedRatioKept", 1)).toBeNil()
			expect(#w.service:getMoments("crimson", 1, 10)).toBe(0)
			expect(w.service:record("crimson", nil, "keepUpgraded", 1)).never.toBeNil() -- a kingdom act needs no ruler
			w.k.rulers = {}
			expect(w.service:record("crimson", nil, "fedRatioKept", 1)).never.toBeNil() -- nobody to credit: the AI series
		end
	)

	it("returns copies and frozen records from samples and getMoments", function()
		local w = boot()
		w.service:record("crimson", 1, "fedRatioKept", 1)
		w.service:sample()
		local list = w.service:samples("crimson", 1)
		expect(#list).toBe(1)
		table.clear(list)
		expect(#w.service:samples("crimson", 1)).toBe(1) -- the stored list is untouched
		expect(table.isfrozen(w.service:samples("crimson", 1)[1])).toBe(true)
		expect(table.isfrozen(w.service:samples("crimson", 1)[1].components)).toBe(true)
		local moments = w.service:getMoments("crimson", 1, 5)
		table.clear(moments)
		expect(#w.service:getMoments("crimson", 1, 5)).toBe(1)
		expect(table.isfrozen(w.service:getMoments("crimson", 1, 5)[1])).toBe(true)
	end)

	it("reads a conditions table without stability as neutral, not as zero", function()
		local w = boot()
		w.k.conditions = { happiness = 80, morale = 60 }
		w.k.unrestPressure = 0
		w.service:sample()
		expect(w.service:samples("crimson", 1)[1].components.stability).toBe(50)
		w.k.conditions = { stability = 70, happiness = 80, morale = 60 }
		w.k.unrestPressure = 10
		w.env.mock:advance(w.interval + 1)
		w.service:sample()
		expect(w.service:samples("crimson", 1)[2].components.stability).toBe(60)
	end)

	it("checks for a due sample every pollSeconds of wall time, not once per interval", function()
		local w = boot()
		local calls = 0
		local real = w.service.sample
		w.service.sample = function(self, ...)
			calls += 1
			return real(self, ...)
		end
		w.env.mock:advance(w.service.config.sampling.pollSeconds * 5 + 0.5)
		expect(calls >= 5).toBe(true)
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

local Military = require("@game/ReplicatedStorage/Game/Sim/Military")

local function actsOf(w, act: string, userId: number?): { any }
	local out = {}
	for _, moment in w.service:getMoments("crimson", userId, 200) do
		if moment.act == act then
			table.insert(out, moment)
		end
	end
	return out
end

-- The shipped waits (30 s samples, 60 s rules) with every wait shortened: each simulated second runs the whole match,
-- so the act rules are specced on a short clock. The logic under test reads only the config.
local FAST = table.clone(Support)
FAST.sampling = table.clone(Support.sampling)
FAST.sampling.intervalSeconds = 5
FAST.rules = {
	fedKept = Support.rules.fedKept,
	starvation = { below = Support.rules.starvation.below, seconds = 12 },
	conscription = { soldierShareAbove = Support.rules.conscription.soldierShareAbove, seconds = 12 },
}

-- one sample, then enough match time for the next one
local function tick(w)
	w.service:sample()
	w.env.mock:advance(w.interval + 1)
end

describe("LeadershipService acts from the simulation", function()
	it("records starvation once an episode after the fed ratio stays under the bar for more than the wait", function()
		local w = boot(nil, FAST)
		w.k.fedRatio = 0.2
		tick(w) -- t0: starts counting
		tick(w) -- 6 s
		tick(w) -- 12 s: exactly the wait, not over it
		expect(#actsOf(w, "starvation", 1)).toBe(0)
		tick(w) -- 18 s: over the wait
		local first = actsOf(w, "starvation", 1)
		expect(#first).toBe(1)
		expect(first[1].userId).toBe(1)
		expect(first[1].component).toBe("conduct")
		for _ = 1, 4 do
			tick(w)
		end
		expect(#actsOf(w, "starvation", 1)).toBe(1) -- still the same episode
		w.k.fedRatio = 1
		tick(w)
		w.k.fedRatio = 0.1
		for _ = 1, 4 do
			tick(w)
		end
		expect(#actsOf(w, "starvation", 1)).toBe(2) -- a new episode counts again
	end)

	it("does not record starvation for a short dip, or at exactly the bar", function()
		local w = boot(nil, FAST)
		w.k.fedRatio = 0.1
		tick(w)
		tick(w)
		w.k.fedRatio = 0.9 -- recovered before the wait was up
		tick(w)
		-- a second short dip starts from nothing: 6 + 6 + 6 s apart is not one 18 s dip
		w.k.fedRatio = 0.1
		tick(w)
		tick(w)
		tick(w)
		w.k.fedRatio = 0.9
		for _ = 1, 3 do
			tick(w)
		end
		w.k.fedRatio = Support.rules.starvation.below -- exactly at the bar is not starving
		for _ = 1, 5 do
			tick(w)
		end
		expect(#actsOf(w, "starvation", 1)).toBe(0)
	end)

	it("records fedRatioKept when a counted phase ends with the fed ratio never under 0.9", function()
		local w = boot(nil, FAST)
		local match = w.registry:get("MatchService").host.match
		assert(match:debugSetPhase("Expansion"))
		w.k.fedRatio = 1
		tick(w)
		w.k.fedRatio = Support.rules.fedKept.atLeast -- exactly at the bar still counts
		tick(w)
		expect(#actsOf(w, "fedRatioKept", 1)).toBe(0) -- the phase has not ended
		assert(match:debugSetPhase("Conflict"))
		w.service:sample()
		local kept = actsOf(w, "fedRatioKept", 1)
		expect(#kept).toBe(1)
		expect(kept[1].component).toBe("conduct")
	end)

	it("does not record fedRatioKept after one dip under the bar, or for a phase that is not counted", function()
		local w = boot(nil, FAST)
		local match = w.registry:get("MatchService").host.match
		assert(match:debugSetPhase("Expansion"))
		w.k.fedRatio = 1
		tick(w)
		w.k.fedRatio = Support.rules.fedKept.atLeast - 0.01
		tick(w)
		w.k.fedRatio = 1
		tick(w)
		assert(match:debugSetPhase("Conflict"))
		w.service:sample()
		expect(#actsOf(w, "fedRatioKept", 1)).toBe(0)
		-- Founding is not a counted phase: leaving it with a full belly records nothing
		local fresh = boot(nil, FAST)
		local freshMatch = fresh.registry:get("MatchService").host.match
		assert(freshMatch:debugSetPhase("Founding"))
		fresh.k.fedRatio = 1
		tick(fresh)
		assert(freshMatch:debugSetPhase("Expansion"))
		fresh.service:sample()
		expect(#actsOf(fresh, "fedRatioKept", 1)).toBe(0)
	end)

	it(
		"records overConscription when soldiers stay above the share of soldiers + citizens for more than the wait",
		function()
			local w = boot(nil, FAST)
			local citizens = #w.k.citizenIds
			for i = 1, citizens * 2 do
				Military.spawnUnit(w.sim, w.k, "soldier", 0, i)
			end
			tick(w)
			tick(w)
			expect(#actsOf(w, "overConscription", 1)).toBe(0)
			tick(w)
			w.service:sample()
			expect(#actsOf(w, "overConscription", 1)).toBe(1)
			for _ = 1, 3 do
				tick(w)
			end
			expect(#actsOf(w, "overConscription", 1)).toBe(1) -- once an episode
		end
	)

	it("does not record overConscription for an army at or under the share", function()
		-- an army sized to exactly the bar: the bar is set to this kingdom's own ratio, so it is "at", not "above"
		local probe = boot(nil, FAST)
		local citizenCount = #probe.k.citizenIds
		local atBar = table.clone(FAST)
		atBar.rules = table.clone(FAST.rules)
		atBar.rules.conscription = table.clone(FAST.rules.conscription)
		atBar.rules.conscription.soldierShareAbove = 3 / (3 + citizenCount)
		local exact = boot(nil, atBar)
		exact.k.unitIds = {}
		for i = 1, 3 do
			Military.spawnUnit(exact.sim, exact.k, "soldier", 0, i)
		end
		for _ = 1, 6 do
			while #exact.k.unitIds < 3 do
				Military.spawnUnit(exact.sim, exact.k, "soldier", 0, 9) -- hold the ratio as the world moves on
			end
			tick(exact)
		end
		expect(#exact.k.citizenIds).toBe(citizenCount)
		expect(#actsOf(exact, "overConscription", 1)).toBe(0)
		local w = boot(nil, FAST)
		for _ = 1, 6 do
			tick(w)
		end
		expect(#actsOf(w, "overConscription", 1)).toBe(0) -- the starting army is far under the share
		w.k.unitIds = {}
		for i = 1, 1 do
			Military.spawnUnit(w.sim, w.k, "soldier", 0, i)
		end
		local soldiers, citizens = #w.k.unitIds, #w.k.citizenIds
		expect(soldiers / (soldiers + citizens) <= Support.rules.conscription.soldierShareAbove).toBe(true)
		for _ = 1, 6 do
			tick(w)
		end
		expect(#actsOf(w, "overConscription", 1)).toBe(0)
	end)

	it("credits an act only to rulers who were seated when its streak began", function()
		-- starvation: ruler 2 joins after the low streak started
		local w = boot(nil, FAST)
		w.k.fedRatio = 0.1
		tick(w)
		tick(w)
		w.sim:addRuler("crimson", 2)
		tick(w)
		tick(w)
		tick(w)
		expect(#actsOf(w, "starvation", 1)).toBe(1)
		expect(#actsOf(w, "starvation", 2)).toBe(0)
		-- fedRatioKept: ruler 2 is seated one sample before the phase ends
		local kept = boot(nil, FAST)
		local match = kept.registry:get("MatchService").host.match
		assert(match:debugSetPhase("Expansion"))
		kept.k.fedRatio = 1
		tick(kept)
		tick(kept)
		kept.sim:addRuler("crimson", 2)
		tick(kept)
		assert(match:debugSetPhase("Conflict"))
		kept.service:sample()
		expect(#actsOf(kept, "fedRatioKept", 1)).toBe(1)
		expect(#actsOf(kept, "fedRatioKept", 2)).toBe(0)
		-- and a ruler who leaves and returns starts again
		local back = boot(nil, FAST)
		back.sim:addRuler("crimson", 2)
		back.k.fedRatio = 0.1
		tick(back)
		table.remove(back.k.rulers, 2)
		tick(back)
		table.insert(back.k.rulers, 2)
		tick(back)
		tick(back)
		tick(back)
		expect(#actsOf(back, "starvation", 1)).toBe(1)
		expect(#actsOf(back, "starvation", 2)).toBe(0)
	end)

	it("closeOut credits the phase the arena begins in (Endgame never changes), once", function()
		local w = boot(nil, FAST)
		local match = w.registry:get("MatchService").host.match
		assert(match:debugSetPhase("Endgame"))
		w.k.fedRatio = Support.rules.fedKept.atLeast -- exactly at the bar still counts
		tick(w)
		tick(w)
		expect(#actsOf(w, "fedRatioKept", 1)).toBe(0) -- the phase has not ended
		w.service:closeOut()
		expect(#actsOf(w, "fedRatioKept", 1)).toBe(1)
		w.service:closeOut()
		assert(match:debugSetPhase("Conflict")) -- any phase edge afterwards
		w.service:sample()
		expect(#actsOf(w, "fedRatioKept", 1)).toBe(1) -- not twice
	end)

	it("closeOut credits nothing for a dip, and takes a last sample", function()
		local w = boot(nil, FAST)
		local match = w.registry:get("MatchService").host.match
		assert(match:debugSetPhase("Endgame"))
		w.k.fedRatio = 1
		tick(w)
		w.k.fedRatio = Support.rules.fedKept.atLeast - 0.01
		tick(w)
		w.k.fedRatio = 1
		w.service:sample() -- a normal round has just been taken: a closing one still adds its own
		local before = #w.service:samples("crimson", 1)
		w.service:closeOut()
		expect(#w.service:samples("crimson", 1)).toBe(before + 1)
		expect(#actsOf(w, "fedRatioKept", 1)).toBe(0)
	end)

	it("records for every seated ruler, and for the no-ruler series when an AI holds the kingdom", function()
		local w = boot(nil, FAST)
		w.sim:addRuler("crimson", 2)
		w.k.fedRatio = 0.1
		for _ = 1, 4 do
			tick(w)
		end
		expect(#actsOf(w, "starvation", 1)).toBe(1)
		expect(#actsOf(w, "starvation", 2)).toBe(1)
		local ai = boot(nil, FAST)
		ai.k.rulers = {}
		ai.k.fedRatio = 0.1
		for _ = 1, 4 do
			tick(ai)
		end
		local moments = ai.service:getMoments("crimson", nil, 50)
		local starvation = 0
		for _, moment in moments do
			if moment.act == "starvation" then
				starvation += 1
				expect(moment.userId).toBe(nil)
			end
		end
		expect(starvation).toBe(1)
	end)

	it("lets the acts move the sampled conduct component", function()
		local w = boot(nil, FAST)
		w.k.fedRatio = 0.1
		for _ = 1, 4 do
			tick(w)
		end
		w.service:sample()
		local series = w.service:samples("crimson", 1)
		expect(series[#series].components.conduct < 50).toBe(true)
	end)
end)
