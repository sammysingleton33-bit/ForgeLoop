--!strict
--[[
	SettingsController (FORGE-04, client) — the local copy of the player's settings.

		SettingsController:get(key) -> value                  -- server snapshot, defaults until it arrives
		SettingsController:set(key, value) -> boolean         -- applies locally at once, then Experience.SetSetting
		SettingsController:volume(category) -> number         -- masterVolume x the category's volume (Sounds categories)
		SettingsController:reducedMotion() -> boolean          -- the setting OR the platform's Reduce Motion
		SettingsController.changed: Signal (key, value)

	Platform accessibility: creator-docs production/publishing/accessibility.md (@af5f853): "The
	**Reduce Motion** toggle maps to the `GuiService.ReducedMotionEnabled` property." We honour it
	even if the in-game toggle is off. The settings UI (FORGE-03 components) calls set() on release,
	not on every slider tick.
]]

local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Schema = require("@game/ReplicatedStorage/Forge/Experience/Schema")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local SettingsController = {}
SettingsController.__index = SettingsController

local Def = { name = "SettingsController", dependencies = {} }

local CATEGORY_SETTING = table.freeze({
	music = "musicVolume",
	ambience = "ambienceVolume",
	sfx = "sfxVolume",
	voice = "sfxVolume",
	ui = "uiVolume",
})
SettingsController.CATEGORY_SETTING = CATEGORY_SETTING

function Def.new(env: any, _registry: any)
	local values = {}
	for key, spec in Schema.SETTINGS do
		values[key] = spec.default
	end
	return setmetatable({ _env = env, _values = values, _links = {}, changed = Signal.new() }, SettingsController)
end

function SettingsController:start()
	table.insert(
		self._links,
		RemoteLink.on(self._env, "Experience.Settings", function(snapshot)
			self:_apply(snapshot)
		end)
	)
end

function SettingsController:destroy()
	for _, link in self._links do
		link:disconnect()
	end
	self.changed:disconnectAll()
end

function SettingsController:_apply(snapshot: any)
	if type(snapshot) ~= "table" then
		return
	end
	for _, key in Schema.SETTING_KEYS do
		local ok, value = Schema.checkSetting(key, snapshot[key])
		if ok and self._values[key] ~= value then
			self._values[key] = value
			self.changed:fire(key, value)
		end
	end
end

function SettingsController:get(key: string): any
	return self._values[key]
end

function SettingsController:set(key: string, value: any): boolean
	local ok, checked = Schema.checkSetting(key, value)
	if not ok then
		return false
	end
	if self._values[key] ~= checked then
		self._values[key] = checked
		self.changed:fire(key, checked)
	end
	RemoteLink.send(self._env, "Experience.SetSetting", key, checked)
	return true
end

function SettingsController:volume(category: string): number
	local key = CATEGORY_SETTING[category]
	local categoryVolume = if key then self._values[key] else 1
	return self._values.masterVolume * categoryVolume
end

function SettingsController:reducedMotion(): boolean
	if self._values.reducedMotion then
		return true
	end
	local ok, platform = pcall(function()
		return self._env.GuiService.ReducedMotionEnabled
	end)
	return ok and platform == true
end

return Def
