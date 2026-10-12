-- RequirePath: the require scanner and the D-017 policy shared by the place check and the loader.
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local RequirePath = require("../../harness/RequirePath")

local function only(source: string)
	local found = RequirePath.scan(source)
	expect(#found).toBe(1)
	return found[1]
end

describe("RequirePath.scan", function()
	it("finds a top-level literal require with its line", function()
		local found = only('local A = 1\nlocal Signal = require("../Core/Signal")\n')
		expect(found.path).toBe("../Core/Signal")
		expect(found.line).toBe(2)
		expect(found.depth).toBe(0)
	end)

	it("a StyLua-wrapped top-level require (continuation line) is still top level", function()
		-- what StyLua 2.6 (column_width 120) makes of a long `local X = require(...)`
		local source = "local RewardTablesForSeasonalLimitedEvents =\n"
			.. '\trequire("@game/ReplicatedStorage/Forge/Economy/RewardTablesForSeasonalLimitedEvents")\n'
		local found = only(source)
		expect(found.line).toBe(2)
		expect(found.depth).toBe(0)
	end)

	it("counts blocks: function, if, do, while, for, repeat", function()
		local cases = {
			'local function f()\n\tlocal X = require("./X")\nend',
			'if ok then\n\trequire("./X")\nend',
			'do\n\trequire("./X")\nend',
			'while busy do\n\trequire("./X")\nend',
			'for i = 1, 2 do\n\trequire("./X")\nend',
			'for _, v in list do\n\trequire("./X")\nend',
			'repeat\n\trequire("./X")\nuntil done',
			'local t = { f = function()\n\treturn require("./X")\nend }',
		}
		for _, source in cases do
			expect(only(source).depth).toBe(1)
		end
		local after =
			RequirePath.scan('local function f()\n\tif a then\n\t\treturn 1\n\tend\nend\nlocal X = require("./X")')
		expect(after[1].depth).toBe(0)
	end)

	it("an if-expression is not a block (no `end`)", function()
		local source = 'local Mode = if isServer then "s" else "c"\nlocal X = require("./X")\n'
			.. 'local Y = if a then if b then 1 else 2 else 3\nlocal Z = require("./Z")'
		local found = RequirePath.scan(source)
		expect(#found).toBe(2)
		expect(found[1].depth).toBe(0)
		expect(found[2].depth).toBe(0)
		local nested = only('local f = function()\n\treturn if x then 1 else 2\nend\nlocal X = require("./X")')
		expect(nested.depth).toBe(0)
	end)

	it("ignores require inside comments and string literals", function()
		local source = table.concat({
			'-- require("./Commented")',
			'--[[ require("./Block") ]]',
			'local msg = "call require(x) first"',
			"local s = [[require('./Long')]]",
			'local t = `require("{name}")`',
			'error("set up with require(module) before use")',
		}, "\n")
		expect(#RequirePath.scan(source)).toBe(0)
	end)

	it("reports non-literal requires with path = nil", function()
		local source = "local a = require(script.Parent.X)\nlocal b = require(`./{name}`)\nlocal load = require"
		local found = RequirePath.scan(source)
		expect(#found).toBe(3)
		for _, entry in found do
			expect(entry.path).toBeNil()
		end
	end)

	it('accepts require "x" call syntax and ignores members named require', function()
		expect(only('local X = require "./X"').path).toBe("./X")
		expect(#RequirePath.scan('loader:require("./X")\nlocal y = obj.require')).toBe(0)
	end)
end)

describe("RequirePath.checkPolicy (D-017, interfaces §1)", function()
	local shared, config, server, client =
		{ name = "shared" }, { name = "config" }, { name = "server" }, { name = "client" }
	local function check(path: string, fromMount, toMount, target: { string }): string?
		return RequirePath.checkPolicy(RequirePath.parse(path), fromMount, toMount, target)
	end

	it("allows relative inside a tree and @game into ReplicatedStorage/Forge from another tree", function()
		expect(check("../Core/Signal", shared, shared, { "ReplicatedStorage", "Forge", "Core", "Signal" })).toBeNil()
		expect(
			check(
				"@game/ReplicatedStorage/Forge/Core/Signal",
				server,
				shared,
				{ "ReplicatedStorage", "Forge", "Core", "Signal" }
			)
		).toBeNil()
		expect(
			check(
				"@game/ReplicatedStorage/Forge/Config/Game",
				shared,
				config,
				{ "ReplicatedStorage", "Forge", "Config", "Game" }
			)
		).toBeNil()
	end)

	it("rejects relative paths across trees and @game inside one tree", function()
		expect(check("../Config/Game", shared, config, { "ReplicatedStorage", "Forge", "Config", "Game" })).toContain(
			'use "@game/ReplicatedStorage/Forge/Config/Game"'
		)
		expect(
			check(
				"@game/ReplicatedStorage/Forge/Core/Signal",
				shared,
				shared,
				{ "ReplicatedStorage", "Forge", "Core", "Signal" }
			)
		).toContain("use a relative path")
	end)

	it("rejects @game into server or client trees, whoever asks", function()
		local secret = { "ServerScriptService", "Forge", "Services", "SecretService" }
		local controller = { "StarterPlayer", "StarterPlayerScripts", "Forge", "Controllers", "ProbeController" }
		expect(check("@game/ServerScriptService/Forge/Services/SecretService", client, server, secret)).toContain(
			"may only reach ReplicatedStorage/Forge"
		)
		expect(
			check(
				"@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/ProbeController",
				shared,
				client,
				controller
			)
		).toContain("may only reach ReplicatedStorage/Forge")
		expect(check("@game/ServerStorage/Forge/X", server, nil, { "ServerStorage", "Forge", "X" })).toContain(
			"may only reach ReplicatedStorage/Forge"
		)
	end)
end)
