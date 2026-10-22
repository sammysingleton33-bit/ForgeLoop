---
id: FL-0136
title: "Environment and architecture visual upgrade with licensed assets: farms and crops, trees, rocks, markets, walls, castles, props, kingdom identity (D-057)"
track: asset
owner: forge-02
status: BUILDING
priority: P1
game: game-001
created: 2026-10-18
updated: 2026-10-19
depends_on: [FL-0135]
evidence:
  - tooling committed 9f4422c7; no third-party files committed (sha256 pins in blender/lib/envkit_sources.json)
  - bash blender/scripts/check.sh PASS; blender/tests 64 passed; forge validate 136 tasks 0 errors; ownership PASS; nothing third-party committed (sha256 pins + CC0 licence text only); Blender renders not Studio
  - bash blender/scripts/check.sh PASS (97 passed, 1 skipped; env_kit verify PASS); env_to_luau.py --validate-only valid on env.json (14 sink warnings) and env_spares.json (6); forge validate 136 tasks 0 errors; D-019 round 1 reviews in games/game-001/art/reviews/img/d057-env-nature-r1/review.json; part-count relief via blender/scripts/lune/EnvRelief.spec.luau (6553->2168, 8309->2765); Blender renders not Studio
  - lune world specs 494 passed (29 files; new KitNodeMarker 14, KitEnvDressing 20 with mutants); bash blender/scripts/check.sh PASS (98 passed, 1 skipped); stylua --check, selene 0 warnings, rojo build ok; env_to_luau.py --validate-only valid (env.json 16 sink warnings, env_spares.json 4); forge validate 138 tasks 0 errors; ownership PASS; D-019 replies in img/d057-env-nodes-r1/review.json and d057-env-dressing-r1/review.json; Blender renders not Studio
  - lune world specs (see report), bash blender/scripts/check.sh PASS (98 passed), stylua/selene clean, rojo build ok, env_to_luau --check up to date, forge validate 138 tasks 0 errors; KitCeiling scratch merge 26,293 / 22,082; EnvNodeFit on the final env.json; Blender renders not Studio
---

# Environment and architecture visual upgrade with licensed assets: farms and crops, trees, rocks, markets, walls, castles, props, kingdom identity (D-057)

## Outcome
The kingdoms and the valley look finished from the aerial camera:
- real crops in the fields;
- organic trees and rocks;
- castles, keeps, walls, markets and houses with the four kingdoms' architecture and banners;
- props that make a town feel lived in.

Construction stages and building levels stay readable.

## Context
- D-057 (same sources, style and import path as FL-0135). This task absorbs FL-0117 (wheat and boulders were parked waiting on the mesh pilot) and the look half of FL-0127 part 2 (the four kingdom identities; FL-0127's layout and fairness work stays there).
- Budgets: D-047's part ceiling becomes a triangle and draw budget for imported pieces (D-057 (5)). Record measured figures.

## Requirements
- Build kit pieces from the chosen pack, Blender-customised to the one style:
  - crops by growth stage;
  - tree and rock sets;
  - keep, house, farm, storehouse, barracks, market, wall, gate and tower;
  - props.
- Per-kingdom variants (roof, trim, banner and emblem, stone and wood tones) through the FL-0127 style table.
- `Kit.build` keeps its signature, stages and levels, and every footprint stays exactly as it is (`Kit.footprint` is the placement contract). Imported pieces must fit the existing footprints.
- The fallback to part-built models stays until the import.
- Same import-ready batch format as FL-0135. One owner import may carry both.
- Before/after renders of a starting kingdom and of all four kingdoms at the aerial distance.

## Validation
Automated: footprint parity specs (imported bounds within `Kit.footprint`), the fallback path, NodeKeepOut still green. Visual: D-019. Studio: B2x rows after the import.

## Completion criteria
- [ ] PR merged after review (FORGE-05 gate, FORGE-07 asset-safety and code review).
- [ ] Studio screenshot evidence in a delivered playable build.

## Log
- 2026-10-18 FORGE-00: created from the owner's visual-quality directive (D-057). It absorbs FL-0117 and FL-0127 part 2's look.
- 2026-10-19 forge-02: READY → BUILDING. Phase 1 only (coordinator): one comparison round S1 (FL-0013 generators) vs S2 (KayKit Medieval Hexagon Pack 1.0 CC0, pinned 84fa4e91, baked to vertex colours) vs S3 (part-built Kit) for keep L1/L3, house, barracks, watchtower, trees/boulder, wheat; branch forge/02-blender-fl0136-compare; tooling pushed (blender/lib/envkit.py, scripts/envkit_*.py, lune/EnvDump.spec.luau). Renders running; then ONE fresh D-019 reviewer, then STOP and report.
- 2026-10-19 forge-02: BUILDING → BUILDING. Phase 1 DONE (one comparison round, one fresh D-019 reviewer, stopped): reviewer SPLIT: buildings best D (current part-built Kit), trees C (FL-0013 generators), wheat B (own style-B); KayKit (S2) fails D-033 as a recolour-only set; only own wheat ships. Recommendation: hybrid on style B (own wheat, own trees and rocks, keep the Kit for identity buildings, KayKit only for common buildings after palette alignment). Record: games/game-001/art/reviews/env-mesh.md; sheets img/d057-env-review-r1/; branch forge/02-blender-fl0136-compare (no PR). Phase 2 awaits FORGE-00.
- 2026-10-19 forge-02: BUILDING → BUILDING. Phase 2 (D-057 (18)-(20)) nature and crop meshes DONE on forge/02-blender-fl0136-nature (stacked on #228; no PR by me; --force because the status stays BUILDING: K's Luau side and the owner's Studio import are still open): 67 style-B meshes in two FBX kits (env_kit_01 = the 52 ids the world places, env_kit_02 = 15 spares), env.json passes K's env_to_luau.py --validate-only; triangles measured from the FBX bytes (tree 318-652, bush 140-340, flower 228-312, rock 116-268, crop 1332-1430, haystack 196; kit 2 fences 72-84); fresh blind D-019 reviewers per family group: trees/bushes/flowers, rocks/boulders/nodes and crops all PASS (B 4s, crops cost 3), the part-built stand-ins NEEDS-WORK; part-count relief measured on the real WorldService with K's runtime: 6553 -> 2168 parts at shipped density, 8309 -> 2765 at density 1.0. Record: games/game-001/art/reviews/env-mesh.md Phase 2, handoff production/handoffs/2026-10-19-forge-02-env-kit-delivery.md. Blender renders, not Studio: import, tint, pivot, collision, draw calls and phone cost are unverified.
- 2026-10-19 FORGE-02 (Kit-runtime worker K, branch `forge/02-blender-fl0136-envrt`, stacked on #228): built the Luau/import side of the NATURE meshes (D-057 (18)-(20)), all HEADLESS (Lune, fake Models, a 15-id placeholder kit; nothing seen in Studio, no render). `Kit/EnvMesh.luau` + `Kit/EnvMeshData.luau` (committed EMPTY: every id is its part-built stand-in until P's data lands): for an id the data lists, `Kit.prop` takes the Model from `Forge.Assets` or `Forge.Assets.EnvKit` and makes it a stand-in-shaped prop (invisible anchored Root, pivot at the base centre, MeshPart `Body` at the data's bbox centre, everything else deleted, CanCollide only on an invisible `Collider` Part from the data or a family default, so WorldService.placeModel/decorate and the keep-out specs treat it like a stand-in); SIZE SANITY: bounds not within the data (max(0.1, 0.5 %), centre 0.25) -> the stand-in, logged once, never an error. Ids the data does not list are cloned as before. `art/env_kit/env_to_luau.py` (validate / convert / --check / --selftest / --print-budget; tris budgets tree 300-900, bush/rock/flower 40-400, crop/haystack/fence proposed 1,500/600; fit to the stand-in 85-115 % footprint, 75-125 % height, nodes <= 102 %), `blender/studio/import_env_kit.luau` (wraps the imported MeshParts, strips everything, size/rotation/mesh-id report, asks the Kit if it accepts each prop), `art/IMPORT_ENVIRONMENT.md`, specs `KitEnvMesh` (21) and `KitEnvMeshImport` (17), handoff to P `production/handoffs/2026-10-19-forge-02-env-kit-schema.md` (rules + the ids the world places with counts and measured stand-in sizes; crops: the NN of `farm_field_<crop>_NN` is a static variant, nothing renders growth by id). 17 mutation rows killed (report). Still open: P's env.json/FBX, the owner's import, D-019 renders, the D-047 relief measured on the real kit, Studio rows.
- 2026-10-19 forge-02: BUILDING → BUILDING. Phase 3 DONE on forge/02-blender-fl0136-dressing (stacked on PR 247, no PR by me; --force because the status stays BUILDING): FORGE-00's decisions applied: ripe only, iron/crystal ore not promoted (bench), nodes readable at 170 studs by a Kit-level marker (post + glowing orb, 2 parts x 38 nodes = +76 parts; mesh scale is not available: 0.7-3.3 % of room measured on the real layout), fences (48), cabbage variants and rim cliffs (12) placed ONLY as imported meshes via Kit.envMeshReady (a world without the kit is unchanged), env_kit_01 is now 58 ids (the 52 reviewed ids unchanged), kit 2 is 9 spares; fresh blind D-019 reviewers: node markers SET B PASS (cohesion 3), farm dressing SET B PASS; measured: part-built world 6,945 parts -> 2,770 with the kit at the shipped density (8,696 -> 3,364 at 1.0), the kit world draws 175,076 triangles (233,894 at 1.0), kit 1 22,834 triangles, kit 2 4,510. Record: games/game-001/art/reviews/env-mesh.md Phase 3; handoff production/handoffs/2026-10-19-forge-02-env-dressing-delivery.md. Blender renders, not Studio: orb glow, onboarding highlight, fence collision, cliffs on the rim, draw calls and phone cost are unverified.
- 2026-10-19 forge-02: BUILDING → BUILDING. Phase 3 round 2 (FORGE-00 ruling) DONE on forge/02-blender-fl0136-dressing (--force: status stays BUILDING): orb markers kept as an interim placeholder; rim cliffs dropped (no cliff placement at any density, rock_cliff_01/02 back on the bench) so env_kit_01 = 56 placed ids (52 + fences 01/02 + cabbage 01/02), env_kit_02 = 11 spares; tree_oak_05 trimmed 5 % horizontally (true outline 12.58 -> 11.955 vs 12.23 allowed: 0.35 over -> 0.275 inside; the other 51 phase-2 meshes byte-identical, subset hash 182b1116d1ceffea unchanged; the hash of the 52 moved 61bac208a4421907 -> d21f68e9d072bad8 because of oak_05 alone; no new fresh review); restated: part-built world 6,945 parts -> 2,734 with the kit at the shipped density (8,696 -> 3,331 at 1.0), kit 1 22,564 triangles, kit 2 4,780, the kit world draws 173,456 triangles (232,412 at 1.0); D-047 combined worst case with FL-0128's war kit via KitCeiling on a scratch merge (74e2e953 + this branch): 26,293 / 27,000 without the kit (26,217 + 76 markers), 22,082 with it. Headless measures, not Studio: the owner needs one row for node/building/field overlaps after the env import.
- 2026-10-22 forge-02: phase 3 (#274) and its follow-ups (#289: IMPORT_ENVIRONMENT.md props = 56 and the two node marker Parts named, EnvMesh.ready records and logs a bad imported dressing mesh, fence collider 2.8 not 4, rim-cliff texts) are MERGED; the owner re-imports the 56-object env_kit.fbx with B22.1. Fence placement over buildable ground is FORGE-01's (field no-build area, #288). The visual upgrade pass 1 (lighting #287, ground and roads #296, nature, citizens) continues under the P0; stays BUILDING.
