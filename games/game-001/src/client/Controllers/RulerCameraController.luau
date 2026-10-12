--!strict
--[[
	RulerCameraController (game-001, FORGE-04, FL-0053; CONTRACTS G4.1): the ruler's camera.

		local camera = registry:find("RulerCameraController")
		camera:setMode("overview")          -- "follow" | "overview"; returns false for anything else
		camera.mode, camera.changed:connect(function(mode, previous) ... end)
		camera:zoomBy(steps)                -- overview height; positive = further out
		camera:shake(magnitude, duration)   -- VFXController.shakeRequested is wired to this

	Modes
		follow    Roblox's default third-person camera (CameraType Custom), tuned for overseeing the
		          kingdom: zoom between follow.minZoom and follow.maxZoom studs (min ≥ 8, so never first
		          person, which smooth turning would break), a shoulder offset (Humanoid.CameraOffset)
		          and the field of view.
		overview  A Scriptable camera high above the ruler, looking down at overview.pitchDeg. It keeps
		          the yaw the player had and follows the ruler with frame-rate-independent smoothing.
		          The mouse wheel, a pinch, or zoomBy() change the height within its range. Entering it
		          blends from the current view over transitionSec.
	Switching
		- V on a keyboard, Y on a gamepad, or the on-screen "View" button on touch toggles the mode.
		- overviewInBuild: entering build mode (InputModeController) switches to overview, and
		  leaving it restores the previous mode, unless the player picked a mode themselves while
		  building.
	Shake
		- magnitude 0..1 (clamped) maps to at most shake.maxDegrees of rotation; duration is capped
		  at shake.maxDuration; it eases out to zero, and at most shake.maxActive shakes add up.
		- It is ignored when SettingsController says cameraShake is off or reduced motion is on (the
		  platform's Reduce Motion included). VFXController already checks this; direct callers get
		  the same rule here.
	The camera runs at RenderPriority.Camera + 1 (after Roblox's camera), so shake also works in
	follow mode. Engine access is guarded: without a camera or the input services (headless boot
	gate) it boots and does nothing.

	Pure helpers (specs): Def.overviewCFrame, Def.smooth, Def.ease, Def.clamp, Def.shakeAmplitude
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local Def = {
	name = "RulerCameraController",
	dependencies = { "RulerController", "InputModeController" },
}

Def.MODES = table.freeze({ "follow", "overview" })
Def.ACTION = "ForgeRulerView"
Def.RENDER_NAME = "ForgeRulerCamera"
Def.DEFAULTS = table.freeze({
	fieldOfView = 70,
	follow = table.freeze({
		minZoom = 10,
		maxZoom = 70,
		shoulder = Vector3.new(1.25, 0.75, 0),
	}),
	overview = table.freeze({
		minHeight = 45,
		maxHeight = 140,
		startHeight = 80,
		zoomStep = 10, -- studs of height per wheel notch / zoomBy(1)
		pitchDeg = 55, -- degrees below the horizon
		smoothing = 6, -- 1/s: the focus closes about 95 % of the gap in 0.5 s
	}),
	transitionSec = 0.6,
	overviewInBuild = true,
	shake = table.freeze({
		maxDegrees = 2,
		maxDuration = 1,
		maxActive = 4,
	}),
})

local Controller = {}
Controller.__index = Controller

function Def.clamp(value: number, low: number, high: number): number
	return math.max(low, math.min(high, value))
end

-- Exponential smoothing that gives the same result for one step of dt as for two steps of dt/2.
function Def.smooth(current: Vector3, target: Vector3, rate: number, dt: number): Vector3
	local alpha = 1 - math.exp(-rate * dt)
	return current:Lerp(target, alpha)
end

-- Smoothstep easing for blends, t in [0, 1].
function Def.ease(t: number): number
	local x = Def.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Camera above `focus`: `height` studs up, looking down at `pitchDeg`, facing along `yaw`
-- (radians around +Y; yaw 0 looks toward -Z, like the default camera).
function Def.overviewCFrame(focus: Vector3, yaw: number, height: number, pitchDeg: number): CFrame
	local pitch = math.rad(Def.clamp(pitchDeg, 10, 89))
	local back = height / math.tan(pitch)
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local position = focus + Vector3.new(0, height, 0) - forward * back
	return CFrame.lookAt(position, focus)
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

-- opts (specs): { config, camera, player, actions, userInput, runService }
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
		_height = config.overview.startHeight,
		_yaw = 0,
		_focus = nil,
		_blendFrom = nil,
		_blendT = 1,
		_autoFrom = nil,
		_rendering = false,
		_pinch = 1,
		mode = "follow",
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

	if self._ruler ~= nil then
		track(
			self._connections,
			self._ruler.characterChanged:connect(function(character)
				self:_onCharacter(character)
			end)
		)
		if self._ruler:getCharacter() ~= nil then
			self:_onCharacter(self._ruler:getCharacter())
		end
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
	self:_bindInput()
	self:_bindRender()
	local camera = self._camera
	if camera == nil then
		env.log("info", "RulerCameraController: no camera; camera modes are skipped")
	else
		pcall(function()
			camera.FieldOfView = self._config.fieldOfView
		end)
	end
	self:_applyFollow()
end

function Controller:destroy()
	for _, connection in self._connections do
		disconnect(connection)
	end
	table.clear(self._connections)
	local actions = self._actions
	if actions ~= nil then
		pcall(function()
			actions:UnbindAction(Def.ACTION)
		end)
	end
	if self._rendering then
		pcall(function()
			(self._opts.runService or self._env.RunService):UnbindFromRenderStep(Def.RENDER_NAME)
		end)
		self._rendering = false
	end
	self.changed:disconnectAll()
end

function Controller:setMode(mode: any): boolean
	if self._input ~= nil and self._input.mode == "build" then
		self._autoFrom = nil -- the player chose a view while building: keep it after build mode
	end
	return self:_setMode(mode)
end

function Controller:toggle(): boolean
	return self:setMode(if self.mode == "follow" then "overview" else "follow")
end

function Controller:zoomBy(steps: number)
	local overview = self._config.overview
	self._height = Def.clamp(self._height + steps * overview.zoomStep, overview.minHeight, overview.maxHeight)
end

function Controller:shake(magnitude: any, duration: any): boolean
	if type(magnitude) ~= "number" or type(duration) ~= "number" or magnitude <= 0 or duration <= 0 then
		return false
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

-- One frame. Live: bound with BindToRenderStep after Roblox's camera; specs call it directly.
function Controller:update(dt: number)
	local camera = self._camera
	if camera == nil then
		return
	end
	if self.mode == "overview" then
		local root = self._ruler and self._ruler:getRoot()
		if root ~= nil then
			local target = root.CFrame.Position
			self._focus = if self._focus
				then Def.smooth(self._focus, target, self._config.overview.smoothing, dt)
				else target
		end
		if self._focus ~= nil then
			local goal = Def.overviewCFrame(self._focus, self._yaw, self._height, self._config.overview.pitchDeg)
			if self._blendFrom ~= nil then
				self._blendT = math.min(1, self._blendT + dt / self._config.transitionSec)
				camera.CFrame = self._blendFrom:Lerp(goal, Def.ease(self._blendT))
				if self._blendT >= 1 then
					self._blendFrom = nil
				end
			else
				camera.CFrame = goal
			end
		end
	end
	if #self._shakes > 0 then
		local pitch, yaw = self:_shakeDegrees(dt)
		camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(pitch), math.rad(yaw), 0)
	end
end

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
	local camera = self._camera
	if camera == nil then
		return
	end
	pcall(function()
		camera.FieldOfView = self._config.fieldOfView
	end)
	if self.mode == "overview" then
		self._yaw = yawOf(camera.CFrame.LookVector)
		local root = self._ruler and self._ruler:getRoot()
		self._focus = if root then root.CFrame.Position else self._focus
		self._blendFrom = camera.CFrame
		self._blendT = 0
		camera.CameraType = Enum.CameraType.Scriptable
	else
		self._blendFrom = nil
		camera.CameraType = Enum.CameraType.Custom
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
	if root ~= nil then
		self._focus = root.CFrame.Position -- snap: a respawn is not a camera move
	end
	self:_applyFollow()
end

function Controller:_onInputMode(mode: string, previous: string)
	if not self._config.overviewInBuild then
		return
	end
	if mode == "build" then
		if self.mode ~= "overview" then
			self._autoFrom = self.mode
			self:_setMode("overview")
		end
	elseif previous == "build" and self._autoFrom ~= nil then
		local restore = self._autoFrom
		self._autoFrom = nil
		self:_setMode(restore)
	end
end

function Controller:_bindInput()
	local env, opts = self._env, self._opts
	local actions = guarded(env, "ContextActionService", opts.actions, "BindAction")
	if actions ~= nil then
		self._actions = actions
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
	local userInput = guarded(env, "UserInputService", opts.userInput, "InputChanged")
	if userInput ~= nil then
		track(
			self._connections,
			connect(userInput, "InputChanged", function(input, processed)
				if
					not processed
					and self.mode == "overview"
					and input.UserInputType == Enum.UserInputType.MouseWheel
				then
					self:zoomBy(-input.Position.Z)
				end
			end)
		)
		track(
			self._connections,
			connect(userInput, "TouchPinch", function(_, scale, _, state, processed)
				self:_pinchTo(scale, state, processed)
			end)
		)
	end
	if actions == nil or userInput == nil then
		env.log("info", "RulerCameraController: input services unavailable; view keys and overview zoom are skipped")
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

function Controller:_bindRender()
	local runService = self._opts.runService or self._env.RunService
	local ok = pcall(function()
		local priority = Enum.RenderPriority.Camera.Value + 1
		runService:BindToRenderStep(Def.RENDER_NAME, priority, function(dt)
			self:update(dt)
		end)
	end)
	self._rendering = ok
end

return table.freeze(Def)
