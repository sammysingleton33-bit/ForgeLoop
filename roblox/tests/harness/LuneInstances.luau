--[[
	LuneInstances — process-wide registry for mocks that fill in engine behaviour on Lune instances.

	Lune's roblox.implementMethod / implementProperty are global per class and may be registered
	only once per process ("class 'Players' already registered property 'PlayerAdded'"), while the
	harness gives every spec file fresh module instances. Mocks therefore register through
	LuneInstances.once and keep per-instance state in LuneInstances.store tables, which the runner
	shares with every spec file (it is preloaded like Test).

	API
		LuneInstances.once(key, fn)   -- run fn the first time `key` is seen in this process
		LuneInstances.store(name)     -- a table that lives for the whole test run
]]

local LuneInstances = {}

local done = {}
local stores = {}

function LuneInstances.once(key: string, fn: () -> ())
	if done[key] then
		return
	end
	done[key] = true
	fn()
end

function LuneInstances.store(name: string): { [any]: any }
	local store = stores[name]
	if store == nil then
		store = {}
		stores[name] = store
	end
	return store
end

return LuneInstances
