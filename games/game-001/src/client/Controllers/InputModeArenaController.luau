--!strict
--[[
	InputModeArenaController (game-001, FORGE-04, FL-0075; CONTRACTS G12.4, G12.6; design
	crown-arena.md §5): the duel controls. It owns InputModeController's `arena` mode and sends only
	through FORGE-01's DuelController:act (G12.6: DuelController is the only sender of Arena.Action).

	When
		- Arena.State (G12.4; also DuelController:getState() at start) at the `duel` stage naming the
		  local player as duellist a or b (isAI false) enters arena mode. Spectators never enter it:
		  they keep the camera and nothing else.
		- Any other stage (`crowning`, `done`, ...), a state that no longer names us, or Results /
		  Lobby (Match.State) returns to explore.
		- While the duel is ours, a return to explore made by anyone else (RulerController does it on
		  a respawn) re-enters arena mode. InputModeController refuses build and edit meanwhile.
		- RulerCameraController switches to its walk (follow) camera for arena mode and back after:
		  the duel is fought on foot, so movement, the thumbstick and jump stay Roblox's own.

	Controls (Def.CONTROLS; FORGE-03's arena HUD can show them as hints through controls())
		action   keyboard + mouse   gamepad     touch button
		light    left click         R1          Light (the biggest, beside jump)
		heavy    R                  R2          Heavy
		block    F (hold)           L1 (hold)   Block (hold)
		parry    E                  L2          Parry
		dodge    Q                  B           Dodge
		- Block is held: the press sends block, the release sends blockEnd; with several sources
		  held (F and a touch, say) blockEnd waits for the last release. Leaving arena mode with block
		  held sends blockEnd, so a champion is never left blocking.
		- Bound through ContextActionService at High priority only while in arena mode, so the keys
		  are free at every other time (Q / E rotate the overview, B is "back").
		- No client-side rate limit: the server's Arena.Action limit (burst 8, 12/s) is the authority.
	Touch
		- On a touch device (UserInputService.TouchEnabled), a ScreenGui ForgeDuelInput under PlayerGui
		  while in arena mode: five round buttons around Roblox's jump button, each at least
		  Def.MIN_TOUCH_PX (44) across, none overlapping another or the jump button, all within the
		  right thumb's reach (Def.TOUCH; "small" when the viewport's shorter side is <= 500 px, the
		  same rule as Roblox's TouchGui). Positions are DRAFT until the Studio phone emulator (E16).
		- A press reacts on touch-down; a held Block ends when that touch ends, on the button or off it.
	Without a DuelController (before FL-0071 lands) a press sends nothing and logs one info line;
	an act() that errors is logged once. Engine access is guarded (headless boot gate).

	API
		controller.active: boolean                    -- arena mode is on (ours)
		controller.changed: Signal<(active: boolean)>
		controller:onArenaState(state)                -- Arena.State
		controller:onPhase(phase)                     -- Match.State
		controller:press(action, down, source?) -> boolean   -- every key, pad and touch button calls it;
		                                              -- true when DuelController:act was called
		controller:controls() -> { { action, keyboard, gamepad, touch } }
	Pure helpers (specs): Def.isDuellist(state, userId), Def.layout(small) -> { button }, Def.reach(button)
]]

local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local Controller = {}
Controller.__index = Controller

local Def = { name = "InputModeArenaController", dependencies = { "InputModeController" } }

Def.MODE = "arena"
Def.ACTIONS = table.freeze({ "light", "heavy", "block", "parry", "dodge" })
Def.HELD = table.freeze({ block = "blockEnd" }) -- held actions and what their release sends
Def.END_PHASES = table.freeze({ Results = true, Lobby = true })
Def.MIN_TOUCH_PX = 44
Def.GUI_NAME = "ForgeDuelInput"

-- ContextActionService bindings, one per action (keyboard + mouse first, then gamepad)
Def.BINDINGS = table.freeze({
	light = { name = "ForgeDuelLight", keys = { Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR1 } },
	heavy = { name = "ForgeDuelHeavy", keys = { Enum.KeyCode.R, Enum.KeyCode.ButtonR2 } },
	block = { name = "ForgeDuelBlock", keys = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 } },
	parry = { name = "ForgeDuelParry", keys = { Enum.KeyCode.E, Enum.KeyCode.ButtonL2 } },
	dodge = { name = "ForgeDuelDodge", keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonB } },
})

-- What the HUD shows (labels, not key codes)
Def.CONTROLS = table.freeze({
	{ action = "light", keyboard = "Left click", gamepad = "R1", touch = "Light" },
	{ action = "heavy", keyboard = "R", gamepad = "R2", touch = "Heavy" },
	{ action = "block", keyboard = "Hold F", gamepad = "Hold L1", touch = "Hold Block" },
	{ action = "parry", keyboard = "E", gamepad = "L2", touch = "Parry" },
	{ action = "dodge", keyboard = "Q", gamepad = "B", touch = "Dodge" },
})

-- Touch buttons: size in px; x, y = the centre's offset from the screen's bottom-right corner.
-- jump = Roblox TouchGui's jump button (top-left offset from bottom-right, and size) for the overlap check.
Def.TOUCH = table.freeze({
	small = {
		light = { size = 68, x = -150, y = -50, label = "Light" },
		heavy = { size = 56, x = -140, y = -128, label = "Heavy" },
		block = { size = 56, x = -62, y = -130, label = "Block" },
		parry = { size = 48, x = -62, y = -200, label = "Parry" },
		dodge = { size = 56, x = -228, y = -100, label = "Dodge" },
		jump = { size = 70, left = -95, top = -90 },
		reach = 260, -- px from the corner to a button's centre that a thumb reaches on a phone
		textSize = 16,
	},
	large = {
		light = { size = 92, x = -245, y = -90, label = "Light" },
		heavy = { size = 76, x = -245, y = -200, label = "Heavy" },
		block = { size = 76, x = -110, y = -270, label = "Block" },
		parry = { size = 64, x = -110, y = -360, label = "Parry" },
		dodge = { size = 76, x = -345, y = -130, label = "Dodge" },
		jump = { size = 120, left = -170, top = -210 },
		reach = 400,
		textSize = 20,
	},
})
Def.SMALL_SCREEN_PX = 500

function Def.isDuellist(state: any, userId: any): boolean
	if type(state) ~= "table" or type(userId) ~= "number" then
		return false
	end
	for _, side in { state.a, state.b } do
		if type(side) == "table" and side.userId == userId and side.isAI ~= true then
			return true
		end
	end
	return false
end

-- The buttons of a layout, in Def.ACTIONS order: { action, size, x, y, label }
function Def.layout(small: boolean): { { [string]: any } }
	local layout = if small then Def.TOUCH.small else Def.TOUCH.large
	local out = {}
	for _, action in Def.ACTIONS do
		local spec = (layout :: any)[action]
		table.insert(out, { action = action, size = spec.size, x = spec.x, y = spec.y, label = spec.label })
	end
	return out
end

-- Distance of a button's centre from the bottom-right corner (where the right thumb rests)
function Def.reach(button: { [string]: any }): number
	return Vector2.new(button.x, button.y).Magnitude
end

local function guarded(env: any, service: string, override: any, member: string): any
	if override ~= nil then
		return override
	end
	local ok, found = pcall(function()
		local value = env[service]
		local _ = value[member] -- the boot gate's unmocked guard errors here
		return value
	end)
	return if ok then found else nil
end

-- opts (specs): { actions, userInput, playerGui, touch: boolean?, viewport: Vector2?, userId: number? }
function Def.create(env: any, registry: any, opts: { [string]: any }?)
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_opts = options,
		_links = {},
		_connections = {},
		_guiConnections = {},
		_holding = {} :: { [string]: { [string]: boolean } },
		_warned = {},
		_ours = false,
		_bound = false,
		_gui = nil :: any,
		active = false,
		changed = Signal.new(),
	}, Controller)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function Controller:start()
	local env, opts = self._env, self._opts
	self._input = self._registry:find("InputModeController")
	self._actions = guarded(env, "ContextActionService", opts.actions, "BindAction")
	self._userInput = guarded(env, "UserInputService", opts.userInput, "InputEnded")
	if self._input ~= nil then
		table.insert(
			self._connections,
			self._input.changed:connect(function(mode, previous)
				self:_onMode(mode, previous)
			end)
		)
	end
	table.insert(
		self._links,
		RemoteLink.on(env, "Arena.State", function(state)
			self:onArenaState(state)
		end)
	)
	table.insert(
		self._links,
		RemoteLink.on(env, "Match.State", function(phase)
			self:onPhase(phase)
		end)
	)
	local duel = self._registry:find("DuelController")
	if duel ~= nil and duel.getState ~= nil then
		local ok, state = pcall(duel.getState, duel)
		if ok then
			self:onArenaState(state)
		end
	end
end

function Controller:destroy()
	self._ours = false
	self:_bind(false)
	for _, link in self._links do
		pcall(function()
			link:disconnect()
		end)
	end
	table.clear(self._links)
	for _, connection in self._connections do
		pcall(function()
			if connection.disconnect then
				connection:disconnect()
			else
				connection:Disconnect()
			end
		end)
	end
	table.clear(self._connections)
	self.changed:disconnectAll()
end

function Controller:_userId(): number?
	if type(self._opts.userId) == "number" then
		return self._opts.userId
	end
	local ok, id = pcall(function()
		return self._env.Players.LocalPlayer.UserId
	end)
	return if ok and type(id) == "number" then id else nil
end

function Controller:onArenaState(state: any)
	if type(state) ~= "table" then
		return
	end
	self._ours = state.stage == "duel" and Def.isDuellist(state, self:_userId())
	self:_follow()
end

function Controller:onPhase(phase: any)
	if type(phase) == "string" and Def.END_PHASES[phase] then
		self._ours = false
		self:_follow()
	end
end

-- Puts InputMode where the duel says it should be.
function Controller:_follow()
	local input = self._input
	if input == nil then
		return
	end
	if self._ours and input.mode ~= Def.MODE then
		input:set(Def.MODE)
	elseif not self._ours and input.mode == Def.MODE then
		input:set("explore")
	end
end

function Controller:_onMode(mode: string, previous: string)
	if mode == Def.MODE then
		self:_bind(true)
	elseif previous == Def.MODE then
		self:_bind(false)
		if self._ours and mode == "explore" then
			self._input:set(Def.MODE) -- e.g. RulerController on a respawn: the duel is still ours
		end
	end
end

function Controller:_bind(on: boolean)
	if on == self._bound then
		return
	end
	self._bound = on
	if on then
		self:_bindKeys()
		self:_mountTouch()
	else
		self:_releaseAll()
		self:_unbindKeys()
		self:_unmountTouch()
	end
	self.active = on
	self.changed:fire(on)
end

-- ------------------------------------------------------------------ sending

function Controller:_warnOnce(key: string, level: string, message: string, data: any?)
	if not self._warned[key] then
		self._warned[key] = true
		self._env.log(level, message, data)
	end
end

function Controller:_send(action: string): boolean
	local duel = self._registry:find("DuelController")
	if duel == nil or duel.act == nil then
		self:_warnOnce("missing", "info", "InputModeArenaController: no DuelController yet; duel input sends nothing")
		return false
	end
	local ok, err = pcall(duel.act, duel, action)
	if not ok then
		self:_warnOnce(
			`act:{action}`,
			"warn",
			`InputModeArenaController: DuelController:act('{action}') failed`,
			{ error = tostring(err) }
		)
	end
	return ok
end

function Controller:press(action: any, down: any, source: any): boolean
	if not self.active or type(action) ~= "string" or not table.find(Def.ACTIONS, action) then
		return false
	end
	local key = if type(source) == "string" then source else "api"
	local release = Def.HELD[action]
	if release == nil then
		return down == true and self:_send(action)
	end
	local held = self._holding[action] or {}
	self._holding[action] = held
	local wasHeld = next(held) ~= nil
	if down == true then
		held[key] = true
		return not wasHeld and self:_send(action)
	end
	if not held[key] then
		return false
	end
	held[key] = nil
	return next(held) == nil and self:_send(release)
end

function Controller:_releaseAll()
	for action, held in self._holding do
		if next(held) ~= nil then
			table.clear(held)
			self:_send(Def.HELD[action])
		end
	end
end

function Controller:controls(): { { [string]: string } }
	return Def.CONTROLS :: any
end

-- ------------------------------------------------------------------ keys and gamepad

function Controller:_bindKeys()
	local actions = self._actions
	if actions == nil then
		return
	end
	local high = Enum.ContextActionPriority.High.Value
	for _, action in Def.ACTIONS do
		local binding = Def.BINDINGS[action]
		pcall(function()
			actions:BindActionAtPriority(binding.name, function(_, state, input)
				local source = "key"
				pcall(function()
					local key = input.KeyCode
					source = tostring(if key ~= nil and key.Name ~= "Unknown" then key else input.UserInputType)
				end)
				if state == Enum.UserInputState.Begin then
					self:press(action, true, source)
				elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
					self:press(action, false, source)
				end
				return Enum.ContextActionResult.Sink
			end, false, high, table.unpack(binding.keys))
		end)
	end
end

function Controller:_unbindKeys()
	local actions = self._actions
	if actions == nil then
		return
	end
	for _, action in Def.ACTIONS do
		local name = Def.BINDINGS[action].name
		pcall(function()
			actions:UnbindAction(name)
		end)
	end
end

-- ------------------------------------------------------------------ touch

function Controller:_isTouch(): boolean
	if self._opts.touch ~= nil then
		return self._opts.touch == true
	end
	local userInput = self._userInput
	if userInput == nil then
		return false
	end
	local ok, enabled = pcall(function()
		return userInput.TouchEnabled
	end)
	return ok and enabled == true
end

function Controller:_isSmall(): boolean
	local viewport = self._opts.viewport
	if viewport == nil then
		local ok, size = pcall(function()
			return self._env.Workspace.CurrentCamera.ViewportSize
		end)
		viewport = if ok then size else nil
	end
	if typeof(viewport) ~= "Vector2" then
		return true -- unknown: the phone layout fits everywhere
	end
	return math.min(viewport.X, viewport.Y) <= Def.SMALL_SCREEN_PX
end

function Controller:_playerGui(): any
	if self._opts.playerGui ~= nil then
		return self._opts.playerGui
	end
	local ok, found = pcall(function()
		return self._env.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end)
	return if ok then found else nil
end

local function isPress(input: any): boolean
	local ok, kind = pcall(function()
		return input.UserInputType
	end)
	return ok and (kind == Enum.UserInputType.Touch or kind == Enum.UserInputType.MouseButton1)
end

function Controller:_mountTouch()
	if not self:_isTouch() then
		return
	end
	local parent = self:_playerGui()
	if parent == nil then
		return
	end
	local env = self._env
	local small = self:_isSmall()
	local style = if small then Def.TOUCH.small else Def.TOUCH.large
	local ok, gui = pcall(function()
		local screen = env.newInstance("ScreenGui")
		screen.Name = Def.GUI_NAME
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 5
		for _, button in Def.layout(small) do
			local view = env.newInstance("TextButton")
			view.Name = `Duel_{button.action}`
			view:SetAttribute("DuelAction", button.action)
			view.AnchorPoint = Vector2.new(0.5, 0.5)
			view.Position = UDim2.new(1, button.x, 1, button.y)
			view.Size = UDim2.fromOffset(button.size, button.size)
			view.BackgroundColor3 = Color3.fromRGB(24, 22, 30)
			view.BackgroundTransparency = 0.3
			view.Text = button.label
			view.TextColor3 = Color3.fromRGB(255, 255, 255)
			view.TextSize = style.textSize
			view.Font = Enum.Font.GothamBold
			view.AutoButtonColor = true
			local corner = env.newInstance("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = view
			local stroke = env.newInstance("UIStroke")
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Thickness = 2
			stroke.Transparency = 0.35
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = view
			view.Parent = screen
			self:_wireButton(view, button.action)
		end
		screen.Parent = parent
		return screen
	end)
	if ok then
		self._gui = gui
	else
		self:_warnOnce("touch", "warn", "InputModeArenaController: the touch buttons failed", { error = tostring(gui) })
	end
end

function Controller:_wireButton(view: any, action: string)
	local source = `touch:{action}`
	local touches = {} -- the touches that began on this button
	pcall(function()
		table.insert(
			self._guiConnections,
			view.InputBegan:Connect(function(input)
				if isPress(input) then
					touches[input] = true
					self:press(action, true, source)
				end
			end)
		)
	end)
	local function ended(input)
		if touches[input] then
			touches[input] = nil
			if next(touches) == nil then
				self:press(action, false, source)
			end
		end
	end
	pcall(function()
		table.insert(self._guiConnections, view.InputEnded:Connect(ended))
	end)
	if self._userInput ~= nil then -- a held Block ends when its touch ends, even off the button
		pcall(function()
			table.insert(self._guiConnections, self._userInput.InputEnded:Connect(ended))
		end)
	end
end

function Controller:_unmountTouch()
	for _, connection in self._guiConnections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self._guiConnections)
	local gui = self._gui
	self._gui = nil
	if gui ~= nil then
		pcall(function()
			gui:Destroy()
		end)
	end
end

return Def
