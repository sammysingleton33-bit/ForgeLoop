--[[
	Client entry point (StarterPlayer.StarterPlayerScripts.Forge.Main). Owned by FORGE-05.

	Waits for the initial replication (require-by-string does not wait for instances), builds the
	live Env, logs the build stamp, then loads every controller definition in
	StarterPlayerScripts.Forge.Controllers in dependency order (Contracts/Loader, interfaces §3).
	Add a controller by adding a module to roblox/src/client/Controllers/ — never edit this file for it.
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local BuildStamp = require("@game/ReplicatedStorage/Forge/Contracts/BuildStamp")
local Env = require("@game/ReplicatedStorage/Forge/Contracts/Env")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")

local env = Env.live()
local build = BuildStamp.read(env.ReplicatedStorage:FindFirstChild("Forge"))
env.log("info", "ForgeLoop client starting", BuildStamp.fields(build))

local registry = Loader.boot(env, script.Parent:FindFirstChild("Controllers"))
env.log("info", "ForgeLoop client controllers started", {
	count = #registry.order,
	order = if #registry.order > 0 then table.concat(registry.order, " > ") else "(none)",
})
