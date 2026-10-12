-- FL-0058: TreasuryService and ProductionService (CONTRACTS G7) with the real framework
-- RemoteService and RemoteClient; KingdomService and CitizenService (FORGE-01) are local doubles.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local RemoteClient = require("@game/ReplicatedStorage/Forge/Core/RemoteClient")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local ProductionDef = require("@game/ServerScriptService/Game/Services/ProductionService")
local TreasuryDef = require("@game/ServerScriptService/Game/Services/TreasuryService")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")

-- FORGE-01 doubles: just the G3/G5 members these services call.
local function kingdomServiceDouble(assignments: { [number]: string })
	return {
		name = "KingdomService",
		new = function()
			return {
				membershipChanged = Signal.new(),
				getKingdomOf = function(_, player)
					return assignments[player.UserId]
				end,
			}
		end,
	}
end

local function citizenServiceDouble(populations: { [string]: any })
	return {
		name = "CitizenService",
		new = function()
			return {
				fed = {},
				getPopulation = function(_, kingdom)
					return populations[kingdom]
				end,
				setFedRatio = function(self, kingdom, ratio)
					self.fed[kingdom] = ratio
				end,
			}
		end,
	}
end

local START = table.clone(Costs.starting)
local function bag(extra)
	local out = { food = START.food or 0, wood = START.wood or 0, stone = START.stone or 0, gold = START.gold or 0 }
	for k, v in extra or {} do
		out[k] = v
	end
	return out
end

describe("TreasuryService (G7)", function()
	local env, registry, treasury, alice, bob, eve, assignments, events
	beforeEach(function()
		env = MockEnv.new({ seed = 5, sharedModules = { Remotes = { Treasury = TreasuryRemotes } } })
		alice = env.mock.players:add({ userId = 1 })
		bob = env.mock.players:add({ userId = 2 })
		eve = env.mock.players:add({ userId = 3 })
		assignments = { [1] = "azure", [2] = "azure", [3] = "crimson" }
		registry = Loader.load(env, { RemoteServiceDef, TreasuryDef, kingdomServiceDouble(assignments) })
		treasury = registry:get("TreasuryService")
		events = {}
		treasury.changed:connect(function(kingdom, totals, deltas)
			table.insert(events, { kingdom = kingdom, totals = totals, deltas = deltas })
		end)
	end)
	afterEach(function()
		registry:destroy()
		GameEvents.disconnectAll()
	end)

	it("starts every kingdom from Costs.starting and reads unknown kingdoms as empty", function()
		for _, kingdom in { "crimson", "azure", "emerald", "gold" } do
			expect(treasury:get(kingdom)).toEqual(bag())
		end
		expect(treasury:get("nowhere")).toEqual({ food = 0, wood = 0, stone = 0, gold = 0 })
		expect(treasury:canAfford("nowhere", {})).toBe(false)
	end)

	it("spends atomically: all or nothing, never negative", function()
		expect(treasury:canAfford("azure", { wood = 100, stone = 50 })).toBe(true)
		expect(treasury:spend("azure", { wood = 60, stone = 999 }, "build:7:1", "building:house")).toBe(false)
		expect(treasury:get("azure")).toEqual(bag()) -- nothing taken from the affordable part
		expect(treasury:spend("azure", { wood = 100 }, "build:8:1", "building:farm")).toBe(true)
		expect(treasury:get("azure").wood).toBe(0)
		expect(treasury:spend("azure", { wood = 1 }, "build:9:1", "building:farm")).toBe(false)
		expect(treasury:get("azure").wood).toBe(0)
		expect(events).toHaveLength(1)
		expect(events[1].deltas).toEqual({ wood = -100 })
	end)

	it("treats a replayed txId as done: no second charge, no second event", function()
		expect(treasury:spend("azure", { wood = 40 }, "build:12:1", "building:house")).toBe(true)
		expect(treasury:spend("azure", { wood = 40 }, "build:12:1", "building:house")).toBe(true)
		expect(treasury:get("azure").wood).toBe(START.wood - 40)
		expect(treasury:deposit("azure", "food", 5, "dep:44:1", "citizen:farmer")).toBe(true)
		expect(treasury:deposit("azure", "food", 5, "dep:44:1", "citizen:farmer")).toBe(true)
		expect(treasury:get("azure").food).toBe(START.food + 5)
		expect(events).toHaveLength(2)
	end)

	it("lets two rulers of one kingdom spend at once without overdrawing", function()
		-- both see 100 wood and try to pay 60; the second must be refused
		local first = treasury:spend("azure", { wood = 60 }, "build:1:1", "building:farm")
		local second = treasury:spend("azure", { wood = 60 }, "build:2:1", "building:farm")
		expect(first).toBe(true)
		expect(second).toBe(false)
		expect(treasury:get("azure").wood).toBe(START.wood - 60)
	end)

	it("spendUpTo takes what is there, returns it, and replays the first answer", function()
		local taken = treasury:spendUpTo("azure", "food", START.food + 30, "upkeep:azure:1", "upkeep")
		expect(taken).toBe(START.food)
		expect(treasury:get("azure").food).toBe(0)
		expect(treasury:spendUpTo("azure", "food", 10, "upkeep:azure:2", "upkeep")).toBe(0)
		expect(treasury:deposit("azure", "food", 50, "dep:1:1", "ruler")).toBe(true)
		expect(treasury:spendUpTo("azure", "food", START.food + 30, "upkeep:azure:1", "upkeep")).toBe(START.food)
		expect(treasury:get("azure").food).toBe(50) -- the replay took nothing
		expect(treasury:spendUpTo("azure", "food", 20, "upkeep:azure:3", "upkeep")).toBe(20)
	end)

	it("refuses bad input and changes nothing", function()
		local cases = {
			function()
				return treasury:deposit("azure", "iron", 5, "a", "x")
			end,
			function()
				return treasury:deposit("azure", "food", -5, "b", "x")
			end,
			function()
				return treasury:deposit("azure", "food", 2.5, "c", "x")
			end,
			function()
				return treasury:deposit("azure", "food", 0 / 0, "d", "x")
			end,
			function()
				return treasury:deposit("azure", "food", 5, "", "x")
			end,
			function()
				return treasury:deposit("azure", "food", 5, "e", "")
			end,
			function()
				return treasury:deposit("nowhere", "food", 5, "f", "x")
			end,
			function()
				return treasury:spend("azure", { food = -1 }, "g", "x")
			end,
			function()
				return treasury:spend("azure", { mana = 1 }, "h", "x")
			end,
		}
		for i, case in cases do
			local ok = case()
			if ok ~= false then
				error(`case {i} should be refused`)
			end
		end
		expect(treasury:spendUpTo("azure", "food", -3, "i", "upkeep")).toBe(0)
		expect(treasury:spendUpTo("azure", "iron", 3, "j", "upkeep")).toBe(0)
		expect(treasury:get("azure")).toEqual(bag())
		expect(events).toHaveLength(0)
	end)

	it("keeps kingdoms separate", function()
		treasury:spend("crimson", { wood = 100 }, "same", "x")
		expect(treasury:spend("azure", { wood = 100 }, "same", "x")).toBe(true)
		expect(treasury:get("crimson").wood).toBe(0)
		expect(treasury:get("azure").wood).toBe(0)
		expect(treasury:get("emerald").wood).toBe(START.wood)
	end)

	it("replicates to members only, answers Treasury.Get and Treasury.GetCosts", function()
		local clients = {}
		for _, player in { alice, bob, eve } do
			env.mock.remotes:asClient(player, function()
				local client = RemoteClient.new(env)
				local seen = {}
				client:on("Treasury.Changed", function(totals, deltas)
					table.insert(seen, { totals = totals, deltas = deltas })
				end)
				clients[player.UserId] = { client = client, seen = seen }
			end)
		end
		treasury:deposit("azure", "wood", 7, "gather:1:1", "ruler")
		env.mock:advance(0)
		expect(clients[1].seen[1].deltas).toEqual({ wood = 7 })
		expect(clients[2].seen[1].totals.wood).toBe(START.wood + 7)
		expect(#clients[3].seen).toBe(0) -- crimson does not see azure's treasury
		env.mock.remotes:asClient(alice, function()
			expect(clients[1].client:invoke("Treasury.Get")).toEqual(treasury:get("azure"))
			expect(clients[1].client:invoke("Treasury.GetCosts").buildings.keep[2]).toEqual(Costs.building("keep", 2))
		end)
		local stranger = env.mock.players:add({ userId = 9 })
		env.mock.remotes:asClient(stranger, function()
			expect(RemoteClient.new(env):invoke("Treasury.Get")).toBeNil()
		end)
	end)

	it("sends the totals to a player who joins a kingdom", function()
		local seen = {}
		env.mock.remotes:asClient(eve, function()
			RemoteClient.new(env):on("Treasury.Changed", function(totals, deltas)
				table.insert(seen, { totals = totals, deltas = deltas })
			end)
		end)
		assignments[3] = "emerald"
		registry:get("KingdomService").membershipChanged:fire(eve, "emerald")
		env.mock:advance(0)
		expect(seen[1].totals).toEqual(treasury:get("emerald"))
		expect(seen[1].deltas).toEqual({})
	end)

	it("resets every kingdom when a new match enters Founding", function()
		treasury:spend("azure", { wood = 100 }, "x1", "x")
		GameEvents.MatchPhaseChanged:fire("Expansion")
		expect(treasury:get("azure").wood).toBe(0)
		GameEvents.MatchPhaseChanged:fire("Founding")
		expect(treasury:get("azure")).toEqual(bag())
		local azureReset
		for _, e in events do
			if e.kingdom == "azure" then
				azureReset = e
			end
		end
		expect(azureReset.deltas.wood).toBe(START.wood) -- members see the refill
		-- old txIds belong to the old match: the same id works again
		expect(treasury:spend("azure", { wood = 100 }, "x1", "x")).toBe(true)
		expect(treasury:get("azure").wood).toBe(0)
	end)
end)

describe("ProductionService upkeep (G7)", function()
	local env, registry, treasury, production, citizens, populations
	beforeEach(function()
		env = MockEnv.new({ seed = 6, sharedModules = { Remotes = { Treasury = TreasuryRemotes } } })
		populations = {
			azure = { total = 14, byJob = { farmer = 3, soldier = 2 }, cap = 20 },
			crimson = { total = 0, byJob = {}, cap = 10 },
		}
		registry = Loader.load(env, {
			RemoteServiceDef,
			TreasuryDef,
			ProductionDef,
			kingdomServiceDouble({}),
			citizenServiceDouble(populations),
		})
		treasury = registry:get("TreasuryService")
		production = registry:get("ProductionService")
		citizens = registry:get("CitizenService")
	end)
	afterEach(function()
		registry:destroy()
		GameEvents.disconnectAll()
	end)

	it("computes upkeep from citizens and soldiers", function()
		local soldier = Costs.unit("soldier").upkeepFood
		expect(production:upkeepFor(populations.azure)).toBe(12 * Costs.upkeep.citizenFood + 2 * soldier)
		expect(production:upkeepFor({ total = 0 })).toBe(0)
	end)

	it("charges nothing outside a running match", function()
		env.mock:advance(Costs.upkeep.intervalSeconds * 2)
		expect(treasury:get("azure").food).toBe(START.food)
		expect(citizens.fed.azure).toBeNil()
	end)

	it("takes upkeep once per interval and sets the fed ratio", function()
		GameEvents.MatchPhaseChanged:fire("Founding")
		local upkeep = production:upkeepFor(populations.azure)
		env.mock:advance(Costs.upkeep.intervalSeconds)
		expect(treasury:get("azure").food).toBe(START.food - upkeep)
		expect(citizens.fed.azure).toBe(1)
		expect(citizens.fed.crimson).toBe(1) -- nobody to feed
		expect(treasury:get("crimson").food).toBe(START.food)
	end)

	it("feeds partially when food runs short and reports the ratio", function()
		GameEvents.MatchPhaseChanged:fire("Founding")
		local upkeep = production:upkeepFor(populations.azure)
		treasury:spendUpTo("azure", "food", START.food - math.floor(upkeep / 2), "drain", "test")
		local left = treasury:get("azure").food
		env.mock:advance(Costs.upkeep.intervalSeconds)
		expect(treasury:get("azure").food).toBe(0)
		expect(citizens.fed.azure).toBeNear(left / upkeep, 1e-9)
		expect(production.lastFed.azure).toBeNear(left / upkeep, 1e-9)
		env.mock:advance(Costs.upkeep.intervalSeconds)
		expect(citizens.fed.azure).toBe(0) -- starving
	end)
end)
