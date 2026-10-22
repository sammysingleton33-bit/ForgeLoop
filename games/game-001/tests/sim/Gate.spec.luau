--[[
	Simulation:placeGate / Commands.PlaceGate (FL-0126 part 2, slice 2, CONTRACTS G13.5): one of a kingdom's wall pieces becomes
	a gate, in place; and what a gate lets through (nothing a wall does not: only an at-war enemy's buildings stop a unit).
	Geometry: one kingdom at the origin; walls stand in the open north of the keep (z = -88), inside the 130-stud territory.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
local Diplomacy = require("@game/ReplicatedStorage/Game/Sim/Diplomacy")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

local deposits = 0

local function world()
	local sim = Simulation.new({ random = Random.new(3), catalog = Catalog.default() })
	local k = sim:addKingdom({ id = "crimson", name = "Test", x = 0, z = 0, populate = false })
	local rival = sim:addKingdom({ id = "azure", name = "Rival", x = 600, z = 0, populate = false })
	for _, res in { "food", "wood", "stone", "gold" } do
		deposits += 1
		sim.treasury:deposit(k.id, res, 5000, `spec:{deposits}`, "test")
	end
	return sim, k, rival
end

local function stock(sim: any, k: any): { [string]: number }
	local out = {}
	for _, res in { "food", "wood", "stone", "gold" } do
		out[res] = sim:balance(k.id, res)
	end
	return out
end

local function wallAt(sim: any, k: any, x: number?): any
	local ids =
		assert(sim:placeLine(k, "wall", x or -48, -88, (x or -48) + sim.catalog.buildings.wall.placeSize.X, -88))
	return sim.buildings[ids[1]]
end

describe("Kingdom/Simulation: gates (FL-0126, G13.5)", function()
	it("turns a wall piece into a gate in place, charging the gate and returning half the wall's price", function()
		local sim, k = world()
		-- a piece turned a quarter (a line along +Z), so the gate has to take the wall's facing, not a default
		local wall = sim.buildings[assert(
			sim:placeLine(k, "wall", -90, -64, -90, -64 + sim.catalog.buildings.wall.placeSize.X)
		)[1]]
		expect(math.abs(wall.yaw) > 1).toBe(true)
		local x, z, yaw = wall.x, wall.z, wall.yaw
		local before = stock(sim, k)
		local gate = assert(sim:placeGate(k, wall.id, 7))
		expect(gate.kind).toBe("gate")
		expect(gate.x).toBe(x)
		expect(gate.z).toBe(z)
		expect(gate.yaw).toBe(yaw)
		expect(gate.placedBy).toBe(7)
		expect(gate.kingdomId).toBe("crimson")
		expect(sim.buildings[wall.id]).toBeNil() -- the wall is gone
		expect(wall.destroyed).toBe(true)
		local gatePrice = sim.costs.building("gate", 1).cost
		local wallPrice = sim.costs.building("wall", 1).cost
		for res, now in stock(sim, k) do
			local expected = before[res]
				- (gatePrice[res] or 0)
				+ math.floor((wallPrice[res] or 0) * sim.catalog.tuning.cancelRefund)
			expect(now).toBe(expected)
		end
		expect(sim:countOf(k, "gate")).toBe(1)
		expect(sim:countOf(k, "wall")).toBe(0)
	end)

	it("keeps the rest of the line: the neighbours of the replaced piece stand where they were", function()
		local sim, k = world()
		local length = sim.catalog.buildings.wall.placeSize.X
		local ids = assert(sim:placeLine(k, "wall", -48, -88, -48 + 3 * length, -88))
		local middle = sim.buildings[ids[2]]
		local gate = assert(sim:placeGate(k, middle.id))
		expect(sim.buildings[ids[1]]).toBeTruthy()
		expect(sim.buildings[ids[3]]).toBeTruthy()
		expect(math.abs(gate.x - middle.x) < 1e-9).toBe(true)
		expect(sim:countOf(k, "wall")).toBe(2)
	end)

	it("allows one gate per kingdom", function()
		local sim, k = world()
		local first, second = wallAt(sim, k, -48), wallAt(sim, k, 0)
		assert(sim:placeGate(k, first.id))
		local before = stock(sim, k)
		expect({ sim:placeGate(k, second.id) }).toEqual({ nil, "limit_reached" })
		expect(sim.buildings[second.id]).toBeTruthy()
		expect(stock(sim, k)).toEqual(before)
	end)

	it("refuses what is not the player's wall, without charging", function()
		local sim, k, rival = world()
		local wall = wallAt(sim, k)
		local farm = assert(sim:placeBuilding(k, "farm", -80, 30, nil, 0))
		local before = stock(sim, k)
		expect({ sim:placeGate(k, farm.id) }).toEqual({ nil, "not_a_wall" })
		expect({ sim:placeGate(rival, wall.id) }).toEqual({ nil, "not_owner" })
		expect({ sim:placeGate(k, 99999) }).toEqual({ nil, "not_found" })
		expect({ sim:placeGate(k, "x") }).toEqual({ nil, "not_found" })
		expect(stock(sim, k)).toEqual(before)
		expect(sim.buildings[wall.id]).toBeTruthy()
	end)

	it("refuses a wall being upgraded, or under attack", function()
		local sim, k = world()
		local wall = wallAt(sim, k)
		wall.level, wall.pendingLevel = 1, 2
		expect({ sim:placeGate(k, wall.id) }).toEqual({ nil, "busy" })
		wall.pendingLevel = nil
		wall.burning = true
		expect({ sim:placeGate(k, wall.id) }).toEqual({ nil, "under_attack" })
		expect(sim.buildings[wall.id]).toBeTruthy()
	end)

	it("counts the wall's refund towards the gate's price", function()
		local sim, k = world()
		local wall = wallAt(sim, k)
		local price = sim.costs.building("gate", 1).cost
		local refund = sim.costs.building("wall", 1).cost
		local res, amount, back = nil, 0, 0
		for r, a in price do
			local share = math.floor((refund[r] or 0) * sim.catalog.tuning.cancelRefund)
			if share > 0 and a > amount then
				res, amount, back = r, a, share
			end
		end
		assert(res, "a resource the wall refunds and the gate costs")
		local keep = amount - back -- exactly enough once the wall's share is returned
		assert(sim:spend(k.id, { [res] = sim:balance(k.id, res) - keep }, "spec:drain", "test"))
		expect(sim:balance(k.id, res) < amount).toBe(true) -- not enough without the refund
		local gate = assert(sim:placeGate(k, wall.id))
		expect(gate.kind).toBe("gate")
		expect(sim:balance(k.id, res)).toBe(0)
	end)

	it("charges nothing and keeps the wall when the kingdom cannot pay for the gate", function()
		local sim, k = world()
		local wall = wallAt(sim, k)
		local price = sim.costs.building("gate", 1).cost
		local refund = sim.costs.building("wall", 1).cost
		-- leave one short of the gate's price in the dearest resource, counting the wall's refund
		local res, amount = next(price)
		for r, a in price do
			if a > amount then
				res, amount = r, a
			end
		end
		local give = amount - 1 - math.floor((refund[res] or 0) * sim.catalog.tuning.cancelRefund)
		local extra = sim:balance(k.id, res) - give
		assert(sim:spend(k.id, { [res] = extra }, "spec:drain", "test"))
		local before = stock(sim, k)
		expect({ sim:placeGate(k, wall.id) }).toEqual({ nil, "cannot_afford" })
		expect(stock(sim, k)).toEqual(before)
		expect(sim.buildings[wall.id]).toBeTruthy()
	end)

	it("is the PlaceGate command: the gate's id on success, the reason on a refusal, invalid args rejected", function()
		local sim, k = world()
		sim.active = true
		local wall = wallAt(sim, k)
		local ok, err, result = Commands.executeFor(sim, k, 1, "PlaceGate", wall.id)
		expect(ok).toBe(true)
		expect(err).toBeNil()
		expect(sim.buildings[result.buildingId].kind).toBe("gate")
		local ok2, err2 = Commands.executeFor(sim, k, 1, "PlaceGate", wall.id)
		expect(ok2).toBe(false)
		expect(err2).toBe("not_found") -- the wall is gone
		local ok3, err3 = Commands.executeFor(sim, k, 1, "PlaceGate", "wall")
		expect(ok3).toBe(false)
		expect(err3).toBe("invalid_args")
	end)
end)

-- ---------------------------------------------------------------- passage: Military.spec's two-kingdom world
local RULER, RIVAL = 101, 201

local function warWorld()
	local sim, k1 = F.kingdom({
		nodes = false,
		tuning = { startCitizens = {}, birthInterval = 1e6, hungerPerDay = 0.001 },
	})
	local k2 = sim:addKingdom({ id = "azure", name = "Rival", x = 300, z = 0 })
	Military.install(sim)
	assert(sim:addRuler("crimson", RULER))
	assert(sim:addRuler("azure", RIVAL))
	F.events(sim)
	return sim, k1, k2
end

local function addBuilding(sim: any, k: any, kind: string, x: number, z: number)
	local b = sim:_createBuilding(k, kind, x, z)
	sim:_completeInstantly(b)
	local stats = sim.catalog.buildings[kind].levels[1]
	b.level = 1
	b.maxHp = stats.hp
	b.hp = stats.hp
	sim:_recompute(k)
	return b
end

local function unit(sim: any, k: any, kind: string, x: number, z: number, order: { [string]: any })
	local u = Military.spawnUnit(sim, k, kind, x, z)
	u.order = order
	return u
end

describe("Sim/Military: what a gate lets through (FL-0126, G13.5)", function()
	it("an at-war enemy meets a gate as a wall: it stops at it and breaks it first", function()
		local sim, k1, k2 = warWorld()
		Diplomacy.setRelation(sim, "crimson", "azure", "War")
		local gate = addBuilding(sim, k1, "gate", 125, 0)
		gate.hp = 6
		local raider = unit(sim, k2, "soldier", 150, 0, { kind = "Move", x = 100, z = 0 })
		local blocked = false
		for _ = 1, 20 do
			sim:advance(0.25)
			if sim.buildings[gate.id] then
				blocked = true
				expect(raider.x).toBeGreaterThanOrEqual(125 + gate.footprint + Military.UNIT_RADIUS)
			end
		end
		expect(blocked).toBe(true)
		expect(sim.buildings[gate.id]).toBeNil() -- broken, then the march goes on
	end)

	it("the owner's units walk through a gate (and a wall of their own), and so does anyone at peace", function()
		local sim, k1 = warWorld()
		Diplomacy.setRelation(sim, "crimson", "azure", "War")
		addBuilding(sim, k1, "gate", 125, 0)
		local mine = unit(sim, k1, "soldier", 150, 0, { kind = "Move", x = 100, z = 0 })
		sim:advance(5)
		expect(mine.x <= 102.01).toBe(true) -- straight through the gate, untouched
		expect(mine.hp).toBe(mine.maxHp)
		-- at peace the rival's march is not stopped either
		local sim2, a1, a2 = warWorld()
		addBuilding(sim2, a1, "gate", 125, 0)
		local walker = unit(sim2, a2, "soldier", 150, 0, { kind = "Move", x = 100, z = 0 })
		sim2:advance(5)
		expect(walker.x).toBeNear(102, 0.01) -- as through a wall (Military.spec): it arrives within 2 studs of the point
	end)
end)
