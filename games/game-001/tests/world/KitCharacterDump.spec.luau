--[[
	Kit character preview dump (FL-0056, D-019 review). KitDump.spec covers citizens per job and soldiers in
	the four kingdom colours; this one adds what that sheet leaves out: one row of every look (idle,
	governor), the soldier kingdom crests (G13.2, D-033(3)) from the front and the side, Kit.portrait rigs
	with their PortraitFocus camera next to the same world rigs (G13.8), the one-part far LOD, and the regalia
	fitted on stand-in R15 and R6 avatars.

	Always: asserts the dump serialises to finite numbers.
	With FORGE_KIT_CHAR_DUMP=<path.json>: also writes the JSON for blender/scripts/render_kit.py
	(groups characters_lineup, characters_looks, characters_aerial, characters_turn, characters_crests,
	characters_crests_side, portraits (each entry also has camera = { cframe, fov }), portraits_world,
	characters_lod, regalia_fit). Run:
	  FORGE_KIT_CHAR_DUMP=/tmp/kit_chars_ext.json lune run roblox/tests/harness/run.luau \
	    --project games/game-001/default.project.json --specs games/game-001/tests/world KitCharacterDump
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Character = require("@game/ReplicatedStorage/Game/Kit/Character")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local KINGDOMS = {
	{ id = "crimson", color = Color3.fromRGB(190, 40, 50) },
	{ id = "azure", color = Color3.fromRGB(40, 110, 210) },
	{ id = "emerald", color = Color3.fromRGB(35, 128, 95) },
	{ id = "gold", color = Color3.fromRGB(235, 185, 16) },
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
	return { name = model.Name, parts = parts, attachments = {} }
end

-- Stand-in avatars with the attachment names (and approximate positions) of Roblox's R15 and R6 rigs.
local function avatar(rigType: string, offsetX: number): (Model, { [string]: Attachment })
	local m = Instance.new("Model")
	m.Name = `avatar_{rigType}`
	local atts: { [string]: Attachment } = {}
	local function part(name: string, size: Vector3, pos: Vector3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(pos + Vector3.new(offsetX, 0, 0))
		p.Color = Color3.fromRGB(158, 168, 188)
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	local function att(p: Part, name: string, pos: Vector3)
		local a = Instance.new("Attachment")
		a.Name = name
		a.CFrame = CFrame.new(pos)
		a.Parent = p
		atts[name] = a
	end
	if rigType == "R15" then
		part("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0))
		part("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0))
		part("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 2.2, 0))
		local upper = part("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.2, 0))
		part("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0))
		part("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0))
		local head = part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 4.6, 0))
		att(upper, "BodyBackAttachment", Vector3.new(0, 0.2, 0.5))
		att(head, "HatAttachment", Vector3.new(0, 0.6, 0))
	else
		part("Left Leg", Vector3.new(1, 2, 1), Vector3.new(-0.5, 1, 0))
		part("Right Leg", Vector3.new(1, 2, 1), Vector3.new(0.5, 1, 0))
		local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
		part("Left Arm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 3, 0))
		part("Right Arm", Vector3.new(1, 2, 1), Vector3.new(1.5, 3, 0))
		local head = part("Head", Vector3.new(1.25, 1.2, 1.25), Vector3.new(0, 4.6, 0))
		att(torso, "BodyBackAttachment", Vector3.new(0, 0, 0.5))
		att(head, "HatAttachment", Vector3.new(0, 0.6, 0))
	end
	return m, atts
end

-- What Humanoid:AddAccessory does: Handle.CFrame = bodyAttachment world * accessoryAttachment:Inverse();
-- parts welded to the Handle keep their offset.
local function wear(acc: Accessory, atts: { [string]: Attachment })
	local handle = acc:FindFirstChild("Handle") :: BasePart
	for _, a in handle:GetChildren() do
		if a:IsA("Attachment") and atts[a.Name] then
			local body = atts[a.Name]
			local target = (body.Parent :: BasePart).CFrame * body.CFrame * a.CFrame:Inverse()
			local delta = target * handle.CFrame:Inverse()
			for _, p in acc:GetDescendants() do
				if p:IsA("BasePart") and p ~= handle then
					p.CFrame = delta * p.CFrame
				end
			end
			handle.CFrame = target
			return
		end
	end
end

local function catalogue()
	local groups = {}
	local function add(group: string, label: string, model: Instance)
		groups[group] = groups[group] or {}
		local entry = serialise(model)
		entry.label = label
		table.insert(groups[group], entry)
	end
	local c = KINGDOMS[1].color
	for _, job in { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" } do
		add("characters_lineup", `citizen {job}`, Kit.character("citizen", job, c))
	end
	add("characters_lineup", "soldier", Kit.character("soldier", "soldier", c))
	add("characters_lineup", "governor", Kit.character("governor", "idle", c))
	add("characters_lineup", "governor azure", Kit.character("governor", "idle", KINGDOMS[2].color))
	-- varied citizen looks (G13.2) covering every palette entry, plus soldiers and a governor
	local looks = {
		{ "farmer", 1, 1, 4, 1 },
		{ "woodcutter", 5, 4, 2, 2 },
		{ "miner", 3, 3, 7, 3 },
		{ "builder", 6, 6, 1, 4 },
		{ "hauler", 4, 5, 5, 5 },
		{ "idle", 2, 2, 5, 6 },
		{ "farmer", 5, 6, 3, 1 },
		{ "woodcutter", 4, 1, 6, 3 },
		{ "miner", 2, 5, 8, 2 },
		{ "builder", 3, 4, 5, 6 },
		{ "hauler", 6, 2, 8, 4 },
		{ "idle", 1, 3, 2, 5 },
	}
	local function lookModels(): { { label: string, model: Model } }
		local out = {}
		for i, l in looks do
			local k = if i <= 6 then KINGDOMS[1] else KINGDOMS[2]
			local look = { skin = l[2], hair = l[3], hairColor = l[4], outfit = l[5] }
			local m = Kit.character("citizen", l[1], k.color, look)
			local names = Kit.LOOK_PALETTES
			table.insert(out, {
				label = `{l[1]} {names.hair[l[3]]} {names.outfit[l[5]]} s{l[2]} c{l[4]} {k.id}`,
				model = m,
			})
		end
		for _, k in KINGDOMS do
			table.insert(
				out,
				{ label = `soldier {k.id}`, model = Kit.character("soldier", "soldier", k.color, nil, k.id) }
			)
		end
		local gov =
			Kit.character("governor", "idle", KINGDOMS[4].color, { skin = 5, hair = 1, hairColor = 1, outfit = 1 })
		table.insert(out, { label = "governor s5 gold", model = gov })
		return out
	end
	for _, e in lookModels() do
		add("characters_looks", e.label, e.model)
	end
	-- the aerial management camera (G13.6) looks down from 40-220 studs: tilt the same rigs 55° towards
	-- the preview camera so the sheet shows head tops and shoulders
	local tilt = CFrame.new(0, 2.2, 0) * CFrame.Angles(math.rad(-55), 0, 0)
	for _, e in lookModels() do
		for _, d in e.model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = tilt * d.CFrame
			end
		end
		add("characters_aerial", e.label, e.model)
	end
	-- turnaround: the hero camera sees the front-right; these show the side and the back
	for _, spec in
		{ { "soldier", "soldier" }, { "citizen", "hauler" }, { "citizen", "woodcutter" }, { "citizen", "miner" } }
	do
		for _, yaw in { 90, 180 } do
			local m = Kit.character(spec[1], spec[2], KINGDOMS[3].color, nil, KINGDOMS[3].id)
			local turn = CFrame.Angles(0, math.rad(yaw), 0)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = turn * d.CFrame
				end
			end
			add("characters_turn", `{spec[2]} yaw {yaw}`, m)
		end
	end
	-- soldier kingdom crests side by side (spire, square, plume, dome): front, then side (yaw 90)
	for _, k in KINGDOMS do
		add(
			"characters_crests",
			`soldier {k.id} {Kit.SOLDIER_CRESTS[k.id]}`,
			Kit.character("soldier", "soldier", k.color, nil, k.id)
		)
	end
	for _, k in KINGDOMS do
		local m = Kit.character("soldier", "soldier", k.color, nil, k.id)
		local turn = CFrame.Angles(0, math.rad(90), 0)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = turn * d.CFrame
			end
		end
		add("characters_crests_side", `soldier {k.id} side`, m)
	end
	-- G13.8 portraits: 3 citizens, a governor and a soldier per kingdom, in the config kingdom colours
	local KC = {
		crimson = Color3.fromRGB(190, 40, 50),
		azure = Color3.fromRGB(40, 110, 210),
		emerald = Color3.fromRGB(35, 128, 95),
		gold = Color3.fromRGB(235, 185, 16),
	}
	local sitters: { { any } } = {
		{ "citizen", "farmer", "crimson", nil, nil, "farmer short crimson" },
		{
			"citizen",
			"hauler",
			"azure",
			{ skin = 5, hair = 5, hairColor = 2, outfit = 2 },
			nil,
			"hauler hood s5 azure",
		},
		{
			"citizen",
			"builder",
			"emerald",
			{ skin = 3, hair = 6, hairColor = 4, outfit = 6 },
			nil,
			"builder strawhat s3 emerald",
		},
		{ "governor", "idle", "gold", { skin = 4, hair = 1, hairColor = 1, outfit = 1 }, nil, "governor s4 gold" },
	}
	for _, k in KINGDOMS do
		table.insert(sitters, { "soldier", "soldier", k.id, nil, k.id, `soldier {k.id} {Kit.SOLDIER_CRESTS[k.id]}` })
	end
	for _, s in sitters do
		local portrait = Kit.portrait(s[1], s[2], KC[s[3]], s[4], s[5])
		add("portraits", s[6], portrait)
		local cam, fov = Kit.portraitCamera(portrait)
		local cf = { cam:GetComponents() }
		for i, v in cf do
			cf[i] = round(v)
		end
		local entry = groups.portraits[#groups.portraits]
		entry.camera = { cframe = cf, fov = fov }
		add("portraits_world", s[6], Kit.character(s[1], s[2], KC[s[3]], s[4], s[5]))
	end
	for _, k in KINGDOMS do
		add("characters_lod", `citizen lod {k.id}`, Character.lod("citizen", k.color))
		add("characters_lod", `soldier lod {k.id}`, Character.lod("soldier", k.color))
	end
	for _, fit in { { "R15", KINGDOMS[1] }, { "R6", KINGDOMS[4] } } do
		for _, yaw in { 0, 180 } do
			local m, atts = avatar(fit[1], 0)
			for _, acc in Kit.regalia(fit[2].color) do
				wear(acc, atts)
				acc.Parent = m
			end
			local turn = CFrame.Angles(0, math.rad(yaw), 0)
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = turn * d.CFrame
				end
			end
			add("regalia_fit", `{fit[1]} {fit[2].id} yaw {yaw}`, m)
		end
	end
	return groups
end

describe("Kit character preview dump", function()
	it("serialises the extra character groups to finite numbers", function()
		local groups = catalogue()
		local nModels = 0
		for _, models in groups do
			for _, m in models do
				nModels += 1
				for _, p in m.parts do
					for _, v in p.cframe do
						expect(v == v and math.abs(v) < 1e6).toBe(true)
					end
				end
			end
		end
		expect(nModels).toBe(87)
		local out = process.env.FORGE_KIT_CHAR_DUMP
		if out and out ~= "" then
			fs.writeFile(out, serde.encode("json", { version = Kit.VERSION, groups = groups }, false))
			print(`kit character dump: {nModels} models -> {out}`)
		end
	end)
end)
