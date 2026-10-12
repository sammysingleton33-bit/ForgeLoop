---
id: FL-0028
title: "Own the skeleton: CI green on GitHub, harness and mocks upkeep"
track: qa
owner: forge-05
status: BUILDING
priority: P0
game: factory
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0003]
estimate_h: 3
evidence: []
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
- [ ] CI green
- [ ] Mock change log in docs/lessons-learned/integration.md

## Log
- 2026-10-12 forge-00: created (READY).
- 2026-10-12 forge-05: READY → BUILDING. Skeleton merged (PR #1, f9e9b0a); FORGE-05 takes custody. CI green on main (run 38295342210). Next: Workspace map mapping + place-check tag assertions, ownership job.
