--[[
	FL-0136 phase 3 (A): dumps the resource node markers exactly as the Kit builds them (Kit.nodeMarker on the model Kit.prop returns), for the part-built
	stand-in and for the imported mesh (K's runtime + Kit/EnvMeshData + the fake import models of fixture EnvMeshKit), so blender/scripts/envnature_scenes.py
	renders the real marker parts on the node meshes and on the stand-ins. Marker parts are in the node's pivot frame (the model is built at the origin).

	  FORGE_ENV_NODEMARKERS=/tmp/env_nodemarkers.json lune run roblox/tests/harness/run.luau \
	    --project games/game-001/default.project.json --specs blender/scripts/lune EnvNodeMarkers

	Output JSON: { markers = { ["<assetId>|<resource>|<standin|mesh>"] = { parts = [...], partCount, reach, top } } }
]]

local T = require("../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local Data = require("@game/ReplicatedStorage/Game/Kit/EnvMeshData")
local EnvKit = require("../../../games/game-001/tests/world/fixtures/EnvMeshKit")

local function round(n: number): number
	return math.floor(n * 1000 + 0.5) / 1000
end

local function dump(model: Model)
	local parts = {}
	local reach, top = 0, 0
	local root = model.PrimaryPart :: BasePart
	local toLocal = (root.CFrame * root.PivotOffset):Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("KitNodeMarker") ~= nil then
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
				canCollide = d.CanCollide,
			})
			local l = toLocal * d.CFrame
			local h = d.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local w = l * Vector3.new(sx * h.X, sy * h.Y, sz * h.Z)
						reach = math.max(reach, math.sqrt(w.X * w.X + w.Z * w.Z))
						top = math.max(top, w.Y)
					end
				end
			end
		end
	end
	return { parts = parts, partCount = #parts, reach = round(reach), top = round(top) }
end

describe("FL-0136 phase 3: node marker dump", function()
	it("builds the marker on every node model (stand-in and mesh) the way WorldService does", function()
		local Props = require("@game/ReplicatedStorage/Game/Kit/Props")
		local lift = tonumber(process.env.FORGE_NODE_MARKER_LIFT or "")
		if lift then
			Props.NODE_MARKER_LIFT = lift
		end
		local size = tonumber(process.env.FORGE_NODE_MARKER_ORB or "")
		if size then
			Props.NODE_MARKER_ORB = size
		end
		local post = tonumber(process.env.FORGE_NODE_MARKER_POST or "")
		if post then
			Props.NODE_MARKER_POST = post
		end
		local out = {}
		local seen = {}
		for _, n in Layout.resourceNodes do
			local key = `{n.assetId}|{n.resource}`
			if not seen[key] then
				seen[key] = true
				EnvKit.uninstall()
				local a = Kit.prop(n.assetId)
				expect(Kit.nodeMarker(a, n.resource)).toBe(true)
				out[`{key}|standin`] = dump(a)
				EnvKit.install(Data, EnvKit.assets(Data, { folder = true }))
				local b = Kit.prop(n.assetId)
				expect(b:GetAttribute("KitEnvMesh")).toBe(true)
				expect(Kit.nodeMarker(b, n.resource)).toBe(true)
				out[`{key}|mesh`] = dump(b)
				EnvKit.uninstall()
			end
		end
		local o = process.env.FORGE_ENV_NODEMARKERS
		if o and o ~= "" then
			local n = 0
			for _ in out do
				n += 1
			end
			fs.writeFile(o, serde.encode("json", { markers = out }, false))
			print(`nodemarkers: {n} marker sets -> {o}`)
		end
	end)
end)
