local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local EngineStubs = require("./doubles/EngineStubs")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local SoundRegistry = require("@game/ReplicatedStorage/Forge/Experience/SoundRegistry")
local Sounds = require("@game/ReplicatedStorage/Forge/Experience/Sounds")
local MusicDirector = require("@game/ReplicatedStorage/Forge/Experience/MusicDirector")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local AudioDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/AudioController")
local KingdomSounds = require("../../../../games/game-001/config/Sounds")
local SandboxSounds = require("../../../../games/sandbox/config/Sounds")

EngineStubs.install()

local function entry(fields)
	local base = {
		id = "test.sound",
		category = "sfx",
		volume = 0.5,
		licence = "test licence",
		source = "test source",
		description = "test",
		status = "ready",
		asset = "rbxassetid://1",
	}
	for k, v in fields or {} do
		base[k] = v
	end
	if base.status == "needed" or base.noAsset then -- `asset = nil` in a table literal cannot clear the default
		base.asset = nil
	end
	base.noAsset = nil
	return base
end

local function hasProblem(problems, substring)
	for _, p in problems do
		if string.find(p, substring, 1, true) then
			return true
		end
	end
	return false
end

describe("Experience/SoundRegistry", function()
	it("accepts the factory list and both game lists", function()
		expect(SoundRegistry.validate(Sounds.FACTORY)).toEqual({})
		expect(SoundRegistry.validate(KingdomSounds)).toEqual({})
		expect(SoundRegistry.validate(SandboxSounds)).toEqual({})
	end)

	it("every music state has a registered track (AI Kingdoms)", function()
		local registry = SoundRegistry.build(Sounds.FACTORY, KingdomSounds)
		for _, id in MusicDirector.STATE_SOUNDS do
			expect(registry:get(id)).never.toBeNil()
		end
	end)

	it("rejects entries without licence, source, category or a valid volume", function()
		local problems = SoundRegistry.validate({
			entry({ id = "a.one", licence = "" }),
			entry({ id = "a.two", source = "   " }),
			entry({ id = "a.three", category = "noise" }),
			entry({ id = "a.four", volume = 0 }),
			entry({ id = "a.five", volume = 1.5 }),
		})
		expect(hasProblem(problems, "(a.one): licence note required")).toBe(true)
		expect(hasProblem(problems, "(a.two): source note required")).toBe(true)
		expect(hasProblem(problems, "(a.three): category must be one of")).toBe(true)
		expect(hasProblem(problems, "(a.four): volume must be a number in (0, 1]")).toBe(true)
		expect(hasProblem(problems, "(a.five): volume must be a number in (0, 1]")).toBe(true)
	end)

	it("ties status to the asset and requires loops for music and ambience", function()
		local problems = SoundRegistry.validate({
			entry({ id = "b.one", status = "ready", noAsset = true }),
			entry({ id = "b.two", status = "candidate", noAsset = true, description = "x" }),
			{
				id = "b.two2",
				category = "sfx",
				volume = 0.5,
				licence = "l",
				source = "s",
				description = "d",
				status = "needed",
				asset = "rbxassetid://5",
			},
			entry({ id = "b.three", asset = "http://evil" }),
			entry({ id = "b.four", category = "music" }),
			entry({ id = "B.bad" }),
			entry({ id = "b.dup" }),
			entry({ id = "b.dup" }),
		})
		expect(hasProblem(problems, "(b.one): status 'ready' needs an asset")).toBe(true)
		expect(hasProblem(problems, "(b.two): status 'candidate' needs an asset")).toBe(true)
		expect(hasProblem(problems, "(b.two2): has an asset, so status cannot be 'needed'")).toBe(true)
		expect(hasProblem(problems, "(b.three): asset must be")).toBe(true)
		expect(hasProblem(problems, "(b.four): music entries loop")).toBe(true)
		expect(hasProblem(problems, "(B.bad): id must look like")).toBe(true)
		expect(hasProblem(problems, "duplicate id in one list")).toBe(true)
	end)

	it("build() lets a game override a factory id and lists what is still needed", function()
		local registry = SoundRegistry.build(
			{ entry({ id = "ui.click", status = "needed", asset = nil }) },
			{ entry({ id = "ui.click", volume = 0.3 }) }
		)
		expect(registry:get("ui.click").volume).toBe(0.3)
		expect(#registry:needed()).toBe(0)
		expect(#Sounds.registry:needed()).toBe(#Sounds.registry:ids()) -- no assets chosen yet (honest state)
	end)
end)

describe("AudioController", function()
	local env, registry, audio, settings, sounds

	local function bootWith(list)
		env = MockEnv.new({
			isServer = false,
			localPlayer = { userId = 601 },
			services = { SoundService = nil, GuiService = { ReducedMotionEnabled = false } },
		})
		env.SoundService = env.mock.dataModel:GetService("SoundService")
		sounds = SoundRegistry.build(list)
		registry = Loader.load(env, {
			SettingsDef,
			{
				name = "AudioController",
				dependencies = { "SettingsController" },
				new = function(e, r)
					-- the real Sound backend; only the engine's read-only IsPlaying is answered by the stub
					local backend = AudioDef.liveBackend(e)
					backend.isPlaying = function(sound)
						return sound.Parent ~= nil and EngineStubs.state(sound).playing
					end
					return AudioDef.create(e, r, { registry = sounds, backend = backend })
				end,
			},
		})
		audio = registry:get("AudioController")
		settings = registry:get("SettingsController")
	end

	beforeEach(function()
		local list = {
			entry({ id = "t.click", category = "ui", cooldown = 0.1, maxInstances = 2 }),
			entry({ id = "t.boom", priority = 3, rollOff = { min = 5, max = 50 } }),
			entry({ id = "t.low", priority = 1, maxInstances = 9, cooldown = 0 }),
			entry({ id = "t.mid", priority = 2, maxInstances = 9, cooldown = 0 }),
			entry({ id = "t.missing", status = "needed", asset = nil }),
			entry({ id = "t.amb1", category = "ambience", loop = true }),
			entry({ id = "t.amb2", category = "ambience", loop = true }),
			entry({ id = "t.amb3", category = "ambience", loop = true }),
		}
		for state, id in MusicDirector.STATE_SOUNDS do
			table.insert(list, entry({ id = id, category = "music", loop = true, volume = 0.5, description = state }))
		end
		bootWith(list)
	end)

	it("plays a real Sound with the asset, volume and category SoundGroup", function()
		local voice = audio:play("t.click", { volume = 0.5 })
		expect(voice).never.toBeNil()
		local sound = voice.sound
		expect(sound.ClassName).toBe("Sound")
		expect(sound.SoundId).toBe("rbxassetid://1")
		expect(sound.Volume).toBeNear(0.25)
		expect(sound.SoundGroup.Name).toBe("ForgeAudio_ui")
		expect(sound.Parent).toBe(env.SoundService)
		expect(EngineStubs.state(sound).plays).toBe(1)
	end)

	it("parents positional sounds to an Attachment at the position with roll-off", function()
		local voice = audio:play("t.boom", { position = Vector3.new(10, 2, -4) })
		local attachment = voice.sound.Parent
		expect(attachment.ClassName).toBe("Attachment")
		expect(attachment.Position).toBe(Vector3.new(10, 2, -4))
		expect(voice.sound.RollOffMaxDistance).toBe(50)
		expect(voice.sound.RollOffMinDistance).toBe(5)
	end)

	it("skips sounds that have no asset yet, and unknown ids, without erroring", function()
		expect(audio:play("t.missing")).toBeNil()
		expect(audio:play("nope.nope")).toBeNil()
		expect(audio.stats.skipped.needed).toBe(1)
		expect(audio.stats.skipped.unknown).toBe(1)
	end)

	it("enforces cooldown and maxInstances per id", function()
		expect(audio:play("t.click")).never.toBeNil()
		expect(audio:play("t.click")).toBeNil()
		expect(audio.stats.skipped.cooldown).toBe(1)
		env.wait(0.2)
		expect(audio:play("t.click")).never.toBeNil()
		env.wait(0.2)
		expect(audio:play("t.click")).toBeNil()
		expect(audio.stats.skipped.instances).toBe(1)
	end)

	it("keeps at most 8 voices; a higher priority steals the oldest lower one, equal priority is skipped", function()
		for _ = 1, 8 do
			expect(audio:play("t.low")).never.toBeNil()
		end
		expect(audio:voices()).toBe(8)
		local first = audio._voices[1].sound
		expect(audio:play("t.mid")).never.toBeNil()
		expect(audio:voices()).toBe(8)
		expect(first.Parent).toBeNil() -- stolen and destroyed
		for _ = 1, 7 do
			audio:play("t.mid")
		end
		expect(audio:play("t.mid")).toBeNil()
		expect(audio.stats.skipped.budget).toBe(1)
		expect(audio:play("t.boom")).never.toBeNil()
	end)

	it("frees voices when sounds finish", function()
		for _ = 1, 8 do
			audio:play("t.low")
		end
		EngineStubs.finish(audio._voices[3].sound)
		expect(audio:voices()).toBe(7)
		expect(audio:play("t.low")).never.toBeNil()
	end)

	it("crossfades music on its own channel (not counted in the 8 voices)", function()
		audio:setMusic("calm")
		local calm = audio._music.sound
		expect(calm.Volume).toBe(0)
		env.wait(2)
		expect(calm.Volume).toBeNear(0.5)
		audio:setMusic("battle")
		local battle = audio._music.sound
		env.wait(0.75)
		expect(calm.Volume).toBeLessThan(0.5)
		expect(battle.Volume).toBeGreaterThan(0)
		env.wait(1)
		expect(calm.Parent).toBeNil()
		expect(battle.Volume).toBeNear(0.5)
		expect(audio:voices()).toBe(0)
		expect(audio:musicState()).toBe("battle")
	end)

	it("setMusic(nil) fades to silence; a state without an asset is counted, not thrown", function()
		audio:setMusic("calm")
		env.wait(2)
		local calm = audio._music.sound
		audio:setMusic(nil)
		env.wait(2)
		expect(calm.Parent).toBeNil()
		bootWith(Sounds.FACTORY)
		audio:setMusic("calm")
		expect(audio.stats.skipped.unknown).toBe(1)
	end)

	it("plays at most two ambience beds and stops beds no longer wanted", function()
		audio:setAmbience({ "t.amb1", "t.amb2", "t.amb3" })
		expect(audio:voices()).toBe(2)
		local amb1 = audio._ambience["t.amb1"].sound
		audio:setAmbience({ "t.amb2" })
		expect(audio:voices()).toBe(1)
		expect(amb1.Parent).toBeNil()
	end)

	it("applies master x category volume to each SoundGroup and follows setting changes", function()
		audio:play("t.click")
		local group = audio._backend.groups.ui
		expect(group.Volume).toBeNear(0.8)
		settings:set("masterVolume", 0.5)
		expect(group.Volume).toBeNear(0.4)
		expect(audio._backend.groups.music.Volume).toBeNear(0.3)
	end)
end)
