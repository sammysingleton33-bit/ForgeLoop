--[[
	Kit architecture preview dump (FL-0054, FORGE-02): house variants (Buildings.build's 5th argument)
	and the stages of the types the main KitDump leaves out, serialised like KitDump.spec.luau.

	Always: asserts the extra catalogue serialises to finite numbers.
	With FORGE_KIT_DUMP_BUILDINGS=<path.json>: writes the JSON for blender/scripts/render_kit.py
	(groups house_variants, stages_more, levels_barracks, levels_keep, levels_house_farm; FL-0086: vs2_levels_a
	mine + blacksmith L1–3, vs2_levels_b market + infirmary L1–2, vs2_levels_c granary + shrine L1–2, vs2_stages
	blacksmith and granary stages 1–3 + complete). Run:
	  FORGE_KIT_DUMP_BUILDINGS=/tmp/kit_arch_extra.json lune run roblox/tests/harness/run.luau \
	    --project games/game-001/default.project.json --specs games/game-001/tests/world KitBuildingsDump
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")

-- canonical kingdom colours (config Kingdoms, D-033), keyed by KingdomId
local CANON: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	CANON[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end
local COLORS = CANON

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
				-- a Seat (the keep Throne) previews as the block it is (render_kit knows primitive classes only)
				class = if d.ClassName == "Seat" then "Part" else d.ClassName,
				shape = if d.ClassName == "Part" or d.ClassName == "Seat" then (d :: Part).Shape.Name else d.ClassName,
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
	local function add(group: string, label: string, model: Instance)
		groups[group] = groups[group] or {}
		local entry = serialise(model)
		entry.label = label
		table.insert(groups[group], entry)
	end
	local houses = {
		{ 1, 1, "crimson" },
		{ 1, 2, "azure" },
		{ 1, 3, "emerald" },
		{ 1, 4, "gold" },
		{ 1, 5, "azure" },
		{ 1, 6, "crimson" },
		{ 2, 2, "gold" },
		{ 2, 3, "azure" },
		{ 2, 4, "emerald" },
	}
	for _, h in houses do
		local level, v, k = h[1], h[2], h[3]
		add("house_variants", `house L{level} v{v} {k}`, Kit.build("house", level, "complete", COLORS[k], v))
	end
	for _, bt in { "storehouse", "watchtower", "lumbercamp" } do
		for _, stage in { 1, 2, 3 } do
			add("stages_more", `{bt} stage {stage}`, Kit.build(bt, 1, stage, COLORS.emerald))
		end
	end
	-- G13.5 level sets (aerial readability)
	for level = 1, 4 do
		add("levels_barracks", `barracks L{level} crimson`, Kit.build("barracks", level, "complete", COLORS.crimson))
	end
	for level = 1, 3 do
		add("levels_keep", `keep L{level} azure`, Kit.build("keep", level, "complete", COLORS.azure))
	end
	for _, h in { { "house", 1, "gold" }, { "house", 2, "gold" }, { "house", 1, "emerald" } } do
		local v = if h[3] == "emerald" then 2 else 1
		add("levels_house_farm", `house L{h[2]} v{v} {h[3]}`, Kit.build("house", h[2], "complete", COLORS[h[3]], v))
	end
	add("levels_house_farm", "house L2 v2 emerald", Kit.build("house", 2, "complete", COLORS.emerald, 2))
	for level = 1, 2 do
		add("levels_house_farm", `farm L{level} azure`, Kit.build("farm", level, "complete", COLORS.azure))
	end
	-- FL-0086: the six VS-2 types at every level, one kingdom per tile, the kingdoms mixed across types (every
	-- type in at least two kingdoms, every tower cap on an upper level), and the stages of two types
	local vs2 = {
		{ "vs2_levels_a", "mine", { "crimson", "azure", "emerald" } },
		{ "vs2_levels_a", "blacksmith", { "gold", "crimson", "azure" } },
		{ "vs2_levels_b", "market", { "emerald", "gold" } },
		{ "vs2_levels_b", "infirmary", { "azure", "crimson" } },
		{ "vs2_levels_c", "granary", { "gold", "emerald" } },
		{ "vs2_levels_c", "shrine", { "crimson", "azure" } },
	}
	for _, g in vs2 do
		for level, k in g[3] do
			add(g[1], `{g[2]} L{level} {k}`, Kit.build(g[2], level, "complete", COLORS[k]))
		end
	end
	for _, s in { { "blacksmith", "emerald" }, { "granary", "crimson" } } do
		for _, stage in { 1, 2, 3, "complete" } do
			add("vs2_stages", `{s[1]} L1 {stage} {s[2]}`, Kit.build(s[1], 1, stage :: any, COLORS[s[2]]))
		end
	end
	return groups
end

describe("Kit architecture preview dump", function()
	it("serialises house variants and extra stages to finite numbers", function()
		local groups = catalogue()
		local n = 0
		for _, models in groups do
			for _, m in models do
				n += 1
				for _, p in m.parts do
					for _, v in p.cframe do
						expect(v == v and math.abs(v) < 1e6).toBe(true)
					end
				end
			end
		end
		expect(n).toBe(53)
		local out = process.env.FORGE_KIT_DUMP_BUILDINGS
		if out and out ~= "" then
			fs.writeFile(out, serde.encode("json", { version = Kit.VERSION, groups = groups }, false))
			print(`kit architecture dump: {n} models -> {out}`)
		end
	end)
end)
