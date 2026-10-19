--[[
	check_plugin_props: fails when game code writes a property that only a plugin (Studio) may write.

	Roblox refuses these writes in a live game ("lacking capability Plugin"); a pcall around them hides the
	error, so the code silently takes its fallback. Lune's roblox library lets the same write through, so no
	spec can see it (FORGE-00, 2026-10-19: the Kit's MeshPart.CollisionFidelity write made every mesh rig and
	env mesh fall back to part-built in a real server, while every Lune gate passed).

	Scans the code that runs in a game: every *.luau under roblox/src and games/*/src. Import and plugin
	scripts (blender/studio, art importers) are not scanned: they run with Plugin capability.
	A line that must stay (code that only ever runs inside a plugin) carries `-- plugin-context` and is skipped.

	Usage: lune run roblox/scripts/check_plugin_props.luau [root ...]   (default: roblox/src games/*/src)
	Prints "plugin props: PASS — N files scanned" or one line per write and "plugin props: FAIL — K write(s)".
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

-- MeshPart / SurfaceAppearance / asset properties with Plugin (or RobloxScript) write security.
local PLUGIN_ONLY = {
	"CollisionFidelity",
	"RenderFidelity",
	"MeshId",
	"DoubleSided",
	"FluidFidelity",
	"ColorMap",
	"MetalnessMap",
	"NormalMap",
	"RoughnessMap",
}

local function stripComment(line: string): (string, string)
	-- drop a trailing `--` comment and blank out string contents (so "p.MeshId = 1" in a string is not a write)
	local out = {}
	local kept = {}
	local quote: string? = nil
	local i = 1
	while i <= #line do
		local c = line:sub(i, i)
		if quote then
			if c == "\\" then
				table.insert(out, "  ")
				table.insert(kept, line:sub(i, i + 1))
				i += 2
				continue
			elseif c == quote then
				quote = nil
				table.insert(out, c)
			else
				table.insert(out, " ")
			end
			table.insert(kept, c)
		else
			if c == '"' or c == "'" or c == "`" then
				quote = c
				table.insert(out, c)
			elseif c == "-" and line:sub(i + 1, i + 1) == "-" then
				break
			else
				table.insert(out, c)
			end
			table.insert(kept, c)
		end
		i += 1
	end
	return table.concat(out), table.concat(kept)
end

-- true when the line assigns to `.Prop` (matched with strings blanked) or `["Prop"]` (matched with strings kept);
-- an `=` that is not `==` (`~=`, `<=`, `>=` never follow the property name directly)
local function writes(blanked: string, kept: string, prop: string): boolean
	for _, pair in { { blanked, "%." .. prop .. "%s*=" }, { kept, "%[%s*[\"']" .. prop .. "[\"']%s*%]%s*=" } } do
		local code, pattern = pair[1], pair[2]
		local s, e = code:find(pattern)
		while s do
			local nextChar = code:sub(e + 1, e + 1)
			if nextChar ~= "=" then
				return true
			end
			s, e = code:find(pattern, e + 1)
		end
	end
	return false
end

local function scanFile(path: string, found: { string })
	local source = fs.readFile(path)
	local n = 0
	local inBlock = false
	for line in (source .. "\n"):gmatch("([^\n]*)\n") do
		n += 1
		-- skip --[[ ... ]] block comments
		if inBlock then
			if line:find("%]%]") then
				inBlock = false
			end
			continue
		end
		if line:find("^%s*%-%-%[%[") and not line:find("%]%]") then
			inBlock = true
			continue
		end
		if line:find("plugin%-context") then
			continue
		end
		local blanked, kept = stripComment(line)
		for _, prop in PLUGIN_ONLY do
			if writes(blanked, kept, prop) then
				table.insert(found, `{path}:{n}: writes {prop} (Plugin security; refused in a live game)`)
			end
		end
	end
end

local function walk(dir: string, files: { string })
	if not fs.isDir(dir) then
		return
	end
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, files)
		elseif name:match("%.luau$") or name:match("%.lua$") then
			table.insert(files, path)
		end
	end
end

local roots = {}
for _, arg in process.args do
	table.insert(roots, arg)
end
if #roots == 0 then
	table.insert(roots, "roblox/src")
	if fs.isDir("games") then
		for _, game in fs.readDir("games") do
			table.insert(roots, `games/{game}/src`)
		end
	end
end
table.sort(roots)

local files = {}
for _, root in roots do
	walk(root, files)
end
table.sort(files)

local found = {}
for _, path in files do
	scanFile(path, found)
end

if #files == 0 then
	print("plugin props: FAIL — no files scanned (wrong working directory?)")
	process.exit(1)
end
for _, line in found do
	print(line)
end
if #found > 0 then
	print(`plugin props: FAIL — {#found} write(s) to plugin-only properties in {#files} files`)
	process.exit(1)
end
print(`plugin props: PASS — {#files} files scanned, no writes to plugin-only properties`)
