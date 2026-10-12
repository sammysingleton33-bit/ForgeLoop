--[[
	EntityService (CONTRACTS G4, FL-0049) booted with RemoteService, MatchService and KingdomService:
	what clients receive on Sim.Events / Sim.Snapshot / Sim.GetEntities, decoded the way
	EntityController decodes it. Every snapshot packet must stay ≤ 900 B (D-025).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local KingdomRemotes = require("@game/ReplicatedStorage/Game/Kingdom/Remotes")
local MatchRemotes = require("@game/ReplicatedStorage/Game/Match/Remotes")
local SimRemotes = require("@game/ReplicatedStorage/Game/Sim/Remotes")
local SnapshotCodec = require("@game/ReplicatedStorage/Game/Sim/SnapshotCodec")
local RemoteServiceDef = require("@game/ServerScriptService/Forge/Services/RemoteService")
local EntityServiceDef = require("@game/ServerScriptService/Game/Services/EntityService")
local KingdomServiceDef = require("@game/ServerScriptService/Game/Services/KingdomService")
local MatchServiceDef = require("@game/ServerScriptService/Game/Services/MatchService")

local booted = {}
local savedMode = MatchConfig.mode

local function boot(options: any?)
	local opts = options or {}
	MatchConfig.mode = opts.mode or savedMode
	local env = MockEnv.new({
		seed = 11,
		sharedModules = { Remotes = { Kingdom = KingdomRemotes, Match = MatchRemotes, Sim = SimRemotes } },
	})
	local definitions = { RemoteServiceDef, MatchServiceDef, KingdomServiceDef, EntityServiceDef }
	if opts.pacing then
		table.insert(definitions, {
			name = "PacingService",
			new = function()
				return opts.pacing
			end,
		})
	end
	local registry = Loader.load(env, definitions)
	table.insert(booted, { registry = registry, env = env })
	local kingdoms = registry:get("KingdomService")
	-- Lune has no characters: a no-op spawn adapter (KingdomService specs cover spawning)
	kingdoms.adapter = {
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
	return env, registry:get("EntityService"), registry:get("MatchService")
end

local function remote(env, name)
	local area, action = string.match(name, "^(%w+)%.(%w+)$")
	return env.ReplicatedStorage.ForgeRemotes:FindFirstChild(area):FindFirstChild(action)
end

-- decoded payloads of every firing of `name` so far, oldest first
local function sent(env, name, decoder)
	local out = {}
	for _, entry in env.mock.remotes:sent(remote(env, name)) do
		local payload = entry.args[1]
		local decoded = assert(decoder(payload))
		table.insert(out, { decoded = decoded, bytes = buffer.len(payload), dropped = entry.dropped })
	end
	return out
end

local function eventsOf(env)
	local list = {}
	for _, batch in sent(env, "Sim.Events", EventCodec.decode) do
		for _, e in batch.decoded.events do
			table.insert(list, e)
		end
	end
	return list
end

local function invoke(env, player, name, ...)
	local args = table.pack(...)
	local results
	env.mock.remotes:asClient(player, function()
		results = table.pack(remote(env, name):InvokeServer(table.unpack(args, 1, args.n)))
	end)
	return table.unpack(results, 1, results.n)
end

afterEach(function()
	for _, b in booted do
		b.registry:destroy()
		for _, entry in b.env.mock.logs do
			if entry.level == "error" then
				error(`server logged an error: {entry.message} {entry.fields and entry.fields.error or ""}`)
			end
		end
		expect(b.env.mock.threadErrors).toEqual({})
	end
	table.clear(booted)
	GameEvents.disconnectAll()
	MatchConfig.mode = savedMode
end)

describe("EntityService replication (G4)", function()
	it("sends each new entity's spawn once, then snapshots that clients can decode, all ≤ 900 B", function()
		local env, entities = boot()
		local spawned = {}
		entities.spawned:connect(function(id)
			table.insert(spawned, id)
		end)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local sim = entities:_sim()
		local spawns = {}
		for _, e in eventsOf(env) do
			if e.type == "spawn" then
				expect(spawns[e.id]).toBeNil() -- once
				spawns[e.id] = e
			end
		end
		expect(#sim.citizenOrder).toBe(12)
		for _, id in sim.citizenOrder do
			local c = sim.citizens[id]
			expect(spawns[id]).toEqual({ type = "spawn", id = id, kind = "citizen", job = c.job, kingdom = "crimson" })
		end
		expect(#spawned).toBe(12)
		local snapshots = sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		expect(#snapshots >= 9).toBe(true) -- ~10 Hz
		for _, s in snapshots do
			expect(s.bytes <= 900).toBe(true)
			expect(s.dropped).toBeFalsy()
			for _, r in s.decoded.records do
				expect(spawns[r.id]).toBeTruthy() -- only entities the client was told about
			end
		end
		local last = snapshots[#snapshots].decoded
		expect(SnapshotCodec.newer(last.seq, snapshots[1].decoded.seq)).toBe(true)
		expect(last.serverTime > 0).toBe(true)
	end)

	it("leaves citizens and soldiers out of the server world view: clients render them (D-023)", function()
		local env, entities, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local sim = entities:_sim()
		local view = match.host._view
		expect(view:find("entity", sim.citizenOrder[1])).toBeNil()
		expect(view:find("building", sim.kingdoms.crimson.keepId)).toBeTruthy()
	end)

	it("Sim.GetEntities returns every live entity as full records at its current position", function()
		local env, entities = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(2)
		local batch = assert(EventCodec.decode(invoke(env, p1, "Sim.GetEntities")))
		local sim = entities:_sim()
		expect(#batch.events).toBe(#sim.citizenOrder)
		for _, e in batch.events do
			expect(e.type).toBe("full")
			local c = sim.citizens[e.id]
			expect(e.kingdom).toBe("crimson")
			expect(e.job).toBe(c.job)
			expect(math.abs(e.x - c.x) <= 1 / 16 + 1e-9).toBe(true)
			expect(math.abs(e.z - c.z) <= 1 / 16 + 1e-9).toBe(true)
		end
	end)

	it("sends moving entities every snapshot and refreshes still ones about once per second", function()
		local env, entities = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local before = #sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		local sim = entities:_sim()
		local counts = {}
		env.mock:advance(3)
		for i, s in sent(env, "Sim.Snapshot", SnapshotCodec.decode) do
			if i > before then
				for _, r in s.decoded.records do
					counts[r.id] = (counts[r.id] or 0) + 1
				end
			end
		end
		for _, id in sim.citizenOrder do
			expect((counts[id] or 0) >= 2).toBe(true) -- everyone at least every ~1 s
		end
		local maxCount = 0
		for _, n in counts do
			maxCount = math.max(maxCount, n)
		end
		expect(maxCount >= 25).toBe(true) -- a walker goes out (nearly) every one of the ~30 snapshots
	end)

	it("reports deliveries as deposit cues, and despawns with a die cue, the reason and no resurrection", function()
		local env, entities = boot()
		local despawned = {}
		entities.despawned:connect(function(id, reason)
			table.insert(despawned, { id, reason })
		end)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(60)
		local deposits = 0
		for _, e in eventsOf(env) do
			if e.type == "cue" and e.cue == "deposit" then
				deposits += 1
				expect(e.resource).toBeTruthy()
			end
		end
		expect(deposits > 0).toBe(true)
		local sim = entities:_sim()
		local victim = sim.citizenOrder[3]
		local before = #eventsOf(env)
		entities:despawn(victim, "test")
		env.mock:advance(0.2)
		local after = eventsOf(env)
		local die, gone = false, false
		for i = before + 1, #after do
			local e = after[i]
			if e.id == victim and e.type == "cue" and e.cue == "die" then
				die = true
				expect(gone).toBe(false) -- the cue comes before the despawn
			elseif e.id == victim and e.type == "despawn" then
				gone = true
			end
		end
		expect(die).toBe(true)
		expect(gone).toBe(true)
		expect(despawned).toEqual({ { victim, "test" } })
		env.mock:advance(2)
		for _, s in sent(env, "Sim.Snapshot", SnapshotCodec.decode) do
			for _, r in s.decoded.records do
				if s.decoded.serverTime > 61 then
					expect(r.id).never.toBe(victim)
				end
			end
		end
	end)

	it("a death inside the simulation still sends the die cue before the despawn, with its cause", function()
		local env, entities = boot()
		local despawned = {}
		entities.despawned:connect(function(id, reason)
			table.insert(despawned, { id, reason })
		end)
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local sim = entities:_sim()
		local victim = sim.citizenOrder[2]
		local before = #eventsOf(env)
		sim:killCitizen(sim.citizens[victim], "raid") -- the host learns of it on its own tick
		env.mock:advance(1)
		local order = {}
		local all = eventsOf(env)
		for i = before + 1, #all do
			if all[i].id == victim then
				table.insert(order, if all[i].type == "cue" then all[i].cue else all[i].type)
			end
		end
		expect(order).toEqual({ "die", "despawn" })
		expect(despawned).toEqual({ { victim, "raid" } })
	end)

	it("spawn / get / despawn work for citizens and soldiers, and job changes go out once", function()
		local env, entities = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local citizen = entities:spawn("citizen", "crimson", "miner", Vector3.new(-300, 0, -300))
		local soldier = entities:spawn("soldier", "crimson", "soldier", Vector3.new(-310, 0, -300))
		expect(citizen ~= soldier).toBe(true)
		local state = assert(entities:get(citizen))
		expect(state.kind).toBe("citizen")
		expect(state.job).toBe("miner")
		expect(type(state.name)).toBe("string")
		expect(typeof(state.position)).toBe("Vector3")
		expect(state.memory).toEqual({})
		expect(assert(entities:get(soldier)).kind).toBe("soldier")
		expect(entities:get(999999)).toBeNil()
		expect(function()
			entities:spawn("citizen", "violet", "miner", Vector3.zero)
		end).toThrow("unknown or fallen kingdom")
		expect(function()
			entities:spawn("dragon", "crimson", "miner", Vector3.zero)
		end).toThrow("unsupported kind")
		local changed = {}
		entities.jobChanged:connect(function(id, job)
			table.insert(changed, { id, job })
		end)
		env.mock:advance(0.2)
		entities:_sim().citizens[citizen].job = "farmer"
		env.mock:advance(0.5)
		-- the first change goes out once; the quota rebalancer may move the citizen on again later
		expect(changed[1]).toEqual({ citizen, "farmer" })
		local jobs = {}
		for _, e in eventsOf(env) do
			if e.type == "job" and e.id == citizen then
				table.insert(jobs, { citizen, e.job })
			end
		end
		expect(jobs).toEqual(changed) -- one job record per jobChanged, in order
		entities:despawn(soldier, "test")
		env.mock:advance(0.2)
		expect(entities:get(soldier)).toBeNil()
	end)

	it("keeps every packet ≤ 900 B with 300 entities and reports perf every 30 s", function()
		local env, entities = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local rng = Random.new(5)
		for i = 1, 288 do
			local kingdom = ({ "crimson", "azure", "emerald", "gold" })[i % 4 + 1]
			entities:spawn(
				"citizen",
				kingdom,
				"hauler",
				Vector3.new(rng:NextNumber(-500, 500), 0, rng:NextNumber(-500, 500))
			)
		end
		env.mock:advance(31)
		local biggest, total = 0, 0
		for _, s in sent(env, "Sim.Snapshot", SnapshotCodec.decode) do
			biggest = math.max(biggest, s.bytes)
			total += #s.decoded.records
			expect(s.dropped).toBeFalsy()
		end
		expect(biggest <= 900).toBe(true)
		expect(total > 0).toBe(true)
		expect(env.mock:hasLog("info", "Kingdom perf")).toBe(true)
		local stats = entities:stats()
		expect(stats.entities >= 300).toBe(true)
		expect(type(stats.encodeMsP99)).toBe("number")
		expect(type(stats.simMsP99)).toBe("number")
	end)

	it("sends reset before the new world's spawns when a match starts over", function()
		local fast = {
			phaseDurations = function()
				return { Lobby = 1, Founding = 2, Expansion = 2, Conflict = 2, Endgame = 2, Results = 1 }
			end,
		}
		local env, _, match = boot({ mode = "match", pacing = fast })
		env.mock.players:add({ userId = 1 })
		env.mock:advance(12)
		expect(match.host.match.roundId).toBe("km-2")
		local events = eventsOf(env)
		local resetAt
		for i, e in events do
			if e.type == "reset" then
				expect(resetAt).toBeNil()
				resetAt = i
			end
		end
		assert(resetAt, "no reset was sent")
		local respawned = 0
		for i = resetAt + 1, #events do
			if events[i].type == "spawn" then
				respawned += 1
			end
			expect(events[i].type).never.toBe("despawn") -- the reset already cleared the old world
		end
		expect(respawned > 0).toBe(true)
	end)
end)
