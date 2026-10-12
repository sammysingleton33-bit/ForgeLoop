--!strict
--[[
	Sim/TreasuryDouble — a faithful local double of FORGE-03's TreasuryService
	(CONTRACTS G7) so the simulation can run and be tested before FL-0058 lands. The simulation only
	talks to the G7 API, so swapping in the real service (registry:get("TreasuryService")) changes
	no simulation code.

	API (G7)
		TreasuryDouble.new(initial: { [KingdomId]: ResourceBag }?): Treasury
		treasury:get(kingdom): ResourceBag                          -- a copy
		treasury:canAfford(kingdom, cost): boolean
		treasury:spend(kingdom, cost, txId, sink): boolean          -- atomic, never negative; idempotent per txId
		treasury:deposit(kingdom, resource, amount, txId, source): boolean  -- idempotent per txId
		treasury.changed: Signal (kingdom, totals, deltas)          -- once per applied transaction
	Double-only helpers (not in G7; specs and audits)
		treasury:seed(kingdom, bag)        -- set a kingdom's starting balance (no event)
		treasury:ledger(kingdom): { { txId, kind, sink|source, bag } }
		treasury:audit(kingdom): (boolean, string?)   -- seed + deposits - spends == balance
	Semantics kept from G7: a replayed txId returns the first result and changes nothing (no event);
	a failed spend is not recorded, so the same txId may be retried later; amounts are non-negative
	integers; unknown kingdoms/resources are programming errors.
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local RESOURCES = { "food", "wood", "stone", "gold" }

local TreasuryDouble = {}
TreasuryDouble.__index = TreasuryDouble

local function checkAmount(amount: any)
	if
		type(amount) ~= "number"
		or amount ~= amount
		or amount < 0
		or amount == math.huge
		or math.floor(amount) ~= amount
	then
		error(`Treasury: amount must be a non-negative integer (got {tostring(amount)})`, 3)
	end
end

local function emptyBag(): { [string]: number }
	return { food = 0, wood = 0, stone = 0, gold = 0 }
end

function TreasuryDouble.new(initial: { [string]: { [string]: number } }?)
	local self = setmetatable({}, TreasuryDouble)
	self._bags = {} :: { [string]: { [string]: number } }
	self._seeds = {} :: { [string]: { [string]: number } }
	self._tx = {} :: { [string]: boolean }
	self._ledger = {} :: { [string]: { any } }
	self.changed = Signal.new()
	for kingdom, bag in initial or {} do
		self:seed(kingdom, bag)
	end
	return self
end

function TreasuryDouble:_bag(kingdom: string): { [string]: number }
	local bag = self._bags[kingdom]
	if bag == nil then
		bag = emptyBag()
		self._bags[kingdom] = bag
		self._seeds[kingdom] = emptyBag()
		self._ledger[kingdom] = {}
	end
	return bag
end

function TreasuryDouble:seed(kingdom: string, bag: { [string]: number })
	local target = self:_bag(kingdom)
	for res, amount in bag do
		assert(target[res] ~= nil, `Treasury: unknown resource '{res}'`)
		checkAmount(amount)
		target[res] = amount
		self._seeds[kingdom][res] = amount
	end
end

function TreasuryDouble:get(kingdom: string): { [string]: number }
	return table.clone(self:_bag(kingdom))
end

function TreasuryDouble:canAfford(kingdom: string, cost: { [string]: number }): boolean
	local bag = self:_bag(kingdom)
	for res, amount in cost do
		if bag[res] == nil then
			error(`Treasury: unknown resource '{tostring(res)}'`, 2)
		end
		checkAmount(amount)
		if bag[res] < amount then
			return false
		end
	end
	return true
end

function TreasuryDouble:spend(kingdom: string, cost: { [string]: number }, txId: string, sink: string): boolean
	assert(type(txId) == "string" and txId ~= "", "Treasury:spend: txId required")
	if self._tx[txId] ~= nil then
		return self._tx[txId]
	end
	if not self:canAfford(kingdom, cost) then
		return false -- not recorded: the caller may retry the same txId later
	end
	local bag = self._bags[kingdom]
	local deltas = {}
	for res, amount in cost do
		if amount > 0 then
			bag[res] -= amount
			deltas[res] = -amount
		end
	end
	self._tx[txId] = true
	table.insert(self._ledger[kingdom], { txId = txId, kind = "spend", sink = sink, bag = table.clone(cost) })
	self.changed:fire(kingdom, table.clone(bag), deltas)
	return true
end

function TreasuryDouble:deposit(
	kingdom: string,
	resource: string,
	amount: number,
	txId: string,
	source: string
): boolean
	assert(type(txId) == "string" and txId ~= "", "Treasury:deposit: txId required")
	local bag = self:_bag(kingdom)
	if bag[resource] == nil then
		error(`Treasury: unknown resource '{tostring(resource)}'`, 2)
	end
	checkAmount(amount)
	if self._tx[txId] ~= nil then
		return self._tx[txId]
	end
	bag[resource] += amount
	self._tx[txId] = true
	table.insert(
		self._ledger[kingdom],
		{ txId = txId, kind = "deposit", source = source, bag = { [resource] = amount } }
	)
	self.changed:fire(kingdom, table.clone(bag), { [resource] = amount })
	return true
end

function TreasuryDouble:ledger(kingdom: string): { any }
	self:_bag(kingdom)
	return table.clone(self._ledger[kingdom])
end

function TreasuryDouble:audit(kingdom: string): (boolean, string?)
	local bag = self:_bag(kingdom)
	local expected = table.clone(self._seeds[kingdom])
	for _, entry in self._ledger[kingdom] do
		local sign = if entry.kind == "spend" then -1 else 1
		for res, amount in entry.bag do
			expected[res] += sign * amount
		end
	end
	for _, res in RESOURCES do
		if expected[res] ~= bag[res] then
			return false, `{kingdom} {res}: ledger {expected[res]} vs balance {bag[res]}`
		end
		if bag[res] < 0 then
			return false, `{kingdom} {res}: negative`
		end
	end
	return true, nil
end

return TreasuryDouble
