--[[
	Kingdom/Types (CONTRACTS G2, v0.4-g3): the id lists every worker validates and encodes against.
	Their order is part of the contract (wire encodings use the index), so it is pinned here.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Types = require("@game/ReplicatedStorage/Game/Kingdom/Types")

describe("Kingdom/Types (G2)", function()
	it("lists every G2 id in contract order", function()
		expect(Types.KINGDOM_IDS).toEqual({ "crimson", "azure", "emerald", "gold" })
		expect(Types.RESOURCE_IDS).toEqual({ "food", "wood", "stone", "gold" })
		expect(Types.ENTITY_KINDS).toEqual({ "citizen", "soldier", "governor" })
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
		expect(Types.BUILDING_TYPES).toEqual({
			"keep",
			"house",
			"farm",
			"storehouse",
			"lumbercamp",
			"quarry",
			"barracks",
			"watchtower",
			"wall",
			"gate",
		})
		expect(Types.MATCH_PHASES).toEqual({ "Lobby", "Founding", "Expansion", "Conflict", "Endgame", "Results" })
		expect(Types.BUILDING_STATES).toEqual({ "planned", "constructing", "complete", "damaged", "destroyed" })
	end)

	it("is() accepts members and rejects everything else", function()
		expect(Types.is("KINGDOM_IDS", "azure")).toBe(true)
		expect(Types.is("KINGDOM_IDS", "Azure")).toBe(false) -- ids are case-sensitive
		expect(Types.is("KINGDOM_IDS", "k1")).toBe(false)
		expect(Types.is("RESOURCE_IDS", "iron")).toBe(false) -- VS-2, additive later
		expect(Types.is("JOB_IDS", 1)).toBe(false)
		expect(Types.is("MATCH_PHASES", nil)).toBe(false)
		expect(function()
			Types.is("NOPE", "x")
		end).toThrow("unknown list")
	end)

	it("is frozen, lists included, so no caller can change the contract at runtime", function()
		expect(table.isfrozen(Types)).toBe(true)
		for _, name in { "KINGDOM_IDS", "RESOURCE_IDS", "ENTITY_KINDS", "JOB_IDS", "BUILDING_TYPES", "MATCH_PHASES" } do
			expect(table.isfrozen((Types :: any)[name])).toBe(true)
		end
		expect(function()
			table.insert(Types.KINGDOM_IDS :: any, "violet")
		end).toThrow()
	end)
end)
