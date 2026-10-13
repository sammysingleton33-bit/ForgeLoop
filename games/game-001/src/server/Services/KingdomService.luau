--!strict
--[[
	KingdomService — kingdom membership, Teams, spawning, Crown Points and kingdom views (CONTRACTS G3,
	FL-0048). Owner: FORGE-01.

	API (G3)
		KingdomService:getKingdom(id): Kingdom        -- G2 Kingdom view (a copy): id, name, color (Color3),
		                                                rulers, isAI, keepBuildingId, crownPoints, regions, alive
		KingdomService:getKingdomOf(player): KingdomId?
		KingdomService:assign(player, preferred?): KingdomId?  -- switching is Lobby-only; nil = spectator
		KingdomService:assignParty(players, preferred?): { [Player]: KingdomId }?  -- parties stay together
		KingdomService:addCrownPoints(id, amount, reason)
		KingdomService.membershipChanged: Signal<(Player, KingdomId?)>
	Assignment: players are seated on arrival (MatchHost). A player whose Player.PartyId matches a seated
	player's goes to that kingdom when it has room; everyone else is balanced. In the Lobby, assignParty
	also regroups members who were already seated. Every kingdom maps to a Team (MatchHost; config
	Kingdoms teamColor, AutoAssignable false); assign sets Player.Team.
	Spawn (D-026; CharacterAutoLoads is false): once WorldService.ready has fired (or at once when there
	is no WorldService) and the player is seated, the service loads the character, pivots it to
	world Layout plots[k].spawn and attaches Kit.regalia(kingdom color). It does the same after every
	death (after Players.RespawnTime) and whenever the player's kingdom changes (Lobby switch, new match).
	Spectators get no character. Engine calls go through `adapter` (KingdomService.robloxAdapter); specs
	replace it because Lune has no characters.
	Failures: a load that errors or returns no character is retried with backoff (1, 2, 4, ... 30 s) while
	the player is still seated, with a warning per attempt. If WorldService exists but has not fired
	ready after WORLD_READY_TIMEOUT seconds, the service warns and spawns anyway.
	membershipChanged fires once per net change, after the simulation tick that made it (<= tickSeconds):
	(player, kingdomId) on a join or a Lobby switch, (player, nil) on leaving, even when the Player has
	already left the server. GameEvents.KingdomJoined(player, kingdomId) fires with every non-nil change
	(G9), so once per join, per switch and per match a player is seated in.
	Dependencies: MatchService. Optional (registry:find in start): WorldService (G10, FORGE-02).
	Studio debug (FL-0068): command kingdom.respawn; preset vs1.row3 (match.phase Founding + respawn).
]]

local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")

local KingdomService = {}
KingdomService.__index = KingdomService

local Def = { name = "KingdomService", dependencies = { "MatchService" } }

local WORLD_READY_TIMEOUT = 30 -- seconds to wait for WorldService.ready before spawning anyway
local LOAD_RETRY_MAX = 30 -- longest wait between character load attempts (seconds)
Def.WORLD_READY_TIMEOUT = WORLD_READY_TIMEOUT

-- The running service, for the Studio debug commands (registered once per process, like MatchService).
local active: any = nil

local function registerDebugCommands()
	for _, command in DebugCommands.list() do
		if command.name == "kingdom.respawn" then
			return
		end
	end
	DebugCommands.register({
		name = "kingdom.respawn",
		label = "Respawn me at my kingdom's plot with regalia",
		run = function(player: any): string?
			if active == nil then
				return "no kingdom service is running"
			end
			if active:getKingdomOf(player) == nil then
				return "you are not in a kingdom"
			end
			active:_spawn(player)
			return "respawning"
		end,
	})
	DebugCommands.registerPreset({
		name = "vs1.row3",
		label = "Row 3: match running, respawn at the keep",
		steps = { { "match.phase", "Founding" }, { "kingdom.respawn" } },
	})
end

export type Adapter = {
	partyOf: (player: any) -> string?, -- Player.PartyId, nil when not in a party
	load: (player: any) -> any?, -- spawns a fresh character (yields); returns it
	pivot: (character: any, cframe: CFrame) -> (),
	attach: (character: any, accessory: any) -> (),
	onDied: (character: any, callback: () -> ()) -> any?, -- connection with :Disconnect()
	respawnDelay: () -> number,
}

-- The engine calls behind spawning. LoadCharacterAsync is the contract call (G3); LoadCharacter is the
-- fallback for engines without it. Unverified in Studio until the FL-0048 playtest.
function KingdomService.robloxAdapter(env: any): Adapter
	return {
		partyOf = function(player: any): string?
			local ok, id = pcall(function()
				return player.PartyId
			end)
			return if ok and type(id) == "string" and id ~= "" then id else nil
		end,
		load = function(player: any): any?
			local ok = pcall(function()
				player:LoadCharacterAsync()
			end)
			if not ok then
				player:LoadCharacter()
			end
			return player.Character
		end,
		pivot = function(character: any, cframe: CFrame)
			character:PivotTo(cframe)
		end,
		attach = function(character: any, accessory: any)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:AddAccessory(accessory)
			else
				accessory.Parent = character
			end
		end,
		onDied = function(character: any, callback: () -> ()): any?
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			return if humanoid then humanoid.Died:Connect(callback) else nil
		end,
		respawnDelay = function(): number
			return env.Players.RespawnTime
		end,
	}
end

function Def.new(env: any, registry: any)
	local self = setmetatable({}, KingdomService)
	self._env = env
	self._registry = registry
	self._match = registry:get("MatchService")
	self.membershipChanged = Signal.new()
	self.adapter = KingdomService.robloxAdapter(env)
	self._worldReady = false
	self._connections = {} :: { any }
	-- userId -> Player seen in a kingdom (ruler events are handled a tick later, when a leaving
	-- Player is no longer in Players) and userId -> "<roundId>/<kingdomId>" last reported
	self._players = {} :: { [number]: any }
	self._reported = {} :: { [number]: string }
	self._spawnGen = {} :: { [number]: number } -- bumped per spawn; a stale spawn stops after it yields
	self._died = {} :: { [number]: any }
	return self
end

function KingdomService:start()
	local host = self._match.host
	host.preferredKingdom = function(player: any): string?
		return self:_partyKingdom(player)
	end
	table.insert(
		self._connections,
		host.events:connect(function(name: string, event: any)
			if name == "RulerJoined" or name == "RulerLeft" then
				self:_report(event.userId)
			end
		end)
	)
	active = self
	registerDebugCommands()
	local world = self._registry:find("WorldService")
	if world == nil or world:isReady() then
		self._worldReady = true
	else
		table.insert(
			self._connections,
			world.ready:connect(function()
				self:_onWorldReady()
			end)
		)
		self._env.spawn(function()
			self._env.wait(WORLD_READY_TIMEOUT)
			if not self._worldReady and not self._destroyed then
				self._env.log("warn", "KingdomService: WorldService not ready; spawning players anyway", {
					seconds = WORLD_READY_TIMEOUT,
				})
				self:_onWorldReady()
			end
		end)
	end
end

function KingdomService:_onWorldReady()
	if self._worldReady then
		return
	end
	self._worldReady = true
	for _, player in self._env.Players:GetPlayers() do
		if self:getKingdomOf(player) then
			self:_spawn(player)
		end
	end
end

-- ---------------------------------------------------------------- membership
-- Reports the ruler's current membership if it differs from the last one reported. Several ruler
-- events of one tick (join then switch, leave then rejoin) collapse into one net change.
function KingdomService:_report(userId: number)
	local player = self._env.Players:GetPlayerByUserId(userId) or self._players[userId]
	if player == nil then
		return
	end
	local match = self._match.host.match
	local kingdomId = match:kingdomOf(userId)
	local key = if kingdomId then `{match.roundId}/{kingdomId}` else nil
	if self._reported[userId] == key then
		return
	end
	self._reported[userId] = key
	self._players[userId] = if kingdomId then player else nil
	self.membershipChanged:fire(player, kingdomId)
	if kingdomId then
		GameEvents.KingdomJoined:fire(player, kingdomId)
		self:_spawn(player)
	else
		self:_forgetCharacter(userId)
	end
end

-- The kingdom of a seated player in the same party (Player.PartyId), if any.
function KingdomService:_partyKingdom(player: any): string?
	local party = self.adapter.partyOf(player)
	if party == nil then
		return nil
	end
	for _, other in self._env.Players:GetPlayers() do
		if other ~= player and self.adapter.partyOf(other) == party then
			local kingdomId = self:getKingdomOf(other)
			if kingdomId then
				return kingdomId
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------- spawning
function KingdomService:_forgetCharacter(userId: number)
	self._spawnGen[userId] = (self._spawnGen[userId] or 0) + 1
	local died = self._died[userId]
	if died then
		died:Disconnect()
		self._died[userId] = nil
	end
end

-- Whether a spawn is still wanted: same generation, the player still here and still in that kingdom.
function KingdomService:_spawnCurrent(player: any, generation: number, kingdomId: string): boolean
	return not self._destroyed
		and self._spawnGen[player.UserId] == generation
		and player.Parent ~= nil
		and self:getKingdomOf(player) == kingdomId
end

-- The player's character, retrying with backoff while the spawn is current; nil once it is not
-- (left, switched, or a newer spawn took over).
function KingdomService:_load(player: any, generation: number, kingdomId: string): any?
	local delay = 1
	local attempt = 0
	while true do
		attempt += 1
		local ok, result = pcall(self.adapter.load, player)
		if ok and result ~= nil then
			return result
		end
		if not self:_spawnCurrent(player, generation, kingdomId) then
			return nil -- e.g. the player left while loading: nothing to report
		end
		self._env.log("warn", "KingdomService: character load failed; retrying", {
			userId = player.UserId,
			attempt = attempt,
			retryIn = delay,
			error = if ok then "no character" else tostring(result),
		})
		self._env.wait(delay)
		delay = math.min(delay * 2, LOAD_RETRY_MAX)
		if not self:_spawnCurrent(player, generation, kingdomId) then
			return nil
		end
	end
end

-- Loads the character at the kingdom's plot spawn wearing regalia (G3). Runs in its own thread, because
-- loading a character yields; a newer spawn or a departure makes an older one stop.
function KingdomService:_spawn(player: any)
	if not self._worldReady then
		return -- spawned when WorldService.ready fires
	end
	local userId = player.UserId
	self:_forgetCharacter(userId)
	local generation = self._spawnGen[userId]
	self._env.spawn(function()
		local kingdomId = self:getKingdomOf(player)
		if kingdomId == nil then
			return
		end
		local character = self:_load(player, generation, kingdomId)
		if character == nil or self._spawnGen[userId] ~= generation or self:getKingdomOf(player) ~= kingdomId then
			return
		end
		local plot = Layout.WORLD.plots[kingdomId]
		self.adapter.pivot(character, plot.spawn)
		local view = self:getKingdom(kingdomId)
		for _, accessory in Kit.regalia(view.color) do
			self.adapter.attach(character, accessory)
		end
		self._died[userId] = self.adapter.onDied(character, function()
			self._env.wait(self.adapter.respawnDelay())
			if self._spawnGen[userId] == generation and player.Parent ~= nil and self:getKingdomOf(player) then
				self:_spawn(player)
			end
		end)
	end)
end

-- ---------------------------------------------------------------- API (G3)
function KingdomService:_sim(): any
	return self._match.host.match.sim
end

function KingdomService:getKingdom(id: string): any?
	return self._match.host:kingdomView(id)
end

function KingdomService:getKingdomOf(player: any): string?
	return self._match.host.match:kingdomOf(player.UserId)
end

function KingdomService:assign(player: any, preferred: string?): string?
	local match = self._match.host.match
	local current = match:kingdomOf(player.UserId)
	if current == nil then
		match:join(player.UserId, preferred or self:_partyKingdom(player))
	elseif preferred and preferred ~= current then
		match:choose(player.UserId, preferred)
	end
	self._match.host:assignTeam(player)
	return match:kingdomOf(player.UserId)
end

function KingdomService:assignParty(players: { any }, preferred: string?): { [any]: string }?
	local userIds = {}
	for _, player in players do
		table.insert(userIds, player.UserId)
	end
	local ok = self._match.host.match:joinParty(userIds, preferred)
	if not ok then
		return nil
	end
	local out = {}
	for _, player in players do
		self._match.host:assignTeam(player)
		out[player] = self:getKingdomOf(player)
	end
	return out
end

function KingdomService:addCrownPoints(id: string, amount: number, reason: string)
	assert(type(amount) == "number" and amount == amount and math.abs(amount) < math.huge, "addCrownPoints: amount")
	self:_sim():addCrownPoints(id, amount, reason)
end

function KingdomService:destroy()
	self._destroyed = true
	if active == self then
		active = nil
	end
	for _, connection in self._connections do
		connection:disconnect()
	end
	self._connections = {}
	for userId in self._died do
		self:_forgetCharacter(userId)
	end
	self.membershipChanged:disconnectAll()
end

return Def
