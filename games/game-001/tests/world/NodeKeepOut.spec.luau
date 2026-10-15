--[[
	World resource nodes keep out of crop fields, build zones and build slots by their DRAWN extent (FL-0124, D-052 (4);
	user playtest 2026-10-13: "farms contain trees and rocks").

	The world layout's per-plot nodes (`<kingdom>_stone1/2`, `_gold1`, `_food1/2`, `_wood1..4`, `heart_*`) are drawn by
	WorldService as Kit.prop models. This spec measures what each model really draws (the live Kit.prop bounds around
	its pivot, not the sim footprint or a guessed radius) and asserts no node touches a crop field, a build zone or a
	build slot, nor stands on a starting building, with the same gap a build slot gets. The plots stay rotated copies
	of each other (per-kingdom fairness, #94): the nodes of two kingdoms differ only by the plot's rotation.

	The areas come from the world layout (`features.fields`, `plots[k].buildZones`, `buildSlots`), turned with the plot
	as FORGE-01's LayoutZones spec reads them. TODO: read them from FORGE-01's Kingdom/Layout.keepOutAreas() once it
	is on main; this spec must not keep a second copy of the geometry.

	The world layout and WorldPlan's decor are deterministic (no seed): this spec has nothing to loop over seeds for.
	The seed-dependent nodes are the sim's generated ones, which FORGE-01's LayoutZones spec checks over seeds 1..20.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")

local KINGDOMS = { "crimson", "azure", "emerald", "gold" }
local GAP = 8 -- studs of open ground between a drawn extent and a field, zone or slot: a clear buffer, not a graze
local BUILDING_GAP = 5 -- and between a drawn extent and a starting building's footprint (largest level)
local STARTING = { "storehouse", "farm", "lumbercamp", "quarry" } -- keep: the keep itself is far from every node

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- crop fields, build zones and build slots of every plot: { name, shape }
local function areas(): { { name: string, shape: any } }
	local out = {}
	for i, field in Layout.features.fields do
		table.insert(out, {
			name = `field {i}`,
			shape = Footprint.rect(field.size, field.center.X, field.center.Y, field.yaw),
		})
	end
	for _, kid in KINGDOMS do
		local plot = Layout.plots[kid]
		local yaw = yawOf(plot.anchors.keep)
		for _, zone in plot.buildZones do
			table.insert(out, {
				name = `{zone.id} zone`,
				shape = Footprint.rect(zone.size, zone.center.X, zone.center.Z, yaw),
			})
		end
		for _, slot in plot.buildSlots do
			table.insert(out, {
				name = slot.id,
				shape = Footprint.rect(Layout.slotSizes[slot.size], slot.center.X, slot.center.Z, slot.rot),
			})
		end
	end
	return out
end

-- horizontal reach of what Kit.prop(assetId) draws around its pivot (a ball counts by its true radius, any other
-- part by its farthest box corner: conservative for a cylinder)
local reachCache: { [string]: number } = {}
local function drawnReach(assetId: string): number
	local cached = reachCache[assetId]
	if cached ~= nil then
		return cached
	end
	local model = Kit.prop(assetId)
	local primary = model.PrimaryPart :: BasePart
	local toLocal = (primary.CFrame * primary.PivotOffset):Inverse()
	local reach = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = toLocal * d.CFrame
			if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
				local c = cf.Position
				reach = math.max(reach, math.sqrt(c.X * c.X + c.Z * c.Z) + d.Size.X / 2)
			else
				local h = d.Size / 2
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = cf * Vector3.new(sx * h.X, 0, sz * h.Z)
						reach = math.max(reach, math.sqrt(w.X * w.X + w.Z * w.Z))
					end
				end
			end
		end
	end
	reachCache[assetId] = reach
	return reach
end

local function nodeById(id: string): any
	for _, n in Layout.resourceNodes do
		if n.id == id then
			return n
		end
	end
	error(`no world node {id}`)
end

describe("World resource nodes keep out of fields, zones and slots by drawn extent (FL-0124)", function()
	it("has the areas the rule is about: 12 crop fields, and 3 zones + 10 slots in each of the 4 plots", function()
		expect(#Layout.features.fields).toBe(12)
		expect(#areas()).toBe(12 + 4 * (3 + 10))
	end)

	it("measures a real extent for every node model (a rock and a tree reach several studs)", function()
		for _, n in Layout.resourceNodes do
			expect(drawnReach(n.assetId)).toBeGreaterThan(2)
		end
	end)

	it("keeps every node's drawn extent clear of every crop field, build zone and build slot", function()
		local list = areas()
		local bad = {}
		for _, n in Layout.resourceNodes do
			local p = n.cframe.Position
			local reach = drawnReach(n.assetId)
			for _, area in list do
				if Footprint.overlapsCircle(area.shape, p.X, p.Z, reach, GAP) then
					table.insert(bad, `{n.id} ({n.assetId}, reach {math.floor(reach * 10) / 10}) touches {area.name}`)
				end
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
	end)

	it("keeps every node's drawn extent off the starting buildings (their footprints at the largest level)", function()
		local bad = {}
		for _, n in Layout.resourceNodes do
			local p = n.cframe.Position
			local reach = drawnReach(n.assetId)
			for _, kid in KINGDOMS do
				for _, name in STARTING do
					local anchor = Layout.plots[kid].anchors[name]
					local shape =
						Footprint.rect(Kit.footprint(name, 9), anchor.Position.X, anchor.Position.Z, yawOf(anchor))
					if Footprint.overlapsCircle(shape, p.X, p.Z, reach, BUILDING_GAP) then
						table.insert(
							bad,
							`{n.id} (reach {math.floor(reach * 10) / 10}) is too close to the {kid} {name}`
						)
					end
				end
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
	end)

	it(
		"keeps the plots rotated copies of each other: every kingdom's nodes sit at the same keep-frame offsets",
		function()
			local base = {}
			for _, n in Layout.resourceNodes do
				local kid = string.match(n.id, "^(%a+)_")
				if kid == "crimson" then
					base[string.sub(n.id, 9)] = (Layout.plots.crimson.anchors.keep:ToObjectSpace(n.cframe)).Position
				end
			end
			local checked = 0
			for _, n in Layout.resourceNodes do
				local kid = string.match(n.id, "^(%a+)_")
				if kid ~= "crimson" and Layout.plots[kid] ~= nil then
					local want = base[string.sub(n.id, #kid + 2)]
					expect(want).never.toBeNil()
					local got = Layout.plots[kid].anchors.keep:ToObjectSpace(n.cframe).Position
					expect((got - want).Magnitude < 0.01).toBe(true)
					checked += 1
				end
			end
			expect(checked).toBe(3 * 9) -- 4 wood, 2 stone, 1 gold, 2 food in each of the other three kingdoms
		end
	)

	it("keeps each node within a gatherer's walk of its nav node, with its work spots around it", function()
		local bad = {}
		for _, n in Layout.resourceNodes do
			local nav = Layout.nav.nodes[n.navNode] -- the plot nodes (the contested heart_* nodes are not FL-0124's)
			local p = n.cframe.Position
			local walk = (Vector3.new(nav.X, 0, nav.Z) - Vector3.new(p.X, 0, p.Z)).Magnitude
			if string.sub(n.id, 1, 6) == "heart_" then
				continue
			end
			if walk >= 75 then
				table.insert(bad, `{n.id} is {math.floor(walk)} studs from its nav node`)
			end
			for _, s in n.workSpots do
				if (s - p).Magnitude >= 6 then
					table.insert(bad, `{n.id} has a work spot {math.floor((s - p).Magnitude)} studs away`)
				end
			end
		end
		expect(table.concat(bad, "; ")).toBe("")
	end)

	it(
		"keeps the scattered decor (WorldPlan, deterministic) off every crop field by its drawn extent (the farm props themselves excepted)",
		function()
			local list = areas()
			local dressed = { crimson = true, azure = true, emerald = true, gold = true }
			for _, pl in WorldPlan.props(Layout, dressed) do
				local p = pl.cframe.Position
				local reach = drawnReach(pl.assetId)
				for _, area in list do
					if
						string.sub(area.name, 1, 5) == "field"
						and string.sub(pl.assetId, 1, 5) ~= "farm_"
						and Footprint.overlapsCircle(area.shape, p.X, p.Z, reach, 0)
					then
						error(`{pl.assetId} at ({math.floor(p.X)}, {math.floor(p.Z)}) draws onto {area.name}`)
					end
				end
			end
		end
	)

	it("moves the world's 20 offending nodes rather than deleting them: the node set is unchanged", function()
		local ids = {}
		for _, n in Layout.resourceNodes do
			ids[n.id] = true
		end
		for _, kid in KINGDOMS do
			for _, r in { "stone1", "stone2", "gold1", "food1", "food2", "wood1", "wood2", "wood3", "wood4" } do
				expect(ids[`{kid}_{r}`]).toBe(true)
			end
		end
		expect(nodeById("heart_stone1").id).toBe("heart_stone1")
	end)
end)
