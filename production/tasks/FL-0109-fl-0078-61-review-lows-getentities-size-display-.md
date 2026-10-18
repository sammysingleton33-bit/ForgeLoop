---
id: FL-0109
title: "FL-0078 #61 review lows: GetEntities size, display names, look key, quota revision"
track: build
owner: forge-01
status: REVIEW
priority: P2
game: game-001
created: 2026-10-13
updated: 2026-10-13
depends_on: [FL-0078]
evidence:
  - "check.sh OVERALL PASS (game-001 1231/0, framework 517/0) on main d65fb2e1 + branch; EntityService.spec 17/0, EntityController.spec 28/0, CitizenService.spec 14/0; mutations 14/15 caught (the survivor was equivalent: a redundant sort, removed)"
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
- 2026-10-13 forge-01: SPECIFIED → BUILDING. --force: SPECIFIED -> BUILDING; its only dependency FL-0078 is merged and FORGE-00 created it for FORGE-01 (866d62da, D-046 audit). Four #61/#71 lows: Sim.GetEntities paged into <= 900 B pages, CitizenView relation ids beside names, only the validated CitizenLook on the wire, quotaRev on Kingdom state for co-ruler job panels.
- 2026-10-13 forge-01: BUILDING → REVIEW. All four #61/#71 lows fixed: (1) Sim.GetEntities(afterId?) -> (buffer, nextAfterId?) pages of <= 49 full records (888 B <= 900 B), cursor validated, rate burst 24 / 6 per s; EntityController reads every page and re-asks an unanswered one; (2) CitizenView familyIds/friendIds/rivalIds beside the names; (3) only Kit.normalizeLook looks on the wire (spawn, full, Sim.Inspect); (4) quotaRev on Kingdom.Population, +1 per accepted quota change (also same-number and setJob), in the push signature. CONTRACTS text proposed in handoff 2026-10-13-forge-01-to-forge-00-03-05-review-lows (CONTRACTS.md is FORGE-00's).
