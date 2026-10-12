--!strict
--[[
	AudioController (FORGE-04, client) — plays registry sounds within the mobile voice budget.

		AudioController:play(soundId, opts?: { volume: number?, position: Vector3? }) -> Voice?   -- interfaces §8
		AudioController:stop(voice)          AudioController:stopAll()
		AudioController:setMusic(state)      -- Experience/MusicDirector state; 1.5 s crossfade; nil = silence
		AudioController:setAmbience({ id })  -- looping beds, at most BUDGET.ambience at once
		AudioController.stats = { played, skipped = { [reason]: number } }
	Skip reasons: unknown (id not in the registry), needed (no asset yet), cooldown, instances
	(maxInstances of that id playing), budget (all voices busy with equal or higher priority),
	unavailable (no SoundService to play in, e.g. a headless boot).

	Budget (FL-0024, roblox/studio-tests/experience.md): at most BUDGET.voices = 8 concurrent
	SFX/UI/voice/ambience sounds plus 1 music track. When full, the new sound steals the oldest
	voice of strictly lower priority; otherwise it is skipped. Ambience beds count as voices.
	Category volume = SettingsController:volume(category), applied to one SoundGroup per category.

	Backend: legacy Sound + SoundGroup objects (Def.liveBackend). creator-docs audio/objects.md
	(@af5f853): "Sound, SoundGroup, and SoundEffect objects are now discouraged in favor of ... audio
	objects", but Sound is not deprecated and the Creator Store inserts sounds as Sound instances
	(audio/assets.md). The backend sits behind a small interface (create/play/stop/isPlaying/
	setVolume/setGroupVolume) so an AudioPlayer/AudioEmitter backend can replace it without touching
	callers (follow-up). Positional sounds are parented to an Attachment at the position, so
	RollOffMin/MaxDistance apply ("Only applies to Sounds parented to a BasePart or Attachment").
]]

local MusicDirector = require("@game/ReplicatedStorage/Forge/Experience/MusicDirector")
local Sounds = require("@game/ReplicatedStorage/Forge/Experience/Sounds")

local AudioController = {}
AudioController.__index = AudioController

local Def = { name = "AudioController", dependencies = { "SettingsController" } }

Def.BUDGET = table.freeze({ voices = 8, music = 1, ambience = 2 })
local FADE_SEC = 1.5
local FADE_STEP = 0.1

export type Voice = { id: string, entry: any, sound: any, startedAt: number, priority: number, category: string }

-- ------------------------------------------------------------------ live backend (Roblox Sound objects)

function Def.liveBackend(env: any)
	local backend = { groups = {}, volumes = {} }
	local holder: any = nil

	-- SoundService is an Instance in Roblox; anything else (an unmocked service in a headless boot)
	-- means there is nowhere to play, and the controller skips sounds instead of erroring.
	function backend.available(): boolean
		return typeof(env.SoundService) == "Instance"
	end

	local function group(category: string): any
		local existing = backend.groups[category]
		if existing then
			return existing
		end
		local soundGroup = env.newInstance("SoundGroup")
		soundGroup.Name = `ForgeAudio_{category}`
		soundGroup.Volume = backend.volumes[category] or 1
		soundGroup.Parent = env.SoundService
		backend.groups[category] = soundGroup
		return soundGroup
	end

	local function anchor(): any
		if holder == nil or holder.Parent == nil then
			holder = env.newInstance("Part")
			holder.Name = "ForgeAudioAnchor"
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

	function backend.create(entry: any, volume: number, pitch: number, position: any): any
		local sound = env.newInstance("Sound")
		sound.Name = entry.id
		sound.SoundId = entry.asset
		sound.Volume = volume
		sound.PlaybackSpeed = pitch
		sound.Looped = entry.loop == true
		sound.SoundGroup = group(entry.category)
		if position ~= nil then
			local attachment = env.newInstance("Attachment")
			attachment.Name = entry.id
			attachment.Position = position -- the anchor sits at the origin, so this is the world position
			attachment.Parent = anchor()
			if entry.rollOff then
				sound.RollOffMinDistance = entry.rollOff.min
				sound.RollOffMaxDistance = entry.rollOff.max
			end
			sound.Parent = attachment
		else
			sound.Parent = env.SoundService
		end
		return sound
	end

	function backend.play(sound: any)
		sound:Play()
	end

	function backend.stop(sound: any)
		sound:Stop()
		local parent = sound.Parent
		sound:Destroy()
		if parent and parent:IsA("Attachment") then
			parent:Destroy()
		end
	end

	function backend.isPlaying(sound: any): boolean
		return sound.Parent ~= nil and sound.IsPlaying
	end

	function backend.setVolume(sound: any, volume: number)
		sound.Volume = volume
	end

	function backend.setGroupVolume(category: string, volume: number)
		backend.volumes[category] = volume -- applied when the group is created on the first sound
		local existing = backend.groups[category]
		if existing then
			existing.Volume = volume
		end
	end

	return backend
end

-- ------------------------------------------------------------------ controller

function Def.create(env: any, registry: any, options: { [string]: any }?)
	local opts = options or {}
	return setmetatable({
		_env = env,
		_settings = registry:get("SettingsController"),
		_registry = opts.registry or Sounds.registry,
		_backend = opts.backend or Def.liveBackend(env),
		_rng = opts.rng or env.random(),
		_voices = {} :: { Voice },
		_lastPlayed = {},
		_music = nil :: Voice?,
		_musicState = nil :: string?,
		_ambience = {},
		_connections = {},
		stats = { played = 0, skipped = {} },
	}, AudioController)
end

function Def.new(env: any, registry: any)
	return Def.create(env, registry, nil)
end

function AudioController:start()
	for _, category in { "music", "ambience", "sfx", "voice", "ui" } do
		self._backend.setGroupVolume(category, self._settings:volume(category))
	end
	table.insert(
		self._connections,
		self._settings.changed:connect(function()
			for _, category in { "music", "ambience", "sfx", "voice", "ui" } do
				self._backend.setGroupVolume(category, self._settings:volume(category))
			end
		end)
	)
end

function AudioController:destroy()
	for _, connection in self._connections do
		connection:disconnect()
	end
	self:stopAll()
end

function AudioController:_skip(reason: string): nil
	self.stats.skipped[reason] = (self.stats.skipped[reason] or 0) + 1
	return nil
end

function AudioController:_prune()
	local kept = {}
	for _, voice in self._voices do
		if self._backend.isPlaying(voice.sound) then
			table.insert(kept, voice)
		else
			self._backend.stop(voice.sound)
		end
	end
	self._voices = kept
end

function AudioController:_countOf(id: string): number
	local count = 0
	for _, voice in self._voices do
		if voice.id == id then
			count += 1
		end
	end
	return count
end

function AudioController:_victim(priority: number): number?
	local best: number? = nil
	for index, voice in self._voices do
		if voice.priority < priority then
			local current = if best then self._voices[best] else nil
			if
				current == nil
				or voice.priority < current.priority
				or (voice.priority == current.priority and voice.startedAt < current.startedAt)
			then
				best = index
			end
		end
	end
	return best
end

function AudioController:_start(entry: any, volume: number, position: any): any
	if self._backend.available and not self._backend.available() then
		return nil
	end
	local variance = entry.pitchVariance or 0
	local pitch = if variance > 0 then 1 + self._rng:NextNumber(-variance, variance) else 1
	local sound = self._backend.create(entry, volume, pitch, position)
	self._backend.play(sound)
	self.stats.played += 1
	return sound
end

function AudioController:play(soundId: string, opts: { volume: number?, position: any? }?): Voice?
	local entry = self._registry:get(soundId)
	if entry == nil then
		return self:_skip("unknown")
	end
	if entry.category == "music" then
		return self:_skip("useSetMusic")
	end
	if entry.asset == nil then
		return self:_skip("needed")
	end
	local now = self._env.clock()
	local last = self._lastPlayed[soundId]
	if last and now - last < (entry.cooldown or 0.05) then
		return self:_skip("cooldown")
	end
	self:_prune()
	if self:_countOf(soundId) >= (entry.maxInstances or 2) then
		return self:_skip("instances")
	end
	local priority = entry.priority or 2
	if #self._voices >= Def.BUDGET.voices then
		local victim = self:_victim(priority)
		if victim == nil then
			return self:_skip("budget")
		end
		local stolen = table.remove(self._voices, victim) :: Voice
		self._backend.stop(stolen.sound)
		self.stats.skipped.stolen = (self.stats.skipped.stolen or 0) + 1
	end
	local volume = entry.volume * math.clamp(if opts and opts.volume then opts.volume else 1, 0, 1)
	local sound = self:_start(entry, volume, if opts then opts.position else nil)
	if sound == nil then
		return self:_skip("unavailable")
	end
	local voice: Voice =
		{ id = soundId, entry = entry, sound = sound, startedAt = now, priority = priority, category = entry.category }
	table.insert(self._voices, voice)
	self._lastPlayed[soundId] = now
	return voice
end

function AudioController:stop(voice: Voice?)
	if voice == nil then
		return
	end
	local index = table.find(self._voices, voice)
	if index then
		table.remove(self._voices, index)
	end
	self._backend.stop(voice.sound)
end

function AudioController:stopAll()
	for _, voice in self._voices do
		self._backend.stop(voice.sound)
	end
	table.clear(self._voices)
	table.clear(self._ambience)
	if self._music then
		self._backend.stop(self._music.sound)
		self._music = nil
	end
	self._musicState = nil
end

function AudioController:voices(): number
	self:_prune()
	return #self._voices
end

-- Ramps a sound's volume in FADE_STEP steps on env.wait (virtual time in specs).
function AudioController:_fade(sound: any, from: number, to: number, thenStop: boolean)
	self._env.spawn(function()
		local steps = math.max(1, math.floor(FADE_SEC / FADE_STEP))
		for i = 1, steps do
			self._env.wait(FADE_STEP)
			if sound.Parent == nil then
				return
			end
			self._backend.setVolume(sound, from + (to - from) * i / steps)
		end
		if thenStop then
			self._backend.stop(sound)
		end
	end)
end

function AudioController:setMusic(state: string?)
	if state == self._musicState then
		return
	end
	self._musicState = state
	local previous = self._music
	self._music = nil
	if previous then
		self:_fade(previous.sound, previous.entry.volume, 0, true)
	end
	local id = if state then MusicDirector.STATE_SOUNDS[state] else nil
	local entry = if id then self._registry:get(id) else nil
	if entry == nil or entry.asset == nil then
		if state ~= nil then
			self:_skip(if entry == nil then "unknown" else "needed")
		end
		return
	end
	local sound = self:_start(entry, 0, nil)
	if sound == nil then
		self:_skip("unavailable")
		return
	end
	self._music = {
		id = entry.id,
		entry = entry,
		sound = sound,
		startedAt = self._env.clock(),
		priority = 3,
		category = "music",
	}
	self:_fade(sound, 0, entry.volume, false)
end

function AudioController:musicState(): string?
	return self._musicState
end

function AudioController:setAmbience(ids: { string })
	local wanted = {}
	for i, id in ids do
		if i <= Def.BUDGET.ambience then
			wanted[id] = true
		end
	end
	for id, voice in self._ambience do
		if not wanted[id] then
			self:stop(voice)
			self._ambience[id] = nil
		end
	end
	for id in wanted do
		if self._ambience[id] == nil then
			local voice = self:play(id)
			if voice then
				self._ambience[id] = voice
			end
		end
	end
end

return Def
