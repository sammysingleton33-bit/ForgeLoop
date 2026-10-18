--[[
	FORGE-05 balance probe: VS-1 slice pacing, headless (Lune + MockEnv; NOT a Studio play test).

	Every real server service of both trees on one MockEnv per run, slice mode (config Match.mode), default
	job quotas (config Kingdoms.startCitizens), one human (userId 1) seated in crimson. The scripted human
	acts through the real remotes (Build.GetSlots, Build.PlaceSlot, Army.Recruit, Army.Command) with
	virtual time; times are simulation seconds since Founding began (= the human's join, slice Lobby 0 s).

	Profiles (one run per seed):
		A   greedy: House on the free fitting build slot nearest the keep as soon as the treasury affords
		    it, then a Barracks as soon as affordable, recruit 3 soldiers once the Barracks stands and the
		    price is affordable, Army.Command({}, "capture") once all 3 are trained. Lower bound.
		Abf greedy, barracks first (no House).
		B   idle: the human does nothing for LIMIT seconds (or until the match ends). Records what the AI
		    kingdoms do and when the treasury first affords a Barracks with nothing built.
		C   onboarding-paced: like A, but the House waits for Spawn + InspectCitizen + BuildOnPlot expectSec,
		    the recruit for the Recruit expectSec after the House and Send for the Capture expectSec after
		    the recruit (config Onboarding; AnswerCitizen is passed over while ConversationService is
		    absent, exactly as OnboardingService does).
		What-ifs (only with FORGE_PACING_FULL=1; NOT main behaviour): the AI governor on and every kingdom
		populated at start, as match mode does for kingdoms without a ruler (MatchHost.new wrapped in this
		spec: match.aiRulers = true, match.populateOnJoin = false). Bai = B, Cai = C, Dai = A with Send
		held until LATE_SEND (480 s, after the AI armies reach the tower). Only the error checks apply.
	Client controllers are not booted: the scripted human calls the remotes they call.
	Prints PACING lines (per run, then a seed/median/target table per profile). Asserts only robust facts:
	no error logs or thread errors, milestones in order, the greedy capture before LIMIT, each charge once.
	It never asserts target compliance: Pacing.luau targets are tuning goals.

	Speed: Sim/WorldView.sync (server-side placeholder/Kit building models; presentation only, nothing in
	the simulation reads it) runs on every 1/16 s tick and was ~78 % of this spec's wall time in MockEnv, so
	each run syncs it once per virtual second instead. Default (check.sh): seeds 1-3, B to 900 s, about 40 s
	of wall time. FORGE_PACING_FULL=1: seeds 1-5 plus the what-ifs, about 4.5 minutes.
]]
local fs = require("@lune/fs")
local process = require("@lune/process")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Costs = require("@game/ReplicatedStorage/Forge/Config/Costs")
local OnboardingConfig = require("@game/ReplicatedStorage/Forge/Config/Onboarding")
local PacingConfig = require("@game/ReplicatedStorage/Forge/Config/Pacing")
local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local MatchHost = require("@game/ReplicatedStorage/Game/Kingdom/MatchHost")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")

local FULL = process.env.FORGE_PACING_FULL == "1"
local SEEDS = if FULL then { 1, 2, 3, 4, 5 } else { 1, 2, 3 }
local LIMIT = 900 -- virtual seconds per run at most
local STEP = 0.5 -- the scripted human looks at the treasury this often
local VIEW_EVERY = 1 -- WorldView.sync period in virtual seconds (see the header)
local USER_ID = 1
local HUMAN = "crimson"
local RESOURCES = { "food", "wood", "stone", "gold" }
local TARGETS = PacingConfig.targets

local SERVER_TREES = {
	{ dir = "roblox/src/server/Services", dm = "ServerScriptService/Forge/Services" },
	{ dir = "games/game-001/src/server/Services", dm = "ServerScriptService/Game/Services" },
}
local SHARED_ROOTS = {
	{ dir = "roblox/src/shared", dm = "ReplicatedStorage/Forge" },
	{ dir = "games/game-001/src/shared", dm = "ReplicatedStorage/Game" },
}

local function moduleNames(dir: string): { string }
	local names = {}
	local full = T.root .. "/" .. dir
	for _, entry in fs.readDir(full) do
		local name = string.match(entry, "^(.-)%.luau$")
		if name and not string.find(name, "%.") and fs.isFile(full .. "/" .. entry) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

local function definitionsIn(trees)
	local definitions = {}
	for _, tree in trees do
		for _, name in moduleNames(tree.dir) do
			table.insert(definitions, Loader.validate(require(`@game/{tree.dm}/{name}`), `{tree.dir}/{name}`))
		end
	end
	return definitions
end

local function remotesByArea()
	local result = {}
	for _, root in SHARED_ROOTS do
		local full = T.root .. "/" .. root.dir
		for _, area in fs.readDir(full) do
			if fs.isDir(`{full}/{area}`) and fs.isFile(`{full}/{area}/Remotes.luau`) then
				result[area] = require(`@game/{root.dm}/{area}/Remotes`)
			end
		end
	end
	return result
end

-- Resolved once while the file loads: Lune's fs calls yield, and a test that yields must finish within the
-- harness's 5 s (real time) budget, so no test touches the file system.
local SERVER_DEFINITIONS = definitionsIn(SERVER_TREES)
local REMOTES = remotesByArea()

-- KingdomService character adapter: no character in MockEnv (so no ruler gathering or ruler presence)
local ADAPTER = {
	partyOf = function()
		return nil
	end,
	load = function()
		return nil
	end,
	pivot = function() end,
	attach = function() end,
	onDied = function()
		return nil
	end,
	respawnDelay = function()
		return 5
	end,
}

-- ---------------------------------------------------------------- formatting
local function fmt(value: number?): string
	if value == nil then
		return "-"
	end
	return string.format("%.1f", value)
end

local function stockText(stock: { [string]: number }?): string
	if stock == nil then
		return "-"
	end
	return `f{math.floor(stock.food)}/w{math.floor(stock.wood)}/s{math.floor(stock.stone)}`
end

local function median(values: { number }): number?
	if #values == 0 then
		return nil
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	local n = #sorted
	if n % 2 == 1 then
		return sorted[(n + 1) / 2]
	end
	return (sorted[n / 2] + sorted[n / 2 + 1]) / 2
end

local function countsText(counts: { [string]: number }): string
	local parts = {}
	for key, n in counts do
		table.insert(parts, `{key}x{n}`)
	end
	table.sort(parts)
	return if #parts == 0 then "none" else table.concat(parts, ",")
end

-- ---------------------------------------------------------------- one server
local function boot(seed: number, matchOverrides: { [string]: any }?)
	local env = MockEnv.new({ seed = seed, sharedModules = { Remotes = REMOTES } })
	local newHost = MatchHost.new
	if matchOverrides then
		MatchHost.new = function(hostEnv: any, remotes: any, options: any)
			local opts = table.clone(options or {})
			opts.match = table.clone(opts.match or {})
			for key, value in matchOverrides do
				opts.match[key] = value
			end
			return newHost(hostEnv, remotes, opts)
		end
	end
	-- This probe measures the VS-1 slice: pin slice mode with PvP off while the services start (MatchService
	-- reads the mode and Match reads pvp when they are built), whatever the default config is (D-053: match).
	local savedMode, savedPvp = MatchConfig.mode, MatchConfig.pvp.enabled
	MatchConfig.mode, MatchConfig.pvp.enabled = "slice", false
	local ok, server = pcall(Loader.load, env, SERVER_DEFINITIONS)
	MatchConfig.mode, MatchConfig.pvp.enabled = savedMode, savedPvp
	MatchHost.new = newHost
	assert(ok, tostring(server))
	server:get("KingdomService").adapter = ADAPTER
	local match = server:get("MatchService")
	local host = match.host
	local sim = host.match.sim
	local view = host._view
	if view then
		local sync = view.sync
		local nextAt = -math.huge
		view.sync = function(self: any, s: any)
			if s.time >= nextAt then
				nextAt = s.time + VIEW_EVERY
				sync(self, s)
			end
		end
	end
	local run = {
		env = env,
		server = server,
		match = match,
		host = host,
		sim = sim,
		seed = seed,
		charges = {},
		events = {},
		firsts = {}, -- [kingdomId] = { [eventKey] = { t, stock } }
		refusals = {},
	}
	local function stock(kid: string): { [string]: number }
		local bag = {}
		for _, res in RESOURCES do
			bag[res] = sim:balance(kid, res)
		end
		return bag
	end
	run.stock = stock
	-- spy on the treasury (pass-through): every spend and upkeep charge, with its txId and sink
	local treasury = server:get("TreasuryService")
	local spend, spendUpTo = treasury.spend, treasury.spendUpTo
	treasury.spend = function(self: any, kingdom: string, cost: any, txId: string, sink: string)
		local paid = spend(self, kingdom, cost, txId, sink)
		table.insert(
			run.charges,
			{ t = sim.time, kingdom = kingdom, cost = table.clone(cost), txId = txId, sink = sink, ok = paid }
		)
		return paid
	end
	treasury.spendUpTo = function(self: any, kingdom: string, res: string, amount: number, txId: string, sink: string)
		local taken = spendUpTo(self, kingdom, res, amount, txId, sink)
		table.insert(
			run.charges,
			{ t = sim.time, kingdom = kingdom, cost = { [res] = taken }, txId = txId, sink = sink, ok = true }
		)
		return taken
	end
	-- every simulation/match event of interest, with the treasury of its kingdom at that moment
	host.events:connect(function(name: string, event: any)
		local kid = event.kingdomId
		local entry = { t = sim.time, name = name, event = event, stock = if kid then stock(kid) else nil }
		if name ~= "ResourceGathered" and name ~= "ObjectiveProgress" then
			table.insert(run.events, entry)
		end
		if kid then
			local key = name
			if name == "ResourceGathered" then
				key = name .. ":" .. tostring(event.resource)
			elseif name == "BuildingPlaced" or name == "BuildingCompleted" then
				key = name .. ":" .. tostring(event.kind)
			end
			local firsts = run.firsts[kid] or {}
			run.firsts[kid] = firsts
			if firsts[key] == nil then
				firsts[key] = entry
			end
			if name ~= "ResourceGathered" and firsts[name] == nil then
				firsts[name] = entry
			end
		end
	end)
	local player = env.mock.players:add({ userId = USER_ID, name = "Probe" })
	env.mock:advance(STEP)
	run.player = player
	run.kingdom = sim.kingdoms[host:kingdomOf(player)]
	return run
end

local function teardown(run: any)
	run.server:destroy()
	GameEvents.disconnectAll()
end

local function logsAt(run: any, level: string): { string }
	local out = {}
	for _, entry in run.env.mock.logs do
		if entry.level == level then
			table.insert(out, `{entry.message} {tostring(entry.fields and entry.fields.error)}`)
		end
	end
	return out
end

local function invoke(run: any, area: string, name: string, ...: any): { [number]: any, n: number }
	local remote = run.env.ReplicatedStorage.ForgeRemotes[area][name]
	local args = table.pack(...)
	local result = { n = 0 }
	run.env.mock.remotes:asClient(run.player, function()
		result = table.pack(remote:InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return result
end

local function fire(run: any, area: string, name: string, ...: any)
	local remote = run.env.ReplicatedStorage.ForgeRemotes[area][name]
	local args = table.pack(...)
	run.env.mock.remotes:asClient(run.player, function()
		remote:FireServer(table.unpack(args, 1, args.n))
	end)
end

local function refuse(run: any, what: string, code: any)
	local key = `{what}:{tostring(code)}`
	run.refusals[key] = (run.refusals[key] or 0) + 1
end

-- The free build slot nearest the keep that fits `kind` (Build.GetSlots over the remote, Build/Fit rule).
local function pickSlot(run: any, kind: string): string?
	local answer = invoke(run, "Build", "GetSlots")
	local slots = answer[1]
	if type(slots) ~= "table" then
		refuse(run, "GetSlots", answer[2] or "no_answer")
		return nil
	end
	local centres = {}
	for _, def in Layout.WORLD.plots[run.kingdom.id].buildSlots do
		centres[def.id] = def.center
	end
	local keep = run.sim.buildings[run.kingdom.keepId]
	local best, bestDistance = nil, math.huge
	for _, slot in slots do
		local centre = centres[slot.id]
		if slot.occupiedBy == nil and centre and Fit.fits(kind, slot.size) then
			local d = (centre.X - keep.x) ^ 2 + (centre.Z - keep.z) ^ 2
			if d < bestDistance then
				best, bestDistance = slot.id, d
			end
		end
	end
	return best
end

local function scaled(cost: { [string]: number }, n: number): { [string]: number }
	local out = {}
	for res, amount in cost do
		out[res] = amount * n
	end
	return out
end

local function firstEvent(run: any, name: string, filter: (any) -> boolean): any?
	for _, entry in run.events do
		if entry.name == name and filter(entry.event) then
			return entry
		end
	end
	return nil
end

local function chargesOf(run: any, kid: string, sink: string): { any }
	local out = {}
	for _, charge in run.charges do
		if charge.kingdom == kid and charge.sink == sink and charge.ok then
			table.insert(out, charge)
		end
	end
	return out
end

local function foodSpentOn(run: any, kid: string, sink: string, untilT: number): number
	local total = 0
	for _, charge in chargesOf(run, kid, sink) do
		if charge.t <= untilT then
			total += charge.cost.food or 0
		end
	end
	return total
end

-- ---------------------------------------------------------------- the scripted human (A, Abf, C)
local function expectSec(stepId: string): number
	for _, flow in OnboardingConfig.flows do
		for _, step in flow.steps do
			if step.id == stepId then
				return step.expectSec or 0
			end
		end
	end
	return 0
end

-- gate(stepName, marks): the earliest virtual second the human takes that step (greedy: 0)
local function greedyGate(_step: string, _marks: any): number
	return 0
end

local function onboardingGate(run: any): (string, any) -> number
	local answer = if run.server:find("ConversationService") then expectSec("AnswerCitizen") else 0
	return function(step: string, marks: any): number
		if step == "build1" then
			return expectSec("Spawn") + expectSec("InspectCitizen") + expectSec("BuildOnPlot")
		elseif step == "recruit" then
			return (marks.build1 or math.huge) + answer + expectSec("Recruit")
		elseif step == "send" then
			return (marks.recruit or math.huge) + expectSec("Capture")
		end
		return 0
	end
end

-- Send no earlier than `at` (what-if Dai: a human who arrives after the AI armies)
local function lateSendGate(at: number): (run: any) -> (string, any) -> number
	return function(_run: any)
		return function(step: string, _marks: any): number
			return if step == "send" then at else 0
		end
	end
end

-- The watchtower at the end of a run: owner, contest flag, progress and which kingdoms have soldiers in it.
local function objectiveState(sim: any): string
	local o = sim.objectives.list[1]
	local present = {}
	for _, uid in sim.unitOrder do
		local u = sim.units[uid]
		if u and u.alive and (u.x - o.x) ^ 2 + (u.z - o.z) ^ 2 <= o.radius * o.radius then
			present[u.kingdomId] = (present[u.kingdomId] or 0) + 1
		end
	end
	local progress = {}
	for _, kid in sim.kingdomOrder do
		if (o.progress[kid] or 0) > 0 then
			table.insert(progress, `{kid}={string.format("%.2f", o.progress[kid])}`)
		end
	end
	return `owner {tostring(o.owner)}, contested {tostring(o.contested)}, progress [{table.concat(progress, ",")}], soldiers in zone {countsText(
		present
	)}`
end

local function lane(seed: number, profile: any): any
	local label, plan = profile.label, profile.plan
	local run = boot(seed, profile.overrides)
	local sim, k = run.sim, run.kingdom
	local gate = profile.gate(run)
	local marks = {} -- driver-side times: build<i>, recruit, send, trained, arrive, workStart:<kind>, enough:<res>
	local ids = {}
	local stage = 1
	local soldierCost = scaled((Costs.unit("soldier") :: any).cost, 3)
	local barracksCost = (Costs.building("barracks", 1) :: any).cost
	local sentAt = nil
	local lastProgress = {}
	local objective = sim.objectives.list[1]
	while sim.time < LIMIT and run.match:getPhase() ~= "Results" do
		run.env.mock:advance(STEP)
		local t = sim.time
		-- observations
		for kind, bid in ids do
			local b = sim.buildings[bid]
			if b and marks["workStart:" .. kind] == nil and (b.progress > 0 or b.level >= 1) then
				marks["workStart:" .. kind] = t
			end
			-- a site that made no progress during the last STEP (before or after its first work), and how
			-- much of that was night (citizens sleep: Citizens.nightStart)
			if b and b.level < 1 then
				if b.progress == lastProgress[kind] then
					marks["stalled:" .. kind] = (marks["stalled:" .. kind] or 0) + STEP
					if sim:isNight() then
						marks["stalledNight:" .. kind] = (marks["stalledNight:" .. kind] or 0) + STEP
					end
				end
				lastProgress[kind] = b.progress
			end
		end
		if marks.build1 and not ids.barracks then
			for res, amount in barracksCost do
				if marks["enough:" .. res] == nil and sim:balance(k.id, res) >= amount then
					marks["enough:" .. res] = t
				end
			end
		end
		local barracks = ids.barracks and sim.buildings[ids.barracks]
		if barracks and barracks.level >= 1 and marks.recruit == nil then
			for res, amount in soldierCost do
				if marks["recruitEnough:" .. res] == nil and sim:balance(k.id, res) >= amount then
					marks["recruitEnough:" .. res] = t
				end
			end
		end
		if marks.arrive == nil and (objective.progress[k.id] or 0) > 0 then
			marks.arrive = t
		end
		if marks.trained == nil and marks.recruit and #k.unitIds >= 3 then
			marks.trained = t
		end
		-- actions
		if stage <= #plan then
			local kind = plan[stage]
			local price = (Costs.building(kind, 1) :: any).cost
			if t >= gate("build" .. stage, marks) and sim:canAfford(k.id, price) then
				local slot = pickSlot(run, kind)
				if slot == nil then
					refuse(run, "PlaceSlot", "no_free_slot")
				else
					local answer = invoke(run, "Build", "PlaceSlot", slot, kind)
					if answer[1] then
						ids[kind] = answer[1]
						marks["build" .. stage] = t
						stage += 1
					else
						refuse(run, "PlaceSlot", answer[2])
					end
				end
			end
		elseif stage == #plan + 1 then
			local b = sim.buildings[ids.barracks]
			if b and b.level >= 1 and t >= gate("recruit", marks) and sim:canAfford(k.id, soldierCost) then
				local answer = invoke(run, "Army", "Recruit", ids.barracks, "soldier", 3)
				if answer[1] == true then
					marks.recruit = t
					stage += 1
				else
					refuse(run, "Recruit", answer[2])
				end
			end
		elseif stage == #plan + 2 then
			-- Army.Command is an event (no answer): the order counts once the host reports UnitsOrdered
			local accepted = sentAt ~= nil
				and firstEvent(run, "UnitsOrdered", function(event)
						return event.kingdomId == k.id and event.kind == "capture" and event.count >= 3
					end)
					~= nil
			if accepted then
				marks.send = sentAt
				stage += 1
			elseif marks.trained and t >= gate("send", marks) and (sentAt == nil or t - sentAt >= 2) then
				if sentAt ~= nil then
					refuse(run, "Command", "no_UnitsOrdered")
				end
				fire(run, "Army", "Command", {}, "capture")
				sentAt = t
			end
		end
	end
	run.env.mock:advance(2) -- a little past the end: late errors and a second MatchEnded would show
	run.label = label
	run.plan = plan
	run.marks = marks
	run.ids = ids
	run.objectiveEnd = objectiveState(sim)
	teardown(run)
	return run
end

-- Milestone times of a lane run, from the host's events (exact simulation times).
local function milestones(run: any): { [string]: any }
	local kid = HUMAN
	local function byHuman(event: any): boolean
		return event.kingdomId == kid and event.by == USER_ID
	end
	local out = {}
	local first = firstEvent(run, "BuildingPlaced", byHuman)
	out.firstBuildPlaced = first
	if first then
		local bid = first.event.buildingId
		out.firstBuildingComplete = firstEvent(run, "BuildingCompleted", function(event)
			return event.buildingId == bid and event.level == 1
		end)
	end
	local barracksPlaced = firstEvent(run, "BuildingPlaced", function(event)
		return byHuman(event) and event.kind == "barracks"
	end)
	out.barracksPlaced = barracksPlaced
	if barracksPlaced then
		local bid = barracksPlaced.event.buildingId
		out.barracksComplete = firstEvent(run, "BuildingCompleted", function(event)
			return event.buildingId == bid and event.level == 1
		end)
	end
	out.firstRecruit = firstEvent(run, "RecruitQueued", byHuman)
	local trained = 0
	for _, entry in run.events do
		if entry.name == "UnitRecruited" and entry.event.kingdomId == kid then
			trained += 1
			if trained == 3 then
				out.trained = entry
			end
		end
	end
	out.send = firstEvent(run, "UnitsOrdered", byHuman)
	out.firstCapture = firstEvent(run, "ObjectiveCaptured", function()
		return true
	end)
	out.ended = firstEvent(run, "MatchEnded", function()
		return true
	end)
	return out
end

local MILESTONE_ROWS = {
	{ key = "firstBuildPlaced", target = "firstBuildPlacedSec" },
	{ key = "firstBuildingComplete", target = "firstBuildingCompleteSec" },
	{ key = "barracksPlaced" },
	{ key = "barracksComplete" },
	{ key = "firstRecruit", target = "firstRecruitSec" },
	{ key = "trained" },
	{ key = "send" },
	{ key = "arrive" }, -- driver mark: first tick with crimson capture progress
	{ key = "firstCapture", target = "firstCaptureSec" },
}

local function timeOf(run: any, m: any, key: string): number?
	if key == "arrive" then
		return run.marks.arrive
	end
	return m[key] and m[key].t
end

local function printLane(run: any, m: any)
	local firsts = run.firsts[HUMAN] or {}
	local marks = run.marks
	local parts = {}
	for _, row in MILESTONE_ROWS do
		local entry = m[row.key]
		local stock = if entry then " [" .. stockText(entry.stock) .. "]" else ""
		table.insert(parts, `{row.key} {fmt(timeOf(run, m, row.key))}{if entry then stock else ""}`)
	end
	print(`PACING {run.label} seed {run.seed}: {table.concat(parts, " · ")}`)
	local sites = {}
	for _, kind in run.plan do
		table.insert(
			sites,
			`{kind} work starts {fmt(marks["workStart:" .. kind])}, stalled {fmt(marks["stalled:" .. kind] or 0)} s (night {fmt(
				marks["stalledNight:" .. kind] or 0
			)} s)`
		)
	end
	local deposits = {}
	for _, res in { "food", "wood", "stone" } do
		local entry = firsts["ResourceGathered:" .. res]
		table.insert(deposits, `{res} {fmt(entry and entry.t)}`)
	end
	print(
		`PACING {run.label} seed {run.seed} sites: {table.concat(sites, "; ")}; barracks price reached: wood {fmt(
			marks["enough:wood"]
		)} stone {fmt(marks["enough:stone"])}; recruit price reached: food {fmt(marks["recruitEnough:food"])} wood {fmt(
			marks["recruitEnough:wood"]
		)}; first citizen deposits {table.concat(deposits, " ")}`
	)
	local ended = m.ended and m.ended.event
	print(
		`PACING {run.label} seed {run.seed} end: births {#chargesOf(run, HUMAN, "population")} (food {foodSpentOn(
			run,
			HUMAN,
			"population",
			math.huge
		)}); upkeep charges {#chargesOf(run, HUMAN, "upkeep")} (food {foodSpentOn(run, HUMAN, "upkeep", math.huge)}); citizens {#run.kingdom.citizenIds} soldiers {#run.kingdom.unitIds}; refusals {countsText(
			run.refusals
		)}; errors {#logsAt(run, "error")}; thread errors {#run.env.mock.threadErrors}; phase {run.match:getPhase()}; winner {tostring(
			ended and ended.winner
		)} ({tostring(ended and ended.reason)}); watchtower {run.objectiveEnd}`
	)
end

local function printTable(label: string, runs: { any }, ms: { any })
	print(`PACING {label} table (seconds after spawn; dev = (median - target) / target; ! = |dev| > 25 %)`)
	local seedHeader = {}
	for _, run in runs do
		table.insert(seedHeader, `s{run.seed}`)
	end
	print(`PACING {label} | milestone | {table.concat(seedHeader, " | ")} | median | target | dev`)
	for _, row in MILESTONE_ROWS do
		local values, cells = {}, {}
		for i, run in runs do
			local value = timeOf(run, ms[i], row.key)
			table.insert(cells, fmt(value))
			if value then
				table.insert(values, value)
			end
		end
		local mid = if #values == #runs then median(values) else nil
		local target = if row.target then TARGETS[row.target] else nil
		local dev = "-"
		if mid and target then
			local pct = (mid - target) / target * 100
			dev = string.format("%+.0f%%%s", pct, if math.abs(pct) > 25 then " !" else "")
		end
		print(
			`PACING {label} | {row.key} | {table.concat(cells, " | ")} | {fmt(mid)} | {if target
				then tostring(target)
				else "-"} | {dev}`
		)
	end
	-- firstGatherSec is a ruler gather (Kingdom.Gather needs a character, absent in MockEnv; onboarding v2
	-- has no gather step): not measured. The citizens' first deposit is shown for context only.
	-- FORGE-04's #98 renames the target to firstDepositSec: read either name, so the merge order is free.
	local gatherTarget = TARGETS.firstDepositSec or TARGETS.firstGatherSec
	local deposits = {}
	for _, run in runs do
		local earliest = math.huge
		for key, entry in run.firsts[HUMAN] or {} do
			if string.find(key, "^ResourceGathered:") then
				earliest = math.min(earliest, entry.t)
			end
		end
		table.insert(deposits, earliest)
	end
	print(
		`PACING {label} | firstGather (ruler) | not measured headless | target {gatherTarget} | citizens' first deposit median {fmt(
			median(deposits)
		)}`
	)
end

-- Robust facts only (never target compliance).
local function checkLane(run: any, m: any)
	expect(logsAt(run, "error")).toEqual({})
	expect(run.env.mock.threadErrors).toEqual({})
	expect(run.kingdom.id).toBe(HUMAN)
	local order = {}
	for _, key in run.plan do
		table.insert(order, if key == "house" then "firstBuildPlaced" else "barracksPlaced")
	end
	for _, entry in { "barracksComplete", "firstRecruit", "trained", "send", "arrive", "firstCapture" } do
		table.insert(order, entry)
	end
	local last = -1
	for _, key in order do
		local t = timeOf(run, m, key)
		assert(t ~= nil, `{run.label} seed {run.seed}: {key} never happened`)
		assert(t >= last, `{run.label} seed {run.seed}: {key} at {t} before the previous milestone ({last})`)
		last = t
	end
	assert(m.firstBuildingComplete and m.firstBuildingComplete.t > m.firstBuildPlaced.t, "first building completes")
	expect(m.firstCapture.event.kingdomId).toBe(HUMAN)
	expect(m.firstCapture.t < LIMIT).toBe(true)
	expect(m.ended.event.winner).toBe(HUMAN)
	expect(run.match:getPhase()).toBe("Results")
	-- each charge once: one per building placed, one recruit of 3 at the full price
	for _, kind in run.plan do
		local paid = chargesOf(run, HUMAN, "building:" .. kind)
		expect(#paid).toBe(1)
		expect(paid[1].cost).toEqual((Costs.building(kind, 1) :: any).cost)
	end
	local recruits = chargesOf(run, HUMAN, "unit:soldier")
	expect(#recruits).toBe(1)
	expect(recruits[1].cost).toEqual(scaled((Costs.unit("soldier") :: any).cost, 3))
	local queued = 0
	for _, entry in run.events do
		if entry.name == "RecruitQueued" and entry.event.kingdomId == HUMAN then
			queued += 1
		end
	end
	expect(queued).toBe(1)
	local ended = 0
	for _, entry in run.events do
		if entry.name == "MatchEnded" then
			ended += 1
		end
	end
	expect(ended).toBe(1)
	expect(#run.env.mock.remotes:sent("Ended")).toBe(1)
end

local function profileLanes(profile: any)
	local runs, ms = {}, {}
	for _, seed in profile.seeds or SEEDS do
		local run = lane(seed, profile)
		local m = milestones(run)
		printLane(run, m)
		table.insert(runs, run)
		table.insert(ms, m)
	end
	printTable(profile.label, runs, ms)
	for i, run in runs do
		if profile.whatIf then
			-- a what-if may legitimately never capture: only the error checks apply
			expect(logsAt(run, "error")).toEqual({})
			expect(run.env.mock.threadErrors).toEqual({})
		else
			checkLane(run, ms[i])
		end
	end
end

local function greedy(_run: any)
	return greedyGate
end

-- What-if (FORGE_PACING_FULL=1 only, NOT main behaviour): what match mode does for kingdoms without a
-- ruler (Kingdom/Match: aiRulers, populateOnJoin), applied to the slice.
local AI_ON = { aiRulers = true, populateOnJoin = false }
local WHAT_IF_SEEDS = { 1, 2, 3 }
local LATE_SEND = 480

-- ---------------------------------------------------------------- idle human (B) and the what-if (Bai)
local function idle(seed: number, label: string, overrides: { [string]: any }?): any
	local run = boot(seed, overrides)
	local sim, k = run.sim, run.kingdom
	local barracksCost = (Costs.building("barracks", 1) :: any).cost
	local marks = {}
	local gatheredAt = {}
	while sim.time < LIMIT and run.match:getPhase() ~= "Results" do
		run.env.mock:advance(STEP)
		local t = sim.time
		if marks.affordBarracks == nil and sim:canAfford(k.id, barracksCost) then
			marks.affordBarracks = t
			marks.affordStock = run.stock(k.id)
		end
		for res, amount in barracksCost do
			if marks["enough:" .. res] == nil and sim:balance(k.id, res) >= amount then
				marks["enough:" .. res] = t
			end
		end
		for _, at in { 60, 120, 300 } do
			if gatheredAt[at] == nil and t >= at then
				gatheredAt[at] = table.clone(k.stats.gathered)
			end
		end
	end
	run.env.mock:advance(2)
	run.label = label
	run.marks = marks
	run.gatheredAt = gatheredAt
	run.endTime = sim.time
	run.endStock = run.stock(k.id)
	run.aiInstalled = sim.rulerAI ~= nil
	run.kingdoms = {}
	for _, kid in sim.kingdomOrder do
		local other = sim.kingdoms[kid]
		run.kingdoms[kid] = {
			citizens = #other.citizenIds,
			soldiers = #other.unitIds,
			buildings = #other.buildingIds,
			rulers = #other.rulers,
			crown = other.crownPoints,
		}
	end
	run.nodesLeft = {}
	for _, nid in k.nearNodes do
		local node = sim.nodes[nid]
		local entry = run.nodesLeft[node.resource] or { amount = 0, nodes = 0, empty = 0 }
		run.nodesLeft[node.resource] = entry
		entry.amount += node.amount
		entry.nodes += 1
		entry.empty += if node.amount <= 0 then 1 else 0
	end
	run.objectiveEnd = objectiveState(sim)
	teardown(run)
	return run
end

local function firstT(run: any, kid: string, key: string): number?
	local firsts = run.firsts[kid]
	return firsts and firsts[key] and firsts[key].t
end

local function nodesText(left: { [string]: any }): string
	local parts = {}
	for _, res in RESOURCES do
		local entry = left[res]
		if entry then
			table.insert(parts, `{res} {math.floor(entry.amount)} ({entry.empty}/{entry.nodes} empty)`)
		end
	end
	return table.concat(parts, ", ")
end

local function printIdle(run: any)
	local ended = firstEvent(run, "MatchEnded", function()
		return true
	end)
	local capture = firstEvent(run, "ObjectiveCaptured", function()
		return true
	end)
	print(
		`PACING {run.label} seed {run.seed}: ran to {fmt(run.endTime)} s; phase {run.match:getPhase()}; RulerAI installed {tostring(
			run.aiInstalled
		)}; capture {if capture then capture.event.kingdomId .. " at " .. fmt(capture.t) else "none"}; MatchEnded {if ended
			then tostring(ended.event.winner) .. " at " .. fmt(ended.t)
			else "no"}; watchtower {run.objectiveEnd}; errors {#logsAt(run, "error")} thread errors {#run.env.mock.threadErrors}`
	)
	local g = run.gatheredAt
	local function rate(res: string): string
		local at = if g[300] then 300 elseif g[120] then 120 else nil
		return if at then string.format("%.1f", g[at][res] / at * 60) else "-"
	end
	print(
		`PACING {run.label} seed {run.seed} {HUMAN} (idle human): barracks affordable at {fmt(run.marks.affordBarracks)} [{stockText(
			run.marks.affordStock
		)}] (wood ok {fmt(run.marks["enough:wood"])}, stone ok {fmt(run.marks["enough:stone"])}); citizen income /min over 0-300 s food {rate(
			"food"
		)} wood {rate("wood")} stone {rate("stone")}; near nodes left {nodesText(run.nodesLeft)}; end stock {stockText(
			run.endStock
		)}; citizens {run.kingdoms[HUMAN].citizens}; births {#chargesOf(run, HUMAN, "population")}`
	)
	for _, kid in run.sim.kingdomOrder do
		if kid ~= HUMAN then
			local info = run.kingdoms[kid]
			local placed, done = {}, {}
			for _, entry in run.events do
				if entry.event.kingdomId == kid and entry.name == "BuildingPlaced" then
					table.insert(placed, `{entry.event.kind}@{fmt(entry.t)}`)
				elseif entry.event.kingdomId == kid and entry.name == "BuildingCompleted" then
					table.insert(done, `{entry.event.kind}@{fmt(entry.t)}`)
				end
			end
			local march = firstEvent(run, "ArmyOrdered", function(event)
				return event.kingdomId == kid and event.order == "Move"
			end)
			print(
				`PACING {run.label} seed {run.seed} AI {kid}: rulers {info.rulers} citizens {info.citizens} soldiers {info.soldiers} buildings {info.buildings}; first placed {placed[1] or "none"} (all {#placed}), first completed {done[1] or "none"}; first recruit {fmt(
					firstT(run, kid, "RecruitQueued")
				)}; first march on the objective {fmt(march and march.t)}; first capture progress {fmt(
					firstT(run, kid, "ObjectiveProgress")
				)}; crown {math.floor(info.crown)}`
			)
		end
	end
end

local function checkIdle(run: any)
	expect(logsAt(run, "error")).toEqual({})
	expect(run.env.mock.threadErrors).toEqual({})
	assert(run.endTime >= LIMIT or run.match:getPhase() == "Results", "idle run stopped early")
end

-- ---------------------------------------------------------------- specs
describe("VS-1 slice pacing probe (headless, real services, default quotas)", function()
	it("A greedy human: House, Barracks, recruit 3, capture", function()
		profileLanes({ label = "A", plan = { "house", "barracks" }, gate = greedy })
	end)

	it("Abf greedy human, barracks first (no House)", function()
		profileLanes({ label = "Abf", plan = { "barracks" }, gate = greedy })
	end)

	it("C onboarding-paced human (config Onboarding expectSec)", function()
		profileLanes({ label = "C", plan = { "house", "barracks" }, gate = onboardingGate })
	end)

	it("B idle human: what the AI kingdoms do in the slice", function()
		local affords = {}
		for _, seed in SEEDS do
			local run = idle(seed, "B")
			printIdle(run)
			checkIdle(run)
			table.insert(affords, run.marks.affordBarracks or math.huge)
		end
		print(`PACING B barracks-first affordable (no House): median {fmt(median(affords))} s`)
	end)

	if FULL then
		it("Bai what-if (NOT main): idle human, AI governor on, every kingdom populated", function()
			for _, seed in SEEDS do
				local run = idle(seed, "Bai", AI_ON)
				printIdle(run)
				checkIdle(run)
			end
		end)

		it("Cai what-if (NOT main): onboarding-paced human against AI governors", function()
			profileLanes({
				label = "Cai",
				plan = { "house", "barracks" },
				gate = onboardingGate,
				overrides = AI_ON,
				seeds = WHAT_IF_SEEDS,
				whatIf = true,
			})
		end)

		it("Dai what-if (NOT main): greedy human who sends at 480 s, after the AI armies", function()
			profileLanes({
				label = "Dai",
				plan = { "house", "barracks" },
				gate = lateSendGate(LATE_SEND),
				overrides = AI_ON,
				seeds = WHAT_IF_SEEDS,
				whatIf = true,
			})
		end)
	end
end)
