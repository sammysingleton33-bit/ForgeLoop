-- Self-test of the harness: every matcher passes when it should and fails (with a useful
-- message) when it should not. A harness that cannot fail would make every other spec meaningless.
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockRandom = require("../../mocks/MockRandom")

local function failureOf(fn): string?
	local ok, err = pcall(fn)
	if ok then
		return nil
	end
	return tostring(err)
end

local function expectFailure(fn, fragment: string)
	local message = failureOf(fn)
	expect(message ~= nil).toBe(true)
	expect(message).toContain("Expectation failed")
	expect(message).toContain(fragment)
	expect(message).toContain("Harness.spec.luau:") -- points at the failing line
end

describe("harness matchers", function()
	it("toBe compares with == and treats NaN as equal to NaN", function()
		expect(1).toBe(1)
		expect(0 / 0).toBe(0 / 0)
		expectFailure(function()
			expect(1).toBe(2)
		end, "expected 1 to be 2")
		expectFailure(function()
			expect({}).toBe({})
		end, "to be {}")
	end)

	it("toEqual compares deeply and names the first differing path", function()
		expect({ a = { b = { 1, 2 } } }).toEqual({ a = { b = { 1, 2 } } })
		expectFailure(function()
			expect({ a = { b = { 1, 2 } } }).toEqual({ a = { b = { 1, 3 } } })
		end, "value.a.b.2")
		expectFailure(function()
			expect({ a = 1, extra = true }).toEqual({ a = 1 })
		end, "unexpected key")
	end)

	it("toBeNear uses a tolerance", function()
		expect(0.1 + 0.2).toBeNear(0.3)
		expect(10).toBeNear(10.4, 0.5)
		expectFailure(function()
			expect(10).toBeNear(11, 0.5)
		end, "within 0.5 of 11")
	end)

	it("toThrow checks that a function errors, optionally with a substring", function()
		expect(function()
			error("kaboom happened")
		end).toThrow("kaboom")
		expectFailure(function()
			expect(function() end).toThrow()
		end, "to throw")
		expectFailure(function()
			expect(function()
				error("other")
			end).toThrow("kaboom")
		end, "it threw")
	end)

	it("toBeNil / toBeTruthy / toBeFalsy / toContain / toHaveLength / comparisons / toBeA", function()
		expect(nil).toBeNil()
		expect(0).toBeTruthy()
		expect(false).toBeFalsy()
		expect({ 1, 2, 3 }).toContain(2)
		expect("hello world").toContain("o w")
		expect({ 1, 2 }).toHaveLength(2)
		expect(3).toBeGreaterThan(2)
		expect(3).toBeLessThanOrEqual(3)
		expect("s").toBeA("string")
		expectFailure(function()
			expect(1).toBeNil()
		end, "to be nil")
		expectFailure(function()
			expect({ 1 }).toContain(5)
		end, "to contain 5")
		expectFailure(function()
			expect(2).toBeGreaterThan(3)
		end, "greater than 3")
	end)

	it(".never inverts every matcher", function()
		expect(1).never.toBe(2)
		expect({ a = 1 }).never.toEqual({ a = 2 })
		expect(function() end).never.toThrow()
		expect(5).never.toBeNil()
		expectFailure(function()
			expect(1).never.toBe(1)
		end, "not to be 1")
		expectFailure(function()
			expect(function()
				error("x")
			end).never.toThrow()
		end, "not to throw")
	end)
end)

describe("MockRandom (the harness's Random)", function()
	it("is deterministic per seed and stays inside the documented ranges", function()
		local a, b = MockRandom.new(123), MockRandom.new(123.9) -- seeds are floored
		for _ = 1, 200 do
			local x = a:NextInteger(-3, 3)
			expect(x).toBe(b:NextInteger(-3, 3))
			expect(x >= -3 and x <= 3).toBe(true)
			local n = a:NextNumber(5, 6)
			expect(n).toBe(b:NextNumber(5, 6))
			expect(n >= 5 and n < 6).toBe(true)
		end
		expect(MockRandom.new(1):NextInteger(1, 10)).toBe(MockRandom.new(1):NextInteger(1, 10))
		expect(MockRandom.new(9):NextInteger(10, 1) >= 1).toBe(true) -- min > max is swapped
	end)

	it("Clone continues the same stream; Shuffle permutes", function()
		local r = MockRandom.new(5)
		r:NextNumber()
		local copy = r:Clone()
		expect(copy:NextNumber()).toBe(r:NextNumber())
		local list = { 1, 2, 3, 4, 5, 6, 7, 8 }
		MockRandom.new(2):Shuffle(list)
		table.sort(list)
		expect(list).toEqual({ 1, 2, 3, 4, 5, 6, 7, 8 })
	end)
end)
