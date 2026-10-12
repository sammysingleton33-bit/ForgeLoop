local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local RateLimiter = require("@game/ReplicatedStorage/Forge/Core/RateLimiter")

describe("Core/RateLimiter", function()
	local now
	local clock = function()
		return now
	end

	beforeEach(function()
		now = 100
	end)

	it("never denies a call that arrives exactly on schedule (float drift, review follow-up on #4)", function()
		local limiter = RateLimiter.new({ burst = 1, perSecond = 5, clock = clock })
		local denied = 0
		for i = 1, 100000 do
			now = 100 + i * 0.2
			if not limiter:allow("k") then
				denied += 1
			end
		end
		expect(denied).toBe(0)
		now += 0.1
		expect(limiter:allow("k")).toBe(false) -- early calls are still refused
	end)

	it("allows a full burst at once, then rejects", function()
		local limiter = RateLimiter.new({ burst = 3, perSecond = 1, clock = clock })
		expect(limiter:allow("a")).toBe(true)
		expect(limiter:allow("a")).toBe(true)
		expect(limiter:allow("a")).toBe(true)
		expect(limiter:allow("a")).toBe(false)
		expect(limiter:tokens("a")).toBe(0)
	end)

	it("refills continuously with the clock and caps at burst", function()
		local limiter = RateLimiter.new({ burst = 4, perSecond = 2, clock = clock })
		for _ = 1, 4 do
			limiter:allow("a")
		end
		expect(limiter:allow("a")).toBe(false)
		now += 0.25
		expect(limiter:tokens("a")).toBeNear(0.5)
		expect(limiter:allow("a")).toBe(false)
		now += 0.25
		expect(limiter:allow("a")).toBe(true) -- 1 token after 0.5 s at 2/s
		expect(limiter:allow("a")).toBe(false)
		now += 3600
		expect(limiter:tokens("a")).toBe(4) -- capped, not 7200
	end)

	it("a rejected call takes no tokens", function()
		local limiter = RateLimiter.new({ burst = 2, perSecond = 1, clock = clock })
		limiter:allow("a", 2)
		for _ = 1, 10 do
			expect(limiter:allow("a")).toBe(false)
		end
		now += 1
		expect(limiter:allow("a")).toBe(true)
	end)

	it("keeps one bucket per key", function()
		local limiter = RateLimiter.new({ burst = 1, perSecond = 1, clock = clock })
		expect(limiter:allow("a")).toBe(true)
		expect(limiter:allow("a")).toBe(false)
		expect(limiter:allow("b")).toBe(true)
		expect(limiter:tokens("never-seen")).toBe(1)
	end)

	it("supports cost: fractional costs, and a cost above burst never passes", function()
		local limiter = RateLimiter.new({ burst = 2, perSecond = 1, clock = clock })
		expect(limiter:allow("a", 0.5)).toBe(true)
		expect(limiter:tokens("a")).toBeNear(1.5)
		expect(limiter:allow("a", 3)).toBe(false)
		now += 100
		expect(limiter:allow("a", 3)).toBe(false)
		expect(limiter:allow("a", 2)).toBe(true)
	end)

	it("reset(key) frees that key's bucket; reset() frees all", function()
		local limiter = RateLimiter.new({ burst = 1, perSecond = 0, clock = clock })
		limiter:allow("a")
		limiter:allow("b")
		expect(limiter:size()).toBe(2)
		expect(limiter:allow("a")).toBe(false)
		limiter:reset("a")
		expect(limiter:size()).toBe(1)
		expect(limiter:allow("a")).toBe(true) -- a fresh, full bucket
		limiter:reset("missing")
		expect(limiter:size()).toBe(2)
		limiter:reset()
		expect(limiter:size()).toBe(0)
		expect(limiter:tokens("b")).toBe(1)
	end)

	it("perSecond = 0 never refills", function()
		local limiter = RateLimiter.new({ burst = 1, perSecond = 0, clock = clock })
		limiter:allow("a")
		now += 1e6
		expect(limiter:allow("a")).toBe(false)
	end)

	it("a clock that goes backwards refills nothing", function()
		local limiter = RateLimiter.new({ burst = 2, perSecond = 1, clock = clock })
		limiter:allow("a")
		limiter:allow("a")
		now -= 50
		expect(limiter:allow("a")).toBe(false)
		now += 50.5 -- back to 0.5 s after the last call
		expect(limiter:tokens("a")).toBeNear(0.5)
	end)

	it("works with env.clock and virtual time", function()
		local env = MockEnv.new()
		local limiter = RateLimiter.new({ burst = 2, perSecond = 5, clock = env.clock })
		expect(limiter:allow(1)).toBe(true)
		expect(limiter:allow(1)).toBe(true)
		expect(limiter:allow(1)).toBe(false)
		env.mock:advance(0.2)
		expect(limiter:allow(1)).toBe(true)
		expect(limiter:allow(1)).toBe(false)
	end)

	it("rejects bad options, nil/NaN keys and bad costs", function()
		expect(function()
			RateLimiter.new({ burst = 0, perSecond = 1, clock = clock })
		end).toThrow("burst")
		expect(function()
			RateLimiter.new({ burst = 1, perSecond = 0 / 0, clock = clock })
		end).toThrow("perSecond")
		expect(function()
			RateLimiter.new({ burst = 1, perSecond = 1 } :: any)
		end).toThrow("clock")
		local limiter = RateLimiter.new({ burst = 1, perSecond = 1, clock = clock })
		expect(function()
			limiter:allow(nil)
		end).toThrow("key")
		expect(function()
			limiter:allow(0 / 0)
		end).toThrow("key")
		expect(function()
			limiter:allow("a", -1)
		end).toThrow("cost")
		expect(function()
			limiter:allow("a", math.huge)
		end).toThrow("cost")
	end)
end)
