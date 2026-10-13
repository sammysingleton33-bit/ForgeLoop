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

	it("applies the user rules: a fight row cannot lower compassion or honor (Society.rules)", function()
		local env, reputation = boot()
		seat(env, 1)
		local original = ContentQuery.actionFirings
		ContentQuery.actionFirings = function(event)
			if event ~= "EnemyAttacked" then
				return {}
			end
			return {
				{
					id = "test_fight",
					farm_key = "test_fight",
					repeat_decay = 1,
					repeat_window_s = 0,
					rows = {},
					rep = { compassion = -3, honor = -2, courage = 2 },
					kingdom = { happiness = 0, stability = 0, morale = 0 },
				},
			}
		end
		local ok, err = pcall(function()
			reputation:fireAction("EnemyAttacked", "crimson")
		end)
		ContentQuery.actionFirings = original
		assert(ok, err)
		local values = reputation:get(1).values
		expect(values.compassion).toBe(50)
		expect(values.honor).toBe(50)
		expect(values.courage).toBe(52)
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
