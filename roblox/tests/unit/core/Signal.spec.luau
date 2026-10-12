local T = require("../../harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

describe("Core/Signal", function()
	local reported
	local previousReporter

	beforeEach(function()
		reported = {}
		previousReporter = Signal.setErrorReporter(function(message)
			table.insert(reported, message)
		end)
	end)

	afterEach(function()
		Signal.setErrorReporter(previousReporter)
	end)

	it("calls handlers in connect order with every argument", function()
		local signal = Signal.new()
		local calls = {}
		signal:connect(function(a, b, c)
			table.insert(calls, { "first", a, b, c })
		end)
		signal:connect(function(a, b, c)
			table.insert(calls, { "second", a, b, c })
		end)
		signal:fire(1, nil, "x")
		expect(calls).toEqual({ { "first", 1, nil, "x" }, { "second", 1, nil, "x" } })
	end)

	it("once() runs a handler a single time and marks it disconnected", function()
		local signal = Signal.new()
		local count = 0
		local connection = signal:once(function()
			count += 1
		end)
		signal:fire()
		signal:fire()
		expect(count).toBe(1)
		expect(connection.connected).toBe(false)
	end)

	it("disconnect() stops delivery and is idempotent", function()
		local signal = Signal.new()
		local count = 0
		local connection = signal:connect(function()
			count += 1
		end)
		signal:fire()
		connection:disconnect()
		connection:disconnect()
		signal:fire()
		expect(count).toBe(1)
		expect(connection.connected).toBe(false)
	end)

	it("skips a handler disconnected during fire and defers one connected during fire", function()
		local signal = Signal.new()
		local order = {}
		local second
		signal:connect(function()
			table.insert(order, "a")
			second:disconnect()
			signal:connect(function()
				table.insert(order, "late")
			end)
		end)
		second = signal:connect(function()
			table.insert(order, "b")
		end)
		signal:fire()
		expect(order).toEqual({ "a" })
		signal:fire()
		expect(order).toEqual({ "a", "a", "late" })
	end)

	it("isolates handlers: an erroring handler is reported and the others still run", function()
		local signal = Signal.new()
		local ran = {}
		signal:connect(function()
			table.insert(ran, 1)
		end)
		signal:connect(function()
			error("handler two broke")
		end)
		signal:connect(function()
			table.insert(ran, 3)
		end)
		expect(function()
			signal:fire()
		end).never.toThrow()
		expect(ran).toEqual({ 1, 3 })
		expect(#reported).toBe(1)
		expect(reported[1]).toContain("handler two broke")
	end)

	it("a yielding handler does not block the handlers after it", function()
		local signal = Signal.new()
		local ran = {}
		local parked
		signal:connect(function()
			parked = coroutine.running()
			coroutine.yield()
			table.insert(ran, "resumed")
		end)
		signal:connect(function()
			table.insert(ran, "second")
		end)
		signal:fire()
		expect(ran).toEqual({ "second" })
		coroutine.resume(parked)
		expect(ran).toEqual({ "second", "resumed" })
	end)

	it("an error raised after a handler yielded and was resumed is still reported", function()
		local signal = Signal.new()
		local parked
		signal:connect(function()
			parked = coroutine.running()
			coroutine.yield()
			error("broke after resume")
		end)
		signal:fire()
		expect(#reported).toBe(0)
		local ok = coroutine.resume(parked)
		expect(ok).toBe(true) -- the handler's own wrapper caught it
		expect(#reported).toBe(1)
		expect(reported[1]).toContain("broke after resume")
	end)

	it("wait() yields the running coroutine until the next fire and returns its arguments", function()
		local signal = Signal.new()
		local received
		local thread = coroutine.create(function()
			received = table.pack(signal:wait())
		end)
		coroutine.resume(thread)
		expect(coroutine.status(thread)).toBe("suspended")
		signal:fire("go", 42)
		expect(coroutine.status(thread)).toBe("dead")
		expect(received.n).toBe(2)
		expect(received[1]).toBe("go")
		expect(received[2]).toBe(42)
	end)

	it("disconnectAll() drops every connection", function()
		local signal = Signal.new()
		local count = 0
		local a = signal:connect(function()
			count += 1
		end)
		signal:connect(function()
			count += 1
		end)
		signal:disconnectAll()
		signal:fire()
		expect(count).toBe(0)
		expect(a.connected).toBe(false)
	end)

	it("Signal.is recognises signals only", function()
		expect(Signal.is(Signal.new())).toBe(true)
		expect(Signal.is({})).toBe(false)
		expect(Signal.is(nil)).toBe(false)
	end)

	it("connect() rejects a non-function handler", function()
		expect(function()
			Signal.new():connect(nil :: any)
		end).toThrow("expects a function")
	end)
end)
