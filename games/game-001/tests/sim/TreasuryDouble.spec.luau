local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local TreasuryDouble = require("@game/ReplicatedStorage/Game/Sim/TreasuryDouble")
local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

describe("Kingdom/TreasuryDouble (G7 double)", function()
	it("deposits once per txId and ignores replays", function()
		local t = TreasuryDouble.new({ azure = { wood = 10 } })
		local events = {}
		t.changed:connect(function(kingdom, totals, deltas)
			table.insert(events, { kingdom, totals.wood, deltas.wood })
		end)
		expect(t:deposit("azure", "wood", 5, "dep:7:1", "citizen:woodcutter")).toBe(true)
		expect(t:deposit("azure", "wood", 5, "dep:7:1", "citizen:woodcutter")).toBe(true) -- replay
		expect(t:get("azure").wood).toBe(15)
		expect(events).toEqual({ { "azure", 15, 5 } })
		expect(t:audit("azure")).toBe(true)
	end)

	it("spends atomically, never below zero, and lets a failed txId retry later", function()
		local t = TreasuryDouble.new({ crimson = { wood = 30, stone = 5 } })
		expect(t:spend("crimson", { wood = 20, stone = 10 }, "build:1:1", "building:house")).toBe(false)
		expect(t:get("crimson")).toEqual({ food = 0, wood = 30, stone = 5, gold = 0 })
		t:deposit("crimson", "stone", 5, "dep:1:1", "citizen:miner")
		expect(t:spend("crimson", { wood = 20, stone = 10 }, "build:1:1", "building:house")).toBe(true)
		expect(t:spend("crimson", { wood = 20, stone = 10 }, "build:1:1", "building:house")).toBe(true) -- replay
		expect(t:get("crimson")).toEqual({ food = 0, wood = 10, stone = 0, gold = 0 })
		expect(t:audit("crimson")).toBe(true)
		expect(#t:ledger("crimson")).toBe(2)
	end)

	it("keeps kingdoms separate and rejects bad input loudly", function()
		local t = TreasuryDouble.new()
		t:deposit("gold", "food", 3, "a", "x")
		expect(t:get("emerald").food).toBe(0)
		expect(function()
			t:deposit("gold", "mana", 1, "b", "x")
		end).toThrow("unknown resource")
		expect(function()
			t:deposit("gold", "food", -1, "c", "x")
		end).toThrow("non-negative integer")
		expect(function()
			t:deposit("gold", "food", 0 / 0, "d", "x")
		end).toThrow("non-negative integer")
		expect(function()
			t:spend("gold", { food = 1 }, "", "x")
		end).toThrow("txId")
	end)

	it("detects a balance changed outside the ledger", function()
		local t = TreasuryDouble.new({ gold = { food = 1 } });
		(t :: any)._bags.gold.food = 2
		expect(t:audit("gold")).toBe(false)
	end)
end)

describe("Kingdom/Types (G2)", function()
	it("lists exactly the contract ids", function()
		expect(Types.KINGDOM_IDS).toEqual({ "crimson", "azure", "emerald", "gold" })
		expect(Types.JOB_IDS).toEqual({
			"idle",
			"farmer",
			"woodcutter",
			"miner",
			"builder",
			"hauler",
			"soldier",
			"archer",
			"knight",
			"ram",
		})
		expect(#Types.BUILDING_TYPES).toBe(10)
		expect(Types.MATCH_PHASES[1]).toBe("Lobby")
		expect(Types.MATCH_PHASES[6]).toBe("Results")
		expect(Types.is("KINGDOM_IDS", "azure")).toBe(true)
		expect(Types.is("KINGDOM_IDS", "k1")).toBe(false)
		expect(Types.is("JOB_IDS", 3)).toBe(false)
		expect(function()
			Types.is("NOPE", "x")
		end).toThrow("unknown list")
	end)
end)
