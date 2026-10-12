--[[
	MockSignal — stand-in for RBXScriptSignal / RBXScriptConnection (engine events such as
	Players.PlayerAdded or RemoteEvent.OnServerEvent).

	Imitates: creator-docs content/en-us/reference/engine/datatypes/RBXScriptSignal.yaml
	(:Connect(fn) -> connection with .Connected and :Disconnect(), :Once(fn), :Wait()).

	Engine-side control (tests and other mocks only — not Roblox API):
		signal:Fire(...)              -- runs every handler; each in its own thread via `spawn`
		signal:connectionCount() -> number

	MockSignal.new({ spawn = fn?, name = string?, onConnect = fn? }): handlers run through
	`spawn(handler, ...)`; onConnect(signal) runs after every Connect/Once (remote queues use it). MockEnv passes
	env.spawn so handlers that call env.wait suspend until env.mock:advance(). Without `spawn`,
	each handler runs immediately in its own coroutine. Errors in handlers fail the running test
	(Test.reportUnhandledError), like an error in the engine's own handler threads would show.
]]

local Test = require("../harness/Test")

local MockSignal = {}
MockSignal.__index = MockSignal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._connections
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

-- Errors are caught inside the thread, so one raised after a yield and a later resume is reported too.
local function defaultSpawn(fn, ...)
	local origin = Test.captureOrigin()
	local thread = coroutine.create(function(...)
		local ok, err = xpcall(fn, function(e)
			return debug.traceback(tostring(e), 2)
		end, ...)
		if not ok then
			Test.reportUnhandledError(err, origin)
		end
	end)
	coroutine.resume(thread, ...)
end

function MockSignal.new(options: { spawn: ((...any) -> ())?, name: string?, onConnect: ((any) -> ())? }?)
	return setmetatable({
		_connections = {},
		_spawn = (options and options.spawn) or defaultSpawn,
		_name = (options and options.name) or "Signal",
		_onConnect = options and options.onConnect,
	}, MockSignal)
end

local function connect(self, fn, once: boolean)
	assert(type(fn) == "function", `{self._name}:Connect expects a function`)
	local connection = setmetatable({ Connected = true, _signal = self, _fn = fn, _once = once }, Connection)
	table.insert(self._connections, connection)
	if self._onConnect then
		self._onConnect(self)
	end
	return connection
end

function MockSignal:Connect(fn)
	return connect(self, fn, false)
end

function MockSignal:Once(fn)
	return connect(self, fn, true)
end

function MockSignal:Wait()
	local thread = coroutine.running()
	connect(self, function(...)
		local ok, err = coroutine.resume(thread, ...)
		if not ok then
			Test.reportUnhandledError(debug.traceback(thread, tostring(err)))
		end
	end, true)
	return coroutine.yield()
end

function MockSignal:Fire(...)
	for _, connection in table.clone(self._connections) do
		if connection.Connected then
			if connection._once then
				connection:Disconnect()
			end
			self._spawn(connection._fn, ...)
		end
	end
end

function MockSignal:connectionCount(): number
	return #self._connections
end

return MockSignal
