# Handoff: FORGE-02 K → FORGE-02 P (cc FORGE-00) · FL-0136 nature meshes: what `env.json` and the FBX must satisfy · 2026-10-19

## What I need / what I'm giving you
The Luau and Studio side of the nature meshes is built against `CONTRACT_ENV.md`; these are the rules my validator and the Kit enforce, with the few places where I tightened
or added to the contract. Run the validator on your `env.json` before every handoff; it names each problem:

```
python3 games/game-001/art/env_kit/env_to_luau.py --validate-only     # reads games/game-001/art/env_kit/env.json
python3 games/game-001/art/env_kit/env_to_luau.py                      # lead only: writes src/shared/Kit/EnvMeshData.luau
```

## What the Kit does with your files (so you can predict it)
- `Kit.prop(assetId)` takes the Model `assetId` from `ReplicatedStorage.Forge.Assets` (or its `EnvKit` folder). `blender/studio/import_env_kit.luau` makes that Model from each
  MeshPart of the imported FBX: Root (invisible, anchored, pivot at the BASE CENTRE) + MeshPart `Body` placed at your `bbox_center`. Roblox places nothing from your scene layout.
- **Size sanity (the part you can break):** the Body's size must match `size` in `env.json` within max(0.1, 0.5 %) per axis, and its centre `bbox_center` within 0.25. Otherwise `Kit.prop`
  silently builds the part-built stand-in for that id (and logs it once). So `size` must be the mesh's true bounding-box size in studs after export (1 Blender unit = 1 stud, no scale on
  the object, transforms applied), and the mesh must be unrotated (Y up, -Z front as the char kit's export).
- The imported Model is stripped to Root + Body: no scripts, no SurfaceAppearance (no PBR), no children, no attributes, no tags. Colours live in the vertex colours only;
  `tint` is `"fixed"`; Kit sets `MeshPart.Color` white, material SmoothPlastic, `CollisionFidelity = Hull`.
- **Physics like the stand-ins:** the Body never collides. What the part-built props block (trunks, rocks, bushes, low parts) the Kit adds as an invisible solid `Collider` Part at the base
  centre: tree = a trunk (20 % of the wider side, 1.4-3.4 studs, up to 7 high), rock/haystack = 80 % of the footprint (up to 7 high), bush = 60 % of the footprint (3 high), fence = its length,
  flower/crop = nothing. Override per id with `"collider": [w, h, d]` or `false` (height is capped at 7 = WorldService.COLLIDE_HEIGHT). Walkable crops and flowers is a deliberate difference:
  by the code, the part-built flowers and bushes block the ruler too (parts default to CanCollide true and `WorldService.decorate` only lets parts above 7 studs through; unverified in Studio);
  say if you want flowers solid.

## `env.json` v1 (the format; full text in the docstring of `env_to_luau.py`)
`{ "schema_version": 1, "unit": "stud", "props": { "<assetId>": { family, bbox_center, size, tris, tint: "fixed", standin_size, node, collider?, fit_note? } } }`
- **assetId**: lowercase, ends `_NN` (`bush_01` is fine). Ids the world never places make the Kit spec fail (a typo would build a crate), so use the table below.
- **family**: `tree | bush | rock | flower | crop | haystack | fence`.
- **bbox_center / size**: Roblox axes (+X right, +Y up, -Z front), from the base centre; the base must sit on y = 0 (error beyond -1.0..+0.5 below/above, warning beyond 0.1); the mesh stands over
  its base centre (|centre x or z| <= half the size, normally ~0).
- **tris**: 1..20,000 per mesh, and the family budget: **tree 300-900, bush/rock/flower 40-400** (contract), **crop 40-1,500, haystack/fence 40-600 (my proposal, the contract is silent)**.
  One body mesh per prop (one MeshPart).
- **standin_size**: the part-built prop's DRAWN bounds (visible parts, pivot frame), taken from the table below or `blender/scripts/lune/EnvDump.spec.luau`. The Kit spec re-measures the live
  stand-in and fails if your number is off by more than 5 %.
- **Fit rule (an error, not advice):** footprint `max(x, z)` within 85-115 % of the stand-in's, height within 75-125 %; a prop used as a resource NODE (`node: true`) footprint within 85-102 %.
  A larger deviation needs `"fit_note": "<why the role needs it>"`.
- **node**: `true` for the ids Layout uses as resource nodes (below); the spec checks it against Layout.

## Ids the world places (WorldPlan.props at density 1, all four kingdoms dressed, plus Layout.resourceNodes) and the stand-in each replaces
Measured 2026-10-19 with a Lune probe over `Kit.prop` (visible parts, pivot frame, studs). `placed` counts placements; `node` counts Layout resource nodes that use the id (an id can be both).
Note `WorldService` dresses one kingdom by default (`DRESSED = { crimson }`), so a build places fewer than `placed`. Rows marked out of scope are not part of this slice.

| id | placed | node | stand-in parts | stand-in size (x y z) | |
|---|---|---|---|---|---|
| `bridge_stone_01` | 1 |  | 13 | 16 x 12.8 x 60 | out of scope |
| `bridge_stone_02` | 1 |  | 13 | 16 x 12.8 x 60 | out of scope |
| `bush_01` | 8 |  | 5 | 7.4 x 5.2 x 6.9 |  |
| `bush_02` | 13 |  | 10 | 7.3 x 5.1 x 7.0 |  |
| `bush_03` | 16 | 8 | 10 | 6.1 x 5.5 x 6.7 |  |
| `bush_04` | 19 |  | 5 | 6.7 x 4.9 x 6.8 |  |
| `bush_05` | 17 |  | 10 | 7.0 x 5.5 x 7.0 |  |
| `bush_06` | 11 |  | 10 | 6.7 x 5.2 x 6.5 |  |
| `bush_07` | 14 |  | 5 | 6.9 x 5.3 x 7.6 |  |
| `bush_08` | 12 |  | 10 | 6.9 x 5.2 x 6.5 |  |
| `farm_field_cabbage_03` | 4 |  | 65 | 38 x 3.1 x 28 | out of scope |
| `farm_field_wheat_01` | 4 |  | 17 | 38 x 2.4 x 28 |  |
| `farm_field_wheat_02` | 4 |  | 17 | 38 x 2.4 x 28 |  |
| `farm_haystack_01` | 4 |  | 4 | 7.3 x 6.2 x 6.2 |  |
| `plant_flowers_01` | 4 |  | 9 | 4.1 x 3.0 x 3.0 |  |
| `plant_flowers_02` | 5 |  | 9 | 3.7 x 3.0 x 3.7 |  |
| `plant_flowers_03` | 5 |  | 9 | 4.2 x 2.9 x 3.4 |  |
| `plant_flowers_04` | 6 |  | 9 | 4.4 x 3.0 x 3.1 |  |
| `plant_flowers_05` | 7 |  | 9 | 3.3 x 3.1 x 3.0 |  |
| `plant_flowers_06` | 4 |  | 9 | 3.5 x 3.0 x 3.7 |  |
| `prop_banner_blue_01` | 2 |  | 13 | 4 x 12.7 x 2 | out of scope |
| `prop_banner_blue_02` | 2 |  | 13 | 4 x 12.7 x 2 | out of scope |
| `prop_banner_green_01` | 2 |  | 13 | 4 x 12.7 x 2 | out of scope |
| `prop_banner_green_02` | 2 |  | 13 | 4 x 12.7 x 2 | out of scope |
| `prop_banner_red_01` | 2 |  | 11 | 4 x 12.7 x 2 | out of scope |
| `prop_banner_red_02` | 2 |  | 11 | 4 x 12.7 x 2 | out of scope |
| `prop_banner_yellow_01` | 2 |  | 12 | 4 x 12.7 x 2 | out of scope |
| `prop_banner_yellow_02` | 2 |  | 12 | 4 x 12.7 x 2 | out of scope |
| `prop_cart_02` | 4 |  | 10 | 5.4 x 5.9 x 10.2 | out of scope |
| `prop_goods_01` | 4 |  | 8 | 8.4 x 3.9 x 3.9 | out of scope |
| `prop_goods_02` | 4 |  | 8 | 8.4 x 3.9 x 3.9 | out of scope |
| `prop_well_01` | 4 |  | 10 | 7.6 x 8.7 x 6 | out of scope |
| `resource_ore_03` | 0 | 4 | 10 | 11.4 x 8.1 x 9.9 |  |
| `resource_ore_04` | 0 | 1 | 10 | 11.6 x 8.1 x 9.0 |  |
| `resource_stone_01` | 0 | 4 | 8 | 16.8 x 7.8 x 10.7 |  |
| `resource_stone_02` | 0 | 4 | 8 | 16.8 x 7.8 x 11.3 |  |
| `resource_stone_03` | 0 | 1 | 8 | 16.7 x 7.8 x 10.5 |  |
| `rock_boulder_l_01` | 23 |  | 5 | 18.0 x 9.1 x 14.3 |  |
| `rock_boulder_l_02` | 15 |  | 5 | 18.7 x 9.2 x 15.9 |  |
| `rock_boulder_l_03` | 23 |  | 5 | 19.0 x 9.5 x 17.2 |  |
| `rock_boulder_m_01` | 20 |  | 4 | 6.2 x 5.3 x 8.9 |  |
| `rock_boulder_m_02` | 20 |  | 4 | 6.4 x 6.0 x 9.3 |  |
| `rock_boulder_m_03` | 18 |  | 4 | 7.3 x 6.0 x 9.7 |  |
| `rock_boulder_s_01` | 18 |  | 3 | 6.2 x 3.8 x 4.9 |  |
| `rock_boulder_s_02` | 13 |  | 3 | 6.4 x 3.8 x 5.3 |  |
| `rock_boulder_s_03` | 20 |  | 3 | 6.8 x 3.7 x 5.7 |  |
| `tree_birch_01` | 11 |  | 9 | 10.1 x 22.2 x 8.1 |  |
| `tree_birch_02` | 9 |  | 9 | 8.2 x 20.8 x 10.3 |  |
| `tree_birch_03` | 9 |  | 9 | 8.8 x 22.6 x 10.0 |  |
| `tree_birch_04` | 8 |  | 9 | 10.5 x 21.2 x 9.0 |  |
| `tree_birch_05` | 11 |  | 9 | 8.6 x 23.0 x 9.4 |  |
| `tree_birch_06` | 11 |  | 9 | 8.6 x 21.6 x 8.3 |  |
| `tree_oak_01` | 9 | 4 | 16 | 18.9 x 25.5 x 21.0 |  |
| `tree_oak_02` | 22 |  | 16 | 16.3 x 24.6 x 16.9 |  |
| `tree_oak_03` | 13 | 4 | 16 | 20.8 x 25.5 x 22.7 |  |
| `tree_oak_04` | 18 |  | 16 | 18.5 x 24.5 x 17.3 |  |
| `tree_oak_05` | 17 | 4 | 16 | 20.0 x 25.2 x 21.8 |  |
| `tree_oak_06` | 19 |  | 16 | 21.3 x 24.9 x 18.6 |  |
| `tree_oak_07` | 15 |  | 16 | 14.3 x 25.9 x 14.9 |  |
| `tree_oak_08` | 12 |  | 16 | 22.4 x 24.7 x 20.4 |  |
| `tree_pine_01` | 22 |  | 22 | 16.4 x 29.6 x 16.4 |  |
| `tree_pine_02` | 15 | 4 | 22 | 16.4 x 32.3 x 16.4 |  |
| `tree_pine_03` | 16 |  | 22 | 16.1 x 30.0 x 16.1 |  |
| `tree_pine_04` | 12 |  | 22 | 16.4 x 32.6 x 16.4 |  |
| `tree_pine_05` | 17 |  | 22 | 16.4 x 30.3 x 16.4 |  |
| `tree_pine_06` | 16 |  | 22 | 16.1 x 28.0 x 16.1 |  |

**Crops today (answer to the contract's question):** `WorldPlan` places `farm_field_<crop>_<NN>` per terrain field with `NN = 1 + (fieldIndex % 3)` and `crop` = the field's crop (`wheat` or
`cabbage`). The NN is only a visual VARIANT of a static field: **nothing renders growth by id**, no stage swaps (the sim's crop growth is not drawn). So `farm_field_wheat_01..03` are three
variants of a ripe-looking field, 38 x 28 studs on a soil bed (`Props.FIELD_SIZE`), not sprout/growing/ripe. Today's data shows wheat 01 and 02 and cabbage 03 placed; provide wheat 01..03.
Draw order matters for the field: the stand-in's soil bed is 0.5 high over a terrain field 0.2 high, and the keep-out specs treat the 38 x 28 footprint as fixed.

## Done (with commits)
- Branch `forge/02-blender-fl0136-envrt` (stacked on #228): `Kit/EnvMesh.luau`, `Kit/EnvMeshData.luau` (EMPTY until your data lands), `Props.prop` hook, `art/env_kit/env_to_luau.py`
  (+ `make_placeholder_env.py`), `blender/studio/import_env_kit.luau`, `art/IMPORT_ENVIRONMENT.md`, specs `KitEnvMesh`, `KitEnvMeshImport`.

## Evidence
- Headless Lune over fake Models and a placeholder kit of 15 ids (every family, nodes, both collider forms, `fit_note`); `env_to_luau.py --selftest` (broken-kit table). **Not seen in Studio.**

## Interfaces touched
Additive: `Kit.envMeshStatus()`; `Props.prop` also looks in `Forge.Assets.EnvKit`. No change to ids, `Kit.prop`'s signature, the wire or any contract.

## Open issues and risks
- Changes to the contract: `fit_note`, `collider`, the crop/haystack/fence budgets, ids must be placed by the world, `standin_size` re-measured by the spec. Tell me if any of them is wrong.
- A leaning mesh's bounding box is larger than its trunk; `size` is the true bbox (the Kit does not look inside the mesh), the collider is separate.
- Mesh ids cannot be live-synced by Rojo: the owner exports the `EnvKit` folder as `roblox/assets/EnvKit.rbxm` after the Studio import (`IMPORT_ENVIRONMENT.md`).

## Next actions for the receiver
1. Build the families in scope with `env.json` as above; run `--validate-only` until it is clean.
2. After the lead runs `env_to_luau.py`, `lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/world KitEnvMesh` also checks every id against
   the world, the budgets and the live stand-ins; fix what it names.

## Files to read
- `games/game-001/art/env_kit/env_to_luau.py` — docstring: the format and every rule
- `games/game-001/src/shared/Kit/EnvMesh.luau` — header: what the Kit does with a Model
