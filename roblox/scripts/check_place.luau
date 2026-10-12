--[[
	check_place — verifies the Rojo-built place (headless; Lune + @lune/roblox).

		lune run roblox/scripts/check_place.luau [place.rbxl] [--require-stamp]

	Checks
	  1. Expected tree: ReplicatedStorage.Forge with Contracts (Env, Loader, GameEvents, Types,
	     BuildStamp), Core.Signal, Config (Folder) with Game, Assets (Folder); ServerScriptService.Forge.Main
	     (Script) and .Services (Folder); StarterPlayer.StarterPlayerScripts.Forge.Main (LocalScript) and
	     .Controllers (Folder); Config.Map (ModuleScript); Workspace.ForgeMap (Folder, games/sandbox/map).
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
	  6. Map (FL-0044) against the map contract games/sandbox/config/Map.luau: every part under
	     Workspace.ForgeMap is anchored; only known Forge* tags; one LobbySpawn (the only
	     SpawnLocation in Workspace, Neutral) and one PlayArea; one Kingdom model per kingdom id;
	     per-kingdom anchor counts (Map.PER_KINGDOM), every kingdom resource per kingdom and every
	     neutral resource; anchors are BaseParts with valid KingdomId/Resource and unique
	     NodeId/PlotId; each kingdom anchor sits inside its Kingdom model and nearer its own Keep than
	     any other Keep (catches parts dropped at the origin), and every anchor lies in the PlayArea;
	     RulerSpawn and Spawn tag the same parts.
	Exit code 1 on any problem.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Map = require("../../games/sandbox/config/Map")
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
	{ "ReplicatedStorage.Forge.Config.Map", "ModuleScript" },
	{ "ReplicatedStorage.Forge.Assets", "Folder" },
	{ "ServerScriptService.Forge", "Folder" },
	{ "ServerScriptService.Forge.Main", "Script" },
	{ "ServerScriptService.Forge.Services", "Folder" },
	{ "StarterPlayer.StarterPlayerScripts.Forge", "Folder" },
	{ "StarterPlayer.StarterPlayerScripts.Forge.Main", "LocalScript" },
	{ "StarterPlayer.StarterPlayerScripts.Forge.Controllers", "Folder" },
	{ "Workspace.ForgeMap", "Folder" },
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

-- ------------------------------------------------------------------ 6. map (FL-0044)
local mapNote = "no map"
local forgeMap = lookup({ "Workspace", "ForgeMap" })
if forgeMap then
	local TAGS, ATTR = Map.TAGS, Map.ATTR
	local knownTags = {}
	for _, tag in TAGS do
		knownTags[tag] = true
	end
	local isKingdomId = {}
	for _, id in Map.KINGDOM_IDS do
		isKingdomId[id] = true
	end
	local isResource = {}
	for _, kind in Map.RESOURCES do
		isResource[kind] = true
	end

	local byTag: { [string]: { any } } = {}
	for _, tag in TAGS do
		byTag[tag] = {}
	end
	local partCount = 0
	for _, instance in forgeMap:GetDescendants() do
		local where = dotted(pathOf(instance))
		if instance:IsA("BasePart") then
			partCount += 1
			if not instance.Anchored then
				problem(`map: {where} is not Anchored (map parts must not fall)`)
			end
		end
		for _, tag in instance:GetTags() do
			if knownTags[tag] then
				table.insert(byTag[tag], instance)
			elseif string.find(tag, "^Forge") then
				problem(`map: {where} has unknown tag {tag} (not in Config/Map TAGS)`)
			end
		end
	end

	local spawnLocations = 0
	for _, instance in lookup({ "Workspace" }):GetDescendants() do
		if instance:IsA("SpawnLocation") then
			spawnLocations += 1
		end
	end
	local lobby = byTag[TAGS.LobbySpawn]
	if #lobby ~= 1 then
		problem(`map: {#lobby} parts tagged {TAGS.LobbySpawn}, expected 1`)
	elseif not lobby[1]:IsA("SpawnLocation") or not lobby[1].Neutral then
		problem(`map: {TAGS.LobbySpawn} must be a Neutral SpawnLocation`)
	end
	if spawnLocations ~= 1 then
		problem(`map: {spawnLocations} SpawnLocations in Workspace, expected only the lobby spawn`)
	end

	local bounds = byTag[TAGS.PlayArea]
	local area = nil
	if #bounds ~= 1 or not bounds[1]:IsA("BasePart") then
		problem(`map: expected exactly one BasePart tagged {TAGS.PlayArea}, found {#bounds}`)
	else
		area = bounds[1]
	end
	local function inArea(instance): boolean
		if area == nil then
			return true
		end
		local offset = area.CFrame:PointToObjectSpace(instance.CFrame.Position)
		return math.abs(offset.X) <= area.Size.X / 2
			and math.abs(offset.Y) <= area.Size.Y / 2
			and math.abs(offset.Z) <= area.Size.Z / 2
	end

	local kingdoms: { [string]: any } = {}
	for _, model in byTag[TAGS.Kingdom] do
		local id = model:GetAttribute(ATTR.KingdomId)
		if not model:IsA("Model") then
			problem(`map: {dotted(pathOf(model))} is tagged {TAGS.Kingdom} but is a {model.ClassName}, not a Model`)
		elseif not isKingdomId[id] then
			problem(`map: {dotted(pathOf(model))} has KingdomId {tostring(id)}, not one of Config/Map KINGDOM_IDS`)
		elseif kingdoms[id] then
			problem(`map: two Kingdom models with KingdomId {id}`)
		else
			kingdoms[id] = model
		end
	end
	for _, id in Map.KINGDOM_IDS do
		if not kingdoms[id] then
			problem(`map: no Kingdom model for KingdomId {id}`)
		end
	end

	local keeps: { [string]: any } = {}
	for _, keep in byTag[TAGS.Keep] do
		local id = keep:GetAttribute(ATTR.KingdomId)
		if isKingdomId[id] and keep:IsA("BasePart") and keeps[id] == nil then
			keeps[id] = keep
		end
	end
	local function nearestKeep(position): string?
		local best, bestDistance, tie = nil, math.huge, false
		for id, keep in keeps do
			local distance = (keep.CFrame.Position - position).Magnitude
			if math.abs(distance - bestDistance) < 1e-3 then
				tie = true
			elseif distance < bestDistance then
				best, bestDistance, tie = id, distance, false
			end
		end
		return if tie then nil else best
	end

	local counts: { [string]: { [string]: number } } = {}
	local resources: { [string]: { [string]: number } } = { [Map.NEUTRAL] = {} }
	for _, id in Map.KINGDOM_IDS do
		counts[id] = {}
		resources[id] = {}
	end
	local seenIds: { [string]: string } = {}
	local anchorCount = 0
	for tagName, tag in TAGS do
		if tag == TAGS.LobbySpawn or tag == TAGS.PlayArea or tag == TAGS.Kingdom then
			continue
		end
		for _, anchor in byTag[tag] do
			anchorCount += 1
			local where = dotted(pathOf(anchor))
			if not anchor:IsA("BasePart") then
				problem(`map: {where} is tagged {tag} but is a {anchor.ClassName}, not a BasePart`)
				continue
			end
			if not inArea(anchor) then
				problem(`map: {where} ({tag}) lies outside the {TAGS.PlayArea} bounds`)
			end
			local id = anchor:GetAttribute(ATTR.KingdomId)
			local neutralOk = tag == TAGS.ResourceNode and id == Map.NEUTRAL
			if not isKingdomId[id] and not neutralOk then
				problem(`map: {where} ({tag}) has KingdomId {tostring(id)}`)
				continue
			end
			if isKingdomId[id] then
				counts[id][tagName] = (counts[id][tagName] or 0) + 1
				local model = kingdoms[id]
				if model and not anchor:IsDescendantOf(model) then
					problem(`map: {where} ({tag}, KingdomId {id}) is not inside the {id} Kingdom model`)
				end
				local nearest = nearestKeep(anchor.CFrame.Position)
				if nearest ~= id then
					local other = if nearest
						then `the {nearest} keep`
						else "no single keep (equidistant: at the origin?)"
					problem(`map: {where} ({tag}, KingdomId {id}) at {anchor.CFrame.Position} is nearest {other}`)
				end
			else
				for _, model in kingdoms do
					if anchor:IsDescendantOf(model) then
						problem(`map: {where} is a Neutral resource inside a Kingdom model`)
					end
				end
			end
			local uniqueAttr = if tag == TAGS.ResourceNode
				then ATTR.NodeId
				elseif tag == TAGS.BuildPlot then ATTR.PlotId
				else nil
			if uniqueAttr then
				local value = anchor:GetAttribute(uniqueAttr)
				if type(value) ~= "string" or value == "" then
					problem(`map: {where} ({tag}) has no {uniqueAttr}`)
				elseif seenIds[value] then
					problem(`map: {uniqueAttr} {value} is used by {seenIds[value]} and {where}`)
				else
					seenIds[value] = where
				end
			end
			if tag == TAGS.ResourceNode then
				local kind = anchor:GetAttribute(ATTR.Resource)
				if not isResource[kind] then
					problem(`map: {where} has Resource {tostring(kind)}, not one of Config/Map RESOURCES`)
				else
					resources[id][kind] = (resources[id][kind] or 0) + 1
				end
			end
			if tag == TAGS.RulerSpawn and not anchor:HasTag(TAGS.Spawn) then
				problem(`map: {where} is a {TAGS.RulerSpawn} without {TAGS.Spawn} (FL-0010 compatibility)`)
			elseif tag == TAGS.Spawn and not anchor:HasTag(TAGS.RulerSpawn) then
				problem(`map: {where} is a {TAGS.Spawn} without {TAGS.RulerSpawn}`)
			end
		end
	end

	for _, id in Map.KINGDOM_IDS do
		for tagName, rule in Map.PER_KINGDOM do
			local have = counts[id][tagName] or 0
			if type(rule) == "number" and have ~= rule then
				problem(`map: kingdom {id} has {have} {TAGS[tagName]}, expected {rule}`)
			elseif type(rule) == "table" and have < rule.min then
				problem(`map: kingdom {id} has {have} {TAGS[tagName]}, expected at least {rule.min}`)
			end
		end
		for _, kind in Map.KINGDOM_RESOURCES do
			if (resources[id][kind] or 0) < 1 then
				problem(`map: kingdom {id} has no {kind} resource node`)
			end
		end
	end
	for _, kind in Map.NEUTRAL_RESOURCES do
		if (resources[Map.NEUTRAL][kind] or 0) < 1 then
			problem(`map: no Neutral {kind} resource node`)
		end
	end
	local kingdomCount = 0
	for _ in kingdoms do
		kingdomCount += 1
	end
	mapNote = `map {kingdomCount} kingdoms, {anchorCount} anchors, {partCount} parts`
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
		.. `{requiresChecked} string requires resolved, {dynamicRequires} dynamic (Contracts only), BuildInfo {stampNote}, {mapNote}`
)
