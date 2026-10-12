--!strict
--[[
	UI/Motion — tweens with a safe fallback. Screens animate through this so they still work (and
	tests stay deterministic) where TweenService is unavailable: then the end state is applied at
	once. Short, purposeful motion only: panel slide-in, value pulses, toast enter/leave.

		local motion = Motion.new(env)            -- uses env.TweenService when it works
		motion:to(frame, { Position = target }, 0.18)
		motion:after(1.2, function() label:Destroy() end)   -- env.spawn + env.wait

	Motion.new(env, { reduced: boolean? }?) -> motion
	motion:to(instance, props, seconds, style?) -> ()  style: Enum.EasingStyle (default Quad, Out)
	motion:after(seconds, fn) -> ()
	motion.enabled -> boolean   false when TweenService is missing or reduced motion is on
]]

local Motion = {}
Motion.__index = Motion

function Motion.new(env: any, opts: { reduced: boolean? }?)
	assert(
		type(env) == "table" and type(env.spawn) == "function" and type(env.wait) == "function",
		"Motion.new(env): env must provide spawn and wait (interfaces §2)"
	)
	local tweenService = nil
	local ok, service = pcall(function()
		local s = env.TweenService
		-- MockEnv's "unmocked" guard errors on use; probe a member to find out.
		local _ = s.Create
		return s
	end)
	if ok then
		tweenService = service
	end
	local reduced = opts ~= nil and opts.reduced == true
	return setmetatable({ _env = env, _tween = tweenService, enabled = tweenService ~= nil and not reduced }, Motion)
end

function Motion:to(instance: any, props: { [string]: any }, seconds: number, style: any?)
	if not self.enabled or seconds <= 0 then
		for key, value in props do
			instance[key] = value
		end
		return
	end
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	self._tween:Create(instance, info, props):Play()
end

function Motion:after(seconds: number, fn: () -> ())
	self._env.spawn(function()
		self._env.wait(seconds)
		fn()
	end)
end

return Motion
