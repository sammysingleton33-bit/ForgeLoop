local T = require("../../harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MockEnv = require("../../mocks/MockEnv")
local TreasuryDef = require("@game/ServerScriptService/Forge/Services/EconomyTreasuryService")
local KingdomWorld = require("./doubles/KingdomWorld")

describe("EconomyTreasuryService (no RemoteService in the build)", function()
	local env, registry, treasury, alice, bob
	beforeEach(function()
		env = MockEnv.new({ seed = 3 })
		alice = env.mock.players:add({ userId = 10 })
		bob = env.mock.players:add({ userId = 11 })
		registry = Loader.load(env, { TreasuryDef })
		treasury = registry:get("EconomyTreasuryService")
	end)
	afterEach(function()
		registry:destroy()
	end)

	it("loads without RemoteService and says so once", function()
		expect(env.mock:hasLog("warn", "no RemoteService")).toBe(true)
	end)

	it("opens a treasury with the configured match start and caps", function()
		treasury:open("k1", { members = { alice } })
		expect(treasury:balances("k1")).toEqual({ food = 100, wood = 150, stone = 50, gold = 50 })
		expect(treasury:caps("k1")).toEqual({ food = 500, wood = 500, stone = 300, gold = 300 })
		expect(treasury:kingdomOf(alice)).toBe("k1")
		expect(treasury:kingdomOf(bob)).toBeNil()
		expect(function()
			treasury:open("k1")
		end).toThrow("already open")
	end)

	it("fires changed exactly once per applied transaction, never on replay or refusal", function()
		treasury:open("k1", { members = { alice } })
		local events = {}
		treasury.changed:connect(function(kingdomId, snapshot, change)
			table.insert(events, { kingdomId, snapshot.version, change.reason, change.delta })
		end)
		expect((treasury:spend("k1", { wood = 50 }, "tx1", "build:farm"))).toBe(true)
		local _, replay = treasury:spend("k1", { wood = 50 }, "tx1", "build:farm")
		expect(replay).toBe("replay")
		local okShort, short = treasury:spend("k1", { stone = 999 }, "tx2", "build:keep")
		expect(okShort).toBe(false)
		expect(short).toBe("insufficient")
		local _, badTag = treasury:spend("k1", { wood = 1 }, "tx3", "")
		expect(badTag).toBe("invalid_tag")
		local _, unknown = treasury:grant("nope", { wood = 1 }, "tx4", "production")
		expect(unknown).toBe("unknown_kingdom")
		expect((treasury:grant("k1", { food = 20 }, "prod:1", "production"))).toBe(true)
		expect(events).toEqual({
			{ "k1", 2, "build:farm", { wood = -50 } },
			{ "k1", 3, "production", { food = 20 } },
		})
		expect(treasury:balances("k1")).toEqual({ food = 120, wood = 100, stone = 50, gold = 50 })
	end)

	it("keeps kingdoms separate", function()
		treasury:open("k1", { members = { alice } })
		treasury:open("k2", { members = { bob }, start = { wood = 5 } })
		treasury:spend("k1", { wood = 100 }, "same-id", "build:x")
		local ok, reason = treasury:spend("k2", { wood = 5 }, "same-id", "build:x")
		expect(ok).toBe(true)
		expect(reason).toBeNil()
		expect(treasury:balances("k1").wood).toBe(50)
		expect(treasury:balances("k2").wood).toBe(0)
	end)

	it("announces raised caps and forgets members who leave", function()
		treasury:open("k1", { members = { alice } })
		local reasons = {}
		treasury.changed:connect(function(_, _, change)
			table.insert(reasons, change.reason)
		end)
		treasury:setCaps("k1", { food = 750 })
		treasury:setCaps("k1", { food = 750 }) -- unchanged: no event
		expect(reasons).toEqual({ "caps" })
		env.mock.players:remove(alice)
		env.mock:advance(0)
		expect(treasury:kingdomOf(alice)).toBeNil()
		treasury:close("k1")
		expect(treasury:isOpen("k1")).toBe(false)
	end)
end)

describe("EconomyTreasuryService + kingdom doubles through the remotes", function()
	local world
	beforeEach(function()
		world = KingdomWorld.new()
	end)
	afterEach(function()
		world:destroy()
	end)

	it("answers Economy.GetTreasury with the caller's treasury", function()
		local snapshot = world.rc.invoke("Economy.GetTreasury")
		expect(snapshot.kingdomId).toBe(world.kingdomId)
		expect(snapshot.balances).toEqual({ food = 100, wood = 150, stone = 50, gold = 50 })
	end)

	it("builds through Gameplay.Build: spends once, replicates the change, completes later", function()
		local received = {}
		world.rc.on("Economy.Treasury", function(snapshot, change)
			table.insert(received, { version = snapshot.version, change = change })
		end)
		local ok, reason, uid = world.controller:build("farm")
		expect(ok).toBe(true)
		expect(reason).toBeNil()
		expect(uid).toBeA("string")
		world:advance(0)
		expect(world.treasury:balances(world.kingdomId).wood).toBe(110)
		local spends = {}
		for _, r in received do
			if r.change and r.change.reason == "build:farm" then
				table.insert(spends, r.change.delta)
			end
		end
		expect(spends).toEqual({ { wood = -40 } })
		local state = world.controller.state
		local farm
		for _, b in state.buildings do
			if b.uid == uid then
				farm = b
			end
		end
		expect(farm.state).toBe("constructing")
		expect(state.builders.busy).toBe(1)
		world:advance(16)
		for _, b in world.controller.state.buildings do
			if b.uid == uid then
				farm = b
			end
		end
		expect(farm.state).toBe("ready")
		expect(farm.level).toBe(1)
	end)

	it("refuses unaffordable or locked buildings without spending", function()
		local ok, reason = world.controller:build("goldmine")
		expect(ok).toBe(false)
		expect(reason).toBe("requirement")
		world.treasury:spend(world.kingdomId, { wood = 140 }, "drain", "test")
		local ok2, reason2 = world.controller:build("farm")
		expect(ok2).toBe(false)
		expect(reason2).toBe("cost")
		expect(world.treasury:balances(world.kingdomId).wood).toBe(10)
	end)

	it("drops malformed client calls before they reach the kingdom", function()
		local result = world.rc.invoke("Gameplay.Build", 42)
		expect(result).toBeNil()
		world.rc.invoke("Gameplay.Build", "farm", "plot", "extra")
		expect(#world.remotes.dropped).toBe(2)
		expect(world.treasury:balances(world.kingdomId).wood).toBe(150)
	end)

	it("pays production from assigned workers every 10 seconds", function()
		local _, _, uid = world.controller:build("farm")
		world:advance(16)
		expect((world.controller:assignWorkers(uid, 3))).toBe(true)
		local before = world.treasury:balances(world.kingdomId).food
		world:advance(60)
		-- 3 workers x 6 food/min = 18 per minute
		expect(world.treasury:balances(world.kingdomId).food - before).toBe(18)
		local okMore, why = world.controller:assignWorkers(uid, 50)
		expect(okMore).toBe(true) -- clamped to the farm's 3 slots
		expect(why).toBeNil()
		expect(world.controller:assignWorkers(uid, 99)).toBeNil() -- outside the declared 0..50: dropped
		expect(#world.remotes.dropped).toBe(1)
	end)
end)
