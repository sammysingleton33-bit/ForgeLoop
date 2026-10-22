--!strict
--[[
	CitizenBubbleController (game-001, FORGE-04, FL-0091; CONTRACTS G13.3, G4.1): citizens visibly think
	and react.

	Hooks only on EntityController (G4.1; only EntityController decodes Sim.*), found with
	registry:find in start():
		.event(entityId, "thought",  { scenarioId, text, icon }, model)   -> thought bubble ("!", "?", "…")
		.event(entityId, "reaction", { text, tone }, model)               -> reaction bubble + a pose
		.event(entityId, "strike",   { occupation, on }, model)           -> "On strike" placard while on
		.event(entityId, "riot",     { on }, model)                       -> "Rioting" placard while on (G13.3
		                                                                     v0.4-g10c; EntityController turns a
		                                                                     strike marked riot into this event)
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

	View: a pool of BillboardGuis (at most bubbles.maxOnScreen), adorned to the citizen's rig. Read from
	the aerial camera (FL-0115; the user's first Studio playtest: bubbles were hard to see and to tap):
		- always on top, so roofs and trees never hide a request; the bubble's bottom edge sits HEIGHT
		  studs above the rig's pivot (SizeOffset), clear of the head;
		- a round glyph badge ("!", "?", "…", each with its own colour, never colour alone) and 17 px
		  words on a light card with a dark outline; at most two lines, cut with an ellipsis (the card and
		  the conversation show the rest);
		- at most 3 bubbles show their words (2 on a phone, 1 zoomed far out: Bubbles:textLimit), and
		  only where their card covers no other bubble on screen (Bubbles:layout, from each bubble's
		  projected position): the other requests show their badge alone, and a reaction without room
		  is not drawn (its pose, sound and effect still play), so eight requests never bury the
		  kingdom. Bubbles keep their size at every zoom (offset pixels);
		- a new request's badge pops twice (PULSE), once per request, never under reduced motion;
		- a tap or click on a bubble selects its citizen (InputModeController:select("citizen", id), G13.6),
		  exactly as a tap on the citizen does, so FORGE-03's card opens. Roblox gives a BillboardGui input
		  only under PlayerGui, so the bubbles live there (ResetOnSpawn off); with no PlayerGui (headless)
		  they sit in the rig and take no input. Outside explore mode (placing a building) they take no
		  input either (Active = false), so a tap there still places.
	Distance is measured from the overview's focus (RulerCameraController:getFocus() while mode is
	"overview"), else from the camera (walk mode, whose focus would be the stale overview one), so
	zooming the overview out (40-220 studs) never hides the citizens under the view; the GUIs
	carry no MaxDistance of their own (0 = no limit) for the same reason. Rigs that EntityController's
	LOD hides (unparented) never take a slot. A job change swaps the rig (released, then rendered at
	once): the citizen keeps its thought and its strike placard, because a strike belongs to the
	citizen (v0.4-g6) and the server sends "off" only when it ends (FORGE-05 #87 M1). A despawn
	(released and not rendered again) clears both. While the ruler talks to a citizen
	(ConversationController.opened .. closed, G13.8; else its state.entityId), that citizen's bubble is
	hidden: the conversation panel shows the same words.

		CitizenBubbleController:refresh()   -- re-pick and redraw (Heartbeat calls it every POLL_SEC)
		CitizenBubbleController:requests() -> { { entityId, position, since } }
		                                    -- open requests with a rig (also LOD-hidden ones, at their last
		                                    -- pivot), except the citizen being talked to (B16 indicators)
		CitizenBubbleController.bubbles     -- the Feedback/Bubbles model (specs)
		CitizenBubbleController.stats       -- { untargeted } events with no citizen to mark (specs)
]]

local Bubbles = require("@game/ReplicatedStorage/Game/Feedback/Bubbles")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local EntityController = require("./EntityController") -- RIG_SCALE: the drawn rig's size (D-059)
local Motion = require("@game/ReplicatedStorage/Forge/UI/Motion")
local ScreenLayout = require("../UI/Layout")
local Vfx = require("@game/ReplicatedStorage/Forge/Config/Vfx")

local Def = {
	name = "CitizenBubbleController",
	dependencies = {},
}

Def.POLL_SEC = 0.25
Def.CUE_EFFECT_SEC = 6 -- a continuous cue effect with no `seconds` of its own stops after this
Def.UNKNOWN_CUE_LOG = 8 -- distinct unknown cue names warned about; later ones share one last warning
Def.HEIGHT = 3.2 * EntityController.RIG_SCALE -- studs above the model's pivot: the bubble's bottom edge (3.2 at the Kit size, scaled with the drawn rig, D-059)
Def.SIZE = table.freeze({ -- Bubbles.SIZES, which the layout uses
	card = UDim2.fromOffset(Bubbles.SIZES.card.X, Bubbles.SIZES.card.Y), -- a thought with words, or a reaction
	badge = UDim2.fromOffset(Bubbles.SIZES.badge.X, Bubbles.SIZES.badge.Y), -- a thought's glyph alone
	placard = UDim2.fromOffset(Bubbles.SIZES.placard.X, Bubbles.SIZES.placard.Y),
})
Def.TEXT_SIZE = 17
Def.GLYPH_SIZE = 28
Def.BADGE_SIZE = 44
local rgb = Color3.fromRGB
Def.INK = rgb(40, 32, 24)
Def.STYLE = table.freeze({
	thought = table.freeze({ background = rgb(250, 246, 235), text = Def.INK }),
	reaction = table.freeze({ background = rgb(255, 255, 255), text = rgb(30, 26, 22) }),
	strike = table.freeze({ background = rgb(150, 42, 30), text = rgb(255, 245, 230) }),
	-- fire orange with dark ink: apart from the strike's dark red, and the words say it too
	riot = table.freeze({ background = rgb(236, 112, 28), text = Def.INK }),
})
-- A new request's badge pops from `scale` back to 1, `times` times (UI/Motion; at once without it).
Def.PULSE = table.freeze({ scale = 1.35, sec = 0.3, gap = 0.45, times = 2 })
-- Badge colours per glyph (Bubbles.ICON); the glyph itself carries the meaning (G13.3).
Def.BADGE = table.freeze({
	["!"] = rgb(242, 190, 60), -- request
	["?"] = rgb(140, 186, 236), -- concern
	["…"] = rgb(166, 214, 146), -- idea
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

-- An entity id: a whole number >= 1 (the sim counts from 1); never NaN, infinite or fractional.
local function isId(value: any): boolean
	return type(value) == "number" and value >= 1 and value < math.huge and value % 1 == 0
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

-- opts (specs): { config = { bubbles, cues }, origin = () -> Vector3, playerGui = Instance,
--   project = (Vector3) -> Vector2? (the camera's WorldToViewportPoint) }
function Def.create(env: any, registry: any, opts: { [string]: any }?): any
	local options = opts or {}
	local config = options.config or Vfx
	return setmetatable({
		_env = env,
		_registry = registry,
		_config = config,
		_origin = options.origin,
		_playerGuiOverride = options.playerGui,
		_project = options.project,
		_playerGui = nil :: any,
		_pulsed = {} :: { [number]: string }, -- entity id -> the request its badge last popped for
		_motion = Motion.new(env),
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
	self._input = registry:find("InputModeController")
	self._playerGui = self._playerGuiOverride or self:_findPlayerGui()
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
	local modeChanged = connect(self._input, "changed", function()
		self:refresh() -- bubbles take input only in explore mode
	end)
	if modeChanged ~= nil then
		table.insert(self._connections, modeChanged)
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
			if self:_onCitizen(entityId, cue, payload, model) then
				self:refresh()
			end
		elseif entityId == nil then
			self.stats.untargeted += 1 -- occupation- or kingdom-wide: the HUD's or the keep's (G13.3)
		end
		return -- a NaN id: nothing to draw on
	end
	-- the raw G13.3 shape: exactly the citizens the server named, each once (v0.4-g6)
	local own = table.clone(payload)
	own.entityIds = nil
	local seen = {}
	local changed = false
	if isId(entityId) then
		seen[entityId] = true
		changed = self:_onCitizen(entityId, cue, own, model)
	end
	for index = 1, #listed do -- the list part only
		local id = listed[index]
		if isId(id) and not seen[id] then
			seen[id] = true
			changed = self:_onCitizen(id, cue, own, nil) or changed
		end
	end
	if next(seen) == nil then
		self.stats.untargeted += 1
	end
	if changed then
		self:refresh() -- once per event, however many citizens it named (FORGE-05 #87 L2)
	end
end

-- Applies one event to one citizen; true when a bubble may have changed (the caller refreshes once).
function Controller:_onCitizen(entityId: number, cue: string, payload: { [string]: any }, model: any): boolean
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
	elseif cue == "riot" then
		self.bubbles:riot(entityId, payload.on == true)
	elseif cue == "cue" then
		self:_playCue(entityId, payload.cue or payload.cueId, payload.tone) -- content/SPEC.md says cueId
		return false
	elseif self._config.cues and self._config.cues[cue] then
		self:_playCue(entityId, cue, nil)
		return false
	else
		return false -- other cues (deposit, hit, die) are FL-0062's feedback layer
	end
	return true
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
	local order = {}
	for _, id in self.bubbles:pick(positions, origin) do
		local bubble = self.bubbles:get(id)
		if bubble ~= nil and id ~= talking and not (bubble.kind == "reaction" and self:_barksOff()) then
			keep[id] = bubble
			table.insert(order, id)
		end
	end
	local anchors = {}
	for _, id in order do
		anchors[id] = self:_screenPoint(positions[id] + Vector3.new(0, Def.HEIGHT, 0))
	end
	local forms = self.bubbles:layout(order, self.bubbles:textLimit(self:_zoom(origin), self:_isPhone()), anchors)
	local interactive = self:_interactive()
	for id in self._pulsed do
		local bubble = self.bubbles:get(id)
		if bubble == nil or bubble.kind ~= "thought" then
			self._pulsed[id] = nil -- answered or gone: the next request pops again
		end
	end
	-- dropped bubbles go back to the pool first, so the new ones reuse them (never above maxOnScreen)
	for id in self._drawn do
		if not (keep[id] and forms[id]) then
			self:_undraw(id)
		end
	end
	for id, bubble in keep do
		if forms[id] then
			self:_draw(id, bubble, forms[id] == "words", interactive)
		end
	end
end

-- Open requests ("!" thoughts) with a rig, for CitizenBubbleIndicatorController (B16): far or LOD-hidden
-- citizens count too, at their rig's last pivot. The citizen in the conversation is left out.
function Controller:requests(): { { entityId: number, position: Vector3, since: number } }
	local talking = self:_talkingTo()
	local out = {}
	for _, request in self.bubbles:requests() do
		local model = self._models[request.entityId]
		local position = if model ~= nil and request.entityId ~= talking then pivotOf(model) else nil
		if position ~= nil then
			table.insert(out, { entityId = request.entityId, position = position, since = request.since })
		end
	end
	return out
end

-- A tap or click on a bubble: select its citizen, as a tap on the citizen would (G13.6).
function Controller:tap(entityId: any): boolean
	local input = self._input
	if not isId(entityId) or input == nil or input.select == nil then
		return false
	end
	if input.accepts ~= nil and not input:accepts("explore") then
		return false
	end
	return input:select("citizen", entityId) == true
end

-- ------------------------------------------------------------------ internals

-- Where a world point is on screen (pixels), for Bubbles:layout; nil when unknown or behind the camera.
function Controller:_screenPoint(position: Vector3): Vector2?
	if self._project ~= nil then
		return self._project(position)
	end
	local ok, point = pcall(function()
		return self._env.Workspace.CurrentCamera:WorldToViewportPoint(position)
	end)
	if not ok or typeof(point) ~= "Vector3" or point.Z <= 0 then
		return nil -- behind the camera (or no camera): no overlap test for it
	end
	return Vector2.new(point.X, point.Y)
end

-- The camera's distance to the view's centre (the overview's zoom); 0 when unknown.
function Controller:_zoom(origin: Vector3): number
	local ok, distance = pcall(function()
		return (self._env.Workspace.CurrentCamera.CFrame.Position - origin).Magnitude
	end)
	return if ok and type(distance) == "number" then distance else 0
end

function Controller:_isPhone(): boolean
	local ok, phone = pcall(function()
		local size = self._env.Workspace.CurrentCamera.ViewportSize
		return ScreenLayout.breakpoint(size.X, size.Y) == "phone"
	end)
	return ok and phone == true
end

function Controller:_reducedMotion(): boolean
	local settings = self._settings
	if settings == nil or settings.reducedMotion == nil then
		return false
	end
	local ok, reduced = pcall(settings.reducedMotion, settings)
	return ok and reduced == true
end

-- A new request's badge pops (once per request; never under reduced motion).
function Controller:_pulse(entityId: number, gui: any, bubble: any)
	if bubble.kind ~= "thought" then
		return
	end
	local key = tostring(bubble.scenarioId or bubble.text)
	if self._pulsed[entityId] == key then
		return
	end
	self._pulsed[entityId] = key
	if self:_reducedMotion() then
		return
	end
	local scale = gui:FindFirstChild("Pulse", true)
	if scale == nil then
		return
	end
	gui:SetAttribute("PulsedAt", self._env.clock())
	local motion = self._motion
	local pulse = Def.PULSE
	local function pop()
		scale.Scale = pulse.scale
		motion:to(scale, { Scale = 1 }, pulse.sec)
	end
	pop()
	for index = 2, pulse.times do
		motion:after(pulse.gap * (index - 1), function()
			if gui:GetAttribute("EntityId") == entityId then -- not a pooled GUI that moved on
				pop()
			end
		end)
	end
end

function Controller:_findPlayerGui(): any
	local ok, found = pcall(function()
		return self._env.Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	end)
	return if ok then found else nil
end

-- Bubbles take input only under PlayerGui, and only in explore mode (not while placing).
function Controller:_interactive(): boolean
	if self._playerGui == nil then
		return false
	end
	local input = self._input
	return input == nil or input.mode == nil or input.mode == "explore"
end

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

function Controller:_build(): any
	local env = self._env
	local gui = env.newInstance("BillboardGui")
	gui.Name = "ForgeCitizenBubble"
	gui.Size = Def.SIZE.card
	gui.SizeOffset = Vector2.new(0, 0.5) -- the bottom edge at HEIGHT, clear of the head
	gui.StudsOffset = Vector3.new(0, Def.HEIGHT, 0)
	gui.AlwaysOnTop = true -- roofs and trees never hide a request from the aerial camera
	gui.LightInfluence = 0
	gui.Active = false
	pcall(function()
		gui.ResetOnSpawn = false -- under PlayerGui: survives the ruler's respawn
	end)
	local button = env.newInstance("TextButton")
	button.Name = "Bubble"
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = gui
	local corner = env.newInstance("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = button
	local stroke = env.newInstance("UIStroke")
	stroke.Name = "Outline"
	stroke.Thickness = 2
	stroke.Color = Def.INK
	stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button
	local badge = env.newInstance("Frame")
	badge.Name = "Badge"
	badge.Parent = button
	local round = env.newInstance("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = badge
	local ring = env.newInstance("UIStroke")
	ring.Thickness = 2
	ring.Color = Def.INK
	ring.Parent = badge
	local pulse = env.newInstance("UIScale")
	pulse.Name = "Pulse"
	pulse.Parent = badge
	local glyph = env.newInstance("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.Font = Enum.Font.GothamBlack
	glyph.TextSize = Def.GLYPH_SIZE
	glyph.TextColor3 = Def.INK
	glyph.Parent = badge
	local text = env.newInstance("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamMedium
	text.TextSize = Def.TEXT_SIZE
	text.TextWrapped = true
	text.TextTruncate = Enum.TextTruncate.AtEnd
	text.TextYAlignment = Enum.TextYAlignment.Center
	text.Parent = button
	pcall(Create.connect, button, "Activated", function()
		self:tap(gui:GetAttribute("EntityId"))
	end)
	return gui
end

-- Paints a bubble GUI (pure apart from the instance): its size, colours, badge and words.
-- withText false shows a thought's glyph badge alone (Bubbles:layout's "badge").
function Def.paint(gui: any, bubble: any, withText: boolean)
	local style = Def.STYLE[bubble.kind]
	local glyphText = if type(bubble.glyph) == "string" and bubble.glyph ~= "" then bubble.glyph else nil
	local badgeOnly = glyphText ~= nil and not withText
	local button = gui:FindFirstChild("Bubble")
	local badge = button:FindFirstChild("Badge")
	local text = button:FindFirstChild("Text")
	local placard = Bubbles.PLACARD[bubble.kind] == true
	gui.Size = if placard then Def.SIZE.placard elseif badgeOnly then Def.SIZE.badge else Def.SIZE.card
	button.BackgroundColor3 = style.background
	button.BackgroundTransparency = if badgeOnly then 1 else 0
	button:FindFirstChild("Outline").Enabled = not badgeOnly
	badge.Visible = glyphText ~= nil
	badge.BackgroundColor3 = if glyphText then Def.BADGE[glyphText] or style.background else style.background
	badge.AnchorPoint = Vector2.new(0.5, 0.5) -- the pulse grows from the badge's centre
	if badgeOnly then
		badge.Position = UDim2.fromScale(0.5, 0.5)
		badge.Size = UDim2.fromScale(1, 1)
	else
		badge.Position = UDim2.new(0, 10 + Def.BADGE_SIZE / 2, 0.5, 0)
		badge.Size = UDim2.fromOffset(Def.BADGE_SIZE, Def.BADGE_SIZE)
	end
	badge:FindFirstChild("Glyph").Text = glyphText or ""
	local left = if glyphText then 10 + Def.BADGE_SIZE + 10 else 14
	text.Visible = not badgeOnly
	text.Text = bubble.text
	text.TextColor3 = style.text
	text.Position = UDim2.fromOffset(left, 0)
	text.Size = UDim2.new(1, -(left + 12), 1, 0)
	text.TextXAlignment = if placard then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
end

function Controller:_draw(entityId: number, bubble: any, withText: boolean, interactive: boolean)
	local model = self._models[entityId]
	if model == nil then
		return
	end
	local gui = self._drawn[entityId]
	if gui == nil then
		gui = table.remove(self._pool) or self:_build()
		self._drawn[entityId] = gui
	end
	gui.MaxDistance = 0 -- no engine limit: the model culls by distance to the camera focus
	Def.paint(gui, bubble, withText)
	gui:SetAttribute("BubbleKind", bubble.kind)
	gui:SetAttribute("EntityId", entityId)
	gui.Active = interactive
	gui.Adornee = model.PrimaryPart or model
	gui.Parent = self._playerGui or model
	self:_pulse(entityId, gui, bubble)
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
