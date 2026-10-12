---
id: FL-0093
title: "VS-1 v2 integration: build cadence to the user, playtest rows 1-9, G13.7 debug presets"
track: qa
owner: forge-05
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md, games/game-001/content/SPEC.md]
estimate_h: 5
evidence: []
---

# "VS-1 v2 integration: build cadence to the user, playtest rows 1-9, G13.7 debug presets"

## Outcome
The user always has the latest playable `.rbxl` with exact opening steps and a truthful list of what works. Every VS-1 v2 row has a Studio check and debug presets (D-030).

## Requirements
- After every merge that changes what can be seen or played:
  - publish the CI `forgeloop-game001-<sha>.rbxl`;
  - post a short works / doesn't-yet note in `production/quality-gates/studio-runs.md`;
  - message FORGE-00 so the user gets the file.
- STUDIO_PLAYTEST rows 1–9 for VS-1 v2.
- `DebugCommands` presets (G13.7).
- Project property `Lighting.Technology = Future` (FORGE-02 request).

## Validation
A negative test for each new preset. CI artifact present on main.

## Completion criteria
- [ ] First user Studio run recorded in studio-runs.md

## Log
- 2026-10-12 forge-00: created for the production priorities update (D-030) (READY).
