-- check.sh step "plugin props" (roblox/scripts/PluginProps.luau): what counts as a write to a Plugin-security
-- property, what does not, and the plugin-context waiver (FORGE-07's #261 M1: nothing tested the scanner).
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local PluginProps = require("../../../scripts/PluginProps")

local function hits(source: string): { string }
	local out = {}
	for _, hit in PluginProps.scan(source) do
		table.insert(out, `{hit.line}:{hit.prop}`)
	end
	return out
end

describe("scripts/PluginProps", function()
	it("finds a dot write, with or without spaces, and in a one-line pcall", function()
		expect(hits("mesh.CollisionFidelity = Enum.CollisionFidelity.Hull")).toEqual({ "1:CollisionFidelity" })
		expect(hits("mesh.RenderFidelity=Enum.RenderFidelity.Performance")).toEqual({ "1:RenderFidelity" })
		expect(hits("pcall(function() p . MeshId = id end)")).toEqual({ "1:MeshId" })
		expect(hits("local ok = pcall(function()\n\tsa.NormalMap = url\nend)")).toEqual({ "2:NormalMap" })
	end)

	it("finds a bracket write with either quote, and rawset", function()
		expect(hits('mesh["CollisionFidelity"] = x')).toEqual({ "1:CollisionFidelity" })
		expect(hits("mesh[ 'RenderFidelity' ]=x")).toEqual({ "1:RenderFidelity" })
		expect(hits('rawset(mesh, "MeshId", id)')).toEqual({ "1:MeshId" })
	end)

	it("finds a write split over two lines", function()
		expect(hits("mesh.CollisionFidelity\n\t= Enum.CollisionFidelity.Box")).toEqual({ "1:CollisionFidelity" })
		expect(hits("mesh.CollisionFidelity\n\t== Enum.CollisionFidelity.Box")).toEqual({})
	end)

	it("finds a key in a table constructor (applied by an instance[k] = v helper)", function()
		expect(hits("Create('MeshPart', { CollisionFidelity = Enum.CollisionFidelity.Hull })")).toEqual({
			"1:CollisionFidelity",
		})
		expect(hits("local props = {\n\tSize = s,\n\tRenderFidelity = r,\n}")).toEqual({ "3:RenderFidelity" })
		expect(hits("local t = { Anchored = true, NormalMap = n }")).toEqual({ "1:NormalMap" })
	end)

	it("finds the Workspace, Lighting, script and HttpService properties too", function()
		expect(hits("workspace.StreamingEnabled = true")).toEqual({ "1:StreamingEnabled" })
		expect(hits("game.Lighting.Technology = Enum.Technology.Future")).toEqual({ "1:Technology" })
		expect(hits("script.Source = code")).toEqual({ "1:Source" })
		expect(hits("HttpService.HttpEnabled = true")).toEqual({ "1:HttpEnabled" })
	end)

	it("does not count reads, comparisons or other properties", function()
		expect(hits("if mesh.CollisionFidelity == Enum.CollisionFidelity.Hull then end")).toEqual({})
		expect(hits("local f = mesh.CollisionFidelity")).toEqual({})
		expect(hits("print(mesh.RenderFidelity, mesh.MeshId)")).toEqual({})
		expect(hits("if mesh.MeshId ~= '' then end")).toEqual({})
		expect(hits("mesh.CollisionGroup = 'Props'")).toEqual({})
		expect(hits("part.Material = Enum.Material.Wood")).toEqual({})
		expect(hits("mesh.MeshIdx = 1")).toEqual({})
	end)

	it("ignores comments, block comments of any level and code inside strings", function()
		expect(hits("-- mesh.CollisionFidelity = Hull")).toEqual({})
		expect(hits("x = 1 -- mesh.CollisionFidelity = Hull")).toEqual({})
		expect(hits("--[[\nmesh.CollisionFidelity = Hull\n]]")).toEqual({})
		expect(hits("--[==[\nmesh.CollisionFidelity = Hull ]]\n]==]")).toEqual({})
		expect(hits('local s = "mesh.CollisionFidelity = Hull"')).toEqual({})
		expect(hits("local s = [[\nmesh.RenderFidelity = x\n]]")).toEqual({})
		expect(hits('local s = "say \\"mesh.MeshId = 1\\""')).toEqual({})
	end)

	it("still scans the code after a block comment or long string closes on the same line", function()
		expect(hits("--[[ note ]] mesh.CollisionFidelity = Hull")).toEqual({ "1:CollisionFidelity" })
		expect(hits("--[[\nnote\n]] mesh.RenderFidelity = r")).toEqual({ "3:RenderFidelity" })
		expect(hits("local s = [[x]]; mesh.MeshId = id")).toEqual({ "1:MeshId" })
	end)

	it("skips a line whose comment says plugin-context, and only that line", function()
		expect(hits("mesh.CollisionFidelity = Hull -- plugin-context: import script only")).toEqual({})
		expect(hits("mesh.CollisionFidelity = Hull\nmesh.RenderFidelity = r -- plugin-context")).toEqual({
			"1:CollisionFidelity",
		})
		-- the word in code or in a string is not a waiver
		expect(hits('mesh.CollisionFidelity = "plugin-context"')).toEqual({ "1:CollisionFidelity" })
	end)

	it("reports each write on its own line number", function()
		expect(hits("a.MeshId = 1\n\nb.MeshId = 2\nc.NormalMap = 3")).toEqual({ "1:MeshId", "3:MeshId", "4:NormalMap" })
	end)

	it("knows the properties the B22 bug and the API dump name", function()
		for _, name in { "CollisionFidelity", "RenderFidelity", "MeshId", "NormalMap", "StreamingEnabled", "Source" } do
			expect(PluginProps.PROPERTIES).toContain(name)
		end
		-- DoubleSided is writable at runtime per the API dump; listing it would only make false alarms
		expect(PluginProps.PROPERTIES).never.toContain("DoubleSided")
	end)
end)
