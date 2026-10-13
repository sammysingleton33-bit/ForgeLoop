--!strict
--[[
	ObjectiveService — the neutral capture points in the world and on the wire (CONTRACTS G8; FL-0052).
	Owner: FORGE-01.

	The objectives live in the kingdom simulation (Sim/Objectives in MatchService's host), placed from
	world/Layout `objectives` (Kingdom/Layout). The simulation owns the capture rules (exclusive presence
	of soldiers or rulers, progress, contest, decay), and on capture it claims the objective's
	`regionId` and adds its Crown Points (config Objectives); this service never repeats them. It shows
	the objectives: a Kit watchtower per objective, and the Army.Objectives / Army.GetObjectives remotes.
	API (G8)
		ObjectiveService:list(): { { id, kind = "capture", position: Vector3, radius: number,
		                             owner: KingdomId?, progress: { [KingdomId]: number } } }
		ObjectiveService.captured: Signal<(objectiveId: string, KingdomId)>   once per capture
	Extra
		ObjectiveService:broadcast()          -- one throttled round: models, then Army.Objectives if changed
		ObjectiveService:getModel(objectiveId): Model?
		ObjectiveService.BROADCAST_HZ         -- Army.Objectives at most this many times per second
	World: Workspace.KingdomObjectives.<objectiveId> = Kit.build("watchtower", 1, "complete",
	Kit.NEUTRAL_COLOR), its pivot on the ground (Kit/WorldPlan heights) at the objective, facing as the
	Layout objective does, placed without PivotTo (WorldView.placeModel); attributes ObjectiveId and
	Owner. On capture it is recoloured in place with Kit.setKingdomColor (the owner's colour); a new
	match turns it neutral again.
	Remotes (Army/Remotes.luau): Army.GetObjectives -> list(); Army.Objectives(list) to every player when
	an owner or a progress (in whole percent) changes, at most BROADCAST_HZ times per second. list()
	rounds every progress to 0.01 (whole percent), so a payload changes exactly when its signature does.
	Events: G9 ObjectiveCaptured (objectiveId, KingdomId) is fired once per capture by the host's event
	fan-out (Kingdom/MatchHost); `captured` mirrors it for server services.
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local Kit = require("@game/ReplicatedStorage/Game/Kit/Kit")
local WorldPlan = require("@game/ReplicatedStorage/Game/Kit/WorldPlan")
local Layout = require("@game/ReplicatedStorage/Game/Kingdom/Layout")
local Objectives = require("@game/ReplicatedStorage/Game/Sim/Objectives")
local WorldView = require("@game/ReplicatedStorage/Game/Sim/WorldView")

local ObjectiveService = {}
ObjectiveService.__index = ObjectiveService

ObjectiveService.BROADCAST_HZ = 2
ObjectiveService.FOLDER = "KingdomObjectives"

local Def = { name = "ObjectiveService", dependencies = { "MatchService", "RemoteService" } }

function Def.new(env: any, registry: any)
	local self = setmetatable({}, ObjectiveService)
	self._env = env
	self._match = registry:get("MatchService")
	self._remotes = registry:get("RemoteService")
	self.captured = Signal.new()
	self._models = {} :: { [string]: any } -- objective id -> watchtower Model
	self._shown = {} :: { [string]: string } -- objective id -> owner the model is coloured for ("" = neutral)
	self._frames = {} :: { [string]: CFrame } -- objective id -> ground pivot (position and facing)
	self._sent = nil :: string? -- signature of the last Army.Objectives
	self._folder = nil :: any
	self._connection = nil :: any
	self._running = false
	return self
end

function ObjectiveService:_sim(): any
	return self._match.host.match.sim
end

-- The pivot of an objective's tower: on the ground at (x, z), turned as its world Layout objective.
function ObjectiveService:_frame(o: any): CFrame
	local frame = self._frames[o.id]
	if frame == nil then
		local y = WorldPlan.groundHeight(Layout.WORLD, o.x, o.z)
		frame = CFrame.new(o.x, y, o.z)
		for _, w in Layout.WORLD.objectives do
			if w.id == o.id then
				frame = frame * (w.cframe - w.cframe.Position)
			end
		end
		self._frames[o.id] = frame
	end
	return frame :: CFrame
end

-- A progress (0..1) in whole percent: what clients see of it.
local function percent(value: number): number
	return math.floor(value * 100 + 0.5)
end

function ObjectiveService:list(): { { [string]: any } }
	local out = {}
	for _, o in Objectives.list(self:_sim()) do
		local progress = {}
		for kid, value in o.progress do
			progress[kid] = percent(value) / 100 -- rounded to 0.01 for the wire
		end
		table.insert(out, {
			id = o.id,
			kind = "capture",
			position = self:_frame(o).Position,
			radius = o.radius,
			owner = o.owner,
			progress = progress,
		})
	end
	return out
end

function ObjectiveService:getModel(objectiveId: string): any?
	return self._models[objectiveId]
end

-- Builds a tower for each objective of the current match, recolours those whose owner changed and
-- removes towers of objectives that no longer exist.
function ObjectiveService:_syncModels()
	local sim = self:_sim()
	local live: { [string]: boolean } = {}
	for _, o in (sim.objectives and sim.objectives.list) or {} do
		live[o.id] = true
		local model = self._models[o.id]
		if model == nil then
			model = Kit.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR)
			model.Name = o.id
			WorldView.placeModel(model, self:_frame(o))
			model:SetAttribute("ObjectiveId", o.id)
			model.Parent = self._folder
			self._models[o.id] = model
			self._shown[o.id] = ""
		end
		local owner = o.owner or ""
		if self._shown[o.id] ~= owner then
			local kingdom = o.owner and sim.kingdoms[o.owner]
			local color = if kingdom
				then Color3.fromRGB(kingdom.color[1], kingdom.color[2], kingdom.color[3])
				else Kit.NEUTRAL_COLOR
			Kit.setKingdomColor(model, color)
			model:SetAttribute("Owner", o.owner)
			self._shown[o.id] = owner
		end
	end
	for id, model in self._models do
		if not live[id] then
			model:Destroy()
			self._models[id] = nil
			self._shown[id] = nil
		end
	end
end

-- What clients can see of the list: owners and progress in whole percent.
function ObjectiveService:_signature(list: { { [string]: any } }): string
	local parts = {}
	local order = self:_sim().kingdomOrder
	for _, view in list do
		local progress = {}
		for _, kid in order do
			local value = view.progress[kid]
			if value and percent(value) > 0 then
				table.insert(progress, `{kid}={percent(value)}`)
			end
		end
		table.insert(parts, `{view.id}:{view.owner or ""}:{table.concat(progress, ",")}`)
	end
	return table.concat(parts, "|")
end

-- One round: towers first, then Army.Objectives to every player when anything visible changed.
-- The loop calls it BROADCAST_HZ times per second; specs may call it directly.
function ObjectiveService:broadcast()
	self:_syncModels()
	local list = self:list()
	local signature = self:_signature(list)
	if signature ~= self._sent then
		self._sent = signature
		self._remotes:fireAll("Army.Objectives", list)
	end
end

function ObjectiveService:start()
	local folder = self._env.newInstance("Folder")
	folder.Name = ObjectiveService.FOLDER
	folder.Parent = self._env.Workspace
	self._folder = folder
	self:_syncModels()
	self._remotes:handle("Army.GetObjectives", function()
		return self:list()
	end)
	self._connection = self._match.host.events:connect(function(name: string, event: any)
		if name == "ObjectiveCaptured" then
			self:_syncModels() -- recolour at once, not on the next broadcast round
			self.captured:fire(event.objectiveId, event.kingdomId)
		end
	end)
	self._running = true
	self._env.spawn(function()
		while self._running do
			self._env.wait(1 / ObjectiveService.BROADCAST_HZ)
			if not self._running then
				break
			end
			local ok, err = pcall(self.broadcast, self)
			if not ok then
				self._env.log("error", "ObjectiveService: broadcast failed", { error = tostring(err) })
			end
		end
	end)
end

function ObjectiveService:destroy()
	self._running = false
	if self._connection then
		self._connection:disconnect()
		self._connection = nil
	end
	self.captured:disconnectAll()
	if self._folder then
		self._folder:Destroy()
		self._folder = nil
	end
	self._models = {}
	self._shown = {}
end

return Def
