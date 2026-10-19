# Handoff: forge-02 (Blender worker P) → forge-02 (Kit env-mesh runtime, worker K) and FORGE-00 · FL-0136 phase 2 · 2026-10-19

## What I need / what I'm giving you
The Blender nature and crop kit for D-057 (18)-(20): **67 original style-B meshes in two FBX kits** plus their `env.json` files, built to K's contract (`games/game-001/art/env_kit/env_to_luau.py`, copied byte-identical from `forge/02-blender-fl0136-envrt` at 83695c53).
`env_kit_01` is exactly the **52 asset ids the world places today** (this is what `Kit/EnvMeshData` is made from); `env_kit_02` holds **15 finished spares** nothing places yet (promote them into kit 1 the day the world places them). I wrote no Luau runtime code and opened no PR.

## Done (with commits)
- Branch `forge/02-blender-fl0136-nature` (stacked on PR #228; final head in my report). Commits: inventory + stand-in table (`dbc777f9`), generators v1 + measured-triangle gate + tests (`d3026abc`), K's contract adopted + spares split (`e0be4c0f`), polish + scenes + sheets (`afd13fe8`), round-1 sheets + kit v1.5 (`2e48a633`), reviewer record + part-count relief + docs (the last commit).
- Files (all under `games/game-001/art/env_kit/` except where noted): `env_kit.fbx` (875 KB, 52 mesh objects named by asset id) + `env.json`; `env_kit_spares.fbx` (315 KB, 15 objects) + `env_spares.json`; `env_to_luau.py` (K's, unchanged). Manifest rows `env_kit_01`, `env_kit_02` (`blender/manifest.d/env_kit.json`).
- One vertex-colour layer (`Col`), one material `M_envkit_vc`, no textures, flat normals, 1 unit = 1 stud, Y up / -Z forward, base on y = 0, object origin at the bbox centre; `env.json` `bbox_center` and `size` are relative to the base-centre pivot (as in the citizen kit).

## Evidence
Blender and headless only; **no Studio evidence for anything below**.
- `python3 games/game-001/art/env_kit/env_to_luau.py --validate-only --in games/game-001/art/env_kit/env.json` → valid (14 warnings); `--in env_spares.json` → valid (6 warnings). The warnings are intentional sinks (rocks, boulders, nodes and cliffs sit 0.40 to 0.54 studs below y = 0 so they rest on uneven ground).
- Triangles MEASURED from the shipped FBX bytes (`blender/lib/fbxtris.py`), not declared, family budgets enforced by `manifest.check()` and so by `check.sh`: tree 318 to 652 (budget 300 to 900), bush 140 to 340, flower 228 to 312, rock 116 to 268 (boulders and nodes), crop 1,332 to 1,430 (40 to 1,500), haystack 196 (40 to 600); kit 2: rock 132 to 220, crop 1,020 to 1,332, fence 72 to 84. Full per-id table: `games/game-001/art/reviews/env-mesh.md` Phase 2, section 3. Fit: footprint 93 to 107 % of each stand-in (nodes 88 to 100 %), height 89 to 113 %, wheat fields 122 %, three `fit_note`s in kit 2.
- Part-count relief on the REAL `WorldService` (Lune, K's runtime copy plus my env.json, `blender/scripts/lune/EnvRelief.spec.luau`): **shipped density 6,553 → 2,168 parts (-4,385, 67 %)**, **density 1.0 8,309 → 2,765 (-5,544, 67 %)**, same placements. The cost moves to triangles (placed nature at most 171k at shipped density and 231k at density 1.0 if all drawn at once; unverified on a phone).
- Fresh image-only D-019 reviewers, one per family group, blind (SET A = part-built stand-ins, SET B = these meshes): trees/bushes/flowers **B PASS** (4 4 4 4 4 4 4 4), rocks/boulders/nodes **B PASS** (4 4 4 4 4 4 4 4), crops **B PASS** (4 4 4 4 4 4 4 cost 3); SET A NEEDS-WORK in all three. Verbatim: `games/game-001/art/reviews/img/d057-env-nature-r1/review.json`. `env_kit_02` is NOT reviewed.
- `bash blender/scripts/check.sh` → `blender check: PASS` (see the report for the exact run); `python -m pytest` in `blender/tests` (25 new env-kit tests: mutants for every budget, fit and sink rule, K's validator on both json files, determinism, FBX import).

## Interfaces touched
Additive only: new `files.env` field in `blender/manifest.schema.json`, new kit rows, `blender/lib/manifest.py` env checks. No Luau, no contract, no shared path touched.

## Open issues and risks
- **Unverified in Studio:** FBX import (MeshPart size, pivot and scale), vertex colours surviving the import with `MeshPart.Color` white (`tint: fixed` everywhere), collision with K's collider parts, draw calls and phone cost, PlotClearance with real MeshPart bounds (`reach_bbox` in `env.json` is the box-corner reach it would use).
- FBX bytes are not reproducible (Blender stamps a time): `build.py --verify` compares the geometry hash; the manifest row carries the sha256 of the committed FBX. The reviewed geometry equals the committed geometry (re-render check in `env-mesh.md` section 7).
- Non-blocking visual defects (reviewers and me): very dark pines, similar birches and plain bushes, quarries differ mostly by tone, tiny rocks and nodes (and invisible gold) at the 170-stud camera, faint wheat shoots stage, small low-contrast haystack. A scale or marker decision may be needed for nodes at the aerial camera.
- Wheat growth is not placed by anything: the stage ids `farm_field_wheat_04` (shoots) and `_05` (green) exist and are measured but only a farm change (K or a later farm-visual task) can use them; `farm_field_wheat_03` has a scarecrow (190 % tall, `fit_note`).

## Next actions for the receiver
1. K: regenerate `Kit/EnvMeshData.luau` from `env.json` (`env_to_luau.py`), run the Kit specs on the real data, and read `env_spares.json` only when the world places those ids (tell me which and I move them into kit 1 and regenerate both files).
2. Owner (Studio): import `env_kit.fbx`, check one oak, one pine, one boulder and a field measure what `env.json` says, confirm vertex colours show with `MeshPart.Color` white, then screenshot the crimson settlement at the 82 and 170 studs cameras (the Blender equivalents are `img/d057-env-nature-r1/sheet_settlement_*.jpg`).
3. FORGE-00: decide whether the spares (cliffs, wood nodes, other ore kinds, fences, wheat stages, two more cabbage variants) are wanted; they cost nothing at runtime until placed.

## Files to read
- `games/game-001/art/reviews/env-mesh.md` "Phase 2" — inventory, kit, measured tables, looks, relief, limits, reproduce commands.
- `games/game-001/art/env_kit/env.json`, `env_spares.json` — the data (per prop: family, bbox, tris, node, stand-in fit).
- `games/game-001/art/reviews/img/d057-env-nature-r1/` — the 11 blind sheets, `review.json`, `key.json`, `review_prompt.md`.
- `blender/reviews/env_kit.md`, `env_kit.json` — author log and machine verdict pinned to the geometry hash.
