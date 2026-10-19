--!nonstrict
--[[
	Resource node markers (FL-0136 phase 3 (A), FORGE-00 decision 4: nodes readable at the 170-stud aerial camera, VISUAL ONLY).
	WorldService puts Kit.nodeMarker on every resource node it places: a post and a glowing orb in the resource's colour, 2 parts, standing
	above the node's highest drawn point. HEADLESS (Lune): the meshes are fake import Models of the real kit's data; nothing here says it
	looks right or reads in Studio (the Blender renders in art/reviews/env-mesh.md "Phase 3" are the look evidence).

	The rule, and why each clause:
	  * every node of every resource (stone, gold, wood = a tree, food = a berry bush) has the marker, on the part-built stand-in and on an
	    accepted imported mesh alike; no decor does (the same tree or bush ids stand in the forests and carry no marker);
	  * at most Props.NODE_MARKER_PARTS (2) parts, in the resource's colour, the four colours distinct, none collidable, touchable or queryable
	    (selection and placement rays pass through; units walk through);
	  * it never widens a node: the marker's reach is inside the node's drawn reach (the NodeKeepOut measure), so the keep-out rules and the
	    plot clearance hold unchanged, and Layout (positions, work spots) is not touched (FORGE-01's);
	  * idempotent; an unknown resource adds nothing.
	`violations` is the rule as code; the mutants below prove it catches each way of breaking it.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local WorldDef = require("@game/ServerScriptService/Game/Services/WorldService")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local Data = require("@game/ReplicatedStorage/Game/Kit/EnvMeshData")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Props = require("@game/ReplicatedStorage/Game/Kit/Props")

local EnvKit = require("./fixtures/EnvMeshKit")

afterEach(function()
	EnvKit.uninstall()
end)

local RESOURCES = { "stone", "gold", "wood", "food" }

local function markerParts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("KitNodeMarker") ~= nil then
			table.insert(out, d)
		end
	end
	return out
end

-- horizontal reach of what a prop draws around its pivot, the NodeKeepOut.spec measure (a ball by its true radius, any other part by its
-- farthest box corner); `skipMarker` leaves the marker out (the node's own reach)
local function reachOf(model: Model, skipMarker: boolean?): number
	local primary = model.PrimaryPart :: BasePart
	local toLocal = (primary.CFrame * primary.PivotOffset):Inverse()
	local reach = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and not (skipMarker and d:GetAttribute("KitNodeMarker") ~= nil) then
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
	return reach
end

local function topOf(model: Model, skipMarker: boolean): number
	local primary = model.PrimaryPart :: BasePart
	local toLocal = (primary.CFrame * primary.PivotOffset):Inverse()
	local top = 0
	for _, d in model:GetDescendants() do
		if
			d:IsA("BasePart")
			and d.Transparency < 0.99
			and not (skipMarker and d:GetAttribute("KitNodeMarker") ~= nil)
		then
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						top = math.max(top, (toLocal * d.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)).Y)
					end
				end
			end
		end
	end
	return top
end

local function sameColor(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.01
end

-- The rule as code: every way the marker on `model` (a node of `resource`, whose own drawn reach is `nodeReach`) breaks it.
local function violations(model: Model, resource: string, nodeReach: number): { string }
	local bad = {}
	local parts = markerParts(model)
	if #parts == 0 then
		return { "no marker" }
	end
	if #parts > Props.NODE_MARKER_PARTS then
		table.insert(bad, `{#parts} marker parts, the budget is {Props.NODE_MARKER_PARTS}`)
	end
	local orbs = 0
	for _, part in parts do
		if part.CanCollide or part.CanTouch or part.CanQuery then
			table.insert(
				bad,
				`{part.Name} is not visual only (CanCollide {part.CanCollide}, CanTouch {part.CanTouch}, CanQuery {part.CanQuery})`
			)
		end
		if part:GetAttribute("KitNodeMarker") ~= resource then
			table.insert(
				bad,
				`{part.Name} is marked for {tostring(part:GetAttribute("KitNodeMarker"))}, not {resource}`
			)
		end
		if part.Name == "NodeMarkerOrb" then
			orbs += 1
			if not sameColor(part.Color, Props.NODE_MARKER_COLORS[resource]) then
				table.insert(bad, `the orb is not the {resource} colour`)
			end
			if part.Material ~= Enum.Material.Neon then
				table.insert(bad, "the orb does not glow (Neon)")
			end
		end
	end
	if orbs ~= 1 then
		table.insert(bad, `{orbs} orbs, one wanted`)
	end
	local reach = 0
	do
		local primary = model.PrimaryPart :: BasePart
		local toLocal = (primary.CFrame * primary.PivotOffset):Inverse()
		for _, part in parts do
			local c = (toLocal * part.CFrame).Position
			local r = if part:IsA("Part") and part.Shape == Enum.PartType.Ball
				then part.Size.X / 2
				else math.max(part.Size.Y, part.Size.Z) / 2
			reach = math.max(reach, math.sqrt(c.X * c.X + c.Z * c.Z) + r)
		end
	end
	if reach > nodeReach then
		table.insert(
			bad,
			`the marker reaches {math.floor(reach * 100) / 100} studs, the node {math.floor(nodeReach * 100) / 100}`
		)
	end
	local top = topOf(model, true)
	local post = nil
	for _, part in parts do
		if part.Name == "NodeMarkerPost" then
			post = part
		end
	end
	if post == nil then
		table.insert(bad, "no post")
	else
		local primary = model.PrimaryPart :: BasePart
		local pivot = primary.CFrame * primary.PivotOffset
		local postTop = (pivot:Inverse() * post.CFrame).Position.Y + post.Size.X / 2 -- an upright cylinder runs along its X axis
		if postTop < top + Props.NODE_MARKER_LIFT - 0.05 then
			table.insert(
				bad,
				`the post tops out at {math.floor(postTop * 10) / 10}, below the node's {math.floor(top * 10) / 10} + {Props.NODE_MARKER_LIFT}`
			)
		end
	end
	return bad
end

local function markNode(model: Model, resource: string): Model
	expect(Kit.nodeMarker(model, resource)).toBe(true)
	return model
end

-- one node per (assetId, resource) the layout uses
local function nodeKinds(): { { assetId: string, resource: string } }
	local seen, out = {}, {}
	for _, n in Layout.resourceNodes do
		local key = `{n.assetId}|{n.resource}`
		if not seen[key] then
			seen[key] = true
			table.insert(out, { assetId = n.assetId, resource = n.resource })
		end
	end
	return out
end

describe("resource node markers (FL-0136 phase 3)", function()
	it("covers all four resources with distinct colours", function()
		for _, r in RESOURCES do
			expect(Props.NODE_MARKER_COLORS[r]).never.toBeNil()
		end
		for i, a in RESOURCES do
			for j, b in RESOURCES do
				if i < j then
					local ca, cb = Props.NODE_MARKER_COLORS[a], Props.NODE_MARKER_COLORS[b]
					expect(math.abs(ca.R - cb.R) + math.abs(ca.G - cb.G) + math.abs(ca.B - cb.B)).toBeGreaterThan(0.45)
				end
			end
		end
		local kinds = {}
		for _, k in nodeKinds() do
			kinds[k.resource] = true
		end
		expect(kinds.stone and kinds.gold and kinds.wood and kinds.food).toBe(true) -- the four node families the world really has
	end)

	it("puts a rule-keeping marker on every node's part-built stand-in", function()
		for _, k in nodeKinds() do
			local model = Kit.prop(k.assetId)
			local reach = reachOf(model)
			markNode(model, k.resource)
			expect(table.concat(violations(model, k.resource, reach), "; ")).toBe("")
			expect(#markerParts(model)).toBe(Props.NODE_MARKER_PARTS)
		end
	end)

	it("puts the same marker on an accepted imported mesh", function()
		EnvKit.install(Data, EnvKit.assets(Data, { folder = true }))
		for _, k in nodeKinds() do
			local model = Kit.prop(k.assetId)
			expect(model:GetAttribute("KitEnvMesh")).toBe(true) -- the mesh, not the stand-in
			local reach = reachOf(model)
			markNode(model, k.resource)
			expect(table.concat(violations(model, k.resource, reach), "; ")).toBe("")
		end
	end)

	it("never widens a node: its reach is inside the smallest node's drawn reach, mesh or stand-in", function()
		local orb = Props.NODE_MARKER_ORB / 2
		for _, k in nodeKinds() do
			local standIn = reachOf(Kit.prop(k.assetId))
			expect(orb).toBeLessThan(standIn) -- NodeKeepOut's measure of the node does not change
			EnvKit.install(Data, EnvKit.assets(Data, { folder = true }))
			local mesh = reachOf(Kit.prop(k.assetId))
			EnvKit.uninstall()
			expect(orb).toBeLessThan(mesh)
		end
	end)

	it("is idempotent, and an unknown resource or a model without a Root adds nothing", function()
		local model = Kit.prop("resource_stone_01")
		markNode(model, "stone")
		local first = #markerParts(model)
		expect(Kit.nodeMarker(model, "stone")).toBe(true)
		expect(#markerParts(model)).toBe(first)
		local other = Kit.prop("resource_stone_01")
		expect(Kit.nodeMarker(other, "iron")).toBe(false)
		expect(Kit.nodeMarker(other, "")).toBe(false)
		expect(#markerParts(other)).toBe(0)
		expect(other:GetAttribute("KitNodeMarker")).toBeNil()
		local bare = Instance.new("Model")
		expect(Kit.nodeMarker(bare, "stone")).toBe(false)
	end)

	it("keeps the marker where the node's pivot is, whatever the Root's CFrame is", function()
		-- an import may leave the Root off the origin: the marker follows the pivot (Root.CFrame * PivotOffset), not the origin
		EnvKit.install(Data, EnvKit.assets(Data, { folder = true }))
		local model = Kit.prop("resource_ore_03")
		local root = model.PrimaryPart :: BasePart
		local shift = CFrame.new(40, 3, -12) * CFrame.Angles(0, 1.1, 0)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = shift * d.CFrame
			end
		end
		markNode(model, "gold")
		local pivot = root.CFrame * root.PivotOffset
		for _, part in markerParts(model) do
			local c = (pivot:Inverse() * part.CFrame).Position
			expect(math.sqrt(c.X * c.X + c.Z * c.Z)).toBeLessThan(0.01)
		end
		expect(table.concat(violations(model, "gold", reachOf(model, true)), "; ")).toBe("")
	end)
end)

describe("the world's nodes carry the marker, nothing else does", function()
	local function boot(withMeshes: boolean)
		local env = MockEnv.new({ seed = 1 })
		if withMeshes then
			local forge = Instance.new("Folder")
			forge.Name = "Forge"
			forge.Parent = env.ReplicatedStorage
			EnvKit.assets(Data, { folder = true }).Parent = forge
			EnvKit.install(Data, nil)
		end
		local svc = WorldDef.new(env, nil)
		svc.terrain = Terrain.recorder()
		svc:start()
		env.mock:advance(30)
		expect(svc.stats.error).toBeNil()
		return env, svc
	end

	for _, withMeshes in { false, true } do
		it(
			`marks all 38 resource nodes and no decor ({if withMeshes then "imported meshes" else "part-built stand-ins"})`,
			function()
				local _, svc = boot(withMeshes)
				local root = svc:getRoot()
				local nodes = root:FindFirstChild("ResourceNodes"):GetChildren()
				expect(#nodes).toBe(38)
				local byResource = {}
				for _, model in nodes do
					local resource = model:GetAttribute("Resource")
					byResource[resource] = (byResource[resource] or 0) + 1
					expect(model:GetAttribute("KitNodeMarker")).toBe(resource)
					expect(#markerParts(model)).toBe(Props.NODE_MARKER_PARTS)
					if withMeshes then
						expect(model:GetAttribute("KitEnvMesh")).toBe(true)
					end
				end
				expect(byResource.wood).toBe(16) -- 4 plots x 4 trees
				expect(byResource.stone).toBe(9) -- 4 x 2 + the heartland's
				expect(byResource.gold).toBe(5) -- 4 + the heartland's
				expect(byResource.food).toBe(8) -- 4 x 2
				-- the forests, lone trees and bushes (same asset ids as the wood and food nodes) have none
				for _, model in root:FindFirstChild("Props"):GetChildren() do
					expect(model:GetAttribute("KitNodeMarker")).toBeNil()
				end
				svc:destroy()
			end
		)
	end

	it("adds exactly 2 parts per node and moves nothing in Layout", function()
		local before = {}
		for _, n in Layout.resourceNodes do
			before[n.id] = { n.cframe.Position, #n.workSpots, n.assetId, n.resource }
		end
		local _, svc = boot(false)
		local root = svc:getRoot()
		local markers = 0
		for _, model in root:FindFirstChild("ResourceNodes"):GetChildren() do
			markers += #markerParts(model)
		end
		expect(markers).toBe(2 * 38)
		-- the layout (FORGE-01's) is as it was: 38 nodes, 3 work spots each, 5 studs from the pivot (7 to 10 in the heartland)
		local n = 0
		for _, node in Layout.resourceNodes do
			n += 1
			local was = before[node.id]
			expect((was[1] - node.cframe.Position).Magnitude).toBe(0)
			expect(#node.workSpots).toBe(3)
			for _, spot in node.workSpots do
				local d = (spot - node.cframe.Position).Magnitude
				expect(d).toBeGreaterThanOrEqual(5 - 0.001)
				expect(d).toBeLessThanOrEqual(10.001)
			end
		end
		expect(n).toBe(38)
		svc:destroy()
	end)
end)

describe("the rule catches each way of breaking it (mutants)", function()
	local function fresh(resource: string, assetId: string): (Model, number)
		local model = Kit.prop(assetId)
		local reach = reachOf(model)
		markNode(model, resource)
		return model, reach
	end

	it("flags a third marker part", function()
		local model, reach = fresh("stone", "resource_stone_01")
		local extra = Instance.new("Part")
		extra.Name = "NodeMarkerExtra"
		extra:SetAttribute("KitNodeMarker", "stone")
		extra.CanCollide, extra.CanTouch, extra.CanQuery = false, false, false
		extra.Parent = model
		local why = table.concat(violations(model, "stone", reach), "; ")
		expect(string.find(why, "marker parts", 1, true) ~= nil).toBe(true)
	end)

	it("flags a collidable, queryable or touchable marker part", function()
		for _, flag in { "CanCollide", "CanQuery", "CanTouch" } do
			local model, reach = fresh("gold", "resource_ore_03")
			local part = markerParts(model)[1];
			(part :: any)[flag] = true
			expect(string.find(table.concat(violations(model, "gold", reach), "; "), "visual only", 1, true) ~= nil).toBe(
				true
			)
		end
	end)

	it("flags a marker that widens the node", function()
		local model, reach = fresh("food", "bush_03")
		for _, part in markerParts(model) do
			if part.Name == "NodeMarkerOrb" then
				part.CFrame = part.CFrame + Vector3.new(reach + 1, 0, 0)
			end
		end
		expect(string.find(table.concat(violations(model, "food", reach), "; "), "reaches", 1, true) ~= nil).toBe(true)
	end)

	it("flags the wrong colour, a dull orb and a marker for another resource", function()
		local model, reach = fresh("gold", "resource_ore_03")
		for _, part in markerParts(model) do
			if part.Name == "NodeMarkerOrb" then
				part.Color = Props.NODE_MARKER_COLORS.stone
			end
		end
		expect(string.find(table.concat(violations(model, "gold", reach), "; "), "colour", 1, true) ~= nil).toBe(true)
		local dull, r2 = fresh("wood", "tree_oak_01")
		for _, part in markerParts(dull) do
			if part.Name == "NodeMarkerOrb" then
				part.Material = Enum.Material.SmoothPlastic
			end
		end
		expect(string.find(table.concat(violations(dull, "wood", r2), "; "), "glow", 1, true) ~= nil).toBe(true)
		local other, r3 = fresh("stone", "resource_stone_01")
		expect(#violations(other, "gold", r3) > 0).toBe(true)
	end)

	it("flags a post that stops below the node, and a node with no marker", function()
		local model, reach = fresh("wood", "tree_pine_02")
		for _, part in markerParts(model) do
			if part.Name == "NodeMarkerPost" then
				part.Size = Vector3.new(part.Size.X / 4, part.Size.Y, part.Size.Z)
			end
		end
		expect(string.find(table.concat(violations(model, "wood", reach), "; "), "post", 1, true) ~= nil).toBe(true)
		local bare = Kit.prop("tree_pine_02")
		expect(violations(bare, "wood", reachOf(bare))[1]).toBe("no marker")
	end)
end)
