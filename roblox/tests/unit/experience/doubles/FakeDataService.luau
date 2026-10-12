--[[
	FakeDataService — a local double of FORGE-01's DataService (interfaces §5) for FORGE-04 specs,
	used until FL-0008 lands. Implements the documented signatures and the rules FORGE-04 relies on:
	step-wise migrations, no downgrade, no partial writes (update runs on a copy), unknown namespaces
	preserved, loaded/releasing signals.

		local data = FakeDataService.new()
		data:registerNamespace("experience", { version = 1, defaults = fn, migrate = fn? })
		data:load(player, stored?) -> (ok, reason?)   -- stored = { [namespace] = { version = n, data = t } }
		data:unload(player) -> stored                  -- fires releasing, returns what would be saved
		data:get(player, ns), data:update(player, ns, fn), data:isLoaded(player), data:saveNow(player)
		data.updates: number of successful updates; data.failUpdates = true makes update() return false
]]

local Signal = require("@game/ReplicatedStorage/Forge/Core/Signal")

local FakeDataService = {}
FakeDataService.__index = FakeDataService

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

function FakeDataService.new()
	return setmetatable({
		_specs = {},
		_profiles = {},
		loaded = Signal.new(),
		releasing = Signal.new(),
		updates = 0,
		saves = 0,
		failUpdates = false,
	}, FakeDataService)
end

function FakeDataService:registerNamespace(name: string, spec: any)
	assert(self._specs[name] == nil, `namespace '{name}' registered twice`)
	assert(type(spec.version) == "number" and type(spec.defaults) == "function", "spec needs version + defaults")
	self._specs[name] = spec
end

function FakeDataService:registeredNamespaces(): { string }
	local names = {}
	for name in self._specs do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function FakeDataService:load(player: any, stored: { [string]: any }?): (boolean, string?)
	local profile = { namespaces = {}, versions = {}, unknown = {} }
	for name, entry in stored or {} do
		if self._specs[name] == nil then
			profile.unknown[name] = deepCopy(entry)
		end
	end
	for name, spec in self._specs do
		local entry = stored and stored[name]
		if entry == nil then
			profile.namespaces[name] = spec.defaults()
		else
			local version = entry.version
			if version > spec.version then
				return false, `stored {name} v{version} is newer than v{spec.version}: no downgrade`
			end
			local data = deepCopy(entry.data)
			for k = version, spec.version - 1 do
				data = spec.migrate(data, k)
			end
			profile.namespaces[name] = data
		end
		profile.versions[name] = spec.version
	end
	self._profiles[player] = profile
	self.loaded:fire(player)
	return true, nil
end

function FakeDataService:unload(player: any): { [string]: any }
	local profile = self._profiles[player]
	assert(profile, "player not loaded")
	self.releasing:fire(player)
	local stored = deepCopy(profile.unknown)
	for name, data in profile.namespaces do
		stored[name] = { version = profile.versions[name], data = deepCopy(data) }
	end
	self._profiles[player] = nil
	return stored
end

function FakeDataService:isLoaded(player: any): boolean
	return self._profiles[player] ~= nil
end

function FakeDataService:waitForLoaded(player: any, _timeoutSec: number): boolean
	return self:isLoaded(player)
end

function FakeDataService:get(player: any, namespace: string): any
	local profile = self._profiles[player]
	return if profile then profile.namespaces[namespace] else nil
end

function FakeDataService:update(player: any, namespace: string, fn: (data: any) -> ()): boolean
	local profile = self._profiles[player]
	if profile == nil or profile.namespaces[namespace] == nil or self.failUpdates then
		return false
	end
	local copy = deepCopy(profile.namespaces[namespace])
	local ok = pcall(fn, copy)
	if not ok then
		return false
	end
	profile.namespaces[namespace] = copy
	self.updates += 1
	return true
end

function FakeDataService:saveNow(player: any): (boolean, string?)
	if self._profiles[player] == nil then
		return false, "not loaded"
	end
	self.saves += 1
	return true, nil
end

return FakeDataService
