local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MockEnv = require("../../mocks/MockEnv")
local RemoteClient = require("@game/ReplicatedStorage/Forge/Core/RemoteClient")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local V = require("@game/ReplicatedStorage/Forge/Core/Validate")

local NAN = 0 / 0
local INF = math.huge

local function declarations()
	return {
		Economy = {
			{
				name = "Economy.BuyItem",
				kind = "function",
				args = { V.string(1, 64), V.integer(1, 99) },
				rate = { burst = 5, perSecond = 1 },
			},
			{ name = "Economy.Equip", kind = "event", args = { V.string(1, 32), V.optional(V.boolean()) } },
			{ name = "Economy.WalletChanged", kind = "serverEvent" },
		},
		Gameplay = {
			{ name = "Gameplay.Aim", kind = "event", args = { V.vector3(1000), V.number(0, 1) } },
			{ name = "Gameplay.Tags", kind = "event", args = { V.array(V.string(1, 16), 4) } },
			{ name = "Gameplay.Ping", kind = "event" },
			{ name = "Gameplay.GetRoundState", kind = "function" },
			{ name = "Gameplay.RoundState", kind = "serverEvent" },
		},
		Experience = {
			{ name = "Experience.Sfx", kind = "unreliableServerEvent" },
		},
	}
end

-- Boots RemoteService through the Loader (which fails if new() yields) with the given declarations.
local function boot(remotes: any?)
	local env = MockEnv.new({ sharedModules = { Remotes = remotes or declarations() } })
	local registry = Loader.load(env, { RemoteServiceDef })
	local service = registry:get("RemoteService")
	local client = RemoteClient.new(env)
	local function as(player, fn)
		env.mock.remotes:asClient(player, fn)
	end
	return env, service, client, as, registry
end

local function bootError(remotes): string
	local ok, err = pcall(boot, remotes)
	assert(not ok, "expected the boot to fail")
	return tostring(err)
end

describe("RemoteService", function()
	describe("boot", function()
		it("creates ReplicatedStorage.ForgeRemotes.<Area>.<Action> with the right classes", function()
			local env = boot()
			local root = env.ReplicatedStorage:FindFirstChild("ForgeRemotes")
			expect(root).never.toBeNil()
			expect(root.ClassName).toBe("Folder")
			local function class(area, action)
				return root:FindFirstChild(area):FindFirstChild(action).ClassName
			end
			expect(class("Economy", "BuyItem")).toBe("RemoteFunction")
			expect(class("Economy", "Equip")).toBe("RemoteEvent")
			expect(class("Economy", "WalletChanged")).toBe("RemoteEvent")
			expect(class("Gameplay", "GetRoundState")).toBe("RemoteFunction")
			expect(class("Experience", "Sfx")).toBe("UnreliableRemoteEvent")
			expect(#root:GetChildren()).toBe(3)
			expect(#root:FindFirstChild("Gameplay"):GetChildren()).toBe(5)
		end)

		it("boots with no declarations (empty ForgeRemotes)", function()
			local env = boot({})
			expect(#env.ReplicatedStorage:FindFirstChild("ForgeRemotes"):GetChildren()).toBe(0)
		end)

		it("rejects a duplicate declaration at boot", function()
			local remotes = declarations()
			table.insert(remotes.Economy, { name = "Economy.BuyItem", kind = "event" })
			local err = bootError(remotes)
			expect(err).toContain("RemoteService.new() failed")
			expect(err).toContain("duplicate remote name 'Economy.BuyItem'")
		end)

		it("rejects bad declarations with the area, index and problem", function()
			local cases = {
				{ { name = "Gameplay.X", kind = "event" }, "does not match the folder 'Economy'" },
				{ { name = "EconomyX", kind = "event" }, "name must be '<Area>.<Action>'" },
				{ { name = "Economy.A.B", kind = "event" }, "name must be '<Area>.<Action>'" },
				{ { name = "Economy.X", kind = "push" }, "kind 'push' must be event, function" },
				{ { name = "Economy.X", kind = "serverEvent", args = { V.boolean() } }, "args are only allowed" },
				{ { name = "Economy.X", kind = "serverEvent", rate = { burst = 1, perSecond = 1 } }, "rate is only" },
				{ { name = "Economy.X", kind = "event", args = { "string" } }, "args[1] must be a validator" },
				{ { name = "Economy.X", kind = "event", rate = { burst = 0, perSecond = 1 } }, "rate.burst" },
				{ { name = "Economy.X", kind = "event", rate = { burst = 1, perSecond = NAN } }, "rate.perSecond" },
				{ { name = "Economy.X", kind = "event", arg = { V.boolean() } }, "unknown field 'arg'" },
				{ "Economy.X", "expected a table" },
			}
			for _, case in cases do
				local err = bootError({ Economy = { case[1] } })
				expect(err).toContain("Economy/Remotes.luau declaration #1")
				expect(err).toContain(case[2])
			end
			expect(bootError({ Economy = { list = "nope" } })).toContain("must return a list")
		end)

		it("refuses to boot when ForgeRemotes already exists", function()
			local env = MockEnv.new({ sharedModules = { Remotes = declarations() } })
			local stray = env.newInstance("Folder")
			stray.Name = "ForgeRemotes"
			stray.Parent = env.ReplicatedStorage
			expect(function()
				Loader.load(env, { RemoteServiceDef })
			end).toThrow("already exists")
		end)
	end)

	describe("handle", function()
		it("errors on undeclared names, server -> client kinds, a second handler and a non-function", function()
			local _, service = boot()
			expect(function()
				service:handle("Economy.Nope", function() end)
			end).toThrow("'Economy.Nope' is not declared")
			expect(function()
				service:handle("Economy.WalletChanged", function() end)
			end).toThrow("kind 'serverEvent' (server -> client)")
			service:handle("Economy.Equip", function() end)
			expect(function()
				service:handle("Economy.Equip", function() end)
			end).toThrow("already has a handler")
			expect(function()
				service:handle("Gameplay.Ping", nil :: any)
			end).toThrow("fn must be a function")
		end)
	end)

	describe("inbound calls", function()
		it("delivers a valid event to the handler with the player and arguments", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local got = {}
			service:handle("Economy.Equip", function(player, itemId, favourite)
				table.insert(got, { player.UserId, itemId, favourite })
			end)
			as(alice, function()
				client:send("Economy.Equip", "sword", true)
				client:send("Economy.Equip", "bow") -- missing optional argument: validated as nil
			end)
			expect(got).toEqual({ { 1, "sword", true }, { 1, "bow", nil } })
			expect(service:stats().dropped).toEqual({})
		end)

		it("drops and counts wrong types without running the handler", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local calls = 0
			service:handle("Economy.Equip", function()
				calls += 1
			end)
			as(alice, function()
				client:send("Economy.Equip", 5)
				client:send("Economy.Equip", { "sword" })
				client:send("Economy.Equip", "sword", "yes")
				client:send("Economy.Equip")
			end)
			expect(calls).toBe(0)
			local stats = service:stats()
			expect(stats.dropped).toEqual({ invalidArgs = 4 })
			expect(stats.droppedByName).toEqual({ ["Economy.Equip"] = 4 })
		end)

		it("drops NaN and ±inf numbers and vectors", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local accepted = {}
			service:handle("Gameplay.Aim", function(_, direction, power)
				table.insert(accepted, { direction, power })
			end)
			as(alice, function()
				client:send("Gameplay.Aim", Vector3.new(1, 0, 0), NAN)
				client:send("Gameplay.Aim", Vector3.new(1, 0, 0), INF)
				client:send("Gameplay.Aim", Vector3.new(1, 0, 0), -INF)
				client:send("Gameplay.Aim", Vector3.new(NAN, 0, 0), 0.5)
				client:send("Gameplay.Aim", Vector3.new(0, INF, 0), 0.5)
				client:send("Gameplay.Aim", Vector3.new(0, 1, 0), 0.5)
			end)
			expect(#accepted).toBe(1)
			expect(service:stats().dropped.invalidArgs).toBe(5)
		end)

		it("drops oversized payloads and invalid UTF-8", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local calls = 0
			service:handle("Economy.Equip", function()
				calls += 1
			end)
			service:handle("Gameplay.Tags", function()
				calls += 1
			end)
			as(alice, function()
				client:send("Economy.Equip", string.rep("x", 33))
				client:send("Economy.Equip", string.rep("x", 200000))
				client:send("Economy.Equip", "\xff")
				client:send("Gameplay.Tags", { "a", "b", "c", "d", "e" })
				client:send("Gameplay.Tags", { "a", string.rep("y", 17) })
				client:send("Gameplay.Tags", { "a", "b" }) -- valid
			end)
			expect(calls).toBe(1)
			expect(service:stats().dropped).toEqual({ invalidArgs = 5 })
		end)

		it("drops calls with extra arguments, also on a remote declared without args", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local calls = 0
			service:handle("Economy.Equip", function()
				calls += 1
			end)
			service:handle("Gameplay.Ping", function()
				calls += 1
			end)
			as(alice, function()
				client:send("Economy.Equip", "sword", true, "extra")
				client:send("Economy.Equip", "sword", nil, nil) -- trailing nils still count
				client:send("Gameplay.Ping", 1)
				client:send("Gameplay.Ping")
			end)
			expect(calls).toBe(1)
			local stats = service:stats()
			expect(stats.dropped).toEqual({ extraArgs = 3 })
			expect(stats.droppedByName).toEqual({ ["Economy.Equip"] = 2, ["Gameplay.Ping"] = 1 })
		end)

		it("rate-limits per player per remote: default burst 10, then 5 per second", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local calls = 0
			service:handle("Economy.Equip", function()
				calls += 1
			end)
			local function burst(n)
				as(alice, function()
					for _ = 1, n do
						client:send("Economy.Equip", "sword")
					end
				end)
			end
			burst(12)
			expect(calls).toBe(10)
			expect(service:stats().dropped).toEqual({ rateLimited = 2 })
			env.mock:advance(0.2) -- one token at 5 per second
			burst(2)
			expect(calls).toBe(11)
			env.mock:advance(60) -- refills to the burst, not beyond
			burst(15)
			expect(calls).toBe(21)
			expect(service:stats().dropped.rateLimited).toBe(8)
		end)

		it("uses the declared rate and keeps players and remotes independent", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local bob = env.mock.players:add({ userId = 2 })
			local bought = 0
			service:handle("Economy.BuyItem", function()
				bought += 1
				return true
			end)
			local pings = 0
			service:handle("Gameplay.Ping", function()
				pings += 1
			end)
			as(alice, function()
				for _ = 1, 7 do
					client:invoke("Economy.BuyItem", "sword", 1)
				end
				client:send("Gameplay.Ping") -- another remote: its own bucket
			end)
			expect(bought).toBe(5) -- declared burst 5
			expect(pings).toBe(1)
			as(bob, function()
				expect(client:invoke("Economy.BuyItem", "bow", 2)).toBe(true) -- bob has his own bucket
			end)
			env.mock:advance(1) -- declared 1 per second
			as(alice, function()
				expect(client:invoke("Economy.BuyItem", "sword", 1)).toBe(true)
				expect(client:invoke("Economy.BuyItem", "sword", 1)).toBeNil()
			end)
		end)

		it("drops calls on declared remotes without a handler and client fires of server -> client remotes", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local result = "unset"
			as(alice, function()
				client:send("Gameplay.Ping")
				result = client:invoke("Gameplay.GetRoundState")
				client:send("Gameplay.RoundState", "Active") -- a serverEvent fired by a client
			end)
			expect(result).toBeNil()
			expect(service:stats().dropped).toEqual({ noHandler = 2, wrongDirection = 1 })
		end)

		it("isolates handler errors: logged, counted, nil to the invoker, later calls still work", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local fail = true
			service:handle("Economy.BuyItem", function(_, itemId, qty)
				if fail then
					error("inventory exploded")
				end
				return itemId, qty
			end)
			local equips = 0
			service:handle("Economy.Equip", function()
				equips += 1
				error("equip broke")
			end)
			as(alice, function()
				local first
				expect(function()
					first = client:invoke("Economy.BuyItem", "sword", 2)
				end).never.toThrow()
				expect(first).toBeNil()
				client:send("Economy.Equip", "sword")
				fail = false
				local itemId, qty = client:invoke("Economy.BuyItem", "sword", 2)
				expect(itemId).toBe("sword")
				expect(qty).toBe(2)
			end)
			expect(equips).toBe(1)
			expect(env.mock:hasLog("error", "handler for 'Economy.BuyItem' failed")).toBe(true)
			expect(env.mock:hasLog("error", "handler for 'Economy.Equip' failed")).toBe(true)
			local entry
			for _, log in env.mock.logs do
				if log.level == "error" and log.fields.remote == "Economy.BuyItem" then
					entry = log
				end
			end
			expect(entry.fields.error).toContain("inventory exploded")
			expect(entry.fields.userId).toBe(1)
			expect(service:stats().dropped).toEqual({ handlerError = 2 })
		end)

		it("returns a function handler's results to the client; nil when the call is dropped", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			service:handle("Gameplay.GetRoundState", function(player)
				return { state = "Lobby", roundId = "r1", asker = player.UserId }
			end)
			service:handle("Economy.BuyItem", function(_, itemId, qty)
				return true, `{itemId}x{qty}`
			end)
			as(alice, function()
				expect(client:invoke("Gameplay.GetRoundState")).toEqual({ state = "Lobby", roundId = "r1", asker = 1 })
				local ok, receipt = client:invoke("Economy.BuyItem", "sword", 3)
				expect(ok).toBe(true)
				expect(receipt).toBe("swordx3")
				expect(client:invoke("Economy.BuyItem", "sword", 0)).toBeNil() -- invalid qty
				expect(client:invoke("Gameplay.GetRoundState", "extra")).toBeNil()
			end)
		end)

		it("logs only the first drop of each remote and reason; the rest are counted", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			service:handle("Economy.Equip", function() end)
			as(alice, function()
				for _ = 1, 3 do
					client:send("Economy.Equip", 1)
				end
			end)
			local warnings = 0
			for _, log in env.mock.logs do
				if log.level == "warn" and string.find(log.message, "dropped call", 1, true) then
					warnings += 1
					expect(log.fields.reason).toBe("invalidArgs")
					expect(log.fields.detail).toContain("argument 1: expected string, got number")
				end
			end
			expect(warnings).toBe(1)
			expect(service:stats().dropped.invalidArgs).toBe(3)
		end)

		it("frees a player's rate-limit state when they leave and drops calls from departed players", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local calls = 0
			service:handle("Economy.Equip", function()
				calls += 1
			end)
			service:handle("Gameplay.Ping", function() end)
			as(alice, function()
				client:send("Economy.Equip", "sword")
				client:send("Gameplay.Ping")
			end)
			expect(service:stats().buckets).toBe(2)
			env.mock.players:remove(alice)
			expect(service:stats().buckets).toBe(0)
			as(alice, function()
				client:send("Economy.Equip", "sword") -- a late packet from the departed player
			end)
			expect(calls).toBe(1)
			expect(service:stats().buckets).toBe(0)
			expect(service:stats().dropped).toEqual({ playerGone = 1 })
		end)
	end)

	describe("outbound", function()
		it("fire() reaches only that player's client", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			local bob = env.mock.players:add({ userId = 2 })
			local got = {}
			for _, player in { alice, bob } do
				as(player, function()
					client:on("Economy.WalletChanged", function(coins)
						table.insert(got, { player.UserId, coins })
					end)
				end)
			end
			expect(service:fire("Economy.WalletChanged", alice, 50)).toBe(true)
			expect(got).toEqual({ { 1, 50 } })
		end)

		it("fireAll() reaches every client, reliable and unreliable", function()
			local env, service, client, as = boot()
			local players = {}
			for userId = 1, 3 do
				table.insert(players, env.mock.players:add({ userId = userId }))
			end
			local states, sounds = {}, {}
			for _, player in players do
				as(player, function()
					client:on("Gameplay.RoundState", function(state, roundId)
						table.insert(states, { player.UserId, state, roundId })
					end)
					client:on("Experience.Sfx", function(sound)
						table.insert(sounds, { player.UserId, sound })
					end)
				end)
			end
			service:fireAll("Gameplay.RoundState", "Countdown", "r7")
			service:fireAll("Experience.Sfx", "bell")
			expect(states).toEqual({ { 1, "Countdown", "r7" }, { 2, "Countdown", "r7" }, { 3, "Countdown", "r7" } })
			expect(sounds).toEqual({ { 1, "bell" }, { 2, "bell" }, { 3, "bell" } })
		end)

		it("fire() to a departed player sends nothing; bad names, kinds and players error", function()
			local env, service = boot()
			local alice = env.mock.players:add({ userId = 1 })
			env.mock.players:remove(alice)
			expect(service:fire("Economy.WalletChanged", alice, 1)).toBe(false)
			expect(#env.mock.remotes:sent("WalletChanged")).toBe(0)
			expect(function()
				service:fire("Economy.Nope", alice)
			end).toThrow("'Economy.Nope' is not declared")
			expect(function()
				service:fireAll("Economy.Nope")
			end).toThrow("'Economy.Nope' is not declared")
			expect(function()
				service:fire("Economy.Equip", alice)
			end).toThrow("kind 'event' (client -> server)")
			expect(function()
				service:fireAll("Economy.BuyItem")
			end).toThrow("kind 'function' (client -> server)")
			expect(function()
				service:fire("Economy.WalletChanged", 1 :: any, 5)
			end).toThrow("player must be a Player")
		end)

		it("never calls InvokeClient", function()
			local env, service, client, as = boot()
			local alice = env.mock.players:add({ userId = 1 })
			service:handle("Gameplay.GetRoundState", function()
				return "Lobby"
			end)
			as(alice, function()
				client:invoke("Gameplay.GetRoundState")
			end)
			service:fireAll("Gameplay.RoundState", "Lobby")
			for _, entry in env.mock.remotes.log do
				expect(entry.direction).never.toBe("invokeClient")
			end
			expect(#env.mock.remotes.log).toBe(2)
		end)
	end)

	describe("destroy", function()
		it("registry:destroy() disconnects every listener and removes ForgeRemotes", function()
			local env, service, client, as, registry = boot()
			local alice = env.mock.players:add({ userId = 1 })
			service:handle("Economy.Equip", function() end)
			as(alice, function()
				client:send("Economy.Equip", "sword")
			end)
			-- engine-side signal objects (MockSignal:connectionCount is mock control API)
			local onEquip = env.ReplicatedStorage.ForgeRemotes.Economy.Equip.OnServerEvent
			local onRoundState = env.ReplicatedStorage.ForgeRemotes.Gameplay.RoundState.OnServerEvent
			expect(onEquip:connectionCount()).toBe(1)
			expect(onRoundState:connectionCount()).toBe(1)
			expect(env.Players.PlayerRemoving:connectionCount()).toBe(1)
			registry:destroy()
			expect(env.ReplicatedStorage:FindFirstChild("ForgeRemotes")).toBeNil()
			expect(onEquip:connectionCount()).toBe(0)
			expect(onRoundState:connectionCount()).toBe(0)
			expect(env.Players.PlayerRemoving:connectionCount()).toBe(0)
			expect(service:stats().buckets).toBe(0)
			expect(env.mock:hasLog("warn", "cleanup failed")).toBe(false)
		end)
	end)
end)
