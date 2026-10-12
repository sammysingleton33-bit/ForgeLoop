--[[
	Client entry point (StarterPlayer.StarterPlayerScripts.Forge.Main). Owned by FORGE-05.

	Waits for the initial replication (require-by-string does not wait for instances), builds the
	live Env, logs the build stamp and the game id, then loads every controller definition in
	StarterPlayerScripts.Forge.Controllers and, in game projects (D-022), StarterPlayerScripts.Game.Controllers
	— one dependency graph across both trees (Contracts/Loader, interfaces §3). In Studio only, it
	then opens the debug panel (Debug/DebugPanel, FL-0068; F8).
	Add a controller by adding a module to a Controllers folder — never edit this file for it.
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local BuildStamp = require("@game/ReplicatedStorage/Forge/Contracts/BuildStamp")
local DebugPanel = require("@game/ReplicatedStorage/Forge/Debug/DebugPanel")
local Env = require("@game/ReplicatedStorage/Forge/Contracts/Env")
local GameConfig = require("@game/ReplicatedStorage/Forge/Config/Game")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")

local env = Env.live()
local build = BuildStamp.read(env.ReplicatedStorage:FindFirstChild("Forge"))
local startFields = BuildStamp.fields(build)
startFields.game = GameConfig.id
env.log("info", "ForgeLoop client starting", startFields)

-- At run time this script sits in Players.<player>.PlayerScripts.Forge; the game tree (if any) is
-- its sibling PlayerScripts.Game, copied from StarterPlayerScripts in the same step.
local folders, trees = {}, {}
for _, tree in { script.Parent, script.Parent.Parent:FindFirstChild("Game") } do
	local controllers = tree:FindFirstChild("Controllers")
	if controllers then
		table.insert(folders, controllers)
		table.insert(trees, tree.Name)
	end
end

local registry = Loader.boot(env, folders)
env.log("info", "ForgeLoop client controllers started", {
	count = #registry.order,
	order = if #registry.order > 0 then table.concat(registry.order, " > ") else "(none)",
	trees = table.concat(trees, ","),
})
DebugPanel.start(env)
