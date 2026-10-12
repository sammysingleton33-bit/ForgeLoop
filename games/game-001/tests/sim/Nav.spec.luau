--[[
	Sim/Nav (FL-0049, CONTRACTS G10.1 Layout.nav): A* routes, route plans, waypoint following, and the
	real world graph sending long trips over the bridges.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Nav = require("@game/ReplicatedStorage/Game/Sim/Nav")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

-- 1 --- 2 --- 3
-- |           |
-- |           5      6 (isolated)
-- 4 ---------/       (4 -> 5 -> 3 = 456 is shorter than 4 -> 1 -> 2 -> 3 = 500)
local function sample()
	return Nav.new({
		nodes = {
			Vector3.new(0, 0, 0),
			Vector3.new(100, 0, 0),
			Vector3.new(200, 0, 0),
			Vector3.new(0, 0, 300),
			Vector3.new(200, 0, 250),
			Vector3.new(900, 0, 900),
		},
		edges = { { 1, 2 }, { 2, 3 }, { 1, 4 }, { 4, 5 }, { 3, 5 } },
	}, { directRange = 150 })
end

-- walk a dummy entity along its waypoints at `speed` studs/s; returns the points it passed
local function walk(nav, from, to, speed)
	local e = { x = from.x, z = from.z }
	local sim = { nav = nav }
	local trail = {}
	for _ = 1, 4000 do
		local wx, wz = Nav.waypoint(sim, e, to.x, to.z)
		local dx, dz = wx - e.x, wz - e.z
		local d = math.sqrt(dx * dx + dz * dz)
		if wx == to.x and wz == to.z and d <= 1 then
			return trail, true
		end
		local step = math.min(d, speed / 16)
		if d > 0 then
			e.x += dx / d * step
			e.z += dz / d * step
		end
		table.insert(trail, { x = e.x, z = e.z })
	end
	return trail, false
end

local function closest(trail, x, z)
	local best = math.huge
	for _, p in trail do
		best = math.min(best, math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2))
	end
	return best
end

describe("Sim/Nav", function()
	it("finds the shortest node route, deterministically, and caches it", function()
		local nav = sample()
		expect(nav:route(1, 3)).toEqual({ 1, 2, 3 })
		expect(nav:route(4, 3)).toEqual({ 4, 5, 3 })
		expect(nav:route(2, 4)).toEqual({ 2, 1, 4 })
		expect(nav:route(1, 6)).toBeNil() -- unreachable
		expect(nav:route(1, 3)).toBe(nav:route(1, 3)) -- cached table
		expect(nav:nearest(190, 20)).toBe(3)
	end)

	it("plans short trips straight and long ones along the graph, ending at the goal", function()
		local nav = sample()
		expect(nav:plan(10, 10, 100, 40)).toEqual({ { x = 100, z = 40 } })
		local plan = nav:plan(-5, 310, 205, -5)
		-- from near node 4 to near node 3: 4 -> 5 -> 3, then the goal
		expect(plan).toEqual({ { x = 0, z = 300 }, { x = 200, z = 250 }, { x = 200, z = 0 }, { x = 205, z = -5 } })
		local isolated = nav:plan(0, 0, 900, 900)
		expect(isolated[#isolated]).toEqual({ x = 900, z = 900 })
	end)

	it("follows waypoints to the goal and replans when the goal moves", function()
		local nav = sample()
		local trail, arrived = walk(nav, { x = -5, z = 310 }, { x = 205, z = -5 }, 12)
		expect(arrived).toBe(true)
		expect(closest(trail, 200, 250) < 4).toBe(true) -- went round by node 5
		local e = { x = -5, z = 310 }
		local sim = { nav = nav }
		Nav.waypoint(sim, e, 205, -5)
		local first = e._route
		Nav.waypoint(sim, e, 205, -5)
		expect(e._route).toBe(first)
		Nav.waypoint(sim, e, 30, 320)
		expect(e._route).never.toBe(first)
		expect(e._route.points).toEqual({ { x = 30, z = 320 } }) -- now a short trip
		expect(select(1, Nav.waypoint({}, e, 7, 8))).toBe(7) -- no nav: straight to the goal
	end)

	it("rejects an edge to a missing node", function()
		expect(function()
			Nav.new({ nodes = { Vector3.zero }, edges = { { 1, 2 } } })
		end).toThrow("missing node")
	end)

	it("sends crimson's march to the watchtower over the north bridge of the world Layout", function()
		local nav = Nav.new(WorldLayout.nav)
		local keep = WorldLayout.plots.crimson.anchors.keep.Position
		local tower = WorldLayout.objectives[1].cframe.Position
		local trail, arrived = walk(nav, { x = keep.X, z = keep.Z }, { x = tower.X, z = tower.Z }, 14)
		expect(arrived).toBe(true)
		local bridge = WorldLayout.features.river.bridges[1].at
		expect(closest(trail, bridge.X, bridge.Y) < 15).toBe(true)
		-- every world plot reaches the tower
		for _, id in { "crimson", "azure", "emerald", "gold" } do
			local p = WorldLayout.plots[id].anchors.keep.Position
			local _, ok = walk(nav, { x = p.X, z = p.Z }, { x = tower.X, z = tower.Z }, 14)
			expect(ok).toBe(true)
		end
	end)
end)
