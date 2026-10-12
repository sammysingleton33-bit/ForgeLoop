--!strict
--[[
	SettingsService (FORGE-04) — the only owner of the `experience` profile namespace (interfaces §5,
	§8) and the player settings API.

		SettingsService:get(player, key) -> value            -- §8; the default when nothing is stored
		SettingsService:getAll(player) -> { [key]: value }   -- a copy
		SettingsService:set(player, key, value) -> boolean    -- validated (Experience/Schema.checkSetting)
		SettingsService:read(player, section) -> table?       -- a deep copy of experience[section]
		SettingsService:update(player, section, fn) -> boolean
			-- Onboarding/Quest/DailyReward services change ONLY their own section through this:
			-- fn(sectionTable) runs on a copy and is committed only if it returns without error.
		SettingsService:isPersistent() -> boolean           -- true when DataService is loaded
		SettingsService.changed: Signal (player, key, value)

	Storage (D-027: VS-1 runs without persistence)
	- DataService present (registry:find in start()): the namespace is registered there and every
	  read/write goes through DataService:get/update (step-wise migrations, no partial writes).
	- DataService absent: a session store keeps one `experience` table per player in memory, created
	  at the first access and dropped when the player leaves. Same API, same validation, same copy
	  semantics, so callers never branch on it.
	Registration happens in start() (D-027 requires the optional lookup there; interfaces §5 asks for
	new()). When FL-0008 lands, FORGE-01 and FORGE-04 agree whether DataService accepts it in start()
	or SettingsService declares the dependency again (handoff 2026-10-12-forge-04-to-forge-01-*).

	Remotes (Experience/Remotes.luau, via RemoteService when loaded): Experience.SetSetting (client ->
	server) and Experience.Settings (a snapshot to the client when the player joins or the profile
	loads, and after each change). Analytics: SettingChanged (key, value) at most once per key per
	player every ANALYTICS_GAP seconds, so slider drags do not spend the analytics budget.
]]

local Schema = require("@game/ReplicatedStorage/Forge/Experience/Schema")
local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local SettingsService = {}
SettingsService.__index = SettingsService

local Def = { name = "SettingsService", dependencies = {} }

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
	return setmetatable({
		_env = env,
		_registry = registry,
		_data = nil,
		_session = {},
		_connections = {},
		_lastAnalytics = {},
		changed = Signal.new(),
	}, SettingsService)
end

function SettingsService:start()
	local env = self._env
	self._remotes = self._registry:find("RemoteService")
	self._analytics = self._registry:find("AnalyticsService")
	local data = self._registry:find("DataService")
	if data then
		local ok, err = pcall(data.registerNamespace, data, Schema.NAMESPACE, Schema.spec())
		if ok then
			self._data = data
		else
			env.log("error", "SettingsService: DataService refused the experience namespace; session store", {
				error = tostring(err),
			})
		end
	else
		env.log("info", "SettingsService: no DataService; settings and progress last for the session (D-027)", {})
	end
	if self._remotes then
		self._remotes:handle("Experience.SetSetting", function(player, key, value)
			self:set(player, key, value)
		end)
	else
		env.log("warn", "SettingsService: RemoteService not loaded; settings remotes inactive", {})
	end
	if self._data and self._data.loaded then
		table.insert(
			self._connections,
			self._data.loaded:connect(function(player)
				self:_push(player)
			end)
		)
	elseif env.Players and env.Players.PlayerAdded then
		table.insert(
			self._connections,
			env.Players.PlayerAdded:Connect(function(player)
				self:_push(player)
			end)
		)
	end
	if env.Players and env.Players.PlayerRemoving then
		table.insert(
			self._connections,
			env.Players.PlayerRemoving:Connect(function(player)
				self._session[player] = nil
				self._lastAnalytics[player] = nil
			end)
		)
	end
end

function SettingsService:destroy()
	for _, connection in self._connections do
		if connection.Disconnect then
			connection:Disconnect()
		else
			connection:disconnect()
		end
	end
	table.clear(self._connections)
	self.changed:disconnectAll()
end

function SettingsService:isPersistent(): boolean
	return self._data ~= nil
end

-- The live namespace table (repaired with defaults); nil when DataService has not loaded it.
function SettingsService:_profile(player: any): any
	if self._data then
		local data = self._data:get(player, Schema.NAMESPACE)
		return if type(data) == "table" then data else nil
	end
	local profile = self._session[player]
	if profile == nil and player.Parent ~= nil then
		profile = Schema.defaults()
		self._session[player] = profile
	end
	return profile
end

-- Runs fn on a normalized copy and commits it only when fn returns (no partial writes).
function SettingsService:_write(player: any, fn: (any) -> ()): boolean
	if self._data then
		return self._data:update(player, Schema.NAMESPACE, function(data)
			Schema.normalize(data)
			fn(data)
		end)
	end
	local profile = self:_profile(player)
	if profile == nil then
		return false
	end
	local copy = deepCopy(profile)
	Schema.normalize(copy)
	local ok = pcall(fn, copy)
	if not ok then
		return false
	end
	self._session[player] = copy
	return true
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
	if self:_profile(player) == nil then
		return false
	end
	if self:get(player, key) == checked then
		return true
	end
	local committed = self:_write(player, function(data)
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
	local perPlayer = self._lastAnalytics[player] or {}
	self._lastAnalytics[player] = perPlayer
	local last = perPlayer[key]
	if last and now - last < ANALYTICS_GAP then
		return
	end
	perPlayer[key] = now
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
	return self:_write(player, function(data)
		fn(data[section])
	end)
end

function SettingsService:isLoaded(player: any): boolean
	return isPlayer(player) and self:_profile(player) ~= nil
end

return Def
