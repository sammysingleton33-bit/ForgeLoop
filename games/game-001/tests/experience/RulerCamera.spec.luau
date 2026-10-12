local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local D = require("./RulerDoubles")
local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")

local C = CameraDef.DEFAULTS
local DT = 1 / 60

local function near(a: Vector3, b: Vector3, eps: number?): boolean
	return (a - b).Magnitude <= (eps or 1e-3)
end

describe("RulerCameraController pure rules (FL-0053)", function()
	it("overviewCFrame() sits height studs above the focus and looks down at it at pitchDeg", function()
		local focus = Vector3.new(100, 0, -40)
		local cf = CameraDef.overviewCFrame(focus, 0, 80, 55)
		expect(math.abs(cf.Position.Y - 80) < 1e-3).toBe(true)
		local toFocus = (focus - cf.Position).Unit
		expect(near(cf.LookVector, toFocus)).toBe(true)
		local pitch = math.deg(math.asin(-cf.LookVector.Y))
		expect(math.abs(pitch - 55) < 1e-3).toBe(true)
		expect(cf.LookVector.Z < 0).toBe(true) -- yaw 0 looks toward -Z, like the default camera
		local turned = CameraDef.overviewCFrame(focus, math.pi / 2, 80, 55)
		expect(turned.LookVector.X < -0.5).toBe(true)
	end)

	it("smooth() is frame-rate independent and converges", function()
		local a, b = Vector3.zero, Vector3.new(10, 0, 0)
		local once = CameraDef.smooth(a, b, 6, 0.1)
		local twice = CameraDef.smooth(CameraDef.smooth(a, b, 6, 0.05), b, 6, 0.05)
		expect(near(once, twice, 1e-6)).toBe(true)
		local p = a
		for _ = 1, 120 do
			p = CameraDef.smooth(p, b, 6, DT)
		end
		expect(near(p, b, 0.01)).toBe(true)
	end)

	it("shakeAmplitude() eases out to zero at the duration and clamps the magnitude", function()
		expect(CameraDef.shakeAmplitude(0.5, 0.4, 0, 2)).toBe(1)
		expect(CameraDef.shakeAmplitude(0.5, 0.4, 0.2, 2)).toBe(0.25)
		expect(CameraDef.shakeAmplitude(0.5, 0.4, 0.4, 2)).toBe(0)
		expect(CameraDef.shakeAmplitude(5, 1, 0, 2)).toBe(2)
	end)
end)

describe("RulerCameraController modes, build mode and shake (FL-0053)", function()
	local env, actions, userInput, player, camera, registry, controller, input, character, humanoid, root, vfx

	local function boot(extra, config)
		registry = D.boot(env, {
			input = { actions = actions },
			ruler = { actions = actions, player = player },
			camera = { actions = actions, userInput = userInput, camera = camera, player = player, config = config },
			extra = extra,
		})
		controller = registry:get("RulerCameraController")
		input = registry:get("InputModeController")
	end

	local function frames(n)
		for _ = 1, n do
			controller:update(DT)
		end
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 58, isServer = false, localPlayer = { userId = 5801 } })
		actions = D.actions()
		userInput = D.userInput()
		player = D.player()
		camera = roblox.Instance.new("Camera")
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 12, 20), Vector3.new(0, 3, 0))
		character, humanoid, root = D.character(Vector3.new(0, 3, 0))
		player.Character = character
		vfx = {
			name = "VFXController",
			dependencies = {},
			new = function()
				return { shakeRequested = Signal.new() }
			end,
		}
	end)

	it("starts in follow with the kingdom-overseeing zoom range, shoulder offset and FOV", function()
		boot()
		expect(controller.mode).toBe("follow")
		expect(player.CameraMinZoomDistance).toBe(C.follow.minZoom)
		expect(player.CameraMaxZoomDistance).toBe(C.follow.maxZoom)
		expect(C.follow.minZoom >= 8).toBe(true) -- never first person (smooth turning needs it)
		expect(humanoid.CameraOffset).toBe(C.follow.shoulder)
		expect(camera.FieldOfView).toBe(C.fieldOfView)
	end)

	it("setMode() switches camera types, fires changed, and refuses unknown modes once", function()
		boot()
		local seen = {}
		controller.changed:connect(function(mode, previous)
			table.insert(seen, `{previous}->{mode}`)
		end)
		expect(controller:setMode("overview")).toBe(true)
		expect(camera.CameraType).toBe(Enum.CameraType.Scriptable)
		expect(controller:setMode("overview")).toBe(true)
		expect(controller:setMode("follow")).toBe(true)
		expect(camera.CameraType).toBe(Enum.CameraType.Custom)
		expect(camera.CameraSubject).toBe(humanoid)
		expect(controller:setMode("cinematic")).toBe(false)
		expect(controller:setMode("cinematic")).toBe(false)
		expect(seen).toEqual({ "follow->overview", "overview->follow" })
		local warnings = 0
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "unknown camera mode", 1, true) then
				warnings += 1
			end
		end
		expect(warnings).toBe(1)
	end)

	it("overview blends from the current view, then follows the ruler from above", function()
		boot()
		local start = camera.CFrame
		controller:setMode("overview")
		frames(1)
		expect(near(camera.CFrame.Position, start.Position, 5)).toBe(true) -- no snap on the first frame
		frames(math.ceil(C.transitionSec / DT) + 1)
		local goal = CameraDef.overviewCFrame(root.CFrame.Position, 0, C.overview.startHeight, C.overview.pitchDeg)
		expect(near(camera.CFrame.Position, goal.Position, 0.01)).toBe(true)
		root.CFrame = CFrame.new(40, 3, 0) -- the ruler walks east
		frames(1)
		expect(camera.CFrame.Position.X > goal.Position.X and camera.CFrame.Position.X < goal.Position.X + 40).toBe(
			true
		)
		frames(180)
		expect(math.abs(camera.CFrame.Position.X - (goal.Position.X + 40)) < 0.05).toBe(true)
	end)

	it("zoom (wheel, pinch, zoomBy) changes the overview height within its range", function()
		boot()
		controller:setMode("overview")
		frames(60)
		controller:zoomBy(-100)
		frames(1)
		expect(math.abs(camera.CFrame.Position.Y - (root.CFrame.Position.Y + C.overview.minHeight)) < 0.01).toBe(true)
		userInput.InputChanged:Fire(
			{ UserInputType = Enum.UserInputType.MouseWheel, Position = Vector3.new(0, 0, -1) },
			false
		)
		frames(1)
		expect(
			math.abs(camera.CFrame.Position.Y - (root.CFrame.Position.Y + C.overview.minHeight + C.overview.zoomStep))
				< 0.01
		).toBe(true)
		local function pinch(scale, state)
			userInput.TouchPinch:Fire({}, scale, 0, state, false)
		end
		pinch(1, Enum.UserInputState.Begin)
		pinch(0.5, Enum.UserInputState.Change) -- pinch in: further out
		pinch(0.25, Enum.UserInputState.Change)
		frames(1)
		-- two halvings of the pinch scale: each zooms out by (1 - 0.5) * 5 steps, not by the cumulative scale
		local expected = C.overview.minHeight + C.overview.zoomStep + 2 * 2.5 * C.overview.zoomStep
		expect(math.abs(camera.CFrame.Position.Y - (root.CFrame.Position.Y + expected)) < 0.01).toBe(true)
		controller:zoomBy(100)
		frames(1)
		expect(math.abs(camera.CFrame.Position.Y - (root.CFrame.Position.Y + C.overview.maxHeight)) < 0.01).toBe(true)
	end)

	it("build mode switches to overview and restores the previous mode afterwards", function()
		boot()
		input:set("build")
		expect(controller.mode).toBe("overview")
		input:set("explore")
		expect(controller.mode).toBe("follow")
	end)

	it("a view the player picks while building is kept after build mode", function()
		boot()
		input:set("build")
		controller:setMode("follow")
		controller:setMode("overview")
		input:set("explore")
		expect(controller.mode).toBe("overview")
	end)

	it("V / gamepad Y / the touch View button toggles the mode", function()
		boot()
		local bound = actions.bound[CameraDef.ACTION]
		assert(bound, "view action bound")
		expect(bound.keys).toEqual({ Enum.KeyCode.V, Enum.KeyCode.ButtonY })
		expect(bound.touch).toBe(true)
		expect(actions.titles[CameraDef.ACTION]).toBe("View")
		actions:press(CameraDef.ACTION, Enum.UserInputState.Begin)
		expect(controller.mode).toBe("overview")
		actions:press(CameraDef.ACTION, Enum.UserInputState.End)
		expect(controller.mode).toBe("overview")
		actions:press(CameraDef.ACTION, Enum.UserInputState.Begin)
		expect(controller.mode).toBe("follow")
	end)

	it("VFXController shake requests rotate the camera and fade out after their duration", function()
		boot({ vfx })
		local shakes = registry:get("VFXController").shakeRequested
		local still = camera.CFrame
		shakes:fire(0.4, 0.3)
		controller:update(0.05)
		expect(near(camera.CFrame.LookVector, still.LookVector, 1e-6)).toBe(false)
		local maxAngle = math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(still.LookVector), -1, 1)))
		expect(maxAngle <= 2 * C.shake.maxDegrees * 0.4 + 1e-3).toBe(true)
		camera.CFrame = still -- Roblox's camera rewrites the CFrame every frame in follow mode
		controller:update(0.3)
		camera.CFrame = still
		controller:update(DT)
		expect(near(camera.CFrame.LookVector, still.LookVector, 1e-9)).toBe(true)
	end)

	it("never shakes when camera shake is off or reduced motion is on (incl. the platform setting)", function()
		for _, values in { { cameraShake = false }, { reducedMotion = true }, { platformReduced = true } } do
			env = MockEnv.new({ seed = 59, isServer = false, localPlayer = { userId = 5802 } })
			boot({ vfx, D.settings(values) })
			local still = camera.CFrame
			expect(controller:shake(1, 1)).toBe(false)
			registry:get("VFXController").shakeRequested:fire(1, 1)
			controller:update(0.05)
			expect(near(camera.CFrame.LookVector, still.LookVector, 1e-9)).toBe(true)
		end
	end)

	it("caps the duration and the number of shakes that add up", function()
		boot()
		for _ = 1, 10 do
			controller:shake(1, 30)
		end
		expect(#controller._shakes).toBe(C.shake.maxActive)
		expect(controller._shakes[1].duration).toBe(C.shake.maxDuration)
		expect(controller:shake(0, 1)).toBe(false)
		expect(controller:shake("big", 1)).toBe(false)
	end)

	it("boots with no camera and no input services (headless) and does nothing", function()
		local bare = MockEnv.new({ seed = 60, isServer = false, localPlayer = { userId = 5803 } })
		local reg = D.boot(bare, {})
		local cam = reg:get("RulerCameraController")
		expect(cam:setMode("overview")).toBe(true)
		cam:update(DT)
		expect(bare.mock:hasLog("info", "RulerCameraController: input services unavailable")).toBe(true)
		expect(bare.mock.threadErrors).toEqual({})
	end)
end)
