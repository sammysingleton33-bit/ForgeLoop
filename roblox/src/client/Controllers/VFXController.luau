--!strict
--[[
	VFXController (FORGE-04, client) — particle presets, floating numbers, citizen reactions, and the
	kingdom feedback pipeline that turns gameplay signals into sound + visuals + toasts + music.

	Effects
		VFXController:play(presetId, opts?: { position: Vector3?, parent: Instance?, tint: Color3? }) -> Effect?
		VFXController:stop(effect)                         -- continuous presets; bursts clean up themselves
		VFXController:float(text, position?) -> Instance?  -- rising text ("+3 Food"), FLOAT_SEC, max FLOATS
		VFXController:react(reaction, position?, kingdomId) -> { Bark }   -- citizen speech bubbles
		VFXController.shakeRequested: Signal (magnitude, duration) -- FORGE-01's CameraController applies it
		VFXController.idleNudge: Signal (phase, idleSec)            -- OnboardingController shows a hint
		VFXController.stats = { played, skipped = { [reason]: number } }
	Budget (Experience/VfxPresets.BUDGET): live particles on screen <= particlesOnScreen and at most
	activePresets effects; a new effect that does not fit evicts strictly lower-priority continuous
	effects, otherwise it is skipped. Reduced motion (SettingsController:reducedMotion) applies each
	preset's rule: "skip", "reduce" (half the particles, no shake) or "keep".

	Feedback pipeline (start): signals arrive on the proposed FORGE-01 remotes Gameplay.KingdomEvent
	(eventName, info) and Gameplay.SiegeImpact (info), plus the contract's Gameplay.RoundState and
	Gameplay.RoundResult. Each signal goes through Experience/CueDirector; actions are dispatched to
	AudioController (sound), this controller (vfx, float, react), NotificationController (notify,
	celebrate; optional until FL-0027) and Experience/MusicDirector (music). The local kingdom is
	Players.LocalPlayer:GetAttribute("KingdomId") (proposed to FORGE-01). Call handleSignal(eventName,
	info) directly to drive it (specs, sandbox tools).
]]

local CitizenReactions = require("@game/ReplicatedStorage/Forge/Experience/CitizenReactions")
local CueDirector = require("@game/ReplicatedStorage/Forge/Experience/CueDirector")
local MusicDirector = require("@game/ReplicatedStorage/Forge/Experience/MusicDirector")
local Pacing = require("@game/ReplicatedStorage/Forge/Experience/Pacing")
local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")

local VFXController = {}
VFXController.__index = VFXController

local Def = { name = "VFXController", dependencies = { "SettingsController", "AudioController" } }

Def.FLOAT_SEC = 1.2
Def.FLOATS = 12
Def.OTHER_RANGE = 250 -- studs: rivals' cosmetic effects farther than this from the camera are not drawn
Def.CITIZEN_TAG = "Citizen"

export type Effect = { id: string, preset: any, live: number, priority: number, continuous: boolean, parts: { any } }

local function numberRange(range: { number }): any
	return NumberRange.new(range[1], range[2])
end

local function colorSequence(colors: { any }, tint: any?): any
	local first = tint or colors[1]
	local last = if tint then tint else (colors[2] or colors[1])
	return ColorSequence.new(first, last)
end

-- ------------------------------------------------------------------ live backend (ParticleEmitter objects)

function Def.liveBackend(env: any)
	local backend = {}
	local holder: any = nil

	local function anchor(): any
		if holder == nil or holder.Parent == nil then
			holder = env.newInstance("Part")
			holder.Name = "ForgeVFXAnchor"
			holder.Anchored = true
			holder.CanCollide = false
			holder.CanQuery = false
			holder.CanTouch = false
			holder.Transparency = 1
			holder.Size = Vector3.new(1, 1, 1)
			holder.CFrame = CFrame.new()
			holder.Parent = env.Workspace
		end
		return holder
	end
	backend.anchor = anchor

	-- Returns the attachment (or given parent) and the emitters built from the preset.
	function backend.build(preset: any, scale: number, opts: { [string]: any }): (any, { any })
		local parent = opts.parent
		local owned = nil
		if parent == nil then
			owned = env.newInstance("Attachment")
			owned.Name = preset.id
			owned.Position = opts.position or Vector3.zero
			owned.Parent = anchor()
			parent = owned
		end
		local emitters = {}
		for index, spec in preset.emitters do
			local emitter = env.newInstance("ParticleEmitter")
			emitter.Name = `{preset.id}#{index}`
			emitter.Texture = spec.texture
			emitter.Color = colorSequence(spec.colors, if preset.tint then opts.tint else nil)
			emitter.Lifetime = numberRange(spec.lifetime)
			emitter.Speed = numberRange(spec.speed)
			emitter.Size = NumberSequence.new(spec.size[1], spec.size[2])
			emitter.Transparency = NumberSequence.new(spec.transparency[1], spec.transparency[2])
			emitter.SpreadAngle = Vector2.new(spec.spread, spec.spread)
			emitter.LightEmission = spec.lightEmission
			emitter.Drag = spec.drag or 0
			emitter.Acceleration = spec.acceleration or Vector3.zero
			emitter.Rate = if spec.rate then spec.rate * scale else 0
			emitter.Enabled = spec.rate ~= nil
			emitter.Parent = parent
			table.insert(emitters, emitter)
		end
		return owned, emitters
	end

	function backend.emit(emitter: any, count: number)
		emitter:Emit(count)
	end

	function backend.stopEmitting(emitter: any)
		emitter.Enabled = false
	end

	function backend.destroy(instance: any)
		if instance then
			instance:Destroy()
		end
	end

	return backend
end

-- ------------------------------------------------------------------ controller

function Def.create(env: any, registry: any, options: { [string]: any }?)
	local opts = options or {}
	return setmetatable({
		_env = env,
		_registry = registry,
		_settings = registry:get("SettingsController"),
		_audio = registry:get("AudioController"),
		_backend = opts.backend or Def.liveBackend(env),
		_rng = opts.rng or env.random(),
		_focus = opts.focus,
		_kingdomId = opts.kingdomId,
		_effects = {} :: { Effect },
		_floats = {},
		_memory = CitizenReactions.newMemory(),
		_links = {},
		_running = false,
		_match = { inMatch = false, roundId = nil, result = nil },
		music = MusicDirector.new(),
		pacing = nil :: any,
		shakeRequested = Signal.new(),
		idleNudge = Signal.new(),
		stats = { played = 0, skipped = {} },
	}, VFXController)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function VFXController:_skip(reason: string): nil
	self.stats.skipped[reason] = (self.stats.skipped[reason] or 0) + 1
	return nil
end

function VFXController:_localKingdom(): string?
	if self._kingdomId then
		return self._kingdomId()
	end
	local player = self._env.Players and self._env.Players.LocalPlayer
	local id = if player then player:GetAttribute("KingdomId") else nil
	return if type(id) == "string" then id else nil
end

function VFXController:_focusPosition(): any
	if self._focus then
		return self._focus()
	end
	local camera = self._env.Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

-- ------------------------------------------------------------------ effects

function VFXController:liveParticles(): number
	local total = 0
	for _, effect in self._effects do
		total += effect.live
	end
	return total
end

function VFXController:_makeRoom(live: number, priority: number): boolean
	local B = VfxPresets.BUDGET
	while #self._effects >= B.activePresets or self:liveParticles() + live > B.particlesOnScreen do
		local victim: number? = nil
		for index, effect in self._effects do
			if effect.continuous and effect.priority < priority then
				if victim == nil or effect.priority < self._effects[victim].priority then
					victim = index
				end
			end
		end
		if victim == nil then
			return false
		end
		self:stop(self._effects[victim])
	end
	return true
end

function VFXController:play(presetId: string, opts: { [string]: any }?): Effect?
	local preset = VfxPresets.get(presetId)
	if preset == nil then
		return self:_skip("unknown")
	end
	local options = opts or {}
	local reduced = self._settings:reducedMotion()
	if reduced and preset.reducedMotion == "skip" then
		return self:_skip("reducedMotion")
	end
	local scale = if reduced and preset.reducedMotion == "reduce" then 0.5 else 1
	local live = VfxPresets.liveParticles(preset) * scale
	if not self:_makeRoom(live, preset.priority) then
		return self:_skip("budget")
	end
	local holder, emitters = self._backend.build(preset, scale, options)
	local continuous = false
	for index, spec in preset.emitters do
		if spec.burst then
			self._backend.emit(emitters[index], math.max(1, math.floor(spec.burst * scale)))
		else
			continuous = true
		end
	end
	local effect: Effect = {
		id = presetId,
		preset = preset,
		live = live,
		priority = preset.priority,
		continuous = continuous and preset.durationSec == nil,
		parts = { holder, emitters },
	}
	table.insert(self._effects, effect)
	self.stats.played += 1
	if preset.shake and not reduced and self._settings:get("cameraShake") ~= false then
		self.shakeRequested:fire(preset.shake.magnitude, preset.shake.duration)
	end
	local lifetime = 0
	for _, spec in preset.emitters do
		lifetime = math.max(lifetime, spec.lifetime[2])
	end
	if not continuous then
		self:_cleanupAfter(effect, lifetime)
	elseif preset.durationSec then
		self._env.spawn(function()
			self._env.wait(preset.durationSec)
			self:stop(effect)
		end)
	end
	return effect
end

function VFXController:_remove(effect: Effect): boolean
	local index = table.find(self._effects, effect)
	if index == nil then
		return false
	end
	table.remove(self._effects, index)
	return true
end

function VFXController:_cleanupAfter(effect: Effect, seconds: number)
	self._env.spawn(function()
		self._env.wait(seconds)
		if self:_remove(effect) then
			self:_destroyParts(effect)
		end
	end)
end

function VFXController:_destroyParts(effect: Effect)
	local holder, emitters = effect.parts[1], effect.parts[2]
	if holder then
		self._backend.destroy(holder)
	else
		for _, emitter in emitters do
			self._backend.destroy(emitter)
		end
	end
end

function VFXController:stop(effect: Effect?)
	if effect == nil or not self:_remove(effect) then
		return
	end
	local emitters = effect.parts[2]
	local lifetime = 0
	for index, spec in effect.preset.emitters do
		self._backend.stopEmitting(emitters[index])
		lifetime = math.max(lifetime, spec.lifetime[2])
	end
	-- particles already in the air finish their lifetime, then the instances go
	self._env.spawn(function()
		self._env.wait(lifetime)
		self:_destroyParts(effect)
	end)
end

function VFXController:activeEffects(): number
	return #self._effects
end

-- ------------------------------------------------------------------ floating text and barks

local function billboard(env: any, text: string, color: any, size: any): (any, any)
	local gui = env.newInstance("BillboardGui")
	gui.Size = size
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	local label = env.newInstance("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return gui, label
end

function VFXController:float(text: string, position: any?): any
	if text == "" or position == nil then
		return self:_skip("float")
	end
	if #self._floats >= Def.FLOATS then
		local oldest = table.remove(self._floats, 1)
		self._backend.destroy(oldest)
	end
	local attachment = self._env.newInstance("Attachment")
	attachment.Name = "ForgeFloat"
	attachment.Position = position
	attachment.Parent = self._backend.anchor()
	local gui, label = billboard(self._env, text, Color3.fromRGB(255, 236, 170), UDim2.fromOffset(160, 36))
	gui.Adornee = attachment
	gui.Parent = attachment
	table.insert(self._floats, attachment)
	local reduced = self._settings:reducedMotion()
	self._env.spawn(function()
		local started = self._env.clock()
		local t = 0
		while t < 1 and attachment.Parent ~= nil do
			self._env.wait(0) -- one frame
			t = math.min(1, (self._env.clock() - started) / Def.FLOAT_SEC)
			if not reduced then
				gui.StudsOffset = Vector3.new(0, 1 + 2 * t, 0)
			end
			label.TextTransparency = math.max(0, (t - 0.6) / 0.4)
			label.TextStrokeTransparency = 0.4 + 0.6 * label.TextTransparency
		end
		local index = table.find(self._floats, attachment)
		if index then
			table.remove(self._floats, index)
		end
		self._backend.destroy(attachment)
	end)
	return attachment
end

local function positionOf(instance: any): any
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") and instance.PrimaryPart then
		return instance.PrimaryPart.Position
	end
	return nil
end

function VFXController:_citizens(): ({ any }, { [string]: any })
	local list, byId = {}, {}
	local ok, tagged = pcall(function()
		return self._env.CollectionService:GetTagged(Def.CITIZEN_TAG)
	end)
	if not ok then
		return list, byId
	end
	for _, instance in tagged do
		local id, kingdom = instance:GetAttribute("CitizenId"), instance:GetAttribute("KingdomId")
		local position = positionOf(instance)
		if type(id) == "string" and type(kingdom) == "string" and position then
			table.insert(list, { id = id, kingdomId = kingdom, position = position })
			byId[id] = instance
		end
	end
	return list, byId
end

function VFXController:react(reaction: string, position: any?, kingdomId: string?): { any }
	if self._settings:get("citizenBarks") == false then
		return {}
	end
	local citizens, byId = self:_citizens()
	local barks =
		CitizenReactions.pick(reaction, citizens, position, kingdomId, self._rng, self._env.clock(), self._memory)
	for _, bark in barks do
		local instance = byId[bark.citizenId]
		local adornee = if instance:IsA("Model") then instance.PrimaryPart else instance
		local gui = billboard(self._env, bark.line, Color3.fromRGB(255, 255, 255), UDim2.fromOffset(180, 40))
		gui.Name = "ForgeBark"
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.Adornee = adornee
		gui.Parent = adornee
		instance:SetAttribute("ForgeEmote", bark.emote) -- FORGE-01's citizen animator may play it
		self._env.spawn(function()
			self._env.wait(bark.durationSec)
			self._backend.destroy(gui)
			if instance:GetAttribute("ForgeEmote") == bark.emote then
				instance:SetAttribute("ForgeEmote", nil)
			end
		end)
	end
	return barks
end

-- ------------------------------------------------------------------ feedback pipeline

function VFXController:_director(): any
	if self._cues == nil then
		self._cues = CueDirector.new({
			now = self._env.clock,
			kingdomId = function()
				return self:_localKingdom()
			end,
			setting = function(key)
				return self._settings:get(key)
			end,
		})
	end
	return self._cues
end

function VFXController:_notify(method: string, ...)
	local notifications = self._registry:find("NotificationController")
	if notifications == nil then
		self._env.log("info", `feedback: {method} skipped (NotificationController not loaded)`, {})
		return
	end
	notifications[method](notifications, ...)
end

function VFXController:_inRange(position: any, mine: boolean): boolean
	if mine or position == nil then
		return true
	end
	local focus = self:_focusPosition()
	return focus == nil or (position - focus).Magnitude <= Def.OTHER_RANGE
end

function VFXController:dispatch(actions: { any }, mine: boolean)
	local now = self._env.clock()
	for _, action in actions do
		if action.kind == "sound" then
			self._audio:play(action.id, { position = action.position })
		elseif action.kind == "vfx" then
			if self:_inRange(action.position, mine) then
				self:play(action.id, { position = action.position, tint = action.tint })
			end
		elseif action.kind == "float" then
			self:float(action.text, action.position)
		elseif action.kind == "react" then
			self:react(action.reaction, action.position, action.kingdomId)
		elseif action.kind == "notify" then
			self:_notify("show", action.notification)
		elseif action.kind == "celebrate" then
			self:_notify("celebrate", action.celebration, action.payload)
		elseif action.kind == "music" then
			if action.input == "combat" then
				self.music:combat(now)
			else
				self.music:calm(now)
			end
			self:_updateMusic()
		end
	end
end

function VFXController:handleSignal(eventName: string, info: { [string]: any }?): { any }
	local data = info or {}
	if self.pacing then
		self.pacing:setKingdom(self:_localKingdom())
		self.pacing:observe(eventName, data, self._env.clock())
	end
	local actions = self:_director():handle(eventName, data)
	local mine = self:_localKingdom() ~= nil and data.kingdomId == self:_localKingdom()
	self:dispatch(actions, mine)
	return actions
end

function VFXController:_updateMusic()
	local phase = if self.pacing then self.pacing:phase() else nil
	local state = self.music:update(
		self._env.clock(),
		{ phase = phase, inMatch = self._match.inMatch, result = self._match.result }
	)
	if state then
		self._audio:setMusic(state)
	end
end

function VFXController:onRoundState(state: string, roundId: string?)
	local now = self._env.clock()
	if state == "Active" then
		if roundId ~= self._match.roundId or not self._match.inMatch then
			self._match = { inMatch = true, roundId = roundId, result = nil }
			self.pacing = Pacing.new(now, { kingdomId = self:_localKingdom() })
		end
	elseif state == "Results" then
		if self.pacing then
			self.pacing:observe("RoundStateChanged", { state = "Results" }, now)
		end
	else
		self._match = { inMatch = false, roundId = nil, result = nil }
		self.pacing = nil
	end
	self:_updateMusic()
end

function VFXController:onRoundResult(result: any)
	local player = self._env.Players and self._env.Players.LocalPlayer
	if type(result) ~= "table" or player == nil then
		return
	end
	local participant = false
	for _, entry in result.participants or {} do
		if entry.userId == player.UserId then
			participant = true
		end
	end
	if not participant then
		return
	end
	local won = table.find(result.winners or {}, player.UserId) ~= nil
	self._match.result = if won then "won" else "lost"
	if won then
		self:play("kingdom.victory", { position = self:_focusPosition() })
	end
	self:_updateMusic()
end

function VFXController:start()
	local env = self._env
	self._running = true
	table.insert(
		self._links,
		RemoteLink.on(env, "Gameplay.KingdomEvent", function(eventName, info)
			if type(eventName) == "string" then
				self:handleSignal(eventName, if type(info) == "table" then info else {})
			end
		end)
	)
	table.insert(
		self._links,
		RemoteLink.on(env, "Gameplay.SiegeImpact", function(info)
			self:handleSignal("SiegeImpact", if type(info) == "table" then info else {})
		end)
	)
	table.insert(
		self._links,
		RemoteLink.on(env, "Gameplay.RoundState", function(state, roundId)
			self:onRoundState(state, roundId)
		end)
	)
	table.insert(
		self._links,
		RemoteLink.on(env, "Gameplay.RoundResult", function(result)
			self:onRoundResult(result)
		end)
	)
	self:_updateMusic()
	env.spawn(function()
		while self._running do
			env.wait(1)
			if not self._running then
				break
			end
			local now = env.clock()
			if self.pacing then
				self.pacing:tick(now)
				if self.pacing:nudgeDue(now) then
					self.idleNudge:fire(self.pacing:phase(), self.pacing:idleFor(now))
				end
			end
			self:_updateMusic()
		end
	end)
end

function VFXController:destroy()
	self._running = false
	for _, link in self._links do
		link:disconnect()
	end
	for _, effect in table.clone(self._effects) do
		self:_remove(effect)
		self:_destroyParts(effect)
	end
	self.shakeRequested:disconnectAll()
	self.idleNudge:disconnectAll()
end

return Def
