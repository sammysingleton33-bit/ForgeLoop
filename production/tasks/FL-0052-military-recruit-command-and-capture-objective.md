---
id: FL-0052
title: "Military: recruit, command and capture objective"
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-12
updated: 2026-10-13
depends_on: [FL-0049, FL-0051, FL-0055]
context: [games/game-001/BRIEF.md, games/game-001/CONTRACTS.md]
estimate_h: 6
evidence:
  - check.sh OVERALL PASS (game-001 864/0); Military.spec +10, MilitaryService.spec 8; 14/14 mutations caught
---

# Military: recruit, command and capture objective

## Outcome
Players recruit soldiers and send them to capture the neutral Watchtower for territory and Crown Points (VS-1 row 7; CONTRACTS G8).

## Requirements
- MilitaryService:
  - recruit: at a barracks, paid with `Costs.unit` via `TreasuryService:spend`; units appear at the barracks `Rally`;
  - command: move, attack, capture or guard; empty `unitIds` means all of my kingdom's idle soldiers;
  - soldiers are entities.
- VS-1 command path: the Send-to-capture button in FORGE-03's army panel sends `Army.Command(kind = "capture", targetId)`. Free selection and target picking (the Command and Selection controllers) are VS-2.
- ObjectiveService:
  - builds the objectives from `Layout.objectives` with `Kit.build("watchtower", 1, "complete", Kit.NEUTRAL_COLOR)`;
  - capture rules: exclusive presence, progress, contest, reset;
  - on capture: recolours via `Kit.setKingdomColor`, claims `regionId`, adds Crown Points.
- Remotes `Army.Recruit`, `Army.Command` and `Army.Objectives` / `Army.GetObjectives`, validated and rate-limited (G8).
- Fires UnitsRecruited and ObjectiveCaptured.

## Validation
- Lune specs: recruit costs and the rally spawn; command validation (ownership, max 50 ids, empty = all idle); capture progress, contest and reset; recolour and claim.
- Studio: recruit 3, press Send-to-capture, capture.

## Completion criteria
- [ ] Studio evidence (user playtest per games/game-001/STUDIO_PLAYTEST.md, BuildInfo sha + screenshots) before ACCEPTED

## Log
- 2026-10-12 forge-00: created for AI Kingdoms VS-1 (READY).
- 2026-10-12 forge-00: plan review fixes (CONTRACTS v0.4-g2, D-024 to D-028): Send-to-capture (selection to VS-2), objective built from Layout with neutral Kit colour, Rally, Costs.unit
- 2026-10-13 forge-01: READY → BUILDING. Army remotes, MilitaryService, ObjectiveService
- 2026-10-13 forge-01: BUILDING → REVIEW. Recruit at a barracks (Rally spawn), UnitOrder move/attack/capture/guard (empty = idle, max 50, own units), ObjectiveService (Kit watchtower, recolour, broadcast), Army.* remotes
