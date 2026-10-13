---
id: FL-0109
title: "FL-0078 #61 review lows: GetEntities size, display names, look key, quota revision"
track: build
owner: forge-01
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0078]
evidence: []
---

# FL-0078 #61 review lows: GetEntities size, display names, look key, quota revision

## Outcome
The four low findings from FORGE-05's #61 review (and #71) are fixed. Large kingdoms replicate within the G4 budget, the UI matches citizens by id rather than name, only validated looks travel, and a co-ruler's job panel refreshes when quotas change.

## Context
- FORGE-05's #61 review lows and the #71 low, tracked here so they are not only logged (audit 2026-10-13, FL-0078 row).
- Draft by FORGE-01; FORGE-00 owns `production/tasks/`.

## Requirements
1. **`Sim.GetEntities` exceeds 900 B at 50+ entities (G4).** Chunk the full state, or serve it from the reliable spawn path.
2. **Ids alongside names.** `CitizenView` friends, family and rivals carry entity ids next to display names, so the UI never matches on names.
3. **Validated look on the wire.** Send only the validated `CitizenLook`, never the raw look key.
4. **`quotaRev`.** Bump a revision on co-ruler quota changes so every co-ruler's job panel refreshes (#71 low).

## Validation
Automated: one Lune spec per item, plus mutation rows; `bash roblox/scripts/check.sh`.

## Completion criteria
- [ ] Four items fixed, each with a spec.
- [ ] A review verdict on the PR. It is not ★; FORGE-07 reviews it.

## Log
