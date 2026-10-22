--[[
	Simulation:placeLine / Commands.PlaceBuildingLine (FL-0126 part 2, CONTRACTS G13.5): a straight wall of Kit segments
	between two points, ends snapped to the grid, all or nothing. Geometry: one kingdom at the origin; lines run north of the
	keep (z = -90, inside the 130-stud territory), clear of the starting farm (south-east).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

local deposits = 0

local function world(amount: number?)
	local sim = Simulation.new({ random = Random.new(3), catalog = Catalog.default() })
	local k = sim:addKingdom({ id = "crimson", name = "Test", x = 0, z = 0, populate = false })
	for _, res in { "food", "wood", "stone", "gold" } do
		deposits += 1
		sim.treasury:deposit(k.id, res, amount or 5000, `spec:{deposits}`, "test")
	end
	return sim, k
end

local function stock(sim: any, k: any): { [string]: number }
	local out = {}
	for _, res in { "food", "wood", "stone", "gold" } do
		out[res] = sim:balance(k.id, res)
	end
	return out
end

local function segmentLength(sim: any): number
	return sim.catalog.buildings.wall.placeSize.X
end

describe("Kingdom/Simulation: wall lines (FL-0126, G13.5)", function()
	it(
		"lays round(length / segment) wall pieces end to end along the line, each facing it, and charges each once",
		function()
			local sim, k = world()
			local length = segmentLength(sim)
			local before = stock(sim, k)
			local ids = assert(sim:placeLine(k, "wall", -48, -88, -48 + 3 * length, -88))
			expect(#ids).toBe(3)
			local price = sim.costs.building("wall", 1).cost
			for res, amount in price do
				expect(before[res] - sim:balance(k.id, res)).toBe(amount * 3)
			end
			for i, id in ids do
				local b = sim.buildings[id]
				expect(b.kind).toBe("wall")
				expect(math.abs(b.x - (-48 + (i - 0.5) * length)) < 1e-6).toBe(true)
				expect(math.abs(b.z - -88) < 1e-6).toBe(true)
				expect(math.abs(b.yaw) < 1e-6).toBe(true)
			end
			-- the pieces touch end to end: no hole for a soldier
			for i = 2, #ids do
				local a, b = sim.buildings[ids[i - 1]], sim.buildings[ids[i]]
				expect(math.abs((b.x - a.x) - length) < 1e-6).toBe(true)
			end
		end
	)

	it("turns the pieces to the line's direction", function()
		local sim, k = world()
		local length = segmentLength(sim)
		local ids = assert(sim:placeLine(k, "wall", -90, -64, -90, -64 + 2 * length)) -- along +Z
		expect(#ids).toBe(2)
		local b = sim.buildings[ids[1]]
		-- the long axis of the piece in the world is (cos yaw, -sin yaw): it points along the line, +Z
		expect(math.abs(math.cos(b.yaw)) < 1e-6).toBe(true)
		expect(math.abs(-math.sin(b.yaw) - 1) < 1e-6 or math.abs(-math.sin(b.yaw) + 1) < 1e-6).toBe(true)
		local shape = b.shape
		expect(math.abs(shape.ux) < 1e-6).toBe(true)
		expect(math.abs(math.abs(shape.uz) - 1) < 1e-6).toBe(true)
	end)

	it("splits the length into the nearest whole number of pieces, at least one", function()
		local sim, k = world()
		local length = segmentLength(sim)
		expect(#assert(sim:placeLine(k, "wall", -48, -88, -48 + math.floor(1.4 * length / 4) * 4, -88))).toBe(1)
		expect(#assert(sim:placeLine(k, "wall", -48, -60, -48 + math.floor(1.6 * length / 4) * 4, -60))).toBe(2)
	end)

	it("lays a diagonal line with each piece along it", function()
		local sim, k = world()
		local length = segmentLength(sim)
		local step = math.floor(length / math.sqrt(2) / 4 + 0.5) * 4 -- a 45 degree line, whole grid steps
		local ids = assert(sim:placeLine(k, "wall", -48, -88, -48 + 2 * step, -88 + 2 * step))
		expect(#ids >= 1).toBe(true)
		local dx, dz = 1 / math.sqrt(2), 1 / math.sqrt(2)
		for _, id in ids do
			local shape = sim.buildings[id].shape
			-- the piece's long axis is the line's direction (up to sign)
			expect(math.abs(math.abs(shape.ux * dx + shape.uz * dz) - 1) < 1e-6).toBe(true)
		end
	end)

	it("snaps both ends to the grid", function()
		local sim, k = world()
		local grid = sim.catalog.tuning.lineGrid
		local length = segmentLength(sim)
		local ids = assert(sim:placeLine(k, "wall", -51, -91, -51 + length, -91))
		local b = sim.buildings[ids[1]]
		local snappedStart = math.floor(-51 / grid + 0.5) * grid
		expect(math.abs(b.x - (snappedStart + length / 2)) < 1e-6).toBe(true)
		expect(b.z).toBe(math.floor(-91 / grid + 0.5) * grid)
	end)

	it("is all or nothing: a blocked piece builds and charges nothing", function()
		local sim, k = world()
		local length = segmentLength(sim)
		-- a farm where the second piece would stand
		assert(sim:placeBuilding(k, "farm", -50 + 1.5 * length, -90, nil, 0))
		local before, buildings = stock(sim, k), #sim.buildingOrder
		local ids, why = sim:placeLine(k, "wall", -50, -90, -50 + 3 * length, -90)
		expect(ids).toBeNil()
		expect(why).toBe("blocked")
		expect(#sim.buildingOrder).toBe(buildings)
		expect(stock(sim, k)).toEqual(before)
	end)

	it("refuses a line outside the kingdom's territory, without charging", function()
		local sim, k = world()
		local before = stock(sim, k)
		local ids, why = sim:placeLine(k, "wall", 900, 900, 900 + segmentLength(sim), 900)
		expect(ids).toBeNil()
		expect(why == "out_of_territory" or why == "out_of_bounds").toBe(true)
		expect(stock(sim, k)).toEqual(before)
	end)

	it("charges all the pieces or none: a kingdom that can pay for two of three pays nothing", function()
		local sim, k = world()
		local length = segmentLength(sim)
		local price = sim.costs.building("wall", 1).cost
		-- leave exactly two pieces' worth of every resource
		for _, res in { "food", "wood", "stone", "gold" } do
			local extra = sim:balance(k.id, res) - (price[res] or 0) * 2
			if extra > 0 then
				assert(sim:spend(k.id, { [res] = extra }, `spec:drain:{res}`, "test"))
			end
		end
		local before = stock(sim, k)
		local ids, why = sim:placeLine(k, "wall", -48, -88, -48 + 3 * length, -88)
		expect(ids).toBeNil()
		expect(why).toBe("cannot_afford")
		expect(stock(sim, k)).toEqual(before)
		expect(#assert(sim:placeLine(k, "wall", -48, -88, -48 + 2 * length, -88))).toBe(2) -- the two it can pay
	end)

	it("refuses a line that is too short, too long, or not a wall", function()
		local sim, k = world()
		local length = segmentLength(sim)
		expect({ sim:placeLine(k, "wall", -50, -90, -50, -90) }).toEqual({ nil, "too_short" })
		expect({ sim:placeLine(k, "wall", -50, -90, -48, -90) }).toEqual({ nil, "too_short" }) -- snaps to a point
		local most = sim.catalog.tuning.maxLineSegments
		expect({ sim:placeLine(k, "wall", -50, -90, -50 + (most + 1) * length, -90) }).toEqual({ nil, "too_long" })
		expect({ sim:placeLine(k, "gate", -50, -90, -50 + length, -90) }).toEqual({ nil, "not_a_line_piece" })
		expect({ sim:placeLine(k, "farm", -50, -90, -50 + length, -90) }).toEqual({ nil, "not_a_line_piece" })
		expect({ sim:placeLine(k, "nonsense", -50, -90, -50 + length, -90) }).toEqual({ nil, "unknown_building" })
	end)

	it("a line of a single piece is one wall; a second line may join the first end to end", function()
		local sim, k = world()
		local length = segmentLength(sim)
		local first = assert(sim:placeLine(k, "wall", -50, -90, -50 + length, -90))
		expect(#first).toBe(1)
		local second = assert(sim:placeLine(k, "wall", -50 + length, -90, -50 + 2 * length, -90))
		expect(#second).toBe(1)
		local a, b = sim.buildings[first[1]], sim.buildings[second[1]]
		expect(Footprint.overlaps(a.shape, b.shape, 0)).toBe(false) -- touching is not overlapping
	end)

	it("is the PlaceBuildingLine command: ids on success, the reason on a refusal, invalid args rejected", function()
		local sim, k = world()
		sim.active = true
		local length = segmentLength(sim)
		local ok, err, result =
			Commands.executeFor(sim, k, 1, "PlaceBuildingLine", "wall", -50, -90, -50 + 2 * length, -90)
		expect(ok).toBe(true)
		expect(err).toBeNil()
		expect(#result.buildingIds).toBe(2)
		local ok2, err2 = Commands.executeFor(sim, k, 1, "PlaceBuildingLine", "wall", -50, -90, -50 + 2 * length, -90)
		expect(ok2).toBe(false)
		expect(err2).toBe("blocked") -- the same spot again
		local ok3, err3 = Commands.executeFor(sim, k, 1, "PlaceBuildingLine", "wall", 0 / 0, -90, 10, 10)
		expect(ok3).toBe(false)
		expect(err3).toBe("invalid_args")
	end)
end)
