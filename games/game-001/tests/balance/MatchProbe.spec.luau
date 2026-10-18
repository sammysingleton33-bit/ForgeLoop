--[[
	FORGE-05 performance probe: the full match, headless (Lune + MockEnv; NOT a Studio or device test).

	Every real server service of both trees on one MockEnv, config Match.mode = "match" for the run (restored
	after), one human (userId 1) who does nothing, every other kingdom as match mode leaves it (FL-0125 turns
	on the governors and PvP; this probe measures whatever main does). Per FL-0131 / FL-0032 it records:
		- tick cost: wall-clock ms of Match:update (the simulation) and of MatchHost:step (simulation + world
		  view + kingdom state), per host tick, as mean, p99 and max per phase. MockEnv's env.wait returns the
		  exact tick (1/16 s), so each host tick is one simulation step here; on a live server the host clamps
		  dt to 1 s and one tick can run up to 16 steps after a hitch (MatchHost:start), which this probe does
		  not reproduce. MockEnv's env.clock is virtual, so MatchHost:simMsPerTick() reads 0 here; this probe
		  times with os.clock instead.
		- snapshot cost: wall-clock ms of EntityService:replicate (diff + SnapshotCodec/EventCodec encode + send)
		  per 10 Hz snapshot tick. It runs on its own loop, NOT inside MatchHost:step, so a per-Heartbeat budget
		  such as BRIEF §14's compares with host step + replicate, not with either alone.
		- entities: citizens, soldiers and buildings per kingdom and in all, sampled once per virtual second;
		  the peak and when it happened.
		- parts: BaseParts under Workspace (the server's world view: Kit building models, ground), sampled
		  every 30 virtual seconds.
	Lune runs plain Luau without Roblox's native code generation or engine, so the ms are indicative only:
	compare builds with each other, not with Roblox's frame budget. Only Studio or a device measures that.

	Default (check.sh): one seed, the first 60 virtual seconds; asserts only that match mode boots, ticks
	and logs no errors. FORGE_MATCH_PROBE=1: seeds 1-2, the whole match (or LIMIT) with every PERF line.
]]
local fs = require("@lune/fs")
local process = require("@lune/process")

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")

local FULL = process.env.FORGE_MATCH_PROBE == "1"
local SEEDS = if FULL then { 1, 2 } else { 1 }
local LIMIT = if FULL then 3600 else 60 -- virtual seconds per run at most
local STEP = 1 -- virtual seconds per advance; entities are sampled at this period
local PART_EVERY = 30 -- virtual seconds between part counts (a full Workspace walk)
local USER_ID = 1

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

-- Resolved once while the file loads (Lune's fs calls yield; tests must not).
local SERVER_DEFINITIONS = definitionsIn(SERVER_TREES)
local REMOTES = remotesByArea()

-- KingdomService character adapter: no character in MockEnv (as in PacingProbe.spec)
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

local function percentile(values: { number }, p: number): number
	if #values == 0 then
		return 0
	end
	local sorted = table.clone(values)
	table.sort(sorted)
	return sorted[math.max(1, math.ceil(#sorted * p))]
end

local function mean(values: { number }): number
	if #values == 0 then
		return 0
	end
	local total = 0
	for _, v in values do
		total += v
	end
	return total / #values
end

local function ms(value: number): string
	return string.format("%.3f", value)
end

local function countParts(root: any): number
	local n = 0
	for _, inst in root:GetDescendants() do
		if inst:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function entities(sim: any): (number, { [string]: string })
	local total = 0
	local per = {}
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		local c, s, b = #k.citizenIds, #k.unitIds, #k.buildingIds
		total += c + s + b
		per[kid] = `c{c}/s{s}/b{b}`
	end
	return total, per
end

local function perText(per: { [string]: string }, order: { string }): string
	local parts = {}
	for _, kid in order do
		table.insert(parts, `{kid} {per[kid]}`)
	end
	return table.concat(parts, "; ")
end

-- ---------------------------------------------------------------- one run
local function run(seed: number): any
	local previousMode = MatchConfig.mode
	MatchConfig.mode = "match"
	local env = MockEnv.new({ seed = seed, sharedModules = { Remotes = REMOTES } })
	local ok, server = pcall(Loader.load, env, SERVER_DEFINITIONS)
	MatchConfig.mode = previousMode
	assert(ok, tostring(server))
	server:get("KingdomService").adapter = ADAPTER
	local match = server:get("MatchService")
	local host = match.host
	local sim = host.match.sim

	-- per-tick wall clock of the simulation and of the whole host step, bucketed by phase
	local result = {
		seed = seed,
		mode = match.mode,
		phases = {} :: { string },
		simMs = {} :: { [string]: { number } },
		hostMs = {} :: { [string]: { number } },
		replicateMs = {} :: { [string]: { number } },
		peak = { total = -1 },
		parts = {} :: { { t: number, n: number } },
	}
	local update = host.match.update
	host.match.update = function(self: any, dt: number)
		local started = os.clock()
		update(self, dt)
		local bucket = result.simMs[self.state]
		if bucket == nil then
			bucket = {}
			result.simMs[self.state] = bucket
			table.insert(result.phases, self.state)
		end
		table.insert(bucket, (os.clock() - started) * 1000)
	end
	local step = host.step
	host.step = function(self: any, dt: number)
		local started = os.clock()
		step(self, dt)
		local phase = self.match.state
		local bucket = result.hostMs[phase] or {}
		result.hostMs[phase] = bucket
		table.insert(bucket, (os.clock() - started) * 1000)
	end

	local entityService = server:get("EntityService")
	local replicate = entityService.replicate
	entityService.replicate = function(self: any)
		local started = os.clock()
		replicate(self)
		local phase = host.match.state
		local bucket = result.replicateMs[phase] or {}
		result.replicateMs[phase] = bucket
		table.insert(bucket, (os.clock() - started) * 1000)
	end

	local player = env.mock.players:add({ userId = USER_ID, name = "Probe" })
	local wallStart = os.clock()
	local nextParts = 0
	while sim.time < LIMIT and match:getPhase() ~= "Results" do
		env.mock:advance(STEP)
		local total, per = entities(sim)
		if total > result.peak.total then
			result.peak = { total = total, t = sim.time, phase = match:getPhase(), per = per }
		end
		if sim.time >= nextParts then
			nextParts = sim.time + PART_EVERY
			table.insert(result.parts, { t = sim.time, n = countParts(env.Workspace) })
		end
	end
	env.mock:advance(2)
	result.wallSeconds = os.clock() - wallStart
	result.endTime = sim.time
	result.endPhase = match:getPhase()
	result.kingdomOrder = table.clone(sim.kingdomOrder)
	result.kingdom = host:kingdomOf(player)
	result.errors = {}
	for _, entry in env.mock.logs do
		if entry.level == "error" then
			table.insert(result.errors, `{entry.message} {tostring(entry.fields and entry.fields.error)}`)
		end
	end
	server:destroy()
	GameEvents.disconnectAll()
	return result
end

local function stats(values: { number }): string
	return `mean {ms(mean(values))} p99 {ms(percentile(values, 0.99))} max {ms(percentile(values, 1))}`
end

local function report(r: any)
	local wall = string.format("%.1f", r.wallSeconds)
	local human = tostring(r.kingdom)
	print(
		`PERF seed {r.seed} mode {r.mode}: {math.floor(r.endTime)} virtual s in {wall} s wall; end phase {r.endPhase}; human in {human}`
	)
	for _, phase in r.phases do
		local s, h, rep = r.simMs[phase] or {}, r.hostMs[phase] or {}, r.replicateMs[phase] or {}
		print(`PERF seed {r.seed} {phase}: ticks {#s}; sim ms {stats(s)}; host step ms {stats(h)}`)
		print(`PERF seed {r.seed} {phase}: snapshots {#rep}; replicate ms {stats(rep)}`)
	end
	local peak = r.peak
	local at, phase = math.floor(peak.t or 0), tostring(peak.phase)
	local per = perText(peak.per or {}, r.kingdomOrder)
	print(`PERF seed {r.seed} entities peak {peak.total} at {at} s ({phase}): {per}`)
	local maxParts, partsAt = 0, 0
	for _, sample in r.parts do
		if sample.n > maxParts then
			maxParts, partsAt = sample.n, sample.t
		end
	end
	print(`PERF seed {r.seed} Workspace BaseParts peak {maxParts} at {math.floor(partsAt)} s ({#r.parts} samples)`)
end

describe("FORGE-05 match probe (headless performance; FL-0131, FL-0032)", function()
	for _, seed in SEEDS do
		it(`match mode boots, ticks and logs no errors (seed {seed}{if FULL then ", full" else ", 60 s"})`, function()
			local r = run(seed)
			report(r)
			expect(r.mode).toBe("match")
			expect(#r.phases > 0).toBe(true)
			expect(r.peak.total > 0).toBe(true)
			if #r.errors > 0 then
				print("PERF errors:\n  " .. table.concat(r.errors, "\n  "))
			end
			expect(#r.errors).toBe(0)
		end)
	end
end)
