# Handoff: FORGE-02 → FORGE-00, FORGE-04 · FL-0128 · errata 2 · 2026-10-19

## What I need / what I'm giving you
Two more corrections to earlier FL-0128 handoffs (existing handoffs are not editable by me, so they live here, next to `2026-10-19-forge-02-war-kit-handoff-errata.md`). Nothing else changes.

## Corrections
1. **`2026-10-19-forge-02-to-forge-00-04-fl0128-defects-b.md` (round B):**
   - "26,900 pin": `KitCeiling.spec` asserts at most **27,000** (`CEILING = 27000`, D-047). The all-built worst case is 26,326 of 27,000.
   - "wholly inside the wall block": the breach, crack and chip marks lie inside the wall block's face outline in **x and y** and stand proud of the face in z, by about **0.015 to 0.46 studs** (FORGE-00's measure; the spec pins x, y and the front face, not that depth). Nothing overhangs the silhouette sideways or above.
2. **`2026-10-19-forge-02-to-forge-00-04-fl0128-damage-frames.md`, re-pivot paragraph** ("You do not need to call `applyDamage` on a move (the parts follow)"): that holds for a `PivotTo` on the **same machine** only. In the game `WorldView.placeModel` runs on the **server**, while the damage parts are made by `FeedbackController` on each **client**, so a server-side move neither knows about nor carries a client's damage parts. On a root move FL-0143 repairs (`Damage` 0 + `applyDamage`) and dresses again, which relies on the PrimaryPart-relative parking and is exactly the path the "moved repair" spec covers (FORGE-04's note, FORGE-07's M1 on #273).

## Evidence
Text only; no behaviour change. The Kit comments are corrected in the same PR (`Damage.luau` header, `Buildings.luau` L3 portcullis comment: the Tympanum behind the bars stays when the gate opens; `kit-architecture.md` round-B record).

## Interfaces touched
None.

## Next actions for the receiver
None.
