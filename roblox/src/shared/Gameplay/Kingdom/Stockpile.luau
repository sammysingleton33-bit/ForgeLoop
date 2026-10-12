--!strict
--[[
	Gameplay/Kingdom/Stockpile — a kingdom's resource balance with storage capacity and an audit
	ledger. Integer-only and all-or-nothing, so a balance can never go negative or drift, and every
	unit that enters or leaves is booked under a reason.

	API
		Stockpile.new(resources: { string }, initial: Cost?, capacity: number): Stockpile
		stockpile:get(resource): number
		stockpile:capacity(): number                      -- per resource
		stockpile:setCapacity(n)                          -- stock above a lowered cap is kept (not destroyed)
		stockpile:add(resource, amount, reason?): number  -- returns the amount actually stored (capped)
		stockpile:canAfford(cost): boolean
		stockpile:spend(cost, reason?): boolean           -- atomic: all of the cost or nothing
		stockpile:take(resource, amount, reason?): number -- removes up to amount, returns what was taken
		stockpile:refund(cost, fraction?, reason?): Cost  -- adds floor(cost * fraction) per resource, capped
		stockpile:snapshot(): Cost                        -- a copy, safe to send to clients
		stockpile:flows(): { income: { [reason]: Cost }, expense: { [reason]: Cost } }  -- copies
		stockpile:audit(): (boolean, string?)             -- initial + income - expense == balance, per resource
	Reasons used by the simulation: income "gathered", "refund", "loot"; expense "construction",
	"upgrade", "meal", "birth", "recruit", "plundered". Default reason "other".
	Errors (programming mistakes, never player input): unknown resource, negative/non-integer amount.
	Validation of player-supplied values happens in Commands before anything reaches the stockpile.
]]

export type Cost = { [string]: number }

export type Stockpile = {
	get: (self: Stockpile, resource: string) -> number,
	capacity: (self: Stockpile) -> number,
	setCapacity: (self: Stockpile, capacity: number) -> (),
	add: (self: Stockpile, resource: string, amount: number, reason: string?) -> number,
	canAfford: (self: Stockpile, cost: Cost) -> boolean,
	spend: (self: Stockpile, cost: Cost, reason: string?) -> boolean,
	take: (self: Stockpile, resource: string, amount: number, reason: string?) -> number,
	refund: (self: Stockpile, cost: Cost, fraction: number?, reason: string?) -> Cost,
	snapshot: (self: Stockpile) -> Cost,
	flows: (self: Stockpile) -> { income: { [string]: Cost }, expense: { [string]: Cost } },
	audit: (self: Stockpile) -> (boolean, string?),
}

local StockpileClass = {}
StockpileClass.__index = StockpileClass

local Stockpile = {}

local function checkAmount(amount: any)
	if
		type(amount) ~= "number"
		or amount ~= amount
		or amount < 0
		or amount == math.huge
		or math.floor(amount) ~= amount
	then
		error(`Stockpile: amount must be a non-negative integer (got {tostring(amount)})`, 3)
	end
end

function Stockpile.new(resources: { string }, initial: Cost?, capacity: number): Stockpile
	local self = setmetatable({
		_amounts = {},
		_initial = {},
		_order = table.clone(resources),
		_cap = capacity,
		_income = {},
		_expense = {},
	}, StockpileClass)
	for _, res in resources do
		self._amounts[res] = 0
	end
	if initial then
		for res, amount in initial do
			if self._amounts[res] == nil then
				error(`Stockpile: unknown resource '{res}'`, 2)
			end
			checkAmount(amount)
			self._amounts[res] = amount
		end
	end
	self._initial = table.clone(self._amounts)
	return (self :: any) :: Stockpile
end

function StockpileClass:_check(resource: string)
	if self._amounts[resource] == nil then
		error(`Stockpile: unknown resource '{tostring(resource)}'`, 3)
	end
end

function StockpileClass:_book(book: { [string]: Cost }, reason: string?, resource: string, amount: number)
	if amount == 0 then
		return
	end
	local key = reason or "other"
	local entry = book[key]
	if entry == nil then
		entry = {}
		book[key] = entry
	end
	entry[resource] = (entry[resource] or 0) + amount
end

function StockpileClass:get(resource: string): number
	self:_check(resource)
	return self._amounts[resource]
end

function StockpileClass:capacity(): number
	return self._cap
end

function StockpileClass:setCapacity(capacity: number)
	checkAmount(capacity)
	self._cap = capacity
end

function StockpileClass:add(resource: string, amount: number, reason: string?): number
	self:_check(resource)
	checkAmount(amount)
	local current = self._amounts[resource]
	local room = math.max(0, self._cap - current)
	local stored = math.min(room, amount)
	self._amounts[resource] = current + stored
	self:_book(self._income, reason, resource, stored)
	return stored
end

function StockpileClass:canAfford(cost: Cost): boolean
	for res, amount in cost do
		self:_check(res)
		checkAmount(amount)
		if self._amounts[res] < amount then
			return false
		end
	end
	return true
end

function StockpileClass:spend(cost: Cost, reason: string?): boolean
	if not self:canAfford(cost) then
		return false
	end
	for res, amount in cost do
		self._amounts[res] -= amount
		self:_book(self._expense, reason, res, amount)
	end
	return true
end

function StockpileClass:take(resource: string, amount: number, reason: string?): number
	self:_check(resource)
	checkAmount(amount)
	local taken = math.min(self._amounts[resource], amount)
	self._amounts[resource] -= taken
	self:_book(self._expense, reason, resource, taken)
	return taken
end

function StockpileClass:refund(cost: Cost, fraction: number?, reason: string?): Cost
	local f = fraction or 1
	local stored = {}
	for _, res in self._order do
		local amount = cost[res]
		if amount then
			stored[res] = self:add(res, math.floor(amount * f), reason or "refund")
		end
	end
	return stored
end

function StockpileClass:snapshot(): Cost
	return table.clone(self._amounts)
end

local function copyBook(book: { [string]: Cost }): { [string]: Cost }
	local out = {}
	for reason, entry in book do
		out[reason] = table.clone(entry)
	end
	return out
end

function StockpileClass:flows()
	return { income = copyBook(self._income), expense = copyBook(self._expense) }
end

function StockpileClass:audit(): (boolean, string?)
	for _, res in self._order do
		local expected = self._initial[res]
		for _, entry in self._income do
			expected += entry[res] or 0
		end
		for _, entry in self._expense do
			expected -= entry[res] or 0
		end
		if expected ~= self._amounts[res] then
			return false, `{res}: ledger says {expected}, balance is {self._amounts[res]}`
		end
		if self._amounts[res] < 0 then
			return false, `{res}: negative balance {self._amounts[res]}`
		end
	end
	return true, nil
end

return Stockpile
