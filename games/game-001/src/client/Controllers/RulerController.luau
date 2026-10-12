--!strict
--[[
	RulerController (game-001, FORGE-04, FL-0053; BRIEF §4 row 2): how the local ruler moves.

	Movement itself is Roblox's default character controls (PlayerModule): WASD or the arrow keys on
	PC, the left stick on a gamepad, and the default thumbstick on touch. CONTRACTS G4.1 says the
	ruler moves only with the default thumbstick. This controller adds:
		- Sprint. Hold Left Shift on PC. Press the left stick (L3) on a gamepad, or the on-screen
		  "Sprint" button on touch, to toggle it. Sprint counts only while moving, and a toggled
		  sprint ends when the ruler stops.
		- Eased speed. WalkSpeed moves toward the walk or sprint speed at `accel` studs/s², so starting
		  or stopping a sprint never lurches.
		- Smooth turning (turn.mode = "align"). Humanoid.AutoRotate is off, and an AlignOrientation
		  on the root turns the ruler toward its move direction at most turn.maxAngularVelocity rad/s.
		  turn.mode = "engine" restores Roblox's own AutoRotate (the fallback if Studio shows a problem).
		- Character tracking for the other ruler controllers: characterChanged, getCharacter(),
		  getRoot(), getHumanoid(). When the ruler dies, respawns or leaves, it returns
		  InputModeController to "explore".
	The ruler's look (regalia) is not here: KingdomService attaches Kit.regalia at spawn (FL-0048).

	API
		RulerController.characterChanged: Signal (character?)
		RulerController:getCharacter() / :getRoot() / :getHumanoid()
		RulerController:standUp() -> boolean           -- leave the throne for walk mode (camera calls it)
		RulerController:setSprint(held: boolean)        -- what the bound keys call (specs too)
		RulerController:toggleSprint()
		RulerController:update(dt)                       -- one frame; Heartbeat calls it live
	Pure helpers (specs): Def.approach, Def.sprintStep, Def.facing, Def.DEFAULTS
	Engine access is guarded, so the headless boot gate (no character, no ContextActionService)
	boots without errors.
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local Def = {
	name = "RulerController",
	dependencies = { "InputModeController" },
}

Def.ACTION = "ForgeRulerSprint"
Def.DEFAULTS = table.freeze({
	walkSpeed = 16, -- studs/s (the Roblox default, so the first playtest has a known baseline)
	sprintSpeed = 24,
	accel = 48, -- studs/s²: walk -> sprint in about 0.17 s
	moveDeadzone = 0.1, -- Humanoid.MoveDirection magnitude below this counts as standing still
	turn = table.freeze({
		mode = "align", -- "align" | "engine"
		maxAngularVelocity = 12, -- rad/s (about 690°/s: a half turn in about a quarter second)
		responsiveness = 30,
	}),
})

local Controller = {}
Controller.__index = Controller

-- Moves `current` toward `target` by at most `step` (never overshoots).
function Def.approach(current: number, target: number, step: number): number
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-- Sprint state: { held: boolean, toggled: boolean } -> (newState, sprinting)
-- A toggled sprint ends as soon as the ruler stops moving; a held key sprints only while moving.
function Def.sprintStep(
	state: { held: boolean, toggled: boolean },
	moving: boolean
): ({ held: boolean, toggled: boolean }, boolean)
	local toggled = state.toggled and moving
	return { held = state.held, toggled = toggled }, moving and (state.held or toggled)
end

-- The upright facing for a move direction, or nil when there is no meaningful direction.
function Def.facing(direction: Vector3, deadzone: number): CFrame?
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < deadzone then
		return nil
	end
	return CFrame.lookAt(Vector3.zero, flat.Unit)
end

local function connect(target: any, eventName: string, handler: (...any) -> ()): any
	local ok, connection = pcall(function()
		return target[eventName]:Connect(handler)
	end)
	return if ok then connection else nil
end

local function track(list: { any }, connection: any)
	if connection ~= nil then
		table.insert(list, connection)
	end
end

local function find(character: any, method: string, arg: string): any
	local ok, result = pcall(function()
		return character[method](character, arg)
	end)
	return if ok then result else nil
end

-- opts (specs): { config, player, actions (ContextActionService-like), runService }
function Def.create(env: any, registry: any, opts: { [string]: any }?): any
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_config = options.config or Def.DEFAULTS,
		_playerOverride = options.player,
		_actionsOverride = options.actions,
		_runServiceOverride = options.runService,
		_connections = {},
		_characterConnections = {},
		_sprint = { held = false, toggled = false },
		_character = nil,
		_humanoid = nil,
		_root = nil,
		_align = nil,
		_input = nil,
		sprinting = false,
		characterChanged = Signal.new(),
	}, Controller)
end

function Def.new(env: any, registry: any): any
	return Def.create(env, registry)
end

function Controller:start()
	local env = self._env
	self._input = self._registry:find("InputModeController")
	local ok, foundPlayer = pcall(function()
		return self._playerOverride or env.Players.LocalPlayer
	end)
	self._player = if ok then foundPlayer else nil
	local player = self._player
	if player ~= nil then
		track(
			self._connections,
			connect(player, "CharacterAdded", function(character)
				self:_onCharacter(character)
			end)
		)
		track(
			self._connections,
			connect(player, "CharacterRemoving", function()
				self:_onCharacter(nil)
			end)
		)
		local hasCharacter, current = pcall(function()
			return player.Character
		end)
		if hasCharacter and current ~= nil then
			self:_onCharacter(current)
		end
	end
	local runService = self._runServiceOverride or env.RunService
	if runService ~= nil then
		track(
			self._connections,
			connect(runService, "Heartbeat", function(dt)
				self:update(dt)
			end)
		)
	end
	self:_bindSprint()
end

function Controller:destroy()
	for _, connection in self._connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self._connections)
	self:_clearCharacter()
	local actions = self._actions
	if actions ~= nil then
		pcall(function()
			actions:UnbindAction(Def.ACTION)
		end)
	end
	self.characterChanged:disconnectAll()
end

function Controller:getCharacter(): any
	return self._character
end

function Controller:getRoot(): any
	return self._root
end

function Controller:getHumanoid(): any
	return self._humanoid
end

-- Leaves the throne (or any seat): walk mode (G13.6: "walk mode unseats"). True if it stood up.
function Controller:standUp(): boolean
	local humanoid = self._humanoid
	if humanoid == nil then
		return false
	end
	local okSit, sitting = pcall(function()
		return humanoid.Sit == true
	end)
	local okSeat, seatPart = pcall(function()
		return humanoid.SeatPart
	end)
	if (okSit and sitting) or (okSeat and seatPart ~= nil) then
		pcall(function()
			humanoid.Jump = true
		end)
		return true
	end
	return false
end

function Controller:setSprint(held: boolean)
	self._sprint = { held = held, toggled = self._sprint.toggled }
end

function Controller:toggleSprint()
	self._sprint = { held = self._sprint.held, toggled = not self._sprint.toggled }
end

function Controller:update(dt: number)
	local humanoid = self._humanoid
	if humanoid == nil then
		return
	end
	local config = self._config
	local direction = humanoid.MoveDirection
	local moving = direction.Magnitude >= config.moveDeadzone
	local state, sprinting = Def.sprintStep(self._sprint, moving)
	self._sprint = state
	self.sprinting = sprinting
	local target = if sprinting then config.sprintSpeed else config.walkSpeed
	humanoid.WalkSpeed = Def.approach(humanoid.WalkSpeed, target, config.accel * dt)
	local align = self._align
	if align ~= nil then
		local facing = Def.facing(direction, config.moveDeadzone)
		if facing ~= nil then
			align.CFrame = facing
		end
	end
end

function Controller:_onCharacter(character: any)
	self:_clearCharacter()
	if self._input ~= nil then
		self._input:set("explore")
	end
	if character == nil then
		self.characterChanged:fire(nil)
		return
	end
	self._character = character
	self._humanoid = find(character, "FindFirstChildOfClass", "Humanoid")
	self._root = find(character, "FindFirstChild", "HumanoidRootPart")
	local humanoid = self._humanoid
	if humanoid ~= nil then
		humanoid.WalkSpeed = self._config.walkSpeed
		track(
			self._characterConnections,
			connect(humanoid, "Died", function()
				self:_onDied()
			end)
		)
		if self._config.turn.mode == "align" and self._root ~= nil then
			self:_buildAlign(humanoid, self._root)
		end
	end
	self.characterChanged:fire(character)
end

function Controller:_onDied()
	self._sprint = { held = false, toggled = false }
	if self._input ~= nil then
		self._input:set("explore")
	end
end

function Controller:_buildAlign(humanoid: any, root: any)
	local env = self._env
	local turn = self._config.turn
	local ok, align = pcall(function()
		local attachment = root:FindFirstChild("RootAttachment")
		if attachment == nil then
			attachment = env.newInstance("Attachment")
			attachment.Name = "ForgeRulerTurn"
			attachment.Parent = root
		end
		local constraint = env.newInstance("AlignOrientation")
		constraint.Name = "ForgeRulerTurn"
		constraint.Mode = Enum.OrientationAlignmentMode.OneAttachment
		constraint.Attachment0 = attachment
		constraint.MaxAngularVelocity = turn.maxAngularVelocity
		constraint.Responsiveness = turn.responsiveness
		constraint.MaxTorque = math.huge
		constraint.CFrame = Def.facing(root.CFrame.LookVector, 0.01) or CFrame.identity
		constraint.Parent = root
		return constraint
	end)
	if ok then
		humanoid.AutoRotate = false
		self._align = align
	else
		self._env.log("warn", "RulerController: smooth turning unavailable; using the engine's AutoRotate")
	end
end

function Controller:_clearCharacter()
	for _, connection in self._characterConnections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self._characterConnections)
	if self._align ~= nil then
		pcall(function()
			self._align:Destroy()
		end)
		self._align = nil
	end
	self._character, self._humanoid, self._root = nil, nil, nil
	self.sprinting = false
end

function Controller:_bindSprint()
	local env = self._env
	local ok, actions = pcall(function()
		local cas = self._actionsOverride or env.ContextActionService
		local _ = cas.BindAction -- the boot gate's unmocked guard errors here
		return cas
	end)
	if not ok then
		env.log("info", "RulerController: no ContextActionService; sprint keys are skipped")
		return
	end
	self._actions = actions
	-- High priority and Sink: Left Shift is also Roblox's default shift-lock key; sprint wins
	-- while this controller runs (FORGE-05 handoff: StarterPlayer.EnableMouseLockOption = false).
	pcall(function()
		actions:BindActionAtPriority(Def.ACTION, function(_, state, input)
			local toggles = input ~= nil
				and (input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonL3)
			if toggles then
				if state == Enum.UserInputState.Begin then
					self:toggleSprint()
				end
			elseif state == Enum.UserInputState.Begin then
				self:setSprint(true)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				self:setSprint(false)
			end
			return Enum.ContextActionResult.Sink
		end, true, Enum.ContextActionPriority.High.Value, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
		actions:SetTitle(Def.ACTION, "Sprint")
	end)
end

return table.freeze(Def)
