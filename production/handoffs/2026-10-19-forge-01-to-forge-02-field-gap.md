# Handoff: FORGE-01 → FORGE-00, FORGE-02 · crop fields keep 3 studs free of buildings (farm fences) · 2026-10-19

FORGE-02's farm fences (#274) stand 2.4 studs outside a crop field with a solid collider. `Simulation:_geometry` refused only the field itself (gap 0), so a house or a wall could be placed over a fence.

## What changed
- `Kingdom/Layout`: each crop field in the no-build list (`reservedAreas`) carries `gap = 3` (the fence offset 2.4 plus the collider). `Simulation:_geometry` keeps `area.gap or 0` studs of free ground from every no-build area; roads and spawn pads stay at 0. `Sim/Footprint.Shape` gains an optional `gap`.
- The area itself is still the field (the list's size, `Layout.reservedAreas`, `keepOutAreas` and node placement are unchanged), so generated trees and rocks, the plots' build slots and the starting buildings do not move.
- Spec `sim/NoBuildAreas`: on all 12 fields, 4 sides and 4 kingdoms, no house is accepted 0.5, 1.5 or 2.5 studs outside a field (before the gap, 4 of these spots took a house). `FENCE-GAP.py`: 3 of 3 rows caught.

## Evidence (headless only)
`sim/NoBuildAreas` 9/0, `sim/BuildingMove`, `Simulation`, `RulerAI`, `Footprint`, `Layout`, `Fit` and `Slots` specs pass; StyLua clean; Selene 0 warnings. The full `check.sh` runs on the PR.

## Open
- FORGE-00's own spot (the crimson wall at (-386.8, -336.9) next to `farm_fence_02`) is refused (`blocked`) on main already in my tree for every yaw I tried (0, 45, 90), probably because of another blocker there; the sampled ring around all 12 fields is the evidence, not that spot.
- A building that sat 0-3 studs from a field before this change is not removed: only new placements and moves are refused.
