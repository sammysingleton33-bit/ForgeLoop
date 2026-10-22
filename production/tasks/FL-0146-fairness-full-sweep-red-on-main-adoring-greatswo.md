---
id: FL-0146
title: "Fairness full sweep red on main: Adoring greatsword noAutoWin and supportMatters"
track: build
owner: forge-01
status: READY
priority: P1
game: game-001
created: 2026-10-22
updated: 2026-10-22
depends_on: []
evidence: []
---

# Fairness full sweep red on main: Adoring greatsword noAutoWin and supportMatters

## Outcome
The full fairness sweep (152 cells × 2000 duels) is green on main again, with the G12.3 bounds unchanged.

## Context
- FORGE-01's full sweep on main ac3fa4da (2026-10-22) fails 10 checks:
  - supportMatters ×3 (65.9 / 66.8 / 67.3);
  - the Adoring greatsword cells at noAutoWin 70.5–73.1 %, against the 70 % bound.
- #250 passed the full sweep at a 68.3 % max (10:44 ruling on 19 Oct). First suspect for the move: #272 (DuelDouble `impactAt`).
- FORGE-07 attributes the cause. FORGE-01 owns the balance fix (config Duel and Support, DuelModel).

## Requirements
- Attribute the cause, with one full run per suspect.
- Make the smallest balance trim that brings every cell inside the bounds.
- Called Warning's empowered uses = 3 is re-tried after this.

## Validation
- Automated: the full sweep is green, and the quick gate is green.

## Completion criteria
- [ ] PR merged before the B23 RC.

## Log
- 2026-10-22 FORGE-00: created.
