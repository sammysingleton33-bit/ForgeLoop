# Environment and architecture mesh comparison (FL-0136 phase 1, D-057 (3)) — FORGE-02 worker B

One comparison round, one fresh image-only D-019 reviewer, then stop. Branch `forge/02-blender-fl0136-compare` (from main f4b4fce0). No runtime Luau
was touched, no full environment was built, no PR. Everything below was rendered in Blender (Cycles); **Blender renders are not Studio renders**.

## What was compared
Same six subjects in every source, fitted to the exact `Kit.footprint(type, level)`:

| | source | how it is used here |
|---|---|---|
| **S1** | the project-original FL-0013 generators on main (`castle_keep`, `house_cottage`, `building_barracks`, `castle_tower`, `tree_*`, `rock_boulder`, `farm_field`) | built in-process by `blender/build.py`'s own `asset.Builder`, palette texture baked to vertex colours exactly like the other sources |
| **S2** | KayKit Medieval Hexagon Pack 1.0 (CC0, Kay Lousberg) | glTF read from the gitignored cache, atlas baked to vertex colours, flat shading, uniform fit |
| **S3** | the current part-built Kit (primitive Parts, with FL-0127's `KingdomStyle`) | `blender/scripts/lune/EnvDump.spec.luau` dumps `Kit.build` / `Kit.prop` read-only; `lib/kitparts.py` rebuilds the Parts |
| **B** | own style-B wheat (`lib/envkit.py: wheat_b`), because the pack has no crop (only `building_grain`, a 230-triangle pile) | faceted, flat colours, three growth stages |

Subjects: keep level 1 (32 x 32; crimson and emerald), keep level 3 (46 x 46), house (20 x 16), barracks (30 x 20), watchtower (14 x 14; crimson and emerald), a lone
oak + a stand of trees + a boulder, a ripe wheat field (38 x 28), plus (not in the rubric) construction stages 1 to 3, a settlement per source, and the three wheat growth stages.
Cameras: RulerCameraController overview, 70 degrees vertical FOV: **82 studs at 44.3 degrees** (its `pitchFor(82)`) and **170 studs at 50 degrees** (the D-019 aerial view; the
controller itself would pitch 57 degrees at 170). 1280 x 720, 20 samples + denoising. Four mesh-kit citizens (farmer, soldier, governor, hauler from `games/game-001/art/char_kit`,
crimson) stand in front of every subject for scale and cohesion.

Fit rule (`lib/envkit.fit_footprint`): uniform scale to the largest size whose XZ box fits, bounding-box centre on the origin, base on y = 0, front -Z. Trees are scaled to the Kit's oak
height (25.5 studs), the boulder to 7.5 studs. S3 is measured as built (the Kit allows entrance steps up to 2 studs beyond the front edge).

## Provenance (nothing third-party is committed except the pins)
KayKit-Medieval-Hexagon-Pack-1.0, https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0, commit **84fa4e91af6a88989be7c99e0891cede11f2ca38** (verified with `git ls-remote`),
licence Creative Commons Zero (CC0 1.0), `LICENSE.txt` sha256 `881e50d3629fba90629bedc65e9e6f47cfab3609598c296dcb7f70ea83174360` (text committed as `blender/lib/KAYKIT-HEXAGON-LICENSE.txt`).
`bash blender/scripts/fetch_kaykit.sh` pins and fetches the repository into `blender/exports/.cache` (gitignored). The sha256 of the 48 pack files this round reads (glTF, bin, atlas of the
red / green hue buildings, neutral wall / stage / grain pieces, the nature pieces) are in `blender/lib/envkit_sources.json`; `tests/test_envkit.py` re-checks them against the cache.
The committed sheets are renders derived from CC0 files; no pack mesh, texture or glTF is committed. No Quaternius or other non-CC0 file was used.

## Fit and triangle table (measured, `envkit_compare.py` JSON reports)
| subject | footprint | source | scale | XZ box (studs) | fills X / Z | height | triangles | MeshParts or Parts | inside the footprint |
|---|---|---|---|---|---|---|---|---|---|
| keep L1 crimson | 32 x 32 | S1 | 0.714 | 32.0 x 28.9 | 100% / 90% | 60.2 | 13,566 | 1 MeshPart | yes |
| keep L1 crimson | 32 x 32 | S2 | 14.18 | 28.0 x 32.0 | 88% / 100% | 56.4 | 5,659 | 1 MeshPart | yes |
| keep L1 crimson | 32 x 32 | S3 | native | 31.4 x 32.7 | | 63.7 | primitives | 218 Parts | front steps +1.0 (Kit allows 2) |
| keep L1 emerald | 32 x 32 | S1 | 0.586 | 32.0 x 26.0 | 100% / 81% | 37.8 | 14,068 | 1 MeshPart | yes |
| keep L1 emerald | 32 x 32 | S2 | 14.18 | 28.0 x 32.0 | 88% / 100% | 56.4 | 5,659 | 1 MeshPart | yes |
| keep L1 emerald | 32 x 32 | S3 | native | 32.0 x 33.0 | | 53.6 | primitives | 236 Parts | front steps +1.0 |
| keep L3 crimson | 46 x 46 | S1 | 1.027 | 46.0 x 41.6 | 100% / 90% | 86.5 | 13,566 (same mesh as L1) | 1 MeshPart | yes |
| keep L3 crimson | 46 x 46 | S2 | kitbash | 46.0 x 46.0 | | 56.4 | 20,575 | 17 MeshParts | yes |
| keep L3 crimson | 46 x 46 | S3 | native | 45.4 x 46.7 | | 86.2 | primitives | 274 Parts | front steps +1.0 |
| house | 20 x 16 | S1 | 0.761 | 15.5 x 16.0 | 78% / 100% | 20.8 | 3,928 | 1 MeshPart | yes |
| house | 20 x 16 | S2 | 18.74 | 14.8 x 16.0 | 74% / 100% | 17.4 | 1,011 | 1 MeshPart | yes |
| house | 20 x 16 | S3 | native | 18.6 x 16.4 | | 32.2 | primitives | 138 Parts | front steps +0.5 |
| barracks | 30 x 20 | S1 | 0.598 | 28.6 x 20.0 | 95% / 100% | 25.6 | 10,674 | 1 MeshPart | yes |
| barracks | 30 x 20 | S2 | 12.77 | 18.4 x 20.0 | 61% / 100% | 20.9 | 4,007 | 1 MeshPart | yes |
| barracks | 30 x 20 | S3 | native | 26.6 x 17.8 | | 21.7 | primitives | 122 Parts | yes |
| watchtower crimson | 14 x 14 | S1 | 0.751 | 14.0 x 14.0 | 100% / 100% | 53.0 | 4,228 | 1 MeshPart | yes |
| watchtower crimson | 14 x 14 | S2 | 12.14 | 12.1 x 14.0 | 86% / 100% | 26.6 | 2,138 | 1 MeshPart | yes |
| watchtower crimson | 14 x 14 | S3 | native | 11.9 x 13.7 | | 53.0 | primitives | 115 Parts | yes |
| watchtower emerald | 14 x 14 | S1 | 0.676 | 14.0 x 14.0 | 100% / 100% | 34.4 | 4,388 | 1 MeshPart | yes |
| watchtower emerald | 14 x 14 | S2 | 12.14 | 12.1 x 14.0 | 86% / 100% | 26.6 | 2,138 | 1 MeshPart | yes |
| watchtower emerald | 14 x 14 | S3 | native | 12.5 x 14.0 | | 42.3 | primitives | 107 Parts | yes |
| oak + stand (8) + boulder | free | S1 | as authored | | | 40.2 | 29,688 (10 trees and rock) | 10 MeshParts | |
| oak + stand (6) + boulder | free | S2 | 21.04 (oak = 25.5 tall) | | | 27.2 | 1,971 | 8 MeshParts | |
| oak + stand (8) + boulder | free | S3 | native | | | 32.3 | primitives | 146 Parts | |
| wheat, ripe | 38 x 28 | S1 | 1.16 | 36.6 x 28.0 | 96% / 100% | 5.8 | 2,844 | 1 MeshPart | yes |
| wheat, ripe | 38 x 28 | S3 | native | 38.0 x 28.0 | | 2.4 | primitives | 17 Parts | yes |
| wheat, ripe | 38 x 28 | B (own) | native | 38.0 x 28.0 | | 4.3 | 1,776 (stages 1 to 3: 4,644 together) | 1 MeshPart | yes |
| settlement (keep, barracks, 2 houses, tower, field, trees, boulder) | | S1 / S2 / S3 | | | | | 68,856 / 17,573 / primitives | 16 / 14 MeshParts / 894 Parts | |

Back-of-envelope (unverified against any device): at S1's manifest triangle counts one VS-2 kingdom of buildings (keep L3 13.6k, ten houses 39k, two barracks 21k, two towers 8k, 12 wall
segments about 26k, a gate about 9k) is about 0.12 million triangles, so about 0.5 million for four kingdoms, before trees. S3 stays inside its own D-047 budget (a VS-2 kingdom is about 4.1k parts, the
world about 17k of the 25k cap, `Kit/Buildings.luau`); the reviewer scored cost from the numbers above only.

### Shape changes the fit needed
- **S2 keep** reads as a tall tower, not a keep: the pack's "castle" is 1.98 x 3.98 x 2.26 units (one hex tile and tall). Uniform scale to 32 gives 28.0 x 56.4 x 32.0 (88% of X). It stays a tower at 170 studs
  (the reviewer says so). **Level 3** has no pack model: I built a kitbash (castle at the level 1 scale, four tower_A corner towers 10 x 10, twelve `wall_straight` segments with one `wall_straight_gate`; 17 MeshParts, 20,575 triangles).
- **S2 barracks** fills 61% of X at the largest uniform scale (the pack's barracks is nearly square): it needs a 1.5x non-uniform stretch, or two copies side by side, to use the 30 x 20 footprint. The house fills 74% of X.
- **S2 watchtower** is 26.6 studs tall (the Kit's is 53): half height at the same footprint.
- **S2 trees** are stacked-cone conifers and one round "single B"; there is **no oak**. The "oak" is the pack's single B scaled to the Kit's oak height; the stand uses the pack's groves.
- **S1 keep** needs scale 0.714 at level 1 (so its detail shrinks by 29%) and 1.03 at level 3: the same mesh, no level geometry. The four hues have different sizes (emerald is a wide low manor: 37.8 tall at L1
  against crimson 60.2), so the footprint fit changes the keep's height per kingdom. S1's round tower has its `door` socket on +Z: it needs a 180 degree yaw to face -Z.
- **S1 house** has a thatch roof for crimson (variant 01, red in `kingdom` only), which reads pale and grass-like from above; the tile variants are blue.
- **S3** needed nothing (native footprints); its XZ box exceeds the footprint only by entrance steps (0.5 to 1.0 stud, the Kit allows 2).

## Renders and sheets
`games/game-001/art/reviews/img/d057-env-review-r1/`: `sheet_keep_L1`, `sheet_keep_L3`, `sheet_house`, `sheet_barracks`, `sheet_watchtower`, `sheet_nature`, `sheet_wheat`, `sheet_stages`, `sheet_town` (JPEG, 36 to 215 KB).
One row per camera; columns are sources with **blind letters** (a fixed letter per source over all sheets, a different column order per sheet; panels of a row share one crop; aerial panels are enlarged about 1.5x and carry a
1:1 inset of the subject where it fits). **Key** (`games/game-001/art/reviews/env-mesh-key.json`, withheld until the review was recorded): **A = S2 KayKit, B = own style-B wheat, C = S1 generators, D = S3 part-built Kit**.
Raw renders: `/tmp` only (reproducible, see the commands below).

## Fresh D-019 reviewer (one session, image-only, sparse checkout of the image folder; reply verbatim in `img/d057-env-review-r1/review.json`)
Rubric: silhouette / variation / readability >= 4; proportions / palette / detail / cohesion / cost >= 3.

| family | set | silhouette | variation | readability | proportions | palette | detail | cohesion | cost | result |
|---|---|---|---|---|---|---|---|---|---|---|
| buildings | A (S2) | 3 | 3 | 4 | 4 | 4 | 4 | 4 | 4 | fails silhouette and variation: same silhouette in both hues |
| buildings | C (S1) | 4 | 4 | 4 | 4 | 3 | 4 | 4 | 1 | fails cost only |
| buildings | D (S3) | 4 | 4 | 4 | 3 | 4 | 3 | 3 | 1 | fails cost only (reviewer's cost; see above) |
| trees, rocks | A (S2) | 3 | 2 | 4 | 4 | 4 | 3 | 4 | 5 | fails silhouette, variation |
| trees, rocks | C (S1) | 3 | 4 | 4 | 4 | 3 | 4 | 4 | 1 | fails silhouette, cost |
| trees, rocks | D (S3) | 3 | 3 | 3 | 3 | 4 | 3 | 3 | 2 | fails silhouette, variation, readability, cost |
| wheat | B (own) | 4 | 2 | 5 | 4 | 5 | 3 | 3 | 5 | fails variation only (one plot, no variants yet) |
| wheat | C (S1) | 3 | 3 | 3 | 4 | 3 | 4 | 4 | 4 | fails silhouette, variation, readability |
| wheat | D (S3) | 3 | 2 | 3 | 3 | 3 | 2 | 2 | 4 | fails four |

Reviewer picks: best at 170 studs next to the citizens: **buildings D (S3), trees C (S1), wheat B (own)**; kingdom identity not by colour alone: **D** (S1 close behind; **A fails D-033**: keep and tower have the
identical silhouette in both hues, only the roof colour changes); hybrid pick: buildings D, trees C, wheat B, but "partly" one style; ship: only wheat B (true). Verdict **SPLIT** (no set wins every family).
Reviewer defects, short: A: same silhouette per hue, one repeated cone tree, keep reads as a tower; C: cost (keep 13.5k, settlement 68k, trees 29k), dull brownish colours fading into the grass, thin wheat, thatch house like the
grass; D: about 900 Parts per settlement, flat tan wheat slabs, bare scaffolding stages, boxy oversized house and barracks; B: identical cones, no variation between plots. The reviewer is one session (one level of
variance is normal; the earlier citizen rounds swung by a level between sessions).

## My own look (every sheet and the raw renders were opened)
- **Keep:** S1 is the richest and most "castle" (wide, turreted, flag), S3 has the strongest aerial read (a red spire cluster that is visible at 10 px) and S2 is a tidy but clearly different building (a tall tower). At 170 studs S1 and S3 are close; S2 is the
  easiest to like and the least keep-like. The emerald hues: S1 a squat timber manor with green roofs, S3 pyramid-capped round towers, S2 the same tower with green roofs (the D-033 failure).
- **House and barracks:** S2's house is the cutest and its red roof is the strongest colour read from above; S2's barracks (a stone fortress with red roofs) reads "military" at once; S3's house and barracks are tall plain slabs; S1's are detailed but beige.
- **Trees:** S1's soft blobs look best close up, S2's cone groves read as forest from far but are one shape, S3's faceted trees are small and dark but share the citizens' faceted language.
- **Wheat:** the own style-B field is clearly the best of the three at both distances; S3 reads as pale planks, S1 as a fenced bed with sparse spikes (the reason FL-0013 parked it).
- **Cohesion:** the citizens (faceted, flat colours) sit best beside S3 and S2; S1's textured palette gradients are a little softer than the citizens.

## What a runtime would need per building (MeshParts) and what is hard
| | S1 | S2 | S3 (today) |
|---|---|---|---|
| MeshParts per building | 1 body per kingdom hue (hue-specific caps and colours; recolour = another mesh) | recommended **2**: one neutral body + one tintable team-colour mesh. The four hues share identical geometry (verified for castle, barracks, home_A, tower_A, market, blacksmith); the team-colour region is only 4% to 15% of the triangles and **7% to 26% of the surface** (`blender/scripts/envkit_hue_diff.py`) | 115 to 274 Parts (keep L1 218, house 138) |
| per-kingdom cap silhouettes (D-033) | native: spire, pyramid, hoarding, onion; four meshes, 55,028 triangles for the four keeps, 17,706 for the four towers | **not in the pack**: recolour only. Needs our own cap meshes per kingdom (4 caps per keep and tower type, about 200 to 600 triangles each, as separate MeshParts on a cap attachment) | native via `KingdomStyle`, same part count |
| levels 1 to 3 of the keep | none (L1 to L3 is a scale: 0.71 to 1.03) | none (kitbash needed: 17 MeshParts, 20.6k triangles) | native (218 / L2 / 274 Parts) |
| construction stages 1 to 3 | none | generic `building_stage_A/B/C` (784 / 902 / 1,218 triangles) and `scaffolding` (2,672): piles and frames, not the building in progress; a per-type stage mesh set would have to be authored | native (32 / 57 / 64 Parts for the keep), readable scaffolding |
| recolouring | rebuild | tint the team mesh (`MeshPart.Color` x white vertex colour) | `Kit.setKingdomColor` in place |
| Door / WorkSpot / Rally / DropOff | stay part-built attachments on the Root; the mesh has sockets `door` / `rally` / `spawn` in the manifest (the tower's door faces +Z) | no sockets: door position must be authored per model | native attachments |
| collision | manifest names `PreciseConvexDecomposition` | none authored | Parts collide natively |
| triangles per building | 3.9k to 14.1k | 1.0k to 5.7k | primitives (about 12 or more triangles per Part) |
Mesh limit: 20,000 per mesh (S2's L3 kitbash is 17 meshes, each far below).

## Recommendation (FORGE-02, for FORGE-00 to decide; the reviewer is split, so this is mine)
**A hybrid on one style (B, faceted, flat colours, vertex colours) with the current Kit kept where it already wins, and no wholesale switch to either pack.**
1. **Wheat / crops: own style-B** (`wheat_b`, 1.8k triangles, three growth stages, accepted by the reviewer and by my own look). Phase 2: stage meshes, a few plot variants (the reviewer's variation 2), cabbage and one more crop.
2. **Trees and rocks: our own style-B generators** (as for the citizens), 300 to 900 triangles per tree, several species and sizes, rocks 100 to 200. Reason: S1's trees look best but cost 3 to 4k each (cost 1);
   S2's are cheap but conifer-only, one repeated shape, no oak (variation 2); S3 spends 9 to 22 Parts per tree and its trees look small. Own generators fit the citizens, the budget and the vertex-colour pipeline. KayKit's groves can stay as an optional
   cheap filler for far forest masses (about 430 to 1,500 triangles per grove) if a phase 2 look test shows they sit well beside our trees.
3. **Buildings: keep S3 (the part-built Kit) as the shipping baseline** because it is the only source that already carries the four kingdom silhouettes (the D-033 rule), levels, stages and the Door / WorkSpot contract inside the D-047 part budget. Upgrade
   only where a mesh clearly wins, in this order: (a) **common buildings with no kingdom silhouette duty** (house, storehouse, market, blacksmith, windmill, mine, lumber mill) from S2 (1.0k to 3.1k triangles, strong roof-colour read, hue by team-colour mesh), after a palette alignment
   with the citizens and a footprint stretch for the wide ones; (b) **identity buildings** (keep, tower, gate, wall) only as our own style-B meshes that reuse S1's silhouettes decimated to about 4 to 6k triangles with separate cap meshes; do not import S2's castle or tower for these.
   The reviewer's own hybrid (D buildings, C trees, B wheat) is the same direction; I replace C's trees with an own generator for cost.
4. **Not recommended:** S2 for the keep and towers (fails D-033, tower-like keep, half-height tower); S1 as the building set at its current triangle counts (about 0.5 million triangles for four kingdoms, unverified against a phone, and per-hue meshes);
   a blanket move from S3 to meshes (the current Kit's architecture scored mostly 4 in its own D-019 rounds, `kit-architecture.md`, and again here on silhouette, variation and readability).
Risks: (i) "partly one style" (reviewer): mixing KayKit houses with part-built keeps and our own trees must be judged on a settlement sheet in phase 2 before any import; (ii) own nature generators are new work and the first round may need two author rounds (D-019);
(iii) the importer, vertex-colour tint and `MeshPart` pivot are unverified in Studio (as for the citizens); (iv) S2's palette (blue-grey stone) differs from the Kit's per-kingdom stone families (`KingdomStyle`), so a retune is needed;
(v) an owner import is needed for every mesh kit (one batch can carry both FL-0135 and FL-0136).

## Not verified / limits
Studio: lighting, material appearance, vertex-colour multiplication, MeshPart pivot and collision, draw calls and phone cost are all **unverified**. One reviewer session (no second opinion); the reviewer judged cost from the numbers in its prompt only (it scored the part-built
Kit's cost 1 although D-047 budgets it). Only two kingdom hues were rendered (crimson, emerald) and only one house, barracks and tower variant per source. The S2 L3 keep is my kitbash, not a pack asset; the S2 trees are scaled to the Kit's oak height, a choice that affects their look.
The wheat is rendered at its ripe stage in all three sources (S3 and S1 have no growth stage); the own wheat's other stages are in `wheat_stages__B__gameplay82.png` (not in the review sheets).

## Reproduce
```
bash blender/scripts/fetch_kaykit.sh
FORGE_ENV_DUMP=/tmp/env_s3.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune EnvDump
~/forge-bpy/bin/python -I blender/scripts/envkit_compare.py --s3 /tmp/env_s3.json --out /tmp/env/r1 --size 1280x720 --samples 20     # all subjects, about 40 minutes on 4 cores
python3 blender/scripts/envkit_sheets.py --renders /tmp/env/r1 --out games/game-001/art/reviews/img/d057-env-review-r1 --key-out /tmp/key.json
~/forge-bpy/bin/python -I blender/scripts/envkit_hue_diff.py        # team-colour share of the KayKit hue variants
~/forge-bpy/bin/python -m pytest -q blender/tests/test_envkit.py    # fit maths, wheat bounds, source pins
```


---

# Phase 2: nature and crops (FL-0136, D-057 (18) to (20)) — FORGE-02 worker P

FORGE-00's amendment after the round above (D-057 (18) to (20)): buildings stay part-built; trees, bushes, rocks, boulders, flowers, resource nodes and crops get NEW project-original
style-B meshes (the citizen kit's direction: faceted, flat-shaded, chunky, one vertex-colour material) through the existing `Kit.prop(assetId)` / `Forge.Assets` path with UNCHANGED ids.
Worker K does the Luau import side; this section is the Blender side (kit, measurements, renders, D-019). Blender renders are not Studio renders.

## 1. Inventory: what the world really places (measured, not read)
Measured with `blender/scripts/lune/EnvInventory.spec.luau` (committed): it boots the real `WorldService` in the Lune mock at the shipped density and at density 1.0
(`WorldPlan.FULL_DENSITY`) with `Kit.prop` wrapped, so every placement, resource node and stand-in part is counted by asset id. The same spec pins the known figure
(`props 616`, `parts 8309` at density 1.0, WorldService.spec) and dumps every stand-in so Blender can rebuild it for the "before" renders.
```
FORGE_ENV_INVENTORY=/tmp/env_inventory.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune EnvInventory
python3 blender/scripts/envkit_standins.py /tmp/env_inventory.json --table      # writes blender/lib/envkit_standins.json, the table the kit is fitted against
```
Result: **shipped density 417 placements + 38 resource nodes = 6,553 parts; density 1.0 616 placements + 38 nodes = 8,309 parts** (crimson dressed, as `WorldService.DRESSED`).
Where ids come from: `WorldPlan.plan` (forests: `tree_oak` 8 / `tree_pine` 6 / `tree_birch` 6 variants by `SPECIES_VARIANTS`; lone oaks and birches; `bush_01..08`; `rock_boulder_{s,m,l}_01..03`
at the hill feet; `plant_flowers_01..06` near the plots; `farm_field_<crop>_<01 + field index % 3>` on every terrain field; the yard dressing) and `world/Layout.luau` resource nodes per plot:
**wood nodes are TREES** (`tree_oak_01`, `tree_oak_03`, `tree_pine_02`, `tree_oak_05`), stone `resource_stone_01/02`, gold `resource_ore_03`, food `bush_03` twice, and in the heartland
`resource_stone_03` and `resource_ore_04`. `resource_wood_*` and `rock_cliff_*` exist as stand-ins and in `KitProps.spec` but nothing places them today.

How crops render today (read for this task): the world places ONE static, ripe field per terrain field for the whole match (12 fields: per plot wheat `_02`, cabbage `_03`, wheat `_01`); the
NN only changes the sheaf jitter of the stand-in (`Props.cropField`). There is **no crop-growth state** anywhere in `src` (searched growth / ripe / sprout / crop). The only growth in the game is the
farm BUILDING's construction stages (`Buildings.buildStage`: furrows 0.35, shoots 0.9, young wheat 1.8 high) and its own wheat rows (2.2 + ears 1.3) beside the field; the buildings stay part-built (D-057 (18)).
So the field ids cannot be growth stages without a runtime change. Decision: `farm_field_wheat_01..03` are three RIPE plot variants (placed: 01, 02), `farm_field_cabbage_01..03` three cabbage variants (placed: 03),
and the growth stages are two extra ids, `farm_field_wheat_04` (furrows with the first shoots) and `farm_field_wheat_05` (green wheat; K's validator wants ids that end in `_NN`, so the stages are
numbered after the three ripe variants), that nothing places yet: K (or a later farm-visual task) decides whether a farm that grows a crop uses them.

Stand-ins replaced (per id; reach = what `PlotClearance` measures, `WorldPlan.CLEAR.radius` is that rounded up: oak 13.5, pine 11.7, birch 8.5, bush 5.2, flowers 3.4, boulder S/M/L 5.8 / 7.5 / 13.3, haystack 4.4):

| asset id | placed (density 1.0 / shipped) | where | stand-in bbox x, y, z | stand-in parts | reach |
|---|---|---|---|---|---|
| `bush_01` | 8 / 6 | bush 8 | 7.4, 5.2, 6.9 | 5 | 4.1 |
| `bush_02` | 13 / 3 | bush 13 | 7.3, 5.1, 7.0 | 10 | 3.9 |
| `bush_03` | 24 / 16 | bush 16, node | 6.1, 5.5, 6.7 | 10 | 3.6 |
| `bush_04` | 19 / 6 | bush 19 | 6.7, 4.8, 6.8 | 5 | 4.0 |
| `bush_05` | 17 / 13 | bush 17 | 7.0, 5.5, 7.0 | 10 | 4.0 |
| `bush_06` | 11 / 5 | bush 11 | 6.7, 5.2, 6.5 | 10 | 3.8 |
| `bush_07` | 14 / 8 | bush 14 | 7.0, 5.3, 7.6 | 5 | 4.2 |
| `bush_08` | 12 / 6 | bush 12 | 6.9, 5.2, 6.5 | 10 | 3.8 |
| `farm_fence_01` | 0 / 0 | not placed today (spare) | 16.5, 2.8, 0.5 | 7 | 8.3 |
| `farm_fence_02` | 0 / 0 | not placed today (spare) | 16.5, 2.8, 0.5 | 8 | 8.3 |
| `farm_field_cabbage_01` | 0 / 0 | not placed today (spare) | 38.0, 3.1, 28.0 | 65 | 29.0 |
| `farm_field_cabbage_02` | 0 / 0 | not placed today (spare) | 38.0, 3.1, 28.0 | 65 | 29.0 |
| `farm_field_cabbage_03` | 4 / 4 | crops 4 | 38.0, 3.1, 28.0 | 65 | 29.0 |
| `farm_field_wheat_01` | 4 / 4 | crops 4 | 38.0, 2.4, 28.0 | 17 | 28.1 |
| `farm_field_wheat_02` | 4 / 4 | crops 4 | 38.0, 2.4, 28.0 | 17 | 28.1 |
| `farm_field_wheat_03` | 0 / 0 | not placed today (spare) | 38.0, 2.4, 28.0 | 17 | 28.1 |
| `farm_haystack_01` | 1 / 1 | dressing 1 | 7.3, 6.2, 6.2 | 4 | 4.3 |
| `plant_flowers_01` | 4 / 4 | flowers 4 | 4.1, 3.0, 3.0 | 9 | 2.3 |
| `plant_flowers_02` | 5 / 5 | flowers 5 | 3.7, 3.0, 3.7 | 9 | 2.4 |
| `plant_flowers_03` | 5 / 5 | flowers 5 | 4.2, 2.9, 3.5 | 9 | 2.3 |
| `plant_flowers_04` | 6 / 6 | flowers 6 | 4.4, 3.0, 3.1 | 9 | 2.3 |
| `plant_flowers_05` | 7 / 7 | flowers 7 | 3.4, 3.1, 3.0 | 9 | 2.3 |
| `plant_flowers_06` | 4 / 4 | flowers 4 | 3.5, 3.0, 3.7 | 9 | 2.3 |
| `resource_ore_01` | 0 / 0 | not placed today (spare) | 10.8, 8.1, 12.0 | 10 | 7.9 |
| `resource_ore_02` | 0 / 0 | not placed today (spare) | 11.5, 8.1, 10.8 | 10 | 8.0 |
| `resource_ore_03` | 4 / 4 | node | 11.4, 8.1, 9.9 | 10 | 8.0 |
| `resource_ore_04` | 1 / 1 | node | 11.6, 8.1, 9.0 | 10 | 8.1 |
| `resource_ore_05` | 0 / 0 | not placed today (spare) | 11.9, 8.1, 9.7 | 10 | 8.0 |
| `resource_ore_06` | 0 / 0 | not placed today (spare) | 13.0, 8.1, 10.4 | 10 | 7.9 |
| `resource_stone_01` | 4 / 4 | node | 16.8, 7.8, 10.7 | 8 | 10.0 |
| `resource_stone_02` | 4 / 4 | node | 16.8, 7.8, 11.3 | 8 | 10.0 |
| `resource_stone_03` | 1 / 1 | node | 16.7, 7.8, 10.5 | 8 | 10.0 |
| `resource_wood_01` | 0 / 0 | not placed today (spare) | 9.1, 4.2, 8.0 | 14 | 7.0 |
| `resource_wood_02` | 0 / 0 | not placed today (spare) | 9.1, 4.2, 7.9 | 14 | 7.0 |
| `rock_boulder_l_01` | 23 / 10 | rocks 23 | 18.0, 9.1, 14.3 | 5 | 11.8 |
| `rock_boulder_l_02` | 15 / 6 | rocks 15 | 18.8, 9.2, 15.9 | 5 | 11.8 |
| `rock_boulder_l_03` | 23 / 15 | rocks 23 | 19.0, 9.5, 17.1 | 5 | 12.2 |
| `rock_boulder_m_01` | 20 / 6 | rocks 20 | 6.2, 5.3, 8.9 | 4 | 6.5 |
| `rock_boulder_m_02` | 20 / 9 | rocks 20 | 6.4, 6.0, 9.3 | 4 | 6.3 |
| `rock_boulder_m_03` | 18 / 10 | rocks 18 | 7.3, 6.0, 9.7 | 4 | 6.2 |
| `rock_boulder_s_01` | 18 / 9 | rocks 18 | 6.2, 3.8, 5.0 | 3 | 4.8 |
| `rock_boulder_s_02` | 13 / 10 | rocks 13 | 6.4, 3.8, 5.3 | 3 | 4.7 |
| `rock_boulder_s_03` | 20 / 10 | rocks 20 | 6.8, 3.7, 5.7 | 3 | 4.6 |
| `rock_cliff_01` | 0 / 0 | not placed today (spare) | 13.6, 10.6, 15.4 | 4 | 10.3 |
| `rock_cliff_02` | 0 / 0 | not placed today (spare) | 13.2, 10.4, 14.9 | 4 | 9.8 |
| `tree_birch_01` | 11 / 11 | forest 8, lone_tree 3 | 10.1, 22.2, 8.1 | 9 | 7.0 |
| `tree_birch_02` | 9 / 7 | forest 7, lone_tree 2 | 8.2, 20.8, 10.3 | 9 | 5.8 |
| `tree_birch_03` | 9 / 8 | forest 4, lone_tree 5 | 8.8, 22.6, 10.0 | 9 | 6.8 |
| `tree_birch_04` | 8 / 6 | forest 6, lone_tree 2 | 10.5, 21.2, 9.0 | 9 | 6.3 |
| `tree_birch_05` | 11 / 8 | forest 9, lone_tree 2 | 8.6, 23.0, 9.4 | 9 | 6.0 |
| `tree_birch_06` | 11 / 8 | forest 7, lone_tree 4 | 8.6, 21.6, 8.3 | 9 | 7.0 |
| `tree_oak_01` | 13 / 13 | forest 8, lone_tree 1, node | 18.9, 25.5, 21.0 | 16 | 11.6 |
| `tree_oak_02` | 22 / 12 | forest 15, lone_tree 7 | 16.3, 24.6, 16.9 | 16 | 9.1 |
| `tree_oak_03` | 17 / 17 | forest 7, lone_tree 6, node | 20.8, 25.5, 22.7 | 16 | 12.6 |
| `tree_oak_04` | 18 / 12 | forest 12, lone_tree 6 | 18.5, 24.5, 17.4 | 16 | 11.7 |
| `tree_oak_05` | 21 / 16 | forest 11, lone_tree 6, node | 20.0, 25.2, 21.8 | 16 | 12.2 |
| `tree_oak_06` | 19 / 16 | forest 14, lone_tree 5 | 21.3, 24.9, 18.6 | 16 | 12.4 |
| `tree_oak_07` | 15 / 10 | forest 9, lone_tree 6 | 14.3, 25.9, 14.9 | 16 | 9.4 |
| `tree_oak_08` | 12 / 9 | forest 7, lone_tree 5 | 22.4, 24.7, 20.4 | 16 | 12.7 |
| `tree_pine_01` | 22 / 18 | forest 22 | 16.4, 29.6, 16.4 | 22 | 11.4 |
| `tree_pine_02` | 19 / 15 | forest 15, node | 16.4, 32.3, 16.4 | 22 | 11.4 |
| `tree_pine_03` | 16 / 13 | forest 16 | 16.1, 30.0, 16.1 | 22 | 11.5 |
| `tree_pine_04` | 12 / 11 | forest 12 | 16.4, 32.6, 16.4 | 22 | 11.5 |
| `tree_pine_05` | 17 / 16 | forest 17 | 16.4, 30.3, 16.4 | 22 | 11.5 |
| `tree_pine_06` | 16 / 13 | forest 16 | 16.1, 28.0, 16.1 | 22 | 11.5 |

Out of scope (untouched): bridges, banners, well, cart, goods (`prop_*`, `bridge_*`), buildings.

Variants decided (every placed id exists, so a world never mixes a mesh with a stand-in of the same family): oak 8, pine 6, birch 6 (the full ranges `SPECIES_VARIANTS` draws from), bush 8, flowers 6,
boulders S / M / L 3 each, stone nodes 3, ore nodes 6 (01-02 iron, 03-04 gold, 05-06 crystal as the stand-in's `variant` rule; 03 and 04 are the placed ones), wheat 3 + 2 growth stages, cabbage 3,
haystack 1; spares that `KitProps.spec` knows but nothing places: cliff 2, wood nodes 2, fences 2. **67 meshes: 52 ids the world places (kit 1) and 15 spares (kit 2)**, see section 2.

## 2. The kit: what was built
*(Phase 3 below promoted six ids from kit 2 into kit 1: it is now 58 + 9 ids and `env_kit.fbx` was rebuilt; the figures in this section are phase 2's, as reviewed.)*

**67 style-B meshes in two FBX kits**, every mesh object named by its asset id, one material `M_envkit_vc`, vertex colours only (`Col`), flat normals, no textures, 1 unit = 1 stud, Y up / -Z forward, base on y = 0,
object origin at the bounding-box centre (`env.json` `bbox_center` and `size` are relative to the base-centre pivot, as in the citizen kit). Everything is generated (no third-party mesh, licence `project-original`).

| kit | files | ids | triangles (sum) | what it is |
|---|---|---|---|---|
| `env_kit_01` | `games/game-001/art/env_kit/env_kit.fbx` (875 KB) + `env.json` | **52** | 19,744 | exactly the ids the world places today (`Kit/EnvMeshData` is made from this) |
| `env_kit_02` | `games/game-001/art/env_kit/env_kit_spares.fbx` (315 KB) + `env_spares.json` | **15** | 7,600 | finished spares nothing places yet; K's spec fails on an id the world never places, so they live in their own kit and are read by nothing until the world uses them |

| group | ids | variants (how they differ) |
|---|---|---|
| oak | `tree_oak_01..08` | five archetypes (the stand-in's classes): dome 01 / 06, tall 02 / 07, wide 03 / 08, lopsided 04, twin crown 05; a trunk with root flare and one or two limbs, 10 or 11 faceted crown lobes plus rim clumps, painted deep blue-green underneath to lime on up-facing facets; 554 to 652 triangles, 15 to 24 studs wide, 24 to 26 high |
| pine | `tree_pine_01..06` | per-id height 28 to 33 studs (the stand-in's), 7 stacked toothed tiers on odd ids and 6 on even ids, each with its own outline, tooth depth and a slight lean; 348 and 396 triangles; blue-green, lighter on top |
| birch | `tree_birch_01..06` | slender white trunk with bark marks and a lighter crown of 5 or 6 lobes, 20 to 23 studs high; 318 and 366 triangles |
| bush | `bush_01..08` | four silhouettes (round, low and wide, tall, twin mound) x three kinds by NN % 3: plain, white blossom (02, 05, 08), red berries (03, 06; `bush_03` is the world's food node so its berries must read from the aerial camera); 140 to 340 triangles |
| flowers | `plant_flowers_01..06` | a leafy tuft with six large blooms; colours red, yellow, white, purple and two mixes; 228 to 312 triangles |
| boulders | `rock_boulder_{s,m,l}_01..03` | three structures per size (a lumped mass with shaving-plane cuts, tipped masses, chips and pebbles), strata, moss tints; 116 to 268 triangles |
| stone nodes | `resource_stone_01..03` | pale strata and cut blocks with rubble, the quarry's read is "worked stone"; 200 triangles each |
| ore nodes | `resource_ore_03, 04` placed; `01, 02, 05, 06` spare | dark host rock with seven angular nuggets: iron (01-02), gold rgb(238, 172, 22) (03-04), crystal (05-06); 218 to 220 triangles |
| spare rocks | `rock_cliff_01..02`, `resource_wood_01..02` (kit 2) | cliff massif; log pile + chopped stump + axe |
| wheat | `farm_field_wheat_01..03` ripe plot variants (01, 02 placed), `04` shoots and `05` green wheat (kit 2) | 38 x 28 studs like the stand-in (the terrain field under it and the placement clearance stay as they are), ridge-topped soil rows with gradient blades: 01 rows along x, golden; 02 rows along z, amber with red poppies; 03 pale straw with a path and a scarecrow; 1,020 to 1,430 triangles |
| cabbage | `farm_field_cabbage_01..03` (03 placed) | six ridges of eight frilly heads in three greens, a different offset and shade pattern per id; 1,332 triangles |
| haystack | `farm_haystack_01` | round-shouldered stack, two darker bands, pitchfork; 196 triangles |
| fences | `farm_fence_01..02` (kit 2) | five posts, one or two rails; 72 to 84 triangles |

**Fit to the stand-in.** The world's keep-out, plot clearance and the camera tuning were made on the part-built stand-ins, so each mesh takes its stand-in's footprint and height (measured by `blender/scripts/envkit_standins.py` from the real Lune dump,
`blender/lib/envkit_standins.json`). The generator's `fit_to` clamps footprint `max(x, z)` to 93 to 107 % of the stand-in's (resource nodes 88 to 100 %) and height to 90 to 110 %; K's validator allows 85 to 115 % (nodes 85 to 102 %) and 75 to 125 %.
Result (table 3): footprints 93 to 107 % (88 % for two spare ore nodes), heights 89 to 113 % except the wheat fields (122 %, the ears stand above the old planks; the crops keep the stand-in's 38 x 28 footprint exactly), and three declared `fit_note`s in kit 2 (wheat 03 scarecrow 190 % high, shoots 50 %, green wheat 76 %: growth stages are meant to differ).
**Sinks:** 20 props (rocks, boulders, nodes, cliffs) are sunk 0.40 to 0.54 studs below y = 0 on purpose so they sit on the uneven terrain without floating; the validator prints these as `warning: the base is at y = -0.4x, not 0`
(14 in kit 1, 6 in kit 2; the generator allows at most 0.6). They are warnings by K's design, not errors.

**Contract with K (worker K's `env_to_luau.py`, copied byte-identical from `forge/02-blender-fl0136-envrt` at 83695c53).** `python3 games/game-001/art/env_kit/env_to_luau.py --validate-only --in <json>` passes on both
`env.json` (valid, 14 warnings) and `env_spares.json` (valid, 6 warnings); `--print-budget` prints the same limits the measured gate uses. Adopted from K: the seven families `tree | bush | rock | flower | crop | haystack | fence`
(resource nodes are family `rock` with `node: true`), crop budget 40 to 1,500 triangles and haystack / fence 40 to 600, ids that end in `_NN` (so the growth stages are `farm_field_wheat_04` and `_05`, not `_stage1`),
every id a world really places, `tint: fixed` (MeshPart.Color stays white; the baked vertex colours are the look; nothing here is kingdom-tinted). K's collider rule adds one invisible part to tree, rock, bush, haystack and fence models, which the relief below counts.

## 3. Measured triangles (the gate reads the FBX bytes, not the generator's own count)
`lib/fbxtris.py` counts triangles and the bounding box straight from the exported FBX; `lib/manifest.py` (`env_budget_errors`, `env_kit_errors`, run by `manifest.check()` and so by `check.sh`) fails the build if any mesh is outside its family budget,
its declared `tris` or box differs from the measured one, a prop is missing from or extra in the FBX, an id is off the `_NN` shape, the fit window is broken without a `fit_note`, a prop sinks more than 0.6 studs, the `sha256` of the committed FBX differs
from the row's, or the FBX text values name a home directory or user. `blender/tests/test_env_kit_budget.py` (25 tests) pins this with mutants (one per budget family, a wrong count, a missing and an extra prop, a bad id, a node over 102 %, a floating prop,
a tampered `env.json`, a stale sha, a personal path replaced in place in the FBX bytes, a broken FBX) and runs K's validator on both json files.

Family budgets and measured ranges (both kits), then every id:


**env_kit_01 (env_kit.fbx, the ids the world places)**

| family | meshes | triangles per mesh (min to max) | total | budget |
|---|---|---|---|---|
| tree | 20 | 318 to 652 | 9058 | 300 to 900 |
| bush | 8 | 140 to 340 | 2000 | 40 to 400 |
| flower | 6 | 228 to 312 | 1626 | 40 to 400 |
| rock | 14 | 116 to 268 | 2740 | 40 to 400 |
| crop | 3 | 1332 to 1430 | 4124 | 40 to 1500 |
| haystack | 1 | 196 to 196 | 196 | 40 to 600 |

**env_kit_02 (env_kit_spares.fbx, ids nothing places yet)**

| family | meshes | triangles per mesh (min to max) | total | budget |
|---|---|---|---|---|
| rock | 8 | 132 to 220 | 1440 | 40 to 400 |
| crop | 5 | 1020 to 1332 | 6004 | 40 to 1500 |
| fence | 2 | 72 to 84 | 156 | 40 to 600 |

**Table 3: env_kit_01, measured per id** (footprint = max(x, z) against the stand-in's, height against the stand-in's; node = a resource node, fit window 85 to 102 %)

| asset id | family | triangles | bbox x, y, z (studs) | footprint vs stand-in | height vs stand-in | node | note |
|---|---|---|---|---|---|---|---|
| `tree_oak_01` | tree | 590 | 21.0, 25.8, 19.7 | 100% | 101% | yes |  |
| `tree_oak_02` | tree | 588 | 15.7, 26.0, 16.6 | 98% | 106% |  |  |
| `tree_oak_03` | tree | 604 | 21.6, 25.5, 22.7 | 100% | 100% | yes |  |
| `tree_oak_04` | tree | 604 | 19.8, 25.8, 18.6 | 107% | 105% |  |  |
| `tree_oak_05` | tree | 610 | 19.2, 25.7, 21.8 | 100% | 102% | yes |  |
| `tree_oak_06` | tree | 554 | 19.8, 25.9, 21.5 | 101% | 104% |  |  |
| `tree_oak_07` | tree | 572 | 15.9, 26.2, 15.3 | 107% | 101% |  |  |
| `tree_oak_08` | tree | 652 | 23.7, 24.2, 24.0 | 107% | 98% |  |  |
| `tree_pine_01` | tree | 396 | 16.2, 29.9, 16.5 | 101% | 101% |  |  |
| `tree_pine_02` | tree | 348 | 16.4, 32.7, 15.7 | 100% | 101% | yes |  |
| `tree_pine_03` | tree | 396 | 15.1, 30.3, 15.7 | 97% | 101% |  |  |
| `tree_pine_04` | tree | 348 | 16.5, 33.0, 16.9 | 103% | 101% |  |  |
| `tree_pine_05` | tree | 396 | 15.9, 30.6, 16.3 | 99% | 101% |  |  |
| `tree_pine_06` | tree | 348 | 16.8, 28.3, 16.7 | 104% | 101% |  |  |
| `tree_birch_01` | tree | 366 | 10.0, 22.1, 10.0 | 99% | 99% |  |  |
| `tree_birch_02` | tree | 318 | 7.8, 19.9, 11.1 | 107% | 96% |  |  |
| `tree_birch_03` | tree | 366 | 9.7, 22.2, 10.1 | 101% | 98% |  |  |
| `tree_birch_04` | tree | 318 | 10.0, 20.6, 8.8 | 95% | 97% |  |  |
| `tree_birch_05` | tree | 366 | 10.0, 22.6, 8.6 | 107% | 98% |  |  |
| `tree_birch_06` | tree | 318 | 9.2, 20.7, 7.3 | 107% | 96% |  |  |
| `bush_01` | bush | 160 | 6.9, 5.5, 6.9 | 93% | 105% |  |  |
| `bush_02` | bush | 280 | 7.8, 4.7, 7.7 | 107% | 93% |  |  |
| `bush_03` | bush | 280 | 6.4, 6.0, 6.2 | 95% | 110% | yes |  |
| `bush_04` | bush | 220 | 7.2, 5.3, 7.0 | 106% | 109% |  |  |
| `bush_05` | bush | 280 | 7.4, 5.6, 7.5 | 107% | 102% |  |  |
| `bush_06` | bush | 300 | 6.9, 4.8, 7.1 | 107% | 92% |  |  |
| `bush_07` | bush | 140 | 7.1, 5.7, 6.3 | 93% | 106% |  |  |
| `bush_08` | bush | 340 | 6.1, 5.1, 7.4 | 107% | 97% |  |  |
| `plant_flowers_01` | flower | 254 | 4.4, 3.1, 3.9 | 107% | 104% |  |  |
| `plant_flowers_02` | flower | 280 | 3.3, 3.0, 4.0 | 106% | 102% |  |  |
| `plant_flowers_03` | flower | 228 | 3.4, 3.1, 4.5 | 107% | 105% |  |  |
| `plant_flowers_04` | flower | 312 | 4.1, 3.0, 3.9 | 93% | 101% |  |  |
| `plant_flowers_05` | flower | 254 | 3.3, 3.1, 3.6 | 107% | 100% |  |  |
| `plant_flowers_06` | flower | 298 | 3.2, 3.1, 4.0 | 107% | 106% |  |  |
| `rock_boulder_s_01` | rock | 144 | 6.6, 3.8, 5.2 | 107% | 101% |  |  |
| `rock_boulder_s_02` | rock | 116 | 6.5, 3.9, 6.8 | 107% | 103% |  |  |
| `rock_boulder_s_03` | rock | 170 | 6.0, 3.9, 7.2 | 107% | 104% |  |  |
| `rock_boulder_m_01` | rock | 160 | 7.8, 6.0, 8.2 | 93% | 113% |  |  |
| `rock_boulder_m_02` | rock | 146 | 9.5, 5.9, 8.6 | 102% | 99% |  |  |
| `rock_boulder_m_03` | rock | 190 | 9.0, 5.9, 9.0 | 93% | 98% |  |  |
| `rock_boulder_l_01` | rock | 246 | 17.6, 8.7, 14.7 | 98% | 95% |  |  |
| `rock_boulder_l_02` | rock | 264 | 15.4, 8.8, 18.1 | 96% | 96% |  |  |
| `rock_boulder_l_03` | rock | 268 | 11.7, 9.1, 18.0 | 94% | 96% |  |  |
| `resource_stone_01` | rock | 200 | 16.8, 8.0, 10.1 | 100% | 102% | yes |  |
| `resource_stone_02` | rock | 200 | 16.5, 7.9, 10.5 | 98% | 102% | yes |  |
| `resource_stone_03` | rock | 200 | 16.7, 7.9, 10.1 | 100% | 102% | yes |  |
| `resource_ore_03` | rock | 218 | 11.0, 7.7, 8.1 | 96% | 96% | yes |  |
| `resource_ore_04` | rock | 218 | 9.3, 7.7, 11.6 | 100% | 96% | yes |  |
| `farm_field_wheat_01` | crop | 1362 | 38.0, 3.0, 28.0 | 100% | 122% |  |  |
| `farm_field_wheat_02` | crop | 1430 | 38.1, 2.9, 28.0 | 100% | 122% |  |  |
| `farm_field_cabbage_03` | crop | 1332 | 38.0, 2.8, 28.0 | 100% | 89% |  |  |
| `farm_haystack_01` | haystack | 196 | 7.8, 6.1, 6.0 | 107% | 99% |  |  |

**Table 3b: env_kit_02 (spares), measured per id**

| asset id | family | triangles | bbox x, y, z (studs) | footprint vs stand-in | height vs stand-in | node | note |
|---|---|---|---|---|---|---|---|
| `rock_cliff_01` | rock | 138 | 14.3, 10.3, 10.5 | 93% | 98% |  |  |
| `rock_cliff_02` | rock | 132 | 11.5, 10.5, 13.9 | 93% | 102% |  |  |
| `resource_ore_01` | rock | 218 | 11.3, 7.7, 9.5 | 95% | 96% | yes |  |
| `resource_ore_02` | rock | 220 | 10.5, 7.7, 9.4 | 92% | 96% | yes |  |
| `resource_ore_05` | rock | 218 | 9.2, 8.1, 10.5 | 88% | 101% | yes |  |
| `resource_ore_06` | rock | 218 | 10.2, 8.0, 11.5 | 88% | 99% | yes |  |
| `resource_wood_01` | rock | 148 | 9.1, 4.1, 8.1 | 100% | 99% | yes |  |
| `resource_wood_02` | rock | 148 | 9.1, 4.1, 8.3 | 100% | 97% | yes |  |
| `farm_field_wheat_03` | crop | 1300 | 38.0, 4.6, 28.0 | 100% | 190% |  | fit_note |
| `farm_field_wheat_04` | crop | 1020 | 38.0, 1.2, 28.0 | 100% | 50% |  | fit_note |
| `farm_field_wheat_05` | crop | 1020 | 38.0, 1.8, 28.0 | 100% | 76% |  | fit_note |
| `farm_field_cabbage_01` | crop | 1332 | 38.0, 2.8, 28.0 | 100% | 89% |  |  |
| `farm_field_cabbage_02` | crop | 1332 | 38.0, 2.8, 28.0 | 100% | 89% |  |  |
| `farm_fence_01` | fence | 72 | 16.5, 2.8, 0.5 | 100% | 100% |  |  |
| `farm_fence_02` | fence | 84 | 16.5, 2.8, 0.5 | 100% | 100% |  |  |

## 4. Look: renders, my own critique, fresh D-019 reviewers
**Method.** Cycles renders through the `bpy` wheel (Blender, not Studio). "Before" = the part-built `Kit.prop` stand-ins rebuilt part by part from the Lune dump (`kitparts.build_model`), "after" = the SHIPPED `env_kit.fbx` / `env_kit_spares.fbx`
(`lib/envkit_scene.py` imports the FBX the Studio import would use). Each scene uses the world's real placements (`EnvInventory.spec` dump) and the part-built keep, houses, farm, storehouse, lumber camp and quarry of the crimson and emerald plots
(not replaced: D-057 (18)) next to four B-style citizens. Cameras: gameplay 82 studs, 44.3 degrees down; aerial 170 studs, 50 degrees; close 45 studs, 30 degrees; 70 degree vertical field of view. A lineup that did not fit the frame is widened and the sheet caption says so.
Scenes (`blender/scripts/envnature_scenes.py`): settlement crimson / emerald (the whole plot with its surroundings), forest broadleaf / pine (the density-1.0 plan), trees lineup (all 20 trees) and close view, bushes and flowers, the nine boulders,
resource nodes, crop fields, wheat in three growth stages. Review sheets: `games/game-001/art/reviews/img/d057-env-nature-r1/sheet_*.jpg` (11 JPEGs, each under 250 KB, blind: "SET A / SET B", column order flipped on alternate sheets).
The manifest preview is `blender/previews/env_kit.jpg` (a lineup of representative props from the shipped FBX).

**My own look (every sheet was opened).**
- Trees: the B oaks are clearly different from each other (dome, tall, wide, lopsided, twin) and carry the citizens' faceted language, where the stand-in's 3 to 5 overlapping spheres look soft and balloon-like beside the angular keep and houses. The pines read as tall cones and
  are easy to tell from oaks, but they are very dark and share one outline family; birches are small faceted lollipops on thin tilted trunks. At the aerial camera the trees read, bushes and birches shrink to specks.
- Rocks and nodes: the boulders are lumpy, cut and moss-tinted, three different structures per size; gold ore reads as gold at 82 studs (it read cream before I deepened it); the three stone quarries differ mostly in tone and rubble (grey on grey).
  At 170 studs rocks and nodes are a few grey pixels in both sets and the gold node cannot be seen: that is a scale or marker question, not a mesh question.
- Crops: wheat is a field of peaked tufts in rows (not stalks), which reads as a crop and not as lumber, the two placed variants differ in orientation, density and colour; cabbage reads as leafy heads; the growth stages read ripe, green, shoots at 82 studs (shoots faint on the soil).
  The haystack is small and low contrast against the grass. In the part-built set the three "stages" are the same field: nothing in the stand-ins shows growth.
- Cohesion: faceted B props sit better beside the faceted citizens and the angular buildings than the soft spheres; the tan wheat is close to the beige roof colour of some buildings.

**Fresh image-only D-019 reviewers (round 1; no round 2 was needed).** One fresh Claude Code session per family group (no memory of me), a sparse checkout of the image folder only, the rubric and the cost facts in `img/d057-env-nature-r1/review_prompt.md`.
Blind: A / B letters fixed over all sheets, never named; the key (`img/d057-env-nature-r1/key.json`: **A = the part-built stand-ins, B = these meshes**) was withheld until the replies were saved. Replies verbatim with session ids: `img/d057-env-nature-r1/review.json`.

| group (sheets) | session | SET B (these meshes): sil / var / read / prop / pal / det / coh / cost | SET B | SET A (stand-ins) |
|---|---|---|---|---|
| trees, bushes, flowers (settlement crimson, forest broadleaf, forest pine, trees lineup, trees close, bushes lineup) | `session_01LoutSfVRK1oYexT4X1j214` | 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4 | **PASS**, ship | NEEDS-WORK (4 / 3 / 4 / 3 / 4 / 4 / 3 / 3) |
| rocks, boulders, resource nodes (settlement emerald, rocks lineup, nodes lineup) | `session_01AdaWs4n75YYboXVj6JCNp7` | 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4 | **PASS**, ship | NEEDS-WORK (3 / 2 / 3 / 3 / 3 / 3 / 3 / 5) |
| crops (crops, wheat stages, settlement emerald) | `session_01XFzLWTYVSQFKXAP6nf2M8L` | 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3 | **PASS**, ship | NEEDS-WORK (2 / 2 / 2 / 3 / 3 / 2 / 3 / 5) |

Pass rule: silhouette, variation and readability each at least 4 and the other five at least 3. Reviewer defects on B that I agree with (none blocking, all in `review.json` per sheet): very dark pines and oak shadow sides, near-identical birches, three similar plain bushes, small flower tufts,
mildly varied quarries, spiky wheat, faint shoots stage, small low-contrast haystack, rocks and nodes tiny at 170 studs. The crops reviewer called the ~1.4k-triangle fields "the heaviest crop item, fine for a handful on screen" (cost 3).
The pass is one session per group (no second opinion), and the cost scores were judged against the cost facts I wrote into the prompt (part counts of the stand-ins, triangle ranges of the meshes), not measured on a device.
The reviewed geometry is the committed geometry (verified: see "Reproduce", the re-render check). `env_kit_02` (spares) is not reviewed: only its wheat stages 04 and 05 appeared on a sheet.

## 5. Part-count relief (measured on the real WorldService, not estimated)
`blender/scripts/lune/EnvRelief.spec.luau` boots the real `WorldService` in the Lune mock (recorded terrain) twice per density, once as today (part-built stand-ins) and once with K's runtime (`Kit/EnvMesh`, the fake Models of fixture `EnvMeshKit`: an invisible `Root`,
a `Body` MeshPart and K's collider part for tree, rock, bush, haystack and fence) built from my `env.json`, wrapping `Kit.prop` to count parts per family. The same placements in both runs (417 / 616 props, plus the resource nodes), `WorldService.spec`'s pin (8,309 parts at density 1.0) asserted.
It needs K's branch (`forge/02-blender-fl0136-envrt` at 83695c53, not merged here), so the numbers are the parts a world with the kit imported would build; a real Studio import (MeshPart count, draw calls) is unverified.

| | parts today | parts with the mesh kit | fewer | placements |
|---|---|---|---|---|
| shipped density | **6,553** | **2,168** | 4,385 (67 %) | 417 + 38 nodes = 455 `Kit.prop` calls, 445 of them mesh props |
| density 1.0 (the untrimmed valley) | **8,309** | **2,765** | 5,544 (67 %) | 616 + 38 nodes = 654 `Kit.prop` calls, 644 of them mesh props |

Where it comes from (shipped density / density 1.0; "other" = bridges, banners, well, cart, goods, 106 parts, untouched by design):

| family | placements | parts today | parts with meshes | relief |
|---|---|---|---|---|
| pine | 86 / 102 | 1,892 / 2,244 | 258 / 306 | 1,634 / 1,938 |
| oak | 105 / 137 | 1,680 / 2,192 | 315 / 411 | 1,365 / 1,781 |
| birch | 48 / 59 | 432 / 531 | 144 / 177 | 288 / 354 |
| bush | 63 / 118 | 530 / 975 | 189 / 354 | 341 / 621 |
| flowers | 31 / 31 | 279 / 279 | 62 / 62 | 217 / 217 |
| crops (wheat, cabbage) | 12 / 12 | 396 / 396 | 24 / 24 | 372 / 372 |
| boulders | 85 / 170 | 342 / 690 | 255 / 510 | 87 / 180 |
| resource nodes (stone, ore) | 14 / 14 | 122 / 122 | 42 / 42 | 80 / 80 |
| haystack | 1 / 1 | 4 / 4 | 3 / 3 | 1 / 1 |
| other (not replaced) | 10 / 10 | 106 / 106 | 106 / 106 | 0 / 0 |
| total | | 6,553 / 8,309 | 2,168 / 2,765 | 4,385 / 5,544 |

The cost moves from parts to triangles: if every placement were drawn at once, the placed nature would be **171,472 triangles at shipped density and 230,594 at density 1.0** (placements x the measured triangles of table 3; trees 111k / 140k, rocks 19k / 36k, crops 16k, bushes 16k / 30k, flowers 8k),
an average of 358 to 385 per placement, against about 12 triangles per primitive Part today. That is a worst case (streaming and culling cut it), and what a phone really pays for it is unverified.
Reading: the relief is 67 % because the K wrapper keeps `Root` and `Body` (and a collider for the solid families); a flower tuft and a field cost two parts, a pine three instead of 22.
Each placed mesh is also one draw call where each stand-in part was its own; that is the likely larger win and it is unverified (Studio).

## 6. Not verified, limits
- **Studio is unavailable here (Linux cloud session).** Unverified in Studio: the FBX import (MeshPart size, pivot and scale after import, the vertex-colour tint with `MeshPart.Color` white, `RenderFidelity`), collision with K's collider parts, draw calls, frame time and memory on a phone, the real part count of an imported world.
  Everything above about looks is Blender (Cycles) evidence; the lighting, shadows and fog of the game are not reproduced.
- One fresh reviewer session per family group, no second opinion; the cost score was judged against facts I supplied, not measured. The sheets were seen as 1550 px JPEGs, not at 1:1.
- `env_kit_02` (15 spares: cliffs, wood nodes, ore 01/02/05/06, wheat 03 to 05, cabbage 01/02, fences) is built, measured and gated, but only its wheat stages appeared on a sheet; it is UNREVIEWED in the manifest.
- Nothing places the growth stages or the spares today; whether a farm should show growth is a design call (and a runtime change) for K or a farm-visual task. The wheat stage ids exist and are measured so that task can start from them.
- FBX bytes are not reproducible (Blender writes a timestamp); `build.py --verify` compares the geometry hash, and the manifest row carries the `sha256` of the committed FBX.
- Fit: the `fit_to` clamp keeps footprints within 7 % and heights within 10 % of the stand-in (wheat 122 %); a Studio check of PlotClearance with the real MeshPart bounds is unverified. `reach_bbox` in `env.json` is the box-corner reach K's clearance uses (up to 1.41 x the radius).
- Oak crowns, pine tiers and the berry or bloom sizes were tuned to read at 82 and 170 studs; a phone camera closer than 45 studs shows the faceting more than my close views do.
- The Luau side (EnvMesh, EnvMeshData, fixtures) is worker K's; I wrote no runtime code and opened no PR.

## 7. Reproduce
```
~/forge-bpy/bin/python blender/build.py --generator env_kit --no-render        # rebuild both kits; --verify compares geometry hashes (check.sh does)
python3 games/game-001/art/env_kit/env_to_luau.py --validate-only --in games/game-001/art/env_kit/env.json         # K's validator (also env_spares.json; --print-budget)
bash blender/scripts/check.sh                                                  # must end "blender check: PASS"
python3 blender/scripts/envkit_report.py --relief /tmp/env_relief.json         # the tables of this section 3 and 5
# inventory and standin table (section 1)
FORGE_ENV_INVENTORY=/tmp/env_inventory.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune EnvInventory
python3 blender/scripts/envkit_standins.py /tmp/env_inventory.json            # writes blender/lib/envkit_standins.json
# part-count relief (section 5): since the runtime and the data are on the same branch (FL-0136 env PR) run it in place:
FORGE_ENV_RELIEF=/tmp/env_relief.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune EnvRelief
# measured on the merged tree (main 790c56d2 + arena): shipped density 6,869 -> 2,514 parts (-4,355), density 1.0 8,620 -> 3,111 (-5,509); the arena's 349 parts are in both
# (the older steps below, with K's copy at 83695c53, gave 6,553 -> 2,168 and 8,309 -> 2,765 before the arena and the outposts changed the plain world)
# (older recipe, kept for the record): needs K's runtime; copy it, convert my env.json, run the spec there
K=/tmp/envrt; mkdir -p $K && git -C <K's worktree> archive 83695c53 | tar -x -C $K     # branch forge/02-blender-fl0136-envrt
python3 games/game-001/art/env_kit/env_to_luau.py --in games/game-001/art/env_kit/env.json --out $K/games/game-001/src/shared/Kit/EnvMeshData.luau
mkdir -p $K/blender/scripts/lune && cp blender/scripts/lune/EnvRelief.spec.luau $K/blender/scripts/lune/
(cd $K && FORGE_ENV_RELIEF=/tmp/env_relief.json lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs blender/scripts/lune EnvRelief)
# renders and sheets (Cycles, about 40 s per view on 4 cores)
~/forge-bpy/bin/python -I blender/scripts/envnature_scenes.py --inv /tmp/env_inventory.json --out /tmp/env/r1 --modes before,after --size 1280x720 --samples 24
python3 blender/scripts/envnature_sheets.py --renders /tmp/env/r1 --out games/game-001/art/reviews/img/d057-env-nature-r1 --key-out /tmp/key.json
~/forge-bpy/bin/python -m pytest -q -p no:warnings blender/tests/test_env_kit_budget.py
```
Re-render check (reviewed geometry == committed geometry): the final FBX was rebuilt at the end of the round (the deeper gold ore); I re-rendered eight non-ore scenes (bushes, rocks, crops, wheat stages, trees lineup and close, both forests) with the committed FBX at the same
settings and compared every pixel with the renders the sheets were cut from: all 19 'after' views of the 11 sheet scenes (settlements, forests, lineups, bushes, rocks, nodes, crops, wheat stages; 8 scenes first, the 3 that hold ore nodes second) re-rendered with the committed FBX are **pixel-identical** (maximum difference 0 of 255, mean 0.0000) to the renders the sheets were cut from, so what the reviewers saw is the committed geometry (`env_kit_01` geometry hash `61bac208a4421907`, pinned in `blender/reviews/env_kit.json`). The 'before' views are the part-built stand-ins and do not depend on the FBX.


---

# Phase 3: resource nodes at 170 studs and the mesh-only farm dressing (FL-0136, FORGE-00's decisions of 2026-10-19) — FORGE-02 worker P

Branch `forge/02-blender-fl0136-dressing`, stacked on `forge/02-blender-fl0136-env` (PR 247: K's runtime and the phase-2 kit, head 8c26e2a8). Blender renders are not Studio renders; every Studio item is listed in section 3.7.
FORGE-00's decisions and what was done with each:

| # | decision | done |
|---|---|---|
| 1 | wheat growth stages: only if the client has per-field state; it has none, so ship ripe only, no new contract | nothing places a stage: `farm_field_wheat_04` and `_05` stay on the bench in `env_kit_spares.fbx`, as does `_03` (a ripe variant with a scarecrow, not asked for) |
| 2 | fences, cabbage and cliffs as dressing, within the D-047 ceiling; triangle totals in the PR | implemented as mesh-only dressing (3.3); parts and triangles in 3.3 and 3.5 |
| 3 | iron and crystal ore: no, not game resources | `resource_ore_01/02/05/06` stay on the bench in `env_kit_spares.fbx` (kit 2), not in `env.json`, not in `Kit/EnvMeshData`, not promoted |
| 4 | nodes readable at the 170-stud camera, visual only: mesh scale or a marker, no Layout or work spot change | a marker (3.2). Scaling is not available: the layout has 0.7 to 3.3 % of room around the quarry and ore |
| 5 | one Studio row for performance | already in PR 247 |

## 3.1 What the world has (measured)
`blender/scripts/lune/EnvNodeFit.spec.luau` boots the real `Layout` and `WorldPlan.props` and measures every node with the stand-in and with the imported mesh (K's runtime, the real `Kit/EnvMeshData`, fake import Models).
There are **38 resource nodes**: 16 wood (the same 4 trees at each plot: `tree_oak_01`, `tree_oak_03`, `tree_oak_05`, `tree_pine_02`; **a wood node is an ordinary tree**), 9 stone (`resource_stone_01/02` per plot and `_03` in the heartland), 5 gold
(`resource_ore_03` per plot, `resource_ore_04` in the heartland) and 8 food (`bush_03` twice per plot; **a food node is an ordinary berry bush**, the same id the valley's decor bushes use). At the aerial camera a lone oak in a forest, a berry bush
among bushes and a 17 x 8 stud quarry stone are a few pixels, and nothing but position says which tree or bush is the node.

## 3.2 A. Nodes at 170 studs: scale is not available, a marker is
**Option (i), scale the node mesh up: no.** The nodes were placed (FL-0124) as close to the fields, slots and starting buildings as the keep-out rules allow, by what the part-built stand-in draws (8 studs to fields, zones and slots, 5 to the starting buildings,
`tests/world/NodeKeepOut.spec`). Measured against the real layout (smallest room over the four plots; the "outline radius" is the mesh's farthest vertex, "box reach" is the NodeKeepOut measure applied to the mesh's bounding box, which is conservative):

| node asset | resource | stand-in reach | mesh outline radius | mesh box reach | room (smallest over the plots) | growth room | work spots from the pivot |
|---|---|---|---|---|---|---|---|
| `tree_oak_01` | wood | 11.59 | 12.59 | 16.33 | 18.21 | +44.7 % | 5 to 5 |
| `tree_oak_03` | wood | 12.61 | 14.05 | 16.63 | 16.47 | +17.2 % | 5 to 5 |
| `tree_pine_02` | wood | 8.51 | 8.58 | 11.49 | 11.36 | +32.3 % | 5 to 5 |
| `tree_oak_05` | wood | 12.17 | 12.58 | 15.02 | 12.23 | -2.8 % | 5 to 5 |
| `resource_stone_01` | stone | 9.62 | 9.70 | 10.99 | 10.02 | +3.3 % | 5 to 5 |
| `resource_stone_02` | stone | 9.62 | 9.65 | 10.58 | 9.90 | +2.6 % | 5 to 5 |
| `resource_ore_03` | gold | 7.05 | 7.06 | 7.41 | 7.11 | +0.7 % | 5 to 5 |
| `bush_03` | food | 3.63 | 3.65 | 5.02 | 4.00 | +9.7 % | 5 to 5 |
| `resource_stone_03` | stone | 9.62 | 9.65 | 10.93 | 283.12 | unbounded (heartland) | 7 to 7.21 |
| `resource_ore_04` | gold | 6.94 | 6.85 | 8.31 | 300.24 | unbounded (heartland) | 7.21 to 10 |

So a quarry stone can grow 2.6 to 3.3 %, the gold ore 0.7 %, a berry bush 9.7 % before a plot rule breaks (the limit is the quarry building, 5 studs, or the plot's last slot, 8 studs); a readable change is 30 % or more. Only the heartland nodes
(no plot around them) could grow, and those are the contested ones the plots do not frame. Notes: (a) with the box measure the imported meshes are already 0.1 to 2.8 studs over the rule for 7 of the 8 plot node types (the real outline is not: only
`tree_oak_05` is 0.35 stud into its 8-stud buffer, nothing touches a field, slot or building); NodeKeepOut runs on the stand-ins only, so nothing fails, but it is a number for FORGE-01 and K (3.7); (b) the work spots (3 per node, 5 studs from the pivot,
7 to 10 in the heartland) are already inside the drawn reach of every node except the berry bush (the workers stand at the foot of the pile), so growing a node would put them deeper into it, not across a new line; (c) the decor measured around each node (the nearest flower tuft, bush or haystack is 2.6 to 11 studs outside the mesh's reach circle for the crimson plot's nodes but one, and `crimson_wood4`'s oak canopy is already 2.7 studs inside a flower tuft's circle) means the neighbours would overlap first. Option (i) needs Layout positions to move, which is FORGE-01's and not allowed here.

**Option (ii), a marker on the node's Model: yes.** Looked at in Blender on the real placements (170 studs / 50 degrees, 82 studs / 44 degrees, with the real keep, houses, farm and citizens) before choosing; the comparison is
`img/d057-env-nodes-candidates/candidates_aerial170.jpg` (crops at 1.7x of the 1280 x 720 aerial render):

| candidate | what I saw |
|---|---|
| A: no marker (PR 247 state) | quarry stones, gold ore and berry bush are small grey, yellow and green piles beside the quarry building; the wood nodes cannot be told from the forest at all |
| B: vertical pennant 3.4 studs on a post | thin, 5 to 8 px at 170 studs, edge-on (invisible) from some azimuths because the model's yaw is random per node |
| C: diamond plate 5 studs (and 3.6) on a post | the shape reads from above at every azimuth but the plate foreshortens at the gameplay pitch, and the glowing colour looks pale |
| E: coloured ground disc (radius 5) | hidden under the stone piles (their half width is 8 to 9), visible only on the bush and the ore; a disc big enough for a tree would widen the node, which has no room |
| **D: glowing orb 5 studs on a post** | the same silhouette from every azimuth and pitch, saturated, 10 to 15 px at 170 studs: **chosen** |

**The rule (`Props.nodeMarker`, `Kit.nodeMarker`; `WorldService` calls it on every node right after `Kit.prop`)**: two parts, a post (radius 0.3, wood) rising 4.5 studs above the node's highest drawn point and an orb (5 studs, Neon) on it in the resource's colour: stone ice white
(214, 234, 255), gold yellow (255, 206, 0), wood orange (255, 104, 24), food red-pink (232, 40, 84) (hues 49, 18 and 345 degrees apart). Visual only: not collidable, touchable or queryable (selection and placement rays pass through) and no shadow.
It is placed at the model's pivot (`Root.CFrame * PivotOffset`, whatever the import did to the Root), on the part-built stand-in and on an accepted mesh alike, and **only on nodes**: the forests' trees and the decor bushes use the same asset ids and carry none (the call is in
`WorldService`'s node loop, not in `Kit.prop`). It never widens a node: the orb reaches 2.5 studs from the pivot, inside the berry bush's 3.6 (the smallest node), so the keep-out rules and the plot clearance are unchanged and `Layout` (positions, work spots) is not touched.
Cost: 2 parts x 38 nodes = **76 parts** in the world with or without the kit (the only pinned number that moved: `WorldService.spec`'s dressing at density 1.0, 8,271 to 8,347).
Specs (`games/game-001/tests/world/KitNodeMarker.spec.luau`, 14): all 38 nodes carry it (16 wood, 9 stone, 5 gold, 8 food) and no decor does, stand-ins and meshes, parts at most `Props.NODE_MARKER_PARTS`, the four colours apart, visual only, reach inside the node's
reach for every node type, idempotent, an unknown resource adds nothing, a shifted Root keeps the marker on the pivot, Layout and work spots unchanged; five mutants (a third part, a collidable, queryable or touchable part, a marker that widens the node, a wrong colour or a dull orb or another resource's,
a post that stops below the node, no marker) each fail the rule; removing the call from `WorldService` fails three specs (checked).

**My own look (every sheet opened).** At 170 studs the nodes are now findable at a glance: ice-white orbs over the two quarry stones, a yellow one over the ore, a red one over each berry bush, orange ones over the four wood-node trees; in A the wood and food nodes are not
distinguishable from decor at all. Weak points I see: the orbs look like balloons on sticks, bigger than the small nodes at 45 studs (the lineup); the orange of the wood marker sits in the same warm band as the crimson roofs and the wheat; the ice-white stone orb reads oddly beside a grey rock;
in the Blender renders the orbs cast shadows (Roblox: `CastShadow` is false, so no detached shadow there); the gold is "obviously gold" against green but only slightly more saturated than the wheat fields.

**Fresh image-only D-019 reviewer (round 1, one session; SET A = the meshes as PR 247 ships them, SET B = the same with markers; blind; 5 sheets: quarry/ore/berries crimson and emerald, the four wood nodes, a lineup of every node kind, the whole settlement; replies verbatim in
`img/d057-env-nodes-r1/review.json`)**: SET B **PASS** (silhouette 4, variation 4, readability 4, proportions 3, palette 4, detail 4, cohesion 3, cost 4), SET A NEEDS-WORK (3 / 2 / 2 / 4 / 4 / 4 / 5 / 5). Identified at both cameras: B all four resources;
A stone and gold with difficulty, food barely, wood never ("the wood-node trees are indistinguishable from the other oaks"). The reviewer's complaints about B: "party balloons rather than a worked-in marker", glossy flat spheres against the matte chunky kit (cohesion 3), thin posts through the canopy,
orange near the roofs and the wheat, markers shrink at 82 studs in the whole-settlement frame; not blocking (suggested: a flag or banner style, matte, a shorter post). **Round 2 was tried, not shipped**: a tilted faceted cube (3.8 studs) on a thicker, shorter post matches the chunky kit better but is clearly
smaller at 170 studs, and a cube big enough to compete would reach 3.99 studs, past the berry bush's 3.6 (the marker would widen a node), so the round-1 orb stays; the marker code shipped is byte-identical to what was reviewed (the dumps compare equal).

## 3.3 B. Dressing: cabbage variants, field fences and rim cliffs, only as imported meshes
**Decision: placed only when the Kit would build the mesh** (`Kit.envMeshReady(id)`: a Model for the id in `Forge.Assets` that passes `EnvMesh`'s checks against `Kit/EnvMeshData`; silent, counts and logs nothing). Why not stand-ins: the part-built `farm_field_cabbage_01/02` are 65 parts each,
a fence stand-in 7 to 8 parts (48 segments would be about 340 parts) and a cliff 4: about 1,000 parts for a world that sits at the D-047 ceiling, to draw something the mesh draws with 2 to 3 parts per prop. And the world without the imported kit (today's, every Lune spec, a Studio place before the import) stays
exactly today's: same placements, same parts, the same fingerprints and pins (`WorldService.spec` 642 placements / fingerprint 1544930042, 615 props / 8,271 dressing parts at density 1.0, + 76 for the markers). A missing or rejected mesh means that piece of dressing is simply not placed.
Implementation: `WorldPlan.meshDressing(layout, placements, ready)` (pure and deterministic, no PRNG; `WorldService` calls it after `WorldPlan.props`), `EnvMesh.ready`, `Kit.envMeshReady`. No Layout or Kingdom change (FORGE-01's); WorldPlan is the Kit's.

* **Cabbage variants.** The four cabbage fields were always `_03` (the id is `1 + field index % 3`, and the cabbage field is always the second of its plot). With the kit a cabbage field takes the variant of its kingdom: crimson `_01`, azure `_02`, emerald `_03`, gold `_01` (3 fields change, 1 stays). Wheat is untouched (`_01`, `_02`).
* **Fences.** `farm_fence_01` (one rail, 72 triangles) and `_02` (two rails, 84), 16.5 studs long, along the outside of each plot's three crop fields (40 x 30 studs, 2.4 studs outside the field's edge): the back and the flanks, never a side that faces the keep (outward normal toward the keep above 0.35) or has another field
  within 8 studs. A segment is dropped (never nudged) when five samples along it touch a slot, a building, a build zone, the arena, a road or the river. Result: **12 segments per plot, 48 in the valley**, identical on the four plots. They stay out of the nodes' drawn extent and cross no nav edge (specs).
  K's collider rule makes a fence solid (16.5 x 4 x 0.8); decorate leaves it solid (below the 7-stud collide height).
* **Cliffs.** `rock_cliff_01/02` (14.3 x 10.3 x 10.5 and 11.5 x 10.5 x 13.9, 138 and 132 triangles) on the flat ground 24 studs inside the foot of the mountain ring, one for every third ring mountain, slid along the foot so the line is irregular, facing the valley, only where the world's own clearance
  (bounds with its 8-stud margin, river, roads, keep-out discs, the arena) and the placed props allow: **12 at the shipped density, 11 at 1.0** (a tree takes one site). Why the rim and not the quarry flank: a grey cliff beside the stone nodes could be mistaken for a node (FORGE-00: keep nodes distinct from decor rocks) and the plots' flanks have no room;
  the rim is what the mountain ring already is. The price is that the cliffs stand 600 studs from every plot and are seen only when the camera goes to the edge. Sites (x, z): (-515, -626) (-347, 649) (-123, -594) (43, 629) (244, -600) (430, 641) (-641, -468) (679, -304) (-618, -105) (657, 76) (-629, 284) (675, 460).

Specs (`games/game-001/tests/world/KitEnvDressing.spec.luau`, 20; the checks are written independently of the implementation, with `Footprint` shapes built from the layout the way NodeKeepOut builds them): without the kit the placements are untouched (nil, none-ready and no-source predicates); `Kit.envMeshReady` is false without the kit
and true with it and builds nothing, counts nothing, logs nothing, false for a wrong-scale import or a missing Model; no fence, cliff or `_01/_02` cabbage in a part-built world and 416 props; the cabbage renumbering by kingdom; 48 fences and 12 (11) cliffs; 12 fences per plot; every fence legal and hugging a field (shipped and 1.0); every cliff legal, on flat ground
and off the other props; fences off the nodes and off the nav edges; a world built with the kit places 48 + 12 meshes with 3 parts each (180) and cabbages with 2; mutants: a fence on a slot, a road, the river, a building or a zone, a cliff on a road, the river, a plot, a node, the valley's edge, a tree or another cliff, a fence away from its field.
`KitEnvMesh.spec` now counts the dressing ids as ids the world places; `WorldService.spec` pins +76.

**shipped density: part-built world 6945 parts (416 props), world with the imported kit 2770 parts (476 props)**

| feature | placements | parts | triangles |
|---|---|---|---|
| bridge | 2 | 26 | 0 |
| bush | 55 | 165 | 13700 |
| cliff | 12 | 36 | 1620 |
| crops | 12 | 24 | 16496 |
| dressing | 9 | 83 | 196 |
| fence | 48 | 144 | 3744 |
| flowers | 31 | 62 | 8372 |
| forest | 184 | 552 | 81954 |
| lone_tree | 39 | 117 | 19986 |
| node:food | 8 | 40 | 2240 |
| node:gold | 5 | 25 | 1090 |
| node:stone | 9 | 45 | 1800 |
| node:wood | 16 | 80 | 8608 |
| rocks | 84 | 252 | 15270 |
| total (props and nodes) | | 1651 | 175076 |

**density 1.0: part-built world 8696 parts (615 props), world with the imported kit 3364 parts (674 props)**

| feature | placements | parts | triangles |
|---|---|---|---|
| bridge | 2 | 26 | 0 |
| bush | 110 | 330 | 27740 |
| cliff | 11 | 33 | 1482 |
| crops | 12 | 24 | 16496 |
| dressing | 9 | 83 | 196 |
| fence | 48 | 144 | 3744 |
| flowers | 31 | 62 | 8372 |
| forest | 222 | 666 | 99984 |
| lone_tree | 60 | 180 | 31088 |
| node:food | 8 | 40 | 2240 |
| node:gold | 5 | 25 | 1090 |
| node:stone | 9 | 45 | 1800 |
| node:wood | 16 | 80 | 8608 |
| rocks | 169 | 507 | 31054 |
| total (props and nodes) | | 2245 | 233894 |

Reading: with the kit the world has 476 placed props (shipped: 416 + 48 fences + 12 cliffs) and costs **2,770 parts against the part-built world's 6,945** (the same world with the markers); the dressing itself is **180 parts and 5,364 triangles** (144 + 36; 3,744 + 1,620).
Gross relief of the phase-2 families against the part-built world is 4,355 parts at the shipped density; the table's total, 4,175, is net of the dressing's 180 (the 76 marker parts are in both columns):

**shipped density: 6945 -> 2770 parts (4175 fewer, 60%)**, same 416 placements

| family | placements (incl. nodes) | parts today | parts with meshes | relief |
|---|---|---|---|---|
| birch | 51 | 459 | 153 | 306 |
| boulders | 84 | 330 | 252 | 78 |
| bush | 63 | 530 | 189 | 341 |
| cliffs | 0 | 0 | 36 | -36 |
| crops | 12 | 396 | 24 | 372 |
| fences | 0 | 0 | 144 | -144 |
| flowers | 31 | 279 | 62 | 217 |
| haystack | 1 | 4 | 3 | 1 |
| oak | 102 | 1632 | 306 | 1326 |
| other | 10 | 106 | 106 | 0 |
| pine | 86 | 1892 | 258 | 1634 |
| resource nodes | 14 | 122 | 42 | 80 |
| total | | | | 4175 |

**density 1.0 (the untrimmed valley): 8696 -> 3364 parts (5332 fewer, 61%)**, same 615 placements

| family | placements (incl. nodes) | parts today | parts with meshes | relief |
|---|---|---|---|---|
| birch | 60 | 540 | 180 | 360 |
| boulders | 169 | 664 | 507 | 157 |
| bush | 118 | 970 | 354 | 616 |
| cliffs | 0 | 0 | 33 | -33 |
| crops | 12 | 396 | 24 | 372 |
| fences | 0 | 0 | 144 | -144 |
| flowers | 31 | 279 | 62 | 217 |
| haystack | 1 | 4 | 3 | 1 |
| oak | 136 | 2176 | 408 | 1768 |
| other | 10 | 106 | 106 | 0 |
| pine | 102 | 2244 | 306 | 1938 |
| resource nodes | 14 | 122 | 42 | 80 |
| total | | | | 5332 |

**D-047 ceiling.** FORGE-00's all-built worst case is about 26.3k of 27k, which already contains the world's parts as they were (6,869 at the shipped density on this base). I did not rebuild an all-built case (no ceiling spec is on this branch; FL-0086's is not merged), so these are that figure plus my measured deltas:
**without the kit** 26.3k + 76 markers = **about 26.4k** (about 0.6k of headroom, the nodes' markers are the only addition: fences, cabbage variants and cliffs are not placed); **with the kit** 26.3k - 6,869 + 2,770 = **about 22.2k** (4.1k lower, the dressing's 180 and the markers' 76 included).
At density 1.0 the world is 8,696 parts part-built and 3,364 with the kit (no all-built figure was rebuilt for that either).

**Look (own critique; two sheets opened, both cameras plus the 45-stud lineup).** The fences make a U around the three fields (back and flanks), thin lines at 170 studs and readable posts and rails at 82; one lone segment on the east side of the first field looks purposeless (it is the field's own flank, the rule is "every exterior side that does not face the keep"); the back segments are identical repeats. The cabbage variants differ only by the heads' offset and shade, the three look alike.
The cliffs read as grey boulders, not as a rock face, and are small beside the 50-stud keep; **I have no render of them on the mountain rim** (the Blender scene has no terrain), so how they sit against the slope is unverified. **Fresh image-only D-019 reviewer (round 1; SET A = the part-built world as it is today, SET B = the world with the meshes and the dressing; 2 sheets: the farm at 170 and 82 studs, a close lineup of the new ids; blind; `img/d057-env-dressing-r1/review.json`)**:
SET B **PASS** (silhouette 4, variation 4, readability 4, proportions 3, palette 4, detail 4, cohesion 4, cost 5), SET A NEEDS-WORK (2 / 2 / 3 / 3 / 4 / 3 / 3 / 2). Reviewer notes on B, none blocking: fences thin and nearly invisible at 170 studs, identical repeats, the cliffs small and pale ("boulders, not rim cliffs"), the cabbage variants subtle,
the wheat busy. Polish candidates (each changes the FBX and needs a new review): thicker or taller fences and varied segment lengths, bigger cliffs, more different cabbage variants.

## 3.4 What changed in the kit files (the owner re-imports `env_kit.fbx`)
`env_kit_01` is now **58 ids** (the 52 the part-built world places, which are geometrically unchanged: the subset hash of those 52 is still 61bac208a4421907, so their phase-2 review stands; plus the 6 dressing ids promoted from the spares): `env_kit.fbx` 1,000,092 bytes (it was 874,652), `Kit/EnvMeshData.luau` regenerated (58 props, 16 sink warnings,
none new in kind). `env_kit_02` (spares) is now **9 ids** (189,340 bytes): wood nodes 01/02, iron ore 01/02, crystal ore 05/06, wheat 03/04/05. **Ripe only** and the ore decision: nothing places a growth stage; iron and crystal stay on the bench, in kit 2 only.
`IMPORT_ENVIRONMENT.md` says "58 ids". The manifest rows and the review pin follow (`blender/reviews/env_kit.json`: `env_kit_01` hash 4a676b85217c85f3, PASS, minimum scores 4 4 4 3 4 4 4 3).

## 3.5 Totals (for the PR text)
Triangles, measured from the FBX bytes (`manifest.check()` enforces the family budgets): **kit 1: 58 meshes, 22,834 triangles** (trees 20 / 9,058; bushes 8 / 2,000; flowers 6 / 1,626; rocks 16 / 3,010; crops 5 / 6,788; haystack 1 / 196; fences 2 / 156), largest mesh 1,430 (a wheat field); **kit 2: 9 meshes, 4,510 triangles** (rocks 6 / 1,170; crops 3 / 3,340).
What the world draws with the kit, every placement counted at its measured triangles (placements x triangles, buildings, bridges, the arena and the kingdoms not included; a worst case, streaming and culling cut it): **175,076 triangles at the shipped density** (trees including the wood nodes 110.5k, rocks, cliffs and the stone and gold nodes 19.8k, crops 16.5k, bushes including the food nodes 15.9k, flowers 8.4k, fences 3.7k)
and **233,894 at density 1.0**. Part count: shipped 6,945 part-built -> 2,770 with the kit (-4,175, -60 %), density 1.0 8,696 -> 3,364 (-5,332, -61 %). (Phase 2 alone was 171,472 and 230,594 on the base before main's arena keep-out.) The dressing adds 5,364 triangles and 180 parts. Phone cost of any of it is unverified.

## 3.6 Reproduce (Phase 3)
```
bash blender/scripts/check.sh                                              # must end "blender check: PASS"
lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/world KitNodeMarker
lune run roblox/tests/harness/run.luau --project games/game-001/default.project.json --specs games/game-001/tests/world KitEnvDressing
FORGE_ENV_NODEFIT=/tmp/nodefit.json lune run ... --specs blender/scripts/lune EnvNodeFit            # the room around each node
FORGE_ENV_DRESSING=/tmp/dressing.json lune run ... --specs blender/scripts/lune EnvDressing         # parts and triangles with and without the kit, the dressing's placements
FORGE_ENV_NODEMARKERS=/tmp/markers.json lune run ... --specs blender/scripts/lune EnvNodeMarkers    # the marker parts as the Kit builds them
FORGE_ENV_RELIEF=/tmp/relief.json lune run ... --specs blender/scripts/lune EnvRelief
python3 blender/scripts/envkit_report.py --relief /tmp/relief.json --nodefit /tmp/nodefit.json --dressing /tmp/dressing.json
~/forge-bpy/bin/python -I blender/scripts/envnature_scenes.py --inv /tmp/inventory.json --out /tmp/nr1 --scenes nodes_east_crimson,nodes_wood_crimson,nodes_east_emerald,nodes_lineup,settlement_crimson --modes after,marked --markers /tmp/markers.json --size 1600x900
~/forge-bpy/bin/python -I blender/scripts/envnature_scenes.py --inv /tmp/inventory.json --out /tmp/dr1 --scenes farm_crimson --modes before,after --dressing /tmp/dressing.json --size 1600x900   # and dressing_lineup
python3 blender/scripts/envnode_sheets.py --group nodes --renders /tmp/nr1 --out <folder> --key-out /tmp/key.json            # and --group dressing
```

## 3.7 Not verified, limits, and what FORGE-00 / K / the owner decide
* **Studio is unavailable here.** Unverified in Studio: the Neon glow and bloom of the orbs, the markers' look against the real lighting, `OnboardingController`'s highlight and arrow on a node Model (they now include the marker and are taller), the real `MeshPart` bounds of the 6 new ids against `EnvMeshData`, fence collision (solid, 4 studs, 16.5 long) against a walking ruler, how a rim cliff sits on the mountain's foot, draw calls and frame time, the real part count of an imported world.
* The cliffs have no render on the rim (no terrain in the Blender scene) and no D-019 sheet shows them in place; the rim sites are legal by the world's own clearance and flat ground, nothing more.
* One reviewer session per group, no second opinion; the node reviewer found the markers cohesion 3 (balloons), the dressing reviewer found the fences thin. Both pass.
* The 38 + 38 part figures and all-built ceiling numbers above are my deltas on FORGE-00's 26.3k, not a rebuilt all-built world.
* `NodeKeepOut.spec` runs only on the stand-ins. With the imported meshes the box measure is 0.1 to 2.8 studs over the rule for 7 of the 9 plot node types and the real outline only 0.35 stud (`tree_oak_05`): K's fit window (nodes at most 102 % of the stand-in footprint) does not cover it. FORGE-00 / K: accept, or run NodeKeepOut with the meshes.
* Asks for FORGE-00: (1) accept the orb marker as the node look (cohesion 3), or ask for a flag/banner restyle; (2) the cliffs on the rim are small and unseen: keep, scale up, or drop; (3) the fences are thin at 170 studs: thicken (a mesh change, new import); (4) wheat `_03` (scarecrow) as a third ripe plot variant: not done, say if wanted; (5) the lone east fence segment of each plot's first field: keep or drop.
