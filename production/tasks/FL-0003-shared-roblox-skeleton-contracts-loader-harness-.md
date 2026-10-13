---
id: FL-0003
title: "Shared Roblox skeleton: contracts, loader, harness, mocks, checks, CI"
track: infra
owner: forge-00
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: []
context: [docs/architecture/interfaces.md]
estimate_h: 4
evidence:
  - "check.sh 2026-10-12 final, after review fixes (base 2cd819b + uncommitted skeleton): toolchain PASS (rojo 7.7.1, selene 0.31.0, stylua 2.6.0, lune 0.11.0); lune tests 179 passed, 0 failed, 0 broken, 16 spec files, 0 skipped; selene 0 errors, 0 warnings; stylua 69 files formatted; rojo build PASS; place check PASS (17 expected instances, 9 scripts, 8 string requires resolved, 3 dynamic in Contracts only); OVERALL PASS. Same result from /tmp with PATH=/usr/bin:/bin"
  - "negative gates re-run on the final tree (each check.sh exit 1, then reverted; file hashes identical to before; green again): failing spec -> lune tests FAIL (expected 2 to be 3, with file:line); broken @game .../Contracts/Loaderr in Main.server -> place check FAIL (does not exist); unformatted line in Types.luau -> stylua FAIL"
  - "extra negatives (scratch copy of the final tree): @game from client/shared into ServerScriptService or StarterPlayer -> lune FAIL + place check 3 policy problems; a step aborted by a shell error -> steps FAIL row, OVERALL FAIL (old script: silent PASS); a spec that never yields -> lune tests timed out FAIL; spawned-thread errors after a later resume fail the spawning test, later ones are reported as late errors; *.spec.lua collected and FooSpec.luau fails the run; Signal without setErrorReporter -> clear load failure; a StyLua-wrapped require and a string containing require(x) -> place check PASS"
  - "review: 27 independent-review findings reproduced and fixed (MockEnv scheduler, WaitForChild/ChildAdded, datatypes, DataStore budgets, require policy + tokenizer, Loader registry:destroy, GameEvents type re-exports, runner late errors, ownership in team.md, interfaces 0.3.1 + D-017, Workspace mapping left to FL-0044, .gitattributes, CI actions v6 / pinned selene asset / artifact file name / change filter); the new specs fail on the pre-fix code"
  - "pytest tools/tests 32 passed; forge.py validate 45 tasks 0 errors; actionlint 1.7.12 with shellcheck: ci.yml clean; shellcheck clean on roblox/scripts/*.sh; luau-analyze strict: Contracts + Core clean with the new solver (old solver: one pre-existing pcall arity note in Env.luau; Roblox globals unknown to the analyzer)"
  - "unverified: Studio S1-S3 incl. @game in live Studio (G6); CI has never run on GitHub (actions v6, change filter, release downloads); selene asset name checked in its release workflow only; bash 3.2 and Windows paths not run on those systems (simulated)"
  - "FORGE-05 integration 2026-10-12: merged PR #1 as merge commit f9e9b0a. PR CI run 38209213389 green on head 26fbf66. Merge result (head + main 798b94d) check.sh OVERALL PASS: Lune 179 passed 0 failed 16 files, Selene 0 errors, StyLua 69 files, Rojo build, place check PASS; pytest 32 passed; forge validate 45 tasks 0 errors. Negative gates re-run independently by FORGE-05 (failing spec, broken @game require, unformatted file: each exit 1)."
  - "CI on main: https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38295342210 green (roblox + tools); artifact forgeloop-main-f9e9b0a uploaded, place check --require-stamp: BuildInfo stamped f9e9b0ad71a4."
  - "#1 f9e9b0a; integration-log.md"
---

# Shared Roblox skeleton: contracts, loader, harness, mocks, checks, CI

## Outcome
Workers start from a green skeleton: Rojo project, Contracts (Env, Loader, GameEvents, Types), Core/Signal, Lune test harness + Roblox mocks, place-structure check, check.sh, CI workflow, Studio smoke test plan.

## Requirements
- Implements docs/architecture/interfaces.md sections 1-4 and 11
- Gates proven able to fail (negative tests)
- Hand over to FORGE-05 (FL-0028)

## Validation
bash roblox/scripts/check.sh (Lune tests, Selene, StyLua, Rojo build, place check); negative tests; CI run on GitHub

## Completion criteria
- [ ] check.sh green
- [ ] Adversarial review findings fixed or answered
- [ ] CI workflow green on GitHub

## Log
- 2026-10-12 forge-00: created (BUILDING).
- 2026-10-12 forge-00: BUILDING → TESTING. Skeleton implemented (contracts v0.3 §1-§4, §11; harness, mocks, place check, check.sh, CI); running gates and negative tests.
- 2026-10-12 forge-00: TESTING → REVIEW. check.sh green from any cwd; each gate proven able to fail; uncommitted in worktree forge/00-skeleton (base 2cd819b). G6 Studio S1-S3 and CI-on-GitHub pending; hand-over to FORGE-05 (FL-0028).
- 2026-10-12 forge-00: review round: 27 findings from independent reviewers reproduced and fixed; check.sh green; three negative gates re-run; stays REVIEW (G6 Studio S1-S3 and CI on GitHub pending).
- 2026-10-12 forge-05: merged PR #1 (f9e9b0a) after green PR CI, merge-result checks and three negative gates; CI green on main with stamped artifact. Stays REVIEW: G6 pending (Studio S1-S3, FL-0036). ACCEPTED after the user's S1 pass.
- 2026-10-13 forge-05: REVIEW → REVIEW. REVIEW, only G6 pending (FORGE-05 acceptance record, D-038 (5); --force because the status stays REVIEW): merged code passed check.sh on the merge result and CI on main; the user's Studio run (G6) is the only gate left.
