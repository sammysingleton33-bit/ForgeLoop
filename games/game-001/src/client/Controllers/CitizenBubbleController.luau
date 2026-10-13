--!strict
--[[
	CitizenBubbleController (game-001, FORGE-04, FL-0091; CONTRACTS G13.3, G4.1): citizens visibly think
	and react.

	Hooks only on EntityController (G4.1; only EntityController decodes Sim.*), found with
	registry:find in start():
		.event(entityId, "thought",  { scenarioId, text, icon }, model)   -> thought bubble ("!", "?", "…")
		.event(entityId, "reaction", { text, tone }, model)               -> reaction bubble + a pose
		.event(entityId, "strike",   { occupation, on }, model)           -> "On strike" placard while on
		.event(entityId, <cue>, payload, model) for a G13.3 `cue` in Vfx.cues (celebrate, grumble, salute,
		    bow, cower, strike_placard, work_fast, rest, hammer)          -> pose + sound + effect
		.event(entityId, "cue", { cue | cueId, tone? }, model)            -> the same; an unknown cue falls
		    back to the reaction tone (payload.tone, else the citizen's current reaction) for its pose
		.rendered(entityId, model) / .released(entityId, model)           -> attach / clear (pooled rigs)
	Targets (CONTRACTS G13.3 v0.4-g6): a strike or cue marks exactly the citizens the server named, never
	every citizen of an occupation. EntityController (FL-0079) fires one event per id. A payload that
	still carries `entityIds` (the raw Sim.Events shape) marks its entityId and each of its entityIds
	once. An event with neither (an occupation- or kingdom-wide cue) is the HUD's or the keep's, never
	shown on citizens here (stats.untargeted).
	A cue's effect is kept per citizen: a continuous one (`rest`'s motes) stops after the cue's `seconds`
	(Vfx.cues; else CUE_EFFECT_SEC), when the citizen's next cue plays an effect, or when its rig is
	released, so a pooled rig never keeps an emitter and the VFX budget is not held by idle citizens.
	Rules live in Feedback/Bubbles (one bubble per citizen, text from the event only, lifetimes, the
	on-screen cap and distance). The `citizenBarks` setting off hides reaction bubbles (the pose,
	sound and effect still play); thoughts and placards always show, because they are gameplay.
	The reaction pose (Bubbles.POSE[tone]: cheer, grumble, slump, salute) is requested from
	EntityController:playPose(entityId, pose) when it has one (proposed to FORGE-01).

	View: a pool of BillboardGuis (at most bubbles.maxOnScreen), reparented to the citizen's model.
	Distance is measured from the overview's focus (RulerCameraController:getFocus() while mode is
	"overview"), else from the camera (walk mode, whose focus would be the stale overview one), so
	zooming the overview out (40-220 studs) never hides the citizens under the view; the GUIs
	carry no MaxDistance of their own (0 = no limit) for the same reason. Rigs that EntityController's
	LOD hides (unparented) never take a slot. A job change swaps the rig (released, then rendered at
	once): the citizen keeps its thought, and drops a strike placard, because it left the striking
	occupation. Bubbles never take input (Active = false, no buttons), so a tap on a citizen still
	reaches InputModeController's selection (G13.6). While the ruler talks to a citizen
	(ConversationController.opened .. closed, G13.8; else its state.entityId), that citizen's bubble is
	hidden: the conversation panel shows the same words.

		CitizenBubbleController:refresh()   -- re-pick and redraw (Heartbeat calls it every POLL_SEC)
		CitizenBubbleController.bubbles     -- the Feedback/Bubbles model (specs)
		CitizenBubbleController.stats       -- { untargeted } events with no citizen to mark (specs)
]]

local Bubbles = require("@game/ReplicatedStorage/Game/Feedback/Bubbles")
local Vfx = require("@game/ReplicatedStorage/Forge/Config/Vfx")

local Def = {
	name = "CitizenBubbleController",
	dependencies = {},
}

Def.POLL_SEC = 0.25
Def.CUE_EFFECT_SEC = 6 -- a continuous cue effect with no `seconds` of its own stops after this
Def.UNKNOWN_CUE_LOG = 8 -- distinct unknown cue names warned about; later ones share one last warning
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

-- An entity id: a number, never NaN (NaN cannot be a table key).
local function isId(value: any): boolean
	return type(value) == "number" and value == value
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
		_unknownCues = 0,
		_leaving = {} :: { [number]: boolean },
		_cueEffects = {} :: { [number]: any },
		_talking = nil :: number?,
		bubbles = Bubbles.new({ now = env.clock, config = config.bubbles }),
		stats = { untargeted = 0 },
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
	self._camera = registry:find("RulerCameraController")
	self._conversation = registry:find("ConversationController")
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
				if not isId(id) then
					return
				end
				self._models[id] = model
				self._leaving[id] = nil -- a rig swap: the citizen stays
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
	local conversation = self._conversation
	local opened = connect(conversation, "opened", function(id)
		self._talking = if isId(id) then id else nil
		self:refresh()
	end)
	if opened ~= nil then
		self._talkSignals = true
		table.insert(self._connections, opened)
		table.insert(
			self._connections,
			connect(conversation, "closed", function()
				self._talking = nil
				self:refresh()
			end)
		)
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
	for id in self._cueEffects do
		self:_stopCueEffect(id)
	end
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
	if type(payload) ~= "table" then
		payload = {}
	end
	local listed = payload.entityIds
	if type(listed) ~= "table" then
		if isId(entityId) then
			self:_onCitizen(entityId, cue, payload, model)
		elseif entityId == nil then
			self.stats.untargeted += 1 -- occupation- or kingdom-wide: the HUD's or the keep's (G13.3)
		end
		return -- a NaN id: nothing to draw on
	end
	-- the raw G13.3 shape: exactly the citizens the server named, each once (v0.4-g6)
	local own = table.clone(payload)
	own.entityIds = nil
	local seen = {}
	if isId(entityId) then
		seen[entityId] = true
		self:_onCitizen(entityId, cue, own, model)
	end
	for _, id in listed do
		if isId(id) and not seen[id] then
			seen[id] = true
			self:_onCitizen(id, cue, own, nil)
		end
	end
	if next(seen) == nil then
		self.stats.untargeted += 1
	end
end

function Controller:_onCitizen(entityId: number, cue: string, payload: { [string]: any }, model: any)
	if model ~= nil then
		self._models[entityId] = model
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
	elseif cue == "cue" then
		self:_playCue(entityId, payload.cue or payload.cueId, payload.tone) -- content/SPEC.md says cueId
		return
	elseif self._config.cues and self._config.cues[cue] then
		self:_playCue(entityId, cue, nil)
		return
	else
		return -- other cues (deposit, hit, die) are FL-0062's feedback layer
	end
	self:refresh()
end

function Controller:refresh()
	for id in self._leaving do
		self.bubbles:release(id) -- released and not rendered again: the citizen is gone
	end
	table.clear(self._leaving)
	for _, id in self.bubbles:tick() do
		self:_undraw(id)
	end
	local origin = self:_originPosition()
	if origin == nil then
		return
	end
	-- only citizens with something to show, and only rigs in the world (LOD-hidden rigs are unparented)
	local positions = {}
	for id, model in self._models do
		if self.bubbles:get(id) ~= nil and model.Parent ~= nil then
			positions[id] = pivotOf(model)
		end
	end
	local talking = self:_talkingTo()
	local keep = {}
	for _, id in self.bubbles:pick(positions, origin) do
		local bubble = self.bubbles:get(id)
		if bubble ~= nil and id ~= talking and not (bubble.kind == "reaction" and self:_barksOff()) then
			keep[id] = bubble
		end
	end
	-- dropped bubbles go back to the pool first, so the new ones reuse them (never above maxOnScreen)
	for id in self._drawn do
		if not keep[id] then
			self:_undraw(id)
		end
	end
	for id, bubble in keep do
		self:_draw(id, bubble)
	end
end

-- ------------------------------------------------------------------ internals

function Controller:_barksOff(): boolean
	local settings = self._settings
	return settings ~= nil and settings:get("citizenBarks") == false
end

-- The citizen in the open conversation (G13.8 signals; else ConversationController.state on main).
function Controller:_talkingTo(): number?
	if self._talkSignals then
		return self._talking
	end
	local conversation = self._conversation
	local state = conversation and conversation.state
	local id = type(state) == "table" and state.entityId or nil
	return if isId(id) then id else nil
end

function Controller:_originPosition(): Vector3?
	if self._origin then
		return self._origin()
	end
	local camera = self._camera
	if camera ~= nil and camera.mode == "overview" and camera.getFocus ~= nil then
		local okFocus, focus = pcall(camera.getFocus, camera)
		if okFocus and typeof(focus) == "Vector3" then
			return focus
		end
	end
	local ok, position = pcall(function()
		return self._env.Workspace.CurrentCamera.CFrame.Position
	end)
	return if ok then position else nil
end

-- The rig goes back to the pool. The bubble state waits until the next refresh: a job change renders
-- the citizen's new rig straight after (EntityController), and then the thought stays.
function Controller:_release(entityId: number)
	if not isId(entityId) then
		return
	end
	self.bubbles:strike(entityId, false) -- a new job is a new occupation, so off strike
	self:_stopCueEffect(entityId) -- its emitter sits on the rig going back to the pool
	self._leaving[entityId] = true
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

function Controller:_playCue(entityId: any, cueId: any, tone: any)
	local spec = type(cueId) == "string" and self._config.cues and self._config.cues[cueId]
	if not spec then
		-- G13.3: an unknown cue falls back to the reaction tone
		local current = self.bubbles:get(entityId)
		local fallback = if type(tone) == "string"
			then tone
			elseif current and current.kind == "reaction" then current.tone
			else nil
		self:_pose(entityId, if fallback then Bubbles.POSE[fallback :: string] else nil)
		self:_warnUnknownCue(tostring(cueId))
		return
	end
	self:_pose(entityId, spec.pose)
	local model = if type(entityId) == "number" then self._models[entityId] else nil
	local position = if model then pivotOf(model) else nil
	if position == nil then
		return -- no rendered rig: nothing to show it on (never at the world origin)
	end
	if spec.sound and self._audio then
		self._audio:play(spec.sound, { position = position })
	end
	if spec.vfx and self._vfx then
		self:_stopCueEffect(entityId)
		local effect = self._vfx:play(spec.vfx, { position = position, parent = model })
		if type(effect) == "table" and effect.continuous then
			self._cueEffects[entityId] = effect
			local seconds = if type(spec.seconds) == "number" then spec.seconds else Def.CUE_EFFECT_SEC
			self._env.spawn(function()
				self._env.wait(seconds)
				if self._cueEffects[entityId] == effect then
					self:_stopCueEffect(entityId)
				end
			end)
		end
	end
end

function Controller:_stopCueEffect(entityId: number)
	local effect = self._cueEffects[entityId]
	if effect ~= nil then
		self._cueEffects[entityId] = nil
		pcall(self._vfx.stop, self._vfx, effect)
	end
end

-- Cue names come from the server: one warning per name, and only for the first few names.
function Controller:_warnUnknownCue(name: string)
	local key = "cue:" .. name
	if self._warned[key] or self._unknownCues > Def.UNKNOWN_CUE_LOG then
		return
	end
	self._unknownCues += 1
	if self._unknownCues > Def.UNKNOWN_CUE_LOG then
		self._env.log("warn", "CitizenBubbleController: more unknown cues; no longer logged")
		return
	end
	self._warned[key] = true
	self._env.log("warn", `CitizenBubbleController: unknown cue '{name}'`)
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
	gui.MaxDistance = 0 -- no engine limit: the model culls by distance to the camera focus
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
