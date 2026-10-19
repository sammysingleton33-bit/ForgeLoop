--[[
	Client entry point (StarterPlayer.StarterPlayerScripts.Forge.Main). Owned by FORGE-05.

	Waits for the initial replication (require-by-string does not wait for instances), builds the
	live Env, logs the build stamp and the game id, then loads every controller definition in
	StarterPlayerScripts.Forge.Controllers and, in game projects (D-022), StarterPlayerScripts.Game.Controllers
	— one dependency graph across both trees (Contracts/Loader, interfaces §3), each controller started
	on its own so one failure cannot take the others down (Loader options.isolate). In Studio only, it
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

-- Each controller starts on its own (interfaces §3, FORGE-00 2026-10-19): one that fails is logged by name and
-- skipped with its dependents, and the rest, the kingdom HUD among them, still come up.
local registry = Loader.boot(env, folders, nil, { isolate = true })
local failed = {}
for name in registry.failed do
	table.insert(failed, name)
end
table.sort(failed)
env.log(if #failed > 0 then "error" else "info", "ForgeLoop client controllers started", {
	count = #registry.order,
	failed = if #failed > 0 then table.concat(failed, ",") else nil,
	order = if #registry.order > 0 then table.concat(registry.order, " > ") else "(none)",
	trees = table.concat(trees, ","),
})
DebugPanel.start(env)
