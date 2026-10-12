-- The cross-tree require rule (D-017) and module identity under the Lune harness.
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local ModuleLoader = require("../../harness/ModuleLoader")

local SignalViaGame = require("@game/ReplicatedStorage/Forge/Core/Signal")
local SignalViaPath = require("../../../src/shared/Core/Signal")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local GameConfig = require("@game/ReplicatedStorage/Forge/Config/Game")

local FIXTURE = T.root .. "/roblox/tests/fixtures/identity"

local function fixtureLoader()
	local loads = {}
	local loader = ModuleLoader.new({
		root = T.root,
		projectFile = FIXTURE .. "/fixture.project.json",
		nativeRequire = function(path)
			error("fixture modules must not reach Lune libraries: " .. path)
		end,
	})
	loader.onLoad = function(file)
		loads[file] = (loads[file] or 0) + 1
	end
	return loader, loads
end

describe("module identity (real project)", function()
	it("@game/... and a filesystem-relative path give the same module table", function()
		expect(rawequal(SignalViaGame, SignalViaPath)).toBe(true)
	end)

	it("a shared module that requires Signal relatively shares that identity", function()
		-- GameEvents requires "../Core/Signal"; the spec reached Signal through "@game".
		expect(getmetatable(GameEvents.PlayerReady)).toBe(SignalViaGame)
	end)

	it("Config (games/sandbox/config) is reachable as ReplicatedStorage.Forge.Config", function()
		expect(GameConfig.id).toBe("sandbox")
	end)
end)

describe("module identity (fixture project with shared + server trees)", function()
	it("relative, nested-relative and @game requires load Counter exactly once", function()
		local loader, loads = fixtureLoader()
		local writer = loader:requireFile(FIXTURE .. "/server/Services/Writer.luau")
		local reader = loader:requireFile(FIXTURE .. "/shared/Reader.luau")
		local deep = loader:requireFile(FIXTURE .. "/shared/Nested/Deep.luau")
		local sibling = loader:requireFile(FIXTURE .. "/server/Services/Sibling.luau")
		expect(writer.bump()).toBe(1)
		expect(reader.read()).toBe(1)
		expect(rawequal(writer.counter, reader.counter)).toBe(true)
		expect(rawequal(deep.counter, reader.counter)).toBe(true)
		expect(rawequal(sibling.writer, writer)).toBe(true)
		expect(loads[FIXTURE .. "/shared/Counter.luau"]).toBe(1)
		expect(loads[FIXTURE .. "/server/Services/Writer.luau"]).toBe(1)
	end)

	it("resolves @game into a nested mount (Config inside Forge)", function()
		local loader = fixtureLoader()
		expect(loader:requireFile(FIXTURE .. "/shared/UsesConfig.luau").settingsName).toBe("fixture-settings")
	end)

	it("each loader is a fresh module registry (spec files do not share state)", function()
		local first = fixtureLoader():requireFile(FIXTURE .. "/shared/Counter.luau")
		local second = fixtureLoader():requireFile(FIXTURE .. "/shared/Counter.luau")
		expect(rawequal(first, second)).toBe(false)
	end)
end)

describe("specs (outside the project trees) may reach any tree by @game", function()
	it("a spec can require a server module that game code may not", function()
		local loader = fixtureLoader()
		local specFile = T.root .. "/roblox/tests/unit/contracts/ModuleIdentity.spec.luau"
		local writer = loader:require(specFile, "@game/ServerScriptService/Forge/Services/Writer")
		expect(type(writer.bump)).toBe("function")
	end)
end)

describe("rejected require forms (what Roblox or D-017 rejects)", function()
	local cases = {
		{ "CycleA", "required recursively" },
		{ "SelfAlias", "'@self' is not an allowed require form" },
		{ "RequiresScript", "ServerScriptService.Forge.Main is a script" },
		{ "Missing", "no ModuleScript at ReplicatedStorage.Forge.Bad.Nope" },
		{ "NoReturn", "did not return exactly one value" },
		{ "UsesLune", "'@lune/...' is not available to Roblox code" },
		{ "NoPrefix", "must start with './', '../' or '@game/'" },
		{ "Folder", "ReplicatedStorage.Forge.Nested is a folder" },
		{ "ReachesServer", "may only reach ReplicatedStorage/Forge" },
		{ "RelativeIntoConfig", "crosses into another source tree" },
		{ "GameSameTree", "stays inside its own source tree" },
	}
	for _, case in cases do
		it(`{case[1]} fails with "{case[2]}"`, function()
			local loader = fixtureLoader()
			expect(function()
				loader:requireFile(FIXTURE .. "/shared/Bad/" .. case[1] .. ".luau")
			end).toThrow(case[2])
		end)
	end
end)
