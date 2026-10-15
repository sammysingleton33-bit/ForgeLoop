---
id: FL-0120
title: Base editing phase 1, UI: Move button, edit-mode ghost, slot snap with Turn (B16)
track: build
owner: forge-03
status: REVIEW
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0119, FL-0114]
evidence:
  - games/game-001/tests/economy/Move.spec.luau 9/0; mutations 21/21; renders in games/game-001/design/ui/REVIEW-placement.md
  - "PR #148: Move.spec 9/0, mutations 21/21, check.sh PASS game-001 1372/0"
---

# Base editing phase 1, UI: Move button, edit-mode ghost, slot snap with Turn (B16)

## Outcome
From a building's panel the player taps Move, drags a ghost (tinted by Build.CanMove), rotates it, snaps to a free slot with Turn, and confirms or cancels. Every refusal is explained.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- CONTRACTS G13.9; the handoff `2026-10-15-forge-00-to-forge-01-03-04-base-editing.md`.
- Reuses Placement.Checker, Ghost, PlacementBar and PlacementInput.
- The flow lives in FORGE-03's existing controllers (UpgradePanel/BuildMenu). A new `BaseEdit*` controller needs FORGE-05 to add it to the ownership rules and team.md first (`tools/check_ownership.py` mirrors team.md).

## Requirements
- Move button in UpgradePanel, hidden on the keep.
- The original stays drawn, dimmed, until the server answers.
- Every new reason code is mapped (not_movable, alarm, under_attack, cooldown).

## Validation
Automated: specs and mutations; renders at three screen sizes. Studio: the B16 checklist.

## Completion criteria
- [ ] PR merged after review.
- [ ] Studio evidence (G6).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
- 2026-10-15 forge-03: SPECIFIED → READY. Contract and server names known (FORGE-01 handoff for #140); building against doubles
- 2026-10-15 forge-03: READY → BUILDING. Move in the building panel, move ghost (CanMove tint, Turn), plot snap with MoveToSlot, dimmed original, cooldown, wording
- 2026-10-15 forge-03: BUILDING → TESTING. Specs, mutations and renders done; Studio after #140
- 2026-10-15 forge-03: TESTING → REVIEW. PR #148 (stacked on #139); dormant until FORGE-01's #140 serves Build.Move
