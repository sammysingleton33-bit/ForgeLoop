--[[
	ModuleLoader — a require() for Lune that follows Roblox semantics over the Rojo project.

	Why: Lune's native require resolves on the filesystem only. Roblox resolves in the DataModel,
	and the cross-tree form "@game/ReplicatedStorage/Forge/..." (D-017) has no filesystem meaning.
	Mapping "@game" to a mirrored directory loads a second copy of a module that is also required
	relatively (two module identities, see docs/lessons-learned/integration.md). This loader keys
	every module by its one canonical source file, so each module has exactly one identity per
	loader, however it is required.

	Resolution (per requiring file):
	  - "@game/A/B"        DataModel path A.B, mapped to a file through the project's "$path" nodes
	  - "./X", "../X"      inside a project tree: resolved in DataModel space from the script's
	                       DataModel path (script.Parent / script.Parent.Parent), like Roblox;
	                       outside the project (tests, mocks): resolved on the filesystem
	  - "@lune/x"          Lune's own libraries; only for files outside the project trees
	  - anything else      error (see RequirePath.parse)
	For files inside the project trees the D-017 policy applies as in the place check
	(RequirePath.checkPolicy: relative stays in its tree, "@game" only into ReplicatedStorage/Forge or
	ReplicatedStorage/Game, and framework trees never reach Game code — D-022);
	specs, mocks and tooling outside the trees may require any module by "@game/...".
	Roblox rules enforced: the target must be a ModuleScript (requiring a Script errors), a module
	must return exactly one non-nil value, and a cyclic require errors.

	API
		ModuleLoader.new({
			root: string,                    -- repository root (absolute)
			projectFile: string?,            -- default <root>/roblox/default.project.json
			globals: { [string]: any }?,     -- injected into every module environment
			preloaded: { [string]: any }?,   -- absolute file -> value (e.g. the running harness)
			nativeRequire: (string) -> any,  -- Lune's require, used for "@lune/..."
			requireInstance: ((any) -> any)?, -- what require(<non-string>) does (default: clear error)
		}) -> loader
		loader:require(fromFile, path) -> any     -- what `require(path)` does inside `fromFile`
		loader:requireFile(file) -> any           -- load a module file by absolute path (cached)
		loader:execute(file) -> ...               -- run a file once (spec files); not cached
		loader:resolve(fromFile, path) -> (file?, err?)
		loader:loadedFiles() -> { string }        -- canonical files loaded so far (sorted)
		loader.onLoad = fn(file, value)           -- optional hook, called once per newly loaded module
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local Path = require("./Path")
local Project = require("./Project")
local RequirePath = require("./RequirePath")

local ModuleLoader = {}
ModuleLoader.__index = ModuleLoader

local LUAU_CANDIDATES = { ".luau", ".lua", "/init.luau", "/init.lua", ".json" }

function ModuleLoader.new(options)
	assert(type(options) == "table" and type(options.root) == "string", "ModuleLoader.new: options.root required")
	assert(type(options.nativeRequire) == "function", "ModuleLoader.new: options.nativeRequire required")
	local root = Path.normalize(options.root)
	local self = setmetatable({
		root = root,
		project = Project.load(options.projectFile or Path.join(root, "roblox/default.project.json")),
		globals = options.globals or {},
		nativeRequire = options.nativeRequire,
		requireInstance = options.requireInstance,
		cache = {},
		loading = {},
		loadingStack = {},
	}, ModuleLoader)
	for file, value in options.preloaded or {} do
		self.cache[Path.normalize(file)] = { value = value }
	end
	return self
end

function ModuleLoader:display(file: string): string
	return Path.relative(self.root, file)
end

-- Resolves a filesystem path without extension to a module file.
local function resolveFsModule(base: string): (string?, string?)
	for _, suffix in LUAU_CANDIDATES do
		local candidate = base .. suffix
		if fs.isFile(candidate) then
			return candidate, nil
		end
	end
	for _, suffix in { ".server.luau", ".client.luau", ".server.lua", ".client.lua" } do
		if fs.isFile(base .. suffix) then
			return nil, `'{Path.basename(base)}' is a Script/LocalScript; only ModuleScripts can be required`
		end
	end
	return nil, `no module at '{base}'`
end

function ModuleLoader:resolve(fromFile: string, path: string): (string?, string?)
	local parsed, parseErr = RequirePath.parse(path)
	if not parsed then
		return nil, parseErr
	end
	local fromDm = self.project:fileToDataModel(fromFile)
	if parsed.kind == "lune" then
		if fromDm then
			return nil, "'@lune/...' is not available to Roblox code (it only exists in Lune)"
		end
		return "@lune/" .. table.concat(parsed.components, "/"), nil
	end

	local targetDm: { string }? = nil
	if parsed.kind == "game" then
		targetDm = parsed.components
	elseif fromDm then
		local base, baseErr = RequirePath.relativeBase(fromDm, parsed.up)
		if not base then
			return nil, baseErr
		end
		local applied, applyErr = RequirePath.apply(base, parsed.components)
		if not applied then
			return nil, applyErr
		end
		targetDm = applied
	end

	if targetDm then
		local file, kind = self.project:dataModelToFile(targetDm)
		local where = table.concat(targetDm, ".")
		if kind == "module" then
			if fromDm then
				-- Game code follows D-017 (same check as roblox/scripts/check_place.luau); tests may
				-- reach any tree, e.g. "@game/ServerScriptService/Forge/Services/X" in a spec.
				local fromMount = self.project:mountForFile(fromFile)
				local toMount = self.project:mountForDataModel(targetDm)
				local policyErr = RequirePath.checkPolicy(parsed, fromMount, toMount, targetDm)
				if policyErr then
					return nil, policyErr
				end
			end
			return Path.normalize(file :: string), nil
		elseif kind == "script" or kind == "localscript" then
			return nil, `{where} is a {kind}; only ModuleScripts can be required`
		elseif kind == "folder" or kind == "node" then
			return nil, `{where} is a folder/service, not a ModuleScript`
		end
		return nil, `no ModuleScript at {where}`
	end

	-- Filesystem resolution for files outside the project trees (tests, mocks, tooling).
	local base = Path.dirname(fromFile)
	for _ = 2, parsed.up do
		base = Path.dirname(base)
	end
	local target = base
	for _, component in parsed.components do
		target = Path.join(target, component)
	end
	local file, err = resolveFsModule(target)
	if not file then
		return nil, err
	end
	return Path.normalize(file), nil
end

function ModuleLoader:require(fromFile: string, path: string): any
	local file, err = self:resolve(fromFile, path)
	if not file then
		error(`require("{path}") in {self:display(fromFile)}: {err}`, 3)
	end
	if string.sub(file, 1, 6) == "@lune/" then
		return self.nativeRequire(file)
	end
	return self:requireFile(file)
end

function ModuleLoader:makeEnvironment(file: string)
	local env = table.clone(self.globals)
	env.require = function(path: any)
		if type(path) ~= "string" then
			if self.requireInstance then
				return self.requireInstance(path)
			end
			error(
				`require({typeof(path)}) in {self:display(file)}: requiring an Instance needs a running Roblox `
					.. "place; under the harness pass the module loader explicitly (e.g. Loader.discover(folder, requireModule))",
				2
			)
		end
		return self:require(file, path)
	end
	return env
end

function ModuleLoader:compile(file: string)
	local source = fs.readFile(file)
	return luau.load(source, {
		debugName = "@" .. self:display(file),
		environment = self:makeEnvironment(file),
	})
end

function ModuleLoader:requireFile(file: string): any
	file = Path.normalize(file)
	local cached = self.cache[file]
	if cached then
		return cached.value
	end
	if self.loading[file] then
		local chain = {}
		for _, f in self.loadingStack do
			table.insert(chain, self:display(f))
		end
		table.insert(chain, self:display(file))
		error("Requested module was required recursively (cyclic require): " .. table.concat(chain, " -> "), 0)
	end
	local value
	if string.sub(file, -5) == ".json" then
		value = serde.decode("json", fs.readFile(file))
	else
		self.loading[file] = true
		table.insert(self.loadingStack, file)
		local ok, results = pcall(function()
			local chunk = self:compile(file)
			return table.pack(chunk())
		end)
		self.loading[file] = nil
		table.remove(self.loadingStack)
		if not ok then
			error(results, 0)
		end
		if results.n ~= 1 or results[1] == nil then
			error(`Module code did not return exactly one value: {self:display(file)} returned {results.n} value(s)`, 0)
		end
		value = results[1]
	end
	self.cache[file] = { value = value }
	if self.onLoad then
		self.onLoad(file, value)
	end
	return value
end

function ModuleLoader:execute(file: string): ...any
	file = Path.normalize(file)
	return self:compile(file)()
end

function ModuleLoader:loadedFiles(): { string }
	local files = {}
	for file in self.cache do
		table.insert(files, file)
	end
	table.sort(files)
	return files
end

return ModuleLoader
