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
		- rigs: citizens + soldiers (the replicated entities that clients render as rigs; BRIEF §14 budgets
		  300 per server, about 75 per kingdom, and 150 rendered on screen), per kingdom and in all, sampled
		  once per virtual second; the peak and when it happened. Buildings are counted beside them, not in them.
		- bandwidth: bytes EntityService sends to the one human per phase (the Sim.Snapshot and Sim.Events
		  buffers; every broadcast reaches every player, so this is the per-player rate), as KB/s next to
		  BRIEF §14's ≈ 5 KB/s at 50 entities (VS-1 broadcast) and ≤ 20 KB/s (VS-2 interest tiers). Until
		  EntityService sends through Sim/Interest (D-055 (2)), this measured figure is the "without Interest"
		  one; beside it the probe estimates "with Interest" every virtual second: rigs within
		  Interest.DEFAULT_NEAR of the human's keep count as near, the rest as far, priced by
		  Interest.bytesPerSecond at 10 Hz. That formula prices every rig's record on its tick (no diffing,
		  no events), so it is an upper bound; the probe prints the same formula without Interest (every rig
		  near) beside it, and the ratio of the two is what Interest saves. The measured figure is lower
		  than either because EntityService sends only what changed.
		- the ten slowest simulation ticks per phase with their sim time, to tell a periodic cost from a one-off.
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
local Interest = require("@game/ReplicatedStorage/Game/Sim/Interest")

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

-- rigs (citizens + soldiers, the replicated entities) and buildings in all, with a per-kingdom text
local function entities(sim: any): (number, number, { [string]: string })
	local rigs, buildings = 0, 0
	local per = {}
	for _, kid in sim.kingdomOrder do
		local k = sim.kingdoms[kid]
		local c, s, b = #k.citizenIds, #k.unitIds, #k.buildingIds
		rigs += c + s
		buildings += b
		per[kid] = `c{c}/s{s}/b{b}`
	end
	return rigs, buildings, per
end

local RIG_BUDGET = 300 -- BRIEF §14 / line 78: entities per server (about 75 per kingdom)
local RIGS_ON_SCREEN = 150 -- BRIEF §14: rendered rigs on screen

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
		peak = { rigs = -1 },
		simT = {} :: { [string]: { number } }, -- sim time of each tick, parallel to simMs
		bytes = {} :: { [string]: number }, -- bytes EntityService sent to the human, per phase
		interestBps = {} :: { [string]: { number } }, -- per virtual second: bytes/s bound with Interest
		broadcastBps = {} :: { [string]: { number } }, -- the same bound without Interest (every rig near)
		densestBps = {} :: { [string]: { number } }, -- the bound with Interest, viewer at the densest keep
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
			result.simT[self.state] = {}
			table.insert(result.phases, self.state)
		end
		table.insert(bucket, (os.clock() - started) * 1000)
		table.insert(result.simT[self.state], sim.time)
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
	-- count the bytes EntityService sends to the human (pass-through; only while replicate runs)
	local counting = false
	local remotes = entityService._remotes
	local fire, fireAll = remotes.fire, remotes.fireAll
	local SENT_BY_ENTITY_SERVICE = { ["Sim.Snapshot"] = true, ["Sim.Events"] = true }
	local function count(name: any, payload: any)
		if counting and SENT_BY_ENTITY_SERVICE[name] and type(payload) == "buffer" then
			local phase = host.match.state
			result.bytes[phase] = (result.bytes[phase] or 0) + buffer.len(payload)
		end
	end
	remotes.fireAll = function(self: any, name: any, payload: any, ...: any)
		count(name, payload) -- every player receives a broadcast
		return fireAll(self, name, payload, ...)
	end
	remotes.fire = function(self: any, name: any, player: any, payload: any, ...: any)
		local sent = fire(self, name, player, payload, ...)
		if sent and player and player.UserId == USER_ID then
			count(name, payload)
		end
		return sent
	end
	local replicate = entityService.replicate
	entityService.replicate = function(self: any)
		local started = os.clock()
		counting = true
		replicate(self)
		counting = false
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
		local rigs, buildings, per = entities(sim)
		local home = sim.kingdoms[host:kingdomOf(player) or ""]
		if home then
			-- every rig's position once, then the near count around each kingdom's keep: the human's own keep
			-- (the best case) and the densest keep (a camera watching the busiest kingdom, D-055 (5))
			local positions = {}
			for _, kid in sim.kingdomOrder do
				local k = sim.kingdoms[kid]
				for _, list in { { k.citizenIds, sim.citizens }, { k.unitIds, sim.units } } do
					for _, id in list[1] do
						table.insert(positions, list[2][id])
					end
				end
			end
			local nearSq = Interest.DEFAULT_NEAR * Interest.DEFAULT_NEAR
			local function nearOf(cx: number, cz: number): number
				local n = 0
				for _, e in positions do
					if e and e.x and (e.x - cx) ^ 2 + (e.z - cz) ^ 2 <= nearSq then
						n += 1
					end
				end
				return n
			end
			local total = #positions
			local nearHome, nearDensest = nearOf(home.x, home.z), 0
			for _, kid in sim.kingdomOrder do
				local k = sim.kingdoms[kid]
				nearDensest = math.max(nearDensest, nearOf(k.x, k.z))
			end
			local phaseNow = match:getPhase()
			local function push(key: string, bps: number)
				local bucket = result[key][phaseNow] or {}
				result[key][phaseNow] = bucket
				table.insert(bucket, bps)
			end
			push("interestBps", Interest.bytesPerSecond(nearHome, total - nearHome, 10))
			push("densestBps", Interest.bytesPerSecond(nearDensest, total - nearDensest, 10))
			push("broadcastBps", Interest.bytesPerSecond(total, 0, 10))
		end
		if rigs > result.peak.rigs then
			result.peak = { rigs = rigs, buildings = buildings, t = sim.time, phase = match:getPhase(), per = per }
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
	-- EntityService's own count: "Kingdom perf" logs bytes/s per player every 30 s (cross-check of the probe's)
	result.servicePerf = {} :: { number }
	for _, entry in env.mock.logs do
		if entry.message == "Kingdom perf" and entry.fields and entry.fields.bytesPerSecond then
			table.insert(result.servicePerf, entry.fields.bytesPerSecond)
		end
	end
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

-- bytes-per-second samples as KB/s, mean and max
local function kb(values: { number }): string
	local meanKb, maxKb = mean(values) / 1024, percentile(values, 1) / 1024
	return `mean {string.format("%.2f", meanKb)} max {string.format("%.2f", maxKb)}`
end

-- the n slowest ticks as "ms@time", slowest first
local function slowest(values: { number }, times: { number }, n: number): string
	local order = {}
	for i = 1, #values do
		order[i] = i
	end
	table.sort(order, function(a: number, b: number): boolean
		return values[a] > values[b]
	end)
	local parts = {}
	for i = 1, math.min(n, #order) do
		local k = order[i]
		table.insert(parts, `{string.format("%.1f", values[k])}@{string.format("%.1f", times[k] or 0)}`)
	end
	return table.concat(parts, " ")
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
		local seconds = #rep / 10 -- snapshots run at 10 Hz
		local kbps = string.format("%.2f", if seconds > 0 then (r.bytes[phase] or 0) / 1024 / seconds else 0)
		local with, without = kb(r.interestBps[phase] or {}), kb(r.broadcastBps[phase] or {})
		print(
			`PERF seed {r.seed} {phase}: snapshots {#rep}; replicate ms {stats(rep)}; measured to the human {kbps} KB/s`
		)
		local densest = kb(r.densestBps[phase] or {})
		print(
			`PERF seed {r.seed} {phase}: upper bound KB/s without Interest {without}; with Interest at own keep {with}`
		)
		print(`PERF seed {r.seed} {phase}: upper bound KB/s with Interest at the densest keep {densest}`)
		print(`PERF seed {r.seed} {phase}: slowest sim ticks (ms@sim s) {slowest(s, r.simT[phase] or {}, 10)}`)
	end
	local totalBytes, totalSnapshots = 0, 0
	for _, phase in r.phases do
		totalBytes += r.bytes[phase] or 0
		totalSnapshots += #(r.replicateMs[phase] or {})
	end
	local probeBps = math.floor((if totalSnapshots > 0 then totalBytes / (totalSnapshots / 10) else 0) + 0.5)
	local serviceBps = math.floor(mean(r.servicePerf) + 0.5)
	print(
		`PERF seed {r.seed} bytes cross-check: probe {probeBps} B/s over the run; EntityService "Kingdom perf" mean {serviceBps} B/s over {#r.servicePerf} logs`
	)
	local peak = r.peak
	local at, phase = math.floor(peak.t or 0), tostring(peak.phase)
	local per = perText(peak.per or {}, r.kingdomOrder)
	print(
		`PERF seed {r.seed} rigs peak {peak.rigs} (budget {RIG_BUDGET} per server, {RIGS_ON_SCREEN} on screen) at {at} s ({phase}); buildings {peak.buildings}: {per}`
	)
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
			expect(r.peak.rigs > 0).toBe(true)
			if #r.errors > 0 then
				print("PERF errors:\n  " .. table.concat(r.errors, "\n  "))
			end
			expect(#r.errors).toBe(0)
		end)
	end
end)
