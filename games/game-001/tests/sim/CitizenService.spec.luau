--[[
	CitizenService (CONTRACTS G5, G7, G8; FL-0050) with FORGE-03's real TreasuryService and
	ProductionService: the population view, the fed ratio driving hunger (no meals bought by
	citizens), inspect, and the Sim.Inspect remote limited to the asker's own kingdom.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local People = require("@game/ReplicatedStorage/Game/Sim/People")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Population = require("@game/ReplicatedStorage/Game/Sim/Population")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local SimRemotes = require("@game/ReplicatedStorage/Game/Sim/Remotes")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

local function service(name)
	return require(`@game/ServerScriptService/{if name == "RemoteService" then "Forge" else "Game"}/Services/{name}`)
end

local booted = {}

local function boot(withEntities: boolean?)
	local env = MockEnv.new({
		seed = 6,
		sharedModules = {
			Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Sim = SimRemotes, Treasury = TreasuryRemotes },
		},
	})
	local definitions = {}
	for _, name in
		{ "RemoteService", "MatchService", "KingdomService", "CitizenService", "TreasuryService", "ProductionService" }
	do
		table.insert(definitions, service(name))
	end
	if withEntities then
		table.insert(definitions, service("EntityService"))
	end
	local savedMode = MatchConfig.mode
	MatchConfig.mode = "slice" -- the VS-1 slice this spec was written for; the shipped default is the full match (D-053)
	local registry = Loader.load(env, definitions)
	MatchConfig.mode = savedMode
	table.insert(booted, { registry = registry, env = env })
	local kingdoms = registry:get("KingdomService")
	kingdoms.adapter = {
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
	return env, registry:get("CitizenService"), registry:get("MatchService"), registry:get("TreasuryService")
end

local function invoke(env, player, name, ...)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	local remote = env.ReplicatedStorage.ForgeRemotes:FindFirstChild(area):FindFirstChild(action)
	local args = table.pack(...)
	local results
	env.mock.remotes:asClient(player, function()
		results = table.pack(remote:InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return table.unpack(results, 1, results.n)
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

describe("CitizenService (G5)", function()
	it("reports the population by job, soldiers included, with the cap", function()
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local pop = assert(citizens:getPopulation("crimson"))
		expect(pop.total).toBe(12)
		expect(pop.byJob).toEqual({ farmer = 3, woodcutter = 3, miner = 2, builder = 2, hauler = 2 })
		expect(pop.cap > 0).toBe(true)
		local sim = match.host.match.sim
		Military.spawnUnit(sim, sim.kingdoms.crimson, "soldier", sim.kingdoms.crimson.x, sim.kingdoms.crimson.z)
		pop = assert(citizens:getPopulation("crimson"))
		expect(pop.total).toBe(13)
		expect(pop.byJob.soldier).toBe(1)
		-- cap = beds + barracks bunks (D-041): it counts the same people as total
		local k = sim.kingdoms.crimson
		expect(pop.cap).toBe(k.popCap)
		local barracks = sim:_createBuilding(k, "barracks", k.x + 40, k.z + 40)
		sim:_completeInstantly(barracks)
		sim:_recompute(k)
		expect(assert(citizens:getPopulation("crimson")).cap).toBe(k.popCap + 4)
		barracks.level = 2
		expect(assert(citizens:getPopulation("crimson")).cap).toBe(k.popCap + 8)
		local levels = sim.catalog.buildings.barracks.levels
		local bunks = levels[2].bunks
		levels[2].bunks = nil -- a level without a bunk count sleeps any number: shown as exactly full
		local unlimited = assert(citizens:getPopulation("crimson")).cap
		levels[2].bunks = bunks
		expect(unlimited).toBe(k.popCap + 1)
		expect(assert(citizens:getPopulation("azure")).total).toBe(0) -- slice: no ruler, no citizens
		expect(citizens:getPopulation("violet")).toBeNil()
	end)

	it("lets the upkeep feed the citizens: no meals bought, hunger falls when fed and rises when starved", function()
		local env, citizens, match, treasury = boot()
		local spent = {}
		treasury.changed:connect(function(kingdom, _totals, deltas)
			if kingdom == "crimson" and (deltas.food or 0) < 0 then
				table.insert(spent, deltas.food)
			end
		end)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		expect(sim.fedByUpkeep).toBe(true)
		local k = sim.kingdoms.crimson
		for _, id in k.citizenIds do
			sim.citizens[id].hunger = 0.5
		end
		env.mock:advance(130) -- two upkeep intervals
		expect(#spent > 0).toBe(true) -- ProductionService charged the upkeep
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			expect(c.activity).never.toBe("Eat")
			expect(c.hunger < 0.5).toBe(true)
		end
		citizens:setFedRatio("crimson", 0)
		local before = sim.citizens[k.citizenIds[1]].hunger
		match.host.match.sim.kingdoms.crimson.fedRatio = 0 -- hold it there between upkeep ticks
		sim:advance(30)
		expect(sim.citizens[k.citizenIds[1]].hunger > before).toBe(true)
	end)

	it("clamps the fed ratio and rejects non-numbers", function()
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local k = match.host.match.sim.kingdoms.crimson
		citizens:setFedRatio("crimson", 3)
		expect(k.fedRatio).toBe(1)
		citizens:setFedRatio("crimson", -1)
		expect(k.fedRatio).toBe(0)
		citizens:setFedRatio("violet", 0.5) -- unknown kingdom: ignored
		expect(function()
			citizens:setFedRatio("crimson", 0 / 0)
		end).toThrow("ratio")
	end)

	it("inspects a citizen, and Sim.Inspect answers only for the asker's own kingdom", function()
		local env, citizens, match = boot()
		local p1 = env.mock.players:add({ userId = 1 }) -- crimson
		local p2 = env.mock.players:add({ userId = 2 }) -- azure
		env.mock:advance(5)
		local sim = match.host.match.sim
		local mine = sim.kingdoms.crimson.citizenIds[1]
		local theirs = sim.kingdoms.azure.citizenIds[1]
		local view = assert(citizens:inspect(mine))
		expect(view.name).toBe(sim.citizens[mine].name)
		expect(view.job).toBe(sim.citizens[mine].job)
		expect(view.mood >= 0 and view.mood <= 100).toBe(true)
		expect(type(view.intent)).toBe("string")
		expect(citizens:inspect(999)).toBeNil()
		expect(invoke(env, p1, "Sim.Inspect", mine)).toEqual(view)
		expect(invoke(env, p1, "Sim.Inspect", theirs)).toBeNil() -- not my kingdom
		expect(invoke(env, p2, "Sim.Inspect", theirs).name).toBe(sim.citizens[theirs].name)
		expect(invoke(env, p1, "Sim.Inspect", "x")).toBeNil() -- rejected by validation
	end)
end)

describe("CitizenService: generated population (G13.2, FL-0078)", function()
	local VIEW_KEYS = {
		"entityId",
		"family",
		"familyIds",
		"friendIds",
		"friends",
		"hasRequest",
		"intent",
		"job",
		"lastMemory",
		"look",
		"loyalty",
		"memories",
		"mood",
		"name",
		"obedience",
		"occupation",
		"rivalIds",
		"rivals",
		"traits",
	}

	it("generates the people when a kingdom is populated, and inspect returns the CitizenView", function()
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 }) -- crimson
		env.mock:advance(5)
		local sim = match.host.match.sim
		expect(sim.profiler).never.toBeNil()
		local ids = sim.kingdoms.crimson.citizenIds
		expect(#ids).toBe(12)
		for _, id in ids do
			local c = sim.citizens[id]
			local view = assert(citizens:inspect(id))
			local keys = {}
			for key in view do
				table.insert(keys, key)
			end
			table.sort(keys)
			local expected = table.clone(VIEW_KEYS)
			if view.lastMemory == nil then
				table.remove(expected, table.find(expected, "lastMemory"))
			end
			expect(keys).toEqual(expected)
			expect(view.entityId).toBe(id)
			expect(view.name).toBe(c.name)
			expect(view.occupation).toBe(c.profile.occupation)
			expect(view.traits).toEqual(c.profile.traits)
			expect(view.loyalty).toBe(c.loyalty)
			expect(view.obedience).toBe(
				Population.obedience(c.profile.traits, People.startReputation(), People.CONTENT)
			)
			expect(view.look).toEqual(c.profile.look)
			expect(view.hasRequest).toBe(false)
			local idsOf = { family = "familyIds", friends = "friendIds", rivals = "rivalIds" }
			for _, relation in { "family", "friends", "rivals" } do
				expect(#view[relation]).toBe(#c.profile[relation])
				expect(view[idsOf[relation]]).toEqual(c.profile[relation]) -- ids beside the names (FL-0109)
				for i, otherId in c.profile[relation] do
					expect(view[relation][i]).toBe(sim.citizens[otherId].name)
				end
			end
			view.traits[1] = "changed" -- a copy
			view.look.skin = 99
			expect(c.profile.traits[1]).never.toBe("changed")
			expect(c.profile.look.skin).never.toBe(99)
		end
	end)

	it("relation ids stay aligned with names when a relation is gone; the look is only ever valid (FL-0109)", function()
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(5)
		local sim = match.host.match.sim
		local c
		for _, id in sim.kingdoms.crimson.citizenIds do
			local candidate = sim.citizens[id]
			if #candidate.profile.friends >= 2 then
				c = candidate
				break
			end
		end
		assert(c, "a citizen with two friends")
		local gone, stays = c.profile.friends[1], c.profile.friends[2]
		sim:killCitizen(sim.citizens[gone], "test")
		local view = assert(citizens:inspect(c.id))
		expect(table.find(view.friendIds, gone)).toBeNil()
		local at = assert(table.find(view.friendIds, stays))
		expect(view.friends[at]).toBe(sim.citizens[stays].name)
		expect(#view.friends).toBe(#view.friendIds)
		-- a look the profile should never hold: out of range, fractional, an extra key
		c.profile.look = { skin = 300, hair = 0, hairColor = 2.5, outfit = 4, key = "raw" }
		local look = assert(citizens:inspect(c.id)).look
		expect(look).toEqual(Kit.normalizeLook(c.profile.look))
		local keys = {}
		for key in look do
			table.insert(keys, key)
		end
		table.sort(keys)
		expect(keys).toEqual({ "hair", "hairColor", "outfit", "skin" })
		for field, range in Kit.LOOK_RANGES do
			expect(look[field] >= 1 and look[field] <= range).toBe(true)
		end
	end)

	it("uses ReputationService's values for obedience when it runs", function()
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(5)
		local id = match.host.match.sim.kingdoms.crimson.citizenIds[1]
		local c = match.host.match.sim.citizens[id]
		local rep = { compassion = 50, honor = 50, competence = 50, courage = 50, authority = 90, fear = 70 }
		citizens._registry = {
			find = function(_, name)
				if name == "ReputationService" then
					return {
						getKingdomReputation = function(_, kingdomId)
							return if kingdomId == "crimson" then rep else nil
						end,
					}
				end
				return nil
			end,
		}
		expect(citizens:inspect(id).obedience).toBe(Population.obedience(c.profile.traits, rep, People.CONTENT))
	end)

	it("quotaRev: every accepted quota change is pushed, even one to the same number (FL-0109, #71 low)", function()
		local env, citizens, match = boot()
		local p1 = env.mock.players:add({ userId = 1 }) -- crimson
		env.mock:advance(3)
		local remote = env.ReplicatedStorage.ForgeRemotes.Kingdom:FindFirstChild("Population")
		local function sent()
			local out = {}
			for _, entry in env.mock.remotes:sent(remote) do
				if entry.player == p1 then
					table.insert(out, entry.args[1])
				end
			end
			return out
		end
		local sim = match.host.match.sim
		sim.step = function() end -- frozen world, match still active: only the quotas can change the payload
		env.mock:advance(1.5)
		local start = citizens:getPopulation("crimson").quotaRev
		expect(start).toBe(0)
		local pushed = #sent()
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "farmer", 5)).toBe(true)
		env.mock:advance(1.5)
		expect(#sent()).toBe(pushed + 1)
		expect(sent()[#sent()].quotaRev).toBe(1)
		-- a co-ruler asking for the same number again: the quotas look the same, the revision does not
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "farmer", 5)).toBe(true)
		env.mock:advance(1.5)
		expect(#sent()).toBe(pushed + 2)
		expect(sent()[#sent()].quotas.farmer).toBe(5)
		expect(sent()[#sent()].quotaRev).toBe(2)
		-- refused requests change nothing
		invoke(env, p1, "Kingdom.SetJobQuota", "hauler", 3)
		invoke(env, p1, "Kingdom.SetJobQuota", "farmer", -1)
		-- ... and the remote's validation is not what stops them: the command itself refuses and keeps the revision
		local rev = sim.kingdoms.crimson.quotaRev
		for _, args in { { "hauler", 3 }, { "farmer", -1 }, { "farmer", 1.5 }, { "nonesuch", 2 }, { "farmer", 0 / 0 } } do
			local ok = Commands.executeFor(sim, sim.kingdoms.crimson, 1, "SetJobQuota", table.unpack(args))
			expect(`{args[1]} {tostring(args[2])}: {ok}`).toBe(`{args[1]} {tostring(args[2])}: false`)
		end
		expect(sim.kingdoms.crimson.quotaRev).toBe(rev)
		env.mock:advance(1.5)
		expect(#sent()).toBe(pushed + 2)
		expect(citizens:getPopulation("crimson").quotaRev).toBe(2)
		-- moving one citizen (setJob) moves the quotas with it: that counts too
		local c = sim.citizens[sim.kingdoms.crimson.citizenIds[1]]
		local to = if c.job == "miner" then "woodcutter" else "miner"
		expect(citizens:setJob(c.id, to)).toBe(true)
		env.mock:advance(1.5)
		expect(sent()[#sent()].quotaRev).toBe(3)
	end)

	it("Kingdom.GetPopulation answers members only; Kingdom.Population follows changes per kingdom", function()
		local env, citizens, match = boot()
		local p1 = env.mock.players:add({ userId = 1 }) -- crimson
		local p2 = env.mock.players:add({ userId = 2 }) -- azure
		env.mock:advance(3)
		expect(invoke(env, p1, "Kingdom.GetPopulation")).toEqual(citizens:getPopulation("crimson"))
		local remote = env.ReplicatedStorage.ForgeRemotes.Kingdom:FindFirstChild("Population")
		local function sentTo(player)
			local out = {}
			for _, entry in env.mock.remotes:sent(remote) do
				if entry.player == player then
					table.insert(out, entry.args[1])
				end
			end
			return out
		end
		expect(#sentTo(p1)).toBe(1)
		expect(sentTo(p1)[1]).toEqual(citizens:getPopulation("crimson"))
		expect(sentTo(p2)[1]).toEqual(citizens:getPopulation("azure"))
		env.mock:advance(3) -- nothing changed: nothing sent
		expect(#sentTo(p1)).toBe(1)
		local sim = match.host.match.sim
		local c = sim.citizens[sim.kingdoms.crimson.citizenIds[1]]
		Military.spawnUnit(sim, sim.kingdoms.crimson, "soldier", c.x, c.z) -- crimson grows by a soldier
		env.mock:advance(1.5)
		expect(#sentTo(p1)).toBe(2)
		expect(sentTo(p1)[2].byJob.soldier).toBe(1)
		expect(#sentTo(p2)).toBe(1) -- azure did not change
		-- quotas travel too (the job panel steps from them), as whole numbers
		local expected = table.clone(sim.kingdoms.crimson.quotas)
		expect(expected.hauler).never.toBeNil() -- the sim keeps a start count for the pool ...
		expected.hauler = nil -- ... but haulers have no quota to step
		expect(sentTo(p1)[2].quotas).toEqual(expected)
		expect(invoke(env, p1, "Kingdom.SetJobQuota", "farmer", 5)).toBe(true)
		env.mock:advance(1.5) -- the quota change (and citizens moving to meet it) is pushed
		local latest = sentTo(p1)[#sentTo(p1)]
		expect(#sentTo(p1) >= 3).toBe(true)
		expect(latest.quotas.farmer).toBe(5)
		for _, n in latest.byJob do
			expect(n >= 0 and n % 1 == 0).toBe(true)
		end
		sim.active = false -- frozen: nobody moves, so only the quota differs
		local pushed = #sentTo(p1)
		sim.kingdoms.crimson.quotas.miner = 7
		env.mock:advance(1.5)
		expect(#sentTo(p1)).toBe(pushed + 1)
		expect(sentTo(p1)[pushed + 1].quotas.miner).toBe(7)
		local spectatorEnv = env
		local p17 = nil
		for i = 3, 17 do
			p17 = spectatorEnv.mock.players:add({ userId = i })
		end
		env.mock:advance(2)
		expect(match.host.match:kingdomOf(17)).toBeNil()
		expect(invoke(env, p17, "Kingdom.GetPopulation")).toBeNil()
		expect(#sentTo(p17)).toBe(0)
	end)

	it("G13.7 hook debugReseed: the kingdom's citizens get the seed's people; the preset service finds it", function()
		local ContentQuery = require("@game/ReplicatedStorage/Game/Content/ContentQuery")
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(3)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local function names()
			local out = {}
			for _, id in k.citizenIds do
				table.insert(out, sim.citizens[id].name)
			end
			return out
		end
		local before = names()
		local presets = service("DebugPresetService").new(env, citizens._registry)
		expect(presets:_hook("reseed", "crimson", 1234)).toContain("reseeded from 1234")
		local first = names()
		expect(first).never.toEqual(before)
		expect(citizens:debugReseed("crimson", 99)).toBe(true)
		expect(names()).never.toEqual(first) -- another seed, other people
		expect(citizens:debugReseed("crimson", 1234)).toBe(true)
		expect(names()).toEqual(first) -- the same seed gives the same people
		for _, id in k.citizenIds do
			local c = sim.citizens[id]
			expect(c.loyalty).toBe(ContentQuery.startLoyalty(c.chemistry))
		end
		expect({ citizens:debugReseed("violet", 1) }).toEqual({ false, "unknown kingdom violet" })
	end)

	it("sends each citizen's look once, in its reliable spawn event (G4, G13.2)", function()
		local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
		local env, _, match = boot(true)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(3)
		local sim = match.host.match.sim
		local remote = env.ReplicatedStorage.ForgeRemotes.Sim:FindFirstChild("Events")
		local looks = {}
		for _, entry in env.mock.remotes:sent(remote) do
			local batch = assert(EventCodec.decode(entry.args[1]))
			for _, e in batch.events do
				if e.type == "spawn" and e.kind == "citizen" then
					looks[e.id] = e.look
				end
			end
		end
		for _, id in sim.kingdoms.crimson.citizenIds do
			expect(looks[id]).toEqual(sim.citizens[id].profile.look)
		end
	end)
end)

describe("CitizenService: job orders and a ruler's visit (CONTRACTS G5, FL-0050)", function()
	local function jobsOf(sim, k)
		local out = {}
		for _, id in k.citizenIds do
			local job = sim.citizens[id].job
			out[job] = (out[job] or 0) + 1
		end
		return out
	end

	it("setJob moves one citizen and its quota follows, so the rebalancer leaves it there", function()
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local farmer
		for _, id in k.citizenIds do
			if sim.citizens[id].job == "farmer" then
				farmer = sim.citizens[id]
				break
			end
		end
		assert(farmer, "a crimson farmer")
		local quotas = table.clone(k.quotas)
		expect(citizens:setJob(farmer.id, "miner")).toBe(true)
		expect(farmer.job).toBe("miner")
		expect(k.quotas.farmer).toBe(quotas.farmer - 1)
		expect(k.quotas.miner).toBe(quotas.miner + 1)
		local jobs = jobsOf(sim, k)
		env.mock:advance(60) -- a minute of rebalancing: nobody is moved back to the farms
		expect(farmer.job).toBe("miner")
		expect(jobsOf(sim, k)).toEqual(jobs)
		-- the hauler pool has no quota: a hauler order only lowers the old job's quota
		expect(citizens:setJob(farmer.id, "hauler")).toBe(true)
		expect(k.quotas.miner).toBe(quotas.miner)
		expect(k.quotas.hauler).toBe(quotas.hauler)
		-- the same job again changes nothing
		local same = table.clone(k.quotas)
		expect(citizens:setJob(farmer.id, "hauler")).toBe(true)
		expect(k.quotas).toEqual(same)
		-- refused: soldiers (Military's), unknown jobs, a unit, nobody, malformed
		expect(citizens:setJob(farmer.id, "soldier")).toBe(false)
		expect(citizens:setJob(farmer.id, "wizard")).toBe(false)
		expect(citizens:setJob(farmer.id, 5 :: any)).toBe(false)
		local unit = Military.spawnUnit(sim, k, "soldier", k.x, k.z)
		expect(citizens:setJob(unit.id, "farmer")).toBe(false)
		expect(citizens:setJob(999999, "farmer")).toBe(false)
		expect(farmer.job).toBe("hauler")
		expect(k.quotas).toEqual(same)
	end)

	it("requestWorkers sets the job's quota and haulers fill it; bad orders change nothing", function()
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local k = sim.kingdoms.crimson
		local miners = jobsOf(sim, k).miner or 0
		expect(citizens:requestWorkers("crimson", "miner", miners + 1)).toBe(true)
		expect(k.quotas.miner).toBe(miners + 1)
		env.mock:advance(60)
		expect(jobsOf(sim, k).miner).toBe(miners + 1)
		local quotas = table.clone(k.quotas)
		expect({ citizens:requestWorkers("crimson", "hauler", 3) }).toEqual({ false, "unknown_job" })
		expect({ citizens:requestWorkers("crimson", "wizard", 3) }).toEqual({ false, "unknown_job" })
		expect({ citizens:requestWorkers("crimson", "miner", -1) }).toEqual({ false, "invalid_args" })
		expect({ citizens:requestWorkers("crimson", "miner", 1.5) }).toEqual({ false, "invalid_args" })
		expect({ citizens:requestWorkers("violet", "miner", 1) }).toEqual({ false, "unknown_kingdom" })
		expect(k.quotas).toEqual(quotas)
	end)

	it("a ruler's visit is remembered and lifts the citizen's mood for a while, once per cooldown", function()
		local env, citizens, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = match.host.match.sim
		local tuning = sim.catalog.tuning
		local c = sim.citizens[sim.kingdoms.crimson.citizenIds[1]]
		c.hunger = 0.5
		expect(assert(citizens:inspect(c.id)).mood).toBe(50)
		expect(sim:rulerVisit(c, 1)).toBe(true)
		local remembered
		for _, entry in c.memory do
			if entry.kind == "rulerVisited" then
				remembered = entry
			end
		end
		expect(remembered and remembered.ref).toBe(1)
		expect(assert(citizens:inspect(c.id)).mood).toBe(50 + tuning.visitMood)
		expect(sim:rulerVisit(c, 1)).toBe(false) -- again at once: no second lift
		env.mock:advance(tuning.visitMoodSeconds + 1)
		c.hunger = 0.5
		expect(assert(citizens:inspect(c.id)).mood).toBe(50) -- the lift has worn off
		c.hunger = 0
		expect(assert(citizens:inspect(c.id)).mood).toBe(100)
		env.mock:advance(math.max(0, tuning.visitCooldown - tuning.visitMoodSeconds))
		c.hunger = 0
		expect(sim:rulerVisit(c, 2)).toBe(true) -- after the cooldown a visit counts again
		expect(assert(citizens:inspect(c.id)).mood).toBe(100) -- clamped
	end)
end)
