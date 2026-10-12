local T = require("../../harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local ConfigCurrencies = require("@game/ReplicatedStorage/Forge/Config/Currencies")
local ConfigRewardTables = require("@game/ReplicatedStorage/Forge/Config/RewardTables")
local ItemRegistry = require("@game/ReplicatedStorage/Forge/Economy/ItemRegistry")
local RewardTables = require("@game/ReplicatedStorage/Forge/Economy/RewardTables")

-- ------------------------------------------------------------------ fixtures

local function cosmetic(id: string, rarity: string, maxStack: number?)
	return { id = id, kind = "cosmetic", name = id, description = "d", icon = "i", rarity = rarity, maxStack = maxStack }
end

local registry = ItemRegistry.new({
	cosmetic("c1", "Common"),
	cosmetic("c2", "Common"),
	cosmetic("s1", "Common", 3),
	cosmetic("u1", "Uncommon"),
	cosmetic("r1", "Rare"),
	cosmetic("e1", "Epic"),
	cosmetic("e2", "Epic"),
	cosmetic("l1", "Legendary"),
	{ id = "b1", kind = "building", name = "B", description = "d", icon = "i", rarity = "Common", building = {} },
})

-- Several items per tier, tiers listed out of rarity order, a qty, and pity (afterOpens 3, Rare).
-- Normal: c1 .125, c2 .125, s1 .25 (qty 3), r1 .3, e1 .05, e2 .15. Guaranteed: r1 .6, e1 .1, e2 .3.
local function mixedTable(): { [string]: any }
	return {
		id = "mixed",
		name = "Mixed",
		cost = { currency = "crowns", amount = 5 },
		pity = { afterOpens = 3, minRarity = "Rare" },
		tiers = {
			{ rarity = "Epic", weight = 2, items = { { itemId = "e1", weight = 1 }, { itemId = "e2", weight = 3 } } },
			{
				rarity = "Common",
				weight = 5,
				items = {
					{ itemId = "c1", weight = 1 },
					{ itemId = "c2", weight = 1 },
					{ itemId = "s1", weight = 2, qty = 3 },
				},
			},
			{ rarity = "Rare", weight = 3, items = { { itemId = "r1", weight = 1 } } },
		},
	}
end

local function simpleTable(id: string): { [string]: any }
	return {
		id = id,
		name = "Simple",
		tiers = {
			{ rarity = "Common", weight = 3, items = { { itemId = "c1", weight = 1 } } },
			{ rarity = "Rare", weight = 1, items = { { itemId = "r1", weight = 1 } } },
		},
	}
end

-- Odds that need rounding: six outcomes of 1/6 each; the guaranteed open (Rare or better) has three
-- of 1/3 each. Without largest remainder these would display 99.96% and 99.99%.
local function thirdsTable(): { [string]: any }
	return {
		id = "thirds",
		name = "Thirds",
		pity = { afterOpens = 2, minRarity = "Rare" },
		tiers = {
			{
				rarity = "Common",
				weight = 3,
				items = { { itemId = "c1", weight = 1 }, { itemId = "c2", weight = 1 }, { itemId = "s1", weight = 1 } },
			},
			{ rarity = "Rare", weight = 1, items = { { itemId = "r1", weight = 1 } } },
			{ rarity = "Epic", weight = 2, items = { { itemId = "e1", weight = 1 }, { itemId = "e2", weight = 1 } } },
		},
	}
end

local fixture = RewardTables.new({ mixedTable(), simpleTable("simple"), thirdsTable() }, registry, { "crowns" })
local default = RewardTables.default()

local CURRENCY_IDS = {}
for _, currency in ConfigCurrencies do
	table.insert(CURRENCY_IDS, currency.id)
end

-- Every (set, tableId) pair whose every reachable pity state the distribution specs walk.
local CASES = {
	{ set = default, tableId = "chest_banners" },
	{ set = default, tableId = "match_reward" },
	{ set = fixture, tableId = "mixed" },
	{ set = fixture, tableId = "simple" },
	{ set = fixture, tableId = "thirds" },
}

-- An rng whose NextNumber always returns the given value(s) in turn (the last one repeats).
local function stubRng(...: number)
	local values = { ... }
	local index = 0
	return {
		NextNumber = function(_self)
			index = math.min(index + 1, #values)
			return values[index]
		end,
	}
end

local function sumOf(list: { number }): number
	local total = 0
	for _, v in list do
		total += v
	end
	return total
end

local function probabilities(odds): { number }
	local out = {}
	for i, entry in odds do
		out[i] = entry.probability
	end
	return out
end

local function field(odds, name: string): { any }
	local out = {}
	for i, entry in odds do
		out[i] = entry[name]
	end
	return out
end

-- "12.50%" -> 1250
local function parseHundredths(text: string): number
	local whole, frac = string.match(text, "^(%d+)%.(%d%d)%%$")
	assert(whole and frac, `not a two-decimal percent: {text}`)
	return tonumber(whole) :: number * 100 + tonumber(frac) :: number
end

-- Problems for a fixture config validated against the fixture registry and currencies {"crowns"}.
local function problemsOf(config: any): { string }
	local ok, problems = RewardTables.validate(config, registry, { "crowns" })
	expect(ok).toBe(#problems == 0)
	return problems
end

local function expectProblem(config: any, ...: string)
	local problems = problemsOf(config)
	expect(#problems).toBeGreaterThanOrEqual(1)
	local text = table.concat(problems, "\n")
	for _, part in { ... } do
		expect(text).toContain(part)
	end
end

local function withChange(change: (t: { [string]: any }) -> ()): { any }
	local t = mixedTable()
	change(t)
	return { t }
end

-- ------------------------------------------------------------------ specs

describe("Economy/RewardTables", function()
	describe("default config (Config.RewardTables)", function()
		it("validates against Config.Items and Config.Currencies with no problems", function()
			local ok, problems = RewardTables.validate(ConfigRewardTables, ItemRegistry.default(), CURRENCY_IDS)
			expect(problems).toEqual({})
			expect(ok).toBe(true)
		end)

		it("exposes both tables in config order with their name, cost and pity", function()
			expect(field(RewardTables.all(), "id")).toEqual({ "chest_banners", "match_reward" })
			local chest = RewardTables.get("chest_banners") :: any
			expect(chest.name).toBe("Royal Chest")
			expect(chest.cost).toEqual({ currency = "crowns", amount = 100 })
			expect(chest.pity).toEqual({ afterOpens = 10, minRarity = "Epic" })
			local match = RewardTables.get("match_reward") :: any
			expect(match.cost).toBeNil()
			expect(match.pity).toBeNil()
			expect(RewardTables.get("nope")).toBeNil()
		end)

		it("copies the config: definitions are frozen copies, the config entries stay unfrozen", function()
			local chest = RewardTables.get("chest_banners") :: any
			expect(chest).never.toBe(ConfigRewardTables[1])
			expect(chest).toEqual(ConfigRewardTables[1])
			expect(table.isfrozen(chest.tiers[1].items[1])).toBe(true)
			expect(table.isfrozen(ConfigRewardTables[1])).toBe(false)
		end)

		it("module functions use the default set (same odds lists)", function()
			expect(RewardTables.odds("chest_banners")).toBe(default:odds("chest_banners"))
			expect(RewardTables.odds("chest_banners", { opensSinceHit = 9 })).toBe(
				default:odds("chest_banners", { opensSinceHit = 9 })
			)
			expect(RewardTables.pityStates("chest_banners")).toBe(default:pityStates("chest_banners"))
			expect(RewardTables.default()).toBe(default)
		end)

		it("chest_banners shows the proposed odds, and the guaranteed open only Epic or better", function()
			local odds = RewardTables.odds("chest_banners")
			expect(field(odds, "itemId")).toEqual({
				"banner_oak",
				"banner_lion",
				"banner_dragon",
				"crest_phoenix",
				"crest_sun",
			})
			expect(field(odds, "rarity")).toEqual({ "Common", "Uncommon", "Rare", "Epic", "Legendary" })
			expect(field(odds, "qty")).toEqual({ 1, 1, 1, 1, 1 })
			for i, p in { 0.6, 0.25, 0.1, 0.04, 0.01 } do
				expect(odds[i].probability).toBeNear(p, 1e-15)
			end
			expect(RewardTables.displayPercents(odds)).toEqual({ "60.00%", "25.00%", "10.00%", "4.00%", "1.00%" })
			local guaranteed = RewardTables.odds("chest_banners", { opensSinceHit = 9 })
			expect(field(guaranteed, "itemId")).toEqual({ "crest_phoenix", "crest_sun" })
			expect(RewardTables.displayPercents(guaranteed)).toEqual({ "80.00%", "20.00%" })
		end)

		it("match_reward shows the proposed odds", function()
			expect(RewardTables.displayPercents(RewardTables.odds("match_reward"))).toEqual({
				"70.00%",
				"20.00%",
				"7.00%",
				"2.50%",
				"0.50%",
			})
		end)

		it("describes the pity rule, or nil without pity", function()
			expect(RewardTables.pityRule("chest_banners")).toBe("Epic or better guaranteed within 10 opens")
			expect(RewardTables.pityRule("match_reward")).toBeNil()
		end)

		it("lists every reachable pity state", function()
			local states = RewardTables.pityStates("chest_banners")
			expect(states).toHaveLength(10)
			for k, state in states do
				expect(state).toEqual({ opensSinceHit = k - 1 })
			end
			expect(RewardTables.pityStates("match_reward")).toEqual({ { opensSinceHit = 0 } })
		end)

		it("errors on an unknown table id, naming it", function()
			expect(function()
				RewardTables.odds("chest_banner")
			end).toThrow('unknown reward table "chest_banner"')
			expect(function()
				RewardTables.pityRule("nope")
			end).toThrow('unknown reward table "nope"')
			expect(function()
				RewardTables.roll("nope", nil, stubRng(0))
			end).toThrow('unknown reward table "nope"')
			expect(function()
				fixture:odds("chest_banners")
			end).toThrow('unknown reward table "chest_banners"')
		end)
	end)

	describe("odds", function()
		it("sum to 1 (within 1e-12) for every table and every reachable pity state", function()
			for _, case in CASES do
				for _, state in case.set:pityStates(case.tableId) do
					local odds = case.set:odds(case.tableId, state)
					expect(math.abs(sumOf(probabilities(odds)) - 1)).toBeLessThanOrEqual(1e-12)
					for _, entry in odds do
						expect(entry.probability).toBeGreaterThan(0)
					end
				end
			end
		end)

		it("display percents list every outcome and sum to exactly 10000 hundredths in every state", function()
			for _, case in CASES do
				for _, state in case.set:pityStates(case.tableId) do
					local odds = case.set:odds(case.tableId, state)
					local hundredths = case.set:displayHundredths(odds)
					local percents = case.set:displayPercents(odds)
					expect(hundredths).toHaveLength(#odds)
					expect(percents).toHaveLength(#odds)
					expect(sumOf(hundredths)).toBe(10000)
					local parsed = {}
					for i, text in percents do
						parsed[i] = parseHundredths(text)
						expect(parsed[i]).toBe(hundredths[i])
						expect(parsed[i]).toBeGreaterThanOrEqual(1) -- no possible outcome shown as 0.00%
					end
					expect(sumOf(parsed)).toBe(10000)
				end
			end
		end)

		it("the non-guaranteed states list every configured item of the table", function()
			for _, case in CASES do
				local configured = {}
				for _, tier in (case.set:get(case.tableId) :: any).tiers do
					for _, item in tier.items do
						configured[item.itemId] = tier.rarity
					end
				end
				local listed = {}
				for _, entry in case.set:odds(case.tableId, { opensSinceHit = 0 }) do
					expect(listed[entry.itemId]).toBeNil() -- each outcome once
					listed[entry.itemId] = entry.rarity
				end
				expect(listed).toEqual(configured)
			end
		end)

		it("orders entries by rarity rank, then config order, with tier x item probabilities", function()
			local odds = fixture:odds("mixed")
			expect(field(odds, "itemId")).toEqual({ "c1", "c2", "s1", "r1", "e1", "e2" })
			expect(field(odds, "rarity")).toEqual({ "Common", "Common", "Common", "Rare", "Epic", "Epic" })
			expect(field(odds, "qty")).toEqual({ 1, 1, 3, 1, 1, 1 })
			for i, p in { 0.125, 0.125, 0.25, 0.3, 0.05, 0.15 } do
				expect(odds[i].probability).toBeNear(p, 1e-15)
			end
			expect(fixture:displayPercents(odds)).toEqual({ "12.50%", "12.50%", "25.00%", "30.00%", "5.00%", "15.00%" })
		end)

		it("rounds odds that are not whole hundredths so the shown percents still total 100.00%", function()
			expect(fixture:displayPercents(fixture:odds("thirds"))).toEqual({
				"16.67%",
				"16.67%",
				"16.67%",
				"16.67%",
				"16.66%",
				"16.66%",
			})
			expect(fixture:displayPercents(fixture:odds("thirds", { opensSinceHit = 1 }))).toEqual({
				"33.34%",
				"33.33%",
				"33.33%",
			})
		end)

		it("conditions the guaranteed open on rarity >= minRarity and renormalises", function()
			expect(fixture:odds("mixed", { opensSinceHit = 1 })).toBe(fixture:odds("mixed"))
			local odds = fixture:odds("mixed", { opensSinceHit = 2 })
			expect(field(odds, "itemId")).toEqual({ "r1", "e1", "e2" })
			for i, p in { 0.6, 0.1, 0.3 } do
				expect(odds[i].probability).toBeNear(p, 1e-15)
			end
			-- a stale counter past the guarantee (e.g. afterOpens lowered in config) is still guaranteed
			expect(fixture:odds("mixed", { opensSinceHit = 40 })).toBe(odds)
		end)

		it("returns frozen lists and entries", function()
			local odds = RewardTables.odds("chest_banners")
			expect(table.isfrozen(odds)).toBe(true)
			expect(function()
				(odds[1] :: any).probability = 1
			end).toThrow()
			expect(function()
				table.insert(odds :: any, odds[1])
			end).toThrow()
		end)

		it("rejects invalid pity states", function()
			for _, bad in { { opensSinceHit = -1 }, { opensSinceHit = 1.5 }, { opensSinceHit = "3" }, {}, 3 } do
				expect(function()
					fixture:odds("mixed", bad :: any)
				end).toThrow("pityState must be nil or")
			end
			expect(function()
				fixture:odds("simple", { opensSinceHit = -1 })
			end).toThrow("pityState must be nil or")
		end)
	end)

	describe("roll samples exactly odds()", function()
		it("returns the entry whose cumulative interval [lo, hi) contains r, in every state", function()
			for _, case in CASES do
				local set, tableId = case.set, case.tableId
				local pity = (set:get(tableId) :: any).pity
				for _, state in set:pityStates(tableId) do
					local odds = set:odds(tableId, state)
					local guaranteed = pity ~= nil and state.opensSinceHit >= pity.afterOpens - 1
					local removed = #odds < #set:odds(tableId, { opensSinceHit = 0 })
					local lo = 0
					for i, entry in odds do
						local hi = lo + entry.probability
						local draws = { lo, lo + (hi - lo) / 2, lo + (hi - lo) * 0.999999 }
						if i == #odds then
							table.insert(draws, 1 - 2 ^ -53) -- the largest double below 1
						end
						for _, r in draws do
							local result = set:roll(tableId, state, stubRng(r))
							expect(result).toEqual({
								tableId = tableId,
								rarity = entry.rarity,
								itemId = entry.itemId,
								qty = entry.qty,
								pityTriggered = guaranteed and removed,
							})
						end
						lo = hi
					end
				end
			end
		end)

		it("matches odds() over 200k seeded rolls per reachable state (each |freq - p| <= 5 sigma)", function()
			local N = 200000
			for caseIndex, case in CASES do
				local set, tableId = case.set, case.tableId
				for _, state in set:pityStates(tableId) do
					local odds = set:odds(tableId, state)
					local index = {}
					for i, entry in odds do
						index[entry.itemId] = i
					end
					local counts = table.create(#odds, 0)
					local rng = Random.new(1000 * caseIndex + state.opensSinceHit)
					for _ = 1, N do
						local result = set:roll(tableId, state, rng)
						local i = index[result.itemId]
						assert(
							i ~= nil,
							`rolled {result.itemId}, which is not in odds({tableId}, {state.opensSinceHit})`
						)
						counts[i] += 1
					end
					for i, entry in odds do
						local p = entry.probability
						local sigma = math.sqrt(p * (1 - p) / N)
						expect(math.abs(counts[i] / N - p)).toBeLessThanOrEqual(5 * sigma)
					end
				end
			end
		end)

		it("is deterministic for a seed: same seed, same sequence; different seed, different sequence", function()
			local function sequence(seed: number): { string }
				local rng = Random.new(seed)
				local out, state = {}, nil
				for i = 1, 200 do
					local result
					result, state = RewardTables.roll("chest_banners", state, rng)
					out[i] = result.itemId
				end
				return out
			end
			expect(sequence(7)).toEqual(sequence(7))
			expect(sequence(7)).never.toEqual(sequence(8))
		end)

		it("accepts a seed number in place of an rng (Random.new(seed))", function()
			local a = RewardTables.roll("match_reward", nil, 12345)
			local b = RewardTables.roll("match_reward", nil, 12345)
			expect(a).toEqual(b)
			local expected = RewardTables.roll("match_reward", nil, Random.new(12345))
			expect(a).toEqual(expected)
		end)

		it("rejects a missing rng and draws outside [0, 1)", function()
			expect(function()
				RewardTables.roll("match_reward", nil, nil)
			end).toThrow("rng must be")
			for _, bad in { 1, -0.1, 0 / 0, 1.5 } do
				expect(function()
					RewardTables.roll("match_reward", nil, stubRng(bad))
				end).toThrow("must return a number in [0, 1)")
			end
		end)
	end)

	describe("pity", function()
		it("opens 1-9 can roll below Epic; the 10th is guaranteed Epic or better; then the count restarts", function()
			local rng = stubRng(0) -- always the first entry: the lowest tier unless it was removed
			local state = nil
			for open = 1, 9 do
				local result
				result, state = RewardTables.roll("chest_banners", state, rng)
				expect(result.itemId).toBe("banner_oak")
				expect(result.rarity).toBe("Common")
				expect(result.pityTriggered).toBe(false)
				expect(state).toEqual({ opensSinceHit = open })
			end
			local tenth
			tenth, state = RewardTables.roll("chest_banners", state, rng)
			expect(tenth).toEqual({
				tableId = "chest_banners",
				rarity = "Epic",
				itemId = "crest_phoenix",
				qty = 1,
				pityTriggered = true,
			})
			expect(state).toEqual({ opensSinceHit = 0 })
			local eleventh
			eleventh, state = RewardTables.roll("chest_banners", state, rng)
			expect(eleventh.itemId).toBe("banner_oak")
			expect(state).toEqual({ opensSinceHit = 1 })
		end)

		it("a natural Epic or Legendary resets the counter without pityTriggered; a Rare does not", function()
			-- chest_banners cumulative: Common .60, Uncommon .85, Rare .95, Epic .99, Legendary 1
			local result, state = RewardTables.roll("chest_banners", { opensSinceHit = 3 }, stubRng(0.999))
			expect(result.itemId).toBe("crest_sun")
			expect(result.pityTriggered).toBe(false)
			expect(state).toEqual({ opensSinceHit = 0 })
			result, state = RewardTables.roll("chest_banners", { opensSinceHit = 8 }, stubRng(0.96))
			expect(result.itemId).toBe("crest_phoenix")
			expect(result.pityTriggered).toBe(false)
			expect(state).toEqual({ opensSinceHit = 0 })
			result, state = RewardTables.roll("chest_banners", { opensSinceHit = 5 }, stubRng(0.9))
			expect(result.rarity).toBe("Rare")
			expect(state).toEqual({ opensSinceHit = 6 })
		end)

		it("nextPityState resets at or above minRarity, otherwise adds 1 and never passes afterOpens - 1", function()
			expect(fixture:nextPityState("mixed", nil, "Common")).toEqual({ opensSinceHit = 1 })
			expect(fixture:nextPityState("mixed", { opensSinceHit = 1 }, "Common")).toEqual({ opensSinceHit = 2 })
			expect(fixture:nextPityState("mixed", { opensSinceHit = 2 }, "Common")).toEqual({ opensSinceHit = 2 })
			expect(fixture:nextPityState("mixed", { opensSinceHit = 1 }, "Rare")).toEqual({ opensSinceHit = 0 })
			expect(fixture:nextPityState("mixed", { opensSinceHit = 1 }, "Epic")).toEqual({ opensSinceHit = 0 })
		end)

		it("nextPityState is always 0 without pity and rejects rarities the table does not have", function()
			expect(fixture:nextPityState("simple", { opensSinceHit = 4 }, "Common")).toEqual({ opensSinceHit = 0 })
			expect(RewardTables.nextPityState("match_reward", nil, "Common")).toEqual({ opensSinceHit = 0 })
			expect(function()
				fixture:nextPityState("simple", nil, "Epic")
			end).toThrow('"Epic" is not a rarity of reward table "simple"')
			expect(function()
				fixture:nextPityState("mixed", nil, "Mythic")
			end).toThrow("is not a rarity of reward table")
		end)

		it("a table without pity never triggers it, whatever the counter says", function()
			local result, state = fixture:roll("simple", { opensSinceHit = 50 }, stubRng(0))
			expect(result.itemId).toBe("c1")
			expect(result.pityTriggered).toBe(false)
			expect(state).toEqual({ opensSinceHit = 0 })
		end)

		it("pityTriggered stays false when no tier is below minRarity (nothing removed)", function()
			local set = RewardTables.new({
				{
					id = "high",
					name = "High",
					pity = { afterOpens = 2, minRarity = "Epic" },
					tiers = {
						{ rarity = "Epic", weight = 3, items = { { itemId = "e1", weight = 1 } } },
						{ rarity = "Legendary", weight = 1, items = { { itemId = "l1", weight = 1 } } },
					},
				},
			}, registry)
			local result = set:roll("high", { opensSinceHit = 1 }, stubRng(0))
			expect(result.itemId).toBe("e1")
			expect(result.pityTriggered).toBe(false)
			expect(probabilities(set:odds("high", { opensSinceHit = 1 }))).toEqual(probabilities(set:odds("high")))
		end)

		it("words the rule for every open and for the top rarity", function()
			local set = RewardTables.new({
				{
					id = "every",
					name = "Every",
					pity = { afterOpens = 1, minRarity = "Rare" },
					tiers = simpleTable("x").tiers,
				},
				{
					id = "top",
					name = "Top",
					pity = { afterOpens = 3, minRarity = "Legendary" },
					tiers = {
						{ rarity = "Common", weight = 3, items = { { itemId = "c1", weight = 1 } } },
						{ rarity = "Legendary", weight = 1, items = { { itemId = "l1", weight = 1 } } },
					},
				},
			}, registry)
			expect(set:pityRule("every")).toBe("Rare or better guaranteed within 1 open")
			expect(set:pityStates("every")).toEqual({ { opensSinceHit = 0 } })
			expect(field(set:odds("every"), "itemId")).toEqual({ "r1" }) -- every open is the guaranteed one
			expect(set:pityRule("top")).toBe("Legendary guaranteed within 3 opens")
		end)
	end)

	describe("display rounding (largest remainder)", function()
		local function odds(list: { number })
			local out = {}
			for i, p in list do
				out[i] = { rarity = "Common", itemId = `i{i}`, qty = 1, probability = p }
			end
			return out
		end

		it("three equal thirds -> 33.34 / 33.33 / 33.33", function()
			local third = odds({ 1 / 3, 1 / 3, 1 / 3 })
			expect(RewardTables.displayHundredths(third)).toEqual({ 3334, 3333, 3333 })
			expect(RewardTables.displayPercents(third)).toEqual({ "33.34%", "33.33%", "33.33%" })
		end)

		it("breaks equal remainders by list order", function()
			local sixths = odds({ 1 / 6, 1 / 6, 1 / 6, 1 / 6, 1 / 6, 1 / 6 })
			expect(RewardTables.displayHundredths(sixths)).toEqual({ 1667, 1667, 1667, 1667, 1666, 1666 })
		end)

		it("gives the missing hundredths to the largest remainders first", function()
			-- exact: 2000.4, 3000.9, 4998.7 -> floors sum to 9998; .9 and .7 get the two missing units
			expect(RewardTables.displayHundredths(odds({ 0.20004, 0.30009, 0.49987 }))).toEqual({ 2000, 3001, 4999 })
		end)

		it("shows a single outcome as 100.00%", function()
			expect(RewardTables.displayPercents(odds({ 1 }))).toEqual({ "100.00%" })
		end)

		it("keeps the sum at 100.00% with tiny probabilities", function()
			local tiny = odds({ 1 - 3e-6, 1e-6, 1e-6, 1e-6 })
			expect(RewardTables.displayHundredths(tiny)).toEqual({ 10000, 0, 0, 0 })
			expect(RewardTables.displayPercents(tiny)).toEqual({ "100.00%", "0.00%", "0.00%", "0.00%" })
			local small = odds({ 0.9999, 0.00005, 0.00005 }) -- 9999 + .5 + .5: the first .5 wins the tie
			expect(RewardTables.displayHundredths(small)).toEqual({ 9999, 1, 0 })
		end)

		it("formats with exactly two decimals", function()
			expect(RewardTables.displayPercents(odds({ 0.125, 0.0005, 0.8745 }))).toEqual({
				"12.50%",
				"0.05%",
				"87.45%",
			})
		end)

		it("always sums to 10000 and stays within 1 hundredth of exact on 500 random distributions", function()
			local rng = Random.new(99)
			for _ = 1, 500 do
				local n = rng:NextInteger(1, 25)
				local weights, total = {}, 0
				for i = 1, n do
					weights[i] = if rng:NextNumber() < 0.2 then rng:NextNumber() * 1e-4 else rng:NextNumber() * 100
					total += weights[i]
				end
				local list = {}
				for i = 1, n do
					list[i] = weights[i] / total
				end
				local hundredths = RewardTables.displayHundredths(odds(list))
				expect(sumOf(hundredths)).toBe(10000)
				for i, h in hundredths do
					expect(math.abs(h - list[i] * 10000)).toBeLessThan(1)
				end
			end
		end)

		it("rejects odds that are empty, malformed or do not sum to 1", function()
			expect(function()
				RewardTables.displayHundredths({})
			end).toThrow("non-empty list")
			expect(function()
				RewardTables.displayHundredths(odds({ 0.5, 0.4 }))
			end).toThrow("must sum to 1")
			expect(function()
				RewardTables.displayHundredths(odds({ 0.5, 0 / 0, 0.5 }))
			end).toThrow("odds[2].probability must be a number in [0, 1]")
			expect(function()
				RewardTables.displayPercents(odds({ 1.5, -0.5 }))
			end).toThrow("odds[1].probability")
		end)

		it("instance methods are the same functions", function()
			local third = odds({ 1 / 3, 1 / 3, 1 / 3 })
			expect(fixture:displayPercents(third)).toEqual(RewardTables.displayPercents(third))
			expect(fixture:displayHundredths(third)).toEqual(RewardTables.displayHundredths(third))
		end)
	end)

	describe("validation", function()
		it("accepts the fixtures", function()
			expect(problemsOf({ mixedTable(), simpleTable("simple"), thirdsTable() })).toEqual({})
		end)

		it("rejects a duplicate table id", function()
			expectProblem(
				{ simpleTable("a"), simpleTable("a") },
				'rewardTables[2] ("a"): id duplicates rewardTables[1]'
			)
		end)

		it("rejects bad ids and names", function()
			expectProblem({ simpleTable("Bad Id") }, 'rewardTables[1] ("Bad Id"): id must be')
			expectProblem(
				withChange(function(t)
					t.name = ""
				end),
				"name must be a non-empty string"
			)
		end)

		it("rejects an unknown item", function()
			expectProblem(
				withChange(function(t)
					t.tiers[1].items[1].itemId = "nope"
				end),
				'rewardTables[1] ("mixed"): tiers[1].items[1].itemId: unknown item "nope"'
			)
		end)

		it("rejects a non-cosmetic item", function()
			expectProblem(
				withChange(function(t)
					t.tiers[2].items[1].itemId = "b1"
				end),
				'tiers[2].items[1].itemId: "b1" is a building; only cosmetic items can be rewards'
			)
		end)

		it("rejects an item whose rarity differs from its tier", function()
			expectProblem(
				withChange(function(t)
					t.tiers[3].items[1].itemId = "u1"
				end),
				'tiers[3].items[1].itemId: "u1" is Uncommon but sits in the Rare tier'
			)
		end)

		it("rejects the same item twice in one table", function()
			expectProblem(
				withChange(function(t)
					t.tiers[2].items[2].itemId = "c1"
				end),
				'tiers[2].items[2].itemId: "c1" already appears at tiers[2].items[1]'
			)
		end)

		it("rejects zero, negative, NaN and infinite weights", function()
			expectProblem(
				withChange(function(t)
					t.tiers[1].weight = 0
				end),
				"tiers[1].weight must be a finite number > 0 (got 0)"
			)
			expectProblem(
				withChange(function(t)
					t.tiers[2].items[3].weight = -2
				end),
				"tiers[2].items[3].weight must be a finite number > 0 (got -2)"
			)
			expectProblem(
				withChange(function(t)
					t.tiers[1].weight = 0 / 0
				end),
				"tiers[1].weight must be a finite number > 0"
			)
			expectProblem(
				withChange(function(t)
					t.tiers[1].items[2].weight = math.huge
				end),
				"tiers[1].items[2].weight must be a finite number > 0"
			)
			expectProblem(
				withChange(function(t)
					t.tiers[3].weight = "3"
				end),
				'tiers[3].weight must be a finite number > 0 (got "3")'
			)
		end)

		it("rejects weights whose sum overflows", function()
			expectProblem(
				withChange(function(t)
					t.tiers[1].weight = 1.7e308
					t.tiers[2].weight = 1.7e308
				end),
				"tiers: the tier weights must have a finite sum"
			)
		end)

		it("rejects a duplicate rarity", function()
			expectProblem(
				withChange(function(t)
					t.tiers[3].rarity = "Epic"
					t.tiers[3].items = { { itemId = "e2", weight = 1 } }
					t.tiers[1].items = { { itemId = "e1", weight = 1 } }
				end),
				'tiers[3].rarity "Epic" duplicates tiers[1]'
			)
		end)

		it("rejects an unknown rarity", function()
			expectProblem(
				withChange(function(t)
					t.tiers[1].rarity = "Mythic"
				end),
				'tiers[1].rarity must be one of Common, Uncommon, Rare, Epic, Legendary (got "Mythic")'
			)
		end)

		it("rejects missing or empty tiers and items", function()
			expectProblem(
				withChange(function(t)
					t.tiers = {}
				end),
				"tiers must be a non-empty list"
			)
			expectProblem(
				withChange(function(t)
					t.tiers = nil
				end),
				"tiers must be a non-empty list (got nil)"
			)
			expectProblem(
				withChange(function(t)
					t.tiers[3].items = {}
				end),
				"tiers[3].items must be a non-empty list"
			)
		end)

		it("rejects bad quantities, including more than the item's stack cap", function()
			expectProblem(
				withChange(function(t)
					t.tiers[2].items[3].qty = 0
				end),
				"tiers[2].items[3].qty must be nil or an integer >= 1 (got 0)"
			)
			expectProblem(
				withChange(function(t)
					t.tiers[2].items[3].qty = 1.5
				end),
				"tiers[2].items[3].qty must be nil or an integer >= 1"
			)
			expectProblem(
				withChange(function(t)
					t.tiers[2].items[3].qty = 4
				end),
				'tiers[2].items[3].qty 4 exceeds the stack cap of "s1" (3)'
			)
			expectProblem(
				withChange(function(t)
					t.tiers[2].items[1].qty = 2
				end),
				'tiers[2].items[1].qty 2 exceeds the stack cap of "c1" (1)'
			)
		end)

		it("rejects unreachable pity and bad pity fields", function()
			expectProblem(
				withChange(function(t)
					t.pity.minRarity = "Legendary"
				end),
				'pity.minRarity "Legendary" is unreachable: no tier is at or above it'
			)
			expectProblem(
				withChange(function(t)
					t.pity.minRarity = "Mythic"
				end),
				"pity.minRarity must be one of"
			)
			expectProblem(
				withChange(function(t)
					t.pity.afterOpens = 0
				end),
				"pity.afterOpens must be an integer >= 1 (got 0)"
			)
			expectProblem(
				withChange(function(t)
					t.pity.afterOpens = 2.5
				end),
				"pity.afterOpens must be an integer >= 1 (got 2.5)"
			)
			expectProblem(
				withChange(function(t)
					t.pity = 10
				end),
				"pity must be nil or a table (got 10)"
			)
		end)

		it("rejects an unknown currency and a bad amount", function()
			expectProblem(
				withChange(function(t)
					t.cost.currency = "gems"
				end),
				'cost.currency: unknown currency "gems"'
			)
			expectProblem(
				withChange(function(t)
					t.cost.amount = 0
				end),
				"cost.amount must be an integer >= 1 (got 0)"
			)
			-- without a currency list only the id shape is checked
			local ok, problems = RewardTables.validate(
				withChange(function(t)
					t.cost.currency = "Gems!"
				end),
				registry
			)
			expect(ok).toBe(false)
			expect(problems[1]).toContain('cost.currency must be a currency id (got "Gems!")')
		end)

		it("rejects unknown fields at every level", function()
			expectProblem(
				withChange(function(t)
					t.costs = t.cost
				end),
				'rewardTables[1] ("mixed"): unknown field "costs"'
			)
			expectProblem(
				withChange(function(t)
					t.tiers[1].wieght = 2
				end),
				'tiers[1]: unknown field "wieght"'
			)
			expectProblem(
				withChange(function(t)
					t.tiers[1].items[1].quantity = 2
				end),
				'tiers[1].items[1]: unknown field "quantity"'
			)
			expectProblem(
				withChange(function(t)
					t.pity.after = 3
				end),
				'pity: unknown field "after"'
			)
			expectProblem(
				withChange(function(t)
					t.cost.price = 3
				end),
				'cost: unknown field "price"'
			)
		end)

		it("rejects any outcome that would be shown as 0.00%", function()
			expectProblem({
				{
					id = "rare_drop",
					name = "Rare drop",
					tiers = {
						{ rarity = "Common", weight = 1e6, items = { { itemId = "c1", weight = 1 } } },
						{ rarity = "Legendary", weight = 1, items = { { itemId = "l1", weight = 1 } } },
					},
				},
			}, '"l1" (Legendary) would be shown as 0.00%')
		end)

		it("rejects config and entries of the wrong shape", function()
			expectProblem("tables", "rewardTables: must be a list of reward tables")
			expectProblem({ simpleTable("a"), 5 }, "rewardTables[2]: must be a table")
			expectProblem(
				withChange(function(t)
					t.tiers[2] = "Common"
				end),
				'tiers[2] must be a table (got "Common")'
			)
		end)

		it("collects every problem in one pass", function()
			local problems = problemsOf(withChange(function(t)
				t.tiers[1].weight = -1
				t.tiers[2].items[1].itemId = "nope"
				t.cost.amount = 0
			end))
			expect(problems).toHaveLength(3)
		end)

		it("new() errors listing every problem; validate errors on a missing registry", function()
			local ok, err = pcall(
				RewardTables.new,
				withChange(function(t)
					t.tiers[1].weight = 0
					t.pity.afterOpens = 0
				end),
				registry,
				{ "crowns" }
			)
			expect(ok).toBe(false)
			expect(tostring(err)).toContain("invalid reward tables (2)")
			expect(tostring(err)).toContain("tiers[1].weight must be")
			expect(tostring(err)).toContain("pity.afterOpens must be")
			expect(function()
				RewardTables.validate({}, nil)
			end).toThrow("itemRegistry must be an ItemRegistry")
		end)
	end)
end)
