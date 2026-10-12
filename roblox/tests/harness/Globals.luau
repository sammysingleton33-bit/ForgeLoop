--[[
	Globals — the Roblox-like global environment the harness gives every module it loads.

	Provided (so shared code runs unchanged in Lune):
	  task      Lune's task library; functions passed to spawn/defer/delay are wrapped so an
	            error inside them — also after the thread yielded and was resumed later — fails
	            the test that spawned it (Test.reportUnhandledError with Test.captureOrigin)
	            instead of only printing; synchronize/desynchronize are no-ops. Threads (not
	            functions) passed to task.spawn/defer are resumed as given: their creator must
	            catch errors (Core/Signal and MockEnv do).
	  Random    the spec file's MockRandom (passed in by the runner, loaded through the module
	            loader, so it is the same table specs and MockEnv get; deterministic per spec file)
	  Enum, Instance and these datatypes from @lune/roblox: Axes, BrickColor, CFrame, Color3,
	            ColorSequence, ColorSequenceKeypoint, Faces, Font, NumberRange, NumberSequence,
	            NumberSequenceKeypoint, PhysicalProperties, Ray, Rect, Region3, Region3int16, UDim,
	            UDim2, Vector2, Vector2int16, Vector3, Vector3int16
	  stand-ins (harness/ExtraDatatypes.luau): TweenInfo, RaycastParams, OverlapParams, DateTime (UTC;
	            DateTime.now() errors — use env.now())
	Not provided (nil): every other Roblox global datatype (e.g. PathWaypoint, CatalogSearchParams,
	SharedTable), and the deprecated globals wait/delay/spawn/tick/time/elapsedTime.
	Blocked (indexing raises a clear error): game, workspace, script, plugin — services come from
	the injected Env (interfaces §2), never from globals.

	API
		Globals.build({
			onUnhandledError: (message: string, origin: any?) -> (),
			captureOrigin: (() -> any)?,
			random: any,                        -- the Random table (MockRandom)
		}) -> (globals, control)
		control.pendingCount() -> number        -- guarded task threads that have not finished yet
]]

local luneTask = require("@lune/task")
local roblox = require("@lune/roblox")

local ExtraDatatypes = require("./ExtraDatatypes")

local Globals = {}

local DATATYPES = {
	"Axes",
	"BrickColor",
	"CFrame",
	"Color3",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"Faces",
	"Font",
	"NumberRange",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"PhysicalProperties",
	"Ray",
	"Rect",
	"Region3",
	"Region3int16",
	"UDim",
	"UDim2",
	"Vector2",
	"Vector2int16",
	"Vector3",
	"Vector3int16",
}
Globals.DATATYPES = DATATYPES

local function blocked(name: string)
	local message = `'{name}' is not available under the Lune test harness: use the injected Env `
		.. "(env.ReplicatedStorage, env.service(name), ...; interfaces §2)"
	return setmetatable({}, {
		__index = function(_, key)
			error(`{message} (tried to read {name}.{tostring(key)})`, 2)
		end,
		__newindex = function(_, key)
			error(`{message} (tried to write {name}.{tostring(key)})`, 2)
		end,
		__tostring = function()
			return `<blocked {name}>`
		end,
	})
end

function Globals.build(options: { onUnhandledError: (string, any?) -> (), captureOrigin: (() -> any)?, random: any })
	local report = options.onUnhandledError
	local captureOrigin = options.captureOrigin or function()
		return nil
	end
	local pending: { [thread]: boolean } = {}
	local pendingCount = 0

	local function track(thread: thread): thread
		if coroutine.status(thread) ~= "dead" and not pending[thread] then
			pending[thread] = true
			pendingCount += 1
		end
		return thread
	end
	local function untrack(thread: thread)
		if pending[thread] then
			pending[thread] = nil
			pendingCount -= 1
		end
	end

	-- Wraps fn so that errors at ANY resume of its thread are reported with the spawner's origin.
	local function guard(fn: (...any) -> ...any)
		local origin = captureOrigin()
		return function(...)
			local ok, err = xpcall(fn, function(e)
				return debug.traceback(tostring(e), 2)
			end, ...)
			untrack(coroutine.running())
			if not ok then
				report(err, origin)
			end
		end
	end

	local task = {
		wait = luneTask.wait,
		cancel = function(thread: thread)
			untrack(thread)
			return luneTask.cancel(thread)
		end,
		spawn = function(f, ...)
			if type(f) == "function" then
				return track(luneTask.spawn(guard(f), ...))
			end
			return luneTask.spawn(f, ...)
		end,
		defer = function(f, ...)
			if type(f) == "function" then
				return track(luneTask.defer(guard(f), ...))
			end
			return luneTask.defer(f, ...)
		end,
		delay = function(seconds: number?, f, ...)
			if type(f) == "function" then
				return track(luneTask.delay(seconds, guard(f), ...))
			end
			return luneTask.delay(seconds, f, ...)
		end,
		synchronize = function() end,
		desynchronize = function() end,
	}

	local globals = {
		task = task,
		Random = options.random,
		Enum = roblox.Enum,
		Instance = roblox.Instance,
		game = blocked("game"),
		workspace = blocked("workspace"),
		script = blocked("script"),
		plugin = blocked("plugin"),
	}
	for _, name in DATATYPES do
		globals[name] = roblox[name]
	end
	for name, value in ExtraDatatypes.build(roblox.Enum) do
		globals[name] = value
	end
	local control = {
		pendingCount = function(): number
			return pendingCount
		end,
	}
	return globals, control
end

return Globals
