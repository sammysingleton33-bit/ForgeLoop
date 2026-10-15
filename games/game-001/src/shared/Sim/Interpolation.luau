--!strict
--[[
	Sim/Interpolation — client-side entity interpolation for snapshots (CONTRACTS G4: 10 Hz with a
	≈200 ms interpolation delay). Pure: numbers, Vector3 and tables only; deterministic.

	Tracks (one per entity) hold samples ordered by server time. The renderer evaluates a track at
	renderTime = estimated server time − delay: positions are interpolated linearly and yaw along the
	shortest arc between the two samples around renderTime. Before the first sample the track shows
	the first; after the newest it holds the newest (no extrapolation). Action and carrying come from
	the sample at or before renderTime.

	The clock estimates the server-time offset from snapshot arrivals (serverTime − local clock). It
	follows arrivals that come earlier than expected quickly (RISE) and later ones slowly (FALL), so
	jitter never pushes the render time past the newest data, snaps on a jump over SNAP seconds
	(e.g. a new match restarts serverTime), and never runs the render time backwards otherwise.

	API
		Interpolation.newTrack(): Track
		Interpolation.push(track, t, position, yaw, action, carrying?)   -- keeps time order; same t replaces
		Interpolation.evaluate(track, renderTime?, out?): State?          -- nil while empty; nil renderTime
		                                                                    = the newest sample
		Interpolation.newest(track): number?                              -- newest sample time
		Interpolation.rebase(track, t)                                    -- keeps only the newest sample, at
		                                                                    time t (a clock snap: new timeline)
		Interpolation.lerpYaw(a, b, alpha): number                        -- radians in [0, 2π)
		Interpolation.newClock(): Clock
			clock:observe(serverTime, localTime): boolean             -- true when an established offset
			                                                          snapped (the old timeline is over)
			clock:serverNow(localTime): number?                       -- nil before the first observation
			clock:renderTime(localTime, delay): number?               -- monotonic unless the clock snapped
			clock:reset()
		Interpolation.MAX_SAMPLES, Interpolation.RISE, Interpolation.FALL, Interpolation.SNAP
	State = { position: Vector3, yaw: number, action: string, carrying: string?, speed: number }
		speed: horizontal studs/s over the interpolated segment (0 while holding a sample).
]]

export type Sample = { t: number, position: Vector3, yaw: number, action: string, carrying: string? }
export type Track = { samples: { Sample } }
export type State = { position: Vector3, yaw: number, action: string, carrying: string?, speed: number }

local Interpolation = {}

Interpolation.MAX_SAMPLES = 32
Interpolation.RISE = 0.5
Interpolation.FALL = 0.05
Interpolation.SNAP = 1

local TAU = 2 * math.pi

function Interpolation.lerpYaw(a: number, b: number, alpha: number): number
	local delta = (b - a + math.pi) % TAU - math.pi
	return (a + delta * alpha) % TAU
end

function Interpolation.newTrack(): Track
	return { samples = {} }
end

function Interpolation.newest(track: Track): number?
	local n = #track.samples
	return if n > 0 then track.samples[n].t else nil
end

-- After a clock snap the old samples sit on the old timeline: keep the newest one as the start of the
-- new timeline, so the entity holds its place instead of interpolating towards old-timeline points.
function Interpolation.rebase(track: Track, t: number)
	local samples = track.samples
	local newest = samples[#samples]
	table.clear(samples)
	if newest then
		newest.t = t
		samples[1] = newest
	end
end

function Interpolation.push(track: Track, t: number, position: Vector3, yaw: number, action: string, carrying: string?)
	local samples = track.samples
	local sample = { t = t, position = position, yaw = yaw, action = action, carrying = carrying }
	local i = #samples
	while i > 0 and samples[i].t > t do
		i -= 1
	end
	if i > 0 and samples[i].t == t then
		samples[i] = sample
		return
	end
	table.insert(samples, i + 1, sample)
	if #samples > Interpolation.MAX_SAMPLES then
		table.remove(samples, 1)
	end
end

local function fill(out: State, sample: Sample, position: Vector3, yaw: number, speed: number): State
	out.position = position
	out.yaw = yaw
	out.action = sample.action
	out.carrying = sample.carrying
	out.speed = speed
	return out
end

function Interpolation.evaluate(track: Track, renderTime: number?, out: State?): State?
	local samples = track.samples
	local n = #samples
	if n == 0 then
		return nil
	end
	local o: State = out or ({} :: any)
	local first, last = samples[1], samples[n]
	if renderTime == nil or renderTime >= last.t then
		return fill(o, last, last.position, last.yaw, 0)
	end
	if renderTime <= first.t then
		return fill(o, first, first.position, first.yaw, 0)
	end
	-- drop samples that can no longer bracket a later render time (render time only moves forward)
	while #samples >= 3 and samples[2].t <= renderTime do
		table.remove(samples, 1)
	end
	local i = 1
	while samples[i + 1].t <= renderTime do
		i += 1
	end
	local a, b = samples[i], samples[i + 1]
	local span = b.t - a.t
	local alpha = (renderTime - a.t) / span
	local flat = Vector3.new(b.position.X - a.position.X, 0, b.position.Z - a.position.Z)
	return fill(
		o,
		a,
		a.position:Lerp(b.position, alpha),
		Interpolation.lerpYaw(a.yaw, b.yaw, alpha),
		flat.Magnitude / span
	)
end

-- ---------------------------------------------------------------- server clock

export type Clock = {
	offset: number?,
	last: number?,
	observe: (self: Clock, serverTime: number, localTime: number) -> boolean,
	serverNow: (self: Clock, localTime: number) -> number?,
	renderTime: (self: Clock, localTime: number, delay: number) -> number?,
	reset: (self: Clock) -> (),
}

local ClockClass = {}
ClockClass.__index = ClockClass

function Interpolation.newClock(): Clock
	return (setmetatable({ offset = nil, last = nil }, ClockClass) :: any) :: Clock
end

function ClockClass.observe(self: Clock, serverTime: number, localTime: number): boolean
	local sample = serverTime - localTime
	if sample ~= sample or math.abs(sample) == math.huge then
		return false
	end
	local offset = self.offset
	if offset == nil or math.abs(sample - offset) > Interpolation.SNAP then
		self.offset = sample
		self.last = nil -- a snap may move the render time backwards (new match)
		return offset ~= nil
	elseif sample > offset then
		self.offset = offset + (sample - offset) * Interpolation.RISE
	else
		self.offset = offset + (sample - offset) * Interpolation.FALL
	end
	return false
end

function ClockClass.serverNow(self: Clock, localTime: number): number?
	local offset = self.offset
	return if offset then localTime + offset else nil
end

function ClockClass.renderTime(self: Clock, localTime: number, delay: number): number?
	local now = self:serverNow(localTime)
	if now == nil then
		return nil
	end
	local t = now - delay
	local last = self.last
	if last ~= nil and t < last then
		t = last
	end
	self.last = t
	return t
end

function ClockClass.reset(self: Clock)
	self.offset = nil
	self.last = nil
end

return table.freeze(Interpolation)
