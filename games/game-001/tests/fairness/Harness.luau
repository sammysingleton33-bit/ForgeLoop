--!strict
--[[
	Harness — Crown Arena fairness harness (FL-0076, FORGE-05; design §9, CONTRACTS G12.3).

	Monte Carlo duels between scripted duellists (Duellist) on a duel model with the G12.2 signatures
	(the gate, FairnessGate.spec, runs FORGE-01's Arena/DuelModel with config Support; run.luau and the
	harness's own specs run the local DuelDouble with the design numbers). Every setup passes CapsCheck before it duels, as
	DuelService must run Caps.check. Each cell reports the win rate of side A with a 95 % Wilson
	interval; the outcome bounds of G12.3 are then checked cell by cell.

		Harness.wilson(successes, n, z?) -> (lo, hi)
		Harness.setup(side: SideSpec, support?) -> (DuellistSetup, problems)
		Harness.duel(model, a: SideSpec, b: SideSpec, seed, options?) -> ("a" | "b" | "draw", seconds)
		Harness.runCell(cell, n, options?) -> CellResult
		Harness.plan(options?) -> { Cell }
		Harness.evaluate(results, contract?) -> { Check }
		Harness.run(options?) -> (results, checks)
		Harness.report(results, checks, meta) -> string (Markdown)

	SideSpec = { skill: "novice" | "average" | "expert", tier: SupportTier, perks: { string }?,
	             power: "pledged" | "empowered"?, weapon: string?, armour: string?, modifiers: { Modifier }? }
	             (modifiers, when given, replace the design numbers: negative tests and real config)
	Cell = { id, bound: "supportMatters" | "skillStillWins" | "noAutoWin" | nil, a: SideSpec, b: SideSpec }

	A bound FAILs when the measured rate breaks it. When the 95 % interval crosses the bound the
	check says so ("marginal"): run more duels before reading anything into it. Side A plays as
	model side "a" in even duels and "b" in odd ones, so the model's resolution order cancels out.
]]

local CapsCheck = require("./CapsCheck")
local CapsContract = require("./CapsContract")
local DesignSupport = require("./DesignSupport")
local DuelDouble = require("./DuelDouble")
local Duellist = require("./Duellist")

local Harness = {}

Harness.DEFAULT_LOADOUT = table.freeze({ weapon = "swordShield", armour = "medium" })
Harness.DEFAULT_ADORING_PERKS = table.freeze({ "reforge", "fieldRemedy", "heartyRations" })
Harness.DT = 0.05

function Harness.wilson(successes: number, n: number, z: number?): (number, number)
	if n <= 0 then
		return 0, 1
	end
	local zz = z or 1.96
	local p = successes / n
	local denominator = 1 + zz * zz / n
	local centre = (p + zz * zz / (2 * n)) / denominator
	local half = zz * math.sqrt(p * (1 - p) / n + zz * zz / (4 * n * n)) / denominator
	return math.max(0, centre - half), math.min(1, centre + half)
end

function Harness.setup(side: any, support: any?): (any, { string })
	local modifiers = side.modifiers
	if modifiers == nil then
		modifiers = (support or DesignSupport).modifiers(side.tier or "hostile", side.perks, side.power or "empowered")
	end
	local problems = CapsCheck.check(modifiers)
	return {
		weapon = side.weapon or Harness.DEFAULT_LOADOUT.weapon,
		armour = side.armour or Harness.DEFAULT_LOADOUT.armour,
		modifiers = modifiers,
	},
		problems
end

local function describe(side: any): string
	local perks = if side.perks and #side.perks > 0 then table.concat(side.perks, "+") else "-"
	local loadout = `{side.weapon or Harness.DEFAULT_LOADOUT.weapon}/{side.armour or Harness.DEFAULT_LOADOUT.armour}`
	local support = if side.modifiers then "custom modifiers" else `{side.tier or "hostile"} [{perks}]`
	return `{side.skill} {support} {loadout}`
end
Harness.describe = describe

-- One duel. a and b are SideSpecs; options = { dt?, support?, allowOverCap? }.
function Harness.duel(model: any, a: any, b: any, seed: number, options: any?): (string, number)
	local opts = options or {}
	local setupA, problemsA = Harness.setup(a, opts.support)
	local setupB, problemsB = Harness.setup(b, opts.support)
	if not opts.allowOverCap and (#problemsA > 0 or #problemsB > 0) then
		error(
			`Harness: setup breaks the G12.3 caps: {table.concat(problemsA, "; ")} {table.concat(problemsB, "; ")}`,
			2
		)
	end
	local policies = {
		a = Duellist.new(a.skill, seed * 2 + 1),
		b = Duellist.new(b.skill, seed * 2 + 2),
	}
	policies.a.side, policies.b.side = "a", "b"
	local state = model.new(nil, setupA, setupB, seed)
	local dt = opts.dt or Harness.DT
	local events = {}
	local winner = "draw"
	for _ = 1, 100000 do
		local inputs = {
			a = policies.a:act(model.view(state, "a"), events),
			b = policies.b:act(model.view(state, "b"), events),
		}
		events = model.step(state, inputs, dt)
		local done = false
		for _, event in events do
			if event.kind == "ended" then
				winner = event.data.winner
				done = true
			end
		end
		if done then
			break
		end
	end
	return winner, state.t
end

function Harness.runCell(cell: any, n: number, options: any?): any
	local opts = options or {}
	local model = opts.model or DuelDouble
	local baseSeed = opts.seed or 1
	local wins, losses, draws, seconds = 0, 0, 0, 0
	for i = 1, n do
		local seed = baseSeed * 1000003 + i
		local swap = i % 2 == 0
		local winner, t
		if swap then
			winner, t = Harness.duel(model, cell.b, cell.a, seed, opts)
			winner = if winner == "a" then "b" elseif winner == "b" then "a" else "draw"
		else
			winner, t = Harness.duel(model, cell.a, cell.b, seed, opts)
		end
		seconds += t
		if winner == "a" then
			wins += 1
		elseif winner == "b" then
			losses += 1
		else
			draws += 1
		end
	end
	local score = wins + draws / 2
	local lo, hi = Harness.wilson(score, n)
	return {
		cell = cell,
		n = n,
		wins = wins,
		losses = losses,
		draws = draws,
		rate = score / n,
		lo = lo,
		hi = hi,
		meanSeconds = seconds / n,
	}
end

-- options = { skills?, pool?, power?, loadouts?, support? }
function Harness.plan(options: any?): { any }
	local opts = options or {}
	local skills = opts.skills or Duellist.TIERS
	local pool = opts.pool or { "reforge", "fieldRemedy", "calledWarning", "heartyRations", "crowdRally" }
	local power = opts.power or "empowered"
	local support = opts.support or DesignSupport
	local adoringPerks = opts.adoringPerks or Harness.DEFAULT_ADORING_PERKS
	local cells = {}
	local function add(id: string, bound: string?, a: any, b: any)
		table.insert(cells, { id = id, bound = bound, a = a, b = b })
	end
	local function baseline(skill: string): any
		return { skill = skill, tier = "hostile", perks = {} }
	end

	for _, skill in skills do
		add(`supportMatters/{skill}`, "supportMatters", {
			skill = skill,
			tier = "adoring",
			perks = adoringPerks,
			power = power,
		}, baseline(skill))
	end
	for i = 1, #Duellist.TIERS - 1 do
		local lower, higher = Duellist.TIERS[i], Duellist.TIERS[i + 1]
		if table.find(skills, lower) or table.find(skills, higher) then
			add(`skillStillWins/{higher}>{lower}`, "skillStillWins", baseline(higher), {
				skill = lower,
				tier = "adoring",
				perks = adoringPerks,
				power = power,
			})
		end
	end
	for _, skill in skills do
		for _, tier in support.TIER_ORDER do
			for _, perks in support.perkSets(tier, pool) do
				local label = if #perks > 0 then table.concat(perks, "+") else "-"
				add(`noAutoWin/{skill}/{tier}/{label}`, "noAutoWin", {
					skill = skill,
					tier = tier,
					perks = perks,
					power = power,
				}, baseline(skill))
			end
		end
		for _, loadout in opts.loadouts or {} do
			local tag = `{loadout.weapon}/{loadout.armour}`
			add(`noAutoWin/{skill}/loadout/{tag}`, "noAutoWin", {
				skill = skill,
				tier = "hostile",
				perks = {},
				weapon = loadout.weapon,
				armour = loadout.armour,
			}, baseline(skill))
			add(`noAutoWin/{skill}/loadout+adoring/{tag}`, "noAutoWin", {
				skill = skill,
				tier = "adoring",
				perks = adoringPerks,
				power = power,
				weapon = loadout.weapon,
				armour = loadout.armour,
			}, baseline(skill))
		end
	end
	return cells
end

function Harness.allLoadouts(): { { weapon: string, armour: string } }
	local out = {}
	for _, weapon in { "swordShield", "greatsword", "spear", "mace" } do
		for _, armour in { "light", "medium", "heavy" } do
			table.insert(out, { weapon = weapon, armour = armour })
		end
	end
	return out
end

function Harness.evaluate(results: { any }, contract: any?): { any }
	local outcome = (contract or CapsContract).outcome
	local checks = {}
	for _, result in results do
		local bound = result.cell.bound
		if bound == nil then
			continue
		end
		local rate, lo, hi = result.rate, result.lo, result.hi
		local ok, rule, edges
		if bound == "supportMatters" then
			ok = rate >= outcome.supportMatters.min and rate <= outcome.supportMatters.max
			rule = `{string.format("%.0f", outcome.supportMatters.min * 100)}-{string.format(
				"%.0f",
				outcome.supportMatters.max * 100
			)} %`
			edges = { outcome.supportMatters.min, outcome.supportMatters.max }
		elseif bound == "skillStillWins" then
			ok = rate >= outcome.skillStillWins
			rule = `>= {string.format("%.0f", outcome.skillStillWins * 100)} %`
			edges = { outcome.skillStillWins }
		elseif bound == "noAutoWin" then
			ok = rate <= outcome.noAutoWin
			rule = `<= {string.format("%.0f", outcome.noAutoWin * 100)} %`
			edges = { outcome.noAutoWin }
		else
			error(`Harness.evaluate: unknown bound '{tostring(bound)}'`)
		end
		local marginal = false
		for _, edge in edges do
			if lo < edge and hi > edge then
				marginal = true
			end
		end
		table.insert(checks, {
			id = result.cell.id,
			bound = bound,
			rule = rule,
			rate = rate,
			lo = lo,
			hi = hi,
			n = result.n,
			status = if ok then "PASS" else "FAIL",
			marginal = marginal,
		})
	end
	return checks
end

-- options = plan options + { n?, seed?, model?, dt?, support?, onCell? }
function Harness.run(options: any?): ({ any }, { any })
	local opts = options or {}
	local results = {}
	for index, cell in Harness.plan(opts) do
		local result = Harness.runCell(cell, opts.n or 200, opts)
		table.insert(results, result)
		if opts.onCell then
			opts.onCell(index, result)
		end
	end
	return results, Harness.evaluate(results, opts.contract)
end

local function pct(x: number): string
	return string.format("%.1f", x * 100)
end

function Harness.report(results: { any }, checks: { any }, meta: { [string]: any }): string
	local lines = {}
	local function line(text: string)
		table.insert(lines, text)
	end
	local failed = 0
	for _, check in checks do
		if check.status == "FAIL" then
			failed += 1
		end
	end
	line("# Crown Arena fairness report (FL-0076)")
	line("")
	line(
		`- Model: **{meta.model}**{if meta.model == "DuelDouble"
			then " (local double: these numbers are NOT the game's; they prove the harness only)"
			else ""}`
	)
	line(`- Support numbers: {meta.support or "design §3/§4 (DesignSupport fixture)"}`)
	line(`- Duels per cell: {meta.n}; base seed {meta.seed}; dt {meta.dt} s; cells {#results}`)
	line(`- Bounds (CONTRACTS G12.3, PROVISIONAL): {#checks} checked, **{failed} failed**`)
	line("")
	line("| Cell | Bound | Rule | Win rate A % | 95 % CI | Status | Mean duel s |")
	line("|---|---|---|---:|---|---|---:|")
	local checkById = {}
	for _, check in checks do
		checkById[check.id] = check
	end
	for _, result in results do
		local check = checkById[result.cell.id]
		local status = if check then check.status .. (if check.marginal then " (marginal)" else "") else "-"
		line(
			`| {result.cell.id} | {result.cell.bound or "-"} | {if check then check.rule else "-"} | {pct(result.rate)} | {pct(
				result.lo
			)}-{pct(result.hi)} | {status} | {string.format("%.1f", result.meanSeconds)} |`
		)
	end
	line("")
	line("A side: " .. "the first SideSpec of each cell; B is the baseline or the opponent named in the cell id.")
	return table.concat(lines, "\n") .. "\n"
end

return Harness
