local T = require("../../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Commands = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Commands")
local Diplomacy = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Diplomacy")
local Layout = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Layout")
local Military = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Military")
local RulerAI = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/RulerAI")
local Simulation = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Simulation")
local Snapshot = require("@game/ReplicatedStorage/Forge/Gameplay/Kingdom/Snapshot")

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

-- k1 at the origin (with trees and rocks) and k2 300 studs east; births off; AI installed but idle.
local function pair(aiOptions: { [string]: any }?)
	local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
	local k2 = sim:addKingdom({ id = "k2", name = "Rival", x = 300, z = 0 })
	Military.install(sim)
	RulerAI.install(sim, aiOptions or { interval = NEVER })
	return sim, k1, k2
end

-- The four Layout kingdoms (k1..k4 clockwise, so k1's neighbours are k2 and k4), no grace period,
-- AI idle so the test drives think() itself; k1 is aggressive (war from day 5) with an army of 6.
local function ring()
	local sim = Simulation.new({ random = Random.new(3), bounds = Layout.boundsFor(260) })
	Layout.generate(sim)
	Military.install(sim)
	Diplomacy.install(sim, { graceSeconds = 0 })
	RulerAI.install(sim, { interval = NEVER })
	local k1 = sim.kingdoms.k1
	sim.rulerAI.aggression.k1 = 1
	for i = 1, 6 do
		Military.spawnUnit(sim, k1, "Militia", k1.x + i, k1.z)
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
		assert(sim:addRuler("k1", 101))
		local calls = recordCommands(function()
			sim:advance(30)
		end)
		expect(#calls).toBeGreaterThan(0)
		for _, c in calls do
			expect(c.kingdomId).toBe("k2")
			expect(c.by).toBeNil()
		end
		expect(sim.rulerAI.lastAction.k1).toBeNil()
		expect(sim:countOf(k1, "House")).toBe(0)

		sim:removeRuler(101)
		calls = recordCommands(function()
			sim:advance(12)
		end)
		local forK1 = F.count(calls, function(c)
			return c.kingdomId == "k1"
		end)
		expect(forK1).toBeGreaterThan(0)
	end)

	it("with assistHumans it also directs kingdoms that have human rulers", function()
		local sim = pair({ assistHumans = true }) -- default interval: k1 first thinks at 3 s, k2 at 6 s
		assert(sim:addRuler("k1", 101))
		local calls = recordCommands(function()
			sim:advance(4)
		end)
		expect(#calls).toBeGreaterThan(0)
		expect(calls[1].kingdomId).toBe("k1")
		expect(calls[1].name).toBe("PlaceBuilding")
	end)

	it("can think before the simulation's first tick (diplomacy installed)", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
		Diplomacy.install(sim)
		RulerAI.install(sim)
		local ok, result = pcall(RulerAI.think, sim, k1)
		expect(ok).toBe(true)
		expect(result).toBe("PlaceBuilding:House")
		expect(sim.rulerAI.aggression.k1).toBeGreaterThanOrEqual(0.3)
		expect(sim.rulerAI.aggression.k1).toBeLessThanOrEqual(1)
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
	it("builds a House when population reaches the cap, and only one at a time", function()
		local sim, k1 = pair()
		expect(sim:population(k1)).toBe(k1.popCap)
		F.events(sim)
		expect(RulerAI.think(sim, k1)).toBe("PlaceBuilding:House")
		local placed = F.events(sim, "BuildingPlaced")
		expect(#placed).toBe(1)
		expect(placed[1].kind).toBe("House")
		expect(placed[1].kingdomId).toBe("k1")
		expect(placed[1].by).toBeNil()
		expect(k1.stock:get("wood")).toBe(60)
		expect(RulerAI.think(sim, k1)).never.toBe("PlaceBuilding:House") -- the site is not finished
		expect(sim:countOf(k1, "House")).toBe(1)
	end)

	it("does not build a House while there is room for two more people", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6, startCitizens = { Farmer = 3, Builder = 2 } } })
		RulerAI.install(sim, { interval = NEVER })
		for _ = 1, 5 do
			RulerAI.think(sim, k1)
		end
		expect(sim:countOf(k1, "House")).toBe(0)
	end)

	it("rings the alarm while enemies are inside and nobody defends, and stops it when they are gone", function()
		local sim, k1, k2 = pair()
		Diplomacy.setRelation(sim, "k1", "k2", "War")
		local raider = Military.spawnUnit(sim, k2, "Militia", 100, 0)
		raider.order = { kind = "Hold" }
		sim:step()
		F.events(sim)
		expect(RulerAI.think(sim, k1)).toBe("SetAlarm")
		expect(k1.alarm).toBe(true)
		expect(F.events(sim, "AlarmChanged")[1].on).toBe(true)
		Diplomacy.setRelation(sim, "k1", "k2", "Peace")
		sim:step()
		expect(RulerAI.think(sim, k1)).toBe("SetAlarm")
		expect(k1.alarm).toBe(false)
		-- with two soldiers at home it leaves the citizens at work
		Diplomacy.setRelation(sim, "k1", "k2", "War")
		Military.spawnUnit(sim, k1, "Militia", 0, 30)
		Military.spawnUnit(sim, k1, "Militia", 0, -30)
		sim:step()
		expect(#k1.threats).toBe(1)
		expect(RulerAI.think(sim, k1)).never.toBe("SetAlarm")
		expect(k1.alarm).toBe(false)
	end)

	it("recruits only what Recruit accepts: a finished barracks, room for the batch, the full price", function()
		local sim, k1 = pair()
		sim.time = 3 * sim.catalog.tuning.dayLength -- day 4: military
		sim.rulerAI.aggression.k1 = 1 -- army target: floor(35% of 10 people) = 3
		k1.stock:add("wood", 300)
		k1.stock:add("stone", 300)
		k1.stock:add("food", 200)
		-- house and farm sites in hand, so think() goes on to the military section
		local barracks = assert(sim:placeBuilding(k1, "Barracks", 0, -40))
		local house = assert(sim:placeBuilding(k1, "House", -40, 0))
		assert(sim:placeBuilding(k1, "Farm", 0, 45))
		local function recruits(): number
			local calls = recordCommands(function()
				RulerAI.think(sim, k1)
			end)
			expect(rejected(calls)).toEqual({})
			return #callsNamed(calls, "Recruit")
		end
		expect(recruits()).toBe(0) -- the barracks is still a construction site
		sim:_completeInstantly(barracks)
		expect(sim:population(k1)).toBe(k1.popCap)
		expect(recruits()).toBe(0) -- no room for a batch of two
		sim:_completeInstantly(house)
		sim:_recompute(k1)
		expect(k1.popCap).toBe(14)
		expect(recruits()).toBe(1)
		expect(recruits()).toBe(1) -- 2 queued < 3, and 10 + 2 + 2 fits in 14
		expect(#barracks.queue).toBe(4)
		expect(recruits()).toBe(0) -- queued soldiers count toward the army target (and the cap)
		table.clear(barracks.queue)
		local food = k1.stock:get("food")
		k1.stock:take("food", food)
		expect(recruits()).toBe(0) -- cannot pay for two
		k1.stock:add("food", food)
		expect(recruits()).toBe(1) -- and with the food back it recruits again
	end)

	it("accepts peace when behind on score, but never an expired proposal", function()
		local sim, k1, k2 = pair()
		Diplomacy.install(sim, { graceSeconds = 0 })
		assert(sim:addRuler("k2", 201))
		Diplomacy.setRelation(sim, "k1", "k2", "War")
		Military.spawnUnit(sim, k1, "Militia", 0, 30) -- an army, so k1 does not propose itself
		assert(Commands.execute(sim, 201, "ProposePeace", "k1"))
		k1.stats.conquered = 0
		expect(Snapshot.score(sim, k1)).toBeGreaterThan(Snapshot.score(sim, k2))
		expect(RulerAI.think(sim, k1)).never.toBe("AcceptPeace") -- ahead: keeps fighting
		expect(sim:atWar("k1", "k2")).toBe(true)

		sim:advance(sim.diplomacy.proposalSeconds + 1)
		k2.stats.conquered = 5 -- now k1 is behind, but the proposal has expired
		local calls = recordCommands(function()
			RulerAI.think(sim, k1)
		end)
		expect(callsNamed(calls, "AcceptPeace")).toEqual({})
		expect(rejected(calls)).toEqual({})

		assert(Commands.execute(sim, 201, "ProposePeace", "k1"))
		expect(RulerAI.think(sim, k1)).toBe("AcceptPeace")
		expect(sim:atWar("k1", "k2")).toBe(false)
	end)

	it("proposes peace at most once per proposalSeconds while it has no army", function()
		local sim = pair({})
		Diplomacy.install(sim, { graceSeconds = 0 })
		assert(sim:addRuler("k2", 201)) -- a human who never answers
		Diplomacy.setRelation(sim, "k1", "k2", "War")
		local proposals = {}
		for _ = 1, 30 do
			sim:advance(10)
			for _, e in F.events(sim, "PeaceProposed") do
				expect(e.kingdomId).toBe("k1")
				expect(e.targetId).toBe("k2")
				table.insert(proposals, e.t)
			end
		end
		expect(#proposals).toBeGreaterThanOrEqual(3)
		for i = 2, #proposals do
			expect(proposals[i] - proposals[i - 1]).toBeGreaterThan(sim.diplomacy.proposalSeconds)
		end
	end)
end)

describe("Kingdom/RulerAI: war", function()
	it("declares war only on a neighbour (index +-1 around the ring) while one lives", function()
		local sim, k1 = ring()
		local k2, k3, k4 = sim.kingdoms.k2, sim.kingdoms.k3, sim.kingdoms.k4
		k2.stats.conquered, k4.stats.conquered = 1, 1 -- k3, across the map, is by far the weakest
		expect(Snapshot.score(sim, k3)).toBeLessThan(Snapshot.score(sim, k2))
		F.events(sim)
		expect(RulerAI.think(sim, k1)).toBe("DeclareWar")
		local declared = F.events(sim, "WarDeclared")
		expect(#declared).toBe(1)
		expect(declared[1].kingdomId).toBe("k1")
		expect(declared[1].targetId).toBe("k2") -- tied with k4; the first in order wins
		expect(declared[1].by).toBeNil()

		-- with both neighbours fallen, anyone left is fair game
		Military.eliminate(sim, k2, nil)
		Military.eliminate(sim, k4, nil)
		expect(wars(sim, "k1")).toEqual({})
		expect(RulerAI.think(sim, k1)).toBe("DeclareWar")
		expect(wars(sim, "k1")).toEqual({ "k3" })
	end)

	it("leaves a kingdom that already fights two wars alone", function()
		local sim, k1 = ring()
		Diplomacy.setRelation(sim, "k2", "k3", "War")
		Diplomacy.setRelation(sim, "k2", "k4", "War")
		sim.kingdoms.k4.stats.conquered = 1 -- k2 would be the weaker neighbour
		expect(RulerAI.think(sim, k1)).toBe("DeclareWar")
		expect(wars(sim, "k1")).toEqual({ "k4" })
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
			-- peace was just made with k2: the AI turns to its other neighbour instead of being refused
			sim.diplomacy.peaceAt[sim:relationKey("k1", "k2")] = sim.time - 1
			sim.kingdoms.k4.stats.conquered = 1 -- k2 would be the weaker neighbour
			expect(attempts()).toBe(1)
			expect(wars(sim, "k1")).toEqual({ "k4" })
		end
	)
end)

describe("Kingdom/RulerAI: findSpot", function()
	it("returns only placeable spots inside the territory, then nil once the territory is full", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
		RulerAI.install(sim, { interval = NEVER })
		k1.stock:setCapacity(100000)
		k1.stock:add("wood", 50000)
		local placed = 0
		local exhausted = false
		for _ = 1, 400 do
			local x, z = RulerAI.findSpot(sim, k1, "House")
			if x == nil then
				expect(z).toBeNil()
				exhausted = true
				break
			end
			expect((sim:canPlace(k1, "House", x, z))).toBe(true)
			expect(math.sqrt((x - k1.x) ^ 2 + (z - k1.z) ^ 2) + 6).toBeLessThanOrEqual(k1.territory)
			assert(sim:placeBuilding(k1, "House", x, z))
			placed += 1
		end
		expect(exhausted).toBe(true)
		expect(placed).toBeGreaterThan(20)
		F.assertInvariants(sim)
	end)

	it("returns nil for an unknown kind, an unaffordable building or a kingdom without a keep", function()
		local sim, k1 = F.kingdom({ tuning = { birthInterval = 1e6 } })
		RulerAI.install(sim, { interval = NEVER })
		expect(RulerAI.findSpot(sim, k1, "Castle")).toBeNil()
		expect(RulerAI.findSpot(sim, k1, "Barracks")).toBeNil() -- wood 100 < 120
		expect(RulerAI.findSpot(sim, k1, "House")).never.toBeNil()
		Military.eliminate(sim, k1, nil)
		expect(RulerAI.findSpot(sim, k1, "House")).toBeNil()
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
	RulerAI.install(sim)
	local run = { sim = sim, invariantErrors = {}, unconfirmed = {}, thinks = 0, results = 0 }
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
				confirmed = kingdom.quotas.Farmer > 0
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
			expect(k.popCap).toBeGreaterThan(10)
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
