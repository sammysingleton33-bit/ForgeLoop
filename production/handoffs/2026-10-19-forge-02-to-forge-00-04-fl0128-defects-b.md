# Handoff: FORGE-02 → FORGE-00 (review and merge) and FORGE-04 (damage part kinds) · FL-0128 · 2026-10-19

## What I need / what I'm giving you
Follow-up round B for FL-0128, the three visible defects the "any visible defects?" reviewer found in PR A (the war kit, merged as interim art with a waiver): breach marks that read as stickers, grass between the L3 portcullis bars, and a near-black open-gate floor that reads as a void at 170 studs. This branch is stacked on A's head; it changes only Kit code, two specs, six review sheets and docs. One name changed for a client reader: see "Interfaces touched".
- **FORGE-00:** review and merge after A. The final `roblox/scripts/check.sh` is yours to run (I ran targeted specs only, as asked).
- **FORGE-04:** if anything filters damage parts by `KitDamageKind`, the value `"soot"` no longer exists (it is `"breach"` now). I know of no reader.

## Done (with commits)
Branch `forge/02-blender-fl0128-defects` (worktree `forgeloop-wt/fl0128-b`, stacked on `forge/02-blender-fl0128-war`; PR opened by the coordinator). Head SHA is in the worker report.
- `Kit/Damage.luau`: breach marks rebuilt as broken stone. Per state 1..4: breaches 1/1/2/2 (a recess 2.2 to 3.2 wide, up to 4.2 high, 0.09 deep, at 0.64 of the supporting wall's colour), hairline cracks 1/2/2/2 (0.14 x up to 3.8 x 0.07, at 0.8 of the wall), chips 2/3/4/5 (0.8 to 1.4 x 0.6 to 1.0 x 0.4, at 1.25 of the wall, round the rim of the recesses), rubble 0/2/3/3 as before. Front face only, wholly inside the wall block they sit on (nothing overhangs a silhouette), lit Slate, never Neon, never black, tinted like the wall so a recolour follows. At most 14 extra parts still (12 marks and rubble, a broken leaf or a stump). The nail-like stick is gone.
- `Kit/Buildings.luau`: the stone tympanum now exists at every gate level; at L3 it sits behind the portcullis bars (bars and cross bar at z = -d/2 + 0.8, panel at -d/2 + 1.35). The open-gate floor is MID-tone in all four kingdoms: sand (160,144,118) for the darkest stone, earth (112,98,84) or dark earth (96,84,72) for the rest, picked from the wall's luminance.
- `tests/world/KitDamage.spec.luau`: the old rule that pinned "dark" marks is replaced by: a breach mark stays within a band of the supporting wall's own value (breach 0.5 to 0.9 of its luminance, crack 0.65 to 0.92, chip 1.05 to 1.6 or within 0.06), luminance at least 0.1, not Neon, front face, inside the block. 28 tests with mutants (black, Neon, translucent, sticker at a third of the value, thick dark stick, no chips, dark chips, overhang, side face).
- `tests/world/KitWarKit.spec.luau`: exactly one Tympanum at every level, the closed-arch sampling covers L3, floor luminance 0.25 to 0.6 and at least 0.15 from the wall; new mutants (near-black floor, white floor, wall-valued floor, no panel behind the L3 bars). 63 tests.
- Sheets (`games/game-001/art/reviews/img/`): `kit_fl0128_gates.jpg`, `kit_fl0128_damage.jpg`, `kit_fl0128_damage_kingdoms.jpg`, `kit_fl0128_damage_170.jpg`, `kit_fl0128_gates_open_170.jpg`, `kit_fl0128_before_after_170.jpg` (only re-rendered, its gate is L1 closed). Notes in `art/reviews/kit-architecture.md` ("FL-0128 defects round B") and `art/ART_DIRECTION.md`.

## Evidence
All headless; Studio unverified.
- Lune, `--specs games/game-001/tests/world`: KitWarKit 63 passed, KitDamage 28, KitCeiling 1, KitBuildings 17 (+ dump 1), KitStyles 20, KitEmblems 14, KitUnitKinds 15, KitCharacter 59 + dump 1 + mesh 48 + import 18 + pose 18, ArenaLayout 23, WorldService 27; 0 failed.
- KitCeiling: all-built worst case 26,326 of 27,000 (WorldService 6,869 + kingdoms 19,121 + neutral towers 336); it was 26,322 (+4: one tympanum per kingdom's L3 gate); under the 26,900 pin.
- Part counts per piece: wall L1/L2/L3 26-30 / 36-40 / 52-60, gate L1 72-77, L2 102-113, L3 121-132 (caps 90 / 120 / 150), watchtower L1 107-116, L2 105-122, ram 37-42.
- stylua --check and selene on the four changed Luau files: 0 errors, 0 warnings. `forge.py validate`: 139 tasks, 0 errors. `check_ownership` against origin/main: see the worker report.
- Images: Blender Cycles previews of Lune dumps (not Roblox renders; materials approximated). I opened every changed sheet and zoomed into the L3 closed row and the damaged wall and gate rows at 2x.
- **Unverified:** how it looks in Roblox Studio (lighting, Slate material, real shadows). `roblox/scripts/check.sh` was not run on this branch.

## Interfaces touched
Additive-compatible but one value renamed: the part attribute `KitDamageKind` takes `"breach"` where it took `"soot"` ("crack", "chip", "leaf", "rubble", "stump" unchanged). `Damage.SOOT` (a module field no other file reads) became `Damage.BREACH`, with `BREACH_SHADE`, `CRACK_SHADE`, `CHIP_LIGHT`. No Kit.* function changed, no remote, no contract. The gate model gained one part at L3 (`Tympanum`).

## Open issues and risks
- Breach marks are subtle at 170 studs: small pale-edged notches, not dark patches. Close up the recess is still a flat rectangle with sharp corners; the chips and the hairline crack are what make it read as broken.
- The tympanum is a flat stone panel; the L3 grille reads as dark bars over dark stone, not as a deep arch.
- The open passage still shades darker towards its back, as an interior does; the floor itself is mid-tone.
- Not in this round, per FORGE-00: shield and bow grip (FL-0135), keep damage at 0.3, framing, units at 170 studs, tower L2 against L1, the ram at 170. The grey slab beside the damaged house is the house's own `Gable` on main.

## Next actions for the receiver
1. FORGE-00: merge A, then this branch (stacked, no conflicts expected), run `bash roblox/scripts/check.sh`.
2. FORGE-04: nothing required; if you filter damage parts by kind, use `"breach"`.
3. Someone with Studio: look at a damaged wall and an open L3 gate at the real camera.

## Files to read
- `games/game-001/src/shared/Kit/Damage.luau` — the header describes the marks and the band rule
- `games/game-001/tests/world/KitDamage.spec.luau` — the band rule and the mutants
- `games/game-001/art/reviews/kit-architecture.md` — "FL-0128 defects round B", item table
- `games/game-001/art/reviews/img/kit_fl0128_gates.jpg`, `kit_fl0128_damage.jpg`, `kit_fl0128_damage_170.jpg`, `kit_fl0128_gates_open_170.jpg` — the evidence
