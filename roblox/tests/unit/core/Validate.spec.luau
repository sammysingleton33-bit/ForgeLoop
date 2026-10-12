local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../mocks/MockEnv")
local V = require("@game/ReplicatedStorage/Forge/Core/Validate")

local NAN = 0 / 0
local INF = math.huge

-- Returns only the boolean, so expect(...) does not see the reason.
local function ok(validator, value): boolean
	return (validator(value))
end

local function reason(validator, value): string
	local good, why = validator(value)
	assert(good == false, "expected the validator to reject the value")
	return why
end

describe("Core/Validate", function()
	describe("string(min, max)", function()
		it("accepts strings whose byte length is in range, including multi-byte UTF-8", function()
			local v = V.string(1, 6)
			expect(ok(v, "a")).toBe(true)
			expect(ok(v, "abcdef")).toBe(true)
			expect(ok(v, "héé")).toBe(true) -- 5 bytes, 3 characters
		end)

		it("measures bytes, not characters: an oversized multi-byte string is rejected", function()
			local v = V.string(0, 4)
			expect(ok(v, "ééé")).toBe(false) -- 3 characters, 6 bytes
			expect(reason(v, "ééé")).toContain("too long")
		end)

		it("rejects too short and oversized strings", function()
			local v = V.string(2, 64)
			expect(reason(v, "a")).toContain("too short")
			expect(reason(v, string.rep("x", 65))).toContain("too long")
			expect(ok(V.string(0, 64), string.rep("x", 100000))).toBe(false)
		end)

		it("rejects invalid UTF-8", function()
			local v = V.string(0, 64)
			expect(ok(v, "\xff")).toBe(false)
			expect(reason(v, "ok\xffok")).toContain("UTF-8")
			expect(ok(v, "\xc3")).toBe(false) -- truncated 2-byte sequence
		end)

		it("rejects wrong types with the type in the reason", function()
			local v = V.string(0, 64)
			expect(reason(v, 5)).toBe("expected string, got number")
			expect(ok(v, nil)).toBe(false)
			expect(ok(v, { "a" })).toBe(false)
			expect(ok(v, true)).toBe(false)
		end)

		it("errors at construction on bad bounds", function()
			expect(function()
				V.string(5, 1)
			end).toThrow("greater than max")
			expect(function()
				V.string(-1, 4)
			end).toThrow("min must be >= 0")
			expect(function()
				V.string(0, INF)
			end).toThrow("finite")
		end)
	end)

	describe("integer(min, max)", function()
		it("accepts whole numbers in range, including the bounds", function()
			local v = V.integer(1, 99)
			expect(ok(v, 1)).toBe(true)
			expect(ok(v, 99)).toBe(true)
			expect(ok(v, 50)).toBe(true)
		end)

		it("rejects fractions, out-of-range values, NaN and ±inf", function()
			local v = V.integer(1, 99)
			expect(reason(v, 1.5)).toContain("expected integer")
			expect(reason(v, 0)).toContain("out of range")
			expect(ok(v, 100)).toBe(false)
			expect(reason(v, NAN)).toContain("not finite")
			expect(ok(v, INF)).toBe(false)
			expect(ok(v, -INF)).toBe(false)
		end)

		it("rejects numeric strings and other types", function()
			local v = V.integer(1, 99)
			expect(reason(v, "5")).toBe("expected integer, got string")
			expect(ok(v, nil)).toBe(false)
		end)

		it("errors at construction on non-integer bounds", function()
			expect(function()
				V.integer(0.5, 3)
			end).toThrow("integers")
		end)
	end)

	describe("number(min, max)", function()
		it("accepts finite numbers in range", function()
			local v = V.number(-1, 1)
			expect(ok(v, 0.25)).toBe(true)
			expect(ok(v, -1)).toBe(true)
		end)

		it("rejects NaN, inf and -inf even when the range is huge", function()
			local v = V.number(-1e308, 1e308)
			expect(reason(v, NAN)).toContain("NaN")
			expect(reason(v, INF)).toContain("inf")
			expect(reason(v, -INF)).toContain("-inf")
		end)

		it("rejects out-of-range values and wrong types", function()
			local v = V.number(0, 10)
			expect(ok(v, 10.0001)).toBe(false)
			expect(ok(v, "1")).toBe(false)
			expect(ok(v, Vector3.new(1, 0, 0))).toBe(false)
		end)

		it("errors at construction on NaN bounds", function()
			expect(function()
				V.number(NAN, 1)
			end).toThrow("finite")
		end)
	end)

	describe("boolean()", function()
		it("accepts only true and false", function()
			local v = V.boolean()
			expect(ok(v, true)).toBe(true)
			expect(ok(v, false)).toBe(true)
			expect(ok(v, nil)).toBe(false)
			expect(ok(v, 1)).toBe(false)
			expect(ok(v, "true")).toBe(false)
		end)
	end)

	describe("enum(values)", function()
		it("accepts listed values only", function()
			local v = V.enum({ "red", "green", 3 })
			expect(ok(v, "red")).toBe(true)
			expect(ok(v, 3)).toBe(true)
			expect(ok(v, "blue")).toBe(false)
			expect(ok(v, "RED")).toBe(false)
			expect(ok(v, nil)).toBe(false)
			expect(ok(v, NAN)).toBe(false)
			expect(ok(v, {})).toBe(false)
		end)

		it("errors at construction on an empty list or NaN", function()
			expect(function()
				V.enum({})
			end).toThrow("non-empty")
			expect(function()
				V.enum({ NAN })
			end).toThrow("NaN")
		end)
	end)

	describe("optional(v)", function()
		it("accepts nil or what the inner validator accepts", function()
			local v = V.optional(V.integer(1, 3))
			expect(ok(v, nil)).toBe(true)
			expect(ok(v, 2)).toBe(true)
			expect(ok(v, 4)).toBe(false)
			expect(ok(v, false)).toBe(false) -- false is not nil
		end)

		it("errors at construction without a validator", function()
			expect(function()
				V.optional(nil :: any)
			end).toThrow("validator function")
		end)
	end)

	describe("array(v, maxLen)", function()
		it("accepts lists with keys exactly 1..n up to maxLen", function()
			local v = V.array(V.string(1, 8), 3)
			expect(ok(v, {})).toBe(true)
			expect(ok(v, { "a", "b", "c" })).toBe(true)
		end)

		it("rejects lists longer than maxLen", function()
			local v = V.array(V.integer(0, 9), 3)
			expect(reason(v, { 1, 2, 3, 4 })).toContain("too long")
		end)

		it("rejects holes, string keys, fractional and non-positive keys", function()
			local v = V.array(V.integer(0, 9), 10)
			local holey = { 1, 2 }
			holey[4] = 4
			expect(reason(v, holey)).toContain("holes")
			local mixed: { [any]: any } = { 1, 2 }
			mixed.extra = 3
			expect(reason(v, mixed)).toContain("string key")
			expect(reason(v, { [1.5] = 1 })).toContain("non-positive-integer key")
			expect(reason(v, { [0] = 1 })).toContain("non-positive-integer key")
			expect(reason(v, { [-1] = 1 })).toContain("non-positive-integer key")
			expect(reason(v, { [2] = 1 })).toContain("holes")
		end)

		it("rejects tables with a metatable and non-tables", function()
			local v = V.array(V.integer(0, 9), 10)
			expect(reason(v, setmetatable({ 1 }, {}))).toContain("metatable")
			expect(reason(v, "abc")).toBe("expected array, got string")
			expect(ok(v, nil)).toBe(false)
		end)

		it("rejects an element the inner validator rejects, naming the index", function()
			local v = V.array(V.number(0, 1), 5)
			expect(reason(v, { 0.5, NAN })).toContain("[2] number is not finite")
		end)

		it("stops reading keys after maxLen: a huge table is rejected without visiting every key", function()
			local huge = {}
			for i = 1, 100000 do
				huge[i] = i
			end
			local visits = 0
			local counting = function(value)
				visits += 1
				return type(value) == "number", nil
			end
			expect(ok(V.array(counting, 10), huge)).toBe(false)
			expect(visits).toBe(0)
		end)

		it("rejects a cyclic table without hanging", function()
			local tree
			tree = function(value)
				return V.array(tree, 4)(value)
			end
			local cyclic = {}
			cyclic[1] = cyclic
			local good, why = tree(cyclic)
			expect(good).toBe(false)
			expect(why).toContain("cyclic")
		end)

		it("caps nesting depth at MAX_DEPTH arrays", function()
			local function nestedValidator(levels)
				local v = V.integer(0, 9)
				for _ = 1, levels do
					v = V.array(v, 2)
				end
				return v
			end
			local function nestedValue(levels)
				local value: any = 1
				for _ = 1, levels do
					value = { value }
				end
				return value
			end
			expect(ok(nestedValidator(V.MAX_DEPTH), nestedValue(V.MAX_DEPTH))).toBe(true)
			local good, why = nestedValidator(12)(nestedValue(12))
			expect(good).toBe(false)
			expect(why).toContain("nested deeper than 8")
		end)

		it("treats an element validator that throws as a rejection and stays usable", function()
			local throwing = V.array(function()
				error("boom")
			end, 3)
			expect(reason(throwing, { 1 })).toContain("validator error")
			-- the depth/cycle bookkeeping recovered: a normal nested validation still works
			local nested = V.array(V.array(V.integer(0, 9), 2), 2)
			expect(ok(nested, { { 1 }, { 2, 3 } })).toBe(true)
		end)

		it("errors at construction on a bad maxLen", function()
			expect(function()
				V.array(V.boolean(), -1)
			end).toThrow("maxLen")
			expect(function()
				V.array(V.boolean(), nil :: any)
			end).toThrow("maxLen")
		end)
	end)

	describe("vector3(maxMagnitude)", function()
		it("accepts Vector3 values within the magnitude", function()
			local v = V.vector3(10)
			expect(ok(v, Vector3.new(3, 4, 0))).toBe(true)
			expect(ok(v, Vector3.new(0, 0, 10))).toBe(true)
		end)

		it("rejects longer vectors, non-finite components and look-alike tables", function()
			local v = V.vector3(10)
			expect(reason(v, Vector3.new(0, 11, 0))).toContain("too long")
			expect(reason(v, Vector3.new(NAN, 0, 0))).toContain("non-finite")
			expect(reason(v, Vector3.new(INF, 0, 0))).toContain("non-finite")
			expect(reason(v, { X = 1, Y = 2, Z = 3, Magnitude = 1 })).toBe("expected Vector3, got table")
			expect(ok(v, Vector2.new(1, 1))).toBe(false)
		end)
	end)

	describe("instanceOf(className)", function()
		it("accepts instances that IsA the class (subclasses included)", function()
			local env = MockEnv.new()
			local player = env.mock.players:add({ userId = 7 })
			expect(ok(V.instanceOf("Player"), player)).toBe(true)
			expect(ok(V.instanceOf("BasePart"), Instance.new("Part"))).toBe(true)
		end)

		it("rejects other classes and non-instances", function()
			local v = V.instanceOf("Player")
			expect(reason(v, Instance.new("Part"))).toBe("expected Player, got Part")
			expect(reason(v, { ClassName = "Player" })).toBe("expected Player, got table")
			expect(ok(v, nil)).toBe(false)
		end)
	end)

	describe("check(validators, ...)", function()
		it("validates positional arguments and passes missing ones as nil", function()
			local args = { V.string(1, 8), V.optional(V.integer(1, 5)) }
			expect((V.check(args, "a", 3))).toBe(true)
			expect((V.check(args, "a"))).toBe(true)
			local good, why = V.check(args, "a", 9)
			expect(good).toBe(false)
			expect(why).toContain("argument 2")
		end)

		it("rejects extra arguments, even trailing nils", function()
			local good, why = V.check({ V.boolean() }, true, nil)
			expect(good).toBe(false)
			expect(why).toContain("too many arguments")
		end)
	end)
	describe("fail closed (review follow-up on #4)", function()
		it("rejects when a validator returns anything but exactly true", function()
			-- the classic slip: V.boolean without () hands back the validator function itself
			local forgot = V.boolean :: any
			expect((V.check({ forgot }, {}))).toBe(false)
			expect((V.array(forgot, 3)({ {}, "x" }))).toBe(false)
			expect((V.optional(forgot)("x"))).toBe(false)
			local stringy = function()
				return "yes"
			end :: any
			expect((V.check({ stringy }, 1))).toBe(false)
			expect((V.record({ a = stringy })({ a = 1 }))).toBe(false)
			expect((V.oneOf({ stringy })(1))).toBe(false)
			-- optional still passes nil and real successes
			expect((V.optional(V.boolean())(nil))).toBe(true)
			expect((V.optional(V.boolean())(true))).toBe(true)
		end)
	end)

	describe("cframe", function()
		it("accepts finite, orthonormal CFrames within range", function()
			local v = V.cframe(1000)
			expect((v(CFrame.new(10, 2, -30)))).toBe(true)
			expect((v(CFrame.new(1, 2, 3) * CFrame.Angles(0, math.rad(37), 0)))).toBe(true)
		end)

		it("rejects wrong types, far positions, NaN/inf and scaled or skewed rotations", function()
			local v = V.cframe(1000)
			expect((v(Vector3.new(1, 2, 3)))).toBe(false)
			expect((v(nil))).toBe(false)
			expect((v(CFrame.new(5000, 0, 0)))).toBe(false)
			expect((v(CFrame.new(0 / 0, 0, 0)))).toBe(false)
			expect((v(CFrame.new(math.huge, 0, 0)))).toBe(false)
			local scaled = CFrame.new(0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 1)
			local ok, why = v(scaled)
			expect(ok).toBe(false)
			expect(why).toContain("orthonormal")
			local skewed = CFrame.new(0, 0, 0, 1, 0.5, 0, 0, 1, 0, 0, 0, 1)
			expect((v(skewed))).toBe(false)
			expect(function()
				V.cframe(-1)
			end).toThrow("maxPosition")
		end)
	end)

	describe("record", function()
		local order = V.record({ kind = V.enum({ "move", "attack" }), target = V.optional(V.integer(1, 99)) })

		it("accepts exactly the declared fields, validating missing ones as nil", function()
			expect((order({ kind = "move", target = 4 }))).toBe(true)
			expect((order({ kind = "attack" }))).toBe(true)
		end)

		it("rejects extra fields, non-string keys, metatables, wrong types and bad fields", function()
			expect((order({ kind = "move", extra = 1 }))).toBe(false)
			expect((order({ kind = "move", [1] = "x" }))).toBe(false)
			expect((order(setmetatable({ kind = "move" }, {})))).toBe(false)
			expect((order("move"))).toBe(false)
			local ok, why = order({ kind = "fly" })
			expect(ok).toBe(false)
			expect(why).toContain(".kind")
			expect((order({ kind = "move", target = 0 / 0 }))).toBe(false)
			expect(function()
				V.record({ [1] = V.boolean() } :: any)
			end).toThrow("keys must be strings")
		end)
	end)

	describe("oneOf", function()
		it("accepts when any alternative accepts, and explains when none does", function()
			local target = V.oneOf({ V.vector3(500), V.integer(1, 1e6) })
			expect((target(Vector3.new(1, 0, 1)))).toBe(true)
			expect((target(42))).toBe(true)
			local ok, why = target("x")
			expect(ok).toBe(false)
			expect(why).toContain("none matched")
			expect((target(Vector3.new(0 / 0, 0, 0)))).toBe(false)
			expect(function()
				V.oneOf({})
			end).toThrow("non-empty")
		end)
	end)
end)
