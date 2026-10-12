---
id: FL-0053
title: Ruler third-person controller, camera and input modes
track: build
owner: forge-04
status: READY
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-12
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence: []
---

# Ruler third-person controller, camera and input modes

## Outcome
The ruler feels good to control on PC and phone (VS-1 row 2).

## Requirements
- `RulerController`: third-person movement on PC and phone (the default thumbstick on touch), sprint, smooth turning.
- `RulerCameraController`: `follow` mode (zoom range and shoulder offset tuned for overseeing the kingdom) and `overview` mode, switched with `setMode` (G4.1).
- `InputModeController`: `explore` | `build`, with `.changed`. Each mode has one owner for taps and clicks: explore gathers or inspects, build places. `command` mode is VS-2.
- No ruler look here: KingdomService attaches `Kit.regalia` at spawn (FL-0048).

## Validation
- Lune specs for input-mode arbitration and camera mode state.
- Studio on PC and the phone emulator.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): moved from forge-01 to forge-04 (D-028); input modes added; ruler look moved to FL-0048/FL-0056
