--[[
	MockEnv — a complete fake of Contracts/Env (interfaces §2, v0.3) for Lune specs, with virtual
	time, deterministic randomness, captured logs and the Roblox service mocks wired together.

		local MockEnv = require("../../mocks/MockEnv")
		local env = MockEnv.new({ seed = 7 })
		local service = MyService.new(env, registry)
		env.mock:advance(60)                      -- run everything that waits up to 60 virtual seconds
		expect(env.mock:hasLog("warn", "retry")).toBe(true)

	Options (all optional)
		isServer = true, jobId = "mock-job-<n>" (never empty), startTime = 1700000000 (unix seconds),
		seed = 1, studio = false, services = { [Name] = override }, sharedModules = { [fileName] = { [Area] = module } },
		localPlayer = { userId = n, name = s? }   -- client-side specs: Players.LocalPlayer + remote client context
	Fields: every Env field (Env.FIELDS) plus `mock` (the control API below).
		DataStoreService MockDataStoreService (latency/clock wired to this env) · Players real Players
		instance (MockPlayers) · MarketplaceService MockMarketplaceService · PolicyService MockPolicyService ·
		AnalyticsService MockAnalyticsService · CollectionService MockCollectionService · RunService and
		HttpService (MockServices) · ReplicatedStorage, Workspace, ServerStorage, Lighting, Teams: real
		Lune instances of one DataModel · MemoryStoreService, TweenService, SoundService, UserInputService,
		ContextActionService, GuiService: "unmocked" guards (error on use) unless passed in `services`.
		Pass the same MockDataStoreService in `services` to two MockEnvs (distinct jobIds) to simulate
		two servers sharing one data store.

	Time model (virtual seconds; nothing here sleeps for real)
		now()            floor(startTime + elapsed)          (os.time-like integer seconds)
		serverTimeNow()  startTime + elapsed + offset         (fractional, like GetServerTimeNow)
		clock()          1000 + elapsed                       (monotonic)
		spawn(fn, ...)   runs fn now in a new thread (like task.spawn); errors at any later resume
		                 are caught too
		wait(s?)         like task.wait: never shorter than one frame (MockEnv.FRAME = 1/60 s), so
		                 wait() and wait(0) mean "next frame". Returns the virtual seconds waited.
		                   - in a scheduled thread (every thread except the spec's own: env.spawn
		                     threads, Signal/GameEvents handlers, the coroutine Loader runs new() in,
		                     coroutine.wrap code, ...): suspends until mock:advance() reaches it — so a
		                     waiting handler does not delay fire(), and Loader sees new() yield;
		                   - in the spec's own thread (the test body and its hooks; Test.isDriverThread):
		                     advances virtual time by that amount at once (spec code never hangs).
		Mock *Async calls (DataStore, PolicyService, UserOwnsGamePassAsync) wait at least one frame
		(DataStore: setLatency, default 0 -> one frame), so they yield like the real web calls.
		Errors in scheduled threads fail the test that spawned them and are kept in mock.threadErrors.

	Control API (env.mock)
		:advance(seconds)          resume due threads in time order (fires Instance events at every
		                           step), then set elapsed += seconds. Not re-entrant: calling it from a
		                           scheduled thread errors. More than MockEnv.MAX_RESUMES resumes in one
		                           call errors (runaway loop) instead of hanging the gate.
		:setServerTimeOffset(s)    shift serverTimeNow relative to now
		:elapsed() -> number       :pendingThreads() -> number
		.logs: { { level, message, fields } }   :hasLog(level, substring) -> boolean   :clearLogs()
		.closeHandlers: { fn }     :runBindToClose(limit = 30) -> (allFinished: boolean, seconds: number)
		.threadErrors: { string }  .instances: { Instance } (created through newInstance)
		.warnings: { string }      engine-style warnings (e.g. "Infinite yield possible on ...")
		.dataModel                 the Lune DataModel behind the instance services
		.players                   MockPlayers control (:add, :remove, .kicks, ...)
		.remotes                   MockRemotes network (:asClient, :sent, ...)
	Instances in the DataModel (and from newInstance) also get WaitForChild, ChildAdded and
	ChildRemoved on the virtual clock: see MockInstanceEvents.luau for what is (not) provided.
	Engine-only members (ParticleEmitter:Emit/:Clear, Sound:Play/:Stop) come from FORGE-04's
	EngineStubs, installed once per process here: Lune lacks them, so a client spec that fires a
	celebration (#49) would otherwise crash in VFXController. Lune allows one registration per
	member per process, so EngineStubs stays the only registrar (its install is idempotent).
]]

local roblox = require("@lune/roblox")

local Env = require("@game/ReplicatedStorage/Forge/Contracts/Env")
local Test = require("../harness/Test")
local MockAnalyticsService = require("./MockAnalyticsService")
local MockCollectionService = require("./MockCollectionService")
local MockDataStoreService = require("./MockDataStoreService")
local MockInstanceEvents = require("./MockInstanceEvents")
local MockMarketplaceService = require("./MockMarketplaceService")
local MockPlayers = require("./MockPlayers")
local MockPolicyService = require("./MockPolicyService")
local MockRandom = require("./MockRandom")
local MockRemotes = require("./MockRemotes")
local MockServices = require("./MockServices")
local MockSignal = require("./MockSignal")
local EngineStubs = require("../unit/experience/doubles/EngineStubs")

local MockEnv = {}

MockEnv.FRAME = 1 / 60 -- task.wait() resumes on the next frame; Roblox runs about 60 frames per second
MockEnv.MAX_RESUMES = 1000000 -- per advance() call

local REMOTE_CLASSES = { RemoteEvent = true, RemoteFunction = true, UnreliableRemoteEvent = true }
local UNMOCKED = {
	"MemoryStoreService",
	"TweenService",
	"SoundService",
	"UserInputService",
	"ContextActionService",
	"GuiService",
}
local LEVELS = { info = true, warn = true, error = true }

local jobCounter = 0

function MockEnv.new(options: { [string]: any }?)
	EngineStubs.install()
	local opts = options or {}
	local overrides = opts.services or {}
	jobCounter += 1
	local jobId = opts.jobId
	if jobId == nil then
		jobId = `mock-job-{jobCounter}`
	end
	assert(type(jobId) == "string" and jobId ~= "", "MockEnv: jobId must be a non-empty string (interfaces §2)")
	local isServer = if opts.isServer == nil then true else opts.isServer
	local startTime = opts.startTime or 1700000000
	local master = MockRandom.new(opts.seed or 1)

	local env: { [string]: any } = {}
	local control = {
		logs = {},
		closeHandlers = {},
		threadErrors = {},
		instances = {},
	}
	env.mock = control

	-- ---------------------------------------------------------- scheduler
	local FRAME = MockEnv.FRAME
	local elapsed = 0
	local serverOffset = 0
	local sequence = 0
	local queue = {} -- { at, seq, thread, started, done } — threads parked by wait()/defer
	local advancing = false
	local hub -- MockInstanceEvents hub (created below, polled at every scheduler step)

	local function report(message: string, origin: any?)
		table.insert(control.threadErrors, message)
		Test.reportUnhandledError(message, origin)
	end

	-- Resumes a parked thread. Threads made by env.spawn/Signal catch their own errors; this catches
	-- the rest (e.g. the coroutine Loader runs new() in, or a plain coroutine.create thread).
	local function resume(thread: thread, ...)
		local ok, err = coroutine.resume(thread, ...)
		if not ok then
			report("scheduled thread: " .. debug.traceback(thread, tostring(err)))
		end
	end

	local function park(delay: number): number
		sequence += 1
		local item = { at = elapsed + delay, seq = sequence, thread = coroutine.running(), started = elapsed }
		table.insert(queue, item)
		local waited = coroutine.yield()
		item.done = true -- resumed (by advance, or early by someone else): never resume it again
		return waited
	end

	local function nextDue(target: number): number?
		local best = nil
		for i, item in queue do
			if item.at <= target + 1e-9 then -- tolerance: 60 frames of 1/60 s add up to a hair over 1
				local current = if best then queue[best] else nil
				if current == nil or item.at < current.at or (item.at == current.at and item.seq < current.seq) then
					best = i
				end
			end
		end
		return best
	end

	function env.spawn(fn: (...any) -> (), ...)
		assert(type(fn) == "function", "env.spawn expects a function")
		local origin = Test.captureOrigin()
		local thread = coroutine.create(function(...)
			local ok, err = xpcall(fn, function(e)
				return debug.traceback(tostring(e), 2)
			end, ...)
			if not ok then
				report("env.spawn thread: " .. tostring(err), origin)
			end
		end)
		resume(thread, ...)
	end

	-- task.defer-like: fn runs at the next scheduler step without virtual time passing.
	local function defer(fn: () -> ())
		env.spawn(function()
			park(0)
			fn()
		end)
	end

	function control:advance(seconds: number)
		assert(type(seconds) == "number" and seconds >= 0, "advance(seconds >= 0)")
		if advancing then
			error(
				"env.mock:advance() was called while the scheduler is already advancing (from a scheduled "
					.. "thread); only the spec's own code advances virtual time",
				2
			)
		end
		advancing = true
		local target = elapsed + seconds
		local resumes = 0
		local ok, err = pcall(function()
			while true do
				hub:poll()
				local index = nextDue(target)
				if index == nil then
					break
				end
				local item = table.remove(queue, index)
				if not item.done and coroutine.status(item.thread) == "suspended" then
					elapsed = math.max(elapsed, item.at)
					resumes += 1
					if resumes > MockEnv.MAX_RESUMES then
						error(
							`env.mock:advance({seconds}): more than {MockEnv.MAX_RESUMES} thread resumes — a runaway `
								.. "loop (e.g. a thread that defers itself forever)",
							0
						)
					end
					resume(item.thread, elapsed - item.started)
				end
			end
		end)
		elapsed = math.max(elapsed, target)
		advancing = false
		if not ok then
			error(err, 0)
		end
	end

	function env.wait(seconds: number?): number
		local s = seconds or 0
		assert(type(s) == "number", "env.wait expects a number of seconds")
		if s ~= s or s < FRAME then
			s = FRAME
		end
		if Test.isDriverThread(coroutine.running()) then
			control:advance(s)
			return s
		end
		return park(s)
	end

	function control:elapsed(): number
		return elapsed
	end

	function control:pendingThreads(): number
		local count = 0
		for _, item in queue do
			if not item.done and coroutine.status(item.thread) == "suspended" then
				count += 1
			end
		end
		return count
	end

	function control:setServerTimeOffset(offset: number)
		serverOffset = offset
	end

	function env.now(): number
		return math.floor(startTime + elapsed)
	end

	function env.clock(): number
		return 1000 + elapsed
	end

	function env.serverTimeNow(): number
		return startTime + elapsed + serverOffset
	end

	function env.random(seed: number?)
		if seed ~= nil then
			return MockRandom.new(seed)
		end
		return MockRandom.new(master:NextInteger(1, 2 ^ 31))
	end

	-- ---------------------------------------------------------- logs
	function env.log(level: string, message: string, fields: { [string]: any }?)
		if not LEVELS[level] then
			error(`env.log: unknown level '{tostring(level)}' (info | warn | error)`, 2)
		end
		assert(type(message) == "string", "env.log: message must be a string")
		table.insert(
			control.logs,
			{ level = level, message = message, fields = if fields then table.clone(fields) else {} }
		)
	end

	function control:hasLog(level: string?, substring: string): boolean
		for _, entry in self.logs do
			if (level == nil or entry.level == level) and string.find(entry.message, substring, 1, true) then
				return true
			end
		end
		return false
	end

	function control:clearLogs()
		table.clear(self.logs)
	end

	-- ---------------------------------------------------------- shutdown
	function env.bindToClose(fn: () -> ())
		if not isServer then
			error("env.bindToClose is server-only (game:BindToClose)", 2)
		end
		assert(type(fn) == "function", "bindToClose expects a function")
		table.insert(control.closeHandlers, fn)
	end

	function control:runBindToClose(limit: number?): (boolean, number)
		local deadline = elapsed + (limit or 30)
		local started = elapsed
		local finished = 0
		for _, handler in self.closeHandlers do
			env.spawn(function()
				handler()
				finished += 1
			end)
		end
		while finished < #self.closeHandlers do
			local index = nextDue(deadline)
			if index == nil then
				break
			end
			self:advance(queue[index].at - elapsed)
		end
		return finished == #self.closeHandlers, elapsed - started
	end

	-- ---------------------------------------------------------- instances and services
	local dataModel = roblox.Instance.new("DataModel")
	control.dataModel = dataModel
	control.warnings = {}

	hub = MockInstanceEvents.newHub({
		wait = env.wait,
		elapsed = function(): number
			return elapsed
		end,
		isDriver = function(): boolean
			return Test.isDriverThread(coroutine.running())
		end,
		spawn = env.spawn,
		warn = function(message: string)
			table.insert(control.warnings, message)
		end,
		newSignal = function(name: string)
			return MockSignal.new({ spawn = env.spawn, name = name })
		end,
	})
	hub:adopt(dataModel)

	local playersInstance, playersControl = MockPlayers.new(dataModel, {
		spawn = env.spawn,
		defer = defer,
	})
	control.players = playersControl
	local network = MockRemotes.newNetwork({ players = playersControl, spawn = env.spawn })
	control.remotes = network

	function env.newInstance(className: string)
		local instance = roblox.Instance.new(className)
		hub:adopt(instance) -- WaitForChild/ChildAdded work before it is parented into the DataModel
		if REMOTE_CLASSES[className] then
			network:attach(instance)
		end
		table.insert(control.instances, instance)
		return instance
	end

	env.isServer = isServer
	env.jobId = jobId
	env.DataStoreService = overrides.DataStoreService
		or MockDataStoreService.new({
			wait = env.wait,
			now = env.serverTimeNow,
			numPlayers = function(): number
				return #playersInstance:GetPlayers()
			end,
		})
	env.Players = overrides.Players or playersInstance
	env.MarketplaceService = overrides.MarketplaceService
		or MockMarketplaceService.new({ spawn = env.spawn, wait = env.wait, players = playersControl })
	env.PolicyService = overrides.PolicyService or MockPolicyService.new({ wait = env.wait })
	env.AnalyticsService = overrides.AnalyticsService or MockAnalyticsService.new()
	env.RunService = overrides.RunService
		or MockServices.runService({ isServer = isServer, isStudio = opts.studio, spawn = env.spawn })
	env.HttpService = overrides.HttpService or MockServices.httpService()
	env.CollectionService = overrides.CollectionService or MockCollectionService.new(dataModel, { spawn = env.spawn })
	for _, name in { "ReplicatedStorage", "Workspace", "ServerStorage", "Lighting", "Teams" } do
		env[name] = overrides[name] or dataModel:GetService(name)
	end
	for _, name in UNMOCKED do
		env[name] = overrides[name] or MockServices.unmocked(name)
	end

	local sharedModules = opts.sharedModules or {}
	function env.sharedModules(fileName: string): { [string]: any }
		return table.clone(sharedModules[fileName] or {})
	end

	function env.service(name: string): any
		if overrides[name] ~= nil then
			return overrides[name]
		end
		if table.find(Env.SERVICE_FIELDS, name) then
			return env[name]
		end
		error(
			"MockEnv: service '" .. name .. "' is not mocked; pass MockEnv.new({ services = { " .. name .. " = ... } })",
			2
		)
	end

	if opts.localPlayer then
		local player = playersControl:add(opts.localPlayer)
		playersControl:setLocalPlayer(player)
		network:setLocalPlayer(player)
		control.localPlayer = player
	end

	return env
end

return MockEnv
