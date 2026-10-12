--!strict
--[[
	Economy/Currencies — validated currency definitions (games/<game>/config/Currencies.luau).

	A currency is "paid" when `robuxPurchasable` is true: random rewards bought with it are paid
	random and need PurchaseService:canBuyPaidRandom (interfaces §7).

	API
		Currencies.SCOPES = { "match", "profile" }
		Currencies.validate(defs) -> (ok: boolean, problems: { string })   every problem, named
		Currencies.new(defs) -> registry                                    errors listing problems
		Currencies.default() -> registry                                    Config.Currencies (cached)
		registry:get(id) -> def?            registry:require(id) -> def (errors when unknown)
		registry:all() -> { def }           config order (= display order)
		registry:ids(scope?) -> { string }  config order, optionally one scope
		registry:set(scope?) -> { [string]: true }
		registry:isPaid(id) -> boolean      robuxPurchasable
		registry:starting(scope) -> Bundle  `start` of every currency in that scope
		registry:caps(scope) -> Bundle      base `cap` of every currency in that scope
]]

local Bundle = require("./Bundle")
local Config = require("@game/ReplicatedStorage/Forge/Config/Currencies")

export type CurrencyDef = {
	id: string,
	name: string,
	scope: "match" | "profile",
	icon: string,
	start: number,
	cap: number,
	robuxPurchasable: boolean,
	description: string,
}

local Currencies = {}
Currencies.__index = Currencies
Currencies.SCOPES = table.freeze({ "match", "profile" })

local FIELDS = {
	id = "string",
	name = "string",
	scope = "string",
	icon = "string",
	start = "number",
	cap = "number",
	robuxPurchasable = "boolean",
	description = "string",
}

function Currencies.validate(defs: any): (boolean, { string })
	local problems = {}
	if type(defs) ~= "table" then
		return false, { "currencies config must be a list" }
	end
	local seen = {}
	for index, def in defs do
		local where = `currency #{index}`
		if type(index) ~= "number" or type(def) ~= "table" then
			table.insert(problems, `{where}: must be a table in a list`)
			continue
		end
		if type(def.id) == "string" then
			where = `currency '{def.id}'`
		end
		for field, kind in FIELDS do
			if type(def[field]) ~= kind then
				table.insert(problems, `{where}: '{field}' must be a {kind}`)
			end
		end
		for field in def do
			if FIELDS[field] == nil then
				table.insert(problems, `{where}: unknown field '{tostring(field)}'`)
			end
		end
		if type(def.id) == "string" then
			if not string.match(def.id, "^[a-z][a-z0-9_]*$") or #def.id > 32 then
				table.insert(problems, `{where}: id must match [a-z][a-z0-9_]* (max 32 bytes)`)
			end
			if seen[def.id] then
				table.insert(problems, `{where}: duplicate id`)
			end
			seen[def.id] = true
		end
		if type(def.scope) == "string" and table.find(Currencies.SCOPES, def.scope) == nil then
			table.insert(problems, `{where}: scope must be "match" or "profile"`)
		end
		if type(def.name) == "string" and def.name == "" then
			table.insert(problems, `{where}: name is empty`)
		end
		if type(def.cap) == "number" and not Bundle.isAmount(def.cap) then
			table.insert(problems, `{where}: cap must be a whole number > 0`)
		end
		if type(def.start) == "number" then
			if not Bundle.isAmount(def.start, true) then
				table.insert(problems, `{where}: start must be a whole number >= 0`)
			elseif type(def.cap) == "number" and def.start > def.cap then
				table.insert(problems, `{where}: start is above cap`)
			end
		end
		if def.robuxPurchasable == true and def.scope == "match" then
			table.insert(problems, `{where}: match resources cannot be robuxPurchasable`)
		end
	end
	return #problems == 0, problems
end

function Currencies.new(defs: { CurrencyDef })
	local ok, problems = Currencies.validate(defs)
	if not ok then
		error("Currencies config invalid:\n  " .. table.concat(problems, "\n  "), 2)
	end
	local byId = {}
	local list = {}
	for _, def in defs do
		local frozen = table.freeze(table.clone(def))
		byId[def.id] = frozen
		table.insert(list, frozen)
	end
	return setmetatable({ _byId = byId, _list = list }, Currencies)
end

local cached = nil
function Currencies.default()
	if cached == nil then
		cached = Currencies.new(Config :: any)
	end
	return cached
end

function Currencies:get(id: string): CurrencyDef?
	return self._byId[id]
end

function Currencies:require(id: string): CurrencyDef
	local def = self._byId[id]
	if def == nil then
		error(`unknown currency '{tostring(id)}'`, 2)
	end
	return def
end

function Currencies:all(): { CurrencyDef }
	return table.clone(self._list)
end

function Currencies:ids(scope: string?): { string }
	local out = {}
	for _, def in self._list do
		if scope == nil or def.scope == scope then
			table.insert(out, def.id)
		end
	end
	return out
end

function Currencies:set(scope: string?): { [string]: boolean }
	local out = {}
	for _, id in self:ids(scope) do
		out[id] = true
	end
	return out
end

function Currencies:isPaid(id: string): boolean
	local def = self._byId[id]
	return def ~= nil and def.robuxPurchasable == true
end

function Currencies:starting(scope: string): Bundle.Bundle
	local out = {}
	for _, def in self._list do
		if def.scope == scope then
			out[def.id] = def.start
		end
	end
	return out
end

function Currencies:caps(scope: string): Bundle.Bundle
	local out = {}
	for _, def in self._list do
		if def.scope == scope then
			out[def.id] = def.cap
		end
	end
	return out
end

return Currencies
