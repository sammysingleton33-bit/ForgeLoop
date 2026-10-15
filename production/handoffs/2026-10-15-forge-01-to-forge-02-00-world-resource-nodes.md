# Handoff: FORGE-01 → FORGE-02 (cc FORGE-00) · boulders, bushes and gold on the farms and build zones · 2026-10-15

## What I need / what I'm giving you
The user's first complaint ("farms in the starting kingdom contain trees and rocks") is still visible in
Studio after the sim-side fix (#131). The sim's own nodes are not the cause. The rocks in the farms are
**FORGE-02's per-plot world resource nodes** (`world/Layout.luau` `addNode`, drawn by
`WorldService` as Kit models): they sit on crop fields, build zones and slots. They are your data, so I
have not touched them. Please move them (offsets below are checked), or tell me to.

## Done (with commits)
- Branch `forge/01-gameplay-nodeextent` (PR in `agents/forge-01/STATUS.md`):
  - `Sim/NodeStyle` (new): how a sim node is drawn and how far the drawing reaches (half-diagonal).
    `Kingdom/Layout.clearSpot` now clears the larger of a node's footprint and its drawn reach. Today this
    changes no generated position (the 4-stud gap already covered the extra reach: rock 5.66 vs footprint 4),
    but a bigger look can no longer put a corner on a field. `WorldView` takes its node look from it.
  - `tests/sim/LayoutZones.spec.luau`: sim nodes against all 12 fields and 12 zones by drawn reach, no drawn
    corner on any area, seeds 1..20; plus a **ratchet** on your world nodes (below).

## Evidence
- Headless Lune only. Probe (world `resourceNodes` against the Layout areas, `Footprint.overlapsCircle`,
  node reach 9 = what `Kit/WorldPlan` already keeps its decor away by):
  - **On crop fields**: `<k>_stone2` stands **inside** field 3 of its plot (crimson (-411,-337) in field 3
    at (-424,-343) 40x30); `<k>_stone1` is 7.8 studs from its edge. Same for azure/emerald/gold (fields
    3, 6, 9, 12).
  - **In the east yard** (`<k>_east`, 50x60): both berry bushes `<k>_food1/2` stand inside the zone, and
    `food1` is within 9 of `<k>_slot8`; `<k>_gold1` (ore) is within 9 of `<k>_slot10`.
  - 20 of the 38 world nodes: `{crimson,azure,emerald,gold}_{stone1,stone2,food1,food2,gold1}`. The wood nodes
    and the `heart_*` nodes are clear.
- The sim does not use these (only `heart_*` feeds `Layout.generate`), so the economy is unaffected; this is
  about what the player sees and where a building ghost lands.
- Candidate keep-frame offsets (crimson; the other plots are rotated copies, so the same offsets). Checked
  with the same area test (nodes 9 studs from every field/zone/slot of the plot, 24 from every starting
  building anchor, 14 from the wood nodes). **Not checked**: roads/nav, terrain height, the quarry and farm
  work spots. Your call:

  | node | now (x, z) | candidate |
  |---|---|---|
  | `stone1` | (70, 66) | (72, 66) |
  | `stone2` | (40, 72) | (30, 62) |
  | `gold1` | (90, 40) | (88, 42) |
  | `food1` | (74, -44) | (38, -20) |
  | `food2` | (70, -32) | (76, 10) |

  The berries move furthest (43 studs): they sit in the build zone by design today, so you may prefer to
  shrink the east zone instead (CONTRACTS G10.1 area), or accept them as a bush patch inside the zone and
  tell me, then I drop them from the ratchet.

## Interfaces touched
None. `Sim/NodeStyle` is additive; no remote, config or contract change.

## Open issues and risks
- **Unverified in Studio**: nobody has looked at the boulders on screen. Sim/headless numbers only.
- The ratchet (`LayoutZones.spec.luau`, `KNOWN`) lists the 20 ids above and fails on any other world node
  that comes within 9 studs of a field, zone or slot. A node you move passes either way; I remove the id
  from `KNOWN` afterwards (it lives in my tests, so you do not edit it).
- Radius 9 is `Kit/WorldPlan`'s own guess at a node's size; if the stone model is wider, tell me the real
  extent and I use it.

## Next actions for the receiver
1. FORGE-02: move/shrink the 20 nodes (or answer which ones stay), then tell me, so I tighten the ratchet.
2. FORGE-00: nothing to approve; this is the "visual-extent clearance" item. If you want the farms
   checked in Studio, the step is: start a match, look at each kingdom's three farm fields from the keep.

## Files to read
- `games/game-001/world/Layout.luau` — `addNode` calls (end of the plot loop), `plotFields`
- `games/game-001/tests/sim/LayoutZones.spec.luau` — the ratchet and the corner check
- `games/game-001/src/shared/Sim/NodeStyle.luau` — drawn reach of a sim node
