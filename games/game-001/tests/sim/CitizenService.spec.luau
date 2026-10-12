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
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local People = require("@game/ReplicatedStorage/Game/Sim/People")
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
	local registry = Loader.load(env, definitions)
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
			for _, relation in { "family", "friends", "rivals" } do
				expect(#view[relation]).toBe(#c.profile[relation])
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
