local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")
local RemoteClient = require("@game/ReplicatedStorage/Forge/Core/RemoteClient")

-- Builds ReplicatedStorage.ForgeRemotes.<Area>.<Action> like RemoteService does.
local function makeRemote(env, area, action, className)
	local root = env.ReplicatedStorage:FindFirstChild("ForgeRemotes")
	if root == nil then
		root = env.newInstance("Folder")
		root.Name = "ForgeRemotes"
		root.Parent = env.ReplicatedStorage
	end
	local folder = root:FindFirstChild(area)
	if folder == nil then
		folder = env.newInstance("Folder")
		folder.Name = area
		folder.Parent = root
	end
	local remote = env.newInstance(className)
	remote.Name = action
	remote.Parent = folder
	return remote
end

describe("Core/RemoteClient", function()
	it("invoke() calls the RemoteFunction and returns the server's results", function()
		local env = MockEnv.new({ localPlayer = { userId = 11 } })
		local fn = makeRemote(env, "Gameplay", "GetRoundState", "RemoteFunction")
		fn.OnServerInvoke = function(player, detail)
			return { state = "Lobby", asker = player.UserId, detail = detail }, 2
		end
		local client = RemoteClient.new(env)
		local snapshot, extra = client:invoke("Gameplay.GetRoundState", "full")
		expect(snapshot).toEqual({ state = "Lobby", asker = 11, detail = "full" })
		expect(extra).toBe(2)
	end)

	it("send() fires the RemoteEvent as the local player", function()
		local env = MockEnv.new({ localPlayer = { userId = 12 } })
		local event = makeRemote(env, "Economy", "Equip", "RemoteEvent")
		local got
		event.OnServerEvent:Connect(function(player, itemId)
			got = { player.UserId, itemId }
		end)
		RemoteClient.new(env):send("Economy.Equip", "sword")
		expect(got).toEqual({ 12, "sword" })
	end)

	it("on() receives server events; the connection disconnects", function()
		local env = MockEnv.new({ localPlayer = { userId = 13 } })
		local event = makeRemote(env, "Gameplay", "RoundState", "RemoteEvent")
		local got = {}
		local connection = RemoteClient.new(env):on("Gameplay.RoundState", function(state, roundId)
			table.insert(got, { state, roundId })
		end)
		event:FireAllClients("Countdown", "r1")
		connection:Disconnect()
		event:FireAllClients("Active", "r1")
		expect(got).toEqual({ { "Countdown", "r1" } })
	end)

	it("separate clients act as their own player (asClient)", function()
		local env = MockEnv.new()
		local event = makeRemote(env, "Economy", "Equip", "RemoteEvent")
		local alice = env.mock.players:add({ userId = 1 })
		local bob = env.mock.players:add({ userId = 2 })
		local senders = {}
		event.OnServerEvent:Connect(function(player)
			table.insert(senders, player.UserId)
		end)
		local client = RemoteClient.new(env)
		env.mock.remotes:asClient(bob, function()
			client:send("Economy.Equip")
		end)
		env.mock.remotes:asClient(alice, function()
			client:send("Economy.Equip")
		end)
		expect(senders).toEqual({ 2, 1 })
	end)

	it("waits for a remote that replicates later", function()
		local env = MockEnv.new({ localPlayer = { userId = 14 } })
		local client = RemoteClient.new(env)
		local result
		env.spawn(function()
			result = client:invoke("Gameplay.Late")
		end)
		env.mock:advance(2)
		expect(result).toBeNil()
		local fn = makeRemote(env, "Gameplay", "Late", "RemoteFunction")
		fn.OnServerInvoke = function()
			return "arrived"
		end
		env.mock:advance(0.1)
		expect(result).toBe("arrived")
	end)

	it("errors with the name after the timeout (default 10 s) when the remote never appears", function()
		local env = MockEnv.new({ localPlayer = { userId = 15 } })
		makeRemote(env, "Gameplay", "Other", "RemoteEvent")
		local client = RemoteClient.new(env)
		local started = env.clock()
		expect(function()
			client:send("Gameplay.Missing", 1)
		end).toThrow("remote 'Gameplay.Missing' not found after 10 s")
		expect(env.clock() - started).toBeNear(10, 0.05)
	end)

	it("the timeout is shared across the path and configurable", function()
		local env = MockEnv.new({ localPlayer = { userId = 16 } })
		local client = RemoteClient.new(env, { timeout = 3 })
		local started = env.clock()
		expect(function()
			client:invoke("Economy.BuyItem")
		end).toThrow("not found after 3 s")
		expect(env.clock() - started).toBeLessThan(3.1)
	end)

	it("a timeout inside a scheduled thread errors that thread only after virtual time passes", function()
		local env = MockEnv.new({ localPlayer = { userId = 17 } })
		local client = RemoteClient.new(env, { timeout = 1 })
		local outcome
		env.spawn(function()
			local ok, err = pcall(function()
				client:send("Debug.Nothing")
			end)
			outcome = { ok, err }
		end)
		env.mock:advance(0.5)
		expect(outcome).toBeNil()
		env.mock:advance(1)
		expect(outcome[1]).toBe(false)
		expect(tostring(outcome[2])).toContain("Debug.Nothing")
	end)

	it("checks the remote's class for each call", function()
		local env = MockEnv.new({ localPlayer = { userId = 18 } })
		makeRemote(env, "Gameplay", "Event", "RemoteEvent")
		makeRemote(env, "Gameplay", "Func", "RemoteFunction")
		local client = RemoteClient.new(env)
		expect(function()
			client:invoke("Gameplay.Event")
		end).toThrow("invoke needs RemoteFunction")
		expect(function()
			client:send("Gameplay.Func")
		end).toThrow("send needs RemoteEvent or UnreliableRemoteEvent")
		expect(function()
			client:on("Gameplay.Func", function() end)
		end).toThrow("on needs RemoteEvent")
	end)

	it("rejects malformed names", function()
		local env = MockEnv.new({ localPlayer = { userId = 19 } })
		local client = RemoteClient.new(env)
		expect(function()
			client:send("NoDot")
		end).toThrow('must be "<Area>.<Action>"')
		expect(function()
			client:send("A.B.C")
		end).toThrow('must be "<Area>.<Action>"')
		expect(function()
			client:send(5 :: any)
		end).toThrow("must be a string")
	end)

	it("module-level invoke/send/on need init(env) and then use that client", function()
		expect(function()
			RemoteClient.send("Gameplay.X")
		end).toThrow("RemoteClient.init(env)")
		local env = MockEnv.new({ localPlayer = { userId = 20 } })
		local event = makeRemote(env, "Gameplay", "Ping", "RemoteEvent")
		local fn = makeRemote(env, "Gameplay", "Echo", "RemoteFunction")
		fn.OnServerInvoke = function(_, value)
			return value
		end
		local received = {}
		event.OnServerEvent:Connect(function(_, value)
			table.insert(received, value)
		end)
		RemoteClient.init(env)
		RemoteClient.send("Gameplay.Ping", "hi")
		expect(RemoteClient.invoke("Gameplay.Echo", 42)).toBe(42)
		local heard
		RemoteClient.on("Gameplay.Ping", function(value)
			heard = value
		end)
		event:FireAllClients("back")
		expect(received).toEqual({ "hi" })
		expect(heard).toBe("back")
	end)

	it("re-resolves a cached remote that left the tree", function()
		local env = MockEnv.new({ localPlayer = { userId = 21 } })
		local first = makeRemote(env, "Gameplay", "Swap", "RemoteFunction")
		first.OnServerInvoke = function()
			return "first"
		end
		local client = RemoteClient.new(env)
		expect(client:invoke("Gameplay.Swap")).toBe("first")
		first:Destroy()
		local second = makeRemote(env, "Gameplay", "Swap", "RemoteFunction")
		second.OnServerInvoke = function()
			return "second"
		end
		expect(client:invoke("Gameplay.Swap")).toBe("second")
	end)
end)
