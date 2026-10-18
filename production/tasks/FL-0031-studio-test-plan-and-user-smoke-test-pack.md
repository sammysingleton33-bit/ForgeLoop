---
id: FL-0031
title: Studio test plan and user smoke-test pack
track: qa
owner: forge-05
status: REVIEW
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0003]
estimate_h: 2
evidence:
  - roblox/STUDIO_TEST_PLAN.md; games/game-001/STUDIO_PLAYTEST.md (d877f45)
  - main CI green on 378a671 (run 38448212649)
---

# Studio test plan and user smoke-test pack

## Outcome
The user can verify the integrated build in Studio in minutes: Rojo plugin connect, S1 require-by-string, S2 BuildInfo, S3 services start, then links to each worker's roblox/studio-tests/<area>.md.

## Requirements
- Exact steps and expected results; the user pastes results (Output log + BuildInfo sha) into the FORGE-05 chat and FORGE-05 records them in production/quality-gates/studio-runs.md

## Validation
Dry-run the steps against the built place file structure

## Completion criteria
- [ ] User completes S1-S3 (FL-0036)

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-00: D-030: the S1 boot check can run on the current main build now (empty world plus debug panel), which confirms require-by-string in live Studio.
- 2026-10-13 forge-05: READY → BUILDING. Plan exists: roblox/STUDIO_TEST_PLAN.md (S1-S3) and games/game-001/STUDIO_PLAYTEST.md (VS-1, refreshed to B6).
- 2026-10-13 forge-05: BUILDING → REVIEW. REVIEW, only G6 pending: the user runs S1-S3 (FL-0036). Known gap: STUDIO_TEST_PLAN.md links assets.md, which does not exist yet (FORGE-02 asked by FORGE-00 to add it).
- 2026-10-13 forge-05: REVIEW → REVIEW. D-046 at-merge record: no PR of its own. The plan is on main: roblox/STUDIO_TEST_PLAN.md (S1-S3; from FL-0003, revised in 443d257) and games/game-001/STUDIO_PLAYTEST.md (VS-1; #7 9ba7283, rows 1-9 #35 51ebfb3, kept current per merge, Mac keys 378a671). REVIEW, only G6 pending (the user runs S1-S3, FL-0036).
