--[[
	Buildings.wallGap (user playtest 2026-10-13, FORGE-03's wall chain placement): two line pieces (wall, gate)
	may touch end to end, so a chain of walls has no 2-stud hole every segment. Every other pair of buildings
	keeps placementGap. The rule is Simulation:canPlace's; the Build rail's CanPlace and Place use it.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

-- a clear spot near the keep where `kind` stands, with room on its +X side for a neighbour `reach` studs on
local function baseSpot(sim, k, kind: string, yaw: number, reach: number): (number, number)
	local keep = sim.buildings[k.keepId]
	for radius = 40, 120, 10 do
		for step = 0, 23 do
			local a = step / 24 * 2 * math.pi
			local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
			if sim:canPlace(k, kind, x, z, yaw) and sim:canPlace(k, kind, x + reach, z, yaw) then
				return x, z
			end
		end
	end
	error(`no spot for {kind}`)
end

-- the real catalog (placement rectangles from the Kit), not KingdomFixtures' circles
local function stocked()
	local sim = Simulation.new({ random = Random.new(3), catalog = Catalog.default() })
	local k = sim:addKingdom({ id = "crimson", name = "Test", x = 0, z = 0 })
	for _, res in { "wood", "stone", "gold", "food" } do
		sim:deposit("crimson", res, 5000, `spec:wall:{res}`, "spec")
	end
	return sim, k
end

describe("wallGap: wall and gate pieces join end to end (user playtest)", function()
	it("is 0 for line pieces and never more than the placement gap", function()
		local sim = stocked()
		local tuning = sim.catalog.tuning
		expect(tuning.wallGap).toBe(0)
		expect(tuning.placementGap).toBe(2)
		expect(tuning.wallGap <= tuning.placementGap).toBe(true)
	end)

	it("two walls touch end to end in a line, unturned and turned; a sliver of overlap is still blocked", function()
		local sim, k = stocked()
		local width = assert(Fit.largestFootprint("wall")).X
		local x, z = baseSpot(sim, k, "wall", 0, width)
		assert(sim:placeBuilding(k, "wall", x, z, 1, 0))
		expect(sim:canPlace(k, "wall", x + width, z, 0)).toBe(true) -- exactly end to end
		expect(sim:canPlace(k, "wall", x + width - 0.5, z, 0)).toBe(false) -- half a stud inside it
		expect(sim:canPlace(k, "wall", x - width, z, 0)).toBe(true) -- the other end too
		-- along Z, turned a quarter (rot 1): the line runs the other way
		local tx, tz = baseSpot(sim, k, "wall", math.pi / 2, 0)
		assert(sim:placeBuilding(k, "wall", tx, tz, 1, math.pi / 2))
		expect(sim:canPlace(k, "wall", tx, tz + width, math.pi / 2)).toBe(true)
		expect(sim:canPlace(k, "wall", tx, tz + width - 0.5, math.pi / 2)).toBe(false)
	end)

	it("a gate joins a wall the same way", function()
		local sim, k = stocked()
		local wall = assert(Fit.largestFootprint("wall"))
		local gate = assert(Fit.largestFootprint("gate"))
		local step = wall.X / 2 + gate.X / 2
		local x, z = baseSpot(sim, k, "wall", 0, step)
		assert(sim:placeBuilding(k, "wall", x, z, 1, 0))
		expect(sim:canPlace(k, "gate", x + step, z, 0)).toBe(true)
		expect(sim:canPlace(k, "gate", x + step - 0.5, z, 0)).toBe(false)
	end)

	it("every other neighbour keeps the placement gap from a wall: only line pieces join", function()
		local sim, k = stocked()
		local wall = assert(Fit.largestFootprint("wall"))
		local house = assert(Fit.largestFootprint("house"))
		local gap = sim.catalog.tuning.placementGap
		local step = wall.X / 2 + house.X / 2
		local x, z = baseSpot(sim, k, "wall", 0, step + gap + 1)
		assert(sim:placeBuilding(k, "wall", x, z, 1, 0))
		expect(sim:canPlace(k, "house", x + step, z, 0)).toBe(false) -- touching: too close
		expect(sim:canPlace(k, "house", x + step + gap - 0.5, z, 0)).toBe(false)
		expect(sim:canPlace(k, "house", x + step + gap, z, 0)).toBe(true) -- the usual gap
		-- and a wall keeps it from a house the other way round
		local hx, hz = baseSpot(sim, k, "house", 0, step + gap + 1)
		assert(sim:placeBuilding(k, "house", hx, hz, 1, 0))
		expect(sim:canPlace(k, "wall", hx + step, hz, 0)).toBe(false)
		expect(sim:canPlace(k, "wall", hx + step + gap, hz, 0)).toBe(true)
	end)
end)
