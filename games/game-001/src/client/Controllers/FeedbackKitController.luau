--!strict
--[[
	FeedbackKitController (game-001, FORGE-04; FORGE-02's FL-0135 handoff
	2026-10-18-forge-02-to-forge-04-fl0135-asset-source.md, D-057): gives the client's Kit the folder
	the imported meshes live in, ReplicatedStorage.Forge.Assets, the same call WorldService makes on
	the server. Without it every client rig and portrait stays part-built, even after the owner's
	import, because the client and the server each have their own Kit.

	When: in new(), not start(). The Loader constructs every controller before it starts any, so the
	folder is set before EntityController (FORGE-01) builds its first rig and before the first
	Kit.portrait, whatever the start order. A rig built before the call would stay part-built in
	EntityController's pool. The call is idempotent; no folder (or no Forge) passes nil, which keeps
	the part-built fallback.

	Def.create(env, registry, deps?) — deps.kit replaces Kit (specs).
	controller.assets -> Instance?   the folder it passed (nil when there is none)
]]

local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")

local Controller = {}
Controller.__index = Controller

local Def = { name = "FeedbackKitController", dependencies = {} }

function Def.create(env: any, registry: any, deps: any?)
	local kit = if type(deps) == "table" and deps.kit ~= nil then deps.kit else Kit
	local forge = env.ReplicatedStorage:FindFirstChild("Forge")
	local assets = if forge ~= nil then forge:FindFirstChild("Assets") else nil
	kit.setAssetSource(assets)
	return setmetatable({ _env = env, _registry = registry, assets = assets }, Controller)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

return Def
