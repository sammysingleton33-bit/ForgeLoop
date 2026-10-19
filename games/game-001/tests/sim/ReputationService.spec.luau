--[[
	ReputationService (CONTRACTS G13.4, FL-0080) on the real content library: each ruler's ledger, the
	actions.csv effects through ContentQuery (rulers' and kingdom's anti-farming histories), kingdom
	conditions, loyalty reactions, food shortage and phase events, fear relaxation and the remotes.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Society = require("@game/ReplicatedStorage/Forge/Config/Society")
local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")
local ReputationContent = require("@game/ReplicatedStorage/Game/Content/Reputation")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local Context = require("@game/ReplicatedStorage/Game/Sim/Context")
local SimRemotes = require("@game/ReplicatedStorage/Game/Sim/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local booted = {}

local function boot()
	local env = MockEnv.new({
		seed = 8,
		sharedModules = {
			Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Sim = SimRemotes, Treasury = TreasuryRemotes },
		},
	})
	local definitions = {}
	for _, name in
		{
			"RemoteService",
			"MatchService",
			"KingdomService",
			"CitizenService",
			"ReputationService",
			"TreasuryService",
			"ProductionService",
		}
	do
		table.insert(definitions, service(name))
	end
	local savedMode = MatchConfig.mode
	MatchConfig.mode = "slice" -- the VS-1 slice this spec was written for; the shipped default is the full match (D-053)
	local registry = Loader.load(env, definitions)
	MatchConfig.mode = savedMode
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
	local match = registry:get("MatchService")
	return env, registry:get("ReputationService"), match, registry:get("CitizenService")
end

afterEach(function()
	for _, b in booted do
		b.registry:destroy()
		for _, entry in b.env.mock.logs do
			if entry.level == "error" then
				error(`server logged an error: {entry.message} {entry.fields and entry.fields.error or ""}`)
			end
		end
	end
	table.clear(booted)
	GameEvents.disconnectAll()
end)

local function freeSpot(sim, k, kind)
	local keep = sim.buildings[k.keepId]
	for radius = 30, 140, 10 do
		for step = 0, 23 do
			local a = step / 24 * 2 * math.pi
			local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
			if sim:canPlace(k, kind, x, z) then
				return x, z
			end
		end
	end
	error(`no free spot for {kind}`)
end

local function stock(sim, k)
	for _, resource in { "wood", "stone", "food" } do
		sim:deposit(k.id, resource, 500, `test:{resource}:{sim.time}:{#sim.buildingOrder}`, "test")
	end
end

-- fills the kingdom to its housing capacity, so another house answers a need (housing_ratio > 0.9)
local function crowd(sim, k)
	local keep = sim.buildings[k.keepId]
	while #k.citizenIds + #k.unitIds < k.popCap do
		local c = sim:_spawnCitizen(k, "hauler", keep.x + 20, keep.z)
		k.stats.born += 1
		sim.profiler.birth(sim, k, c) -- an arrival, like a birth
	end
end

-- a building placed by `userId` and finished at once; the host relays BuildingCompleted on its next tick
local function build(env, match, userId, kind)
	local sim = match.host.match.sim
	local k = sim.kingdoms.crimson
	stock(sim, k)
	local x, z = freeSpot(sim, k, kind)
	local b = assert(sim:placeBuilding(k, kind, x, z, userId))
	sim:addWork(b, sim:workFor(kind, 1))
	env.mock:advance(0.25)
	return b
end

local function firing(event, ctx)
	return ContentQuery.actionFirings(event, ctx)[1]
end

-- A content query whose actions.csv is `rows` (each row: id, event, rep, kingdom?, audience?,
-- audience_condition?, audience_loyalty?, farm_key?, repeat_decay?, repeat_window_s?); everything else is
-- the shipped content.
local function contentWith(rows)
	local actions, byEvent = {}, {}
	for i, row in rows do
		actions[i] = {
			id = row.id,
			event = row.event,
			condition = {},
			farm_key = row.farm_key or row.id,
			repeat_decay = row.repeat_decay or 1,
			repeat_window_s = row.repeat_window_s or 0,
			rep = row.rep,
			audience = row.audience,
			audience_condition = row.audience_condition or {},
			audience_loyalty = row.audience_loyalty or 0,
			kingdom = row.kingdom or { happiness = 0, stability = 0, morale = 0 },
			notice = row.notice,
		}
		byEvent[row.event] = byEvent[row.event] or {}
		table.insert(byEvent[row.event], i)
	end
	local data = ContentQuery.data
	return ContentQuery.new({
		dialogue = data.dialogue,
		decisions = data.decisions,
		consequences = data.consequences,
		traits = data.traits,
		occupations = data.occupations,
		reputation = {
			categories = data.reputation.categories,
			order = data.reputation.order,
			actions = actions,
			byEvent = byEvent,
		},
	})
end

local ZERO_REP = { compassion = 0, honor = 0, competence = 0, courage = 0, authority = 0, fear = 0 }

local function seat(env, n)
	local players = {}
	for i = 1, n do
		players[i] = env.mock.players:add({ userId = i })
	end
	env.mock:advance(1)
	return players
end

describe("ReputationService: ledger and API (G13.4)", function()
	it("starts each ruler at the content starts; apply clamps and records server time", function()
		local env, reputation = boot()
		seat(env, 1)
		local view = reputation:get(1)
		for category, def in ReputationContent.categories do
			expect(view.values[category]).toBe(def.start)
		end
		expect(view.history).toEqual({})
		local applied = reputation:apply(1, "test", { courage = 70, fear = -5 }, "a test")
		expect(applied).toEqual({ courage = 50, fear = -5 })
		view = reputation:get(1)
		expect(view.values.courage).toBe(100)
		expect(view.history[1].t).toBeNear(env.serverTimeNow(), 1e-6)
		expect(view.history[1].source).toBe("test")
		reputation:apply(1, "test", { bravery = 3 }, "unknown key")
		local warned = false
		for _, entry in env.mock.logs do
			warned = warned or (entry.level == "warn" and entry.fields and entry.fields.keys == "bravery")
		end
		expect(warned).toBe(true)
	end)

	it("getKingdomReputation is the best of the kingdom's rulers, else the starts", function()
		local env, reputation, match = boot()
		seat(env, 2)
		expect(match.host.match:kingdomOf(2)).toBe("crimson")
		reputation:apply(1, "t", { authority = 20 }, "x")
		reputation:apply(2, "t", { fear = 30 }, "y")
		local best = reputation:getKingdomReputation("crimson")
		expect(best.authority).toBe(70)
		expect(best.fear).toBe(50)
		expect(reputation:getKingdomReputation("emerald").authority).toBe(ReputationContent.categories.authority.start)
	end)
end)

describe("ReputationService: actions (SPEC §6.9)", function()
	it("a needed house: the placing ruler's reputation, the conditions and civilians' loyalty", function()
		local env, reputation, match = boot()
		seat(env, 2)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local ctx = Context.kingdom(sim, "crimson")
		expect(ctx["kingdom.housing_ratio"] > 0.9).toBe(true) -- housing is needed
		local f = firing("BuildingCompleted:house", ctx)
		local before = {}
		for _, id in k.citizenIds do
			before[id] = sim.citizens[id].loyalty
		end
		local conditions = table.clone(k.conditions)
		build(env, match, 1, "house")
		local mine, theirs = reputation:get(1), reputation:get(2)
		expect(mine.values.compassion).toBe(50 + f.rep.compassion)
		expect(mine.values.competence).toBe(50 + f.rep.competence)
		expect(mine.history[1].source).toBe("house_built")
		expect(theirs.history).toEqual({}) -- the co-ruler did not build it
		expect(k.conditions.happiness).toBeNear(conditions.happiness + f.kingdom.happiness, 0.2) -- (+ drift)
		local heard = 0
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			local expected = 0
			for _, row in f.rows do
				local listener = { occupation = c.profile.occupation, speaker = false }
				if ContentQuery.inActionAudience(row, listener, Context.citizen(sim, c, ctx)) then
					expected += ContentQuery.actionLoyalty(row, c.profile.traits, c.chemistry, 1)
				end
			end
			expect(c.loyalty).toBeNear(before[id] + expected, 1e-9)
			if expected ~= 0 then
				heard += 1
			end
		end
		expect(heard > 0).toBe(true)
	end)

	it("anti-farming: a ruler's own history decays their reputation; the kingdom's is shared by co-rulers", function()
		local env, reputation, match = boot()
		seat(env, 2)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local f = firing("BuildingCompleted:house", Context.kingdom(sim, "crimson"))
		local decay = f.repeat_decay
		build(env, match, 1, "house")
		local happiness = k.conditions.happiness
		crowd(sim, k)
		local loyalty, expected = {}, {}
		local ctx = Context.kingdom(sim, "crimson")
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			loyalty[id] = c.loyalty
			expected[id] = 0
			for _, row in f.rows do
				local listener = { occupation = c.profile.occupation, speaker = false }
				if ContentQuery.inActionAudience(row, listener, Context.citizen(sim, c, ctx)) then
					expected[id] += ContentQuery.actionLoyalty(row, c.profile.traits, c.chemistry, decay)
				end
			end
		end
		build(env, match, 1, "house") -- ruler 1 again: both multipliers decay
		for id, before in loyalty do
			expect(sim.citizens[id].loyalty).toBeNear(math.clamp(before + expected[id], 0, 100), 1e-9)
		end
		expect(reputation:get(1).values.compassion).toBeNear(50 + f.rep.compassion * (1 + decay), 1e-9)
		expect(k.conditions.happiness).toBeNear(happiness + f.kingdom.happiness * decay, 0.2)
		happiness = k.conditions.happiness
		crowd(sim, k)
		build(env, match, 2, "house") -- the co-ruler: full reputation, but the kingdom's third firing
		expect(reputation:get(2).values.compassion).toBeNear(50 + f.rep.compassion, 1e-9)
		expect(k.conditions.happiness).toBeNear(happiness + f.kingdom.happiness * decay * decay, 0.2)
	end)

	it("an unneeded house earns nothing and records no firing", function()
		local env, reputation, match = boot()
		seat(env, 1)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local keep = sim.buildings[k.keepId]
		keep.level = 3 -- room for 20: housing no longer needed
		sim:_recompute(k)
		expect(Context.kingdom(sim, "crimson")["kingdom.housing_ratio"] <= 0.9).toBe(true)
		build(env, match, 1, "house")
		expect(reputation:get(1).history).toEqual({})
		expect((reputation._kingdomFarm.crimson or {}).build_house).toBeNil()
	end)

	it("food shortage once per dip; a well-fed phase pays, a phase with a shortage does not", function()
		local env, reputation, match, citizens = boot()
		seat(env, 1)
		local host = match.host
		local f = firing("FoodShortage", { ["kingdom.fed_ratio"] = 0.3 })
		citizens:setFedRatio("crimson", 0.3)
		env.mock:advance(1.5)
		expect(reputation:get(1).values.competence).toBe(50 + f.rep.competence)
		env.mock:advance(5) -- still below: no second shortage
		expect(reputation:get(1).values.competence).toBe(50 + f.rep.competence)
		citizens:setFedRatio("crimson", 1)
		env.mock:advance(1.5)
		local before = reputation:get(1).values.compassion
		assert(host.match:debugSetPhase("Expansion")) -- this phase had a shortage: no phase_fed reward
		env.mock:advance(0.5)
		expect(reputation:get(1).values.compassion).toBe(before)
		env.mock:advance(2)
		assert(host.match:debugSetPhase("Conflict")) -- a phase fed throughout pays
		env.mock:advance(0.5)
		local fed = firing("MatchPhaseChanged:Conflict", { ["kingdom.fed_ratio"] = 1, phase = "Conflict" })
		expect(reputation:get(1).values.compassion).toBe(before + fed.rep.compassion)
	end)

	it("recruiting credits the recruiting ruler only, not the co-ruler (#68 L2)", function()
		local env, reputation, match = boot()
		seat(env, 2) -- users 1 and 2 rule crimson together
		local sim = match.host.match.sim
		local ctx = Context.kingdom(sim, "crimson", { phase = match.host.match.state })
		local f = firing("UnitsRecruited", ctx)
		expect(f).never.toBeNil()
		sim:emit("RecruitQueued", { kingdomId = "crimson", unit = "soldier", count = 1, barracksId = 0, by = 2 })
		env.mock:advance(0.25)
		expect(#reputation:get(2).history > 0).toBe(true)
		expect(reputation:get(1).history).toEqual({})
	end)

	it("a keep upgrade credits the ruler who started it, not the co-ruler (#68 M1)", function()
		local env, reputation, match = boot()
		seat(env, 2) -- users 1 and 2 rule crimson together
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local keep = sim.buildings[k.keepId]
		expect(keep.placedBy).toBeNil() -- the keep has no placer: crediting the placer meant every ruler
		local f = firing("BuildingUpgraded:keep", Context.kingdom(sim, "crimson"))
		expect(f).never.toBeNil()
		stock(sim, k)
		assert(sim:startUpgrade(k, keep.id, 2))
		sim:addWork(keep, sim:workFor("keep", 2))
		env.mock:advance(0.25)
		expect(keep.level).toBe(2)
		local theirs = reputation:get(2)
		expect(theirs.values.competence).toBe(50 + f.rep.competence)
		expect(theirs.history[1].source).toBe("keep_upgraded")
		expect(reputation:get(1).history).toEqual({})
		expect(reputation._upgradedBy[keep.id]).toBeNil() -- forgotten once credited
	end)

	it("an actor who has left the kingdom earns nothing, and nobody else is credited (#68 L1)", function()
		local env, reputation, match = boot()
		seat(env, 3) -- users 1 and 2 in crimson, 3 elsewhere
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		expect(table.find(k.rulers, 3)).toBeNil()
		local farm = reputation._kingdomFarm.crimson
		sim:emit("RecruitQueued", { kingdomId = "crimson", unit = "soldier", count = 1, barracksId = 0, by = 3 })
		env.mock:advance(0.25)
		expect(reputation:get(1).history).toEqual({})
		expect(reputation:get(2).history).toEqual({})
		expect(reputation:get(3).history).toEqual({})
		-- the kingdom still reacted once (its own history records the firing)
		farm = reputation._kingdomFarm.crimson
		expect(farm ~= nil and next(farm) ~= nil).toBe(true)
		-- no actor at all (the AI, a starting building): every ruler, as before
		sim:emit("RecruitQueued", { kingdomId = "crimson", unit = "soldier", count = 1, barracksId = 0 })
		env.mock:advance(0.25)
		expect(#reputation:get(1).history > 0).toBe(true)
		expect(#reputation:get(2).history > 0).toBe(true)
	end)

	it("an upgrade cancelled or destroyed forgets its upgrader", function()
		local env, reputation, match = boot()
		seat(env, 2)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local keep = sim.buildings[k.keepId]
		stock(sim, k)
		assert(sim:startUpgrade(k, keep.id, 2))
		env.mock:advance(0.25)
		expect(reputation._upgradedBy[keep.id]).toBe(2)
		assert(sim:cancelConstruction(k, keep.id, 2))
		env.mock:advance(0.25)
		expect(reputation._upgradedBy[keep.id]).toBeNil()
		-- started by ruler 1 now: ruler 2's old start does not count
		stock(sim, k)
		assert(sim:startUpgrade(k, keep.id, 1))
		sim:addWork(keep, sim:workFor("keep", 2))
		env.mock:advance(0.25)
		expect(#reputation:get(1).history > 0).toBe(true)
		expect(reputation:get(2).history).toEqual({})
	end)

	it("an objective's capture and loss go to the right kingdoms' rulers", function()
		local env, reputation, match = boot()
		seat(env, 3) -- users 1 and 2 in crimson, 3 elsewhere
		local other = match.host.match:kingdomOf(3)
		expect(other).never.toBe("crimson")
		local sim = match.host.match.sim
		sim:emit("ObjectiveCaptured", { objectiveId = "tower", kingdomId = "crimson", previousOwner = other })
		env.mock:advance(0.25)
		local won = firing("ObjectiveCaptured", {})
		local lost = firing("ObjectiveLost", {})
		expect(reputation:get(1).values.courage).toBe(50 + won.rep.courage)
		expect(reputation:get(2).values.courage).toBe(50 + won.rep.courage)
		expect(reputation:get(3).values.fear).toBe(ReputationContent.categories.fear.start + lost.rep.fear)
	end)

	it("PhaseEndedWellFed pays only when the phase's lowest fed ratio stayed >= wellFedAtLeast (#68 L2)", function()
		local env, reputation, match, citizens = boot()
		seat(env, 1)
		local host = match.host
		reputation.content = contentWith({
			{ id = "fed_expansion", event = "PhaseEndedWellFed:Expansion", rep = { compassion = 4 } },
			{ id = "fed_conflict", event = "PhaseEndedWellFed:Conflict", rep = { compassion = 4 } },
		})
		local threshold = Society.food.wellFedAtLeast
		expect(Society.food.shortageBelow < 0.6 and 0.6 < threshold).toBe(true)
		assert(host.match:debugSetPhase("Expansion"))
		env.mock:advance(1.5)
		assert(host.match:debugSetPhase("Conflict")) -- Expansion stayed fed: it pays
		env.mock:advance(1.5)
		local paid = reputation:get(1).values.compassion
		expect(paid).toBe(50 + 4)
		citizens:setFedRatio("crimson", 0.6) -- a dip: no shortage (>= 0.5), but not well fed either
		env.mock:advance(2)
		citizens:setFedRatio("crimson", 1)
		env.mock:advance(2)
		assert(host.match:debugSetPhase("Endgame")) -- Conflict's low was 0.6: nothing
		env.mock:advance(1.5)
		expect(reputation:get(1).values.compassion).toBe(paid)
	end)

	it("history text is the row's notice, else a plain line from the change, never an action id", function()
		local env, reputation = boot()
		seat(env, 1)
		local rep = table.clone(ZERO_REP)
		rep.authority, rep.fear = 2, -1
		reputation.content = contentWith({
			{ id = "soldiers_recruited", event = "TestQuiet", rep = rep }, -- no notice text in the content
			{
				id = "decayed",
				event = "TestDecayed",
				rep = { compassion = 3 },
				repeat_decay = 0.5,
				repeat_window_s = 600,
			},
			{ id = "told", event = "TestTold", rep = { honor = 1 }, notice = "You kept your word." },
		})
		reputation:fireAction("TestQuiet", "crimson")
		local history = reputation:get(1).history
		expect(#history).toBe(2) -- one entry per category moved
		for _, entry in history do
			expect(entry.source).toBe("soldiers_recruited") -- the id stays the source, for analytics
			expect(entry.text).toBe("Authority +2, Fear -1")
			expect(string.find(entry.text, "_", 1, true)).toBeNil()
		end
		reputation:fireAction("TestDecayed", "crimson")
		local first = reputation:get(1).history
		expect(first[#first].text).toBe("Compassion +3")
		reputation:fireAction("TestDecayed", "crimson") -- decayed by the ruler's own history: 3 x 0.5
		local last = reputation:get(1).history
		expect(last[#last].delta).toBe(1.5)
		expect(last[#last].text).toBe("Compassion +1.5")
		reputation:fireAction("TestTold", "crimson")
		local told = reputation:get(1).history
		expect(told[#told].text).toBe("You kept your word.")
	end)

	it(
		"history text says what really moved: a category at its cap is not claimed, a sliver reads plainly (#129 M1)",
		function()
			local env, reputation = boot()
			seat(env, 1)
			local rep = table.clone(ZERO_REP)
			rep.authority, rep.fear = 2, -1
			reputation.content = contentWith({
				{ id = "soldiers_recruited", event = "TestQuiet", rep = rep }, -- no notice text in the content
				{ id = "sliver", event = "TestSliver", rep = { honor = 0.04 } },
			})
			reputation:apply(1, "setup", { authority = 49 }, "setup") -- authority 50 -> 99: one point of room
			reputation:fireAction("TestQuiet", "crimson")
			local history = reputation:get(1).history
			local entries = {}
			for _, entry in history do
				if entry.source == "soldiers_recruited" then
					entries[entry.category] = entry
				end
			end
			expect(entries.authority.delta).toBe(1) -- clamped at 100
			expect(entries.fear.delta).toBe(-1)
			for _, entry in entries do
				expect(entry.text).toBe("Authority +1, Fear -1") -- the sentence matches the chips
			end
			-- authority is now at its cap: only the fear entry is written, and it does not claim authority
			reputation:fireAction("TestQuiet", "crimson")
			local again = {}
			for _, entry in reputation:get(1).history do
				if entry.source == "soldiers_recruited" then
					table.insert(again, entry)
				end
			end
			expect(#again).toBe(3)
			expect(again[3].category).toBe("fear")
			expect(again[3].text).toBe("Fear -1")
			-- a change too small to print as a number still gets a plain line
			reputation:fireAction("TestSliver", "crimson")
			local sliver = reputation:get(1).history
			expect(sliver[#sliver].text).toBe("Your reputation changed")
			expect(sliver[#sliver].delta).toBeNear(0.04, 1e-9)
		end
	)

	it("keeps citizens' loyalty within 0..100 whatever a firing adds (#68 L3)", function()
		local env, reputation, match = boot()
		seat(env, 1)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		reputation.content = contentWith({
			{ id = "cheer", event = "TestCheer", rep = ZERO_REP, audience = "kingdom", audience_loyalty = 10 },
			{ id = "boo", event = "TestBoo", rep = ZERO_REP, audience = "kingdom", audience_loyalty = -10 },
		})
		local high, low = sim.citizens[k.citizenIds[1]], sim.citizens[k.citizenIds[2]]
		high.loyalty, low.loyalty = 98, 2
		reputation:fireAction("TestCheer", "crimson")
		expect(high.loyalty).toBe(100)
		expect(low.loyalty > 2).toBe(true)
		low.loyalty = 2
		reputation:fireAction("TestBoo", "crimson")
		expect(low.loyalty).toBe(0)
		expect(high.loyalty < 100).toBe(true)
	end)

	it("applies the user rules: a fight row cannot lower compassion or honor (Society.rules)", function()
		local env, reputation = boot()
		seat(env, 2) -- both co-rulers are credited: the rules hold for each
		local rep = table.clone(ZERO_REP)
		rep.compassion, rep.honor, rep.courage = -3, -2, 2
		reputation.content = contentWith({ { id = "test_fight", event = "EnemyAttacked", rep = rep } })
		reputation:fireAction("EnemyAttacked", "crimson")
		for userId = 1, 2 do
			local values = reputation:get(userId).values
			expect(values.compassion).toBe(50)
			expect(values.honor).toBe(50)
			expect(values.courage).toBe(52)
		end
	end)

	it(
		"applies ContentQuery.fireAction as given: rows summed, then clamped once; the kingdom once per firing",
		function()
			local env, reputation, match = boot()
			seat(env, 2) -- users 1 and 2 rule crimson together
			local sim = match.host.match.sim
			local k = sim.kingdoms.crimson
			local clamp = ContentQuery.LOYALTY_CLAMP.kingdom
			-- two rows of one action, each worth the whole kingdom clamp: a listener gets the clamp, not twice it
			local rep = table.clone(ZERO_REP)
			rep.honor = 4
			local rows = {}
			for i = 1, 2 do
				table.insert(rows, {
					id = "test_feast",
					event = "Feast",
					farm_key = "feast",
					repeat_decay = 0.5,
					repeat_window_s = 600,
					rep = rep,
					audience = "kingdom",
					audience_loyalty = clamp,
					kingdom = { happiness = 2 * i, stability = 0, morale = 0 },
				})
			end
			reputation.content = contentWith(rows)
			local loyalty = {}
			for _, id in k.citizenIds do
				loyalty[id] = sim.citizens[id].loyalty
			end
			local happiness = k.conditions.happiness
			reputation:fireAction("Feast", "crimson")
			for id, before in loyalty do
				expect(sim.citizens[id].loyalty).toBeNear(math.min(100, before + clamp), 1e-9)
			end
			expect(k.conditions.happiness).toBeNear(happiness + 2 + 4, 1e-9) -- both rows, once (not per ruler)
			expect(reputation:get(1).values.honor).toBe(58) -- the rows summed for each credited ruler
			expect(reputation:get(2).values.honor).toBe(58)
			expect(#reputation._kingdomFarm.crimson.feast).toBe(1) -- one firing, however many rulers
			-- again: each ruler's own history and the kingdom's decay their part (0.5 per earlier firing)
			happiness = k.conditions.happiness
			reputation:fireAction("Feast", "crimson", { rulers = { 2 } })
			expect(reputation:get(1).values.honor).toBe(58)
			expect(reputation:get(2).values.honor).toBe(58 + 4) -- 2 rows × 4 × 0.5
			expect(k.conditions.happiness).toBeNear(happiness + (2 + 4) * 0.5, 1e-9)
			expect(#reputation._rulerFarm[1].feast).toBe(1)
			expect(#reputation._rulerFarm[2].feast).toBe(2)
			expect(#reputation._kingdomFarm.crimson.feast).toBe(2)
		end
	)

	it("an audience condition reads each listener's own context (citizen.hunger)", function()
		local env, reputation, match = boot()
		seat(env, 1)
		local sim = match.host.match.sim
		local ids = sim.kingdoms.crimson.citizenIds
		reputation.content = contentWith({
			{
				id = "test_bread",
				event = "BreadShared",
				rep = ZERO_REP,
				audience = "kingdom",
				audience_condition = { { var = "citizen.hunger", op = ">=", value = 0.5 } },
				audience_loyalty = 2,
			},
		})
		local hungry, fed = sim.citizens[ids[1]], sim.citizens[ids[2]]
		hungry.hunger, fed.hunger = 0.8, 0
		local a, b = hungry.loyalty, fed.loyalty
		reputation:fireAction("BreadShared", "crimson")
		expect(hungry.loyalty > a).toBe(true)
		expect(fed.loyalty).toBe(b)
	end)

	it("rulerVisited: only the visited citizen reacts", function()
		local env, reputation, match = boot()
		seat(env, 1)
		local sim = match.host.match.sim
		local ids = sim.kingdoms.crimson.citizenIds
		local visited, other = sim.citizens[ids[1]], sim.citizens[ids[2]]
		local a, b = visited.loyalty, other.loyalty
		reputation:rulerVisited(1, visited.id)
		expect(visited.loyalty > a).toBe(true)
		expect(other.loyalty).toBe(b)
		-- the visited citizen remembers it and cheers up (G5, FL-0050); the other one doesn't
		expect(visited.moodLift).never.toBeNil()
		expect(other.moodLift).toBeNil()
		local remembered = false
		for _, entry in visited.memory do
			remembered = remembered or (entry.kind == "rulerVisited" and entry.ref == 1)
		end
		expect(remembered).toBe(true)
		-- another kingdom's citizen: no reaction from a crimson ruler
		local azure = sim.kingdoms.azure
		local stranger = sim:_spawnCitizen(azure, "farmer", azure.x, azure.z)
		reputation:rulerVisited(1, stranger.id)
		expect(stranger.moodLift).toBeNil()
	end)
end)

describe("ReputationService: upkeep and remotes", function()
	it("fear above its start fades by Society.fear.relaxPerMinute, one entry a minute", function()
		local env, reputation = boot()
		seat(env, 1)
		local rate = Society.fear.relaxPerMinute
		reputation:apply(1, "test", { fear = 2 * rate + 1 }, "scared") -- not a multiple of the rate
		local start = ReputationContent.categories.fear.start
		env.mock:advance(61)
		local view = reputation:get(1)
		expect(view.values.fear).toBe(start + rate + 1)
		expect(view.history[#view.history].source).toBe("fear_relax")
		env.mock:advance(600)
		expect(reputation:get(1).values.fear).toBe(start) -- never below its start
	end)

	it("conditions drift toward the fed target while the match runs", function()
		local env, _, match, citizens = boot()
		seat(env, 1)
		local k = match.host.match.sim.kingdoms.crimson
		citizens:setFedRatio("crimson", 0)
		local before = k.conditions.happiness
		env.mock:advance(60)
		expect(k.conditions.happiness < before).toBe(true)
	end)

	it("Kingdom.GetReputation answers rulers; Kingdom.Reputation is pushed on change only", function()
		local env, reputation, match = boot()
		local players = seat(env, 1)
		local p1 = players[1]
		local remote = env.ReplicatedStorage.ForgeRemotes.Kingdom:FindFirstChild("GetReputation")
		local payload
		env.mock.remotes:asClient(p1, function()
			payload = remote:InvokeServer()
		end)
		expect(payload).toEqual(reputation:payload(1))
		expect(payload.kingdom.happiness).toBe(match.host:kingdomView("crimson").happiness)
		local event = env.ReplicatedStorage.ForgeRemotes.Kingdom:FindFirstChild("Reputation")
		local function sent()
			local n = 0
			for _, entry in env.mock.remotes:sent(event) do
				if entry.player == p1 then
					n += 1
				end
			end
			return n
		end
		env.mock:advance(2)
		local n = sent()
		expect(n >= 1).toBe(true)
		env.mock:advance(3)
		expect(sent()).toBe(n) -- nothing changed (conditions at their target round the same)
		reputation:apply(1, "test", { honor = 5 }, "kept a promise")
		env.mock:advance(1.5)
		expect(sent()).toBe(n + 1)
		for i = 2, 17 do
			env.mock.players:add({ userId = i })
		end
		env.mock:advance(1)
		local spectator = env.mock.players:get(17)
		local none
		env.mock.remotes:asClient(spectator, function()
			none = remote:InvokeServer()
		end)
		expect(none).toBeNil()
	end)

	it("a new world starts every ledger over; CitizenService obedience reads the reputation", function()
		local env, reputation, match, citizens = boot()
		seat(env, 1)
		reputation:apply(1, "test", { authority = 40 }, "firm")
		local sim = match.host.match.sim
		local id = sim.kingdoms.crimson.citizenIds[1]
		local high = citizens:inspect(id).obedience
		reputation:apply(1, "test", { authority = -60 }, "weak")
		expect(citizens:inspect(id).obedience < high).toBe(true)
		match.host.match:_newWorld()
		expect(reputation:get(1).history).toEqual({})
	end)
end)
