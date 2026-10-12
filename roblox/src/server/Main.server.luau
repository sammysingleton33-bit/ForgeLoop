--[[
	Server entry point (ServerScriptService.Forge.Main). Owned by FORGE-05.

	Builds the live Env, logs the build stamp, then loads every service definition in
	ServerScriptService.Forge.Services in dependency order (Contracts/Loader, interfaces §3).
	Add a service by adding a module to roblox/src/server/Services/ — never edit this file for it.
]]

local BuildStamp = require("@game/ReplicatedStorage/Forge/Contracts/BuildStamp")
local Env = require("@game/ReplicatedStorage/Forge/Contracts/Env")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")

local env = Env.live()
local build = BuildStamp.read(env.ReplicatedStorage:FindFirstChild("Forge"))
local startFields = BuildStamp.fields(build)
startFields.jobId = env.jobId
env.log("info", "ForgeLoop server starting", startFields)

local registry = Loader.boot(env, script.Parent:FindFirstChild("Services"))
env.log("info", "ForgeLoop server services started", {
	count = #registry.order,
	order = if #registry.order > 0 then table.concat(registry.order, " > ") else "(none)",
	sha = startFields.sha,
})
