--!strict
--[[
	KingdomService — kingdom membership, Crown Points and kingdom views (CONTRACTS G3, FL-0048).
	Owner: FORGE-01.

	API (G3)
		KingdomService:getKingdom(id): Kingdom        -- G2 Kingdom view (a copy): id, name, color (Color3),
		                                                rulers, isAI, keepBuildingId, crownPoints, alive
		KingdomService:getKingdomOf(player): KingdomId?
		KingdomService:assign(player, preferred?): KingdomId?  -- balanced; switching is Lobby-only
		KingdomService:assignParty(players, preferred?): { [Player]: KingdomId }?  -- parties stay together
		KingdomService:addCrownPoints(id, amount, reason)
		KingdomService.membershipChanged: Signal<(Player, KingdomId?)>
	Players join automatically on PlayerAdded (MatchHost); assign/assignParty are for lobby UIs and
	party systems. Every kingdom maps to a Team (chat, leaderboard, spawn). Empty kingdoms have
	isAI = true and are run by the AI governor (VS-2 tuning; config Governor).
	Fires GameEvents.KingdomJoined(player, kingdomId) once per join (G9).
]]

local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local KingdomService = {}
KingdomService.__index = KingdomService

local Def = { name = "KingdomService", dependencies = { "MatchService" } }

function Def.new(env: any, registry: any)
	local self = setmetatable({}, KingdomService)
	self._env = env
	self._match = registry:get("MatchService")
	self.membershipChanged = Signal.new()
	return self
end

function KingdomService:start()
	self._match.host.events:connect(function(name: string, event: any)
		if name ~= "RulerJoined" and name ~= "RulerLeft" then
			return
		end
		local player = self._env.Players:GetPlayerByUserId(event.userId)
		if player == nil then
			return
		end
		if name == "RulerJoined" then
			self.membershipChanged:fire(player, event.kingdomId)
			GameEvents.KingdomJoined:fire(player, event.kingdomId)
		else
			self.membershipChanged:fire(player, self:getKingdomOf(player))
		end
	end)
end

function KingdomService:_sim(): any
	return self._match.host.match.sim
end

function KingdomService:getKingdom(id: string): any?
	local k = self:_sim().kingdoms[id]
	if k == nil then
		return nil
	end
	return {
		id = k.id,
		name = k.name,
		color = Color3.fromRGB(k.color[1], k.color[2], k.color[3]),
		rulers = table.clone(k.rulers),
		isAI = #k.rulers == 0,
		keepBuildingId = if k.alive then k.keepId else nil,
		crownPoints = k.crownPoints,
		alive = k.alive,
	}
end

function KingdomService:getKingdomOf(player: any): string?
	return self._match.host.match:kingdomOf(player.UserId)
end

function KingdomService:assign(player: any, preferred: string?): string?
	local match = self._match.host.match
	local current = match:kingdomOf(player.UserId)
	local ok, result
	if current == nil then
		ok, result = match:join(player.UserId, preferred)
	elseif preferred and preferred ~= current then
		ok, result = match:choose(player.UserId, preferred)
	else
		return current
	end
	self._match.host:_assignTeam(player)
	return if ok then result else match:kingdomOf(player.UserId)
end

function KingdomService:assignParty(players: { any }, preferred: string?): { [any]: string }?
	local userIds = {}
	for _, player in players do
		table.insert(userIds, player.UserId)
	end
	local ok, seated = self._match.host.match:joinParty(userIds, preferred)
	if not ok then
		return nil
	end
	local out = {}
	for _, player in players do
		self._match.host:_assignTeam(player)
		out[player] = self:getKingdomOf(player)
	end
	return out
end

function KingdomService:addCrownPoints(id: string, amount: number, reason: string)
	assert(type(amount) == "number" and amount == amount and math.abs(amount) < math.huge, "addCrownPoints: amount")
	self:_sim():addCrownPoints(id, amount, reason)
end

function KingdomService:destroy()
	self.membershipChanged:disconnectAll()
end

return Def
