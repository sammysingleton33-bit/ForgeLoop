---
id: FL-0028
title: "Own the skeleton: CI green on GitHub, harness and mocks upkeep"
track: qa
owner: forge-05
status: ACCEPTED
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0003]
estimate_h: 3
evidence:
  - "main CI run 38448920626 green on cac9522 (https://github.com/sammysingleton33-bit/ForgeLoop/actions/runs/38448920626); check.sh OVERALL PASS locally on main 13acf26 + #113 (framework 517/0, game-001 1220/0)"
  - main CI run 38448920626 green (cac9522)
---

# Own the skeleton: CI green on GitHub, harness and mocks upkeep

## Outcome
FORGE-05 takes custody of the skeleton (FL-0003), gets .github/workflows/ci.yml green on GitHub, and serves workers harness/mock requests.

## Requirements
- Fix anything CI reveals that local runs did not
- Mocks stay faithful to Roblox semantics (cite docs)

## Validation
CI run link on main; check.sh green locally

## Completion criteria
- [x] CI green
- [x] Mock change log in docs/lessons-learned/integration.md

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-05: READY → BUILDING. Skeleton merged (PR #1, f9e9b0a); FORGE-05 takes custody. CI green on main (run 38295342210). Next: Workspace map mapping + place-check tag assertions, ownership job.
- 2026-10-13 forge-05: BUILDING → REVIEW. Skeleton custody since PR #1: CI green on main throughout (ownership, tools, roblox jobs), harness and mock requests served (#116 per-folder game specs, #120 EngineStubs in MockEnv); mock change log kept in docs/lessons-learned/integration.md (now through #120).
- 2026-10-13 forge-05: REVIEW → ACCEPTED. D-046 audit: no Studio gate; completion criteria met (CI green on main; mock change log in docs/lessons-learned/integration.md). FORGE-00 asked for this move (18:31).
