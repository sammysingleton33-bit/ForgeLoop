--!strict
--[[
	EconomyTreasuryService (FORGE-03) — in-match kingdom treasuries: the food, wood, stone and gold
	(match-scope currencies, Config.Currencies) a kingdom holds during one match. Never saved:
	in-match resources are separate from player wallets (EconomyService, profile scope).

	Kingdom ownership belongs to FORGE-01's KingdomService: it opens a treasury when a kingdom is
	founded, keeps the member list current and spends/grants through this service. Proposed API
	and flow: production/handoffs/2026-10-12-forge-03-to-forge-01-kingdom-api.md.

	API (server)
		service:open(kingdomId, { members: { Player }?, start: Bundle?, caps: Bundle? }?)
			start defaults to Currencies `start`, caps to Currencies `cap` (match scope). Errors if open.
		service:close(kingdomId)                       end of match; members get no more updates
		service:isOpen(kingdomId) -> boolean
		service:setMembers(kingdomId, { Player })      who sees this treasury (replication)
		service:kingdomOf(player) -> string?
		service:balances(kingdomId) -> Bundle          service:caps(kingdomId) -> Bundle
		service:snapshot(kingdomId) -> TreasurySnapshot
		service:canAfford(kingdomId, cost) -> (boolean, missing: Bundle)
		service:spend(kingdomId, cost, txId, sink) -> (ok, reason?, result)
		service:grant(kingdomId, bundle, txId, source) -> (ok, reason?, result)
		service:setCaps(kingdomId, caps)               e.g. Construction:storageCaps after a Storehouse
			All-or-nothing and idempotent per txId (Economy/Wallet). reason: nil | "replay" |
			"insufficient" | "invalid_amount" | "invalid_tx" | "invalid_tag" | "unknown_kingdom".
		service.changed: Signal (kingdomId, snapshot, change)  once per applied transaction, never on
			a replay or a refused one (interfaces §4 exactly-once rule).
	Remotes (shared/Economy/Remotes.luau): fires Economy.Treasury to the kingdom's members on every
	change and on open; answers Economy.GetTreasury. Uses RemoteService when present (found in
	start(), so this service also loads in builds without it).
	Analytics: match resources are not player currencies and are not reported to
	AnalyticsService:economy (EconomyService remains its only caller, interfaces §7).
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local Currencies = require("@game/ReplicatedStorage/Forge/Economy/Currencies")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Wallet = require("@game/ReplicatedStorage/Forge/Economy/Wallet")

type Bundle = Bundle.Bundle

export type TreasurySnapshot = { kingdomId: string, balances: Bundle, caps: Bundle, version: number }
export type TreasuryChange = { txId: string, reason: string, delta: Bundle, overflow: Bundle }

local EconomyTreasuryService = {}
EconomyTreasuryService.__index = EconomyTreasuryService

local Def = { name = "EconomyTreasuryService", dependencies = {} }

local MAX_TAG = 64

function Def.new(env: any, registry: any)
	local currencies = Currencies.default()
	return setmetatable({
		_env = env,
		_registry = registry,
		_currencies = currencies,
		_ids = currencies:ids("match"),
		_treasuries = {} :: { [string]: any },
		_memberOf = {} :: { [number]: string },
		_remotes = nil :: any,
		_connections = {},
		changed = Signal.new(),
	}, EconomyTreasuryService)
end

function EconomyTreasuryService:start()
	self._remotes = self._registry:find("RemoteService")
	if self._remotes then
		self._remotes:handle("Economy.GetTreasury", function(player)
			local kingdomId = self:kingdomOf(player)
			return if kingdomId then self:snapshot(kingdomId) else nil
		end)
	else
		self._env.log("warn", "EconomyTreasuryService: no RemoteService; treasuries are not replicated", {})
	end
	local players = self._env.Players
	if players and players.PlayerRemoving then
		table.insert(
			self._connections,
			players.PlayerRemoving:Connect(function(player)
				local kingdomId = self._memberOf[player.UserId]
				if kingdomId and self._treasuries[kingdomId] then
					local t = self._treasuries[kingdomId]
					t.members[player.UserId] = nil
				end
				self._memberOf[player.UserId] = nil
			end)
		)
	end
end

function EconomyTreasuryService:destroy()
	for _, connection in self._connections do
		connection:Disconnect()
	end
	self._connections = {}
	self.changed:disconnectAll()
end

local function validId(kingdomId: any): boolean
	return type(kingdomId) == "string" and #kingdomId > 0 and #kingdomId <= 64
end

function EconomyTreasuryService:open(kingdomId: string, opts: { members: { any }?, start: Bundle?, caps: Bundle? }?)
	assert(validId(kingdomId), "EconomyTreasuryService:open: kingdomId must be a string of 1-64 bytes")
	assert(self._treasuries[kingdomId] == nil, `EconomyTreasuryService:open: '{kingdomId}' is already open`)
	local o = opts or {}
	local wallet = Wallet.new({
		currencies = self._ids,
		start = o.start or self._currencies:starting("match"),
		caps = o.caps or self._currencies:caps("match"),
	})
	self._treasuries[kingdomId] = { wallet = wallet, version = 1, members = {} }
	self:setMembers(kingdomId, o.members or {})
end

function EconomyTreasuryService:close(kingdomId: string)
	local t = self._treasuries[kingdomId]
	if t == nil then
		return
	end
	for userId in t.members do
		if self._memberOf[userId] == kingdomId then
			self._memberOf[userId] = nil
		end
	end
	self._treasuries[kingdomId] = nil
end

function EconomyTreasuryService:isOpen(kingdomId: string): boolean
	return self._treasuries[kingdomId] ~= nil
end

function EconomyTreasuryService:setMembers(kingdomId: string, members: { any })
	local t = self._treasuries[kingdomId]
	assert(t, `EconomyTreasuryService:setMembers: '{tostring(kingdomId)}' is not open`)
	for userId in t.members do
		if self._memberOf[userId] == kingdomId then
			self._memberOf[userId] = nil
		end
	end
	t.members = {}
	for _, player in members do
		t.members[player.UserId] = player
		self._memberOf[player.UserId] = kingdomId
	end
	local snapshot = self:snapshot(kingdomId)
	for _, player in t.members do
		self:_send(player, snapshot, nil)
	end
end

function EconomyTreasuryService:kingdomOf(player: any): string?
	return self._memberOf[player.UserId]
end

function EconomyTreasuryService:balances(kingdomId: string): Bundle
	local t = self._treasuries[kingdomId]
	return if t then t.wallet:balances() else {}
end

function EconomyTreasuryService:caps(kingdomId: string): Bundle
	local t = self._treasuries[kingdomId]
	return if t then t.wallet:caps() else {}
end

function EconomyTreasuryService:snapshot(kingdomId: string): TreasurySnapshot
	local t = self._treasuries[kingdomId]
	assert(t, `EconomyTreasuryService:snapshot: '{tostring(kingdomId)}' is not open`)
	return { kingdomId = kingdomId, balances = t.wallet:balances(), caps = t.wallet:caps(), version = t.version }
end

function EconomyTreasuryService:canAfford(kingdomId: string, cost: Bundle): (boolean, Bundle)
	local t = self._treasuries[kingdomId]
	if t == nil then
		return false, Bundle.copy(cost)
	end
	return t.wallet:canAfford(cost)
end

function EconomyTreasuryService:_send(player: any, snapshot: TreasurySnapshot, change: TreasuryChange?)
	if self._remotes then
		self._remotes:fire("Economy.Treasury", player, snapshot, change)
	end
end

function EconomyTreasuryService:_publish(kingdomId: string, change: TreasuryChange)
	local t = self._treasuries[kingdomId]
	t.version += 1
	local snapshot = self:snapshot(kingdomId)
	for _, player in t.members do
		self:_send(player, snapshot, change)
	end
	self.changed:fire(kingdomId, snapshot, change)
end

function EconomyTreasuryService:_apply(
	method: string,
	kingdomId: string,
	bundle: Bundle,
	txId: string,
	tag: string
): (boolean, string?, any)
	local t = self._treasuries[kingdomId]
	if t == nil then
		return false, "unknown_kingdom", nil
	end
	if type(tag) ~= "string" or #tag == 0 or #tag > MAX_TAG then
		return false, "invalid_tag", nil
	end
	local ok, reason, result = t.wallet[method](t.wallet, bundle, txId)
	if ok and reason == nil then
		self:_publish(kingdomId, { txId = txId, reason = tag, delta = result.applied, overflow = result.overflow })
	end
	return ok, reason, result
end

function EconomyTreasuryService:spend(kingdomId: string, cost: Bundle, txId: string, sink: string)
	return self:_apply("spend", kingdomId, cost, txId, sink)
end

function EconomyTreasuryService:grant(kingdomId: string, bundle: Bundle, txId: string, source: string)
	return self:_apply("grant", kingdomId, bundle, txId, source)
end

function EconomyTreasuryService:setCaps(kingdomId: string, caps: Bundle)
	local t = self._treasuries[kingdomId]
	assert(t, `EconomyTreasuryService:setCaps: '{tostring(kingdomId)}' is not open`)
	local before = t.wallet:caps()
	t.wallet:setCaps(caps)
	if not Bundle.equals(before, t.wallet:caps()) then
		self:_publish(kingdomId, { txId = `caps:{t.version}`, reason = "caps", delta = {}, overflow = {} })
	end
end

return Def
