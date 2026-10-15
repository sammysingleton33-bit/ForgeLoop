--[[
	Plot clearance (user's first Studio playtest, 2026-10-13: "starting kingdom farm areas visually conflict with
	rocks and trees"). For all four plots, no tree, bush, boulder, flower or prop stands on or within 4 studs of a
	farm field, a starting building's footprint, a build slot, a plot build zone or a road (hand-placed yard props
	may stand in the zones). The reserved areas come from the world Layout (fields, zones, slots, anchors) and
	Kit.footprint (buildings); each prop's size comes from its live Kit.prop
	bounds, never from WorldPlan.CLEAR, so a prop that grows (or a stale CLEAR.radius) fails here.
	Resource nodes are not dressing: the spec leaves their ids and positions alone (FORGE-01's Kingdom/Layout keeps
	the sim's generated nodes off the fields and zones, FL-0112).
	TODO: switch to FORGE-01's Kingdom/Layout.keepOutAreas() (fields, build zones, slot rects; PR #140) once it merges.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Def = require("@game/ServerScriptService/Game/Services/WorldService")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local ALL = { crimson = true, azure = true, emerald = true, gold = true }
local MARGIN = 4 -- the user's number: studs of open ground between natural dressing and reserved ground
local NATURAL = { forest = true, lone_tree = true, bush = true, rocks = true, flowers = true }

-- reserved ground as rectangles { cf, half, label }, straight from Layout and Kit.footprint
local function reserved()
	local out = {}
	for i, field in Layout.features.fields do
		local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
		table.insert(out, { cf = cf, half = field.size / 2, label = `field {i}`, field = true })
	end
	for _, k in KINGDOMS do
		local plot = Layout.plots[k]
		for name, anchor in plot.anchors do
			local fp = Kit.footprint(name, 99) -- clamps to the largest level: buildings upgrade in place
			table.insert(out, { cf = anchor, half = fp / 2, label = `{k} {name}` })
		end
		for _, slot in plot.buildSlots do
			local cf = CFrame.new(slot.center) * CFrame.Angles(0, slot.rot, 0)
			table.insert(out, { cf = cf, half = Layout.slotSizes[slot.size] / 2, label = slot.id })
		end
		local look = plot.anchors.keep.LookVector
		local yaw = math.atan2(-look.X, -look.Z)
		for _, zone in plot.buildZones do -- plot-local: turned with the keep (FORGE-01's LayoutZones reads them so)
			local cf = CFrame.new(zone.center) * CFrame.Angles(0, yaw, 0)
			table.insert(out, { cf = cf, half = zone.size / 2, label = zone.id, zone = true })
		end
	end
	return out
end

local function rectDistance(rect, x: number, z: number): number
	local p = rect.cf:PointToObjectSpace(Vector3.new(x, rect.cf.Position.Y, z))
	local dx, dz = math.max(0, math.abs(p.X) - rect.half.X), math.max(0, math.abs(p.Z) - rect.half.Y)
	return math.sqrt(dx * dx + dz * dz)
end

-- horizontal radius (studs from the pivot) of a prop's visible parts, from its live Kit.prop model
local radii = {}
local function liveRadius(assetId: string): number
	if radii[assetId] then
		return radii[assetId]
	end
	local model = Kit.prop(assetId)
	local pivot = model.PrimaryPart.CFrame * model.PrimaryPart.PivotOffset
	local r = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.99 then
			local cf = pivot:ToObjectSpace(d.CFrame)
			local _, _, _, r00, r01, r02, r10, _, _, r20, r21, r22 = cf:GetComponents()
			local shape = if d:IsA("Part") then d.Shape.Name else "Block"
			local reach
			if shape == "Ball" then
				reach = d.Size.X / 2
			elseif shape == "Cylinder" and math.abs(r10) > 0.999 then
				reach = math.max(d.Size.Y, d.Size.Z) / 2 -- an upright cylinder: its radius
			else
				local h = d.Size / 2
				local ex = math.abs(r00) * h.X + math.abs(r01) * h.Y + math.abs(r02) * h.Z
				local ez = math.abs(r20) * h.X + math.abs(r21) * h.Y + math.abs(r22) * h.Z
				reach = math.sqrt(ex * ex + ez * ez)
			end
			r = math.max(r, math.sqrt(cf.X * cf.X + cf.Z * cf.Z) + reach)
		end
	end
	radii[assetId] = r
	return r
end

-- items: { { assetId, x, z, feature } }; returns one line per dressing item that stands too close
local function violations(items: { any }): { string }
	local rects = reserved()
	local bad = {}
	for _, item in items do
		if item.feature ~= "bridge" and item.feature ~= "crops" then
			local r = liveRadius(item.assetId)
			local natural = NATURAL[item.feature] == true
			for _, rect in rects do
				-- kingdom dressing (banners, well, cart, goods) is hand-placed in the yard: item may stand close to
				-- buildings, slots and roads, but never on them, and keeps the margin from a field
				local gap = if natural or rect.field then MARGIN else 0
				-- the yard well, banners and goods are meant to stand in the build zones
				if (natural or not rect.zone) and rectDistance(rect, item.x, item.z) < r + gap then
					table.insert(
						bad,
						`{item.assetId} ({item.feature}) at ({math.floor(item.x)}, {math.floor(item.z)}) near {rect.label}`
					)
				end
			end
			for i, road in Layout.features.roads do
				local gap = if natural then MARGIN else 0
				if WorldPlan.distToPolyline(item.x, item.z, road.points) < road.width / 2 + r + gap then
					table.insert(
						bad,
						`{item.assetId} ({item.feature}) at ({math.floor(item.x)}, {math.floor(item.z)}) near road {i}`
					)
				end
			end
		end
	end
	return bad
end

local function itemsOf(placements: { any }): { any }
	local out = {}
	for _, p in placements do
		table.insert(
			out,
			{ assetId = p.assetId, x = p.cframe.Position.X, z = p.cframe.Position.Z, feature = p.feature }
		)
	end
	return out
end

describe("Plot clearance (user playtest, farm areas)", function()
	it(
		"keeps every tree, bush, rock, flower and prop off the fields, buildings, slots and roads of all four plots",
		function()
			local bad = violations(itemsOf(WorldPlan.props(Layout, ALL)))
			expect(table.concat(bad, "; ")).toBe("")
			-- restoring the density knob (phone test) must not bring the clutter back
			bad = violations(itemsOf(WorldPlan.props(Layout, ALL, WorldPlan.FULL_DENSITY)))
			expect(table.concat(bad, "; ")).toBe("")
		end
	)

	it(
		"has the reserved ground it is meant to check (4 plots: 3 fields, 3 zones, 5 buildings and 10 slots each)",
		function()
			local fields, zones, buildings, slots = 0, 0, 0, 0
			for _, rect in reserved() do
				if rect.field then
					fields += 1
				elseif rect.zone then
					zones += 1
				elseif string.find(rect.label, "_slot") then
					slots += 1
				else
					buildings += 1
				end
			end
			expect(fields).toBe(12)
			expect(zones).toBe(12)
			expect(buildings).toBe(20)
			expect(slots).toBe(40)
		end
	)

	it("detects and removes dressing on or beside reserved ground, and only that (WorldPlan.clear)", function()
		local field = Layout.features.fields[1]
		local cf = CFrame.new(field.center.X, 0, field.center.Y) * CFrame.Angles(0, field.yaw or 0, 0)
		local function at(local_x: number, local_z: number, assetId: string, feature: string)
			local p = cf:PointToWorldSpace(Vector3.new(local_x, 0, local_z))
			return { assetId = assetId, cframe = CFrame.new(p), feature = feature }
		end
		local hx, hz = field.size.X / 2, field.size.Y / 2
		local plan = {
			at(0, 0, "tree_oak_01", "forest"), -- in the middle of the field
			at(hx + 2, 0, "rock_boulder_m_01", "rocks"), -- a boulder 2 studs from its edge
			at(0, -hz - 7, "bush_01", "bush"), -- a bush whose body leaves < 4 studs
			at(0, hz + 60, "plant_flowers_01", "flowers"), -- far from the field: stays
		}
		local bad = violations(itemsOf(plan))
		expect(#bad).toBeGreaterThanOrEqual(3) -- the checker sees the first three (and not the far flower)
		local kept = WorldPlan.clear(Layout, plan)
		for _, p in kept do
			expect(p.assetId == "tree_oak_01" or p.assetId == "rock_boulder_m_01" or p.assetId == "bush_01").toBe(false)
		end
		-- a far-away tree, bridges and crops are never touched
		local far = { assetId = "tree_oak_02", cframe = CFrame.new(-480, 0, 60), feature = "lone_tree" }
		expect(#violations(itemsOf({ far }))).toBe(0)
		local bridge =
			{ assetId = "bridge_stone_01", cframe = CFrame.new(field.center.X, 0, field.center.Y), feature = "bridge" }
		local crops = {
			assetId = "farm_field_wheat_01",
			cframe = CFrame.new(field.center.X, 0, field.center.Y),
			feature = "crops",
		}
		local out = WorldPlan.clear(Layout, { far, bridge, crops })
		expect(#out).toBe(3)
	end)

	it("clears natural dressing that only a build zone reserves, and leaves the yard props in the zones", function()
		-- keep-frame (-108, -84): inside reach of the west zone's corner, clear of every field, building, slot and road
		local keep = Layout.plots.crimson.anchors.keep
		local tree = {
			assetId = "tree_oak_01",
			cframe = CFrame.new(keep:PointToWorldSpace(Vector3.new(-108, 0, -84))),
			feature = "forest",
		}
		local bad = violations(itemsOf({ tree }))
		expect(#bad).toBe(1)
		expect(string.find(bad[1], "crimson_west", 1, true)).never.toBeNil()
		expect(#WorldPlan.clear(Layout, { tree })).toBe(0)
		-- the yard well and the gate banners are meant to stand in the build zones: they stay
		local ids = {}
		for _, p in WorldPlan.props(Layout, { crimson = true }) do
			if p.feature == "dressing" then
				ids[p.assetId] = true
			end
		end
		expect(ids.prop_well_01).toBe(true)
		expect(ids.prop_banner_red_01).toBe(true)
	end)

	it("removes only dressing: the cleared plan is the generated plan minus those placements, in order", function()
		local plan = WorldPlan.plan(Layout, ALL)
		local cleared = WorldPlan.props(Layout, ALL, WorldPlan.FULL_DENSITY) -- clearance only, no trim
		expect(#cleared).toBeLessThan(#plan)
		local j = 1
		for _, p in plan do
			local q = cleared[j]
			if q and q.assetId == p.assetId and q.feature == p.feature and q.cframe == p.cframe then
				j += 1
			else
				expect(NATURAL[p.feature] == true or p.feature == "dressing").toBe(true) -- never a bridge or crops
			end
		end
		expect(j).toBe(#cleared + 1)
	end)

	it("sizes CLEAR.radius to the live Kit.prop bounds of every planned asset", function()
		local bad = {}
		for _, p in WorldPlan.plan(Layout, ALL) do
			local live, documented = liveRadius(p.assetId), WorldPlan.footprintRadius(p.assetId)
			if (NATURAL[p.feature] or p.feature == "dressing") and live > documented then
				bad[p.assetId] = `{p.assetId}: live {string.format("%.2f", live)} > CLEAR.radius {documented}`
			end
		end
		local lines = {}
		for _, line in bad do
			table.insert(lines, line)
		end
		table.sort(lines)
		expect(table.concat(lines, "; ")).toBe("")
	end)

	it("places only cleared dressing in the built world (WorldService, all four plots dressed)", function()
		local env = MockEnv.new({ seed = 1 })
		local svc = Def.new(env, nil)
		svc.terrain = Terrain.recorder()
		svc.dressed = table.clone(ALL)
		svc:start()
		env.mock:advance(30)
		expect(svc.stats.error).toBeNil()
		local items = {}
		for _, model in svc:getRoot().Props:GetChildren() do
			local pos = model.PrimaryPart.CFrame.Position
			table.insert(items, { assetId = model.Name, x = pos.X, z = pos.Z, feature = model:GetAttribute("Feature") })
		end
		expect(#items).toBe(svc.stats.props)
		expect(#items).toBeGreaterThan(100)
		expect(table.concat(violations(items), "; ")).toBe("")
		svc:destroy()
	end)
end)
