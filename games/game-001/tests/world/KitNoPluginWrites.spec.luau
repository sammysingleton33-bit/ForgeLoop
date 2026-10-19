--!nonstrict
--[[
	Kit never writes a property that needs plugin rights (FL-0136 / D-057 follow-up; found by FORGE-00's CONTRACTS verify
	pass). MeshPart.CollisionFidelity has Plugin security: a game script that writes it fails ("The current thread cannot
	write 'CollisionFidelity' (lacking capability Plugin)"), the build inside Kit's pcall is rejected, and every mesh prop and
	every mesh rig falls back to part-built in a live server while the headless specs (Lune has no such check) stay green.
	The Studio import scripts set these (the command bar has plugin rights) and the saved Forge.Assets models carry them.

	This is a static scan of every Kit/*.luau: no assignment to .CollisionFidelity, .RenderFidelity, .MeshId or .DoubleSided.
	Reading them is fine (Kit/EnvMesh reads MeshId to see that an import has a mesh).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local fs = require("@lune/fs")

local KIT_DIR = "games/game-001/src/shared/Kit"
local FORBIDDEN = { "CollisionFidelity", "RenderFidelity", "MeshId", "DoubleSided" }

-- Strips comments (--[[ ]] blocks and -- to end of line) so prose that names a property is not mistaken for code.
local function code(source: string): string
	source = string.gsub(source, "%-%-%[(=*)%[.-%]%1%]", "")
	source = string.gsub(source, "%-%-[^\n]*", "")
	return source
end

-- The offending assignments in a source text: "<expr>.Name = value" (not "==", not a read).
local function writesIn(source: string): { string }
	local found = {}
	local stripped = code(source)
	for _, name in FORBIDDEN do
		for line in string.gmatch(stripped, "[^\n]+") do
			if string.find(line, "%." .. name .. "%s*=[^=]") then
				table.insert(found, line)
			end
		end
	end
	return found
end

describe("Kit writes no plugin-only property", function()
	it("scans the scanner: it finds a write, ignores a read, a comparison and a comment", function()
		expect(#writesIn("mesh.CollisionFidelity = Enum.CollisionFidelity.Hull")).toBe(1)
		expect(#writesIn("part.MeshId = 'rbxassetid://1'")).toBe(1)
		expect(#writesIn("clone.RenderFidelity=Enum.RenderFidelity.Precise")).toBe(1)
		expect(#writesIn("x.DoubleSided = true")).toBe(1)
		expect(#writesIn("local id = part.MeshId")).toBe(0)
		expect(#writesIn("if part.MeshId == '' then")).toBe(0)
		expect(#writesIn("-- mesh.CollisionFidelity = Hull in a comment")).toBe(0)
		expect(#writesIn("--[[ part.MeshId = 1 ]] local ok = true")).toBe(0)
	end)

	it("no Kit/*.luau assigns CollisionFidelity, RenderFidelity, MeshId or DoubleSided", function()
		local checked = 0
		for _, entry in fs.readDir(KIT_DIR) do
			if string.match(entry, "%.luau$") then
				checked += 1
				local found = writesIn(fs.readFile(`{KIT_DIR}/{entry}`))
				if #found > 0 then
					error(
						`{KIT_DIR}/{entry} writes a property a game script cannot write: {table.concat(found, " | ")}`
					)
				end
			end
		end
		expect(checked).toBeGreaterThan(10) -- Kit/*.luau
	end)
end)
