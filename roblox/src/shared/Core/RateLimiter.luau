--!strict
--[[
	RateLimiter — token bucket per key (players, user ids, strings, ...) on an injected clock.

	API
		RateLimiter.new({ burst: number, perSecond: number, clock: () -> number }): RateLimiter
			burst      bucket size (> 0): calls allowed at once from a full bucket
			perSecond  refill rate (>= 0) in tokens per second
			clock      monotonic seconds, e.g. env.clock (never os.clock directly in services)
		limiter:allow(key, cost = 1): boolean   -- takes `cost` tokens when available, else false
		limiter:tokens(key): number              -- tokens available now (burst for an unknown key)
		limiter:reset(key?)                      -- forget one key (frees its bucket) or every key
		limiter:size(): number                   -- number of keys with a bucket (memory check)

	Semantics
		- A key starts with a full bucket. Refill is continuous: tokens = min(burst, tokens +
		  elapsed * perSecond), computed lazily on allow()/tokens(); there are no timers.
		- A rejected allow() takes nothing. cost may be fractional; a cost above burst never passes.
		- The clock must be monotonic; if it ever goes backwards, nothing refills until it passes
		  the last time seen.
		- Buckets live until reset(key): callers own key lifetime (RemoteService resets a player's
		  key on Players.PlayerRemoving).
		- Programmer errors (bad options, nil/NaN key, negative or non-finite cost) raise errors.
]]

export type Options = {
	burst: number,
	perSecond: number,
	clock: () -> number,
}

export type RateLimiter = {
	allow: (self: RateLimiter, key: any, cost: number?) -> boolean,
	tokens: (self: RateLimiter, key: any) -> number,
	reset: (self: RateLimiter, key: any?) -> (),
	size: (self: RateLimiter) -> number,
}

type Bucket = { tokens: number, at: number }

local RateLimiter = {}
RateLimiter.__index = RateLimiter

local function isFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function RateLimiter.new(options: Options): RateLimiter
	if type(options) ~= "table" then
		error("RateLimiter.new({ burst, perSecond, clock }): options table expected", 2)
	end
	if not isFinite(options.burst) or options.burst <= 0 then
		error("RateLimiter.new: burst must be a finite number > 0", 2)
	end
	if not isFinite(options.perSecond) or options.perSecond < 0 then
		error("RateLimiter.new: perSecond must be a finite number >= 0", 2)
	end
	if type(options.clock) ~= "function" then
		error("RateLimiter.new: clock must be a function returning monotonic seconds", 2)
	end
	local self = setmetatable({
		_burst = options.burst,
		_perSecond = options.perSecond,
		_clock = options.clock,
		_buckets = {} :: { [any]: Bucket },
		_count = 0,
	}, RateLimiter)
	return (self :: any) :: RateLimiter
end

local function checkKey(key: any)
	if key == nil or key ~= key then
		error("RateLimiter: key must not be nil or NaN", 3)
	end
end

-- Tokens for `bucket` at time `now` (does not store anything).
local function refilled(self: any, bucket: Bucket, now: number): number
	local elapsed = now - bucket.at
	if not (elapsed > 0) then
		return bucket.tokens
	end
	return math.min(self._burst, bucket.tokens + elapsed * self._perSecond)
end

function RateLimiter.allow(self: any, key: any, cost: number?): boolean
	checkKey(key)
	local amount = if cost == nil then 1 else cost
	if not isFinite(amount) or amount < 0 then
		error("RateLimiter:allow: cost must be a finite number >= 0", 2)
	end
	local now = self._clock()
	local bucket: Bucket? = self._buckets[key]
	if bucket == nil then
		bucket = { tokens = self._burst, at = now }
		self._buckets[key] = bucket
		self._count += 1
	end
	local b = bucket :: Bucket
	b.tokens = refilled(self, b, now)
	if now > b.at then
		b.at = now
	end
	-- a hair of tolerance: refill arithmetic in floating point must not deny a call that arrives
	-- exactly on schedule (burst 1 at 5/s, calls 0.2 s apart)
	if b.tokens >= amount - 1e-9 then
		b.tokens = math.max(0, b.tokens - amount)
		return true
	end
	return false
end

function RateLimiter.tokens(self: any, key: any): number
	checkKey(key)
	local bucket: Bucket? = self._buckets[key]
	if bucket == nil then
		return self._burst
	end
	return refilled(self, bucket, self._clock())
end

function RateLimiter.reset(self: any, key: any?)
	if key == nil then
		table.clear(self._buckets)
		self._count = 0
		return
	end
	if key ~= key then
		return
	end
	if self._buckets[key] ~= nil then
		self._buckets[key] = nil
		self._count -= 1
	end
end

function RateLimiter.size(self: any): number
	return self._count
end

return RateLimiter
