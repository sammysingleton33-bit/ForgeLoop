--!strict
--[[
	VFXController (FORGE-04, client) — particle presets, floating text and speech bubbles within the
	mobile budget. Generic: games add their own presets and decide when to play them (game-001: the
	FeedbackController in games/game-001/src/client/Controllers, FL-0062).

		VFXController:play(presetId, opts?: { position: Vector3?, parent: Instance?, tint: Color3? }) -> Effect?
		VFXController:stop(effect)                         -- continuous presets; bursts clean up themselves
		VFXController:register(presets) -> { string }      -- add game presets (validated; problems returned)
		VFXController:float(text, position?) -> Instance?  -- rising text ("+3 Wood"), FLOAT_SEC, max FLOATS
		VFXController:bubble(adornee, text, seconds) -> Instance?  -- a speech bubble over a part or model
		VFXController.shakeRequested: Signal (magnitude, duration) -- the game's camera controller applies it
		VFXController.stats = { played, skipped = { [reason]: number } }
	Budget (Experience/VfxPresets.BUDGET): live particles on screen <= particlesOnScreen and at most
	activePresets effects; a new effect that does not fit evicts strictly lower-priority continuous
	effects, otherwise it is skipped. Reduced motion (SettingsController:reducedMotion) applies each
	preset's rule: "skip", "reduce" (half the particles, no shake) or "keep". Floats do not rise with
	reduced motion; they only fade.
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")

local VFXController = {}
VFXController.__index = VFXController

local Def = { name = "VFXController", dependencies = { "SettingsController" } }

Def.FLOAT_SEC = 1.2
Def.FLOATS = 12
Def.BUBBLES = 8

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
		_backend = opts.backend or Def.liveBackend(env),
		_effects = {} :: { Effect },
		_floats = {},
		_bubbles = {},
		shakeRequested = Signal.new(),
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

function VFXController:bubble(adornee: any, text: string, seconds: number): any
	if adornee == nil or text == "" then
		return self:_skip("bubble")
	end
	if #self._bubbles >= Def.BUBBLES then
		local oldest = table.remove(self._bubbles, 1)
		self._backend.destroy(oldest)
	end
	local gui = billboard(self._env, text, Color3.fromRGB(255, 255, 255), UDim2.fromOffset(180, 40))
	gui.Name = "ForgeBubble"
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.Adornee = adornee
	gui.Parent = adornee
	table.insert(self._bubbles, gui)
	self._env.spawn(function()
		self._env.wait(seconds)
		local index = table.find(self._bubbles, gui)
		if index then
			table.remove(self._bubbles, index)
		end
		self._backend.destroy(gui)
	end)
	return gui
end

function VFXController:register(presets: { any }): { string }
	return VfxPresets.register(presets)
end

function VFXController:destroy()
	for _, effect in table.clone(self._effects) do
		self:_remove(effect)
		self:_destroyParts(effect)
	end
	self.shakeRequested:disconnectAll()
end

return Def
