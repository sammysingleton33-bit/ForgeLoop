--[[
	D-059 work slots (Sim/CitizenActions.workSpot; FORGE-04 under a one-PR exception, FORGE-01 owns the file):
	citizens working the same node or building stand apart on its reach circle instead of on one spot, facing
	it, deterministically. Headless, on the kingdom fixture of tests/sim (a kingdom at the origin).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local CitizenActions = require("@game/ReplicatedStorage/Game/Sim/CitizenActions")
local Replication = require("@game/ReplicatedStorage/Game/Sim/Replication")
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local EntityController = require("@game/StarterPlayer/StarterPlayerScripts/Game/Controllers/EntityController")

local DT = 1 / 16

local function setup(jobs: { [string]: number })
	local sim, k = F.kingdom({ nodes = false, tuning = { startCitizens = jobs, birthInterval = 1e6 } })
	return sim, k
end

local function citizens(sim, k, job: string?): { any }
	local out = {}
	for _, c in sim:citizensOf(k) do
		if job == nil or c.job == job then
			table.insert(out, c)
		end
	end
	return out
end

-- Sends each citizen to `target` (activity, phase Go) and steps only its walk until all of them work.
local function goWork(sim, list: { any }, activity: string, target: any)
	for _, c in list do
		c.activity, c.target, c.phase, c.done, c.workTimer = activity, target, "Go", false, 0
	end
	for _ = 1, 60 / DT do
		local all = true
		for _, c in list do
			if c.phase == "Go" then
				CitizenActions.step(sim, c, DT)
			end
			all = all and c.phase == "Work"
		end
		if all then
			return
		end
	end
	error("the citizens never reached their work")
end

local function dist(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

describe("Sim/CitizenActions: work slots (D-059)", function()
	it("workers on one node stand apart on its reach circle, one slot step apart, facing it", function()
		local sim, k = setup({ miner = 3 })
		local rock = sim:addNode("rock", 40, 0)
		local miners = citizens(sim, k, "miner")
		goWork(sim, miners, "Gather", rock.id)
		local reach = rock.footprint + 1
		local step = math.min(CitizenActions.SLOT_SPACING / reach, CitizenActions.SLOT_MAX_TURN)
		local chord = 2 * reach * math.sin(step / 2)
		local seen = {}
		for _, c in miners do
			-- exactly on the reach circle: walked onto the slot, not left arriveRadius short of it
			expect(dist(c.x, c.z, rock.x, rock.z)).toBeNear(reach, 1e-6)
			expect(dist(c.x, c.z, c.slotX, c.slotZ)).toBeLessThan(1e-6)
			expect(c.faceX).toBe(rock.x)
			expect(c.faceZ).toBe(rock.z)
			seen[c.slot] = c
		end
		-- slots 0, 1, 2: 0 on the kingdom's side (the kingdom is at the origin, the rock at +X: slot 0 at x = 35)
		expect(seen[0] ~= nil and seen[1] ~= nil and seen[2] ~= nil).toBe(true)
		expect(seen[0].x).toBeNear(rock.x - reach, 1e-6)
		expect(seen[0].z).toBeNear(0, 1e-6)
		expect(seen[1].z * seen[2].z < 0).toBe(true) -- +1 and -1: either side of slot 0
		-- one step each way from slot 0 (the side facing the kingdom, angle pi from the rock): SLOT_SPACING of arc,
		-- capped at SLOT_MAX_TURN
		for _, i in { 1, 2 } do
			local turn = math.atan2(seen[i].z - rock.z, seen[i].x - rock.x)
			local from = math.abs(math.abs(turn) - math.pi)
			expect(from).toBeNear(step, 1e-6)
		end
		for i = 1, #miners do
			for j = i + 1, #miners do
				local a, b = miners[i], miners[j]
				assert(dist(a.x, a.z, b.x, b.z) >= chord - 1e-6, `slots {a.slot} and {b.slot} too close`)
			end
		end
		-- and Replication turns each worker to face the rock, whichever way it walked in
		local records = Replication.new():frame(sim).records
		for _, r in records do
			local c = sim.citizens[r.id]
			local fx, fz = -math.sin(r.yaw), -math.cos(r.yaw)
			local tx, tz = rock.x - c.x, rock.z - c.z
			local n = math.sqrt(tx * tx + tz * tz)
			expect((fx * tx + fz * tz) / n).toBeNear(1, 1e-6)
		end
	end)

	it("stands at each activity's own arrive radius: a node's footprint + 1, a farm's edge, a site's + 1", function()
		local sim, k = setup({ woodcutter = 2, farmer = 2, builder = 1 })
		local tree = sim:addNode("tree", -40, 10)
		local farm = nil
		for _, b in sim.buildings do
			if b.kind == "farm" and b.kingdomId == k.id then
				farm = b
			end
		end
		assert(farm ~= nil, "the fixture's farm")
		local woodcutters = citizens(sim, k, "woodcutter")
		goWork(sim, woodcutters, "Gather", tree.id)
		for _, w in woodcutters do
			expect(dist(w.x, w.z, tree.x, tree.z)).toBeNear(tree.footprint + 1, 1e-6)
		end
		-- a small target: the step is capped at SLOT_MAX_TURN (3.5 studs of arc would be more on a tree)
		local function between(a, b, x, z): number
			local d = math.abs(math.atan2(a.z - z, a.x - x) - math.atan2(b.z - z, b.x - x))
			return math.min(d, 2 * math.pi - d)
		end
		expect(CitizenActions.SLOT_SPACING / (tree.footprint + 1) > CitizenActions.SLOT_MAX_TURN).toBe(true)
		expect(between(woodcutters[1], woodcutters[2], tree.x, tree.z)).toBeNear(CitizenActions.SLOT_MAX_TURN, 1e-6)
		-- the fixture's farm (footprint 10): SLOT_SPACING studs of arc between neighbours
		local farmers = citizens(sim, k, "farmer")
		goWork(sim, farmers, "Farm", farm.id)
		for _, f in farmers do
			expect(dist(f.x, f.z, farm.x, farm.z)).toBeNear(farm.footprint, 1e-6)
		end
		expect(CitizenActions.SLOT_SPACING / farm.footprint < CitizenActions.SLOT_MAX_TURN).toBe(true)
		expect(between(farmers[1], farmers[2], farm.x, farm.z) * farm.footprint).toBeNear(
			CitizenActions.SLOT_SPACING,
			1e-6
		)
		local builder = citizens(sim, k, "builder")[1]
		farm.pendingLevel = farm.level + 1 -- an upgrade to work on
		goWork(sim, { builder }, "Build", farm.id)
		expect(dist(builder.x, builder.z, farm.x, farm.z)).toBeNear(farm.footprint + 1, 1e-6)
		-- the farmers and the builder share the farm's slots: the builder took the next one
		expect(builder.slot).toBe(2)
	end)

	it("takes the lowest free slot, keeps it while the target stays, and frees it when the target changes", function()
		local sim, k = setup({ miner = 4 })
		local rock = sim:addNode("rock", 40, 0)
		local other = sim:addNode("rock", 0, 40)
		local m = citizens(sim, k, "miner")
		goWork(sim, { m[1], m[2], m[3] }, "Gather", rock.id)
		expect({ m[1].slot, m[2].slot, m[3].slot }).toEqual({ 0, 1, 2 })
		-- m2 goes to another rock: its slot here is free again
		goWork(sim, { m[2] }, "Gather", other.id)
		expect(m[2].slot).toBe(0)
		-- m3 delivers and comes back to the same rock: it keeps its own slot and spot, not the freed one
		local x, z = m[3].x, m[3].z
		m[3].x, m[3].z = 0, 0
		goWork(sim, { m[3] }, "Gather", rock.id)
		expect(m[3].slot).toBe(2)
		expect(m[3].x).toBeNear(x, 1e-6)
		expect(m[3].z).toBeNear(z, 1e-6)
		-- m1 goes to eat at the keep (no slot there): its slot is free while it is away, and the next miner takes it
		m[1].activity, m[1].target, m[1].phase = "Eat", k.keepId, "Go"
		CitizenActions.step(sim, m[1], DT) -- a step with another target frees its slot
		expect(m[1].slot).toBeNil()
		expect(m[1].faceX).toBeNil()
		goWork(sim, { m[4] }, "Gather", rock.id)
		expect(m[4].slot).toBe(0)
		-- and the freed slot 1 is next
		m[1].x, m[1].z = 0, 0
		goWork(sim, { m[1] }, "Gather", rock.id)
		expect(m[1].slot).toBe(1)
		-- a worker sent elsewhere frees its slot at once, even before its own next step (the same tick)
		m[3].activity, m[3].target, m[3].phase = "Gather", other.id, "Go"
		m[2].x, m[2].z = 0, 0
		goWork(sim, { m[2] }, "Gather", rock.id)
		expect(m[2].slot).toBe(2)
	end)

	it("on the keep itself (the kingdom's centre) the slots start from +X, SLOT_SPACING studs of arc apart", function()
		local sim, k = setup({ builder = 2 })
		local keep = sim.buildings[k.keepId]
		keep.pendingLevel = keep.level + 1
		local builders = citizens(sim, k, "builder")
		goWork(sim, builders, "Build", keep.id)
		local reach = keep.footprint + 1
		local first = if builders[1].slot == 0 then builders[1] else builders[2]
		expect(first.x).toBeNear(keep.x + reach, 1e-6)
		expect(first.z).toBeNear(keep.z, 1e-6)
		local a = math.atan2(builders[1].z - keep.z, builders[1].x - keep.x)
		local b = math.atan2(builders[2].z - keep.z, builders[2].x - keep.x)
		local d = math.abs(a - b)
		expect(math.min(d, 2 * math.pi - d) * reach).toBeNear(CitizenActions.SLOT_SPACING, 1e-6)
		-- wider than a citizen (the part-built one is 2.3-2.4 studs across), with room between their swings
		expect(dist(builders[1].x, builders[1].z, builders[2].x, builders[2].z) > 3).toBe(true)
	end)

	it("on a middling target (a house site) neighbours stand SLOT_SPACING studs of arc apart", function()
		local sim, k = setup({ builder = 2 })
		local site = assert(sim:placeBuilding(k, "house", 0, -40))
		local builders = citizens(sim, k, "builder")
		goWork(sim, builders, "Build", site.id)
		local reach = site.footprint + 1
		local step = CitizenActions.SLOT_SPACING / reach
		expect(step < CitizenActions.SLOT_MAX_TURN).toBe(true)
		local a = math.atan2(builders[1].z - site.z, builders[1].x - site.x)
		local b = math.atan2(builders[2].z - site.z, builders[2].x - site.x)
		local d = math.abs(a - b)
		expect(math.min(d, 2 * math.pi - d) * reach).toBeNear(CitizenActions.SLOT_SPACING, 1e-6)
	end)

	it("spaces slots for the drawn citizen: 3.5 studs x the client's rig scale, 3 x it at a tree", function()
		-- the client draws every rig RIG_SCALE x the Kit size (EntityController); the sim's spacing follows it
		expect(CitizenActions.SLOT_SPACING).toBeNear(3.5 * EntityController.RIG_SCALE, 1e-9)
		local sim, k = setup({ woodcutter = 2 })
		local tree = sim:addNode("tree", -40, 10)
		local w = citizens(sim, k, "woodcutter")
		goWork(sim, w, "Gather", tree.id)
		-- a tree's two woodcutters: the cap's chord, clear of a drawn citizen (2.4 studs wide x the scale, and room)
		local apart = dist(w[1].x, w[1].z, w[2].x, w[2].z)
		expect(apart).toBeNear(2 * (tree.footprint + 1) * math.sin(CitizenActions.SLOT_MAX_TURN / 2), 1e-6)
		expect(apart >= 3 * EntityController.RIG_SCALE - 1e-6).toBe(true)
	end)

	it("a moved farm or site gives its workers a new slot at the new place (FL-0119; FORGE-01 L1)", function()
		local sim, k = setup({ farmer = 2 })
		local farm = nil
		for _, b in sim.buildings do
			if b.kind == "farm" and b.kingdomId == k.id then
				farm = b
			end
		end
		assert(farm ~= nil, "the fixture's farm")
		local f = citizens(sim, k, "farmer")
		goWork(sim, f, "Farm", farm.id)
		local slot = f[1].slot
		-- the ruler moves the farm while f[1] still works it: on its next walk there it heads for the new place
		farm.x += 30
		f[1].x, f[1].z = 0, 0
		goWork(sim, { f[1] }, "Farm", farm.id)
		expect(dist(f[1].x, f[1].z, farm.x, farm.z)).toBeNear(farm.footprint, 1e-6)
		expect(f[1].faceX).toBe(farm.x)
		expect(f[1].slot).toBe(slot) -- the same index: f[2] still holds its own
	end)

	it("measures from +X for a worker without a kingdom on record (FORGE-01 L2)", function()
		local sim, k = setup({ miner = 1 })
		local rock = sim:addNode("rock", 40, 0)
		local m = citizens(sim, k, "miner")[1]
		m.activity, m.target, m.phase = "Gather", rock.id, "Go"
		local saved = sim.kingdoms[m.kingdomId]
		sim.kingdoms[m.kingdomId] = nil
		local ok, err = pcall(CitizenActions.workSpot, sim, m, rock.x, rock.z, rock.footprint + 1)
		sim.kingdoms[m.kingdomId] = saved
		assert(ok, err)
		expect(m.slotX).toBeNear(rock.x + rock.footprint + 1, 1e-6)
		expect(m.slotZ).toBeNear(rock.z, 1e-6)
	end)

	it("a dead worker's slot goes to the next worker (FORGE-01 L3)", function()
		local sim, k = setup({ miner = 3 })
		local rock = sim:addNode("rock", 40, 0)
		local m = citizens(sim, k, "miner")
		goWork(sim, { m[1], m[2] }, "Gather", rock.id)
		local first = if m[1].slot == 0 then m[1] else m[2]
		sim:killCitizen(first, "test")
		expect(sim.citizens[first.id]).toBeNil()
		goWork(sim, { m[3] }, "Gather", rock.id)
		expect(m[3].slot).toBe(0)
	end)

	it(
		"never puts two workers on one spot: past a full circle the next ones stand on a ring further out (FORGE-07 L1)",
		function()
			local sim, k = setup({ miner = 14 })
			local rock = sim:addNode("rock", 40, 0)
			local m = citizens(sim, k, "miner")
			goWork(sim, m, "Gather", rock.id)
			local reach = rock.footprint + 1
			local step = math.min(CitizenActions.SLOT_SPACING / reach, CitizenActions.SLOT_MAX_TURN)
			local perRing = math.floor(2 * math.pi / step + 1e-9)
			expect(perRing < #m).toBe(true) -- more workers than one circle holds
			local closest = math.huge
			for i = 1, #m do
				for j = i + 1, #m do
					closest = math.min(closest, dist(m[i].x, m[i].z, m[j].x, m[j].z))
				end
				local ring = reach + (m[i].slot // perRing) * CitizenActions.SLOT_SPACING
				expect(dist(m[i].x, m[i].z, rock.x, rock.z)).toBeNear(ring, 1e-6)
			end
			expect(closest >= 2 * reach * math.sin(step / 2) - 1e-6).toBe(true) -- a slot's chord at the least
		end
	)

	it("is deterministic: the same seed puts every citizen on the same spot", function()
		local function positions(): { [number]: { number } }
			local match = Match.new({
				random = Random.new(11),
				minPlayers = 0,
				now = function()
					return 1700000000
				end,
			})
			local sim = match.sim
			local t0 = sim.time
			while sim.time < t0 + 30 do
				match:update(MatchConfig.tickSeconds)
			end
			local out = {}
			for _, id in sim.citizenOrder do
				local c = sim.citizens[id]
				out[id] = { c.x, c.z, c.slot or -1 }
			end
			return out
		end
		local a, b = positions(), positions()
		local n = 0
		for id, p in a do
			expect(b[id]).toEqual(p)
			n += 1
		end
		expect(n > 40).toBe(true)
	end)
end)
