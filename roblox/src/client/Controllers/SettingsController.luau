--!strict
--[[
	SettingsController (FORGE-04, client) — the local copy of the player's settings.

		SettingsController:get(key) -> value                  -- server snapshot, defaults until it arrives
		SettingsController:set(key, value) -> boolean         -- applies locally at once; Experience.SetSetting once
		                                                         the key has been still for SEND_DELAY_SEC
		SettingsController:volume(category) -> number         -- masterVolume x the category's volume (Sounds categories)
		SettingsController:reducedMotion() -> boolean          -- the setting OR the platform's Reduce Motion
		SettingsController.changed: Signal (key, value)

	Platform accessibility: creator-docs production/publishing/accessibility.md (@af5f853): "The
	**Reduce Motion** toggle maps to the `GuiService.ReducedMotionEnabled` property." We honour it
	even if the in-game toggle is off.

	Taps in a row (FORGE-07's #123 M3): the settings panel's steppers call set() on every tap, so
	set() coalesces: one Experience.SetSetting per key once that key has been still for
	SEND_DELAY_SEC (the latest value), which also keeps a burst under the remote's rate limit. The
	server pushes a full snapshot after every accepted change; while a key's own change is not yet
	answered (PENDING_SEC after its send), a snapshot value for that key that differs is an older
	echo and is ignored, and the matching value acknowledges it. After PENDING_SEC the snapshot wins
	again (a change the server refused or clamped snaps back).
]]

local RemoteLink = require("@game/ReplicatedStorage/Forge/Experience/RemoteLink")
local Schema = require("@game/ReplicatedStorage/Forge/Experience/Schema")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local SettingsController = {}
SettingsController.__index = SettingsController

local Def = { name = "SettingsController", dependencies = {} }

SettingsController.SEND_DELAY_SEC = 0.3
SettingsController.PENDING_SEC = 2
Def.SEND_DELAY_SEC = SettingsController.SEND_DELAY_SEC
Def.PENDING_SEC = SettingsController.PENDING_SEC

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
	return setmetatable({
		_env = env,
		_values = values,
		_links = {},
		_pending = {} :: { [string]: { value: any, sendAt: number, untilAt: number, sent: boolean } },
		_send = function(key: string, value: any)
			RemoteLink.send(env, "Experience.SetSetting", key, value)
		end,
		changed = Signal.new(),
	}, SettingsController)
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
	local now = self._env.clock()
	for _, key in Schema.SETTING_KEYS do
		local ok, value = Schema.checkSetting(key, snapshot[key])
		local pending = self._pending[key]
		if ok and pending ~= nil then
			local answered = pending.sent and value == pending.value
			local waiting = not pending.sent or now < pending.untilAt
			if answered or not waiting then
				self._pending[key] = nil -- our change answered, or unanswered too long: the server's value wins
			else
				ok = false -- an older echo: the local change stands
			end
		end
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
	local env = self._env
	local pending = self._pending[key]
	local waiting = pending ~= nil and not pending.sent
	self._pending[key] = {
		value = checked,
		sendAt = env.clock() + SettingsController.SEND_DELAY_SEC,
		untilAt = math.huge,
		sent = false,
	}
	if not waiting then
		env.spawn(function()
			self:_flush(key)
		end)
	end
	return true
end

-- Sends a key's latest value once it has been still for SEND_DELAY_SEC (see set()).
function SettingsController:_flush(key: string)
	local env = self._env
	while true do
		local pending = self._pending[key]
		if pending == nil or pending.sent then
			return
		end
		local left = pending.sendAt - env.clock()
		if left <= 0 then
			pending.sent = true
			pending.untilAt = env.clock() + SettingsController.PENDING_SEC
			self._send(key, pending.value)
			return
		end
		env.wait(left)
	end
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
