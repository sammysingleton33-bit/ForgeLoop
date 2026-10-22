--[[
	Sim/RulerAI fortifying (FL-0126 part 2, slice 4): a governor with aggression >= 0.5, a keep at level 2 and its two watchtowers
	walls the approach to its keep: an arc of up to 11 pieces about 132 studs out, laid tangent and centred on the nearest other
	keep, with the gate in the middle of the arc. (The yard fills the ground out to about 120 studs, so a ring nearer the keep
	finds almost no room in a real match.) Specs drive think() directly and finish every site at once.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local RulerAI = require("@game/ReplicatedStorage/Game/Sim/RulerAI")
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")

local NEVER = 1e9
local deposits = 0

-- crimson at the origin with a level-2 keep and its two towers (inside the arc), azure 400 studs east; plenty of
-- wood and stone; AI idle (the test calls think()); day 5.
local function world(aggression: number)
	local sim, k = F.kingdom({ nodes = false, tuning = { birthInterval = 1e6, startCitizens = {} } })
	local rival = sim:addKingdom({ id = "azure", name = "Rival", x = 400, z = 0, populate = false })
	Military.install(sim)
	RulerAI.install(sim, { interval = NEVER })
	sim.rulerAI.aggression.crimson = aggression
	sim.rulerAI.aggression.azure = 0
	local keep = sim.buildings[k.keepId]
	keep.level = 2
	keep.pendingLevel = nil
	sim:_recompute(k)
	for i, spot in { { 36, -36 }, { -36, 36 } } do
		local b = sim:_createBuilding(k, "watchtower", spot[1], spot[2])
		sim:_completeInstantly(b)
		b.level = 1
		b.maxHp = sim.catalog.buildings.watchtower.levels[1].hp
		b.hp = b.maxHp
		_ = i
	end
	sim:_recompute(k)
	for _, res in { "food", "wood", "stone", "gold" } do
		deposits += 1
		sim.treasury:deposit(k.id, res, 5000, `spec:fortify:{deposits}`, "test")
	end
	sim.time = 4 * sim.catalog.tuning.dayLength
	return sim, k, rival
end

local function finishSites(sim: any, k: any)
	for _, bid in table.clone(k.buildingIds) do
		local b = sim.buildings[bid]
		if b.pendingLevel ~= nil and b.kind ~= "keep" then
			sim:_completeInstantly(b)
		end
	end
	sim:_recompute(k)
end

-- thinks `times` times, finishing every site after each, and returns what was issued
local function run(sim: any, k: any, times: number): { string }
	local issued = {}
	for _ = 1, times do
		local what = RulerAI.think(sim, k)
		if what then
			table.insert(issued, what)
		end
		finishSites(sim, k)
		sim.time += 7 -- past the no-spot rest and the think interval
	end
	return issued
end

local function piecesOf(sim: any, k: any, kind: string): { any }
	local out = {}
	for _, bid in k.buildingIds do
		local b = sim.buildings[bid]
		if b.kind == kind then
			table.insert(out, b)
		end
	end
	return out
end

describe("Sim/RulerAI: fortifying (FL-0126)", function()
	it(
		"walls the approach: pieces about 132 studs out, laid along the circle, on the side of the nearest keep",
		function()
			local sim, k = world(1)
			run(sim, k, 120)
			local walls = piecesOf(sim, k, "wall")
			local gates = piecesOf(sim, k, "gate")
			expect(#walls + #gates <= 13).toBe(true) -- D-047: up to 12 walls and the gate
			expect(#walls >= 6).toBe(true)
			local keep = sim.buildings[k.keepId]
			for _, b in walls do
				local r = math.sqrt((b.x - keep.x) ^ 2 + (b.z - keep.z) ^ 2)
				expect(math.abs(r - 132) < 1e-6).toBe(true) -- open ground: every slot fits at the arc's own radius
				expect(b.x > keep.x).toBe(true) -- the rival is due east: the arc is on that side
				-- tangent: the piece's long axis is at right angles to the radius
				local ux, uz = math.cos(b.yaw), -math.sin(b.yaw) -- the long axis, as Footprint.rect turns it
				local rx, rz = (b.x - keep.x) / r, (b.z - keep.z) / r
				expect(math.abs(ux * rx + uz * rz) < 1e-6).toBe(true)
			end
			expect(sim:countOf(k, "wall") <= sim.catalog.buildings.wall.maxCount).toBe(true)
		end
	)

	it("puts the one gate in the middle of the arc, facing the nearest other keep", function()
		local sim, k, rival = world(1)
		run(sim, k, 120)
		local gates = piecesOf(sim, k, "gate")
		expect(#gates).toBe(1)
		local gate = gates[1]
		local keep = sim.buildings[k.keepId]
		local gr = math.sqrt((gate.x - keep.x) ^ 2 + (gate.z - keep.z) ^ 2)
		expect(math.abs(gr - 132) < 1e-6).toBe(true) -- made in place: a wall piece of the arc
		expect(math.abs(gate.z - keep.z) < 1e-3).toBe(true) -- the middle slot: on the line to the rival
		-- the gate is nearer to the rival than any wall piece
		local dg = (gate.x - rival.x) ^ 2 + (gate.z - rival.z) ^ 2
		for _, w in piecesOf(sim, k, "wall") do
			expect(dg <= (w.x - rival.x) ^ 2 + (w.z - rival.z) ^ 2 + 1e-3).toBe(true)
		end
		-- the gate's slot is not built over again: no wall stands within a piece's length of it
		for _, w in piecesOf(sim, k, "wall") do
			expect((w.x - gate.x) ^ 2 + (w.z - gate.z) ^ 2 > 20 ^ 2).toBe(true)
		end
		expect(#piecesOf(sim, k, "wall") + #gates <= 13).toBe(true)
	end)

	it("keeps the gate for the last: no gate before six pieces stand", function()
		local sim, k = world(1)
		local gateAt = nil
		for i = 1, 120 do
			local what = RulerAI.think(sim, k)
			if what == "PlaceGate" and gateAt == nil then
				gateAt = i
				local finished = 0
				for _, w in piecesOf(sim, k, "wall") do
					if w.level >= 1 then
						finished += 1
					end
				end
				expect(finished + 1 >= 6).toBe(true) -- the converted piece was one of the six
			end
			finishSites(sim, k)
			sim.time += 7
		end
		expect(gateAt).toBeTruthy()
	end)

	it("with the Kit's real footprints on open ground, nearly the whole arc and the gate fit", function()
		local sim = Simulation.new({ random = Random.new(3), catalog = Catalog.default() })
		local k = sim:addKingdom({ id = "crimson", name = "Test", x = 0, z = 0, populate = false })
		sim:addKingdom({ id = "azure", name = "Rival", x = 400, z = 0, populate = false })
		Military.install(sim)
		RulerAI.install(sim, { interval = NEVER })
		sim.rulerAI.aggression.crimson = 1
		sim.rulerAI.aggression.azure = 0
		local keep = sim.buildings[k.keepId]
		keep.level = 2
		keep.pendingLevel = nil
		sim:_recompute(k)
		for _, spot in { { 36, -36 }, { -36, 36 } } do
			local b = sim:_createBuilding(k, "watchtower", spot[1], spot[2])
			sim:_completeInstantly(b)
		end
		sim:_recompute(k)
		for _, res in { "food", "wood", "stone", "gold" } do
			deposits += 1
			sim.treasury:deposit(k.id, res, 5000, `spec:fortify:{deposits}`, "test")
		end
		sim.time = 4 * sim.catalog.tuning.dayLength
		run(sim, k, 160)
		local walls = #piecesOf(sim, k, "wall")
		expect(walls >= 8 and walls <= 12).toBe(true)
		expect(#piecesOf(sim, k, "gate")).toBe(1)
	end)

	it("only a governor with aggression >= 0.5 fortifies, and only with a level-2 keep and both towers", function()
		local cautious = world(0.4)
		local sim, k = cautious, cautious.kingdoms.crimson
		run(sim, k, 120)
		expect(#piecesOf(sim, k, "wall")).toBe(0)
		local bold, bk = world(1)
		bold.buildings[bk.keepId].level = 1
		bold:_recompute(bk)
		run(bold, bk, 120)
		expect(#piecesOf(bold, bk, "wall")).toBe(0)
		local towerless, tk = world(1)
		for _, b in piecesOf(towerless, tk, "watchtower") do
			towerless:_removeBuilding(b)
		end
		-- no stone to rebuild the towers (they cost 80), plenty of wood for the palisade
		assert(towerless:spend(tk.id, { stone = towerless:balance(tk.id, "stone") }, "spec:drain:stone", "test"))
		run(towerless, tk, 30)
		expect(#piecesOf(towerless, tk, "wall")).toBe(0)
	end)

	it("never builds a palisade out of the last wood: below the reserve it waits", function()
		local sim, k = world(1)
		assert(sim:spend(k.id, { wood = sim:balance(k.id, "wood") - 100 }, "spec:poor", "test"))
		run(sim, k, 60)
		expect(#piecesOf(sim, k, "wall")).toBe(0)
	end)

	it("builds one piece at a time: a wall under construction holds the next", function()
		local sim, k = world(1)
		local first = RulerAI.think(sim, k)
		local second
		for _ = 1, 40 do
			if first == "PlaceBuilding:wall" then
				break
			end
			finishSites(sim, k)
			sim.time += 7
			first = RulerAI.think(sim, k)
		end
		expect(first).toBe("PlaceBuilding:wall")
		local standing = #piecesOf(sim, k, "wall")
		second = RulerAI.think(sim, k) -- the first piece is still a site
		expect(second == "PlaceBuilding:wall").toBe(false)
		expect(#piecesOf(sim, k, "wall")).toBe(standing)
	end)

	it("rests for a minute once every slot of the arc is built or blocked", function()
		local sim, k = world(1)
		run(sim, k, 120)
		local resting = sim.rulerAI.noSpotUntil
		resting[`{k.id}:wall`] = nil
		RulerAI.think(sim, k)
		expect(resting[`{k.id}:wall`]).toBeTruthy()
		expect(resting[`{k.id}:wall`] > sim.time).toBe(true)
		expect(resting[`{k.id}:wall`] <= sim.time + 60).toBe(true)
	end)

	it("faces the nearest living keep: a fallen rival no longer draws the arc", function()
		local sim, k, rival = world(1)
		sim:addKingdom({ id = "emerald", name = "North", x = 0, z = 500, populate = false })
		sim.rulerAI.aggression.emerald = 0
		rival.alive = false -- azure (due east, nearer) has fallen: the arc faces emerald, due north (+Z)
		run(sim, k, 120)
		local walls = piecesOf(sim, k, "wall")
		expect(#walls >= 4).toBe(true)
		for _, b in walls do
			expect(b.z > 0).toBe(true)
		end
	end)

	it("holds the next wall while the gate is still a site", function()
		local sim, k = world(1)
		local issued
		for _ = 1, 120 do
			issued = RulerAI.think(sim, k)
			if issued == "PlaceGate" then
				break
			end
			finishSites(sim, k)
			sim.time += 7
		end
		expect(issued).toBe("PlaceGate")
		sim.time += 7
		expect(RulerAI.think(sim, k) == "PlaceBuilding:wall").toBe(false) -- the gate is not finished yet
	end)

	it("holds its other pieces for the gate while the stone is short, then goes on without it", function()
		local sim, k = world(1)
		assert(sim:spend(k.id, { stone = sim:balance(k.id, "stone") }, "spec:drain:stone", "test")) -- the gate costs stone
		run(sim, k, 10) -- the palisade rises to six pieces; the gate cannot be paid
		local six = #piecesOf(sim, k, "wall")
		expect(six).toBe(6)
		expect(#piecesOf(sim, k, "gate")).toBe(0)
		run(sim, k, 20) -- 140 s later: still waiting for the gate
		expect(#piecesOf(sim, k, "wall")).toBe(six)
		sim.time += 300 -- the patience runs out
		run(sim, k, 10)
		expect(#piecesOf(sim, k, "wall") > six).toBe(true)
		expect(#piecesOf(sim, k, "gate")).toBe(0)
	end)

	it(
		"on the real match's crowded yard, the aggressive governors still raise their palisade (FORGE-07's #315 finding)",
		function()
			-- seed 11: farms, houses, camps, towers and trees fill the ground out to about 120 studs; a ring at 64 found 0-2 free slots
			local match = Match.new({
				random = Random.new(11),
				minPlayers = 0,
				now = function()
					return 1700000000
				end,
			})
			local sim = match.sim
			while sim.time < 1800 and match.state ~= "Results" do
				match:update(MatchConfig.tickSeconds)
			end
			local fortified, pieces = 0, 0
			for _, kid in sim.kingdomOrder do
				local k = sim.kingdoms[kid]
				local keep = sim.buildings[k.keepId]
				local walls = 0
				for _, b in piecesOf(sim, k, "wall") do
					if b.level >= 1 then
						walls += 1
						expect(math.sqrt((b.x - keep.x) ^ 2 + (b.z - keep.z) ^ 2) <= k.territory).toBe(true)
					end
				end
				if walls >= 4 then
					fortified += 1
					expect((sim.rulerAI.aggression[kid] or 0) >= 0.5).toBe(true) -- only the bold fortify
				end
				pieces += walls
			end
			expect(fortified >= 2).toBe(true)
			expect(pieces <= 4 * sim.catalog.buildings.wall.maxCount).toBe(true)
		end
	)
end)
