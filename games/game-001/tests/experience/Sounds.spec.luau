local T = require("../../../../roblox/tests/harness/Test")
local describe, it, expect = T.describe, T.it, T.expect

local SoundRegistry = require("@game/ReplicatedStorage/Forge/Experience/SoundRegistry")
local Sounds = require("@game/ReplicatedStorage/Forge/Experience/Sounds")
local MusicDirector = require("@game/ReplicatedStorage/Forge/Experience/MusicDirector")
local GameSounds = require("@game/ReplicatedStorage/Forge/Config/Sounds")

-- BRIEF §11 and the P0 rows of production/handoffs/2026-10-12-forge-04-to-user-sounds.md
local VS1 = {
	"music.calm",
	"music.build",
	"ambience.birds",
	"kingdom.chop",
	"kingdom.mine",
	"kingdom.harvest",
	"kingdom.hammer",
	"kingdom.build.place",
	"kingdom.build.complete",
	"kingdom.recruit",
	"kingdom.capture",
	"kingdom.founded",
}

describe("game-001 Sounds.luau", function()
	it("is a valid registry list and merges with the factory list", function()
		expect(SoundRegistry.validate(GameSounds)).toEqual({})
		expect(Sounds.registry:get("ui.click")).never.toBeNil()
		expect(Sounds.registry:get("kingdom.capture")).never.toBeNil()
	end)

	it("registers a track for every music state", function()
		for state, id in MusicDirector.STATE_SOUNDS do
			local entry = Sounds.registry:get(id)
			expect(entry and entry.category).toBe("music")
			expect(entry and entry.loop == true).toBe(true)
			assert(entry, `music state {state} has no sound {id}`)
		end
	end)

	it("covers the VS-1 slice sounds, all still 'needed' (no asset chosen or heard yet)", function()
		for _, id in VS1 do
			assert(Sounds.registry:get(id), `missing VS-1 sound {id}`)
		end
		for _, entry in GameSounds do
			expect(entry.status).toBe("needed")
			expect(entry.asset).toBeNil()
		end
	end)
end)
