local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")

describe("SettingsController taps in a row (FORGE-07 #123 M3)", function()
	local env, settings, sent

	beforeEach(function()
		env = MockEnv.new({ seed = 103, isServer = false, localPlayer = { userId = 10301 } })
		settings = SettingsDef.new(env, nil)
		sent = {}
		settings._send = function(key, value)
			table.insert(sent, `{key}={value}`)
		end
	end)

	local function settle()
		env.mock:advance(SettingsDef.SEND_DELAY_SEC + 0.01)
	end

	it("an older echo never reverts a newer tap; the matching echo acknowledges it", function()
		settings:set("musicVolume", 0.7)
		settings:set("musicVolume", 0.8)
		settle()
		settings:_apply({ musicVolume = 0.7 }) -- FORGE-07's repro: the echo of the first tap
		expect(settings:get("musicVolume")).toBe(0.8)
		settings:_apply({ musicVolume = 0.8 }) -- our change, answered
		settings:_apply({ musicVolume = 0.5 }) -- a later server change (another device) applies
		expect(settings:get("musicVolume")).toBe(0.5)
	end)

	it("taps in a row send once, the last value, after the key is still (under the rate limit)", function()
		for step = 1, 8 do
			settings:set("sfxVolume", step / 10)
			env.mock:advance(0.1)
		end
		expect(sent).toEqual({}) -- still tapping
		settings:_apply({ sfxVolume = 1 }) -- a snapshot before the send: the local value stands
		expect(settings:get("sfxVolume")).toBe(0.8)
		settle()
		expect(sent).toEqual({ "sfxVolume=0.8" })
		settings:set("uiVolume", 0.3)
		settle()
		expect(sent).toEqual({ "sfxVolume=0.8", "uiVolume=0.3" }) -- keys are independent
	end)

	it("a change the server never answers snaps back to the server's value after PENDING_SEC", function()
		settings:set("musicVolume", 0.9)
		settle()
		settings:_apply({ musicVolume = 0.6 })
		expect(settings:get("musicVolume")).toBe(0.9) -- still waiting for our answer
		env.mock:advance(SettingsDef.PENDING_SEC)
		settings:_apply({ musicVolume = 0.6 }) -- refused or clamped: the server's value wins
		expect(settings:get("musicVolume")).toBe(0.6)
		expect(env.mock.threadErrors).toEqual({})
	end)
end)
