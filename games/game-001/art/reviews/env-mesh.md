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
