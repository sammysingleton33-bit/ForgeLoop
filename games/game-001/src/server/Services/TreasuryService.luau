--!strict
--[[
	TreasuryService (FORGE-03, game-001) — each kingdom's shared stockpile of food, wood, stone and
	gold (CONTRACTS G7). Exact and exploit-proof: every change is all-or-nothing, never negative and
	idempotent per transaction id, so a retried or replayed request never double-spends or
	double-deposits. Built on the framework ledger `Economy/Wallet`.

	API (server)
		TreasuryService:get(kingdom) -> ResourceBag                     copy, every resource (0 if none)
		TreasuryService:canAfford(kingdom, cost) -> boolean
		TreasuryService:spend(kingdom, cost, txId, sink) -> boolean     all or nothing; a replayed txId
		                                                                returns true and changes nothing
		TreasuryService:spendUpTo(kingdom, resource, amount, txId, sink) -> number
		                                                                takes min(balance, amount); a
		                                                                replay returns the first result
		TreasuryService:deposit(kingdom, resource, amount, txId, source) -> boolean
		TreasuryService.changed: Signal<(KingdomId, totals, deltas)>     once per applied change, never
		                                                                on a replay or a refusal
		TreasuryService:reset()                                         every kingdom back to Costs.starting
	Amounts are whole numbers > 0 (deposit/spendUpTo) and costs are bags of known resources; txId
	is 1-100 bytes; sink/source tags 1-64 bytes. Bad input returns false / 0 and changes nothing.
	No storage cap in VS-1 (G7 clarification).

	Kingdoms: the four G2 ids. Every kingdom starts from config Costs.starting and is reset when
	the match enters Founding (GameEvents.MatchPhaseChanged), so a new match never inherits a
	stockpile. A service that writes to the treasury from its own Founding handler must list
	"TreasuryService" in its `dependencies`, so it starts after this service and its write lands
	after the reset (handlers run in start order).
	Idempotency lasts the whole match: each match gets fresh wallets that remember TX_MEMORY ids
	per kingdom (a 45-minute match makes about 2,800), and spendUpTo remembers its answers per
	(kingdom, resource, txId).
	Members: KingdomService:getKingdomOf(player) (FORGE-01, found in start()). Treasury.Changed
	goes to members only; a player who joins a kingdom (KingdomService.membershipChanged) gets the
	current totals at once. Without KingdomService nobody is a member: the service still works for
	other server systems, and Treasury.Get returns nil.
	Remotes (shared/Treasury/Remotes.luau): Treasury.Changed, Treasury.Get, Treasury.GetCosts.
]]

local Bundle = require("@game/ReplicatedStorage/Forge/Economy/Bundle")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Resources = require("@game/ReplicatedStorage/Forge/Config/Resources")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Wallet = require("@game/ReplicatedStorage/Forge/Economy/Wallet")

type Bag = { [string]: number }

local TreasuryService = {}
TreasuryService.__index = TreasuryService

-- CONTRACTS G2 KingdomId.
TreasuryService.KINGDOMS = table.freeze({ "crimson", "azure", "emerald", "gold" })
TreasuryService.MAX_TAG = 64
-- spendUpTo results remembered for replays (oldest dropped first).
TreasuryService.SPEND_UP_TO_MEMORY = 512
TreasuryService.TX_MEMORY = 20000
TreasuryService.MAX_TX_ID = 100

local Def = { name = "TreasuryService", dependencies = { "RemoteService" } }

function Def.new(env: any, registry: any)
	local self = setmetatable({
		_env = env,
		_registry = registry,
		_remotes = registry:get("RemoteService"),
		_kingdomService = nil :: any,
		_wallets = {} :: { [string]: any },
		_upTo = {} :: { [string]: number },
		_upToOrder = {} :: { string },
		_connections = {},
		changed = Signal.new(),
	}, TreasuryService)
	self:reset()
	return self
end

function TreasuryService:start()
	self._kingdomService = self._registry:find("KingdomService")
	self._remotes:handle("Treasury.Get", function(player)
		local kingdom = self:_kingdomOf(player)
		return if kingdom then self:get(kingdom) else nil
	end)
	self._remotes:handle("Treasury.GetCosts", function()
		return Costs.catalogue()
	end)
	table.insert(
		self._connections,
		GameEvents.MatchPhaseChanged:connect(function(phase)
			if phase == "Founding" then
				self:reset()
			end
		end)
	)
	local ks = self._kingdomService
	if ks and ks.membershipChanged then
		table.insert(
			self._connections,
			ks.membershipChanged:connect(function(player, kingdom)
				if kingdom and self._wallets[kingdom] then
					self._remotes:fire("Treasury.Changed", player, self:get(kingdom), {})
				end
			end)
		)
	end
end

function TreasuryService:destroy()
	for _, connection in self._connections do
		connection:disconnect()
	end
	self._connections = {}
	self.changed:disconnectAll()
end

function TreasuryService:_kingdomOf(player: any): string?
	local ks = self._kingdomService
	if ks == nil then
		return nil
	end
	return ks:getKingdomOf(player)
end

function TreasuryService:reset()
	local isReset = next(self._wallets) ~= nil
	for _, kingdom in TreasuryService.KINGDOMS do
		local before = if self._wallets[kingdom] then self._wallets[kingdom]:balances() else {}
		self._wallets[kingdom] =
			Wallet.new({ currencies = Resources.ids, start = Costs.starting, txLimit = TreasuryService.TX_MEMORY })
		if isReset then
			local totals = self:get(kingdom)
			self:_publish(kingdom, totals, Bundle.sub(totals, before))
		end
	end
	self._upTo = {}
	self._upToOrder = {}
end

function TreasuryService:get(kingdom: string): Bag
	local wallet = self._wallets[kingdom]
	if wallet == nil then
		local empty = {}
		for _, id in Resources.ids do
			empty[id] = 0
		end
		return empty
	end
	return wallet:balances()
end

function TreasuryService:canAfford(kingdom: string, cost: Bag): boolean
	local wallet = self._wallets[kingdom]
	if wallet == nil or not Bundle.validate(cost, { currencies = Resources.defs, allowEmpty = true }) then
		return false
	end
	return (wallet:canAfford(cost))
end

local function validTxId(txId: any): boolean
	return type(txId) == "string" and #txId > 0 and #txId <= TreasuryService.MAX_TX_ID
end

local function validTag(tag: any): boolean
	return type(tag) == "string" and #tag > 0 and #tag <= TreasuryService.MAX_TAG
end

function TreasuryService:_publish(kingdom: string, totals: Bag, deltas: Bag)
	local ks = self._kingdomService
	if ks then
		for _, player in self._env.Players:GetPlayers() do
			if ks:getKingdomOf(player) == kingdom then
				self._remotes:fire("Treasury.Changed", player, totals, deltas)
			end
		end
	end
	self.changed:fire(kingdom, totals, deltas)
end

-- Applies a change through the wallet and announces it once. Returns (ok, reason, result).
function TreasuryService:_apply(kingdom: string, method: string, bag: Bag, txId: string, tag: string)
	local wallet = self._wallets[kingdom]
	if wallet == nil or not validTag(tag) then
		return false, "invalid", nil
	end
	local ok, reason, result = wallet[method](wallet, bag, txId)
	if ok and reason == nil then
		self:_publish(kingdom, result.balances, result.applied)
	end
	return ok, reason, result
end

function TreasuryService:spend(kingdom: string, cost: Bag, txId: string, sink: string): boolean
	if type(cost) == "table" and getmetatable(cost) == nil and next(cost) == nil then
		return self._wallets[kingdom] ~= nil and validTag(sink) -- nothing to pay (e.g. starting buildings)
	end
	if not validTxId(txId) then
		return false
	end
	local ok = self:_apply(kingdom, "spend", cost, txId, sink)
	return ok == true
end

function TreasuryService:deposit(
	kingdom: string,
	resource: string,
	amount: number,
	txId: string,
	source: string
): boolean
	if Resources.defs[resource] == nil or not validTxId(txId) then
		return false
	end
	local ok = self:_apply(kingdom, "grant", { [resource] = amount }, txId, source)
	return ok == true
end

function TreasuryService:spendUpTo(
	kingdom: string,
	resource: string,
	amount: number,
	txId: string,
	sink: string
): number
	local memoryKey = `{tostring(kingdom)}|{tostring(resource)}|{tostring(txId)}`
	local remembered = self._upTo[memoryKey]
	if remembered ~= nil then
		return remembered
	end
	local wallet = self._wallets[kingdom]
	if wallet == nil or Resources.defs[resource] == nil or not validTag(sink) then
		return 0
	end
	if not Bundle.isAmount(amount) or not validTxId(txId) then
		return 0
	end
	local take = math.min(wallet:balance(resource), amount)
	if take > 0 then
		-- The wallet id names the resource too: the same txId on food and on wood are two spends.
		local ok, reason = self:_apply(kingdom, "spend", { [resource] = take }, `upTo:{resource}:{txId}`, sink)
		if not ok or reason ~= nil then
			return 0
		end
	end
	self._upTo[memoryKey] = take
	table.insert(self._upToOrder, memoryKey)
	if #self._upToOrder > TreasuryService.SPEND_UP_TO_MEMORY then
		self._upTo[table.remove(self._upToOrder, 1) :: string] = nil
	end
	return take
end

return Def
