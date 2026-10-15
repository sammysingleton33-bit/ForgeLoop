--[[
	Sim/Consequences (FL-0082; living-kingdom §5): the pure checks behind ConsequenceService — the sustained
	wait no single moment can satisfy, the aggrieved test, effective stability, the instigator, morale.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Consequences = require("@game/ReplicatedStorage/Game/Sim/Consequences")
local Society = require("@game/ReplicatedStorage/Forge/Config/Society")

local STRIKE = { loyaltyBelow = 30, obedienceBelow = 30, memoryTags = { "exploited", "pay_refused" } }

describe("Consequences.sustained: the condition must hold without a break", function()
	it("is false until `seconds` have passed since it started holding, then true", function()
		local tracker = Consequences.tracker()
		expect(Consequences.sustained(tracker, "riot", true, 100, 60)).toBe(false) -- starts the wait
		expect(Consequences.sustained(tracker, "riot", true, 159.9, 60)).toBe(false)
		expect(Consequences.sustained(tracker, "riot", true, 160, 60)).toBe(true) -- exactly the wait
		expect(Consequences.sustained(tracker, "riot", true, 500, 60)).toBe(true)
	end)

	it("a single moment never counts, and any break starts the wait over", function()
		local tracker = Consequences.tracker()
		expect(Consequences.sustained(tracker, "k", true, 0, 60)).toBe(false)
		expect(Consequences.sustained(tracker, "k", false, 59, 60)).toBe(false) -- the break
		expect(Consequences.sustained(tracker, "k", true, 60, 60)).toBe(false) -- waits again from 60
		expect(Consequences.sustained(tracker, "k", true, 119, 60)).toBe(false)
		expect(Consequences.sustained(tracker, "k", true, 120, 60)).toBe(true)
		-- zero seconds still needs the condition at the check itself
		expect(Consequences.sustained(Consequences.tracker(), "z", false, 5, 0)).toBe(false)
		expect(Consequences.sustained(Consequences.tracker(), "z", true, 5, 0)).toBe(true)
	end)

	it("keys are independent; forget starts one key's wait over", function()
		local tracker = Consequences.tracker()
		Consequences.sustained(tracker, "a", true, 0, 10)
		Consequences.sustained(tracker, "b", true, 0, 10)
		Consequences.forget(tracker, "a")
		expect(Consequences.sustained(tracker, "a", true, 10, 10)).toBe(false)
		expect(Consequences.sustained(tracker, "b", true, 10, 10)).toBe(true)
		expect(Consequences.sustained(tracker, "a", true, 20, 10)).toBe(true)
	end)
end)

describe("Consequences.aggrieved", function()
	it("needs low loyalty, low obedience and a grievance memory, all three", function()
		local c = { id = 1, loyalty = 10, pinned = { pay_refused = true } }
		expect(Consequences.aggrieved(c, 10, STRIKE)).toBe(true)
		expect(Consequences.aggrieved({ id = 1, loyalty = 30, pinned = c.pinned }, 10, STRIKE)).toBe(false)
		expect(Consequences.aggrieved(c, 30, STRIKE)).toBe(false) -- obedient enough
		expect(Consequences.aggrieved({ id = 1, loyalty = 10 }, 10, STRIKE)).toBe(false) -- no memories
		expect(Consequences.aggrieved({ id = 1, loyalty = 10, pinned = { pardoned = true } }, 10, STRIKE)).toBe(false)
		expect(Consequences.aggrieved({ id = 1, loyalty = 10, pinned = { exploited = true } }, 10, STRIKE)).toBe(true)
		expect(Consequences.aggrieved({ id = 1, pinned = c.pinned }, 10, STRIKE)).toBe(false) -- nil loyalty = 50
	end)

	it("every shipped strike memory tag is pinned by a content decision, except the reserved one", function()
		local Decisions = require("@game/ReplicatedStorage/Game/Content/Decisions")
		local pinned = {}
		for _, row in Decisions do
			if type(row) == "table" and row.memory_tag and row.memory_tag ~= "" then
				pinned[row.memory_tag] = true
			end
		end
		for _, tag in Society.strike.memoryTags do
			if tag ~= "exploited" then
				expect(pinned[tag] == true and tag or `{tag} (never pinned)`).toBe(tag)
			end
		end
	end)
end)

describe("Consequences: stability, instigator, rioters, morale", function()
	it("effective stability is stability minus the unrest pressure", function()
		expect(Consequences.effectiveStability({ conditions = { stability = 40 } })).toBe(40)
		expect(Consequences.effectiveStability({ conditions = { stability = 40 }, unrestPressure = 15 })).toBe(25)
		expect(Consequences.effectiveStability({ unrestPressure = 5 })).toBe(-5) -- no conditions yet
	end)

	it("the instigator is the least loyal citizen below the bar (ties: the lowest id), else nil", function()
		local citizens = { { id = 7, loyalty = 20 }, { id = 3, loyalty = 12 }, { id = 9, loyalty = 12 }, { id = 2 } }
		expect(Consequences.instigator(citizens, 25).id).toBe(3)
		expect(Consequences.instigator(citizens, 12)).toBeNil() -- strictly below
		expect(Consequences.instigator({}, 25)).toBeNil()
		expect(Consequences.instigator({ { id = 4 } }, 51).id).toBe(4) -- nil loyalty counts as 50
	end)

	it("leastLoyal returns at most `count`, least loyal first, without touching the input", function()
		local citizens = { { id = 5, loyalty = 30 }, { id = 1, loyalty = 30 }, { id = 2, loyalty = 5 } }
		local ids = Consequences.ids(Consequences.leastLoyal(citizens, 2))
		expect(ids).toEqual({ 2, 1 })
		expect(Consequences.ids(Consequences.leastLoyal(citizens, 10))).toEqual({ 2, 1, 5 })
		expect(Consequences.leastLoyal(citizens, 0)).toEqual({})
		expect(Consequences.ids(citizens)).toEqual({ 5, 1, 2 })
	end)

	it("morale: steady at or above retreatBelow, retreat below it, surrender below surrenderBelow", function()
		local cfg = { retreatBelow = 30, surrenderBelow = 15 }
		expect(Consequences.moraleState(30, cfg)).toBe("steady")
		expect(Consequences.moraleState(29.9, cfg)).toBe("retreat")
		expect(Consequences.moraleState(15, cfg)).toBe("retreat")
		expect(Consequences.moraleState(14, cfg)).toBe("surrender")
		expect(Consequences.moraleState(0, cfg)).toBe("surrender")
	end)

	it("the shipped thresholds end above where they start, so a rule cannot flicker", function()
		local c = Society.consequences
		expect(c.shortage.endFedAbove > c.shortage.fedBelow).toBe(true)
		expect(c.riot.endStabilityAbove > c.riot.stabilityBelow).toBe(true)
		expect(Society.strike.endLoyaltyAbove >= Society.strike.loyaltyBelow).toBe(true)
		expect(c.rebellion.enabled).toBe(false) -- gated off in the VS-1 slice
		expect(c.morale.surrenderBelow < c.morale.retreatBelow).toBe(true)
		for _, rule in { c.shortage, c.riot, c.rebellion } do
			expect(rule.sustainSeconds > c.tick).toBe(true) -- more than one check: never one moment
		end
	end)
end)
