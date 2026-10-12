--!strict
--[[
	Economy/Inventory — item stacks, stack caps and equip slots over a plain data table that lives in
	the `economy` profile namespace (interfaces §5). Pure logic: no services, no txIds, no events —
	InventoryService (server) owns persistence, idempotency and ItemGranted.

	Data (kept by reference: every change is written into the table passed to new)
		{ stacks = { [itemId]: integer }, equipped = { [slot]: itemId } }
		A stack that reaches 0 is removed (stacks[itemId] = nil).

	API
		Inventory.new(registry: ItemRegistry.Registry, data: Data?): Inventory
			-- data nil: a new { stacks = {}, equipped = {} }; a missing stacks/equipped table is
			-- created inside data. Errors if stacks/equipped is present but not a table.
		inv.data: Data
		inv:count(itemId: string): number
		inv:canAdd(itemId: string, qty: number): (boolean, Reason?)
		inv:add(itemId: string, qty: number): (boolean, Reason?)      -- all-or-nothing
		inv:remove(itemId: string, qty: number): (boolean, Reason?)   -- never below 0; the last copy unequips
		inv:equip(itemId: string): (boolean, Reason?)                 -- replaces whatever the slot held
		inv:unequip(slot: string): (boolean, Reason?)
		inv:equipped(slot: string): string?

	Reasons (stable lowercase strings; the UI maps them to text). Checks run in this order:
		add/canAdd   "unknown_item", "not_storable", "invalid_qty", "stack_full"
		remove       "unknown_item", "not_storable", "invalid_qty", "insufficient"
		equip        "unknown_item", "not_equippable", "not_owned"
		unequip      "not_equipped"
	  unknown_item    the id is not in the registry
	  not_storable    buildings and units are built or trained in a match, never stored
	  invalid_qty     qty is not an integer >= 1
	  stack_full      count + qty would exceed the cap (def.maxStack, or 1 when nil); nothing is added
	  insufficient    fewer than qty owned; nothing is removed
	  not_equippable  the item has no equipSlot
	  not_owned       the player owns none
	  not_equipped    the slot is empty
]]

local ItemRegistry = require("./ItemRegistry")

export type Data = {
	stacks: { [string]: number },
	equipped: { [string]: string },
}
export type Reason =
	"unknown_item"
	| "not_storable"
	| "invalid_qty"
	| "stack_full"
	| "insufficient"
	| "not_equippable"
	| "not_owned"
	| "not_equipped"

local STORABLE_KINDS: { [string]: boolean } = { cosmetic = true }

local Inventory = {}

local InventoryClass = {}
InventoryClass.__index = InventoryClass

type InventoryData = {
	data: Data,
	_registry: ItemRegistry.Registry,
}
export type Inventory = typeof(setmetatable({} :: InventoryData, InventoryClass))

local function isPositiveInteger(value: any): boolean
	return type(value) == "number" and value >= 1 and value % 1 == 0 and value ~= math.huge
end

function Inventory.new(registry: ItemRegistry.Registry, data: Data?): Inventory
	if type(registry) ~= "table" or type((registry :: any).get) ~= "function" then
		error("Inventory.new: registry must be an ItemRegistry (ItemRegistry.new or ItemRegistry.default())", 2)
	end
	local store: any = data
	if store == nil then
		store = {}
	elseif type(store) ~= "table" then
		error(`Inventory.new: data must be a table or nil (got {typeof(store)})`, 2)
	end
	for _, field in { "stacks", "equipped" } do
		if store[field] == nil then
			store[field] = {}
		elseif type(store[field]) ~= "table" then
			error(`Inventory.new: data.{field} must be a table (got {typeof(store[field])})`, 2)
		end
	end
	return setmetatable({ data = store :: Data, _registry = registry }, InventoryClass)
end

function InventoryClass.count(self: Inventory, itemId: string): number
	local n = self.data.stacks[itemId]
	if type(n) == "number" then
		return n
	end
	return 0
end

function InventoryClass.canAdd(self: Inventory, itemId: string, qty: number): (boolean, Reason?)
	local def = self._registry:get(itemId)
	if def == nil then
		return false, "unknown_item"
	end
	if not STORABLE_KINDS[def.kind] then
		return false, "not_storable"
	end
	if not isPositiveInteger(qty) then
		return false, "invalid_qty"
	end
	if self:count(itemId) + qty > (def.maxStack or 1) then
		return false, "stack_full"
	end
	return true, nil
end

function InventoryClass.add(self: Inventory, itemId: string, qty: number): (boolean, Reason?)
	local ok, reason = self:canAdd(itemId, qty)
	if not ok then
		return false, reason
	end
	self.data.stacks[itemId] = self:count(itemId) + qty
	return true, nil
end

function InventoryClass.remove(self: Inventory, itemId: string, qty: number): (boolean, Reason?)
	local def = self._registry:get(itemId)
	if def == nil then
		return false, "unknown_item"
	end
	if not STORABLE_KINDS[def.kind] then
		return false, "not_storable"
	end
	if not isPositiveInteger(qty) then
		return false, "invalid_qty"
	end
	local have = self:count(itemId)
	if have < qty then
		return false, "insufficient"
	end
	local left = have - qty
	if left > 0 then
		self.data.stacks[itemId] = left
	else
		self.data.stacks[itemId] = nil
		local equipped = self.data.equipped
		for slot, equippedId in equipped do
			if equippedId == itemId then
				equipped[slot] = nil
			end
		end
	end
	return true, nil
end

function InventoryClass.equip(self: Inventory, itemId: string): (boolean, Reason?)
	local def = self._registry:get(itemId)
	if def == nil then
		return false, "unknown_item"
	end
	local slot = def.equipSlot
	if slot == nil then
		return false, "not_equippable"
	end
	if self:count(itemId) < 1 then
		return false, "not_owned"
	end
	self.data.equipped[slot] = itemId
	return true, nil
end

function InventoryClass.unequip(self: Inventory, slot: string): (boolean, Reason?)
	if type(slot) ~= "string" or self.data.equipped[slot] == nil then
		return false, "not_equipped"
	end
	self.data.equipped[slot] = nil
	return true, nil
end

function InventoryClass.equipped(self: Inventory, slot: string): string?
	if type(slot) ~= "string" then
		return nil
	end
	local itemId = self.data.equipped[slot]
	if type(itemId) == "string" then
		return itemId
	end
	return nil
end

return table.freeze(Inventory)
