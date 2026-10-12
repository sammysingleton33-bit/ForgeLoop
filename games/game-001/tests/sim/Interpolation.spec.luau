--[[
	Sim/Interpolation (CONTRACTS G4: ≈200 ms interpolation) and Sim/Pick (G4.1 pick maths).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Interpolation = require("@game/ReplicatedStorage/Game/Sim/Interpolation")
local Pick = require("@game/ReplicatedStorage/Game/Sim/Pick")

local TAU = 2 * math.pi

local function track(samples: { { number } }): Interpolation.Track
	local tr = Interpolation.newTrack()
	for _, s in samples do
		Interpolation.push(tr, s[1], Vector3.new(s[2], 0, 0), s[3] or 0, s[4] or "walk")
	end
	return tr
end

-- shortest signed difference of two angles, radians
local function angleDiff(a: number, b: number): number
	return math.abs((a - b + math.pi) % TAU - math.pi)
end

describe("Sim/Interpolation", function()
	it("interpolates yaw along the shortest arc, both ways across 0", function()
		local r = math.rad
		expect(angleDiff(Interpolation.lerpYaw(r(350), r(10), 0.5), 0)).toBeNear(0, 1e-9)
		expect(angleDiff(Interpolation.lerpYaw(r(10), r(350), 0.25), r(5))).toBeNear(0, 1e-9)
		expect(angleDiff(Interpolation.lerpYaw(r(90), r(180), 0.5), r(135))).toBeNear(0, 1e-9)
		expect(Interpolation.lerpYaw(r(350), r(10), 0)).toBeNear(r(350), 1e-9)
		expect(angleDiff(Interpolation.lerpYaw(r(350), r(10), 1), r(10))).toBeNear(0, 1e-9)
		for _, alpha in { 0, 0.3, 0.7, 1 } do
			local yaw = Interpolation.lerpYaw(r(-170), r(170), alpha)
			expect(yaw >= 0 and yaw < TAU).toBe(true)
			-- the long way round would pass through 0°; the short arc stays within 20° of 180°
			expect(angleDiff(yaw, math.pi)).toBeLessThanOrEqual(r(10) + 1e-9)
		end
	end)

	it("interpolates position linearly between the samples around the render time", function()
		local tr = track({ { 1, 0 }, { 1.1, 10 }, { 1.2, 30 } })
		local s = Interpolation.evaluate(tr, 1.05) :: Interpolation.State
		expect(s.position.X).toBeNear(5, 1e-4)
		expect(s.speed).toBeNear(100, 1e-3)
		s = Interpolation.evaluate(tr, 1.15) :: Interpolation.State
		expect(s.position.X).toBeNear(20, 1e-4)
		expect(s.speed).toBeNear(200, 1e-3)
	end)

	it("shows the first sample before it and holds the newest after it (no extrapolation)", function()
		local tr = track({ { 2, 4 }, { 2.1, 8 } })
		expect((Interpolation.evaluate(tr, 1) :: any).position.X).toBe(4)
		local held = Interpolation.evaluate(tr, 9) :: Interpolation.State
		expect(held.position.X).toBe(8)
		expect(held.speed).toBe(0)
		expect((Interpolation.evaluate(tr, nil) :: any).position.X).toBe(8)
		expect(Interpolation.evaluate(Interpolation.newTrack(), 1)).toBeNil()
	end)

	it("takes action and carrying from the sample at or before the render time", function()
		local tr = Interpolation.newTrack()
		Interpolation.push(tr, 1, Vector3.zero, 0, "walk")
		Interpolation.push(tr, 2, Vector3.zero, 0, "carry", "wood")
		local s = Interpolation.evaluate(tr, 1.9) :: Interpolation.State
		expect(s.action).toBe("walk")
		expect(s.carrying).toBeNil()
		s = Interpolation.evaluate(tr, 2) :: Interpolation.State
		expect(s.action).toBe("carry")
		expect(s.carrying).toBe("wood")
	end)

	it("keeps samples in time order, replaces a duplicate time and caps the buffer", function()
		local tr = track({ { 3, 30 }, { 1, 10 }, { 2, 20 }, { 2, 25 } })
		expect(#tr.samples).toBe(3)
		expect(tr.samples[1].t).toBe(1)
		expect(tr.samples[2].position.X).toBe(25)
		expect(Interpolation.newest(tr)).toBe(3)
		for i = 1, Interpolation.MAX_SAMPLES + 10 do
			Interpolation.push(tr, 10 + i, Vector3.zero, 0, "idle")
		end
		expect(#tr.samples).toBe(Interpolation.MAX_SAMPLES)
		expect(Interpolation.newest(tr)).toBe(10 + Interpolation.MAX_SAMPLES + 10)
	end)

	it("drops samples a later render time can no longer use, keeping the bracket", function()
		local tr = track({ { 1, 0 }, { 2, 1 }, { 3, 2 }, { 4, 3 } })
		Interpolation.evaluate(tr, 3.5)
		expect(#tr.samples).toBe(2)
		expect(tr.samples[1].t).toBe(3)
		expect((Interpolation.evaluate(tr, 3.5) :: any).position.X).toBeNear(2.5, 1e-6)
	end)
end)

describe("Sim/Interpolation clock", function()
	it("renders exactly `delay` behind the server time when latency is constant", function()
		local clock = Interpolation.newClock()
		expect(clock:renderTime(1000, 0.2)).toBeNil()
		for i = 0, 20 do
			clock:observe(50 + i * 0.1, 1000 + i * 0.1) -- offset -950
		end
		expect(clock:serverNow(1002)).toBeNear(52, 1e-9)
		expect(clock:renderTime(1002, 0.2) :: number).toBeNear(51.8, 1e-9)
	end)

	it("follows early arrivals quickly and late ones slowly, never running backwards", function()
		local clock = Interpolation.newClock()
		clock:observe(10, 100) -- offset -90
		clock:observe(10.2, 100.1) -- arrived 0.1 s early: offset rises half way
		expect(clock.offset).toBeNear(-89.95, 1e-9)
		clock:observe(10.3, 100.5) -- arrived late (jitter): offset falls slowly
		expect(clock.offset).toBeGreaterThan(-89.97)
		local previous = -math.huge
		local jitter = { 0, 0.08, -0.05, 0.12, -0.1, 0.03, 0.15, -0.02 }
		for i = 1, 80 do
			local t = 100.5 + i / 60
			if i % 6 == 0 then
				clock:observe(10.3 + i / 60 - 0.05 + jitter[(i // 6) % #jitter + 1], t)
			end
			local render = clock:renderTime(t, 0.2) :: number
			expect(render).toBeGreaterThanOrEqual(previous)
			previous = render
		end
	end)

	it("snaps to a jump over SNAP seconds (a new match restarts serverTime) and resets", function()
		local clock = Interpolation.newClock()
		clock:observe(600, 100)
		expect(clock:renderTime(100, 0.2) :: number).toBeNear(599.8, 1e-9)
		clock:observe(0.5, 101)
		expect(clock:renderTime(101, 0.2) :: number).toBeNear(0.3, 1e-9)
		clock:reset()
		expect(clock:serverNow(101)).toBeNil()
	end)
end)

describe("Sim/Pick", function()
	-- top-down camera: screen = (x, z) * 10, depth = 100 - y; nil when x < 0 (off screen)
	local function project(p: Vector3): (Vector2?, number?)
		if p.X < 0 then
			return nil, nil
		end
		return Vector2.new(p.X * 10, p.Z * 10), 100 - p.Y
	end
	local candidates = {
		{ id = 1, position = Vector3.new(10, 0, 10) },
		{ id = 2, position = Vector3.new(20, 0, 10) },
		{ id = 3, position = Vector3.new(-5, 0, 0) },
		{ id = 4, position = Vector3.new(20, 5, 10) }, -- same screen point as 2, nearer the camera
	}

	it("picks the nearest projected entity within the radius", function()
		expect(Pick.nearest(candidates, Vector2.new(110, 100), project, 60)).toBe(1)
		expect(Pick.nearest(candidates, Vector2.new(160, 100), project, 60)).toBe(4) -- 2 and 4 tie: nearer wins
		expect(Pick.nearest(candidates, Vector2.new(400, 400), project, 60)).toBeNil()
		expect(Pick.nearest(candidates, Vector2.new(-50, 0), project, 60)).toBeNil() -- 3 is off screen
		expect(Pick.nearest({}, Vector2.new(0, 0), project, 60)).toBeNil()
	end)
end)
