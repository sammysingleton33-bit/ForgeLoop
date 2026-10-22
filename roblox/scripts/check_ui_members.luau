--[[
	check_ui_members: fails when game code uses an engine member a live client refuses while Lune lets it through
	(a write to a read-only or not-scriptable property, a GetPropertyChangedSignal of a property no class has, an Enum
	item that does not exist). The rules and their limits are in UiMembers.luau (spec:
	roblox/tests/unit/contracts/UiMembers.spec.luau). Same file set as check_plugin_props.

	Usage: lune run roblox/scripts/check_ui_members.luau [root ...]
	Prints "ui members: PASS — N files scanned" or one line per hit and "ui members: FAIL — K hit(s)".
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local UiMembers = require("./UiMembers")

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
if #files == 0 then
	print("ui members: FAIL — no files scanned (wrong working directory?)")
	process.exit(1)
end

local index = UiMembers.index(roblox.getReflectionDatabase())
local WHAT = {
	write = "writes %s (not writable by scripts in a live client)",
	signal = 'GetPropertyChangedSignal("%s"): no class has this property',
	enum = "Enum.%s does not exist",
}
local count = 0
for _, path in files do
	for _, hit in UiMembers.scan(fs.readFile(path), index) do
		count += 1
		print(`{path}:{hit.line}: {string.format(WHAT[hit.kind], hit.name)}`)
	end
end
if count > 0 then
	print(`ui members: FAIL — {count} hit(s) in {#files} files`)
	process.exit(1)
end
print(`ui members: PASS — {#files} files scanned`)
