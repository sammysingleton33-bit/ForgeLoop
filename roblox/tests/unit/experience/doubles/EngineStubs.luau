--[[
	EngineStubs — fills in the engine-only members FORGE-04's live audio/VFX backends call, so specs
	run the real instance-building code on real Lune instances:
		Sound:Play(), Sound:Stop()   ParticleEmitter:Emit(count), :Clear()
	Sound.IsPlaying is in Lune's reflection database without a default, so implementProperty cannot
	answer it: specs replace the backend's isPlaying with EngineStubs.state(sound).playing instead.
	Imitates creator-docs reference/engine/classes/Sound.yaml and ParticleEmitter.yaml (behaviour only
	as far as these specs need: a Sound plays until stopped or EngineStubs.finish(sound)).
	Registered once per Lune process (harness/LuneInstances); per-instance state lives in a shared store.

		EngineStubs.install()
		EngineStubs.state(sound) -> { plays, stops, playing }
		EngineStubs.finish(sound)                  -- the sound reached its end (non-looped)
		EngineStubs.emitted(emitter) -> { number } -- counts passed to Emit, in order
]]

local roblox = require("@lune/roblox")

local LuneInstances = require("../../../harness/LuneInstances")

local EngineStubs = {}

local sounds = LuneInstances.store("ExperienceEngineStubs.sounds")
local emitters = LuneInstances.store("ExperienceEngineStubs.emitters")

local function soundState(sound)
	local state = sounds[sound]
	if state == nil then
		state = { plays = 0, stops = 0, playing = false }
		sounds[sound] = state
	end
	return state
end

local function register()
	roblox.implementMethod("Sound", "Play", function(sound)
		local state = soundState(sound)
		state.plays += 1
		state.playing = true
	end)
	roblox.implementMethod("Sound", "Stop", function(sound)
		local state = soundState(sound)
		state.stops += 1
		state.playing = false
	end)
	roblox.implementMethod("ParticleEmitter", "Emit", function(emitter, count)
		emitters[emitter] = emitters[emitter] or {}
		table.insert(emitters[emitter], count or 16)
	end)
	roblox.implementMethod("ParticleEmitter", "Clear", function(_emitter) end)
end

function EngineStubs.install()
	LuneInstances.once("ExperienceEngineStubs", register)
end

function EngineStubs.state(sound)
	return soundState(sound)
end

function EngineStubs.finish(sound)
	soundState(sound).playing = false
end

function EngineStubs.emitted(emitter)
	return emitters[emitter] or {}
end

return EngineStubs
