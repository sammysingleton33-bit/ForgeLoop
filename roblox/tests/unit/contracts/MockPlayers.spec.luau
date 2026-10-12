local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")

describe("MockPlayers (via MockEnv)", function()
	it("add() parents a real Player and fires PlayerAdded", function()
		local env = MockEnv.new()
		local added = {}
		env.Players.PlayerAdded:Connect(function(player)
			table.insert(added, player)
		end)
		local alice = env.mock.players:add({ userId = 1, name = "Alice" })
		expect(typeof(alice)).toBe("Instance")
		expect(alice:IsA("Player")).toBe(true)
		expect(alice.UserId).toBe(1)
		expect(alice.Parent == env.Players).toBe(true)
		expect(added[1] == alice).toBe(true)
		expect(#env.Players:GetPlayers()).toBe(1)
		expect(env.Players:GetPlayerByUserId(1) == alice).toBe(true)
		expect(env.Players:GetPlayerByUserId(2)).toBeNil()
	end)

	it("remove() fires PlayerRemoving while Parent is still Players, then clears Parent", function()
		local env = MockEnv.new()
		local parentDuringRemoving
		env.Players.PlayerRemoving:Connect(function(player)
			parentDuringRemoving = player.Parent
		end)
		local bob = env.mock.players:add({ userId = 2 })
		env.mock.players:remove(bob)
		expect(parentDuringRemoving == env.Players).toBe(true)
		expect(bob.Parent).toBeNil()
		expect(#env.Players:GetPlayers()).toBe(0)
	end)

	it("Kick() is recorded and the player is removed on the next scheduler step", function()
		local env = MockEnv.new()
		local removed = false
		env.Players.PlayerRemoving:Connect(function()
			removed = true
		end)
		local carol = env.mock.players:add({ userId = 3 })
		carol:Kick("Your data is newer than this server")
		local kicked, message = env.mock.players:wasKicked(carol)
		expect(kicked).toBe(true)
		expect(message).toBe("Your data is newer than this server")
		expect(removed).toBe(false)
		env.mock:advance(0)
		expect(removed).toBe(true)
		expect(carol.Parent).toBeNil()
	end)

	it("a player who leaves during an async load is visible to the loader (Parent == nil)", function()
		local env = MockEnv.new()
		env.DataStoreService:setLatency(3)
		local store = env.DataStoreService:GetDataStore("Profiles")
		local outcome
		env.Players.PlayerAdded:Connect(function(player)
			store:GetAsync("u_" .. player.UserId) -- yields 3 virtual seconds
			outcome = if player.Parent == nil then "left during load" else "still here"
		end)
		local dave = env.mock.players:add({ userId = 4 })
		env.mock:advance(1)
		env.mock.players:remove(dave)
		expect(outcome).toBeNil()
		env.mock:advance(2)
		expect(outcome).toBe("left during load")
	end)

	it("adding the same UserId twice is an error", function()
		local env = MockEnv.new()
		env.mock.players:add({ userId = 5 })
		expect(function()
			env.mock.players:add({ userId = 5 })
		end).toThrow("already in game")
	end)
end)
