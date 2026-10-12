--!strict
--[[
	InputModeController (game-001, FORGE-04, FL-0053; CONTRACTS G4.1): who owns taps and clicks.

		local input = registry:find("InputModeController")
		input:set("build")              -- FORGE-03's build menu, when placement starts
		input.mode                      -- "explore" | "build"   ("command" is VS-2)
		input.changed:connect(function(mode, previous) ... end)
		input:accepts("explore")        -- optional: true when a tap or click now belongs to that mode

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
Def.DEFAULTS = table.freeze({
	settleSec = 0.15,
})

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

-- opts (specs): { config = DEFAULTS-like, actions = ContextActionService-like }
function Def.create(env: any, registry: any, opts: { [string]: any }?): any
	local options = opts or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_config = options.config or Def.DEFAULTS,
		_actionsOverride = options.actions,
		_actions = nil,
		_bound = false,
		_firing = false,
		_queue = {},
		_refused = {},
		_changedAt = -math.huge,
		mode = "explore",
		changed = Signal.new(),
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
end

function Controller:destroy()
	self:_bindLeave(false)
	self.changed:disconnectAll()
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
