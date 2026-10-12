local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local D = require("./RulerDoubles")
local RulerDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerController")

local C = RulerDef.DEFAULTS
local EAST = Vector3.new(1, 0, 0)

describe("RulerController pure rules (FL-0053)", function()
	it("approach() moves toward the target by at most one step and never overshoots", function()
		expect(RulerDef.approach(16, 24, 3)).toBe(19)
		expect(RulerDef.approach(23, 24, 3)).toBe(24)
		expect(RulerDef.approach(24, 16, 5)).toBe(19)
		expect(RulerDef.approach(17, 16, 5)).toBe(16)
	end)

	it("sprintStep(): a held key sprints only while moving; a toggle ends when the ruler stops", function()
		local state, sprinting = RulerDef.sprintStep({ held = true, toggled = false }, false)
		expect(sprinting).toBe(false)
		expect(state.held).toBe(true)
		state, sprinting = RulerDef.sprintStep(state, true)
		expect(sprinting).toBe(true)
		state, sprinting = RulerDef.sprintStep({ held = false, toggled = true }, true)
		expect(sprinting).toBe(true)
		state, sprinting = RulerDef.sprintStep(state, false)
		expect(sprinting).toBe(false)
		expect(state.toggled).toBe(false)
		state, sprinting = RulerDef.sprintStep(state, true)
		expect(sprinting).toBe(false) -- moving again does not bring a cancelled toggle back
	end)

	it("facing() ignores tiny or vertical input and returns an upright facing", function()
		expect(RulerDef.facing(Vector3.new(0.05, 0, 0), 0.1)).toBeNil()
		expect(RulerDef.facing(Vector3.new(0, 1, 0), 0.1)).toBeNil()
		local facing = RulerDef.facing(Vector3.new(2, 0.5, 0), 0.1)
		assert(facing)
		expect((facing.LookVector - EAST).Magnitude < 1e-4).toBe(true)
		expect(math.abs(facing.UpVector.Y - 1) < 1e-4).toBe(true)
	end)
end)

describe("RulerController with a character (FL-0053)", function()
	local env, actions, player, registry, ruler, input

	local function frames(n, dt)
		for _ = 1, n do
			ruler:update(dt)
		end
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 55, isServer = false, localPlayer = { userId = 5501 } })
		actions = D.actions()
		player = D.player()
		registry = D.boot(env, {
			input = { actions = actions },
			ruler = { actions = actions, player = player },
			camera = false,
		})
		ruler = registry:get("RulerController")
		input = registry:get("InputModeController")
	end)

	it("binds sprint at high priority to Left Shift and L3 with a touch button titled Sprint", function()
		local bound = actions.bound[RulerDef.ACTION]
		assert(bound, "sprint is bound")
		expect(bound.touch).toBe(true)
		expect(bound.priority).toBe(Enum.ContextActionPriority.High.Value)
		expect(bound.keys).toEqual({ Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3 })
		expect(actions.titles[RulerDef.ACTION]).toBe("Sprint")
	end)

	it("eases WalkSpeed to sprint speed while Shift is held and moving, and back on release", function()
		local character, humanoid = D.character()
		player.CharacterAdded:Fire(character)
		expect(humanoid.WalkSpeed).toBe(C.walkSpeed)
		humanoid.MoveDirection = EAST
		local result = actions:press(RulerDef.ACTION, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.LeftShift })
		expect(result).toBe(Enum.ContextActionResult.Sink)
		local dt = 1 / 60
		local last = humanoid.WalkSpeed
		for _ = 1, 30 do
			ruler:update(dt)
			expect(humanoid.WalkSpeed - last <= C.accel * dt + 1e-6).toBe(true) -- never a lurch
			last = humanoid.WalkSpeed
		end
		expect(humanoid.WalkSpeed).toBe(C.sprintSpeed)
		expect(ruler.sprinting).toBe(true)
		actions:press(RulerDef.ACTION, Enum.UserInputState.End, { KeyCode = Enum.KeyCode.LeftShift })
		frames(30, dt)
		expect(humanoid.WalkSpeed).toBe(C.walkSpeed)
	end)

	it("standing still never sprints, even with Shift held", function()
		local character, humanoid = D.character()
		player.CharacterAdded:Fire(character)
		humanoid.MoveDirection = Vector3.zero
		actions:press(RulerDef.ACTION, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.LeftShift })
		frames(30, 1 / 60)
		expect(ruler.sprinting).toBe(false)
		expect(humanoid.WalkSpeed).toBe(C.walkSpeed)
	end)

	it("touch and L3 toggle sprint; the toggle ends when the ruler stops", function()
		local character, humanoid = D.character()
		player.CharacterAdded:Fire(character)
		humanoid.MoveDirection = EAST
		actions:press(RulerDef.ACTION, Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Touch })
		actions:press(RulerDef.ACTION, Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Touch })
		frames(30, 1 / 60)
		expect(ruler.sprinting).toBe(true) -- releasing the touch button does not stop a toggle
		humanoid.MoveDirection = Vector3.zero
		frames(1, 1 / 60)
		expect(ruler.sprinting).toBe(false)
		humanoid.MoveDirection = EAST
		frames(30, 1 / 60)
		expect(ruler.sprinting).toBe(false)
		actions:press(RulerDef.ACTION, Enum.UserInputState.Begin, { KeyCode = Enum.KeyCode.ButtonL3 })
		frames(1, 1 / 60)
		expect(ruler.sprinting).toBe(true)
	end)

	it(
		"smooth turning: AutoRotate off, an AlignOrientation faces the move direction and keeps it when stopping",
		function()
			local character, humanoid, root = D.character()
			player.CharacterAdded:Fire(character)
			expect(humanoid.AutoRotate).toBe(false)
			local align = root:FindFirstChild("ForgeRulerTurn")
			assert(align and align:IsA("AlignOrientation"), "AlignOrientation on the root")
			expect(align.MaxAngularVelocity).toBe(C.turn.maxAngularVelocity)
			expect(align.Attachment0).toBe(root:FindFirstChild("RootAttachment"))
			humanoid.MoveDirection = EAST
			ruler:update(1 / 60)
			expect((align.CFrame.LookVector - EAST).Magnitude < 1e-4).toBe(true)
			humanoid.MoveDirection = Vector3.zero
			ruler:update(1 / 60)
			expect((align.CFrame.LookVector - EAST).Magnitude < 1e-4).toBe(true)
		end
	)

	it("turn.mode = 'engine' keeps Roblox's AutoRotate and adds no constraint", function()
		local engineEnv = MockEnv.new({ seed = 56, isServer = false, localPlayer = { userId = 5502 } })
		local enginePlayer = D.player()
		local config = table.clone(C)
		config.turn = { mode = "engine", maxAngularVelocity = 12, responsiveness = 30 }
		D.boot(engineEnv, { ruler = { player = enginePlayer, config = config }, camera = false })
		local character, humanoid, root = D.character()
		enginePlayer.CharacterAdded:Fire(character)
		expect(humanoid.AutoRotate).toBe(true)
		expect(root:FindFirstChild("ForgeRulerTurn")).toBeNil()
	end)

	it("respawn, removal and death return input to explore; characterChanged reports the character", function()
		local seen = {}
		ruler.characterChanged:connect(function(character)
			table.insert(seen, if character then character.Name else "none")
		end)
		local character = D.character()
		player.CharacterAdded:Fire(character)
		input:set("build")
		player.CharacterRemoving:Fire(character)
		expect(input.mode).toBe("explore")
		expect(ruler:getCharacter()).toBeNil()
		player.CharacterAdded:Fire(character)
		input:set("build")
		ruler:toggleSprint()
		ruler:_onDied() -- Humanoid.Died: Lune instances have no events, Studio step E7 covers the wiring
		expect(input.mode).toBe("explore")
		expect(ruler.sprinting).toBe(false)
		expect(seen).toEqual({ "Ruler", "none", "Ruler" })
	end)

	it("picks up a character that already exists at start", function()
		local lateEnv = MockEnv.new({ seed = 57, isServer = false, localPlayer = { userId = 5503 } })
		local latePlayer = D.player()
		local character = D.character()
		latePlayer.Character = character
		local reg = D.boot(lateEnv, { ruler = { player = latePlayer }, camera = false })
		expect(reg:get("RulerController"):getCharacter()).toBe(character)
	end)
end)
