--[[
	KingdomWorld — one MockEnv running the real EconomyTreasuryService with the FORGE-01 doubles
	(RemoteService, KingdomService on the server; RemoteClient, KingdomController on the client)
	and a local player who owns a fresh kingdom. Specs and the UI snapshot tool
	(design/ui/render/) build on it.

		local world = KingdomWorld.new({ clientDefinitions = { UIControllerDef }, kingdom = { name = "Aldmere" } })
		world.kingdom:build(world.player, "farm")       -- server side
		world.controller:build("farm")                   -- through the remotes, like the UI
		world:advance(20)                                -- virtual seconds (constructions, production)

	Options: seed, userId, playerName, kingdom (createKingdom opts: name, tincture, start, citizens,
	tiles, rank, kingdoms), clientDefinitions (extra client controllers, e.g. UIController),
	sharedModules (extra env.sharedModules entries, merged), services (MockEnv service overrides).
	Fields: env, player, server (registry), client (registry), kingdomId, kingdom (KingdomService
	double), treasury (EconomyTreasuryService), controller (KingdomController double), remotes
	(RemoteService double), rc (RemoteClient double).
]]

local MockEnv = require("../../../mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local EconomyRemotes = require("@game/ReplicatedStorage/Forge/Economy/Remotes")
local TreasuryDef = require("@game/ServerScriptService/Forge/Services/EconomyTreasuryService")
local KingdomDoubles = require("./KingdomDoubles")
local RemoteDoubles = require("./RemoteDoubles")

local KingdomWorld = {}
KingdomWorld.__index = KingdomWorld

function KingdomWorld.new(opts: { [string]: any }?)
	local o = opts or {}
	local shared = { Remotes = { Economy = EconomyRemotes, Gameplay = KingdomDoubles.RemoteDecl } }
	for fileName, byArea in o.sharedModules or {} do
		shared[fileName] = shared[fileName] or {}
		for area, module in byArea do
			shared[fileName][area] = module
		end
	end
	local env = MockEnv.new({
		seed = o.seed or 1,
		localPlayer = { userId = o.userId or 1, name = o.playerName or "Aldric" },
		sharedModules = shared,
		services = o.services,
	})
	local rc = RemoteDoubles.client(env)
	shared.RemoteClient = { Core = rc }
	local player = env.Players.LocalPlayer
	local playerGui = env.newInstance("PlayerGui") -- the engine creates it; the mock player has none
	playerGui.Parent = player
	local server =
		Loader.load(env, { RemoteDoubles.serviceDefinition(), TreasuryDef, KingdomDoubles.serviceDefinition() })
	local kingdom = server:get("KingdomService")
	local kingdomId = kingdom:createKingdom(player, o.kingdom)
	local definitions = { KingdomDoubles.controllerDefinition() }
	for _, def in o.clientDefinitions or {} do
		table.insert(definitions, def)
	end
	local client = Loader.load(env, definitions)
	env.mock:advance(0) -- deliver queued remote events and the controller's first fetch
	return setmetatable({
		env = env,
		player = player,
		server = server,
		client = client,
		kingdomId = kingdomId,
		kingdom = kingdom,
		treasury = server:get("EconomyTreasuryService"),
		remotes = server:get("RemoteService"),
		controller = client:get("KingdomController"),
		rc = rc,
	}, KingdomWorld)
end

function KingdomWorld:advance(seconds: number)
	self.env.mock:advance(seconds)
end

function KingdomWorld:destroy()
	self.client:destroy()
	self.server:destroy()
end

return KingdomWorld
