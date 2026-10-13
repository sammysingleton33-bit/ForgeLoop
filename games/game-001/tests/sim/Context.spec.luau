--[[
	Sim/Context (content/SPEC.md §4): the flat kingdom and citizen contexts the content conditions read.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Context = require("@game/ReplicatedStorage/Game/Sim/Context")
local People = require("@game/ReplicatedStorage/Game/Sim/People")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

local function world()
	local sim = F.kingdom()
	local k = sim.kingdoms.crimson
	People.install(sim, 11, People.CONTENT)
	return sim, k
end

describe("Sim/Context", function()
	it("builds the kingdom variables, every building count, flags and rep", function()
		local sim, k = world()
		k.fedRatio = 0.4
		k.conditions = { happiness = 61, stability = 62, morale = 63 }
		local ctx =
			Context.kingdom(sim, "crimson", { phase = "Expansion", events = { "shortage" }, rep = { fear = 33 } })
		expect(ctx.phase).toBe("Expansion")
		expect(ctx["kingdom.fed_ratio"]).toBe(0.4)
		expect(ctx["kingdom.food"]).toBe(sim:balance("crimson", "food"))
		expect(ctx["kingdom.population"]).toBe(#k.citizenIds)
		expect(ctx["kingdom.housing_ratio"]).toBe(#k.citizenIds / k.popCap)
		expect(ctx["kingdom.happiness"]).toBe(61)
		expect(ctx["event.shortage"]).toBe(true)
		expect(ctx["rep.fear"]).toBe(33)
		for _, kind in Types.BUILDING_TYPES do
			expect(type(ctx[`kingdom.count.{kind}`])).toBe("number")
		end
		expect(ctx["kingdom.count.keep"]).toBe(1)
		expect(ctx["kingdom.level.keep"]).toBe(1)
		expect(Context.kingdom(sim, "nowhere")).toEqual({})
	end)

	it("`before` shows the kingdom as it was just before a building reached its level", function()
		local sim, k = world()
		local house = sim:_createBuilding(k, "house", 40, 40)
		sim:_completeInstantly(house)
		sim:_recompute(k)
		local after = Context.kingdom(sim, "crimson")
		local beforeIt = Context.kingdom(sim, "crimson", { before = { buildingId = house.id, level = 1 } })
		expect(after["kingdom.count.house"]).toBe(beforeIt["kingdom.count.house"] + 1)
		local cap = sim.catalog.buildings.house.levels[1].popCap
		expect(beforeIt["kingdom.housing_ratio"]).toBeNear(#k.citizenIds / (k.popCap - cap), 1e-9)
		local keep = sim.buildings[k.keepId]
		keep.level = 2
		sim:_recompute(k)
		local upgraded = Context.kingdom(sim, "crimson", { before = { buildingId = keep.id, level = 2 } })
		expect(upgraded["kingdom.level.keep"]).toBe(1)
		expect(upgraded["kingdom.count.keep"]).toBe(1) -- still standing at level 1
	end)

	it("builds the citizen variables: traits, relations, memories and pinned memories", function()
		local sim, k = world()
		local c = sim.citizens[k.citizenIds[1]]
		c.memory = { { kind = "rulerVisited", t = 0 } }
		c.pinned = { quarry_shored = true }
		local ctx = Context.citizen(sim, c, { phase = "Founding" }, { obedience = 44 })
		expect(ctx.phase).toBe("Founding")
		expect(ctx.occupation).toBe(c.profile.occupation)
		expect(ctx["citizen.loyalty"]).toBe(c.loyalty)
		expect(ctx["citizen.chemistry"]).toBe(c.chemistry)
		expect(ctx["citizen.obedience"]).toBe(44)
		for _, trait in c.profile.traits do
			expect(ctx[`citizen.trait.{trait}`]).toBe(true)
		end
		expect(ctx["citizen.memory.rulerVisited"]).toBe(true)
		expect(ctx["citizen.memory.quarry_shored"]).toBe(true)
		expect(ctx["citizen.has_friend"]).toBe(true) -- every generated citizen has 1-3 friends
		expect(ctx["citizen.has_family"] == true).toBe(#c.profile.family > 0)
		for _, id in c.profile.friends do
			sim.citizens[id] = nil -- friends gone: the flag goes with them
		end
		expect(Context.citizen(sim, c)["citizen.has_friend"]).toBeNil()
	end)
end)
