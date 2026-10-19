--[[
	EntityService (CONTRACTS G4, FL-0049) booted with RemoteService, MatchService and KingdomService:
	what clients receive on Sim.Events / Sim.Snapshot / Sim.GetEntities, decoded the way
	EntityController decodes it. Every snapshot packet must stay ≤ 900 B (D-025).
]]

local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect, afterEach = T.describe, T.it, T.expect, T.afterEach

local MockEnv = require("../../../../roblox/tests/mocks/MockEnv")
local GameEvents = require("@game/ReplicatedStorage/Forge/Contracts/GameEvents")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local People = require("@game/ReplicatedStorage/Game/Sim/People")
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
	MatchConfig.mode = opts.mode or "slice" -- the specs that do not say are the VS-1 slice ones; the shipped default is the full match (D-053)
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

	it("Sim.GetEntities pages: each live entity once, ascending ids, every page <= 900 B (FL-0109)", function()
		local env, entities = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(2)
		local sim = entities:_sim()
		local keep = sim.buildings[sim.kingdoms.crimson.keepId]
		for i = 1, 110 do
			-- every tenth one a soldier: soldiers come after the citizens in the frame, so ids are not in
			-- order there and the pages must sort them
			local kind, job = if i % 10 == 0 then "soldier" else "citizen", if i % 10 == 0 then "soldier" else "farmer"
			entities:spawn(kind, "crimson", job, Vector3.new(keep.x + 20 + i % 10, 0, keep.z + 20 + i // 10))
		end
		local live = #sim.citizenOrder + #sim.unitOrder
		expect(live > 2 * EntityServiceDef.PAGE_MAX).toBe(true) -- three pages at least
		local seen, count, last, pages = {}, 0, 0, 0
		local after = nil
		repeat
			local buf, nextAfter = invoke(env, p1, "Sim.GetEntities", after)
			pages += 1
			expect(buffer.len(buf) <= 900).toBe(true)
			local batch = assert(EventCodec.decode(buf))
			expect(#batch.events <= EntityServiceDef.PAGE_MAX).toBe(true)
			for _, e in batch.events do
				expect(e.type).toBe("full")
				expect(e.id > last).toBe(true) -- ascending, across pages too
				last = e.id
				expect(seen[e.id]).toBeNil()
				seen[e.id] = true
				count += 1
			end
			if nextAfter ~= nil then
				expect(nextAfter).toBe(last) -- the next page starts after this page's last id
			end
			after = nextAfter
		until after == nil or pages > 20
		expect(count).toBe(live)
		expect(pages).toBe(math.ceil(live / EntityServiceDef.PAGE_MAX))
		-- past the last id: an empty page and no next one
		local tail, none = invoke(env, p1, "Sim.GetEntities", 65535)
		expect(#assert(EventCodec.decode(tail)).events).toBe(0)
		expect(none).toBeNil()
		-- a cursor the server cannot use is dropped (RemoteService validation): no answer
		for _, bad in { -1, 1.5, "1", 70000, {}, 0 / 0, math.huge, -math.huge } do
			expect(invoke(env, p1, "Sim.GetEntities", bad)).toBeNil()
		end
	end)

	it(
		"Sim.GetEntities: with exactly two full pages of entities the second page has no next cursor (#127 L1)",
		function()
			local env, entities = boot()
			local p1 = env.mock.players:add({ userId = 1 })
			env.mock:advance(2)
			local sim = entities:_sim()
			local keep = sim.buildings[sim.kingdoms.crimson.keepId]
			local live = #sim.citizenOrder + #sim.unitOrder
			expect(live <= 2 * EntityServiceDef.PAGE_MAX).toBe(true)
			for i = 1, 2 * EntityServiceDef.PAGE_MAX - live do
				entities:spawn(
					"citizen",
					"crimson",
					"farmer",
					Vector3.new(keep.x + 20 + i % 10, 0, keep.z + 20 + i // 10)
				)
			end
			expect(#sim.citizenOrder + #sim.unitOrder).toBe(2 * EntityServiceDef.PAGE_MAX)
			local first, firstNext = invoke(env, p1, "Sim.GetEntities")
			expect(#assert(EventCodec.decode(first)).events).toBe(EntityServiceDef.PAGE_MAX)
			expect(firstNext).never.toBeNil()
			local second, secondNext = invoke(env, p1, "Sim.GetEntities", firstNext)
			expect(#assert(EventCodec.decode(second)).events).toBe(EntityServiceDef.PAGE_MAX)
			expect(secondNext).toBeNil() -- not an extra, empty page
		end
	)

	it("puts only the validated look on the wire, whatever the profile holds (FL-0109)", function()
		local env, entities = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(2)
		local sim = entities:_sim()
		local keep = sim.buildings[sim.kingdoms.crimson.keepId]
		local id = entities:spawn("citizen", "crimson", "farmer", Vector3.new(keep.x + 25, 0, keep.z + 25))
		local raw = { skin = 300, hair = 0, hairColor = 2.5, outfit = 4, key = "raw" } -- encodes as nothing valid
		sim.citizens[id].profile = { look = raw }
		env.mock:advance(0.5)
		local spawned
		for _, e in eventsOf(env) do
			if e.type == "spawn" and e.id == id then
				spawned = e
			end
		end
		assert(spawned, "the spawn went out (an unencodable look would have dropped the whole batch)")
		expect(spawned.look).toEqual(Kit.normalizeLook(raw))
		local full
		for _, e in assert(EventCodec.decode(invoke(env, p1, "Sim.GetEntities"))).events do
			if e.id == id then
				full = e
			end
		end
		expect(assert(full).look).toEqual(Kit.normalizeLook(raw))
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

	it("sends a citizen whose look changed (the Studio reseed) as a spawn again, nobody else (#91 M1)", function()
		local env, entities = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local sim = entities:_sim()
		if sim.profiler == nil then -- CitizenService installs People in the game; this boot has none
			People.install(sim, 7, People.CONTENT)
		end
		env.mock:advance(0.5)
		local function spawnsSince(mark: number): { [number]: any }
			local out = {}
			for i, e in eventsOf(env) do
				if i > mark and e.type == "spawn" then
					out[e.id] = e
				end
			end
			return out
		end
		local k = sim.kingdoms.crimson
		local a, b = sim.citizens[k.citizenIds[1]], sim.citizens[k.citizenIds[2]]
		local mark = #eventsOf(env)
		local new = table.clone(Kit.normalizeLook(a.profile.look))
		new.skin = new.skin % #Kit.LOOK_PALETTES.skin + 1
		a.profile.look = new
		b.profile.look = table.clone(b.profile.look) -- a new table with the same look: no spawn
		env.mock:advance(0.5)
		local spawns = spawnsSince(mark)
		expect(spawns[b.id]).toBeNil()
		local again = assert(spawns[a.id], "no spawn for the citizen whose look changed")
		expect(Kit.lookKey(again.look)).toBe(Kit.lookKey(new))
		expect({ again.kind, again.job, again.kingdom }).toEqual({ "citizen", a.job, "crimson" })
		local count = 0
		for _ in spawns do
			count += 1
		end
		expect(count).toBe(1)

		-- the real reseed: a spawn for exactly the citizens whose look key changed
		local before = {}
		for _, id in k.citizenIds do
			before[id] = Kit.lookKey(sim.citizens[id].profile.look)
		end
		mark = #eventsOf(env)
		People.reseed(sim, "crimson", 1234, People.CONTENT)
		local changed = {}
		for _, id in k.citizenIds do
			if Kit.lookKey(sim.citizens[id].profile.look) ~= before[id] then
				changed[id] = true
			end
		end
		expect(next(changed)).never.toBeNil()
		env.mock:advance(0.5)
		local resent = {}
		for id in spawnsSince(mark) do
			resent[id] = true
		end
		expect(resent).toEqual(changed)
		env.mock:advance(1)
		expect(next(spawnsSince(#eventsOf(env)))).toBeNil() -- once, not every tick
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

	it("the sim.spawn debug command spawns test citizens for the presser's kingdom", function()
		local env, entities = boot()
		local p1 = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local before = #entities:_sim().citizenOrder
		local ok, message = DebugCommands.run(p1, "sim.spawn", 50)
		expect(ok).toBe(true)
		expect(message).toContain("50")
		expect(#entities:_sim().citizenOrder).toBe(before + 50)
		expect((DebugCommands.run(p1, "sim.spawn", 301))).toBe(false) -- validated, fail closed
		env.mock:advance(1)
		local spawns = 0
		for _, e in eventsOf(env) do
			if e.type == "spawn" then
				spawns += 1
			end
		end
		expect(spawns).toBe(before + 50)
	end)

	it("never replicates an id over 65535 (one warning) and goes on replicating the rest (#39 L1)", function()
		local env, entities, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local sim = match.host.match.sim
		sim._nextEntity = EntityServiceDef.MAX_ID - 1
		local last = entities:spawn("citizen", "crimson", "farmer", Vector3.new(0, 0, 0)) -- 65535
		local over = entities:spawn("citizen", "crimson", "farmer", Vector3.new(4, 0, 0)) -- 65536
		local overSoldier = entities:spawn("soldier", "crimson", "soldier", Vector3.new(8, 0, 0))
		expect({ last, over }).toEqual({ 65535, 65536 })
		local spawnedIds = {}
		entities.spawned:connect(function(id)
			table.insert(spawnedIds, id)
		end)
		env.mock:advance(1)
		local ids = {}
		for _, e in eventsOf(env) do
			if e.type == "spawn" then
				ids[e.id] = true
			end
		end
		expect(ids[last]).toBe(true)
		expect(ids[over]).toBeNil()
		expect(ids[overSoldier]).toBeNil()
		expect(table.find(spawnedIds, over)).toBeNil()
		local warnings = 0
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "over 65535", 1, true) then
				warnings += 1
			end
		end
		expect(warnings).toBe(1) -- once per world, not per tick
		local before = #sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		env.mock:advance(1)
		expect(#sent(env, "Sim.Snapshot", SnapshotCodec.decode) > before).toBe(true) -- still replicating
		expect(#assert(EventCodec.decode(entities:_fullState())).events > 0).toBe(true) -- GetEntities too
		-- a new world may warn again: the same over-range citizen warns once more after a reset
		entities:_resetWorld()
		env.mock:advance(1)
		local again = 0
		for _, entry in env.mock.logs do
			if entry.level == "warn" and string.find(entry.message, "over 65535", 1, true) then
				again += 1
			end
		end
		expect(again).toBe(2)
	end)

	it("an entity off the wire's range keeps replicating everything else (#39 L1)", function()
		local env, entities = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local far = entities:spawn("citizen", "crimson", "farmer", Vector3.new(SnapshotCodec.MAX_COORD + 100, 0, 0))
		local near = entities:spawn("citizen", "crimson", "farmer", Vector3.new(4, 0, 0))
		local before = #sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		env.mock:advance(1) -- no "replication failed" error (afterEach checks the logs)
		local recordIds = {}
		local snapshots = sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		for i = before + 1, #snapshots do
			for _, r in snapshots[i].decoded.records do
				recordIds[r.id] = true
			end
		end
		expect(recordIds[near]).toBe(true)
		expect(recordIds[far]).toBeNil()
		local spawned = {}
		for _, e in eventsOf(env) do
			if e.type == "spawn" then
				spawned[e.id] = true
			end
		end
		expect(spawned[far]).toBe(true) -- it exists; only its position is held back
		expect(env.mock:hasLog("warn", "off the wire's range")).toBe(true)
	end)

	it("a tick that fails to encode commits nothing; the next tick sends it all, signals once (#39 L1)", function()
		local env, entities, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local kingdomId = assert(match.host.match:kingdomOf(1))
		local spawnedIds = {}
		entities.spawned:connect(function(id)
			table.insert(spawnedIds, id)
		end)
		-- carrying a resource the wire has no code for (a programming mistake): this tick cannot be encoded
		local id = entities:spawn("citizen", "crimson", "farmer", Vector3.new(0, 0, 0))
		local c = entities:_sim().citizens[id]
		c.carrying = { resource = "diamonds", amount = 1 }
		-- a kingdom event queued before the failed tick is kept for the next one (#93 M1)
		local speaker = entities:_sim().kingdoms[kingdomId].citizenIds[1]
		entities:sendKingdomEvent(kingdomId, {
			type = "thought",
			id = speaker,
			icon = "request",
			scenarioId = "spec_thought",
			text = "a thought",
		})
		local function thoughts()
			local n = 0
			for _, e in eventsOf(env) do
				if e.type == "thought" and e.scenarioId == "spec_thought" then
					n += 1
				end
			end
			return n
		end
		local ok, err = pcall(function()
			entities:replicate()
		end)
		expect(ok).toBe(false)
		expect(tostring(err)).toContain("diamonds")
		expect(spawnedIds).toEqual({}) -- nothing committed, no signal
		local function spawnsOf(target)
			local n = 0
			for _, e in eventsOf(env) do
				if e.type == "spawn" and e.id == target then
					n += 1
				end
			end
			return n
		end
		expect(spawnsOf(id)).toBe(0)
		expect(thoughts()).toBe(0)
		c.carrying = nil -- fixed
		entities:replicate()
		expect(spawnsOf(id)).toBe(1)
		expect(spawnedIds).toEqual({ id })
		expect(thoughts()).toBe(1) -- delivered with the next good tick
		entities:replicate()
		expect(spawnsOf(id)).toBe(1)
		expect(spawnedIds).toEqual({ id })
		expect(thoughts()).toBe(1) -- exactly once
	end)

	it("sends at most MAX_RECORDS records a tick; the rest go out on the next ticks (#39 L1)", function()
		local env, entities, match = boot()
		env.mock.players:add({ userId = 1 })
		env.mock:advance(1)
		local max = EntityServiceDef.MAX_RECORDS
		EntityServiceDef.MAX_RECORDS = 5
		local ok, err = pcall(function()
			local seen = {}
			local total = 0
			for _, k in match.host.match.sim.kingdoms do
				total += #k.citizenIds + #k.unitIds
			end
			expect(total > 5).toBe(true)
			local before = #sent(env, "Sim.Snapshot", SnapshotCodec.decode)
			for _ = 1, 20 do
				entities:replicate()
			end
			local snapshots = sent(env, "Sim.Snapshot", SnapshotCodec.decode)
			for i = before + 1, #snapshots do
				expect(#snapshots[i].decoded.records <= 5).toBe(true)
				for _, r in snapshots[i].decoded.records do
					seen[r.id] = true
				end
			end
			local count = 0
			for _ in seen do
				count += 1
			end
			expect(count > 5).toBe(true) -- the capped rest went out on later ticks
		end)
		EntityServiceDef.MAX_RECORDS = max
		assert(ok, err)
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
		-- seq keeps counting across matches, so clients drop late packets of the old world
		local snapshots = sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		for i = 2, #snapshots do
			local a, b = snapshots[i - 1].decoded, snapshots[i].decoded
			expect(a.seq == b.seq or SnapshotCodec.newer(b.seq, a.seq)).toBe(true)
		end
	end)
end)

-- every Sim.Events batch fired to this one player alone (G13.3 kingdom batches), decoded, oldest first
local function kingdomBatches(env, player)
	local out = {}
	for _, entry in env.mock.remotes:sent(remote(env, "Sim.Events"), "toClient") do
		if entry.player == player then
			table.insert(out, (assert(EventCodec.decode(entry.args[1]))))
		end
	end
	return out
end

-- seats userIds 1..count (4 kingdoms of 4 rulers; the 17th is a spectator) and groups them
local function seat(env, match, count: number)
	local byKingdom, spectators = {}, {}
	for userId = 1, count do
		env.mock.players:add({ userId = userId })
	end
	env.mock:advance(0.5)
	for _, player in env.Players:GetPlayers() do
		local kingdomId = match.host.match:kingdomOf(player.UserId)
		if kingdomId == nil then
			table.insert(spectators, player)
		else
			byKingdom[kingdomId] = byKingdom[kingdomId] or {}
			table.insert(byKingdom[kingdomId], player)
		end
	end
	return byKingdom, spectators
end

describe("EntityService kingdom events (G13.3, FL-0079)", function()
	it("sends each kingdom's events to its members only, in order, once, on the next tick", function()
		local env, entities, match = boot()
		local byKingdom, spectators = seat(env, match, 17)
		expect(#byKingdom.crimson >= 1 and #byKingdom.azure >= 1 and #spectators == 1).toBe(true)
		local sim = entities:_sim()
		local citizen = sim.kingdoms.crimson.citizenIds[1]
		local other = sim.kingdoms.azure.citizenIds[1]
		local crimson = {
			{
				type = "thought",
				id = citizen,
				scenarioId = "farmer_drought",
				text = "Le blé ! 🌾",
				icon = "request",
			},
			{ type = "strike", occupation = "farmer", on = true, entityIds = { citizen } },
			{ type = "kcue", occupation = "farmer", cue = "strike_placard", entityIds = { citizen } },
			{ type = "reaction", id = citizen, text = "", tone = "angry" },
		}
		local azure = { { type = "kcue", id = other, cue = "salute" } }
		local first = table.clone(crimson[1])
		entities:sendKingdomEvent("crimson", first)
		entities:sendKingdomEvent("azure", azure[1])
		local struck = table.clone(crimson[2])
		struck.entityIds = table.clone(crimson[2].entityIds)
		entities:sendKingdomEvent("crimson", struck)
		entities:sendKingdomEvent("crimson", crimson[3])
		entities:sendKingdomEvent("crimson", crimson[4])
		first.text = "changed after queueing" -- the queue keeps its own copy
		table.insert(struck.entityIds, 999) -- of the id list too
		for _, player in env.Players:GetPlayers() do
			expect(#kingdomBatches(env, player)).toBe(0) -- nothing before the next tick
		end
		local snapshotsBefore = #sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		env.mock:advance(0.1)
		local snapshots = sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		expect(#snapshots).toBe(snapshotsBefore + 1) -- exactly one tick ran
		local tickTime = snapshots[#snapshots].decoded.serverTime
		env.mock:advance(1) -- later ticks never repeat them
		for kingdomId, members in byKingdom do
			for _, player in members do
				local batches = kingdomBatches(env, player)
				if kingdomId == "crimson" then
					expect(#batches).toBe(1)
					expect(batches[1].events).toEqual(crimson)
					expect(batches[1].serverTime).toBe(tickTime) -- the tick's serverTime
				elseif kingdomId == "azure" then
					expect(#batches).toBe(1)
					expect(batches[1].events).toEqual(azure)
				else
					expect(#batches).toBe(0)
				end
			end
		end
		expect(#kingdomBatches(env, spectators[1])).toBe(0)
		for _, entry in env.mock.remotes:sent(remote(env, "Sim.Events"), "toAllClients") do
			for _, e in assert(EventCodec.decode(entry.args[1])).events do
				expect(e.type).never.toBe("thought") -- G13.3 events never go to everyone
				expect(e.type).never.toBe("reaction")
				expect(e.type).never.toBe("strike")
				expect(e.type).never.toBe("kcue")
			end
		end
	end)

	it("drops a batch that does not encode with one error log; snapshots and other kingdoms go on", function()
		local env, entities, match = boot()
		local byKingdom = seat(env, match, 17)
		local crimsonPlayer, azurePlayer = byKingdom.crimson[1], byKingdom.azure[1]
		local sim = entities:_sim()
		local citizen = sim.kingdoms.crimson.citizenIds[1]
		entities:sendKingdomEvent("crimson", { type = "reaction", id = citizen, text = "fine", tone = "happy" })
		entities:sendKingdomEvent(
			"crimson",
			{ type = "thought", id = citizen, scenarioId = "s", text = 42, icon = "idea" }
		)
		entities:sendKingdomEvent("azure", { type = "strike", occupation = "miner", on = false, entityIds = { 2 } })
		local snapshotsBefore = #sent(env, "Sim.Snapshot", SnapshotCodec.decode)
		env.mock:advance(0.1)
		local errors = {}
		for _, entry in env.mock.logs do
			if entry.level == "error" then
				table.insert(errors, entry)
			end
		end
		expect(#errors).toBe(1)
		expect(errors[1].message).toContain("dropped a kingdom event batch")
		expect(errors[1].fields.kingdom).toBe("crimson")
		expect(errors[1].fields.error).toContain("text must be a string")
		env.mock:clearLogs() -- the error was expected (afterEach fails on any other)
		expect(#kingdomBatches(env, crimsonPlayer)).toBe(0) -- the whole batch is dropped
		expect(#kingdomBatches(env, azurePlayer)).toBe(1)
		expect(kingdomBatches(env, azurePlayer)[1].events).toEqual({
			{ type = "strike", occupation = "miner", on = false, entityIds = { 2 } },
		})
		env.mock:advance(1)
		expect(#sent(env, "Sim.Snapshot", SnapshotCodec.decode) >= snapshotsBefore + 10).toBe(true)
		expect(env.mock:hasLog("error", "replication failed")).toBe(false)
		-- the queue is not stuck: the next good event goes out
		entities:sendKingdomEvent("crimson", { type = "kcue", id = citizen, cue = "cower" })
		env.mock:advance(0.1)
		local batches = kingdomBatches(env, crimsonPlayer)
		expect(#batches).toBe(1)
		expect(batches[1].events).toEqual({ { type = "kcue", id = citizen, cue = "cower" } })
	end)

	it("refuses unknown kingdoms and non-G13.3 types, and a reset drops queued events", function()
		local env, entities, match = boot()
		local byKingdom = seat(env, match, 1)
		local player = byKingdom.crimson[1]
		expect(function()
			entities:sendKingdomEvent("violet", { type = "strike", occupation = "miner", on = true, entityIds = {} })
		end).toThrow("unknown kingdom")
		expect(function()
			entities:sendKingdomEvent(
				"crimson",
				{ type = "spawn", id = 1, kind = "citizen", job = "farmer", kingdom = "gold" }
			)
		end).toThrow("not a G13.3 event type")
		expect(function()
			entities:sendKingdomEvent("crimson", "strike" :: any)
		end).toThrow("not a G13.3 event type")
		entities:sendKingdomEvent("crimson", { type = "strike", occupation = "miner", on = true, entityIds = { 1 } })
		entities:_resetWorld() -- a new match world: ids start over
		env.mock:advance(0.1)
		expect(#kingdomBatches(env, player)).toBe(0)
		local last = eventsOf(env)
		local sawReset = false
		for _, e in last do
			sawReset = sawReset or e.type == "reset"
		end
		expect(sawReset).toBe(true)
	end)
end)

describe("EntityService VS-1 reactions (CONTRACTS G5, FL-0050)", function()
	it("a keep reaching level 2 makes its citizens near it celebrate, once; far or foreign ones don't", function()
		local env, entities, match = boot()
		local byKingdom = seat(env, match, 5) -- rulers in several kingdoms, so several are populated
		local sim = entities:_sim()
		local k = sim.kingdoms.crimson
		local keep = sim.buildings[k.keepId]
		local radius = sim.catalog.tuning.celebrateRadius
		local near = sim.citizens[k.citizenIds[1]]
		local far = sim.citizens[k.citizenIds[2]]
		near.x, near.z = keep.x + radius * 0.5, keep.z
		far.x, far.z = keep.x + radius + 30, keep.z
		local foreignKingdom
		for kingdomId in byKingdom do
			if kingdomId ~= "crimson" and #sim.kingdoms[kingdomId].citizenIds > 0 then
				foreignKingdom = sim.kingdoms[kingdomId]
				break
			end
		end
		local foreign = sim.citizens[assert(foreignKingdom).citizenIds[1]]
		foreign.x, foreign.z = keep.x + 1, keep.z + 1 -- a stranger at the gate
		local before = #eventsOf(env)
		keep.pendingLevel = 2
		keep.progress = 0
		expect(sim:addWork(keep, 1e9)).toBe(true) -- the upgrade completes inside the simulation
		env.mock:advance(0.2)
		local celebrated = {}
		local all = eventsOf(env)
		for i = before + 1, #all do
			local e = all[i]
			if e.type == "cue" and e.cue == "celebrate" then
				celebrated[e.id] = (celebrated[e.id] or 0) + 1
			end
		end
		expect(celebrated[near.id]).toBe(1)
		expect(celebrated[far.id]).toBeNil()
		expect(celebrated[foreign.id]).toBeNil()
		for id in celebrated do
			local c = sim.citizens[id]
			expect(c.kingdomId).toBe("crimson")
		end
		-- level 3 is not the level-2 celebration
		before = #eventsOf(env)
		keep.pendingLevel = 3
		keep.progress = 0
		sim:addWork(keep, 1e9)
		env.mock:advance(0.2)
		all = eventsOf(env)
		for i = before + 1, #all do
			expect(all[i].type == "cue" and all[i].cue == "celebrate").toBe(false)
		end
	end)
end)

-- FL-0125 (D-055 (2), (5)): in the full match each player's snapshots follow their Sim.Focus (else their character):
-- near entities at the snapshot rate, the rest every farEvery-th tick, own soldiers always.
describe("EntityService interest tiers and Sim.Focus (D-055)", function()
	-- ids of the records each player got, per snapshot (a list of sets, oldest first)
	local function snapshotsFor(env, player)
		local out = {}
		for _, entry in env.mock.remotes:sent(remote(env, "Sim.Snapshot")) do
			if entry.player == player or entry.direction == "toAllClients" then
				local set = {}
				for _, r in assert(SnapshotCodec.decode(entry.args[1])).records do
					set[r.id] = true
				end
				table.insert(out, set)
			end
		end
		return out
	end

	local function focus(env, player, x, z)
		env.mock.remotes:asClient(player, function()
			remote(env, "Sim.Focus"):FireServer(Vector3.new(x, 0, z))
		end)
	end

	-- one walking citizen near each pole of the world, so both are "moving" and selected every tick
	local function twoCamps(_, entities)
		local near = entities:spawn("citizen", "crimson", "hauler", Vector3.new(-600, 0, 0))
		local far = entities:spawn("citizen", "azure", "hauler", Vector3.new(600, 0, 0))
		local sim = entities:_sim()
		sim.citizens[near].activity, sim.citizens[far].activity = "Walk", "Walk"
		return near, far
	end

	it("sends the entities near each player's focus every tick and the rest every farEvery-th", function()
		local env, entities = boot({ mode = "match" })
		local a = env.mock.players:add({ userId = 1 })
		local b = env.mock.players:add({ userId = 2 })
		env.mock:advance(0.5)
		local west, east = twoCamps(env, entities)
		focus(env, a, -600, 0)
		focus(env, b, 600, 0)
		local before = #snapshotsFor(env, a)
		env.mock:advance(2)
		local forA, forB = snapshotsFor(env, a), snapshotsFor(env, b)
		local ticks = #forA - before
		expect(ticks >= 15).toBe(true)
		local westA, eastA, westB, eastB = 0, 0, 0, 0
		for i = before + 1, #forA do
			westA += if forA[i][west] then 1 else 0
			eastA += if forA[i][east] then 1 else 0
		end
		for i = #forB - ticks + 1, #forB do
			westB += if forB[i][west] then 1 else 0
			eastB += if forB[i][east] then 1 else 0
		end
		expect(westA).toBe(ticks) -- near A: every snapshot
		expect(eastB).toBe(ticks) -- near B: every snapshot
		expect(eastA < ticks / 2).toBe(true) -- far from A: about every fifth
		expect(eastA >= 1).toBe(true)
		expect(westB < ticks / 2).toBe(true)
	end)

	it("keeps a player's own soldiers in their snapshots wherever they look", function()
		local env, entities = boot({ mode = "match" })
		local a = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local mine = entities:spawn("soldier", "crimson", "soldier", Vector3.new(-600, 0, 0))
		local theirs = entities:spawn("soldier", "azure", "soldier", Vector3.new(-600, 10, 0))
		local sim = entities:_sim()
		focus(env, a, 600, 0)
		local before = #snapshotsFor(env, a)
		for _ = 1, 20 do -- both soldiers shift a little every 0.1 s, so both are selected on every snapshot
			sim.units[mine].x += 0.5
			sim.units[theirs].x += 0.5
			env.mock:advance(0.1)
		end
		local list = snapshotsFor(env, a)
		local ownSeen, otherSeen = 0, 0
		for i = before + 1, #list do
			ownSeen += if list[i][mine] then 1 else 0
			otherSeen += if list[i][theirs] then 1 else 0
		end
		expect(ownSeen).toBe(#list - before)
		expect(otherSeen < (#list - before) / 2).toBe(true)
		expect(otherSeen >= 1).toBe(true)
	end)

	it("a stale focus falls back to the character, and a missing character means everything is far", function()
		local env, entities = boot({ mode = "match" })
		local a = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local west = twoCamps(env, entities)
		focus(env, a, -600, 0)
		env.mock:advance(1)
		local before = #snapshotsFor(env, a)
		env.mock:advance(1)
		local fresh = #snapshotsFor(env, a) - before
		local seen = 0
		for i = before + 1, #snapshotsFor(env, a) do
			seen += if snapshotsFor(env, a)[i][west] then 1 else 0
		end
		expect(seen).toBe(fresh) -- a fresh focus: near
		env.mock:advance(MatchConfig.interest.focusStaleSeconds + 1) -- no keepalive: the focus is ignored
		local mid = #snapshotsFor(env, a)
		env.mock:advance(2)
		local list = snapshotsFor(env, a)
		local stale = 0
		for i = mid + 1, #list do
			stale += if list[i][west] then 1 else 0
		end
		expect(stale < (#list - mid) / 2).toBe(true) -- no character in Lune: far
	end)

	it("the slice broadcasts everything to everyone, whatever the focus", function()
		local env, entities = boot()
		local a = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		local _, east = twoCamps(env, entities)
		focus(env, a, -600, 0)
		local before = #snapshotsFor(env, a)
		env.mock:advance(2)
		local list = snapshotsFor(env, a)
		local seen = 0
		for i = before + 1, #list do
			seen += if list[i][east] then 1 else 0
		end
		expect(seen).toBe(#list - before)
	end)

	it("ignores Y, clamps X and Z to the wire's range, and refuses what the validator refuses", function()
		local env, entities = boot({ mode = "match" })
		local a = env.mock.players:add({ userId = 1 })
		focus(env, a, 1e9 % 3000, 0) -- a legal vector
		env.mock.remotes:asClient(a, function()
			remote(env, "Sim.Focus"):FireServer(Vector3.new(0, 1e6, 0)) -- longer than 4000 studs: refused
			remote(env, "Sim.Focus"):FireServer("not a vector")
		end)
		local stored = entities._focus[1]
		expect(stored).never.toBeNil()
		expect(stored.z).toBe(0)
		expect(math.abs(stored.x) <= SnapshotCodec.MAX_COORD).toBe(true)
	end)
	it("holds the bandwidth budget with 300 entities and 8 players: tiers cost far less than broadcast", function()
		local function measure(mode: string)
			local env, entities = boot({ mode = mode })
			local players = {}
			for userId = 1, 8 do
				players[userId] = env.mock.players:add({ userId = userId })
			end
			env.mock:advance(0.5)
			local rng = Random.new(5)
			local ids = {}
			for i = 1, 300 do
				local kingdom = ({ "crimson", "azure", "emerald", "gold" })[i % 4 + 1]
				table.insert(
					ids,
					entities:spawn(
						"soldier",
						kingdom,
						"soldier",
						Vector3.new(rng:NextNumber(-500, 500), 0, rng:NextNumber(-500, 500))
					)
				)
			end
			local sim = entities:_sim()
			local base = 0
			for _, entry in env.mock.remotes:sent(remote(env, "Sim.Snapshot")) do
				base += buffer.len(entry.args[1])
			end
			local started = os.clock()
			for step = 1, 100 do -- 10 s, every entity moving on every snapshot: the worst case
				for _, id in ids do
					sim.units[id].x += if step % 2 == 0 then 0.4 else -0.4
				end
				if step % 3 == 0 then
					for _, player in players do
						focus(env, player, rng:NextNumber(-400, 400), rng:NextNumber(-400, 400))
					end
				end
				env.mock:advance(0.1)
			end
			local cpuMs = (os.clock() - started) * 1000 / 100
			local total = -base
			for _, entry in env.mock.remotes:sent(remote(env, "Sim.Snapshot")) do
				total += buffer.len(entry.args[1])
			end
			-- the slice fires each buffer once to everybody; the full match fires one stream per player
			return if mode == "slice" then total / 10 else total / 10 / 8, cpuMs
		end
		local sliceBytes, sliceMs = measure("slice")
		local matchBytes, matchMs = measure("match")
		print(
			`INTEREST 300 moving entities, 8 players: bytes/s per player slice {math.floor(sliceBytes)}, match {math.floor(
				matchBytes
			)}; ms per 0.1 s step (sim + encode, headless) slice {math.floor(sliceMs * 100) / 100}, match {math.floor(
				matchMs * 100
			) / 100}`
		)
		expect(matchBytes < sliceBytes * 0.7).toBe(true)
		expect(matchBytes <= 20000).toBe(true) -- BRIEF §14: <= 20 KB/s per player
	end)
	it("drops a player's focus when they leave (FORGE-07 L1)", function()
		local env, entities = boot({ mode = "match" })
		local a = env.mock.players:add({ userId = 1 })
		env.mock:advance(0.5)
		focus(env, a, 10, 10)
		expect(entities._focus[1]).never.toBeNil()
		env.mock.players:remove(a)
		env.mock:advance(0.5)
		expect(entities._focus[1]).toBeNil()
	end)

	it("the far tier never slows an idle entity's refresh: farEvery divides REFRESH_EVERY (FORGE-07 L2)", function()
		local Def = require("@game/ServerScriptService/Game/Services/EntityService")
		expect(Def.REFRESH_EVERY % MatchConfig.interest.farEvery).toBe(0)
	end)
end)
