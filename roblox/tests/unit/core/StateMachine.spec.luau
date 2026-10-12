local T = require("../../harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local StateMachine = require("@game/ReplicatedStorage/Forge/Core/StateMachine")

local function build(overrides: { [string]: any }?)
	local log = {}
	local function hooks(name)
		return {
			onEnter = function(ctx, from, ...)
				table.insert(log, { "enter", name, from, ctx, ... })
			end,
			onExit = function(ctx, to, ...)
				table.insert(log, { "exit", name, to, ctx, ... })
			end,
		}
	end
	local options = {
		initial = "Lobby",
		states = { Lobby = hooks("Lobby"), Countdown = hooks("Countdown"), Active = hooks("Active") },
		transitions = {
			{ from = "Lobby", to = "Countdown" },
			{ from = "Countdown", to = "Active" },
			{ from = "Countdown", to = "Lobby" },
			{ from = "Active", to = "Lobby" },
		},
		context = "ctx",
	}
	for k, v in overrides or {} do
		options[k] = v
	end
	return StateMachine.new(options), log
end

describe("Core/StateMachine", function()
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

	it("starts in the initial state without running hooks or firing changed", function()
		local machine, log = build()
		expect(machine:state()).toBe("Lobby")
		expect(#log).toBe(0)
	end)

	it("runs exit before enter, passes context and arguments, then fires changed(new, old)", function()
		local machine, log = build()
		local changes = {}
		machine.changed:connect(function(new, old)
			table.insert(changes, { new, old, machine:state() })
		end)
		expect(machine:transition("Countdown", 10)).toBe(true)
		expect(machine:state()).toBe("Countdown")
		expect(log).toEqual({
			{ "exit", "Lobby", "Countdown", "ctx", 10 },
			{ "enter", "Countdown", "Lobby", "ctx", 10 },
		})
		expect(changes).toEqual({ { "Countdown", "Lobby", "Countdown" } })
	end)

	it("errors on an illegal transition, naming from and to, and does not change state", function()
		local machine, log = build()
		expect(function()
			machine:transition("Active")
		end).toThrow("illegal transition Lobby -> Active")
		expect(function()
			machine:transition("Results")
		end).toThrow("unknown state 'Results'")
		expect(machine:state()).toBe("Lobby")
		expect(#log).toBe(0)
	end)

	it("a self-transition is illegal unless declared", function()
		local machine = build()
		expect(function()
			machine:transition("Lobby")
		end).toThrow("illegal transition Lobby -> Lobby")
		local looping, log = build({
			transitions = { { from = "Lobby", to = "Lobby" } },
		})
		expect(looping:transition("Lobby")).toBe(true)
		expect(#log).toBe(2)
	end)

	it("returns false without hooks or signal when the guard rejects", function()
		local allow = false
		local guardArgs
		local machine, log = build({
			transitions = {
				{
					from = "Lobby",
					to = "Countdown",
					guard = function(ctx, ...)
						guardArgs = { ctx, ... }
						return allow
					end,
				},
			},
		})
		local fired = 0
		machine.changed:connect(function()
			fired += 1
		end)
		expect(machine:can("Countdown")).toBe(false)
		expect(machine:transition("Countdown", "why")).toBe(false)
		expect(guardArgs).toEqual({ "ctx", "why" })
		expect(machine:state()).toBe("Lobby")
		expect(#log).toBe(0)
		expect(fired).toBe(0)
		allow = true
		expect(machine:can("Countdown")).toBe(true)
		expect(machine:transition("Countdown")).toBe(true)
		expect(fired).toBe(1)
	end)

	it("can() reports declared transitions from the current state and never errors", function()
		local machine = build()
		expect(machine:can("Countdown")).toBe(true)
		expect(machine:can("Active")).toBe(false)
		expect(machine:can("Nope")).toBe(false)
		expect(machine:can(nil :: any)).toBe(false)
	end)

	it("a transition requested inside a hook errors clearly (not queued) and leaves a usable machine", function()
		local machine
		machine = StateMachine.new({
			initial = "A",
			states = {
				A = {},
				B = {
					onEnter = function()
						machine:transition("C")
					end,
				},
				C = {},
			},
			transitions = { { from = "A", to = "B" }, { from = "B", to = "C" } },
		})
		expect(function()
			machine:transition("B")
		end).toThrow("re-entrant or concurrent transition to 'C'")
		expect(machine:state()).toBe("B") -- onEnter failed after the switch; not queued to C
		expect(machine:transition("C")).toBe(true) -- unlocked again
	end)

	it("a transition requested inside a guard errors", function()
		local machine
		machine = StateMachine.new({
			initial = "A",
			states = { A = {}, B = {} },
			transitions = {
				{
					from = "A",
					to = "B",
					guard = function()
						machine:transition("B")
						return true
					end,
				},
			},
		})
		expect(function()
			machine:transition("B")
		end).toThrow("re-entrant or concurrent transition")
		expect(machine:state()).toBe("A")
	end)

	it("a changed handler may transition: the machine is unlocked when changed fires", function()
		local machine = build()
		machine.changed:connect(function(new)
			if new == "Countdown" then
				machine:transition("Active")
			end
		end)
		machine:transition("Countdown")
		expect(machine:state()).toBe("Active")
		expect(#reported).toBe(0)
	end)

	it("onExit failing keeps the old state and fires nothing", function()
		local fired = 0
		local machine = StateMachine.new({
			initial = "A",
			states = {
				A = {
					onExit = function()
						error("exit broke")
					end,
				},
				B = {},
			},
			transitions = { { from = "A", to = "B" } },
		})
		machine.changed:connect(function()
			fired += 1
		end)
		expect(function()
			machine:transition("B")
		end).toThrow("onExit('A') failed during A -> B")
		expect(machine:state()).toBe("A")
		expect(fired).toBe(0)
	end)

	it("onEnter failing keeps the new state, still fires changed, then rethrows", function()
		local seen
		local machine = StateMachine.new({
			initial = "A",
			states = {
				A = {},
				B = {
					onEnter = function()
						error("enter broke")
					end,
				},
			},
			transitions = { { from = "A", to = "B" } },
		})
		machine.changed:connect(function(new, old)
			seen = { new, old }
		end)
		expect(function()
			machine:transition("B")
		end).toThrow("enter broke")
		expect(machine:state()).toBe("B")
		expect(seen).toEqual({ "B", "A" })
	end)

	it("rejects bad declarations at construction", function()
		expect(function()
			StateMachine.new({ initial = "X", states = { A = {} }, transitions = {} })
		end).toThrow("initial state 'X' is not declared")
		expect(function()
			StateMachine.new({ initial = "A", states = { A = {} }, transitions = { { from = "A", to = "B" } } })
		end).toThrow("to 'B' is not a declared state")
		expect(function()
			StateMachine.new({
				initial = "A",
				states = { A = {}, B = {} },
				transitions = { { from = "A", to = "B" }, { from = "A", to = "B" } },
			})
		end).toThrow("duplicate transition A -> B")
		expect(function()
			StateMachine.new({ initial = "A", states = { A = { onEnter = 5 } }, transitions = {} } :: any)
		end).toThrow("onEnter must be a function")
		expect(function()
			StateMachine.new({
				initial = "A",
				states = { A = {}, B = {} },
				transitions = { { from = "A", to = "B", guard = true } },
			} :: any)
		end).toThrow("guard must be a function")
	end)

	it("destroy() disconnects changed handlers", function()
		local machine = build()
		local fired = 0
		machine.changed:connect(function()
			fired += 1
		end)
		machine:destroy()
		machine:transition("Countdown")
		expect(fired).toBe(0)
	end)
end)
