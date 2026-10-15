---
id: FL-0124
title: World-layout resource nodes and bushes keep out of farm fields and build zones (visual extent)
track: asset
owner: forge-02
status: REVIEW
priority: P0
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0112, FL-0116]
evidence:
  - check.sh OVERALL PASS (game-001 1438/0, lune 528, selene 0, stylua 492); NodeKeepOut.spec 8/8; renders games/game-001/art/reviews/img/fl0124_farmside_*
---

# World-layout resource nodes and bushes keep out of farm fields and build zones (visual extent)

## Outcome
No world-layout rock, bush or node, judged by its full visual extent, touches a starting farm field, a plot build zone or a slot, for any seed. This closes the user's #1 complaint together with FORGE-01's sim-node fix (#152).

## Context
- The user's first Studio feedback: "farms contain trees and rocks".
- FORGE-07 on #152: after FORGE-01's fix, the remaining rocks and bushes are FORGE-02's 20 world-layout nodes.
- D-052 (4).

## Requirements
- Consume FORGE-01's `Kingdom/Layout.keepOutAreas()` (fields, build zones, slot rects) once it is on main; don't keep a private copy.
- Use each node's or prop's visual radius (canopy or rock extent), not its footprint.
- Move rather than delete where possible, keeping the world's node counts fair per kingdom (#94).

## Validation
Automated: a spec over seeds 1..20 for zero visual-extent overlaps with fields, zones and slots; a mutation row. Visual: an aerial render of every starting farm. Studio: B17 checklist G1 again.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 review).
- [ ] Studio evidence (G6).

## Log
- 2026-10-15 FORGE-00: created from FORGE-07's B17 review round (D-052).
- 2026-10-15 forge-02: READY → BUILDING. Started (P0, D-052 (4)): spec first (tests/world/NodeKeepOut.spec.luau measures each world node's drawn extent from the live Kit.prop bounds and reproduces FORGE-01's 20 offenders: stone1/2 on field 3, gold1 on slot10, berries in the east zone, plus wood2 canopy over the lumber camp), then move the nodes in keep-frame offsets so the plots stay rotated copies.
- 2026-10-15 forge-02: BUILDING → REVIEW. PR opened. The 20 offending world nodes (stone1/2, gold1, food1/2 per plot) and two lumber-camp trees moved in the keep frame (identical in all four plots), never deleted: 8 studs off every crop field, build zone and slot and 5 studs off every starting building's real footprint, by the live Kit.prop drawn extent. NodeKeepOut.spec 8 tests (fields/zones/slots, buildings, fairness copies, nav distance, decor vs fields, node set unchanged), 11 Layout mutations killed. 8 aerial renders (every starting farm, before/after). Fresh image-only review: nodes out in all four kingdoms; remaining: 2 terrain-scatter trees at plot corners (FL-0116/#159's clearance) and the lumber-camp forest one tree-width from a build rectangle. Studio G1 unverified.
