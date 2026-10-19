# Writing a generator (FORGE-02)

A generator is one file `blender/generators/<name>.py`. `build.py` discovers it automatically.
Read `ART_DIRECTION.md` first. Look at `generators/house_cottage.py` as the reference example.

## Module contract
```python
NAME = "house_cottage"        # == file name; asset ids are f"{NAME}_{NN}" unless asset_id() is defined
VERSION = 2                   # bump when output geometry changes on purpose
CATEGORY = "house"            # first word of every asset id (id regex ^[a-z]+(_[a-z0-9]+)+_\d{2}$)
BUDGET = "building_small"     # class in budgets.json (LOD0 triangle budget)
COLLISION = {"fidelity": "PreciseConvexDecomposition"}   # Box | Hull | Default | PreciseConvexDecomposition | None
CHECKS = {"min_windows": 3}   # structural anti-primitive checks against b.stats (min_/max_/has_ prefixes)
DEFAULT_VARIANTS = 6

def variants(n, seed) -> list[dict]      # deterministic params per variant; include "seed" and optional "kingdom"
def build(b, params) -> None            # add Pieces to the Builder `b`
# optional: asset_id(i, params) -> str, HERO_VIEW = {"azimuth": 35, "elevation": 20},
#           LINEUP_GAP = 4.0, GAMEPLAY_DISTANCE = 60.0, GAMEPLAY_HEIGHT = 12.0, RENDER_FIDELITY = "Automatic"
```

## Builder (`lib/asset.py`)
- `b.rng` — seeded `random.Random`; use only this for randomness (determinism).
- `b.add(piece_or_list, color=None, grad=..., smooth=..., tint=..., tag=...)`.
- `b.socket(name, x, y, z)` — gameplay attach points (door, interact, spawn, banner…), exported in the manifest in Roblox coordinates.
- `b.collision_box(cx, cy, cz, sx, sy, sz, name)` — optional invisible collision Parts (e.g. tree trunk only).
- `b.stats["windows"] = 4` — values checked by `CHECKS`; `b.count_tag("roof")`.

## Geometry (`lib/geo.py`): plain-Python `Piece`s
Primitives (base at z=0 unless noted): `box(sx, sy, sz, color, base=True)`, `lathe([(r, z), ...], seg)`,
`cylinder(r0, r1, h, seg)`, `cone(r, h, seg)`, `prism(poly2d, depth, axis="Y")`, `loft(poly, ys, deform=)`,
`loft_rings(rings)`, `icosphere(radius, subdiv)`, `uvsphere(radius, seg, rings)`, `tube(points, radii, seg)`,
`merge(pieces)`; operators `bevel(p, offset, segments)`, `subdivide(p, cuts)`, `recalc_normals(p)`.
Piece methods: `move`, `rotate(angle, "X|Y|Z")`, `scale`, `transform(Matrix)`, `jitter(rng, amount)`,
`noise_displace(amount, freq, seed)`, `taper(z0, z1, s0, s1)`, `bend(fn)`, `paint(color=, grad=, smooth=, tint=, tag=)`, `copy()`.

Colour gradient (`grad`): default `("range", 0.3, 0.85)` along the piece's height; `"global"` = whole asset
height; `"flat"`; a number; `("range", lo, hi)`; `("grange", lo, hi)` = asset-height range. 0 = darkest, 1 = lightest.
Foliage: use strong ranges (0.0–1.0) so clumps get dark undersides and sunny tops.

## Shared kit (`lib/kit.py`) — use it, don't re-invent
`bbox` (bevelled box), `oriented_box` (beam p0→p1), `wall_face_frame`, `window`, `door`, `gable_roof`
(`style="tile"|"thatch"`), `thatch_roof`, `gable_end`, `cone_roof`, `crenellations`, `chimney`,
`stone_course`, `plank_floor`, constants `CHAR_H, DOOR_W, DOOR_H, WIN_W, WIN_H, SILL_Z, STOREY, TIMBER`.
Kingdom colours: `palette.kingdom_color(k, role)` with roles `roof_dark roof roof_light cloth_dark cloth
cloth_light trim trim_dark shutter stone stone_dark stone_light accent wood emblem glow`.

## Triangle discipline
A bevelled box costs ~44 tris, a plain box 12. Bevel what is big enough to catch light (walls, roofs, big
stones, trunks); keep small members (timbers, battens, frames) unbevelled. Lathes: 6–10 segments.

## Commands
```bash
~/forge-bpy/bin/python blender/build.py --generator <name> --quick     # fast iteration (small renders)
~/forge-bpy/bin/python blender/build.py --generator <name>             # final previews (600 px heroes)
~/forge-bpy/bin/python blender/build.py --list
```
Outputs: `exports/<id>.fbx` + `.validation.json` (git-ignored), `renders/<name>/` (git-ignored),
`previews/<name>.jpg` (committed, ≤ 250 KB), `manifest.d/<name>.json` (committed).

## Review loop (D-019) — mandatory
Render → open the image (Read the PNG/JPG) → score with the rubric in `reviews/README.md` → refine.
At least two critique→refine rounds per generator, logged in `reviews/<name>.md`. Script success is not quality.

## Library backlog (requests from the generator workers, 2026-10-12)
Apply after the current worker rounds finish, because `lib/` changes rebuild every generator. In priority order:
1. **Hash stability.** Some bmesh ops order their output by memory address, so the first build in a process can
   triangulate differently and change the geometry hash that pins reviews (seen on rocks; fixed locally in
   `_rock_common.canonical()`). Make `asset.geometry_hash` order-independent (sort triangles canonically),
   migrate the recorded review hashes once, and add a test that builds one generator twice in one process.
2. **Gameplay stats in the manifest.** `b.stats` values gameplay needs (`harvest_radius`, socket radii) reach only
   the validation JSON. Export them per asset in the manifest (schema bump) for FORGE-01.
3. **Kit helpers to share:**
   - `ashlar_plane` / `ashlar_ring` / `annulus` (now in `_castle_common.py`);
   - a cart wheel, wide double barn doors and per-band lathe colours (now in `_farm_common.py`);
   - a smooth geodesic option for `geo.icosphere` (now in `_vegetation_common.py`).
   - `emblem()` (crown, star, oak leaf, sun) from `_kingdom_props_common.py` into `lib/kit.py`. farm_* already
     import it across generator families; every kingdom banner and shield should share one emblem source.
   - `wheel()`, `sheet()` (solid cloth, `normal="auto"`) and `sweep_loop()` from `_kingdom_props_common.py`.
4b. **`kit.oriented_box` gets an explicit `up` parameter.** When the normal is parallel to the beam axis, the
   cross-section is arbitrary today (worked around with `obox` in `siege_ballista.py`).
4c. **Docs/rig.** `geo.icosphere(subdiv=1)` is a 20-face icosahedron (document it). The hero proxy is cut off at
   the right edge of small-prop heroes (`prop_goods`); place it relative to the asset width.
4. **Kit options:**
   - `gable_roof(..., flush_ridge=True)`, a ridge cap without the 0.2 overshoot;
   - a cheap voussoir mode for `kit.door` (about 12 tris per stone, not ~540 per door).
5. **Bug.** Clamping a whole sphere to the ground folds it flat, and `recalc_normals` then flips the shell inward (black render). Guard the clamp, or skip normal recalculation on degenerate shells.
6. **Data.**
   - a `cliff` budget class (1500); rock_cliff uses `ruin` today;
   - a cool `snow` swatch (append-only), where tree_pine uses `foam` today.
7. **Variation check.** Modular pieces that share end posts (fences, walls) score as near-identical side
   silhouettes. Compare front and top silhouettes only for classes tagged `modular`.

## Parked: farm_field (NEEDS-WORK after 3 fresh-review rounds, 2026-10-12)
Rounds 1–3 failed on silhouette (3/5) for the same cause each time: a 32×24 plot of wheat inside the
3,000-tri crop budget reads as a flat bed with thin spikes. Readability, palette and triangle cost passed in round 3.
Rather than a fourth round of the same approach, the change of strategy is:
1. **Split crops from plots.** The plot asset is the bed, border and props. Crops become separate small
   instanced assets (`crop_wheat_clump`, `crop_maize`, …, about 150–300 tris each) that WorldPlan/Kit scatter densely,
   so wheat can be a chunky waist-high mass without blowing one mesh's budget. This needs a FORGE-01/FORGE-05
   check on the instance counts.
2. Or a `crop_large` budget class (4,500), as the farm worker requested, if instancing is rejected.
3. Vary the borders (only 03 is stone) and give 04/06 a vertical accent (trellis, post with basket).
4. Gameplay strip: 6 × 32-stud plots only fit at 88 studs. Allow a two-row lineup for wide sets
   (`LINEUP_ROWS = 2`) so the reviewer can judge at 60.

The in-game farm uses the Kit's part-built field (FL-0054), so VS-1 is not blocked. The Blender field is an FL-0057 import.

## Parked: tree_birch (NEEDS-WORK after 3 fresh-review rounds, 2026-10-12)
Round 1 failed on variation; rounds 2–3 failed on silhouette (3/5) for the same cause: crowns built as stacked,
equal-size blobs with no branch arms. Bark read, the autumn ramp, variation and triangle cost now pass.
Strategy change (one attempt, then report): build the birch crown with tree_oak's proven crown builder (the oak
passed first time) using a tapering teardrop envelope with drooping tips. Clumps hang on short visible branch arms.
Use one continuous trunk taper (06's seam), add a small dark root flare on every variant, use bold flush bark marks,
and drop the hairline twigs. Not on the VS-1 path: forests use oak and pine, and the Kit has its own birch stand-in.

## Parked: rock_cliff (NEEDS-WORK after 2 fresh-review rounds on silhouette, 2026-10-12)
Both rounds read the cliffs as built walls or a layer cake (stacked horizontal slabs, block grids). The world does
not need cliff meshes for VS-1/VS-2: WorldPlan already builds hills with terrain Rock/Slate crowns and scatters
boulder clusters at their feet. Strategy change, if cliffs are needed later: build them as clusters of the passed
rock_boulder masses (scaled, overlapped and tilted), with turf from the boulder moss helper, rather than as layered slabs.

## Parked: resource_stone and resource_ore (NEEDS-WORK after 3 fresh-review rounds, 2026-10-12)
In-game resource nodes use the Kit's part-built stand-ins (`Kit/Props.luau`), so VS-1 is not blocked.
- **resource_stone.** Round 1 failed on variation, rounds 2–3 on "+"-reading joints and hull-like bases. The props
  (windlass, crane, treadwheel, sled) pass, and the quarry reads distinct from ore and wood in every colour mode.
  Strategy change: build the rock from the passed rock_boulder builder (uncut faceted rock), carve one worked face,
  and put the joints only on that face, staggered across tiers and checked from the low gameplay camera. Use a
  warm mid-grey, never near-white.
- **resource_ore.** v1 passed round 1 on colour alone. The accessibility rework (rounds 2–3) made it worse: iron
  reads as meat or candy, the gold nuggets sit on the surface, and every variant shares one layout. v1 cannot be
  restored because it was never committed. Lesson: commit a passing version before asking for an optional
  improvement. Strategy change: generalise the crystal approach, which reads in colour, greyscale and CVD, to
  every ore. Iron becomes dull steel-grey angular crystals in rust-stained rock; gold becomes bright faceted nuggets
  embedded in a split seam. Use the passed boulder builder for the rock, and give each variant its own layout.

## Parked: prop_well (NEEDS-WORK after 3 fresh-review rounds, 2026-10-13)
Round 3 failed on readability only (3/5). Silhouette, variation, palette rules and triangle cost pass. Remaining fixes
(one attempt when unparked):
- blue: the star finial is a speck at 40 studs. Use an ivory star on a royal-blue roundel, the same size as the crown and sun finials.
- gold: the thatch reads as khaki hay. Put the sun on an ivory or bronze roundel, add bronze/ivory eave trim, and warm the thatch.
- 01 and 04 share a body (posts, crank, ring). Give 04 its own well head (round pavilion roof or bronze-banded rim).
The in-game well is the Kit stand-in, so VS-1 is not blocked.

## Parked: kingdom emblem polish (char_soldier archers, smithy_04 / barracks_04 sun, crown consistency) — 2026-10-13
Emblem readability went through fresh rounds 4–6. Each round fixed the named defects (crescent finials,
flame → crown per D-039, one oak design, sun never on gold) and then found smaller ones. Per the two-attempt
rule this is parked with a change of strategy instead of another detail round.
- Open (fresh round 6): char_soldier archers 05–08 (chest emblem only marker, pouch covers it; 07 red
  feather, 08 green panel, 08 sun on cream-on-yellow vanishes in grayscale); smithy_04 and barracks_04 sun is
  a small sun-in-ring on gold that reads as a dot / cog at range; crown differs (gold + band on soldiers and
  banners, plain cream on smithy/barracks via their own `emblem_poly`).
- Strategy for the next pass: **one kit-wide emblem plaque**, not per-generator emblem tweaks. A helper in
  `_kingdom_props_common` that every generator calls for kingdom identity: an ivory field (almond shield or
  square plaque) carrying the large emblem in the kingdom's dark tone. Reference: the soldier's large ringless
  sun on a cream almond shield (fresh round 6: "the best sun in the kit"); crown = gold with band.
  Size it from the gameplay camera distance (emblem ≥ ~10 px at the sheet's gameplay strip), retire
  `_civic_common.emblem_poly` / `_village_large_common.emblem_poly`, then one fresh review across all
  emblem-bearing generators.
- Not on the VS-1 critical path: VS-1 renders the part-built Luau Kit (D-021); Blender meshes swap in later
  by asset id.
