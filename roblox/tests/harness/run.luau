--[[
	FORGELOOP Lune test runner.

		lune run roblox/tests/harness/run.luau            -- every spec
		lune run roblox/tests/harness/run.luau Signal     -- only spec files whose path contains "Signal"

	Discovers every *.spec.luau and *.spec.lua under roblox/tests/unit (recursively, sorted), loads
	each with a fresh ModuleLoader (Roblox require semantics; one module identity per file per spec
	file; the global Random is that loader's MockRandom), runs it and prints failures with
	locations. Exit code 1 if anything failed, if a spec file failed to load or defined no tests,
	if a file is named like a spec but would not be collected (e.g. FooSpec.luau, Foo.test.luau),
	if a spawned thread errored after its spec file finished, or if no spec files were found.
	There is no skip.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")

local Globals = require("./Globals")
local LuneInstances = require("./LuneInstances")
local ModuleLoader = require("./ModuleLoader")
local Path = require("./Path")
local Test = require("./Test")

local function scriptDir(): string
	local source = string.gsub(debug.info(1, "s"), "^@", "")
	if not Path.isAbsolute(source) then
		source = Path.join(process.cwd, source)
	end
	return Path.dirname(source)
end

local HARNESS_DIR = scriptDir()
local ROOT = Path.normalize(HARNESS_DIR .. "/../../..")
local UNIT_DIR = ROOT .. "/roblox/tests/unit"
local TEST_MODULE = HARNESS_DIR .. "/Test.luau"
local LUNE_INSTANCES_MODULE = HARNESS_DIR .. "/LuneInstances.luau"
local MOCK_RANDOM_MODULE = ROOT .. "/roblox/tests/mocks/MockRandom.luau"
-- Core/Signal (FORGE-01) documents setErrorReporter; the harness uses it so handler errors fail tests.
local SIGNAL_SUFFIX = "/roblox/src/shared/Core/Signal.luau"

local function isSpecName(name: string): boolean
	return string.sub(name, -10) == ".spec.luau" or string.sub(name, -9) == ".spec.lua"
end

-- Luau files whose name says "spec"/"test" but that the runner would not collect.
local function looksLikeSpec(name: string): boolean
	local lower = string.lower(name)
	if not (string.sub(lower, -5) == ".luau" or string.sub(lower, -4) == ".lua") then
		return false
	end
	return string.find(lower, "spec", 1, true) ~= nil or string.find(lower, "%.test%.") ~= nil
end

local function findSpecs(dir: string, out: { string }, misnamed: { string })
	if not fs.isDir(dir) then
		return out
	end
	local entries = fs.readDir(dir)
	table.sort(entries)
	for _, name in entries do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			findSpecs(full, out, misnamed)
		elseif isSpecName(name) then
			table.insert(out, full)
		elseif looksLikeSpec(name) then
			table.insert(misnamed, full)
		end
	end
	return out
end

Test.root = ROOT -- absolute repository root, for specs that read files

local filter = process.args[1]
local misnamed = {}
local allSpecs = findSpecs(UNIT_DIR, {}, misnamed)
local specs = {}
for _, file in allSpecs do
	if filter == nil or string.find(Path.relative(ROOT, file), filter, 1, true) then
		table.insert(specs, file)
	end
end

print(`FORGELOOP Lune tests — {#specs} spec file(s) under {Path.relative(ROOT, UNIT_DIR)}`)
if filter then
	print(`  filter "{filter}": {#specs} of {#allSpecs} spec files selected`)
end

local passed, failed, brokenFiles = 0, 0, 0
local failures = {}
local pendingCounters = {}

for _, file in misnamed do
	brokenFiles += 1
	local display = Path.relative(ROOT, file)
	table.insert(failures, {
		file = display,
		name = "(not collected)",
		errors = { "named like a spec, but the runner only collects *.spec.luau and *.spec.lua: rename it" },
	})
	print(`FAIL  {display}  (named like a spec but not collected)`)
end

for _, file in specs do
	local display = Path.relative(ROOT, file)
	Test._beginFile(display)
	local globals, globalsControl = Globals.build({
		-- looked up at call time, so a harness self-test can intercept reports
		onUnhandledError = function(message: string, origin: any?)
			Test.reportUnhandledError(message, origin)
		end,
		captureOrigin = Test.captureOrigin,
	})
	table.insert(pendingCounters, globalsControl.pendingCount)
	local loader = ModuleLoader.new({
		root = ROOT,
		globals = globals,
		preloaded = { [TEST_MODULE] = Test, [LUNE_INSTANCES_MODULE] = LuneInstances },
		nativeRequire = require,
	})
	local fileProblems = {}
	-- Core/Signal reports handler errors with warn() in Roblox; under test they fail the running
	-- test instead (a spec that checks isolation installs its own reporter with setErrorReporter).
	loader.onLoad = function(loadedFile: string, value: any)
		if string.sub(loadedFile, -#SIGNAL_SUFFIX) == SIGNAL_SUFFIX and type(value) == "table" then
			if type(value.setErrorReporter) ~= "function" then
				table.insert(
					fileProblems,
					"harness: Core/Signal no longer exports setErrorReporter(fn); the harness needs it to fail "
						.. "tests on Signal handler errors (roblox/src/shared/Core/Signal.luau header, run.luau)"
				)
				return
			end
			value.setErrorReporter(function(message: string)
				Test.reportUnhandledError("Signal handler error: " .. message)
			end)
		end
	end
	-- One Random per spec file, loaded through the loader so specs, mocks and the global share it.
	local randomLoaded, randomOrErr = pcall(loader.requireFile, loader, MOCK_RANDOM_MODULE)
	local loaded, loadErr = randomLoaded, randomOrErr
	if randomLoaded then
		globals.Random = randomOrErr
		loaded, loadErr = pcall(loader.execute, loader, file)
	end
	if loaded and #fileProblems > 0 then
		loaded, loadErr = false, table.concat(fileProblems, "\n")
	end
	if not loaded then
		Test._abortCollect()
		brokenFiles += 1
		table.insert(failures, { file = display, name = "(spec file failed to load)", errors = { tostring(loadErr) } })
		print(`FAIL  {display}  (failed to load)`)
		continue
	end
	local results = Test._run({ timeout = 5, pending = globalsControl.pendingCount })
	local filePassed, fileFailed = 0, 0
	for _, result in results.tests do
		if result.ok then
			filePassed += 1
		else
			fileFailed += 1
			table.insert(failures, { file = display, name = result.name, errors = result.errors })
		end
	end
	if #results.fileErrors > 0 then
		fileFailed += 1
		table.insert(failures, { file = display, name = "(outside any test)", errors = results.fileErrors })
	end
	if #results.tests == 0 then
		brokenFiles += 1
		table.insert(failures, { file = display, name = "(no tests)", errors = { "spec file defines no tests" } })
	end
	passed += filePassed
	failed += fileFailed
	local status = if fileFailed == 0 and #results.tests > 0 then "ok  " else "FAIL"
	print(`{status}  {display}  ({filePassed} passed, {fileFailed} failed)`)
end

if #failures > 0 then
	print("\nFailures:")
	for _, f in failures do
		print(`\n  x {f.file} :: {f.name}`)
		for _, err in f.errors do
			print("    " .. string.gsub(tostring(err), "\n", "\n    "))
		end
	end
end

-- Threads still running after their spec file finished: give them a moment, then report errors.
local function pendingTotal(): number
	local total = 0
	for _, count in pendingCounters do
		total += count()
	end
	return total
end
local drainStarted = os.clock()
while pendingTotal() > 0 and os.clock() - drainStarted < 2 do
	task.wait()
end
local late = Test._lateErrors()
if #late > 0 then
	print("\nLate errors (threads that errored after their spec file finished):")
	for _, entry in late do
		failed += 1
		print(`\n  x {entry.origin}\n    ` .. string.gsub(entry.message, "\n", "\n    "))
	end
end

local problems = failed + brokenFiles
if #specs == 0 then
	problems += 1
	print("\nNo spec files found — nothing was tested.")
end
print(`\nLune tests: {passed} passed, {failed} failed, {brokenFiles} broken file(s), {#specs} spec file(s), 0 skipped`)
print(if problems == 0 then "RESULT: PASS" else "RESULT: FAIL")
process.exit(if problems == 0 then 0 else 1)
