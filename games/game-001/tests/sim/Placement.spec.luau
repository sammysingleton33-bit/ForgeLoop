--[[
	Building placement on the game catalog (CONTRACTS G6, G13.5; FORGE-05 finding M2): canPlace tests each
	building's Kit footprint rectangle at its largest level, turned by its yaw and kept placementGap from
	its neighbours and from resource nodes; types without a Kit footprint keep the footprint circle.
	The footprint radius (reach for citizens, units and combat) stays half the longer level-1 side.
	Geometry: one kingdom at the origin; specs build west of the keep (x < -23), clear of the starting
	farm (east, tuning.startBuildings), with explicit yaws unless they test the default facing.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

local deposits = 0

local function world(catalog: any?)
	local sim = Simulation.new({ random = Random.new(3), catalog = catalog or Catalog.default() })
	local k = sim:addKingdom({ id = "crimson", name = "Test", x = 0, z = 0, populate = false })
	for _, res in { "food", "wood", "stone", "gold" } do
		deposits += 1
		sim.treasury:deposit(k.id, res, 5000, `spec:{deposits}`, "test")
	end
	return sim, k
end

local function gap(sim): number
	return sim.catalog.tuning.placementGap
end

describe("Kingdom/Simulation: placement rectangles (G6, M2)", function()
	it("places with the largest Kit level's rectangle and keeps the level-1 reach radius", function()
		local catalog = Catalog.default()
		for kind, def in catalog.buildings do
			local first = Kit.footprint(kind, 1)
			expect(def.placeSize).toEqual(Kit.footprint(kind, Costs.maxLevel(kind)))
			expect(def.footprint).toBe(math.max(first.X, first.Y) / 2)
		end
	end)

	it("blocks two farms the old circles allowed when their rectangles meet at the corners", function()
		local sim, k = world()
		local radius = sim.catalog.buildings.farm.footprint -- level-1 circle: 17
		local a = assert(sim:placeBuilding(k, "farm", -80, -40, nil, 0))
		local d = (2 * radius + gap(sim)) / math.sqrt(2) + 0.05
		local x, z = a.x + d, a.z - d
		expect(math.sqrt((x - a.x) ^ 2 + (z - a.z) ^ 2) >= 2 * radius + gap(sim)).toBe(true) -- old rule: fine
		expect({ sim:canPlace(k, "farm", x, z, 0) }).toEqual({ false, "blocked" })
		expect({ sim:placeBuilding(k, "farm", x, z, nil, 0) }).toEqual({ nil, "blocked" })
	end)

	it("allows neighbours exactly placementGap apart, and not closer", function()
		local sim, k = world()
		local size = sim.catalog.buildings.farm.placeSize
		local a = assert(sim:placeBuilding(k, "farm", -80, -50, nil, 0))
		local touching = a.x + size.X + gap(sim)
		expect({ sim:canPlace(k, "farm", touching - 0.01, a.z, 0) }).toEqual({ false, "blocked" })
		expect({ sim:canPlace(k, "farm", a.x + size.X, a.z, 0) }).toEqual({ false, "blocked" }) -- no gap
		expect({ sim:canPlace(k, "farm", touching, a.z, 0) }).toEqual({ true })
		assert(sim:placeBuilding(k, "farm", touching, a.z, nil, 0))
	end)

	it("judges the largest level: a level-1 site that would collide once upgraded is blocked", function()
		local sim, k = world()
		local first, last = Kit.footprint("farm", 1), Kit.footprint("farm", Costs.maxLevel("farm"))
		expect(last.X > first.X).toBe(true)
		local a = assert(sim:placeBuilding(k, "farm", -80, -50, nil, 0))
		local x = a.x + first.X + gap(sim) + 1 -- level-1 rectangles would keep the gap
		expect(Footprint.overlaps(Footprint.rect(first, a.x, a.z, 0), Footprint.rect(first, x, a.z, 0), gap(sim))).toBe(
			false
		)
		expect({ sim:canPlace(k, "farm", x, a.z, 0) }).toEqual({ false, "blocked" })
		expect({ sim:canPlace(k, "farm", a.x + last.X + gap(sim), a.z, 0) }).toEqual({ true })
	end)

	it("turns the rectangle with the yaw: a long building turned a quarter frees the space", function()
		local sim, k = world()
		local barracks = sim.catalog.buildings.barracks.placeSize -- 34 x 22: long on X
		expect(barracks.X > barracks.Y).toBe(true)
		local farm = sim.catalog.buildings.farm.placeSize
		local a = assert(sim:placeBuilding(k, "farm", -104, 0, nil, 0))
		-- 3 studs of room for the barracks' short side, not for its long side
		local x = a.x + farm.X / 2 + gap(sim) + barracks.Y / 2 + 3
		expect({ sim:canPlace(k, "barracks", x, 0, 0) }).toEqual({ false, "blocked" })
		expect({ sim:canPlace(k, "barracks", x, 0, math.pi) }).toEqual({ false, "blocked" })
		expect({ sim:canPlace(k, "barracks", x, 0, math.pi / 2) }).toEqual({ true })
		local b = assert(sim:placeBuilding(k, "barracks", x, 0, nil, math.pi / 2))
		expect(b.yaw).toBe(math.pi / 2)
	end)

	it("without a yaw, judges the facing placeBuilding will give (front towards the keep)", function()
		local sim, k = world()
		local farm = sim.catalog.buildings.farm.placeSize
		local barracks = sim.catalog.buildings.barracks.placeSize
		local a = assert(sim:placeBuilding(k, "farm", -104, 0, nil, 0))
		local x = a.x + farm.X / 2 + gap(sim) + barracks.Y / 2 + 3 -- due west of the keep: turned a quarter
		expect({ sim:canPlace(k, "barracks", x, 0) }).toEqual({ true })
		local b = assert(sim:placeBuilding(k, "barracks", x, 0))
		expect(math.abs(math.cos(b.yaw)) < 1e-9).toBe(true) -- faces east, towards the keep
	end)

	it("keeps resource nodes clear of the rectangle: corners block, the short sides no longer waste room", function()
		local sim, k = world()
		local size = sim.catalog.buildings.farm.placeSize
		local radius = sim.catalog.buildings.farm.footprint
		local tree = sim.catalog.nodes.tree.footprint
		local x, z = -80, -50
		-- a tree just past the short side: the old circle rule blocked it, the rectangle does not
		local side = sim:addNode("tree", x, z - (size.Y / 2 + gap(sim) + tree))
		expect(math.abs(side.z - z) < radius + tree + gap(sim)).toBe(true)
		-- a tree off the corner, beyond the old circle: now it blocks
		local reach = (gap(sim) + tree) / math.sqrt(2) - 0.05
		local corner = sim:addNode("tree", x - size.X / 2 - reach, z + size.Y / 2 + reach)
		expect(math.sqrt((corner.x - x) ^ 2 + (corner.z - z) ^ 2) >= radius + tree + gap(sim)).toBe(true)
		expect({ sim:canPlace(k, "farm", x, z, 0) }).toEqual({ false, "blocked" })
		corner.amount, corner.regrow = 0, nil -- gone for good: no longer blocks
		expect({ sim:canPlace(k, "farm", x, z, 0) }).toEqual({ true })
	end)

	it("keeps the circle for a type without a placement rectangle", function()
		local catalog = Catalog.default()
		catalog.buildings.house.placeSize = nil -- as for a type the Kit does not know
		local sim, k = world(catalog)
		local r = catalog.buildings.house.footprint
		local a = assert(sim:placeBuilding(k, "house", -80, -50, nil, 0))
		for _, yaw in { 0, math.pi / 4, math.pi / 2 } do
			local d = 2 * r + gap(sim)
			expect({ sim:canPlace(k, "house", a.x + d * math.cos(yaw), a.z + d * math.sin(yaw), yaw) }).toEqual({
				true,
			})
			d -= 0.01
			expect({ sim:canPlace(k, "house", a.x + d * math.cos(yaw), a.z + d * math.sin(yaw), yaw) }).toEqual({
				false,
				"blocked",
			})
		end
	end)
end)
