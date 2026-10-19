--!nonstrict
--[[
	Test support for the FL-0136 nature meshes: the placeholder env kit, fake Forge.Assets folders of the Models the
	Studio import script makes (Root + Body MeshPart), dirty variants of them, and bounds of what Kit.prop draws. Not a spec
	(no describe/it), so the runner does not collect it.

	The placeholder (env_placeholder.env.json, made by art/env_kit/make_placeholder_env.py) has the shape of the real kit's
	env.json with numbers measured on the part-built props; EnvMeshFixture.luau is its env_to_luau.py output.
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local EnvMesh = require("@game/ReplicatedStorage/Game/Kit/EnvMesh")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local EnvKit = {}

EnvKit.FIXTURE_JSON = "games/game-001/tests/world/fixtures/env_placeholder.env.json"

local decoded: any = nil
-- The placeholder env.json as the converter reads it (a fresh copy each call: specs mutate it).
function EnvKit.fixture(): any
	if decoded == nil then
		decoded = serde.decode("json", fs.readFile(EnvKit.FIXTURE_JSON))
	end
	return EnvKit.deepCopy(decoded)
end

function EnvKit.deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = EnvKit.deepCopy(x)
	end
	return out
end

function EnvKit.ids(data: any): { string }
	local out = {}
	for id in data.props do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

local meshCount = 0

-- The Model blender/studio/import_env_kit.luau makes for one prop: an invisible anchored Root (a footprint plate, pivot at
-- the base centre) and the MeshPart "Body" at the data's bbox centre. opts: scale = Vector3 (the imported size is wrong),
-- shift = Vector3 (the mesh sits off its place), noMeshId, noRoot, noMesh, nested (the MeshPart inside a sub-Model), dirty
-- (scripts, SurfaceAppearance, a Decal, a weld, attributes, tags, a nested Folder, a plain Part), asMeshPart (the id is a bare MeshPart).
function EnvKit.model(id: string, def: any, opts: any?): Instance
	local o = opts or {}
	meshCount += 1
	local size = Vector3.new(def.size[1], def.size[2], def.size[3])
	if o.asMeshPart then
		local bare = Instance.new("MeshPart")
		bare.Name = id
		bare.MeshId = "rbxassetid://1"
		bare.Size = size
		return bare
	end
	local model = Instance.new("Model")
	model.Name = id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(size.X, 0.2, size.Z)
	root.CFrame = CFrame.new(0, 0.1, 0)
	root.PivotOffset = CFrame.new(0, -0.1, 0)
	root.Anchored = false -- the Kit must anchor it
	root.CanCollide = true
	root.Transparency = 0.5
	root.Parent = model
	if not o.noRoot then
		model.PrimaryPart = root
	end
	if not o.noMesh then
		local body = Instance.new("MeshPart")
		body.Name = "Body"
		if not o.noMeshId then
			body.MeshId = `rbxassetid://{200000 + meshCount}`
		end
		body.Size = if o.scale then Vector3.new(size.X * o.scale.X, size.Y * o.scale.Y, size.Z * o.scale.Z) else size
		body.CFrame = CFrame.new(def.bbox_center[1], def.bbox_center[2], def.bbox_center[3]) + (o.shift or Vector3.zero)
		body.Anchored = false
		body.CanCollide = true -- the Kit decides physics
		body.Color = Color3.fromRGB(0, 255, 0)
		body.Material = Enum.Material.Neon
		local parent: Instance = model
		if o.nested then
			parent = Instance.new("Model")
			parent.Name = "Wrapper"
			parent.Parent = model
		end
		body.Parent = parent
		if o.dirty then
			Instance.new("SurfaceAppearance").Parent = body
			Instance.new("Decal").Parent = body
			Instance.new("Script").Parent = body
			Instance.new("Attachment").Parent = body
			body:SetAttribute("Imported", "yes")
			body:AddTag("Stale")
		end
	end
	if o.dirty then
		Instance.new("Script").Parent = model
		Instance.new("LocalScript").Parent = root
		Instance.new("WeldConstraint").Parent = model
		Instance.new("Folder").Parent = model
		local stray = Instance.new("Part")
		stray.Name = "Stray"
		stray.Parent = model
		model:SetAttribute("Imported", true)
		root:SetAttribute("Imported", true)
		model:AddTag("Stale")
		root:AddTag("Stale")
	end
	return model
end

-- ReplicatedStorage.Forge.Assets with a Model per prop. opts.folder = true puts them in Assets.EnvKit (the import script's
-- folder), else directly in Assets; opts.omit = { [id] = true }; opts.per = { [id] = model opts } (see EnvKit.model); opts.all = model opts for all.
function EnvKit.assets(data: any, opts: any?): Folder
	local o = opts or {}
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	local into: Instance = assets
	if o.folder then
		into = Instance.new("Folder")
		into.Name = EnvMesh.FOLDER_NAME
		into.Parent = assets
	end
	for _, id in EnvKit.ids(data) do
		if not (o.omit and o.omit[id]) then
			local model = EnvKit.model(id, data.props[id], (o.per and o.per[id]) or o.all)
			model.Parent = into
		end
	end
	return assets
end

-- Runs fn with the data and a fake asset source installed in the Kit, then puts the Kit back.
EnvKit.logs = {} :: { string }

-- Installs the data and the asset source; rejections are collected in EnvKit.logs instead of printed.
function EnvKit.install(data: any, assets: Instance?)
	EnvMesh.setData(data)
	Kit.setAssetSource(assets)
	EnvKit.logs = {}
	EnvMesh.setLogger(function(line)
		table.insert(EnvKit.logs, line)
	end)
end

function EnvKit.uninstall()
	Kit.setAssetSource(nil)
	EnvMesh.setData(nil)
	EnvMesh.setLogger(nil)
end

function EnvKit.parts(model: Instance): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

-- Drawn bounds of what Kit.prop returns, in the pivot frame (visible parts, like PlotClearance/NodeKeepOut): centre, size.
function EnvKit.drawn(model: Model): (Vector3, Vector3)
	local root = model.PrimaryPart :: BasePart
	local pivot = root.CFrame * root.PivotOffset
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in EnvKit.parts(model) do
		if p.Transparency < 0.99 then
			local h = p.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = pivot:PointToObjectSpace(p.CFrame * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						mn = mn:Min(w)
						mx = mx:Max(w)
					end
				end
			end
		end
	end
	return (mn + mx) / 2, mx - mn
end

-- every part's class, name, size, CFrame, colour, material, flags and attributes: equal signatures = identical props
function EnvKit.signature(model: Instance): string
	local rows = {}
	for _, p in EnvKit.parts(model) do
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
			)}|{p.Color:ToHex()}|{p.Material.Name}|{tostring(p.Anchored)}{tostring(p.CanCollide)}{tostring(
				p.CanQuery
			)}{tostring(p.CanTouch)}|{table.concat(attrs, ";")}`
		)
	end
	table.sort(rows)
	return table.concat(rows, "\n")
end

return EnvKit
