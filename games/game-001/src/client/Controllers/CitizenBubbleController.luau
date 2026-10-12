--!strict
--[[
	CitizenBubbleController (game-001, FORGE-04, FL-0091; CONTRACTS G13.3, G4.1): citizens visibly think
	and react.

	Hooks only on EntityController (G4.1; only EntityController decodes Sim.*), found with
	registry:find in start():
		.event(entityId, "thought",  { scenarioId, text, icon }, model)   -> thought bubble ("!", "?", "…")
		.event(entityId, "reaction", { text, tone }, model)               -> reaction bubble + a pose
		.event(entityId, "strike",   { occupation, on }, model)           -> "On strike" placard while on
		.event(entityId, "consequence", { cue = id }, model)              -> config Vfx.cues[id]: sound + effect
		.rendered(entityId, model) / .released(entityId, model)           -> attach / clear (pooled rigs)
	Rules live in Feedback/Bubbles (one bubble per citizen, text from the event only, lifetimes, the
	on-screen cap and distance). The `citizenBarks` setting off hides reaction bubbles (the pose,
	sound and effect still play); thoughts and placards always show, because they are gameplay.
	The reaction pose (Bubbles.POSE[tone]: cheer, grumble, slump, salute) is requested from
	EntityController:playPose(entityId, pose) when it has one (proposed to FORGE-01).

	View: a pool of BillboardGuis (at most bubbles.maxOnScreen), reparented to the citizen's model,
	with MaxDistance as a second guard. Bubbles never take input (Active = false, no buttons), so a
	tap on a citizen still reaches InputModeController's selection (G13.6).

		CitizenBubbleController:refresh()   -- re-pick and redraw (Heartbeat calls it every POLL_SEC)
		CitizenBubbleController.bubbles     -- the Feedback/Bubbles model (specs)
]]

local Bubbles = require("@game/ReplicatedStorage/Game/Feedback/Bubbles")
local Vfx = require("@game/ReplicatedStorage/Forge/Config/Vfx")

local Def = {
	name = "CitizenBubbleController",
	dependencies = {},
}

Def.POLL_SEC = 0.25
Def.HEIGHT = 3.2 -- studs above the model's pivot
local rgb = Color3.fromRGB
Def.STYLE = table.freeze({
	thought = table.freeze({ background = rgb(250, 246, 235), text = rgb(40, 32, 24) }),
	reaction = table.freeze({ background = rgb(255, 255, 255), text = rgb(30, 26, 22) }),
	strike = table.freeze({ background = rgb(120, 40, 30), text = rgb(255, 245, 230) }),
})

local Controller = {}
Controller.__index = Controller

local function connect(target: any, signalName: string, handler: (...any) -> ()): any
	local signal = target and target[signalName]
	if signal == nil then
		return nil
	end
	local ok, connection = pcall(function()
		return signal:connect(handler)
	end)
	return if ok then connection else nil
end

local function pivotOf(model: any): Vector3?
	local ok, position = pcall(function()
		local primary = model.PrimaryPart
		if primary then
			return primary.CFrame.Position
		end
		return model:GetPivot().Position
	end)
	return if ok then position else nil
end

-- opts (specs): { config = { bubbles, cues }, origin = () -> Vector3 }
function Def.create(env: any, registry: any, opts: { [string]: any }?): any
	local options = opts or {}
	local config = options.config or Vfx
	return setmetatable({
		_env = env,
		_registry = registry,
		_config = config,
		_origin = options.origin,
		_models = {} :: { [number]: any },
		_drawn = {} :: { [number]: any },
		_pool = {} :: { any },
		_connections = {},
		_running = false,
		_warned = {},
		bubbles = Bubbles.new({ now = env.clock, config = config.bubbles }),
	}, Controller)
end

function Def.new(env: any, registry: any): any
	return Def.create(env, registry)
end

function Controller:start()
	local registry = self._registry
	self._entities = registry:find("EntityController")
	self._settings = registry:find("SettingsController")
	self._audio = registry:find("AudioController")
	self._vfx = registry:find("VFXController")
	local entities = self._entities
	if entities == nil then
		self._env.log(
			"info",
			"CitizenBubbleController: no EntityController yet; bubbles wait for FORGE-01's G4.1 signals"
		)
		return
	end
	for _, item in
		{
			connect(entities, "rendered", function(id, model)
				self._models[id] = model
			end),
			connect(entities, "released", function(id)
				self:_release(id)
			end),
			connect(entities, "event", function(id, cue, payload, model)
				self:onEvent(id, cue, payload, model)
			end),
		}
	do
		table.insert(self._connections, item)
	end
	self._running = true
	local env = self._env
	env.spawn(function()
		while self._running do
			self:refresh()
			env.wait(Def.POLL_SEC)
		end
	end)
end

function Controller:destroy()
	self._running = false
	for _, connection in self._connections do
		pcall(function()
			connection:disconnect()
		end)
	end
	table.clear(self._connections)
	for _, gui in self._drawn do
		gui:Destroy()
	end
	for _, gui in self._pool do
		gui:Destroy()
	end
	table.clear(self._drawn)
	table.clear(self._pool)
end

function Controller:onEvent(entityId: any, cue: string, payload: any, model: any)
	if model ~= nil and type(entityId) == "number" then
		self._models[entityId] = model
	end
	if type(payload) ~= "table" then
		payload = {}
	end
	if cue == "thought" then
		self.bubbles:thought(entityId, payload)
	elseif cue == "reaction" then
		local bubble = self.bubbles:reaction(entityId, payload)
		if bubble ~= nil then
			self:_pose(entityId, Bubbles.POSE[bubble.tone :: string])
		end
	elseif cue == "strike" then
		self.bubbles:strike(entityId, payload.on == true)
	elseif cue == "consequence" then
		self:_playCue(payload.cue, entityId)
		return
	else
		return -- other cues (deposit, hit, celebrate) are FL-0062's feedback layer
	end
	self:refresh()
end

function Controller:refresh()
	for _, id in self.bubbles:tick() do
		self:_undraw(id)
	end
	local origin = self:_originPosition()
	if origin == nil then
		return
	end
	local positions = {}
	for id, model in self._models do
		local position = pivotOf(model)
		if position ~= nil then
			positions[id] = position
		end
	end
	local keep = {}
	for _, id in self.bubbles:pick(positions, origin) do
		local bubble = self.bubbles:get(id)
		if bubble ~= nil and not (bubble.kind == "reaction" and self:_barksOff()) then
			keep[id] = true
			self:_draw(id, bubble)
		end
	end
	for id in self._drawn do
		if not keep[id] then
			self:_undraw(id)
		end
	end
end

-- ------------------------------------------------------------------ internals

function Controller:_barksOff(): boolean
	local settings = self._settings
	return settings ~= nil and settings:get("citizenBarks") == false
end

function Controller:_originPosition(): Vector3?
	if self._origin then
		return self._origin()
	end
	local ok, position = pcall(function()
		return self._env.Workspace.CurrentCamera.CFrame.Position
	end)
	return if ok then position else nil
end

function Controller:_release(entityId: number)
	self.bubbles:release(entityId)
	self:_undraw(entityId)
	self._models[entityId] = nil
end

function Controller:_pose(entityId: number, pose: string?)
	local entities = self._entities
	if pose == nil or entities == nil then
		return
	end
	if entities.playPose == nil then
		if not self._warned.pose then
			self._warned.pose = true
			self._env.log(
				"info",
				"CitizenBubbleController: EntityController has no playPose yet; reaction poses skipped"
			)
		end
		return
	end
	pcall(entities.playPose, entities, entityId, pose)
end

function Controller:_playCue(cueId: any, entityId: any)
	local spec = type(cueId) == "string" and self._config.cues and self._config.cues[cueId]
	if not spec then
		if not self._warned[tostring(cueId)] then
			self._warned[tostring(cueId)] = true
			self._env.log("warn", `CitizenBubbleController: unknown consequence cue '{tostring(cueId)}'`)
		end
		return
	end
	local model = if type(entityId) == "number" then self._models[entityId] else nil
	local position = if model then pivotOf(model) else nil
	if spec.sound and self._audio then
		self._audio:play(spec.sound, { position = position })
	end
	if spec.vfx and self._vfx then
		self._vfx:play(spec.vfx, { position = position, parent = model })
	end
end

local function build(env: any): any
	local gui = env.newInstance("BillboardGui")
	gui.Name = "ForgeCitizenBubble"
	gui.Size = UDim2.fromOffset(180, 46)
	gui.StudsOffset = Vector3.new(0, Def.HEIGHT, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Active = false
	local frame = env.newInstance("Frame")
	frame.Name = "Bubble"
	frame.Size = UDim2.fromScale(1, 1)
	frame.Active = false
	frame.Parent = gui
	local glyph = env.newInstance("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.new(0, 22, 1, 0)
	glyph.Font = Enum.Font.GothamBold
	glyph.TextSize = 22
	glyph.Parent = frame
	local text = env.newInstance("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(24, 0)
	text.Size = UDim2.new(1, -28, 1, 0)
	text.Font = Enum.Font.Gotham
	text.TextSize = 13
	text.TextWrapped = true
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = frame
	return gui
end

function Controller:_draw(entityId: number, bubble: any)
	local model = self._models[entityId]
	if model == nil then
		return
	end
	local gui = self._drawn[entityId]
	if gui == nil then
		gui = table.remove(self._pool) or build(self._env)
		self._drawn[entityId] = gui
	end
	local config = self._config.bubbles or Bubbles.DEFAULTS
	gui.MaxDistance = config.maxDistance or Bubbles.DEFAULTS.maxDistance
	local style = Def.STYLE[bubble.kind]
	local frame = gui:FindFirstChild("Bubble")
	frame.BackgroundColor3 = style.background
	local glyph = frame:FindFirstChild("Glyph")
	glyph.Text = bubble.glyph or ""
	glyph.TextColor3 = style.text
	local text = frame:FindFirstChild("Text")
	text.Text = bubble.text
	text.TextColor3 = style.text
	gui:SetAttribute("BubbleKind", bubble.kind)
	gui.Adornee = model.PrimaryPart or model
	gui.Parent = model
end

function Controller:_undraw(entityId: number)
	local gui = self._drawn[entityId]
	if gui == nil then
		return
	end
	self._drawn[entityId] = nil
	pcall(function() -- nil is valid in Roblox; Lune's reflection refuses a nil Ref
		gui.Adornee = nil
	end)
	gui.Parent = nil
	table.insert(self._pool, gui)
end

return table.freeze(Def)
