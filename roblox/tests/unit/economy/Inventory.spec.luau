local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local Inventory = require("@game/ReplicatedStorage/Forge/Economy/Inventory")
local ItemRegistry = require("@game/ReplicatedStorage/Forge/Economy/ItemRegistry")

local function def(id: string, kind: string, extra: { [string]: any }?)
	local d: { [string]: any } = { id = id, kind = kind, name = id, description = "d", icon = "i", rarity = "Common" }
	for key, value in extra or {} do
		d[key] = value
	end
	return d
end

local registry = ItemRegistry.new({
	def("hat", "cosmetic", { equipSlot = "head" }), -- cap 1 (maxStack nil)
	def("crown", "cosmetic", { equipSlot = "head", maxStack = 3 }),
	def("cape", "cosmetic", { equipSlot = "back" }),
	def("gem", "cosmetic", { maxStack = 5 }), -- not equippable
	def("hut", "building", { building = {} }),
	def("spear", "unit", { unit = {} }),
})

describe("Economy/Inventory", function()
	local inv
	beforeEach(function()
		inv = Inventory.new(registry)
	end)

	describe("new", function()
		it("creates empty defaults when data is nil", function()
			expect(inv.data).toEqual({ stacks = {}, equipped = {} })
			expect(inv:count("gem")).toBe(0)
		end)

		it("keeps a reference to the data table and fills in missing parts inside it", function()
			local data: any = { stacks = { gem = 2 } }
			local own = Inventory.new(registry, data)
			expect(own.data).toBe(data)
			expect(data.equipped).toEqual({})
			expect(own:count("gem")).toBe(2)
			expect(own:add("gem", 1)).toBe(true)
			expect(data.stacks.gem).toBe(3)
		end)

		it("rejects data of the wrong shape and a missing registry", function()
			expect(function()
				Inventory.new(registry, { stacks = 5 } :: any)
			end).toThrow("data.stacks must be a table")
			expect(function()
				Inventory.new(registry, { stacks = {}, equipped = "hat" } :: any)
			end).toThrow("data.equipped must be a table")
			expect(function()
				Inventory.new(registry, "data" :: any)
			end).toThrow("data must be a table or nil")
			expect(function()
				Inventory.new(nil :: any)
			end).toThrow("registry must be an ItemRegistry")
		end)
	end)

	describe("add / canAdd", function()
		it("adds up to the default cap of 1 when maxStack is nil", function()
			expect({ inv:add("hat", 1) }).toEqual({ true })
			expect(inv:count("hat")).toBe(1)
			expect({ inv:canAdd("hat", 1) }).toEqual({ false, "stack_full" })
			expect({ inv:add("hat", 1) }).toEqual({ false, "stack_full" })
			expect(inv:count("hat")).toBe(1)
		end)

		it("is all-or-nothing against maxStack", function()
			expect({ inv:add("gem", 3) }).toEqual({ true })
			expect({ inv:add("gem", 3) }).toEqual({ false, "stack_full" })
			expect(inv:count("gem")).toBe(3) -- nothing partially added
			expect({ inv:add("gem", 2) }).toEqual({ true })
			expect(inv:count("gem")).toBe(5)
			expect({ inv:add("gem", 6) }).toEqual({ false, "stack_full" })
		end)

		it("rejects unknown items and buildings/units", function()
			expect({ inv:add("nope", 1) }).toEqual({ false, "unknown_item" })
			expect({ inv:add(nil :: any, 1) }).toEqual({ false, "unknown_item" })
			expect({ inv:add("hut", 1) }).toEqual({ false, "not_storable" })
			expect({ inv:add("spear", 1) }).toEqual({ false, "not_storable" })
			expect(inv.data.stacks).toEqual({})
		end)

		it("rejects quantities that are not integers >= 1", function()
			for _, qty in { 0, -1, 1.5, 0 / 0, math.huge, "2" } do
				expect({ inv:add("gem", qty :: any) }).toEqual({ false, "invalid_qty" })
			end
			expect({ inv:add("gem", nil :: any) }).toEqual({ false, "invalid_qty" })
			expect(inv.data.stacks).toEqual({})
		end)

		it("checks in the documented order: unknown_item, not_storable, invalid_qty, stack_full", function()
			expect({ inv:canAdd("nope", 0) }).toEqual({ false, "unknown_item" })
			expect({ inv:canAdd("hut", 0) }).toEqual({ false, "not_storable" })
			expect({ inv:canAdd("gem", 99.5) }).toEqual({ false, "invalid_qty" })
		end)

		it("canAdd never changes the data", function()
			expect({ inv:canAdd("gem", 5) }).toEqual({ true })
			expect(inv.data.stacks).toEqual({})
		end)
	end)

	describe("remove", function()
		it("removes and deletes a stack that reaches 0", function()
			inv:add("gem", 4)
			expect({ inv:remove("gem", 3) }).toEqual({ true })
			expect(inv:count("gem")).toBe(1)
			expect({ inv:remove("gem", 1) }).toEqual({ true })
			expect(inv:count("gem")).toBe(0)
			expect(inv.data.stacks.gem).toBeNil()
		end)

		it("never goes below 0: insufficient removes nothing", function()
			inv:add("gem", 2)
			expect({ inv:remove("gem", 3) }).toEqual({ false, "insufficient" })
			expect(inv:count("gem")).toBe(2)
			expect({ inv:remove("cape", 1) }).toEqual({ false, "insufficient" })
		end)

		it("rejects unknown items, buildings/units and bad quantities", function()
			inv:add("gem", 2)
			expect({ inv:remove("nope", 1) }).toEqual({ false, "unknown_item" })
			expect({ inv:remove("hut", 1) }).toEqual({ false, "not_storable" })
			expect({ inv:remove("gem", 0) }).toEqual({ false, "invalid_qty" })
			expect({ inv:remove("gem", 1.5) }).toEqual({ false, "invalid_qty" })
			expect(inv:count("gem")).toBe(2)
		end)
	end)

	describe("equip / unequip", function()
		it("equips an owned item into its slot", function()
			inv:add("hat", 1)
			expect({ inv:equip("hat") }).toEqual({ true })
			expect(inv:equipped("head")).toBe("hat")
			expect(inv.data.equipped).toEqual({ head = "hat" })
		end)

		it("requires owning at least one", function()
			expect({ inv:equip("cape") }).toEqual({ false, "not_owned" })
			expect(inv:equipped("back")).toBeNil()
		end)

		it("rejects items without an equipSlot and unknown items", function()
			inv:add("gem", 1)
			expect({ inv:equip("gem") }).toEqual({ false, "not_equippable" })
			expect({ inv:equip("hut") }).toEqual({ false, "not_equippable" })
			expect({ inv:equip("nope") }).toEqual({ false, "unknown_item" })
			expect(inv.data.equipped).toEqual({})
		end)

		it("replaces whatever the slot held and leaves other slots alone", function()
			inv:add("hat", 1)
			inv:add("crown", 1)
			inv:add("cape", 1)
			inv:equip("hat")
			inv:equip("cape")
			expect({ inv:equip("crown") }).toEqual({ true })
			expect(inv:equipped("head")).toBe("crown")
			expect(inv:equipped("back")).toBe("cape")
			expect(inv:count("hat")).toBe(1) -- replacing does not remove the old item
		end)

		it("unequip empties the slot once, then reports not_equipped", function()
			inv:add("cape", 1)
			inv:equip("cape")
			expect({ inv:unequip("back") }).toEqual({ true })
			expect(inv:equipped("back")).toBeNil()
			expect({ inv:unequip("back") }).toEqual({ false, "not_equipped" })
			expect({ inv:unequip(nil :: any) }).toEqual({ false, "not_equipped" })
			expect(inv:count("cape")).toBe(1)
		end)

		it("removing the last copy unequips it; removing a non-last copy does not", function()
			inv:add("crown", 2)
			inv:add("cape", 1)
			inv:equip("crown")
			inv:equip("cape")
			inv:remove("crown", 1)
			expect(inv:equipped("head")).toBe("crown")
			inv:remove("crown", 1)
			expect(inv:equipped("head")).toBeNil()
			expect(inv:equipped("back")).toBe("cape")
			expect(inv.data.equipped).toEqual({ back = "cape" })
		end)
	end)

	describe("with the sandbox registry (Config.Items) plus a building and a unit", function()
		it("stores cosmetics and refuses buildings and units", function()
			local defs = table.clone(require("@game/ReplicatedStorage/Forge/Config/Items"))
			table.insert(defs, {
				id = "keep",
				kind = "building",
				name = "Keep",
				description = "d",
				icon = "kingdom",
				rarity = "Common",
				building = {},
			})
			table.insert(defs, {
				id = "militia",
				kind = "unit",
				name = "Militia",
				description = "d",
				icon = "militia",
				rarity = "Common",
				unit = {},
			})
			local own = Inventory.new(ItemRegistry.setDefault(defs))
			expect({ own:add("banner_oak", 1) }).toEqual({ true })
			expect({ own:add("banner_oak", 1) }).toEqual({ false, "stack_full" })
			expect({ own:equip("banner_oak") }).toEqual({ true })
			expect(own:equipped("banner")).toBe("banner_oak")
			expect({ own:add("keep", 1) }).toEqual({ false, "not_storable" })
			expect({ own:add("militia", 1) }).toEqual({ false, "not_storable" })
		end)
	end)
end)
