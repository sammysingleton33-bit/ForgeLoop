--!strict
--[[
	Economy/RewardTables — weighted rarity tiers, honest odds, optional pity and seeded rolls
	(interfaces §7). Shared by the server (RewardService rolls) and the UI (odds screen). roll() walks
	the very list odds() returns with one uniform draw, so the odds a player is shown are exactly the
	distribution the server samples for the same pity state.

	API — module functions use the default set (Config.RewardTables); an instance from new() has the
	same functions as methods (tables:odds(tableId, pityState), ...), so specs can use fixtures.
		RewardTables.validate(config, itemRegistry, currencyIds: { string }?): (boolean, { string })
		RewardTables.new(config, itemRegistry, currencyIds: { string }?): Tables  -- errors listing every problem
		RewardTables.default(): Tables   -- Config.RewardTables + ItemRegistry.default() + Config.Currencies ids; cached
		odds(tableId, pityState: PityState?): { OddsEntry }   -- frozen { rarity, itemId, qty, probability }
		pityRule(tableId): string?            -- "Epic or better guaranteed within 10 opens"; nil without pity
		pityStates(tableId): { PityState }    -- every reachable state: opensSinceHit 0 .. afterOpens - 1
		nextPityState(tableId, pityState: PityState?, rolledRarity: string): PityState
		roll(tableId, pityState: PityState?, rng: Random | number): (RewardResult, PityState)
		displayHundredths(odds): { number }   -- integer hundredths of a percent, sum exactly 10000
		displayPercents(odds): { string }     -- "12.50%", one per entry, sum exactly 100.00%
		get(tableId): TableDef?               -- frozen definition (name, cost, pity, tiers)
		all(): { TableDef }                   -- config order
		RewardTables.ODDS_SUM_TOLERANCE       -- 1e-9: displayHundredths rejects odds further from 1

	Odds: one entry per tier item, ordered by rarity rank (Common first), then config order;
	probability = tierWeight / sum(tierWeights) * itemWeight / sum(itemWeights in the tier).
	Pity: PityState = { opensSinceHit: integer >= 0 } (opens since the last result at or above
	pity.minRarity; nil means 0). When opensSinceHit >= afterOpens - 1 the open is the guaranteed one:
	tiers below minRarity are removed and the remaining weights renormalised. RewardResult.pityTriggered
	is true only when that removed at least one tier. nextPityState resets to 0 on a result at or above
	minRarity, otherwise adds 1 (never past afterOpens - 1); without pity it is always 0.
	Rolls: rng is a Random (or anything with :NextNumber() in [0, 1)) or a seed for Random.new(seed).
	The entry chosen is the first whose cumulative probability exceeds the draw r; if floating-point
	rounding leaves the total a hair below 1 and r lands above it, the last entry is chosen.
	Display: largest-remainder rounding of probability * 10000; unassigned hundredths go to the largest
	remainders (remainders compared at 1e-9 resolution, ties in list order).

	Validation (every problem named with the table and field): unique ids; name; at least one tier;
	rarities valid and each at most once; weights finite and > 0 (and finite sums); every itemId exists,
	is a cosmetic, has the tier's rarity and appears once per table; qty an integer >= 1 within the item's
	stack cap; pity.afterOpens an integer >= 1 and pity.minRarity reachable; cost.currency a known
	currency (when currencyIds is given) and cost.amount an integer >= 1; unknown fields rejected; and no
	possible outcome, in any pity state, may be displayed as 0.00%.
]]

local ItemRegistry = require("./ItemRegistry")
local Types = require("../Contracts/Types")
local ConfigCurrencies = require("@game/ReplicatedStorage/Forge/Config/Currencies")
local ConfigRewardTables = require("@game/ReplicatedStorage/Forge/Config/RewardTables")

export type RewardResult = Types.RewardResult
export type PityState = { opensSinceHit: number }
export type OddsEntry = { rarity: string, itemId: string, qty: number, probability: number }
export type TierItem = { itemId: string, weight: number, qty: number? }
export type Tier = { rarity: string, weight: number, items: { TierItem } }
export type Pity = { afterOpens: number, minRarity: string }
export type Cost = { currency: string, amount: number }
export type TableDef = { id: string, name: string, tiers: { Tier }, pity: Pity?, cost: Cost? }

type Compiled = {
	def: TableDef,
	normal: { OddsEntry },
	guaranteed: { OddsEntry }?, -- nil without pity
	pityRemovesTiers: boolean,
	minRank: number?,
	tierRarities: { [string]: boolean },
	states: { PityState },
	rule: string?,
}

local RewardTables = {}
RewardTables.ODDS_SUM_TOLERANCE = 1e-9

local HUNDREDTHS_TOTAL = 10000
local SNAP = 1e-7 -- probability * 10000 this close to an integer is treated as that integer
local REMAINDER_RESOLUTION = 1e9

local TABLE_FIELDS = { id = true, name = true, tiers = true, pity = true, cost = true }
local TIER_FIELDS = { rarity = true, weight = true, items = true }
local ENTRY_FIELDS = { itemId = true, weight = true, qty = true }
local PITY_FIELDS = { afterOpens = true, minRarity = true }
local COST_FIELDS = { currency = true, amount = true }

local Tables = {}
Tables.__index = Tables

type TablesData = { _byId: { [string]: Compiled }, _list: { TableDef } }
export type Tables = typeof(setmetatable({} :: TablesData, Tables))

-- ---------------------------------------------------------------- helpers

local function show(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) == "table" then
		return "a table"
	end
	return tostring(value)
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and math.abs(value) ~= math.huge
end

local function isPositiveFinite(value: any): boolean
	return type(value) == "number" and value > 0 and value ~= math.huge -- NaN fails value > 0
end

-- true when the keys of t are exactly 1..#t
local function isList(t: any): boolean
	if type(t) ~= "table" then
		return false
	end
	local n = #t
	local count = 0
	for key in t do
		if type(key) ~= "number" or key < 1 or key > n or key % 1 ~= 0 then
			return false
		end
		count += 1
	end
	return count == n
end

-- path "" for the table itself, else e.g. "tiers[1]" -> 'tiers[1]: unknown field "wieght"'
local function unknownFields(t: { [any]: any }, allowed: { [string]: boolean }, problem: (string) -> (), path: string)
	local unknown = {}
	for key in t do
		if type(key) ~= "string" or not allowed[key] then
			table.insert(unknown, show(key))
		end
	end
	table.sort(unknown)
	for _, key in unknown do
		problem(if path == "" then `unknown field {key}` else `{path}: unknown field {key}`)
	end
end

local function frozenCopy(value: any, memo: { [any]: any }): any
	if type(value) ~= "table" then
		return value
	end
	local existing = memo[value]
	if existing ~= nil then
		return existing
	end
	local copy = {}
	memo[value] = copy
	for key, child in value do
		copy[frozenCopy(key, memo)] = frozenCopy(child, memo)
	end
	return table.freeze(copy)
end

local function rank(rarity: string): number
	return ItemRegistry.rarityRank(rarity) :: number
end

local RARITY_LIST = table.concat(ItemRegistry.RARITIES, ", ")

-- ---------------------------------------------------------------- display rounding

local function displayHundredths(odds: { OddsEntry }): { number }
	if not isList(odds) or #odds == 0 then
		error("RewardTables.displayHundredths: odds must be a non-empty list of { probability: number }", 2)
	end
	local n = #odds
	local hundredths: { number } = table.create(n, 0)
	local keys: { number } = table.create(n, 0)
	local total, assigned = 0, 0
	for i = 1, n do
		local entry: any = odds[i]
		local p = if type(entry) == "table" then entry.probability else nil
		if type(p) ~= "number" or not (p >= 0 and p <= 1 + RewardTables.ODDS_SUM_TOLERANCE) then
			error(`RewardTables.displayHundredths: odds[{i}].probability must be a number in [0, 1] (got {show(p)})`, 2)
		end
		total += p
		local exact = p * HUNDREDTHS_TOTAL
		local nearest = math.floor(exact + 0.5)
		if math.abs(exact - nearest) < SNAP then
			exact = nearest
		end
		local whole = math.floor(exact)
		hundredths[i] = whole
		keys[i] = math.floor((exact - whole) * REMAINDER_RESOLUTION + 0.5)
		assigned += whole
	end
	if math.abs(total - 1) > RewardTables.ODDS_SUM_TOLERANCE then
		error(`RewardTables.displayHundredths: probabilities must sum to 1 (got {total})`, 2)
	end
	local missing = HUNDREDTHS_TOTAL - assigned
	assert(missing >= 0 and missing <= n, "RewardTables.displayHundredths: rounding invariant broken")
	local order: { number } = table.create(n, 0)
	for i = 1, n do
		order[i] = i
	end
	table.sort(order, function(a: number, b: number): boolean
		if keys[a] ~= keys[b] then
			return keys[a] > keys[b]
		end
		return a < b
	end)
	for k = 1, missing do
		hundredths[order[k]] += 1
	end
	return hundredths
end

local function displayPercents(odds: { OddsEntry }): { string }
	local hundredths = displayHundredths(odds)
	local out: { string } = table.create(#hundredths, "")
	for i, h in hundredths do
		out[i] = string.format("%d.%02d%%", math.floor(h / 100), h % 100)
	end
	return out
end

RewardTables.displayHundredths = displayHundredths
RewardTables.displayPercents = displayPercents

-- ---------------------------------------------------------------- compiling a (valid) table

local function buildOdds(sortedTiers: { Tier }, minRank: number?): { OddsEntry }
	local kept: { Tier } = {}
	local tierSum = 0
	for _, tier in sortedTiers do
		if minRank == nil or rank(tier.rarity) >= minRank then
			table.insert(kept, tier)
			tierSum += tier.weight
		end
	end
	local entries: { OddsEntry } = {}
	for _, tier in kept do
		local itemSum = 0
		for _, item in tier.items do
			itemSum += item.weight
		end
		for _, item in tier.items do
			table.insert(
				entries,
				table.freeze({
					rarity = tier.rarity,
					itemId = item.itemId,
					qty = item.qty or 1,
					probability = (tier.weight / tierSum) * (item.weight / itemSum),
				})
			)
		end
	end
	return table.freeze(entries)
end

local function ruleText(pity: Pity): string
	local top = ItemRegistry.RARITIES[#ItemRegistry.RARITIES]
	local what = if pity.minRarity == top then top else `{pity.minRarity} or better`
	local opens = if pity.afterOpens == 1 then "1 open" else `{pity.afterOpens} opens`
	return `{what} guaranteed within {opens}`
end

local function compile(def: TableDef): Compiled
	local sorted: { Tier } = {}
	local tierRarities: { [string]: boolean } = {}
	for i, tier in def.tiers do
		sorted[i] = tier
		tierRarities[tier.rarity] = true
	end
	table.sort(sorted, function(a: Tier, b: Tier): boolean
		return rank(a.rarity) < rank(b.rarity)
	end)
	local normal = buildOdds(sorted, nil)
	local compiled: Compiled = {
		def = def,
		normal = normal,
		guaranteed = nil,
		pityRemovesTiers = false,
		minRank = nil,
		tierRarities = tierRarities,
		states = table.freeze({ table.freeze({ opensSinceHit = 0 }) }),
		rule = nil,
	}
	local pity = def.pity
	if pity ~= nil then
		local minRank = rank(pity.minRarity)
		local guaranteed = buildOdds(sorted, minRank)
		local states: { PityState } = {}
		for opens = 0, pity.afterOpens - 1 do
			table.insert(states, table.freeze({ opensSinceHit = opens }))
		end
		compiled.guaranteed = guaranteed
		compiled.pityRemovesTiers = #guaranteed < #normal -- every tier has at least one item
		compiled.minRank = minRank
		compiled.states = table.freeze(states)
		compiled.rule = ruleText(pity)
	end
	return compiled
end

-- ---------------------------------------------------------------- validation

local function validateTable(
	t: any,
	label: string,
	registry: any,
	currencySet: { [string]: boolean }?,
	add: (string) -> ()
): boolean
	local clean = true
	local function problem(message: string)
		clean = false
		add(`{label}: {message}`)
	end

	unknownFields(t, TABLE_FIELDS, problem, "")
	if not ItemRegistry.isValidId(t.id) then
		problem(`id must be a string matching ^[a-z][a-z0-9_]*$ of at most 32 bytes (got {show(t.id)})`)
	end
	if type(t.name) ~= "string" or #t.name == 0 then
		problem(`name must be a non-empty string (got {show(t.name)})`)
	end

	local tiersUsable = isList(t.tiers) and #t.tiers > 0
	local maxTierRank = 0
	if not tiersUsable then
		problem(`tiers must be a non-empty list (got {show(t.tiers)})`)
	else
		local tierAt: { [string]: number } = {}
		local itemAt: { [string]: string } = {}
		local tierSum = 0
		for j = 1, #t.tiers do
			local tier = t.tiers[j]
			local tl = `tiers[{j}]`
			if type(tier) ~= "table" then
				problem(`{tl} must be a table (got {show(tier)})`)
				continue
			end
			unknownFields(tier, TIER_FIELDS, problem, tl)
			local tierRank = ItemRegistry.rarityRank(tier.rarity)
			if tierRank == nil then
				problem(`{tl}.rarity must be one of {RARITY_LIST} (got {show(tier.rarity)})`)
			elseif tierAt[tier.rarity] ~= nil then
				problem(`{tl}.rarity {show(tier.rarity)} duplicates tiers[{tierAt[tier.rarity]}]`)
			else
				tierAt[tier.rarity] = j
				maxTierRank = math.max(maxTierRank, tierRank)
			end
			if isPositiveFinite(tier.weight) then
				tierSum += tier.weight
			else
				problem(`{tl}.weight must be a finite number > 0 (got {show(tier.weight)})`)
			end
			if not isList(tier.items) or #tier.items == 0 then
				problem(`{tl}.items must be a non-empty list (got {show(tier.items)})`)
				continue
			end
			local itemSum = 0
			for k = 1, #tier.items do
				local entry = tier.items[k]
				local el = `{tl}.items[{k}]`
				if type(entry) ~= "table" then
					problem(`{el} must be a table (got {show(entry)})`)
					continue
				end
				unknownFields(entry, ENTRY_FIELDS, problem, el)
				local def = if type(entry.itemId) == "string" then registry:get(entry.itemId) else nil
				if def == nil then
					problem(`{el}.itemId: unknown item {show(entry.itemId)}`)
				else
					if def.kind ~= "cosmetic" then
						problem(`{el}.itemId: {show(def.id)} is a {def.kind}; only cosmetic items can be rewards`)
					end
					if tierRank ~= nil and def.rarity ~= tier.rarity then
						problem(`{el}.itemId: {show(def.id)} is {def.rarity} but sits in the {tier.rarity} tier`)
					end
					if itemAt[def.id] ~= nil then
						problem(`{el}.itemId: {show(def.id)} already appears at {itemAt[def.id]}`)
					else
						itemAt[def.id] = el
					end
					local cap = def.maxStack or 1
					if isInteger(entry.qty) and entry.qty > cap then
						problem(`{el}.qty {entry.qty} exceeds the stack cap of {show(def.id)} ({cap})`)
					end
				end
				if isPositiveFinite(entry.weight) then
					itemSum += entry.weight
				else
					problem(`{el}.weight must be a finite number > 0 (got {show(entry.weight)})`)
				end
				if entry.qty ~= nil and not (isInteger(entry.qty) and entry.qty >= 1) then
					problem(`{el}.qty must be nil or an integer >= 1 (got {show(entry.qty)})`)
				end
			end
			if itemSum == math.huge then
				problem(`{tl}.items: the item weights must have a finite sum`)
			end
		end
		if tierSum == math.huge then
			problem("tiers: the tier weights must have a finite sum")
		end
	end

	if t.pity ~= nil then
		if type(t.pity) ~= "table" then
			problem(`pity must be nil or a table (got {show(t.pity)})`)
		else
			unknownFields(t.pity, PITY_FIELDS, problem, "pity")
			if not (isInteger(t.pity.afterOpens) and t.pity.afterOpens >= 1) then
				problem(`pity.afterOpens must be an integer >= 1 (got {show(t.pity.afterOpens)})`)
			end
			local minRank = ItemRegistry.rarityRank(t.pity.minRarity)
			if minRank == nil then
				problem(`pity.minRarity must be one of {RARITY_LIST} (got {show(t.pity.minRarity)})`)
			elseif tiersUsable and maxTierRank < minRank then
				problem(`pity.minRarity {show(t.pity.minRarity)} is unreachable: no tier is at or above it`)
			end
		end
	end

	if t.cost ~= nil then
		if type(t.cost) ~= "table" then
			problem(`cost must be nil or a table (got {show(t.cost)})`)
		else
			unknownFields(t.cost, COST_FIELDS, problem, "cost")
			local currency = t.cost.currency
			if currencySet ~= nil then
				if type(currency) ~= "string" or not currencySet[currency] then
					problem(`cost.currency: unknown currency {show(currency)}`)
				end
			elseif not ItemRegistry.isValidId(currency) then
				problem(`cost.currency must be a currency id (got {show(currency)})`)
			end
			if not (isInteger(t.cost.amount) and t.cost.amount >= 1) then
				problem(`cost.amount must be an integer >= 1 (got {show(t.cost.amount)})`)
			end
		end
	end

	if clean then
		-- Honest display: in every pity state the odds sum to 1 and every possible outcome shows >= 0.01%.
		local compiled = compile(t :: TableDef)
		local lists = { { compiled.normal, "" } }
		if compiled.guaranteed ~= nil then
			table.insert(lists, { compiled.guaranteed, " on the guaranteed (pity) open" })
		end
		for _, pair in lists do
			local odds: { OddsEntry }, when: string = pair[1], pair[2]
			local sum = 0
			for _, entry in odds do
				sum += entry.probability
			end
			if math.abs(sum - 1) > 1e-12 then
				problem(`odds{when} sum to {sum}, not 1`)
				continue
			end
			local hundredths = displayHundredths(odds)
			for i, entry in odds do
				if hundredths[i] < 1 then
					problem(
						`{show(entry.itemId)} ({entry.rarity}) would be shown as 0.00%{when}; raise its weight so `
							.. "every possible outcome shows at least 0.01%"
					)
				end
			end
		end
	end
	return clean
end

function RewardTables.validate(config: any, itemRegistry: any, currencyIds: { string }?): (boolean, { string })
	if type(itemRegistry) ~= "table" or type(itemRegistry.get) ~= "function" then
		error("RewardTables.validate: itemRegistry must be an ItemRegistry (ItemRegistry.new or .default())", 2)
	end
	local currencySet: { [string]: boolean }? = nil
	if currencyIds ~= nil then
		local set = {}
		for _, id in currencyIds do
			set[id] = true
		end
		currencySet = set
	end
	local problems: { string } = {}
	local function add(message: string)
		table.insert(problems, message)
	end
	if type(config) ~= "table" then
		add(`rewardTables: must be a list of reward tables (got {typeof(config)})`)
		return false, problems
	end
	if not isList(config) then
		add("rewardTables: must be a list (keys 1..n with no gaps or other keys)")
	end
	local firstIndex: { [string]: number } = {}
	for index = 1, #config do
		local t = config[index]
		local label = `rewardTables[{index}]`
		if type(t) ~= "table" then
			add(`{label}: must be a table (got {typeof(t)})`)
			continue
		end
		if type(t.id) == "string" then
			label ..= ` ({show(t.id)})`
			local first = firstIndex[t.id]
			if first ~= nil then
				add(`{label}: id duplicates rewardTables[{first}]`)
			else
				firstIndex[t.id] = index
			end
		end
		validateTable(t, label, itemRegistry, currencySet, add)
	end
	return #problems == 0, problems
end

-- ---------------------------------------------------------------- instances

function RewardTables.new(config: { TableDef }, itemRegistry: any, currencyIds: { string }?): Tables
	local ok, problems = RewardTables.validate(config, itemRegistry, currencyIds)
	if not ok then
		error(`RewardTables: invalid reward tables ({#problems}):\n  {table.concat(problems, "\n  ")}`, 2)
	end
	local byId: { [string]: Compiled } = {}
	local list: { TableDef } = {}
	local memo = {}
	for index = 1, #config do
		local def: TableDef = frozenCopy(config[index], memo)
		list[index] = def
		byId[def.id] = compile(def)
	end
	local self = setmetatable({ _byId = table.freeze(byId), _list = table.freeze(list) }, Tables)
	return table.freeze(self) :: any
end

local function lookup(self: Tables, tableId: string): Compiled
	local compiled = if type(tableId) == "string" then self._byId[tableId] else nil
	if compiled == nil then
		error(`RewardTables: unknown reward table {show(tableId)}`, 3)
	end
	return compiled
end

local function opensOf(pityState: any): number
	if pityState == nil then
		return 0
	end
	local opens = if type(pityState) == "table" then pityState.opensSinceHit else nil
	if not (isInteger(opens) and opens >= 0) then
		error(`RewardTables: pityState must be nil or \{ opensSinceHit: integer >= 0 } (got {show(opens)})`, 3)
	end
	return opens
end

local function isGuaranteedOpen(compiled: Compiled, opens: number): boolean
	local pity = compiled.def.pity
	return pity ~= nil and opens >= pity.afterOpens - 1
end

function Tables.odds(self: Tables, tableId: string, pityState: PityState?): { OddsEntry }
	local compiled = lookup(self, tableId)
	if isGuaranteedOpen(compiled, opensOf(pityState)) then
		return compiled.guaranteed :: { OddsEntry }
	end
	return compiled.normal
end

function Tables.pityRule(self: Tables, tableId: string): string?
	return lookup(self, tableId).rule
end

function Tables.pityStates(self: Tables, tableId: string): { PityState }
	return lookup(self, tableId).states
end

function Tables.nextPityState(self: Tables, tableId: string, pityState: PityState?, rolledRarity: string): PityState
	local compiled = lookup(self, tableId)
	local opens = opensOf(pityState)
	if type(rolledRarity) ~= "string" or not compiled.tierRarities[rolledRarity] then
		error(`RewardTables: {show(rolledRarity)} is not a rarity of reward table {show(tableId)}`, 2)
	end
	local pity = compiled.def.pity
	if pity == nil or rank(rolledRarity) >= (compiled.minRank :: number) then
		return { opensSinceHit = 0 }
	end
	return { opensSinceHit = math.min(opens + 1, pity.afterOpens - 1) }
end

function Tables.roll(self: Tables, tableId: string, pityState: PityState?, rng: any): (RewardResult, PityState)
	local compiled = lookup(self, tableId)
	local guaranteed = isGuaranteedOpen(compiled, opensOf(pityState))
	local odds = self:odds(tableId, pityState) -- the very list the UI displays for this state
	local generator = rng
	if type(rng) == "number" then
		generator = Random.new(rng)
	elseif type(rng) ~= "table" and type(rng) ~= "userdata" then
		error(`RewardTables.roll: rng must be a Random (or :NextNumber() object) or a seed (got {typeof(rng)})`, 2)
	end
	local r = generator:NextNumber()
	if type(r) ~= "number" or not (r >= 0 and r < 1) then
		error(`RewardTables.roll: rng:NextNumber() must return a number in [0, 1) (got {show(r)})`, 2)
	end
	local chosen = odds[#odds] -- reached only if rounding left the cumulative total below r
	local cumulative = 0
	for _, entry in odds do
		cumulative += entry.probability
		if r < cumulative then
			chosen = entry
			break
		end
	end
	local result: RewardResult = {
		tableId = tableId,
		rarity = chosen.rarity,
		itemId = chosen.itemId,
		qty = chosen.qty,
		pityTriggered = guaranteed and compiled.pityRemovesTiers,
	}
	return result, self:nextPityState(tableId, pityState, chosen.rarity)
end

function Tables.get(self: Tables, tableId: string): TableDef?
	local compiled = if type(tableId) == "string" then self._byId[tableId] else nil
	return if compiled then compiled.def else nil
end

function Tables.all(self: Tables): { TableDef }
	return self._list
end

function Tables.displayHundredths(_self: Tables, odds: { OddsEntry }): { number }
	return displayHundredths(odds)
end

function Tables.displayPercents(_self: Tables, odds: { OddsEntry }): { string }
	return displayPercents(odds)
end

-- ---------------------------------------------------------------- default set (module functions)

local cachedDefault: Tables? = nil

function RewardTables.default(): Tables
	if cachedDefault == nil then
		local currencyIds: { string } = {}
		for _, currency in ConfigCurrencies do
			table.insert(currencyIds, currency.id)
		end
		cachedDefault = RewardTables.new(ConfigRewardTables :: any, ItemRegistry.default(), currencyIds)
	end
	return cachedDefault :: Tables
end

function RewardTables.odds(tableId: string, pityState: PityState?): { OddsEntry }
	return RewardTables.default():odds(tableId, pityState)
end

function RewardTables.pityRule(tableId: string): string?
	return RewardTables.default():pityRule(tableId)
end

function RewardTables.pityStates(tableId: string): { PityState }
	return RewardTables.default():pityStates(tableId)
end

function RewardTables.nextPityState(tableId: string, pityState: PityState?, rolledRarity: string): PityState
	return RewardTables.default():nextPityState(tableId, pityState, rolledRarity)
end

function RewardTables.roll(tableId: string, pityState: PityState?, rng: any): (RewardResult, PityState)
	return RewardTables.default():roll(tableId, pityState, rng)
end

function RewardTables.get(tableId: string): TableDef?
	return RewardTables.default():get(tableId)
end

function RewardTables.all(): { TableDef }
	return RewardTables.default():all()
end

return table.freeze(RewardTables)
