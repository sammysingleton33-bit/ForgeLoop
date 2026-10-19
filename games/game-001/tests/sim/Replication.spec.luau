local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local F = require("./KingdomFixtures")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Replication = require("@game/ReplicatedStorage/Game/Sim/Replication")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")

local function byId(records)
	local out = {}
	for _, r in records do
		out[r.id] = r
	end
	return out
end

describe("Sim/Replication: entity height (G4 y = feet)", function()
	it("stands records on sim.groundY and samples it again only when the entity moves", function()
		local sim, k = F.kingdom()
		local calls = 0
		sim.groundY = function(x, z)
			calls += 1
			return 5 + x * 0.01 - z * 0.02
		end
		local tracker = Replication.new()
		local frame = tracker:frame(sim)
		expect(#frame.records).toBe(#k.citizenIds)
		for _, r in frame.records do
			expect(r.y).toBeNear(5 + r.x * 0.01 - r.z * 0.02, 1e-9)
		end
		expect(calls).toBe(#frame.records)

		tracker:frame(sim) -- nobody moved: no new samples
		expect(calls).toBe(#frame.records)

		local c = sim.citizens[k.citizenIds[1]]
		c.x += 12
		local moved = byId(tracker:frame(sim).records)[c.id]
		expect(calls).toBe(#frame.records + 1)
		expect(moved.y).toBeNear(5 + c.x * 0.01 - c.z * 0.02, 1e-9)
	end)

	it("without a surface, records sit at the groundY argument (0 by default)", function()
		local sim = F.kingdom()
		for _, r in Replication.new():frame(sim).records do
			expect(r.y).toBe(0)
		end
		for _, r in Replication.new():frame(sim, 2.5).records do
			expect(r.y).toBe(2.5)
		end
	end)

	it("entityState reports the same height in its position", function()
		local sim, k = F.kingdom()
		sim.groundY = function()
			return 7.25
		end
		local state = Replication.entityState(sim, k.citizenIds[1])
		expect(state.position.Y).toBe(7.25)
	end)
end)

describe("Kingdom/Layout.groundY (world plots)", function()
	local bridges = Layout.WORLD.features.river.bridges

	local function onBridge(br, along: number, side: number): (number, number)
		local yaw = math.rad(br.yaw)
		local sin, cos = math.sin(yaw), math.cos(yaw)
		return br.at.X + along * sin + side * cos, br.at.Y + along * cos - side * sin
	end

	it("puts entities on the bridge deck over the river and on the ramps down to the banks", function()
		expect(#bridges).toBe(2)
		for _, br in bridges do
			local base = WorldPlan.groundHeight(Layout.WORLD, br.at.X + 30, br.at.Y)
			expect(Layout.groundY(br.at.X, br.at.Y)).toBeNear(base + br.deckY, 1e-9)
			-- the flat deck spans 12 studs either way and the full width (14)
			local x, z = onBridge(br, 11, 6)
			expect(Layout.groundY(x, z)).toBeNear(base + br.deckY, 1e-9)
			x, z = onBridge(br, -11, -6)
			expect(Layout.groundY(x, z)).toBeNear(base + br.deckY, 1e-9)
			-- halfway down each ramp
			x, z = onBridge(br, 21, 0)
			expect(Layout.groundY(x, z)).toBeNear(
				math.max(WorldPlan.groundHeight(Layout.WORLD, x, z), base + br.deckY / 2),
				1e-9
			)
			-- beside the bridge it is the river bed again
			x, z = onBridge(br, 0, 10)
			expect(Layout.groundY(x, z)).toBe(WorldPlan.groundHeight(Layout.WORLD, x, z))
			expect(Layout.groundY(x, z)).toBeLessThan(0)
		end
	end)

	it("follows hills and the river bed away from the bridges", function()
		local f = Layout.WORLD.features
		local hill = f.hills[1]
		expect(Layout.groundY(hill.center.X, hill.center.Y)).toBeNear(f.groundY + hill.height, 1e-6)
		local river = f.river.points[5] -- far from both bridges
		expect(Layout.groundY(river.X, river.Y)).toBe(f.groundY - f.river.depth)
		for _, plot in Layout.WORLD.plots do
			local keep = plot.anchors.keep.Position
			expect(Layout.groundY(keep.X, keep.Z)).toBeNear(WorldPlan.groundHeight(Layout.WORLD, keep.X, keep.Z), 0.05)
		end
	end)

	it("stays within 0.3 studs of WorldPlan.groundHeight across a hill, between lattice corners", function()
		local hill = Layout.WORLD.features.hills[2]
		local worst = 0
		for i = 0, 399 do
			local a, d = i * 2.39996, hill.radius * math.sqrt((i + 0.5) / 400)
			local x, z = hill.center.X + d * math.cos(a) + 0.37, hill.center.Y + d * math.sin(a) + 0.61
			worst = math.max(worst, math.abs(Layout.groundY(x, z) - WorldPlan.groundHeight(Layout.WORLD, x, z)))
		end
		expect(worst).toBeLessThan(0.3) -- the most is at the hill foot, where the slope breaks
	end)

	it("samples the terrain at most once per lattice corner", function()
		local original = WorldPlan.groundHeight
		local calls = 0
		WorldPlan.groundHeight = function(...)
			calls += 1
			return original(...)
		end
		local ok, err = pcall(function()
			Layout.groundY(601.3, -611.7) -- a spot no other spec stands on
			expect(calls).toBe(4)
			Layout.groundY(601.3, -611.7)
			Layout.groundY(601.9, -610.1) -- same cell
			expect(calls).toBe(4)
		end)
		WorldPlan.groundHeight = original
		assert(ok, err)
	end)
end)

describe("Sim/Replication: the unit kind is the job on the wire", function()
	it("sends soldier, archer, knight and ram as the job of a unit, and a citizen's job as before", function()
		local sim, k = F.kingdom()
		local ids = {}
		for i, kind in { "soldier", "archer", "knight", "ram" } do
			ids[kind] = Military.spawnUnit(sim, k, kind, 100 + i * 4, 100).id
		end
		local frame = Replication.new():frame(sim)
		for kind, id in ids do
			expect(frame.identity[id].job).toBe(kind)
			expect(frame.identity[id].kind).toBe("soldier") -- the entity kind stays
			expect(Replication.entityState(sim, id).job).toBe(kind)
		end
		local citizen = sim.citizens[k.citizenIds[1]]
		expect(frame.identity[citizen.id].job).toBe(citizen.job)
	end)

	it("survives the spawn event's wire format for every unit kind", function()
		for _, kind in { "soldier", "archer", "knight", "ram" } do
			local buf =
				EventCodec.encode(1, { { type = "spawn", id = 7, kind = "soldier", job = kind, kingdom = "crimson" } })
			local batch = assert(EventCodec.decode(buf))
			expect(batch.events[1].job).toBe(kind)
		end
	end)
end)
