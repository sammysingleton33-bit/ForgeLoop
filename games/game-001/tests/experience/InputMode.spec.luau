local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local D = require("./RulerDoubles")
local InputModeDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/InputModeController")

describe("InputModeController (G4.1, FL-0053)", function()
	local env, actions, registry, input

	beforeEach(function()
		env = MockEnv.new({ seed = 53, isServer = false, localPlayer = { userId = 5301 } })
		actions = D.actions()
		registry = D.boot(env, { input = { actions = actions }, ruler = { actions = actions }, camera = false })
		input = registry:get("InputModeController")
	end)

	it("starts in explore and fires changed once per real change, with the previous mode", function()
		local seen = {}
		input.changed:connect(function(mode, previous)
			table.insert(seen, `{previous}->{mode}`)
		end)
		expect(input.mode).toBe("explore")
		expect(input:set("build")).toBe(true)
		expect(input:set("build")).toBe(true)
		expect(input:set("explore")).toBe(true)
		expect(seen).toEqual({ "explore->build", "build->explore" })
	end)

	it("refuses unknown modes and 'command' (VS-2), logging each once", function()
		expect(input:set("command")).toBe(false)
		expect(input:set("command")).toBe(false)
		expect(input:set("fly")).toBe(false)
		expect(input.mode).toBe("explore")
		local warnings = 0
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "InputModeController: mode", 1, true) then
				warnings += 1
			end
		end
		expect(warnings).toBe(2)
		expect(env.mock:hasLog("warn", "'command' is not available in VS-1 (VS-2)")).toBe(true)
	end)

	it("applies a set() made inside a changed handler after every handler saw the current change", function()
		local first, second = {}, {}
		input.changed:connect(function(mode)
			table.insert(first, mode)
			if mode == "build" then
				input:set("explore") -- e.g. a menu that refuses build mode
			end
		end)
		input.changed:connect(function(mode)
			table.insert(second, mode)
		end)
		input:set("build")
		expect(first).toEqual({ "build", "explore" })
		expect(second).toEqual({ "build", "explore" })
		expect(input.mode).toBe("explore")
	end)

	it("accepts() gives a tap to the new mode's owner only after settleSec", function()
		expect(input:accepts("explore")).toBe(true)
		input:set("build")
		expect(input:accepts("build")).toBe(false) -- the Place-button tap itself
		expect(input:accepts("explore")).toBe(false)
		env.mock:advance(InputModeDef.DEFAULTS.settleSec + 0.01)
		expect(input:accepts("build")).toBe(true)
		expect(input:accepts("explore")).toBe(false)
	end)

	it("binds X / gamepad B only while in build mode; pressing it returns to explore", function()
		expect(actions.bound[InputModeDef.ACTION]).toBeNil()
		input:set("build")
		local bound = actions.bound[InputModeDef.ACTION]
		expect(bound ~= nil).toBe(true)
		expect(bound.keys).toEqual({ Enum.KeyCode.X, Enum.KeyCode.ButtonB })
		expect(actions:press(InputModeDef.ACTION, Enum.UserInputState.End)).toBe(Enum.ContextActionResult.Pass)
		expect(input.mode).toBe("build")
		expect(actions:press(InputModeDef.ACTION, Enum.UserInputState.Begin)).toBe(Enum.ContextActionResult.Sink)
		expect(input.mode).toBe("explore")
		expect(actions.bound[InputModeDef.ACTION]).toBeNil()
	end)

	it("works without ContextActionService (headless boot): set() still switches, keys are skipped", function()
		local bare = MockEnv.new({ seed = 54, isServer = false, localPlayer = { userId = 5302 } })
		local reg = D.boot(bare, { camera = false })
		local controller = reg:get("InputModeController")
		expect(controller:set("build")).toBe(true)
		expect(controller.mode).toBe("build")
		expect(bare.mock:hasLog("info", "InputModeController: no ContextActionService")).toBe(true)
		expect(bare.mock.threadErrors).toEqual({})
	end)
end)
