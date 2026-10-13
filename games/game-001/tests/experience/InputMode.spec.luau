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

describe("InputModeController selection (G13.6, FL-0090)", function()
	local env, userInput, registry, input, picks, hit, world

	local function tag(instance, name)
		env.CollectionService:AddTag(instance, name)
		return instance
	end

	local function tap(x, y, moveTo, heldSec)
		userInput.InputBegan:Fire({ UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(x, y, 0) }, false)
		if heldSec then
			env.mock:advance(heldSec)
		end
		local up = moveTo or Vector2.new(x, y)
		userInput.InputEnded:Fire(
			{ UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(up.X, up.Y, 0) },
			false
		)
	end

	local function seen()
		local out = {}
		input.selected:connect(function(kind, id)
			table.insert(out, `{kind}:{tostring(id)}`)
		end)
		return out
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 61, isServer = false, localPlayer = { userId = 6101 } })
		userInput = D.userInput()
		picks = {} -- screen x -> entity id (EntityController:pick double)
		hit = nil
		world = env.newInstance("Folder")
		world.Parent = env.Workspace
		registry = D.boot(env, {
			input = {
				userInput = userInput,
				raycast = function()
					return hit
				end,
			},
			camera = false,
			extra = {
				{
					name = "EntityController",
					new = function()
						return {
							pick = function(_, screenPos)
								return picks[screenPos.X]
							end,
						}
					end,
				},
			},
		})
		input = registry:get("InputModeController")
	end)

	it("a tap on a citizen selects it through EntityController:pick, before any raycast", function()
		local log = seen()
		picks[100] = 42
		hit = env.newInstance("Part") -- would be "none"; the citizen wins
		tap(100, 200)
		expect(log).toEqual({ "citizen:42" })
		expect(input.selection.kind).toBe("citizen")
	end)

	it("a tap on a building part selects the building through an ancestor's BuildingId attribute", function()
		local log = seen()
		local model = env.newInstance("Model")
		model:SetAttribute("BuildingId", 17)
		model.Parent = world
		local wall = env.newInstance("Part")
		wall.Parent = model
		hit = wall
		tap(300, 200)
		expect(log).toEqual({ "building:17" })
	end)

	it("a tap on a plot marker selects the slot through the BuildSlot tag and its SlotId", function()
		local log = seen()
		local marker = tag(env.newInstance("Part"), "BuildSlot")
		marker:SetAttribute("SlotId", "crimson_s3")
		marker.Parent = world
		hit = marker
		tap(300, 200)
		hit = nil
		tap(310, 200) -- empty ground / sky: clears the selection
		expect(log).toEqual({ "slot:crimson_s3", "none:" })
	end)

	it("a tap on bare ground (an untagged part) fires none, so FORGE-03's panels close", function()
		local log = seen()
		input:select("building", 4)
		local ground = env.newInstance("Part")
		ground.Name = "Grass"
		ground.Parent = world
		hit = ground
		tap(300, 200)
		expect(log).toEqual({ "building:4", "none:" })
		expect(input.selection.kind).toBe("none")
	end)

	it("a drag (pan) or a long press is not a tap; GUI-handled input never selects", function()
		local log = seen()
		picks[100] = 7
		tap(100, 200, Vector2.new(100 + InputModeDef.DEFAULTS.tapPixels, 200))
		tap(100, 200, nil, InputModeDef.DEFAULTS.tapSec + 0.1)
		userInput.InputBegan:Fire(
			{ UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(100, 200, 0) },
			true
		)
		userInput.InputEnded:Fire(
			{ UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(100, 200, 0) },
			true
		)
		expect(log).toEqual({})
		tap(100, 200)
		expect(log).toEqual({ "citizen:7" })
	end)

	it("build mode clears the selection and taps do not select while placing", function()
		local log = seen()
		picks[100] = 9
		tap(100, 200)
		input:set("build")
		tap(100, 200)
		expect(log).toEqual({ "citizen:9", "none:" })
		input:set("explore")
		env.mock:advance(InputModeDef.DEFAULTS.settleSec + 0.01)
		tap(100, 200)
		expect(log).toEqual({ "citizen:9", "none:", "citizen:9" })
	end)

	it("back fires on gamepad B and Backspace, never on Esc or on a press a GUI handled (#126 L6)", function()
		local backs = 0
		input.back:connect(function()
			backs += 1
		end)
		local function press(key, processed)
			userInput.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = key }, processed)
		end
		press(Enum.KeyCode.ButtonB, false)
		press(Enum.KeyCode.Backspace, false)
		expect(backs).toBe(2)
		press(Enum.KeyCode.Escape, false) -- Roblox's menu key
		press(Enum.KeyCode.Backspace, true) -- typing in a TextBox
		press(Enum.KeyCode.ButtonB, true) -- leaving gamepad GUI selection
		press(Enum.KeyCode.X, false)
		expect(backs).toBe(2)
		expect(input.selection.kind).toBe("none") -- a key is never a tap
	end)

	it("back never fires in build mode, nor for the press that left it (settle window)", function()
		local backs = 0
		input.back:connect(function()
			backs += 1
		end)
		local function pressB()
			userInput.InputBegan:Fire(
				{ UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonB },
				false
			)
		end
		input:set("build")
		env.mock:advance(InputModeDef.DEFAULTS.settleSec + 0.01)
		pressB()
		expect(backs).toBe(0)
		input:set("explore") -- what the bound B does in build mode
		pressB()
		expect(backs).toBe(0)
		env.mock:advance(InputModeDef.DEFAULTS.settleSec + 0.01)
		pressB()
		expect(backs).toBe(1)
	end)

	it("selecting a citizen reports CitizenInspected to the onboarding (FL-0092)", function()
		local reports = {}
		local reg = D.boot(MockEnv.new({ seed = 62, isServer = false, localPlayer = { userId = 6102 } }), {
			input = { userInput = D.userInput() },
			camera = false,
			extra = {
				{
					name = "OnboardingController",
					new = function()
						return {
							report = function(_, action)
								table.insert(reports, action)
								return true
							end,
						}
					end,
				},
			},
		})
		local controller = reg:get("InputModeController")
		controller:select("building", 1)
		controller:select("citizen", 5)
		expect(reports).toEqual({ "CitizenInspected" })
	end)

	it("select() is the programmatic path and refuses unknown kinds", function()
		local log = seen()
		expect(input:select("building", 3)).toBe(true)
		expect(input:select("dragon", 1)).toBe(false)
		expect(log).toEqual({ "building:3" })
	end)

	it("resolveHit() stops after 8 levels and returns none for nil", function()
		expect(select(
			1,
			InputModeDef.resolveHit(nil, function()
				return false
			end)
		)).toBe("none")
		local top = env.newInstance("Model")
		top:SetAttribute("BuildingId", 1)
		local current = top
		for _ = 1, 9 do
			local child = env.newInstance("Folder")
			child.Parent = current
			current = child
		end
		expect(select(
			1,
			InputModeDef.resolveHit(current, function()
				return false
			end)
		)).toBe("none")
	end)
end)
