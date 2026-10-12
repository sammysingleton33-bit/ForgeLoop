local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Def = require("@game/ServerScriptService/Game/Services/WorldService")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local ANCHORS = { "keep", "storehouse", "farm", "lumbercamp", "quarry" }
-- the smallest slot each type is meant for; its largest level must fit (slots never grow on upgrade)
local INTENDED = {
	house = "S",
	barracks = "M",
	storehouse = "M",
	watchtower = "M",
	market = "M",
	granary = "M",
	infirmary = "M",
	blacksmith = "M",
	shrine = "M",
	farm = "L",
	lumbercamp = "L",
	quarry = "L",
	mine = "L",
}

local function slotFrame(slot): CFrame
	return CFrame.new(slot.center) * CFrame.Angles(0, slot.rot, 0)
end

-- true when world point p (XZ) is inside the slot rectangle grown by `margin`
local function inSlot(slot, p: Vector3, margin: number): boolean
	local size = Layout.slotSizes[slot.size]
	local q = slotFrame(slot):PointToObjectSpace(Vector3.new(p.X, slot.center.Y, p.Z))
	return math.abs(q.X) <= size.X / 2 + margin and math.abs(q.Z) <= size.Y / 2 + margin
end

-- sample points of a rectangle (frame, size) on a 2-stud grid, edges included
local function samples(cf: CFrame, size: Vector2): { Vector3 }
	local out = {}
	local nx, nz = math.max(1, math.ceil(size.X / 2)), math.max(1, math.ceil(size.Y / 2))
	for i = 0, nx do
		for j = 0, nz do
			table.insert(
				out,
				cf:PointToWorldSpace(Vector3.new(-size.X / 2 + size.X * i / nx, 0, -size.Y / 2 + size.Y * j / nz))
			)
		end
	end
	return out
end

local function inPolygon(poly: { Vector2 }, x: number, z: number): boolean
	local inside = false
	local j = #poly
	for i = 1, #poly do
		local a, b = poly[i], poly[j]
		if (a.Y > z) ~= (b.Y > z) and x < (b.X - a.X) * (z - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		j = i
	end
	return inside
end

local function allSlots()
	local out = {}
	for _, k in KINGDOMS do
		for _, s in Layout.plots[k].buildSlots do
			table.insert(out, { kingdom = k, slot = s })
		end
	end
	return out
end

describe("Layout build slots (G13.5)", function()
	it("gives every kingdom at least 8 slots with unique ids, S/M/L sizes and a yaw", function()
		local seen = {}
		for _, k in KINGDOMS do
			local slots = Layout.plots[k].buildSlots
			expect(#slots >= 8).toBe(true)
			local sizes = { S = 0, M = 0, L = 0 }
			for _, s in slots do
				expect(type(s.id)).toBe("string")
				expect(#s.id >= 1 and #s.id <= 32).toBe(true) -- Build.PlaceSlot slotId string(1,32)
				expect(seen[s.id]).toBeNil()
				seen[s.id] = true
				expect(typeof(s.center)).toBe("Vector3")
				expect(type(s.rot)).toBe("number")
				expect(sizes[s.size]).never.toBeNil()
				sizes[s.size] += 1
			end
			expect(sizes.S >= 2 and sizes.M >= 2 and sizes.L >= 1).toBe(true)
		end
		for _, size in { "S", "M", "L" } do
			expect(typeof(Layout.slotSizes[size])).toBe("Vector2")
		end
	end)

	it("fits each building type's largest footprint in its intended slot size", function()
		local bad = {}
		for _, t in Kit.BUILDING_TYPES do
			local size = INTENDED[t]
			if size then
				local slot = Layout.slotSizes[size]
				for level = 1, 6 do
					local fp = Kit.footprint(t, level)
					if fp.X > slot.X or fp.Y > slot.Y then
						table.insert(bad, `{t} L{level} {fp.X}x{fp.Y} > {size} {slot.X}x{slot.Y}`)
					end
				end
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
	end)

	it("keeps slots apart from each other, the starting buildings, nav, roads, river and resources", function()
		local bad = {}
		local list = allSlots()
		local f = Layout.features
		-- starting buildings at their largest level
		local buildings = {}
		for _, k in KINGDOMS do
			for _, a in ANCHORS do
				local fp = Kit.footprint(a, 6)
				table.insert(buildings, { label = `{k} {a}`, cf = Layout.plots[k].anchors[a], size = fp })
			end
		end
		for i, e in list do
			local s = e.slot
			local size = Layout.slotSizes[s.size]
			local pts = samples(slotFrame(s), size)
			for j, o in list do
				if j ~= i then
					for _, p in pts do
						if inSlot(o.slot, p, 2) then
							table.insert(bad, `{s.id} overlaps {o.slot.id}`)
							break
						end
					end
				end
			end
			for _, b in buildings do
				for _, p in samples(b.cf, b.size) do
					if inSlot(s, p, 2) then
						table.insert(bad, `{s.id} overlaps {b.label}`)
						break
					end
				end
			end
			for n, p in Layout.nav.nodes do
				if inSlot(s, p, 2) then
					table.insert(bad, `{s.id} covers nav node {n}`)
				end
			end
			for _, edge in Layout.nav.edges do
				local a, b = Layout.nav.nodes[edge[1]], Layout.nav.nodes[edge[2]]
				local steps = math.ceil((b - a).Magnitude)
				for t = 0, steps do
					if inSlot(s, a:Lerp(b, t / steps), 1) then
						table.insert(bad, `{s.id} crosses nav edge {edge[1]}-{edge[2]}`)
						break
					end
				end
			end
			for _, p in pts do
				local x, z = p.X, p.Z
				for r, road in f.roads do
					if WorldPlan.distToPolyline(x, z, road.points) < road.width / 2 + 1 then
						table.insert(bad, `{s.id} on road {r}`)
						break
					end
				end
				if WorldPlan.distToPolyline(x, z, f.river.points) < f.river.width / 2 + 10 then
					table.insert(bad, `{s.id} on the river`)
					break
				end
			end
			for _, r in Layout.resourceNodes do
				if inSlot(s, r.cframe.Position, 4) then
					table.insert(bad, `{s.id} covers {r.id}`)
				end
				for _, w in r.workSpots do
					if inSlot(s, w, 1) then
						table.insert(bad, `{s.id} covers a {r.id} work spot`)
						break
					end
				end
			end
			local plot = Layout.plots[e.kingdom]
			if inSlot(s, plot.spawn.Position, 2) then
				table.insert(bad, `{s.id} covers the spawn`)
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
	end)

	it("puts every slot on flat ground inside its kingdom's home region", function()
		local bad = {}
		for _, e in allSlots() do
			local s = e.slot
			local poly = Layout.regions[Layout.plots[e.kingdom].regionId].polygon
			for _, p in samples(slotFrame(s), Layout.slotSizes[s.size]) do
				local g = WorldPlan.groundHeight(Layout, p.X, p.Z)
				if math.abs(g) > 0.5 then
					table.insert(bad, `{s.id} ground {g} at ({math.floor(p.X)}, {math.floor(p.Z)})`)
					break
				end
				if not inPolygon(poly, p.X, p.Z) then
					table.insert(bad, `{s.id} leaves {Layout.plots[e.kingdom].regionId}`)
					break
				end
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
	end)

	it("keeps every world prop (forests, dressing, crops) out of the slots", function()
		local bad = {}
		local dressed = { crimson = true, azure = true, emerald = true, gold = true }
		local list = allSlots()
		for _, p in WorldPlan.props(Layout, dressed) do
			for _, e in list do
				if inSlot(e.slot, p.cframe.Position, 0) then
					table.insert(bad, `{p.assetId} ({p.feature}) in {e.slot.id}`)
				end
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
	end)

	it("faces each slot's front onto a nav edge (a street) within 15 studs", function()
		local bad = {}
		local nodes = Layout.nav.nodes
		for _, e in allSlots() do
			local s = e.slot
			local size = Layout.slotSizes[s.size]
			local door = slotFrame(s):PointToWorldSpace(Vector3.new(0, 0, -size.Y / 2))
			local best = math.huge
			for _, edge in Layout.nav.edges do
				local a, b = nodes[edge[1]], nodes[edge[2]]
				best = math.min(
					best,
					WorldPlan.distToPolyline(door.X, door.Z, { Vector2.new(a.X, a.Z), Vector2.new(b.X, b.Z) })
				)
			end
			if best > 15 then
				table.insert(bad, `{s.id} front {math.floor(best)} studs from nav`)
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
	end)
end)

describe("WorldService build slot markers (G13.5)", function()
	it("tags one BuildSlot marker per slot with SlotId, Size and Kingdom at the slot", function()
		local env = MockEnv.new({ seed = 1 })
		local svc = Def.new(env, nil)
		svc.terrain = Terrain.recorder()
		svc:start()
		env.mock:advance(30)
		local markers = env.CollectionService:GetTagged("BuildSlot")
		local list = allSlots()
		expect(#markers).toBe(#list)
		local byId = {}
		for _, m in markers do
			byId[m:GetAttribute("SlotId")] = m
		end
		for _, e in list do
			local m = byId[e.slot.id]
			expect(m).never.toBeNil()
			expect(m:GetAttribute("Size")).toBe(e.slot.size)
			expect(m:GetAttribute("Kingdom")).toBe(e.kingdom)
			expect(m.CanQuery).toBe(true)
			expect(m.CanCollide).toBe(false)
			local dx = m.CFrame.Position.X - e.slot.center.X
			local dz = m.CFrame.Position.Z - e.slot.center.Z
			expect(math.abs(dx) + math.abs(dz)).toBeLessThan(1e-3)
			local size = Layout.slotSizes[e.slot.size]
			expect(m.Size.X).toBeNear(size.X, 1e-3)
			expect(m.Size.Z).toBeNear(size.Y, 1e-3)
			-- only the tagged Root is queryable, and nothing in the marker collides
			for _, d in m.Parent:GetDescendants() do
				if d:IsA("BasePart") then
					expect(d.CanCollide).toBe(false)
					expect(d.CanQuery).toBe(d == m)
				end
			end
		end
		svc:destroy()
	end)

	it("keeps a slot marker small (part budget)", function()
		local model = Kit.slotMarker(Layout.slotSizes.L, Kit.NEUTRAL_COLOR)
		expect(Kit.partCount(model) <= 20).toBe(true)
	end)
end)
