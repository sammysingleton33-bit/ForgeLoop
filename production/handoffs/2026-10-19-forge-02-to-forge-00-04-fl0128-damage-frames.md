# Handoff: FORGE-02 → FORGE-00 (review, merge) and FORGE-04 (FL-0143 builds on it) · FL-0128 · 2026-10-19

## What I need / what I'm giving you
The `Kit/Damage.luau` fix FORGE-00 asked for as a P1 before FL-0143 (#273) can merge: damage was worked out on world axes and parked parts at absolute CFrames, both dormant until `Kit.applyDamage` is called on placed buildings. Now a building is damaged in its own frame, wherever it stands and however it is turned, and a damaged building that is moved repairs exactly. FORGE-00: review and merge after #268 (this branch is stacked on it); run the final `roblox/scripts/check.sh` (I ran targeted specs only). FORGE-04: the contract you call is in `2026-10-19-forge-02-war-kit-handoff-errata.md` ("The `Kit.applyDamage` contract") and in the `Kit/Damage.luau` header.

## Done (with commits)
Branch `forge/02-blender-damage-frames` (worktree `forgeloop-wt/fl0128-c`, stacked on `forge/02-blender-fl0128-defects`; the coordinator opens the PR). Head SHA is in the worker report.
- **(a) World axes.** Everything (which face is the front, which parts go, where marks and rubble lie, the order of it all) is worked out in the model's own frame, `PrimaryPart.CFrame * PivotOffset`, and turned into world CFrames only when a part is made (`Damage.frameOf`). Comparisons that used to hinge on 1e-6 lean 1e-3 towards equal (32-bit CFrames).
- **(b) Parked parts.** Stored relative to the `PrimaryPart` and restored at its CFrame as it is then (untouched, bit for bit, when the model has not moved); a gate leaf, band or portcullis returns in the pose the gate has then.
- **(c) Rubble** stands on the model's base plane (y = 0 of its frame), so on terrain at any height, and inside the footprint: sides and back strictly, the front at most 2 studs beyond (the Kit's own allowance for entrance steps). The keep's stump slab is shrunk to fit its footprint.
- **(d) L1 palisade.** It has no wall block: breach, crack and chip marks are spread over the standing logs and the two posts (at least two supports whenever there are two marks), each narrower than its support, wholly inside it and below its top, in wood.
- **`KitLevel`.** `Kit.build` clamps the level to `Kit.MAX_LEVEL[type]` and stores and names the clamped level (`Buildings.MAX_LEVEL`, exported as `Kit.MAX_LEVEL`); the stand-ins are level 1.
- **Order.** `Kit.build` writes the part attribute `KitOrder` (the order the damage walks a model's parts in, taken once while every part is exactly where it was made): the choice of parts no longer depends on float noise from a turn or a move, on gate poses or on the order repairs leave the children in. A part without it (an emblem a recolour re-formed) is ordered last by position.
- **FORGE-07's three lows (#268):** a light wall's mark can no longer hide as "within 0.06" of its wall (the arm applies to walls darker than 0.25 only; a mutant colours a pale wall's breach with the wall's own colour); the L3 door head must stand behind every portcullis bar (a mutant at -d/2 + 0.2 fails); the (44,40,36) floor of the mark colours is pinned on untinted supports (a mutant at (41,38,34) fails).
- **Stale comments fixed:** the Damage header (front-right corner, "inside the box", `setKingdomColor`, models without a PrimaryPart), `Buildings.luau` (all-built 26,326, the measured table re-measured over the seven colours), `Siege.luau` (ram 37-42 in the four kingdoms, 31 neutral), `Character.luau` (crest paragraph: 9 base / 11 with details, 8 / 10 without a kingdom, a knight without one 9), `Crowd.luau` (the crest is the soldiers' by name, its own primitive and size), `WorldService.luau` (WorldView builds the models), `ART_DIRECTION.md`, `KitCeiling.spec` (farms at level 2, neutral towers at level 2), `Kit.luau`.
- **Docs:** `art/reviews/kit-architecture.md` "FL-0128 damage frames"; the errata handoff `2026-10-19-forge-02-war-kit-handoff-errata.md`; the FL-0128 task Log and evidence.

## Evidence
All headless (Lune specs, Blender Cycles previews of Lune dumps); **Studio unverified**.
- Lune, `--specs games/game-001/tests/world`: KitDamage 38, KitWarKit 64, Kit.spec 20, KitCeiling 1 (26,326 of 27,000: WorldService 6,869 + kingdoms 19,121 + neutral towers 336, unchanged), KitBuildings 17 (+ dump 1), KitStyles 20, KitEmblems 14, KitUnitKinds 15, KitCharacter 59 + dump 1 + mesh 48 + import 18 + pose 18, ArenaLayout 23, WorldService 27; 0 failed. stylua --check and selene on every changed Luau file: clean. `forge.py validate`: 143 tasks, 0 errors.
- KitDamage "frames" (new): every wall and gate level (1..3) in all four kingdoms and the other types at their top level (keep L1..L3 too), at every state (wall and gate) or two: at most 14 extra parts; every damage part inside the as-built bounds in the model's frame (rubble 4 in front, stump 0.6 aside); plain repair exact; built turned 90 / 180 at y 40 and elsewhere = the damage at the origin; damaged then moved (new place and yaw) = followed, repaired = a pristine copy moved the same way (world CFrames, none doubled, none parked), damaged again at another state = a pristine moved copy damaged at that state; rubble bottom at base - 0.2 at y 40 and y 3.5; a gate opened while a leaf is out, moved and repaired = the open gate; the palisade (four kingdoms, states 1..4); and a footprint check re-dressing keep L1..L3, wall L1..L3, gate L1 / L3, watchtower L1 / L2, house L1 / L2 turned 90 / 180 / 270 through seven states. "level": the damage of a wall asked for at level 5 is that of level 3.
- Mutants (all caught): damage on world axes (`Damage.frameOf` returns the world frame), parked parts at absolute CFrames, rubble at world y, all palisade marks on one log, a palisade mark above its log, an unclamped `KitLevel` (here and in Kit.spec), a pale wall's breach in the wall's own colour, the lowered colour floor, the L3 door head in front of the bars.
- Reproduction of the old defect: with `Damage.frameOf` swapped for the world frame, the rubble of a keep L1 placed at (100, 5, -40) lies 72 studs outside its footprint at every yaw; fixed, it is exactly 2.00 (the front allowance) at yaw 0 / 90 / 180 / 270.
- Before / after: 592 damaged variants dumped with the old and the new code (every type, every level, four kingdoms, four states). 96 are the stand-ins' second level (now level 1, the same damage as their level 1, bit for bit). Of the other 496: 115 identical bit for bit, 331 differ only in where the rubble lies, 50 differ otherwise (16 palisade, 30 watchtower L1 / L2 and storehouse L1 where two equally distant parts tied and float noise used to decide, 4 keep L1 stump slabs shrunk to the footprint).
- Sheets re-rendered and opened by me (`games/game-001/art/reviews/img/`): `kit_fl0128_damage.jpg`, `kit_fl0128_damage_kingdoms.jpg`, `kit_fl0128_damage_170.jpg` (same cameras and scale as before; they read as before, rubble nearer the foot), and the new `kit_fl0128_damage_frames.jpg` (palisade at five states in two kingdoms; a wall L2 and a gate L2 built turned 0 / 90 / 180 / 270 degrees). The gates, units and before/after sheets are unchanged (no gate or unit geometry changed).
- Spec run time: KitDamage about 3.5 minutes, KitWarKit about 3 (headless, one core each); `check.sh` will take that longer.

## Interfaces touched
Additive: `Kit.MAX_LEVEL` (a table of the highest level per type); `Kit.build` clamps its `level` argument and stores the clamped level in `KitLevel` and in the model name (`wall_L3_complete` for a wall asked for at level 5; nobody read the old value); the part attribute `KitOrder` on every building part; `Damage.frameOf` / `Damage.register` (module internals, not on `Kit`). `Kit.applyDamage`'s signature and the part attributes it writes are unchanged; a model without a `PrimaryPart` now writes no `KitDamageState` (it used to write the state it was asked for).

## Open issues and risks
- Rubble is not strictly inside the footprint: up to 2 studs in front of the front edge, as far as the Kit's own steps may go. Strictly inside would put it inside the wall of most buildings (they fill their footprint); `RUBBLE` placement is one clamp in `Damage.luau` ("step 4") if FORGE-00 wants zero.
- 30 damaged variants (watchtower L1 / L2, storehouse L1) pick a different one of two equally distant parts than before; both are valid damage, the old one was decided by float noise.
- The order of a model that was not built by `Kit.build` (a clone loses nothing, it keeps `KitOrder`; a hand-made model has none) is by position and only robust away from a rounding edge.
- Farms are built at level 2 by the ceiling spec; level 3 adds 3 parts each (+36, 26,362 of 27,000).
- Studio unverified: the look of the damage, the Slate and Wood marks under real lighting.

## Next actions for the receiver
1. FORGE-00: merge #268, then this branch; run `bash roblox/scripts/check.sh`.
2. FORGE-04: FL-0143 may merge after this; the contract is in the errata handoff.
3. Someone with Studio: damage a turned keep and a gate, move one (G13.9), repair it.

## Files to read
- `games/game-001/src/shared/Kit/Damage.luau` — the header is the contract
- `games/game-001/tests/world/KitDamage.spec.luau` — "frames", the moved repair, the turned footprint, the mutants
- `games/game-001/tests/world/Kit.spec.luau` — the `KitLevel` clamp
- `games/game-001/art/reviews/kit-architecture.md` — "FL-0128 damage frames"
- `production/handoffs/2026-10-19-forge-02-war-kit-handoff-errata.md` — errata and the `applyDamage` contract
