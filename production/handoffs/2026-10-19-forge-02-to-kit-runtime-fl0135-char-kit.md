# Handoff: forge-02 (mesh kit) → forge-02 (Kit mesh-rig runtime, PR #207) · FL-0135 · 2026-10-19

## What I need / what I'm giving you
The Blender character kit is built to the contract of `rig_to_luau.py` / `Kit/CharacterMesh.luau`: **103 original pieces in one FBX plus `rig.json`** that passes `python3 games/game-001/art/char_kit/rig_to_luau.py --validate-only` with 0 warnings. Nothing in `roblox/` or `games/game-001/src/` was touched by me. I need the owner's Studio import (one batch) and your runtime to read the data; the converter on this branch is a verbatim copy of the file on `forge/02-blender-fl0135-runtime` (no edits: if you change it, take your version on merge).

## Done (with commits)
- Branch `forge/02-blender-fl0135-meshes` (head in the final report; contract commit `cdce24a9`). Merged `origin/main` (no conflicts).
- `games/game-001/art/char_kit/citizen_kit.fbx` (about 0.48 MB, 103 mesh objects named by piece id, vertex colours in one `Col` layer, one material `M_charkit_vc`, 1 Blender unit = 1 stud, Y up / -Z forward), `rig.json` (schema_version 1), `rig_to_luau.py` (copied). One manifest row `char_kit_01` (licence `project-original`). Rebuild: `~/forge-bpy/bin/python blender/build.py --generator char_kit` (deterministic; `bash blender/scripts/check.sh` re-verifies the geometry hash).

## Evidence
Blender and headless only; **no Studio evidence for anything below**.
- `python3 games/game-001/art/char_kit/rig_to_luau.py --validate-only` → `valid (0 warning(s))`. `--out` was NOT run by me (the generated `CharacterMeshData.luau` is yours).
- Triangles MEASURED from the shipped file, not declared: `~/forge-bpy/bin/python -I blender/scripts/charkit_budget.py` (FBX bytes via `blender/lib/fbxtris.py` and a Blender import, both equal to `tris` in rig.json; every job x all 1,728 looks x 4 kingdoms): farmer 894, woodcutter 822, miner 830, builder 790, hauler 936, blacksmith 748, merchant 926, healer 938, idle 798 (citizen cap 1,000; worst body 862 of 900; hand tool or sack <= 102 of 150); soldier 856, soldier_swordsman 920, soldier_archer 934, governor 926 (cap 1,500); <= 16 pieces (governor 16); largest mesh 188 triangles; texture memory 0. `blender/lib/manifest.py check()` recomputes this on every `check.sh` and fails over budget or on any declared-vs-measured mismatch (mutants in `blender/tests/test_kit_budget.py`).
- `bash blender/scripts/check.sh` PASS; `python -m pytest -q blender/tests` 55+ passed; pose clearance over every Pose action: nothing over 0.06 stud except thin soft shells (aprons, regal hem, sack strap up to 0.33 stud when a thigh swings through them in walk / flee).

## Interfaces touched
None breaking. Additive: the data the runtime reads is the contract's; extra top-level keys (`looks`, `tints`, `budget`, `measured`, `geometry_hash`) are ignored by the converter. The triangle budget is 1,000 per citizen (D-057 (11)), soldiers and governors 1,500.

## What the data says (so you do not have to guess)
- Assemblies: `farmer woodcutter miner builder hauler blacksmith merchant healer idle soldier soldier_swordsman soldier_archer governor`. The unit-kind keys `soldier_swordsman` and `soldier_archer` are my guess at the sim's unit names (`archer` exists in `RulerAI`); rename the keys in `art/char_kit` if the sim says otherwise, or tell me.
- Variants (ids are prefix + digits + suffix): `head_01..06`, `hair_01..10` (`hair_10` is a hood, tint kingdom) and `hair_beard`, `torso_01..06` (tunic, work, jerkin, vest, sleeveless, robe), `boot_01..03_l/_r` and `boot_plate_l/_r`, `acc_01` (empty: no accessory) / `acc_02` (headband), `crest_%kingdom%` and `shield_%kingdom%` with all four kingdoms plus `neutral`. Left / right pieces are explicit (`_l`, `_r`, left at -x); nothing uses `mirror`.
- Colour model, per piece `tint`: `skin`, `hair` (Character palettes), `cloth` (your `Character.clothColor`), `kingdom` (`tint_factor` given per piece), `fixed` (baked, white multiplier). Deliberately baked (`fixed`) so the job reads at a glance whatever the runtime's job panel says: woodcutter charcoal beanie, builder cream hard hat, merchant violet beret and coat, healer white coif and smock, blacksmith soot cap and charcoal shirt, all steel, gold and leather. The kingdom colour is `mantle_kingdom` (a shoulder yoke on every worker), the soldier tabard / sleeves / crest / pennant / shield, the governor's cape / cap. `tints.cloth_panels` and `tints.cloth_legs` in rig.json mirror `Character.luau` (job panels, `folk` for jobs without one) and are only what my Blender renders use; you do not need them.
- Placement: `bbox_center` / `size` per piece, rest CFrame = `CFrame.new(bbox_center)`; joints as in your header (`TorsoTool` for the hauler's sack); `weld_to` is the joint name for extras, null for bases.

## Open issues and risks
- **Unverified in Studio:** importer axes and unit scale, MeshPart bounding box after import, vertex colours surviving the import and being multiplied by `MeshPart.Color`, the draw-call cost of 12 to 16 MeshParts per citizen at D-047 crowd sizes.
- Soft shells (aprons, regal hem, sack strap) are crossed by a swinging thigh in the fast walk / flee frames (<= 0.33 stud).
- Known weak spots (see `games/game-001/art/reviews/char-mesh.md`): thin tools vanish from the aerial camera, faces carry no information at 170 studs, the hauler reads by the sack only from the side or behind.

## Next actions for the receiver
1. Owner: import `citizen_kit.fbx` with `blender/studio/import_char_kit.luau` (your script), check `torso_01` measures about 1.8 x 1.9 x 1.2 studs, record importer settings that worked and send them to me.
2. Run `rig_to_luau.py` (no flags) and commit `CharacterMeshData.luau`; run the Kit specs on the real data (budgets, joints, clearance).
3. Studio screenshots at the aerial and portrait views for the B2x row.

## Files to read
- `games/game-001/art/char_kit/rig.json`, `rig_to_luau.py` — the contract.
- `blender/lib/ckit_resolve.py` — the Python port of your variant resolution (I resolve every render through it).
- `games/game-001/art/reviews/char-mesh.md` — review log, measured table, what is placeholder.
