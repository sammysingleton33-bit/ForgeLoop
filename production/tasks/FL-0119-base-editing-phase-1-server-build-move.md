---
id: FL-0119
title: "Base editing phase 1, server: Build.CanMove / Move / MoveToSlot, atomic in-place moves (CONTRACTS G13.9, B16)"
track: build
owner: forge-01
status: REVIEW
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0113, FL-0051]
evidence:
  - "bash roblox/scripts/check.sh at d8c0e80c: OVERALL PASS (Lune 517/0; game-001 specs 1390 passed, 0 failed, 88 files); roblox/tests/unit/gameplay/mutations.py FL-0119: 44/44 CAUGHT; forge.py validate 122 tasks 0 errors; check_ownership PASS. Headless only: unverified in Studio."
---

# Base editing phase 1, server: Build.CanMove / Move / MoveToSlot, atomic in-place moves (CONTRACTS G13.9, B16)

## Outcome
A ruler can move one of their own buildings (any except the keep) to free ground or onto a free slot, turned as they like. Everything about the building is preserved, and nothing can be duplicated, refunded or reset.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- CONTRACTS G13.9 v0.4-g9i (rules), D-049 (defaults).
- Design: `production/handoffs/2026-10-15-forge-00-to-forge-01-03-04-base-editing.md` (state inventory, exploit table, spec list; from a code investigation of Simulation, CitizenActions, Military, Nav and BuildingService).
- Rebase after the open FORGE-01 PRs that touch Simulation and Commands (#127, #125, #100).

## Requirements
- A one-command, in-place move: same id and record. It never calls placeBuilding, cancelConstruction or _removeBuilding, never charges or refunds, and never re-emits BuildingPlaced.
- Validation = Build.Place geometry ignoring itself; skip limits, keep level and cost.
- Refusals: not_found, not_owner, not_movable (keep), alarm, under_attack, cooldown (`Buildings.moveCooldown` 2 s), plus the placement and slot reasons.
- Citizens working, building or resting at it go back to Go, with claims kept.
- Barracks keep their queue; new recruits use the new Rally.
- Move clears slotId; MoveToSlot sets it in the same command.
- The Build.Buildings signature gains x|z|yaw; WorldView re-pivots without a rebuild.
- G9 BuildingMoved.
- Objective-zone placement rule for Place, PlaceSlot and Move.

## Validation
Automated: tests/sim/BuildingMove.spec.luau (the 13 cases in the handoff), BuildingService remote and fuzz specs, the WorldView re-pivot spec, determinism; mutation rows for every exploit rule. Studio: the B16 checklist (move a site mid-build, a farm with workers, a barracks with a queue, a slot re-turn, refusals).

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (G6).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
- 2026-10-15 forge-01: READY → BUILDING. Started: Sim canMove/moveBuilding + Commands.MoveBuilding, Build.CanMove/Move/MoveToSlot, broadcast signature + WorldView re-pivot, BuildingMoved, objective-zone placement rule (R13), moveCooldown; specs BuildingMove (13 cases) + exploits fuzz + mutation rows. Stacked on #132 (Fit.fits turn).
- 2026-10-15 forge-01: BUILDING → REVIEW. Server side built to CONTRACTS G13.9 v0.4-g9j: in-place MoveBuilding, Build.CanMove/Move/MoveToSlot, keep-circle destinations, per-building under_attack, war/peace lockout, 10 s cooldown, 30 s drop-off settling, no-build areas, soldier/ruler clearance, WorldView re-pivot, BuildingMoved relay. PR from forge/01-gameplay-basemove (stacked on the wallGap PR). Studio + the UI (FL-0120/0121) are not done.
