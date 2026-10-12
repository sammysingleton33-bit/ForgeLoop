--!strict
--[[
	Contracts/Env — the environment every service/controller receives instead of calling
	game:GetService directly (docs/architecture/interfaces.md §2, contract v0.3).

	API
		Env.live(): Env          -- the real environment; only valid inside Roblox
		Env.SERVICE_FIELDS       -- names of the service fields (all typed `any`)
		Env.FUNCTION_FIELDS      -- names of the function fields
		Env.FIELDS               -- every field of the Env type (used by the MockEnv completeness spec)

	Env.live() touches `game` only when it is called, never when this module is required, so
	Lune tests can require Env freely and build fakes with roblox/tests/mocks/MockEnv.luau.

	Live behaviour
		jobId           game.JobId, or "studio-<GUID>" when it is empty (Studio play sessions)
		now()           os.time() (UTC unix seconds); clock() os.clock(); serverTimeNow() workspace:GetServerTimeNow()
		wait/spawn      task.wait / task.spawn
		random(seed?)   Random.new(seed?)
		log(level, message, fields?)  "[Forge] <level> <message> k=v ..." via print (info) or warn (warn, error)
		bindToClose(fn) game:BindToClose(fn); errors on the client (server-only API)
		newInstance     Instance.new
		sharedModules(fileName)  { [Area] = require(ReplicatedStorage.Forge.<Area>.<fileName>) } for every
		                area folder that has a ModuleScript of that name (e.g. "Remotes", interfaces §6)
		service(name)   game:GetService(name)
	Service fields that cannot be obtained on this side (pcall around GetService) are nil.
]]

export type LogLevel = "info" | "warn" | "error"

export type Env = {
	isServer: boolean,
	DataStoreService: any,
	MemoryStoreService: any,
	Players: any,
	MarketplaceService: any,
	PolicyService: any,
	AnalyticsService: any,
	RunService: any,
	HttpService: any,
	ReplicatedStorage: any,
	Workspace: any,
	TweenService: any,
	SoundService: any,
	jobId: string,
	now: () -> number, -- unix seconds (os.time / DateTime in live)
	clock: () -> number, -- monotonic seconds (os.clock)
	wait: (seconds: number) -> (),
	spawn: (fn: (...any) -> (), ...any) -> (),
	random: (seed: number?) -> any, -- Random.new
	log: (level: LogLevel, message: string, fields: { [string]: any }?) -> (),
	-- v0.2 additions
	bindToClose: (fn: () -> ()) -> (), -- game:BindToClose
	serverTimeNow: () -> number, -- workspace:GetServerTimeNow(); use for client-facing deadlines
	newInstance: (className: string) -> any, -- Instance.new (mocked in tests)
	sharedModules: (fileName: string) -> { [string]: any }, -- ReplicatedStorage.Forge.<Area>.<fileName> keyed by Area
	-- v0.3 additions
	CollectionService: any,
	Teams: any,
	ServerStorage: any,
	Lighting: any,
	UserInputService: any,
	ContextActionService: any,
	GuiService: any,
	service: (name: string) -> any, -- any other Roblox service by name (mockable)
}

local Env = {}

Env.SERVICE_FIELDS = table.freeze({
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
	"CollectionService",
	"Teams",
	"ServerStorage",
	"Lighting",
	"UserInputService",
	"ContextActionService",
	"GuiService",
})

Env.FUNCTION_FIELDS = table.freeze({
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
	"service",
})

local allFields = { "isServer", "jobId" }
for _, name in Env.SERVICE_FIELDS do
	table.insert(allFields, name)
end
for _, name in Env.FUNCTION_FIELDS do
	table.insert(allFields, name)
end
Env.FIELDS = table.freeze(allFields)

local LEVELS = { info = true, warn = true, error = true }

function Env.formatLog(level: string, message: string, fields: { [string]: any }?): string
	local parts = { `[Forge] {level} {message}` }
	if fields then
		local keys: { string } = {}
		for key in fields do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in keys do
			table.insert(parts, `{key}={tostring(fields[key])}`)
		end
	end
	return table.concat(parts, " ")
end

function Env.live(): Env
	local RunService = game:GetService("RunService")
	local HttpService = game:GetService("HttpService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local isServer = RunService:IsServer()

	local function tryService(name: string): any
		local ok, service = pcall(function()
			return game:GetService(name)
		end)
		return if ok then service else nil
	end

	local jobId = game.JobId
	if jobId == "" then
		jobId = "studio-" .. HttpService:GenerateGUID(false)
	end

	local function log(level: LogLevel, message: string, fields: { [string]: any }?)
		if not LEVELS[level] then
			error(`env.log: unknown level '{tostring(level)}' (info | warn | error)`, 2)
		end
		local line = Env.formatLog(level, message, fields)
		if level == "info" then
			print(line)
		else
			warn(line)
		end
	end

	local env: Env = {
		isServer = isServer,
		DataStoreService = tryService("DataStoreService"),
		MemoryStoreService = tryService("MemoryStoreService"),
		Players = tryService("Players"),
		MarketplaceService = tryService("MarketplaceService"),
		PolicyService = tryService("PolicyService"),
		AnalyticsService = tryService("AnalyticsService"),
		RunService = RunService,
		HttpService = HttpService,
		ReplicatedStorage = ReplicatedStorage,
		Workspace = tryService("Workspace"),
		TweenService = tryService("TweenService"),
		SoundService = tryService("SoundService"),
		jobId = jobId,
		now = function(): number
			return os.time()
		end,
		clock = function(): number
			return os.clock()
		end,
		wait = function(seconds: number)
			task.wait(seconds)
		end,
		spawn = function(fn: (...any) -> (), ...: any)
			task.spawn(fn, ...)
		end,
		random = function(seed: number?): any
			if seed == nil then
				return Random.new()
			end
			return Random.new(seed)
		end,
		log = log,
		bindToClose = function(fn: () -> ())
			if not isServer then
				error("env.bindToClose is server-only (game:BindToClose)", 2)
			end
			game:BindToClose(fn)
		end,
		serverTimeNow = function(): number
			return workspace:GetServerTimeNow()
		end,
		newInstance = function(className: string): any
			return Instance.new(className :: any)
		end,
		sharedModules = function(fileName: string): { [string]: any }
			local result = {}
			local forge = ReplicatedStorage:FindFirstChild("Forge")
			if forge == nil then
				return result
			end
			for _, area in forge:GetChildren() do
				if area:IsA("Folder") then
					local module = area:FindFirstChild(fileName)
					if module and module:IsA("ModuleScript") then
						result[area.Name] = require(module) :: any
					end
				end
			end
			return result
		end,
		CollectionService = tryService("CollectionService"),
		Teams = tryService("Teams"),
		ServerStorage = tryService("ServerStorage"),
		Lighting = tryService("Lighting"),
		UserInputService = tryService("UserInputService"),
		ContextActionService = tryService("ContextActionService"),
		GuiService = tryService("GuiService"),
		service = function(name: string): any
			return game:GetService(name :: any)
		end,
	}
	return env
end

return Env
