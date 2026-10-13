--!strict
--[[
	EntityService — server-simulated entities and their replication (CONTRACTS G4, D-023/D-025, FL-0049).
	Owner: FORGE-01.

	Citizens and soldiers live in the kingdom simulation (MatchService's host); no Humanoids exist on
	the server. This service exposes them through the G4 API and streams them to every client
	(VS-1: no interest tiers):
		Sim.Snapshot  10 Hz, SnapshotCodec v2 buffers (≤ 80 records, ≤ 900 B). Moving entities (walk,
		              carry, flee, fight) and any entity whose sent state changed go out every
		              snapshot; the rest are refreshed round-robin about once per second.
		Sim.Events    one EventCodec buffer per snapshot tick when anything happened: spawn, despawn,
		              job changes (found by diffing the live entity set), the cues deposit (a citizen's
		              delivery) and die, and reset when a new match world replaces the old one.
		Sim.GetEntities  every live entity as EventCodec "full" records (spawn + current state).
	serverTime on both = seconds since Founding began (Match.State startedAtServerTime).

	API (G4)
		EntityService:spawn(kind, kingdom, job, position: Vector3): EntityId   -- "citizen" | "soldier"
		EntityService:get(id): EntityState?          -- server only; a copy (Sim/Replication.entityState)
		EntityService:despawn(id, reason)
		EntityService.spawned: Signal<(EntityId)> · .despawned: Signal<(EntityId, reason)>
		EntityService.jobChanged: Signal<(EntityId, JobId)>
	Extra
		EntityService:replicate()                    -- one snapshot tick (the loop calls it; specs too)
		EntityService:stats() -> { entities, bytesPerSecond, encodeMsP99, simMsP99, snapshotsSent }
	Studio debug (FL-0068): command sim.spawn(count) spawns test citizens around the presser's keep.
	Performance (G7/FL-0049): every 30 s logs "Kingdom perf" with entities, bytes/s per player,
	sim ms p99 per host tick and encode ms p99 per snapshot tick.
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Replication = require("@game/ReplicatedStorage/Game/Sim/Replication")
local SnapshotCodec = require("@game/ReplicatedStorage/Game/Sim/SnapshotCodec")

local EntityService = {}
EntityService.__index = EntityService

local Def = { name = "EntityService", dependencies = { "MatchService", "RemoteService" } }

-- The running service, for the Studio debug commands (registered once per process, like MatchService).
local active: any = nil

local function registerDebugCommands()
	for _, command in DebugCommands.list() do
		if command.name == "sim.spawn" then
			return
		end
	end
	DebugCommands.register({
		name = "sim.spawn",
		label = "Spawn test citizens around me (FL-0049 perf run)",
		args = { Validate.integer(1, 300) },
		run = function(player: any, count: number): string?
			if active == nil then
				return "no entity service is running"
			end
			local kingdom = active._match.host.match:kingdomOf(player.UserId)
			if kingdom == nil then
				return "you are not in a kingdom"
			end
			local k = active:_sim().kingdoms[kingdom]
			local jobs = { "farmer", "woodcutter", "miner", "builder", "hauler" }
			for i = 1, count do
				local angle = i * 2.4
				local radius = 12 + (i % 10) * 3
				active:spawn(
					"citizen",
					kingdom,
					jobs[i % #jobs + 1],
					Vector3.new(k.x + math.cos(angle) * radius, 0, k.z + math.sin(angle) * radius)
				)
			end
			return `spawned {count} citizens for {kingdom}`
		end,
	})
end

Def.SNAPSHOT_HZ = 10
Def.REFRESH_EVERY = 10 -- snapshot ticks between round-robin refreshes of a still entity (~1 s)
Def.LOG_EVERY = 30
Def.WINDOW = 300 -- samples kept for the p99 figures

local function p99(samples: { number }): number
	if #samples == 0 then
		return 0
	end
	local sorted = table.clone(samples)
	table.sort(sorted)
	return sorted[math.max(1, math.ceil(#sorted * 0.99))]
end

function Def.new(env: any, registry: any)
	local self = setmetatable({}, EntityService)
	self._env = env
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	self.spawned = Signal.new()
	self.despawned = Signal.new()
	self.jobChanged = Signal.new()
	self._tracker = Replication.new()
	self._known = {} :: { [number]: { kind: string, job: string, kingdom: string } }
	self._sentState = {} :: { [number]: string } -- id -> last sent quantised state
	self._pending = {} :: { any } -- events gathered since the last tick
	self._despawnReason = {} :: { [number]: string }
	self._vanishing = {} :: { [number]: number } -- id -> frame it left the simulation, awaiting its die cue
	self._dieQueued = {} :: { [number]: boolean }
	self._seq = 0
	self._frame = 0
	self._bytes = 0
	self._sent = 0
	self._encodeMs = {} :: { number }
	self._windowStart = env.clock()
	self._running = false
	self._remotes:handle("Sim.GetEntities", function(_player: any)
		return self:_fullState()
	end)
	return self
end

function EntityService:_sim(): any
	return self._match.host.match.sim
end

function EntityService:_serverTime(): number
	local started = self._match.host:phaseInfo().startedAtServerTime
	return math.max(0, self._env.serverTimeNow() - started)
end

function EntityService:_fullState(): buffer
	local frame = self._tracker:frame(self:_sim())
	local events = {}
	for _, r in frame.records do
		local who = frame.identity[r.id]
		table.insert(events, {
			type = "full",
			id = r.id,
			kind = who.kind,
			job = who.job,
			kingdom = who.kingdom,
			look = who.look,
			x = r.x,
			y = r.y,
			z = r.z,
			yaw = r.yaw,
			action = r.action,
			carrying = r.carrying,
		})
	end
	return EventCodec.encode(self:_serverTime(), events)
end

function EntityService:start()
	local host = self._match.host
	host.events:connect(function(name: string, event: any)
		if name == "ResourceGathered" and event.source == "citizen" and event.citizenId then
			table.insert(
				self._pending,
				{ type = "cue", id = event.citizenId, cue = "deposit", resource = event.resource }
			)
		elseif name == "CitizenDied" then
			self:_queueDeath(event.citizenId, event.cause)
		elseif name == "UnitKilled" then
			self:_queueDeath(event.unitId, "killed")
		elseif name == "MatchPhaseChanged" and event.previous == "Results" then
			-- a fresh world: ids start over, so clients drop everything before the new spawns
			for id in self._known do
				self.despawned:fire(id, "reset")
			end
			self._known = {}
			self._sentState = {}
			self._vanishing = {}
			self._dieQueued = {}
			self._tracker = Replication.new()
			self._pending = { { type = "reset" } }
		end
	end)
	active = self
	registerDebugCommands()
	self._running = true
	self._env.spawn(function()
		while self._running do
			self._env.wait(1 / Def.SNAPSHOT_HZ)
			if not self._running then
				break
			end
			local ok, err = pcall(self.replicate, self)
			if not ok then
				self._env.log("error", "EntityService: replication failed", { error = tostring(err) })
			end
		end
	end)
end

-- A death reaches this service through the host's event fan-out (its own tick), possibly after the
-- entity has already left the simulation; the die cue always goes out before the despawn.
function EntityService:_queueDeath(id: number, reason: string)
	if self._dieQueued[id] then
		return
	end
	self._dieQueued[id] = true
	self._despawnReason[id] = self._despawnReason[id] or reason
	table.insert(self._pending, { type = "cue", id = id, cue = "die" })
end

-- How many snapshot ticks a vanished entity waits for its die cue before it is despawned anyway.
Def.DEATH_GRACE = 3

function EntityService:_despawnEvent(id: number): { [string]: any }
	self._sentState[id] = nil
	self._vanishing[id] = nil
	self._dieQueued[id] = nil
	self.despawned:fire(id, self._despawnReason[id] or "removed")
	self._despawnReason[id] = nil
	return { type = "despawn", id = id }
end

-- Cues for entities that never reached a client (spawned and died within one tick) are dropped.
function EntityService:_diff(identity: { [number]: any }): { any }
	local events = {}
	local pending = self._pending
	self._pending = {}
	for _, e in pending do
		local id = e.id
		if e.type ~= "cue" or self._known[id] ~= nil or identity[id] ~= nil or self._vanishing[id] ~= nil then
			table.insert(events, e)
			if e.type == "cue" and e.cue == "die" and self._vanishing[id] ~= nil then
				table.insert(events, self:_despawnEvent(id))
			end
		elseif e.type == "cue" and e.cue == "die" then
			self._dieQueued[id] = nil
		end
	end
	local ids = {}
	for id in identity do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local now, before = identity[id], self._known[id]
		if before == nil then
			table.insert(
				events,
				{ type = "spawn", id = id, kind = now.kind, job = now.job, kingdom = now.kingdom, look = now.look }
			)
			self.spawned:fire(id)
		elseif before.job ~= now.job then
			table.insert(events, { type = "job", id = id, job = now.job })
			self.jobChanged:fire(id, now.job)
		end
	end
	-- a citizen whose look changed (the Studio reseed, FL-0104) is sent as a spawn again, so every
	-- connected client swaps its rig (#91 M1); a new client gets the new look in its first spawn anyway
	for _, id in ids do
		local now, before = identity[id], self._known[id]
		-- (the same profile.look table every tick unless a reseed replaced it: compared by key only then)
		if before ~= nil and before.look ~= now.look and Kit.lookKey(before.look) ~= Kit.lookKey(now.look) then
			table.insert(
				events,
				{ type = "spawn", id = id, kind = now.kind, job = now.job, kingdom = now.kingdom, look = now.look }
			)
		end
	end
	local gone = {}
	for id in self._known do
		if identity[id] == nil then
			table.insert(gone, id)
		end
	end
	table.sort(gone)
	for _, id in gone do
		if self._dieQueued[id] then
			-- its die cue is in this batch (above): despawn right after it
			table.insert(events, self:_despawnEvent(id))
		else
			self._vanishing[id] = self._frame -- wait briefly for the die cue
		end
	end
	local expired = {}
	for id, since in self._vanishing do
		if self._frame - since >= Def.DEATH_GRACE then
			table.insert(expired, id)
		end
	end
	table.sort(expired)
	for _, id in expired do
		table.insert(events, self:_despawnEvent(id))
	end
	self._known = identity
	return events
end

-- Which records go out this tick: moving or changed entities, plus a round-robin refresh.
function EntityService:_select(records: { any }): { any }
	local out = {}
	for _, r in records do
		local key =
			`{SnapshotCodec.quantize(r.x)},{SnapshotCodec.quantize(r.z)},{math.round(r.yaw * 40)},{r.action},{r.carrying}`
		if
			Replication.MOVING[r.action]
			or self._sentState[r.id] ~= key
			or (r.id + self._frame) % Def.REFRESH_EVERY == 0
		then
			self._sentState[r.id] = key
			table.insert(out, r)
		end
	end
	return out
end

-- One snapshot tick to every player. Specs may call it directly.
function EntityService:replicate()
	local started = self._env.clock()
	local frame = self._tracker:frame(self:_sim())
	local events = self:_diff(frame.identity)
	self._frame += 1
	self._seq = (self._seq + 1) % 65536
	local serverTime = self:_serverTime()
	local outgoing = {}
	if #events > 0 then
		table.insert(outgoing, { "Sim.Events", EventCodec.encode(serverTime, events) })
	end
	for _, chunk in SnapshotCodec.encodeChunks(self:_select(frame.records), self._seq, serverTime) do
		table.insert(outgoing, { "Sim.Snapshot", chunk })
	end
	table.insert(self._encodeMs, (self._env.clock() - started) * 1000)
	if #self._encodeMs > Def.WINDOW then
		table.remove(self._encodeMs, 1)
	end
	local players = #self._env.Players:GetPlayers()
	for _, item in outgoing do
		self._remotes:fireAll(item[1], item[2])
		self._bytes += buffer.len(item[2]) * players
		self._sent += 1
	end
	if self._env.clock() - self._windowStart >= Def.LOG_EVERY then
		self._env.log("info", "Kingdom perf", self:stats())
		self._bytes = 0
		self._windowStart = self._env.clock()
	end
end

function EntityService:stats(): { [string]: number }
	local sim = self:_sim()
	local elapsed = math.max(1e-6, self._env.clock() - self._windowStart)
	local players = math.max(1, #self._env.Players:GetPlayers())
	return {
		entities = #sim.citizenOrder + #sim.unitOrder,
		bytesPerSecond = math.floor(self._bytes / elapsed / players + 0.5),
		encodeMsP99 = math.floor(p99(self._encodeMs) * 1000 + 0.5) / 1000,
		simMsP99 = self._match.host:simMsP99(),
		snapshotsSent = self._sent,
	}
end

function EntityService:spawn(kind: string, kingdom: string, job: string, position: Vector3): number
	local sim = self:_sim()
	local k = sim.kingdoms[kingdom]
	assert(k ~= nil and k.alive, `EntityService:spawn: unknown or fallen kingdom '{tostring(kingdom)}'`)
	if kind == "citizen" then
		assert(sim.catalog.jobs[job] ~= nil, `EntityService:spawn: unknown job '{tostring(job)}'`)
		local c = sim:_spawnCitizen(k, job, position.X, position.Z)
		sim:_assignHomes(k)
		return c.id
	elseif kind == "soldier" then
		local unitType = if sim.catalog.units[job] then job else "soldier"
		return Military.spawnUnit(sim, k, unitType, position.X, position.Z).id
	end
	error(`EntityService:spawn: unsupported kind '{tostring(kind)}'`)
end

function EntityService:get(id: number): any?
	return Replication.entityState(self:_sim(), id)
end

function EntityService:despawn(id: number, reason: string)
	local sim = self:_sim()
	local c = sim.citizens[id]
	local u = sim.units[id]
	if c == nil and u == nil then
		return
	end
	self._despawnReason[id] = reason
	self:_queueDeath(id, reason)
	if c then
		sim:killCitizen(c, reason)
	else
		Military.killUnit(sim, u, nil)
	end
end

function EntityService:destroy()
	if active == self then
		active = nil
	end
	self._running = false
	self.spawned:disconnectAll()
	self.despawned:disconnectAll()
	self.jobChanged:disconnectAll()
end

return Def
