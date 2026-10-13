--!strict
--[[
	UI/Placement — the maths and the server check behind the build ghost (FL-0059). No instances.

		Placement.GRID = 2                               studs; ghost positions snap to it
		Placement.snap(position, grid?) -> Vector3       X and Z to the grid, Y unchanged
		Placement.nextRotation(rot) -> number            0 → 1 → 2 → 3 → 0 (90° steps, G8 `rot`)
		Placement.size(footprint, rot) -> Vector2        the footprint as placed (X/Z swap on 90° and 270°)
		Placement.cframe(position, rot) -> CFrame        what the server builds from the remote args (G8):
		                                                 CFrame.new(position) * CFrame.Angles(0, rot * π / 2, 0)
		Placement.key(type, position, rot) -> string     identifies one ghost spot

	Placement.Checker.new(options) -> checker            throttled `Build.CanPlace` for the ghost tint
		options = { invoke: (type, position, rot) -> (ok, reason?),   e.g. remotes:invoke("Build.CanPlace", ...)
		            onResult: (key, ok: boolean, reason: string?) -> (),
		            spawn, wait, clock,                    env.spawn / env.wait / env.clock
		            interval: number? }                    min seconds between two calls (default 0.12)
		checker:request(type, position, rot)   the latest wish wins: at most one call in flight, calls
		                                       start at least `interval` apart, and a spot that moved on
		                                       while a call was in flight is checked next. With 0.12 s
		                                       this stays under the remote's limit (burst 10, 10/s).
		checker:cancel()                       forget the wish and ignore the reply in flight
		checker.calls -> number                calls made (specs)
	A call that errors (no remote, server failure) reports ok = false with reason nil.
]]

local Placement = {}

Placement.GRID = 2

function Placement.snap(position: Vector3, grid: number?): Vector3
	local g = grid or Placement.GRID
	return Vector3.new(math.floor(position.X / g + 0.5) * g, position.Y, math.floor(position.Z / g + 0.5) * g)
end

function Placement.nextRotation(rot: number): number
	return (rot + 1) % 4
end

function Placement.size(footprint: Vector2, rot: number): Vector2
	if rot % 2 == 1 then
		return Vector2.new(footprint.Y, footprint.X)
	end
	return footprint
end

function Placement.cframe(position: Vector3, rot: number): CFrame
	return CFrame.new(position) * CFrame.Angles(0, rot * math.pi / 2, 0)
end

function Placement.key(buildingType: string, position: Vector3, rot: number): string
	return string.format("%s|%.2f|%.2f|%.2f|%d", buildingType, position.X, position.Y, position.Z, rot)
end

local Checker = {}
Checker.__index = Checker

function Checker.new(options: { [string]: any })
	assert(type(options.invoke) == "function", "Placement.Checker: invoke is required")
	assert(type(options.onResult) == "function", "Placement.Checker: onResult is required")
	return setmetatable({
		_o = options,
		_interval = options.interval or 0.12,
		_want = nil :: any,
		_inFlight = false,
		_lastStart = -math.huge,
		_generation = 0,
		calls = 0,
	}, Checker)
end

function Checker:request(buildingType: string, position: Vector3, rot: number)
	self._want =
		{ type = buildingType, position = position, rot = rot, key = Placement.key(buildingType, position, rot) }
	self:_pump()
end

function Checker:cancel()
	self._want = nil
	self._generation += 1
end

function Checker:_pump()
	if self._inFlight or self._want == nil then
		return
	end
	self._inFlight = true
	local o = self._o
	local generation = self._generation
	o.spawn(function()
		local gap = self._interval - (o.clock() - self._lastStart)
		if gap > 0 then
			o.wait(gap)
		end
		local want = self._want
		if want == nil or generation ~= self._generation then
			self._inFlight = false
			self:_pump()
			return
		end
		self._lastStart = o.clock()
		self.calls += 1
		local called, ok, reason = pcall(o.invoke, want.type, want.position, want.rot)
		self._inFlight = false
		if generation == self._generation then
			if called then
				o.onResult(want.key, ok == true, if type(reason) == "string" then reason else nil)
			else
				o.onResult(want.key, false, nil)
			end
			local latest = self._want
			if latest and latest.key ~= want.key then
				self:_pump()
			end
		else
			self:_pump()
		end
	end)
end

Placement.Checker = Checker

return table.freeze(Placement)
