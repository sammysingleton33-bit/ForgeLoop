--!strict
--[[
	RulerCameraController (game-001, FORGE-04, FL-0053 + FL-0090; CONTRACTS G4.1, G13.6): the ruler's camera.

		local camera = registry:find("RulerCameraController")
		camera:setMode("follow")            -- "overview" (default) | "follow"; false for anything else
		camera.mode, camera.changed:connect(function(mode, previous) ... end)
		camera:panBy(Vector2) / camera:rotateBy(degrees) / camera:zoomBy(steps)   -- overview rig
		camera:focusOn(position)            -- e.g. a panel's "go to" button; clamped to the map
		camera:focusOn(position, { duration = 0.6 }) -> boolean   -- conversations (G13.8, FL-0100): glide
		                                    -- to `conversation.zoom` studs, the citizen above the centre
		camera:restore() -> boolean         -- glide back to the view saved by the first focusOn(_, opts)
		camera:getFocus() -> Vector3?
		camera:shake(magnitude, duration)   -- VFXController.shakeRequested is wired to this
		camera:setEditDrag(active)          -- base editing (G13.9, FL-0121): while a building is dragged,
		                                    -- the drag never pans; the screen edge does (edge-pan)

	overview (default, D-030): the aerial management view. The ruler sits on the throne (FORGE-01
	seats them) while the player looks after the kingdom from above.
		- Pan: WASD / arrow keys, left-mouse drag, one-finger drag, or the left stick. Speed scales
		  with the zoom, so the screen moves at the same rate whether close or far.
		- Zoom: mouse wheel, pinch, or zoomBy(); overview.minZoom..maxZoom studs (≈ 40–220, G13.6)
		  from the focus. The pitch follows the zoom: flatter close up, steeper far out.
		- Rotate: Q / E, right-mouse drag, a two-finger twist, or the right stick. Q / E are not bound
		  in build or edit mode: there FORGE-03's placement and move take Q (cancel) and R / Shift+R
		  (turn the building), so the view turns with the right mouse button, a twist or the stick.
		- Bounded to the map: the focus stays inside the Layout regions' box (G10.1) plus a margin.
		- Streaming: when the focus moves far, the camera asks the server to stream around it
		  (Player:RequestStreamAroundAsync, throttled; Player.ReplicationFocus is server-only).
		- Interest focus (D-055 (5)): the overview reports its ground focus (clamped to the map) through
		  FORGE-01's `Sim.Focus` remote, at most once per FOCUS.everySec (4 a second), and again after
		  FOCUS.keepaliveSec even when it holds still, so the server's staleness fallback never kicks in
		  while the player watches one spot. A move under FOCUS.moveStuds (10 studs) waits for the
		  keepalive. Walk mode reports nothing (the character is the fallback).
		  Spectators report the same way. Interest only: the server never uses it for authority.
		- The character's movement and jump keys are sunk (ContextActionService, High priority) and
		  the touch thumbstick is hidden (GuiService.TouchControlsEnabled), so the ruler stays seated.
	follow (walk mode, kept from FL-0053): Roblox's third-person camera with zoom follow.minZoom..
	maxZoom (never first person), a shoulder offset and the field of view. Entering it makes the
	ruler stand up (RulerController:standUp) and shows the touch controls again.
	Switching: V / gamepad Y / the touch "View" button. overviewInBuild: build mode and base editing
	("edit", G13.9) always use the overview, and leaving them restores the previous mode unless the
	player chose one meanwhile.
	Base editing (G13.9, FL-0121): in B17's Move flow (D-052 (1)) edit mode lasts while a building is
	being moved, and a tap there aims the ghost, so selections in edit mode never move the camera
	(FORGE-07's #148 B1 side effect). setEditDrag (parked with the drag gesture, FL-0123: no caller
	yet) is for FORGE-03's edit UI while it drags a building: a mouse drag or one-finger
	drag no longer pans; instead, a pointer within EDGE_PIXELS of the screen edge pans toward that
	edge (faster nearer the edge, at most panSpeed). setEditDrag(false), or leaving edit mode, ends it.
	Shake: magnitude 0..1 maps to at most shake.maxDegrees, eased out within maxDuration, at most
	maxActive at once, never with cameraShake off or reduced motion on (SettingsController); a NaN or
	infinite magnitude or duration is refused. Each frame's shake is undone before Roblox's camera
	runs (undoShake, bound at RenderPriority.Camera - 1), because Roblox's camera turns from the
	current look: a shake left in place would add up into a lasting turn in walk mode (#29).
	Conversations (D-036, G13.8): ConversationController.opened(entityId, position) glides the
	overview toward the citizen (eased over `duration`, the citizen framed above the centre so the
	portrait rising from the bottom never covers them, clamped to the map); .closed glides back to
	the saved focus, rotation and zoom. The camera stands in front of the citizen's face
	(Def.conversationYaw; v0.4-g9e): the server turns the held citizen to face the ruler's character,
	so the facing is the line from the citizen to the ruler's character, as the server computes it.
	Without a ruler character it falls back to the rig's facing (EntityController:getModel) and
	follows one turn at most (checked every FOLLOW_SEC, re-aimed past FOLLOW_DEGREES), only within
	FOLLOW_WINDOW_SEC of the opening and while the citizen stays within FOLLOW_STUDS of where the
	conversation opened: a citizen who walks away (released at EndConversation, after the hold's 12 s
	of v0.4-g9f, or by an alarm) never takes the camera with them, and the framing holds for the
	whole window. Reduced motion cuts instead of gliding. A pan, a "go to" or a turn by the player
	ends the glide and the following. Glide durations are clamped
	(Def.glideDuration). During a conversation the zoom may go down to the conversation's. Walk
	mode ignores conversations; coming back to the overview drops any glide left from one.

	The camera runs at RenderPriority.Camera + 1. Engine access is guarded: without a camera, input
	services or Layout it boots and does nothing (the headless boot gate).
	Pure helpers (specs): Def.aerialCFrame, Def.pitchFor, Def.clampFocus, Def.boundsFromLayout,
	Def.worldPerPixel, Def.panVector, Def.smooth, Def.ease, Def.clamp, Def.shakeAmplitude
]]

local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local ScreenLayout = require("../UI/Layout") -- FORGE-03's breakpoints (read only)
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local Def = {
	name = "RulerCameraController",
	dependencies = { "RulerController", "InputModeController" },
}

Def.MODES = table.freeze({ "overview", "follow" })
Def.DEFAULT_MODE = "overview"
Def.ACTION = "ForgeRulerView"
Def.PAN_ACTION = "ForgeOverviewPan"
Def.ROTATE_ACTION = "ForgeOverviewRotate"
Def.SEAT_ACTION = "ForgeOverviewSeat"
Def.RENDER_NAME = "ForgeRulerCamera"
Def.FOLLOW_SEC = 0.2 -- how often an open conversation re-reads the citizen's facing
Def.FOLLOW_DEGREES = 10 -- a smaller turn keeps the current view
Def.FOLLOW_STUDS = 2 -- a citizen further than this from where the conversation opened has been released
Def.FOLLOW_WINDOW_SEC = 1.5 -- the server's turn arrives within this (the hold starts at Converse)
Def.MAX_GLIDE_SEC = 3 -- longest conversation glide (a NaN or infinite duration takes the default)
Def.UNSHAKE_NAME = "ForgeRulerCameraUnshake"
Def.FOCUS_REMOTE = "Sim.Focus" -- FORGE-01's additive Sim remote (D-055 (5)); inert until it exists
Def.FOCUS = table.freeze({ everySec = 0.25, keepaliveSec = 1, moveStuds = 10 })
Def.PAN_KEYS = table.freeze({
	[Enum.KeyCode.W] = Vector2.new(0, 1),
	[Enum.KeyCode.Up] = Vector2.new(0, 1),
	[Enum.KeyCode.S] = Vector2.new(0, -1),
	[Enum.KeyCode.Down] = Vector2.new(0, -1),
	[Enum.KeyCode.A] = Vector2.new(-1, 0),
	[Enum.KeyCode.Left] = Vector2.new(-1, 0),
	[Enum.KeyCode.D] = Vector2.new(1, 0),
	[Enum.KeyCode.Right] = Vector2.new(1, 0),
})
Def.ROTATE_KEYS = table.freeze({ [Enum.KeyCode.Q] = -1, [Enum.KeyCode.E] = 1 })
Def.FALLBACK_BOUNDS = table.freeze({ min = Vector2.new(-1024, -1024), max = Vector2.new(1024, 1024) })

Def.DEFAULTS = table.freeze({
	fieldOfView = 70,
	follow = table.freeze({
		minZoom = 10,
		maxZoom = 70,
		shoulder = Vector3.new(1.25, 0.75, 0),
	}),
	overview = table.freeze({
		minZoom = 40,
		maxZoom = 220,
		startZoom = 120,
		minPitchDeg = 38, -- at minZoom
		maxPitchDeg = 65, -- at maxZoom
		zoomStep = 14, -- studs per wheel notch / zoomBy(1)
		panSpeed = 0.9, -- keys and stick: zoom distances per second
		rotateSpeed = 90, -- Q / E and the stick: degrees per second
		dragRotate = 0.3, -- right-drag: degrees per pixel
		smoothing = 12, -- 1/s: how fast the shown view follows the target view
		boundsMargin = 40,
		stickDeadzone = 0.2,
		streamMoveStuds = 128,
		streamEverySec = 1,
		streamTimeoutSec = 2,
	}),
	transitionSec = 0.6,
	-- conversation focus (G13.8): 25-35 studs from the citizen, the kingdom still visible around
	conversation = table.freeze({
		zoom = 30,
		offset = Vector2.new(0, -6), -- focus shift in screen studs (x right, y forward): the citizen above the centre
		-- phones (FORGE-03's measured FL-0099 stage tops at 750 x 311: 47 % with short answers, 29-30 %
		-- with costed or long ones; the HUD stack ends at 26 %): the head goes just under the HUD. At
		-- zoom 30 and 38° pitch, 12 studs put the head at 28-30 % and the feet at 37 %, so a short
		-- conversation shows the whole citizen and a long one hides at most the body (the portrait
		-- shows the face)
		phoneOffset = Vector2.new(0, -12),
		durationSec = 0.6,
	}),
	overviewInBuild = true,
	shake = table.freeze({
		maxDegrees = 2,
		maxDuration = 1,
		maxActive = 4,
	}),
})

-- Input modes that keep the aerial overview (G13.6 build, G13.9 edit).
Def.OVERVIEW_MODES = table.freeze({ build = true, edit = true })
Def.EDGE_PIXELS = 48 -- edge-pan band while dragging a building (G13.9)

-- Edge-pan direction for a pointer on screen: x = right, y = forward (screen up), each -1..1,
-- growing as the pointer nears the edge; zero outside the band.
function Def.edgeDirection(pointer: Vector2, viewport: Vector2, band: number): Vector2
	if viewport.X <= 0 or viewport.Y <= 0 or band <= 0 then
		return Vector2.zero
	end
	local function axis(at: number, size: number): number
		if at < band then
			return -math.clamp((band - at) / band, 0, 1)
		elseif at > size - band then
			return math.clamp((at - (size - band)) / band, 0, 1)
		end
		return 0
	end
	return Vector2.new(axis(pointer.X, viewport.X), -axis(pointer.Y, viewport.Y))
end

local Controller = {}
Controller.__index = Controller

-- ------------------------------------------------------------------ pure helpers

function Def.clamp(value: number, low: number, high: number): number
	return math.max(low, math.min(high, value))
end

-- Exponential smoothing that gives the same result for one step of dt as for two steps of dt/2.
function Def.smooth(current: any, target: any, rate: number, dt: number): any
	local alpha = 1 - math.exp(-rate * dt)
	if type(current) == "number" then
		return current + (target - current) * alpha
	end
	return current:Lerp(target, alpha)
end

-- Smoothstep easing for blends, t in [0, 1].
function Def.ease(t: number): number
	local x = Def.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Pitch (degrees below the horizon) for a zoom distance: flatter close up, steeper far out.
function Def.pitchFor(zoom: number, overview: any): number
	local span = overview.maxZoom - overview.minZoom
	local t = if span > 0 then Def.clamp((zoom - overview.minZoom) / span, 0, 1) else 0
	return overview.minPitchDeg + (overview.maxPitchDeg - overview.minPitchDeg) * t
end

-- Camera `zoom` studs from `focus`, facing along `yaw` (radians around +Y; yaw 0 looks toward -Z,
-- like the default camera), at the pitch for that zoom.
function Def.aerialCFrame(focus: Vector3, yaw: number, zoom: number, overview: any): CFrame
	local pitch = math.rad(Def.pitchFor(zoom, overview))
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local position = focus - forward * (zoom * math.cos(pitch)) + Vector3.new(0, zoom * math.sin(pitch), 0)
	return CFrame.lookAt(position, focus)
end

-- The overview view that frames a citizen at `position` for a conversation (G13.8): the focus moves
-- by `conversation.offset` in screen studs (`phoneOffset` on a phone), so the citizen sits above the
-- centre; clamped to the map.
function Def.conversationView(
	position: Vector3,
	yaw: number,
	conversation: any,
	bounds: any,
	margin: number,
	phone: boolean?
): any
	local offset = if phone and conversation.phoneOffset then conversation.phoneOffset else conversation.offset
	local focus = Def.clampFocus(position + Def.panVector(offset, yaw), bounds, margin)
	return { focus = focus, yaw = yaw, zoom = conversation.zoom }
end

-- The map box from Layout (G10.1): every region polygon point and every plot spawn.
function Def.boundsFromLayout(layout: any): { min: Vector2, max: Vector2 }?
	if type(layout) ~= "table" then
		return nil
	end
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	local function add(x: number, z: number)
		minX, minZ = math.min(minX, x), math.min(minZ, z)
		maxX, maxZ = math.max(maxX, x), math.max(maxZ, z)
	end
	for _, region in (if type(layout.regions) == "table" then layout.regions else {}) do
		for _, point in (if type(region) == "table" and type(region.polygon) == "table" then region.polygon else {}) do
			if typeof(point) == "Vector2" then
				add(point.X, point.Y)
			end
		end
	end
	for _, plot in (if type(layout.plots) == "table" then layout.plots else {}) do
		if type(plot) == "table" and typeof(plot.spawn) == "CFrame" then
			add(plot.spawn.Position.X, plot.spawn.Position.Z)
		end
	end
	if minX > maxX then
		return nil
	end
	return { min = Vector2.new(minX, minZ), max = Vector2.new(maxX, maxZ) }
end

-- Keeps the focus inside the bounds (plus the margin); the height is kept.
function Def.clampFocus(focus: Vector3, bounds: { min: Vector2, max: Vector2 }, margin: number): Vector3
	return Vector3.new(
		Def.clamp(focus.X, bounds.min.X - margin, bounds.max.X + margin),
		focus.Y,
		Def.clamp(focus.Z, bounds.min.Y - margin, bounds.max.Y + margin)
	)
end

-- Studs of ground per screen pixel at a zoom distance (vertical field of view in degrees).
function Def.worldPerPixel(zoom: number, fieldOfView: number, viewportHeight: number): number
	return 2 * zoom * math.tan(math.rad(fieldOfView) / 2) / math.max(viewportHeight, 1)
end

-- World XZ movement for a screen-space direction (x = right, y = forward) at `yaw`.
function Def.panVector(direction: Vector2, yaw: number): Vector3
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	return right * direction.X + forward * direction.Y
end

-- Eased-out amplitude (degrees) of one shake `age` seconds in.
function Def.shakeAmplitude(magnitude: number, duration: number, age: number, maxDegrees: number): number
	if duration <= 0 or age >= duration then
		return 0
	end
	local left = 1 - age / duration
	return Def.clamp(magnitude, 0, 1) * maxDegrees * left * left
end

local function yawOf(look: Vector3): number
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return 0
	end
	return math.atan2(-flat.X, -flat.Z)
end

-- The yaw that looks at a citizen's face, so the camera stands in front of them (G13.8 v0.4-g9e).
-- No usable facing (nil, flat or NaN): `fallback`, the current yaw.
function Def.conversationYaw(facing: any, fallback: number): number
	if typeof(facing) ~= "Vector3" then
		return fallback
	end
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude ~= flat.Magnitude or flat.Magnitude < 0.1 then
		return fallback
	end
	return yawOf(-flat)
end

-- A glide duration: a finite, non-negative number up to MAX_GLIDE_SEC, else `default`.
function Def.glideDuration(value: any, default: number): number
	if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then
		return default
	end
	return math.min(value, Def.MAX_GLIDE_SEC)
end

-- Shortest signed difference between two angles (radians).
local function angleDelta(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

local function connect(target: any, eventName: string, handler: (...any) -> ()): any
	local ok, connection = pcall(function()
		return target[eventName]:Connect(handler)
	end)
	return if ok then connection else nil
end

-- Core Signal connections have :disconnect(); engine (RBXScriptConnection) and mock ones :Disconnect().
local function disconnect(connection: any)
	pcall(function()
		if type(connection) == "table" and connection.disconnect ~= nil then
			connection:disconnect()
		else
			connection:Disconnect()
		end
	end)
end

local function track(list: { any }, connection: any)
	if connection ~= nil then
		table.insert(list, connection)
	end
end

local function guarded(env: any, field: string, override: any, member: string): any
	if override ~= nil then
		return override
	end
	local ok, service = pcall(function()
		local value = env[field]
		local _ = value[member] -- the boot gate's unmocked guard errors here
		return value
	end)
	return if ok then service else nil
end

-- ------------------------------------------------------------------ lifecycle

-- opts (specs): { config, camera, player, actions, userInput, guiService, runService, layout, viewportHeight,
--   viewportWidth, sendFocus = (Vector3) -> () }
function Def.create(env: any, registry: any, opts: { [string]: any }?): any
	local options = opts or {}
	local config = options.config or Def.DEFAULTS
	return setmetatable({
		_env = env,
		_registry = registry,
		_config = config,
		_opts = options,
		_connections = {},
		_shakes = {},
		_refused = {},
		_held = {},
		_rotateHeld = {},
		_stick = Vector2.zero,
		_stickTurn = 0,
		_drag = nil,
		_editDrag = false,
		_pointer = nil :: Vector2?,
		_panLast = nil,
		_pinch = 1,
		_twist = 0,
		_target = { focus = nil, yaw = 0, zoom = config.overview.startZoom },
		_shown = nil,
		_blendFrom = nil,
		_blendT = 1,
		_glide = nil :: any, -- { from, to, t, duration }: an eased move of the shown view (conversations)
		_saved = nil :: any, -- the view to return to after a conversation
		_autoFrom = nil,
		_rendering = false,
		_streamedAt = nil,
		_streamedFocus = nil,
		_focusSent = nil :: Vector3?,
		_focusSentAt = nil :: number?,
		_focusRemote = false,
		_focusLookedAt = nil :: number?,
		focusReports = 0,
		mode = Def.DEFAULT_MODE,
		changed = Signal.new(),
	}, Controller)
end

function Def.new(env: any, registry: any): any
	return Def.create(env, registry)
end

function Controller:start()
	local env, opts = self._env, self._opts
	local registry = self._registry
	self._ruler = registry:find("RulerController")
	self._input = registry:find("InputModeController")
	self._settings = registry:find("SettingsController")
	local vfx = registry:find("VFXController")
	local okCamera, foundCamera = pcall(function()
		return opts.camera or env.Workspace.CurrentCamera
	end)
	self._camera = if okCamera then foundCamera else nil
	local okPlayer, foundPlayer = pcall(function()
		return opts.player or env.Players.LocalPlayer
	end)
	self._player = if okPlayer then foundPlayer else nil
	local layout = if opts.layout ~= nil then opts.layout else Layout
	self._bounds = Def.boundsFromLayout(layout) or Def.FALLBACK_BOUNDS
	self._actions = guarded(env, "ContextActionService", opts.actions, "BindAction")
	self._userInput = guarded(env, "UserInputService", opts.userInput, "InputChanged")
	self._guiService = guarded(env, "GuiService", opts.guiService, "TouchControlsEnabled")

	if self._ruler ~= nil then
		track(
			self._connections,
			self._ruler.characterChanged:connect(function(character)
				self:_onCharacter(character)
			end)
		)
	end
	if self._input ~= nil then
		track(
			self._connections,
			self._input.changed:connect(function(mode, previous)
				self:_onInputMode(mode, previous)
			end)
		)
	end
	if vfx ~= nil and vfx.shakeRequested ~= nil then
		track(
			self._connections,
			vfx.shakeRequested:connect(function(magnitude, duration)
				self:shake(magnitude, duration)
			end)
		)
	end
	self:_listenConversations()
	self:_bindView()
	self:_bindPointer()
	self:_bindRender()
	if self._camera == nil then
		env.log("info", "RulerCameraController: no camera; camera modes are skipped")
	else
		pcall(function()
			self._camera.FieldOfView = self._config.fieldOfView
		end)
	end
	if self._actions == nil or self._userInput == nil then
		env.log("info", "RulerCameraController: input services unavailable; camera keys and gestures are skipped")
	end
	if self._ruler ~= nil and self._ruler:getCharacter() ~= nil then
		self:_onCharacter(self._ruler:getCharacter())
	end
	self:_apply()
end

function Controller:destroy()
	for _, connection in self._connections do
		disconnect(connection)
	end
	table.clear(self._connections)
	local actions = self._actions
	if actions ~= nil then
		for _, name in { Def.ACTION, Def.PAN_ACTION, Def.ROTATE_ACTION, Def.SEAT_ACTION } do
			pcall(function()
				actions:UnbindAction(name)
			end)
		end
	end
	self:_setTouchControls(true)
	if self._rendering then
		pcall(function()
			local runService = self._opts.runService or self._env.RunService
			runService:UnbindFromRenderStep(Def.RENDER_NAME)
			runService:UnbindFromRenderStep(Def.UNSHAKE_NAME)
		end)
		self._rendering = false
	end
	self.changed:disconnectAll()
end

-- ------------------------------------------------------------------ public API

function Controller:setMode(mode: any): boolean
	if self._input ~= nil and Def.OVERVIEW_MODES[self._input.mode] then
		self._autoFrom = nil -- the player chose a view while building or editing: keep it afterwards
	end
	return self:_setMode(mode)
end

function Controller:toggle(): boolean
	return self:setMode(if self.mode == "overview" then "follow" else "overview")
end

function Controller:getFocus(): Vector3?
	return self._target.focus
end

function Controller:focusOn(position: Vector3, opts: { duration: number?, facing: Vector3? }?): boolean
	if opts == nil then
		self._glide = nil -- a pan or a "go to" ends a conversation glide
		self._talking = nil -- and stops following the citizen's turn
		self._target.focus = Def.clampFocus(position, self._bounds, self._config.overview.boundsMargin)
		return true
	end
	if typeof(position) ~= "Vector3" or self.mode ~= "overview" or self._target.focus == nil then
		return false
	end
	local conversation = self._config.conversation or Def.DEFAULTS.conversation
	local target = self._target
	if self._saved == nil then
		self._saved = { focus = target.focus, yaw = target.yaw, zoom = target.zoom }
	end
	local yaw = Def.conversationYaw(opts.facing, target.yaw)
	local view = Def.conversationView(
		position,
		yaw,
		conversation,
		self._bounds,
		self._config.overview.boundsMargin,
		self:_isPhone()
	)
	self:_glideTo(view, Def.glideDuration(opts.duration, conversation.durationSec))
	return true
end

-- The citizen's rig pivot (EntityController:getModel); nil when there is no rig.
function Controller:_rigOf(entityId: any): CFrame?
	local entities = self._registry:find("EntityController")
	if entities == nil or entities.getModel == nil then
		return nil
	end
	local ok, pivot = pcall(function()
		local model = entities:getModel(entityId)
		return if model then model:GetPivot() else nil
	end)
	return if ok and typeof(pivot) == "CFrame" then pivot else nil
end

-- Where the held citizen will face (G13.8 v0.4-g9e): toward the ruler's character, as the server
-- turns them; "rig" when there is no ruler character and the rig's own facing is used instead.
function Controller:_conversationFacing(entityId: any, position: Vector3): (Vector3?, string?)
	local root = self._ruler and self._ruler:getRoot()
	if root ~= nil then
		local ok, toRuler = pcall(function()
			return root.CFrame.Position - position
		end)
		if ok and typeof(toRuler) == "Vector3" and Vector3.new(toRuler.X, 0, toRuler.Z).Magnitude > 0.5 then
			return toRuler, "ruler"
		end
	end
	local pivot = self:_rigOf(entityId)
	return if pivot then pivot.LookVector else nil, if pivot then "rig" else nil
end

-- Rig fallback only: the server's turn toward the ruler may arrive after the panel opened, so the
-- camera follows one such turn, and never a citizen who has been released and walks away.
function Controller:_followTalker(dt: number)
	local talking = self._talking
	if talking == nil then
		return
	end
	talking.age += dt
	if talking.age > Def.FOLLOW_WINDOW_SEC then
		self._talking = nil -- the hold's turn has had its time
		return
	end
	talking.wait -= dt
	if talking.wait > 0 then
		return
	end
	talking.wait = Def.FOLLOW_SEC
	local pivot = self:_rigOf(talking.entityId)
	if pivot == nil then
		return
	end
	local moved = pivot.Position - talking.position
	if Vector3.new(moved.X, 0, moved.Z).Magnitude > Def.FOLLOW_STUDS then
		self._talking = nil -- released: the camera stays where it is
		return
	end
	local yaw = Def.conversationYaw(pivot.LookVector, talking.yaw)
	if math.abs(angleDelta(talking.yaw, yaw)) < math.rad(Def.FOLLOW_DEGREES) then
		return
	end
	self._talking = nil -- the one turn: after it, the camera holds
	local conversation = self._config.conversation or Def.DEFAULTS.conversation
	local view = Def.conversationView(
		talking.position,
		yaw,
		conversation,
		self._bounds,
		self._config.overview.boundsMargin,
		self:_isPhone()
	)
	self:_glideTo(view, conversation.durationSec)
end

-- Back to the view saved by the first focusOn(position, opts). False when there is nothing to restore.
function Controller:restore(opts: { duration: number? }?): boolean
	local saved = self._saved
	self._saved = nil
	self._talking = nil
	if saved == nil or saved.focus == nil then
		return false
	end
	local conversation = self._config.conversation or Def.DEFAULTS.conversation
	local duration = Def.glideDuration(opts and opts.duration, conversation.durationSec)
	self:_glideTo(saved, duration)
	return true
end

-- ConversationController (FORGE-03, G13.8) fires opened(entityId, position) and closed(entityId).
-- Its signals may be framework Signals (:connect) or RBXScriptSignals (:Connect).
function Controller:_listenConversations()
	local conversations = self._registry:find("ConversationController")
	local function listen(signal: any, handler: (...any) -> ()): boolean
		if signal == nil then
			return false
		end
		local ok, connection = pcall(function()
			return if signal.connect then signal:connect(handler) else signal:Connect(handler)
		end)
		if ok and connection ~= nil then
			table.insert(self._connections, connection)
		end
		return ok
	end
	local opened = conversations
		and listen(conversations.opened, function(entityId, position)
			if typeof(position) ~= "Vector3" then
				return
			end
			local facing, source = self:_conversationFacing(entityId, position)
			if self:focusOn(position, { facing = facing }) and source == "rig" then
				self._talking =
					{ entityId = entityId, position = position, yaw = self._target.yaw, wait = Def.FOLLOW_SEC, age = 0 }
			end
		end)
	local closed = conversations and listen(conversations.closed, function()
		self:restore()
	end)
	if not (opened and closed) then
		self._env.log(
			"info",
			"RulerCameraController: no ConversationController.opened/closed yet (FORGE-03, G13.8); conversation focus waits"
		)
	end
end

function Controller:_reducedMotion(): boolean
	local settings = self._settings
	if settings == nil then
		return false
	end
	local ok, reduced = pcall(function()
		return if settings.reducedMotion then settings:reducedMotion() else settings:get("reducedMotion")
	end)
	return ok and reduced == true
end

-- Sets the target view; the shown view eases there over `duration` (a cut with reduced motion).
function Controller:_glideTo(view: any, duration: number)
	local target = self._target
	target.focus, target.yaw, target.zoom = view.focus, view.yaw, view.zoom
	local shown = self._shown
	if self:_reducedMotion() or duration <= 0 or shown == nil then
		self._glide = nil
		self._shown = nil -- the next frame starts at the target: a cut
		return
	end
	self._glide = {
		from = { focus = shown.focus, yaw = shown.yaw, zoom = shown.zoom },
		to = { focus = view.focus, yaw = view.yaw, zoom = view.zoom },
		t = 0,
		duration = duration,
	}
end

-- Moves the overview focus by a screen-space amount in studs (x = right, y = forward).
function Controller:panBy(studs: Vector2)
	local focus = self._target.focus
	if focus == nil then
		return
	end
	self:focusOn(focus + Def.panVector(studs, self._target.yaw))
end

-- Base editing (G13.9): while a building is dragged, drags never pan and the screen edge does.
function Controller:setEditDrag(active: any): boolean
	local on = active == true and self._input ~= nil and self._input.mode == "edit"
	self._editDrag = on
	if on then
		self._drag = nil -- a pan already under way stops
		self._panLast = nil
	end
	return on
end

function Controller:rotateBy(degrees: number)
	self._talking = nil -- the player turns the view: stop following the citizen
	self._target.yaw += math.rad(degrees)
end

function Controller:zoomBy(steps: number)
	local overview = self._config.overview
	local minZoom = overview.minZoom
	if self._saved ~= nil then
		-- in a conversation (30 studs, below the overview's minimum) zooming in never moves the camera out
		local conversation = self._config.conversation or Def.DEFAULTS.conversation
		minZoom = math.min(minZoom, conversation.zoom)
	end
	self._target.zoom = Def.clamp(self._target.zoom + steps * overview.zoomStep, minZoom, overview.maxZoom)
end

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

function Controller:shake(magnitude: any, duration: any): boolean
	if not finite(magnitude) or not finite(duration) or magnitude <= 0 or duration <= 0 then
		return false -- NaN would poison the camera CFrame for good (#29)
	end
	local settings = self._settings
	if settings ~= nil then
		local reduced = if settings.reducedMotion then settings:reducedMotion() else settings:get("reducedMotion")
		if reduced or settings:get("cameraShake") == false then
			return false
		end
	end
	local limits = self._config.shake
	table.insert(self._shakes, {
		magnitude = Def.clamp(magnitude, 0, 1),
		duration = math.min(duration, limits.maxDuration),
		age = 0,
	})
	while #self._shakes > limits.maxActive do
		table.remove(self._shakes, 1)
	end
	return true
end

-- One frame. Live: bound with BindToRenderStep after Roblox's camera; specs call it directly.
function Controller:update(dt: number)
	local camera = self._camera
	if camera == nil then
		return
	end
	if self.mode == "overview" then
		self:_stepOverview(dt, camera)
	end
	if #self._shakes > 0 then
		local pitch, yaw = self:_shakeDegrees(dt)
		local offset = CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
		camera.CFrame = camera.CFrame * offset
		self._shaken = { offset = offset, cframe = camera.CFrame }
	end
end

-- Before Roblox's camera (live: RenderPriority.Camera - 1): takes last frame's shake back out, so
-- the next frame starts from the unshaken view. Nothing to do if someone else moved the camera since.
function Controller:undoShake()
	local shaken = self._shaken
	local camera = self._camera
	self._shaken = nil
	if shaken == nil or camera == nil then
		return
	end
	local now = camera.CFrame
	local was = shaken.cframe
	-- the same CFrame within float precision (a CFrame property is stored in single precision)
	if
		(now.Position - was.Position).Magnitude < 1e-3
		and now.LookVector:Dot(was.LookVector) > 1 - 1e-6
		and now.UpVector:Dot(was.UpVector) > 1 - 1e-6
	then
		camera.CFrame = now * shaken.offset:Inverse()
	end
end

-- ------------------------------------------------------------------ overview

function Controller:_stepOverview(dt: number, camera: any)
	local overview = self._config.overview
	local target = self._target
	if target.focus == nil then
		return
	end
	self:_followTalker(dt)
	-- keys and stick: a screen direction, scaled with the zoom
	local direction = Vector2.zero
	for _, vector in self._held do
		direction += vector
	end
	direction += self._stick
	if self._editDrag and self._pointer ~= nil then
		direction += Def.edgeDirection(self._pointer, self:_viewport(), Def.EDGE_PIXELS)
	end
	if direction.Magnitude > 0 then
		direction = if direction.Magnitude > 1 then direction.Unit else direction
		self:panBy(direction * (overview.panSpeed * target.zoom * dt))
	end
	local turn = self._stickTurn
	for _, sign in self._rotateHeld do
		turn += sign
	end
	if turn ~= 0 then
		self:rotateBy(Def.clamp(turn, -1, 1) * overview.rotateSpeed * dt)
	end

	local shown = self._shown
	local glide = self._glide
	if shown == nil then
		shown = { focus = target.focus, yaw = target.yaw, zoom = target.zoom }
		self._shown = shown
	elseif glide ~= nil then
		glide.t = math.min(glide.duration, glide.t + dt)
		local k = Def.ease(glide.t / glide.duration)
		shown.focus = glide.from.focus:Lerp(glide.to.focus, k)
		shown.yaw = glide.from.yaw + angleDelta(glide.from.yaw, glide.to.yaw) * k
		shown.zoom = glide.from.zoom + (glide.to.zoom - glide.from.zoom) * k
		if glide.t >= glide.duration then
			self._glide = nil
		end
	else
		shown.focus = Def.smooth(shown.focus, target.focus, overview.smoothing, dt)
		shown.yaw += angleDelta(shown.yaw, target.yaw) * (1 - math.exp(-overview.smoothing * dt))
		shown.zoom = Def.smooth(shown.zoom, target.zoom, overview.smoothing, dt)
	end
	local goal = Def.aerialCFrame(shown.focus, shown.yaw, shown.zoom, overview)
	if self._blendFrom ~= nil then
		self._blendT = math.min(1, self._blendT + dt / self._config.transitionSec)
		camera.CFrame = self._blendFrom:Lerp(goal, Def.ease(self._blendT))
		if self._blendT >= 1 then
			self._blendFrom = nil
		end
	else
		camera.CFrame = goal
	end
	self:_streamAround(target.focus)
	self:_reportFocus(target.focus)
end

-- Sim.Focus (D-055 (5)): the overview's ground focus for the server's interest selection, throttled.
function Controller:_reportFocus(focus: Vector3)
	local now = self._env.clock()
	local rule = Def.FOCUS
	local sentAt = self._focusSentAt
	if sentAt ~= nil then
		if now - sentAt < rule.everySec then
			return
		end
		local sent = self._focusSent :: Vector3
		if (focus - sent).Magnitude < rule.moveStuds and now - sentAt < rule.keepaliveSec then
			return
		end
	end
	local send = self._opts.sendFocus
	if send == nil and not self:_focusRemoteReady() then
		return -- not declared yet (FORGE-01): never queue sends that would each wait out RemoteClient's timeout
	end
	self._focusSent, self._focusSentAt = focus, now
	self.focusReports += 1
	if send ~= nil then
		send(focus)
	else
		RemoteLink.send(self._env, Def.FOCUS_REMOTE, focus)
	end
end

-- ReplicatedStorage.ForgeRemotes.Sim.Focus exists (looked up at most once a second until found).
function Controller:_focusRemoteReady(): boolean
	if self._focusRemote then
		return true
	end
	local now = self._env.clock()
	if self._focusLookedAt ~= nil and now - self._focusLookedAt < 1 then
		return false
	end
	self._focusLookedAt = now
	local ok, found = pcall(function()
		local root = self._env.ReplicatedStorage:FindFirstChild("ForgeRemotes")
		local area = root and root:FindFirstChild("Sim")
		return area and area:FindFirstChild("Focus")
	end)
	self._focusRemote = ok and found ~= nil
	return self._focusRemote
end

function Controller:_streamAround(focus: Vector3)
	local overview = self._config.overview
	local player = self._player
	if player == nil then
		return
	end
	local now = self._env.clock()
	if self._streamedFocus ~= nil then
		local far = (focus - self._streamedFocus).Magnitude >= overview.streamMoveStuds
		if not far or now - (self._streamedAt :: number) < overview.streamEverySec then
			return
		end
	end
	self._streamedFocus, self._streamedAt = focus, now
	self._env.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(focus, overview.streamTimeoutSec)
		end)
	end)
end

-- Total shake rotation (degrees) right now; advances the shakes by dt.
function Controller:_shakeDegrees(dt: number): (number, number)
	local pitch, yaw = 0, 0
	local maxDegrees = self._config.shake.maxDegrees
	for index = #self._shakes, 1, -1 do
		local item = self._shakes[index]
		item.age += dt
		local amplitude = Def.shakeAmplitude(item.magnitude, item.duration, item.age, maxDegrees)
		if amplitude <= 0 then
			table.remove(self._shakes, index)
		else
			pitch += amplitude * math.sin(item.age * 47 + index)
			yaw += amplitude * math.sin(item.age * 31 + index * 2)
		end
	end
	return pitch, yaw
end

-- ------------------------------------------------------------------ modes

function Controller:_setMode(mode: any): boolean
	if not table.find(Def.MODES, mode) then
		local key = tostring(mode)
		if not self._refused[key] then
			self._refused[key] = true
			self._env.log("warn", `RulerCameraController: unknown camera mode '{key}'`, { mode = key })
		end
		return false
	end
	if mode == self.mode then
		return true
	end
	local previous = self.mode
	self.mode = mode
	self:_apply()
	self.changed:fire(mode, previous)
	return true
end

function Controller:_apply()
	local overview = self.mode == "overview"
	self:_bindOverviewKeys(overview)
	self:_setTouchControls(not overview)
	local camera = self._camera
	if overview then
		self._glide = nil -- a glide left from a conversation that ended in walk mode never replays
		self._talking = nil
		local root = self._ruler and self._ruler:getRoot()
		if self._target.focus == nil and root ~= nil then
			self:focusOn(root.CFrame.Position)
		end
		if camera ~= nil then
			self._target.yaw = yawOf(camera.CFrame.LookVector)
			self._shown = nil
			self._blendFrom = camera.CFrame
			self._blendT = 0
			camera.CameraType = Enum.CameraType.Scriptable
		end
	else
		self._blendFrom = nil
		if self._ruler ~= nil and self._ruler.standUp then
			self._ruler:standUp()
		end
		if camera ~= nil then
			camera.CameraType = Enum.CameraType.Custom
		end
		self:_applyFollow()
	end
end

function Controller:_applyFollow()
	local follow = self._config.follow
	local player = self._player
	if player ~= nil then
		pcall(function()
			player.CameraMaxZoomDistance = follow.maxZoom
			player.CameraMinZoomDistance = follow.minZoom
		end)
	end
	local humanoid = self._ruler and self._ruler:getHumanoid()
	if humanoid ~= nil then
		pcall(function()
			humanoid.CameraOffset = follow.shoulder
		end)
		local camera = self._camera
		if camera ~= nil and self.mode == "follow" then
			pcall(function()
				camera.CameraSubject = humanoid
			end)
		end
	end
end

function Controller:_onCharacter(character: any)
	if character == nil then
		return
	end
	local root = self._ruler and self._ruler:getRoot()
	if root ~= nil and self._target.focus == nil then
		self:focusOn(root.CFrame.Position) -- the throne: the first view is the player's own keep
	end
	self:_applyFollow()
end

function Controller:_onInputMode(mode: string, previous: string)
	if not Def.OVERVIEW_MODES[mode] then
		self:_bindRotateKeys(self.mode == "overview")
	else
		self:_bindRotateKeys(false) -- Q / R belong to FORGE-03's placement and move
	end
	if mode ~= "edit" then
		self:setEditDrag(false)
	end
	if not self._config.overviewInBuild then
		return
	end
	if Def.OVERVIEW_MODES[mode] then
		if self.mode ~= "overview" then
			self._autoFrom = self.mode
			self:_setMode("overview")
		end
	elseif Def.OVERVIEW_MODES[previous] and self._autoFrom ~= nil then
		local restore = self._autoFrom
		self._autoFrom = nil
		self:_setMode(restore)
	end
end

function Controller:_setTouchControls(enabled: boolean)
	local gui = self._guiService
	if gui ~= nil then
		pcall(function()
			gui.TouchControlsEnabled = enabled
		end)
	end
end

-- ------------------------------------------------------------------ input bindings

function Controller:_bindView()
	local actions = self._actions
	if actions == nil then
		return
	end
	pcall(function()
		actions:BindAction(Def.ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then
				self:toggle()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, true, Enum.KeyCode.V, Enum.KeyCode.ButtonY)
		actions:SetTitle(Def.ACTION, "View")
	end)
end

function Controller:_bindOverviewKeys(on: boolean)
	local actions = self._actions
	if actions == nil then
		return
	end
	if not on then
		table.clear(self._held)
		pcall(function()
			actions:UnbindAction(Def.PAN_ACTION)
			actions:UnbindAction(Def.SEAT_ACTION)
		end)
		self:_bindRotateKeys(false)
		return
	end
	local high = Enum.ContextActionPriority.High.Value
	pcall(function()
		local keys = {}
		for key in Def.PAN_KEYS do
			table.insert(keys, key)
		end
		actions:BindActionAtPriority(Def.PAN_ACTION, function(_, state, input)
			local key = input and input.KeyCode
			local vector = key and Def.PAN_KEYS[key]
			if vector == nil then
				return Enum.ContextActionResult.Pass
			end
			if state == Enum.UserInputState.Begin then
				self._held[key] = vector
			else
				self._held[key] = nil
			end
			return Enum.ContextActionResult.Sink -- the seated ruler never walks off
		end, false, high, table.unpack(keys))
		-- jump would unseat the ruler from the throne: sink it while in the overview
		actions:BindActionAtPriority(Def.SEAT_ACTION, function()
			return Enum.ContextActionResult.Sink
		end, false, high, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	end)
	self:_bindRotateKeys(self._input == nil or not Def.OVERVIEW_MODES[self._input.mode])
end

function Controller:_bindRotateKeys(on: boolean)
	local actions = self._actions
	if actions == nil then
		return
	end
	if not on then
		table.clear(self._rotateHeld)
		pcall(function()
			actions:UnbindAction(Def.ROTATE_ACTION)
		end)
		return
	end
	pcall(function()
		actions:BindActionAtPriority(Def.ROTATE_ACTION, function(_, state, input)
			local key = input and input.KeyCode
			local sign = key and Def.ROTATE_KEYS[key]
			if sign == nil then
				return Enum.ContextActionResult.Pass
			end
			self._rotateHeld[key] = if state == Enum.UserInputState.Begin then sign else nil
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Q, Enum.KeyCode.E)
	end)
end

-- FORGE-03's phone breakpoint (UI/Layout) for the viewport; specs set opts.viewportWidth/Height.
function Controller:_isPhone(): boolean
	local width = self._opts.viewportWidth
	if width == nil then
		local ok, size = pcall(function()
			return self._camera.ViewportSize.X
		end)
		width = if ok and type(size) == "number" and size > 0 then size else 1280
	end
	return ScreenLayout.breakpoint(width, self:_viewportHeight()) == "phone"
end

function Controller:_viewport(): Vector2
	local width = self._opts.viewportWidth
	if width == nil then
		local ok, size = pcall(function()
			return self._camera.ViewportSize.X
		end)
		width = if ok and type(size) == "number" then size else 0
	end
	return Vector2.new(width, self:_viewportHeight())
end

function Controller:_viewportHeight(): number
	if self._opts.viewportHeight then
		return self._opts.viewportHeight
	end
	local ok, height = pcall(function()
		return self._camera.ViewportSize.Y
	end)
	return if ok and type(height) == "number" and height > 0 then height else 720
end

function Controller:_tapPixels(): number
	return if self._input and self._input.tapPixels then self._input.tapPixels else 8
end

-- A screen-space drag of `pixels` (x right, y down) moves the ground with the pointer.
function Controller:dragBy(pixels: Vector2)
	local studsPerPixel = Def.worldPerPixel(self._target.zoom, self._config.fieldOfView, self:_viewportHeight())
	self:panBy(Vector2.new(-pixels.X, pixels.Y) * studsPerPixel)
end

function Controller:_bindPointer()
	local userInput = self._userInput
	if userInput == nil then
		return
	end
	local overview = self._config.overview
	track(
		self._connections,
		connect(userInput, "InputBegan", function(input, processed)
			if processed or self.mode ~= "overview" then
				return
			end
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2 then
				self._drag = { button = kind, start = input.Position, last = input.Position, active = false }
			end
		end)
	)
	track(
		self._connections,
		connect(userInput, "InputEnded", function(input)
			if self._drag and input.UserInputType == self._drag.button then
				self._drag = nil
			end
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				self._stick = Vector2.zero
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				self._stickTurn = 0
			end
		end)
	)
	track(
		self._connections,
		connect(userInput, "InputChanged", function(input, processed)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseWheel then
				if not processed and self.mode == "overview" then
					self:zoomBy(-input.Position.Z)
				end
			elseif kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
				self._pointer = Vector2.new(input.Position.X, input.Position.Y) -- edge-pan (G13.9)
				if kind == Enum.UserInputType.MouseMovement then
					self:_mouseMoved(input.Position)
				end
			elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
				local stick = Vector2.new(input.Position.X, input.Position.Y)
				self._stick = if stick.Magnitude >= overview.stickDeadzone and self.mode == "overview"
					then stick
					else Vector2.zero
			elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
				local x = input.Position.X
				self._stickTurn = if math.abs(x) >= overview.stickDeadzone and self.mode == "overview" then x else 0
			end
		end)
	)
	track(
		self._connections,
		connect(userInput, "TouchPan", function(touches, translation, _, state, processed)
			self:_touchPan(touches, translation, state, processed)
		end)
	)
	track(
		self._connections,
		connect(userInput, "TouchPinch", function(_, scale, _, state, processed)
			self:_pinchTo(scale, state, processed)
		end)
	)
	track(
		self._connections,
		connect(userInput, "TouchRotate", function(_, rotation, _, state, processed)
			self:_twistTo(rotation, state, processed)
		end)
	)
end

function Controller:_mouseMoved(position: Vector3)
	local drag = self._drag
	if drag == nil or self.mode ~= "overview" or self._editDrag then
		return
	end
	local delta = Vector2.new(position.X - drag.last.X, position.Y - drag.last.Y)
	drag.last = position
	if not drag.active then
		local moved = Vector2.new(position.X - drag.start.X, position.Y - drag.start.Y)
		if moved.Magnitude < self:_tapPixels() then
			return -- still a tap (InputModeController selects on release)
		end
		drag.active = true
		delta = moved
	end
	if drag.button == Enum.UserInputType.MouseButton1 then
		self:dragBy(delta)
	else
		self:rotateBy(delta.X * self._config.overview.dragRotate)
	end
end

-- One finger drags the ground; two-finger gestures are pinch and twist.
function Controller:_touchPan(touches: any, translation: Vector2, state: any, processed: boolean?)
	if state == Enum.UserInputState.Begin or self._panLast == nil then
		self._panLast = translation
	end
	if processed or self.mode ~= "overview" or self._editDrag or type(touches) ~= "table" or #touches ~= 1 then
		self._panLast = translation
		return
	end
	local delta = translation - self._panLast
	self._panLast = translation
	if translation.Magnitude >= self:_tapPixels() then
		self:dragBy(delta)
	end
	if state == Enum.UserInputState.End then
		self._panLast = nil
	end
end

-- TouchPinch reports the scale since the pinch began; zoom by the change since the last event.
-- Pinching out (scale growing) brings the camera closer.
function Controller:_pinchTo(scale: number, state: any, processed: boolean?)
	if state == Enum.UserInputState.Begin then
		self._pinch = 1
	end
	if processed or self.mode ~= "overview" or state ~= Enum.UserInputState.Change or scale <= 0 then
		return
	end
	local ratio = scale / self._pinch
	self._pinch = scale
	self:zoomBy((1 - ratio) * 5)
end

-- TouchRotate reports the degrees turned since the gesture began.
function Controller:_twistTo(rotation: number, state: any, processed: boolean?)
	if state == Enum.UserInputState.Begin then
		self._twist = 0
	end
	if processed or self.mode ~= "overview" or state ~= Enum.UserInputState.Change then
		return
	end
	local delta = rotation - self._twist
	self._twist = rotation
	self:rotateBy(-delta)
end

function Controller:_bindRender()
	local runService = self._opts.runService or self._env.RunService
	local ok = pcall(function()
		local priority = Enum.RenderPriority.Camera.Value + 1
		runService:BindToRenderStep(Def.RENDER_NAME, priority, function(dt)
			self:update(dt)
		end)
		runService:BindToRenderStep(Def.UNSHAKE_NAME, Enum.RenderPriority.Camera.Value - 1, function()
			self:undoShake()
		end)
	end)
	self._rendering = ok
end

return table.freeze(Def)
