--!strict
--[[
	SettingsService (FORGE-04) — the only registrant of the `experience` profile namespace
	(interfaces §5, §8) and the player settings API.

		SettingsService:get(player, key) -> value            -- §8; the default when the profile is not loaded
		SettingsService:getAll(player) -> { [key]: value }   -- a copy
		SettingsService:set(player, key, value) -> boolean    -- validated (Experience/Schema.checkSetting)
		SettingsService:read(player, section) -> table?       -- a deep copy of experience[section]
		SettingsService:update(player, section, fn) -> boolean
			-- Onboarding/Quest/DailyReward services change ONLY their own section through this:
			-- fn(sectionTable) runs on a copy; DataService commits it only if fn returns without error.
		SettingsService.changed: Signal (player, key, value)

	Remotes (Experience/Remotes.luau, via RemoteService when loaded): Experience.SetSetting (client ->
	server) and Experience.Settings (snapshot to the client on profile load and after each change).
	Analytics: SettingChanged (key, value) at most once per key per player every ANALYTICS_GAP seconds,
	so slider drags do not spend the analytics budget.
]]

local Schema = require("@game/ReplicatedStorage/Forge/Experience/Schema")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local SettingsService = {}
SettingsService.__index = SettingsService

local Def = { name = "SettingsService", dependencies = { "DataService" } }

local ANALYTICS_GAP = 10

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function isPlayer(value: any): boolean
	return typeof(value) == "Instance" and value:IsA("Player")
end

function Def.new(env: any, registry: any)
	local data = registry:get("DataService")
	data:registerNamespace(Schema.NAMESPACE, Schema.spec())
	return setmetatable({
		_env = env,
		_registry = registry,
		_data = data,
		_connections = {},
		_lastAnalytics = {},
		changed = Signal.new(),
	}, SettingsService)
end

function SettingsService:start()
	self._remotes = self._registry:find("RemoteService")
	self._analytics = self._registry:find("AnalyticsService")
	if self._remotes then
		self._remotes:handle("Experience.SetSetting", function(player, key, value)
			self:set(player, key, value)
		end)
	else
		self._env.log("warn", "SettingsService: RemoteService not loaded; settings remotes inactive", {})
	end
	if self._data.loaded then
		table.insert(
			self._connections,
			self._data.loaded:connect(function(player)
				self:_push(player)
			end)
		)
	end
end

function SettingsService:destroy()
	for _, connection in self._connections do
		connection:disconnect()
	end
	table.clear(self._connections)
	self.changed:disconnectAll()
end

-- The live namespace table, repaired with defaults; nil when not loaded.
function SettingsService:_profile(player: any): any
	local data = self._data:get(player, Schema.NAMESPACE)
	if type(data) ~= "table" then
		return nil
	end
	return data
end

function SettingsService:_push(player: any)
	if self._remotes then
		self._remotes:fire("Experience.Settings", player, self:getAll(player))
	end
end

function SettingsService:get(player: any, key: string): any
	local spec = Schema.SETTINGS[key]
	if spec == nil then
		return nil
	end
	local profile = if isPlayer(player) then self:_profile(player) else nil
	local value = if profile and type(profile.settings) == "table" then profile.settings[key] else nil
	local ok, checked = Schema.checkSetting(key, value)
	return if ok then checked else spec.default
end

function SettingsService:getAll(player: any): { [string]: any }
	local out = {}
	for _, key in Schema.SETTING_KEYS do
		out[key] = self:get(player, key)
	end
	return out
end

function SettingsService:set(player: any, key: string, value: any): boolean
	if not isPlayer(player) then
		return false
	end
	local ok, checked = Schema.checkSetting(key, value)
	if not ok then
		return false
	end
	if self:get(player, key) == checked then
		return true
	end
	local committed = self._data:update(player, Schema.NAMESPACE, function(data)
		Schema.normalize(data)
		data.settings[key] = checked
	end)
	if not committed then
		return false
	end
	self.changed:fire(player, key, checked)
	self:_push(player)
	self:_report(player, key, checked)
	return true
end

function SettingsService:_report(player: any, key: string, value: any)
	if self._analytics == nil then
		return
	end
	local now = self._env.clock()
	local id = `{player.UserId}:{key}`
	local last = self._lastAnalytics[id]
	if last and now - last < ANALYTICS_GAP then
		return
	end
	self._lastAnalytics[id] = now
	self._analytics:event(player, "SettingChanged", { key = key, value = value })
end

function SettingsService:read(player: any, section: string): any
	if not table.find(Schema.SECTIONS, section) or not isPlayer(player) then
		return nil
	end
	local profile = self:_profile(player)
	if profile == nil then
		return nil
	end
	local copy = deepCopy(profile)
	Schema.normalize(copy)
	return copy[section]
end

function SettingsService:update(player: any, section: string, fn: (any) -> ()): boolean
	if section == "settings" or not table.find(Schema.SECTIONS, section) or not isPlayer(player) then
		return false
	end
	return self._data:update(player, Schema.NAMESPACE, function(data)
		Schema.normalize(data)
		fn(data[section])
	end)
end

function SettingsService:isLoaded(player: any): boolean
	return isPlayer(player) and self:_profile(player) ~= nil
end

return Def
