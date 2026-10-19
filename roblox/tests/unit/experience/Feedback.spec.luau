local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local CueDirector = require("@game/ReplicatedStorage/Forge/Experience/CueDirector")
local MusicDirector = require("@game/ReplicatedStorage/Forge/Experience/MusicDirector")
local SoundRegistry = require("@game/ReplicatedStorage/Forge/Experience/SoundRegistry")
local VfxPresets = require("@game/ReplicatedStorage/Forge/Experience/VfxPresets")

local function entry(id)
	return { id = id, category = "sfx", volume = 0.5, licence = "l", source = "s", description = "d", status = "needed" }
end
local SOUNDS = SoundRegistry.build({ entry("t.build"), entry("t.alarm"), entry("t.chop"), entry("t.mine") })

-- A small game-style matrix: who acted decides the variant; "@resource" picks the sound per resource.
local CUES = {
	Built = {
		{
			when = { relation = "mine" },
			sound = "t.build",
			vfx = "reward.burst",
			notify = { kind = "info", title = "{buildingType} complete" },
			react = "cheer",
			coalesce = { key = "built", windowSec = 2 },
		},
		{ when = { relation = "others" }, vfx = "reward.burst" },
	},
	Raid = {
		{
			when = { relation = "against" },
			sound = "t.alarm",
			notify = { kind = "warning", title = "Under attack!", important = true },
			music = "combat",
		},
	},
	Gathered = {
		{
			when = { relation = "mine" },
			sound = "@resource",
			vfx = "hit.generic",
			float = "+{amount} {resource}",
			coalesce = { key = "{resource}", windowSec = 1.5 },
		},
	},
	Ended = {
		{
			when = { relation = "mine", outcome = "won" },
			notify = { kind = "reward", title = "Won" },
			celebrate = "victory",
		},
		{ when = { relation = "mine", outcome = "lost" }, notify = { kind = "warning", title = "Lost" } },
	},
}

local function classify(_signal, info)
	local relation = if info.kingdom == "me" then "mine" elseif info.target == "me" then "against" else "others"
	return { relation = relation, outcome = info.outcome }
end

local IDS = {
	resource = function(info)
		return ({ wood = "t.chop", stone = "t.mine" })[info.resource]
	end,
}

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

describe("Experience/CueDirector", function()
	local now, settingValues, director

	beforeEach(function()
		now = 100
		settingValues = { notifications = "all", citizenBarks = true }
		director = CueDirector.new({
			cues = CUES,
			classify = classify,
			ids = IDS,
			now = function()
				return now
			end,
			setting = function(key)
				return settingValues[key]
			end,
		})
	end)

	it("validates a matrix against the sound registry and VFX presets", function()
		local problems = CueDirector.validate(CUES, {
			sounds = SOUNDS,
			vfx = VfxPresets,
			reactions = { cheer = true },
			expand = function(name)
				return if name == "resource" then { "t.chop", "t.mine" } else nil
			end,
		})
		expect(problems).toEqual({})
	end)

	it("the validator catches a sound-only cue, unknown ids, bad tags and notify kinds", function()
		local problems = CueDirector.validate({
			Bad = {
				{ sound = "t.alarm" },
				{ when = "mine", vfx = "nope.preset", react = "dance", notify = { kind = "loud", title = "" } },
				{ sound = "nope.sound", vfx = "reward.burst", music = 5 },
			},
		}, { sounds = SOUNDS, vfx = VfxPresets, reactions = { cheer = true } })
		local text = table.concat(problems, "\n")
		expect(text).toContain("Bad[1]: sound-only cue; add a visual (accessibility rule)")
		expect(text).toContain("Bad[2]: when must be a table of tags")
		expect(text).toContain("Bad[2]: unknown vfx preset 'nope.preset'")
		expect(text).toContain("Bad[2]: unknown reaction 'dance'")
		expect(text).toContain("Bad[2]: notify.kind must be")
		expect(text).toContain("Bad[2]: notify.title required")
		expect(text).toContain("Bad[3]: unknown sound 'nope.sound'")
		expect(text).toContain("Bad[3]: music must be an input name")
	end)

	it("picks the variant from the game's classification", function()
		local mine =
			director:handle("Built", { kingdom = "me", buildingType = "Farm", position = Vector3.new(1, 0, 0) })
		expect(kinds(mine)).toEqual({ "sound", "vfx", "react", "notify" })
		expect(find(mine, "sound").position).toBe(Vector3.new(1, 0, 0))
		expect(find(mine, "notify").notification.title).toBe("Farm complete")
		expect(kinds(director:handle("Built", { kingdom = "rival" }))).toEqual({ "vfx" })
		expect(#director:handle("Raid", { kingdom = "rival", target = "someone" })).toBe(0)
		expect(#director:handle("Unknown", { kingdom = "me" })).toBe(0)
	end)

	it("matches every tag in `when` (outcome variants)", function()
		local won = director:handle("Ended", { kingdom = "me", outcome = "won" })
		expect(find(won, "notify").notification.title).toBe("Won")
		expect(find(won, "celebrate").celebration).toBe("victory")
		local lost = director:handle("Ended", { kingdom = "me", outcome = "lost" })
		expect(find(lost, "notify").notification.title).toBe("Lost")
	end)

	it("resolves @placeholders per signal and drops the action when nothing matches", function()
		local wood = director:handle("Gathered", { kingdom = "me", resource = "wood", amount = 4 })
		expect(find(wood, "sound").id).toBe("t.chop")
		expect(find(wood, "float").text).toBe("+4 wood")
		local gold = director:handle("Gathered", { kingdom = "me", resource = "gold", amount = 1 })
		expect(find(gold, "sound")).toBeNil()
	end)

	it("coalesces repeats: one sound per window, floats every time, one toast that counts up", function()
		local first = director:handle("Built", { kingdom = "me", buildingType = "House" })
		now += 1
		local second = director:handle("Built", { kingdom = "me", buildingType = "Farm" })
		expect(find(first, "sound")).never.toBeNil()
		expect(find(second, "sound")).toBeNil()
		expect(find(second, "react")).toBeNil()
		expect(find(second, "vfx")).never.toBeNil()
		expect(find(second, "notify").notification.key).toBe(find(first, "notify").notification.key)
		expect(find(second, "notify").notification.count).toBe(2)
		now += 3
		local later = director:handle("Built", { kingdom = "me", buildingType = "Farm" })
		expect(find(later, "sound")).never.toBeNil()
		expect(find(later, "notify").notification.count).toBe(1)
	end)

	it("coalesces per key: different resources do not merge", function()
		director:handle("Gathered", { kingdom = "me", resource = "wood", amount = 1 })
		local stone = director:handle("Gathered", { kingdom = "me", resource = "stone", amount = 1 })
		expect(find(stone, "sound")).never.toBeNil()
	end)

	it("respects the notifications and citizen-bark settings", function()
		settingValues.notifications = "important"
		settingValues.citizenBarks = false
		local built = director:handle("Built", { kingdom = "me", buildingType = "Farm" })
		expect(find(built, "notify")).toBeNil()
		expect(find(built, "react")).toBeNil()
		local raid = director:handle("Raid", { kingdom = "rival", target = "me" })
		expect(find(raid, "notify")).never.toBeNil()
		expect(find(raid, "music").input).toBe("combat")
	end)

	it("formats templates from primitive info only and caps the length", function()
		expect(CueDirector.format("{buildingType} upgraded to level {level}", { buildingType = "Mill", level = 2 })).toBe(
			"Mill upgraded to level 2"
		)
		expect(CueDirector.format("{missing} complete", {})).toBe("complete")
		expect(#CueDirector.format("{x}", { x = string.rep("a", 200) })).toBe(60)
	end)
end)

describe("Experience/MusicDirector", function()
	local PHASES = { Founding = "calm", Expansion = "build", Conflict = "tension" }

	it("follows the game's phase map, but only after the minimum dwell time", function()
		local music = MusicDirector.new({ phaseStates = PHASES, minDwellSec = 20 })
		expect(music:update(0, { inMatch = true, phase = "Founding" })).toBe("calm")
		expect(music:update(5, { inMatch = true, phase = "Expansion" })).toBeNil()
		expect(music:update(21, { inMatch = true, phase = "Expansion" })).toBe("build")
		expect(music:update(50, { inMatch = true, phase = "Unknown" })).toBe("calm")
	end)

	it("switches to battle at once on combat and holds it, ending soon after calm", function()
		local music = MusicDirector.new({ phaseStates = PHASES, minDwellSec = 20, combatHoldSec = 25, calmTailSec = 8 })
		music:update(0, { inMatch = true, phase = "Conflict" })
		music:combat(30)
		expect(music:update(30, { inMatch = true, phase = "Conflict" })).toBe("battle")
		expect(music:update(50, { inMatch = true, phase = "Conflict" })).toBeNil()
		music:calm(40) -- combat over: rings out for 8 s (sooner than the 25 s hold from t = 30)
		expect(music:update(47, { inMatch = true, phase = "Conflict" })).toBeNil()
		expect(music:update(49, { inMatch = true, phase = "Conflict" })).toBe("tension")
	end)

	it("victory and defeat override everything immediately", function()
		local music = MusicDirector.new({ phaseStates = PHASES })
		music:update(0, { inMatch = true, phase = "Conflict" })
		music:combat(1)
		expect(music:update(2, { inMatch = true, phase = "Conflict", result = "won" })).toBe("victory")
		local other = MusicDirector.new()
		other:update(0, { inMatch = true })
		expect(other:update(1, { inMatch = true, result = "lost" })).toBe("defeat")
		expect(other:update(2, { inMatch = false })).toBe("calm")
	end)

	it("a scene plays at once, outranks battle, and ends without waiting for the dwell; the result wins", function()
		local music = MusicDirector.new({ phaseStates = PHASES, minDwellSec = 20, combatHoldSec = 25 })
		music:update(0, { inMatch = true, phase = "Conflict" })
		music:combat(1)
		expect(music:update(1, { inMatch = true, phase = "Conflict" })).toBe("battle")
		expect(music:update(2, { inMatch = true, phase = "Conflict", scene = "arena" })).toBe("arena")
		expect(music:update(3, { inMatch = true, phase = "Conflict", scene = "arena" })).toBeNil()
		expect(music:update(60, { inMatch = true, phase = "Conflict" })).toBe("tension") -- scene over, dwell long past
		music:update(61, { inMatch = true, phase = "Conflict", scene = "arena" })
		expect(music:update(62, { inMatch = true, phase = "Conflict" })).toBe("tension") -- 1 s later: no dwell wait
		expect(music:update(63, { inMatch = true, phase = "Conflict", scene = "arena", result = "won" })).toBe(
			"victory"
		)
		local blank = MusicDirector.new({ phaseStates = PHASES })
		expect(blank:update(0, { inMatch = true, phase = "Expansion", scene = "" })).toBe("build") -- "" is no scene
		expect(MusicDirector.soundFor("battle")).toBe("music.battle")
		expect(MusicDirector.soundFor("arena")).toBe("music.arena")
	end)
end)
