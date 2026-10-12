--[[
	Test — describe/it/expect for FORGELOOP Lune specs (roblox/tests/unit/**/*.spec.luau).

	Usage in a spec:
		local T = require("../../harness/Test")
		local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

		describe("Thing", function()
			beforeEach(function() ... end)
			it("does X", function()
				expect(1 + 1).toBe(2)
				expect({ a = 1 }).toEqual({ a = 1 })
				expect(0.1 + 0.2).toBeNear(0.3)
				expect(function() error("boom") end).toThrow("boom")
				expect(nil).toBeNil()
				expect(5).never.toBe(6)
			end)
		end)

	Matchers: toBe (==, NaN equals NaN), toEqual (deep), toBeNear(expected, tolerance = 1e-6),
	toThrow(substring?), toBeNil, toBeTruthy, toBeFalsy, toContain(item or substring),
	toHaveLength(n), toBeGreaterThan, toBeGreaterThanOrEqual, toBeLessThan, toBeLessThanOrEqual,
	toBeA(typeofName). Every matcher has a `.never` form.

	Hooks: beforeEach/afterEach (scoped to the enclosing describe; outer hooks run first/last).
	No skip/only/todo: every registered test runs. A test fails when it throws, when an
	expectation fails, when it yields and is not resumed within the timeout, or when a thread it
	spawned reports an unhandled error (Test.reportUnhandledError) — also after the test body
	returned: errors are charged to the test that spawned the thread (captureOrigin), even when
	they arrive while a later test of the same spec file runs. Errors from a thread whose spec
	file has already finished are reported at the end of the run ("late errors").

	Test.root: absolute repository root (set by the runner) for specs that read files.
	Scheduler support (MockEnv): Test.isDriverThread(thread) is true for the thread that runs the
	current test body and its hooks, and for the runner's own thread (spec-file load time).
	Spawn support (Globals, MockEnv): Test.captureOrigin() -> origin, then
	Test.reportUnhandledError(message, origin?).
	Runner API (used by run.luau): Test._beginFile(displayName), Test._run({ timeout, pending })
	-> results, Test._lateErrors() -> { { origin: string, message: string } }.
]]

local task = require("@lune/task")

local Format = require("./Format")

local Test = {}

local EXPECT_PREFIX = "Expectation failed: "

local root
local currentSuite
local collecting = false
local runningState = nil -- the running test's state { name, file, errors, thread, done }
local fileErrors = {}
local fileToken = nil -- origin for threads spawned while a spec file loads (outside any test)
local currentFile = "?"
local runnerThread = nil
local lateErrors = {}

local function newSuite(name: string, parent)
	return { kind = "suite", name = name, parent = parent, children = {}, beforeEach = {}, afterEach = {} }
end

local function callerLocation(): string
	for level = 2, 40 do
		local source, line = debug.info(level, "sl")
		if source == nil then
			break
		end
		local s = string.gsub(source, "\\", "/")
		if s ~= "[C]" and not string.find(s, "harness/Test", 1, true) then
			s = string.gsub(s, "^@", "")
			return `{s}:{line}`
		end
	end
	return "<unknown location>"
end

local function errorHandler(err: any): string
	local message = tostring(err)
	if string.sub(message, 1, #EXPECT_PREFIX) == EXPECT_PREFIX then
		return message
	end
	local trace = debug.traceback("", 2)
	local kept = {}
	for line in string.gmatch(trace, "[^\n]+") do
		if
			not string.find(line, "harness/Test", 1, true)
			and not string.find(line, "harness/run", 1, true)
			and not string.find(line, "[C]", 1, true)
			and string.match(line, "%S")
		then
			table.insert(kept, "    " .. line)
		end
	end
	if #kept > 0 then
		return message .. "\n" .. table.concat(kept, "\n")
	end
	return message
end

-- ---------------------------------------------------------------- registration

function Test.describe(name: string, fn: () -> ())
	assert(collecting, "describe() must be called while a spec file loads, not inside it()")
	assert(type(name) == "string" and type(fn) == "function", "describe(name, fn)")
	local suite = newSuite(name, currentSuite)
	table.insert(currentSuite.children, suite)
	local previous = currentSuite
	currentSuite = suite
	local ok, err = xpcall(fn, errorHandler)
	currentSuite = previous
	if not ok then
		table.insert(suite.children, { kind = "broken", name = "(describe body)", error = err })
	end
end

function Test.it(name: string, fn: () -> ())
	assert(collecting, "it() must be called while a spec file loads (inside describe), not inside another it()")
	assert(type(name) == "string" and type(fn) == "function", "it(name, fn)")
	table.insert(currentSuite.children, { kind = "test", name = name, fn = fn, suite = currentSuite })
end

function Test.beforeEach(fn: () -> ())
	assert(collecting, "beforeEach() must be called inside describe while the spec file loads")
	table.insert(currentSuite.beforeEach, fn)
end

function Test.afterEach(fn: () -> ())
	assert(collecting, "afterEach() must be called inside describe while the spec file loads")
	table.insert(currentSuite.afterEach, fn)
end

-- The origin of a thread about to be spawned: the running test, or the loading spec file.
function Test.captureOrigin(): any
	return runningState or fileToken
end

-- Spawned threads (task.spawn via the harness, MockEnv.spawn, Signal handlers, mock signals)
-- report errors here. With an origin, the error is charged to the test (or file) that spawned
-- the thread; without one, to the test running now.
function Test.reportUnhandledError(message: string, origin: any?)
	local text = "unhandled error in a spawned thread: " .. tostring(message)
	local target = origin or runningState or fileToken
	if target == nil then
		table.insert(lateErrors, { origin = "(outside any spec file)", message = text })
	elseif target.file ~= currentFile or target.closed then
		table.insert(lateErrors, { origin = target.file .. " :: " .. target.name, message = text })
	elseif target.kind == "file" then
		table.insert(fileErrors, text)
	else
		if target ~= runningState and runningState ~= nil then
			text ..= ` (reported while '{runningState.name}' was running)`
		end
		table.insert(target.errors, text)
	end
end

-- True for the thread that drives virtual time: the running test body (and its hooks), or the
-- runner's own thread while a spec file loads. Every other thread is a "scheduled" thread.
function Test.isDriverThread(thread: thread): boolean
	if runningState ~= nil and not runningState.done then
		return thread == runningState.thread
	end
	return thread == runnerThread
end

-- ---------------------------------------------------------------- expectations

local function fail(message: string)
	error(EXPECT_PREFIX .. message .. "\n    at " .. callerLocation(), 0)
end

local function sameValue(a: any, b: any): boolean
	return a == b or (a ~= a and b ~= b)
end

local function deepEqual(a: any, b: any, path: string, seen: { [any]: any }): (boolean, string?)
	if sameValue(a, b) then
		return true, nil
	end
	if typeof(a) ~= typeof(b) then
		return false, `{path}: expected {Format.value(b)} ({typeof(b)}), received {Format.value(a)} ({typeof(a)})`
	end
	if type(a) ~= "table" then
		return false, `{path}: expected {Format.value(b)}, received {Format.value(a)}`
	end
	if seen[a] == b then
		return true, nil
	end
	seen[a] = b
	for k, v in next, b do
		local ok, msg = deepEqual(rawget(a, k), v, path .. "." .. tostring(k), seen)
		if not ok then
			return false, msg
		end
	end
	for k, v in next, a do
		if rawget(b, k) == nil then
			return false, `{path}.{tostring(k)}: unexpected key with value {Format.value(v)}`
		end
	end
	return true, nil
end

local function lengthOf(v: any): number?
	if type(v) == "string" or type(v) == "table" then
		return #v
	end
	return nil
end

local function makeMatchers(actual: any, negate: boolean)
	local m = {}
	local notText = if negate then " not" else ""
	local function check(pass: boolean, message: string)
		if pass == negate then
			fail(message)
		end
	end

	function m.toBe(expected: any)
		check(sameValue(actual, expected), `expected {Format.value(actual)}{notText} to be {Format.value(expected)}`)
	end
	function m.toEqual(expected: any)
		local ok, why = deepEqual(actual, expected, "value", {})
		if negate then
			check(ok, `expected {Format.value(actual)} not to deep-equal {Format.value(expected)}`)
		else
			check(
				ok,
				`deep equality failed at {why}\n    expected: {Format.value(expected)}\n    received: {Format.value(
					actual
				)}`
			)
		end
	end
	function m.toBeNear(expected: number, tolerance: number?)
		local tol = tolerance or 1e-6
		local ok = type(actual) == "number" and type(expected) == "number" and math.abs(actual - expected) <= tol
		check(ok, `expected {Format.value(actual)}{notText} to be within {tol} of {Format.value(expected)}`)
	end
	function m.toThrow(substring: string?)
		if type(actual) ~= "function" then
			fail(`toThrow expects a function, received {Format.value(actual)}`)
		end
		local ok, err = pcall(actual)
		local message = if ok then nil else tostring(err)
		if substring == nil then
			check(not ok, `expected function{notText} to throw` .. (if message then `, it threw: {message}` else ""))
		else
			local matched = message ~= nil and string.find(message, substring, 1, true) ~= nil
			check(
				matched,
				`expected function{notText} to throw an error containing {Format.value(substring)}; `
					.. (if message then `it threw: {message}` else "it did not throw")
			)
		end
	end
	function m.toBeNil()
		check(actual == nil, `expected {Format.value(actual)}{notText} to be nil`)
	end
	function m.toBeTruthy()
		check(not not actual, `expected {Format.value(actual)}{notText} to be truthy`)
	end
	function m.toBeFalsy()
		check(not actual, `expected {Format.value(actual)}{notText} to be falsy`)
	end
	function m.toContain(item: any)
		local found = false
		if type(actual) == "string" and type(item) == "string" then
			found = string.find(actual, item, 1, true) ~= nil
		elseif type(actual) == "table" then
			for _, v in actual do
				if sameValue(v, item) then
					found = true
					break
				end
			end
		else
			fail(`toContain expects a table or string, received {Format.value(actual)}`)
		end
		check(found, `expected {Format.value(actual)}{notText} to contain {Format.value(item)}`)
	end
	function m.toHaveLength(n: number)
		local len = lengthOf(actual)
		check(len == n, `expected length{notText} to be {n}, received length {tostring(len)} of {Format.value(actual)}`)
	end
	local function compare(name: string, op: (number, number) -> boolean, word: string)
		m[name] = function(expected: number)
			local ok = type(actual) == "number" and type(expected) == "number" and op(actual, expected)
			check(ok, `expected {Format.value(actual)}{notText} to be {word} {Format.value(expected)}`)
		end
	end
	compare("toBeGreaterThan", function(a, b)
		return a > b
	end, "greater than")
	compare("toBeGreaterThanOrEqual", function(a, b)
		return a >= b
	end, "greater than or equal to")
	compare("toBeLessThan", function(a, b)
		return a < b
	end, "less than")
	compare("toBeLessThanOrEqual", function(a, b)
		return a <= b
	end, "less than or equal to")
	function m.toBeA(typeName: string)
		check(typeof(actual) == typeName, `expected typeof {Format.value(actual)}{notText} to be {typeName}`)
	end
	return m
end

function Test.expect(actual: any)
	local positive = makeMatchers(actual, false)
	positive.never = makeMatchers(actual, true)
	return positive
end

-- ---------------------------------------------------------------- runner side

function Test._beginFile(displayName: string?)
	if fileToken then
		fileToken.closed = true
	end
	root = newSuite("", nil)
	currentSuite = root
	collecting = true
	runningState = nil
	fileErrors = {}
	currentFile = displayName or "?"
	fileToken = { kind = "file", file = currentFile, name = "(spec file load)", errors = fileErrors }
	runnerThread = coroutine.running()
end

local function fullName(node): string
	local parts = { node.name }
	local suite = node.suite or node.parent
	while suite and suite.parent do
		table.insert(parts, 1, suite.name)
		suite = suite.parent
	end
	return table.concat(parts, " > ")
end

local function collectHooks(suite, key: string): { () -> () }
	local chain = {}
	local s = suite
	while s do
		table.insert(chain, 1, s)
		s = s.parent
	end
	local hooks = {}
	if key == "beforeEach" then
		for _, item in chain do
			for _, h in item.beforeEach do
				table.insert(hooks, h)
			end
		end
	else
		for i = #chain, 1, -1 do
			for _, h in chain[i].afterEach do
				table.insert(hooks, h)
			end
		end
	end
	return hooks
end

-- Lets threads that are ready (deferred, spawned, short delays) run before results are taken,
-- so their errors land on the test that spawned them. `pending` counts guarded Lune threads that
-- have not finished; waiting for them is capped (a thread may legitimately loop forever).
local function drain(pending: (() -> number)?, cap: number)
	task.wait()
	if pending == nil then
		return
	end
	local started = os.clock()
	while pending() > 0 and os.clock() - started < cap do
		task.wait()
	end
end

local function runTest(node, timeout: number, pending: (() -> number)?)
	local state = { kind = "test", name = fullName(node), file = currentFile, done = false, errors = {} }
	runningState = state
	local befores = collectHooks(node.suite, "beforeEach")
	local afters = collectHooks(node.suite, "afterEach")
	local thread = coroutine.create(function()
		local ok, err = xpcall(function()
			for _, hook in befores do
				hook()
			end
			node.fn()
		end, errorHandler)
		if not ok then
			table.insert(state.errors, err)
		end
		for _, hook in afters do
			local hookOk, hookErr = xpcall(hook, errorHandler)
			if not hookOk then
				table.insert(state.errors, "afterEach: " .. hookErr)
			end
		end
		state.done = true
	end)
	state.thread = thread
	local resumed, resumeErr = coroutine.resume(thread)
	if not resumed then
		table.insert(state.errors, tostring(resumeErr))
		state.done = true
	end
	local started = os.clock()
	while not state.done do
		if os.clock() - started > timeout then
			table.insert(
				state.errors,
				`test yielded and did not finish within {timeout}s (a wait/Signal:wait that is never resumed? `
					.. "use MockEnv time control instead of real waits)"
			)
			state.done = true
			break
		end
		task.wait()
	end
	drain(pending, 0.1) -- errors from threads the test just spawned are still charged to it
	runningState = nil
	return state
end

function Test._run(options: { timeout: number?, pending: (() -> number)? }?)
	collecting = false
	local timeout = (options and options.timeout) or 5
	local pending = options and options.pending
	local states = {}
	local results = { tests = {}, fileErrors = fileErrors }
	local function visit(suite)
		for _, child in suite.children do
			if child.kind == "suite" then
				visit(child)
			elseif child.kind == "broken" then
				table.insert(states, {
					name = fullName({ name = child.name, suite = suite }),
					errors = { child.error },
				})
			else
				table.insert(states, runTest(child, timeout, pending))
			end
		end
	end
	visit(root)
	drain(pending, 1) -- last chance for this file's threads before its results are taken
	fileToken.closed = true
	for _, state in states do
		state.closed = true
		table.insert(results.tests, { name = state.name, ok = #state.errors == 0, errors = state.errors })
	end
	return results
end

-- Errors from threads whose spec file had already finished (see reportUnhandledError).
function Test._lateErrors(): { { origin: string, message: string } }
	return lateErrors
end

function Test._abortCollect()
	collecting = false
	if fileToken then
		fileToken.closed = true
	end
end

return Test
