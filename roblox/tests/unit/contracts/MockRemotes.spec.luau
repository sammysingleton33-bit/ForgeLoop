local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")

local function setup()
	local env = MockEnv.new()
	local folder = env.newInstance("Folder")
	folder.Name = "ForgeRemotes"
	folder.Parent = env.ReplicatedStorage
	local function remote(className, name)
		local r = env.newInstance(className)
		r.Name = name
		r.Parent = folder
		return r
	end
	return env, remote
end

describe("MockRemotes", function()
	describe("RemoteEvent", function()
		it("server FireClient reaches that player's client OnClientEvent with copied arguments", function()
			local env, remote = setup()
			local event = remote("RemoteEvent", "Economy.WalletChanged")
			local alice = env.mock.players:add({ userId = 1 })
			local bob = env.mock.players:add({ userId = 2 })
			local payload = { coins = 5 }
			local aliceGot, bobGot
			env.mock.remotes:asClient(alice, function()
				event.OnClientEvent:Connect(function(data)
					aliceGot = data
				end)
			end)
			env.mock.remotes:asClient(bob, function()
				event.OnClientEvent:Connect(function(data)
					bobGot = data
				end)
			end)
			event:FireClient(alice, payload)
			expect(aliceGot).toEqual({ coins = 5 })
			expect(rawequal(aliceGot, payload)).toBe(false)
			expect(bobGot).toBeNil()
			expect(#env.mock.remotes:sent("Economy.WalletChanged", "toClient")).toBe(1)
		end)

		it("FireAllClients reaches every player; events fired before a listener connects are queued", function()
			local env, remote = setup()
			local event = remote("RemoteEvent", "Gameplay.RoundState")
			local alice = env.mock.players:add({ userId = 1 })
			local bob = env.mock.players:add({ userId = 2 })
			event:FireAllClients("Countdown", "r1", 10, 2)
			local got = {}
			for _, player in { alice, bob } do
				env.mock.remotes:asClient(player, function()
					event.OnClientEvent:Connect(function(state, roundId)
						table.insert(got, { player.UserId, state, roundId })
					end)
				end)
			end
			expect(got).toEqual({ { 1, "Countdown", "r1" }, { 2, "Countdown", "r1" } })
		end)

		it("client FireServer arrives as OnServerEvent(player, ...)", function()
			local env, remote = setup()
			local event = remote("RemoteEvent", "Experience.Ack")
			local alice = env.mock.players:add({ userId = 1 })
			local got
			event.OnServerEvent:Connect(function(player, a, b)
				got = { player.UserId, a, b }
			end)
			env.mock.remotes:asClient(alice, function()
				event:FireServer("x", 2)
			end)
			expect(got).toEqual({ 1, "x", 2 })
		end)

		it("copies arguments like Roblox: functions -> nil, non-string keys -> strings, Instances kept", function()
			local env, remote = setup()
			local event = remote("RemoteEvent", "Debug.Echo")
			local alice = env.mock.players:add({ userId = 1 })
			local got
			event.OnServerEvent:Connect(function(_, fn, dict, instance, list)
				got = { fn = fn, dict = dict, instance = instance, list = list }
			end)
			local part = Instance.new("Part")
			env.mock.remotes:asClient(alice, function()
				event:FireServer(function() end, { [10] = "ten", name = "n" }, part, { "a", "b" })
			end)
			expect(got.fn).toBeNil()
			expect(got.dict).toEqual({ ["10"] = "ten", name = "n" })
			expect(got.instance == part).toBe(true)
			expect(got.list).toEqual({ "a", "b" })
		end)

		it("client members need a client context", function()
			local _, remote = setup()
			local event = remote("RemoteEvent", "Gameplay.X")
			expect(function()
				event:FireServer(1)
			end).toThrow("needs a client context")
		end)
	end)

	describe("RemoteFunction", function()
		it("InvokeServer returns the server's results; server errors propagate to the client", function()
			local env, remote = setup()
			local fn = remote("RemoteFunction", "Gameplay.GetRoundState")
			local alice = env.mock.players:add({ userId = 1 })
			fn.OnServerInvoke = function(player, detail)
				if detail == "boom" then
					error("server handler failed")
				end
				return { state = "Lobby", asker = player.UserId }
			end
			local result
			env.mock.remotes:asClient(alice, function()
				result = fn:InvokeServer()
			end)
			expect(result).toEqual({ state = "Lobby", asker = 1 })
			expect(function()
				env.mock.remotes:asClient(alice, function()
					fn:InvokeServer("boom")
				end)
			end).toThrow("server handler failed")
		end)

		it("InvokeServer without OnServerInvoke is an error (Roblox would yield forever)", function()
			local env, remote = setup()
			local fn = remote("RemoteFunction", "Economy.BuyItem")
			local alice = env.mock.players:add({ userId = 1 })
			expect(function()
				env.mock.remotes:asClient(alice, function()
					fn:InvokeServer()
				end)
			end).toThrow("OnServerInvoke is not set")
		end)

		it("InvokeClient calls that client's OnClientInvoke", function()
			local env, remote = setup()
			local fn = remote("RemoteFunction", "Debug.Ping")
			local alice = env.mock.players:add({ userId = 1 })
			env.mock.remotes:asClient(alice, function()
				fn.OnClientInvoke = function(n)
					return n + 1
				end
			end)
			expect(fn:InvokeClient(alice, 41)).toBe(42)
		end)
	end)

	describe("UnreliableRemoteEvent", function()
		it("drops payloads over 1000 bytes and on dropNext; never queues", function()
			local env, remote = setup()
			local sfx = remote("UnreliableRemoteEvent", "Experience.Sfx")
			local alice = env.mock.players:add({ userId = 1 })
			sfx:FireClient(alice, "queued?") -- no listener yet: discarded
			local got = {}
			env.mock.remotes:asClient(alice, function()
				sfx.OnClientEvent:Connect(function(v)
					table.insert(got, v)
				end)
			end)
			sfx:FireClient(alice, "small")
			sfx:FireClient(alice, string.rep("x", 1200))
			env.mock.remotes:dropNext(sfx)
			sfx:FireClient(alice, "lost")
			sfx:FireClient(alice, "last")
			expect(got).toEqual({ "small", "last" })
			local log = env.mock.remotes:sent(sfx)
			expect(#log).toBe(5)
			expect(log[3].dropped).toBe(true)
			expect(log[4].dropped).toBe(true)
		end)

		it("measures buffers by buffer.len: 1000 bytes are delivered, 1001 are dropped (FL-0067)", function()
			local env, remote = setup()
			local snapshot = remote("UnreliableRemoteEvent", "Sim.Snapshot")
			local alice = env.mock.players:add({ userId = 1 })
			local sizes = {}
			env.mock.remotes:asClient(alice, function()
				snapshot.OnClientEvent:Connect(function(b)
					table.insert(sizes, buffer.len(b))
				end)
			end)
			snapshot:FireClient(alice, buffer.create(1000))
			snapshot:FireClient(alice, buffer.create(1001))
			snapshot:FireAllClients(buffer.create(1001))
			expect(sizes).toEqual({ 1000 })
			local log = env.mock.remotes:sent(snapshot)
			expect(log[2].dropped).toBe(true)
			expect(log[3].dropped).toBe(true)
		end)

		it("copies buffers: a server write after FireClient is not visible to the client (FL-0067)", function()
			local env, remote = setup()
			local snapshot = remote("UnreliableRemoteEvent", "Sim.Snapshot")
			local alice = env.mock.players:add({ userId = 1 })
			local received
			env.mock.remotes:asClient(alice, function()
				snapshot.OnClientEvent:Connect(function(b)
					received = b
				end)
			end)
			local b = buffer.create(4)
			buffer.writeu32(b, 0, 7)
			snapshot:FireClient(alice, b)
			buffer.writeu32(b, 0, 99)
			expect(buffer.readu32(received, 0)).toBe(7)
			expect(rawequal(received, b)).toBe(false)
		end)

		it("holds and releases payloads to model delay and reordering (FL-0067)", function()
			local env, remote = setup()
			local snapshot = remote("UnreliableRemoteEvent", "Sim.Snapshot")
			local alice = env.mock.players:add({ userId = 1 })
			local seqs = {}
			env.mock.remotes:asClient(alice, function()
				snapshot.OnClientEvent:Connect(function(seq)
					table.insert(seqs, seq)
				end)
			end)
			local network = env.mock.remotes
			network:holdUnreliable(snapshot)
			snapshot:FireClient(alice, 1)
			snapshot:FireAllClients(2)
			snapshot:FireClient(alice, 3)
			expect(seqs).toEqual({}) -- delayed
			expect(network:heldCount(snapshot)).toBe(3)
			expect(network:releaseUnreliable(snapshot, { 3, 1, 2 })).toBe(3)
			expect(seqs).toEqual({ 3, 1, 2 })
			snapshot:FireClient(alice, 4) -- released: delivery is immediate again
			expect(seqs).toEqual({ 3, 1, 2, 4 })
			network:holdUnreliable(snapshot)
			snapshot:FireClient(alice, 5)
			snapshot:FireClient(alice, 6)
			network:releaseUnreliable(snapshot, "reverse")
			expect(seqs).toEqual({ 3, 1, 2, 4, 6, 5 })
			expect(function()
				network:holdUnreliable(remote("RemoteEvent", "Kingdom.Reliable"))
			end).toThrow("only applies to UnreliableRemoteEvent")
			network:holdUnreliable(snapshot)
			snapshot:FireClient(alice, 7)
			expect(function()
				network:releaseUnreliable(snapshot, { 1, 1 })
			end).toThrow("order has 2 entries")
		end)

		it("holds client -> server payloads too", function()
			local env, remote = setup()
			local ping = remote("UnreliableRemoteEvent", "Sim.Ping")
			local alice = env.mock.players:add({ userId = 1 })
			local got = {}
			ping.OnServerEvent:Connect(function(player, n)
				table.insert(got, player.UserId * 100 + n)
			end)
			env.mock.remotes:holdUnreliable(ping)
			env.mock.remotes:asClient(alice, function()
				ping:FireServer(1)
				ping:FireServer(2)
			end)
			expect(got).toEqual({})
			env.mock.remotes:releaseUnreliable(ping, "reverse")
			expect(got).toEqual({ 102, 101 })
		end)
	end)

	it("remotes not created through env.newInstance are rejected", function()
		local stray = Instance.new("RemoteEvent")
		expect(function()
			return stray.OnServerEvent
		end).toThrow("was not created through env.newInstance")
	end)
end)
