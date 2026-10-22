--[[
	Kingdom/Layout.reservedAreas (CONTRACTS G13.9 v0.4-g9j): the crop fields, the plot roads (the avenue from the
	keep door to the gate and the cross street) and the spawn pads are no-build areas for Place, PlaceSlot and
	Move. Layout.generate hands them to the simulation on the world layout (sim.noBuild). The plots' own build
	slots, the starting buildings and the nodes stay clear of them, so a plot is never half unbuildable.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

local WORLD = Layout.WORLD

local function generate()
	local sim = Simulation.new({ random = Random.new(5), catalog = Catalog.default(), bounds = Layout.bounds() })
	Layout.generate(sim)
	return sim
end

local function inside(point: Vector3): boolean
	for _, area in Layout.reservedAreas() do
		-- a point: overlapsCircle with radius 0 is never true (touching is not overlapping), so a hair of radius
		if Footprint.overlapsCircle(area, point.X, point.Z, 0.01, 0) then
			return true
		end
	end
	return false
end

-- a point in the keep's frame (local -Z is the keep's front, towards the plot's yard)
local function local_(kid: string, x: number, z: number): Vector3
	return (WORLD.plots[kid].anchors.keep * CFrame.new(x, 0, z)).Position
end

describe("Layout.reservedAreas: no-build areas (G13.9 v0.4-g9j)", function()
	it("lists 12 crop fields, 4 spawn pads and the 4 plot roads of every kingdom", function()
		local areas = Layout.reservedAreas()
		-- 3 fields per plot, one pad per plot, and per plot the avenue (2 segments) and the cross street (2)
		expect(#areas).toBe(#WORLD.features.fields + #KingdomsConfig.identities + 4 * #KingdomsConfig.identities)
		expect(#WORLD.features.fields).toBe(12)
		-- a copy: changing it does not change the next answer
		table.clear(areas)
		expect(#Layout.reservedAreas() > 0).toBe(true)
	end)

	it("keepOutAreas lists every slot, build zone and crop field a generated node keeps out of", function()
		local slots, zones = 0, 0
		for _, identity in KingdomsConfig.identities do
			local plot = WORLD.plots[identity.id]
			slots += #plot.buildSlots
			zones += #plot.buildZones
		end
		local areas = Layout.keepOutAreas()
		expect(#areas).toBe(slots + zones + #WORLD.features.fields)
		expect(#areas > 60).toBe(true)
		table.clear(areas) -- a copy
		expect(#Layout.keepOutAreas() > 60).toBe(true)
		-- a slot centre is in it; the crop fields are in both lists
		local slot = WORLD.plots.crimson.buildSlots[1]
		local found = false
		for _, area in Layout.keepOutAreas() do
			found = found or Footprint.overlapsCircle(area, slot.center.X, slot.center.Z, 0.01, 0)
		end
		expect(found).toBe(true)
	end)

	it(
		"keeps 3 studs of free ground around a crop field: no house is placed within 2.5 studs of one (the farm fences)",
		function()
			local sim = generate()
			local def = sim.catalog.buildings.house
			local refused, accepted = 0, 0
			for _, field in WORLD.features.fields do
				local cx, cz, yaw = field.center.X, field.center.Y, field.yaw
				local hx, hz = field.size.X / 2, field.size.Y / 2
				for _, identity in KingdomsConfig.identities do
					local kingdom = sim.kingdoms[identity.id]
					for _, clear in { 0.5, 1.5, 2.5 } do
						for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
							-- a house `clear` studs outside the field's edge, on one of its four sides, in the field's frame
							local lx = side[1] * (hx + def.footprint + clear)
							local lz = side[2] * (hz + def.footprint + clear)
							local x = cx + lx * math.cos(yaw) + lz * math.sin(yaw)
							local z = cz - lx * math.sin(yaw) + lz * math.cos(yaw)
							local fits = sim:_geometry(kingdom, "house", x, z, yaw, nil)
							if fits then
								accepted += 1
							else
								refused += 1
							end
						end
					end
				end
			end
			expect(refused > 100).toBe(true) -- the probe covered the fields
			expect(accepted).toBe(0) -- before the gap, 4 of these spots took a house (and the fence's collider ended up inside it)
		end
	)

	it("covers the spawn point, the avenue and the cross street of every plot, and not the yard or the keep", function()
		for _, identity in KingdomsConfig.identities do
			local kid = identity.id
			local spawn = WORLD.plots[kid].spawn.Position
			expect(inside(spawn)).toBe(true)
			expect(inside(spawn + Vector3.new(7, 0, 0))).toBe(true) -- the pad is a square 16 studs across, not a dot
			expect(inside(spawn + Vector3.new(0, 0, -7))).toBe(true)
			expect(inside(spawn + Vector3.new(-5, 0, 5))).toBe(true)
			expect(inside(local_(kid, 0, -60))).toBe(true) -- the avenue through the yard
			expect(inside(local_(kid, 0, -100))).toBe(true) -- ... and out to the gate
			expect(inside(local_(kid, -50, -62))).toBe(true) -- the cross street
			expect(inside(local_(kid, 50, -62))).toBe(true)
			expect(inside(local_(kid, 0, 0))).toBe(false) -- the keep itself is not a road
			expect(inside(local_(kid, -20, -82))).toBe(false) -- a slot beside the avenue is free ground
			expect(inside(local_(kid, 0, -140))).toBe(false) -- past the gate the road is the valley road
		end
	end)

	it("Layout.generate gives them to the simulation on the world layout, and only there", function()
		expect(#generate().noBuild).toBe(#Layout.reservedAreas())
		local square = Simulation.new({ random = Random.new(5), bounds = Layout.boundsFor(300) })
		Layout.generate(square, { spacing = 300 })
		expect(#square.noBuild).toBe(0)
	end)

	it(
		"no build slot reaches one: every type that fits can be placed on every plot, turned every way it fits",
		function()
			local sim = generate()
			local checked = 0
			for _, identity in KingdomsConfig.identities do
				local k = sim.kingdoms[identity.id]
				for _, slot in WORLD.plots[identity.id].buildSlots do
					for kind, def in sim.catalog.buildings do
						if def.placeable and kind ~= "wall" and kind ~= "gate" then
							for _, turn in Fit.turns(kind, slot.size) do
								local yaw = slot.rot + turn * math.pi / 2
								local ok, why = sim:_geometry(k, kind, slot.center.X, slot.center.Z, yaw, nil, false)
								expect(`{slot.id} {kind} turn {turn}: {why}`).toBe(`{slot.id} {kind} turn {turn}: nil`)
								expect(ok).toBe(true)
								checked += 1
							end
						end
					end
				end
			end
			expect(checked > 100).toBe(true)
		end
	)

	it("and a building can be moved onto every slot too: the slots lie inside the keep's own circle", function()
		local sim = generate()
		for _, identity in KingdomsConfig.identities do
			local k = sim.kingdoms[identity.id]
			for _, slot in WORLD.plots[identity.id].buildSlots do
				for kind, def in sim.catalog.buildings do
					if def.placeable and kind ~= "wall" and kind ~= "gate" then
						for _, turn in Fit.turns(kind, slot.size) do
							local yaw = slot.rot + turn * math.pi / 2
							local ok, why = sim:_geometry(k, kind, slot.center.X, slot.center.Z, yaw, nil, true)
							expect(`{slot.id} {kind} turn {turn}: {why}`).toBe(`{slot.id} {kind} turn {turn}: nil`)
							expect(ok).toBe(true)
						end
					end
				end
			end
		end
	end)

	it("the starting buildings stand clear of them", function()
		local sim = generate()
		for _, bid in sim.buildingOrder do
			local b = sim.buildings[bid]
			for _, area in sim.noBuild do
				if Footprint.overlaps(b.shape, area, 0) then
					error(`{b.kingdomId} {b.kind} stands in a no-build area`)
				end
			end
		end
	end)

	it("the avenue in front of the keep door refuses a building, a spot beside it takes one", function()
		local sim = generate()
		local k = sim.kingdoms.crimson
		for _, res in { "wood", "stone", "gold", "food" } do
			sim:deposit("crimson", res, 5000, `spec:avenue:{res}`, "spec")
		end
		local onAvenue = local_("crimson", 0, -60)
		local ok, why = sim:canPlace(k, "house", onAvenue.X, onAvenue.Z, 0)
		expect(ok).toBe(false)
		expect(why).toBe("blocked")
		-- the same house on a slot, which is free ground beside the avenue
		local slot = WORLD.plots.crimson.buildSlots[1]
		expect(sim:canPlace(k, "house", slot.center.X, slot.center.Z, slot.rot)).toBe(true)
	end)
end)
