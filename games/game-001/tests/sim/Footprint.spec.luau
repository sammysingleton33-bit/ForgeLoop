--[[
	Sim/Footprint: oriented placement rectangles, circles and the overlap tests canPlace uses
	(CONTRACTS G6, G13.5; FORGE-05 finding M2).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")

local FARM = Vector2.new(40, 32) -- Kit farm at its largest level
local GAP = 2

describe("Sim/Footprint", function()
	it("turns a rectangle like CFrame.Angles(0, yaw, 0): width on local X, depth on local Z", function()
		for _, yaw in { 0, 0.4, math.pi / 2, 2.5, -1.1 } do
			local r = Footprint.rect(FARM, 10, -5, yaw)
			local cf = CFrame.new(10, 0, -5) * CFrame.Angles(0, yaw, 0)
			-- a dot just inside each edge overlaps; just outside it does not
			for _, offset in { Vector3.new(19.9, 0, 0), Vector3.new(0, 0, 15.9), Vector3.new(-19.9, 0, 0) } do
				local p = cf:PointToWorldSpace(offset)
				expect(Footprint.overlapsCircle(r, p.X, p.Z, 0.05, 0)).toBe(true)
			end
			for _, offset in { Vector3.new(20.1, 0, 0), Vector3.new(0, 0, 16.1), Vector3.new(0, 0, -16.1) } do
				local p = cf:PointToWorldSpace(offset)
				expect(Footprint.overlapsCircle(r, p.X, p.Z, 0.05, 0)).toBe(false)
			end
		end
	end)

	it("lets two rectangles stand exactly `gap` apart, and not closer", function()
		local a = Footprint.rect(FARM, 0, 0, 0)
		expect(Footprint.overlaps(a, Footprint.rect(FARM, 40 + GAP, 0, 0), GAP)).toBe(false)
		expect(Footprint.overlaps(a, Footprint.rect(FARM, 40 + GAP - 0.01, 0, 0), GAP)).toBe(true)
		expect(Footprint.overlaps(a, Footprint.rect(FARM, 0, -(32 + GAP), math.pi), GAP)).toBe(false)
		expect(Footprint.overlaps(a, Footprint.rect(FARM, 0, -(32 + GAP - 0.01), math.pi), GAP)).toBe(true)
		-- a quarter turn swaps the axes: side by side on X the turned one only needs 20 + 16
		expect(Footprint.overlaps(a, Footprint.rect(FARM, 20 + 16 + GAP, 0, math.pi / 2), GAP)).toBe(false)
		expect(Footprint.overlaps(a, Footprint.rect(FARM, 20 + 16 + GAP - 0.01, 0, -math.pi / 2), GAP)).toBe(true)
	end)

	it("catches corners the circle test missed and frees space the circles wasted", function()
		local a = Footprint.rect(FARM, 0, 0, 0)
		-- a diagonal neighbour the old circles allowed (level-1 farm radius 17) still overlaps at the corners
		local d = (17 + 17 + GAP) / math.sqrt(2) + 0.1
		expect(Footprint.overlaps(a, Footprint.rect(FARM, d, d, 0), GAP)).toBe(true)
		-- a square turned into a diamond may come as close as its corner allows (a circle would not)
		local square = Vector2.new(20, 20)
		local diamond = Footprint.rect(square, 20 + GAP + 10 * math.sqrt(2) + 0.01, 0, math.pi / 4)
		expect(Footprint.overlaps(a, diamond, GAP)).toBe(false)
		expect(Footprint.overlaps(a, Footprint.rect(square, 20 + GAP + 10 * math.sqrt(2) - 0.01, 0, math.pi / 4), GAP)).toBe(
			true
		)
	end)

	it("separates on the other rectangle's axes too (a turned corner beside an edge)", function()
		-- a thin bar across a's corner diagonal: its shadows on X and Z cover a, only its own axis separates
		local a = Footprint.rect(Vector2.new(10, 10), 0, 0, 0)
		local b = Footprint.rect(Vector2.new(30, 4), 7, 7, math.pi / 4)
		expect(Footprint.overlaps(a, b, 0)).toBe(false)
		expect(Footprint.overlaps(b, a, 0)).toBe(false)
	end)

	it("measures a node circle to the rectangle: edges and corners", function()
		local a = Footprint.rect(FARM, 0, 0, 0)
		local r = 3
		expect(Footprint.overlapsCircle(a, 20 + GAP + r, 0, r, GAP)).toBe(false) -- touches at the gap
		expect(Footprint.overlapsCircle(a, 20 + GAP + r - 0.01, 0, r, GAP)).toBe(true)
		local corner = (GAP + r) / math.sqrt(2)
		expect(Footprint.overlapsCircle(a, 20 + corner + 0.01, 16 + corner + 0.01, r, GAP)).toBe(false)
		expect(Footprint.overlapsCircle(a, 20 + corner - 0.01, 16 + corner - 0.01, r, GAP)).toBe(true)
		expect(Footprint.overlapsCircle(a, 1, 1, r, GAP)).toBe(true) -- inside
	end)

	it("handles circles (types without a Kit footprint) against circles and rectangles", function()
		local c = Footprint.circle(0, 0, 6)
		expect(Footprint.overlaps(c, Footprint.circle(6 + 4 + GAP, 0, 4), GAP)).toBe(false)
		expect(Footprint.overlaps(c, Footprint.circle(6 + 4 + GAP - 0.01, 0, 4), GAP)).toBe(true)
		local rect = Footprint.rect(FARM, 6 + GAP + 20, 0, 0)
		expect(Footprint.overlaps(c, rect, GAP)).toBe(false)
		expect(Footprint.overlaps(rect, c, GAP)).toBe(false)
		local closer = Footprint.rect(FARM, 6 + GAP + 20 - 0.01, 0, 0)
		expect(Footprint.overlaps(c, closer, GAP)).toBe(true)
		expect(Footprint.overlaps(closer, c, GAP)).toBe(true)
		expect(Footprint.overlapsCircle(c, 6 + 3 + GAP, 0, 3, GAP)).toBe(false)
	end)

	it("is symmetric and never misses a true overlap (sampled)", function()
		local rng = Random.new(7)
		for _ = 1, 400 do
			local sa = Vector2.new(rng:NextNumber(4, 40), rng:NextNumber(4, 40))
			local sb = Vector2.new(rng:NextNumber(4, 40), rng:NextNumber(4, 40))
			local a = Footprint.rect(sa, rng:NextNumber(-30, 30), rng:NextNumber(-30, 30), rng:NextNumber(-4, 4))
			local b = Footprint.rect(sb, rng:NextNumber(-30, 30), rng:NextNumber(-30, 30), rng:NextNumber(-4, 4))
			local gap = rng:NextNumber(0, 3)
			local hit = Footprint.overlaps(a, b, gap)
			expect(Footprint.overlaps(b, a, gap)).toBe(hit)
			-- the centre of b inside a, or of a inside b, is always an overlap
			if Footprint.overlapsCircle(a, b.x, b.z, 1e-3, 0) or Footprint.overlapsCircle(b, a.x, a.z, 1e-3, 0) then
				expect(hit).toBe(true)
			end
		end
	end)
end)
