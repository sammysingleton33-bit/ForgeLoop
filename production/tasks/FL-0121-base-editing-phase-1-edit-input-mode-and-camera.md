---
id: FL-0121
title: Base editing phase 1, input and camera: "edit" input mode and edit-drag camera (B16)
track: build
owner: forge-04
status: TESTING
priority: P1
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0119, FL-0090, FL-0053]
evidence:
  - InputMode.spec 18/18; RulerCamera.spec 35/35; mutations.py FL-0121 11/11 CAUGHT; Studio E12 unverified (blocked until FL-0119/FL-0120)
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
