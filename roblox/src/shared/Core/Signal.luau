--!strict
--[[
	Signal — a small synchronous signal used by GameEvents and services (runs in Roblox and Lune).

	API
		Signal.new(): Signal
		signal:connect(handler: (...any) -> ()): Connection
		signal:once(handler: (...any) -> ()): Connection   -- disconnects itself before its first call
		signal:fire(...any)                                 -- calls handlers now, in connect order
		signal:wait(): ...any                               -- yields the running coroutine until the next fire
		signal:disconnectAll()
		connection.connected: boolean, connection:disconnect()  (idempotent)
		Signal.is(value): boolean
		Signal.setErrorReporter(fn: (message: string) -> ()): previousReporter

	Semantics
		- Each handler runs in its own coroutine, immediately, until it finishes or yields
		  (a yielding handler does not delay the others; the task scheduler resumes it later).
		- Handler isolation: an error in one handler is reported (default: warn with traceback) and
		  the remaining handlers still run. fire() itself never throws because of a handler. This
		  also holds for errors raised after the handler yielded and was resumed later.
		- The Lune test harness (roblox/tests/harness/run.luau) calls setErrorReporter so a handler
		  error fails the running test: keep setErrorReporter when refactoring this module.
		- A handler connected during fire() first runs on the next fire(); a handler disconnected
		  during fire() before its turn is skipped.
]]

export type Connection = {
	connected: boolean,
	disconnect: (self: Connection) -> (),
}

export type Signal = {
	connect: (self: Signal, handler: (...any) -> ()) -> Connection,
	once: (self: Signal, handler: (...any) -> ()) -> Connection,
	fire: (self: Signal, ...any) -> (),
	wait: (self: Signal) -> ...any,
	disconnectAll: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

local ConnectionClass = {}
ConnectionClass.__index = ConnectionClass

local function defaultReporter(message: string)
	warn("[Signal] handler error: " .. message)
end

local reporter: (string) -> () = defaultReporter

-- Runs a handler inside its coroutine; xpcall here (not around resume) also catches errors that
-- happen after the handler yielded and was resumed by the task scheduler.
local function runHandler(handler: (...any) -> (), ...: any)
	local ok, err = xpcall(handler :: any, function(e: any): any
		return debug.traceback(tostring(e), 2)
	end, ...)
	if not ok then
		reporter(tostring(err))
	end
end

function Signal.setErrorReporter(fn: (string) -> ()): (string) -> ()
	local previous = reporter
	reporter = fn
	return previous
end

function Signal.new(): Signal
	local self = setmetatable({ _connections = {} }, Signal)
	return (self :: any) :: Signal
end

function Signal.is(value: any): boolean
	return type(value) == "table" and getmetatable(value) == Signal
end

function ConnectionClass.disconnect(self: any)
	if not self.connected then
		return
	end
	self.connected = false
	local list = self._signal._connections
	local index = table.find(list, self)
	if index then
		table.remove(list, index)
	end
end

local function addConnection(self: any, handler: (...any) -> (), once: boolean): Connection
	assert(type(handler) == "function", "Signal:connect expects a function")
	local connection = setmetatable({
		connected = true,
		_signal = self,
		_handler = handler,
		_once = once,
	}, ConnectionClass)
	table.insert(self._connections, connection)
	return (connection :: any) :: Connection
end

function Signal.connect(self: any, handler: (...any) -> ()): Connection
	return addConnection(self, handler, false)
end

function Signal.once(self: any, handler: (...any) -> ()): Connection
	return addConnection(self, handler, true)
end

function Signal.fire(self: any, ...: any)
	local snapshot: { any } = table.clone(self._connections)
	for _, connection in snapshot do
		if not connection.connected then
			continue
		end
		if connection._once then
			connection:disconnect()
		end
		local thread = coroutine.create(runHandler)
		local ok, err = coroutine.resume(thread, connection._handler, ...)
		if not ok then
			reporter(debug.traceback(thread, tostring(err)))
		end
	end
end

function Signal.wait(self: any): ...any
	local thread = coroutine.running()
	addConnection(self, function(...)
		task.spawn(thread, ...)
	end, true)
	return coroutine.yield()
end

function Signal.disconnectAll(self: any)
	for _, connection in self._connections do
		connection.connected = false
	end
	table.clear(self._connections)
end

return Signal
