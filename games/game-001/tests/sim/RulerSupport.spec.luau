--[[
	Sim/RulerAI support buildings (FL-0149, D-060): a governor with a level-2 keep, a storehouse, a lumber camp and a quarry,
	from day 3, builds the support buildings that bring key citizens (config Support roles[r].building): one at a time, the
	first it can pay in the order blacksmith, infirmary, granary, shrine, and only for a role whose key citizen is
	alive. The palisade's gate and the keep's L2 upgrade have the stone first. Specs drive think() directly.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local RulerAI = require("@game/ReplicatedStorage/Game/Sim/RulerAI")

local NEVER = 1e9
local deposits = 0

local SUPPORT = { "blacksmith", "infirmary", "granary", "shrine" }

-- crimson with a level-2 keep and the three drop-offs finished, plenty of wood and stone, day 5; the citizens named in
-- `keys` (role -> true) carry that key role; the AI is idle (the test calls think()).
local function world(keys: { string }, aggression: number?)
	local sim, k = F.kingdom({ nodes = false, tuning = { birthInterval = 1e6 } })
	sim:addKingdom({ id = "azure", name = "Rival", x = 400, z = 0, populate = false })
	Military.install(sim)
	RulerAI.install(sim, { interval = NEVER })
	sim.rulerAI.aggression.crimson = aggression or 0
	sim.rulerAI.aggression.azure = 0
	local keep = sim.buildings[k.keepId]
	keep.level = 2
	keep.pendingLevel = nil
	sim:_recompute(k)
	for i, kind in { "storehouse", "lumbercamp", "quarry" } do
		local b = sim:_createBuilding(k, kind, 30 + i * 22, 40)
		sim:_completeInstantly(b)
	end
	sim:_recompute(k)
	for i, role in keys do
		local c = sim.citizens[k.citizenIds[i]]
		c.profile = { keyRole = role }
	end
	for _, res in { "food", "wood", "stone", "gold" } do
		deposits += 1
		sim.treasury:deposit(k.id, res, 5000, `spec:support:{deposits}`, "test")
	end
	sim.time = 4 * sim.catalog.tuning.dayLength
	return sim, k
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

local function kindsStanding(sim: any, k: any): { [string]: number }
	local out = {}
	for _, bid in k.buildingIds do
		local b = sim.buildings[bid]
		out[b.kind] = (out[b.kind] or 0) + 1
	end
	return out
end

local function run(sim: any, k: any, times: number): { string }
	local issued = {}
	for _ = 1, times do
		local what = RulerAI.think(sim, k)
		if what then
			table.insert(issued, what)
		end
		finishSites(sim, k)
		sim.time += 7
	end
	return issued
end

describe("Sim/RulerAI: support buildings (FL-0149)", function()
	it("builds a support building for each key citizen alive, in order, one at a time", function()
		local sim, k = world({ "blacksmith", "healer", "elder", "provisioner" })
		local order = {}
		for _ = 1, 60 do
			local what = RulerAI.think(sim, k)
			if what and string.sub(what, 1, 14) == "PlaceBuilding:" and table.find(SUPPORT, string.sub(what, 15)) then
				table.insert(order, string.sub(what, 15))
				-- one at a time: while this one is a site, the next think builds no other support building
				local again = RulerAI.think(sim, k)
				expect(again ~= nil and table.find(SUPPORT, string.sub(again, 15)) ~= nil).toBe(false)
			end
			finishSites(sim, k)
			sim.time += 7
		end
		-- the order of the plan: the blacksmith first (the elder, the provisioner and the merchant follow their turn)
		expect(table.concat(order, ",")).toBe("blacksmith,infirmary,granary,shrine")
	end)

	it("builds only for a role whose key citizen is alive", function()
		local sim, k = world({ "healer", "merchant" })
		run(sim, k, 12)
		local built = kindsStanding(sim, k)
		expect(built.infirmary).toBe(1)
		expect(built.market).toBe(nil) -- the market is deferred with the Merchant (D-061): it is not even a building type
		expect(built.blacksmith).toBe(nil)
		expect(built.granary).toBe(nil)
		expect(built.shrine).toBe(nil)
		-- the healer dies: a kingdom that has not built the infirmary yet does not build it for nobody
		local sim2, k2 = world({ "healer" })
		sim2.citizens[k2.citizenIds[1]].alive = false
		run(sim2, k2, 12)
		expect(kindsStanding(sim2, k2).infirmary).toBe(nil)
	end)

	it("builds the first it can pay: a dear one does not hold up a cheap one", function()
		local sim, k = world({ "blacksmith", "provisioner" })
		-- stone for the granary (20) but not for the blacksmith (60)
		assert(sim:spend(k.id, { stone = sim:balance(k.id, "stone") - 30 }, "spec:poor", "test"))
		run(sim, k, 6)
		local built = kindsStanding(sim, k)
		expect(built.granary).toBe(1)
		expect(built.blacksmith).toBe(nil)
	end)

	it("waits for day 3 and a level-2 keep, and for the storehouse, the lumber camp and the quarry", function()
		local early, ek = world({ "blacksmith" })
		early.time = 1 * early.catalog.tuning.dayLength
		run(early, ek, 6)
		expect(kindsStanding(early, ek).blacksmith).toBe(nil)
		local low, lk = world({ "blacksmith" })
		low.buildings[lk.keepId].level = 1
		low:_recompute(lk)
		run(low, lk, 6)
		expect(kindsStanding(low, lk).blacksmith).toBe(nil)
		local bare, bk = world({ "blacksmith" })
		for _, bid in table.clone(bk.buildingIds) do
			if bare.buildings[bid].kind == "quarry" then
				bare:_removeBuilding(bare.buildings[bid])
			end
		end
		run(bare, bk, 6)
		expect(kindsStanding(bare, bk).blacksmith).toBe(nil)
	end)

	it("keeps wood in hand: below the price plus the margin it waits", function()
		local sim, k = world({ "blacksmith" })
		assert(sim:spend(k.id, { wood = sim:balance(k.id, "wood") - 120 }, "spec:poor", "test")) -- the price is 80 wood
		run(sim, k, 6)
		expect(kindsStanding(sim, k).blacksmith).toBe(nil)
	end)

	it("leaves the stone to the palisade's gate while it waits for one", function()
		local sim, k = world({ "blacksmith" }, 1)
		for i = 1, 6 do -- six finished wall pieces and no gate: the governor wants the gate first
			local b = sim:_createBuilding(k, "wall", 200 + i * 40, 200)
			sim:_completeInstantly(b)
		end
		sim:_recompute(k)
		run(sim, k, 3)
		expect(kindsStanding(sim, k).blacksmith).toBe(nil)
	end)
end)
