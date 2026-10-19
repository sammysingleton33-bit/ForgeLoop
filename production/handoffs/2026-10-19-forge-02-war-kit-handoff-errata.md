# Handoff: FORGE-02 → FORGE-00, FORGE-04, FORGE-01 · FL-0128 · errata for 2026-10-19-forge-02-to-forge-00-04-fl0128-war-kit.md and the `Kit.applyDamage` contract for FL-0143 · 2026-10-19

## What I need / what I'm giving you
Corrections to five statements in my war-kit handoff (`2026-10-19-forge-02-to-forge-00-04-fl0128-war-kit.md`, which I do not edit: handoffs are append-only), and the exact contract of `Kit.applyDamage` after the damage-frames fix (branch `forge/02-blender-damage-frames`), which FORGE-04's FL-0143 (#273) calls from `FeedbackController`. Where this note and the old handoff disagree, this note is right.

## Errata
1. **"All-built worst case ... pinned at 26,900" is wrong.** `tests/world/KitCeiling.spec.luau` asserts `total <= CEILING` with `CEILING = 27000` (the D-047 ceiling); nothing is pinned at 26,900. Measured by that spec: 26,322 after the defect-only round, 26,326 after defects round B and after the damage-frames fix (WorldService 6,869 + four kingdoms 19,121 + three neutral towers 336). The spec builds farms at level 2 (the game also builds them at level 3: +3 parts each, +36 in all, so 26,362 still under 27,000) and the three neutral towers at level 2 (their highest); its header now says so.
2. **`Kit.lod` does not exist.** The far stand-in for a character is `Kit.characterLod(kind, kingdomColor)` (one part, same Root height). The ram has no far LOD of its own: `Kit.characterLod("soldier", color)` is the stand-in until one is added.
3. **Routing.** The old handoff sends the `EntityController` and `Sim/WorldView` edits to FORGE-04. `docs/workflows/team.md` / `ownership.json` give `client/Controllers/Entity*` and `shared/Sim/**` to FORGE-01, and `client/Controllers/Feedback*` to FORGE-04. FL-0143 has since put the damage writer (`Damage` attribute + `Kit.applyDamage`) in FORGE-04's `FeedbackController` and kept the ram's `Log` joint (the `_animate` change) with FORGE-01.
4. **"no PR, the coordinator opens it" is stale.** The war kit is PR #260; defects round B is PR #268; the damage-frames fix is the PR after them.
5. **"the parts ... never intersect the roof or walls" was not true of the L1 palisade, and is only half true now.** The old soot streak on the palisade sat on the -X post, overhung it and rose above its top. Since the frames fix every breach, crack and chip lies wholly inside the wall block, log or post it sits on, flush on its front face and below its top (spec: KitDamage, every wall and gate level, four kingdoms, every state). Rubble and the stump do intersect geometry on purpose: rubble leans against the foot of the building and may sit partly inside its base, the stump sits on the top of what stood under the cap that fell.

Also: the FL-0128 task front matter says "all-built worst case 26,313": the measured figures are 26,322 and 26,326 (above). `KitDamageKind` "soot" in that handoff became "breach" in #268 (kinds now: breach, crack, chip, leaf, rubble, stump).

## The `Kit.applyDamage` contract (for FL-0143, FORGE-04)
- **Call:** `model:SetAttribute("Damage", Kit.damageFromHp(hp, maxHp))` then `Kit.applyDamage(model)`, on the model WorldView built with `Kit.build` (a finished building). Nothing is returned. A `Damage` that is not a number is 0; thresholds 0.25 / 0.5 / 0.75 / 0.95 give states 1..4.
- **Ignored:** a model without a `PrimaryPart` (nothing built, no attribute written); a construction stage (`KitStage ~= "complete"`: damage parts are cleared and `KitDamageState` removed).
- **Idempotent and order-free:** the same state again does nothing (it returns at once); the result depends on the state alone, never on the states before it. Going 0.97 -> 0.3 -> 0.6 gives exactly a fresh model at 0.6. Setting `Damage` below 0.25 (or 0) and calling again is the repair: every removed part is back, every damage part gone, the model is the model as built.
- **Writes:** the model attribute `KitDamageState` (1..4, absent at 0); child parts with `KitDamage = true` and `KitDamageKind` = breach / crack / chip / leaf / rubble / stump (at most 14, anchored, no collision, touch or query); parts it takes off the model are parked (parent nil) and come back on repair. Never touches `Burning`, `Hp`, `MaxHp`, `Damage` or the model's highest part.
- **Frame:** all of it is worked out in the model's own frame (the pivot: `PrimaryPart.CFrame * PivotOffset`): the front face is the model's -Z, the collapsed corner is its +X/-Z corner, rubble stands on its base plane (y = 0 of that frame, so on terrain at any height) inside its footprint (at most 2 studs in front, like the Kit's entrance steps). A model turned by any yaw or placed anywhere is damaged exactly like one at the origin.
- **Re-pivot (G13.9 move, `WorldView.placeModel`, `Model:PivotTo`):** the damage parts are children, so they move with the model. The parked parts are stored relative to the `PrimaryPart` and come back at its CFrame as it is then, so damage -> move (new place and yaw) -> repair puts every part exactly where a pristine copy moved the same way has it, nothing left at the old place and nothing doubled; damage again after the move is the same as damaging a pristine moved copy. You do not need to call `applyDamage` on a move (the parts follow), only when `Damage` changes. A move that changes only the `PrimaryPart` and not the other parts is not supported (`placeModel` moves them all).
- **Gates:** a leaf, band or portcullis parked by damage returns in the pose the gate has then (`Kit.setGateOpen` poses the parked ones as well; `KitGateOpen` is the truth), also after a move. The broken leaf (a damage part) is not moved by `setGateOpen`.
- **Recolour:** `Kit.setKingdomColor` also recolours the parked parts and the damage parts that carry a `KitTint` (marks, rubble and the stump copy their wall's tint; the broken leaf and the palisade's marks keep their colours).
- **Models you clone or build elsewhere:** the order the damage walks a model's parts in is fixed at build as the part attribute `KitOrder` (written by `Kit.build`), so a clone keeps it; a part without it (an emblem re-formed by a recolour) is ordered by its position, last.
- **New in this fix, additive:** `Kit.MAX_LEVEL[type]` and the clamp in `Kit.build` (below); `Damage.frameOf(model)` and `Damage.register(model)` are internals (a spec swaps `frameOf`); the part attribute `KitOrder` is on every building part.

## Done (with commits)
Branch `forge/02-blender-damage-frames` (stacked on `forge/02-blender-fl0128-defects`): see `2026-10-19-forge-02-to-forge-00-04-fl0128-damage-frames.md` for the fix itself, the evidence and the sheets.

## Evidence
Headless only (Lune specs); this is a documentation correction. Numbers above are from `tests/world/KitCeiling.spec.luau` (26,326 of 27,000) and the part-count measurements in that note. **Unverified:** Studio.

## Interfaces touched
None here (additive notes only). The fix: `KitLevel` stores the clamped level (`Kit.build("wall", 5, ...)` is level 3), `KitDamageKind` unchanged since #268, new part attribute `KitOrder`.

## Open issues and risks
- None known. Everything here is headless evidence; the look of the damage in Studio (lighting, Slate and Wood materials) is unverified.

## Next actions for the receiver
1. FORGE-00: link this errata from CONTRACTS G10's war-kit rows where they quote the old handoff.
2. FORGE-04 / FORGE-01: nothing to change; use the contract above.

## Files to read
- `games/game-001/src/shared/Kit/Damage.luau` — the header is the contract
- `games/game-001/tests/world/KitDamage.spec.luau` — "frames", the moved repair, the turned footprint, the mutants
