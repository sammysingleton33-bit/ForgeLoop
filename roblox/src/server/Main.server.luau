--[[
	Server entry point (ServerScriptService.Forge.Main). Owned by FORGE-05.

	Builds the live Env, logs the build stamp and the game id, then loads every service definition
	in ServerScriptService.Forge.Services and, in game projects (D-022), ServerScriptService.Game.Services
	— one dependency graph across both trees (Contracts/Loader, interfaces §3). In Studio only, it
	then serves the debug panel (Debug/DebugServer, FL-0068); live servers create no debug remotes.
	Add a service by adding a module to a Services folder — never edit this file for it.
]]

local BuildStamp = require("@game/ReplicatedStorage/Forge/Contracts/BuildStamp")
local DebugServer = require("@game/ReplicatedStorage/Forge/Debug/DebugServer")
local Env = require("@game/ReplicatedStorage/Forge/Contracts/Env")
local GameConfig = require("@game/ReplicatedStorage/Forge/Config/Game")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")

local env = Env.live()
local build = BuildStamp.read(env.ReplicatedStorage:FindFirstChild("Forge"))
local startFields = BuildStamp.fields(build)
startFields.jobId = env.jobId
startFields.game = GameConfig.id
env.log("info", "ForgeLoop server starting", startFields)

local folders, trees = {}, {}
for _, tree in { script.Parent, script.Parent.Parent:FindFirstChild("Game") } do
	local services = tree:FindFirstChild("Services")
	if services then
		table.insert(folders, services)
		table.insert(trees, tree.Name)
	end
end

local registry = Loader.boot(env, folders)
env.log("info", "ForgeLoop server services started", {
	count = #registry.order,
	order = if #registry.order > 0 then table.concat(registry.order, " > ") else "(none)",
	sha = startFields.sha,
	trees = table.concat(trees, ","),
})
if DebugServer.start(env, registry) then
	env.log("info", "ForgeLoop debug panel served (Studio only)", { sha = startFields.sha })
end
