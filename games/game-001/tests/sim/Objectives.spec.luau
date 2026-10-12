local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Objectives = require("@game/ReplicatedStorage/Game/Sim/Objectives")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")

-- two kingdoms far apart, a neutral tower at the origin (capture 10 s, radius 18)
local function world()
	local sim = Simulation.new({
		random = Random.new(4),
		catalog = F.catalog({ birthInterval = 1e6, hungerPerDay = 0.001 }),
	})
	local crimson = sim:addKingdom({ id = "crimson", x = -300, z = 0 })
	local azure = sim:addKingdom({ id = "azure", x = 300, z = 0 })
	Military.install(sim)
	Objectives.install(sim, { { id = "tower", x = 0, z = 0, captureSeconds = 10, crownPoints = 100 } })
	return sim, crimson, azure, sim.objectives.list[1]
end

local function holdUnit(sim, kingdom, x, z)
	local u = Military.spawnUnit(sim, kingdom, "soldier", x, z)
	u.order = { kind = "Hold" }
	return u
end

describe("Kingdom/Objectives", function()
	it("captures after captureSeconds of uncontested presence and pays Crown Points and territory", function()
		local sim, crimson, _, tower = world()
		holdUnit(sim, crimson, 2, 2)
		sim:advance(5)
		expect(tower.owner).toBeNil()
		expect(tower.progress.crimson).toBeNear(0.5, 0.03)
		sim:advance(5.25)
		expect(tower.owner).toBe("crimson")
		local captured = F.events(sim, "ObjectiveCaptured")
		expect(#captured).toBe(1)
		expect(captured[1].kingdomId).toBe("crimson")
		expect(crimson.crownPoints).toBeGreaterThanOrEqual(100)
		expect(sim:territoryOwner(10, 10)).toBe("crimson")
		expect(sim:territoryOwner(0, 200)).toBeNil()
	end)

	it("lets the captor build inside the claimed region", function()
		local sim, crimson, _, _ = world()
		holdUnit(sim, crimson, 0, 0)
		sim:advance(11)
		local ok, err = sim:canPlace(crimson, "house", 30, 25)
		expect(err).toBeNil()
		expect(ok).toBe(true)
	end)

	it("freezes while contested and resumes when one side leaves", function()
		local sim, crimson, azure, tower = world()
		holdUnit(sim, crimson, 3, 0)
		sim:advance(4)
		local before = tower.progress.crimson
		local blocker = holdUnit(sim, azure, -3, 0)
		sim:advance(6)
		expect(tower.contested).toBe(true)
		expect(tower.progress.crimson).toBeNear(before, 1e-9)
		expect(tower.owner).toBeNil()
		blocker.x = 200 -- walks away
		sim:advance(6.5)
		expect(tower.owner).toBe("crimson")
	end)

	it("decays a challenger's progress at half rate when nobody stands there", function()
		local sim, crimson, _, tower = world()
		local u = holdUnit(sim, crimson, 0, 0)
		sim:advance(6) -- 0.6
		u.x = 100
		sim:advance(4) -- -0.2 at half rate
		expect(tower.progress.crimson).toBeNear(0.4, 0.03)
	end)

	it("counts rulers standing in the zone, and lets another kingdom recapture", function()
		local sim, crimson, azure, tower = world()
		sim:addRuler("crimson", 11)
		sim:addRuler("azure", 22)
		sim:setRulerPosition(11, 1, 1)
		sim:advance(10.25)
		expect(tower.owner).toBe("crimson")
		sim:setRulerPosition(11, nil, nil)
		sim:setRulerPosition(22, -1, -1)
		sim:advance(10.25)
		expect(tower.owner).toBe("azure")
		expect(sim:territoryOwner(10, 10)).toBe("azure")
		local captured = F.events(sim, "ObjectiveCaptured")
		expect(captured[#captured].previousOwner).toBe("crimson")
		expect(#F.events(sim, "RegionReleased")).toBe(0) -- drained above with the captures
		expect(crimson.crownPoints).toBeGreaterThanOrEqual(100)
		expect(azure.crownPoints).toBeGreaterThanOrEqual(100)
	end)

	it("pays hold points while the owner keeps the point", function()
		local sim, crimson, _, tower = world()
		holdUnit(sim, crimson, 0, 0)
		sim:advance(10.25)
		expect(tower.owner).toBe("crimson")
		local after = crimson.crownPoints
		sim:advance(60)
		expect(crimson.crownPoints - after).toBe(6) -- holdPointsPerMinute
	end)

	it("lists objectives as copies (G8 shape)", function()
		local sim, crimson = world()
		holdUnit(sim, crimson, 0, 0)
		sim:advance(2)
		local list = Objectives.list(sim)
		expect(#list).toBe(1)
		expect(list[1].kind).toBe("capture")
		list[1].progress.crimson = 99
		expect(sim.objectives.list[1].progress.crimson < 1).toBe(true)
		expect(Objectives.presence(sim, sim.objectives.list[1])).toEqual({ "crimson" })
	end)

	it("rejects bad definitions", function()
		local sim = Simulation.new({ random = Random.new(1) })
		expect(function()
			Objectives.install(sim, { { id = "a", x = 0, z = 0 }, { id = "a", x = 1, z = 1 } })
		end).toThrow("unique id")
		local sim2 = Simulation.new({ random = Random.new(1) })
		expect(function()
			Objectives.install(sim2, { { id = "b", x = 0, z = 0, captureSeconds = 0 } })
		end).toThrow("bad numbers")
	end)
end)
