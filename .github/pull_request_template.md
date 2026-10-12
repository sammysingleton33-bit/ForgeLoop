<!-- Title: [FORGE-0N] FL-00xx <summary>   (or [CODEX] ...). The ownership check reads this prefix. -->

## Tasks
FL-00xx (status after this PR: REVIEW / ACCEPTED)

## What changed
- 

## Evidence (exact commands and results)
- `bash roblox/scripts/check.sh` → OVERALL PASS (Lune N passed / 0 failed, Selene 0, StyLua N files, map gen, Rojo build, place check)
- `python -m pytest -q tools/tests` → N passed
- `python tools/forge.py validate` → N tasks, 0 errors
- `python tools/check_ownership.py --base origin/main` → PASS
- Negative test (each new gate/spec proven able to fail): 

## Unverified
- (anything not run: Studio behaviour, visuals, real DataStores/purchases, multiplayer)

## Studio steps
- `roblox/studio-tests/<area>.md` section …, or "none"

## Contract changes
none / additive (list) / breaking (DECISIONS.md entry: D-0xx)

- [ ] Only my paths (`docs/workflows/team.md`; exceptions in `production/quality-gates/ownership.json`)
- Stacked on: none / #N
