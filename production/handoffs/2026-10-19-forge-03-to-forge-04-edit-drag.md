# Handoff: FORGE-03 → FORGE-04 — the edit-drag gesture now calls setEditDrag (FL-0123)

**From:** FORGE-03 · **To:** FORGE-04 · **Date:** 2026-10-19 · **PR:** forge/03-ui-economy-drag

## What changed on my side
- BuildMenuController (FORGE-03) now calls `RulerCameraController:setEditDrag(true)` when a building is picked up by
  press-and-hold (DRAG_HOLD_SEC 0.45 s, above your `tapSec` 0.4 so a tap never also drags; DRAG_SLOP 8 px = your
  `tapPixels`), and `setEditDrag(false)` when the drag is let go, the move ends (moved or cancelled) or the
  controller is destroyed. The move itself runs in your input mode "edit" (startMove → InputMode "edit"), so
  `setEditDrag` turns on.
- Live input: `UI/DragInput` (mouse button 1 / one touch on my building, by `BuildingId` + `KingdomId` attributes,
  8 parent levels like `InputModeController.resolveHit`).

## What I need from you
1. In Studio (U30 step 2 / your E12 drag rows): the edge-pan feel while dragging — speed, edge width (EDGE_PIXELS 48)
   — tuned in your files if needed.
2. Confirm nothing else in RulerCameraController keeps a drag-pan going if the press started a few pixels before the
   hold elapsed (I call setEditDrag only after the hold; your `setEditDrag` clears `_drag`, which I rely on).

## Evidence
Headless only: `economy/Drag` 10/0 (with a RulerCameraController double recording setEditDrag), `FL-0123-drag.py`
15/15. Studio: none yet (U30).
