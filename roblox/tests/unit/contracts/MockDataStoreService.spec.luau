local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockDataStoreService = require("../../mocks/MockDataStoreService")
local MockEnv = require("../../mocks/MockEnv")

local RT = Enum.DataStoreRequestType

describe("MockDataStoreService", function()
	it("Get/Set/Remove round-trip and return fresh copies", function()
		local store = MockDataStoreService.new():GetDataStore("Profiles")
		expect(store:GetAsync("u_1")).toBeNil()
		local version = store:SetAsync("u_1", { coins = 5, items = { "a" } }, { 1 })
		expect(type(version)).toBe("string")
		local value, info = store:GetAsync("u_1")
		expect(value).toEqual({ coins = 5, items = { "a" } })
		expect(info.Version).toBe(version)
		expect(info:GetUserIds()).toEqual({ 1 })
		value.coins = 999
		expect(store:GetAsync("u_1").coins).toBe(5)
		local old = store:RemoveAsync("u_1")
		expect(old.coins).toBe(5)
		expect(store:GetAsync("u_1")).toBeNil()
	end)

	describe("UpdateAsync", function()
		it("passes the current value and key info, writes the returned value", function()
			local store = MockDataStoreService.new():GetDataStore("Profiles")
			store:SetAsync("u_1", { coins = 1 })
			local sawInfo
			local newValue = store:UpdateAsync("u_1", function(current, info)
				sawInfo = info
				current.coins += 1
				return current
			end)
			expect(newValue).toEqual({ coins = 2 })
			expect(sawInfo.Version ~= nil).toBe(true)
			expect(store:GetAsync("u_1")).toEqual({ coins = 2 })
		end)

		it("returning nil cancels: nothing is written and nil is returned; both budgets are still spent", function()
			-- error-codes-and-limits.md: "UpdateAsync consumes from both the read and write request
			-- budgets. A single call will decrement both limits." The legacy SetIncrementAsync item is
			-- spent only "when it returns a non-nil value" (DataStoreRequestType.yaml).
			local dss = MockDataStoreService.new()
			local store = dss:GetDataStore("Profiles")
			store:SetAsync("u_1", { coins = 1 })
			local writesBefore = dss:GetRequestBudgetForRequestType(RT.StandardWrite)
			local readsBefore = dss:GetRequestBudgetForRequestType(RT.StandardRead)
			local legacyBefore = dss:GetRequestBudgetForRequestType(RT.SetIncrementAsync)
			local result = store:UpdateAsync("u_1", function()
				return nil
			end)
			expect(result).toBeNil()
			expect(store:GetAsync("u_1")).toEqual({ coins = 1 })
			expect(dss:GetRequestBudgetForRequestType(RT.StandardWrite)).toBe(writesBefore - 1)
			expect(dss:GetRequestBudgetForRequestType(RT.StandardRead)).toBe(readsBefore - 2) -- update + get
			expect(dss:GetRequestBudgetForRequestType(RT.SetIncrementAsync)).toBe(legacyBefore)
		end)

		it("re-runs the transform when another server wrote between read and commit", function()
			local dss = MockDataStoreService.new()
			local store = dss:GetDataStore("Profiles")
			store:SetAsync("u_1", { lock = "none" })
			dss:interleaveNextUpdate("Profiles", "u_1", function(write)
				write({ lock = "server-B" })
			end)
			local seen = {}
			local result = store:UpdateAsync("u_1", function(current)
				table.insert(seen, current.lock)
				if current.lock ~= "none" then
					return nil -- someone else holds the lock: cancel
				end
				return { lock = "server-A" }
			end)
			expect(seen).toEqual({ "none", "server-B" })
			expect(result).toBeNil()
			expect(dss:peek("Profiles", "u_1")).toEqual({ lock = "server-B" })
		end)

		it("rejects a transform that yields and propagates a transform error", function()
			local store = MockDataStoreService.new():GetDataStore("Profiles")
			expect(function()
				store:UpdateAsync("u_1", function()
					coroutine.yield()
					return 1
				end)
			end).toThrow("must not yield")
			expect(function()
				store:UpdateAsync("u_1", function()
					error("migration bug")
				end)
			end).toThrow("migration bug")
		end)
	end)

	describe("failure injection", function()
		it("failNext(method, count) fails exactly that many calls of that method", function()
			local dss = MockDataStoreService.new()
			local store = dss:GetDataStore("Profiles")
			dss:failNext("UpdateAsync", 2)
			for _ = 1, 2 do
				expect(function()
					store:UpdateAsync("u_1", function()
						return 1
					end)
				end).toThrow("502")
			end
			expect(store:UpdateAsync("u_1", function()
				return 1
			end)).toBe(1)
			expect(store:GetAsync("u_1")).toBe(1)
		end)

		it("afterCommit failures write but still throw (unknown write state)", function()
			local dss = MockDataStoreService.new()
			local store = dss:GetDataStore("Profiles")
			dss:failNext(
				"SetAsync",
				1,
				{ afterCommit = true, message = "503: Data store request was successful but key wasn't found." }
			)
			expect(function()
				store:SetAsync("u_1", "written")
			end).toThrow("503")
			expect(store:GetAsync("u_1")).toBe("written")
		end)

		it("failures can target one store and the wildcard method", function()
			local dss = MockDataStoreService.new()
			dss:failNext("*", 1, { store = "Other" })
			expect(dss:GetDataStore("Profiles"):GetAsync("k")).toBeNil()
			expect(function()
				dss:GetDataStore("Other"):GetAsync("k")
			end).toThrow("502")
		end)
	end)

	describe("request budgets", function()
		it("GetRequestBudgetForRequestType reflects spending and setBudget", function()
			local dss = MockDataStoreService.new({ budget = 10 })
			local store = dss:GetDataStore("Profiles")
			expect(dss:GetRequestBudgetForRequestType(RT.StandardRead)).toBe(10)
			store:GetAsync("k")
			expect(dss:GetRequestBudgetForRequestType(RT.StandardRead)).toBe(9)
			expect(dss:GetRequestBudgetForRequestType(RT.GetAsync)).toBe(9)
			store:UpdateAsync("k", function()
				return 1
			end)
			expect(dss:GetRequestBudgetForRequestType(RT.StandardWrite)).toBe(9)
			expect(dss:GetRequestBudgetForRequestType(RT.UpdateAsync)).toBe(9)
		end)

		it("an exhausted budget throttles with the documented 30x error", function()
			local dss = MockDataStoreService.new()
			dss:setBudget(RT.StandardWrite, 0)
			local store = dss:GetDataStore("Profiles")
			expect(function()
				store:SetAsync("k", 1)
			end).toThrow("302: SetAsync request dropped")
			expect(function()
				store:UpdateAsync("k", function()
					return 1
				end)
			end).toThrow("304: UpdateAsync request dropped")
			dss:setBudget(RT.StandardRead, 0)
			expect(function()
				store:GetAsync("k")
			end).toThrow("301: GetAsync request dropped")
		end)
	end)

	describe("request budgets on the MockEnv clock", function()
		it("refill per virtual minute at 60 + 40 x players, up to one minute's worth", function()
			local env = MockEnv.new()
			local dss = env.DataStoreService
			dss:setBudget(RT.StandardWrite, 0)
			env.mock:advance(30)
			expect(dss:GetRequestBudgetForRequestType(RT.StandardWrite)).toBe(30) -- 0 players: 60/min
			env.mock:advance(600)
			expect(dss:GetRequestBudgetForRequestType(RT.StandardWrite)).toBe(60) -- capped at 1 minute
			env.mock.players:add({ userId = 1 })
			env.mock.players:add({ userId = 2 })
			dss:setBudget(RT.StandardRead, 0)
			env.mock:advance(15)
			expect(dss:GetRequestBudgetForRequestType(RT.StandardRead)).toBe(35) -- (60 + 80) / 4
		end)

		it("a throttled server recovers once the budget refills", function()
			local env = MockEnv.new()
			local store = env.DataStoreService:GetDataStore("Profiles")
			env.DataStoreService:setBudget(RT.StandardWrite, 0)
			expect(function()
				store:SetAsync("k", 1)
			end).toThrow("302")
			env.mock:advance(2)
			store:SetAsync("k", 2)
			expect(store:GetAsync("k")).toBe(2)
		end)

		it("the startup burst (default 1000) is not refilled once spent below the per-minute cap", function()
			local env = MockEnv.new()
			local dss = env.DataStoreService
			expect(dss:GetRequestBudgetForRequestType(RT.StandardRead)).toBe(1000)
			env.mock:advance(60)
			expect(dss:GetRequestBudgetForRequestType(RT.StandardRead)).toBe(1000)
		end)
	end)

	it("every request yields at least one frame in a scheduled thread (latency 0)", function()
		local env = MockEnv.new()
		local store = env.DataStoreService:GetDataStore("Profiles")
		local done = false
		env.spawn(function()
			store:GetAsync("k")
			done = true
		end)
		expect(done).toBe(false)
		env.mock:advance(MockEnv.FRAME)
		expect(done).toBe(true)
	end)

	describe("data limits", function()
		it("rejects values over 4,194,304 characters with 105", function()
			local store = MockDataStoreService.new():GetDataStore("Profiles")
			store:SetAsync("fits", string.rep("a", 4194302)) -- 2 quote characters make it 4,194,304
			expect(function()
				store:SetAsync("big", string.rep("a", 4194303))
			end).toThrow("105: Serialized value exceeds 4MB limit")
		end)

		it("rejects unstorable values with 103/104", function()
			local store = MockDataStoreService.new():GetDataStore("Profiles")
			expect(function()
				store:SetAsync("k", { fn = function() end })
			end).toThrow("104")
			expect(function()
				-- selene: allow(mixed_table)
				store:SetAsync("k", { 1, 2, x = 3 })
			end).toThrow("104")
			expect(function()
				store:SetAsync("k", "\255\254")
			end).toThrow("valid UTF-8")
			expect(function()
				store:SetAsync("k", setmetatable({}, {}))
			end).toThrow("103")
			expect(function()
				store:SetAsync("k", 0 / 0)
			end).toThrow("104")
		end)

		it("validates key names (101 empty, 102 over 50 characters)", function()
			local store = MockDataStoreService.new():GetDataStore("Profiles")
			expect(function()
				store:GetAsync("")
			end).toThrow("101")
			expect(function()
				store:GetAsync(string.rep("k", 51))
			end).toThrow("102")
		end)

		it("IncrementAsync adds integers and rejects non-integers", function()
			local store = MockDataStoreService.new():GetDataStore("Stats")
			expect(store:IncrementAsync("visits")).toBe(1)
			expect(store:IncrementAsync("visits", 5)).toBe(6)
			expect(function()
				store:IncrementAsync("visits", 0.5)
			end).toThrow("integer")
		end)
	end)

	it("latency runs on the MockEnv clock: a load in env.spawn finishes only after advance()", function()
		local env = MockEnv.new()
		env.DataStoreService:setLatency(2)
		local store = env.DataStoreService:GetDataStore("Profiles")
		local loaded = nil
		env.spawn(function()
			loaded = store:GetAsync("u_1") or "default"
		end)
		expect(loaded).toBeNil()
		env.mock:advance(1.9)
		expect(loaded).toBeNil()
		env.mock:advance(0.1)
		expect(loaded).toBe("default")
	end)

	it("records every request in order", function()
		local dss = MockDataStoreService.new()
		local store = dss:GetDataStore("Profiles")
		store:GetAsync("a")
		store:SetAsync("b", 1)
		expect(dss:requests()).toEqual({
			{ method = "GetAsync", store = "Profiles", key = "a" },
			{ method = "SetAsync", store = "Profiles", key = "b" },
		})
	end)
end)
