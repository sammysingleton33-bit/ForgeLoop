--[[
	Crown Arena preview dump (FL-0072, FORGE-02): the arena in several kingdom pairings, seated crowds, the role-prop
	line-up and the armour x weapon sheet, serialised like KitDump.spec.luau (class, shape, size, CFrame, colour, material).

	Always: asserts the catalogue serialises to finite numbers.
	With FORGE_KIT_DUMP_ARENA=<path.json>: also writes the JSON for the scratch Blender renderer (D-019 review). Run:
	  FORGE_KIT_DUMP_ARENA=/tmp/arena.json lune run roblox/tests/harness/run.luau \
	    --project games/game-001/default.project.json --specs games/game-001/tests/world KitArenaDump
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Avatar = require("./support/AvatarStandIn")

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
			})
		end
	end
	local attachments = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Attachment") and d.Parent and d.Parent:IsA("BasePart") then
			local p = (d.Parent :: BasePart).CFrame * d.CFrame
			local cf = { p:GetComponents() }
			for i, v in cf do
				cf[i] = round(v)
			end
			table.insert(attachments, { name = d.Name, position = { round(p.X), round(p.Y), round(p.Z) }, cframe = cf })
		end
	end
	return { name = model.Name, parts = parts, attachments = attachments }
end

-- no PivotTo in Lune: put a model's pivot on `cf` the way WorldService.placeModel does
local function place(model: Model, cf: CFrame)
	local primary = model.PrimaryPart :: BasePart
	local delta = cf * (primary.CFrame * primary.PivotOffset):Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end

local ROLES = { "blacksmith", "healer", "captain", "provisioner", "elder", "merchant" }

-- the arena with both stands filled: 60 of the 72 seats a stand, the six key citizens on the rail
local function crowded(a: Color3, b: Color3): Model
	local arena = Kit.arena(a, b)
	local root = arena.PrimaryPart :: BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Crowd"
	folder.Parent = arena
	local seats: { [string]: Attachment } = {}
	for _, d in root:GetChildren() do
		if d:IsA("Attachment") then
			seats[d.Name] = d
		end
	end
	for _, side in { "A", "B" } do
		local color = if side == "A" then a else b
		for r = 1, 4 do
			for s = 1, 18 do
				if (s + 2 * r) % 6 ~= 0 then
					local att = seats[`Stand{side}_Row{r}_Seat{s}`]
					local fig = Kit.crowdFigure(color, nil, (r * 5 + s * 3) % Kit.CROWD_VARIANTS + 1)
					place(fig, root.CFrame * att.CFrame)
					fig.Parent = folder
				end
			end
		end
		for n, role in ROLES do
			local att = seats[`Stand{side}_Rail{n}`]
			local fig = Kit.crowdFigure(color, role, 1)
			place(fig, root.CFrame * att.CFrame)
			fig.Parent = folder
		end
	end
	return arena
end

-- every role in one kingdom's colour in front of every plain variant, on a stone strip
local function lineup(color: Color3): Model
	local m = Instance.new("Model")
	m.Name = "lineup"
	local base = Instance.new("Part")
	base.Name = "Strip"
	base.Size = Vector3.new(48, 0.4, 14)
	base.CFrame = CFrame.new(0, -0.2, 3)
	base.Color = Color3.fromRGB(193, 180, 152)
	base.Anchored = true
	base.Parent = m
	for i, role in ROLES do
		local fig = Kit.crowdFigure(color, role, 1)
		place(fig, CFrame.new((i - 3.5) * 6.0, 0, 0))
		fig.Parent = m
	end
	for v = 1, Kit.CROWD_VARIANTS do
		local fig = Kit.crowdFigure(color, nil, v)
		place(fig, CFrame.new((v - 6.5) * 3.0, 0, 6))
		fig.Parent = m
	end
	return m
end

-- one stand-in avatar in a given armour with a given weapon in its right hand, in the kingdom's colour
local function geared(rigType: string, armour: string, weapon: string?, color: Color3): Model
	local av = Avatar.build(rigType)
	for _, acc in Kit.armour(armour, color) do
		Avatar.wear(acc, av)
	end
	if weapon then
		Avatar.hold(Kit.weapon(weapon, color), av)
	end
	return av.model
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
	local pairs_ = {
		{ "neutral", nil, nil },
		{ "crimson_azure", CANON.crimson, CANON.azure },
		{ "emerald_gold", CANON.emerald, CANON.gold },
		{ "gold_crimson", CANON.gold, CANON.crimson },
		{ "azure_emerald", CANON.azure, CANON.emerald },
	}
	for _, p in pairs_ do
		add("arena", p[1], Kit.arena(p[2], p[3]))
	end
	add("crowd", "crowd_crimson_azure", crowded(CANON.crimson, CANON.azure))
	add("crowd", "crowd_emerald_gold", crowded(CANON.emerald, CANON.gold))
	for _, k in { "crimson", "azure", "emerald", "gold" } do
		add("roles", `roles_{k}`, lineup(CANON[k]))
	end
	local kingdoms = { "crimson", "azure", "emerald", "gold" }
	for ai, armour in { "light", "medium", "heavy" } do
		for wi, weapon in { "swordShield", "greatsword", "spear", "mace" } do
			local k = kingdoms[(ai + wi) % 4 + 1]
			add("gear", `gear_{armour}_{weapon}`, geared("R15", armour, weapon, CANON[k]), { kingdom = k })
		end
		-- armour alone, for the close-up views (front, side, back)
		add("gear", `gear_{armour}_none`, geared("R15", armour, nil, CANON[kingdoms[ai]]), { kingdom = kingdoms[ai] })
		-- R6 fit: the same armour with the mace
		add("gear", `gear_r6_{armour}`, geared("R6", armour, "mace", CANON[kingdoms[ai]]), { kingdom = kingdoms[ai] })
	end
	return groups
end

describe("Crown Arena preview dump", function()
	it("serialises the catalogue to finite numbers", function()
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
		expect(n).toBeGreaterThan(0)
		local out = process.env.FORGE_KIT_DUMP_ARENA
		if out and out ~= "" then
			fs.writeFile(out, serde.encode("json", { version = Kit.VERSION, groups = groups }, false))
			print(`arena dump: {n} models -> {out}`)
		end
	end)
end)
