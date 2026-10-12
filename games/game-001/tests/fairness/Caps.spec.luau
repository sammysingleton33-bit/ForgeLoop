-- Crown Arena caps spec (FL-0076, FORGE-05; design §6/§9, CONTRACTS G12.3).
--
-- 1. CapsContract (the harness's copy of the caps) equals the G12.3 table in CONTRACTS.md, so a cap
--    changes only with the contract (and its DECISIONS entry).
-- 2. Every tier x perk set x power of the design numbers (§3/§4) is within the caps.
-- 3. Each way of breaking a cap is caught (negative cases).
-- 4. When FORGE-01's src/shared/Arena/Caps.luau exists, its Caps.check agrees on the same sets.
local fs = require("@lune/fs")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local CapsCheck = require("./CapsCheck")
local CapsContract = require("./CapsContract")
local DesignSupport = require("./DesignSupport")

local CONTRACTS = "games/game-001/CONTRACTS.md"
local CAPS_DIR = "games/game-001/src/shared/Arena"

-- Fractions as whole percentages (0.55 * 100 is 55.000000000000007 in doubles).
local function percent(x: number): number
	return math.floor(x * 100 + 0.5)
end

local function numbers(text: string): { number }
	local out = {}
	for token in string.gmatch(text, "%d+%.?%d*") do
		table.insert(out, tonumber(token) :: number)
	end
	return out
end

-- Rows of the G12.3 table: { label, value }.
local function g123Rows(): { { string } }
	local text = fs.readFile(T.root .. "/" .. CONTRACTS)
	local rows, inSection = {}, false
	for line in string.gmatch(text, "[^\n]+") do
		if string.match(line, "^###? ") then
			inSection = string.find(line, "G12.3", 1, true) ~= nil
		elseif inSection then
			local label, value = string.match(line, "^|%s*(.-)%s*|%s*(.-)%s*|%s*$")
			if label and label ~= "Cap" and not string.match(label, "^%-+$") then
				table.insert(rows, { label, value })
			end
		end
	end
	return rows
end

local function allSets(): { { tier: string, perks: { string }, power: string } }
	local out = {}
	for _, tier in DesignSupport.TIER_ORDER do
		for _, perks in DesignSupport.perkSets(tier, DesignSupport.PERK_ORDER) do
			for _, power in { "pledged", "empowered" } do
				table.insert(out, { tier = tier, perks = perks, power = power })
			end
		end
	end
	return out
end

local function hasProblem(problems: { string }, fragment: string): boolean
	for _, problem in problems do
		if string.find(problem, fragment, 1, true) then
			return true
		end
	end
	return false
end

local function trigger(source: string, stat: string, magnitude: number, extra: { [string]: any }?): { [string]: any }
	local m = {
		source = source,
		kind = "trigger",
		stat = stat,
		magnitude = magnitude,
		duration = 6,
		condition = "hpBelow:0.5",
	}
	for k, v in extra or {} do
		m[k] = v
	end
	return m
end

-- Over-cap sets: { name, modifiers, expected problem fragment }.
local OVER_CAP = {
	{ "passive per stat", { { source = "tier:x", kind = "passive", stat = "damage", magnitude = 0.06 } }, "per stat" },
	{
		"passive combined",
		{
			{ source = "tier:x", kind = "passive", stat = "damageReduction", magnitude = 0.05 },
			{ source = "tier:x", kind = "passive", stat = "staminaRegen", magnitude = 0.04 },
		},
		"combined",
	},
	{
		"four triggers",
		{
			trigger("perk:a", "damage", 0.05),
			trigger("perk:b", "damageReduction", 0.05),
			trigger("perk:c", "staminaRegen", 0.05),
			{ source = "perk:d", kind = "heal", magnitude = 0.05, duration = 4, condition = "hpBelow:0.35" },
		},
		"4 support triggers",
	},
	{
		"Fine Wares takes a slot",
		{
			trigger("perk:a", "damage", 0.05),
			trigger("perk:b", "damageReduction", 0.05),
			trigger("perk:c", "staminaRegen", 0.05),
			{ source = "perk:fineWares", kind = "passive", stat = "damage", magnitude = 0.02, slot = true },
		},
		"4 support triggers",
	},
	{ "trigger too long", { trigger("perk:a", "damage", 0.05, { duration = 9 }) }, "lasts 9 s" },
	{ "trigger too strong", { trigger("perk:a", "damage", 0.11) }, "cap +10.0 %" },
	{
		"stat total",
		{
			{ source = "tier:x", kind = "passive", stat = "damageReduction", magnitude = 0.06 },
			trigger("perk:a", "damageReduction", 0.10),
		},
		"can reach +16.0 %",
	},
	{ "single heal", { { source = "perk:h", kind = "heal", magnitude = 0.09, duration = 4 } }, "per trigger" },
	{
		"heal per duel",
		{
			{ source = "perk:h1", kind = "heal", magnitude = 0.06, duration = 4 },
			{ source = "perk:h2", kind = "heal", magnitude = 0.06, duration = 4 },
		},
		"per duel",
	},
	{ "quiet start", { trigger("perk:a", "damage", 0.05, { earliest = 5 }) }, "first 10 s" },
	{
		"below baseline",
		{ { source = "tier:hostile", kind = "passive", stat = "damage", magnitude = -0.02 } },
		"below baseline",
	},
	{ "acts on the opponent", { trigger("perk:a", "damage", 0.05, { affectsOpponent = true }) }, "on the opponent" },
	{ "same trigger twice", { trigger("perk:a", "damage", 0.05), trigger("perk:a", "damage", 0.05) }, "listed twice" },
	{ "unknown stat", { trigger("perk:a", "speed", 0.05) }, "unknown stat" },
	{ "unknown kind", { { source = "perk:a", kind = "stun", magnitude = 0.05, duration = 2 } }, "unknown kind" },
	{ "NaN magnitude", { trigger("perk:a", "damage", 0 / 0) }, "finite" },
}

describe("Crown Arena caps (G12.3)", function()
	it("CapsContract equals the G12.3 table in CONTRACTS.md (row by row)", function()
		local rows = g123Rows()
		expect(#rows >= 10).toBe(true)
		local seen = {}
		for _, row in rows do
			local label, value = row[1], row[2]
			local n = numbers(value)
			local numberless = string.find(label, "^Same%-stat")
				or string.find(label, "^Effects on the opponent")
				or string.find(label, "^Weak support")
			if numberless then
				-- rules without numbers, enforced by CapsCheck: stacking, affectsOpponent, below baseline
				expect(#n).toBe(0)
			elseif string.find(label, "^Passive blessing") then
				expect(n).toEqual({ percent(CapsContract.passivePerStat), percent(CapsContract.passiveCombined) })
			elseif string.find(label, "^Support triggers per duel") then
				expect(n).toEqual({ CapsContract.maxTriggers })
			elseif string.find(label, "^Trigger duration") then
				expect(n).toEqual({ CapsContract.triggerMaxSeconds, percent(CapsContract.triggerMaxMagnitude) })
			elseif string.find(label, "^Total support bonus") then
				expect(n).toEqual({ percent(CapsContract.totalPerStat) })
			elseif string.find(label, "^Support healing") then
				expect(n).toEqual({ percent(CapsContract.healPerDuel), percent(CapsContract.healPerTrigger) })
			elseif string.find(label, "^Quiet start") then
				expect(n).toEqual({ CapsContract.quietStartSeconds })
			elseif string.find(label, "^Outcome bounds") then
				local o = CapsContract.outcome
				expect(n).toEqual({
					percent(o.supportMatters.min),
					percent(o.supportMatters.max),
					percent(o.skillStillWins),
					percent(o.noAutoWin),
				})
			else
				error(`unknown G12.3 row '{label}': update CapsContract, CapsCheck and this spec`)
			end
			seen[label] = true
		end
		local count = 0
		for _ in seen do
			count += 1
		end
		expect(count).toBe(10)
	end)

	it("keeps every design tier x perk set x power within the caps (§3/§4)", function()
		local sets = allSets()
		expect(#sets > 100).toBe(true)
		for _, set in sets do
			local problems = CapsCheck.check(DesignSupport.modifiers(set.tier, set.perks, set.power))
			if #problems > 0 then
				error(`{set.tier} [{table.concat(set.perks, "+")}] {set.power}: {table.concat(problems, "; ")}`)
			end
		end
	end)

	it("counts the two-effect Crowd Rally as one trigger and allows Fine Wares at the passive cap", function()
		local rally = DesignSupport.modifiers("adoring", { "reforge", "fieldRemedy", "crowdRally" }, "empowered")
		expect(CapsCheck.check(rally)).toEqual({})
		local wares = DesignSupport.modifiers("adoring", { "reforge", "fineWares", "crowdRally" }, "empowered")
		expect(CapsCheck.check(wares)).toEqual({}) -- damage reduction 2 + 3 = 5 %, total 5 + 10 = 15 %
	end)

	it("catches every way of breaking a cap", function()
		for _, case in OVER_CAP do
			local name, modifiers, fragment = case[1], case[2], case[3]
			local problems = CapsCheck.check(modifiers :: any)
			if not hasProblem(problems, fragment) then
				error(`{name}: expected a problem containing '{fragment}', got: {table.concat(problems, "; ")}`)
			end
		end
	end)

	it("refuses design sets that do not fit the tier", function()
		expect(function()
			DesignSupport.modifiers("divided", { "reforge", "fieldRemedy", "heartyRations" }, "empowered")
		end).toThrow("2 trigger slot(s)")
		expect(function()
			DesignSupport.modifiers("loyal", { "crowdRally" }, "empowered")
		end).toThrow("needs the Adoring tier")
		expect(#DesignSupport.perkSets("hostile", DesignSupport.PERK_ORDER)).toBe(1)
	end)
end)

-- FORGE-01's Caps.luau (FL-0071) is checked against the same sets once it exists.
if fs.isDir(T.root .. "/" .. CAPS_DIR) and fs.isFile(T.root .. "/" .. CAPS_DIR .. "/Caps.luau") then
	describe("Arena/Caps.luau (FORGE-01) agrees with CapsCheck", function()
		it("accepts every design set and refuses every over-cap set", function()
			local Caps = require("@game/ReplicatedStorage/Game/Arena/Caps")
			for _, set in allSets() do
				local ok = Caps.check(DesignSupport.modifiers(set.tier, set.perks, set.power))
				expect(ok).toBe(true)
			end
			for _, case in OVER_CAP do
				local ok = Caps.check(case[2] :: any)
				if ok ~= false then
					error(`Caps.check accepted the over-cap set '{case[1]}'`)
				end
			end
		end)
	end)
end
