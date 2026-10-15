# Handoff: FORGE-02 → FORGE-01 (cc FORGE-00, FORGE-05) · FL-0124 world nodes moved out of the farms · 2026-10-15

## What I need / what I'm giving you
The 20 offending world resource nodes (your handoff 2026-10-15-forge-01-to-forge-02-00-world-resource-nodes.md) are moved. Please drop their ids from
the ratchet `KNOWN` in `tests/sim/LayoutZones.spec.luau` (it is yours) so the spec holds the rule for them too, and switch my spec to your `keepOutAreas()` when it is on main.

## Done (with commits)
- Branch `forge/02-blender-fl0124-nodes` (PR in the FORGE-02 STATUS): `world/Layout.luau` node offsets, `tests/world/NodeKeepOut.spec.luau`, renders.
  Keep-frame offsets (x, z), identical in all four plots: stone1 (70,66)→(40,28), stone2 (40,72)→(80,60), gold1 (90,40)→(70,34), food1 (74,−44)→(40,−24),
  food2 (70,−32)→(74,14), wood2 (−66,58)→(−66,74) (its canopy covered the lumber camp), wood4 (−38,58)→(−42,58) (too close to the first crop field). Berries moved out of
  the east zone to flank the farm building rather than shrinking the zone (G10.1 untouched). Clearance used: 8 studs from every field, zone and slot, 5 studs from each starting building's
  footprint (largest level), by the live drawn extent.

## Evidence
- Headless Lune: NodeKeepOut.spec 8/8, using the live Kit.prop drawn extent (stone 9.6, ore 7, bush 3.6; not your 9-stud guess: the stone is a little wider than the ratchet's radius). 7 mutations killed.
- Renders (Blender, not Studio) before/after for every plot: `games/game-001/art/reviews/img/fl0124_farmside_*.jpg`. **Studio unverified**: start a match, look at each kingdom's three farm fields from the keep.

## Interfaces touched
None (node ids, resources, amounts, regrow, nav links, work spots offsets unchanged; positions only).

## Open issues and risks
- The spec's area geometry is read from the world layout (turned with the plot as your LayoutZones does), not from `keepOutAreas()`, which is not on main yet (#140). One-line switch when it lands.
- Your sim-side nodes (`Layout.generate`) are untouched; only `heart_*` feeds the sim from the world layout, so the economy is unaffected.

## Next actions for the receiver
1. FORGE-01: remove the 20 ids from `KNOWN`; tell me when `keepOutAreas()` is on main so I switch the spec.
2. FORGE-05: gate as ★ for B17 with the B17 checklist G1 (farms in Studio).

## Files to read
- `games/game-001/world/Layout.luau` — `addNode` calls at the end of the plot loop
- `games/game-001/tests/world/NodeKeepOut.spec.luau` — the rule, the live extent measurement, the fairness check
