-- Crown Arena fairness gate (FL-0076, FORGE-05; design §6, §9; CONTRACTS G12.3).
--
-- The real thing: FORGE-01's Arena/DuelModel with the support config Support produces (Arena/SupportModel), scripted
-- duellists at three skill tiers, every support tier and perk set. It fails when an outcome bound breaks:
--   supportMatters  Adoring vs Hostile at equal skill wins 55-65 %
--   skillStillWins  one skill tier better with Hostile beats Adoring support >= 60 %
--   noAutoWin       no tier or perk set wins more than 70 % against the equal-skill Hostile baseline
-- Duels per cell: supportMatters and skillStillWins 2000 (the merge gate), noAutoWin 400 (every cell; the 2000-duel
-- sweep of all cells and loadouts is FORGE_FAIRNESS_FULL=1, about 10 min). Seeds are fixed, so a run is reproducible.
-- The report goes to roblox/build/fairness/report.md (and the CI artifact). Headless, scripted duellists: this says the
-- numbers keep support inside the bounds, not that a duel feels fair to a player.
local fs = require("@lune/fs")
local process = require("@lune/process")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local DuelModel = require("@game/ReplicatedStorage/Game/Arena/DuelModel")
local Support = require("@game/ReplicatedStorage/Forge/Config/Support")
local ConfigSupport = require("./ConfigSupport")
local Harness = require("./Harness")

local FULL = process.env.FORGE_FAIRNESS_FULL == "1"
local GATE_N = 2000
local SWEEP_N = if FULL then 2000 else 400
local REPORT_DIR = "roblox/build/fairness"

local function failures(checks: { any }): { string }
	local out = {}
	for _, check in checks do
		if check.status ~= "PASS" then
			table.insert(out, `{check.id} {string.format("%.1f", check.rate * 100)} % ({check.rule})`)
		end
	end
	return out
end

-- The pre-trim numbers (fieldRemedy 5 % / 8 %, Adoring passive +2 %): measured over the supportMatters bound in
-- FL-0076's first run, so the gate must fail on them.
local function overStrongConfig(): any
	local cfg = table.clone(Support)
	cfg.tiers = table.clone(Support.tiers)
	cfg.tiers.adoring = table.clone(Support.tiers.adoring)
	cfg.tiers.adoring.passive = { damageReduction = 0.02, staminaRegen = 0.02 }
	cfg.perks = table.clone(Support.perks)
	cfg.perks.fieldRemedy = table.clone(Support.perks.fieldRemedy)
	cfg.perks.fieldRemedy.pledged = 0.05
	cfg.perks.fieldRemedy.empowered = 0.08
	return cfg
end

describe("Crown Arena fairness gate (real DuelModel, config Support)", function()
	it("keeps every outcome bound", function()
		local support = ConfigSupport.new()
		local options = {
			model = DuelModel,
			support = support,
			loadouts = if FULL then Harness.allLoadouts() else nil,
		}
		local results = {}
		for _, cell in Harness.plan(options) do
			local n = if cell.bound == "noAutoWin" then SWEEP_N else GATE_N
			table.insert(results, Harness.runCell(cell, n, options))
		end
		local checks = Harness.evaluate(results)
		local report = Harness.report(results, checks, {
			model = "DuelModel",
			support = "config Support (Arena/SupportModel)",
			n = `{GATE_N} (supportMatters, skillStillWins) / {SWEEP_N} (noAutoWin)`,
		})
		pcall(fs.writeDir, REPORT_DIR)
		pcall(fs.writeFile, `{REPORT_DIR}/report.md`, report)
		local worst = { supportMatters = {}, skillStillWins = math.huge, noAutoWin = 0 }
		for _, check in checks do
			if check.bound == "supportMatters" then
				table.insert(worst.supportMatters, string.format("%.1f", check.rate * 100))
			elseif check.bound == "skillStillWins" then
				worst.skillStillWins = math.min(worst.skillStillWins, check.rate)
			else
				worst.noAutoWin = math.max(worst.noAutoWin, check.rate)
			end
		end
		print(
			`fairness: {#checks} bounds; supportMatters {table.concat(worst.supportMatters, " / ")} %, `
				.. `skillStillWins min {string.format("%.1f", worst.skillStillWins * 100)} %, `
				.. `noAutoWin max {string.format("%.1f", worst.noAutoWin * 100)} % (report {REPORT_DIR}/report.md)`
		)
		expect(failures(checks)).toEqual({})
	end)

	it("fails on support that is too strong (the pre-trim numbers)", function()
		local support = ConfigSupport.new(overStrongConfig())
		local cell
		for _, candidate in Harness.plan({ support = support, skills = { "average" } }) do
			if candidate.bound == "supportMatters" then
				cell = candidate
			end
		end
		assert(cell, "no supportMatters cell")
		local result = Harness.runCell(cell, GATE_N, { model = DuelModel, support = support })
		local checks = Harness.evaluate({ result })
		expect(checks[1].status).toBe("FAIL")
	end)

	-- A perk picked twice must be refused or count once: a second copy of the same perk is never more support
	-- (FORGE-00, the Fine Wares double-count FORGE-01 fixed). Checked for every perk and both powers.
	it("never stacks a repeated pick", function()
		local support = ConfigSupport.new()
		local function key(m: any): string
			return `{m.source}|{m.kind}|{tostring(m.stat)}|{tostring(m.magnitude)}|{tostring(m.lead)}|{tostring(
				m.condition
			)}`
		end
		local function counts(mods: { any }): { [string]: number }
			local out = {}
			for _, m in mods do
				out[key(m)] = (out[key(m)] or 0) + 1
			end
			return out
		end
		local stacked = {}
		for name in Support.perks do
			for _, power in { "pledged", "empowered" } do
				local ok, twice = pcall(support.modifiers, "adoring", { name, name }, power)
				if ok then
					local once = support.modifiers("adoring", { name }, power)
					local a, b = counts(once), counts(twice)
					for k, n in b do
						if (a[k] or 0) ~= n then
							table.insert(stacked, `{name} ({power}): {k} x{n}`)
						end
					end
				end
			end
		end
		table.sort(stacked)
		expect(stacked).toEqual({})
	end)

	it("a repeated-pick loadout stays under noAutoWin", function()
		local support = ConfigSupport.new()
		local side = { skill = "average", tier = "adoring", perks = { "fineWares", "fineWares", "fieldRemedy" } }
		local ok = pcall(support.modifiers, side.tier, side.perks, "empowered")
		if not ok then
			return -- refused at the source: nothing to measure
		end
		local cell = {
			id = "noAutoWin/average/adoring/fineWares+fineWares+fieldRemedy",
			bound = "noAutoWin",
			a = side,
			b = { skill = "average", tier = "hostile", perks = {} },
		}
		local result = Harness.runCell(cell, SWEEP_N, { model = DuelModel, support = support })
		local checks = Harness.evaluate({ result })
		print(`fairness: repeated pick {cell.id} {string.format("%.1f", result.rate * 100)} %`)
		expect(checks[1].status).toBe("PASS")
	end)

	it("reads the game's support numbers, not the design fixture", function()
		local support = ConfigSupport.new()
		local mods = support.modifiers("adoring", { "fieldRemedy" }, "empowered")
		local heal, passive = nil, nil
		for _, m in mods do
			if m.source == "perk:fieldRemedy" then
				heal = m.magnitude
			elseif m.source == "tier:adoring" and m.stat == "damageReduction" then
				passive = m.magnitude
			end
		end
		expect(heal).toBe(Support.perks.fieldRemedy.empowered)
		expect(passive).toBe(Support.tiers.adoring.passive.damageReduction)
	end)
end)
