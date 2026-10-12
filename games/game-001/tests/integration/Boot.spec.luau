-- game-001 integration (FORGE-05): the framework and game trees boot together headlessly.
--
-- Runs under the game-001 project (check.sh "game specs"):
--   lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests
--
-- Every service in roblox/src/server/Services and games/game-001/src/server/Services (and every
-- controller in both client trees) is required, validated and booted together with MockEnv, the
-- way Main.server/Main.client do it in Roblox: one dependency graph across trees and workers.
-- A service that only works alone fails here; so does a missing dependency, a cycle across
-- workers, or a name used in both trees. Remotes declarations from both trees are passed in as
-- env.sharedModules("Remotes"), like Env.live() collects them.
local fs = require("@lune/fs")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameConfig = require("@game/ReplicatedStorage/Forge/Config/Game")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")

-- (filesystem directory, DataModel path for @game requires)
local SERVER_TREES = {
	{ dir = "roblox/src/server/Services", dm = "ServerScriptService/Forge/Services" },
	{ dir = "games/game-001/src/server/Services", dm = "ServerScriptService/Game/Services" },
}
local CLIENT_TREES = {
	{ dir = "roblox/src/client/Controllers", dm = "StarterPlayer/StarterPlayerScripts/Forge/Controllers" },
	{ dir = "games/game-001/src/client/Controllers", dm = "StarterPlayer/StarterPlayerScripts/Game/Controllers" },
}
local SHARED_ROOTS = {
	{ dir = "roblox/src/shared", dm = "ReplicatedStorage/Forge" },
	{ dir = "games/game-001/src/shared", dm = "ReplicatedStorage/Game" },
}

-- Module names directly in `dir` (what Loader.discover would see as ModuleScripts).
local function moduleNames(dir: string): { string }
	local names = {}
	local full = T.root .. "/" .. dir
	if not fs.isDir(full) then
		return names
	end
	for _, entry in fs.readDir(full) do
		local name = string.match(entry, "^(.-)%.luau$")
		if name and not string.find(name, "%.") and fs.isFile(full .. "/" .. entry) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

-- Every definition in the trees, with the same duplicate check as Loader.discoverAll.
local function definitionsIn(trees): ({ any }, number)
	local definitions, definedIn, files = {}, {}, 0
	for _, tree in trees do
		for _, name in moduleNames(tree.dir) do
			files += 1
			local definition = Loader.validate(require(`@game/{tree.dm}/{name}`), `{tree.dir}/{name}`)
			if definition.name ~= name then
				error(`{tree.dir}/{name}.luau declares name '{definition.name}'; it must match the module name`)
			end
			if definedIn[name] then
				error(`'{name}' is defined in both {definedIn[name]} and {tree.dir}; names must be unique across trees`)
			end
			definedIn[name] = tree.dir
			table.insert(definitions, definition)
		end
	end
	return definitions, files
end

-- env.sharedModules("Remotes") as Env.live() builds it across Forge and Game.
local function remotesByArea(): { [string]: any }
	local result, foundIn = {}, {}
	for _, root in SHARED_ROOTS do
		local full = T.root .. "/" .. root.dir
		if fs.isDir(full) then
			for _, area in fs.readDir(full) do
				-- (isDir first: Lune's fs.isFile errors when a path component is a file, e.g. .gitkeep)
				if fs.isDir(`{full}/{area}`) and fs.isFile(`{full}/{area}/Remotes.luau`) then
					if foundIn[area] then
						error(`area '{area}' has Remotes in both {foundIn[area]} and {root.dir} (Env.sharedModules)`)
					end
					foundIn[area] = root.dir
					result[area] = require(`@game/{root.dm}/{area}/Remotes`)
				end
			end
		end
	end
	return result
end

describe("game-001 project wiring (FL-0046)", function()
	it("Config is games/game-001/config (Config/Game.id = game-001)", function()
		expect(GameConfig.id).toBe("game-001")
	end)

	it("every server service in both trees loads, validates and sorts into one graph", function()
		local definitions, files = definitionsIn(SERVER_TREES)
		expect(#definitions).toBe(files)
		expect(#Loader.sort(definitions)).toBe(files)
	end)

	it("every client controller in both trees loads, validates and sorts into one graph", function()
		local definitions, files = definitionsIn(CLIENT_TREES)
		expect(#definitions).toBe(files)
		expect(#Loader.sort(definitions)).toBe(files)
	end)
end)

describe("game-001 headless boot (FL-0046)", function()
	it("the server boots every service from both trees and runs 10 virtual seconds without errors", function()
		local definitions = definitionsIn(SERVER_TREES)
		local env = MockEnv.new({ seed = 1, sharedModules = { Remotes = remotesByArea() } })
		local registry = Loader.load(env, definitions)
		expect(#registry.order).toBe(#definitions)
		env.mock:advance(10)
		expect(env.mock.threadErrors).toEqual({})
		registry:destroy()
	end)

	it("a client boots every controller from both trees and runs 10 virtual seconds without errors", function()
		local definitions = definitionsIn(CLIENT_TREES)
		local env = MockEnv.new({
			seed = 1,
			isServer = false,
			localPlayer = { userId = 1001, name = "Ruler" },
			sharedModules = { Remotes = remotesByArea() },
		})
		local registry = Loader.load(env, definitions)
		expect(#registry.order).toBe(#definitions)
		env.mock:advance(10)
		expect(env.mock.threadErrors).toEqual({})
		registry:destroy()
	end)
end)
