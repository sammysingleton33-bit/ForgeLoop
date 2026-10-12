--[[
	Project — reads a Rojo project file and maps files <-> DataModel paths the way Rojo 7 builds them.

	Used by the Lune module loader so that "@game/..." and relative requires resolve exactly as in
	the built place, and by roblox/scripts/check_place.luau to know which source tree an instance
	came from.

	Rojo sync rules mirrored here (Rojo 7.7.1, verified by building roblox/default.project.json):
	  X.server.luau -> Script "X"        X.client.luau -> LocalScript "X"
	  X.luau / X.lua -> ModuleScript "X" X.json        -> ModuleScript "X" (returns the decoded table)
	  dir/           -> Folder "dir"     dir/init.luau -> ModuleScript "dir" (init.server/.client -> scripts)
	  other files (README.md, .gitkeep, ...) produce no instance.

	API
		Project.load(projectFile) -> Project
		project.mounts: { { dm: { string }, fs: string } }   -- every "$path" node
		project.nodes: { { dm, className?, properties? } }   -- every node ("$properties" as written)
		project:mountForFile(file) -> mount?                 -- deepest mount whose directory holds `file`
		project:mountForDataModel(dm) -> mount?               -- deepest mount whose DataModel path prefixes `dm`
		project:fileToDataModel(file) -> ({ string }?, kind?) -- kind: "module" | "script" | "localscript"
		project:dataModelToFile(dm) -> (file?, kind)          -- kind: "module" | "script" | "localscript" | "folder" | "node" | "missing"
]]

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Path = require("./Path")

local Project = {}
Project.__index = Project

local SCRIPT_SUFFIXES = {
	{ suffix = ".server.luau", kind = "script" },
	{ suffix = ".server.lua", kind = "script" },
	{ suffix = ".client.luau", kind = "localscript" },
	{ suffix = ".client.lua", kind = "localscript" },
	{ suffix = ".luau", kind = "module" },
	{ suffix = ".lua", kind = "module" },
}

local function endsWith(s: string, suffix: string): boolean
	return #s >= #suffix and string.sub(s, -#suffix) == suffix
end

-- Instance name and kind for a file name, or nil when Rojo creates no script for it.
local function classifyFileName(fileName: string): (string?, string?)
	for _, rule in SCRIPT_SUFFIXES do
		if endsWith(fileName, rule.suffix) then
			return string.sub(fileName, 1, #fileName - #rule.suffix), rule.kind
		end
	end
	if
		endsWith(fileName, ".json")
		and not endsWith(fileName, ".model.json")
		and not endsWith(fileName, ".meta.json")
		and not endsWith(fileName, ".project.json")
	then
		return string.sub(fileName, 1, #fileName - 5), "module"
	end
	return nil, nil
end
Project.classifyFileName = classifyFileName

function Project.load(projectFile: string)
	projectFile = Path.normalize(projectFile)
	local decoded = serde.decode("json", fs.readFile(projectFile))
	local projectDir = Path.dirname(projectFile)
	local self = setmetatable({ file = projectFile, name = decoded.name, mounts = {}, nodes = {} }, Project)
	local function walk(node, dm: { string })
		table.insert(self.nodes, { dm = dm, className = node["$className"], properties = node["$properties"] })
		if node["$path"] then
			table.insert(self.mounts, { dm = dm, fs = Path.join(projectDir, node["$path"]) })
		end
		for key, child in node do
			if string.sub(key, 1, 1) ~= "$" and type(child) == "table" then
				local childDm = table.clone(dm)
				table.insert(childDm, key)
				walk(child, childDm)
			end
		end
	end
	walk(decoded.tree, {})
	return self
end

local function isPrefix(prefix: { string }, full: { string }): boolean
	if #prefix > #full then
		return false
	end
	for i, name in prefix do
		if full[i] ~= name then
			return false
		end
	end
	return true
end

function Project:mountForFile(file: string)
	file = Path.normalize(file)
	local best = nil
	for _, mount in self.mounts do
		local dir = mount.fs
		if string.sub(file, 1, #dir + 1) == dir .. "/" or file == dir then
			if best == nil or #mount.fs > #best.fs then
				best = mount
			end
		end
	end
	return best
end

function Project:mountForDataModel(dm: { string })
	local best = nil
	for _, mount in self.mounts do
		if isPrefix(mount.dm, dm) and (best == nil or #mount.dm > #best.dm) then
			best = mount
		end
	end
	return best
end

function Project:fileToDataModel(file: string): ({ string }?, string?)
	file = Path.normalize(file)
	local mount = self:mountForFile(file)
	if not mount then
		return nil, nil
	end
	local rel = Path.relative(mount.fs, file)
	local parts = string.split(rel, "/")
	local fileName = table.remove(parts) :: string
	local name, kind = classifyFileName(fileName)
	if not name then
		return nil, nil
	end
	local dm = table.clone(mount.dm)
	for _, part in parts do
		table.insert(dm, part)
	end
	if name ~= "init" then
		table.insert(dm, name)
	end
	return dm, kind
end

-- Looks for the script Rojo would build as child `name` of directory `dir`.
local function findChildScript(dir: string, name: string): (string?, string)
	for _, rule in SCRIPT_SUFFIXES do
		local candidate = dir .. "/" .. name .. rule.suffix
		if fs.isFile(candidate) then
			return candidate, rule.kind
		end
	end
	local json = dir .. "/" .. name .. ".json"
	if fs.isFile(json) then
		return json, "module"
	end
	local sub = dir .. "/" .. name
	if fs.isDir(sub) then
		for _, rule in SCRIPT_SUFFIXES do
			local init = sub .. "/init" .. rule.suffix
			if fs.isFile(init) then
				return init, rule.kind
			end
		end
		return sub, "folder"
	end
	return nil, "missing"
end

function Project:dataModelToFile(dm: { string }): (string?, string)
	local mount = self:mountForDataModel(dm)
	if not mount then
		for _, node in self.nodes do
			if #node.dm == #dm and isPrefix(node.dm, dm) then
				return nil, "node"
			end
		end
		return nil, "missing"
	end
	local rest = table.move(dm, #mount.dm + 1, #dm, 1, {})
	if #rest == 0 then
		if fs.isFile(mount.fs) then
			local _, kind = classifyFileName(Path.basename(mount.fs))
			return mount.fs, kind or "missing"
		end
		local dir, name = Path.dirname(mount.fs), Path.basename(mount.fs)
		local file, kind = findChildScript(dir, name)
		if kind == "folder" or kind == "missing" then
			return mount.fs, if fs.isDir(mount.fs) then "folder" else "missing"
		end
		return file, kind
	end
	local dir = mount.fs
	for i = 1, #rest - 1 do
		dir = dir .. "/" .. rest[i]
		if not fs.isDir(dir) then
			return nil, "missing"
		end
	end
	return findChildScript(dir, rest[#rest])
end

return Project
