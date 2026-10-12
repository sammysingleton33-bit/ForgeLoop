--!strict
--[[
	StateMachine — declared states and transitions with guards, enter/exit hooks and a change signal.

	API
		StateMachine.new({
			initial = "Lobby",
			states = { Lobby = { onEnter = fn?, onExit = fn? }, Active = {}, ... },
			transitions = { { from = "Lobby", to = "Active", guard = fn? }, ... },
			context = any?,                 -- passed as the first argument to guards and hooks
		}): StateMachine
		machine:state(): string
		machine:can(to: string, ...any): boolean
		machine:transition(to: string, ...any): boolean
		machine.changed: Signal             -- fires (newState, oldState) after every change
		machine:destroy()                   -- disconnects every `changed` handler

	Callbacks
		guard(context, ...)      -> boolean  `...` = the extra arguments of can()/transition()
		onExit(context, to, ...)             runs on the state being left
		onEnter(context, from, ...)          runs on the state being entered

	Semantics
		- new() validates the declaration and errors on: unknown initial state, a transition naming
		  an undeclared state, a duplicate from -> to pair, or a hook/guard that is not a function.
		  new() does not run the initial state's onEnter and does not fire `changed`.
		- transition(to, ...):
		    * errors when `to` is not a declared state, or when no transition from the current state
		      to `to` is declared ("illegal transition A -> C"); the state does not change;
		    * returns false (no error, no hooks, no signal) when the transition's guard returns a
		      falsy value;
		    * otherwise runs onExit of the old state, switches state(), runs onEnter of the new state,
		      fires changed(new, old) and returns true. A self-transition (A -> A) runs only when
		      declared and then runs both hooks.
		- can(to, ...) is true when a transition from the current state to `to` is declared and its
		  guard (if any) passes. It never errors for unknown states. Guards should be pure: can()
		  calls them too.
		- Re-entrancy: calling transition() from inside a guard, onExit or onEnter raises an error
		  ("re-entrant or concurrent transition"). It is not queued. Guards and hooks must not
		  yield: a transition started by another thread while a hook is suspended is refused the same
		  way. Defer it (task.defer / env.spawn after a
		  wait) or call it from a `changed` handler: `changed` fires after the transition finished,
		  so handlers may transition; handlers after that one still receive the (new, old) pair of
		  their own event while state() has already moved on.
		- Hook errors propagate out of transition() (prefixed with the transition) after the machine
		  is unlocked. onExit failing leaves the old state (no signal). onEnter failing leaves the new
		  state; `changed` still fires before the error is rethrown, so listeners match state().
]]

local Signal = require("./Signal")

export type StateDef = {
	onEnter: ((context: any, from: string, ...any) -> ())?,
	onExit: ((context: any, to: string, ...any) -> ())?,
}

export type TransitionDef = {
	from: string,
	to: string,
	guard: ((context: any, ...any) -> boolean)?,
}

export type Options = {
	initial: string,
	states: { [string]: StateDef },
	transitions: { TransitionDef },
	context: any?,
}

export type StateMachine = {
	state: (self: StateMachine) -> string,
	can: (self: StateMachine, to: string, ...any) -> boolean,
	transition: (self: StateMachine, to: string, ...any) -> boolean,
	destroy: (self: StateMachine) -> (),
	changed: Signal.Signal,
}

local StateMachine = {}
StateMachine.__index = StateMachine

local function fail(message: string)
	error("StateMachine.new: " .. message, 3)
end

function StateMachine.new(options: Options): StateMachine
	if type(options) ~= "table" then
		fail("expected an options table { initial, states, transitions }")
	end
	if type(options.states) ~= "table" then
		fail("states must be a table { [name] = { onEnter?, onExit? } }")
	end
	local states: { [string]: StateDef } = {}
	for name, def in options.states do
		if type(name) ~= "string" or name == "" then
			fail("state names must be non-empty strings")
		end
		if type(def) ~= "table" then
			fail(`state '{name}' must be a table (use an empty table for a state without hooks)`)
		end
		for _, hook in { "onEnter", "onExit" } do
			if def[hook] ~= nil and type(def[hook]) ~= "function" then
				fail(`state '{name}'.{hook} must be a function`)
			end
		end
		states[name] = def
	end
	if type(options.initial) ~= "string" or states[options.initial] == nil then
		fail(`initial state '{tostring(options.initial)}' is not declared in states`)
	end
	if type(options.transitions) ~= "table" then
		fail("transitions must be a list of { from, to, guard? }")
	end
	local edges: { [string]: { [string]: TransitionDef } } = {}
	for i, t in options.transitions do
		if type(i) ~= "number" or type(t) ~= "table" then
			fail("transitions must be a list of { from, to, guard? }")
		end
		if type(t.from) ~= "string" or states[t.from] == nil then
			fail(`transition {i}: from '{tostring(t.from)}' is not a declared state`)
		end
		if type(t.to) ~= "string" or states[t.to] == nil then
			fail(`transition {i}: to '{tostring(t.to)}' is not a declared state`)
		end
		if t.guard ~= nil and type(t.guard) ~= "function" then
			fail(`transition {t.from} -> {t.to}: guard must be a function`)
		end
		edges[t.from] = edges[t.from] or {}
		if edges[t.from][t.to] then
			fail(`duplicate transition {t.from} -> {t.to}`)
		end
		edges[t.from][t.to] = t
	end
	local self = setmetatable({
		changed = Signal.new(),
		_state = options.initial,
		_states = states,
		_edges = edges,
		_context = options.context,
		_busy = nil :: string?, -- "A -> B" while a guard or hook of that transition runs
	}, StateMachine)
	return (self :: any) :: StateMachine
end

function StateMachine.state(self: any): string
	return self._state
end

local function edgeFrom(self: any, to: any): TransitionDef?
	local fromCurrent = self._edges[self._state]
	return if fromCurrent then fromCurrent[to] else nil
end

-- Runs fn(...) with the machine locked; returns ok, err (errors are caught so the lock is released).
local function locked(self: any, label: string, fn: (...any) -> ...any, ...: any): (boolean, any)
	self._busy = label
	local results = table.pack(pcall(fn, ...))
	self._busy = nil
	return table.unpack(results, 1, results.n)
end

function StateMachine.can(self: any, to: string, ...: any): boolean
	if self._busy then
		return false
	end
	local edge = edgeFrom(self, to)
	if edge == nil then
		return false
	end
	if edge.guard == nil then
		return true
	end
	local ok, result = locked(self, `{self._state} -> {to}`, edge.guard, self._context, ...)
	if not ok then
		error(`StateMachine: guard of {self._state} -> {to} failed: {tostring(result)}`, 2)
	end
	return result and true or false
end

function StateMachine.transition(self: any, to: string, ...: any): boolean
	local from: string = self._state
	if self._busy then
		error(
			`StateMachine: re-entrant or concurrent transition to '{tostring(to)}' requested while a guard or hook of `
				.. `{self._busy}; transitions are not queued — defer it or transition from a changed handler`,
			2
		)
	end
	if type(to) ~= "string" or self._states[to] == nil then
		error(`StateMachine: unknown state '{tostring(to)}' (illegal transition {from} -> {tostring(to)})`, 2)
	end
	local edge = edgeFrom(self, to)
	if edge == nil then
		error(`StateMachine: illegal transition {from} -> {to} (not declared)`, 2)
	end
	local label = `{from} -> {to}`
	local edgeDef = edge :: TransitionDef
	if edgeDef.guard then
		local ok, allowed = locked(self, label, edgeDef.guard, self._context, ...)
		if not ok then
			error(`StateMachine: guard of {label} failed: {tostring(allowed)}`, 2)
		end
		if not allowed then
			return false
		end
	end
	local onExit = self._states[from].onExit
	if onExit then
		local ok, err = locked(self, label, onExit, self._context, to, ...)
		if not ok then
			error(`StateMachine: onExit('{from}') failed during {label}: {tostring(err)}`, 2)
		end
	end
	self._state = to
	local onEnter = self._states[to].onEnter
	local enterOk, enterErr = true, nil
	if onEnter then
		enterOk, enterErr = locked(self, label, onEnter, self._context, from, ...)
	end
	self.changed:fire(to, from)
	if not enterOk then
		error(`StateMachine: onEnter('{to}') failed during {label}: {tostring(enterErr)}`, 2)
	end
	return true
end

function StateMachine.destroy(self: any)
	self.changed:disconnectAll()
end

return StateMachine
