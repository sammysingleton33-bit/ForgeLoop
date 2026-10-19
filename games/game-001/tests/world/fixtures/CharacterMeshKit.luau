--!nonstrict
--[[
	Test support for the Kit mesh rigs (FL-0135, D-057): the placeholder citizen kit, a fake ReplicatedStorage.Forge.Assets
	folder of MeshParts built from any rig data (Lune has no importer), forward kinematics as the engine does it and
	the usual rig queries. Not a spec (no describe/it), so the runner does not collect it.

	The placeholder (char_kit_placeholder.rig.json, made by art/char_kit/make_placeholder_rig.py) has the shape of the real
	kit's rig.json but boxes for geometry; CharacterMeshFixture.luau is its rig_to_luau.py output.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local CharacterMesh = require("@game/ReplicatedStorage/Game/Kit/CharacterMesh")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local MeshKit = {}

MeshKit.FIXTURE_JSON = "games/game-001/tests/world/fixtures/char_kit_placeholder.rig.json"
MeshKit.CRIMSON = Color3.fromRGB(190, 40, 50)
MeshKit.AZURE = Color3.fromRGB(40, 110, 210)
MeshKit.GOLD = Color3.fromRGB(235, 185, 16)
MeshKit.EMERALD = Color3.fromRGB(35, 128, 95)
MeshKit.KINGDOM_IDS = { "crimson", "azure", "emerald", "gold" }
MeshKit.KINGDOM_COLORS = {
	crimson = MeshKit.CRIMSON,
	azure = MeshKit.AZURE,
	emerald = MeshKit.EMERALD,
	gold = MeshKit.GOLD,
}
MeshKit.CITIZEN_JOBS = { "idle", "farmer", "woodcutter", "miner", "builder", "hauler" }

local decoded: any = nil
-- The placeholder rig.json as the converter reads it (a fresh copy each call: specs mutate it).
function MeshKit.fixture(): any
	if decoded == nil then
		decoded = serde.decode("json", fs.readFile(MeshKit.FIXTURE_JSON))
	end
	return MeshKit.deepCopy(decoded)
end

function MeshKit.deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = MeshKit.deepCopy(x)
	end
	return out
end

-- ------------------------------------------------------------------ the fake import

-- ReplicatedStorage.Forge.Assets with a CitizenKit folder of MeshParts named by piece id, as the Studio import leaves it.
-- opts.omit = { [id] = true } leaves pieces out; opts.replace = { [id] = Instance } swaps one in; opts.noMeshId = { [id] = true }.
function MeshKit.assets(data: any, opts: any?): Folder
	local o = opts or {}
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	local kit = Instance.new("Folder")
	kit.Name = CharacterMesh.FOLDER_NAME
	kit.Parent = assets
	local n = 0
	for id, def in data.pieces do
		if def.empty ~= true and not (o.omit and o.omit[id]) then
			n += 1
			local piece = if o.replace and o.replace[id] then o.replace[id] else Instance.new("MeshPart")
			piece.Name = id
			if piece:IsA("MeshPart") then
				if not (o.noMeshId and o.noMeshId[id]) then
					piece.MeshId = `rbxassetid://{100000 + n}`
				end
				piece.Size = Vector3.new(def.size[1], def.size[2], def.size[3])
				piece.Anchored = true -- an imported piece sits anchored in Workspace
				piece.Color = Color3.fromRGB(0, 255, 0) -- the Kit must paint it, not inherit it
				piece.Material = Enum.Material.Neon
			elseif piece:IsA("BasePart") then
				piece.Size = Vector3.new(def.size[1], def.size[2], def.size[3])
			end
			piece.Parent = kit
		end
	end
	return assets
end

-- Runs fn with `data` and a fake Assets folder installed in the Kit, then puts the Kit back.
function MeshKit.with(data: any, assets: Instance?, fn: () -> ())
	CharacterMesh.setData(data)
	Kit.setAssetSource(assets)
	local ok, err = pcall(fn)
	Kit.setAssetSource(nil)
	CharacterMesh.setData(nil)
	if not ok then
		error(err, 0)
	end
end

function MeshKit.install(data: any, assets: Instance?)
	CharacterMesh.setData(data)
	Kit.setAssetSource(assets)
end

function MeshKit.uninstall()
	Kit.setAssetSource(nil)
	CharacterMesh.setData(nil)
end

-- ------------------------------------------------------------------ queries

function MeshKit.parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

function MeshKit.child(rig: Model, name: string): BasePart
	return rig:FindFirstChild(name) :: BasePart
end

function MeshKit.motors(rig: Model): { Motor6D }
	local out = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Motor6D") then
			table.insert(out, d)
		end
	end
	return out
end

function MeshKit.motorOf(rig: Model, name: string): Motor6D
	for _, m in MeshKit.motors(rig) do
		if m.Name == name then
			return m
		end
	end
	error(`no Motor6D {name}`)
end

function MeshKit.jointWorld(m: Motor6D): CFrame
	return (m.Part0 :: BasePart).CFrame * m.C0
end

-- every part's class, name, size, CFrame, colour, material and attributes: equal signatures = identical rigs
function MeshKit.signature(rig: Model): string
	local rows = {}
	for _, p in MeshKit.parts(rig) do
		local cf = { p.CFrame:GetComponents() }
		for i, v in cf do
			cf[i] = string.format("%.3f", v)
		end
		local attrs = {}
		for k, v in p:GetAttributes() do
			table.insert(attrs, `{k}={tostring(v)}`)
		end
		table.sort(attrs)
		table.insert(
			rows,
			`{p.Name}|{p.ClassName}|{string.format("%.3f,%.3f,%.3f", p.Size.X, p.Size.Y, p.Size.Z)}|{table.concat(
				cf,
				","
			)}|{p.Color:ToHex()}|{p.Material.Name}|{table.concat(attrs, ";")}`
		)
	end
	table.sort(rows)
	return table.concat(rows, "\n")
end

-- Forward kinematics as the engine does it: Part1 = Part0 * C0 * Transform * C1:Inverse(); welds follow either way.
function MeshKit.posed(rig: Model, joints: { [string]: CFrame }): { [BasePart]: CFrame }
	local root = rig.PrimaryPart :: BasePart
	local world: { [BasePart]: CFrame } = { [root] = root.CFrame }
	local motors = MeshKit.motors(rig)
	local welds = {}
	for _, d in rig:GetDescendants() do
		if d:IsA("Weld") and not d:IsA("Motor6D") then
			table.insert(welds, d)
		end
	end
	local moved = true
	while moved do
		moved = false
		for _, m in motors do
			local p0, p1 = m.Part0 :: BasePart, m.Part1 :: BasePart
			if world[p0] and not world[p1] then
				world[p1] = world[p0] * m.C0 * (joints[m.Name] or CFrame.new()) * m.C1:Inverse()
				moved = true
			end
		end
		for _, w in welds do
			local p0, p1 = w.Part0 :: BasePart, w.Part1 :: BasePart
			if world[p0] and not world[p1] then
				world[p1] = world[p0] * w.C0 * w.C1:Inverse()
				moved = true
			elseif world[p1] and not world[p0] then
				world[p0] = world[p1] * w.C1 * w.C0:Inverse()
				moved = true
			end
		end
	end
	return world
end

-- `root` and every part welded to it, directly or through other welds (never across a Motor6D)
function MeshKit.assembly(rig: Model, root: BasePart): { BasePart }
	local out: { BasePart } = { root }
	local seen: { [BasePart]: boolean } = { [root] = true }
	local i = 1
	while i <= #out do
		local part = out[i]
		i += 1
		for _, d in rig:GetDescendants() do
			if d:IsA("Weld") and not d:IsA("Motor6D") then
				local a, b = d.Part0 :: BasePart, d.Part1 :: BasePart
				local other = if a == part then b elseif b == part then a else nil
				if other and not seen[other] then
					seen[other] = true
					table.insert(out, other)
				end
			end
		end
	end
	return out
end

-- separating-axis clearance of two boxes (cf, size): positive = free space, negative = how deep they overlap
function MeshKit.boxBox(cfA: CFrame, sizeA: Vector3, cfB: CFrame, sizeB: Vector3): number
	local axesA = { cfA.RightVector, cfA.UpVector, cfA.LookVector }
	local axesB = { cfB.RightVector, cfB.UpVector, cfB.LookVector }
	local halfA = { sizeA.X / 2, sizeA.Y / 2, sizeA.Z / 2 }
	local halfB = { sizeB.X / 2, sizeB.Y / 2, sizeB.Z / 2 }
	local d = cfB.Position - cfA.Position
	local candidates = {}
	for _, a in axesA do
		table.insert(candidates, a)
	end
	for _, b in axesB do
		table.insert(candidates, b)
	end
	for _, a in axesA do
		for _, b in axesB do
			local c = a:Cross(b)
			if c.Magnitude > 1e-6 then
				table.insert(candidates, c.Unit)
			end
		end
	end
	local best = -math.huge
	for _, axis in candidates do
		local ra, rb = 0, 0
		for i = 1, 3 do
			ra += halfA[i] * math.abs(axesA[i]:Dot(axis))
			rb += halfB[i] * math.abs(axesB[i]:Dot(axis))
		end
		best = math.max(best, math.abs(d:Dot(axis)) - ra - rb)
	end
	return best
end

-- world-space corners of a part's box
function MeshKit.corners(p: BasePart, cf: CFrame?): { Vector3 }
	local out = {}
	local h = p.Size / 2
	local frame = cf or p.CFrame
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(out, frame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
			end
		end
	end
	return out
end

function MeshKit.bounds(list: { BasePart }): (Vector3, Vector3)
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in list do
		for _, w in MeshKit.corners(p) do
			mn = mn:Min(w)
			mx = mx:Max(w)
		end
	end
	return mn, mx
end

-- ------------------------------------------------------------------ the case matrix

-- every look at the corners of the ranges (2^4 = 16)
function MeshKit.cornerLooks(): { any }
	local r = Kit.LOOK_RANGES
	local out = {}
	for _, skin in { 1, r.skin } do
		for _, hair in { 1, r.hair } do
			for _, hairColor in { 1, r.hairColor } do
				for _, outfit in { 1, r.outfit } do
					table.insert(out, { skin = skin, hair = hair, hairColor = hairColor, outfit = outfit })
				end
			end
		end
	end
	return out
end

-- deterministic looks from a seed (Park–Miller), like a generated population
function MeshKit.seededLook(seed: number): any
	local s = seed
	local r = Kit.LOOK_RANGES
	local function roll(n: number): number
		s = (s * 16807) % 2147483647
		return s % n + 1
	end
	return { skin = roll(r.skin), hair = roll(r.hair), hairColor = roll(r.hairColor), outfit = roll(r.outfit) }
end

export type Case = { kind: string, job: string, color: Color3, look: any, kingdom: string?, label: string }

-- Every (kind, job, look, kingdom) the world builds, over the fixture's assemblies: the citizen jobs with the default
-- look, the corner looks and seeded looks; soldiers (and drafted citizens) in each kingdom; governors in each kingdom.
function MeshKit.cases(): { Case }
	local out: { Case } = {}
	local function add(kind: string, job: string, id: string?, look: any, kingdom: string?)
		table.insert(out, {
			kind = kind,
			job = job,
			color = if id then MeshKit.KINGDOM_COLORS[id] else Kit.NEUTRAL_COLOR,
			look = look,
			kingdom = kingdom,
			label = `{kind} {job} {id or "neutral"} {if look then Kit.lookKey(look) else "default"} {kingdom or "-"}`,
		})
	end
	for _, job in MeshKit.CITIZEN_JOBS do
		add("citizen", job, "azure", nil, nil)
		for _, look in MeshKit.cornerLooks() do
			add("citizen", job, "crimson", look, nil)
		end
		for seed = 1, 6 do
			add("citizen", job, MeshKit.KINGDOM_IDS[seed % 4 + 1], MeshKit.seededLook(seed), nil)
		end
	end
	for i, id in MeshKit.KINGDOM_IDS do
		add("soldier", "soldier", id, nil, id)
		add("soldier", "soldier", id, MeshKit.seededLook(10 + i), id)
		add("citizen", "soldier", id, MeshKit.seededLook(20 + i), id) -- drafted
		add("governor", "idle", id, MeshKit.seededLook(30 + i), id)
		add("governor", "governor", id, nil, nil) -- no kingdom argument: the colour's hue picks
	end
	add("soldier", "soldier", nil, nil, nil) -- neutral, no kingdom
	return out
end

return MeshKit
