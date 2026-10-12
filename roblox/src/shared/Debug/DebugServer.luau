--!strict
--[[
	Debug/DebugServer — serves the Studio debug panel (FL-0068, D-028). Owned by FORGE-05.

	Main.server calls DebugServer.start(env, registry) after the services boot. Outside Studio
	(RunService:IsStudio() is false) it returns nil and creates nothing: no remotes exist, so live
	servers can never run a debug command. In Studio it creates

		ReplicatedStorage.ForgeDebug.List  RemoteFunction  () -> { commands, presets }
		ReplicatedStorage.ForgeDebug.Run   RemoteFunction  ("command" | "preset", name, ...) -> { ok, message }

	Calls are rate limited per player (burst 20, 10 per second), arguments are validated by
	Debug/DebugCommands (fail closed) and every command runs under pcall, so a bad call cannot error
	the server. Built-in commands: forge.buildInfo (the BuildInfo sha), forge.services (boot order).

		DebugServer.start(env, registry?) -> Handle?   -- Handle = { folder, stop: () -> () }
]]

local BuildStamp = require("../Contracts/BuildStamp")
local DebugCommands = require("./DebugCommands")
local RateLimiter = require("../Core/RateLimiter")

export type Handle = { folder: any, stop: () -> () }

local DebugServer = {}

local function registerBuiltIns(env: any, registry: any?)
	local present = {}
	for _, entry in DebugCommands.list() do
		present[entry.name] = true
	end
	if not present["forge.buildInfo"] then
		DebugCommands.register({
			name = "forge.buildInfo",
			label = "Show BuildInfo (sha, branch)",
			run = function()
				return BuildStamp.describe(BuildStamp.read(env.ReplicatedStorage:FindFirstChild("Forge")))
			end,
		})
	end
	if not present["forge.services"] then
		DebugCommands.register({
			name = "forge.services",
			label = "List booted services",
			run = function()
				local order = if registry then registry.order else {}
				return if #order > 0 then table.concat(order, " > ") else "(none)"
			end,
		})
	end
end

function DebugServer.start(env: any, registry: any?): Handle?
	if not env.RunService:IsStudio() then
		return nil
	end
	registerBuiltIns(env, registry)

	local limiter = RateLimiter.new({ burst = 20, perSecond = 10, clock = env.clock })
	local folder = env.newInstance("Folder")
	folder.Name = "ForgeDebug"
	local list = env.newInstance("RemoteFunction")
	list.Name = "List"
	list.Parent = folder
	local run = env.newInstance("RemoteFunction")
	run.Name = "Run"
	run.Parent = folder

	list.OnServerInvoke = function(player: any)
		if not limiter:allow(player) then
			return { commands = {}, presets = {}, message = "rate limited" }
		end
		return { commands = DebugCommands.list(), presets = DebugCommands.presets() }
	end
	run.OnServerInvoke = function(player: any, kind: any, name: any, ...: any)
		if not limiter:allow(player) then
			return { ok = false, message = "rate limited" }
		end
		local ok, message
		if kind == "command" then
			ok, message = DebugCommands.run(player, name, ...)
		elseif kind == "preset" then
			ok, message = DebugCommands.runPreset(player, name)
		else
			ok, message = false, `unknown kind '{tostring(kind)}' (command | preset)`
		end
		env.log(if ok then "info" else "warn", "debug command", {
			kind = tostring(kind),
			name = tostring(name),
			ok = ok,
			userId = if typeof(player) == "Instance" then player.UserId else nil,
		})
		return { ok = ok, message = message }
	end

	local removing = env.Players.PlayerRemoving:Connect(function(player: any)
		limiter:reset(player)
	end)
	folder.Parent = env.ReplicatedStorage -- complete tree, parented last

	return {
		folder = folder,
		stop = function()
			removing:Disconnect()
			folder:Destroy()
		end,
	}
end

return DebugServer
