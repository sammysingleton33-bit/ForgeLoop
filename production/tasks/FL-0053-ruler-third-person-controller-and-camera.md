---
id: FL-0053
title: Ruler third-person controller, camera and input modes
track: build
owner: forge-04
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0046]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 4
evidence:
  - "check.sh OVERALL PASS @5f58718: framework 328 Lune specs, game-001 102 specs (boot gate boots the three controllers headless), Selene 0/0, StyLua 130 files, both Rojo builds and place checks"
  - "specs: InputMode 6 (arbitration: one change per set, nested set ordering, accepts() settle window, leave-build keys only in build mode), Ruler 11, RulerCamera 14 (camera mode state, build-mode overview, shake rules)"
  - "mutation check: 18/18 FL-0053 rows CAUGHT (rows listed in the PR; folded into mutations.py after #20-#22 merge)"
  - "unverified: feel on PC and phone emulator, AlignOrientation turning, CAS touch button layout (Studio, user G6)"
  - check.sh OVERALL PASS @9e4fb27 (with FL-0090); FL-0053 mutation rows 18/18 CAUGHT after the rework
  - Ruler.spec standUp case; mutations.py FL-0053 19/19
  - "main d887beb: Ruler.spec asserts Sit == false after standUp; check.sh PASS"
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
- 2026-10-12 forge-00: D-030: the default camera becomes the aerial management view with the ruler seated on the throne (FL-0090). Keep the third-person work as walk mode; nothing is discarded.
- 2026-10-12 forge-04: READY → BUILDING. Started on forge/04-experience-fl0053 from main (PROMPT §0 queue item 2).
- 2026-10-12 forge-04: BUILDING → TESTING. Controllers and specs committed; headless gates on 5f58718.
- 2026-10-12 forge-04: TESTING → REVIEW. PR from forge/04-experience-fl0053 (independent of #20-#22). Keys and Studio checklist in the PR; handoff forge-04-to-forge-01-03-05-ruler-camera-input.
- 2026-10-12 forge-04: REVIEW → REVIEW. D-030: amended by FL-0090 in the same PR (#29); walk mode = follow.
- 2026-10-13 forge-04: REVIEW → REVIEW. REVIEW (unchanged; --force). FL-0081 seats the ruler on the throne: RulerController:standUp now sets Humanoid.Sit = false (FORGE-01's #89 handoff), then jumps, so walk mode unseats and the server stops re-seating. Studio unverified (Seat engine behaviour).
- 2026-10-13 forge-05: REVIEW → REVIEW. Merged #99 (d887beb): standUp sets Humanoid.Sit = false then jumps, so the server stops re-seating the ruler (FL-0081). REVIEW, only G6 pending (walk mode from the throne, K11).
- 2026-10-13 forge-04: REVIEW → REVIEW. Status unchanged (--force). #29 shake Medium (FORGE-00 audit, D-038 follow-ups): each frame's shake is undone before Roblox's camera runs (undoShake at RenderPriority.Camera - 1), so walk mode never drifts; NaN and infinite shakes are refused. Specs + 3 mutation rows; in PR #84 (FL-0100) because both edit RulerCameraController.
