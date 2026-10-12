--!strict
--[[
	Economy/Wallet — a multi-currency ledger: non-negative, capped, overflow-guarded, idempotent
	per transaction id, all-or-nothing. Used for kingdom treasuries (match resources) and, with a
	profile data table, for player wallets.

	Transactions
		spend(cost, txId)   charges every entry or nothing. Unknown currency, a bad amount or a
		                    shortfall changes nothing and does NOT consume the txId (a later retry
		                    with the same id may succeed).
		grant(bundle, txId) adds every entry, clamped at that currency's cap; the clamped-off part
		                    is reported as `overflow` (lost, never stored). The txId is consumed even
		                    when everything overflowed, so a replay can never add it later.
		A txId already applied returns ok = true, reason = "replay" and changes nothing: callers
		fire their events only when reason ~= "replay" (interfaces §4 exactly-once rule).
		Processed txIds are remembered in data.txOrder (oldest evicted first, `txLimit`, default
		1000) so a saved wallet keeps its idempotency across sessions.

	API
		Wallet.new({ currencies: { string }, caps: Bundle?, start: Bundle?, data: table?, txLimit: number? })
			data = { balances = {}, txOrder = {} } is used in place (pass the profile table to persist)
		wallet:balance(id) -> number          wallet:balances() -> Bundle (copy, every currency)
		wallet:caps() -> Bundle (copy)        wallet:setCaps(caps)   (balances above a lower cap stay)
		wallet:canAfford(cost) -> (boolean, missing: Bundle)
		wallet:spend(cost, txId) -> (ok, reason?, result)
		wallet:grant(bundle, txId) -> (ok, reason?, result)
			result = { applied: Bundle (signed change), overflow: Bundle, missing: Bundle, balances: Bundle }
			reasons: nil (applied) | "replay" | "insufficient" | "invalid_tx" | "invalid_amount"
		wallet:seen(txId) -> boolean
]]

local Bundle = require("./Bundle")

type Bundle = Bundle.Bundle

export type Result = { applied: Bundle, overflow: Bundle, missing: Bundle, balances: Bundle }

local Wallet = {}
Wallet.__index = Wallet

Wallet.DEFAULT_TX_LIMIT = 1000
Wallet.MAX_TX_ID = 100

function Wallet.new(opts: { currencies: { string }, caps: Bundle?, start: Bundle?, data: any?, txLimit: number? })
	assert(type(opts) == "table" and type(opts.currencies) == "table", "Wallet.new({ currencies = { ... } })")
	local allowed: { [string]: boolean } = {}
	for _, id in opts.currencies do
		allowed[id] = true
	end
	local caps: Bundle = {}
	for _, id in opts.currencies do
		caps[id] = if opts.caps and opts.caps[id] then opts.caps[id] else Bundle.MAX_AMOUNT
	end
	local data = opts.data or {}
	data.balances = data.balances or {}
	data.txOrder = data.txOrder or {}
	for _, id in opts.currencies do
		if data.balances[id] == nil then
			data.balances[id] = if opts.start and opts.start[id] then opts.start[id] else 0
		end
	end
	local seen: { [string]: boolean } = {}
	for _, txId in data.txOrder do
		seen[txId] = true
	end
	return setmetatable({
		_order = table.clone(opts.currencies),
		_allowed = allowed,
		_caps = caps,
		_data = data,
		_seen = seen,
		_txLimit = opts.txLimit or Wallet.DEFAULT_TX_LIMIT,
	}, Wallet)
end

function Wallet:balance(id: string): number
	return self._data.balances[id] or 0
end

function Wallet:balances(): Bundle
	local out = {}
	for _, id in self._order do
		out[id] = self._data.balances[id] or 0
	end
	return out
end

function Wallet:caps(): Bundle
	return Bundle.copy(self._caps)
end

function Wallet:setCaps(caps: Bundle)
	local ok, problem = Bundle.validate(caps, { currencies = self._allowed, allowEmpty = true })
	assert(ok, `Wallet:setCaps: {problem}`)
	for id, cap in caps do
		self._caps[id] = cap
	end
end

function Wallet:seen(txId: string): boolean
	return self._seen[txId] == true
end

function Wallet:canAfford(cost: Bundle): (boolean, Bundle)
	local missing = Bundle.missing(self._data.balances, cost)
	return next(missing) == nil, missing
end

local function validTxId(txId: any): boolean
	return type(txId) == "string" and #txId > 0 and #txId <= Wallet.MAX_TX_ID
end

function Wallet:_remember(txId: string)
	self._seen[txId] = true
	local order = self._data.txOrder
	table.insert(order, txId)
	while #order > self._txLimit do
		local oldest = table.remove(order, 1)
		self._seen[oldest] = nil
	end
end

function Wallet:_result(applied: Bundle?, overflow: Bundle?, missing: Bundle?): Result
	return { applied = applied or {}, overflow = overflow or {}, missing = missing or {}, balances = self:balances() }
end

function Wallet:spend(cost: Bundle, txId: string): (boolean, string?, Result)
	if not validTxId(txId) then
		return false, "invalid_tx", self:_result()
	end
	if self._seen[txId] then
		return true, "replay", self:_result()
	end
	if not Bundle.validate(cost, { currencies = self._allowed }) then
		return false, "invalid_amount", self:_result()
	end
	local affordable, missing = self:canAfford(cost)
	if not affordable then
		return false, "insufficient", self:_result(nil, nil, missing)
	end
	local balances = self._data.balances
	for id, amount in cost do
		balances[id] -= amount
	end
	self:_remember(txId)
	return true, nil, self:_result(Bundle.negate(cost))
end

function Wallet:grant(bundle: Bundle, txId: string): (boolean, string?, Result)
	if not validTxId(txId) then
		return false, "invalid_tx", self:_result()
	end
	if self._seen[txId] then
		return true, "replay", self:_result()
	end
	if not Bundle.validate(bundle, { currencies = self._allowed }) then
		return false, "invalid_amount", self:_result()
	end
	local balances = self._data.balances
	local applied, overflow = {}, {}
	for id, amount in bundle do
		local current = balances[id] or 0
		local room = math.max(0, self._caps[id] - current)
		local added = math.min(amount, room)
		if added > 0 then
			balances[id] = current + added
			applied[id] = added
		end
		if amount > added then
			overflow[id] = amount - added
		end
	end
	self:_remember(txId)
	return true, nil, self:_result(applied, overflow)
end

return Wallet
