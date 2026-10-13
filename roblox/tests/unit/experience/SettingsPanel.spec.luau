local T = require("../../harness/Test")
local describe, it, expect, beforeEach, afterEach = T.describe, T.it, T.expect, T.beforeEach, T.afterEach

local MockEnv = require("../../mocks/MockEnv")
local FakeDataService = require("./doubles/FakeDataService")
local FakeRemoteService = require("./doubles/FakeRemoteService")
local Loader = require("@game/ReplicatedStorage/Forge/Contracts/Loader")
local Create = require("@game/ReplicatedStorage/Forge/UI/Create")
local Schema = require("@game/ReplicatedStorage/Forge/Experience/Schema")
local ExperienceRemotes = require("@game/ReplicatedStorage/Forge/Experience/Remotes")
local SettingsModel = require("@game/ReplicatedStorage/Forge/Experience/SettingsModel")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")
local SettingsServiceDef = require("@game/ServerScriptService/Forge/Services/SettingsService")
local SettingsDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsController")
local PanelDef = require("@game/StarterPlayer/StarterPlayerScripts/Forge/Controllers/SettingsPanelController")

local function rowsByKey(sections)
	local out = {}
	for _, section in sections do
		for _, row in section.rows do
			out[row.key] = row
		end
	end
	return out
end

local function find(root, name)
	return root and root:FindFirstChild(name, true)
end

local function tap(instance)
	assert(instance, "tap: nothing to tap")
	local face = instance:FindFirstChild("Face") or instance
	expect(Create.fire(face, "Activated")).toBeGreaterThan(0)
end

describe("Experience/SettingsModel (FL-0103)", function()
	it("shows every setting exactly once, each with a label", function()
		local seen = {}
		for _, section in SettingsModel.SECTIONS do
			for _, key in section.keys do
				expect(Schema.SETTINGS[key]).never.toBeNil()
				expect(seen[key]).toBeNil()
				seen[key] = true
				expect(type(SettingsModel.LABEL[key])).toBe("string")
			end
		end
		for _, key in Schema.SETTING_KEYS do
			if not seen[key] then
				error(`setting {key} is in no section`)
			end
		end
	end)

	it("rows show what is in force: whole percentages, On / Off, option labels, defaults for bad values", function()
		local rows = rowsByKey(SettingsModel.sections({
			musicVolume = 0.6,
			sfxVolume = "loud",
			reducedMotion = true,
			notifications = "important",
			effectsQuality = "reduced",
		}))
		expect(rows.musicVolume.text).toBe("60%")
		expect(rows.musicVolume.progress).toBe(0.6)
		expect(rows.masterVolume.text).toBe("100%") -- missing: the default
		expect(rows.masterVolume.canUp).toBe(false)
		expect(rows.masterVolume.canDown).toBe(true)
		expect(rows.sfxVolume.value).toBe(Schema.SETTINGS.sfxVolume.default) -- bad value: the default
		expect(rows.reducedMotion.text).toBe("On")
		expect(rows.cameraShake.text).toBe("On")
		expect(rows.notifications.text).toBe("Important only")
		expect(rows.effectsQuality.text).toBe("Reduced")
		expect(rows.effectsQuality.kind).toBe("enum")
	end)

	it(
		"next(): volumes step by 0.1 and stop at 0 and 1, toggles flip, choices cycle, wrong actions do nothing",
		function()
			expect(SettingsModel.next("musicVolume", 0.6, "up")).toBe(0.7)
			expect(SettingsModel.next("musicVolume", 0.6, "down")).toBe(0.5)
			expect(SettingsModel.next("musicVolume", 0.05, "down")).toBe(0)
			expect(SettingsModel.next("musicVolume", 0.97, "up")).toBe(1)
			expect(SettingsModel.next("masterVolume", 1, "up")).toBeNil()
			expect(SettingsModel.next("masterVolume", 0, "down")).toBeNil()
			expect(SettingsModel.next("reducedMotion", false, "toggle")).toBe(true)
			expect(SettingsModel.next("cameraShake", true, "toggle")).toBe(false)
			expect(SettingsModel.next("notifications", "all", "cycle")).toBe("important")
			expect(SettingsModel.next("notifications", "important", "cycle")).toBe("all")
			expect(SettingsModel.next("effectsQuality", "full", "cycle")).toBe("reduced")
			expect(SettingsModel.next("musicVolume", 0.6, "toggle")).toBeNil()
			expect(SettingsModel.next("reducedMotion", false, "up")).toBeNil()
			expect(SettingsModel.next("dragons", 1, "up")).toBeNil()
			expect(SettingsModel.next("musicVolume", 0 / 0, "up")).toBe(0.7) -- NaN: from the default (0.6)
		end
	)

	it("the device's Reduce Motion is named on the toggle while the in-game one is off", function()
		local rows = rowsByKey(SettingsModel.sections({ reducedMotion = false }, { platformReducedMotion = true }))
		expect(rows.reducedMotion.note).never.toBeNil()
		rows = rowsByKey(SettingsModel.sections({ reducedMotion = true }, { platformReducedMotion = true }))
		expect(rows.reducedMotion.note).toBeNil()
		rows = rowsByKey(SettingsModel.sections({ reducedMotion = false }))
		expect(rows.reducedMotion.note).toBeNil() -- the device's setting is off too
	end)
end)

describe("SettingsService accepts the panel's values (FL-0103 round trip)", function()
	it("effectsQuality is a setting: full / reduced persist, anything else is refused", function()
		local env = MockEnv.new({ seed = 103 })
		local data = FakeDataService.new()
		local remotes = FakeRemoteService.new({ declarations = ExperienceRemotes })
		local registry = Loader.load(env, {
			{
				name = "DataService",
				new = function()
					return data
				end,
			},
			{
				name = "RemoteService",
				new = function()
					return remotes
				end,
			},
			SettingsServiceDef,
		})
		local service = registry:get("SettingsService")
		local player = env.mock.players:add({ userId = 103 })
		data:load(player, nil)
		expect(service:get(player, "effectsQuality")).toBe("full")
		expect(service:set(player, "effectsQuality", "reduced")).toBe(true)
		expect(service:get(player, "effectsQuality")).toBe("reduced")
		expect(service:set(player, "effectsQuality", "ultra")).toBe(false)
		expect(service:get(player, "effectsQuality")).toBe("reduced")
		-- what one tap of the panel sends, through the remote
		local value = SettingsModel.next("musicVolume", 0.6, "up")
		expect((remotes:call("Experience.SetSetting", player, "musicVolume", value))).toBe(true)
		remotes:call("Experience.SetSetting", player, "effectsQuality", "ultra") -- a string passes the remote's shape
		expect(service:get(player, "effectsQuality")).toBe("reduced") -- SettingsService refuses the value
		expect(service:get(player, "musicVolume")).toBe(0.7)
	end)
end)

describe("SettingsPanelController (FL-0103)", function()
	local env, registry, settings, panel, sent, playerGui

	local function boot(extra)
		local defs = extra or {}
		table.insert(defs, SettingsDef)
		table.insert(defs, {
			name = "SettingsPanelController",
			dependencies = { "SettingsController" },
			new = function(e, r)
				return PanelDef.create(e, r, { playerGui = playerGui })
			end,
		})
		registry = Loader.load(env, defs)
		settings = registry:get("SettingsController")
		panel = registry:get("SettingsPanelController")
		sent = {}
		settings.changed:connect(function(key, value)
			table.insert(sent, { key = key, value = value })
		end)
	end

	local previousConnector

	beforeEach(function()
		env = MockEnv.new({ seed = 104, isServer = false, localPlayer = { userId = 104 } })
		previousConnector = Create.useTestConnector() -- taps reach the kit's handlers (Create.fire)
		playerGui = env.newInstance("Folder")
		playerGui.Name = "PlayerGui"
	end)

	afterEach(function()
		Create.setConnector(previousConnector)
	end)

	it(
		"without a host: open() draws the panel in its own ScreenGui; a tap changes the setting and patches the row",
		function()
			boot()
			expect(panel.host).toBeNil()
			panel:open()
			expect(panel.isOpen).toBe(true)
			local gui = playerGui:FindFirstChild("ForgeSettings")
			expect(gui).never.toBeNil()
			expect(gui.DisplayOrder).toBe(30)
			local row = find(gui, "musicVolume")
			local up = find(row, "Up")
			tap(up)
			expect(settings:get("musicVolume")).toBe(0.7)
			expect(find(gui, "musicVolume")).toBe(row) -- patched, not rebuilt under the finger
			expect(find(find(gui, "musicVolume"), "Up")).toBe(up)
			tap(find(find(gui, "reducedMotion"), "Toggle"))
			expect(settings:get("reducedMotion")).toBe(true)
			tap(find(find(gui, "effectsQuality"), "Toggle"))
			expect(settings:get("effectsQuality")).toBe("reduced")
			expect(#sent).toBe(3)
			panel:close()
			expect(panel.isOpen).toBe(false)
			expect(find(gui, "SettingsPanel")).toBeNil()
			expect(gui.Enabled).toBe(false)
		end
	)

	it("a volume at its end disables that end's button, and a change from elsewhere redraws the open panel", function()
		boot()
		panel:open()
		local gui = playerGui:FindFirstChild("ForgeSettings")
		local master = find(gui, "masterVolume")
		expect(find(master, "Up"):GetAttribute("disabled")).toBe(true) -- 100% already
		expect(panel:change("masterVolume", "up")).toBe(false)
		settings:set("masterVolume", 0.5) -- e.g. another device's push
		expect(find(master, "Up"):GetAttribute("disabled")).toBe(false)
		expect(find(master, "Level"):FindFirstChildWhichIsA("TextLabel", true).Text).toBe("50%")
	end)

	it(
		"with a HUD host: a rail button opens it in the host's drawer as the menu 'settings'; another menu closes it",
		function()
			local menus = env.newInstance("Frame")
			local host = {
				menuChanged = Signal.new(),
				rendered = Signal.new(),
				roots = { menus = menus },
				items = {},
				menu = nil,
			}
			function host:addRailItem(item)
				table.insert(self.items, item)
			end
			function host:removeRailItem(id)
				self.removed = id
			end
			function host:setMenu(id)
				if self.menu == id then
					id = nil
				end
				self.menu = id
				self.menuChanged:fire(id)
			end
			function host:metrics()
				return { breakpoint = "phone", drawer = { x = 400, y = 60, width = 420, height = 300 } }
			end
			boot({
				{
					name = "KingdomHudController",
					new = function()
						return host
					end,
				},
			})
			expect(panel.host).toBe(host)
			expect(host.items[1].id).toBe("settings")
			host:setMenu("settings") -- the rail button
			expect(panel.isOpen).toBe(true)
			local view = menus:FindFirstChild("SettingsPanel")
			expect(view).never.toBeNil()
			expect(view.Position).toBe(UDim2.fromOffset(400, 60))
			expect(view.Size).toBe(UDim2.fromOffset(420, 300))
			host:setMenu("army")
			expect(panel.isOpen).toBe(false)
			expect(menus:FindFirstChild("SettingsPanel")).toBeNil()
			panel:toggle()
			expect(host.menu).toBe("settings")
			panel:close()
			expect(host.menu).toBeNil()
			panel:destroy()
			expect(host.removed).toBe("settings")
		end
	)
end)
