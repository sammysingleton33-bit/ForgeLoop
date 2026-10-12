--[[
	KingdomWorld — one MockEnv running the real framework RemoteService, the real TreasuryService
	(FORGE-03) and small doubles of FORGE-01's KingdomService, MatchService and BuildingService that
	answer the CONTRACTS G8 remotes (Kingdom.*, Match.*, Build.*) with the G2 shapes. The local
	player rules Emberhold (crimson) with a second ruler; the client controllers under test boot on
	the same env and talk to the server only through the remotes. Specs and the UI snapshot scenes
	build on it.

		local world = KingdomWorld.new({ clientDefinitions = { KingdomHudDef, BuildMenuDef } })
		world.build:progress(id, 0.5)        -- server side: construction progress, pushed to clients
		world:advance(1)                     -- virtual seconds

	Options: latency (seconds Build.CanPlace takes to answer; default 0), userId, playerName, kingdom (default "crimson"; false = no kingdom yet), noPlayerGui,
	clientDefinitions, treasury (a starting ResourceBag that replaces Costs.starting for the
	player's kingdom), match = { phase, endsAt?, startedAt? }.
	Fields: env, player, server (registry), client (registry), kingdoms (KingdomService double),
	match (MatchService double), build (BuildingService double), treasury (TreasuryService),
	remotes (RemoteService), calls (BuildingService call log: { { name, args } }).

	Double rules (stand-ins for FORGE-01, not the game's rules): your territory is the square
	|x| <= 200, |z| <= 200 (reason "territory"); a new building needs 24 studs from any other
	("overlap"); costs come from config Costs and are spent with TreasuryService:spend ("cost").
]]

local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MockEnv = require("../../../../../roblox/tests/mocks/MockEnv")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local TreasuryDef = require("@game/ServerScriptService/Game/Services/TreasuryService")
local TreasuryRemotes = require("@game/ReplicatedStorage/Game/Treasury/Remotes")
local V = require("@game/ReplicatedStorage/Forge/Core/Validate")

local KingdomWorld = {}
KingdomWorld.__index = KingdomWorld

local TYPES =
	{ "keep", "house", "farm", "storehouse", "lumbercamp", "quarry", "barracks", "watchtower", "wall", "gate" }

-- FORGE-01's remote declarations as CONTRACTS G8 describes them (kinds, arguments, rates).
KingdomWorld.REMOTES = {
	Kingdom = {
		{ name = "Kingdom.State", kind = "serverEvent" },
		{ name = "Kingdom.GetState", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
	},
	Match = {
		{ name = "Match.State", kind = "serverEvent" },
		{ name = "Match.GetState", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
	},
	Build = {
		{ name = "Build.Buildings", kind = "serverEvent" },
		{ name = "Build.GetBuildings", kind = "function", args = {}, rate = { burst = 5, perSecond = 2 } },
		{
			name = "Build.CanPlace",
			kind = "function",
			args = { V.enum(TYPES), V.vector3(4000), V.integer(0, 3) },
			rate = { burst = 10, perSecond = 10 },
		},
		{
			name = "Build.Place",
			kind = "function",
			args = { V.enum(TYPES), V.vector3(4000), V.integer(0, 3) },
			rate = { burst = 3, perSecond = 1 },
		},
		{
			name = "Build.Upgrade",
			kind = "function",
			args = { V.integer(1, 65535) },
			rate = { burst = 3, perSecond = 1 },
		},
	},
}

KingdomWorld.KINGDOMS = {
	{ id = "crimson", name = "Emberhold", color = Color3.fromRGB(184, 64, 46) },
	{ id = "azure", name = "Frostmere", color = Color3.fromRGB(63, 114, 181) },
	{ id = "emerald", name = "Thornwood", color = Color3.fromRGB(62, 138, 75) },
	{ id = "gold", name = "Sunspire", color = Color3.fromRGB(201, 154, 54) },
}

-- ------------------------------------------------------------------ KingdomService double (G3)

local function kingdomServiceDef(world)
	return {
		name = "KingdomService",
		dependencies = { "RemoteService" },
		new = function(_, registry)
			local remotes = registry:get("RemoteService")
			local svc = {
				membershipChanged = Signal.new(),
				members = {} :: { [number]: string },
				kingdoms = {},
			}
			for i, k in KingdomWorld.KINGDOMS do
				svc.kingdoms[k.id] = {
					id = k.id,
					name = k.name,
					color = k.color,
					rulers = {},
					isAI = true,
					keepBuildingId = i,
					crownPoints = 0,
					regions = { k.id .. "_home" },
					alive = true,
				}
			end
			function svc:getKingdomOf(player)
				return self.members[player.UserId]
			end
			function svc:getKingdom(id)
				return self.kingdoms[id]
			end
			function svc:list()
				local out = {}
				for _, k in KingdomWorld.KINGDOMS do
					table.insert(out, self.kingdoms[k.id])
				end
				return out
			end
			function svc:publish()
				for _, player in world.env.Players:GetPlayers() do
					remotes:fire(
						"Kingdom.State",
						player,
						{ kingdoms = self:list(), mine = self.members[player.UserId] }
					)
				end
			end
			-- quiet = true skips membershipChanged (TreasuryService's own push on join), modelling a
			-- push the client missed: the HUD must still fetch the new kingdom's treasury.
			function svc:join(player, id, userIds, quiet)
				self.members[player.UserId] = id
				local k = self.kingdoms[id]
				table.insert(k.rulers, player.UserId)
				for _, other in userIds or {} do
					table.insert(k.rulers, other)
				end
				k.isAI = false
				if not quiet then
					self.membershipChanged:fire(player, id)
				end
				self:publish()
			end
			function svc:addCrownPoints(id, amount)
				self.kingdoms[id].crownPoints += amount
				self:publish()
			end
			function svc:start()
				remotes:handle("Kingdom.GetState", function(player)
					return { kingdoms = self:list(), mine = self.members[player.UserId] }
				end)
			end
			return svc
		end,
	}
end

-- ------------------------------------------------------------------ MatchService double (G3)

local function matchServiceDef(world, opts)
	return {
		name = "MatchService",
		dependencies = { "RemoteService" },
		new = function(_, registry)
			local remotes = registry:get("RemoteService")
			local m = opts or {}
			local svc = {
				phase = m.phase or "Founding",
				endsAt = m.endsAt,
				startedAt = m.startedAt or world.env.serverTimeNow(),
			}
			function svc:setPhase(phase, endsAt)
				self.phase, self.endsAt = phase, endsAt
				remotes:fireAll("Match.State", phase, endsAt, self.startedAt)
			end
			function svc:start()
				remotes:handle("Match.GetState", function()
					return self.phase, self.endsAt, self.startedAt
				end)
			end
			return svc
		end,
	}
end

-- ------------------------------------------------------------------ BuildingService double (G6)

local function buildingServiceDef(world)
	return {
		name = "BuildingService",
		dependencies = { "RemoteService", "TreasuryService", "KingdomService" },
		new = function(_, registry)
			local remotes = registry:get("RemoteService")
			local treasury = registry:get("TreasuryService")
			local kingdoms = registry:get("KingdomService")
			local svc = { buildings = {} :: { [number]: any }, positions = {} :: { [number]: Vector3 }, nextId = 1 }
			local function wire(b)
				return table.clone(b) -- no CFrame on the wire (G8)
			end
			function svc:add(kingdom, buildingType, level, state, position)
				local id = self.nextId
				self.nextId += 1
				self.buildings[id] = {
					id = id,
					kingdom = kingdom,
					type = buildingType,
					level = level,
					state = state,
					progress = if state == "complete" then 1 else 0,
					hp = 100,
					maxHp = 100,
					footprint = Vector2.new(20, 20),
				}
				self.positions[id] = position
				return id
			end
			function svc:push(id)
				remotes:fireAll("Build.Buildings", { wire(self.buildings[id]) })
			end
			function svc:progress(id, value, state)
				local b = self.buildings[id]
				b.progress = value
				b.state = state or (if value >= 1 then "complete" else "constructing")
				self:push(id)
			end
			function svc:canPlace(kingdom, buildingType, position)
				if math.abs(position.X) > 200 or math.abs(position.Z) > 200 then
					return false, "territory"
				end
				for _, other in self.positions do
					if (Vector3.new(other.X, 0, other.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude < 24 then
						return false, "overlap"
					end
				end
				local entry = Costs.building(buildingType, 1)
				if entry == nil then
					return false, "unknown_type"
				end
				if not treasury:canAfford(kingdom, entry.cost) then
					return false, "cost"
				end
				return true
			end
			function svc:start()
				-- Starting buildings (G6): the keep and the four economy buildings of every kingdom.
				for i, k in KingdomWorld.KINGDOMS do
					local base = Vector3.new(i * 1000, 0, 0)
					self:add(k.id, "keep", 1, "complete", base)
				end
				local home = Vector3.new(-150, 0, -150)
				for j, t in { "storehouse", "farm", "lumbercamp", "quarry" } do
					self:add("crimson", t, 1, "complete", home + Vector3.new(j * 30, 0, 0))
				end
				self.positions[1] = Vector3.new(0, 0, 0) -- crimson keep at the plot centre
				remotes:handle("Build.GetBuildings", function()
					local out = {}
					for id in self.buildings do
						table.insert(out, wire(self.buildings[id]))
					end
					return out
				end)
				remotes:handle("Build.CanPlace", function(player, buildingType, position, rot)
					table.insert(world.calls, { name = "CanPlace", args = { buildingType, position, rot } })
					if world.latency > 0 then
						world.env.wait(world.latency) -- the round trip
					end
					local kingdom = kingdoms:getKingdomOf(player)
					if kingdom == nil then
						return false, "no_kingdom"
					end
					return self:canPlace(kingdom, buildingType, position)
				end)
				remotes:handle("Build.Place", function(player, buildingType, position, rot)
					table.insert(world.calls, { name = "Place", args = { buildingType, position, rot } })
					local kingdom = kingdoms:getKingdomOf(player)
					if kingdom == nil then
						return nil, "no_kingdom"
					end
					local ok, reason = self:canPlace(kingdom, buildingType, position)
					if not ok then
						return nil, reason
					end
					local entry = Costs.building(buildingType, 1)
					if not treasury:spend(kingdom, entry.cost, `place:{self.nextId}`, "construction") then
						return nil, "cost"
					end
					local id = self:add(kingdom, buildingType, 1, "planned", position)
					self.buildings[id].placedBy = player.UserId
					self:push(id)
					return id
				end)
				remotes:handle("Build.Upgrade", function(player, buildingId)
					table.insert(world.calls, { name = "Upgrade", args = { buildingId } })
					local b = self.buildings[buildingId]
					local kingdom = kingdoms:getKingdomOf(player)
					if b == nil then
						return false, "not_found"
					elseif b.kingdom ~= kingdom then
						return false, "not_owner"
					elseif b.state ~= "complete" then
						return false, "busy"
					end
					local entry = Costs.building(b.type, b.level + 1)
					if entry == nil then
						return false, "max_level"
					end
					if
						not treasury:spend(kingdom, entry.cost, `upgrade:{buildingId}:{b.level + 1}`, "construction")
					then
						return false, "cost"
					end
					b.level += 1
					b.state = "constructing"
					b.progress = 0
					self:push(buildingId)
					return true
				end)
			end
			return svc
		end,
	}
end

function KingdomWorld.new(opts: { [string]: any }?)
	local o = opts or {}
	local shared = { Remotes = table.clone(KingdomWorld.REMOTES) }
	shared.Remotes.Treasury = TreasuryRemotes
	local env = MockEnv.new({
		seed = 1,
		localPlayer = { userId = o.userId or 1, name = o.playerName or "Sam" },
		sharedModules = shared,
	})
	local self = setmetatable({ env = env, calls = {}, latency = o.latency or 0 }, KingdomWorld)
	local player = env.Players.LocalPlayer
	self.player = player
	if not o.noPlayerGui then
		local playerGui = env.newInstance("PlayerGui") -- the engine creates it; the mock player has none
		playerGui.Parent = player
	end
	local co = env.mock.players:add({ userId = 2, name = "Mira" })
	self.coRuler = co
	self.server = Loader.load(env, {
		RemoteServiceDef,
		TreasuryDef,
		kingdomServiceDef(self),
		matchServiceDef(self, o.match),
		buildingServiceDef(self),
	})
	self.remotes = self.server:get("RemoteService")
	self.treasury = self.server:get("TreasuryService")
	self.kingdoms = self.server:get("KingdomService")
	self.match = self.server:get("MatchService")
	self.build = self.server:get("BuildingService")
	local kingdom = if o.kingdom == nil then "crimson" else o.kingdom
	if kingdom then
		if o.treasury then
			-- Top up / spend the difference so the kingdom starts from exactly o.treasury.
			local now = self.treasury:get(kingdom)
			for id, amount in o.treasury do
				local diff = amount - (now[id] or 0)
				if diff > 0 then
					self.treasury:deposit(kingdom, id, diff, "seed:" .. id, "spec")
				elseif diff < 0 then
					self.treasury:spend(kingdom, { [id] = -diff }, "seed:" .. id, "spec")
				end
			end
		end
		self.kingdoms:join(player, kingdom, { 2 })
		self.kingdoms.members[2] = kingdom
	end
	self.kingdomId = kingdom
	self.client = Loader.load(env, o.clientDefinitions or {})
	env.mock:advance(0.1) -- deliver queued remote events and the controllers' first requests
	return self
end

function KingdomWorld:advance(seconds: number)
	self.env.mock:advance(seconds)
end

function KingdomWorld:callsNamed(name: string): { any }
	local out = {}
	for _, call in self.calls do
		if call.name == name then
			table.insert(out, call)
		end
	end
	return out
end

function KingdomWorld:destroy()
	self.client:destroy()
	self.server:destroy()
end

return KingdomWorld
