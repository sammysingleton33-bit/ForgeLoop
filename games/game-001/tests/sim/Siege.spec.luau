--[[
	Siege viability (FL-0126, FORGE-07's #187 numbers): war must be able to decide something.
	  - A determined assault (15 units: soldiers and a ram, focused) takes an UNDEFENDED level 2 keep in about 3-5 minutes.
	  - Soldiers alone barely scratch a keep (they cannot decide a war without rams).
	  - A DEFENDED keep holds against a comparable force.
	The unit numbers are config Military / Buildings; the AI side (RulerAI assault) is covered in RulerAI.spec and the
	long probe (sim/long/WarProbe.spec).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Diplomacy = require("@game/ReplicatedStorage/Game/Sim/Diplomacy")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")

local function world()
	local sim, k1 = F.kingdom({ nodes = false, tuning = { startCitizens = {}, birthInterval = 1e6 } })
	local k2 = sim:addKingdom({ id = "azure", name = "Rival", x = 300, z = 0 })
	Military.install(sim)
	assert(sim:addRuler("crimson", 101))
	assert(sim:addRuler("azure", 201))
	Diplomacy.setRelation(sim, "crimson", "azure", "War")
	-- both keeps at level 2, as every governor's is at war time
	for _, k in { k1, k2 } do
		local keep = sim.buildings[k.keepId]
		local stats = sim.catalog.buildings.keep.levels[2]
		keep.level, keep.maxHp, keep.hp = 2, stats.hp, stats.hp
		sim:_recompute(k)
	end
	F.events(sim)
	return sim, k1, k2
end

-- soldiers and rams standing at the keep's edge, ordered to attack it
local function assault(sim, from, target, soldiers: number, rams: number)
	local keep = sim.buildings[target.keepId]
	local list = {}
	for i = 1, soldiers do
		local u = Military.spawnUnit(sim, from, "soldier", keep.x - 20, (i - soldiers / 2) * 3)
		u.order = { kind = "Attack", kingdomId = target.id }
		table.insert(list, u)
	end
	for i = 1, rams do
		local u = Military.spawnUnit(sim, from, "ram", keep.x - 19, i * 4)
		u.order = { kind = "Attack", kingdomId = target.id }
		table.insert(list, u)
	end
	return list
end

-- seconds until `target` is eliminated, or nil within `limit`
local function secondsToFall(sim, target, limit: number): number?
	local t = 0
	while t < limit do
		sim:advance(1)
		t += 1
		if not target.alive then
			return t
		end
	end
	return nil
end

describe("Siege viability: undefended keeps", function()
	it("13 soldiers and a ram take an undefended level 2 keep in 3 to 5 minutes", function()
		local sim, k1, k2 = world()
		assault(sim, k1, k2, 13, 1)
		local seconds = secondsToFall(sim, k2, 600)
		expect(seconds).never.toBeNil()
		expect((seconds :: number) >= 180).toBe(true)
		expect((seconds :: number) <= 300).toBe(true)
	end)

	it("two rams make it faster than one", function()
		local sim, k1, k2 = world()
		assault(sim, k1, k2, 11, 2)
		local seconds = secondsToFall(sim, k2, 600)
		expect(seconds).never.toBeNil()
		expect((seconds :: number) < 170).toBe(true)
	end)

	it(
		"soldiers without a ram cannot decide a war: 13 of them leave a level 2 keep standing after 5 minutes",
		function()
			local sim, k1, k2 = world()
			assault(sim, k1, k2, 13, 0)
			expect(secondsToFall(sim, k2, 300)).toBeNil()
			local keep = sim.buildings[k2.keepId]
			expect(keep.hp > keep.maxHp * 0.5).toBe(true)
		end
	)
end)

describe("Siege viability: defended keeps", function()
	it("hold against a comparable force: 12 soldiers and a ram are spent and the keep stands", function()
		local sim, k1, k2 = world()
		local keep = sim.buildings[k2.keepId]
		for i = 1, 12 do
			local u = Military.spawnUnit(sim, k2, "soldier", keep.x - 12 + (i % 4) * 3, (i - 6) * 3)
			u.order = { kind = "Defend" }
		end
		assault(sim, k1, k2, 12, 1)
		expect(secondsToFall(sim, k2, 600)).toBeNil()
		expect(k2.alive).toBe(true)
		expect(#k1.unitIds).toBe(0) -- the assault was spent on the defenders and the keep's fire
	end)
end)
