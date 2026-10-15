---
id: FL-0123
title: Base editing, drag gesture: press-and-drag a building with edge-pan (setEditDrag), on top of the Move flow
track: build
owner: forge-03
status: SPECIFIED
priority: P2
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0120, FL-0121]
evidence: []
---

# Base editing, drag gesture: press-and-drag a building with edge-pan (setEditDrag), on top of the Move flow

## Outcome
Besides Move → ghost → confirm, a player can press and drag one of their buildings directly. The camera edge-pans while dragging (FORGE-04's `setEditDrag`).

## Context
- D-052 (1): B17 ships the Move flow; this task is the CoC-style drag on top of it.
- FORGE-04's `RulerCameraController:setEditDrag` and edge-pan exist (#142) but have no caller.
- CONTRACTS G13.9.

## Requirements
- FORGE-03 (owner): the press-and-hold to start a drag (mouse and touch), and calls to `setEditDrag(true/false)`.
- FORGE-04: confirms the edge-pan feel; tunes it in its own files.
- Tapping one's own plot or building mid-move doesn't cancel the move (FORGE-07's #148 finding stays fixed).

## Validation
Automated: specs and mutations. Studio: the E12 drag rows.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (G6).

## Log
- 2026-10-15 FORGE-00: created from FORGE-07's B17 review round (D-052).
