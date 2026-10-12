local T = require("../../harness/Test")
local describe, it, expect, beforeEach = T.describe, T.it, T.expect, T.beforeEach

local MockEnv = require("../../mocks/MockEnv")
local FakeDataService = require("./doubles/FakeDataService")
local FakeRemoteService = require("./doubles/FakeRemoteService")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Schema = require("@game/ReplicatedStorage/Forge/Experience/Schema")
local ExperienceRemotes = require("@game/ReplicatedStorage/Forge/Experience/Remotes")
local SettingsDef = require("@game/ServerScriptService/Forge/Services/SettingsService")

local function fakeAnalytics()
	local calls = {}
	return {
		calls = calls,
		event = function(_, player, name, fields)
			table.insert(calls, { player = player, name = name, fields = fields })
			return true
		end,
	}
end

local function boot(env, data, remotes, analytics)
	local defs = {
		{
			name = "DataService",
			new = function()
				return data
			end,
		},
		SettingsDef,
	}
	if remotes then
		table.insert(defs, {
			name = "RemoteService",
			new = function()
				return remotes
			end,
		})
	end
	if analytics then
		table.insert(defs, {
			name = "AnalyticsService",
			new = function()
				return analytics
			end,
		})
	end
	return Loader.load(env, defs)
end

describe("Experience/Schema", function()
	it("defaults every section and every setting", function()
		local data = Schema.defaults()
		for _, section in Schema.SECTIONS do
			expect(type(data[section])).toBe("table")
		end
		for key, spec in Schema.SETTINGS do
			expect(data.settings[key]).toBe(spec.default)
		end
		expect(data.daily).toEqual({ streak = 0, lastClaimDay = -1, claimedTotal = 0, graceUsedDay = -1 })
	end)

	it("checks setting values: volumes clamp to 0..1 at 0.01 steps, types must match", function()
		local ok, value = Schema.checkSetting("musicVolume", 0.333)
		expect(ok).toBe(true)
		expect(value).toBe(0.33)
		ok, value = Schema.checkSetting("musicVolume", 7)
		expect(ok).toBe(true)
		expect(value).toBe(1)
		expect((Schema.checkSetting("musicVolume", 0 / 0))).toBe(false)
		expect((Schema.checkSetting("musicVolume", "loud"))).toBe(false)
		expect((Schema.checkSetting("reducedMotion", 1))).toBe(false)
		expect((Schema.checkSetting("notifications", "important"))).toBe(true)
		expect((Schema.checkSetting("notifications", "never"))).toBe(false)
		expect((Schema.checkSetting("unknownKey", true))).toBe(false)
	end)

	it("normalize repairs missing sections and bad values but keeps unknown keys", function()
		local data = { settings = { musicVolume = "x", sfxVolume = 0.2 }, futureThing = { a = 1 } }
		Schema.normalize(data)
		expect(data.settings.musicVolume).toBe(Schema.SETTINGS.musicVolume.default)
		expect(data.settings.sfxVolume).toBe(0.2)
		expect(data.onboarding).toEqual({ flows = {} })
		expect(data.futureThing).toEqual({ a = 1 })
	end)

	it("migrates step by step through DataService (k = stored .. VERSION - 1)", function()
		local order = {}
		local migrate = Schema.buildMigrate({
			[1] = function(d)
				table.insert(order, 1)
				d.settings.legacyVolume = nil
				return d
			end,
			[2] = function(d)
				table.insert(order, 2)
				d.daily.graceUsedDay = d.daily.graceUsedDay or -1
				return d
			end,
		})
		local data = FakeDataService.new()
		data:registerNamespace("experience", { version = 3, defaults = Schema.defaults, migrate = migrate })
		local player = Instance.new("Player")
		local ok = data:load(player, {
			experience = { version = 1, data = { settings = { legacyVolume = 1 }, daily = { streak = 4 } } },
		})
		expect(ok).toBe(true)
		expect(order).toEqual({ 1, 2 })
		local stored = data:get(player, "experience")
		expect(stored.settings.legacyVolume).toBeNil()
		expect(stored.daily).toEqual({ streak = 4, graceUsedDay = -1 })
	end)

	it("a missing migration step errors with its version", function()
		expect(function()
			Schema.migrate({}, 1)
		end).toThrow("no migration from version 1 to 2")
	end)

	it("refuses to downgrade a newer stored version", function()
		local data = FakeDataService.new()
		data:registerNamespace("experience", Schema.spec())
		local ok, reason = data:load(Instance.new("Player"), { experience = { version = 9, data = {} } })
		expect(ok).toBe(false)
		expect(reason).toContain("no downgrade")
	end)
end)

describe("SettingsService", function()
	local env, data, remotes, analytics, registry, settings, player

	beforeEach(function()
		env = MockEnv.new({ seed = 11 })
		data = FakeDataService.new()
		remotes = FakeRemoteService.new({ declarations = ExperienceRemotes })
		analytics = fakeAnalytics()
		registry = boot(env, data, remotes, analytics)
		settings = registry:get("SettingsService")
		player = env.mock.players:add({ userId = 501 })
	end)

	it("registers the experience namespace with DataService when it is loaded", function()
		expect(data:registeredNamespaces()).toEqual({ "experience" })
		expect(settings:isPersistent()).toBe(true)
		expect(function()
			data:registerNamespace("experience", Schema.spec())
		end).toThrow("registered twice")
	end)

	it("returns defaults before the profile loads, and stored values after", function()
		expect(settings:get(player, "musicVolume")).toBe(0.6)
		expect(settings:set(player, "musicVolume", 0.2)).toBe(false) -- not loaded: nothing written
		data:load(player, { experience = { version = 1, data = { settings = { musicVolume = 0.25 } } } })
		expect(settings:get(player, "musicVolume")).toBe(0.25)
		expect(settings:get(player, "sfxVolume")).toBe(0.8)
		expect(settings:get(player, "nope")).toBeNil()
	end)

	it("pushes the snapshot to the client when the profile loads", function()
		data:load(player, nil)
		local sent = remotes:sentTo("Experience.Settings", player)
		expect(#sent).toBe(1)
		expect(sent[1].args[1].musicVolume).toBe(0.6)
	end)

	it("persists a valid change, fires changed and pushes the new snapshot", function()
		data:load(player, nil)
		local seen
		settings.changed:connect(function(p, key, value)
			seen = { p, key, value }
		end)
		expect(settings:set(player, "reducedMotion", true)).toBe(true)
		expect(data:get(player, "experience").settings.reducedMotion).toBe(true)
		expect(seen).toEqual({ player, "reducedMotion", true })
		expect(#remotes:sentTo("Experience.Settings", player)).toBe(2)
	end)

	it("rejects invalid values without writing", function()
		data:load(player, nil)
		local before = data.updates
		expect(settings:set(player, "reducedMotion", "yes")).toBe(false)
		expect(settings:set(player, "masterVolume", 0 / 0)).toBe(false)
		expect(settings:set({ UserId = 1 }, "masterVolume", 1)).toBe(false)
		expect(data.updates).toBe(before)
	end)

	it("handles Experience.SetSetting from clients; invalid calls never reach the handler", function()
		data:load(player, nil)
		expect((remotes:call("Experience.SetSetting", player, "sfxVolume", 0.4))).toBe(true)
		expect(settings:get(player, "sfxVolume")).toBe(0.4)
		expect((remotes:call("Experience.SetSetting", player, "admin", true))).toBe(false)
		expect((remotes:call("Experience.SetSetting", player, "sfxVolume", 5))).toBe(false)
		expect((remotes:call("Experience.SetSetting", player, "sfxVolume", 0.5, "extra"))).toBe(false)
		expect(remotes.rejected).toBe(3)
		expect(settings:get(player, "sfxVolume")).toBe(0.4)
	end)

	it("reports SettingChanged at most once per key per 10 s (slider drags)", function()
		data:load(player, nil)
		settings:set(player, "musicVolume", 0.1)
		settings:set(player, "musicVolume", 0.2)
		settings:set(player, "sfxVolume", 0.3)
		expect(#analytics.calls).toBe(2)
		env.wait(11)
		settings:set(player, "musicVolume", 0.3)
		expect(#analytics.calls).toBe(3)
		expect(analytics.calls[1].fields).toEqual({ key = "musicVolume", value = 0.1 })
	end)

	it("update(section) changes only that section; 'settings' and unknown sections are refused", function()
		data:load(player, nil)
		expect(settings:update(player, "onboarding", function(section)
			section.flows.first = { version = 1, completed = 2, skipped = false }
		end)).toBe(true)
		local stored = data:get(player, "experience")
		expect(stored.onboarding.flows.first.completed).toBe(2)
		expect(stored.settings.musicVolume).toBe(0.6)
		expect(settings:update(player, "settings", function() end)).toBe(false)
		expect(settings:update(player, "economy", function() end)).toBe(false)
	end)

	it("an erroring update writes nothing (no partial write)", function()
		data:load(player, nil)
		local ok = settings:update(player, "daily", function(section)
			section.streak = 99
			error("boom")
		end)
		expect(ok).toBe(false)
		expect(data:get(player, "experience").daily.streak).toBe(0)
	end)

	it("read(section) returns a copy", function()
		data:load(player, nil)
		local copy = settings:read(player, "daily")
		copy.streak = 50
		expect(data:get(player, "experience").daily.streak).toBe(0)
		expect(settings:read(player, "bogus")).toBeNil()
	end)

	it("logs (does not fail) when RemoteService is absent", function()
		local env2 = MockEnv.new()
		boot(env2, FakeDataService.new(), nil, nil)
		expect(env2.mock:hasLog("warn", "RemoteService not loaded")).toBe(true)
	end)
end)

describe("SettingsService without DataService (D-027: session-only)", function()
	local env, remotes, registry, settings, player

	beforeEach(function()
		env = MockEnv.new({ seed = 12 })
		remotes = FakeRemoteService.new({ declarations = ExperienceRemotes })
		registry = Loader.load(env, {
			{
				name = "RemoteService",
				new = function()
					return remotes
				end,
			},
			SettingsDef,
		})
		settings = registry:get("SettingsService")
		player = env.mock.players:add({ userId = 551 })
	end)

	it("boots without DataService and says so", function()
		expect(settings:isPersistent()).toBe(false)
		expect(env.mock:hasLog("info", "no DataService")).toBe(true)
	end)

	it("pushes the default snapshot when the player joins", function()
		local sent = remotes:sentTo("Experience.Settings", player)
		expect(#sent).toBe(1)
		expect(sent[1].args[1].musicVolume).toBe(0.6)
	end)

	it("keeps settings and section progress for the session", function()
		expect(settings:set(player, "musicVolume", 0.3)).toBe(true)
		expect(settings:get(player, "musicVolume")).toBe(0.3)
		expect(settings:update(player, "onboarding", function(section)
			section.flows.first = { version = 1, completed = 3, skipped = false }
		end)).toBe(true)
		expect(settings:read(player, "onboarding").flows.first.completed).toBe(3)
	end)

	it("has the same no-partial-write and validation rules as the persistent store", function()
		expect(settings:set(player, "musicVolume", "loud")).toBe(false)
		expect(settings:update(player, "daily", function(section)
			section.streak = 9
			error("boom")
		end)).toBe(false)
		expect(settings:read(player, "daily").streak).toBe(0)
		expect(settings:update(player, "settings", function() end)).toBe(false)
	end)

	it("forgets the session when the player leaves", function()
		settings:set(player, "sfxVolume", 0.1)
		env.mock.players:remove(player)
		expect(settings:get(player, "sfxVolume")).toBe(0.8) -- a departed player gets defaults, nothing new is stored
		expect(settings:set(player, "sfxVolume", 0.2)).toBe(false)
	end)
end)
