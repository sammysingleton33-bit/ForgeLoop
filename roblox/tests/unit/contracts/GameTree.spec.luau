-- Framework (Forge) + game (Game) trees in one project (D-022): require policy, module identity and
-- Loader discovery across trees, on a fixture that mirrors games/game-001/default.project.json.
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MockEnv = require("../../mocks/MockEnv")
local ModuleLoader = require("../../harness/ModuleLoader")
local Project = require("../../harness/Project")
local RequirePath = require("../../harness/RequirePath")

local FIXTURE = T.root .. "/roblox/tests/fixtures/gametree"

local function fixtureLoader()
	local loads = {}
	local loader = ModuleLoader.new({
		root = T.root,
		projectFile = FIXTURE .. "/game.project.json",
		nativeRequire = function(path)
			error("fixture modules must not reach Lune libraries: " .. path)
		end,
	})
	loader.onLoad = function(file)
		loads[file] = (loads[file] or 0) + 1
	end
	return loader, loads
end

describe("game tree requires (D-022)", function()
	it("game server code reaches framework and game shared code by @game; one identity each", function()
		local loader, loads = fixtureLoader()
		local kingdom = loader:requireFile(FIXTURE .. "/game/server/Services/KingdomService.luau")
		local types = loader:requireFile(FIXTURE .. "/game/shared/Kingdom/Types.luau")
		local thing = loader:requireFile(FIXTURE .. "/forge/shared/Core/Thing.luau")
		expect(rawequal(types.framework, thing)).toBe(true)
		expect(kingdom.name).toBe("KingdomService")
		expect(loads[FIXTURE .. "/game/shared/Kingdom/Types.luau"]).toBe(1)
		expect(loads[FIXTURE .. "/forge/shared/Core/Thing.luau"]).toBe(1)
	end)

	it("game client code and game config reach game shared code", function()
		local loader = fixtureLoader()
		expect(loader:requireFile(FIXTURE .. "/game/client/Controllers/RulerController.luau").client).toBe(true)
		expect(loader:requireFile(FIXTURE .. "/config/Game.luau").id).toBe("fixture")
	end)

	it("framework code may never require game code", function()
		local loader = fixtureLoader()
		expect(function()
			loader:requireFile(FIXTURE .. "/forge/shared/Bad/ReachesGame.luau")
		end).toThrow("framework code never requires game code (D-022)")
	end)

	it("game code inside the Game shared tree uses relative paths, not @game", function()
		local loader = fixtureLoader()
		expect(function()
			loader:requireFile(FIXTURE .. "/game/shared/Bad/SelfGame.luau")
		end).toThrow("stays inside its own source tree")
	end)

	it("game server code still cannot reach a server tree by @game", function()
		local loader = fixtureLoader()
		expect(function()
			loader:requireFile(FIXTURE .. "/game/server/Bad/ReachesForgeServer.luau")
		end).toThrow('"@game/" may only reach ReplicatedStorage/Forge/... ')
	end)

	it("isFrameworkMount: Forge trees are framework, Config and Game trees are not", function()
		local project = Project.load(FIXTURE .. "/game.project.json")
		local function mountAt(path: string)
			return project:mountForDataModel(string.split(path, "."))
		end
		expect(RequirePath.isFrameworkMount(mountAt("ReplicatedStorage.Forge.Core"))).toBe(true)
		expect(RequirePath.isFrameworkMount(mountAt("ServerScriptService.Forge.Services"))).toBe(true)
		expect(RequirePath.isFrameworkMount(mountAt("ReplicatedStorage.Forge.Config.Game"))).toBe(false)
		expect(RequirePath.isFrameworkMount(mountAt("ReplicatedStorage.Game.Kingdom"))).toBe(false)
		expect(RequirePath.isFrameworkMount(mountAt("StarterPlayer.StarterPlayerScripts.Game"))).toBe(false)
		expect(RequirePath.isFrameworkMount(nil)).toBe(false)
	end)
end)

describe("Loader across the Forge and Game service trees", function()
	-- Instance folders standing in for ServerScriptService.Forge.Services / .Game.Services, with
	-- each ModuleScript resolved to the fixture file of the same name.
	local function servicesFolder(name: string, moduleNames: { string })
		local folder = Instance.new("Folder")
		folder.Name = name
		for _, moduleName in moduleNames do
			local module = Instance.new("ModuleScript")
			module.Name = moduleName
			module.Parent = folder
		end
		return folder
	end

	it("boots a game service after the framework service it depends on", function()
		local loader = fixtureLoader()
		local files = {
			DataService = FIXTURE .. "/forge/server/Services/DataService.luau",
			KingdomService = FIXTURE .. "/game/server/Services/KingdomService.luau",
		}
		local registry = Loader.boot(MockEnv.new(), {
			servicesFolder("ForgeServices", { "DataService" }),
			servicesFolder("GameServices", { "KingdomService" }),
		}, function(module)
			return loader:requireFile(files[module.Name])
		end)
		expect(registry.order).toEqual({ "DataService", "KingdomService" })
		expect(registry:get("KingdomService").data.kind).toBe("data")
	end)
end)
