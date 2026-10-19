# Handoff: forge-02 (Blender worker P) → forge-02 lead / FORGE-00 · FL-0136 phase 3 · 2026-10-19

## What I need / what I'm giving you
FORGE-00's follow-ups on the nature kit, on a NEW branch stacked on PR 247 (`forge/02-blender-fl0136-env` at 8c26e2a8; PR 247's branch is untouched): resource nodes readable at the 170-stud camera (visual only), and the fences, cabbage variants and cliffs as mesh-only dressing.
Ripe only (no growth stages), iron and crystal ore not promoted. The Luau side is small and sits in the Kit (FORGE-02's paths): `Props.nodeMarker`, `WorldPlan.meshDressing`, `EnvMesh.ready`; no Layout, Kingdom or `roblox/scripts/check.sh` change. The branch is NOT a PR; you open it.

## Done (with commits)
- Branch `forge/02-blender-fl0136-dressing` (final head in my report). Commits so far: the work + node sheets (`bf19c036`), the dressing sheets (`e0f61080`), then the records and docs (last commit).
- **A. Nodes at 170 studs.** Scaling the meshes is not available (measured on the real layout: the quarry stones have 2.6 to 3.3 % of room, the gold ore 0.7 %, a berry bush 9.7 %, `crimson_wood4`'s oak none; the limit is the 8-stud buffer to fields, slots and zones and the 5 studs to the quarry building). So: a **marker** on every resource node, a post and a glowing orb in the resource colour (stone ice white, gold yellow, wood orange, food red-pink), 2 parts, visual only, inside the node's reach, on stand-ins and meshes alike, only on the 38 nodes (not on the forest trees or decor bushes that share their ids). +76 parts world-wide. `Layout` and work spots untouched.
- **B. Dressing**, placed only when `Kit.envMeshReady(id)` (the Kit would build the mesh), so a world without the import is exactly today's: cabbage field variants by kingdom (`_01`, `_02`, `_03`, `_01`), **48 field fence segments** (12 per plot: back and flanks), **12 rim cliffs** (11 at density 1.0) at the foot of the mountain ring. 180 parts, 5,364 triangles.
- `env_kit_01` is now **58 ids** (52 + the six dressing ids); `env_kit_02` is **9 spares**. The 52 reviewed ids are geometrically unchanged (subset hash 61bac208a4421907).
- Specs: `KitNodeMarker.spec` (14, with mutants), `KitEnvDressing.spec` (20, with mutants); `KitEnvMesh.spec` counts the dressing ids as placed; `WorldService.spec` pin 8,271 -> 8,347 (the 76 marker parts, and nothing else moved: the placement fingerprints are unchanged).

## Evidence (headless and Blender; **nothing is Studio evidence**)
- Targeted Lune specs: `KitNodeMarker` 14 passed, `KitEnvDressing` 20 passed, `KitEnvMesh` + `KitEnvMeshImport` 44 passed, `WorldService` 27 passed; the whole `games/game-001/tests/world` directory: see my report for the final run. Selene 0 warnings and `stylua --check games` clean on the changed files. I did not run `roblox/scripts/check.sh` (yours).
- Mutation checks: removing the `Kit.nodeMarker` call from `WorldService` fails 3 specs; the spec mutants each fail the rule they target.
- Measured numbers (Lune on the real world, K's runtime, the real `Kit/EnvMeshData`): part-built world 6,945 parts at the shipped density (6,869 + 76 markers), 2,770 with the kit (-4,175, -60 %), 8,696 -> 3,364 at density 1.0 (-61 %); the kit world draws 175,076 triangles at the shipped density and 233,894 at 1.0 (placements x measured triangles, a worst case).
- D-019, fresh image-only reviewers, blind, one session each: **resource node markers** SET B PASS 4 / 4 / 4 / 3 / 4 / 4 / 3 / 4 (cohesion 3: "balloons on sticks"), SET A NEEDS-WORK 3 / 2 / 2 / 4 / 4 / 4 / 5 / 5; all four resources found at both cameras in B, wood never in A. **Farm dressing** SET B PASS 4 / 4 / 4 / 3 / 4 / 4 / 4 / 5, SET A NEEDS-WORK 2 / 2 / 3 / 3 / 4 / 3 / 3 / 2. Replies verbatim: `games/game-001/art/reviews/img/d057-env-nodes-r1/review.json`, `d057-env-dressing-r1/review.json`.

## Interfaces touched
Additive, FORGE-02's area only: `Kit.nodeMarker(model, resource)`, `Kit.envMeshReady(assetId)`, `EnvMesh.ready(assetId, source)`, `WorldPlan.meshDressing(layout, placements, ready)` and `WorldPlan.MESH_DRESSING`, `Props.NODE_MARKER_*`. `WorldService` calls the first and the fourth. New placement features `fence` and `cliff` (only with the kit). No Layout, Kingdom, contract or `roblox/scripts` change.

## PR text (triangle totals, as FORGE-00 asked)
- **Kit 1 (`env_kit.fbx`, the 58 ids the world places): 22,834 triangles** (trees 20 / 9,058, bushes 8 / 2,000, flowers 6 / 1,626, rocks incl. nodes and cliffs 16 / 3,010, crops 5 / 6,788, haystack 1 / 196, fences 2 / 156; largest mesh 1,430). **Kit 2 (`env_kit_spares.fbx`, 9 spares): 4,510.**
- **The world draws with the kit** (every placement x its measured triangles; buildings, bridges, the arena and the kingdoms not counted): **175,076 at the shipped density, 233,894 at density 1.0.** The dressing's share: 5,364 (3,744 fences + 1,620 cliffs). Part count: 6,945 -> 2,770 (shipped), 8,696 -> 3,364 (1.0).
- D-047: FORGE-00's ~26.3k all-built worst case + 76 markers = ~26.4k without the kit (the only addition there); ~22.2k with it. I did not rebuild an all-built case; these are deltas on FORGE-00's figure.

## Open issues and risks
- **Unverified in Studio:** the orbs' Neon glow against the real lighting, the highlight and arrow of `OnboardingController` on a node Model (now taller), the six new meshes' real bounds against `EnvMeshData`, fence collision against a walking ruler (solid, 4 studs high), how a rim cliff sits on the mountain foot (no terrain in the Blender scene: no render of them in place), draw calls and phone cost.
- With the imported meshes, `NodeKeepOut`'s box measure is 0.1 to 2.8 studs over the rule for 7 of the 8 plot node types; the meshes' real outline is inside it except `tree_oak_05` (0.35 stud into its 8-stud buffer, nothing touches a field, slot or building). `NodeKeepOut.spec` runs on the stand-ins only, so nothing fails; K's fit window (nodes <= 102 % of the stand-in footprint) does not cover it.
- Reviewer notes on the new look, none blocking: balloon-like markers (cohesion 3), thin and repeated fences, small pale cliffs, subtle cabbage variants. Each fix that touches a mesh changes `env_kit.fbx` and needs a new review round.

## Next actions for the receiver
1. FORGE-00 decisions (also in `env-mesh.md` 3.7): the orb marker as the node look or a flag restyle; the rim cliffs (keep, scale up, drop); fences thicker; wheat `_03` as a third ripe variant (not done); the lone east fence segment of each plot's first field.
2. K / FORGE-01: NodeKeepOut with the meshes (accept, or measure with the mesh outline).
3. Owner, in Studio, after PR 247's import: **re-import `env_kit.fbx`**, which changed: 58 mesh objects (it was 52; `farm_fence_01/02`, `farm_field_cabbage_01/02`, `rock_cliff_01/02` are new, 1,000,092 bytes). `IMPORT_ENVIRONMENT.md` is updated; `import_env_kit.luau` is unchanged. `env_kit_spares.fbx` is still not needed. Then look at the quarry, the farm fields and the rim from the 170 and 82-stud cameras and report.
4. What is **ripe only**: every crop field is a ripe field; `farm_field_wheat_03/04/05` (scarecrow variant, shoots, green wheat) stay on the bench in `env_kit_spares.fbx`. **Iron and crystal ore (`resource_ore_01/02/05/06`) are not promoted**: they are not game resources (food, wood, stone, gold); they sit in the spares kit only, with the wood nodes `resource_wood_01/02`.

## Files to read
- `games/game-001/art/reviews/env-mesh.md` "Phase 3" — the node measurements, the marker candidates, the dressing, numbers, limits, asks.
- `games/game-001/art/reviews/img/d057-env-nodes-r1/`, `d057-env-dressing-r1/` — the blind sheets, `review.json`, `key.json`, `review_prompt.md`; `d057-env-nodes-candidates/candidates_aerial170.jpg` — the marker candidates.
- `games/game-001/src/shared/Kit/Props.luau` (`nodeMarker`), `WorldPlan.luau` (`meshDressing`), `EnvMesh.luau` (`ready`), `games/game-001/tests/world/KitNodeMarker.spec.luau`, `KitEnvDressing.spec.luau`.
- `blender/scripts/lune/EnvNodeFit.spec.luau`, `EnvNodeMarkers.spec.luau`, `EnvDressing.spec.luau`, `blender/scripts/envnode_sheets.py`.
