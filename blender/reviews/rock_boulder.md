# rock_boulder: review log (author rounds, D-019)

Generator: `generators/rock_boulder.py` (v1) + shared helper `generators/_rock_common.py`.
9 assets: `rock_boulder_{s,m,l}_{01..03}` (sizes S 3-5, M 7-10, L 14-20 studs footprint; shapes dome / tall / table).
Images: `previews/rock_boulder.jpg`, `renders/rock_boulder/rock_boulder_<size>_<nn>_hero.png`,
`renders/rock_boulder/rock_boulder_gameplay.png` (renders are git-ignored and overwritten by each build;
the scores below were taken from the quick-build sheet of each round).

Rubric order: silhouette / variation / readability / proportions / palette / detail / cohesion / tris.

## Round 1: first build
Scores: 2 / 3 / 3 / 2 / 3 / 2 / 3 / 3.
Problems seen:
- Moss caps were thick, subdivided, smooth "helmets/jelly lids" sitting on the rocks; S_03 was almost all moss.
- Masses were egg / potato shaped (22-24-point ellipsoid hulls), little faceting; satellites tiny and far away.
- Hero view: the 5.5-stud proxy (placed front-right by the rig) hid the small boulders completely.
- Footprints undershot the size classes (S 3.0, M 5.9 instead of 3-5 / 7-10).
- L variants over budget (1259/1000), one open-edge failure (moss cap freed before use), 3 degenerate-face failures.
Changes: sliver fixer in `to_piece` (dissolve_degenerate + edge rotation of zero-area tris); cluster footprint
normalised to the exact size class; `HERO_VIEW` azimuth -35 (proxy now stands beside the rock; this also shows the
lit front plus the shaded left side, better modelling); satellites closer and larger; fewer pebbles/tufts.

## Round 2
Scores: 3 / 4 / 4 / 3 / 3 / 3 / 3 / 4.
Problems: moss still read as a lid with an even rim all round; tall shape still an egg.
Changes: new `moss_patch` (moss grows only on up-facing facets above 40-45 % height, lifted 0.1-0.3 studs,
tapered rim, flat-shaded) so the outline follows the rock facets; tall archetype: near-vertical fracture planes
and a tilted flat top (menhir-like slab).

## Round 3
Scores: 3 / 4 / 4 / 3 / 3 / 3 / 4 / 4.
Problems: masses still too smooth/rounded (too many hull points, shallow fractures); chamfers barely visible.
Changes: 12-14 hull points with 4-5 deep fracture planes (big flat facets), chamfer on edges > 28 deg,
biggest satellite 0.5-0.6 x main radius leaning on the main mass, facet colouring threshold lowered
(tops take the light swatch, undersides the dark one = painted light).

## Round 4 (final)
Scores: 4 / 4 / 4 / 4 / 4 / 3 / 4 / 4 (PASS on author scoring).
Changes: first satellite biased to the front half and pushed out so it reads in the hero; final full build.
Remaining weaknesses: on 2 of 9 the big satellite is still partly swallowed by the main mass; moss on M_03 / L_01
covers most of the top (reads, but heavy); granite vs stone families are close in hue (warm reads distinct).
Tris 330-978 (budget 1000), all PASS, min silhouette diff 0.177 (threshold 0.08).

## Technical note (all rock/resource generators)
Before the final build, `_rock_common.to_piece` was made order-independent (`canonical()` rebuilds each bmesh in
a geometry-sorted order before triangulating; moss vertices are offset in sorted order). Some bmesh operators
order their output by memory address, so the first build in a process triangulated differently from later ones
and the geometry hash changed between runs. Verified: identical hashes across repeated builds and processes.
Ground contact fix (same final build): grass tufts used to sink 0.05 studs and tilted props (tool handles,
ladder / tripod / sawhorse feet, root flares, the felled trunk) dipped up to 0.29 below z=0, which pushed the
pivot below the real ground line. Now rock pieces are clipped at z=0 in `to_piece`, tufts start at z=0, tool and
ladder bases are raised 0.14, and `rest_on_ground()` lifts any prop piece that still dips: every asset's lowest
point is exactly z=0 (checked per asset).

## Cross-set fix round (lead review), v2
Findings: moss caps read as flat, hard-edged lime lids (m_01, s_03, m_03; m_03 read as a bush); s_03 cost
670 tris for a 4x2x4 rock; l_01 978/1000.
Changes: moss is now 2-3 overlapping plates of the rock's own surface around sunny points (`moss_plates`), lifted
0.05-0.12 studs, so it follows every facet and the outline is ragged/patchy; muted olive (`moss`) tops with
cooler `pine_light` undersides. Small rocks skip the chamfer and use fewer hull points (S now 140-238 tris);
large rocks chamfer only edges over 38 deg and have one pebble/tuft fewer (L now about 830-920); tall stones are
capped at the size-class height. Shared `to_piece` hardening (no vertex welding, safe sliver rotation).
Final full build (v2): 140-920 tris / 1000 (S 140-238, M 540-736, L 694-920), all PASS, min silhouette diff 0.219.
