---
id: FL-0113
title: "Build.PlaceSlot turn: rotate buildings on plots, server and Fit (CONTRACTS v0.4-g9h, B15 #2)"
track: build
owner: forge-01
status: REVIEW
priority: P0
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0081]
evidence:
  - "check.sh PASS on the merge (game-001 1313/0); own mutants 6/6; E2E probe with #135: sim yaw = slot.rot + pi/2 exactly, bad turns dropped"
---

# Build.PlaceSlot turn: rotate buildings on plots, server and Fit (CONTRACTS v0.4-g9h, B15 #2)

## Outcome
A ruler can place a building on a plot slot facing any of the four directions that fit. The server validates the turn, and the replicated facing is correct.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- The user's "buildings cannot be rotated": free placement already rotates (R, `Build.Place` rot), but `Build.PlaceSlot` had no rotation, and onboarding steers players to plot slots.
- CONTRACTS G13.5 v0.4-g9h (main 1dbd1fb9). FORGE-03's picker Turn control is FL-0114.

## Requirements
- `Build.PlaceSlot(slotId, type, turn?)` with `turn: integer(0,3)?`; rot = `(slot.rot + turn) % 4`.
- `Fit.fits(type, size, turn?)` swaps the axes for odd turns, else `does_not_fit`.
- Omitted turn = today's behaviour.

## Validation
Automated: specs for omitted turn, half turn always fits, odd turns per the swapped axes, a bad turn is refused, replicated rot; mutations. Studio: B15 checklist rotation rows.

## Completion criteria
- [ ] PR merged after review.
- [ ] Studio evidence (G6).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
- 2026-10-15 forge-05: BUILDING → REVIEW. Merged #132 (f36b1f0), B15 item 2 server; only G6 (a turned building on a real plot) left
