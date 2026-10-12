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
	Remotes (Build/Remotes.luau): Build.CanPlace / Build.Place (type, position, rot), Build.Upgrade,
	Build.GetBuildings, and Build.Buildings: the G2 views of buildings that changed (placed, progress,
	level, hp, destroyed), to every player, at most BROADCAST_HZ times per second.
	The facing comes from rot only; the client never sends a rotation (no CFrame on the wire).
	Not yet: build zones (G10.1 buildZones; the VS-1 path is G13.5 build slots, FL-0081) and linking
	a building's Door to the nav graph.
]]

local BuildingService = {}
BuildingService.__index = BuildingService

local Def = { name = "BuildingService", dependencies = { "MatchService", "RemoteService" } }

Def.BROADCAST_HZ = 2

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
	self._round = nil :: string?
	self._running = false
	return self
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
	self._running = true
	self._env.spawn(function()
		while self._running do
			self._env.wait(1 / Def.BROADCAST_HZ)
			if not self._running then
				break
			end
			local ok, err = pcall(self.broadcast, self)
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
function BuildingService:broadcast()
	local sim = self:_sim()
	local round = self._match.host.match.roundId
	if round ~= self._round then
		self._round = round
		self._sent = {} -- a new world: everything is new
	end
	local changed = {}
	for _, id in sim.buildingOrder do
		local b = sim.buildings[id]
		local view = sim:viewOf(b)
		local signature =
			`{view.type}|{view.level}|{view.state}|{math.floor(view.progress * 100)}|{math.floor(view.hp)}|{view.maxHp}`
		if self._sent[id] ~= signature then
			self._sent[id] = signature
			table.insert(changed, view)
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
