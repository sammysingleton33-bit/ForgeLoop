--[[
	Sim/WorldView in the game's Kit mode (G6/G10, FL-0051 visuals): every building is FORGE-02's
	Kit.build model at the building's position and facing, replaced whole as its stage advances; the
	starting buildings stand at the world Layout's plot anchors; footprints come from Kit.footprint.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Catalog = require("@game/ReplicatedStorage/Game/Sim/Catalog")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local Match = require("@game/ReplicatedStorage/Game/Kingdom/Match")
local WorldView = require("@game/ReplicatedStorage/Game/Sim/WorldView")

local function world()
	local env = MockEnv.new({ seed = 2 })
	local match = Match.new({ random = Random.new(4), mode = "slice" })
	match:join(1)
	match:update(1 / 16)
	local view = WorldView.new(env, { buildings = "kit", entities = false, createGround = false })
	view:sync(match.sim)
	return env, match, view
end

local function pivotOf(model)
	local root = model.PrimaryPart
	return root.CFrame * root.PivotOffset
end

describe("Sim/WorldView Kit buildings", function()
	it("draws every building as a Kit model at its position and facing, tagged for selection", function()
		local _, match, view = world()
		local sim = match.sim
		for _, id in sim.buildingOrder do
			local b = sim.buildings[id]
			local model = view:find("building", id)
			expect(model.ClassName).toBe("Model")
			expect(model:GetAttribute("BuildingId")).toBe(id)
			expect(model:GetAttribute("Kind")).toBe(b.kind)
			expect(model:GetAttribute("KingdomId")).toBe(b.kingdomId)
			local pivot = pivotOf(model)
			expect((pivot.Position - Vector3.new(b.x, 0, b.z)).Magnitude < 1e-3).toBe(true)
			local look = pivot.LookVector
			local yaw = math.atan2(-look.X, -look.Z)
			local d = (yaw - b.yaw) % (2 * math.pi)
			expect(math.min(d, 2 * math.pi - d) < 1e-3).toBe(true)
		end
	end)

	it("starts each kingdom with keep, storehouse, farm, lumber camp and quarry at the plot anchors", function()
		local _, match = world()
		local sim = match.sim
		for _, kid in sim.kingdomOrder do
			local anchors = Layout.WORLD.plots[kid].anchors
			local found = {}
			for _, id in sim.kingdoms[kid].buildingIds do
				local b = sim.buildings[id]
				local anchor = anchors[b.kind]
				expect(anchor).toBeTruthy()
				expect((anchor.Position - Vector3.new(b.x, 0, b.z)).Magnitude < 1e-6).toBe(true)
				expect(b.level).toBe(1)
				found[b.kind] = true
			end
			for _, kind in { "keep", "storehouse", "farm", "lumbercamp", "quarry" } do
				expect(found[kind]).toBe(true)
			end
		end
	end)

	it("takes placement footprints from Kit.footprint (G6)", function()
		local catalog = Catalog.default()
		for _, kind in Kit.BUILDING_TYPES do
			local def = catalog.buildings[kind]
			if def then
				local size = Kit.footprint(kind, 1)
				expect(def.footprint).toBe(math.max(size.X, size.Y) / 2)
			end
		end
	end)

	it("replaces a site's model as it goes through stages 1, 2, 3 and complete", function()
		local _, match, view = world()
		local sim = match.sim
		local k = sim.kingdoms.crimson
		local keep = sim.buildings[k.keepId]
		local house
		for radius = 40, 140, 10 do
			for step = 0, 23 do
				local a = step / 24 * 2 * math.pi
				local x, z = keep.x + math.cos(a) * radius, keep.z + math.sin(a) * radius
				if house == nil and sim:canPlace(k, "house", x, z) then
					house = assert(sim:placeBuilding(k, "house", x, z, 1))
				end
			end
		end
		assert(house, "no spot for a house")
		view:sync(sim)
		local stages, models = {}, {}
		local last = nil
		for _ = 1, 160 * 16 do
			sim:step()
			view:sync(sim)
			local stage = WorldView.stageOf(sim, house)
			if stage ~= last then
				table.insert(stages, stage)
				table.insert(models, view:find("building", house.id))
				last = stage
			end
			if stage == "complete" then
				break
			end
		end
		expect(stages).toEqual({ 1, 2, 3, "complete" })
		for i = 2, #models do
			expect(rawequal(models[i], models[i - 1])).toBe(false) -- replaced whole, never patched
			expect(models[i - 1].Parent).toBeNil()
		end
		expect(view:find("building", house.id):GetAttribute("Level")).toBe(1)
	end)

	it("rebuilds a building that changes kingdom in the new kingdom's colour and folder (Kit emblems)", function()
		local _, match, view = world()
		local sim = match.sim
		local crimson, azure = sim.kingdoms.crimson, sim.kingdoms.azure
		local farm
		for _, id in crimson.buildingIds do
			if sim.buildings[id].kind == "farm" then
				farm = sim.buildings[id]
			end
		end
		assert(farm, "crimson starts with a farm")
		local before = assert(view:find("building", farm.id))
		view:sync(sim)
		expect(rawequal(view:find("building", farm.id), before)).toBe(true) -- nothing changed: kept
		-- the farm passes to azure
		table.remove(crimson.buildingIds, table.find(crimson.buildingIds, farm.id))
		table.insert(azure.buildingIds, farm.id)
		farm.kingdomId = "azure"
		view:sync(sim)
		local after = assert(view:find("building", farm.id))
		expect(rawequal(after, before)).toBe(false) -- rebuilt, never recoloured in place
		expect(before.Parent).toBeNil()
		expect(after:GetAttribute("KingdomId")).toBe("azure")
		expect(after.Parent.Parent.Name).toBe("azure") -- <kingdomId>/Buildings/building:<id>
		local fresh = Kit.build("farm", farm.level, "complete", Color3.fromRGB(table.unpack(azure.color)))
		expect(#after:GetDescendants()).toBe(#fresh:GetDescendants()) -- what a fresh azure farm is made of
		fresh:Destroy()
	end)

	it("marks a building a riot burns with Burning = true, and clears it when the fire ends (FL-0082)", function()
		local env, match, view = world()
		local sim = match.sim
		local farm
		for _, id in sim.kingdoms.crimson.buildingIds do
			if sim.buildings[id].kind == "farm" then
				farm = sim.buildings[id]
			end
		end
		assert(farm, "crimson starts with a farm")
		expect(view:find("building", farm.id):GetAttribute("Burning")).toBeNil()
		farm.burning = true
		view:sync(sim)
		expect(view:find("building", farm.id):GetAttribute("Burning")).toBe(true)
		farm.burning = nil
		view:sync(sim)
		expect(view:find("building", farm.id):GetAttribute("Burning")).toBeNil()
		-- the placeholder parts view carries it too
		local parts = WorldView.new(env, { entities = false, createGround = false })
		farm.burning = true
		parts:sync(sim)
		expect(parts:find("building", farm.id):GetAttribute("Burning")).toBe(true)
		farm.burning = nil
		parts:sync(sim)
		expect(parts:find("building", farm.id):GetAttribute("Burning")).toBeNil()
	end)
end)
