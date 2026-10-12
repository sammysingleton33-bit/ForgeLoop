--!strict
--[[
	InputModeController (game-001, FORGE-04, FL-0053 + FL-0090; CONTRACTS G4.1, G13.6): who owns taps
	and clicks, and what a tap selects.

		local input = registry:find("InputModeController")
		input:set("build")              -- FORGE-03's build menu, when placement starts
		input.mode                      -- "explore" | "build"   ("command" is VS-2)
		input.changed:connect(function(mode, previous) ... end)
		input:accepts("explore")        -- optional: true when a tap or click now belongs to that mode
		input.selected:connect(function(kind, id) ... end)   -- G13.6; FORGE-03's panels listen
		input.selection                 -- { kind, id } of the last selection
		input:select(kind, id)          -- programmatic selection (a list row, "go to")

	Selection (G13.6; nobody else raycasts for selection)
		- In explore mode a tap or click (pointer moved < tapPixels and released within tapSec;
		  RulerCameraController uses the same tapPixels to start a drag-pan) resolves:
		    1. citizen:  EntityController:pick(screenPos) (FORGE-01, G4.1)
		    2. building: the hit instance or an ancestor with a BuildingId attribute
		    3. slot:     the hit instance or an ancestor tagged BuildSlot (its SlotId attribute)
		    4. otherwise "none" (tapping empty ground clears the selection)
		  and fires selected(kind, id).
		- Entering build mode clears the selection (selected("none", "")): panels close while placing.
		- Input that a GUI already handled (gameProcessedEvent) never selects.

	Arbitration (specs: games/game-001/tests/experience/InputMode.spec.luau)
		- One mode at a time, and each mode has one owner for taps and clicks:
		    explore -> FORGE-01's InteractionController (gather, inspect a citizen)
		    build   -> FORGE-03's BuildMenuController (place)
		- set(mode) validates. Unknown modes and "command" (VS-2) are refused and logged once each.
		- changed fires only on a real change, with (mode, previous).
		- A set() made inside a changed handler is applied after every handler has seen the current
		  change, so all handlers see the same sequence of modes.
		- accepts(mode) stays false for settleSec after a change, so the tap that switched the mode
		  (for example the Place button) is never handled again by the new mode's owner.
		- Leaving build mode: X on a keyboard or B on a gamepad, bound through ContextActionService
		  only while in build mode, so the keys stay free otherwise. RulerController also returns to
		  explore when the ruler dies or respawns.
	Without ContextActionService (the headless boot gate) the keys are skipped; set() still works.
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

export type Mode = "explore" | "build"

local Def = {
	name = "InputModeController",
	dependencies = {},
}

Def.MODES = table.freeze({ "explore", "build" })
Def.LATER = table.freeze({ command = "VS-2" })
Def.ACTION = "ForgeLeaveBuildMode"
Def.KINDS = table.freeze({ "citizen", "building", "slot", "none" })
Def.DEFAULTS = table.freeze({
	settleSec = 0.15,
	tapPixels = 8,
	tapSec = 0.4,
	rayLength = 2000,
})

-- True when a press and its release count as a tap (not a drag-pan or a long press).
function Def.isTap(downAt: Vector2, upAt: Vector2, heldSec: number, config: any): boolean
	return (upAt - downAt).Magnitude < config.tapPixels and heldSec <= config.tapSec
end

-- What a raycast hit selects: walks up from the hit instance (at most 8 levels).
-- hasTag(instance, tag) is CollectionService:HasTag. Returns (kind, id).
function Def.resolveHit(hit: any, hasTag: (any, string) -> boolean): (string, any)
	local current = hit
	for _ = 1, 8 do
		if current == nil then
			break
		end
		local okId, buildingId = pcall(function()
			return current:GetAttribute("BuildingId")
		end)
		if okId and buildingId ~= nil then
			return "building", buildingId
		end
		local okTag, tagged = pcall(hasTag, current, "BuildSlot")
		if okTag and tagged then
			local okSlot, slotId = pcall(function()
				return current:GetAttribute("SlotId")
			end)
			return "slot", if okSlot and slotId ~= nil then slotId else current.Name
		end
		local okParent, parent = pcall(function()
			return current.Parent
		end)
		current = if okParent then parent else nil
	end
	return "none", ""
end

local Controller = {}
Controller.__index = Controller

local function actionService(env: any, override: any): any
	if override ~= nil then
		return override
	end
	local ok, service = pcall(function()
		local cas = env.ContextActionService
		local _ = cas.BindAction -- the boot gate's unmocked guard errors here
		return cas
	end)
	return if ok then service else nil
end

-- opts (specs): { config = DEFAULTS-like, actions = ContextActionService-like, userInput, raycast,
--   hasTag }   raycast(screenPos: Vector2) -> Instance? replaces the camera ray in specs
function Def.create(env: any, registry: any, opts: { [string]: any }?): any
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_config = options.config or Def.DEFAULTS,
		_actionsOverride = options.actions,
		_userInputOverride = options.userInput,
		_raycastOverride = options.raycast,
		_hasTagOverride = options.hasTag,
		_actions = nil,
		_connections = {},
		_press = nil,
		_bound = false,
		_firing = false,
		_queue = {},
		_refused = {},
		_changedAt = -math.huge,
		mode = "explore",
		tapPixels = (options.config or Def.DEFAULTS).tapPixels,
		selection = { kind = "none", id = "" },
		changed = Signal.new(),
		selected = Signal.new(),
	}, Controller)
end

function Def.new(env: any, registry: any): any
	return Def.create(env, registry)
end

function Controller:start()
	self._actions = actionService(self._env, self._actionsOverride)
	if self._actions == nil then
		self._env.log("info", "InputModeController: no ContextActionService; the leave-build keys are skipped")
	end
	self:_bindPointer()
end

function Controller:destroy()
	self:_bindLeave(false)
	for _, connection in self._connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self._connections)
	self.changed:disconnectAll()
	self.selected:disconnectAll()
end

-- Programmatic selection (also what a resolved tap calls). Unknown kinds are refused.
function Controller:select(kind: any, id: any): boolean
	if not table.find(Def.KINDS, kind) then
		return false
	end
	local value = if id == nil then "" else id
	self.selection = { kind = kind, id = value }
	self.selected:fire(kind, value)
	return true
end

-- Resolves a tap at a screen position and selects the result (explore mode only).
function Controller:tapAt(screenPos: Vector2): (string?, any)
	if not self:accepts("explore") then
		return nil, nil
	end
	local kind, id = self:_resolve(screenPos)
	self:select(kind, id)
	return kind, id
end

function Controller:_resolve(screenPos: Vector2): (string, any)
	local entities = self._registry:find("EntityController")
	if entities ~= nil and entities.pick ~= nil then
		local ok, entityId = pcall(entities.pick, entities, screenPos)
		if ok and entityId ~= nil then
			return "citizen", entityId
		end
	end
	local hit = self:_raycast(screenPos)
	if hit == nil then
		return "none", ""
	end
	local env = self._env
	local hasTag = self._hasTagOverride
		or function(instance, tag)
			return env.CollectionService:HasTag(instance, tag)
		end
	return Def.resolveHit(hit, hasTag)
end

function Controller:_raycast(screenPos: Vector2): any
	if self._raycastOverride ~= nil then
		return self._raycastOverride(screenPos)
	end
	local env = self._env
	local ok, hit = pcall(function()
		local camera = env.Workspace.CurrentCamera
		local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
		local params = RaycastParams.new()
		local character = env.Players.LocalPlayer and env.Players.LocalPlayer.Character
		if character then
			params.FilterDescendantsInstances = { character }
			params.FilterType = Enum.RaycastFilterType.Exclude
		end
		local result = env.Workspace:Raycast(ray.Origin, ray.Direction * self._config.rayLength, params)
		return result and result.Instance
	end)
	return if ok then hit else nil
end

function Controller:_bindPointer()
	local env = self._env
	local userInput = self._userInputOverride
	if userInput == nil then
		local ok, found = pcall(function()
			local uis = env.UserInputService
			local _ = uis.InputBegan -- the boot gate's unmocked guard errors here
			return uis
		end)
		userInput = if ok then found else nil
	end
	if userInput == nil then
		env.log("info", "InputModeController: no UserInputService; tap selection is skipped")
		return
	end
	local function isPointer(input: any): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	local okBegan, began = pcall(function()
		return userInput.InputBegan:Connect(function(input, processed)
			if processed or not isPointer(input) then
				return
			end
			self._press = { at = Vector2.new(input.Position.X, input.Position.Y), t = env.clock() }
		end)
	end)
	if okBegan then
		table.insert(self._connections, began)
	end
	local okEnded, ended = pcall(function()
		return userInput.InputEnded:Connect(function(input, processed)
			local press = self._press
			if press == nil or not isPointer(input) then
				return
			end
			self._press = nil
			local upAt = Vector2.new(input.Position.X, input.Position.Y)
			if not processed and Def.isTap(press.at, upAt, env.clock() - press.t, self._config) then
				self:tapAt(upAt)
			end
		end)
	end)
	if okEnded then
		table.insert(self._connections, ended)
	end
end

function Controller:set(mode: any): boolean
	if not table.find(Def.MODES, mode) then
		local key = tostring(mode)
		if not self._refused[key] then
			self._refused[key] = true
			local later = Def.LATER[key]
			self._env.log(
				"warn",
				`InputModeController: mode '{key}' is not available` .. (if later then ` in VS-1 ({later})` else ""),
				{ mode = key }
			)
		end
		return false
	end
	if self._firing then
		table.insert(self._queue, mode)
		return true
	end
	local nextMode: any = mode
	while nextMode ~= nil do
		if nextMode ~= self.mode then
			local previous = self.mode
			self.mode = nextMode
			self._changedAt = self._env.clock()
			self:_bindLeave(nextMode == "build")
			if nextMode == "build" and self.selection.kind ~= "none" then
				self:select("none", "") -- panels close while placing
			end
			self._firing = true
			self.changed:fire(nextMode, previous)
			self._firing = false
		end
		nextMode = table.remove(self._queue, 1)
	end
	return true
end

-- True when a tap or click arriving now belongs to `mode`'s owner.
function Controller:accepts(mode: string): boolean
	return self.mode == mode and self._env.clock() - self._changedAt >= self._config.settleSec
end

function Controller:_bindLeave(on: boolean)
	local actions = self._actions
	if actions == nil then
		return
	end
	if on and not self._bound then
		local ok = pcall(function()
			actions:BindAction(Def.ACTION, function(_, state)
				if state == Enum.UserInputState.Begin then
					self:set("explore")
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.KeyCode.X, Enum.KeyCode.ButtonB)
		end)
		self._bound = ok
	elseif not on and self._bound then
		pcall(function()
			actions:UnbindAction(Def.ACTION)
		end)
		self._bound = false
	end
end

return table.freeze(Def)
