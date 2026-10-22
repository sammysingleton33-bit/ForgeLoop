--[[
	Crown Arena fairness run (FL-0076, FORGE-05). Plain Lune, from the repository root:

		lune run games/game-001/tests/fairness/run.luau                  -- quick: average skill, 200 duels per cell
		lune run games/game-001/tests/fairness/run.luau --full           -- every skill tier and loadout, 2000 per cell
		lune run games/game-001/tests/fairness/run.luau --duels 500 --skills novice,expert --seed 7 --out <file>

	Writes the Markdown report (default roblox/build/fairness/report.md, which is gitignored) and
	prints one line per bound check. Exit 1 when a bound fails, 2 on bad options.

	NOT THE MERGE GATE (FL-0146). This CLI runs the local DuelDouble with the PROVISIONAL design numbers
	(DesignSupport): it measures the harness, not the game. The gate is FairnessGate.spec (real
	Arena/DuelModel + config Support through ConfigSupport), run by check.sh and in full by:
		FORGE_FAIRNESS_FULL=1 lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/fairness FairnessGate
	A bound that fails here says nothing about the gate; quote the gate's summary line, never this one.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("./Harness")

local options = { n = 200, seed = 1, skills = { "average" }, out = "roblox/build/fairness/report.md" }
local args = process.args
local i = 1
while i <= #args do
	local arg = args[i]
	if arg == "--full" then
		options.n = 2000
		options.skills = nil
		options.loadouts = Harness.allLoadouts()
	elseif arg == "--duels" and tonumber(args[i + 1]) then
		options.n = math.floor(tonumber(args[i + 1]) :: number)
		i += 1
	elseif arg == "--seed" and tonumber(args[i + 1]) then
		options.seed = math.floor(tonumber(args[i + 1]) :: number)
		i += 1
	elseif arg == "--skills" and args[i + 1] then
		options.skills = string.split(args[i + 1], ",")
		i += 1
	elseif arg == "--loadouts" then
		options.loadouts = Harness.allLoadouts()
	elseif arg == "--out" and args[i + 1] then
		options.out = args[i + 1]
		i += 1
	else
		print(`fairness: unknown or incomplete option '{arg}'`)
		process.exit(2)
	end
	i += 1
end

print(
	"fairness CLI: instrument = DuelDouble with DesignSupport (design numbers). This is NOT the merge gate (FairnessGate.spec, FL-0146)."
)
local started = os.clock()
options.onCell = function(index: number, result: any)
	print(
		string.format(
			"%3d  %-60s %5.1f %%  [%5.1f, %5.1f]",
			index,
			result.cell.id,
			result.rate * 100,
			result.lo * 100,
			result.hi * 100
		)
	)
end
local results, checks = Harness.run(options)
local elapsed = os.clock() - started

local report = Harness.report(results, checks, {
	model = "DuelDouble",
	n = options.n,
	seed = options.seed,
	dt = Harness.DT,
})
local dir = string.match(options.out, "^(.*)/[^/]+$")
if dir and not fs.isDir(dir) then
	fs.writeDir(dir)
end
fs.writeFile(options.out, report)

local failed = 0
for _, check in checks do
	if check.status == "FAIL" then
		failed += 1
	end
end
print(
	string.format(
		"fairness CLI (DuelDouble + design numbers; NOT the merge gate, see FairnessGate.spec): %d cells x %d duels in %.1f s; %d of %d bound checks failed; report %s",
		#results,
		options.n,
		elapsed,
		failed,
		#checks,
		options.out
	)
)
process.exit(if failed > 0 then 1 else 0)
