local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Commands = require("@game/ReplicatedStorage/Game/Sim/Commands")
local Diplomacy = require("@game/ReplicatedStorage/Game/Sim/Diplomacy")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Objectives = require("@game/ReplicatedStorage/Game/Sim/Objectives")
local RulerAI = require("@game/ReplicatedStorage/Game/Sim/RulerAI")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")
local Snapshot = require("@game/ReplicatedStorage/Game/Sim/Snapshot")

local NEVER = 1e9 -- an AI think interval that never comes round: tests call RulerAI.think directly

-- Records every command issued through Commands.executeFor while fn runs (RulerAI looks the
-- function up at call time, so the wrapper sees all of them). Always restores the original.
local function recordCommands(fn: ({ any }) -> ()): { any }
	local calls = {}
	local original = Commands.executeFor
	Commands.executeFor = function(sim, kingdom, by, name, ...)
		local ok, err, result = original(sim, kingdom, by, name, ...)
		table.insert(calls, { kingdomId = kingdom.id, by = by, name = name, ok = ok, err = err, t = sim.time })
		return ok, err, result
	end
	local success, problem = pcall(fn, calls)
	Commands.executeFor = original
	if not success then
		error(problem, 0)
	end
	return calls
end

local function rejected(calls: { any }): { string }
	local out = {}
	for _, c in calls do
		if not c.ok then
			table.insert(out, `{c.kingdomId} {tostring(c.name)}: {tostring(c.err)} at {c.t}`)
		end
	end
	return out
end

local function callsNamed(calls: { any }, name: string): { any }
	local out = {}
	for _, c in calls do
		if c.name == name then
			table.insert(out, c)
		end
	end
	return out
end

-- k1 ("crimson") at the origin with trees and rocks, k2 ("azure") 300 studs east; births off; AI
-- installed but idle. Each kingdom starts with 12 citizens in a keep housing 12. Scores are Crown Points.
local function pair(aiOptions: { [string]: any }?)
	local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
	local k2 = sim:addKingdom({ id = "azure", name = "Rival", x = 300, z = 0 })
	Military.install(sim)
	RulerAI.install(sim, aiOptions or { interval = NEVER })
	return sim, k1, k2
end

-- The four Layout kingdoms crimson, azure, emerald, gold (k1..k4, clockwise: crimson's neighbours are
-- azure and gold, emerald is across the map), no grace period, AI idle so the test drives think()
-- itself; crimson is aggressive (war from day 5) with an army of 6. No objectives installed.
local function ring()
	local sim = Simulation.new({ random = Random.new(3), bounds = Layout.boundsFor(260) })
	Layout.generate(sim)
	Military.install(sim)
	Diplomacy.install(sim, { graceSeconds = 0 })
	RulerAI.install(sim, { interval = NEVER })
	local k1 = sim.kingdoms.crimson
	sim.rulerAI.aggression.crimson = 1
	for i = 1, 6 do
		Military.spawnUnit(sim, k1, "soldier", k1.x + i, k1.z)
	end
	sim.time = 4 * sim.catalog.tuning.dayLength -- start of day 5 (think() reads the day; nothing is stepped)
	return sim, k1
end

local function wars(sim, kingdomId: string): { string }
	local out = {}
	for _, kid in sim.kingdomOrder do
		if sim:atWar(kingdomId, kid) then
			table.insert(out, kid)
		end
	end
	return out
end

describe("Kingdom/RulerAI: who it rules", function()
	it("rules only kingdoms without human rulers, and takes over again when the last one leaves", function()
		local sim, k1 = pair({}) -- default interval: thinks every 6 s
		assert(sim:addRuler("crimson", 101))
		local calls = recordCommands(function()
			sim:advance(30)
		end)
		expect(#calls).toBeGreaterThan(0)
		for _, c in calls do
			expect(c.kingdomId).toBe("azure")
			expect(c.by).toBeNil()
		end
		expect(sim.rulerAI.lastAction.crimson).toBeNil()
		expect(sim:countOf(k1, "house")).toBe(0)

		sim:removeRuler(101)
		calls = recordCommands(function()
			sim:advance(12)
		end)
		local forK1 = F.count(calls, function(c)
			return c.kingdomId == "crimson"
		end)
		expect(forK1).toBeGreaterThan(0)
	end)

	it("with assistHumans it also directs kingdoms that have human rulers", function()
		local sim = pair({ assistHumans = true }) -- default interval: k1 first thinks at 3 s, k2 at 6 s
		assert(sim:addRuler("crimson", 101))
		local calls = recordCommands(function()
			sim:advance(4)
		end)
		expect(#calls).toBeGreaterThan(0)
		expect(calls[1].kingdomId).toBe("crimson")
		expect(calls[1].name).toBe("PlaceBuilding")
	end)

	it("can think before the simulation's first tick (diplomacy installed)", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
		Diplomacy.install(sim)
		RulerAI.install(sim)
		local ok, result = pcall(RulerAI.think, sim, k1)
		expect(ok).toBe(true)
		expect(result).toBe("PlaceBuilding:house")
		expect(sim.rulerAI.aggression.crimson).toBeGreaterThanOrEqual(0.3)
		expect(sim.rulerAI.aggression.crimson).toBeLessThanOrEqual(1)
	end)

	it("never thinks for an eliminated kingdom; installs once", function()
		local sim, k1 = pair()
		Military.eliminate(sim, k1, nil)
		expect(RulerAI.think(sim, k1)).toBeNil()
		expect(function()
			RulerAI.install(sim)
		end).toThrow("already installed")
	end)
end)

describe("Kingdom/RulerAI: decisions", function()
	it(
		"builds more bunks when they are all that hold the army back, so a war can ever be declared (FL-0125)",
		function()
			local sim, k1 = pair()
			sim.time = 3 * sim.catalog.tuning.dayLength -- day 4: military
			sim.rulerAI.aggression.crimson = 1 -- army target: floor(35% of 12 people) = 4
			F.stock(sim, k1):add("wood", 400)
			F.stock(sim, k1):add("stone", 400)
			F.stock(sim, k1):add("food", 200)
			local barracks = assert(sim:placeBuilding(k1, "barracks", 0, -40))
			assert(sim:placeBuilding(k1, "house", -40, 0))
			assert(sim:placeBuilding(k1, "farm", 0, 45))
			sim:_completeInstantly(barracks)
			for i = 1, 3 do
				Military.spawnUnit(sim, k1, "soldier", k1.x + i, k1.z)
			end
			expect(Military.recruitCap(sim, k1)).toBe(4) -- 3 soldiers, a batch of 2 does not fit the 4 bunks
			local calls = recordCommands(function()
				expect(RulerAI.think(sim, k1)).toBe("UpgradeBuilding:barracks")
			end)
			expect(rejected(calls)).toEqual({})
			expect(#callsNamed(calls, "Recruit")).toBe(0)
			-- one upgrade at a time: the barracks is a construction site until it is done
			expect(RulerAI.think(sim, k1)).never.toBe("UpgradeBuilding:barracks")
			barracks.level = barracks.pendingLevel :: number -- the builders finish the upgrade
			barracks.pendingLevel = nil
			expect(Military.recruitCap(sim, k1)).toBe(8)
			calls = recordCommands(function()
				RulerAI.think(sim, k1)
			end)
			expect(#callsNamed(calls, "Recruit")).toBe(1) -- and with room it recruits again
		end
	)

	it("does not upgrade the barracks for bunks it does not need, or cannot pay for", function()
		local sim, k1 = pair()
		sim.time = 3 * sim.catalog.tuning.dayLength
		sim.rulerAI.aggression.crimson = 1
		F.stock(sim, k1):add("wood", 400)
		F.stock(sim, k1):add("stone", 400)
		F.stock(sim, k1):add("food", 200)
		local barracks = assert(sim:placeBuilding(k1, "barracks", 0, -40))
		assert(sim:placeBuilding(k1, "house", -40, 0))
		assert(sim:placeBuilding(k1, "farm", 0, 45))
		sim:_completeInstantly(barracks)
		for i = 1, 3 do
			Military.spawnUnit(sim, k1, "soldier", k1.x + i, k1.z)
		end
		F.stock(sim, k1):take("stone", sim:balance(k1.id, "stone"))
		expect(RulerAI.think(sim, k1)).never.toBe("UpgradeBuilding:barracks") -- no stone: the upgrade is not on offer
		F.stock(sim, k1):add("stone", 400)
		for i = 4, 5 do
			Military.spawnUnit(sim, k1, "soldier", k1.x + i, k1.z)
		end
		-- 5 soldiers of 17 people: the army is at its target (35 %), so no more room is needed
		expect(RulerAI.think(sim, k1)).never.toBe("UpgradeBuilding:barracks")
	end)

	it(
		"rests for a minute after a placement search finds nothing, instead of walking the territory again (FL-0125)",
		function()
			local sim, k1 = pair()
			local searches: { [string]: number } = {}
			local original = RulerAI.findSpot
			RulerAI.findSpot = function(_, _, kind)
				searches[kind] = (searches[kind] or 0) + 1
				return nil, nil
			end
			local ok, problem = pcall(function()
				expect(sim:population(k1)).toBe(k1.popCap) -- wants a house
				RulerAI.think(sim, k1)
				expect(searches.house).toBe(1)
				RulerAI.think(sim, k1)
				RulerAI.think(sim, k1)
				expect(searches.house).toBe(1) -- resting
				sim.time += 59
				RulerAI.think(sim, k1)
				expect(searches.house).toBe(1)
				sim.time += 2
				RulerAI.think(sim, k1)
				expect(searches.house).toBe(2) -- a minute later it looks again (land may have opened up)
				-- another kind is its own search
				expect(sim.rulerAI.noSpotUntil["crimson:house"]).never.toBeNil()
				expect(searches.farm).toBe(2) -- each kind rests on its own
			end)
			RulerAI.findSpot = original
			if not ok then
				error(problem, 0)
			end
		end
	)

	it(
		"never recruits past the army cap (D-055): its target and its batches stop at config Military.maxSoldiers",
		function()
			local sim, k1 = pair()
			sim.catalog.tuning.maxSoldiers = 3
			sim.time = 3 * sim.catalog.tuning.dayLength -- day 4: military
			sim.rulerAI.aggression.crimson = 1
			F.stock(sim, k1):add("wood", 400)
			F.stock(sim, k1):add("stone", 400)
			F.stock(sim, k1):add("food", 400)
			local barracks = assert(sim:placeBuilding(k1, "barracks", 0, -40))
			assert(sim:placeBuilding(k1, "house", -40, 0))
			assert(sim:placeBuilding(k1, "farm", 0, 45))
			sim:_completeInstantly(barracks)
			barracks.level = 3 -- 12 bunks: only the cap holds the army back
			local recruits = 0
			for _ = 1, 8 do
				local calls = recordCommands(function()
					RulerAI.think(sim, k1)
				end)
				expect(rejected(calls)).toEqual({})
				recruits += #callsNamed(calls, "Recruit")
			end
			expect(recruits).toBe(1) -- one batch of two; a second would make 4 > 3
			expect(#barracks.queue + #k1.unitIds <= 3).toBe(true)
		end
	)

	it("builds a House when population reaches the cap, and only one at a time", function()
		local sim, k1 = pair()
		expect(sim:population(k1)).toBe(k1.popCap)
		F.events(sim)
		expect(RulerAI.think(sim, k1)).toBe("PlaceBuilding:house")
		local placed = F.events(sim, "BuildingPlaced")
		expect(#placed).toBe(1)
		expect(placed[1].kind).toBe("house")
		expect(placed[1].kingdomId).toBe("crimson")
		expect(placed[1].by).toBeNil()
		expect(sim:balance(k1.id, "wood")).toBe(60)
		expect(RulerAI.think(sim, k1)).never.toBe("PlaceBuilding:house") -- the site is not finished
		expect(sim:countOf(k1, "house")).toBe(1)
	end)

	it("does not build a House while there is room for two more people", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6, startCitizens = { farmer = 3, builder = 2 } } })
		RulerAI.install(sim, { interval = NEVER })
		for _ = 1, 5 do
			RulerAI.think(sim, k1)
		end
		expect(sim:countOf(k1, "house")).toBe(0)
	end)

	it("does not build a House for soldiers: they sleep in barracks bunks, not beds (D-041)", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6, startCitizens = { farmer = 3, builder = 2 } } })
		Military.install(sim)
		RulerAI.install(sim, { interval = NEVER })
		for i = 1, 7 do -- 5 citizens + 7 soldiers = 12 people in a kingdom with 12 beds
			Military.spawnUnit(sim, k1, "soldier", k1.x + i * 2, k1.z + 20)
		end
		expect(sim:population(k1)).toBe(k1.popCap)
		for _ = 1, 5 do
			RulerAI.think(sim, k1)
		end
		expect(sim:countOf(k1, "house")).toBe(0)
	end)

	it("rings the alarm while enemies are inside and nobody defends, and stops it when they are gone", function()
		local sim, k1, k2 = pair()
		Diplomacy.setRelation(sim, "crimson", "azure", "War")
		local raider = Military.spawnUnit(sim, k2, "soldier", 100, 0)
		raider.order = { kind = "Hold" }
		sim:advance(0.25) -- one former 4 Hz tick
		F.events(sim)
		expect(RulerAI.think(sim, k1)).toBe("SetAlarm")
		expect(k1.alarm).toBe(true)
		expect(F.events(sim, "AlarmChanged")[1].on).toBe(true)
		Diplomacy.setRelation(sim, "crimson", "azure", "Peace")
		sim:advance(0.25) -- one former 4 Hz tick
		expect(RulerAI.think(sim, k1)).toBe("SetAlarm")
		expect(k1.alarm).toBe(false)
		-- with two soldiers at home it leaves the citizens at work
		Diplomacy.setRelation(sim, "crimson", "azure", "War")
		Military.spawnUnit(sim, k1, "soldier", 0, 30)
		Military.spawnUnit(sim, k1, "soldier", 0, -30)
		sim:advance(0.25) -- one former 4 Hz tick
		expect(#k1.threats).toBe(1)
		expect(RulerAI.think(sim, k1)).never.toBe("SetAlarm")
		expect(k1.alarm).toBe(false)
	end)

	it("recruits only what Recruit accepts: a finished barracks, bunks for the batch, the full price", function()
		local sim, k1 = pair()
		sim.time = 3 * sim.catalog.tuning.dayLength -- day 4: military
		sim.rulerAI.aggression.crimson = 1 -- army target: floor(35% of 12 people) = 4
		F.stock(sim, k1):add("wood", 300)
		F.stock(sim, k1):add("stone", 300)
		F.stock(sim, k1):add("food", 200)
		-- house and farm sites in hand, so think() goes on to the military section
		local barracks = assert(sim:placeBuilding(k1, "barracks", 0, -40))
		assert(sim:placeBuilding(k1, "house", -40, 0))
		assert(sim:placeBuilding(k1, "farm", 0, 45))
		local function recruits(): number
			local calls = recordCommands(function()
				RulerAI.think(sim, k1)
			end)
			expect(rejected(calls)).toEqual({})
			return #callsNamed(calls, "Recruit")
		end
		expect(recruits()).toBe(0) -- the barracks is still a construction site
		sim:_completeInstantly(barracks)
		-- every bed is taken and the house is still a site: soldiers sleep in the 4 bunks (D-041)
		expect(#k1.citizenIds).toBe(k1.popCap)
		expect(recruits()).toBe(1)
		expect(recruits()).toBe(1) -- 2 queued < 4, and 2 + 2 fits in the 4 bunks
		expect(#barracks.queue).toBe(4)
		expect(recruits()).toBe(0) -- queued soldiers count toward the army target (and the bunks)
		table.remove(barracks.queue)
		expect(recruits()).toBe(0) -- 3 < 4, but one free bunk cannot take a batch of two
		table.clear(barracks.queue)
		local food = sim:balance(k1.id, "food")
		F.stock(sim, k1):take("food", food)
		expect(recruits()).toBe(0) -- cannot pay for two
		F.stock(sim, k1):add("food", food)
		expect(recruits()).toBe(1) -- and with the food back it recruits again
	end)

	it("accepts peace when behind on score, but never an expired proposal", function()
		local sim, k1, k2 = pair()
		Diplomacy.install(sim, { graceSeconds = 0 })
		assert(sim:addRuler("azure", 201))
		Diplomacy.setRelation(sim, "crimson", "azure", "War")
		Military.spawnUnit(sim, k1, "soldier", 0, 30) -- an army, so k1 does not propose itself
		assert(Commands.execute(sim, 201, "ProposePeace", "crimson"))
		sim:addCrownPoints("crimson", 10, "test")
		expect(Snapshot.score(sim, k1)).toBeGreaterThan(Snapshot.score(sim, k2))
		expect(RulerAI.think(sim, k1)).never.toBe("AcceptPeace") -- ahead: keeps fighting
		expect(sim:atWar("crimson", "azure")).toBe(true)

		sim:advance(sim.diplomacy.proposalSeconds + 1)
		sim:addCrownPoints("azure", 500, "test") -- now k1 is behind, but the proposal has expired
		local calls = recordCommands(function()
			RulerAI.think(sim, k1)
		end)
		expect(callsNamed(calls, "AcceptPeace")).toEqual({})
		expect(rejected(calls)).toEqual({})

		assert(Commands.execute(sim, 201, "ProposePeace", "crimson"))
		expect(RulerAI.think(sim, k1)).toBe("AcceptPeace")
		expect(sim:atWar("crimson", "azure")).toBe(false)
	end)

	it("proposes peace at most once per proposalSeconds while it has no army", function()
		local sim = pair({})
		Diplomacy.install(sim, { graceSeconds = 0 })
		assert(sim:addRuler("azure", 201)) -- a human who never answers
		Diplomacy.setRelation(sim, "crimson", "azure", "War")
		local proposals = {}
		for _ = 1, 30 do
			sim:advance(10)
			for _, e in F.events(sim, "PeaceProposed") do
				expect(e.kingdomId).toBe("crimson")
				expect(e.targetId).toBe("azure")
				table.insert(proposals, e.t)
			end
		end
		expect(#proposals).toBeGreaterThanOrEqual(3)
		for i = 2, #proposals do
			expect(proposals[i] - proposals[i - 1]).toBeGreaterThan(sim.diplomacy.proposalSeconds)
		end
	end)
end)

describe("Kingdom/RulerAI: logistics and objectives", function()
	local function nearestDistance(sim, x: number, z: number, resource: string): number
		local best = math.huge
		for _, nid in sim.nodeOrder do
			local node = sim.nodes[nid]
			if node.resource == resource then
				best = math.min(best, math.sqrt((node.x - x) ^ 2 + (node.z - z) ^ 2))
			end
		end
		return best
	end

	it("from day 2 builds a lumber camp by the forest, then a quarry by the rocks, one of each", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6, startCitizens = { farmer = 3, woodcutter = 2 } } })
		RulerAI.install(sim, { interval = NEVER })
		F.stock(sim, k1):add("wood", 200)
		expect(RulerAI.think(sim, k1)).toBeNil() -- day 1: nothing to do yet
		sim.time = sim.catalog.tuning.dayLength -- day 2
		F.events(sim)
		expect(RulerAI.think(sim, k1)).toBe("PlaceBuilding:lumbercamp")
		local camp = sim.buildings[F.events(sim, "BuildingPlaced")[1].buildingId]
		local keep = sim.buildings[k1.keepId]
		local toKeep = math.sqrt((camp.x - keep.x) ^ 2 + (camp.z - keep.z) ^ 2)
		expect(nearestDistance(sim, camp.x, camp.z, "wood")).toBeLessThan(toKeep / 2)
		expect(RulerAI.think(sim, k1)).never.toBe("PlaceBuilding:quarry") -- one site at a time
		sim:_completeInstantly(camp)
		expect(RulerAI.think(sim, k1)).toBe("PlaceBuilding:quarry")
		local quarry = sim.buildings[F.events(sim, "BuildingPlaced")[1].buildingId]
		expect(quarry.kind).toBe("quarry")
		local quarryToKeep = math.sqrt((quarry.x - keep.x) ^ 2 + (quarry.z - keep.z) ^ 2)
		expect(nearestDistance(sim, quarry.x, quarry.z, "stone")).toBeLessThan(quarryToKeep / 2)
		sim:_completeInstantly(quarry)
		for _ = 1, 3 do
			RulerAI.think(sim, k1)
		end
		expect(sim:countOf(k1, "lumbercamp")).toBe(1)
		expect(sim:countOf(k1, "quarry")).toBe(1)
	end)

	it("marches a standing army of 3+ at peace on the nearest capture point it does not own, once", function()
		local sim, k1 = pair()
		Objectives.install(sim, { { id = "near", x = 0, z = 100 }, { id = "far", x = 0, z = -200 } })
		local soldiers = {}
		for i = 1, 2 do
			table.insert(soldiers, Military.spawnUnit(sim, k1, "soldier", i * 3, 20))
		end
		local function orders(): { any }
			local calls = recordCommands(function()
				RulerAI.think(sim, k1)
			end)
			expect(rejected(calls)).toEqual({})
			return callsNamed(calls, "ArmyOrder")
		end
		expect(orders()).toEqual({}) -- two soldiers are not an army yet
		table.insert(soldiers, Military.spawnUnit(sim, k1, "soldier", 9, 20))
		F.events(sim)
		expect(RulerAI.think(sim, k1)).toBe("ArmyOrder:Objective")
		for _, u in soldiers do
			expect(u.order).toEqual({ kind = "Move", x = 0, z = 100 })
		end
		expect(F.events(sim, "ArmyOrdered")[1].by).toBeNil()
		expect(orders()).toEqual({}) -- already on the way: not issued again
		-- once it owns the near point it moves on to the next one
		sim.objectives.list[1].owner = "crimson"
		expect(#orders()).toBe(1)
		expect(soldiers[1].order).toEqual({ kind = "Move", x = 0, z = -200 })
		-- at war the army is not sent off to capture points
		sim.objectives.list[1].owner = nil
		Diplomacy.setRelation(sim, "crimson", "azure", "War")
		expect(orders()).toEqual({})
		expect(soldiers[1].order).toEqual({ kind = "Move", x = 0, z = -200 })
	end)
end)

describe("Kingdom/RulerAI: war", function()
	it("declares war only on a neighbour (index +-1 around the ring) while one lives", function()
		local sim, k1 = ring()
		local k2, k3, k4 = sim.kingdoms.azure, sim.kingdoms.emerald, sim.kingdoms.gold
		sim:addCrownPoints("azure", 300, "test")
		sim:addCrownPoints("gold", 300, "test") -- emerald, across the map, is by far the weakest
		expect(Snapshot.score(sim, k3)).toBeLessThan(Snapshot.score(sim, k2))
		F.events(sim)
		expect(RulerAI.think(sim, k1)).toBe("DeclareWar")
		local declared = F.events(sim, "WarDeclared")
		expect(#declared).toBe(1)
		expect(declared[1].kingdomId).toBe("crimson")
		expect(declared[1].targetId).toBe("azure") -- tied with gold; the first in order wins
		expect(declared[1].by).toBeNil()

		-- with both neighbours fallen, anyone left is fair game
		Military.eliminate(sim, k2, nil)
		Military.eliminate(sim, k4, nil)
		expect(wars(sim, "crimson")).toEqual({})
		expect(RulerAI.think(sim, k1)).toBe("DeclareWar")
		expect(wars(sim, "crimson")).toEqual({ "emerald" })
	end)

	it("leaves a kingdom that already fights two wars alone", function()
		local sim, k1 = ring()
		Diplomacy.setRelation(sim, "azure", "emerald", "War")
		Diplomacy.setRelation(sim, "azure", "gold", "War")
		sim:addCrownPoints("gold", 300, "test") -- azure would be the weaker neighbour
		expect(RulerAI.think(sim, k1)).toBe("DeclareWar")
		expect(wars(sim, "crimson")).toEqual({ "gold" })
	end)

	it(
		"does not declare war before its war day, without an army, in the grace period or in a peace cooldown",
		function()
			local sim, k1 = ring()
			local day = sim.catalog.tuning.dayLength
			local function attempts()
				local calls = recordCommands(function()
					RulerAI.think(sim, k1)
				end)
				expect(rejected(calls)).toEqual({})
				return #callsNamed(calls, "DeclareWar")
			end
			sim.time = 3 * day -- day 4: too early even for the most aggressive AI
			expect(attempts()).toBe(0)
			sim.time = 4 * day
			local saved = table.clone(k1.unitIds)
			table.remove(k1.unitIds, 1) -- five soldiers are not enough
			expect(attempts()).toBe(0)
			k1.unitIds = saved
			sim.diplomacy.graceSeconds = 10 * day -- a long grace period (Match option)
			expect(attempts()).toBe(0)
			sim.diplomacy.graceSeconds = 0
			-- peace was just made with azure: the AI turns to its other neighbour instead of being refused
			sim.diplomacy.peaceAt[sim:relationKey("crimson", "azure")] = sim.time - 1
			sim:addCrownPoints("gold", 300, "test") -- azure would be the weaker neighbour
			expect(attempts()).toBe(1)
			expect(wars(sim, "crimson")).toEqual({ "gold" })
		end
	)
end)

describe("Kingdom/RulerAI: findSpot", function()
	it("returns only placeable spots inside the territory, then nil once the territory is full", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
		RulerAI.install(sim, { interval = NEVER })
		F.stock(sim, k1):add("wood", 50000)
		local placed = 0
		local exhausted = false
		for _ = 1, 400 do
			local x, z = RulerAI.findSpot(sim, k1, "house")
			if x == nil then
				expect(z).toBeNil()
				exhausted = true
				break
			end
			expect((sim:canPlace(k1, "house", x, z))).toBe(true)
			expect(math.sqrt((x - k1.x) ^ 2 + (z - k1.z) ^ 2) + 6).toBeLessThanOrEqual(k1.territory)
			assert(sim:placeBuilding(k1, "house", x, z))
			placed += 1
		end
		expect(exhausted).toBe(true)
		expect(placed).toBeGreaterThan(20)
		F.assertInvariants(sim)
	end)

	it("returns nil for an unknown kind, an unaffordable building or a kingdom without a keep", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
		RulerAI.install(sim, { interval = NEVER })
		expect(RulerAI.findSpot(sim, k1, "castle")).toBeNil()
		expect(RulerAI.findSpot(sim, k1, "barracks")).toBeNil() -- wood 100 < 120
		expect(RulerAI.findSpot(sim, k1, "house")).never.toBeNil()
		Military.eliminate(sim, k1, nil)
		expect(RulerAI.findSpot(sim, k1, "house")).toBeNil()
	end)
end)

describe("Kingdom/RulerAI: findSpot on the world layout (G13.9 v0.4-g9j)", function()
	-- the no-build areas, and soldiers and rulers standing about, are placement rules like any other: the AI
	-- finds its spots with canPlace, so it keeps off them without knowing about them
	it("keeps off crop fields, plot roads and spawn pads, and off people standing about", function()
		local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
		local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
		local sim = Simulation.new({ random = Random.new(9), catalog = Catalog.default(), bounds = Layout.bounds() })
		Layout.generate(sim, { kingdoms = 2, populate = false })
		Military.install(sim)
		RulerAI.install(sim, { interval = NEVER })
		local k1, k2 = sim.kingdoms.crimson, sim.kingdoms.azure
		sim:deposit("crimson", "wood", 90000, "spec:ai:wood", "spec")
		expect(#sim.noBuild > 0).toBe(true)
		-- a ruler of azure and a soldier of azure standing in crimson's land
		local rx, rz = RulerAI.findSpot(sim, k1, "house")
		sim:setRulerPosition(777, rx, rz)
		local ux, uz = RulerAI.findSpot(sim, k1, "house")
		Military.spawnUnit(sim, k2, "soldier", ux, uz)
		local placed = 0
		for _ = 1, 60 do
			local x, z = RulerAI.findSpot(sim, k1, "house")
			if x == nil then
				break
			end
			local b = assert(sim:placeBuilding(k1, "house", x, z))
			placed += 1
			for _, area in sim.noBuild do
				expect(Footprint.overlaps(b.shape, area, 0)).toBe(false)
			end
			expect(Footprint.overlapsCircle(b.shape, rx, rz, sim.catalog.tuning.rulerClearance, 0)).toBe(false)
			expect(Footprint.overlapsCircle(b.shape, ux, uz, 1.5, 0)).toBe(false)
		end
		expect(placed).toBeGreaterThan(10) -- the plot still has room for a town
		F.assertInvariants(sim)
	end)
end)

-- One AI-only match world, run once and shared by the tests below (10 simulated minutes).
local EVENT_OF = {
	PlaceBuilding = "BuildingPlaced",
	UpgradeBuilding = "UpgradeStarted",
	SetAlarm = "AlarmChanged",
	Recruit = "RecruitQueued",
	DeclareWar = "WarDeclared",
	ProposePeace = "PeaceProposed",
	AcceptPeace = "PeaceMade",
	ArmyOrder = "ArmyOrdered",
}
local worldRun = nil
local function aiWorld()
	if worldRun then
		return worldRun
	end
	local sim = Simulation.new({ random = Random.new(1), bounds = Layout.boundsFor(260) })
	Layout.generate(sim)
	Military.install(sim)
	Diplomacy.install(sim)
	local objectives = {}
	for _, o in Layout.OBJECTIVES do
		table.insert(objectives, table.clone(o))
	end
	Objectives.install(sim, objectives) -- as Match does
	RulerAI.install(sim)
	local run = { sim = sim, invariantErrors = {}, unconfirmed = {}, thinks = 0, results = 0, byName = {} }
	local start = {}
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		start[kid] = { citizens = #k.citizenIds, buildings = #k.buildingIds }
	end
	run.start = start
	local originalThink = RulerAI.think
	local calls
	-- every think() that reports a command must have issued exactly that command, successfully,
	-- and the simulation must show it (its event, or for SetJobQuota the new quota)
	RulerAI.think = function(s, kingdom)
		local eventsBefore = #s._events
		local callsBefore = #calls
		local result = originalThink(s, kingdom)
		run.thinks += 1
		if result then
			run.results += 1
			local name, detail = string.match(result, "^([^:]+):?(.*)$")
			run.byName[result] = (run.byName[result] or 0) + 1
			local last = calls[#calls]
			local confirmed = #calls > callsBefore and last.name == name and last.ok and last.kingdomId == kingdom.id
			if confirmed and EVENT_OF[name] then
				confirmed = false
				for i = eventsBefore + 1, #s._events do
					local e = s._events[i]
					if e.name == EVENT_OF[name] and e.kingdomId == kingdom.id then
						confirmed = detail == "" or name ~= "PlaceBuilding" or e.kind == detail
					end
				end
			elseif confirmed and name == "SetJobQuota" then
				confirmed = kingdom.quotas.farmer > 0
			end
			if not confirmed then
				table.insert(run.unconfirmed, `{kingdom.id} {result} at {s.time}`)
			end
		end
		return result
	end
	local ok, problem = pcall(function()
		calls = recordCommands(function(list)
			calls = list
			for _ = 1, 60 do
				sim:advance(10)
				local fine, why = pcall(F.assertInvariants, sim)
				if not fine then
					table.insert(run.invariantErrors, `t={sim.time}: {why}`)
				end
				sim:drainEvents()
			end
		end)
	end)
	RulerAI.think = originalThink
	if not ok then
		error(problem, 0)
	end
	run.calls = calls
	worldRun = run
	return run
end

describe("Kingdom/RulerAI: an AI-only match world over ten minutes", function()
	it("grows every kingdom (more citizens, more buildings) with the invariants holding every 10 s", function()
		local run = aiWorld()
		expect(run.invariantErrors).toEqual({})
		for _, kid in run.sim.kingdomOrder do
			local k = run.sim.kingdoms[kid]
			expect(k.alive).toBe(true)
			expect(#k.citizenIds).toBeGreaterThan(run.start[kid].citizens)
			expect(#k.buildingIds).toBeGreaterThan(run.start[kid].buildings + 4)
			expect(k.popCap).toBeGreaterThan(12)
		end
	end)

	it("never issues a command the simulation rejects, and every reported command really happened", function()
		local run = aiWorld()
		expect(#run.calls).toBeGreaterThan(20)
		expect(run.results).toBeGreaterThan(20)
		expect(rejected(run.calls)).toEqual({})
		expect(run.unconfirmed).toEqual({})
		for _, c in run.calls do
			expect(c.by).toBeNil()
		end
	end)

	it("is deterministic: the same seed gives the same AI decisions", function()
		local function short()
			local sim = Simulation.new({ random = Random.new(9), bounds = Layout.boundsFor(260) })
			Layout.generate(sim)
			Military.install(sim)
			Diplomacy.install(sim)
			RulerAI.install(sim)
			local names = {}
			for _ = 1, 18 do
				sim:advance(10)
				for _, e in sim:drainEvents() do
					if e.name == "BuildingPlaced" or e.name == "UpgradeStarted" or e.name == "RecruitQueued" then
						table.insert(names, `{e.t} {e.kingdomId} {e.name} {e.kind or e.unit or ""}`)
					end
				end
			end
			return names, Snapshot.overview(sim, 1)
		end
		local namesA, overviewA = short()
		local namesB, overviewB = short()
		expect(#namesA).toBeGreaterThan(4)
		expect(namesA).toEqual(namesB)
		expect(overviewA).toEqual(overviewB)
	end)
end)
