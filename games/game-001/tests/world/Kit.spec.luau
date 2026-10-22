local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

-- CONTRACTS G2 BuildingType, in contract order.
local BUILDING_TYPES =
	{ "keep", "house", "farm", "storehouse", "lumbercamp", "quarry", "barracks", "watchtower", "wall", "gate" }
local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

-- canonical kingdom colours (config Kingdoms, D-033), keyed by KingdomId
local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local KINGDOM_COLORS = { CANON.crimson, CANON.azure, CANON.emerald, CANON.gold }
local STAGES = { 1, 2, 3, "complete" }
local PRIMITIVE_CLASSES = { Part = true, WedgePart = true, CornerWedgePart = true, Seat = true } -- Seat: keep Throne (G13.6)
local MAX_BUILDING_PARTS = 260 -- per model at levels 1–2; world budget ≤ 25k parts (BRIEF §14)
-- Documented exception: the keep's level 3 (the kingdom centrepiece, one per kingdom) may use up to
-- Buildings.PART_BUDGET.keep = 300 parts; asserted below. Every other model and level stays ≤ 260.
local KEEP_L3_MAX_PARTS = 300

local function parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

local function noYield(fn: () -> any): any
	local co = coroutine.create(fn)
	local ok, result = coroutine.resume(co)
	assert(ok, result)
	assert(coroutine.status(co) == "dead", "function yielded")
	return result
end

describe("Kit.build (G10)", function()
	it("builds every type, level and stage from primitive parts only, without yielding", function()
		for _, bt in BUILDING_TYPES do
			for level = 1, 2 do
				for _, stage in STAGES do
					for _, color in KINGDOM_COLORS do
						local model = noYield(function()
							return Kit.build(bt, level, stage, color)
						end)
						expect(model.ClassName).toBe("Model")
						expect(model.PrimaryPart).never.toBeNil()
						for _, p in parts(model) do
							if not PRIMITIVE_CLASSES[p.ClassName] then
								error(`{bt} L{level} {stage}: non-primitive part {p.ClassName} {p.Name}`)
							end
							expect(p.Anchored).toBe(true)
						end
						for _, d in model:GetDescendants() do
							expect(d:IsA("PartOperation")).toBe(false)
						end
						if #parts(model) > MAX_BUILDING_PARTS then
							error(
								`{bt} L{level} stage {stage} colour {color}: {#parts(model)} parts > {MAX_BUILDING_PARTS}`
							)
						end
					end
				end
			end
		end
	end)

	it("keeps the keep's level 3 within its documented exception (≤ 300 parts) and its stages ≤ 260", function()
		local Buildings = require("@game/ReplicatedStorage/Game/Kit/Buildings")
		expect(Buildings.PART_BUDGET.keep).toBe(KEEP_L3_MAX_PARTS)
		for _, color in KINGDOM_COLORS do
			for _, stage in STAGES do
				local model = Kit.build("keep", 3, stage, color)
				local limit = if stage == "complete" then KEEP_L3_MAX_PARTS else MAX_BUILDING_PARTS
				expect(#parts(model)).toBeLessThanOrEqual(limit)
			end
		end
	end)

	it("puts a Door attachment on every model and WorkSpots on working buildings", function()
		for _, bt in BUILDING_TYPES do
			for _, stage in STAGES do
				local model = Kit.build(bt, 1, stage, KINGDOM_COLORS[1])
				local root = model.PrimaryPart :: BasePart
				expect(root:FindFirstChild("Door")).never.toBeNil()
				expect(root:FindFirstChild("Door").ClassName).toBe("Attachment")
				if bt ~= "wall" and bt ~= "gate" then
					expect(root:FindFirstChild("WorkSpot1")).never.toBeNil()
				end
			end
		end
	end)

	it("adds DropOff to the storehouse and Rally to the barracks in every stage", function()
		for _, stage in STAGES do
			local store = Kit.build("storehouse", 1, stage, KINGDOM_COLORS[2])
			expect((store.PrimaryPart :: BasePart):FindFirstChild("DropOff")).never.toBeNil()
			local barracks = Kit.build("barracks", 1, stage, KINGDOM_COLORS[3])
			expect((barracks.PrimaryPart :: BasePart):FindFirstChild("Rally")).never.toBeNil()
		end
	end)

	it("keeps doors outside the footprint so units can path to them", function()
		for _, bt in BUILDING_TYPES do
			local fp = Kit.footprint(bt, 1)
			local model = Kit.build(bt, 1, "complete", KINGDOM_COLORS[1])
			local door = (model.PrimaryPart :: BasePart):FindFirstChild("Door") :: Attachment
			local p = door.CFrame.Position
			local inside = math.abs(p.X) < fp.X / 2 - 0.5 and math.abs(p.Z) < fp.Y / 2 - 0.5
			expect(inside).toBe(false)
		end
	end)

	it("rejects unknown types and bad stages", function()
		expect(function()
			Kit.build("castle", 1, "complete", KINGDOM_COLORS[1])
		end).toThrow("unknown building type")
		expect(function()
			Kit.build("house", 1, 4, KINGDOM_COLORS[1])
		end).toThrow("stage")
	end)
end)

describe("Kit.footprint", function()
	it("returns a positive Vector2 for every type and clamps levels", function()
		for _, bt in BUILDING_TYPES do
			local fp = Kit.footprint(bt, 1)
			expect(fp.X).toBeGreaterThan(0)
			expect(fp.Y).toBeGreaterThan(0)
			expect(Kit.footprint(bt, 99)).toEqual(Kit.footprint(bt, 99))
		end
		expect(Kit.footprint("keep", 2).X).toBeGreaterThan(Kit.footprint("keep", 1).X)
	end)
end)

-- Kit.build clamps the level it is given and STORES the clamped level (the model attribute KitLevel, the model's name): a level the Kit
-- has no look for is the highest it has (below 1, or not a number: 1). Kit.applyDamage seeds its marks by KitLevel, so a wall asked
-- for at level 5 is a level 3 wall in every way a consumer can see.
local TOP_LEVEL = {
	keep = 3,
	house = 2,
	farm = 3,
	storehouse = 2,
	lumbercamp = 3,
	quarry = 3,
	barracks = 4,
	watchtower = 2,
	wall = 3,
	gate = 3,
	mine = 1,
	blacksmith = 1,
	market = 1,
	infirmary = 1,
	granary = 1,
	shrine = 1,
}

local function levelViolations(): { string }
	local out: { string } = {}
	for _, bt in Kit.BUILDING_TYPES do
		if Kit.MAX_LEVEL[bt] ~= TOP_LEVEL[bt] then
			table.insert(out, `{bt}: Kit.MAX_LEVEL {Kit.MAX_LEVEL[bt]}, want {TOP_LEVEL[bt]}`)
		end
		for _, asked in { -3, 0, 0.5, 1, 2, 3, 4, 5, 99, 2.7, 0 / 0 } do
			local want = if asked ~= asked then 1 else math.clamp(math.floor(asked), 1, TOP_LEVEL[bt])
			local model = Kit.build(bt, asked, "complete", KINGDOM_COLORS[1])
			if model:GetAttribute("KitLevel") ~= want then
				table.insert(
					out,
					`{bt} asked for level {asked}: KitLevel {model:GetAttribute("KitLevel")}, want {want}`
				)
			end
			if string.find(model.Name, `_L{want}_`, 1, true) == nil then
				table.insert(out, `{bt} asked for level {asked}: named {model.Name}, want level {want}`)
			end
		end
	end
	return out
end

describe("Kit.build stores the level that was built (KitLevel)", function()
	it("clamps the stored level for every type", function()
		local out = levelViolations()
		if #out > 0 then
			error(`{#out} violations, e.g. ` .. table.concat(out, "; ", 1, math.min(#out, 6)))
		end
	end)
	it("catches a build that stores the level it was asked for (a wall asked for at level 5 stored 5)", function()
		local build = Kit.build
		Kit.build = function(bt, level, ...)
			local model = build(bt, level, ...)
			model:SetAttribute("KitLevel", level)
			return model
		end
		local out = levelViolations()
		Kit.build = build
		expect(#out > 0).toBe(true)
	end)
end)

describe("Kit.setKingdomColor", function()
	it("recolours tinted parts in place and leaves the rest", function()
		local model = Kit.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR)
		local before = {}
		for _, p in parts(model) do
			before[p] = p.Color
		end
		Kit.setKingdomColor(model, KINGDOM_COLORS[1])
		local changed, kept = 0, 0
		for _, p in parts(model) do
			if p:GetAttribute("KitTint") ~= nil then
				if p.Color ~= before[p] then
					changed += 1
				end
			elseif p.Color == before[p] then
				kept += 1
			end
		end
		expect(changed).toBeGreaterThan(2)
		expect(kept).toBeGreaterThan(10)
	end)
end)

describe("Kit.character (≤ Kit.CHARACTER_MAX_PARTS (9) parts, D-026 as amended by D-032)", function()
	local JOBS = { "idle", "farmer", "woodcutter", "miner", "builder", "hauler", "soldier" }
	it("builds rigs of at most 9 non-colliding parts joined by Motor6Ds named after the moving part", function()
		for _, kind in { "citizen", "soldier", "governor" } do
			for _, job in JOBS do
				local rig = noYield(function()
					return Kit.character(kind, job, KINGDOM_COLORS[2])
				end)
				local ps = parts(rig)
				expect(#ps).toBeLessThanOrEqual(Kit.CHARACTER_MAX_PARTS)
				expect(rig.PrimaryPart).never.toBeNil()
				expect((rig.PrimaryPart :: BasePart).Anchored).toBe(true)
				for _, p in ps do
					expect(p.CanCollide).toBe(false)
					expect(p.CanTouch).toBe(false)
					expect(p.CanQuery).toBe(false)
				end
				local motors, welded = 0, 0
				for _, d in rig:GetDescendants() do
					if d:IsA("Motor6D") then
						motors += 1
						expect(d.Name).toBe((d.Part1 :: BasePart).Name)
						expect((d.Part1 :: BasePart).Name).never.toBe("Hair")
						expect((d.Part1 :: BasePart).Name).never.toBe("Accessory")
						expect((d.Part1 :: BasePart):GetAttribute("KitDetail")).toBeNil()
					elseif d:IsA("Weld") or d:IsA("WeldConstraint") then
						-- D-032: headwear (Hair) is welded to the Head, never motored
						-- headwear and accessories weld to the Head; D-048 detail parts to the Head or the Tool
						local name = (d.Part1 :: BasePart).Name
						if name == "Detail1" or name == "Detail2" then
							expect(d.Part0 == rig:FindFirstChild("Head") or d.Part0 == rig:FindFirstChild("Tool")).toBe(
								true
							)
						else
							expect(d.Part0).toBe(rig:FindFirstChild("Head"))
							expect(table.find({ "Hair", "Accessory" }, name)).never.toBeNil()
						end
						welded += 1
					end
					expect(d:IsA("Humanoid")).toBe(false)
					expect(d:IsA("Animator")).toBe(false)
				end
				expect(welded).toBe(
					(if rig:FindFirstChild("Hair") then 1 else 0)
						+ (if rig:FindFirstChild("Accessory") then 1 else 0)
						+ (if rig:FindFirstChild("Detail1") then 1 else 0)
						+ (if rig:FindFirstChild("Detail2") then 1 else 0)
				)
				expect(motors).toBe(#ps - 1 - welded)
			end
		end
	end)

	it("is about 5.5 studs tall (Roblox character scale), 5.97 with the silhouette pass's bigger head", function()
		local rig = Kit.character("citizen", "farmer", KINGDOM_COLORS[1])
		local top, bottom = -math.huge, math.huge
		for _, p in parts(rig) do
			if p.Name ~= "Tool" and p.Name ~= "Hair" and p:GetAttribute("KitDetail") == nil then -- the body: a hat, crest or detail may rise above the head
				top = math.max(top, p.CFrame.Position.Y + p.Size.Y / 2)
				bottom = math.min(bottom, p.CFrame.Position.Y - p.Size.Y / 2)
			end
		end
		expect(top - bottom).toBeNear(5.97, 0.2) -- 5.5 before the silhouette pass 2: the head is drawn Kit.CHARACTER_HEAD_SCALE x bigger and sits 0.07 higher
	end)
end)

describe("Kit.regalia", function()
	it("returns a crown on HatAttachment and a cape on BodyBackAttachment", function()
		local acc = Kit.regalia(KINGDOM_COLORS[4])
		expect(#acc).toBe(2)
		local names = {}
		for _, a in acc do
			expect(a.ClassName).toBe("Accessory")
			local handle = a:FindFirstChild("Handle")
			expect(handle).never.toBeNil()
			for _, c in (handle :: Instance):GetChildren() do
				if c:IsA("Attachment") then
					names[c.Name] = true
				end
			end
		end
		expect(names.HatAttachment).toBe(true)
		expect(names.BodyBackAttachment).toBe(true)
	end)
end)

describe("Kit.prop and Kit.regionMarkers", function()
	it("returns a part-built stand-in when no mesh is registered", function()
		for _, id in
			{ "tree_oak_01", "tree_pine_02", "resource_stone_01", "resource_wood_01", "bush_03", "prop_goods_01" }
		do
			local m = Kit.prop(id)
			expect(m.ClassName).toBe("Model")
			expect(m:GetAttribute("KitStandIn")).toBe(true)
			expect(#parts(m)).toBeGreaterThan(1)
		end
	end)

	it("clones a registered asset when present", function()
		local folder = Instance.new("Folder")
		local mesh = Instance.new("Model")
		-- an id the nature mesh kit does not list (Kit/EnvMeshData), so no size sanity applies: a listed id is tested in KitEnvMesh.spec
		mesh.Name = "prop_goods_01"
		local p = Instance.new("Part")
		p.Parent = mesh
		mesh.Parent = folder
		Kit.setAssetSource(folder)
		local m = Kit.prop("prop_goods_01")
		Kit.setAssetSource(nil)
		expect(m:GetAttribute("KitStandIn")).toBeNil()
		expect(m.Name).toBe("prop_goods_01")
	end)

	it("plants flags along a region polygon in the kingdom colour", function()
		local poly = { Vector2.new(0, 0), Vector2.new(100, 0), Vector2.new(100, 100), Vector2.new(0, 100) }
		local m = Kit.regionMarkers(poly, KINGDOM_COLORS[3])
		local flags = 0
		for _, p in parts(m) do
			if p.Name == "Flag" then
				flags += 1
				expect(p.Color).toEqual(KINGDOM_COLORS[3])
			end
		end
		expect(flags).toBe(8)
	end)
end)

describe("Banner props carry the canonical kingdom colours (D-033)", function()
	-- Blender asset names (prop_banner_<red|blue|green|yellow>_NN) map to KingdomIds; a missing key would
	-- silently fall back to another kingdom's colour
	local BANNER_KINGDOM = { red = "crimson", blue = "azure", green = "emerald", yellow = "gold" }

	local function bannerColor(name: string): Color3?
		local model = Kit.prop(`prop_banner_{name}_01`)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Banner" then
				return d.Color
			end
		end
		return nil
	end

	for name, id in BANNER_KINGDOM do
		it(`colours prop_banner_{name} with the {id} kingdom colour`, function()
			local got, want = bannerColor(name), CANON[id]
			expect(want).never.toBeNil()
			expect(got).never.toBeNil()
			local gotV = Vector3.new((got :: Color3).R, (got :: Color3).G, (got :: Color3).B)
			expect((gotV - Vector3.new(want.R, want.G, want.B)).Magnitude).toBeLessThan(1e-3)
		end)
	end
end)
