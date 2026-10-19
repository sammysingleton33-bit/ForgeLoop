--!strict
--[[
	Contracts/Loader — service/controller lifecycle (docs/architecture/interfaces.md §3, contract v0.3).

	A definition module (server: roblox/src/server/Services/<Name>.luau, client:
	roblox/src/client/Controllers/<Name>.luau) returns:
		{ name = "<Name>", dependencies = { "<Other>", ... }?, new = function(env, registry) ... end }
	`new` builds the instance without yielding; the instance may have :start() (may spawn threads;
	should not yield) and :destroy().

	Discovery is separate from ordering:
		Loader.discover(folder, requireModule?) -> { Definition }
			every ModuleScript directly inside `folder`, sorted by name, each required and validated
			(name must equal the module name). Other children (Folders for helpers) are ignored.
		Loader.sort(definitions) -> { Definition }
			dependency order (Kahn), ties broken by name. Errors name the problem: duplicate name,
			missing dependency, or the exact cycle ("A -> B -> A").
		Loader.load(env, definitions, options?) -> Registry
			sort, then new() for every definition in order, then start() in the same order.
			options.isolate = true (the client, Main.client; FORGE-00 2026-10-19, interfaces §3 migration note):
			every new() and start() runs on its own; a failure (error, yield, nil) is logged at error level
			with the definition's name, that definition is marked failed, and the boot carries on. A
			definition whose declared dependency failed is skipped with its own error line ("skipped:
			dependency X failed") and never runs against a half-built peer. registry.failed lists the
			failures by name. Without the option (the server) one failure stops the boot, as before.
		Loader.discoverAll(folders, requireModule?) -> { Definition }
			discover() over several folders (framework Forge tree + game Game tree, D-022); a name
			defined in two folders is an error naming both folders.
		Loader.boot(env, folders?, requireModule?, options?) -> Registry  -- discover + load. `folders` is
			one Folder, a list of Folders, or nil (no services). `options` as for load.

	Registry
		registry:get(name)  -> instance; errors if `name` is not loaded. During new(), only declared
		                       dependencies may be fetched (clear error otherwise).
		registry:find(name) -> instance or nil; call it in start() or later (it errors inside new(),
		                       because services constructed after the caller would look absent).
		registry.order      -> { string } construction/start order (logged by Main at boot)
		registry:destroy()  -> calls instance:destroy() (when present) in reverse order. Every destroy
		                       runs even if an earlier one errors; afterwards one error lists the
		                       failures. Idempotent (a second call does nothing). Used by specs to tear
		                       services down; Main does not call it (services that must flush on
		                       shutdown use env.bindToClose).
]]

export type Definition = {
	name: string,
	dependencies: { string }?,
	new: (env: any, registry: Registry) -> any,
}

export type Registry = {
	get: (self: Registry, name: string) -> any,
	find: (self: Registry, name: string) -> any,
	destroy: (self: Registry) -> (),
	order: { string },
	failed: { [string]: string },
}

export type LoadOptions = { isolate: boolean? }

local Loader = {}

local function describeList(names: { string }): string
	if #names == 0 then
		return "none"
	end
	local sorted = table.clone(names)
	table.sort(sorted)
	return table.concat(sorted, ", ")
end

function Loader.validate(definition: any, source: string): Definition
	if type(definition) ~= "table" then
		error(`Loader: {source} must return a definition table, got {typeof(definition)}`, 0)
	end
	if type(definition.name) ~= "string" or definition.name == "" then
		error(`Loader: {source} has no string 'name'`, 0)
	end
	if type(definition.new) ~= "function" then
		error(`Loader: {source} ('{definition.name}') has no new(env, registry) function`, 0)
	end
	local deps = definition.dependencies
	if deps ~= nil then
		if type(deps) ~= "table" then
			error(`Loader: {source} ('{definition.name}') dependencies must be a list of names`, 0)
		end
		for i, dep in deps do
			if type(i) ~= "number" or type(dep) ~= "string" then
				error(`Loader: {source} ('{definition.name}') dependencies must be a list of names`, 0)
			end
		end
	end
	return definition :: Definition
end

function Loader.discover(folder: any, requireModule: ((any) -> any)?): { Definition }
	local load = requireModule or require
	local modules: { any } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a: any, b: any): boolean
		return a.Name < b.Name
	end)
	local definitions = {}
	for _, module in modules do
		local source = `{folder.Name}/{module.Name}`
		local definition = Loader.validate((load :: any)(module), source)
		if definition.name ~= module.Name then
			error(`Loader: {source} declares name '{definition.name}'; it must match the module name`, 0)
		end
		table.insert(definitions, definition)
	end
	return definitions
end

local function findCycle(byName: { [string]: Definition }, remaining: { [string]: boolean }): { string }
	-- Depth-first search over the unresolved definitions; returns the first cycle found.
	local state: { [string]: number } = {} -- 1 = on stack, 2 = done
	local stack: { string } = {}
	local found: { string }? = nil
	local function visit(name: string)
		if found then
			return
		end
		state[name] = 1
		table.insert(stack, name)
		local deps = table.clone(byName[name].dependencies or {})
		table.sort(deps)
		for _, dep in deps do
			if remaining[dep] then
				if state[dep] == 1 then
					local start = table.find(stack, dep) :: number
					local cycle = table.move(stack, start, #stack, 1, {})
					table.insert(cycle, dep)
					found = cycle
					return
				elseif state[dep] == nil then
					visit(dep)
					if found then
						return
					end
				end
			end
		end
		table.remove(stack)
		state[name] = 2
	end
	local names = {}
	for name in remaining do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		if state[name] == nil then
			visit(name)
		end
		if found then
			return found
		end
	end
	return names
end

function Loader.sort(definitions: { Definition }): { Definition }
	local byName: { [string]: Definition } = {}
	local names = {}
	for _, definition in definitions do
		if byName[definition.name] then
			error(`Loader: duplicate service name '{definition.name}'`, 0)
		end
		byName[definition.name] = definition
		table.insert(names, definition.name)
	end
	local blockers: { [string]: number } = {}
	local dependents: { [string]: { string } } = {}
	for _, definition in definitions do
		local count = 0
		local seen = {}
		local deps: { string } = definition.dependencies or {}
		for _, dep in deps do
			if dep == definition.name then
				error(`Loader: dependency cycle: {dep} -> {dep}`, 0)
			end
			if byName[dep] == nil then
				error(
					`Loader: '{definition.name}' depends on '{dep}', which is not loaded (loaded: {describeList(names)})`,
					0
				)
			end
			if not seen[dep] then
				seen[dep] = true
				count += 1
				dependents[dep] = dependents[dep] or {}
				table.insert(dependents[dep], definition.name)
			end
		end
		blockers[definition.name] = count
	end
	local ready = {}
	for _, name in names do
		if blockers[name] == 0 then
			table.insert(ready, name)
		end
	end
	local ordered = {}
	while #ready > 0 do
		table.sort(ready)
		local name = table.remove(ready, 1) :: string
		table.insert(ordered, byName[name])
		local waiting: { string } = dependents[name] or {}
		for _, dependent in waiting do
			blockers[dependent] -= 1
			if blockers[dependent] == 0 then
				table.insert(ready, dependent)
			end
		end
	end
	if #ordered < #definitions then
		local remaining = {}
		for name, count in blockers do
			if count > 0 then
				remaining[name] = true
			end
		end
		local cycle = findCycle(byName, remaining)
		error(`Loader: dependency cycle: {table.concat(cycle, " -> ")}`, 0)
	end
	return ordered
end

function Loader.load(env: any, definitions: { Definition }, options: LoadOptions?): Registry
	local ordered = Loader.sort(definitions)
	-- (type-checked: a caller that forwards a multi-return, as the specs do, may put a number here)
	local isolate = type(options) == "table" and options.isolate == true
	local instances: { [string]: any } = {}
	local order: { string } = {}
	local failed: { [string]: string } = {}
	local known: { [string]: boolean } = {}
	for _, definition in ordered do
		known[definition.name] = true
	end
	local constructing: Definition? = nil

	local registry = { order = order, failed = failed }
	function registry.get(_self: any, name: string): any
		local instance = instances[name]
		if instance ~= nil then
			if constructing and not table.find(constructing.dependencies or {}, name) then
				error(`Loader: {constructing.name}.new() fetched '{name}' without declaring it in dependencies`, 2)
			end
			return instance
		end
		if constructing then
			if known[name] then
				error(`Loader: {constructing.name}.new() fetched '{name}' without declaring it in dependencies`, 2)
			end
			error(`Loader: {constructing.name}.new() needs '{name}', which is not loaded`, 2)
		end
		error(`Loader: service '{name}' is not loaded (loaded: {describeList(order)})`, 2)
	end
	function registry.find(_self: any, name: string): any
		if constructing then
			error(`Loader: {constructing.name}.new() called registry:find('{name}'); call find in start() or later`, 2)
		end
		return instances[name]
	end
	local destroyed = false
	function registry.destroy(_self: any)
		if destroyed then
			return
		end
		destroyed = true
		local failures: { string } = {}
		for i = #order, 1, -1 do
			local name = order[i]
			local instance = instances[name]
			if type(instance) == "table" and type(instance.destroy) == "function" then
				local ok, err = pcall(instance.destroy, instance)
				if not ok then
					table.insert(failures, `{name}:destroy() failed: {tostring(err)}`)
				end
			end
		end
		if #failures > 0 then
			error(`Loader: {table.concat(failures, "; ")}`, 2)
		end
	end

	-- A failure stops the boot (the server), or, when isolating (the client), is logged with the name and
	-- marks that definition failed so its dependents are skipped.
	local function fail(name: string, message: string)
		if not isolate then
			error(message, 0)
		end
		failed[name] = message
		env.log("error", message, { controller = name })
	end
	-- The first declared dependency that failed, if any (a dependent never runs against a half-built peer).
	local function failedDependency(definition: Definition): string?
		for _, dep in definition.dependencies or {} do
			if failed[dep] ~= nil then
				return dep
			end
		end
		return nil
	end

	for _, definition in ordered do
		local name = definition.name
		local dep = failedDependency(definition)
		if dep ~= nil then
			fail(name, `Loader: {name} skipped: dependency {dep} failed`)
			continue
		end
		constructing = definition
		local thread = coroutine.create(definition.new)
		local ok, result = coroutine.resume(thread, env, registry)
		constructing = nil
		if not ok then
			fail(name, `Loader: {name}.new() failed: {debug.traceback(thread, tostring(result))}`)
		elseif coroutine.status(thread) ~= "dead" then
			fail(name, `Loader: {name}.new() yielded; new() must not yield (interfaces §3)`)
		elseif result == nil then
			fail(name, `Loader: {name}.new() returned nil`)
		else
			instances[name] = result
			table.insert(order, name)
		end
	end
	for _, definition in ordered do
		local name = definition.name
		local instance = instances[name]
		if instance == nil or failed[name] ~= nil then
			continue
		end
		local dep = failedDependency(definition)
		if dep ~= nil then
			fail(name, `Loader: {name} skipped: dependency {dep} failed`)
			continue
		end
		if type(instance) == "table" and type(instance.start) == "function" then
			local ok, err = pcall(instance.start, instance)
			if not ok then
				fail(name, `Loader: {name}:start() failed: {tostring(err)}`)
			end
		end
	end
	return (registry :: any) :: Registry
end

function Loader.discoverAll(folders: { any }, requireModule: ((any) -> any)?): { Definition }
	local definitions: { Definition } = {}
	local definedIn: { [string]: string } = {}
	for _, folder in folders do
		local where = folder:GetFullName()
		for _, definition in Loader.discover(folder, requireModule) do
			local previous = definedIn[definition.name]
			if previous then
				error(
					`Loader: '{definition.name}' is defined in both {previous} and {where}; names must be unique across trees`,
					0
				)
			end
			definedIn[definition.name] = where
			table.insert(definitions, definition)
		end
	end
	return definitions
end

function Loader.boot(env: any, folders: any?, requireModule: ((any) -> any)?, options: LoadOptions?): Registry
	local list: { any } = if folders == nil then {} elseif type(folders) == "table" then folders else { folders }
	return Loader.load(env, Loader.discoverAll(list, requireModule), options)
end

return Loader
