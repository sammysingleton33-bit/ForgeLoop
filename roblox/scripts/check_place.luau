--[[
	check_place — verifies the Rojo-built place (headless; Lune + @lune/roblox).

		lune run roblox/scripts/check_place.luau [place.rbxl] [--require-stamp] [--project <file>]

	--project: the Rojo project the place was built from (default roblox/default.project.json); game
	projects (games/game-001/default.project.json, D-022) add the Game trees.

	Checks
	  1. Expected tree: ReplicatedStorage.Forge with Contracts (Env, Loader, GameEvents, Types,
	     BuildStamp), Core.Signal, Config (Folder) with Game, Assets (Folder); ServerScriptService.Forge.Main
	     (Script) and .Services (Folder); StarterPlayer.StarterPlayerScripts.Forge.Main (LocalScript) and
	     .Controllers (Folder); plus every "$path" mount of the project (game projects: ReplicatedStorage.Game,
	     ServerScriptService.Game, StarterPlayerScripts.Game) and their Services/Controllers folders
	     when those directories exist.
	  2. Every Script/LocalScript/ModuleScript has non-empty source.
	  3. Every string require in every script resolves to a ModuleScript in this place (relative
	     from the script, or "@game/..."), with no ambiguous names on the way. This is the server's
	     view of the place; which side may see what is rule 4.
	  4. The D-017 policy as extended by D-022 (RequirePath.checkPolicy, also applied by the Lune
	     module loader): relative paths stay inside one source tree (Rojo "$path" mount); "@game/..."
	     is used only to reach another tree, and only ReplicatedStorage/Forge/... (shared, Config,
	     Assets) or ReplicatedStorage/Game/... (game shared code) — never ServerScriptService,
	     ServerStorage or StarterPlayer; framework (Forge) code never reaches Game code. Requires sit at the top level of the
	     module (block depth 0 from a tokenizer, so StyLua-wrapped lines are fine); non-literal
	     requires (require(instance), aliasing `require`) only inside Contracts/.
	  5. BuildInfo: if roblox/src/shared/BuildInfo.json exists, ReplicatedStorage.Forge.BuildInfo must
	     be a ModuleScript carrying the same sha (with --require-stamp the stamp is mandatory).
	  7. Project properties: every "$properties" value in the project (e.g. game-001's Players
	     CharacterAutoLoads, Workspace streaming, D-025/D-026) is present with that value in the place,
	     so a property Rojo drops or mis-converts fails here. Booleans, numbers, strings and enum names
	     are compared; any other value type is reported as unverifiable (extend this check).
	  6. Area names: no area folder in ReplicatedStorage.Game has a Remotes module when the same-named
	     area in ReplicatedStorage.Forge has one (env.sharedModules would collide at run time).
	Exit code 1 on any problem.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Path = require("../tests/harness/Path")
local Project = require("../tests/harness/Project")
local RequirePath = require("../tests/harness/RequirePath")

local function scriptDir(): string
	local source = string.gsub(debug.info(1, "s"), "^@", "")
	if not Path.isAbsolute(source) then
		source = Path.join(process.cwd, source)
	end
	return Path.dirname(source)
end

local ROOT = Path.normalize(scriptDir() .. "/../..")
local placeArg, requireStamp, projectArg = nil, false, nil
do
	local i = 1
	while i <= #process.args do
		local arg = process.args[i]
		if arg == "--require-stamp" then
			requireStamp = true
		elseif arg == "--project" then
			projectArg = process.args[i + 1]
			i += 1
		else
			placeArg = arg
		end
		i += 1
	end
end
local placeFile = if placeArg then Path.join(process.cwd, placeArg) else ROOT .. "/roblox/build/sandbox.rbxl"

local problems = {}
local function problem(message: string)
	table.insert(problems, message)
end

if not fs.isFile(placeFile) then
	print(`place check: FAIL — {placeFile} not found (run rojo build first)`)
	process.exit(1)
end

local game = roblox.deserializePlace(fs.readFile(placeFile))
local projectFile = if projectArg then Path.join(process.cwd, projectArg) else ROOT .. "/roblox/default.project.json"
if not fs.isFile(projectFile) then
	print(`place check: FAIL — project file {projectFile} not found`)
	process.exit(1)
end
local project = Project.load(projectFile)

local function pathOf(instance): { string }
	local names = {}
	local current = instance
	while current and current ~= game do
		table.insert(names, 1, current.Name)
		current = current.Parent
	end
	return names
end

local function dotted(names: { string }): string
	return if #names == 0 then "game" else table.concat(names, ".")
end

-- Walks names from `game`; reports ambiguity (two children with one name) like a careful reviewer.
local function lookup(names: { string }): (any?, string?)
	local current = game
	for i, name in names do
		local matches = {}
		for _, child in current:GetChildren() do
			if child.Name == name then
				table.insert(matches, child)
			end
		end
		if #matches == 0 then
			return nil, `{dotted(table.move(names, 1, i, 1, {}))} does not exist`
		elseif #matches > 1 then
			return nil, `{dotted(table.move(names, 1, i, 1, {}))} is ambiguous ({#matches} children share the name)`
		end
		current = matches[1]
	end
	return current, nil
end

-- ------------------------------------------------------------------ 1. expected tree
local EXPECTED = {
	{ "ReplicatedStorage.Forge", "Folder" },
	{ "ReplicatedStorage.Forge.Contracts", "Folder" },
	{ "ReplicatedStorage.Forge.Contracts.Env", "ModuleScript" },
	{ "ReplicatedStorage.Forge.Contracts.Loader", "ModuleScript" },
	{ "ReplicatedStorage.Forge.Contracts.GameEvents", "ModuleScript" },
	{ "ReplicatedStorage.Forge.Contracts.Types", "ModuleScript" },
	{ "ReplicatedStorage.Forge.Contracts.BuildStamp", "ModuleScript" },
	{ "ReplicatedStorage.Forge.Core.Signal", "ModuleScript" },
	{ "ReplicatedStorage.Forge.Config", "Folder" },
	{ "ReplicatedStorage.Forge.Config.Game", "ModuleScript" },
	{ "ReplicatedStorage.Forge.Assets", "Folder" },
	{ "ServerScriptService.Forge", "Folder" },
	{ "ServerScriptService.Forge.Main", "Script" },
	{ "ServerScriptService.Forge.Services", "Folder" },
	{ "StarterPlayer.StarterPlayerScripts.Forge", "Folder" },
	{ "StarterPlayer.StarterPlayerScripts.Forge.Main", "LocalScript" },
	{ "StarterPlayer.StarterPlayerScripts.Forge.Controllers", "Folder" },
}
-- Every "$path" mount of the project must be in the place, plus the Services/Controllers folders of
-- the server/client mounts when they exist on disk (an empty folder still builds into a Folder).
do
	local seen = {}
	for _, expected in EXPECTED do
		seen[expected[1]] = true
	end
	for _, mount in project.mounts do
		local path = table.concat(mount.dm, ".")
		if not seen[path] then
			seen[path] = true
			table.insert(EXPECTED, { path, if fs.isDir(mount.fs) then "Folder" else "ModuleScript" })
		end
		for _, sub in { "Services", "Controllers" } do
			local subPath = path .. "." .. sub
			if fs.isDir(mount.fs .. "/" .. sub) and not seen[subPath] then
				seen[subPath] = true
				table.insert(EXPECTED, { subPath, "Folder" })
			end
		end
	end
end
for _, expected in EXPECTED do
	local instance, err = lookup(string.split(expected[1], "."))
	if not instance then
		problem(`tree: {err}`)
	elseif instance.ClassName ~= expected[2] then
		problem(`tree: {expected[1]} is a {instance.ClassName}, expected {expected[2]}`)
	end
end

-- ------------------------------------------------------------------ 2-4. scripts and requires
local function mountOf(names: { string })
	return project:mountForDataModel(names)
end

local scripts, requiresChecked, dynamicRequires = 0, 0, 0
for _, instance in game:GetDescendants() do
	if instance:IsA("LuaSourceContainer") then
		scripts += 1
		local names = pathOf(instance)
		local where = dotted(names)
		local source = instance.Source
		if not string.match(source, "%S") then
			problem(`source: {where} ({instance.ClassName}) is empty`)
		end
		local inContracts = string.find(where, "^ReplicatedStorage%.Forge%.Contracts%.") ~= nil
		for _, found in RequirePath.scan(source) do
			local at = `{where}:{found.line}`
			if found.path == nil then
				dynamicRequires += 1
				if not inContracts then
					problem(
						`require: {at} uses a non-literal require ({found.text}); only Contracts/ may (interfaces §1)`
					)
				end
				continue
			end
			requiresChecked += 1
			if found.depth > 0 then
				problem(
					`require: {at} require("{found.path}") is inside a function or block, not at the top level of the module (interfaces §1)`
				)
			end
			local parsed, parseErr = RequirePath.parse(found.path)
			if not parsed then
				problem(`require: {at} {parseErr}`)
				continue
			end
			if parsed.kind == "lune" then
				problem(`require: {at} "{found.path}" — @lune libraries do not exist in Roblox`)
				continue
			end
			local base: { string }? = {}
			local baseErr = nil
			if parsed.kind == "relative" then
				base, baseErr = RequirePath.relativeBase(names, parsed.up)
			end
			local target, applyErr = nil, baseErr
			if base then
				target, applyErr = RequirePath.apply(base, parsed.components)
			end
			if not target then
				problem(`require: {at} "{found.path}": {applyErr}`)
				continue
			end
			local resolved, lookupErr = lookup(target)
			if not resolved then
				problem(`require: {at} "{found.path}" does not resolve: {lookupErr}`)
				continue
			end
			if not resolved:IsA("ModuleScript") then
				problem(`require: {at} "{found.path}" resolves to a {resolved.ClassName}, not a ModuleScript`)
				continue
			end
			local policyErr = RequirePath.checkPolicy(parsed, mountOf(names), mountOf(target), target)
			if policyErr then
				problem(`policy: {at} "{found.path}" {policyErr}`)
			end
		end
	end
end

-- ------------------------------------------------------------------ 6. area names across Forge and Game
do
	local forge = lookup({ "ReplicatedStorage", "Forge" })
	local gameShared = lookup({ "ReplicatedStorage", "Game" })
	if forge and gameShared then
		for _, area in gameShared:GetChildren() do
			local twin = forge:FindFirstChild(area.Name)
			if
				area:IsA("Folder")
				and twin
				and twin:IsA("Folder")
				and area:FindFirstChild("Remotes")
				and twin:FindFirstChild("Remotes")
			then
				problem(
					`areas: ReplicatedStorage.Forge.{area.Name} and ReplicatedStorage.Game.{area.Name} both declare `
						.. "Remotes; env.sharedModules keys areas by name, so one would shadow the other (rename one area)"
				)
			end
		end
	end
end

-- ------------------------------------------------------------------ 7. project properties
local propertiesChecked = 0
for _, node in project.nodes do
	if node.properties == nil then
		continue
	end
	local where = dotted(node.dm)
	local instance, err = lookup(node.dm)
	if not instance then
		problem(`properties: {err}`)
		continue
	end
	local names = {}
	for name in node.properties do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in names do
		local expected = node.properties[name]
		local ok, actual = pcall(function()
			return instance[name]
		end)
		if not ok then
			problem(`properties: {where}.{name} cannot be read from the place ({actual})`)
			continue
		end
		local kind = type(expected)
		local same
		if typeof(actual) == "EnumItem" and kind == "string" then
			same = actual.Name == expected
		elseif kind == "boolean" or kind == "string" then
			same = actual == expected
		elseif kind == "number" then
			same = type(actual) == "number" and math.abs(actual - expected) <= 1e-6 * math.max(1, math.abs(expected))
		else
			problem(`properties: {where}.{name} has a {kind} value the place check cannot verify yet (extend check 7)`)
			continue
		end
		propertiesChecked += 1
		if not same then
			problem(`properties: {where}.{name} is {tostring(actual)} in the place, project says {tostring(expected)}`)
		end
	end
end

-- ------------------------------------------------------------------ 5. BuildInfo
local stampFile = ROOT .. "/roblox/src/shared/BuildInfo.json"
local buildInfo = lookup({ "ReplicatedStorage", "Forge", "BuildInfo" })
local stampNote
if fs.isFile(stampFile) then
	local stamp = serde.decode("json", fs.readFile(stampFile))
	if not buildInfo or not buildInfo:IsA("ModuleScript") then
		problem("stamp: BuildInfo.json exists but ReplicatedStorage.Forge.BuildInfo is not a ModuleScript in the place")
	elseif not string.find(buildInfo.Source, stamp.sha, 1, true) then
		problem(`stamp: ReplicatedStorage.Forge.BuildInfo does not carry sha {stamp.sha} (rebuild after stamping)`)
	end
	stampNote = `stamped {string.sub(stamp.sha, 1, 12)}`
elseif requireStamp then
	problem("stamp: --require-stamp given but roblox/src/shared/BuildInfo.json is missing (run stamp_build.sh)")
	stampNote = "missing"
else
	stampNote = "unstamped (optional)"
end

local relativePlace = Path.relative(ROOT, placeFile)
if #problems > 0 then
	print(`place check: FAIL — {relativePlace}`)
	for _, message in problems do
		print("  - " .. message)
	end
	print(
		`place check: {scripts} scripts, {requiresChecked} string requires, {dynamicRequires} dynamic requires, {#problems} problem(s)`
	)
	process.exit(1)
end
print(
	`place check: PASS — {relativePlace} ({project.name}): {#EXPECTED} expected instances, {scripts} scripts, `
		.. `{requiresChecked} string requires resolved, {dynamicRequires} dynamic (Contracts only), `
		.. `{propertiesChecked} project properties, BuildInfo {stampNote}`
)
