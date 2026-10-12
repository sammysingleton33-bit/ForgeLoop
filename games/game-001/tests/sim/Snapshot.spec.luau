local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Snapshot = require("@game/ReplicatedStorage/Game/Sim/Snapshot")

-- Only remote-safe values: strings, numbers, booleans and plain tables of them (array or string keys).
local function assertRemoteSafe(value, path, seen)
	seen = seen or {}
	local t = type(value)
	if t == "string" or t == "number" or t == "boolean" or t == "nil" then
		if t == "number" then
			assert(value == value and math.abs(value) ~= math.huge, `{path}: non-finite number`)
		end
		return
	end
	assert(t == "table", `{path}: {t} is not remote-safe`)
	assert(getmetatable(value) == nil, `{path}: has a metatable`)
	assert(not seen[value], `{path}: shared or cyclic table`)
	seen[value] = true
	local n = #value
	for k, v in value do
		if type(k) == "number" then
			assert(k >= 1 and k <= n and math.floor(k) == k, `{path}: sparse array key {k}`)
		else
			assert(type(k) == "string", `{path}: key of type {type(k)}`)
		end
		assertRemoteSafe(v, `{path}.{tostring(k)}`, seen)
	end
end

describe("Kingdom/Snapshot", function()
	it("describes a kingdom with remote-safe values only", function()
		local sim, k = F.kingdom()
		Military.install(sim)
		assert(sim:placeBuilding(k, "house", 0, -35))
		sim:advance(45)
		local snap = Snapshot.kingdom(sim, "crimson", 7)
		assertRemoteSafe(snap, "snapshot")
		expect(snap.seq).toBe(7)
		expect(snap.kingdom.id).toBe("crimson")
		expect(snap.kingdom.resources).toEqual(sim.treasury:get(k.id))
		expect(#snap.citizens).toBe(#k.citizenIds)
		expect(#snap.buildings).toBe(3)
		expect(snap.day).toBe(1)
	end)

	it("never aliases live simulation tables", function()
		local sim, k = F.kingdom()
		sim:addRuler("crimson", 5)
		local snap = Snapshot.kingdom(sim, "crimson", 1)
		snap.kingdom.rulers[1] = 999
		snap.kingdom.quotas.farmer = 0
		snap.kingdom.priorities.wood = 0
		snap.kingdom.resources.food = 0
		snap.kingdom.color[1] = 0
		expect(k.rulers).toEqual({ 5 })
		expect(k.quotas.farmer).toBe(3)
		expect(k.priorities.wood).toBe(1)
		expect(sim:balance(k.id, "food")).toBe(120)
		expect(k.color[1]).never.toBe(0)
	end)

	it("reports construction progress from 0 to 1", function()
		local sim, k = F.kingdom()
		local house = sim:placeBuilding(k, "house", 0, -35)
		local function progress()
			for _, b in Snapshot.kingdom(sim, "crimson", 1).buildings do
				if b.id == house.id then
					return b.progress, b.level
				end
			end
			return nil
		end
		expect(progress()).toBe(0)
		local work = sim:workFor("house", 1)
		sim:addWork(house, work / 2)
		expect(progress()).toBe(0.5)
		sim:addWork(house, work / 2)
		local p, level = progress()
		expect(p).toBe(0)
		expect(level).toBe(1)
	end)

	it("returns nil for an unknown kingdom", function()
		local sim = F.kingdom()
		expect(Snapshot.kingdom(sim, "nope", 1)).toBeNil()
	end)

	it("scores a kingdom by its Crown Points", function()
		local sim, k = F.kingdom()
		expect(Snapshot.score(sim, k)).toBe(0)
		sim:addCrownPoints(k.id, 25, "test")
		expect(Snapshot.score(sim, k)).toBe(25)
		expect(Snapshot.kingdom(sim, k.id, 1).kingdom.crownPoints).toBe(25)
		local events = F.events(sim, "CrownPoints")
		expect(#events).toBe(1)
		expect(events[1].total).toBe(25)
	end)

	it("summarises every kingdom in the overview", function()
		local sim = F.kingdom()
		sim:addKingdom({ id = "azure", name = "Other", x = 400, z = 0 })
		local overview = Snapshot.overview(sim, 3)
		assertRemoteSafe(overview, "overview")
		expect(overview.seq).toBe(3)
		expect(#overview.kingdoms).toBe(2)
		expect(overview.kingdoms[2].name).toBe("Other")
		expect(overview.kingdoms[2].rulerCount).toBe(0)
	end)
end)
