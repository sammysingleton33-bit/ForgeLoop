--[[
	Arena/Caps (FL-0070, CONTRACTS G12.3): the fairness caps at their limits. FORGE-05's tests/fairness/Caps.spec checks
	this file against its own reference on every design set; this spec pins each cap's edge from the inside.
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Caps = require("@game/ReplicatedStorage/Game/Arena/Caps")

local function passive(stat: string, magnitude: number, slot: boolean?, source: string?)
	return { source = source or `passive:{stat}`, kind = "passive", stat = stat, magnitude = magnitude, slot = slot }
end

local function trigger(source: string, stat: string, magnitude: number, duration: number?)
	return {
		source = source,
		kind = "trigger",
		stat = stat,
		magnitude = magnitude,
		duration = duration or 6,
		condition = "staminaOut",
	}
end

local function refused(modifiers: any, fragment: string)
	local ok, reason = Caps.check(modifiers)
	expect(ok).toBe(false)
	expect(string.find(reason :: string, fragment, 1, true)).never.toBeNil()
end

describe("Arena/Caps: what is allowed", function()
	it("accepts no support at all, and sets exactly at the limits", function()
		expect(Caps.check({})).toBe(true)
		expect((Caps.check({ passive("damage", 0.05), passive("damageReduction", 0.03) }))).toBe(true) -- 5 % a stat, 8 % combined
		expect(
			(
				Caps.check({
					passive("damage", 0.05),
					trigger("perk:a", "damage", 0.10, 8), -- 15 % total on damage, 8 s
					trigger("perk:b", "staminaRegen", 0.10),
					{ source = "perk:c", kind = "heal", magnitude = 0.08, duration = 6, condition = "hpBelow:0.5" },
				})
			)
		).toBe(true)
		local ok, reason = Caps.check({})
		expect(reason).toBeNil()
		expect(ok).toBe(true)
	end)

	it("one trigger with two effects (Crowd Rally) takes one slot", function()
		local rally = {
			trigger("crowdRally", "damageReduction", 0.06),
			trigger("crowdRally", "staminaRegen", 0.06),
			trigger("perk:a", "damage", 0.05),
			trigger("perk:b", "damageReduction", 0.04),
		}
		expect((Caps.check(rally))).toBe(true) -- 3 sources
	end)
end)

describe("Arena/Caps: what is refused, and why", function()
	it("passive over 5 % on a stat or 8 % combined", function()
		refused({ passive("damage", 0.06) }, "per stat")
		refused({ passive("damage", 0.05), passive("damageReduction", 0.05) }, "combined")
	end)

	it("more than 3 triggers, a trigger over 8 s or over +10 %", function()
		refused({
			trigger("a", "damage", 0.05),
			trigger("b", "damageReduction", 0.05),
			trigger("c", "staminaRegen", 0.05),
			trigger("d", "damage", 0.05),
		}, "4 support triggers")
		refused({ trigger("a", "damage", 0.05, 9) }, "lasts 9 s")
		refused({ trigger("a", "damage", 0.11) }, "cap +10.0 %")
	end)

	it("more than +15 % on one stat at once: the per-stat caps already add up to exactly the total", function()
		local n = Caps.NUMBERS
		expect(math.abs(n.passivePerStat + n.triggerMaxMagnitude - n.totalPerStat) < 1e-9).toBe(true)
		refused({ passive("damage", 0.05), trigger("a", "damage", 0.11) }, "cap")
		refused({ passive("damage", 0.05), passive("damage", 0.01), trigger("a", "damage", 0.10) }, "per stat")
	end)

	it("healing over 8 % a trigger or 10 % a duel", function()
		refused({ { source = "a", kind = "heal", magnitude = 0.09, duration = 6 } }, "per trigger")
		refused({
			{ source = "a", kind = "heal", magnitude = 0.06, duration = 6 },
			{ source = "b", kind = "heal", magnitude = 0.06, duration = 6 },
		}, "per duel")
	end)

	it("a trigger inside the quiet start, an effect on the opponent, a negative or non-finite bonus", function()
		refused(
			{ { source = "a", kind = "trigger", stat = "damage", magnitude = 0.05, duration = 6, earliest = 5 } },
			"first 10 s"
		)
		refused(
			{ { source = "a", kind = "passive", stat = "damage", magnitude = 0.01, affectsOpponent = true } },
			"opponent"
		)
		refused({ passive("damage", -0.01) }, "baseline")
		refused({ passive("damage", 0 / 0) }, "finite")
		refused({ passive("armourPierce", 0.01) }, "unknown stat")
		refused({ { source = "a", kind = "stun", magnitude = 0.01 } }, "unknown kind")
	end)

	it("the same trigger listed twice, a bad duration, a modifier list that is not a list", function()
		refused({ trigger("a", "damage", 0.05), trigger("a", "damage", 0.05) }, "twice")
		refused({ { source = "a", kind = "trigger", stat = "damage", magnitude = 0.05, duration = 0 } }, "duration")
		refused("nope" :: any, "list")
	end)

	it("reports every problem with problems(), and the first with check()", function()
		local problems = Caps.problems({ passive("damage", 0.06), trigger("a", "damage", 0.11) })
		expect(#problems >= 2).toBe(true)
		local _, first = Caps.check({ passive("damage", 0.06), trigger("a", "damage", 0.11) })
		expect(first).toBe(problems[1])
	end)
end)
