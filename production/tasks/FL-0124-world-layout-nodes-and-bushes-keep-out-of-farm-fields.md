---
id: FL-0124
title: World-layout resource nodes and bushes keep out of farm fields and build zones (visual extent)
track: asset
owner: forge-02
status: READY
priority: P0
game: game-001
created: 2026-10-15
updated: 2026-10-15
depends_on: [FL-0112, FL-0116]
evidence: []
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
