-- Crown Arena fairness harness mechanics (FL-0076, FORGE-05; design §9).
--
-- These specs prove the harness, not the game: statistics, determinism, an unbiased mirror match,
-- the G12.3 trigger rules inside the duel double, setups refused over the caps, and a bound that
-- fails when support is made too strong. The real numbers come from `run.luau` (report) and, once
-- FORGE-01's DuelModel replaces DuelDouble, from the merge gate.
local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local DuelDouble = require("./DuelDouble")
local Harness = require("./Harness")

local function close(actual: number, expected: number, tolerance: number?)
	if math.abs(actual - expected) > (tolerance or 1e-3) then
		error(`expected {expected}, got {actual}`)
	end
end

-- Drives the double directly: B attacks whenever it can (until stopAt), A only takes hits.
local function beating(setupA: any, seconds: number, action: string?, stopAt: number?): ({ any }, any)
	local state = DuelDouble.new(nil, setupA, { weapon = "swordShield", armour = "medium" }, 1)
	local log = {}
	while state.t < seconds and not state.ended do
		local input = if state.t < (stopAt or math.huge)
			then { action = action or "heavy", inRange = true, facing = true }
			else nil
		local events = DuelDouble.step(state, { b = input }, 0.05)
		for _, event in events do
			table.insert(log, event)
		end
	end
	return log, state
end

describe("Fairness harness: statistics", function()
	it("computes 95 % Wilson intervals", function()
		local lo, hi = Harness.wilson(50, 100)
		close(lo, 0.4038)
		close(hi, 0.5962)
		lo, hi = Harness.wilson(0, 10)
		expect(lo).toBe(0)
		close(hi, 0.2775)
		lo, hi = Harness.wilson(10, 10)
		close(lo, 0.7225)
		expect(hi).toBe(1)
	end)

	it("evaluates each outcome bound, including marginal results", function()
		local function result(bound: string, rate: number, lo: number, hi: number): any
			return { cell = { id = `{bound}/{rate}`, bound = bound }, n = 2000, rate = rate, lo = lo, hi = hi }
		end
		local checks = Harness.evaluate({
			result("supportMatters", 0.60, 0.58, 0.62),
			result("supportMatters", 0.67, 0.65, 0.69),
			result("supportMatters", 0.54, 0.52, 0.56),
			result("skillStillWins", 0.61, 0.59, 0.63),
			result("skillStillWins", 0.58, 0.56, 0.605),
			result("noAutoWin", 0.69, 0.67, 0.71),
			result("noAutoWin", 0.72, 0.70, 0.74),
			{ cell = { id = "info" }, n = 1, rate = 0.5, lo = 0, hi = 1 },
		})
		local got = {}
		for _, check in checks do
			table.insert(got, check.status .. (if check.marginal then "~" else ""))
		end
		expect(got).toEqual({ "PASS", "FAIL", "FAIL~", "PASS~", "FAIL~", "PASS~", "FAIL" })
	end)
end)

describe("Fairness harness: duels", function()
	it("replays a duel exactly from its seed", function()
		local cell = {
			id = "replay",
			a = { skill = "average", tier = "adoring", perks = { "reforge", "calledWarning" } },
			b = { skill = "average", tier = "hostile", perks = {} },
		}
		local first = Harness.runCell(cell, 40, { seed = 11 })
		local second = Harness.runCell(cell, 40, { seed = 11 })
		expect({ first.wins, first.losses, first.draws, first.meanSeconds }).toEqual({
			second.wins,
			second.losses,
			second.draws,
			second.meanSeconds,
		})
		local other = Harness.runCell(cell, 40, { seed = 12 })
		expect(other.meanSeconds ~= first.meanSeconds).toBe(true)
	end)

	it("gives a mirror match about 50 % (no side or seed bias)", function()
		local side = { skill = "average", tier = "hostile", perks = {} }
		local result = Harness.runCell({ id = "mirror", a = side, b = side }, 400, { seed = 5 })
		expect(result.lo < 0.5 and result.hi > 0.5).toBe(true)
	end)

	it("refuses a setup over the caps unless a negative test asks for it", function()
		local overCap = {
			skill = "average",
			modifiers = { { source = "tier:x", kind = "passive", stat = "damageReduction", magnitude = 0.5 } },
		}
		local baseline = { skill = "average", tier = "hostile", perks = {} }
		expect(function()
			Harness.duel(DuelDouble, overCap, baseline, 1)
		end).toThrow("breaks the G12.3 caps")
		-- The no-auto-win bound catches support made too strong (+50 % damage reduction).
		local result = Harness.runCell(
			{ id = "noAutoWin/overCap", bound = "noAutoWin", a = overCap, b = baseline },
			100,
			{
				seed = 3,
				allowOverCap = true,
			}
		)
		local check = Harness.evaluate({ result })[1]
		expect(check.status).toBe("FAIL")
		expect(result.rate > 0.7).toBe(true)
	end)

	it("plans every bound: support, skill and every tier x perk set", function()
		local cells = Harness.plan({ skills = { "average" } })
		local byBound = {}
		for _, cell in cells do
			byBound[cell.bound] = (byBound[cell.bound] or 0) + 1
		end
		-- adoring C(5,3)=10, loyal C(4,3)=4, divided C(4,2)=6, restless 4, hostile 1
		expect(byBound).toEqual({ supportMatters = 1, skillStillWins = 2, noAutoWin = 25 })
		local withLoadouts = Harness.plan({ skills = { "average" }, loadouts = Harness.allLoadouts() })
		expect(#withLoadouts).toBe(28 + 24)
	end)

	it("writes a report that marks the double", function()
		local cell = {
			id = "noAutoWin/average/hostile/-",
			bound = "noAutoWin",
			a = { skill = "average", tier = "hostile", perks = {} },
			b = { skill = "average", tier = "hostile", perks = {} },
		}
		local results = { Harness.runCell(cell, 20, { seed = 1 }) }
		local text = Harness.report(
			results,
			Harness.evaluate(results),
			{ model = "DuelDouble", n = 20, seed = 1, dt = Harness.DT }
		)
		expect(text).toContain("NOT the game's")
		expect(text).toContain("| noAutoWin/average/hostile/- | noAutoWin | <= 70 % |")
	end)
end)

describe("Fairness harness: G12.3 rules inside the duel double", function()
	it("fires a trigger once, never in the first 10 s", function()
		local log = beating({
			modifiers = {
				{
					source = "perk:reforge",
					kind = "trigger",
					stat = "damageReduction",
					magnitude = 0.10,
					duration = 6,
					condition = "hpBelow:0.95",
				},
			},
		}, 40)
		local fired, firstHitAt = {}, nil
		for _, event in log do
			if event.kind == "triggerFired" then
				table.insert(fired, event.t)
			elseif event.kind == "hit" and firstHitAt == nil then
				firstHitAt = event.t
			end
		end
		expect(firstHitAt ~= nil and firstHitAt < 10).toBe(true) -- the condition held before the quiet start
		expect(#fired).toBe(1)
		expect(fired[1] >= 10).toBe(true)
	end)

	it("applies the stronger of two damage-reduction triggers, not both", function()
		local reforge = {
			source = "perk:reforge",
			kind = "trigger",
			stat = "damageReduction",
			magnitude = 0.10,
			duration = 8,
			condition = "hpBelow:0.99",
		}
		local rally = {
			source = "crowdRally",
			kind = "trigger",
			stat = "damageReduction",
			magnitude = 0.05,
			duration = 8,
			condition = "hpBelow:0.99",
		}
		local log = beating({ modifiers = { reforge, rally } }, 16)
		local firedAt
		for _, event in log do
			if event.kind == "triggerFired" then
				firedAt = event.t
			end
		end
		expect(firedAt ~= nil).toBe(true)
		local base = DuelDouble.WEAPONS.swordShield.heavy * (1 - DuelDouble.ARMOUR.medium.reduction)
		for _, event in log do
			if event.kind == "hit" then
				local expected = if event.t > (firedAt :: number) + 1e-9 then base * 0.90 else base
				close(event.data.damage, expected, 1e-6)
			end
		end
	end)

	it("spreads a heal over its duration and never above max HP", function()
		local heal =
			{ source = "perk:fieldRemedy", kind = "heal", magnitude = 0.08, duration = 4, condition = "hpBelow:0.99" }
		-- one heavy hit (13.2 HP), then the heal fires at 10 s and adds 8 HP over 4 s
		local _, healed = beating({ modifiers = { heal } }, 30, "heavy", 1)
		local _, plain = beating({}, 30, "heavy", 1)
		close(healed.a.hp - plain.a.hp, 8, 0.05)
		-- one light hit (5.6 HP): the same heal stops at max HP
		local _, capped = beating({ modifiers = { heal } }, 30, "light", 0.5)
		expect(capped.a.hp).toBe(DuelDouble.CONFIG.maxHp)
	end)
end)
