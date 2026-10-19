--[[
	Arena/Ledger (FL-0069; CONTRACTS G12.2 LeadershipService:record, design §3): acts become moments with pre-authored
	text, ruler levels move per act and stay 0..100, valour is capped per minute, kingdom offsets are bounded, and an
	unknown act is refused rather than invented.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local Ledger = require("@game/ReplicatedStorage/Game/Arena/Ledger")

describe("Ledger.record", function()
	it("records a conduct act as a moment with the act's own text and signed delta", function()
		local ledger = Ledger.new()
		local moment, reason = Ledger.record(ledger, "crimson", 7, "fedRatioKept", 1, 30)
		expect(reason).toBe(nil)
		assert(moment, "a moment")
		expect(moment.act).toBe("fedRatioKept")
		expect(moment.component).toBe("conduct")
		expect(moment.delta).toBe(Support.acts.fedRatioKept.delta)
		expect(moment.text).toBe(Support.acts.fedRatioKept.text)
		expect(moment.t).toBe(30)
		expect(moment.userId).toBe(7)
		expect(moment.kingdom).toBe("crimson")
	end)

	it("moves that ruler's level only: starts at 50, other rulers and components are untouched", function()
		local ledger = Ledger.new()
		expect(Ledger.level(ledger, "crimson", 7, "conduct")).toBe(50)
		Ledger.record(ledger, "crimson", 7, "starvation", 1, 10)
		expect(Ledger.level(ledger, "crimson", 7, "conduct")).toBe(50 + Support.acts.starvation.delta)
		expect(Ledger.level(ledger, "crimson", 8, "conduct")).toBe(50)
		expect(Ledger.level(ledger, "azure", 7, "conduct")).toBe(50)
		expect(Ledger.level(ledger, "crimson", 7, "valour")).toBe(50)
	end)

	it("refuses an unknown act without recording anything", function()
		local ledger = Ledger.new()
		local moment, reason = Ledger.record(ledger, "crimson", 7, "burnedTheTown", 1, 10)
		expect(moment).toBe(nil)
		expect(reason).toBe("unknown_act")
		expect(#Ledger.moments(ledger, "crimson", 7, 10)).toBe(0)
	end)

	it("scales the delta by the magnitude, clamped 0..2, and treats junk as 1", function()
		local ledger = Ledger.new()
		local base = Support.acts.defendedRaid.delta
		local half = Ledger.record(ledger, "crimson", 7, "defendedRaid", 0.5, 1)
		local huge = Ledger.record(ledger, "crimson", 7, "defendedRaid", 99, 2)
		local junk = Ledger.record(ledger, "crimson", 7, "defendedRaid", 0 / 0, 3)
		assert(half and huge and junk, "moments")
		expect(half.delta).toBe(base * 0.5)
		expect(huge.delta).toBe(base * 2)
		expect(junk.delta).toBe(base)
		local none, reason = Ledger.record(ledger, "crimson", 7, "defendedRaid", 0, 4)
		expect(none).toBe(nil)
		expect(reason).toBe("no_effect")
		local negative, why = Ledger.record(ledger, "crimson", 7, "defendedRaid", -5, 5)
		expect(negative).toBe(nil)
		expect(why).toBe("no_effect") -- a negative magnitude cannot turn a good act into a bad one
	end)

	it("keeps a ruler level inside 0..100", function()
		local ledger = Ledger.new()
		for i = 1, 40 do
			Ledger.record(ledger, "crimson", 7, "starvation", 2, i)
		end
		expect(Ledger.level(ledger, "crimson", 7, "conduct")).toBe(0)
		for i = 1, 80 do
			Ledger.record(ledger, "crimson", 7, "fedRatioKept", 2, 100 + i)
		end
		expect(Ledger.level(ledger, "crimson", 7, "conduct")).toBe(100)
	end)

	it("caps valour gained per rolling minute and lets it recover after the window", function()
		local ledger = Ledger.new()
		local cap = Support.valourCapPerMinute
		local gained = 0
		local refused = 0
		for i = 1, 20 do
			local moment, reason = Ledger.record(ledger, "crimson", 7, "defendedOwnLand", 1, i)
			if moment then
				gained += moment.delta
			else
				expect(reason).toBe("capped")
				refused += 1
			end
		end
		expect(gained).toBe(cap)
		expect(refused > 0).toBe(true)
		expect(Ledger.level(ledger, "crimson", 7, "valour")).toBe(50 + cap)
		-- a minute after the first gain the room opens again
		local later = Ledger.record(ledger, "crimson", 7, "defendedOwnLand", 1, 200)
		assert(later, "valour can be gained again once the window has passed")
		expect(later.delta > 0).toBe(true)
	end)

	it("trims a valour gain that only half fits under the cap", function()
		local ledger = Ledger.new()
		local cap = Support.valourCapPerMinute
		local first = Ledger.record(ledger, "crimson", 7, "defendedOwnLand", 1, 1)
		assert(first, "first gain")
		local second = Ledger.record(ledger, "crimson", 7, "capturedInPerson", 1, 2)
		assert(second, "second gain is trimmed, not refused")
		expect(first.delta + second.delta <= cap).toBe(true)
		expect(Ledger.level(ledger, "crimson", 7, "valour")).toBe(50 + first.delta + second.delta)
	end)

	it("keeps each ruler's valour cap separate", function()
		local ledger = Ledger.new()
		for i = 1, 20 do
			Ledger.record(ledger, "crimson", 7, "defendedOwnLand", 1, i)
		end
		local other = Ledger.record(ledger, "crimson", 8, "defendedOwnLand", 1, 21)
		assert(other, "another ruler still has room")
		expect(other.delta).toBe(Support.acts.defendedOwnLand.delta)
	end)

	it("moves a kingdom act's offset, not a ruler level, and bounds it", function()
		local ledger = Ledger.new()
		for i = 1, 40 do
			Ledger.record(ledger, "crimson", nil, "keepUpgraded", 2, i)
		end
		expect(Ledger.offset(ledger, "crimson", "reputation")).toBe(Ledger.MAX_OFFSET)
		expect(Ledger.offset(ledger, "azure", "reputation")).toBe(0)
		expect(Ledger.level(ledger, "crimson", nil, "conduct")).toBe(50)
	end)
end)

describe("Ledger with its own config", function()
	it("classifies a component by the ledger's config, not the shipped one", function()
		local config = {
			components = { custom = { scope = "ruler" }, wide = { scope = "kingdom" } },
			acts = {
				x = { component = "custom", delta = 5, text = "t" },
				y = { component = "wide", delta = 5, text = "u" },
			},
			valourCapPerMinute = 6,
		}
		local ledger = Ledger.new(config)
		Ledger.record(ledger, "k", 1, "x", 1, 10)
		Ledger.record(ledger, "k", nil, "y", 1, 11)
		expect(Ledger.level(ledger, "k", 1, "custom")).toBe(55) -- a ruler level
		expect(Ledger.offset(ledger, "k", "custom")).toBe(0)
		expect(Ledger.offset(ledger, "k", "wide")).toBe(5) -- a kingdom offset
		expect(Ledger.level(ledger, "k", nil, "wide")).toBe(50)
	end)
end)

describe("Ledger.moments", function()
	it("returns newest first, at most the limit, for that kingdom only", function()
		local ledger = Ledger.new()
		Ledger.record(ledger, "crimson", 7, "fedRatioKept", 1, 10)
		Ledger.record(ledger, "azure", 9, "starvation", 1, 15)
		Ledger.record(ledger, "azure", 7, "starvation", 1, 16) -- the same user id in another kingdom
		Ledger.record(ledger, "azure", nil, "keepUpgraded", 1, 17) -- a kingdom moment elsewhere
		Ledger.record(ledger, "crimson", 7, "defendedRaid", 1, 20)
		Ledger.record(ledger, "crimson", 7, "petitionFulfilled", 1, 30)
		local top = Ledger.moments(ledger, "crimson", 7, 2)
		expect(#top).toBe(2)
		expect(top[1].act).toBe("petitionFulfilled")
		expect(top[2].act).toBe("defendedRaid")
		expect(#Ledger.moments(ledger, "crimson", 7, 99)).toBe(3)
		expect(#Ledger.moments(ledger, "crimson", 7, 0)).toBe(0)
		expect(#Ledger.moments(ledger, "azure", 9, 5)).toBe(2) -- its own and the kingdom's, not user 7's
	end)

	it("shows a ruler their own moments and the kingdom's, not a co-ruler's", function()
		local ledger = Ledger.new()
		Ledger.record(ledger, "crimson", 7, "fedRatioKept", 1, 10)
		Ledger.record(ledger, "crimson", 8, "starvation", 1, 11)
		Ledger.record(ledger, "crimson", nil, "keepUpgraded", 1, 12)
		local seven = Ledger.moments(ledger, "crimson", 7, 10)
		expect(#seven).toBe(2)
		expect(seven[1].act).toBe("keepUpgraded")
		expect(seven[2].act).toBe("fedRatioKept")
		expect(#Ledger.moments(ledger, "crimson", nil, 10)).toBe(3)
	end)

	it("is deterministic: the same acts in the same order give the same ledger", function()
		local function run()
			local ledger = Ledger.new()
			for i, act in { "fedRatioKept", "starvation", "defendedOwnLand", "defendedRaid", "keepUpgraded" } do
				Ledger.record(ledger, "crimson", 7, act, 1, i * 10)
			end
			local out = {}
			for _, moment in Ledger.moments(ledger, "crimson", 7, 99) do
				table.insert(out, `{moment.t}:{moment.act}:{moment.delta}`)
			end
			table.insert(out, tostring(Ledger.level(ledger, "crimson", 7, "conduct")))
			table.insert(out, tostring(Ledger.level(ledger, "crimson", 7, "valour")))
			return out
		end
		expect(run()).toEqual(run())
	end)
end)

describe("Ledger.moments cap", function()
	it("keeps the last moments of each kingdom: a busy kingdom does not push out a quiet one's", function()
		local ledger = Ledger.new()
		Ledger.record(ledger, "azure", 9, "fedRatioKept", 1, 1)
		Ledger.record(ledger, "azure", 9, "starvation", 1, 2)
		for i = 1, Ledger.MAX_PER_KINGDOM + 50 do
			Ledger.record(ledger, "crimson", 7, if i % 2 == 0 then "fedRatioKept" else "starvation", 1, 10 + i)
		end
		expect(#Ledger.moments(ledger, "crimson", nil, 10000)).toBe(Ledger.MAX_PER_KINGDOM)
		expect(#Ledger.moments(ledger, "azure", nil, 10000)).toBe(2)
		local newest = Ledger.moments(ledger, "crimson", nil, 1)[1]
		expect(newest.t).toBe(10 + Ledger.MAX_PER_KINGDOM + 50) -- the oldest went, not the newest
		expect(Ledger.moments(ledger, "crimson", nil, 10000)[Ledger.MAX_PER_KINGDOM].t).toBe(10 + 51)
		-- the levels are not touched by the trimming
		expect(Ledger.level(ledger, "azure", 9, "conduct")).toBe(
			50 + Support.acts.fedRatioKept.delta + Support.acts.starvation.delta
		)
	end)

	it("hands out frozen moments", function()
		local ledger = Ledger.new()
		local moment = Ledger.record(ledger, "crimson", 7, "fedRatioKept", 1, 5)
		assert(moment, "a moment")
		expect(table.isfrozen(moment)).toBe(true)
		expect(table.isfrozen(Ledger.moments(ledger, "crimson", 7, 5)[1])).toBe(true)
	end)

	it("knows which components belong to a ruler", function()
		local ledger = Ledger.new()
		expect(Ledger.isRulerComponent(ledger, "conduct")).toBe(true)
		expect(Ledger.isRulerComponent(ledger, "valour")).toBe(true)
		expect(Ledger.isRulerComponent(ledger, "reputation")).toBe(false)
		expect(Ledger.isRulerComponent(ledger, "nonsense")).toBe(false)
	end)
end)
