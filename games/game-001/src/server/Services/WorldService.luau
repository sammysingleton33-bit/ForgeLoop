--!strict
--[[
	WorldService — builds the AI Kingdoms valley at server start from world/Layout (CONTRACTS G10,
	FL-0055). Owner: FORGE-02.

	At start (in a spawned thread, spread across frames):
	  1. applies world/Lighting (Lighting properties, Atmosphere, Sky, ColorCorrection, Bloom, SunRays,
	     Clouds, terrain material colours, water);
	  2. runs Kit/WorldPlan terrain ops through the terrain adapter (Kit/Terrain): one Fill* per feature
	     piece, at most VOXELS_PER_FRAME voxels per frame;
	  3. places resource nodes (Kit.prop by asset id, tagged ResourceNode + NodeId), build zones
	     (invisible parts tagged BuildZone + ZoneId, Kingdom), the objective zone (ObjectiveZone +
	     ObjectiveId, Radius), plot markers (KingdomPlot + Kingdom) and build slot markers
	     (Kit.slotMarker; its Root part is tagged BuildSlot + SlotId, Size, Kingdom; G13.5);
	  4. places the Crown Arena (Kit.arena at Layout.arena, FL-0072, G12.6): once, neutral, tagged CrownArena with its attachments
	     as Kit builds them; ArenaService dresses it with Kit.arenaDress when the two kingdoms are known;
	  5. places props and forests from WorldPlan.props (deterministic), PROPS_PER_FRAME per frame, cleared off the
	     plots' fields, buildings, slots and roads and thinned by the dressing density knob (world/Layout
	     features.density, D-047; 1.0 = the untrimmed valley);
	  6. fires `ready` and logs the build time in ms.
	It never calls Kit.build: BuildingService and ObjectiveService build buildings (G6, G10).
	Tags are for visuals and client hints only; the sim reads Layout.

	API
		WorldService.ready: Signal<()>
		WorldService:isReady(): boolean
		WorldService:getRoot(): Folder?     -- Workspace.World once built
		WorldService.stats: { ms, terrainOps, props, parts, arenaParts }  -- parts counts every part created, the arena's included
	Test hooks: set `service.terrain` (Kit/Terrain recorder), `service.layout`, `service.dressed`,
	`service.density` (overrides the layout's dressing knob, e.g. WorldPlan.FULL_DENSITY),
	`service.voxelsPerFrame` or `service.partsPerFrame` before start().
	Robustness: start() is idempotent; the build runs under pcall, so `ready` always fires (an error is
	logged at error level and kept in stats.error); destroy() stops the build at the next frame and removes
	Workspace.World. Invisible zone parts are not queryable; decoration never fires Touched and only collides
	near the ground.
]]

local KingdomsConfig = require("@game/ReplicatedStorage/Forge/Config/Kingdoms")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local Terrain = require("@game/ReplicatedStorage/Game/Kit/Terrain")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/World/Layout")
local LightingPreset = require("@game/ReplicatedStorage/Game/World/Lighting")

local WorldService = {}
WorldService.__index = WorldService

WorldService.DRESSED = { crimson = true } -- VS-1: one kingdom fully dressed, the others blocked out
WorldService.VOXELS_PER_FRAME = 64 * 64 * 64
WorldService.PARTS_PER_FRAME = 400 -- parts created per frame before yielding (nodes, markers, props)
-- decoration parts higher than this above their model's pivot do not collide (canopies, banners, roofs)
WorldService.COLLIDE_HEIGHT = 7

local Def = { name = "WorldService", dependencies = {} }

function Def.new(env, _registry)
	local self = setmetatable({
		_env = env,
		_ready = false,
		_root = nil :: any,
		ready = Signal.new(),
		terrain = Terrain.forWorkspace(env.Workspace, env.log),
		layout = Layout,
		lighting = LightingPreset,
		stats = { ms = 0, terrainOps = 0, props = 0, parts = 0, arenaParts = 0 },
		dressed = table.clone(WorldService.DRESSED),
		density = nil :: { [string]: number }?, -- nil: the layout's knob (features.density)
		voxelsPerFrame = WorldService.VOXELS_PER_FRAME,
		partsPerFrame = WorldService.PARTS_PER_FRAME,
		_started = false,
		_destroyed = false,
		_frameParts = 0,
	}, WorldService)
	return self
end

function WorldService:isReady(): boolean
	return self._ready
end

function WorldService:getRoot(): any
	return self._root
end

function WorldService:start()
	if self._started then
		return -- a second start() must not build a second world
	end
	self._started = true
	self._env.spawn(function()
		local ok, err = pcall(self._build, self)
		if self._destroyed then
			return
		end
		if not ok then
			-- never leave waiters (KingdomService) hanging: report loudly, then fire ready with what exists
			self.stats.error = tostring(err)
			self._env.log("error", "WorldService build failed", { error = self.stats.error })
		end
		self._ready = true
		self.ready:fire()
	end)
end

function WorldService:destroy()
	self._destroyed = true -- the build thread stops at its next frame boundary
	self.ready:disconnectAll()
	if self._root then
		self._root:Destroy()
		self._root = nil
	end
end

-- Yield one frame (and stop if destroyed) once `n` more parts would exceed the per-frame budget.
function WorldService:_budget(n: number)
	self._frameParts += n
	if self._frameParts >= self.partsPerFrame then
		self._frameParts = 0
		self:_wait()
	end
end

function WorldService:_wait()
	self._env.wait(0)
	if self._destroyed then
		error("WorldService destroyed during build", 0)
	end
end

-- ---------------------------------------------------------------- helpers

-- Slot markers in the canonical kingdom colours (config Kingdoms, D-033): the pennants and the sign tablet
-- carry KitTint and the tablet the kingdom's emblem (D-039), so Kit.setKingdomColor recolours them and
-- re-forms the emblem.
local KINGDOM_COLORS: { [string]: Color3 } = {}
for _, identity in KingdomsConfig.identities do
	local c = identity.color
	KINGDOM_COLORS[identity.id] = Color3.fromRGB(c[1], c[2], c[3])
end

local function setProps(instance: any, props: { [string]: any })
	for k, v in props do
		instance[k] = v
	end
end

-- Move a whole model so its pivot (PrimaryPart CFrame * PivotOffset) lands on `cf` (no PivotTo, so the
-- same code runs in Lune).
local function placeModel(model: any, cf: CFrame)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local pivot = primary.CFrame * primary.PivotOffset
	local delta = cf * pivot:Inverse()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end
WorldService._placeModel = placeModel

-- Decoration physics: nothing needs Touched, and only parts near the ground block movement (trunks, rocks,
-- walls); canopies, banners and roofs above COLLIDE_HEIGHT let units and the camera through.
local function decorate(model: any, base: number, solid: boolean?)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = false
			if d == model.PrimaryPart and d.Transparency >= 1 then
				d.CanQuery = false -- the invisible footprint plate must not catch raycasts
			end
			if not solid and d.CFrame.Position.Y - d.Size.Y / 2 > base + WorldService.COLLIDE_HEIGHT then
				d.CanCollide = false
			end
			n += 1
		end
	end
	return n
end
WorldService._decorate = decorate

function WorldService:_folder(name: string, parent: any): any
	local f = self._env.newInstance("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function WorldService:_zonePart(name: string, cf: CFrame, size: Vector3, shape: any?): any
	local p = self._env.newInstance("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false -- invisible markers must not catch placement or selection raycasts (G13.6)
	p.Transparency = 1
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	return p
end

function WorldService:_applyLighting()
	local env, preset = self._env, self.lighting
	local lighting = env.Lighting
	setProps(lighting, preset.lighting)
	local function child(className: string, props: { [string]: any })
		local existing = lighting:FindFirstChildOfClass(className)
		local inst = existing or env.newInstance(className)
		setProps(inst, props)
		inst.Parent = lighting
	end
	child("Atmosphere", preset.atmosphere)
	child("Sky", preset.sky)
	child("ColorCorrectionEffect", preset.colorCorrection)
	child("BloomEffect", preset.bloom)
	child("SunRaysEffect", preset.sunRays)
	for name, color in preset.terrainColors do
		self.terrain.setMaterialColor(name, color)
	end
	self.terrain.setWater(preset.water)
	-- dynamic clouds live under Terrain (Roblox only)
	if self.terrain.live then
		local terrain = env.Workspace:FindFirstChildOfClass("Terrain")
		local clouds = terrain:FindFirstChildOfClass("Clouds") or env.newInstance("Clouds")
		setProps(clouds, preset.clouds)
		clouds.Parent = terrain
	end
end

-- ---------------------------------------------------------------- build

function WorldService:_build()
	local env = self._env
	local layout = self.layout
	local t0 = env.clock()
	local CollectionService = env.CollectionService

	self:_applyLighting()
	local forge = env.ReplicatedStorage:FindFirstChild("Forge")
	Kit.setAssetSource(forge and forge:FindFirstChild("Assets") or nil)

	local root = self:_folder("World", env.Workspace)
	self._root = root
	local nodesFolder = self:_folder("ResourceNodes", root)
	local zonesFolder = self:_folder("Zones", root)
	local slotsFolder = self:_folder("BuildSlots", root)
	local propsFolder = self:_folder("Props", root)
	local arenaFolder = self:_folder("Arena", root)

	-- terrain, chunked by voxel budget
	local ops = WorldPlan.terrainOps(layout, self.density)
	local budget = 0
	for _, op in ops do
		local v = WorldPlan.voxels(op)
		if budget > 0 and budget + v > self.voxelsPerFrame then
			budget = 0
			self:_wait()
		end
		self.terrain.fill(op)
		budget += v
	end
	self.stats.terrainOps = #ops
	self:_wait()

	local parts = 0
	local function count(model: any)
		local n = 0
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		parts += n
		self:_budget(n)
	end

	-- resource nodes (tagged; the sim reads Layout, tags are for visuals and client hints)
	for _, node in layout.resourceNodes do
		local model = Kit.prop(node.assetId)
		model.Name = node.id
		local p = node.cframe.Position
		local y = WorldPlan.groundHeight(layout, p.X, p.Z)
		placeModel(model, CFrame.new(p.X, y, p.Z) * (node.cframe - node.cframe.Position))
		model:SetAttribute("NodeId", node.id)
		model:SetAttribute("Resource", node.resource)
		decorate(model, y)
		model.Parent = nodesFolder
		CollectionService:AddTag(model, "ResourceNode")
		count(model)
	end
	self:_wait()

	-- build zones and kingdom plots
	for _, kingdom in { "crimson", "azure", "emerald", "gold" } do
		local plot = layout.plots[kingdom]
		if plot then
			local marker = self:_zonePart(`Plot_{kingdom}`, plot.anchors.keep, Vector3.new(4, 1, 4))
			marker:SetAttribute("Kingdom", kingdom)
			marker:SetAttribute("RegionId", plot.regionId)
			marker.Parent = zonesFolder
			CollectionService:AddTag(marker, "KingdomPlot")
			for _, zone in plot.buildZones do
				local part = self:_zonePart(
					zone.id,
					CFrame.new(zone.center + Vector3.new(0, 0.5, 0)),
					Vector3.new(zone.size.X, 1, zone.size.Y)
				)
				part:SetAttribute("ZoneId", zone.id)
				part:SetAttribute("Kingdom", kingdom)
				part.Parent = zonesFolder
				CollectionService:AddTag(part, "BuildZone")
			end
			for _, slot in plot.buildSlots or {} do
				local size = layout.slotSizes[slot.size]
				local model = Kit.slotMarker(size, KINGDOM_COLORS[kingdom] or Kit.NEUTRAL_COLOR)
				model.Name = slot.id
				local y = WorldPlan.groundHeight(layout, slot.center.X, slot.center.Z)
				placeModel(model, CFrame.new(slot.center.X, y, slot.center.Z) * CFrame.Angles(0, slot.rot, 0))
				local slotRoot = model.PrimaryPart
				slotRoot:SetAttribute("SlotId", slot.id)
				slotRoot:SetAttribute("Size", slot.size)
				slotRoot:SetAttribute("Kingdom", kingdom)
				model.Parent = slotsFolder
				CollectionService:AddTag(slotRoot, "BuildSlot")
				count(model)
			end
		end
	end
	for _, o in layout.objectives do
		local p = o.cframe.Position
		local y = WorldPlan.groundHeight(layout, p.X, p.Z)
		local zone = self:_zonePart(
			`Objective_{o.id}`,
			CFrame.new(p.X, y + 0.5, p.Z) * CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(1, o.radius * 2, o.radius * 2),
			Enum.PartType.Cylinder
		)
		zone:SetAttribute("ObjectiveId", o.id)
		zone:SetAttribute("Radius", o.radius)
		zone:SetAttribute("RegionId", o.regionId)
		zone.Parent = zonesFolder
		CollectionService:AddTag(zone, "ObjectiveZone")
	end
	self:_wait()

	-- the Crown Arena (G12.6): one model, neutral until the two kingdoms of the final duel are known. Its low parts (the ring, the
	-- stands, the gate walls) collide, everything above COLLIDE_HEIGHT (towers' tops, caps, banners, the royal roof) does not.
	local arena = layout.arena
	if arena then
		local model = Kit.arena()
		model.Name = "CrownArena"
		local p = arena.cframe.Position
		local y = WorldPlan.groundHeight(layout, p.X, p.Z)
		placeModel(model, CFrame.new(p.X, y, p.Z) * (arena.cframe - arena.cframe.Position))
		model:SetAttribute("RegionId", arena.regionId)
		decorate(model, y)
		model.Parent = arenaFolder
		CollectionService:AddTag(model, "CrownArena")
		local before = parts
		count(model)
		self.stats.arenaParts = parts - before
		self:_wait()
	end

	-- props and forests, deterministic, at most partsPerFrame parts per frame
	local placements = WorldPlan.props(layout, self.dressed, self.density)
	for _, placement in placements do
		local model = Kit.prop(placement.assetId)
		placeModel(model, placement.cframe)
		model:SetAttribute("Feature", placement.feature)
		decorate(model, placement.cframe.Position.Y, placement.feature == "bridge") -- bridges stay solid
		model.Parent = propsFolder
		count(model)
	end
	self.stats.props = #placements
	self.stats.parts = parts

	self.stats.ms = math.floor((env.clock() - t0) * 1000 + 0.5)
	env.log("info", "WorldService ready", {
		ms = self.stats.ms,
		terrainOps = self.stats.terrainOps,
		props = self.stats.props,
		parts = parts,
	})
	-- start() marks the service ready and fires `ready` once this returns (or fails)
end

return Def
