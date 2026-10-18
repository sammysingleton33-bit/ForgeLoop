--!strict
--[[
	EntityService — server-simulated entities and their replication (CONTRACTS G4, D-023/D-025, FL-0049).
	Owner: FORGE-01.

	Citizens and soldiers live in the kingdom simulation (MatchService's host); no Humanoids exist on
	the server. This service exposes them through the G4 API and streams them to the clients (the slice: every client gets everything; the full match: interest tiers,
	Sim.Focus and Sim/Interest, D-055):
		Sim.Snapshot  10 Hz, SnapshotCodec v2 buffers (≤ 80 records, ≤ 900 B). Moving entities (walk,
		              carry, flee, fight) and any entity whose sent state changed go out every
		              snapshot; the rest are refreshed round-robin about once per second.
		Sim.Events    one EventCodec buffer per snapshot tick when anything happened: spawn, despawn,
		              job changes (found by diffing the live entity set), the cues deposit (a citizen's
		              delivery) and die, and reset when a new match world replaces the old one.
		              Then, per kingdom with queued G13.3 events (sendKingdomEvent), one more buffer
		              with the same serverTime, fired only to that kingdom's current members
		              (match:kingdomOf(userId)); never to other kingdoms or spectators.
		Sim.GetEntities(afterId?) -> (buffer, nextAfterId?)
		              every live entity as EventCodec "full" records (spawn + current state), in pages
		              of at most Def.PAGE_MAX records by ascending id so each buffer stays within G4's
		              900 B (FL-0109, #61 low): the page holds the entities with id > afterId (0 or nil:
		              from the start); nextAfterId is the last id on the page when more follow, else nil.
		              The client asks again with it until nil. Pages are read live, so an entity spawned
		              or despawned meanwhile is covered by Sim.Events (G4 client rules).
	serverTime on both = seconds since Founding began (Match.State startedAtServerTime).

	API (G4)
		EntityService:spawn(kind, kingdom, job, position: Vector3): EntityId   -- "citizen" | "soldier"
		EntityService:get(id): EntityState?          -- server only; a copy (Sim/Replication.entityState)
		EntityService:despawn(id, reason)
		EntityService.spawned: Signal<(EntityId)> · .despawned: Signal<(EntityId, reason)>
		EntityService.jobChanged: Signal<(EntityId, JobId)>
	Extra
		EntityService:sendKingdomEvent(kingdomId, event)   -- G13.3, FL-0079: queue one thought, reaction,
			strike or kcue event (EventCodec shapes) for that kingdom's members. The next replicate()
			encodes the kingdom's queue in order as its own batch, sends it once, then clears it. A batch
			that does not encode is dropped with one error log; the tick goes on. A reset (new match
			world) drops queued events: entity ids start over.
		EntityService:replicate()                    -- one snapshot tick (the loop calls it; specs too)
		EntityService:stats() -> { entities, bytesPerSecond, encodeMsP99, simMsP99, snapshotsSent }
	Studio debug (FL-0068): command sim.spawn(count) spawns test citizens around the presser's keep.
	Performance (G7/FL-0049): every 30 s logs "Kingdom perf" with entities, bytes/s per player,
	sim ms p99 per host tick and encode ms p99 per snapshot tick.
	Robustness (#39 L1): ids above MAX_ID (the wire's u16) are not replicated, and positions off the wire's
	range (±SnapshotCodec.MAX_COORD, or not finite) are not sent (one warning each per world); a tick sends
	at most MAX_RECORDS records (over the cap each tick starts further along; the rest go later); a tick
	is encoded before anything is committed, so a tick that fails to encode changes nothing (no state, no
	signals) and the next one sends it all again.
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Validate = require("@game/ReplicatedStorage/Forge/Core/Validate")
local DebugCommands = require("@game/ReplicatedStorage/Forge/Debug/DebugCommands")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Military = require("@game/ReplicatedStorage/Game/Sim/Military")
local Interest = require("@game/ReplicatedStorage/Game/Sim/Interest")
local MatchConfig = require("@game/ReplicatedStorage/Forge/Config/Match")
local Replication = require("@game/ReplicatedStorage/Game/Sim/Replication")
local SnapshotCodec = require("@game/ReplicatedStorage/Game/Sim/SnapshotCodec")

-- Only a validated CitizenLook goes on the wire (FL-0109, #61 low): exactly the four G13.2 fields, each a
-- palette index (Kit.normalizeLook), whatever the profile holds; nil (no look) stays nil.
local function wireLook(look: any): any
	return if look == nil then nil else Kit.normalizeLook(look)
end

local EntityService = {}
EntityService.__index = EntityService

local Def = { name = "EntityService", dependencies = { "MatchService", "RemoteService" } }

Def.MAX_ID = 65535 -- ids travel as u16 (G4)
Def.MAX_RECORDS = SnapshotCodec.MAX_RECORDS * SnapshotCodec.MAX_CHUNKS -- one tick's snapshot chunks

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
Def.PAGE_MAX = 49 -- Sim.GetEntities records per page: 6 B header + 49 x 18 B "full" records = 888 B <= 900 B
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
	self._kingdomPending = {} :: { [string]: { any } } -- kingdom -> its G13.3 events since the last tick
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
	self._deferred = nil :: { any }? -- signals of the tick being encoded, fired once it has encoded
	self._warned = {} :: { [string]: boolean } -- warnings given this world (ids, offMap)
	self._focus = {} :: { [number]: { x: number, z: number, at: number } } -- Sim.Focus per player (interest only)
	self._remotes:handle("Sim.Focus", function(player: any, focus: Vector3)
		local limit = SnapshotCodec.MAX_COORD
		self._focus[player.UserId] = {
			x = math.clamp(focus.X, -limit, limit),
			z = math.clamp(focus.Z, -limit, limit),
			at = self._env.clock(),
		}
	end)
	self._remotes:handle("Sim.GetEntities", function(_player: any, afterId: number?)
		return self:_fullState(afterId)
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

local function onWire(v: number): boolean
	return v == v and math.abs(v) <= SnapshotCodec.MAX_COORD
end

-- The tracker's frame without what the wire cannot carry: ids over MAX_ID (not replicated at all) and
-- positions off the wire's range (the entity keeps its last sent position). One warning each per world.
function EntityService:_replicable(): any
	local frame = self._tracker:frame(self:_sim())
	local over = 0
	for id in frame.identity do
		if id > Def.MAX_ID then
			frame.identity[id] = nil
			over += 1
		end
	end
	local records, offMap = {}, 0
	for _, r in frame.records do
		if r.id > Def.MAX_ID then
			continue
		elseif onWire(r.x) and onWire(r.y) and onWire(r.z) then
			table.insert(records, r)
		else
			offMap += 1
		end
	end
	frame.records = records
	if over > 0 and not self._warned.ids then
		self._warned.ids = true
		self._env.log("warn", "EntityService: entities with ids over 65535 are not replicated", { count = over })
	end
	if offMap > 0 and not self._warned.offMap then
		self._warned.offMap = true
		self._env.log("warn", "EntityService: entity positions off the wire's range are not sent", { count = offMap })
	end
	return frame
end

-- A signal fired by the tick being encoded waits until the tick is sent; outside a tick it fires now.
function EntityService:_emit(signal: any, ...: any)
	if self._deferred then
		table.insert(self._deferred, table.pack(signal, ...))
	else
		signal:fire(...)
	end
end

-- One Sim.GetEntities page: the live entities with id > afterId, ascending, at most PAGE_MAX of them,
-- and the id to ask after for the next page (nil on the last one).
function EntityService:_fullState(afterId: number?): (buffer, number?)
	local frame = self:_replicable()
	local after = afterId or 0
	local records = {} -- ascending ids: Replication sorts the frame
	for _, r in frame.records do
		if r.id > after then
			table.insert(records, r)
		end
	end
	local events = {}
	for i = 1, math.min(#records, Def.PAGE_MAX) do
		local r = records[i]
		local who = frame.identity[r.id]
		table.insert(events, {
			type = "full",
			id = r.id,
			kind = who.kind,
			job = who.job,
			kingdom = who.kingdom,
			look = wireLook(who.look),
			x = r.x,
			y = r.y,
			z = r.z,
			yaw = r.yaw,
			action = r.action,
			carrying = r.carrying,
		})
	end
	local nextAfter = if #records > Def.PAGE_MAX then records[Def.PAGE_MAX].id else nil
	return EventCodec.encode(self:_serverTime(), events), nextAfter
end

function EntityService:start()
	local host = self._match.host
	host.events:connect(function(name: string, event: any)
		if name == "ResourceGathered" and event.source == "citizen" and event.citizenId then
			table.insert(
				self._pending,
				{ type = "cue", id = event.citizenId, cue = "deposit", resource = event.resource }
			)
		elseif name == "BuildingCompleted" and event.kind == "keep" and event.level == 2 then
			self:_celebrate(event.kingdomId, event.buildingId)
		elseif name == "CitizenDied" then
			self:_queueDeath(event.citizenId, event.cause)
		elseif name == "UnitKilled" then
			self:_queueDeath(event.unitId, "killed")
		elseif name == "MatchPhaseChanged" and event.previous == "Results" then
			self:_resetWorld()
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

-- The keep reached level 2 (CONTRACTS G5 VS-1 reaction): every citizen of the kingdom within
-- tuning.celebrateRadius of it plays the celebrate cue, once.
function EntityService:_celebrate(kingdomId: string, keepId: number)
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	local keep = sim.buildings[keepId]
	if k == nil or keep == nil then
		return
	end
	local radius = sim.catalog.tuning.celebrateRadius
	for _, cid in k.citizenIds do
		local c = sim.citizens[cid]
		local dx, dz = c.x - keep.x, c.z - keep.z
		if dx * dx + dz * dz <= radius * radius then
			table.insert(self._pending, { type = "cue", id = cid, cue = "celebrate" })
		end
	end
end

-- A fresh world: ids start over, so clients drop everything before the new spawns, and events
-- queued for the old world's entities are dropped.
function EntityService:_resetWorld()
	for id in self._known do
		self.despawned:fire(id, "reset")
	end
	self._known = {}
	self._sentState = {}
	self._vanishing = {}
	self._dieQueued = {}
	self._tracker = Replication.new()
	self._pending = { { type = "reset" } }
	self._kingdomPending = {}
	self._warned = {} -- a new world may warn again (#39 L2)
end

local KINGDOM_EVENT_TYPES = { thought = true, reaction = true, strike = true, kcue = true }

-- G13.3: queues one conversation event for a kingdom's members (sent on the next tick).
function EntityService:sendKingdomEvent(kingdomId: string, event: { [string]: any })
	assert(
		table.find(EventCodec.KINGDOMS, kingdomId) ~= nil,
		`EntityService:sendKingdomEvent: unknown kingdom '{tostring(kingdomId)}'`
	)
	local kind = if type(event) == "table" then event.type else typeof(event) -- e.g. "string": refused
	assert(KINGDOM_EVENT_TYPES[kind], `EntityService:sendKingdomEvent: not a G13.3 event type '{tostring(kind)}'`)
	local queue = self._kingdomPending[kingdomId]
	if queue == nil then
		queue = {}
		self._kingdomPending[kingdomId] = queue
	end
	local copy = table.clone(event)
	if type(copy.entityIds) == "table" then
		copy.entityIds = table.clone(copy.entityIds) -- the queue keeps its own list too
	end
	table.insert(queue, copy)
end

-- This tick's kingdom batches, in KINGDOMS order. A batch that fails to encode is logged and dropped.
function EntityService:_kingdomBatches(serverTime: number): { { any } }
	local out = {}
	local pending = self._kingdomPending
	self._kingdomPending = {}
	for _, kingdomId in EventCodec.KINGDOMS do
		local queue = pending[kingdomId]
		if queue == nil then
			continue
		end
		local ok, result = pcall(EventCodec.encode, serverTime, queue)
		if ok then
			table.insert(out, { "Sim.Events", result, kingdomId })
		else
			self._env.log(
				"error",
				"EntityService: dropped a kingdom event batch",
				{ kingdom = kingdomId, events = #queue, error = tostring(result) }
			)
		end
	end
	return out
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
	self:_emit(self.despawned, id, self._despawnReason[id] or "removed")
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
			table.insert(events, {
				type = "spawn",
				id = id,
				kind = now.kind,
				job = now.job,
				kingdom = now.kingdom,
				look = wireLook(now.look),
			})
			self:_emit(self.spawned, id)
		elseif before.job ~= now.job then
			table.insert(events, { type = "job", id = id, job = now.job })
			self:_emit(self.jobChanged, id, now.job)
		end
	end
	-- a citizen whose look changed (the Studio reseed, FL-0104) is sent as a spawn again, so every
	-- connected client swaps its rig (#91 M1); a new client gets the new look in its first spawn anyway
	for _, id in ids do
		local now, before = identity[id], self._known[id]
		-- (the same profile.look table every tick unless a reseed replaced it: compared by key only then)
		if before ~= nil and before.look ~= now.look and Kit.lookKey(before.look) ~= Kit.lookKey(now.look) then
			table.insert(events, {
				type = "spawn",
				id = id,
				kind = now.kind,
				job = now.job,
				kingdom = now.kingdom,
				look = wireLook(now.look),
			})
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
	local n = #records
	-- over the cap, each tick starts further along, so no entity waits behind the same ones every tick
	local first = if n > Def.MAX_RECORDS then (self._frame * Def.MAX_RECORDS) % n else 0
	for step = 1, n do
		local r = records[(first + step - 1) % n + 1]
		if #out >= Def.MAX_RECORDS then
			break -- the rest keep their old sent state, so they go out on a later tick
		end
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

-- Interest tiers apply in the full match; the slice keeps broadcasting (VS-1).
function EntityService:_interestOn(): boolean
	return MatchConfig.interest.enabled == true and self._match.host.match.mode == "match"
end

-- Where a player is looking, for the near tier: a fresh Sim.Focus, else their character, else nowhere (all far).
function EntityService:_viewerOf(player: any): { x: number, z: number }?
	local focus = self._focus[player.UserId]
	if focus and self._env.clock() - focus.at <= MatchConfig.interest.focusStaleSeconds then
		return focus
	end
	local x, z = self._match.host._positionOf(player)
	if x ~= nil and z ~= nil then
		return { x = x, z = z }
	end
	return nil
end

-- The snapshot chunks one player gets: the tick's selected records filtered by distance (own soldiers always).
function EntityService:_interestChunks(
	player: any,
	records: { any },
	always: { [string]: { [number]: boolean } }
): { any }
	local kingdomId = self._match.host.match:kingdomOf(player.UserId)
	local selected = Interest.select(records, self:_viewerOf(player), self._frame, {
		nearRadius = MatchConfig.interest.nearRadius,
		farEvery = MatchConfig.interest.farEvery,
		always = if kingdomId then always[kingdomId] else nil,
	})
	return SnapshotCodec.encodeChunks(selected, self._seq, self:_serverTime())
end

function EntityService:_encodeTick(frame: any): { any }
	local events = self:_diff(frame.identity)
	self._frame += 1
	self._seq = (self._seq + 1) % 65536
	local serverTime = self:_serverTime()
	local outgoing = {}
	if #events > 0 then
		table.insert(outgoing, { "Sim.Events", EventCodec.encode(serverTime, events) })
	end
	-- after the global batch: a kingdom event may concern an entity spawned this tick
	for _, item in self:_kingdomBatches(serverTime) do
		table.insert(outgoing, item)
	end
	local records = self:_select(frame.records)
	if self:_interestOn() then
		local sim = self:_sim()
		local always = {}
		for kid, kingdom in sim.kingdoms do
			local own = {}
			for _, id in kingdom.unitIds do
				own[id] = true
			end
			always[kid] = own
		end
		for _, player in self._env.Players:GetPlayers() do
			for _, chunk in self:_interestChunks(player, records, always) do
				table.insert(outgoing, { "Sim.Snapshot", chunk, nil, player })
			end
		end
		return outgoing
	end
	for _, chunk in SnapshotCodec.encodeChunks(records, self._seq, serverTime) do
		table.insert(outgoing, { "Sim.Snapshot", chunk })
	end
	return outgoing
end

-- One snapshot tick to every player. Specs may call it directly. It is encoded first; only a tick that
-- encodes commits its state and fires its signals (#39 L1).
function EntityService:replicate()
	local started = self._env.clock()
	local frame = self:_replicable()
	local saved = {
		pending = self._pending,
		known = self._known,
		frame = self._frame,
		seq = self._seq,
		sentState = table.clone(self._sentState),
		vanishing = table.clone(self._vanishing),
		dieQueued = table.clone(self._dieQueued),
		despawnReason = table.clone(self._despawnReason),
		kingdomPending = self._kingdomPending, -- _kingdomBatches swaps it out during the encode (#93 M1)
	}
	self._deferred = {}
	local ok, result = pcall(self._encodeTick, self, frame)
	local deferred = self._deferred :: { any }
	self._deferred = nil
	if not ok then
		self._pending, self._known, self._frame, self._seq = saved.pending, saved.known, saved.frame, saved.seq
		self._sentState, self._vanishing = saved.sentState, saved.vanishing
		self._dieQueued, self._despawnReason = saved.dieQueued, saved.despawnReason
		self._kingdomPending = saved.kingdomPending -- a failed tick keeps its thoughts, reactions, strikes, cues
		error(result, 0)
	end
	local outgoing = result :: { any }
	for _, call in deferred do
		call[1]:fire(table.unpack(call, 2, call.n))
	end
	table.insert(self._encodeMs, (self._env.clock() - started) * 1000)
	if #self._encodeMs > Def.WINDOW then
		table.remove(self._encodeMs, 1)
	end
	local everyone = self._env.Players:GetPlayers()
	local match = self._match.host.match
	for _, item in outgoing do
		local kingdomId = item[3]
		if item[4] ~= nil then
			if self._remotes:fire(item[1], item[4], item[2]) then -- one player's interest-filtered snapshot
				self._bytes += buffer.len(item[2])
			end
		elseif kingdomId == nil then
			self._remotes:fireAll(item[1], item[2])
			self._bytes += buffer.len(item[2]) * #everyone
		else
			for _, player in everyone do
				if match:kingdomOf(player.UserId) == kingdomId and self._remotes:fire(item[1], player, item[2]) then
					self._bytes += buffer.len(item[2])
				end
			end
		end
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
