--[[
	MockRandom — deterministic stand-in for Roblox's Random datatype.

	Imitates: creator-docs content/en-us/reference/engine/datatypes/Random.yaml
	(Random.new(seed?), :NextInteger(min, max), :NextNumber(min?, max?), :NextUnitVector(),
	:Shuffle(tb), :Clone()).

	Same seed -> same sequence on every machine, so specs are reproducible. The numbers are NOT
	the ones Roblox's own generator produces for that seed (this one is xoshiro128**; Roblox's
	algorithm is not documented), so never assert on rolled values that you expect to match Studio.
	As documented for Roblox, the seed is truncated to an integer (0 and 0.99 give the same stream).

	The harness also injects this as the global `Random` for modules under test.
]]

local roblox = require("@lune/roblox")

local MockRandom = {}
MockRandom.__index = MockRandom

local band, bxor, lshift, rshift = bit32.band, bit32.bxor, bit32.lshift, bit32.rshift

local function rotl(x: number, k: number): number
	return bit32.lrotate(x, k)
end

local function mul32(a: number, b: number): number
	-- 32-bit wrapping multiply without losing precision in doubles
	local aLow, aHigh = band(a, 0xFFFF), rshift(a, 16)
	return band(aLow * b + band(aHigh * b, 0xFFFF) * 0x10000, 0xFFFFFFFF)
end

local function splitmix32(state: number): (number, number)
	state = band(state + 0x9E3779B9, 0xFFFFFFFF)
	local z = state
	z = mul32(bxor(z, rshift(z, 16)), 0x85EBCA6B)
	z = mul32(bxor(z, rshift(z, 13)), 0xC2B2AE35)
	z = bxor(z, rshift(z, 16))
	return state, z
end

local seedCounter = 0

function MockRandom.new(seed: number?)
	if seed == nil then
		-- deterministic per process: unseeded generators get 1, 2, 3, ... (Roblox would use entropy)
		seedCounter += 1
		seed = seedCounter
	end
	assert(type(seed) == "number" and seed == seed, "Random.new: seed must be a number")
	local n = math.floor(seed :: number) -- documented: rounds down to the nearest integer
	local low = n % 4294967296
	local high = math.floor(n / 4294967296) % 4294967296
	local state = {}
	local sm = bxor(low, mul32(high, 0x5BD1E995))
	for i = 1, 4 do
		local out
		sm, out = splitmix32(sm)
		state[i] = out
	end
	if state[1] == 0 and state[2] == 0 and state[3] == 0 and state[4] == 0 then
		state[1] = 1
	end
	return setmetatable({ _s = state, _seed = seed }, MockRandom)
end

function MockRandom:_next32(): number
	local s = self._s
	local result = mul32(rotl(mul32(s[2], 5), 7), 9)
	local t = lshift(s[2], 9)
	s[3] = bxor(s[3], s[1])
	s[4] = bxor(s[4], s[2])
	s[2] = bxor(s[2], s[3])
	s[1] = bxor(s[1], s[4])
	s[3] = bxor(s[3], t)
	s[4] = rotl(s[4], 11)
	return result
end

-- Uniform number in [0, 1) with 53 bits of precision.
function MockRandom:_unit(): number
	local a = rshift(self:_next32(), 5) -- 27 bits
	local b = rshift(self:_next32(), 6) -- 26 bits
	return (a * 67108864 + b) / 9007199254740992
end

function MockRandom:NextNumber(min: number?, max: number?): number
	local lo, hi = min or 0, max or 1
	return lo + (hi - lo) * self:_unit()
end

function MockRandom:NextInteger(min: number, max: number): number
	assert(type(min) == "number" and type(max) == "number", "NextInteger(min, max) requires two numbers")
	-- documented: both arguments are truncated toward zero; min > max is swapped
	local function trunc(x: number): number
		return if x < 0 then math.ceil(x) else math.floor(x)
	end
	min, max = trunc(min), trunc(max)
	if min > max then
		min, max = max, min
	end
	return min + math.floor(self:_unit() * (max - min + 1))
end

function MockRandom:Shuffle(tb: { any })
	for i = #tb, 2, -1 do
		local j = self:NextInteger(1, i)
		tb[i], tb[j] = tb[j], tb[i]
	end
end

function MockRandom:NextUnitVector(): any
	local z = self:NextNumber(-1, 1)
	local angle = self:NextNumber(0, 2 * math.pi)
	local r = math.sqrt(1 - z * z)
	local x, y = r * math.cos(angle), r * math.sin(angle)
	return roblox.Vector3.new(x, y, z)
end

function MockRandom:Clone()
	local copy = setmetatable({ _s = table.clone(self._s), _seed = self._seed }, MockRandom)
	return copy
end

return MockRandom
