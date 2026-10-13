-- Kingdom/Reputation (FL-0080): the pure ledger, the user rules and the kingdom conditions (CONTRACTS G13.4).
-- Actions (actions.csv) run through ContentQuery in ReputationService; ReputationService.spec covers them
-- end to end on the real content library.

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local Reputation = require("@game/ReplicatedStorage/Game/Kingdom/Reputation")
local Society = require("@game/ReplicatedStorage/Forge/Config/Society")

-- ---------------------------------------------------------------- fixture categories (generated shape)

local function rep(values: { [string]: number }?): { [string]: number }
	local v = values or {}
	return {
		compassion = v.compassion or 0,
		honor = v.honor or 0,
		competence = v.competence or 0,
		courage = v.courage or 0,
		authority = v.authority or 0,
		fear = v.fear or 0,
	}
end

local function category(id: string, name: string, start: number)
	return { id = id, name = name, description = `{name} (fixture)`, affects = `What moves {name}.`, start = start }
end

local CONTENT = {
	categories = {
		compassion = category("compassion", "Compassion", 50),
		honor = category("honor", "Honor", 50),
		competence = category("competence", "Competence", 50),
		courage = category("courage", "Courage", 50),
		authority = category("authority", "Authority", 50),
		fear = category("fear", "Fear", 20),
	},
	order = { "compassion", "honor", "competence", "courage", "authority", "fear" },
}

-- ---------------------------------------------------------------- helpers

local function ctxOf(values: { fed: number?, housing: number?, barracks: number? }?)
	local v = values or {}
	return {
		["kingdom.fed_ratio"] = v.fed,
		["kingdom.housing_ratio"] = v.housing,
		["kingdom.count.barracks"] = v.barracks,
	}
end

-- ---------------------------------------------------------------- ledger

describe("Kingdom/Reputation: ledger, clamps and history", function()
	it("starts every category at its content start (fear 20), in canonical order", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		expect(ledger.values).toEqual({
			compassion = 50,
			honor = 50,
			competence = 50,
			courage = 50,
			authority = 50,
			fear = 20,
		})
		expect(ledger.order).toEqual(CONTENT.order)
		expect(ledger.history).toEqual({})
		expect(ledger.limit).toBe(Society.historyLimit)
	end)

	it("clamps every value to 0..100 and records the applied, post-clamp delta", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		local applied = Reputation.apply(ledger, "deserter_forgiven", { compassion = 60, fear = -30 }, "Mercy.", 12.5)
		expect(ledger.values.compassion).toBe(100)
		expect(ledger.values.fear).toBe(0)
		expect(applied).toEqual({ compassion = 50, fear = -20 })
		expect(ledger.history).toEqual({
			{ t = 12.5, category = "compassion", delta = 50, text = "Mercy.", source = "deserter_forgiven" },
			{ t = 12.5, category = "fear", delta = -20, text = "Mercy.", source = "deserter_forgiven" },
		})
	end)

	it("leaves no history for zero or fully clamped changes", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		Reputation.apply(ledger, "a", { compassion = 50 }, "Up.", 1)
		local applied = Reputation.apply(ledger, "b", { compassion = 5, honor = 0 }, "Nothing moves.", 2)
		expect(applied).toEqual({})
		expect(#ledger.history).toBe(1)
		expect(ledger.values.compassion).toBe(100)
	end)

	it("keeps only the newest historyLimit entries, oldest first", function()
		local config = table.clone(Society)
		config.historyLimit = 3
		local ledger = Reputation.newLedger(CONTENT.categories, config)
		for i = 1, 5 do
			Reputation.apply(ledger, `s{i}`, { honor = 1 }, `entry {i}`, i)
		end
		expect(#ledger.history).toBe(3)
		expect(ledger.history[1].text).toBe("entry 3")
		expect(ledger.history[3].text).toBe("entry 5")
		expect(ledger.values.honor).toBe(55)
	end)

	it("never errors on unknown categories or bad amounts: ignores and reports them", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		local applied, ignored =
			Reputation.apply(ledger, "x", { compassion = 1, charisma = 5, honor = 0 / 0, fear = math.huge }, "t", 3)
		expect(applied).toEqual({ compassion = 1 })
		expect(ignored).toEqual({ "charisma", "fear", "honor" })
		expect(ledger.values.honor).toBe(50)
		expect(ledger.values.fear).toBe(20)
		expect(ledger.values.charisma).toBeNil()
		expect(#ledger.history).toBe(1)
	end)

	it("view copies the values and the latest n entries", function()
		local ledger = Reputation.newLedger(CONTENT.categories)
		for i = 1, 4 do
			Reputation.apply(ledger, "s", { courage = i }, `e{i}`, i)
		end
		local view = Reputation.view(ledger, 2)
		expect(#view.history).toBe(2)
		expect(view.history[1].text).toBe("e3")
		expect(view.history[2].text).toBe("e4")
		view.values.courage = 0
		view.history[1].delta = 99
		expect(ledger.values.courage).toBe(60)
		expect(ledger.history[3].delta).toBe(3)
		expect(#Reputation.view(ledger).history).toBe(4)
	end)
end)

-- ---------------------------------------------------------------- user rules

describe("Kingdom/Reputation: user rules (guardRules)", function()
	it("a fight event cannot lower compassion or honor; its other losses and gains stay", function()
		local guarded, blocked =
			Reputation.guardRules("EnemyAttacked", rep({ compassion = -2, honor = -1, courage = 2, fear = -1 }))
		expect(blocked).toEqual({ "compassion", "honor" })
		expect(guarded.compassion).toBe(0)
		expect(guarded.honor).toBe(0)
		expect(guarded.courage).toBe(2)
		expect(guarded.fear).toBe(-1)
	end)

	it("matches the event by name, whatever its argument", function()
		local _, blocked = Reputation.guardRules("KingdomEliminated:azure", rep({ compassion = -3 }))
		expect(blocked).toEqual({ "compassion" })
	end)

	it("atrocities are not fights: burning farms still costs honor and raises fear", function()
		local guarded, blocked = Reputation.guardRules("EnemyFarmsBurned", rep({ honor = -2, fear = 3 }))
		expect(blocked).toEqual({})
		expect(guarded.honor).toBe(-2)
		expect(guarded.fear).toBe(3)
	end)

	it("peacekeeping is not rewarded by itself: peace rows raise nothing, their losses count", function()
		local guarded, blocked = Reputation.guardRules("PeaceMade", rep({ compassion = 2, honor = 1, courage = -1 }))
		expect(blocked).toEqual({ "compassion", "honor" })
		expect(guarded.courage).toBe(-1)
		-- no event, no change: a long quiet, fed peace drifts the kingdom conditions only
		local ledger = Reputation.newLedger(CONTENT.categories)
		local before = Reputation.view(ledger)
		local conditions = Reputation.newConditions()
		for _ = 1, 20 do
			Reputation.driftConditions(conditions, ctxOf({ fed = 1, housing = 0.8 }), 60)
		end
		expect(Reputation.view(ledger)).toEqual(before)
	end)

	it("returns a copy and leaves other events alone", function()
		local input = rep({ compassion = -2, honor = 2 })
		local guarded, blocked = Reputation.guardRules("BuildingCompleted:house", input)
		expect(blocked).toEqual({})
		expect(guarded).toEqual(input)
		guarded.honor = 99
		expect(input.honor).toBe(2)
	end)

	it("one application never swings a condition by more than maxConditionStep", function()
		local conditions = Reputation.newConditions()
		local _, applied = Reputation.applyConditions(conditions, { happiness = -20, stability = -20, morale = 0 })
		local step = Society.maxConditionStep
		expect(applied).toEqual({ happiness = -step, stability = -step, morale = 0 })
		expect(conditions.stability).toBe(Society.conditionStart.stability - step)
		local _, up = Reputation.applyConditions(conditions, { happiness = 50, morale = step / 2 })
		expect(up.happiness).toBe(step)
		expect(up.morale).toBe(step / 2)
	end)
end)

-- ---------------------------------------------------------------- kingdom conditions

describe("Kingdom/Reputation: kingdom conditions", function()
	it("start from config and stay within 0..100", function()
		local conditions = Reputation.newConditions()
		expect(conditions).toEqual(Society.conditionStart)
		conditions.morale = 97
		conditions.stability = 3
		local _, applied = Reputation.applyConditions(conditions, { morale = 6, stability = -6, happiness = 0 / 0 })
		expect(conditions.morale).toBe(100)
		expect(conditions.stability).toBe(0)
		expect(conditions.happiness).toBe(Society.conditionStart.happiness)
		expect(applied).toEqual({ happiness = 0, stability = -3, morale = 3 })
	end)

	it("drift is monotonic: more food never lowers a condition, and a fed kingdom drifts up", function()
		local previous, previousTarget = nil, nil
		for _, fed in { 0, 0.25, 0.5, 0.75, 1 } do
			local ctx = ctxOf({ fed = fed, housing = 0.8 })
			local target = Reputation.conditionTargets(ctx) :: any
			local conditions = Reputation.driftConditions(Reputation.newConditions(), ctx, 120)
			if previous then
				expect(target.happiness).toBeGreaterThan(previousTarget.happiness)
				expect(target.stability).toBeGreaterThan(previousTarget.stability)
				expect(target.morale).toBeGreaterThan(previousTarget.morale)
				for _, c in Reputation.CONDITIONS do
					expect(conditions[c]).toBeGreaterThanOrEqual(previous[c])
				end
			end
			previous, previousTarget = conditions, target
		end
		local start = Society.conditionStart
		local fed = Reputation.driftConditions(Reputation.newConditions(), ctxOf({ fed = 1 }), 60)
		expect(fed.happiness).toBeGreaterThan(start.happiness)
		local starved = Reputation.driftConditions(Reputation.newConditions(), ctxOf({ fed = 0 }), 60)
		expect(starved.happiness).toBeLessThan(start.happiness)
	end)

	it("drift is capped: at most rate × dt per call and never past the target", function()
		local rate = Society.drift.rate
		local target = Reputation.conditionTargets(ctxOf({ fed = 1, housing = 0.5 })) :: any
		expect(target.happiness).toBe(Society.drift.fed.happiness)
		local conditions = Reputation.newConditions()
		local start = conditions.happiness
		Reputation.driftConditions(conditions, ctxOf({ fed = 1, housing = 0.5 }), 10)
		expect(conditions.happiness - start).toBeLessThanOrEqual(rate.happiness * 10 + 1e-9)
		expect(conditions.happiness).toBeGreaterThan(start)
		Reputation.driftConditions(conditions, ctxOf({ fed = 1, housing = 0.5 }), 1e6)
		expect(conditions.happiness).toBe(target.happiness)
		expect(conditions.stability).toBe(target.stability)
		expect(conditions.morale).toBe(target.morale)
		conditions.happiness = 100
		Reputation.driftConditions(conditions, ctxOf({ fed = 1, housing = 0.5 }), 1e6)
		expect(conditions.happiness).toBe(target.happiness) -- from above: down to the target, not below
	end)

	it("crowding lowers the targets; an unknown fed ratio or dt <= 0 changes nothing", function()
		local roomy = Reputation.conditionTargets(ctxOf({ fed = 1, housing = 0.8 })) :: any
		local crowded = Reputation.conditionTargets(ctxOf({ fed = 1, housing = 3 })) :: any
		expect(roomy.happiness - crowded.happiness).toBe(Society.drift.crowdingPenalty.happiness)
		expect(roomy.stability - crowded.stability).toBe(Society.drift.crowdingPenalty.stability)
		expect(Reputation.conditionTargets(ctxOf({ housing = 0.8 }))).toBeNil()
		local conditions = Reputation.newConditions()
		Reputation.driftConditions(conditions, ctxOf({ housing = 3 }), 600)
		Reputation.driftConditions(conditions, ctxOf({ fed = 0 }), 0)
		Reputation.driftConditions(conditions, ctxOf({ fed = 0 }), -5)
		expect(conditions).toEqual(Society.conditionStart)
	end)
end)

describe("config Society", function()
	it("holds the G13.3 / G13.4 values and a usable drift model", function()
		expect(Society.openRequests).toBe(3)
		expect(Society.requestRefreshSeconds).toBe(20)
		expect(Society.historySent).toBe(30)
		expect(Society.historyLimit).toBeGreaterThanOrEqual(Society.historySent)
		expect(Society.maxConditionStep).toBeGreaterThan(0)
		for _, c in Reputation.CONDITIONS do
			expect(Society.conditionStart[c]).toBeA("number")
			expect(Society.drift.rate[c]).toBeGreaterThan(0)
			expect(Society.drift.fed[c]).toBeGreaterThanOrEqual(Society.drift.starved[c]) -- monotonic in food
			expect(Society.drift.crowdingPenalty[c]).toBeGreaterThanOrEqual(0) -- monotonic in housing
		end
		expect(Society.drift.housingCrowded).toBeGreaterThan(Society.drift.housingComfort)
		expect(Society.rules.fightNoLoss).toContain("compassion")
		expect(Society.rules.fightEvents).toContain("KingdomEliminated")
		expect(Society.strike.sustainSeconds).toBeGreaterThan(0)
	end)
end)
