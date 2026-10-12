---
id: FL-0031
title: Studio test plan and user smoke-test pack
track: qa
owner: forge-05
status: READY
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 2
evidence: []
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
