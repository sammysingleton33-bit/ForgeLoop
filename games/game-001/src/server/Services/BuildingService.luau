--!strict
--[[
	BuildingService — placing and upgrading buildings (CONTRACTS G6, G8 Build area; FL-0051).
	Owner: FORGE-01.

	Buildings live in the kingdom simulation (MatchService's host); the game draws them with FORGE-02's
	Kit models (Sim/WorldView). This service is the server API and the Build.* remotes.
	API (G6)
		BuildingService:canPlace(kingdom, type, cframe): (boolean, reason?)   -- type, keep level, limit,
		                                           bounds, territory, overlap (the Kit.footprint rectangle
		                                           of the largest level, turned by the cframe), cost
		BuildingService:place(player, type, cframe): (buildingId?, reason?)   -- charges through the
		                                           treasury (Costs.luau via TreasuryService); sets placedBy
		BuildingService:upgrade(player, buildingId): (boolean, reason?)
		BuildingService.toCFrame(position: Vector3, rot: number): CFrame    -- rot 0..3 = 90° steps
		BuildingService:slots(kingdomId): { { id, size, occupiedBy: number? } }   -- G13.5 build slots
		BuildingService:placeSlot(player, slotId, type): (buildingId?, reason?)   -- on the player's kingdom's
		                                           slot, facing its street (the slot's rot), when the type fits
		                                           (Build/Fit); then exactly the Build.Place rules and price.
		                                           Reasons: not_in_match, unknown_slot, not_on_plot (wall, gate:
		                                           v0.4-g9a), slot_occupied, does_not_fit, then Build.Place's
	Remotes (Build/Remotes.luau): Build.CanPlace / Build.Place (type, position, rot), Build.Upgrade,
	Build.GetBuildings, and Build.Buildings: the G2 views of buildings that changed (placed, progress,
	level, hp, destroyed), to every player, at most BROADCAST_HZ times per second. A building removed from
	the world goes out once more with state "destroyed"; when a new world starts, every old building does
	(its own batch, first: the new world's ids start over).
	The facing comes from rot only; the client never sends a rotation (no CFrame on the wire).
	Build slots (G13.5): world Layout.plots[k].buildSlots; a slot is occupied while a standing building
	placed on it (building.slotId) exists, or any standing building of the kingdom overlaps its rectangle
	(Layout.slotSizes, turned by the slot's rot), such as one placed there with Build.Place. Build.GetSlots answers the asker's kingdom; Build.Slots goes to a
	kingdom's members when a slot is taken or freed, and to a member when they arrive.
	Not yet: build zones (G10.1 buildZones; the VS-1 path is the build slots) and linking a building's
	Door to the nav graph.
]]

local Fit = require("@game/ReplicatedStorage/Game/Build/Fit")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local Footprint = require("@game/ReplicatedStorage/Game/Sim/Footprint")
local WorldLayout = require("@game/ReplicatedStorage/Game/World/Layout")

local BuildingService = {}
BuildingService.__index = BuildingService

local Def = { name = "BuildingService", dependencies = { "MatchService", "RemoteService" } }

Def.BROADCAST_HZ = 2
-- building types that never stand on a plot: walls and gates go on territory lines (VS-2, G13.5 v0.4-g9a)
Def.NOT_ON_PLOT = table.freeze({ wall = true, gate = true })

function BuildingService.toCFrame(position: Vector3, rot: number): CFrame
	return CFrame.new(position.X, 0, position.Z) * CFrame.Angles(0, (rot % 4) * math.pi / 2, 0)
end

local function yawOf(cframe: CFrame): number
	local look = cframe.LookVector
	return math.atan2(-look.X, -look.Z)
end

function Def.new(env: any, registry: any)
	local self = setmetatable({}, BuildingService)
	self._env = env
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	self._sent = {} :: { [number]: string } -- building id -> signature last broadcast
	self._views = {} :: { [number]: any } -- building id -> view last broadcast (for its "destroyed" view)
	self._round = nil :: string?
	self._slotsSent = {} :: { [any]: string } -- player -> slots signature last sent
	self._running = false
	return self
end

-- ---------------------------------------------------------------- build slots (G13.5)
function BuildingService:_slotDefs(kingdomId: string): { any }
	local match = self._match.host.match
	local plot = Layout.WORLD.plots[kingdomId]
	if match.options.spacing ~= nil or plot == nil then
		return {} -- the square test layout has no slots
	end
	return plot.buildSlots or {}
end

-- The building occupying a slot: the one placed on it (building.slotId), else any standing building of
-- the kingdom whose shape overlaps the slot rectangle, e.g. one placed there with Build.Place (#89 M1).
function BuildingService:_occupant(kingdomId: string, slotId: string): number?
	local sim = self:_sim()
	local k = sim.kingdoms[kingdomId]
	local ids = if k then k.buildingIds else {} -- a destroyed or cancelled building leaves buildingIds
	for _, bid in ids do
		local b = sim.buildings[bid]
		if b and b.slotId == slotId then
			return b.id
		end
	end
	local rect
	for _, slot in self:_slotDefs(kingdomId) do
		if slot.id == slotId then
			rect = Footprint.rect(WorldLayout.slotSizes[slot.size], slot.center.X, slot.center.Z, slot.rot)
		end
	end
	for _, bid in if rect then ids else {} do
		local b = sim.buildings[bid]
		if b and b.shape and Footprint.overlaps(rect, b.shape, 0) then
			return b.id
		end
	end
	return nil
end

function BuildingService:slots(kingdomId: string): { { id: string, size: string, occupiedBy: number? } }
	local out = {}
	for _, slot in self:_slotDefs(kingdomId) do
		table.insert(out, { id = slot.id, size = slot.size, occupiedBy = self:_occupant(kingdomId, slot.id) })
	end
	return out
end

function BuildingService:placeSlot(player: any, slotId: string, kind: string): (number?, string?)
	local host = self._match.host
	local kingdomId = host:kingdomOf(player)
	if kingdomId == nil then
		return nil, "not_in_match"
	end
	local slot
	for _, def in self:_slotDefs(kingdomId) do
		if def.id == slotId then
			slot = def
		end
	end
	if slot == nil then
		return nil, "unknown_slot"
	end
	if Def.NOT_ON_PLOT[kind] then
		return nil, "not_on_plot" -- line structures (VS-2), whatever fits physically (G13.5 v0.4-g9a)
	end
	if self:_occupant(kingdomId, slotId) then
		return nil, "slot_occupied"
	end
	if not Fit.fits(kind, slot.size) then
		return nil, "does_not_fit"
	end
	local center = slot.center
	local ok, err, result = host:command(player, "PlaceBuilding", kind, center.X, center.Z, slot.rot)
	if not ok then
		return nil, err
	end
	self:_sim().buildings[result.buildingId].slotId = slotId
	return result.buildingId, nil
end

local function slotsSignature(kingdomId: string, slots: { any }): string
	local parts = { kingdomId }
	for _, slot in slots do
		table.insert(parts, `{slot.id}={slot.occupiedBy or 0}`)
	end
	return table.concat(parts, "|")
end

-- Build.Slots to every member whose kingdom's slots (or whose kingdom) changed since the last send.
function BuildingService:pushSlots()
	local match = self._match.host.match
	local seen = {}
	for _, player in self._env.Players:GetPlayers() do
		seen[player] = true
		local kingdomId = match:kingdomOf(player.UserId)
		local slots = if kingdomId then self:slots(kingdomId) else nil
		local signature = if slots and kingdomId then slotsSignature(kingdomId, slots) else ""
		if signature ~= (self._slotsSent[player] or "") then
			self._slotsSent[player] = signature
			if slots then
				self._remotes:fire("Build.Slots", player, slots)
			end
		end
	end
	for player in self._slotsSent do
		if not seen[player] then
			self._slotsSent[player] = nil
		end
	end
end

function BuildingService:_sim(): any
	return self._match.host.match.sim
end

function BuildingService:start()
	local host = self._match.host
	self._remotes:handle("Build.CanPlace", function(player: any, kind: string, position: Vector3, rot: number)
		return self:canPlace(host:kingdomOf(player), kind, BuildingService.toCFrame(position, rot))
	end)
	self._remotes:handle("Build.Place", function(player: any, kind: string, position: Vector3, rot: number)
		return self:place(player, kind, BuildingService.toCFrame(position, rot))
	end)
	self._remotes:handle("Build.Upgrade", function(player: any, buildingId: number)
		return self:upgrade(player, buildingId)
	end)
	self._remotes:handle("Build.GetBuildings", function()
		return self:_sim():buildingViews()
	end)
	self._remotes:handle("Build.PlaceSlot", function(player: any, slotId: string, kind: string)
		return self:placeSlot(player, slotId, kind)
	end)
	self._remotes:handle("Build.GetSlots", function(player: any)
		local kingdomId = host:kingdomOf(player)
		return if kingdomId then self:slots(kingdomId) else nil
	end)
	self._running = true
	self._env.spawn(function()
		while self._running do
			self._env.wait(1 / Def.BROADCAST_HZ)
			if not self._running then
				break
			end
			local ok, err = pcall(self.broadcast, self)
			if ok then
				ok, err = pcall(self.pushSlots, self)
			end
			if not ok then
				self._env.log("error", "BuildingService: broadcast failed", { error = tostring(err) })
			end
		end
	end)
end

function BuildingService:canPlace(kingdomId: string?, kind: string, cframe: CFrame): (boolean, string?)
	local sim = self:_sim()
	local k = kingdomId and sim.kingdoms[kingdomId]
	if k == nil then
		return false, "not_in_match"
	end
	if not sim.active then
		return false, "match_not_active"
	end
	local p = cframe.Position
	return sim:canPlace(k, kind, p.X, p.Z, yawOf(cframe)) -- the rules Place enforces, facing and cost included
end

function BuildingService:place(player: any, kind: string, cframe: CFrame): (number?, string?)
	local p = cframe.Position
	local ok, err, result = self._match.host:command(player, "PlaceBuilding", kind, p.X, p.Z, yawOf(cframe))
	if not ok then
		return nil, err
	end
	return result.buildingId, nil
end

function BuildingService:upgrade(player: any, buildingId: number): (boolean, string?)
	local ok, err = self._match.host:command(player, "UpgradeBuilding", buildingId)
	return ok, err
end

-- One broadcast of the buildings that changed since the last one. Specs may call it directly.
-- A removed building's last view, marked destroyed (Build.Buildings promises one, Remotes.luau).
local function destroyedView(view: { [string]: any }): { [string]: any }
	local out = table.clone(view)
	out.state = "destroyed"
	out.hp = 0
	return out
end

function BuildingService:broadcast()
	local sim = self:_sim()
	local round = self._match.host.match.roundId
	if round ~= self._round then
		-- a new world: every building of the old one is gone (sent first, as its own batch, because
		-- the new world's ids start over)
		local gone = {}
		for _, view in self._views or {} do
			table.insert(gone, destroyedView(view))
		end
		table.sort(gone, function(a, b)
			return a.id < b.id
		end)
		if #gone > 0 then
			self._remotes:fireAll("Build.Buildings", gone)
		end
		self._round = round
		self._sent = {}
		self._views = {}
	end
	local changed = {}
	local present = {}
	for _, id in sim.buildingOrder do
		local b = sim.buildings[id]
		local view = sim:viewOf(b)
		present[id] = true
		local signature =
			`{view.type}|{view.level}|{view.state}|{math.floor(view.progress * 100)}|{math.floor(view.hp)}|{view.maxHp}`
		if self._sent[id] ~= signature then
			self._sent[id] = signature
			self._views[id] = view
			table.insert(changed, view)
		end
	end
	-- removed from the world (cancelled sites, eliminated kingdoms): send "destroyed" once
	for id, view in self._views do
		if not present[id] then
			table.insert(changed, destroyedView(view))
			self._views[id] = nil
			self._sent[id] = nil
		end
	end
	if #changed > 0 then
		self._remotes:fireAll("Build.Buildings", changed)
	end
end

function BuildingService:destroy()
	self._running = false
end

return Def
