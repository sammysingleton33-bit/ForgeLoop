# Handoff: FORGE-02 → FORGE-00, FORGE-04 · FL-0128 · errata 2 · 2026-10-19

## What I need / what I'm giving you
Three more corrections to earlier FL-0128 handoffs (existing handoffs are not editable by me, so they live here, next to `2026-10-19-forge-02-war-kit-handoff-errata.md`). Nothing else changes.

## Corrections
1. **`2026-10-19-forge-02-to-forge-00-04-fl0128-defects-b.md` (round B):**
   - "26,900 pin": `KitCeiling.spec` asserts at most **27,000** (`CEILING = 27000`, D-047). The all-built worst case is 26,326 of 27,000.
   - "wholly inside the wall block": the breach, crack and chip marks lie inside the wall block's face outline in **x and y** and stand proud of the face in z, by about **0.015 to 0.46 studs** (FORGE-00's measure; the spec pins x, y and the front face, not that depth). Nothing overhangs the silhouette sideways or above.
2. **`2026-10-19-forge-02-to-forge-00-04-fl0128-damage-frames.md`, re-pivot paragraph** ("You do not need to call `applyDamage` on a move (the parts follow)"): that holds for a `PivotTo` on the **same machine** only. In the game `WorldView.placeModel` runs on the **server**, while the damage parts are made by `FeedbackController` on each **client**, so a server-side move neither knows about nor carries a client's damage parts. On a root move FL-0143 repairs (`Damage` 0 + `applyDamage`) and dresses again, which relies on the PrimaryPart-relative parking and is exactly the path the "moved repair" spec covers (FORGE-04's note, FORGE-07's M1 on #273).
3. **`2026-10-19-forge-02-war-kit-handoff-errata.md`, line 21 (the "Re-pivot" bullet of the `Kit.applyDamage` contract; FORGE-07's L3 on #277):** the same sentence ("the damage parts are children, so they move with the model ... You do not need to call `applyDamage` on a move (the parts follow)") is true for a `PivotTo` on one machine only. **Read it as:** the damage parts are children of the model, so a `PivotTo` on the same machine moves them with it. In the game they are made by `FeedbackController` on each client while `WorldView.placeModel` moves the model on the server, so a server-side move neither knows about nor carries a client's damage parts: on a move FL-0143 repairs (`Damage` 0 + `applyDamage`) and dresses again. That path relies on the parked parts being stored relative to the `PrimaryPart` (damage -> move -> repair equals a pristine copy moved the same way; the "moved repair" spec). The rest of the bullet stands. The errata file itself is not edited here (existing handoffs are FORGE-00's by the ownership check), so this item is the correction of record.

## Evidence
Text only; no behaviour change. The Kit comments are corrected in the same PR (`Damage.luau` header, `Buildings.luau` L3 portcullis comment: the Tympanum behind the bars stays when the gate opens; `kit-architecture.md` round-B record).

## Interfaces touched
None.

## Next actions for the receiver
None.
