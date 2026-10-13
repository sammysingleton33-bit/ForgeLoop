--!strict
--[[
	EntityController — renders the server's entities on this client (CONTRACTS G4, G4.1; FL-0049).
	Owner: FORGE-01. The only module that decodes Sim.* (G4.1).

	API (G4.1)
		EntityController.rendered: Signal<(EntityId, Model)>      -- a rig now shows this entity
		EntityController.released: Signal<(EntityId, Model)>      -- fired before the rig returns to the pool;
		                                                             getModel(id) still returns it meanwhile
		EntityController.event: Signal<(EntityId?, cue, payload, Model?)>
			cues from Sim.Events for known entities: deposit (payload { resource = ResourceId }), hit, die,
			celebrate (payload {}); Model is nil while the entity has no rig yet.
			G13.3 conversation events (FL-0079; only this kingdom's members receive them), for FORGE-04
			bubbles and FORGE-03 panels:
			  thought   (id, "thought", { scenarioId, text, icon = "request" | "concern" | "idea" }, Model?)
			  reaction  (id, "reaction", { text, tone = "happy" | "angry" | "sad" | "neutral" }, Model?)
			  kcue      on citizens: (id, <cue>, { occupation? }, Model?) once per id (its entityId and its
			            entityIds, each once); with neither: (nil, <cue>, { occupation? }, nil), for the
			            HUD or the keep only. <cue> is one of EventCodec.KINGDOM_CUES (celebrate, grumble,
			            salute, bow, cower, strike_placard, work_fast, rest, hammer); "celebrate" also
			            arrives as a G4 cue
			  strike    (id, "strike", { occupation, on: boolean }, Model?) once per id in its entityIds:
			            exactly the citizens whose strike changed; never fanned out by occupation (v0.4-g6)
			As for cues, an event with an entity id fires only while that entity is known and not
			despawned (otherwise it is dropped); text may be empty.
		EntityController:pick(screenPos: Vector2): EntityId?      -- nearest visible rig within PICK_RADIUS px
			of screenPos, in Camera:WorldToScreenPoint space (InputObject.Position); nil when none
		EntityController:getModel(id): Model?                     -- the entity's rig (also while LOD-hidden)
	Additive
		controller:step(dt)          one render frame; RunService.Heartbeat calls it, specs may call it
		controller.adapter           engine calls (Adapter); specs replace it with a recording double
		controller.folder            Workspace.KingdomEntities, created in start() (D-025)
		controller.stats             { snapshots, stale, unknown, despawned, malformed } counters
		Def.INTERP_DELAY, LOD_HIDE, LOD_SHOW, DEATH_DELAY, DEATH_BLEND, PICK_RADIUS, PICK_HEIGHT,
		POOL_MAX, FOLDER_NAME, Def.robloxAdapter(env)

	Replication (G4 client rules)
		start() connects Sim.Snapshot and Sim.Events FIRST, then invokes Sim.GetEntities and applies its
		"full" records (retried while the server answers nil).
		- Snapshots whose seq is not newer than the newest applied seq (SnapshotCodec.newer) are dropped;
		  every chunk of the newest seq is applied.
		- Unknown ids are ignored (a snapshot can arrive before its spawn).
		- Despawned ids are remembered, so neither a late snapshot nor a stale full record brings one
		  back. Only a spawn record clears an id.
		- A reset record releases every rig and forgets the despawned ids and the server clock. The seq is
		  kept: EntityService's seq keeps increasing across matches, so a late snapshot of the old match
		  is still dropped
		  (a new match restarts serverTime).
		Events: spawn, despawn, job (swaps the rig: released, then rendered), cue (fires `event`; die
		blends into the dead pose and releases the rig after DEATH_DELAY), full (spawn + state), reset,
		and the G13.3 thought, reaction, strike and kcue (fire `event`, see above).
	Rendering (D-026, D-025)
		- Samples are buffered per entity by snapshot serverTime. They render INTERP_DELAY (0.2 s)
		  behind the server time estimated from arrivals (Sim/Interpolation).
		- Position is the rig pivot (base centre). Yaw turns about +Y, CFrame.Angles(0, yaw, 0); the
		  rig faces -Z at yaw 0.
		- Rigs come from Kit.character(kind, job, colour of the kingdom in config Kingdoms, look?) with
		  the citizen's look from its spawn record (G13.2; Kit falls back to its default look). They are
		  pooled per (kind, job, kingdom, Kit.lookKey(look)), POOL_MAX spares in all (the oldest is
		  destroyed first), and parented to one client-created Workspace folder.
		- Each frame, one BulkMoveTo moves every visible root, and each motor gets its Sim/Pose
		  Transform.
		- LOD: beyond LOD_HIDE studs from the LOD centre, a rig is unparented and skips pose work. It
		  comes back within LOD_SHOW studs. The centre is RulerCameraController:getFocus() while its mode
		  is "overview" (G13.6; registry:find), else the local character, else the camera focus.
		- Soldiers get their kingdom as Kit.character's `kingdom` argument (the helmet crest, G13.2).
	Engine calls (BulkMoveTo, Motor6D.Transform, camera and character reads) go through `adapter`
	(Lune has no BulkMoveTo). Unverified in Studio until the FL-0049 playtest.
]]

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local RemoteClient = require("@game/ReplicatedStorage/Forge/Core/RemoteClient")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local EventCodec = require("@game/ReplicatedStorage/Game/Sim/EventCodec")
local Interpolation = require("@game/ReplicatedStorage/Game/Sim/Interpolation")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Pick = require("@game/ReplicatedStorage/Game/Sim/Pick")
local Pose = require("@game/ReplicatedStorage/Game/Sim/Pose")
local SnapshotCodec = require("@game/ReplicatedStorage/Game/Sim/SnapshotCodec")

local EntityController = {}
EntityController.__index = EntityController

local Def = { name = "EntityController", dependencies = {} }

Def.INTERP_DELAY = 0.2 -- seconds behind the estimated server time (G4)
Def.LOD_HIDE = 150 -- studs (G4 streaming, D-025)
Def.LOD_SHOW = 140 -- hysteresis: a hidden rig returns inside this distance
Def.DEATH_DELAY = 2 -- seconds the dead pose stays before the rig is released
Def.DEATH_BLEND = 0.4 -- seconds to fall into the dead pose
Def.PICK_RADIUS = 60 -- pixels
Def.PICK_HEIGHT = 2.75 -- studs above the pivot: the body centre the pick aims at
Def.POOL_MAX = 64 -- spare rigs kept in all; past it the oldest spare is destroyed
Def.FOLDER_NAME = "KingdomEntities"
Def.GET_ENTITIES_TRIES = 10
Def.RETRY_SECONDS = 1.5

export type Adapter = {
	bulkMove: (parts: { any }, cframes: { CFrame }) -> (), -- workspace:BulkMoveTo(..., FireCFrameChanged)
	setTransform: (motor: any, cframe: CFrame) -> (), -- Motor6D.Transform
	focus: () -> Vector3?, -- LOD centre outside the overview: the local character, else the camera focus
	project: (point: Vector3) -> (Vector2?, number?), -- screen point and depth; nil when off screen
}

type Rig = { model: any, root: any, rootOffset: CFrame, motors: { [string]: any }, key: string }

type Entity = {
	id: number,
	kind: string,
	job: string,
	kingdom: string,
	look: any?, -- G13.2 CitizenLook from the spawn record (citizens)
	track: Interpolation.Track,
	state: Interpolation.State,
	pose: Pose.Joints,
	phase: number,
	rig: Rig?,
	hidden: boolean, -- LOD: the rig is unparented
	cframe: CFrame?, -- pivot rendered last frame
	position: Vector3?,
	diedAt: number?, -- env.clock() of the die cue
	gone: boolean, -- despawned while the dead pose plays
	done: boolean, -- dead and released: never rendered again
}

local IDENTITY = CFrame.new()
local DEAD_POSE = Pose.sample("dead", "idle", 0, 0)
local GOLDEN = 0.6180339887 -- spreads the animation phase of neighbouring ids

local COLORS: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	COLORS[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end

function Def.robloxAdapter(env: any): Adapter
	return {
		bulkMove = function(parts: { any }, cframes: { CFrame })
			env.Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end,
		setTransform = function(motor: any, cframe: CFrame)
			motor.Transform = cframe
		end,
		focus = function(): Vector3?
			local player = env.Players.LocalPlayer
			local character = player and player.Character
			local root = character and character.PrimaryPart
			if root then
				return root.Position
			end
			local camera = env.Workspace.CurrentCamera
			return if camera then camera.Focus.Position else nil
		end,
		project = function(point: Vector3): (Vector2?, number?)
			local camera = env.Workspace.CurrentCamera
			if camera == nil then
				return nil, nil
			end
			local screen, onScreen = camera:WorldToScreenPoint(point)
			if not onScreen or screen.Z <= 0 then
				return nil, nil
			end
			return Vector2.new(screen.X, screen.Y), screen.Z
		end,
	}
end

function Def.new(env: any, registry: any)
	local self = setmetatable({}, EntityController)
	self._env = env
	self._registry = registry
	self._camera = nil :: any -- RulerCameraController, found on the first frame that has one
	self.rendered = Signal.new()
	self.released = Signal.new()
	self.event = Signal.new()
	self.adapter = Def.robloxAdapter(env)
	self.folder = nil :: any
	self.stats = { snapshots = 0, stale = 0, unknown = 0, despawned = 0, malformed = 0 }
	self._entities = {} :: { [number]: Entity }
	self._despawned = {} :: { [number]: boolean }
	self._newestSeq = nil :: number?
	self._clock = Interpolation.newClock()
	self._spares = {} :: { Rig } -- released rigs, oldest first, at most POOL_MAX
	self._connections = {} :: { any }
	self._snapshotConnection = nil :: any
	self._eventsConnection = nil :: any
	self._parts = {} :: { any }
	self._cframes = {} :: { CFrame }
	self._fresh = {} :: { Entity } -- rendered during this frame, announced after its BulkMoveTo
	self._warned = {} :: { [string]: boolean }
	self._destroyed = false
	return self
end

function EntityController:start()
	local env = self._env
	local folder = env.newInstance("Folder")
	folder.Name = Def.FOLDER_NAME
	folder.Parent = env.Workspace
	self.folder = folder
	table.insert(
		self._connections,
		env.RunService.Heartbeat:Connect(function(dt: number)
			self:step(dt)
		end)
	)
	env.spawn(function()
		self:_connect()
	end)
end

-- ---------------------------------------------------------------- remotes

function EntityController:_warnOnce(key: string, message: string, fields: { [string]: any }?)
	if self._warned[key] then
		return
	end
	self._warned[key] = true
	self._env.log("warn", message, fields)
end

-- Handlers first, then the initial state (G4): nothing sent in between is lost.
function EntityController:_connect()
	local env = self._env
	local client = RemoteClient.new(env)
	while not self._destroyed do
		local ok, err = pcall(function()
			if self._snapshotConnection == nil then
				self._snapshotConnection = client:on("Sim.Snapshot", function(buf: any)
					self:_onSnapshot(buf)
				end)
			end
			if self._eventsConnection == nil then
				self._eventsConnection = client:on("Sim.Events", function(buf: any)
					self:_applyBatch(buf, false)
				end)
			end
		end)
		if ok then
			break
		end
		self:_warnOnce("remotes", "EntityController: Sim remotes unavailable; retrying", { error = tostring(err) })
		env.wait(Def.RETRY_SECONDS)
	end
	for _ = 1, Def.GET_ENTITIES_TRIES do
		if self._destroyed then
			return
		end
		local ok, buf = pcall(function()
			return client:invoke("Sim.GetEntities")
		end)
		if self._destroyed then
			return
		end
		if ok and buf ~= nil then
			self:_applyBatch(buf, true)
			return
		end
		env.wait(Def.RETRY_SECONDS)
	end
	self:_warnOnce("getEntities", "EntityController: Sim.GetEntities gave no answer")
end

function EntityController:_onSnapshot(buf: any)
	if self._destroyed then
		return
	end
	local frame, reason = SnapshotCodec.decode(buf)
	if frame == nil then
		self.stats.malformed += 1
		self:_warnOnce("snapshot", "EntityController: malformed Sim.Snapshot", { reason = reason })
		return
	end
	local newest = self._newestSeq
	if newest ~= nil and frame.seq ~= newest and not SnapshotCodec.newer(frame.seq, newest) then
		self.stats.stale += 1
		return
	end
	self._newestSeq = frame.seq
	self.stats.snapshots += 1
	self._clock:observe(frame.serverTime, self._env.clock())
	for _, r in frame.records do
		local entity = self._entities[r.id]
		if self._despawned[r.id] then
			self.stats.despawned += 1
		elseif entity == nil then
			self.stats.unknown += 1
		else
			Interpolation.push(entity.track, frame.serverTime, Vector3.new(r.x, r.y, r.z), r.yaw, r.action, r.carrying)
		end
	end
end

function EntityController:_applyBatch(buf: any, initial: boolean)
	if self._destroyed then
		return
	end
	local batch, reason = EventCodec.decode(buf)
	if batch == nil then
		self.stats.malformed += 1
		self:_warnOnce("events", "EntityController: malformed Sim.Events batch", { reason = reason })
		return
	end
	if initial and self._clock.offset == nil then
		self._clock:observe(batch.serverTime, self._env.clock())
	end
	for _, e in batch.events do
		local kind = e.type
		if kind == "spawn" then
			self:_spawn(e, nil)
		elseif kind == "full" then
			self:_spawn(e, batch.serverTime)
		elseif kind == "despawn" then
			self:_despawn(e.id)
		elseif kind == "job" then
			self:_setJob(e.id, e.job)
		elseif kind == "cue" then
			self:_cue(e.id, e.cue, e.resource)
		elseif kind == "thought" then
			self:_fireFor(e.id, "thought", { scenarioId = e.scenarioId, text = e.text, icon = e.icon })
		elseif kind == "reaction" then
			self:_fireFor(e.id, "reaction", { text = e.text, tone = e.tone })
		elseif kind == "kcue" then
			local ids = e.entityIds or {}
			if e.id ~= nil and not table.find(ids, e.id) then
				table.insert(ids, 1, e.id)
			end
			for _, id in ids do
				self:_fireFor(id, e.cue, { occupation = e.occupation })
			end
			if #ids == 0 then
				self.event:fire(nil, e.cue, { occupation = e.occupation }, nil) -- HUD or keep only
			end
		elseif kind == "strike" then
			for _, id in e.entityIds do -- exactly the citizens whose strike changed (G13.3 v0.4-g6)
				self:_fireFor(id, "strike", { occupation = e.occupation, on = e.on })
			end
		elseif kind == "reset" then
			self:_reset()
		end
	end
end

-- ---------------------------------------------------------------- entity records

-- A spawn record (serverTime nil) clears a despawned id; a full record (spawn + state at serverTime)
-- is a picture of the past and never brings a despawned id back.
function EntityController:_spawn(e: any, serverTime: number?)
	local id = e.id
	if serverTime ~= nil and self._despawned[id] then
		return
	end
	self._despawned[id] = nil
	local entity = self._entities[id]
	if entity ~= nil and (entity.gone or entity.done) then
		if serverTime ~= nil then
			return -- a dead entity's state never revives it
		end
		self:_remove(entity)
		entity = nil
	end
	if entity == nil then
		local created: Entity = {
			id = id,
			kind = e.kind,
			job = e.job,
			kingdom = e.kingdom,
			look = e.look,
			track = Interpolation.newTrack(),
			state = {} :: any,
			pose = {},
			phase = (id * GOLDEN) % 1,
			rig = nil,
			hidden = false,
			cframe = nil,
			position = nil,
			diedAt = nil,
			gone = false,
			done = false,
		}
		self._entities[id] = created
		entity = created
	elseif entity.kind ~= e.kind or entity.job ~= e.job or entity.kingdom ~= e.kingdom then
		entity.kind, entity.job, entity.kingdom = e.kind, e.job, e.kingdom
		self:_swap(entity)
	end
	if serverTime ~= nil then
		local live = entity :: Entity
		Interpolation.push(live.track, serverTime, Vector3.new(e.x, e.y, e.z), e.yaw, e.action, e.carrying)
	end
end

function EntityController:_despawn(id: number)
	self._despawned[id] = true
	local entity = self._entities[id]
	if entity == nil then
		return
	end
	if entity.diedAt ~= nil and entity.rig ~= nil then
		entity.gone = true -- the dead pose finishes first (step releases it)
		return
	end
	self:_remove(entity)
end

function EntityController:_setJob(id: number, job: string)
	local entity = self._entities[id]
	if entity == nil or self._despawned[id] or entity.job == job then
		return
	end
	entity.job = job
	self:_swap(entity)
end

function EntityController:_cue(id: number, cue: string, resource: string?)
	local entity = self._entities[id]
	if entity ~= nil and not self._despawned[id] and cue == "die" and entity.diedAt == nil then
		entity.diedAt = self._env.clock()
	end
	self:_fireFor(id, cue, if cue == "deposit" then { resource = resource } else {})
end

-- Fires `event` for a known entity that is not despawned, with its model (nil while it has no rig).
function EntityController:_fireFor(id: number, name: string, payload: { [string]: any })
	local entity = self._entities[id]
	if entity == nil or self._despawned[id] then
		return
	end
	local rig = entity.rig
	self.event:fire(id, name, payload, if rig then rig.model else nil)
end

function EntityController:_reset()
	for _, entity in self._entities do
		self:_release(entity)
	end
	table.clear(self._entities)
	table.clear(self._despawned)
	self._clock:reset() -- serverTime restarts with the new match; seq does not (see the header)
end

function EntityController:_remove(entity: Entity)
	self:_release(entity)
	if self._entities[entity.id] == entity then
		self._entities[entity.id] = nil
	end
end

-- ---------------------------------------------------------------- rigs and pool

-- Kit.lookKey: equal keys build identical rigs (no look = Kit's default look)
local function poolKey(kind: string, job: string, kingdom: string, look: any?): string
	return `{kind}|{job}|{kingdom}|{Kit.lookKey(look)}`
end

-- look (G13.2 CitizenLook, from the spawn record) and, for soldiers, the kingdom (their helmet
-- crest, D-033) are Kit.character's optional 4th and 5th arguments
local function buildRig(kind: string, job: string, kingdom: string, look: any?, key: string): Rig
	local crest = if kind == "soldier" then kingdom else nil
	local model = (Kit.character :: any)(kind, job, COLORS[kingdom] or Kit.NEUTRAL_COLOR, look, crest)
	local root = model.PrimaryPart
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	return { model = model, root = root, rootOffset = root.PivotOffset:Inverse(), motors = motors, key = key }
end

function EntityController:_acquire(entity: Entity): Rig
	local key = poolKey(entity.kind, entity.job, entity.kingdom, entity.look)
	local spares = self._spares
	for i = #spares, 1, -1 do -- the newest matching spare
		if spares[i].key == key then
			return table.remove(spares, i)
		end
	end
	return buildRig(entity.kind, entity.job, entity.kingdom, entity.look, key)
end

-- Attaches a rig. Inside a frame (`inFrame`) the frame's BulkMoveTo places it and `rendered` fires
-- after that move; otherwise it is placed now. Either way handlers see the rig where it belongs.
function EntityController:_render(entity: Entity, hidden: boolean, inFrame: boolean?)
	local rig = self:_acquire(entity)
	rig.model:SetAttribute("EntityId", entity.id)
	entity.rig = rig
	entity.hidden = hidden
	if not inFrame and entity.cframe then
		self.adapter.bulkMove({ rig.root }, { (entity.cframe :: CFrame) * rig.rootOffset })
	end
	rig.model.Parent = if hidden then nil else self.folder
	if inFrame then
		table.insert(self._fresh, entity)
	else
		self.rendered:fire(entity.id, rig.model)
	end
end

-- `released` fires while the entity still holds the rig; only then does it go to the pool.
function EntityController:_release(entity: Entity)
	local rig = entity.rig
	if rig == nil then
		return
	end
	self.released:fire(entity.id, rig.model)
	entity.rig = nil
	rig.model.Parent = nil
	rig.model:SetAttribute("EntityId", nil)
	if self._destroyed then
		rig.model:Destroy()
		return
	end
	table.insert(self._spares, rig)
	if #self._spares > Def.POOL_MAX then
		table.remove(self._spares, 1).model:Destroy() -- one bound for every key (looks make many keys)
	end
end

-- Kind, job or kingdom changed: a different Kit rig shows the entity.
function EntityController:_swap(entity: Entity)
	if entity.rig == nil or entity.done then
		return
	end
	local hidden = entity.hidden
	self:_release(entity)
	self:_render(entity, hidden)
end

-- ---------------------------------------------------------------- frame

-- The LOD centre: the overview camera's focus while RulerCameraController is in "overview" (the ruler
-- sits on the throne and the player looks after the whole plot, #39 M1), else adapter.focus() (the
-- local character, else the camera focus).
function EntityController:_lodCentre(): Vector3?
	local camera = self._camera
	if camera == nil and self._registry and self._registry.find then
		camera = self._registry:find("RulerCameraController")
		self._camera = camera
	end
	if camera and camera.mode == "overview" then
		local focus = camera:getFocus()
		if focus then
			return focus
		end
	end
	return self.adapter.focus()
end

function EntityController:step(dt: number)
	if self._destroyed then
		return
	end
	local now = self._env.clock()
	local renderTime = self._clock:renderTime(now, Def.INTERP_DELAY)
	local focus = self:_lodCentre()
	local parts, cframes = self._parts, self._cframes
	table.clear(parts)
	table.clear(cframes)
	for _, entity in self._entities do
		self:_stepEntity(entity, dt, now, renderTime, focus)
	end
	if #parts > 0 then
		self.adapter.bulkMove(parts, cframes)
	end
	local fresh = self._fresh
	if #fresh > 0 then
		self._fresh = {}
		for _, entity in fresh do
			local rig = entity.rig
			if rig then
				self.rendered:fire(entity.id, rig.model)
			end
		end
	end
end

function EntityController:_stepEntity(entity: Entity, dt: number, now: number, renderTime: number?, focus: Vector3?)
	if entity.done then
		return
	end
	if entity.diedAt ~= nil and now - entity.diedAt >= Def.DEATH_DELAY then
		self:_release(entity)
		entity.done = true
		if entity.gone then
			self:_remove(entity)
		end
		return
	end
	local state = Interpolation.evaluate(entity.track, renderTime, entity.state)
	if state == nil then
		return -- spawned, but no position yet
	end
	local position = state.position
	local pivot = CFrame.new(position) * CFrame.Angles(0, state.yaw, 0)
	entity.cframe = pivot
	entity.position = position
	local far = false
	if focus ~= nil then
		far = (position - focus).Magnitude > (if entity.hidden then Def.LOD_SHOW else Def.LOD_HIDE)
	end
	local rig = entity.rig
	if rig == nil then
		self:_render(entity, far, true)
		rig = entity.rig
	elseif far ~= entity.hidden then
		entity.hidden = far
		rig.model.Parent = if far then nil else self.folder
	end
	if far or rig == nil then
		return
	end
	table.insert(self._parts, rig.root)
	table.insert(self._cframes, pivot * rig.rootOffset)
	self:_animate(entity, rig, state, dt, now)
end

function EntityController:_animate(entity: Entity, rig: Rig, state: Interpolation.State, dt: number, now: number)
	local action = state.action
	entity.phase = (entity.phase + dt * Pose.rate(action, entity.job, state.speed)) % 1
	local joints = Pose.sample(action, entity.job, entity.phase, state.speed, entity.pose)
	if entity.diedAt ~= nil then
		joints = Pose.blend(joints, DEAD_POSE, (now - entity.diedAt) / Def.DEATH_BLEND, joints)
	end
	local setTransform = self.adapter.setTransform
	for joint, motor in rig.motors do
		setTransform(motor, joints[joint] or IDENTITY)
	end
end

-- ---------------------------------------------------------------- queries

function EntityController:getModel(id: number): any?
	local entity = self._entities[id]
	local rig = entity and entity.rig
	return if rig then rig.model else nil
end

function EntityController:pick(screenPos: Vector2): number?
	local candidates = {}
	local lift = Vector3.new(0, Def.PICK_HEIGHT, 0)
	for id, entity in self._entities do
		if entity.rig ~= nil and not entity.hidden and entity.diedAt == nil and entity.position ~= nil then
			table.insert(candidates, { id = id, position = (entity.position :: Vector3) + lift })
		end
	end
	return Pick.nearest(candidates, screenPos, self.adapter.project, Def.PICK_RADIUS)
end

function EntityController:destroy()
	if self._destroyed then
		return
	end
	for _, entity in self._entities do
		self:_release(entity)
	end
	self._destroyed = true
	table.clear(self._entities)
	for _, connection in self._connections do
		connection:Disconnect()
	end
	if self._snapshotConnection then
		self._snapshotConnection:Disconnect()
	end
	if self._eventsConnection then
		self._eventsConnection:Disconnect()
	end
	for _, rig in self._spares do
		rig.model:Destroy()
	end
	table.clear(self._spares)
	if self.folder then
		self.folder:Destroy()
	end
	self.rendered:disconnectAll()
	self.released:disconnectAll()
	self.event:disconnectAll()
end

return Def
