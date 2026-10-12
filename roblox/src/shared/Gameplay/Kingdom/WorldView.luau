--!strict
--[[
	Gameplay/Kingdom/WorldView — renders the simulation as temporary placeholder parts (server side).

	Until FORGE-02's kingdom assets exist, every entity is one anchored Part so the world is visible
	and testable: keeps, houses, farms, ... sized by footprint and level; construction sites are
	translucent and grow with progress; citizens and soldiers are small blocks that move each tick;
	trees, rocks and gold veins shrink to stumps when depleted. Parts replicate to clients normally.
	Asset ids replace these parts later without touching the simulation (look up by EntityId).

		Workspace.ForgeKingdoms
			Ground                      flat ground sized to the map bounds (createGround = true)
			Nodes/<nodeId>              attributes: EntityId, Kind, Resource, Amount
			<kingdomId>/Buildings/<id>  attributes: EntityId, KingdomId, Kind, Level, PendingLevel, Progress, Hp, MaxHp
			<kingdomId>/Citizens/<id>   attributes: EntityId, KingdomId, Occupation, Activity, CitizenName
			<kingdomId>/Units/<id>      attributes: EntityId, KingdomId, Kind, Hp, MaxHp

	API
		WorldView.new(env, options?): WorldView
			options: { groundY = 0, parent = env.Workspace, createGround = true }
		view:sync(sim)                 -- create, update and remove parts to match the simulation
		view:find(entityId): Instance?
		view:count(): number           -- live entity parts (specs)
		view:destroy()
	Positions: simulation X/Z map to world X/Z; Y is groundY plus half the part height.
]]

local WorldView = {}
WorldView.__index = WorldView

local BUILDING_STYLE: { [string]: { height: number, color: { number }?, material: string } } = {
	Keep = { height = 22, material = "Slate" },
	House = { height = 9, color = { 140, 98, 57 }, material = "WoodPlanks" },
	Farm = { height = 1, color = { 160, 170, 70 }, material = "Grass" },
	Storehouse = { height = 11, color = { 120, 85, 50 }, material = "WoodPlanks" },
	Barracks = { height = 12, material = "Brick" },
	Tower = { height = 24, material = "Cobblestone" },
	Wall = { height = 10, color = { 130, 130, 125 }, material = "Cobblestone" },
}
local NODE_STYLE: { [string]: { size: { number }, color: { number }, material: string } } = {
	Tree = { size = { 4, 14, 4 }, color = { 50, 110, 45 }, material = "Grass" },
	Rock = { size = { 8, 6, 8 }, color = { 120, 120, 125 }, material = "Slate" },
	GoldVein = { size = { 7, 5, 7 }, color = { 230, 190, 60 }, material = "Foil" },
}
local OCCUPATION_COLOR: { [string]: { number } } = {
	Farmer = { 200, 180, 90 },
	Woodcutter = { 110, 75, 40 },
	Quarrier = { 150, 150, 150 },
	Miner = { 90, 90, 110 },
	Builder = { 230, 140, 40 },
	Laborer = { 200, 200, 200 },
}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function WorldView.new(env: any, options: { [string]: any }?)
	local opts = options or {}
	local self = setmetatable({}, WorldView)
	self._env = env
	self._groundY = opts.groundY or 0
	self._createGround = if opts.createGround == nil then true else opts.createGround
	self._parts = {} :: { [string]: any }
	local root = env.newInstance("Folder")
	root.Name = "ForgeKingdoms"
	root.Parent = opts.parent or env.Workspace
	self._root = root
	self._nodes = self:_folder(root, "Nodes")
	self._kingdomFolders = {} :: { [string]: { [string]: any } }
	self._ground = nil :: any
	return self
end

function WorldView:_folder(parent: any, name: string): any
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = self._env.newInstance("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function WorldView:_kingdom(kingdom: any): { [string]: any }
	local folders = self._kingdomFolders[kingdom.id]
	if folders == nil then
		local root = self:_folder(self._root, kingdom.id)
		root:SetAttribute("KingdomName", kingdom.name)
		folders = {
			root = root,
			Buildings = self:_folder(root, "Buildings"),
			Citizens = self:_folder(root, "Citizens"),
			Units = self:_folder(root, "Units"),
		}
		self._kingdomFolders[kingdom.id] = folders
	end
	return folders
end

function WorldView:_part(id: string, parent: any, size: Vector3, color: Color3, material: string): any
	local part = self._parts[id]
	if part == nil then
		part = self._env.newInstance("Part")
		part.Name = id
		part.Anchored = true
		part.CanCollide = false
		part:SetAttribute("EntityId", id)
		part.Parent = parent
		self._parts[id] = part
	end
	if part.Size ~= size then
		part.Size = size
	end
	if part.Color ~= color then
		part.Color = color
	end
	local mat = (Enum.Material :: any)[material]
	if part.Material ~= mat then
		part.Material = mat
	end
	return part
end

function WorldView:_place(part: any, x: number, z: number, height: number)
	local target = CFrame.new(x, self._groundY + height / 2, z)
	if (part.CFrame.Position - target.Position).Magnitude > 0.05 then
		part.CFrame = target
	end
end

function WorldView:_ensureGround(sim: any)
	if not self._createGround or self._ground ~= nil then
		return
	end
	local b = sim.bounds
	local ground = self._env.newInstance("Part")
	ground.Name = "Ground"
	ground.Anchored = true
	ground.Size = Vector3.new(b.maxX - b.minX, 1, b.maxZ - b.minZ)
	ground.CFrame = CFrame.new((b.minX + b.maxX) / 2, self._groundY - 0.5, (b.minZ + b.maxZ) / 2)
	ground.Color = Color3.fromRGB(96, 140, 70)
	ground.Material = Enum.Material.Grass
	ground.Parent = self._root
	self._ground = ground
end

function WorldView:sync(sim: any)
	self:_ensureGround(sim)
	local live: { [string]: boolean } = {}

	for _, nid in sim.nodeOrder do
		local node = sim.nodes[nid]
		local style = NODE_STYLE[node.kind]
		local size = style.size
		local depleted = node.amount <= 0
		local h = if depleted then 1.5 else size[2]
		local part = self:_part(nid, self._nodes, Vector3.new(size[1], h, size[3]), rgb(style.color), style.material)
		part.Transparency = if depleted then 0.6 else 0
		part:SetAttribute("Kind", node.kind)
		part:SetAttribute("Resource", node.resource)
		part:SetAttribute("Amount", node.amount)
		self:_place(part, node.x, node.z, h)
		live[nid] = true
	end

	for _, kid in sim.kingdomOrder do
		local kingdom = sim.kingdoms[kid]
		local folders = self:_kingdom(kingdom)
		local kingdomColor = rgb(kingdom.color)
		for _, bid in kingdom.buildingIds do
			local b = sim.buildings[bid]
			local style = BUILDING_STYLE[b.kind] or { height = 8, material = "Plastic" }
			local width = b.footprint * 1.6
			local fullHeight = style.height * (1 + 0.25 * math.max(0, b.level - 1))
			local progress = 1
			if b.level == 0 and b.pendingLevel ~= nil then
				local stats = sim.catalog.buildings[b.kind].levels[b.pendingLevel]
				progress = math.clamp(b.progress / stats.work, 0.05, 1)
			end
			local height = math.max(1, fullHeight * progress)
			local color = if style.color then rgb(style.color) else kingdomColor
			local part = self:_part(bid, folders.Buildings, Vector3.new(width, height, width), color, style.material)
			part.Transparency = if b.level == 0 then 0.55 else 0
			part:SetAttribute("KingdomId", kid)
			part:SetAttribute("Kind", b.kind)
			part:SetAttribute("Level", b.level)
			part:SetAttribute("PendingLevel", b.pendingLevel)
			part:SetAttribute("Progress", progress)
			part:SetAttribute("Hp", b.hp)
			part:SetAttribute("MaxHp", b.maxHp)
			self:_place(part, b.x, b.z, height)
			live[bid] = true
		end
		for _, cid in kingdom.citizenIds do
			local c = sim.citizens[cid]
			local part = self:_part(
				cid,
				folders.Citizens,
				Vector3.new(1.6, 4.5, 1.6),
				rgb(OCCUPATION_COLOR[c.occupation] or { 200, 200, 200 }),
				"SmoothPlastic"
			)
			part:SetAttribute("KingdomId", kid)
			part:SetAttribute("Occupation", c.occupation)
			part:SetAttribute("Activity", c.activity)
			part:SetAttribute("CitizenName", c.name)
			self:_place(part, c.x, c.z, 4.5)
			live[cid] = true
		end
		for _, uid in kingdom.unitIds do
			local u = sim.units[uid]
			local part = self:_part(uid, folders.Units, Vector3.new(2, 5, 2), kingdomColor, "Metal")
			part:SetAttribute("KingdomId", kid)
			part:SetAttribute("Kind", u.kind)
			part:SetAttribute("Hp", u.hp)
			part:SetAttribute("MaxHp", u.maxHp)
			self:_place(part, u.x, u.z, 5)
			live[uid] = true
		end
	end

	for id, part in self._parts do
		if not live[id] then
			part:Destroy()
			self._parts[id] = nil
		end
	end
end

function WorldView:find(entityId: string): any?
	return self._parts[entityId]
end

function WorldView:count(): number
	local n = 0
	for _ in self._parts do
		n += 1
	end
	return n
end

function WorldView:destroy()
	self._root:Destroy()
	self._parts = {}
	self._kingdomFolders = {}
end

return WorldView
