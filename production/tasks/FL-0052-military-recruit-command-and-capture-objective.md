---
id: FL-0052
title: "Military: recruit, command and capture objective"
track: build
owner: forge-01
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0049, FL-0051]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 8
evidence: []
---

# Military: recruit, command and capture objective

## Outcome
Players recruit soldiers and send them to capture the neutral Watchtower for territory and Crown Points (VS-1 row 7; CONTRACTS G8).

## Requirements
- MilitaryService recruit (barracks, treasury spend) and command (move/attack/capture/guard); soldiers are entities
- ObjectiveService capture rules (exclusive presence, progress, award territory and crown points); Army.* remotes validated and rate-limited
- Fires UnitsRecruited and ObjectiveCaptured

## Validation
Lune specs: recruit costs, command validation (ownership, max 50 ids), capture progress/contest/reset; Studio: recruit 3 and capture

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
