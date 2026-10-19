# Handoff: forge-02 (mesh kit, worker B) → forge-02 (Kit runtime, worker K) and FORGE-00 · FL-0135 · 2026-10-19

## What I need / what I'm giving you
The kit data changed on `forge/02-blender-fl0135-silhouettes` (FORGE-00 OPTION A: bolder job silhouettes inside the kit, no zoom-dependent swap). `rig.json`, `citizen_kit.fbx` and the generated `Kit/CharacterMeshData.luau` are regenerated together; the converter and every Kit spec are unchanged and green. This supplements `2026-10-19-forge-02-to-kit-runtime-fl0135-char-kit.md` (not edited, it is already on main).

## Done (with commits)
- Branch `forge/02-blender-fl0135-silhouettes` (from the kit branch of PR #220); head SHA in the final worker report. No PR opened (the coordinator opens it).
- Assembly rename on FORGE-07's review of #220: `soldier_swordsman` is now `soldier_knight` (sim units in `config/Military.luau`: soldier, archer, knight, ram). Keys now: `soldier` (default), `soldier_knight`, `soldier_archer`. No ram (siege engines are FL-0128).
- Piece changes the runtime sees by name: new `hat_hauler` (the hauler assembly now has a `hat` slot and no `hair` slot, like the other hat jobs); new merged back-gear pieces `gear_farmer`, `gear_woodcutter`, `gear_miner`, `gear_builder`, `gear_smith`, `gear_merchant`, `gear_healer` (joint Torso, tint fixed, slot extra) replace the old per-job aprons / packs / satchels; `hat_coif`, `hat_smith`, the hats, tools and `trim_regal` are re-modelled; `mantle_kingdom` is slimmer. 111 pieces in the FBX (was 103), 7,180 triangles.

## Evidence
- `~/forge-bpy/bin/python -I blender/scripts/charkit_budget.py` (measured from the FBX): citizens max 966 / 1,000 (healer), body <= 878 / 900, tool <= 102 / 150; soldiers and governor <= 978 / 1,500; pieces <= 16. PASS.
- `python3 games/game-001/art/char_kit/rig_to_luau.py`: 0 warnings. `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/world`: 318 passed, 0 failed (Kit filter 248). Specs not weakened.
- `blender/scripts/charkit_runtime_checks.py`: 0 violations; worst tool-head clearance 0.204 (limit 0.1), lowest fall corner -0.133 (limit -0.25), highest body point 7.17 (< 7.2). `blender/tests` 58 passed; `bash blender/scripts/check.sh` PASS.
- D-019: two fresh image-only reviewers (`games/game-001/art/reviews/img/d057-sil-review-r1/`, `-r2/`, replies verbatim in `review.json`): NEEDS-WORK both times (After silhouette 3, variation 3, readability 3; bar 4). 170-stud identities in r2: 3 yes, 7 partly, 1 no (idle). Record and options in `games/game-001/art/reviews/char-mesh.md`. Blender (Cycles) renders only: nothing here was seen in Studio (**unverified**).

## Interfaces touched
Additive in `rig.json` / `CharacterMeshData.luau` (new piece ids, one assembly key renamed). No contract change; the converter already accepts any `soldier_<unit>` key.

## Open issues and risks
- Unit-kind lookup: the runtime must ask for `soldier_knight` for the sim unit `knight` (it used `soldier_swordsman` only in the test dump). Search for the old key in your branch before merging.
- The 170-stud identity read is still "partly" for builder, hauler, blacksmith, healer and idle (see char-mesh.md options a to d); decision for FORGE-00.

## Next actions for the receiver
1. Merge the branch after PR review; run `rig_to_luau.py` and the Kit specs once more on the merged tree.
2. In Studio, after the owner's import: compare the aerial and portrait views against `img/d057-sil-review-r2/sheet_lineup170.jpg` (a B2x row).

## Files to read
- `games/game-001/art/reviews/char-mesh.md` — silhouette pass, scores, what is weak
- `games/game-001/art/reviews/img/d057-sil-review-r2/sheet_lineup170.jpg`, `sheet_aerial170.jpg` — old vs new at 170 studs
