--[[
	check_place — verifies the Rojo-built place (headless; Lune + @lune/roblox).

		lune run roblox/scripts/check_place.luau [place.rbxl] [--require-stamp]

	Checks
	  1. Expected tree: ReplicatedStorage.Forge with Contracts (Env, Loader, GameEvents, Types,
	     BuildStamp), Core.Signal, Config (Folder) with Game, Assets (Folder); ServerScriptService.Forge.Main
	     (Script) and .Services (Folder); StarterPlayer.StarterPlayerScripts.Forge.Main (LocalScript) and
	     .Controllers (Folder). (Workspace / games/sandbox/map comes with FL-0044, interfaces §1.)
	  2. Every Script/LocalScript/ModuleScript has non-empty source.
	  3. Every string require in every script resolves to a ModuleScript in this place (relative
	     from the script, or "@game/..."), with no ambiguous names on the way. This is the server's
	     view of the place; which side may see what is rule 4.
	  4. The D-017 policy (RequirePath.checkPolicy, also applied by the Lune module loader):
	     relative paths stay inside one source tree (Rojo "$path" mount); "@game/..." is used only
	     to reach another tree, and only ReplicatedStorage/Forge/... (shared, Config, Assets) — never
	     ServerScriptService, ServerStorage or StarterPlayer. Requires sit at the top level of the
	     module (block depth 0 from a tokenizer, so StyLua-wrapped lines are fine); non-literal
	     requires (require(instance), aliasing `require`) only inside Contracts/.
	  5. BuildInfo: if roblox/src/shared/BuildInfo.json exists, ReplicatedStorage.Forge.BuildInfo must
	     be a ModuleScript carrying the same sha (with --require-stamp the stamp is mandatory).
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
local placeArg, requireStamp = nil, false
for _, arg in process.args do
	if arg == "--require-stamp" then
		requireStamp = true
	else
		placeArg = arg
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
local project = Project.load(ROOT .. "/roblox/default.project.json")

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
	`place check: PASS — {relativePlace}: {#EXPECTED} expected instances, {scripts} scripts, `
		.. `{requiresChecked} string requires resolved, {dynamicRequires} dynamic (Contracts only), BuildInfo {stampNote}`
)
