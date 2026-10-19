local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local roblox = require("@lune/roblox")
local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local D = require("./RulerDoubles")
local CameraDef = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/RulerCameraController")

local C = CameraDef.DEFAULTS
local O = C.overview
local DT = 1 / 60

local function near(a: Vector3, b: Vector3, eps: number?): boolean
	return (a - b).Magnitude <= (eps or 1e-3)
end

describe("RulerCameraController pure rules (FL-0053, FL-0090)", function()
	it("aerialCFrame() sits zoom studs from the focus, looking at it, at the zoom's pitch", function()
		local focus = Vector3.new(100, 0, -40)
		for _, zoom in { O.minZoom, O.startZoom, O.maxZoom } do
			local cf = CameraDef.aerialCFrame(focus, 0, zoom, O)
			expect(math.abs((cf.Position - focus).Magnitude - zoom) < 1e-3).toBe(true)
			expect(near(cf.LookVector, (focus - cf.Position).Unit)).toBe(true)
			local pitch = math.deg(math.asin(-cf.LookVector.Y))
			expect(math.abs(pitch - CameraDef.pitchFor(zoom, O)) < 1e-3).toBe(true)
		end
		expect(CameraDef.pitchFor(O.minZoom, O)).toBe(O.minPitchDeg) -- flatter close up
		expect(CameraDef.pitchFor(O.maxZoom, O)).toBe(O.maxPitchDeg) -- steeper far out
		expect(CameraDef.aerialCFrame(focus, 0, 100, O).LookVector.Z < 0).toBe(true) -- yaw 0 looks toward -Z
		expect(CameraDef.aerialCFrame(focus, math.pi / 2, 100, O).LookVector.X < -0.3).toBe(true)
	end)

	it("boundsFromLayout() boxes every region polygon and plot spawn of the real Layout", function()
		local bounds = CameraDef.boundsFromLayout(Layout)
		assert(bounds, "the Layout has regions")
		for _, region in Layout.regions do
			for _, point in region.polygon do
				expect(point.X >= bounds.min.X and point.X <= bounds.max.X).toBe(true)
				expect(point.Y >= bounds.min.Y and point.Y <= bounds.max.Y).toBe(true)
			end
		end
		for _, plot in Layout.plots do
			local p = plot.spawn.Position
			expect(p.X >= bounds.min.X and p.X <= bounds.max.X and p.Z >= bounds.min.Y and p.Z <= bounds.max.Y).toBe(
				true
			)
		end
		expect(CameraDef.boundsFromLayout({})).toBeNil()
		expect(CameraDef.boundsFromLayout(nil)).toBeNil()
	end)

	it("clampFocus() keeps the focus within bounds + margin and keeps its height", function()
		local bounds = { min = Vector2.new(-100, -50), max = Vector2.new(100, 50) }
		expect(CameraDef.clampFocus(Vector3.new(500, 7, -500), bounds, 10)).toBe(Vector3.new(110, 7, -60))
		expect(CameraDef.clampFocus(Vector3.new(1, 2, 3), bounds, 10)).toBe(Vector3.new(1, 2, 3))
	end)

	it(
		"conversationView() frames the citizen above the centre at the conversation zoom, inside the map (FL-0100)",
		function()
			local conversation = C.conversation
			local bounds = { min = Vector2.new(-100, -50), max = Vector2.new(100, 50) }
			local citizen = Vector3.new(10, 3, 0)
			local view = CameraDef.conversationView(citizen, 0, conversation, bounds, 10)
			expect(view.zoom).toBe(conversation.zoom)
			expect(conversation.zoom >= 25 and conversation.zoom <= 35).toBe(true)
			-- yaw 0 looks toward -Z; the focus moves toward the camera (+Z), so the citizen sits further up the screen
			expect(near(view.focus, Vector3.new(10, 3, -conversation.offset.Y))).toBe(true)
			local edge = CameraDef.conversationView(Vector3.new(500, 3, 0), 0, conversation, bounds, 10)
			expect(edge.focus.X).toBe(110) -- clamped to bounds + margin
		end
	)

	it("panVector() maps screen right/forward onto the ground at any yaw; worldPerPixel scales with zoom", function()
		expect(near(CameraDef.panVector(Vector2.new(0, 1), 0), Vector3.new(0, 0, -1))).toBe(true)
		expect(near(CameraDef.panVector(Vector2.new(1, 0), 0), Vector3.new(1, 0, 0))).toBe(true)
		local look = CameraDef.aerialCFrame(Vector3.zero, math.pi / 2, 100, O).LookVector
		expect(near(CameraDef.panVector(Vector2.new(0, 1), math.pi / 2), Vector3.new(look.X, 0, look.Z).Unit)).toBe(
			true
		)
		local close = CameraDef.worldPerPixel(40, 70, 720)
		local far = CameraDef.worldPerPixel(200, 70, 720)
		expect(math.abs(far / close - 5) < 1e-6).toBe(true)
	end)

	it("smooth() is frame-rate independent; shakeAmplitude() eases out and clamps", function()
		local target = Vector3.new(10, 0, 0)
		local once = CameraDef.smooth(Vector3.zero, target, 6, 0.1)
		local twice = CameraDef.smooth(CameraDef.smooth(Vector3.zero, target, 6, 0.05), target, 6, 0.05)
		expect(near(once, twice, 1e-6)).toBe(true)
		local n1 = CameraDef.smooth(0, 10, 6, 0.1)
		local n2 = CameraDef.smooth(CameraDef.smooth(0, 10, 6, 0.05), 10, 6, 0.05)
		expect(math.abs(n1 - n2) < 1e-9).toBe(true)
		expect(CameraDef.shakeAmplitude(0.5, 0.4, 0, 2)).toBe(1)
		expect(CameraDef.shakeAmplitude(0.5, 0.4, 0.2, 2)).toBe(0.25)
		expect(CameraDef.shakeAmplitude(0.5, 0.4, 0.4, 2)).toBe(0)
		expect(CameraDef.shakeAmplitude(5, 1, 0, 2)).toBe(2)
	end)
end)

describe("RulerCameraController overview, walk mode, build mode and shake (FL-0053, FL-0090)", function()
	local env, actions, userInput, player, camera, gui, registry, controller, input, humanoid, vfx
	local THRONE = Vector3.new(120, 3, -40)

	local function boot(extra, config, layout, sendFocus)
		registry = D.boot(env, {
			input = { actions = actions },
			ruler = { actions = actions, player = player },
			camera = {
				actions = actions,
				userInput = userInput,
				guiService = gui,
				camera = camera,
				player = player,
				config = config,
				layout = layout,
				viewportHeight = 720,
				sendFocus = sendFocus,
			},
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

	local function settle()
		frames(math.ceil(C.transitionSec / DT) + 240)
	end

	local function key(name, code, state)
		return actions:press(name, state or Enum.UserInputState.Begin, { KeyCode = code })
	end

	local function mouse(event, kind, x, y)
		userInput[event]:Fire({ UserInputType = kind, Position = Vector3.new(x, y, 0) }, false)
	end

	beforeEach(function()
		env = MockEnv.new({ seed = 58, isServer = false, localPlayer = { userId = 5801 } })
		actions = D.actions()
		userInput = D.userInput()
		player = D.player()
		gui = { TouchControlsEnabled = true }
		camera = roblox.Instance.new("Camera")
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 12, 20), Vector3.new(0, 3, 0))
		local character, h = D.character(THRONE)
		humanoid = h
		player.Character = character
		vfx = {
			name = "VFXController",
			dependencies = {},
			new = function()
				return { shakeRequested = Signal.new() }
			end,
		}
	end)

	it("starts in the overview over the throne; move and jump keys are sunk and the thumbstick hidden", function()
		boot()
		expect(controller.mode).toBe("overview")
		expect(camera.CameraType).toBe(Enum.CameraType.Scriptable)
		expect(controller:getFocus()).toBe(THRONE)
		expect(gui.TouchControlsEnabled).toBe(false)
		local pan = actions.bound[CameraDef.PAN_ACTION]
		local seat = actions.bound[CameraDef.SEAT_ACTION]
		assert(pan and seat, "pan and seat actions bound")
		expect(pan.priority).toBe(Enum.ContextActionPriority.High.Value)
		expect(#pan.keys).toBe(8)
		expect(seat.keys).toEqual({ Enum.KeyCode.Space, Enum.KeyCode.ButtonA })
		expect(key(CameraDef.PAN_ACTION, Enum.KeyCode.W)).toBe(Enum.ContextActionResult.Sink)
		key(CameraDef.PAN_ACTION, Enum.KeyCode.W, Enum.UserInputState.End)
		expect(key(CameraDef.SEAT_ACTION, Enum.KeyCode.Space)).toBe(Enum.ContextActionResult.Sink)
		settle()
		local goal = CameraDef.aerialCFrame(controller:getFocus() :: Vector3, controller._target.yaw, O.startZoom, O)
		expect(near(camera.CFrame.Position, goal.Position, 0.05)).toBe(true)
	end)

	it("WASD pans relative to the view at a speed that scales with the zoom", function()
		boot()
		settle()
		local start = controller:getFocus() :: Vector3
		key(CameraDef.PAN_ACTION, Enum.KeyCode.D)
		frames(60) -- one second
		key(CameraDef.PAN_ACTION, Enum.KeyCode.D, Enum.UserInputState.End)
		local moved = (controller:getFocus() :: Vector3) - start
		local right = CameraDef.panVector(Vector2.new(1, 0), controller._target.yaw)
		expect(math.abs(moved.Magnitude - O.panSpeed * O.startZoom) < 1).toBe(true)
		expect(near(moved.Unit, right, 1e-3)).toBe(true)
		local still = controller:getFocus()
		frames(30)
		expect(controller:getFocus()).toBe(still) -- released: no drift
	end)

	it("the focus never leaves the map bounds + margin", function()
		local layout = { regions = { home = { polygon = { Vector2.new(0, 0), Vector2.new(200, 100) } } } }
		boot(nil, nil, layout)
		controller:focusOn(Vector3.new(0, 0, 0))
		expect(controller:getFocus()).toBe(Vector3.new(0, 0, 0))
		controller:focusOn(Vector3.new(9999, 0, -9999))
		expect(controller:getFocus()).toBe(Vector3.new(200 + O.boundsMargin, 0, -O.boundsMargin))
		for _ = 1, 50 do
			controller:panBy(Vector2.new(0, 500))
		end
		local focus = controller:getFocus() :: Vector3
		expect(focus.X >= -O.boundsMargin and focus.X <= 200 + O.boundsMargin).toBe(true)
		expect(focus.Z >= -O.boundsMargin and focus.Z <= 100 + O.boundsMargin).toBe(true)
	end)

	it("zoom stays within 40-220 studs (wheel, pinch, zoomBy)", function()
		boot()
		controller:zoomBy(-100)
		expect(controller._target.zoom).toBe(O.minZoom)
		userInput.InputChanged:Fire(
			{ UserInputType = Enum.UserInputType.MouseWheel, Position = Vector3.new(0, 0, -1) },
			false
		)
		expect(controller._target.zoom).toBe(O.minZoom + O.zoomStep)
		local function pinch(scale, state)
			userInput.TouchPinch:Fire({}, scale, 0, state, false)
		end
		pinch(1, Enum.UserInputState.Begin)
		pinch(0.5, Enum.UserInputState.Change) -- pinch in: further out, by the change since the last event
		pinch(0.25, Enum.UserInputState.Change)
		expect(controller._target.zoom).toBe(O.minZoom + O.zoomStep + 2 * 2.5 * O.zoomStep)
		controller:zoomBy(100)
		expect(controller._target.zoom).toBe(O.maxZoom)
	end)

	it("left-drag pans the ground with the pointer only after tapPixels; right-drag rotates", function()
		boot()
		local start = controller:getFocus() :: Vector3
		mouse("InputBegan", Enum.UserInputType.MouseButton1, 400, 300)
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 405, 300)
		expect(controller:getFocus()).toBe(start) -- 5 px: still a tap
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 500, 300)
		local studs = 100 * CameraDef.worldPerPixel(O.startZoom, C.fieldOfView, 720)
		local moved = (controller:getFocus() :: Vector3) - start
		expect(math.abs(moved.Magnitude - studs) < 1e-3).toBe(true)
		-- the ground follows the pointer: dragging right moves the view left
		expect(near(moved.Unit, -CameraDef.panVector(Vector2.new(1, 0), controller._target.yaw), 1e-3)).toBe(true)
		mouse("InputEnded", Enum.UserInputType.MouseButton1, 500, 300)
		local yaw = controller._target.yaw
		mouse("InputBegan", Enum.UserInputType.MouseButton2, 400, 300)
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 500, 300)
		expect(math.abs(math.deg(controller._target.yaw - yaw) - 100 * O.dragRotate) < 1e-6).toBe(true)
	end)

	it("one-finger drag pans, a two-finger twist rotates; two-finger moves never pan", function()
		boot()
		local start = controller:getFocus() :: Vector3
		local one, two = { Vector2.new(1, 1) }, { Vector2.new(1, 1), Vector2.new(9, 9) }
		userInput.TouchPan:Fire(one, Vector2.zero, Vector2.zero, Enum.UserInputState.Begin, false)
		userInput.TouchPan:Fire(one, Vector2.new(0, 50), Vector2.zero, Enum.UserInputState.Change, false)
		local panned = controller:getFocus() :: Vector3
		expect((panned - start).Magnitude > 1).toBe(true)
		userInput.TouchPan:Fire(two, Vector2.new(0, 120), Vector2.zero, Enum.UserInputState.Change, false)
		expect(controller:getFocus()).toBe(panned)
		local yaw = controller._target.yaw
		userInput.TouchRotate:Fire(two, 0, 0, Enum.UserInputState.Begin, false)
		userInput.TouchRotate:Fire(two, 30, 0, Enum.UserInputState.Change, false)
		userInput.TouchRotate:Fire(two, 45, 0, Enum.UserInputState.Change, false)
		expect(math.abs(math.deg(controller._target.yaw - yaw) + 45) < 1e-6).toBe(true)
	end)

	it("Q / E rotate in the overview, but are left to FORGE-03's placement in build mode", function()
		boot()
		assert(actions.bound[CameraDef.ROTATE_ACTION], "rotate bound in explore")
		key(CameraDef.ROTATE_ACTION, Enum.KeyCode.E)
		local yaw = controller._target.yaw
		frames(60)
		expect(math.abs(math.deg(controller._target.yaw - yaw) - O.rotateSpeed) < 1e-3).toBe(true)
		key(CameraDef.ROTATE_ACTION, Enum.KeyCode.E, Enum.UserInputState.End)
		input:set("build")
		expect(actions.bound[CameraDef.ROTATE_ACTION]).toBeNil()
		input:set("explore")
		expect(actions.bound[CameraDef.ROTATE_ACTION] ~= nil).toBe(true)
	end)

	it("asks the server to stream around the focus, throttled by distance and time", function()
		local requests = {}
		function player.RequestStreamAroundAsync(_, position)
			table.insert(requests, position)
		end
		boot()
		frames(1)
		expect(#requests).toBe(1)
		controller:panBy(Vector2.new(O.streamMoveStuds / 2, 0))
		frames(90)
		expect(#requests).toBe(1) -- not far enough
		controller:panBy(Vector2.new(O.streamMoveStuds, 0))
		frames(1)
		expect(#requests).toBe(1) -- far enough, but too soon (the virtual clock has not moved)
		env.mock:advance(O.streamEverySec)
		frames(1)
		expect(#requests).toBe(2)
	end)

	it(
		"reports the overview's focus for interest at most 4 a second, kept alive, never in walk mode (D-055 (5))",
		function()
			local sent = {}
			boot(nil, nil, nil, function(focus)
				table.insert(sent, focus)
			end)
			frames(1)
			expect(#sent).toBe(1)
			expect(sent[1]).toEqual(controller:getFocus()) -- the clamped ground focus, not a free number
			controller:panBy(Vector2.new(20, 0))
			frames(5) -- the virtual clock has not moved: inside FOCUS.everySec
			expect(#sent).toBe(1)
			env.mock:advance(CameraDef.FOCUS.everySec)
			frames(1)
			expect(#sent).toBe(2)
			env.mock:advance(CameraDef.FOCUS.everySec)
			frames(1)
			expect(#sent).toBe(2) -- held still: no report until the keepalive
			env.mock:advance(CameraDef.FOCUS.keepaliveSec)
			frames(1)
			expect(#sent).toBe(3)
			for _ = 1, 40 do -- two virtual seconds of panning: never more than 4 a second
				controller:panBy(Vector2.new(30, 0))
				env.mock:advance(0.05)
				frames(1)
			end
			expect(#sent - 3 <= 2 * 4 + 1).toBe(true)
			local before = #sent
			expect(controller:setMode("follow")).toBe(true)
			for _ = 1, 10 do
				env.mock:advance(1)
				frames(1)
			end
			expect(#sent).toBe(before) -- walk mode reports nothing; the character is the server's fallback
		end
	)

	it("without the Sim.Focus remote it sends nothing and logs nothing (FORGE-01 declares it)", function()
		boot()
		for _ = 1, 20 do
			env.mock:advance(0.3)
			frames(1)
		end
		expect(controller.focusReports).toBe(0)
		expect(env.mock:hasLog("warn", "could not send")).toBe(false)
	end)

	it("follow (walk mode) stands the ruler up, shows the thumbstick and tunes Roblox's camera", function()
		boot()
		local stood = 0
		local ruler = registry:get("RulerController")
		local original = ruler.standUp
		ruler.standUp = function(self)
			stood += 1
			return original(self)
		end
		expect(controller:setMode("follow")).toBe(true)
		expect(stood).toBe(1)
		expect(camera.CameraType).toBe(Enum.CameraType.Custom)
		expect(camera.CameraSubject).toBe(humanoid)
		expect(gui.TouchControlsEnabled).toBe(true)
		expect(actions.bound[CameraDef.PAN_ACTION]).toBeNil()
		expect(actions.bound[CameraDef.SEAT_ACTION]).toBeNil()
		expect(player.CameraMinZoomDistance).toBe(C.follow.minZoom)
		expect(player.CameraMaxZoomDistance).toBe(C.follow.maxZoom)
		expect(C.follow.minZoom >= 8).toBe(true) -- never first person (smooth turning needs it)
		expect(humanoid.CameraOffset).toBe(C.follow.shoulder)
		expect(controller:setMode("cinematic")).toBe(false)
		expect(env.mock:hasLog("warn", "unknown camera mode 'cinematic'")).toBe(true)
	end)

	it("returning to the overview blends from the walk view over transitionSec (no snap)", function()
		boot()
		controller:setMode("follow")
		local walkView = CFrame.lookAt(THRONE + Vector3.new(0, 8, 20), THRONE)
		camera.CFrame = walkView
		controller:setMode("overview")
		frames(1)
		expect(near(camera.CFrame.Position, walkView.Position, 5)).toBe(true) -- the first frame stays close
		frames(math.ceil(C.transitionSec / DT) + 240)
		local goal =
			CameraDef.aerialCFrame(controller:getFocus() :: Vector3, controller._target.yaw, controller._target.zoom, O)
		expect(near(camera.CFrame.Position, goal.Position, 0.05)).toBe(true)
	end)

	it("V / gamepad Y / the touch View button toggles overview and walk mode", function()
		boot()
		local bound = actions.bound[CameraDef.ACTION]
		assert(bound, "view action bound")
		expect(bound.keys).toEqual({ Enum.KeyCode.V, Enum.KeyCode.ButtonY })
		expect(bound.touch).toBe(true)
		expect(actions.titles[CameraDef.ACTION]).toBe("View")
		actions:press(CameraDef.ACTION, Enum.UserInputState.Begin)
		expect(controller.mode).toBe("follow")
		actions:press(CameraDef.ACTION, Enum.UserInputState.End)
		expect(controller.mode).toBe("follow")
		actions:press(CameraDef.ACTION, Enum.UserInputState.Begin)
		expect(controller.mode).toBe("overview")
	end)

	it("build mode uses the overview and restores walk mode afterwards, unless the player chose a view", function()
		boot()
		controller:setMode("follow")
		input:set("build")
		expect(controller.mode).toBe("overview")
		input:set("explore")
		expect(controller.mode).toBe("follow")
		input:set("build")
		controller:setMode("follow")
		controller:setMode("overview")
		input:set("explore")
		expect(controller.mode).toBe("overview")
	end)

	it("edit mode (G13.9) keeps the overview; setEditDrag stops drag-pan and pans at the screen edge", function()
		boot()
		controller._opts.viewportWidth = 1280
		controller:setMode("follow")
		input:set("edit")
		expect(controller.mode).toBe("overview")
		input:set("explore")
		expect(controller.mode).toBe("follow")
		controller:setMode("overview")
		expect(controller:setEditDrag(true)).toBe(false) -- only while editing
		input:set("edit")
		env.mock:advance(0.2)
		expect(controller:setEditDrag(true)).toBe(true)
		settle()
		local start = controller:getFocus() :: Vector3
		mouse("InputBegan", Enum.UserInputType.MouseButton1, 400, 300)
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 600, 360) -- dragging a building
		frames(5)
		expect(near(controller:getFocus() :: Vector3, start, 1e-6)).toBe(true) -- the drag never pans
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 1279, 360) -- at the right edge
		frames(30)
		local moved = (controller:getFocus() :: Vector3) - start
		expect(moved.Magnitude > 1).toBe(true)
		expect(near(moved.Unit, CameraDef.panVector(Vector2.new(1, 0), controller._target.yaw), 1e-3)).toBe(true)
		controller:setEditDrag(false)
		local stopped = controller:getFocus() :: Vector3
		frames(30)
		expect(near(controller:getFocus() :: Vector3, stopped, 1e-6)).toBe(true) -- no edge-pan once dropped
		controller:setEditDrag(true)
		input:set("explore") -- leaving edit mode ends it too
		expect(controller._editDrag).toBe(false)
		expect(CameraDef.edgeDirection(Vector2.new(640, 360), Vector2.new(1280, 720), 48)).toEqual(Vector2.zero)
		expect(CameraDef.edgeDirection(Vector2.new(0, 0), Vector2.new(1280, 720), 48)).toEqual(Vector2.new(-1, 1))
		expect(CameraDef.edgeDirection(Vector2.new(640, 720), Vector2.new(1280, 720), 48)).toEqual(Vector2.new(0, -1))
	end)

	it(
		"edit drag on touch: only the finger holding the building edge-pans; a second finger never does (#234)",
		function()
			boot()
			controller._opts.viewportWidth = 1280
			controller:setMode("overview")
			input:set("edit")
			env.mock:advance(0.2)
			settle()
			local function touch(x, y)
				return { UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(x, y, 0) }
			end
			local holding = touch(400, 300)
			userInput.InputBegan:Fire(holding, false) -- the hold starts on the building (DragInput: unprocessed)
			-- a second finger lands near the right edge before the hold completes (a pinch starting)
			local other = touch(1270, 360)
			userInput.InputBegan:Fire(other, false)
			expect(controller:setEditDrag(true, Vector2.new(400, 300))).toBe(true) -- FORGE-03's hold of 0.45 s
			expect(controller._dragTouch).toBe(holding)
			local start = controller:getFocus() :: Vector3
			-- the second finger moves at the edge: no edge-pan
			other.Position = Vector3.new(1275, 360, 0)
			userInput.InputChanged:Fire(other, false)
			frames(30)
			expect(near(controller:getFocus() :: Vector3, start, 1e-6)).toBe(true)
			-- the holding finger reaches the edge: the view pans
			holding.Position = Vector3.new(1279, 360, 0)
			userInput.InputChanged:Fire(holding, false)
			frames(30)
			local moved = (controller:getFocus() :: Vector3) - start
			expect(moved.Magnitude > 1).toBe(true)
			-- the holding finger lifts: the edge-pan stops, even before setEditDrag(false)
			userInput.InputEnded:Fire(holding, false)
			local stopped = controller:getFocus() :: Vector3
			frames(30)
			expect(near(controller:getFocus() :: Vector3, stopped, 1e-6)).toBe(true)
			controller:setEditDrag(false)
			-- without an edit drag, any finger's move is the pointer again (the next drag picks its finger)
			expect(#controller._touches).toBe(1) -- the second finger is still down
			userInput.InputEnded:Fire(other, false)
			expect(#controller._touches).toBe(0)
		end
	)

	it("edit drag on touch: an older thumb resting on the world never takes the edge-pan (#239 M1)", function()
		boot()
		controller._opts.viewportWidth = 1280
		controller:setMode("overview")
		input:set("edit")
		env.mock:advance(0.2)
		settle()
		local function touch(x, y)
			return { UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(x, y, 0) }
		end
		local resting = touch(200, 360) -- the left thumb, down first
		userInput.InputBegan:Fire(resting, false)
		local holding = touch(900, 300) -- the right thumb holds a building for 0.45 s
		userInput.InputBegan:Fire(holding, false)
		expect(controller:setEditDrag(true, Vector2.new(900, 300))).toBe(true)
		expect(controller._dragTouch).toBe(holding)
		local start = controller:getFocus() :: Vector3
		resting.Position = Vector3.new(1, 360, 0) -- the resting thumb slides to the left edge: no pan
		userInput.InputChanged:Fire(resting, false)
		frames(30)
		expect(near(controller:getFocus() :: Vector3, start, 1e-6)).toBe(true)
		holding.Position = Vector3.new(1279, 360, 0) -- the holding finger reaches the right edge: it pans
		userInput.InputChanged:Fire(holding, false)
		frames(30)
		local moved = (controller:getFocus() :: Vector3) - start
		expect(moved.Magnitude > 1).toBe(true)
		expect(near(moved.Unit, CameraDef.panVector(Vector2.new(1, 0), controller._target.yaw), 1e-3)).toBe(true)
		-- without a press point (or a bad one) the oldest finger is the one held
		controller:setEditDrag(false)
		expect(controller:setEditDrag(true)).toBe(true)
		expect(controller._dragTouch).toBe(resting)
		controller:setEditDrag(false)
		expect(controller:setEditDrag(true, "nowhere")).toBe(true)
		expect(controller._dragTouch).toBe(resting)
		controller:setEditDrag(false)
		expect(controller._dragTouch).toBeNil()
	end)

	it("edit drag on touch: a finger already at the edge when the hold completes pans at once (#239 L2)", function()
		boot()
		controller._opts.viewportWidth = 1280
		controller:setMode("overview")
		input:set("edit")
		env.mock:advance(0.2)
		settle()
		local holding = { UserInputType = Enum.UserInputType.Touch, Position = Vector3.new(1278, 360, 0) }
		userInput.InputBegan:Fire(holding, false) -- a building parked at the right edge is held
		local start = controller:getFocus() :: Vector3
		expect(controller:setEditDrag(true, Vector2.new(1278, 360))).toBe(true)
		frames(30) -- no move after the hold: the edge-pan still runs
		expect(((controller:getFocus() :: Vector3) - start).Magnitude > 1).toBe(true)
	end)

	it("heldTouch: the touch nearest the press point, a tie keeps the older; no point gives the oldest", function()
		local a = { Position = Vector3.new(100, 100, 0) }
		local b = { Position = Vector3.new(500, 100, 0) }
		local c = { Position = Vector3.new(300, 100, 0) }
		expect(CameraDef.heldTouch({ a, b }, Vector2.new(480, 90))).toBe(b)
		expect(CameraDef.heldTouch({ a, b }, Vector2.new(110, 100))).toBe(a)
		expect(CameraDef.heldTouch({ a, b, c }, Vector2.new(400, 100))).toBe(b) -- b and c tie at 100 px: b is older
		expect(CameraDef.heldTouch({ a, b }, nil)).toBe(a)
		expect(CameraDef.heldTouch({ a, b }, Vector2.new(0 / 0, 1))).toBe(a)
		expect(CameraDef.heldTouch({ {}, b }, Vector2.new(110, 100))).toBe(b) -- a touch without a position is skipped
		expect(CameraDef.heldTouch({}, Vector2.new(1, 1))).toBeNil()
	end)

	it("setEditDrag(true) stops a pan already under way, and a held drag never pans until a new press", function()
		boot()
		controller:setMode("overview")
		input:set("edit")
		env.mock:advance(0.2)
		settle()
		local start = controller:getFocus() :: Vector3
		mouse("InputBegan", Enum.UserInputType.MouseButton1, 400, 300)
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 300, 300) -- a pan starts
		expect(controller._drag).never.toBeNil()
		expect(controller:setEditDrag(true)).toBe(true)
		expect(controller._drag).toBeNil() -- FORGE-03 can rely on this (#234 ask 2)
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 200, 300)
		controller:setEditDrag(false) -- the hold ends
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 100, 300) -- the button is still down
		frames(20)
		local after = controller:getFocus() :: Vector3
		-- only the pan made before the hold moved the view; nothing after the hold began
		mouse("InputChanged", Enum.UserInputType.MouseMovement, 50, 300)
		frames(20)
		expect(near(controller:getFocus() :: Vector3, after, 1e-6)).toBe(true)
		expect((after - start).Magnitude < 1e3).toBe(true)
	end)

	it("a selection never moves the camera, in edit mode too (B17 Move flow: a tap aims the ghost; #148 B1)", function()
		boot()
		local kingdoms = roblox.Instance.new("Folder")
		kingdoms.Name = "ForgeKingdoms"
		local crimson = roblox.Instance.new("Folder")
		crimson.Name = "crimson"
		crimson.Parent = kingdoms
		local buildings = roblox.Instance.new("Folder")
		buildings.Name = "Buildings"
		buildings.Parent = crimson
		local house = roblox.Instance.new("Model")
		house:SetAttribute("BuildingId", 9)
		local base = roblox.Instance.new("Part")
		base.CFrame = CFrame.new(THRONE.X + 60, 0, THRONE.Z - 30)
		base.Parent = house
		house.PrimaryPart = base
		house.Parent = buildings
		kingdoms.Parent = env.Workspace
		settle()
		local before = controller:getFocus() :: Vector3
		input:select("building", 9) -- explore mode: the panel's own "go to" decides
		expect(near(controller:getFocus() :: Vector3, before, 1e-6)).toBe(true)
		-- edit mode lasts while a building is moved (D-052 (1)); a tap on one of your buildings there is
		-- the player aiming the ghost next to it, so the view must not jump to it
		input:set("edit")
		input:select("building", 9)
		input:select("slot", "crimson_slot1")
		frames(30)
		expect(near(controller:getFocus() :: Vector3, before, 1e-6)).toBe(true)
		expect(controller.mode).toBe("overview")
	end)

	it("VFXController shake requests rotate the camera and fade out after their duration", function()
		boot({ vfx })
		controller:setMode("follow") -- Roblox's camera owns the CFrame; shake is added on top
		local shakes = registry:get("VFXController").shakeRequested
		local still = camera.CFrame
		shakes:fire(0.4, 0.3)
		controller:update(0.05)
		expect(near(camera.CFrame.LookVector, still.LookVector, 1e-6)).toBe(false)
		local angle = math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(still.LookVector), -1, 1)))
		expect(angle <= 2 * C.shake.maxDegrees * 0.4 + 1e-3).toBe(true)
		camera.CFrame = still
		controller:update(0.3)
		camera.CFrame = still
		controller:update(DT)
		expect(near(camera.CFrame.LookVector, still.LookVector, 1e-9)).toBe(true)
	end)

	it("undoes each frame's shake before Roblox's camera runs, so walk mode never drifts (#29 Medium)", function()
		boot({ vfx })
		controller:setMode("follow")
		local still = camera.CFrame
		controller:shake(1, 0.5)
		-- a frame: our undo step, then Roblox's camera (it turns from the current look; here it holds it),
		-- then our update adds this frame's shake
		for _ = 1, 40 do
			controller:undoShake()
			camera.CFrame = camera.CFrame -- Roblox's camera keeps the look it reads
			controller:update(DT)
		end
		controller:undoShake()
		expect(#controller._shakes).toBe(0)
		-- no lasting turn (within single-precision rounding over 40 frames; without the undo it is degrees)
		expect(near(camera.CFrame.LookVector, still.LookVector, 1e-4)).toBe(true)
		-- someone else moved the camera after our shake: the undo leaves their CFrame alone
		controller:shake(1, 0.5)
		controller:update(DT)
		local moved = CFrame.new(5, 5, 5)
		camera.CFrame = moved
		controller:undoShake()
		expect(camera.CFrame).toBe(moved)
	end)

	it("refuses NaN and infinite shakes, which would poison the camera (#29 Medium)", function()
		boot({ vfx })
		local nan = 0 / 0
		expect(controller:shake(nan, 1)).toBe(false)
		expect(controller:shake(1, nan)).toBe(false)
		expect(controller:shake(math.huge, 1)).toBe(false)
		expect(controller:shake(1, math.huge)).toBe(false)
		expect(#controller._shakes).toBe(0)
		registry:get("VFXController").shakeRequested:fire(nan, nan)
		controller:update(DT)
		local look = camera.CFrame.LookVector
		expect(look.X == look.X and look.Y == look.Y and look.Z == look.Z).toBe(true)
	end)

	it("never shakes when camera shake is off or reduced motion is on (incl. the platform setting)", function()
		for _, values in { { cameraShake = false }, { reducedMotion = true }, { platformReduced = true } } do
			env = MockEnv.new({ seed = 59, isServer = false, localPlayer = { userId = 5802 } })
			boot({ vfx, D.settings(values) })
			controller:setMode("follow")
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

	it(
		"focusOn(position, { duration }) glides to the citizen; restore() glides back to the saved view (FL-0100)",
		function()
			boot()
			settle()
			local saved =
				{ focus = controller:getFocus(), yaw = controller._target.yaw, zoom = controller._target.zoom }
			local citizen = THRONE + Vector3.new(30, 0, -20)
			expect(controller:focusOn(citizen, { duration = 0.6 })).toBe(true)
			local view =
				CameraDef.conversationView(citizen, saved.yaw, C.conversation, controller._bounds, O.boundsMargin)
			local goal = CameraDef.aerialCFrame(view.focus, view.yaw, view.zoom, O)
			frames(6) -- 0.1 s in: on the way, not there
			expect(near(camera.CFrame.Position, goal.Position, 0.5)).toBe(false)
			expect(near(controller._shown.focus, view.focus, 0.5)).toBe(false) -- the focus eases too
			expect(near(controller._shown.focus, saved.focus, 0.5)).toBe(false)
			frames(math.ceil(0.6 / DT))
			expect(near(camera.CFrame.Position, goal.Position, 1e-3)).toBe(true)
			expect(controller:focusOn(citizen + Vector3.new(4, 0, 0), {})).toBe(true) -- a second citizen
			expect(controller:restore()).toBe(true)
			frames(math.ceil(0.6 / DT) + 1)
			expect(controller:getFocus()).toBe(saved.focus) -- the first saved view, not the second citizen
			expect(controller._target.yaw).toBe(saved.yaw)
			expect(controller._target.zoom).toBe(saved.zoom)
			local back = CameraDef.aerialCFrame(saved.focus, saved.yaw, saved.zoom, O)
			expect(near(camera.CFrame.Position, back.Position, 1e-3)).toBe(true)
			expect(controller:restore()).toBe(false) -- nothing left to restore
		end
	)

	it(
		"playShots glides through each shot and stays on the last; the player's turn, pan or zoom takes over (FL-0074)",
		function()
			boot()
			settle()
			local a = THRONE + Vector3.new(20, 0, -10)
			local b = THRONE + Vector3.new(-20, 0, 10)
			local shots = {
				{ focus = a, yaw = 0, zoom = 60, seconds = 0.5 },
				{ focus = b, yaw = math.pi / 2, zoom = 80, seconds = 0.5 },
			}
			expect(controller:playShots(shots)).toBe(true)
			expect(controller:shotsPlaying()).toBe(true)
			frames(8) -- on the way to the first shot
			local goalA = CameraDef.aerialCFrame(a, 0, 60, O)
			expect(near(camera.CFrame.Position, goalA.Position, 0.5)).toBe(false)
			frames(22) -- 0.5 s: the first shot
			expect(near(camera.CFrame.Position, goalA.Position, 1e-2)).toBe(true)
			frames(35) -- the second shot, then the pass ends and the view stays
			local goalB = CameraDef.aerialCFrame(b, math.pi / 2, 80, O)
			expect(near(camera.CFrame.Position, goalB.Position, 1e-2)).toBe(true)
			expect(controller:shotsPlaying()).toBe(false)
			frames(30)
			expect(near(camera.CFrame.Position, goalB.Position, 1e-2)).toBe(true)
			expect(controller:getFocus()).toBe(b)
			for _, takeOver in
				{
					function()
						controller:rotateBy(10)
					end,
					function()
						controller:panBy(Vector2.new(5, 0))
					end,
					function()
						controller:zoomBy(1)
					end,
					function()
						controller:focusOn(THRONE)
					end,
				}
			do
				expect(controller:playShots({ { focus = a, yaw = 0, zoom = 60, seconds = 2 } })).toBe(true)
				frames(3)
				takeOver()
				expect(controller:shotsPlaying()).toBe(false)
				expect(controller._glide).toBeNil() -- handed over at once, not after the glide
			end
			-- a conversation ends the pass too: its own glide replaces the pass's
			expect(controller:playShots({ { focus = a, yaw = 0, zoom = 60, seconds = 2 } })).toBe(true)
			frames(3)
			controller:focusOn(THRONE, { duration = 0.5 })
			expect(controller:shotsPlaying()).toBe(false)
			expect(controller._glide).never.toBeNil()
			local goal = controller._glide.to.focus -- the conversation view (framed near the citizen)
			expect((goal - THRONE).Magnitude < (goal - a).Magnitude).toBe(true)
			-- bad shots are refused; zoom and seconds are clamped
			expect(controller:playShots({})).toBe(false)
			expect(controller:playShots("shots")).toBe(false)
			expect(controller:playShots({ { focus = a, yaw = 0 / 0, zoom = 60, seconds = 1 } })).toBe(false)
			expect(controller:playShots({ { focus = a, yaw = 0, zoom = 60, seconds = 0 } })).toBe(false)
			expect(controller:playShots({ { focus = a, yaw = 0, zoom = 1000, seconds = 99 } })).toBe(true)
			expect(controller._shots.list[1].zoom).toBe(O.maxZoom)
			expect(controller._shots.list[1].seconds).toBe(CameraDef.SHOT_MAX_SEC)
			-- a focus far off the map is clamped into the camera's bounds, like focusOn
			local far = THRONE + Vector3.new(100000, 0, -100000)
			expect(controller:playShots({ { focus = far, yaw = 0, zoom = 60, seconds = 1 } })).toBe(true)
			local clamped = controller._shots.list[1].focus
			expect(clamped.X < far.X and clamped.Z > far.Z).toBe(true)
			expect(near(clamped, CameraDef.clampFocus(far, controller._bounds, O.boundsMargin), 1e-6)).toBe(true)
			expect(controller:stopShots()).toBe(true)
			expect(controller:stopShots()).toBe(false)
		end
	)

	it("reduced motion cuts to each shot and holds it; walk mode refuses a pass and ends one (FL-0074)", function()
		boot({ D.settings({ reducedMotion = true }) })
		settle()
		local a = THRONE + Vector3.new(20, 0, -10)
		local b = THRONE + Vector3.new(-20, 0, 10)
		controller:playShots({
			{ focus = a, yaw = 0, zoom = 60, seconds = 0.5 },
			{ focus = b, yaw = 0, zoom = 60, seconds = 0.5 },
		})
		controller:update(DT)
		local goalA = CameraDef.aerialCFrame(a, 0, 60, O)
		expect(near(camera.CFrame.Position, goalA.Position, 1e-3)).toBe(true) -- one frame: a cut
		frames(20)
		expect(near(camera.CFrame.Position, goalA.Position, 1e-3)).toBe(true) -- held
		frames(12)
		local goalB = CameraDef.aerialCFrame(b, 0, 60, O)
		expect(near(camera.CFrame.Position, goalB.Position, 1e-3)).toBe(true) -- the next cut
		expect(controller:playShots({ { focus = a, yaw = 0, zoom = 60, seconds = 2 } })).toBe(true)
		controller:setMode("follow")
		expect(controller:shotsPlaying()).toBe(false)
		frames(2)
		expect(controller:playShots({ { focus = a, yaw = 0, zoom = 60, seconds = 2 } })).toBe(false)
		controller:setMode("overview")
		expect(controller:shotsPlaying()).toBe(false)
	end)

	it("reduced motion cuts to the conversation view instead of gliding (FL-0100)", function()
		boot({ D.settings({ reducedMotion = true }) })
		settle()
		local citizen = THRONE + Vector3.new(30, 0, -20)
		controller:focusOn(citizen, { duration = 0.6 })
		controller:update(DT)
		local view = CameraDef.conversationView(
			citizen,
			controller._target.yaw,
			C.conversation,
			controller._bounds,
			O.boundsMargin
		)
		local goal = CameraDef.aerialCFrame(view.focus, view.yaw, view.zoom, O)
		expect(near(camera.CFrame.Position, goal.Position, 1e-3)).toBe(true) -- one frame: a cut
	end)

	it("follows ConversationController.opened / closed; a pan ends a glide; walk mode ignores it (FL-0100)", function()
		local opened, closed = Signal.new(), Signal.new()
		boot({
			{
				name = "ConversationController",
				dependencies = {},
				new = function()
					return { opened = opened, closed = closed }
				end,
			},
		})
		settle()
		local saved = controller:getFocus()
		local citizen = THRONE + Vector3.new(-25, 0, 15)
		opened:fire(7, citizen)
		local view = CameraDef.conversationView(
			citizen,
			controller._target.yaw,
			C.conversation,
			controller._bounds,
			O.boundsMargin
		)
		expect(controller:getFocus()).toBe(view.focus)
		expect(controller._glide).never.toBeNil()
		controller:panBy(Vector2.new(1, 0)) -- the player takes over
		expect(controller._glide).toBeNil()
		closed:fire(7)
		expect(controller:getFocus()).toBe(saved)
		controller:setMode("follow")
		expect(controller:focusOn(citizen, {})).toBe(false)
		expect(env.mock:hasLog("info", "conversation focus waits")).toBe(false)
	end)

	it(
		"conversationYaw() looks at the citizen's face; no usable facing keeps the current yaw (G13.8 v0.4-g9e)",
		function()
			for _, facing in { Vector3.new(0, 0, -1), Vector3.new(1, 0, 0), Vector3.new(-0.6, 0.3, 0.8) } do
				local yaw = CameraDef.conversationYaw(facing, 0)
				local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw)) -- what aerialCFrame looks along
				local flat = Vector3.new(facing.X, 0, facing.Z).Unit
				expect(near(forward, -flat, 1e-6)).toBe(true) -- the camera faces the citizen's front
			end
			expect(CameraDef.conversationYaw(nil, 1.25)).toBe(1.25)
			expect(CameraDef.conversationYaw(Vector3.new(0, 1, 0), 1.25)).toBe(1.25) -- straight up: no facing
			expect(CameraDef.conversationYaw(Vector3.new(0 / 0, 0, 1), 1.25)).toBe(1.25)
		end
	)

	local function conversationWorld()
		local opened, closed = Signal.new(), Signal.new()
		local rig = { at = Vector3.zero, facing = Vector3.new(1, 0, 0) }
		function rig:GetPivot()
			return CFrame.lookAt(self.at, self.at + self.facing)
		end
		boot({
			{
				name = "ConversationController",
				dependencies = {},
				new = function()
					return { opened = opened, closed = closed }
				end,
			},
			{
				name = "EntityController",
				dependencies = {},
				new = function()
					return {
						getModel = function(_, id)
							return if id == 7 then rig else nil
						end,
					}
				end,
			},
		})
		settle()
		return opened, closed, rig
	end

	it(
		"faces the citizen toward the ruler's character, as the server turns them; nothing to follow (v0.4-g9e)",
		function()
			local opened, _, rig = conversationWorld()
			local citizen = THRONE + Vector3.new(-25, 0, 15)
			rig.at = citizen -- facing away (+X) until the server's hold turns them
			local ruler = controller._ruler:getRoot().CFrame.Position
			opened:fire(7, citizen)
			expect(controller._target.yaw).toBe(CameraDef.conversationYaw(ruler - citizen, 0))
			expect(controller._talking).toBeNil() -- the facing is already the final one: no second glide
			rig.facing = Vector3.new(0, 0, 1)
			rig.at = citizen + Vector3.new(6, 0, 0)
			frames(math.ceil(CameraDef.FOLLOW_SEC / DT) * 3)
			expect(controller._target.yaw).toBe(CameraDef.conversationYaw(ruler - citizen, 0))
		end
	)

	it("without a ruler character: the rig's facing, one turn followed, never a released citizen (#84 M1)", function()
		local opened, closed, rig = conversationWorld()
		controller._ruler = nil -- no ruler character on this client
		local citizen = THRONE + Vector3.new(-25, 0, 15)
		rig.at = citizen
		opened:fire(7, citizen)
		expect(controller._target.yaw).toBe(CameraDef.conversationYaw(Vector3.new(1, 0, 0), 0))
		rig.facing = Vector3.new(0, 0, 1) -- the server's turn toward the ruler arrives
		frames(math.ceil(CameraDef.FOLLOW_SEC / DT) + 1)
		local turned = CameraDef.conversationYaw(Vector3.new(0, 0, 1), 0)
		expect(controller._target.yaw).toBe(turned)
		expect(controller._talking).toBeNil() -- one turn, then the camera holds
		rig.facing = Vector3.new(-1, 0, 0)
		frames(math.ceil(CameraDef.FOLLOW_SEC / DT) + 1)
		expect(controller._target.yaw).toBe(turned)
		closed:fire(7)
		-- released (EndConversation, the 12 s hold of v0.4-g9f, or an alarm): the citizen walks off, panel open
		rig.at, rig.facing = citizen, Vector3.new(1, 0, 0)
		opened:fire(7, citizen)
		local held = controller._target.yaw
		local focus = controller:getFocus()
		frames(math.ceil(CameraDef.FOLLOW_WINDOW_SEC / DT) + 1) -- no turn came within the window
		expect(controller._talking).toBeNil()
		for step = 1, 4 do -- FORGE-05's probe: four legs, turning each time
			rig.at = citizen + Vector3.new(1.5 * step, 0, 0)
			rig.facing = Vector3.new(math.cos(step), 0, math.sin(step))
			frames(math.ceil(CameraDef.FOLLOW_SEC / DT) + 1)
		end
		expect(controller._target.yaw).toBe(held)
		expect(controller:getFocus()).toBe(focus)
		closed:fire(7)
		-- released early and already 3 studs off inside the window: still not followed
		rig.at, rig.facing = citizen, Vector3.new(1, 0, 0)
		opened:fire(7, citizen)
		rig.at, rig.facing = citizen + Vector3.new(3, 0, 0), Vector3.new(0, 0, -1)
		frames(math.ceil(CameraDef.FOLLOW_SEC / DT) + 1)
		expect(controller._target.yaw).toBe(held)
		expect(controller._talking).toBeNil()
		closed:fire(7)
		-- the player's own turn during the window wins over the citizen's
		rig.at, rig.facing = citizen, Vector3.new(1, 0, 0)
		opened:fire(7, citizen)
		controller:rotateBy(30)
		local mine = controller._target.yaw
		rig.facing = Vector3.new(0, 0, 1)
		frames(math.ceil(CameraDef.FOLLOW_SEC / DT) + 1)
		expect(controller._target.yaw).toBe(mine)
	end)

	it("a conversation that ends in walk mode leaves no glide to replay in the overview (#84 L1)", function()
		local opened, closed = conversationWorld()
		local citizen = THRONE + Vector3.new(-25, 0, 15)
		opened:fire(7, citizen)
		frames(math.ceil(C.conversation.durationSec / DT) + 1)
		controller:setMode("follow")
		closed:fire(7)
		expect(controller._glide).never.toBeNil() -- restore() glides, but nothing steps it in walk mode
		controller:setMode("overview")
		expect(controller._glide).toBeNil()
	end)

	it(
		"zooming in during a conversation never moves the camera out; glide durations are clamped (#84 L2, L3)",
		function()
			local opened, closed = conversationWorld()
			local citizen = THRONE + Vector3.new(-25, 0, 15)
			opened:fire(7, citizen)
			expect(controller._target.zoom).toBe(C.conversation.zoom)
			controller:zoomBy(-1)
			expect(controller._target.zoom).toBe(C.conversation.zoom) -- 30, not the overview's 40
			controller:zoomBy(1)
			expect(controller._target.zoom).toBe(C.conversation.zoom + O.zoomStep)
			closed:fire(7)
			controller:zoomBy(-20)
			expect(controller._target.zoom).toBe(O.minZoom)
			local default = C.conversation.durationSec
			expect(CameraDef.glideDuration(0 / 0, default)).toBe(default)
			expect(CameraDef.glideDuration(math.huge, default)).toBe(default)
			expect(CameraDef.glideDuration(-1, default)).toBe(default)
			expect(CameraDef.glideDuration(100, default)).toBe(CameraDef.MAX_GLIDE_SEC)
			expect(CameraDef.glideDuration(0.3, default)).toBe(0.3)
			expect(controller:focusOn(citizen, { duration = 0 / 0 })).toBe(true)
			expect(controller._glide.duration).toBe(default)
			frames(math.ceil(default / DT) + 1)
			expect(controller._glide).toBeNil() -- it ends
		end
	)

	it(
		"on a phone the citizen's head sits just under the HUD stack, above a costed conversation's stage (FL-0099)",
		function()
			boot()
			settle()
			local citizen = THRONE + Vector3.new(30, 0, -20)
			local function fromTop(point)
				local p = camera.CFrame:PointToObjectSpace(point)
				local ndc = (p.Y / -p.Z) / math.tan(math.rad(C.fieldOfView / 2))
				return (1 - ndc) / 2
			end
			controller._opts.viewportWidth, controller._opts.viewportHeight = 750, 311 -- FORGE-03's phone
			controller:focusOn(citizen, { duration = 0 })
			frames(2)
			local head = fromTop(citizen + Vector3.new(0, 4, 0))
			expect(head >= 0.27 and head <= 0.31).toBe(true) -- above a costed stage's top at 29-30 %
			expect(fromTop(citizen + Vector3.new(0, 5, 0)) >= 0.26).toBe(true) -- below the HUD stack (26 %)
			expect(fromTop(citizen) <= 0.40).toBe(true) -- whole citizen clear of a short stage at 47 %
			local phone = controller:getFocus()
			controller:restore({ duration = 0 })
			controller._opts.viewportWidth, controller._opts.viewportHeight = 1920, 1080
			controller:focusOn(citizen, { duration = 0 })
			local desktop = CameraDef.conversationView(
				citizen,
				controller._target.yaw,
				C.conversation,
				controller._bounds,
				O.boundsMargin
			)
			expect(controller:getFocus()).toBe(desktop.focus) -- desktop keeps the usual offset
			expect(near(phone, desktop.focus, 1)).toBe(false)
		end
	)

	it("boots with no camera, input services or character (headless) and does nothing", function()
		local bare = MockEnv.new({ seed = 60, isServer = false, localPlayer = { userId = 5803 } })
		local reg = D.boot(bare, {})
		local cam = reg:get("RulerCameraController")
		expect(cam.mode).toBe("overview")
		expect(cam:setMode("follow")).toBe(true)
		cam:update(DT)
		expect(bare.mock:hasLog("info", "RulerCameraController: input services unavailable")).toBe(true)
		expect(bare.mock.threadErrors).toEqual({})
	end)
end)
