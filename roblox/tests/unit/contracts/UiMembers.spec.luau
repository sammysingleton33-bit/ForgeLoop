-- check.sh step "ui members" (roblox/scripts/UiMembers.luau): what a live client refuses that Lune lets through
-- (FORGE-00, B22 HUD P0). Built on Lune's reflection database, like the check itself.
local roblox = require("@lune/roblox")

local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local UiMembers = require("../../../scripts/UiMembers")

local index = UiMembers.index(roblox.getReflectionDatabase())

local function hits(source: string): { string }
	local out = {}
	for _, hit in UiMembers.scan(source, index) do
		table.insert(out, `{hit.line}:{hit.kind}:{hit.name}`)
	end
	return out
end

describe("scripts/UiMembers", function()
	it("flags a write to a read-only GUI property in every write shape", function()
		expect(hits("frame.AbsoluteSize = Vector2.new(1, 1)")).toEqual({ "1:write:AbsoluteSize" })
		expect(hits('label["TextBounds"] = v')).toEqual({ "1:write:TextBounds" })
		expect(hits('Create("TextLabel", { Name = "X", TextBounds = v })')).toEqual({ "1:write:TextBounds" })
		expect(hits("local t = {\n\tAbsolutePosition = p,\n}")).toEqual({ "2:write:AbsolutePosition" })
	end)

	it("passes writable properties, reads and comparisons", function()
		expect(hits("frame.Size = UDim2.new()\nstroke.Transparency = 0.2\npart.Shape = s")).toEqual({})
		expect(hits("local w = label.TextBounds.X\nif frame.AbsoluteSize == v then end")).toEqual({})
		expect(hits("-- frame.AbsoluteSize = v")).toEqual({})
		expect(hits("local FRAME = { A = 1, B = 2 }\nParts.C = C")).toEqual({}) -- one-letter names
	end)

	it("flags GetPropertyChangedSignal of a property no class has, and passes a real one", function()
		expect(hits('x:GetPropertyChangedSignal("AbsoluteSise")')).toEqual({ "1:signal:AbsoluteSise" })
		expect(hits('x:GetPropertyChangedSignal("AbsoluteSize")')).toEqual({})
	end)

	it("flags an Enum item that does not exist, and passes a real one", function()
		expect(hits("local f = Enum.FontWeight.Boldest")).toEqual({ "1:enum:FontWeight.Boldest" })
		expect(hits("local f = Enum.FontWeight.Bold")).toEqual({})
	end)

	it("lexes like PluginProps: a -- inside a string, block comments, rawset (FORGE-05 M1 and L1 on #291)", function()
		expect(hits('label.Text = "a -- b"; frame.AbsoluteSize = v')).toEqual({ "1:write:AbsoluteSize" })
		expect(hits("--[[\n\tframe.AbsoluteSize = v\n]]\nlocal x = 1")).toEqual({})
		expect(hits('rawset(frame, "AbsoluteSize", v)')).toEqual({ "1:write:AbsoluteSize" })
		expect(hits('print("Enum.FontWeight.Boldest")')).toEqual({}) -- string contents are not code
	end)

	it("skips a line that carries member-ok", function()
		expect(hits("frame.AbsoluteSize = v -- member-ok: a plain table, not an Instance")).toEqual({})
	end)
end)
