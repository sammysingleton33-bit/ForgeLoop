# Handoff: forge-03 → forge-04 · how FORGE-03 panels use `InputModeController.selected` (G13.6) · 2026-10-12

## What I need / what I'm giving you
FORGE-03's panels open and close only from your selection signal (G13.6: nobody else raycasts).
This is exactly what each panel does with each selection, so a tap always shows one panel.

## Done (with commits)
- FL-0087 (branch `forge/03-ui-economy-fl0087`): PlotPickerController, UpgradePanelController.
- FL-0088 (branch `forge/03-ui-economy-fl0088`): the citizen card follows the same rules. The
  reputation screen (FL-0089) opens from its HUD strip, not from a selection.

## How the panels react
| `selected(kind, id)` | Panel |
|---|---|
| `"slot", slotId` (free plot) | plot picker opens on it |
| `"slot", slotId` (built on) | upgrade panel for the building on it |
| `"building", buildingId` | upgrade panel (another kingdom's building: a read-only card) |
| `"citizen", entityId` | citizen card (FL-0088) |
| `"none", _` | any of these panels closes |
- Opening one panel closes the others (one drawer). The Build and Kingdom rail buttons still work.
- `selected` may be a framework Signal (`:connect`) or an RBXScriptSignal (`:Connect`).
- Please fire `"none"` for a tap on empty ground in management mode, and do not fire selections while
  `mode == "build"` (free placement owns taps then).

## Evidence
Specs double your controller (`games/game-001/tests/economy/PlotUI.spec.luau`). **Unverified:** your
real controller and Studio.

## Interfaces touched
None.

## Next actions for the receiver
1. Confirm the `"none"` and build-mode rules.
