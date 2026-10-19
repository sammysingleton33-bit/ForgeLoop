# env_kit — author review log (D-019), FL-0136 phase 2

Generator: `generators/env_kit.py` (+ `_envkit_style.py`, `_envkit_trees.py`, `_envkit_plants.py`, `_envkit_rocks.py`, `_envkit_crops.py`), multi-prop kit built by `lib/envkit_build.py`.
Two FBX kits: `env_kit_01` = the 52 asset ids the world places today (`games/game-001/art/env_kit/env_kit.fbx` + `env.json`), `env_kit_02` = 15 spare ids nothing places yet
(`env_kit_spares.fbx` + `env_spares.json`). Style B (faceted, flat-shaded, vertex colours, one material). Full write-up, measured tables and the part-count relief:
`games/game-001/art/reviews/env-mesh.md` "Phase 2". Scores 1-5: silhouette / variation / readability / proportions / palette / detail / cohesion / triangle cost.

Render evidence is Blender (Cycles), never Studio. The "before" is the part-built `Kit.prop` stand-in rebuilt from a Lune dump of the real stand-ins; the "after" loads the SHIPPED FBX.

## Author rounds (my own look, every sheet opened)
Round 0 (first full build, 67 meshes, lineups and settlements rendered):
- Trees: flat and uniform (every oak the same dome, mid-green on mid-green) -> archetypes dome / tall / wide / lopsided / twin per id, a steeper ramp (deep blue-green to lime) painted by height and up-facing, rim clumps on the crown.
- Wheat first read as bricks, then (thinned) as sparse: -> ridge-topped clumps with gradient blades, three plot variants (rows along x golden; rows along z amber with poppies; pale straw with a path and a scarecrow).
- Gold ore read cream at 82 studs: -> deeper gold rgb(238,172,22), less white mixed in, seven angular nuggets on a dark base.
- Lineups showed some ids as stand-ins (only one FBX loaded) and the footprint measure differed from K's (mean radius vs max(x, z)): scenes now load both kits, `fit_to` uses K's measure.
After these changes I rendered the 11 round-1 sheets, opened them (settlements, forests, lineups, close views, crops, wheat stages) and judged them fit to send to the reviewers; I did not record numeric own scores.

## Fresh D-019 reviewers (round 1, one fresh image-only session per family group; SET A = part-built stand-ins, SET B = these meshes; blind)
Replies verbatim, session ids, image lists and the key: `games/game-001/art/reviews/img/d057-env-nature-r1/review.json`, `key.json`; sheets `sheet_*.jpg` beside them.

| group | sheets | SET B scores (sil / var / read / prop / pal / det / coh / cost) | SET B | SET A (the stand-ins) |
|---|---|---|---|---|
| trees, bushes, flowers | settlement crimson, forest broadleaf, forest pine, trees lineup, trees close, bushes lineup | 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4 | PASS | NEEDS-WORK (variation 3) |
| rocks, boulders, nodes | settlement emerald, rocks lineup, nodes lineup | 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4 | PASS | NEEDS-WORK (variation 2) |
| crops | crops, wheat stages, settlement emerald | 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3 | PASS | NEEDS-WORK (silhouette 2, variation 2, readability 2) |

No author round 2 was needed (PASS on all three groups). The reviewed geometry is the committed geometry: `env_kit_01` geometry hash `61bac208a4421907` is pinned in `env_kit.json`; I re-rendered all 19 'after' views of the 11 sheet scenes from the committed FBX at the same settings and every pixel equals the renders the sheets were cut from (maximum difference 0 of 255).
`env_kit_02` (spares) is NOT reviewed: only its wheat stages 04 and 05 were on a sheet.

## Defects the reviewers and I still see (none blocking; candidates for a polish pass)
- Aerial camera (170 studs): trees are readable, bushes, birches, rocks and nodes shrink to specks and the gold ore is not visible (a scale or marker question, not a mesh one).
- Pines are very dark and share one outline family; oak shadow sides sink toward near-black; some oak pairs are close to duplicates; birches are faceted lollipops on thin tilted trunks.
- The three plain bushes are alike; flower tufts are small. The three stone quarries differ mostly by tone and rubble.
- Wheat reads as a field of peaked tufts, not stalks; the shoots stage is faint at 82 studs; the haystack is small and low contrast against the grass.
- Stage and plot variants of wheat/cabbage change the field as a whole (they are not per-plant meshes), so "ripe vs unripe" works only if the runtime places the stage ids.
