local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local MockRandom = require("../../mocks/MockRandom")
local EngineStubs = require("./doubles/EngineStubs")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local CitizenReactions = require("@game/ReplicatedStorage/Forge/Experience/CitizenReactions")
local CueDirector = require("@game/ReplicatedStorage/Forge/Experience/CueDirector")
local Cues = require("@game/ReplicatedStorage/Forge/Experience/Cues")
local KingdomSignals = require("@game/ReplicatedStorage/Forge/Experience/KingdomSignals")
local MusicDirector = require("@game/ReplicatedStorage/Forge/Experience/MusicDirector")
local Pacing = require("@game/ReplicatedStorage/Forge/Experience/Pacing")
local SoundRegistry = require("@game/ReplicatedStorage/Forge/Experience/SoundRegistry")
local Sounds = require("@game/ReplicatedStorage/Forge/Experience/Sounds")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local AudioDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/AudioController")
local VFXDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/VFXController")
local KingdomSounds = require("../../../../games/game-001/config/Sounds")

EngineStubs.install()

local KINGDOM_REGISTRY = SoundRegistry.build(Sounds.FACTORY, KingdomSounds)

local function kinds(actions)
	local out = {}
	for _, action in actions do
		table.insert(out, action.kind)
	end
	return out
end

local function find(actions, kind)
	for _, action in actions do
		if action.kind == kind then
			return action
		end
	end
	return nil
end

describe("Experience/Cues matrix", function()
	it("references only registered sounds, VFX presets and reactions, with a visual for every sound", function()
		local problems = CueDirector.validate(
			Cues.CUES,
			{ sounds = KINGDOM_REGISTRY, vfx = VfxPresets, reactions = CitizenReactions.REACTIONS }
		)
		expect(problems).toEqual({})
	end)

	it("covers every proposed kingdom signal except internal bookkeeping", function()
		for _, name in KingdomSignals.PROPOSED do
			expect(Cues.CUES[name]).never.toBeNil()
		end
	end)

	it("the validator catches a sound-only cue and unknown ids", function()
		local problems = CueDirector.validate({
			Bad = {
				{ relation = "mine", sound = "kingdom.alarm.bell" },
				{ relation = "self", vfx = "nope.preset", react = "dance", notify = { kind = "loud", title = "" } },
			},
		}, { sounds = KINGDOM_REGISTRY, vfx = VfxPresets, reactions = CitizenReactions.REACTIONS })
		local text = table.concat(problems, "\n")
		expect(text).toContain("Bad[1]: sound-only cue; add a visual (accessibility rule)")
		expect(text).toContain("Bad[2]: relation must be mine | against | others")
		expect(text).toContain("Bad[2]: unknown vfx preset 'nope.preset'")
		expect(text).toContain("Bad[2]: unknown citizen reaction 'dance'")
		expect(text).toContain("Bad[2]: notify.kind must be")
		expect(text).toContain("Bad[2]: notify.title required")
	end)
end)

describe("Experience/CueDirector", function()
	local now, settingValues, director

	beforeEach(function()
		now = 100
		settingValues = { notifications = "all", citizenBarks = true }
		director = CueDirector.new({
			now = function()
				return now
			end,
			kingdomId = function()
				return "k1"
			end,
			setting = function(key)
				return settingValues[key]
			end,
		})
	end)

	it("plays sound, vfx, toast and a citizen cheer for my finished building", function()
		local actions = director:handle(
			"BuildingCompleted",
			{ kingdomId = "k1", buildingType = "Farm", level = 1, position = Vector3.new(1, 0, 0) }
		)
		expect(kinds(actions)).toEqual({ "sound", "vfx", "react", "notify" })
		expect(find(actions, "sound").id).toBe("kingdom.build.complete")
		expect(find(actions, "sound").position).toBe(Vector3.new(1, 0, 0))
		expect(find(actions, "notify").notification.title).toBe("Farm complete")
		expect(find(actions, "react").kingdomId).toBe("k1")
	end)

	it("shows only a quiet effect for a rival's building, and nothing for unknown events", function()
		expect(kinds(director:handle("BuildingCompleted", { kingdomId = "k2", buildingType = "Farm" }))).toEqual({
			"vfx",
		})
		expect(#director:handle("SomethingElse", { kingdomId = "k1" })).toBe(0)
	end)

	it("warns the defender and switches the music to combat when attacked", function()
		local actions = director:handle("SiegeStarted", { kingdomId = "k2", defenderKingdomId = "k1" })
		expect(find(actions, "sound").id).toBe("kingdom.alarm.bell")
		expect(find(actions, "notify").notification.kind).toBe("warning")
		expect(find(actions, "react").reaction).toBe("panic")
		expect(find(actions, "music").input).toBe("combat")
	end)

	it("picks the variant from my side's outcome", function()
		local won =
			director:handle("BattleEnded", { kingdomId = "k2", defenderKingdomId = "k1", winnerKingdomId = "k1" })
		expect(find(won, "notify").notification.title).toBe("Attack repelled!")
		local lost = director:handle("SiegeEnded", { kingdomId = "k1", defenderKingdomId = "k3", outcome = "Repelled" })
		expect(find(lost, "notify").notification.title).toBe("The siege failed")
		local breach =
			director:handle("SiegeEnded", { kingdomId = "k1", defenderKingdomId = "k3", outcome = "Breached" })
		expect(find(breach, "sound").id).toBe("kingdom.siege.breach")
	end)

	it("reacts to morale only when it crosses a band", function()
		expect(#director:handle("MoraleChanged", { kingdomId = "k1", morale = 55, previous = 60 })).toBe(0)
		local unhappy = director:handle("MoraleChanged", { kingdomId = "k1", morale = 25, previous = 35 })
		expect(find(unhappy, "notify").notification.title).toBe("Your citizens are unhappy")
		local recovered = director:handle("MoraleChanged", { kingdomId = "k1", morale = 40, previous = 25 })
		expect(find(recovered, "notify").notification.title).toBe("Your citizens are calmer")
		local joyful = director:handle("MoraleChanged", { kingdomId = "k1", morale = 80, previous = 65 })
		expect(find(joyful, "react").reaction).toBe("cheer")
	end)

	it("resolves resource sounds and VFX per resource", function()
		local wood = director:handle("ResourceProduced", { kingdomId = "k1", resource = "Wood", amount = 4 })
		expect(find(wood, "sound").id).toBe("kingdom.wood.chop")
		expect(find(wood, "vfx").id).toBe("kingdom.harvest.wood")
		expect(find(wood, "float").text).toBe("+4 Wood")
	end)

	it("coalesces repeats: one sound per window, floats every time, one toast that counts up", function()
		local first = director:handle("BuildingCompleted", { kingdomId = "k1", buildingType = "House" })
		now += 1
		local second = director:handle("BuildingCompleted", { kingdomId = "k1", buildingType = "Farm" })
		expect(find(first, "sound")).never.toBeNil()
		expect(find(second, "sound")).toBeNil()
		expect(find(second, "react")).toBeNil()
		expect(find(second, "vfx")).never.toBeNil()
		expect(find(second, "notify").notification.key).toBe(find(first, "notify").notification.key)
		expect(find(second, "notify").notification.count).toBe(2)
		now += 3
		local later = director:handle("BuildingCompleted", { kingdomId = "k1", buildingType = "Farm" })
		expect(find(later, "sound")).never.toBeNil()
		expect(find(later, "notify").notification.count).toBe(1)
	end)

	it("coalesces per key: different resources do not merge", function()
		director:handle("ResourceProduced", { kingdomId = "k1", resource = "Food", amount = 1 })
		local wood = director:handle("ResourceProduced", { kingdomId = "k1", resource = "Wood", amount = 1 })
		expect(find(wood, "sound")).never.toBeNil()
	end)

	it("respects the notifications and citizen-bark settings", function()
		settingValues.notifications = "important"
		settingValues.citizenBarks = false
		local built = director:handle("BuildingCompleted", { kingdomId = "k1", buildingType = "Farm" })
		expect(find(built, "notify")).toBeNil()
		expect(find(built, "react")).toBeNil()
		local siege = director:handle("SiegeStarted", { kingdomId = "k2", defenderKingdomId = "k1" })
		expect(find(siege, "notify")).never.toBeNil() -- important ones still show
	end)

	it("formats templates from primitive info only and caps the length", function()
		expect(CueDirector.format("{buildingType} upgraded to level {level}", { buildingType = "Mill", level = 2 })).toBe(
			"Mill upgraded to level 2"
		)
		expect(CueDirector.format("{missing} complete", {})).toBe("complete")
		expect(#CueDirector.format("{x}", { x = string.rep("a", 200) })).toBe(60)
	end)
end)

describe("Experience/CitizenReactions", function()
	local function citizens()
		return {
			{ id = "a", kingdomId = "k1", position = Vector3.new(2, 0, 0) },
			{ id = "b", kingdomId = "k1", position = Vector3.new(10, 0, 0) },
			{ id = "c", kingdomId = "k1", position = Vector3.new(1000, 0, 0) },
			{ id = "d", kingdomId = "k2", position = Vector3.new(1, 0, 0) },
		}
	end

	it("picks the nearest citizens of the kingdom within the radius, up to the maximum", function()
		local memory = CitizenReactions.newMemory()
		local barks = CitizenReactions.pick("acknowledge", citizens(), Vector3.zero, "k1", MockRandom.new(1), 0, memory)
		expect(#barks).toBe(1)
		expect(barks[1].citizenId).toBe("a")
		expect(barks[1].emote).toBe("nod")
	end)

	it("gives each citizen a cooldown and never repeats a line twice in a row", function()
		local memory = CitizenReactions.newMemory()
		local rng = MockRandom.new(2)
		local first = CitizenReactions.pick("acknowledge", citizens(), Vector3.zero, "k1", rng, 0, memory)
		local second = CitizenReactions.pick("acknowledge", citizens(), Vector3.zero, "k1", rng, 1, memory)
		expect(second[1].citizenId).toBe("b")
		expect(second[1].line).never.toBe(first[1].line)
		local third = CitizenReactions.pick("acknowledge", citizens(), Vector3.zero, "k1", rng, 2, memory)
		expect(#third).toBe(0) -- a and b are cooling down; c is out of range
		local later = CitizenReactions.pick("acknowledge", citizens(), Vector3.zero, "k1", rng, 9, memory)
		expect(later[1].citizenId).toBe("a")
	end)

	it("returns nothing without a kingdom or for an unknown reaction", function()
		local memory = CitizenReactions.newMemory()
		expect(#CitizenReactions.pick("cheer", citizens(), nil, nil, MockRandom.new(1), 0, memory)).toBe(0)
		expect(#CitizenReactions.pick("dance", citizens(), nil, "k1", MockRandom.new(1), 0, memory)).toBe(0)
	end)
end)

describe("Experience/MusicDirector", function()
	it("follows the match phase, but only after the minimum dwell time", function()
		local music = MusicDirector.new({ minDwellSec = 20 })
		expect(music:update(0, { inMatch = true, phase = "Opening" })).toBe("calm")
		expect(music:update(5, { inMatch = true, phase = "Development" })).toBeNil()
		expect(music:update(21, { inMatch = true, phase = "Development" })).toBe("build")
	end)

	it("switches to battle at once on combat and holds it, ending soon after calm", function()
		local music = MusicDirector.new({ minDwellSec = 20, combatHoldSec = 25, calmTailSec = 8 })
		music:update(0, { inMatch = true, phase = "Competition" })
		music:combat(30)
		expect(music:update(30, { inMatch = true, phase = "Competition" })).toBe("battle")
		expect(music:update(50, { inMatch = true, phase = "Competition" })).toBeNil()
		music:calm(40) -- combat over: rings out for 8 s (sooner than the 25 s hold from t = 30)
		expect(music:update(47, { inMatch = true, phase = "Competition" })).toBeNil()
		expect(music:update(49, { inMatch = true, phase = "Competition" })).toBe("tension")
	end)

	it("victory and defeat override everything immediately", function()
		local music = MusicDirector.new()
		music:update(0, { inMatch = true, phase = "Conflict" })
		music:combat(1)
		expect(music:update(2, { inMatch = true, phase = "Conflict", result = "won" })).toBe("victory")
		local other = MusicDirector.new()
		other:update(0, { inMatch = true })
		expect(other:update(1, { inMatch = true, result = "lost" })).toBe("defeat")
		expect(other:update(2, { inMatch = false })).toBe("calm")
	end)
end)

describe("Experience/Pacing", function()
	it("advances on real signals, not only the clock", function()
		local pacing = Pacing.new(0, { kingdomId = "k1" })
		expect(pacing:phase()).toBe("Opening")
		pacing:observe("BuildingCompleted", { kingdomId = "k1" }, 30)
		pacing:observe("BuildingCompleted", { kingdomId = "k2" }, 40)
		pacing:observe("BuildingCompleted", { kingdomId = "k1" }, 50)
		expect(pacing:phase()).toBe("Opening")
		expect(pacing:observe("BuildingCompleted", { kingdomId = "k1" }, 60)).toBe("Development")
		expect(pacing:observe("UnitsRecruited", { kingdomId = "k3" }, 90)).toBe("Competition")
		expect(pacing:observe("SiegeStarted", { kingdomId = "k3", defenderKingdomId = "k1" }, 120)).toBe("Conflict")
		expect(pacing:observe("RoundStateChanged", { state = "Results" }, 600)).toBe("Resolution")
	end)

	it("escalates a quiet match by the minute fallbacks and never goes back", function()
		local pacing = Pacing.new(0, { kingdomId = "k1" })
		expect(pacing:tick(5 * 60)).toBeNil()
		expect(pacing:tick(6 * 60)).toBe("Development")
		expect(pacing:tick(16 * 60)).toBe("Competition")
		expect(pacing:tick(28 * 60)).toBe("Conflict")
		expect(pacing:tick(38 * 60)).toBe("Resolution")
		expect(pacing:observe("BuildingCompleted", { kingdomId = "k1" }, 39 * 60)).toBeNil()
		expect(pacing:phase()).toBe("Resolution")
	end)

	it("flags dead air once per idle spell, with a longer threshold later in the match", function()
		local pacing = Pacing.new(0, { kingdomId = "k1" })
		expect(pacing:nudgeDue(24)).toBe(false)
		expect(pacing:nudgeDue(25)).toBe(true)
		expect(pacing:nudgeDue(40)).toBe(false)
		pacing:observe("ConstructionStarted", { kingdomId = "k1" }, 50)
		expect(pacing:idleFor(60)).toBe(10)
		pacing:observe("KingdomUpgraded", { kingdomId = "k1" }, 60)
		expect(pacing:phase()).toBe("Development")
		expect(pacing:nudgeDue(100)).toBe(false)
		expect(pacing:nudgeDue(105)).toBe(true)
	end)
end)

describe("Kingdom feedback pipeline (VFXController.handleSignal)", function()
	local env, registry, vfx, audio, notifications

	beforeEach(function()
		env = MockEnv.new({ isServer = false, localPlayer = { userId = 801 }, services = { GuiService = {} } })
		env.SoundService = env.mock.dataModel:GetService("SoundService")
		local list = {}
		for _, id in KINGDOM_REGISTRY:ids() do
			local e = table.clone(KINGDOM_REGISTRY:get(id))
			e.status, e.asset = "candidate", "rbxassetid://99"
			table.insert(list, e)
		end
		local withAssets = SoundRegistry.build(list)
		notifications = { shown = {}, celebrated = {} }
		function notifications.show(_, n)
			table.insert(notifications.shown, n)
		end
		function notifications.celebrate(_, kind, payload)
			table.insert(notifications.celebrated, { kind = kind, payload = payload })
		end
		registry = Loader.load(env, {
			SettingsDef,
			{
				name = "AudioController",
				dependencies = { "SettingsController" },
				new = function(e, r)
					local backend = AudioDef.liveBackend(e)
					backend.isPlaying = function(sound)
						return sound.Parent ~= nil and EngineStubs.state(sound).playing
					end
					return AudioDef.create(e, r, { registry = withAssets, backend = backend })
				end,
			},
			{
				name = "VFXController",
				dependencies = { "SettingsController", "AudioController" },
				new = function(e, r)
					return VFXDef.create(e, r, {
						kingdomId = function()
							return "k1"
						end,
						focus = function()
							return Vector3.zero
						end,
					})
				end,
			},
			{
				name = "NotificationController",
				new = function()
					return notifications
				end,
			},
		})
		vfx = registry:get("VFXController")
		audio = registry:get("AudioController")
	end)

	it("a kingdom upgrade plays the fanfare, the effect, a toast and a celebration", function()
		vfx:handleSignal("KingdomUpgraded", { kingdomId = "k1", tier = 2, position = Vector3.new(0, 0, 5) })
		expect(#audio._voices).toBe(1) -- music plays on its own channel
		expect(audio._voices[1].id).toBe("kingdom.upgrade.fanfare")
		expect(vfx:activeEffects()).toBe(1)
		expect(notifications.shown[1].title).toBe("Your kingdom reached tier 2")
		expect(notifications.shown[1].kind).toBe("achievement")
		expect(notifications.celebrated[1].kind).toBe("kingdomTier")
	end)

	it("drives the music from the match: calm -> battle on attack -> victory", function()
		vfx:onRoundState("Active", "m1")
		env.mock:advance(2.5)
		expect(audio:musicState()).toBe("calm")
		vfx:handleSignal("BattleStarted", { kingdomId = "k2", defenderKingdomId = "k1" })
		expect(audio:musicState()).toBe("battle")
		vfx:onRoundResult({ participants = { { userId = 801 } }, winners = { 801 } })
		expect(audio:musicState()).toBe("victory")
	end)

	it("rivals' far-away cosmetic effects are not drawn", function()
		vfx:handleSignal(
			"BuildingCompleted",
			{ kingdomId = "k2", buildingType = "Farm", position = Vector3.new(900, 0, 0) }
		)
		expect(vfx:activeEffects()).toBe(0)
		vfx:handleSignal(
			"BuildingCompleted",
			{ kingdomId = "k2", buildingType = "Farm", position = Vector3.new(90, 0, 0) }
		)
		expect(vfx:activeEffects()).toBe(1)
	end)

	it("fires an idle nudge after dead air in a match", function()
		local nudges = {}
		vfx.idleNudge:connect(function(phase, idle)
			table.insert(nudges, { phase, idle })
		end)
		vfx:onRoundState("Active", "m2")
		env.mock:advance(26)
		expect(#nudges).toBe(1)
		expect(nudges[1][1]).toBe("Opening")
	end)
end)
