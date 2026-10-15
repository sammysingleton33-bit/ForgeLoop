---
id: FL-0114
title: Rotation UI: ghost facing arrow, discoverable Rotate, plot picker Turn (B15 #2)
track: build
owner: forge-03
status: BUILDING
priority: P0
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0113, FL-0087, FL-0059]
evidence: []
---

# Rotation UI: ghost facing arrow, discoverable Rotate, plot picker Turn (B15 #2)

## Outcome
The player sees which way a building will face before placing, can rotate it with R, the Rotate button or gamepad Y, and can turn it on a plot slot using only the turns that fit.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- FORGE-03 B1 (ghost facing arrow, Rotate button shows the facing, gamepad Y) and B2 (picker Turn against `Build.PlaceSlot` turn, g9h).

## Requirements
- B1: the facing arrow on the ghost, a Rotate button that shows the facing, gamepad Y, and a clear hint.
- B2: the plot picker Turn offers only `Fit.fits(type, size, turn)` turns; the ghost shows the facing.
- Every new refusal reason is mapped (FL-0105 pattern).

## Validation
Automated: specs and mutations; renders at three screen sizes looked at. Studio: B15 checklist rotation rows.

## Completion criteria
- [ ] PR(s) merged after review.
- [ ] Studio evidence (G6).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
