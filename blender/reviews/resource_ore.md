# resource_ore: review log (author rounds, D-019)

Generator: `generators/resource_ore.py` (v1) + `generators/_rock_common.py`. 6 assets `resource_ore_01..06`
(01-02 iron, 03-04 gold, 05-06 crystal).
Images: `previews/resource_ore.jpg`, `renders/resource_ore/resource_ore_NN_hero.png`,
`renders/resource_ore/resource_ore_gameplay.png` (git-ignored, overwritten per build).

Rubric order: silhouette / variation / readability / proportions / palette / detail / cohesion / tris.

## Round 1: first build
Scores: 3 / 4 / 4 / 3 / 4 / 3 / 3 / 3.
Problems seen:
- Veins were two thin even bands crossing in an X: the rocks looked gift-wrapped with ribbon.
- Gold nuggets floated in the air (snapped along the band normal off the surface).
- Crystals too fat and overlapping (blob); loose ground crystals lay flat like sticks.
- 06 over budget (1504/1500).
Changes: one wedge-shaped band limited to the front, nugget clusters ray-cast inside the band plane, slimmer
crystals fanned out, upright ground crystals, one pebble fewer.

## Round 2
Scores: 3 / 4 / 4 / 4 / 4 / 3 / 4 / 4.
Problems: an even-width band still reads as a belt/strap; nuggets too small to see.
Changes: replaced bands with a chain of exposed ore plates (the rock surface inside an irregular 8-plane polygon,
inflated to stand proud) running diagonally across the front, each with 2-4 chunky nuggets (iron 0.6-1.05,
gold 0.42-0.75 studs) + an ore plate and nugget on the big satellite.

## Round 3 (final)
Scores: 4 / 4 / 5 / 4 / 4 / 4 / 4 / 4 (PASS on author scoring).
Reads at 50-60 studs: iron = blue-grey rock with rust-orange patches (+ mine cart on 02), gold = dark rock with
bright yellow seam (+ crate on 04), crystal = dark slate with cyan spikes. Final full build.
Remaining weaknesses: iron and gold share the same silhouette language (they differ by colour, not shape);
the crystal rock's big flat dark facets are plain; gold plates on 04 are large ("melted cheese").
Tris 916-1438 (budget 1500), all PASS, min silhouette diff 0.148.

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
Findings: gold too dark/mustard (accessibility); iron and gold shared one shape language; ore/stone/wood nodes
shared the "main mass + front stack + leaning tool" layout.
Changes: gold uses `gold` / `ore_gold` / `yellow_glow` (value >= 0.8, light tips on up-facing facets) and its cue is
SHAPE: short thin seams studded with 4-5 big protruding nuggets each (sunk only 5 %, elongated 1.5x) plus extra
nuggets bursting out elsewhere and a nugget cluster on the satellite. Iron is FLAT: four long, low plates (barely
proud) with at most one flush lump each. Composition: loose ore now sits in a heap at one side (front left clear
for the worker), the only tool is a pick bitten into the top of 01, carts/crates kept on 02/04, no leaning tools.
Final full build (v2): 922-1390 tris / 1500, all PASS, min silhouette diff 0.196.

## Round 3 (fresh-review round 2: NEEDS-WORK, accessibility), v3
Reviewer findings: iron veins as bright as the slate (vanish in greyscale, khaki like gold for protan/deutan);
gold nuggets specks at 52 studs; ore_01-04 read as plain boulders.
Changes:
- Iron: dark rust-red ore (red_cloth_dark / red_roof_dark, linear luminance 0.04-0.08) on a lighter cool-grey rock
  (stone_cool_dark / stone_cool / stone_cool_light, 0.13-0.43): a clear brightness gap in greyscale and for
  colour-blind viewers (iron = dark, gold = bright, crystal = mid-bright spikes). Veins are three chunky RAISED
  flat bands (rock surface lifted ~0.45 studs), plus one big angular ore chunk jutting out of the top (breaks the
  outline) and one out of the satellite.
- Gold: three big ROUND lumps (r 1.2-1.55, 12-point hulls, sunk only 8 %) sitting high on the rock so they break
  the silhouette, two medium lumps on the front, one on the satellite; seams dropped.
- Colour-independent cues: a spill of ore at the base (angular chunks for iron, round lumps for gold), a bigger
  mine cart (4.2 x 2.9 x 2) heaped with chunks, a bigger iron-banded crate heaped with gold lumps.
- Self-check: greyscale conversion of the final gameplay strip (renders/resource_ore/resource_ore_gameplay.png) shows dark iron bands/chunks on light rock, light
  gold lumps on dark rock, light crystal spikes on dark rock.
Quick-build scores: silhouette 4, variation 4, readability 5, proportions 4, palette 4, detail 4, cohesion 4, tris 4.
Final full build (v3): 716-1390 tris / 1500, all PASS, min silhouette diff 0.274.
