--[[
	Sim/RulerAI fortifying (FL-0126 part 2, slice 4): a governor with aggression >= 0.5, a keep at level 2 and its two watchtowers
	rings the keep with a palisade (up to 11 pieces, 64 studs out, laid tangent) and turns the piece that faces the nearest other
	keep into the gate. Specs drive think() directly in open ground and finish every site at once.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Simulation = require("@game/ReplicatedStorage/Game/Sim/Simulation")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local RulerAI = require("@game/ReplicatedStorage/Game/Sim/RulerAI")

local NEVER = 1e9
local deposits = 0

-- crimson at the origin with a level-2 keep and its two towers (between the keep and the ring), azure 400 studs east; plenty of
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
	it("rings the keep with wall pieces 64 studs out, laid along the circle, up to the 12-slot count", function()
		local sim, k = world(1)
		run(sim, k, 120)
		local walls = piecesOf(sim, k, "wall")
		local gates = piecesOf(sim, k, "gate")
		expect(#walls + #gates <= 12).toBe(true)
		expect(#walls >= 6).toBe(true)
		local keep = sim.buildings[k.keepId]
		for _, b in walls do
			local r = math.sqrt((b.x - keep.x) ^ 2 + (b.z - keep.z) ^ 2)
			expect(math.abs(r - 64) < 1e-6).toBe(true)
			-- tangent: the piece's long axis is at right angles to the radius
			local ux, uz = math.cos(b.yaw), -math.sin(b.yaw) -- the long axis, as Footprint.rect turns it
			local rx, rz = (b.x - keep.x) / r, (b.z - keep.z) / r
			expect(math.abs(ux * rx + uz * rz) < 1e-6).toBe(true)
		end
		expect(sim:countOf(k, "wall") <= sim.catalog.buildings.wall.maxCount).toBe(true)
	end)

	it("puts the one gate in the slot that faces the nearest other keep, at the gate's own radius", function()
		local sim, k, rival = world(1)
		run(sim, k, 120)
		local gates = piecesOf(sim, k, "gate")
		expect(#gates).toBe(1)
		local gate = gates[1]
		local keep = sim.buildings[k.keepId]
		expect(math.abs(math.sqrt((gate.x - keep.x) ^ 2 + (gate.z - keep.z) ^ 2) - 66) < 1e-6).toBe(true)
		-- the gate is nearer to the rival than any wall piece
		local dg = (gate.x - rival.x) ^ 2 + (gate.z - rival.z) ^ 2
		for _, w in piecesOf(sim, k, "wall") do
			expect(dg <= (w.x - rival.x) ^ 2 + (w.z - rival.z) ^ 2 + 1e-6).toBe(true)
		end
		expect(#piecesOf(sim, k, "wall") + #gates <= 12).toBe(true)
	end)

	it("keeps the gate for the last: no gate before six pieces stand", function()
		local sim, k = world(1)
		local gateAt = nil
		for i = 1, 120 do
			local what = RulerAI.think(sim, k)
			if what == "PlaceBuilding:gate" and gateAt == nil then
				gateAt = i
				local finished = 0
				for _, w in piecesOf(sim, k, "wall") do
					if w.level >= 1 then
						finished += 1
					end
				end
				expect(finished >= 6).toBe(true)
			end
			finishSites(sim, k)
			sim.time += 7
		end
		expect(gateAt).toBeTruthy()
	end)

	it(
		"with the Kit's real footprints on open ground, nearly the whole ring and the gate fit (the starting farm and the towers take a slot or two)",
		function()
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
			expect(walls >= 8 and walls <= 11).toBe(true)
			expect(#piecesOf(sim, k, "gate")).toBe(1)
		end
	)

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
end)
