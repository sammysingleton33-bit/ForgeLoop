--[[
	FL-0136 comparison round, source S3 (the current part-built Kit): serialises the subjects of the comparison
	(keep L1 / L3, house, barracks, watchtower in two hues; trees, boulder and wheat field props) to JSON for
	blender/scripts/envkit_compare.py, in the same format as games/game-001/tests/world/KitDump.spec.luau.
	Read-only over the game's Kit; nothing in the game is changed. Run from the repository root:
	  FORGE_ENV_DUMP=/tmp/env_s3.json lune run roblox/tests/harness/run.luau \
	    --project games/game-001/default.project.json --specs blender/scripts/lune EnvDump
]]

local T = require("../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end

local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function serialise(model: Instance)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = { d.CFrame:GetComponents() }
			for i, v in cf do
				cf[i] = round(v)
			end
			table.insert(parts, {
				name = d.Name,
				class = if d.ClassName == "Seat" then "Part" else d.ClassName,
				shape = if d.ClassName == "Part" or d.ClassName == "Seat" then (d :: Part).Shape.Name else d.ClassName,
				size = { round(d.Size.X), round(d.Size.Y), round(d.Size.Z) },
				cframe = cf,
				color = { round(d.Color.R), round(d.Color.G), round(d.Color.B) },
				material = d.Material.Name,
				transparency = d.Transparency,
				canCollide = d.CanCollide,
			})
		end
	end
	local attachments = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Parent and d.Parent:IsA("BasePart") then
			local p = (d.Parent :: BasePart).CFrame * d.CFrame
			table.insert(attachments, { name = d.Name, position = { round(p.X), round(p.Y), round(p.Z) } })
		end
	end
	return { name = model.Name, parts = parts, attachments = attachments }
end

local function catalogue()
	local out = {}
	local function add(key: string, model: Instance, extra: { [string]: any }?)
		local entry = serialise(model)
		entry.label = key
		entry.partCount = #entry.parts
		for k, v in extra or {} do
			entry[k] = v
		end
		out[key] = entry
	end
	for _, hue in { "crimson", "emerald" } do
		local color = CANON[hue]
		add(`keep_L1_{hue}`, Kit.build("keep", 1, "complete", color), { footprint = { 32, 32 } })
		add(`keep_L3_{hue}`, Kit.build("keep", 3, "complete", color), { footprint = { 46, 46 } })
		add(`house_L1_{hue}`, Kit.build("house", 1, "complete", color), { footprint = { 20, 16 } })
		add(`barracks_L1_{hue}`, Kit.build("barracks", 1, "complete", color), { footprint = { 30, 20 } })
		add(`watchtower_L1_{hue}`, Kit.build("watchtower", 1, "complete", color), { footprint = { 14, 14 } })
	end
	-- the neutral kit look and the three construction stages of a keep and a house (hard parts of any imported set)
	for stage = 1, 3 do
		add(`keep_L1_crimson_stage{stage}`, Kit.build("keep", 1, stage, CANON.crimson))
		add(`house_L1_crimson_stage{stage}`, Kit.build("house", 1, stage, CANON.crimson))
	end
	for _, id in
		{
			"tree_oak_01",
			"tree_oak_02",
			"tree_oak_03",
			"tree_oak_04",
			"tree_oak_05",
			"tree_pine_01",
			"tree_pine_02",
			"tree_pine_03",
			"tree_pine_04",
			"tree_birch_01",
			"tree_birch_02",
			"tree_birch_03",
			"bush_01",
			"bush_02",
			"rock_boulder_m_01",
			"rock_boulder_m_02",
			"rock_boulder_l_01",
			"rock_boulder_s_01",
			"farm_field_wheat_01",
			"farm_field_wheat_02",
		}
	do
		add(id, Kit.prop(id))
	end
	return out
end

describe("FL-0136 S3 dump", function()
	it("serialises the comparison subjects to finite numbers", function()
		local subjects = catalogue()
		local n, parts = 0, 0
		for _, m in subjects do
			n += 1
			for _, p in m.parts do
				parts += 1
				for _, v in p.cframe do
					expect(v == v and math.abs(v) < 1e6).toBe(true)
				end
				for _, v in p.size do
					expect(v).toBeGreaterThan(0)
				end
			end
		end
		expect(n).toBeGreaterThan(30)
		local out = process.env.FORGE_ENV_DUMP
		if out and out ~= "" then
			fs.writeFile(out, serde.encode("json", { version = Kit.VERSION, subjects = subjects }, false))
			print(`env dump: {n} models, {parts} parts -> {out}`)
		end
	end)
end)
