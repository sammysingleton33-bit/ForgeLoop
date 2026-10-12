local fs = require("@lune/fs")

local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Types = require("@game/ReplicatedStorage/Forge/Contracts/Types")

-- interfaces.md §4 (contract v0.3), in table order
local CONTRACT_EVENTS = {
	"PlayerReady",
	"RoundStateChanged",
	"PlayerEliminated",
	"RoundEnded",
	"CurrencyChanged",
	"ItemGranted",
	"PurchaseCompleted",
	"RewardRolled",
	"OnboardingStep",
	"ShopViewed",
}

describe("Contracts/GameEvents", function()
	beforeEach(function()
		GameEvents.disconnectAll()
	end)

	it("declares exactly the §4 events, in order", function()
		expect(GameEvents.EVENT_NAMES).toEqual(CONTRACT_EVENTS)
	end)

	it("every event is a Core/Signal (one module identity across require forms)", function()
		for _, name in CONTRACT_EVENTS do
			expect(Signal.is(GameEvents[name])).toBe(true)
		end
	end)

	it("delivers payloads to subscribers", function()
		local got
		GameEvents.ShopViewed:connect(function(player, shopId, itemId)
			got = { player, shopId, itemId }
		end)
		GameEvents.ShopViewed:fire("p1", "main", nil)
		expect(got).toEqual({ "p1", "main", nil })
	end)

	it("errors on an undeclared event (typo guard) and on assignment", function()
		expect(function()
			return GameEvents.PlayerReddy
		end).toThrow("GameEvents.PlayerReddy is not a declared event")
		expect(function()
			GameEvents.NewThing = Signal.new()
		end).toThrow("GameEvents is read-only")
	end)

	it("disconnectAll() clears every event", function()
		local count = 0
		GameEvents.RoundEnded:connect(function()
			count += 1
		end)
		GameEvents.disconnectAll()
		GameEvents.RoundEnded:fire({})
		expect(count).toBe(0)
	end)

	it("documents the exactly-once rule in the module header", function()
		local source = fs.readFile(T.root .. "/roblox/src/shared/Contracts/GameEvents.luau")
		expect(source).toContain("EXACTLY-ONCE RULE")
		expect(source).toContain("never on an")
		expect(source).toContain("idempotent replay")
	end)
end)

describe("Contracts/Types", function()
	it("round states are exactly the five contract states, in order", function()
		expect(Types.ROUND_STATES).toEqual({ "Lobby", "Intermission", "Countdown", "Active", "Results" })
		expect(Types.isRoundState("Active")).toBe(true)
		expect(Types.isRoundState("active")).toBe(false)
		expect(Types.isRoundState(nil)).toBe(false)
	end)
end)
