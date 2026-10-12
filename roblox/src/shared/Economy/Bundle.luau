--!strict
--[[
	Economy/Bundle — maths on resource bundles ({ [currencyId]: integer }), shared by the server
	ledger (Wallet, game TreasuryService) and the UI (costs, shortfalls). Pure; never mutates
	its inputs.

	API
		Bundle.MAX_AMOUNT                      largest amount one bundle entry may hold (2^40)
		Bundle.isAmount(n, allowZero?): boolean  finite integer in (0 | 1) .. MAX_AMOUNT
		Bundle.validate(b, opts?) -> (ok: boolean, problem: string?)
			opts = { allowZero: boolean?, allowEmpty: boolean?, currencies: { [string]: any }? }
			rejects non-tables, non-string keys, non-integer/negative/NaN/huge amounts, unknown ids
		Bundle.copy(b) -> Bundle                Bundle.isEmpty(b) -> boolean
		Bundle.add(a, b) -> Bundle              Bundle.sub(a, b) -> Bundle (may go negative)
		Bundle.negate(b) -> Bundle              Bundle.equals(a, b) -> boolean (missing == 0)
		Bundle.covers(have, cost) -> boolean    every cost entry <= have
		Bundle.missing(have, cost) -> Bundle    positive shortfalls only (empty when covered)
		Bundle.ordered(b, order?) -> { { id: string, amount: number } }
			entries sorted by `order` (a list of ids; unknown ids last, by name), zeros dropped
]]

export type Bundle = { [string]: number }

local Bundle = {}

Bundle.MAX_AMOUNT = 2 ^ 40

function Bundle.isAmount(n: any, allowZero: boolean?): boolean
	if type(n) ~= "number" or n ~= n or n == math.huge or n == -math.huge then
		return false
	end
	if n ~= math.floor(n) or n > Bundle.MAX_AMOUNT then
		return false
	end
	if allowZero then
		return n >= 0
	end
	return n > 0
end

function Bundle.validate(b: any, opts: { allowZero: boolean?, allowEmpty: boolean?, currencies: { [string]: any }? }?)
	local o = opts or {}
	if type(b) ~= "table" or getmetatable(b) ~= nil then
		return false, "bundle must be a plain table"
	end
	local count = 0
	for key, amount in b do
		count += 1
		if type(key) ~= "string" or key == "" then
			return false, `bundle key {tostring(key)} must be a currency id string`
		end
		if o.currencies and o.currencies[key] == nil then
			return false, `unknown currency '{key}'`
		end
		if not Bundle.isAmount(amount, o.allowZero) then
			return false,
				`amount for '{key}' must be a whole number {if o.allowZero then ">= 0" else "> 0"} (got {tostring(
					amount
				)})`
		end
	end
	if count == 0 and not o.allowEmpty then
		return false, "bundle is empty"
	end
	return true, nil
end

function Bundle.copy(b: Bundle): Bundle
	return table.clone(b)
end

function Bundle.isEmpty(b: Bundle): boolean
	for _, v in b do
		if v ~= 0 then
			return false
		end
	end
	return true
end

function Bundle.add(a: Bundle, b: Bundle): Bundle
	local out = Bundle.copy(a)
	for k, v in b do
		out[k] = (out[k] or 0) + v
	end
	return out
end

function Bundle.sub(a: Bundle, b: Bundle): Bundle
	local out = Bundle.copy(a)
	for k, v in b do
		out[k] = (out[k] or 0) - v
	end
	return out
end

function Bundle.negate(b: Bundle): Bundle
	local out = {}
	for k, v in b do
		out[k] = -v
	end
	return out
end

function Bundle.equals(a: Bundle, b: Bundle): boolean
	for k, v in a do
		if (b[k] or 0) ~= v then
			return false
		end
	end
	for k, v in b do
		if (a[k] or 0) ~= v then
			return false
		end
	end
	return true
end

function Bundle.covers(have: Bundle, cost: Bundle): boolean
	for k, v in cost do
		if (have[k] or 0) < v then
			return false
		end
	end
	return true
end

function Bundle.missing(have: Bundle, cost: Bundle): Bundle
	local out = {}
	for k, v in cost do
		local short = v - (have[k] or 0)
		if short > 0 then
			out[k] = short
		end
	end
	return out
end

function Bundle.ordered(b: Bundle, order: { string }?): { { id: string, amount: number } }
	local rank: { [string]: number } = {}
	if order then
		for i, id in order do
			rank[id] = i
		end
	end
	local out = {}
	for id, amount in b do
		if amount ~= 0 then
			table.insert(out, { id = id, amount = amount })
		end
	end
	table.sort(out, function(x, y)
		local rx, ry = rank[x.id] or math.huge, rank[y.id] or math.huge
		if rx ~= ry then
			return rx < ry
		end
		return x.id < y.id
	end)
	return out
end

return table.freeze(Bundle)
