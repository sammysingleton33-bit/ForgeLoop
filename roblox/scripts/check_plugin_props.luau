--[[
	check_plugin_props: fails when game code writes a property that only a plugin (Studio) may write.

	Roblox refuses these writes in a live game ("lacking capability Plugin"); a pcall around them hides the
	error, so the code silently takes its fallback. Lune's roblox library lets the same write through, so no
	spec can see it (FORGE-00, 2026-10-19: the Kit's MeshPart.CollisionFidelity write made every mesh rig and
	env mesh fall back to part-built in a real server, while every Lune gate passed).

	Scans what a place is built from: every *.luau under roblox/src and games/*/src, games/*/config and
	games/*/world. Import and plugin scripts (blender/studio, art importers) are not scanned: they run with Plugin
	capability. The matching, the property list and its limits are in PluginProps.luau (spec:
	roblox/tests/unit/contracts/PluginProps.spec.luau). A line that must stay (code that only ever runs inside a
	plugin) carries `-- plugin-context` and is skipped.

	Usage: lune run roblox/scripts/check_plugin_props.luau [root ...]
	(default: roblox/src and games/*/{src,config,world})
	Prints "plugin props: PASS — N files scanned" or one line per write and "plugin props: FAIL — K write(s)".
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local PluginProps = require("./PluginProps")

local function scanFile(path: string, found: { string })
	for _, hit in PluginProps.scan(fs.readFile(path)) do
		table.insert(found, `{path}:{hit.line}: writes {hit.prop} (Plugin security; refused in a live game)`)
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
			for _, sub in { "src", "config", "world" } do
				table.insert(roots, `games/{game}/{sub}`)
			end
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
