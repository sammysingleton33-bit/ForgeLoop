---
id: FL-0121
title: Base editing phase 1, input and camera: "edit" input mode and edit-drag camera (B16)
track: build
owner: forge-04
status: REVIEW
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0119, FL-0090, FL-0053]
evidence:
  - InputMode.spec 18/18; RulerCamera.spec 35/35; mutations.py FL-0121 11/11 CAUGHT; Studio E12 unverified (blocked until FL-0119/FL-0120)
  - check.sh OVERALL PASS @12df398 (lune 517/0, game-001 1346/0, Selene 0/0); InputMode 18/18, RulerCamera 35/35; mutations FL-0121 11/11, FL-0053 22/22, FL-0090 16/16, FL-0115 23/23; Studio E12 unverified (needs FL-0119/FL-0120)
  - "RulerCamera.spec 35/35 (new: a selection never moves the camera in edit mode; fails on main's controller); mutations FL-0121 10/10, FL-0053 30/30, FL-0090 16/16, FL-0100 33/33 CAUGHT; Studio E12 unverified (needs #140 and #148)"
---

# Base editing phase 1, input and camera: "edit" input mode and edit-drag camera (B16)

## Outcome
While editing the base, taps select only the player's own buildings (and free slots as targets), the aerial camera stays put, and dragging a building edge-pans instead of panning the camera.

## Context
- User feedback record: `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049 (B15/B16 cycle).
- CONTRACTS G13.9 (G4.1 edit mode); the handoff `2026-10-15-forge-00-to-forge-01-03-04-base-editing.md`.

## Requirements
- InputModeController mode "edit".
- RulerCameraController keeps the overview in edit, and adds `setEditDrag(active)` (drag-pan off, edge-pan on) and focusOn the selected building.

## Validation
Automated: InputMode and RulerCamera specs, mutations. Studio: the B16 checklist.

## Completion criteria
- [ ] PR merged after review.
- [ ] Studio evidence (G6).

## Log
- 2026-10-15 FORGE-00: created from the user's first live Studio feedback (record `production/handoffs/2026-10-13-forge-00-to-all-first-studio-feedback.md`; D-049).
- 2026-10-15 forge-04: SPECIFIED → BUILDING. Started on forge/04-experience-fl0121, stacked on #137 (hover; FORGE-00's order #133 -> hover -> FL-0121), building against CONTRACTS G13.9 v0.4-g9j while FL-0119/FL-0120 land
- 2026-10-15 forge-04: BUILDING → TESTING. InputModeController mode edit (own buildings and own plots only; X/B leave; entering clears the selection) and RulerCameraController (overview kept in edit; setEditDrag: drag-pan off, edge-pan on within 48 px; selecting your building in edit pans to it); Studio E12; handoff forge-04-to-forge-03-01-edit-mode-input-camera
- 2026-10-15 forge-04: TESTING → REVIEW. PR #142 (from main; #137 merged): edit mode, own-only taps, edit-drag camera, edge-pan, focus on select. Older FL-0053/FL-0090 rows retargeted to edit mode's lines.
- 2026-10-15 forge-04: REVIEW → REVIEW. B17 follow-up (D-052 (1), FORGE-05's #142 gate): E12 rewritten to the Move flow that ships (Move -> ghost -> confirm; taps aim the ghost; X/B/Q/Cancel end it), drag and edge-pan rows parked (FL-0123). A selection in edit mode no longer pans the camera: mid-move a tap aims the ghost (FORGE-07's #148 B1 side effect); _onSelected and Def.findBuilding removed. #142 L4: the Q/E header comment (Q cancels, R turns). #142 L1: evidence counts at the merged head 01ef6dc were InputMode 22/22, FL-0053 30/30 (PR body corrected). M1 (touch edit-drag spec) rides FL-0123.
