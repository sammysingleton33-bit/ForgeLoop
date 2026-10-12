--!strict
--[[
	Economy/ItemRegistry — validated item definitions (games/<game>/config/Items.luau; interfaces §7).
	Shared: the server grants by these definitions and the UI shows them.

	API
		ItemRegistry.RARITIES: { string }    -- "Common", "Uncommon", "Rare", "Epic", "Legendary" (rank order)
		ItemRegistry.KINDS: { string }       -- "building", "unit", "cosmetic"
		ItemRegistry.MAX_ID_BYTES: number    -- 32
		ItemRegistry.rarityRank(rarity: any): number?  -- 1 (Common) .. 5 (Legendary); nil if not a rarity
		ItemRegistry.isValidId(value: any): boolean    -- string, ^[a-z][a-z0-9_]*$, at most 32 bytes
		ItemRegistry.validate(defs: any): (boolean, { string })  -- every problem, each naming the item and field
		ItemRegistry.new(defs: { ItemDef }): Registry            -- errors listing every problem
		ItemRegistry.setDefault(defsOrRegistry)                  -- the game's registry (e.g. its Config.Items)
		ItemRegistry.default(): Registry                         -- errors until setDefault was called
		registry:get(id: string): ItemDef?
		registry:require(id: string): ItemDef                    -- errors on an unknown id
		registry:all(): { ItemDef }                              -- config order
		registry:ofKind(kind: string): { ItemDef }               -- config order; errors on an unknown kind

	Rules (common fields only)
		id           string matching ^[a-z][a-z0-9_]*$, at most 32 bytes, unique
		kind         one of KINDS
		name, description, icon   non-empty strings
		rarity       one of RARITIES
		maxStack     nil or an integer >= 1 (Inventory uses 1 when nil)
		equipSlot    nil, or a non-empty string on a cosmetic
		building     a table when kind = "building", absent otherwise
		unit         a table when kind = "unit", absent otherwise
		Any other top-level field is rejected (typo guard). The contents of `building` and `unit` are
		validated by the game that uses them, not here.

	Returned definitions and lists are deep-frozen copies made at construction: the config tables are
	never mutated, and `building` / `unit` keep their contents unchanged.
]]

-- Framework code never requires game config (it differs per game and may be absent): the game
-- registers its items once with ItemRegistry.setDefault(require(<its Config/Items>)).

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type Kind = "building" | "unit" | "cosmetic"
export type ItemDef = {
	id: string,
	kind: Kind,
	name: string,
	description: string,
	icon: string,
	rarity: Rarity,
	maxStack: number?,
	equipSlot: string?,
	building: { [any]: any }?,
	unit: { [any]: any }?,
}

local ItemRegistry = {}

local RARITIES: { string } = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local KINDS: { string } = { "building", "unit", "cosmetic" }
ItemRegistry.RARITIES = table.freeze(RARITIES)
ItemRegistry.KINDS = table.freeze(KINDS)
ItemRegistry.MAX_ID_BYTES = 32

local RARITY_RANK: { [string]: number } = {}
for rank, rarity in RARITIES do
	RARITY_RANK[rarity] = rank
end

local KIND_SET: { [string]: boolean } = {}
for _, kind in KINDS do
	KIND_SET[kind] = true
end

local FIELDS: { [string]: boolean } = {
	id = true,
	kind = true,
	name = true,
	description = true,
	icon = true,
	rarity = true,
	maxStack = true,
	equipSlot = true,
	building = true,
	unit = true,
}

local Registry = {}
Registry.__index = Registry

type RegistryData = {
	_list: { ItemDef },
	_byId: { [string]: ItemDef },
	_byKind: { [string]: { ItemDef } },
}
export type Registry = typeof(setmetatable({} :: RegistryData, Registry))

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

local function isNonEmptyString(value: any): boolean
	return type(value) == "string" and #value > 0
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

function ItemRegistry.rarityRank(rarity: any): number?
	if type(rarity) ~= "string" then
		return nil
	end
	return RARITY_RANK[rarity]
end

function ItemRegistry.isValidId(value: any): boolean
	return type(value) == "string"
		and #value <= ItemRegistry.MAX_ID_BYTES
		and string.match(value, "^[a-z][a-z0-9_]*$") ~= nil
end

local function validateDef(def: any, label: string, add: (string) -> ())
	local function problem(field: string, message: string)
		add(`{label}: {field} {message}`)
	end

	local unknown = {}
	for key in def do
		if type(key) ~= "string" or not FIELDS[key] then
			table.insert(unknown, show(key))
		end
	end
	table.sort(unknown)
	for _, key in unknown do
		add(`{label}: unknown field {key}`)
	end

	if not ItemRegistry.isValidId(def.id) then
		problem("id", `must be a string matching ^[a-z][a-z0-9_]*$ of at most 32 bytes (got {show(def.id)})`)
	end
	if type(def.kind) ~= "string" or not KIND_SET[def.kind] then
		problem("kind", `must be one of {table.concat(KINDS, ", ")} (got {show(def.kind)})`)
	end
	for _, field in { "name", "description", "icon" } do
		if not isNonEmptyString(def[field]) then
			problem(field, `must be a non-empty string (got {show(def[field])})`)
		end
	end
	if ItemRegistry.rarityRank(def.rarity) == nil then
		problem("rarity", `must be one of {table.concat(RARITIES, ", ")} (got {show(def.rarity)})`)
	end
	if def.maxStack ~= nil and not (isInteger(def.maxStack) and def.maxStack >= 1) then
		problem("maxStack", `must be nil or an integer >= 1 (got {show(def.maxStack)})`)
	end
	if def.equipSlot ~= nil then
		if def.kind ~= "cosmetic" then
			problem("equipSlot", `is only allowed on cosmetic items (kind is {show(def.kind)})`)
		elseif not isNonEmptyString(def.equipSlot) then
			problem("equipSlot", `must be a non-empty string (got {show(def.equipSlot)})`)
		end
	end
	for _, sub in { "building", "unit" } do
		if def.kind == sub then
			if type(def[sub]) ~= "table" then
				problem(sub, `must be a table when kind is "{sub}" (got {show(def[sub])})`)
			end
		elseif def[sub] ~= nil then
			problem(sub, `is only allowed when kind is "{sub}" (kind is {show(def.kind)})`)
		end
	end
end

function ItemRegistry.validate(defs: any): (boolean, { string })
	local problems: { string } = {}
	local function add(message: string)
		table.insert(problems, message)
	end
	if type(defs) ~= "table" then
		add(`items: must be a list of item definitions (got {typeof(defs)})`)
		return false, problems
	end
	if not isList(defs) then
		add("items: must be a list (keys 1..n with no gaps or other keys)")
	end
	local firstIndex: { [string]: number } = {}
	for index = 1, #defs do
		local def = defs[index]
		local label = `item {index}`
		if type(def) ~= "table" then
			add(`{label}: must be a table (got {typeof(def)})`)
			continue
		end
		if type(def.id) == "string" then
			label ..= ` ({show(def.id)})`
			local first = firstIndex[def.id]
			if first ~= nil then
				add(`{label}: id duplicates item {first}`)
			else
				firstIndex[def.id] = index
			end
		end
		validateDef(def, label, add)
	end
	return #problems == 0, problems
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

function ItemRegistry.new(defs: { ItemDef }): Registry
	local ok, problems = ItemRegistry.validate(defs)
	if not ok then
		error(`ItemRegistry: invalid item definitions ({#problems}):\n  {table.concat(problems, "\n  ")}`, 2)
	end
	local list: { ItemDef } = {}
	local byId: { [string]: ItemDef } = {}
	local byKind: { [string]: { ItemDef } } = {}
	for _, kind in KINDS do
		byKind[kind] = {}
	end
	local memo = {}
	for index = 1, #defs do
		local def: ItemDef = frozenCopy(defs[index], memo)
		table.insert(list, def)
		byId[def.id] = def
		table.insert(byKind[def.kind], def)
	end
	for _, kind in KINDS do
		table.freeze(byKind[kind])
	end
	local self = setmetatable({
		_list = table.freeze(list),
		_byId = table.freeze(byId),
		_byKind = table.freeze(byKind),
	}, Registry)
	return table.freeze(self) :: any
end

function Registry.get(self: Registry, id: string): ItemDef?
	if type(id) ~= "string" then
		return nil
	end
	return self._byId[id]
end

function Registry.require(self: Registry, id: string): ItemDef
	local def = self:get(id)
	if def == nil then
		error(`ItemRegistry: unknown item id {show(id)}`, 2)
	end
	return def
end

function Registry.all(self: Registry): { ItemDef }
	return self._list
end

function Registry.ofKind(self: Registry, kind: string): { ItemDef }
	local list = if type(kind) == "string" then self._byKind[kind] else nil
	if list == nil then
		error(`ItemRegistry: unknown kind {show(kind)} (expected one of {table.concat(KINDS, ", ")})`, 2)
	end
	return list
end

local cachedDefault: Registry? = nil

function ItemRegistry.setDefault(defsOrRegistry: any): Registry
	if type(defsOrRegistry) == "table" and getmetatable(defsOrRegistry) ~= nil then
		cachedDefault = defsOrRegistry
	else
		cachedDefault = ItemRegistry.new(defsOrRegistry)
	end
	return cachedDefault :: Registry
end

function ItemRegistry.default(): Registry
	if cachedDefault == nil then
		error("ItemRegistry.default: call ItemRegistry.setDefault(<the game's Config.Items>) first", 2)
	end
	return cachedDefault :: Registry
end

return table.freeze(ItemRegistry)
