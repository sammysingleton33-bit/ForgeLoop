--[[
	MockDataStoreService — in-memory DataStoreService with failure injection, request budgets,
	latency on the MockEnv clock and an "another server wrote first" hook.

	Imitates (creator-docs, raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/...):
	  reference/engine/classes/DataStoreService.yaml   GetDataStore, GetRequestBudgetForRequestType
	  reference/engine/classes/GlobalDataStore.yaml    GetAsync / SetAsync / UpdateAsync / IncrementAsync / RemoveAsync
	  reference/engine/classes/DataStoreKeyInfo.yaml   Version, CreatedTime, UpdatedTime, GetUserIds, GetMetadata
	  reference/engine/enums/DataStoreRequestType.yaml which budget each call consumes
	  cloud-services/data-stores/error-codes-and-limits.md  101/102 key errors, 103-105 value errors,
	                                                        301-306 throttling, 502 RequestRejected
	Semantics kept:
	  - UpdateAsync calls transform(current, keyInfo); returning nil cancels: nothing is written and
	    UpdateAsync returns nil. The transform must not yield. Errors in it propagate to the caller.
	    If another server writes between the read and the commit, the transform runs again with the
	    new value (simulate with interleaveNextUpdate).
	  - Values are stored as JSON: every read returns a fresh copy; storing functions, Instances,
	    mixed tables, metatables, non-finite numbers or invalid UTF-8 errors (103/104); values over
	    4,194,304 characters error (105). Keys must be 1..50 characters (101/102).
	  - Budgets (error-codes-and-limits.md "Server limits" + "Experience limits"; DataStoreRequestType.yaml):
    GetAsync -> StandardRead (+legacy GetAsync); SetAsync/IncrementAsync -> StandardWrite
    (+legacy SetIncrementAsync); RemoveAsync -> StandardRemove (+legacy SetIncrementAsync);
    UpdateAsync -> StandardRead + StandardWrite on every call, cancelled or not ("A single call will
    decrement both limits"; the StandardWrite enum text has no non-nil condition) (+legacy GetAsync,
    UpdateAsync; legacy SetIncrementAsync only when it writes, as that legacy item's text says).
    Per-minute rates: 60 + numPlayers x 40 for StandardRead/Write/Remove, 5 + numPlayers x 2 for
    StandardList; the legacy items (no longer documented) use their modern counterpart's rate.
    Under MockEnv the budgets refill continuously on the virtual clock at rate/60 per second, with
    numPlayers from MockPlayers, up to one minute's worth (the cap is an assumption: undocumented).
    A server starts with a one-time burst (documented, amount undocumented): `budget`, default 1000.
    A request needs a budget of at least 1; otherwise it fails with its 30x throttle error (Roblox
    would queue it first; the mock fails at once). Standalone (no `now` given): no refill.
  - Every request yields like a web call: under MockEnv it waits setLatency seconds, at least one
    frame (env.wait), so a DataStore call inside Loader new() is reported as a yield.
  - A failed write may still have been applied in Roblox ("does not always guarantee that the
	    backend write did not occur"): failNext(..., { afterCommit = true }) reproduces that.
	Not modelled: GetAsync caching, OrderedDataStore, versions listing, MemoryStore.

	Roblox API (PascalCase) on the service: GetDataStore(name, scope?), GetGlobalDataStore(),
	GetRequestBudgetForRequestType(Enum.DataStoreRequestType.X)
	Control API (camelCase, tests only):
		MockDataStoreService.new({ wait = fn?, now = fn?, numPlayers = fn?, budget = number? })  -- MockEnv passes all
		dss:failNext(method, count?, { message = string?, afterCommit = boolean?, store = string? }?)
		    method: "GetAsync" | "SetAsync" | "UpdateAsync" | "IncrementAsync" | "RemoveAsync" | "*"
		dss:setBudget(requestTypeOrName | "*", n)
		dss:setLatency(seconds)                       -- every request waits via options.wait first
		dss:interleaveNextUpdate(storeName, key, fn(write, read))  -- runs once between the transform
		                                              -- and the commit of the next UpdateAsync on that key;
		                                              -- write(value) = another server's write
		dss:peek(storeName, key, scope?) -> value copy | nil
		dss:poke(storeName, key, value, scope?)       -- write without budgets/failures/latency
		dss:requests() -> { { method, store, key } }  -- every request in order
		dss:clearFailures()
]]

local Wire = require("./Wire")

local MockDataStoreService = {}
MockDataStoreService.__index = MockDataStoreService

local MockDataStore = {}
MockDataStore.__index = MockDataStore

local DEFAULT_FAILURE = "502: API Services rejected request with error: HTTP 500 (Internal Server Error) [mock]"
local DEFAULT_BUDGET = 1000

-- method -> budgets spent when the request starts / when it writes, and its throttle error
local REQUEST_TYPES = {
	GetAsync = {
		atStart = { "StandardRead", "GetAsync" },
		atCommit = {},
		throttle = "301: GetAsync request dropped. Request was throttled, but throttled request queue was full.",
	},
	SetAsync = {
		atStart = { "StandardWrite", "SetIncrementAsync" },
		atCommit = {},
		throttle = "302: SetAsync request dropped. Request was throttled, but throttled request queue was full.",
	},
	IncrementAsync = {
		atStart = { "StandardWrite", "SetIncrementAsync" },
		atCommit = {},
		throttle = "303: IncrementAsync request dropped. Request was throttled, but throttled request queue was full.",
	},
	UpdateAsync = {
		atStart = { "StandardRead", "StandardWrite", "GetAsync", "UpdateAsync" },
		atCommit = { "SetIncrementAsync" },
		throttle = "304: UpdateAsync request dropped. Request was throttled, but throttled request queue was full.",
	},
	RemoveAsync = {
		atStart = { "StandardRemove", "SetIncrementAsync" },
		atCommit = {},
		throttle = "306: RemoveAsync request dropped. Request was throttled, but throttled request queue was full.",
	},
}

-- Requests per minute = base + perPlayer x numPlayers (error-codes-and-limits.md, "Server limits").
local RATES = {
	StandardRead = { 60, 40 },
	StandardWrite = { 60, 40 },
	StandardRemove = { 60, 40 },
	StandardList = { 5, 2 },
	GetAsync = { 60, 40 },
	SetIncrementAsync = { 60, 40 },
	UpdateAsync = { 60, 40 },
}

local function enumName(requestType: any): string
	if type(requestType) == "string" then
		return requestType
	end
	if typeof(requestType) == "EnumItem" then
		return requestType.Name
	end
	error("GetRequestBudgetForRequestType expects an Enum.DataStoreRequestType item", 3)
end

function MockDataStoreService.new(options: {
	wait: ((number) -> ())?,
	now: (() -> number)?,
	numPlayers: (() -> number)?,
	budget: number?,
}?)
	local now = options and options.now
	local self = setmetatable({
		_wait = options and options.wait,
		_now = now or os.time,
		_refills = now ~= nil,
		_lastRefill = if now then now() else 0,
		_numPlayers = (options and options.numPlayers) or function()
			return 0
		end,
		_defaultBudget = (options and options.budget) or DEFAULT_BUDGET,
		_budgets = {},
		_failures = {},
		_latency = 0,
		_stores = {},
		_data = {}, -- storeKey -> key -> entry { json, version, created, updated, userIds, metadata }
		_interleave = {},
		_requests = {},
		_versionCounter = 0,
	}, MockDataStoreService)
	return self
end

local function storeKey(name: string, scope: string?): string
	return (scope or "global") .. "/" .. name
end

-- ------------------------------------------------------------------ Roblox API

function MockDataStoreService:GetDataStore(name: string, scope: string?, _options: any?)
	assert(type(name) == "string" and #name > 0 and #name <= 50, "GetDataStore: name must be 1..50 characters")
	if scope ~= nil then
		assert(type(scope) == "string" and #scope > 0 and #scope <= 50, "GetDataStore: scope must be 1..50 characters")
	end
	local id = storeKey(name, scope)
	local store = self._stores[id]
	if not store then
		store = setmetatable({ Name = name, _service = self, _id = id }, MockDataStore)
		self._stores[id] = store
		self._data[id] = self._data[id] or {}
	end
	return store
end

function MockDataStoreService:GetGlobalDataStore()
	return self:GetDataStore("__GlobalDataStore")
end

function MockDataStoreService:GetRequestBudgetForRequestType(requestType: any): number
	local name = enumName(requestType)
	self:_refill()
	return math.floor(self:_budget(name))
end

-- ------------------------------------------------------------------ control API

function MockDataStoreService:failNext(
	method: string,
	count: number?,
	options: { message: string?, afterCommit: boolean?, store: string? }?
)
	assert(method == "*" or REQUEST_TYPES[method], `failNext: unknown method '{tostring(method)}'`)
	table.insert(self._failures, {
		method = method,
		remaining = count or 1,
		message = (options and options.message) or DEFAULT_FAILURE,
		afterCommit = options and options.afterCommit or false,
		store = options and options.store,
	})
end

function MockDataStoreService:clearFailures()
	table.clear(self._failures)
end

function MockDataStoreService:setBudget(requestType: any, n: number)
	self:_refill()
	if requestType == "*" then
		self._defaultBudget = n
		table.clear(self._budgets)
	else
		self._budgets[enumName(requestType)] = n
	end
end

function MockDataStoreService:setLatency(seconds: number)
	assert(seconds == 0 or self._wait, "setLatency needs a wait function (create the mock through MockEnv)")
	self._latency = seconds
end

function MockDataStoreService:interleaveNextUpdate(storeName: string, key: string, fn: (any, any) -> ())
	table.insert(self._interleave, { store = storeName, key = key, fn = fn })
end

function MockDataStoreService:peek(storeName: string, key: string, scope: string?): any
	local entry = (self._data[storeKey(storeName, scope)] or {})[key]
	return if entry then Wire.decodeFromDataStore(entry.json) else nil
end

function MockDataStoreService:poke(storeName: string, key: string, value: any, scope: string?)
	local store = self:GetDataStore(storeName, scope)
	store:_commit(key, value, nil, nil)
end

function MockDataStoreService:requests()
	return table.clone(self._requests)
end

-- ------------------------------------------------------------------ internals

function MockDataStoreService:_takeFailure(method: string, storeName: string)
	for i, failure in self._failures do
		if
			(failure.method == "*" or failure.method == method) and (failure.store == nil or failure.store == storeName)
		then
			failure.remaining -= 1
			if failure.remaining <= 0 then
				table.remove(self._failures, i)
			end
			return failure
		end
	end
	return nil
end

function MockDataStoreService:_budget(name: string): number
	local budget = self._budgets[name]
	return if budget == nil then self._defaultBudget else budget
end

-- Continuous refill on the injected clock, up to one minute's worth of requests.
function MockDataStoreService:_refill()
	if not self._refills then
		return
	end
	local now = self._now()
	local dt = now - self._lastRefill
	self._lastRefill = now
	if dt <= 0 then
		return
	end
	local players = self._numPlayers()
	for name, rate in RATES do
		local perMinute = rate[1] + rate[2] * players
		local current = self:_budget(name)
		if current < perMinute then
			self._budgets[name] = math.min(perMinute, current + perMinute * dt / 60)
		end
	end
end

function MockDataStoreService:_spend(names: { string }, throttle: string)
	self:_refill()
	for _, name in names do
		if self:_budget(name) < 1 then
			error(throttle, 0)
		end
	end
	for _, name in names do
		self._budgets[name] = self:_budget(name) - 1
	end
end

local function checkKey(key: any)
	if type(key) ~= "string" or #key == 0 then
		error("101: Key name can't be empty.", 0)
	end
	if #key > 50 then
		error("102: Key name exceeds the 50 character limit.", 0)
	end
end

function MockDataStore:_begin(method: string, key: string)
	local service = self._service
	checkKey(key)
	table.insert(service._requests, { method = method, store = self.Name, key = key })
	local spec = REQUEST_TYPES[method]
	service:_spend(spec.atStart, spec.throttle)
	if service._wait then
		service._wait(service._latency) -- at least one frame: Roblox *Async calls always yield
	end
	local failure = service:_takeFailure(method, self.Name)
	if failure and not failure.afterCommit then
		error(failure.message, 0)
	end
	return failure
end

local function keyInfo(entry)
	if entry == nil then
		return nil
	end
	local userIds = table.clone(entry.userIds or {})
	local metadata = table.clone(entry.metadata or {})
	return {
		Version = entry.version,
		CreatedTime = entry.created,
		UpdatedTime = entry.updated,
		GetUserIds = function()
			return table.clone(userIds)
		end,
		GetMetadata = function()
			return table.clone(metadata)
		end,
	}
end

function MockDataStore:_entry(key: string)
	return self._service._data[self._id][key]
end

function MockDataStore:_commit(key: string, value: any, userIds: { number }?, metadata: { [string]: any }?)
	local service = self._service
	if userIds ~= nil then
		for _, id in userIds do
			if type(id) ~= "number" then
				error("513: Attribute userId format is invalid.", 0)
			end
		end
	end
	if metadata ~= nil and type(metadata) ~= "table" then
		error("513: Attribute metadata format is invalid.", 0)
	end
	local json = Wire.encodeForDataStore(value)
	local nowMs = math.floor(service._now() * 1000)
	local previous = self:_entry(key)
	service._versionCounter += 1
	local entry = {
		json = json,
		version = `mock-v{service._versionCounter}`,
		created = if previous then previous.created else nowMs,
		updated = nowMs,
		userIds = if userIds then table.clone(userIds) else {},
		metadata = if metadata then table.clone(metadata) else {},
	}
	service._data[self._id][key] = entry
	return entry
end

local function finish(failure)
	if failure and failure.afterCommit then
		error(failure.message, 0)
	end
end

function MockDataStore:GetAsync(key: string, _options: any?)
	local failure = self:_begin("GetAsync", key)
	local entry = self:_entry(key)
	finish(failure)
	if entry == nil then
		return nil, nil
	end
	return Wire.decodeFromDataStore(entry.json), keyInfo(entry)
end

function MockDataStore:SetAsync(key: string, value: any, userIds: { number }?, _options: any?)
	local failure = self:_begin("SetAsync", key)
	local entry = self:_commit(key, value, userIds, nil)
	finish(failure)
	return entry.version
end

function MockDataStore:IncrementAsync(key: string, delta: number?, userIds: { number }?, _options: any?)
	local failure = self:_begin("IncrementAsync", key)
	local entry = self:_entry(key)
	local current = if entry then Wire.decodeFromDataStore(entry.json) else 0
	if type(current) ~= "number" or current % 1 ~= 0 then
		error("IncrementAsync: the stored value is not an integer", 0)
	end
	local step = delta or 1
	if type(step) ~= "number" or step % 1 ~= 0 then
		error("IncrementAsync: delta must be an integer", 0)
	end
	local newValue = current + step
	self:_commit(key, newValue, userIds, nil)
	finish(failure)
	return newValue
end

function MockDataStore:RemoveAsync(key: string)
	local failure = self:_begin("RemoveAsync", key)
	local entry = self:_entry(key)
	self._service._data[self._id][key] = nil
	finish(failure)
	if entry == nil then
		return nil, nil
	end
	return Wire.decodeFromDataStore(entry.json), keyInfo(entry)
end

local function callTransform(transform, current, info)
	local thread = coroutine.create(transform)
	local results = table.pack(coroutine.resume(thread, current, info))
	if not results[1] then
		error(results[2], 0)
	end
	if coroutine.status(thread) ~= "dead" then
		error("UpdateAsync: the transform function yielded; it must not yield (GlobalDataStore.yaml)", 0)
	end
	return results[2], results[3], results[4]
end

function MockDataStore:UpdateAsync(key: string, transform: (any, any) -> (any, { number }?, { [string]: any }?))
	assert(type(transform) == "function", "UpdateAsync: transform must be a function")
	local failure = self:_begin("UpdateAsync", key)
	local service = self._service
	for _ = 1, 100 do
		local entry = self:_entry(key)
		local current = if entry then Wire.decodeFromDataStore(entry.json) else nil
		local newValue, userIds, metadata = callTransform(transform, current, keyInfo(entry))
		if newValue == nil then
			finish(failure)
			return nil, nil
		end
		-- another server may write between our read and our commit
		for i, hook in service._interleave do
			if hook.store == self.Name and hook.key == key then
				table.remove(service._interleave, i)
				hook.fn(function(value: any)
					self:_commit(key, value, nil, nil)
				end, function(): any
					local e = self:_entry(key)
					return if e then Wire.decodeFromDataStore(e.json) else nil
				end)
				break
			end
		end
		if self:_entry(key) ~= entry then
			continue -- the key changed: call the transform again with the new value
		end
		local spec = REQUEST_TYPES.UpdateAsync
		service:_spend(spec.atCommit, spec.throttle)
		local committed = self:_commit(key, newValue, userIds, metadata)
		finish(failure)
		return Wire.decodeFromDataStore(committed.json), keyInfo(committed)
	end
	error("UpdateAsync: the key kept changing (100 retries)", 0)
end

return MockDataStoreService
