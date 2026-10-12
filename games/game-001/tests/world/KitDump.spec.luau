--[[
	Kit preview dump (FL-0054 preview path). Builds the Kit catalogue (every building type in all four
	kingdom colours, construction stages, characters per job, props, regalia, region markers) and
	serialises every part (class, shape, size, CFrame, colour, material, transparency).

	Always: asserts the catalogue serialises to finite numbers.
	With FORGE_KIT_DUMP=<path.json>: also writes the JSON, which blender/scripts/render_kit.py renders
	into contact sheets (D-019 review). Run:
	  FORGE_KIT_DUMP=/tmp/kit.json lune run roblox/tests/harness/run.luau \
	    --project games/game-001/default.project.json --specs games/game-001/tests/world KitDump
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local KINGDOMS = {
	{ id = "crimson", color = Color3.fromRGB(196, 40, 28) },
	{ id = "azure", color = Color3.fromRGB(13, 105, 172) },
	{ id = "emerald", color = Color3.fromRGB(40, 127, 71) },
	{ id = "gold", color = Color3.fromRGB(245, 205, 48) },
}

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
				class = d.ClassName,
				shape = if d.ClassName == "Part" then (d :: Part).Shape.Name else d.ClassName,
				size = { round(d.Size.X), round(d.Size.Y), round(d.Size.Z) },
				cframe = cf,
				color = { round(d.Color.R), round(d.Color.G), round(d.Color.B) },
				material = d.Material.Name,
				transparency = d.Transparency,
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
	local groups = {}
	local function add(group: string, label: string, model: Instance, extra: { [string]: any }?)
		groups[group] = groups[group] or {}
		local entry = serialise(model)
		entry.label = label
		for k, v in extra or {} do
			entry[k] = v
		end
		table.insert(groups[group], entry)
	end
	for _, bt in Kit.BUILDING_TYPES do
		for _, k in KINGDOMS do
			add(`building_{bt}`, `{bt} L1 {k.id}`, Kit.build(bt, 1, "complete", k.color), { kingdom = k.id })
		end
		add(
			`building_{bt}`,
			`{bt} L1 neutral`,
			Kit.build(bt, 1, "complete", Kit.NEUTRAL_COLOR),
			{ kingdom = "neutral" }
		)
		add(
			`building_{bt}`,
			`{bt} L2 crimson`,
			Kit.build(bt, 2, "complete", KINGDOMS[1].color),
			{ kingdom = "crimson" }
		)
	end
	for _, bt in { "house", "keep", "barracks", "farm" } do
		for _, stage in { 1, 2, 3, "complete" } do
			add("stages", `{bt} stage {stage}`, Kit.build(bt, 1, stage, KINGDOMS[2].color))
		end
	end
	for _, k in KINGDOMS do
		for _, job in { "farmer", "woodcutter", "miner", "builder", "hauler" } do
			add("characters", `citizen {job} {k.id}`, Kit.character("citizen", job, k.color))
		end
		add("characters", `soldier {k.id}`, Kit.character("soldier", "soldier", k.color))
	end
	for _, id in
		{
			"tree_oak_01",
			"tree_pine_02",
			"tree_birch_01",
			"bush_03",
			"resource_stone_01",
			"resource_ore_03",
			"resource_wood_01",
			"prop_goods_01",
		}
	do
		add("props", id, Kit.prop(id))
	end
	local regalia = Instance.new("Model")
	regalia.Name = "regalia"
	for _, acc in Kit.regalia(KINGDOMS[1].color) do
		acc.Parent = regalia
	end
	add("props", "regalia crimson", regalia)
	return groups
end

describe("Kit preview dump", function()
	it("serialises the whole catalogue to finite numbers", function()
		local groups = catalogue()
		local nModels, nParts = 0, 0
		for _, models in groups do
			for _, m in models do
				nModels += 1
				for _, p in m.parts do
					nParts += 1
					for _, v in p.cframe do
						expect(v == v and math.abs(v) < 1e6).toBe(true)
					end
					for _, v in p.size do
						expect(v).toBeGreaterThan(0)
					end
				end
			end
		end
		expect(nModels).toBeGreaterThan(60)
		local out = process.env.FORGE_KIT_DUMP
		if out and out ~= "" then
			fs.writeFile(out, serde.encode("json", { version = Kit.VERSION, groups = groups }, false))
			print(`kit dump: {nModels} models, {nParts} parts -> {out}`)
		end
	end)
end)
