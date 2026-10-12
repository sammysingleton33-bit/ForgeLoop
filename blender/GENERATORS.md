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
