-- Contracts/Env: the §2 field list, and Env.live() exercised against a fake `game`.
local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Env = require("@game/ReplicatedStorage/Forge/Contracts/Env")
local MockRandom = require("../../mocks/MockRandom")
local ModuleLoader = require("../../harness/ModuleLoader")

-- interfaces.md §2, contract v0.3 (v0.1 fields + v0.2 + v0.3 additions)
local CONTRACT_FIELDS = {
	"isServer",
	"DataStoreService",
	"MemoryStoreService",
	"Players",
	"MarketplaceService",
	"PolicyService",
	"AnalyticsService",
	"RunService",
	"HttpService",
	"ReplicatedStorage",
	"Workspace",
	"TweenService",
	"SoundService",
	"jobId",
	"now",
	"clock",
	"wait",
	"spawn",
	"random",
	"log",
	"bindToClose",
	"serverTimeNow",
	"newInstance",
	"sharedModules",
	"CollectionService",
	"Teams",
	"ServerStorage",
	"Lighting",
	"UserInputService",
	"ContextActionService",
	"GuiService",
	"service",
}

local function sorted(list)
	local copy = table.clone(list)
	table.sort(copy)
	return copy
end

-- A minimal fake of the Roblox globals Env.live() touches, recording what happened.
local function fakeWorld(options)
	local record = { gameReads = 0, printed = {}, warned = {}, closeHandlers = {}, spawned = 0, waited = {} }
	local services = {}
	local function makeService(name)
		local service = { Name = name, ClassName = name }
		services[name] = service
		return service
	end
	for _, name in Env.SERVICE_FIELDS do
		makeService(name)
	end
	services.RunService.IsServer = function()
		return options.isServer
	end
	services.HttpService.GenerateGUID = function(_, wrap)
		expect(wrap).toBe(false)
		return "0f0f0f0f-aaaa-4bbb-8ccc-123456789abc"
	end
	local remotesModule = { Name = "Remotes" }
	function remotesModule:IsA(className)
		return className == "ModuleScript"
	end
	local gameplay = { Name = "Gameplay" }
	function gameplay:IsA(className)
		return className == "Folder"
	end
	function gameplay:FindFirstChild(name)
		return if name == "Remotes" then remotesModule else nil
	end
	local economy = { Name = "Economy" }
	function economy:IsA(className)
		return className == "Folder"
	end
	function economy:FindFirstChild()
		return nil
	end
	local forge = {}
	function forge:GetChildren()
		return { gameplay, economy }
	end
	-- options.gameAreas: { [areaName] = hasRemotes } builds ReplicatedStorage.Game (D-022)
	local gameRoot = nil
	if options.gameAreas then
		gameRoot = {}
		local areas = {}
		for areaName, hasRemotes in options.gameAreas do
			local area = { Name = areaName }
			function area:IsA(className)
				return className == "Folder"
			end
			function area:FindFirstChild(name)
				return if hasRemotes and name == "Remotes"
					then { Name = "Remotes:" .. areaName, IsA = remotesModule.IsA }
					else nil
			end
			table.insert(areas, area)
		end
		function gameRoot:GetChildren()
			return areas
		end
	end
	function services.ReplicatedStorage:FindFirstChild(name)
		if name == "Forge" then
			return forge
		elseif name == "Game" then
			return gameRoot
		end
		return nil
	end

	local game = setmetatable({}, {
		__index = function(_, key)
			record.gameReads += 1
			if key == "JobId" then
				return options.jobId
			elseif key == "GetService" then
				return function(_, name)
					local service = services[name]
					if service == nil then
						error("unknown service " .. tostring(name))
					end
					return service
				end
			elseif key == "BindToClose" then
				return function(_, fn)
					table.insert(record.closeHandlers, fn)
				end
			end
			return nil
		end,
	})
	local globals = {
		game = game,
		workspace = {
			GetServerTimeNow = function()
				return 123.5
			end,
		},
		task = {
			wait = function(s)
				table.insert(record.waited, s)
			end,
			spawn = function(fn, ...)
				record.spawned += 1
				fn(...)
			end,
		},
		Random = MockRandom,
		Instance = {
			new = function(className)
				return { ClassName = className }
			end,
		},
		print = function(line)
			table.insert(record.printed, line)
		end,
		warn = function(line)
			table.insert(record.warned, line)
		end,
	}
	local loader = ModuleLoader.new({
		root = T.root,
		globals = globals,
		nativeRequire = require,
		requireInstance = function(instance)
			return { required = instance.Name }
		end,
	})
	return loader, record
end

local ENV_FILE = "/roblox/src/shared/Contracts/Env.luau"

describe("Contracts/Env field list", function()
	it("Env.FIELDS is exactly the §2 v0.3 field list", function()
		expect(sorted(Env.FIELDS)).toEqual(sorted(CONTRACT_FIELDS))
	end)
end)

describe("Env.live() against a fake game", function()
	it("requiring Env does not touch game; only Env.live() does", function()
		local loader, record = fakeWorld({ isServer = true, jobId = "job-1" })
		local LiveEnv = loader:requireFile(T.root .. ENV_FILE)
		expect(record.gameReads).toBe(0)
		LiveEnv.live()
		expect(record.gameReads).toBeGreaterThan(0)
	end)

	it("fills every field and passes the real JobId through", function()
		local loader = fakeWorld({ isServer = true, jobId = "job-1" })
		local env = loader:requireFile(T.root .. ENV_FILE).live()
		for _, field in CONTRACT_FIELDS do
			expect(env[field] ~= nil).toBe(true)
		end
		expect(env.jobId).toBe("job-1")
		expect(env.isServer).toBe(true)
		expect(env.DataStoreService.Name).toBe("DataStoreService")
		expect(env.service("Teams").Name).toBe("Teams")
		expect(env.serverTimeNow()).toBe(123.5)
		expect(env.newInstance("Folder").ClassName).toBe("Folder")
	end)

	it("substitutes a non-empty studio GUID when game.JobId is empty", function()
		local loader = fakeWorld({ isServer = true, jobId = "" })
		local env = loader:requireFile(T.root .. ENV_FILE).live()
		expect(env.jobId).toBe("studio-0f0f0f0f-aaaa-4bbb-8ccc-123456789abc")
	end)

	it("bindToClose registers on the server and errors on the client", function()
		local serverLoader, serverRecord = fakeWorld({ isServer = true, jobId = "s" })
		local serverEnv = serverLoader:requireFile(T.root .. ENV_FILE).live()
		serverEnv.bindToClose(function() end)
		expect(#serverRecord.closeHandlers).toBe(1)

		local clientLoader = fakeWorld({ isServer = false, jobId = "c" })
		local clientEnv = clientLoader:requireFile(T.root .. ENV_FILE).live()
		expect(clientEnv.isServer).toBe(false)
		expect(function()
			clientEnv.bindToClose(function() end)
		end).toThrow("server-only")
	end)

	it(
		"log() formats fields: print for info, warn for warn, a red line (task.spawn(error)) for error; rejects unknown levels",
		function()
			local loader, record = fakeWorld({ isServer = true, jobId = "j" })
			local env = loader:requireFile(T.root .. ENV_FILE).live()
			env.log("info", "hello", { b = 2, a = "x" })
			env.log("warn", "careful")
			-- the fake task.spawn runs its function at once, so the red line surfaces here as the thrown error
			-- (FORGE-07 L3 on #283: errors printed yellow through warn before)
			local spawnedBefore = record.spawned
			expect(function()
				env.log("error", "bad")
			end).toThrow("[Forge] error bad")
			expect(record.spawned).toBe(spawnedBefore + 1)
			expect(record.printed).toEqual({ "[Forge] info hello a=x b=2" })
			expect(record.warned).toEqual({ "[Forge] warn careful" })
			expect(function()
				env.log("debug" :: any, "nope")
			end).toThrow("unknown level")
		end
	)

	it("sharedModules(fileName) requires that module from every area folder, keyed by area", function()
		local loader = fakeWorld({ isServer = true, jobId = "j" })
		local env = loader:requireFile(T.root .. ENV_FILE).live()
		expect(env.sharedModules("Remotes")).toEqual({ Gameplay = { required = "Remotes" } })
		expect(env.sharedModules("Nothing")).toEqual({})
	end)

	it("sharedModules spans ReplicatedStorage.Forge and ReplicatedStorage.Game (D-022)", function()
		local loader = fakeWorld({ isServer = true, jobId = "j", gameAreas = { Kingdom = true, Sim = false } })
		local env = loader:requireFile(T.root .. ENV_FILE).live()
		expect(env.sharedModules("Remotes")).toEqual({
			Gameplay = { required = "Remotes" },
			Kingdom = { required = "Remotes:Kingdom" },
		})
	end)

	it("sharedModules rejects an area that has the module in both trees", function()
		local loader = fakeWorld({ isServer = true, jobId = "j", gameAreas = { Gameplay = true } })
		local env = loader:requireFile(T.root .. ENV_FILE).live()
		expect(function()
			env.sharedModules("Remotes")
		end).toThrow(
			"area 'Gameplay' has a Remotes module in both ReplicatedStorage.Forge and ReplicatedStorage.Game"
		)
	end)

	it("wait/spawn/random delegate to task and Random", function()
		local loader, record = fakeWorld({ isServer = true, jobId = "j" })
		local env = loader:requireFile(T.root .. ENV_FILE).live()
		env.wait(2)
		local ran = false
		env.spawn(function(x)
			ran = x
		end, true)
		expect(record.waited).toEqual({ 2 })
		expect(ran).toBe(true)
		expect(env.random(5):NextInteger(1, 100)).toBe(MockRandom.new(5):NextInteger(1, 100))
		expect(type(env.now())).toBe("number")
	end)
end)
