---
id: FL-0093
title: "VS-1 v2 integration: build cadence to the user, playtest rows 1-9, G13.7 debug presets"
track: qa
owner: forge-05
status: BUILDING
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: []
context: [games/game-001/design/living-kingdom.md, games/game-001/CONTRACTS.md, games/game-001/BRIEF.md]
estimate_h: 5
evidence:
  - "B1: run 38310484338 green, artifact forgeloop-game001-b6f252f id 11774113089; recorded in studio-runs.md"
  - "B2: run 38314053545 green, artifact forgeloop-game001-986c773 id 11776021599"
  - "B3: run 38316514200 green, artifact forgeloop-game001-a0377a1 id 11777330723; delivered by FORGE-00 22:29 UTC"
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
- 2026-10-12 forge-05: READY → BUILDING. Build cadence started: B1 forgeloop-game001-b6f252f (first visible build: world v0 + lighting) sent to FORGE-00 for the user; Lighting.Technology=Future merged (#30). Next: playtest rows 1-9, G13.7 presets (ownership PR #32 first).
- 2026-10-12 forge-05: BUILDING → BUILDING. Evidence update (status unchanged): user builds B2 (986c773) and B3 (a0377a1: F1 slab fixed, citizens via #39, menus keep state) delivered via FORGE-00; G13.5 Costs/Buildings integration spec as draft PR #47 (lands after FORGE-01's alignment). Waiting on the user's first Studio report.
