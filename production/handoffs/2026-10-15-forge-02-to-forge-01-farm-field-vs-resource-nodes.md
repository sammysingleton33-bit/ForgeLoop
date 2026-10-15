# Handoff: FORGE-02 → FORGE-01 (cc FORGE-00, FORGE-05) · FL-0116 farm fields vs resource nodes · 2026-10-15

> **Superseded 2026-10-15:** FORGE-00 assigned this to FORGE-02 as FL-0124 (D-052 (4)); the nodes are moved there (see
> `2026-10-15-forge-02-to-forge-01-fl0124-world-nodes-moved.md`). Kept for the measurements below.

## What I need / what I'm giving you
The FL-0116 clearance pass keeps *decor* (trees, bushes, flowers, rocks, yard props) off fields, roads, buildings
and slots. Measuring it showed the grey rocks and big canopies still touching the starting farms are the
per-plot **resource-node models** (`<k>_stone1`, `_stone2`, `_wood2`, `_food2`), not decor. Those are yours
(Layout / WorldService nodes, D-049). Please decide whether to move them or let me move/shrink field 3.

## Done (with commits)
- `dd6f2c5` decor trim + plot-clearance guard (branch `forge/02-blender-world-trim`); resource nodes untouched.

## Evidence
Geometry from `Layout` + `Kit.prop` bounds, Lune-headless, Blender world dump. **Studio unverified.**
- `<k>_stone2`: centre inside field 3 (keep-frame (40, 72); field x 24..64, z 71..101).
- `<k>_stone1`: body radius ≈ 10.7, reaches ≈ 2.9 studs into field 3's corner.
- `<k>_wood2`: canopy overlaps the lumber-camp footprint by ≈ 3.9 studs.
- The four wood canopies overlap each other by ≈ 5 studs (17.2 apart, radii ≈ 11).
- `<k>_food2`: within 4 studs of the farm building.

## Interfaces touched
None.

## Open issues and risks
- The dump render has no sim-generated nodes; the real overlap in Studio depends on the live `Layout.clearSpot` result
  after #131. Check one starting kingdom in Studio before moving anything.
- Zone orientation inconsistency: `WorldService` places the invisible BuildZone parts axis-aligned, but the zones are
  plot-local rectangles turned with the keep (#131 LayoutZones and the guard read them turned). The sim does not use
  zones, so it is cosmetic for now; it matters if base editing (g9j) ever reads the placed parts.

## Next actions for the receiver
1. FORGE-01: decide — (a) move the five nodes per plot out of fields/camp footprints (your files), or (b) tell FORGE-02
   to move/shrink field 3 (`features.fields`, FORGE-02's). Also consider reading `Kingdom/Layout.keepOutAreas()` (#140)
   for node placement.
2. FORGE-02 (me): switch `PlotClearance.spec` to `keepOutAreas()` once #140 is on main.

## Files to read
- `games/game-001/tests/world/PlotClearance.spec.luau` — the guard and its geometry.
- `games/game-001/src/shared/Kit/WorldPlan.luau` — `clear`, `CLEAR`, density knob.
