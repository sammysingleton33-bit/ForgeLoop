# farm_field — author review log (FORGE-02 farm worker)

Asset ids `farm_field_01..06`, budget `crop` (3000), footprint 32 x 24 studs, rows run front to back (Y)
so the front entry gap opens straight onto a furrow. Rubric: reviews/README.md (1-5).

## Round 1 — first pass (v1, quick build)
Images: `previews/farm_field.jpg` (r1, overwritten), `renders/farm_field/farm_field_01_hero.png`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 2 | 4 | 2 | 3 | 3 | 2 | 3 | 4 |

Problems seen
- Wheat read as **baguettes / bread loaves**: one smooth domed loft per row, the 6-tri ears were buried in
  the dome and the same colour as the body. Not a golden field.
- Wattle border read as wooden **planks** (2 wide bumps); soil slab + border made the plot look like a tray.
- Raised beds looked like smooth boards; sprouts and pumpkin leaves too small/thin to read.
- Gameplay strip at 80 studs, camera at 12: fields are a thin line.

Changes
- Rebuilt wheat as a flat-topped body + 4 ear lanes (round 1b), then (see round 2) a different structure.
- Beds became lumpy lofts (noise) for non-wheat crops; sprouts/pumpkin leaves enlarged; wattle got 3 rods
  per face with alternating rod colours; stakes taller.
- `GAMEPLAY_HEIGHT = 22`, `GAMEPLAY_DISTANCE = 60`, `LINEUP_GAP = 2` so the strip shows the plots.

## Round 2 — wheat redesign (A/B test)
Images: `scratchpad/farm/ab.png` (A/B of four row designs), `scratchpad/farm/f1.png` (hero, 640 px).

The round-1b flat body still read as "spiky golden caterpillars" (thorn-like 3-sided ears on a planar wall).
Rendered four row designs side by side (A current, B/C/D: low dark stalk mass + long 'stalk + head'
spindles). **C won**: a low flared stalk mass (dark straw, shadowed) pierced by 5 staggered lanes of 6-tri
spindles whose long thin lower cone reads as the stalk and the swollen top as the seed head, leaning with a
sine "wind" along the row, edge lanes drooping outwards. 4-sided spindles (D) looked like crystals.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 3 | 3 | 3 | 4 |

Problems seen: heads a bit pale (too much `straw`); stooks on the harvest variant read as little stick
figures (five thin splayed sheaves); wattle still plank-like at distance; soil slab edge "tray".

Changes: head colours weighted to `wheat`/`hay`; stooks rebuilt as a ribbed 8-rib bundle with a rope band,
splayed butts and a crown of loose heads; soil slab inset inside the border so the border is the plot edge;
wattle rods `bark_light`/`wood_light`, taller pointed `bark_dark` stakes; cabbages enlarged (1.12-1.32).

## Round 3 — polish + budget
Images: `previews/farm_field.jpg`, `scratchpad/farm/field_r3.jpg`, `scratchpad/farm/f2.png`, `f3.png`, `f4.png`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 3 | 4 | 4 |

All six fit the budget (2618-2944 tris); variation min diff 0.10 (03 vs 06).
Remaining weaknesses: wattle border is cheap (one woven band per side, no over/under weave — the weave
costs too much over 112 studs of perimeter in a 3000-tri budget; the fence generator has the real weave);
cabbages/lettuce are simple lathes; stubble strips are plain.

## Round 4 — final (full build)
Images: `previews/farm_field.jpg` (final, 1300 px sheet), `renders/farm_field/farm_field_0N_hero.png`,
`renders/farm_field/farm_field_gameplay.png`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 3 | 4 | 4 |

Changes: worn stepping stones through the entry gap, weed tufts in the border corners (only where the
budget allows), collision switched to fidelity `None` + five border collision boxes (crops walk-through,
gap open). Final: 2690-2968 tris / 3000, all PASS, variation min 0.119 (04 vs 05), BUILD PASS.
Gameplay (60 studs): wheat reads as golden bristly rows, cabbage/lettuce green dots, pumpkins orange,
scarecrows mark two plots; the sown plot is intentionally quiet (beds + sprouts).

## Round 5 — fix round after the fresh-context review (NEEDS-WORK) + palette v1 retune (v2)
Reviewer issues: field_06 read as bare dirt at 60 studs; every plot had the same 32 x 24 silhouette;
field_02 stubble slabs read as planks and the stooks did not read as tied sheaves; 01/04 near the budget cap.
Images: `previews/farm_field.jpg` (final), `scratchpad/farm/field_fix_quick.jpg`, `scratchpad/farm/f2.png`, `f5.png`.

Changes (VERSION 2)
- Plot width is now per variant: **04 pumpkin patch 24 x 24** (4 rows) with a **tool rack** (hoe, spade, rake on a
  rail; vertical accent); **05 kitchen garden 16 x 24** with **runner-bean pole teepees** (4 poles tied at the apex,
  climbing leaf mass, red flowers, pods; ~5.2 tall) between a carrot row. 03 and 06 keep their scarecrows.
- 06: leafy seedlings (three broad leaves 1.4-1.7 long, ~2x the old sprouts) at 1.3-1.45 spacing.
- 02: stubble slabs replaced by two lanes of low stubble tufts per cut bed (3 cut, 2 standing rows); stooks are four
  individually **tied sheaves** (dark butts, contrasting `cloth_brown` band, flared straw heads) stood head-to-head,
  plus two sheaves lying where they were bound.
- Wheat: 4 head lanes instead of 5 (slightly fatter heads), fewer loft stations -> 01 at 2418 tris.
  04: 8-segment pumpkins, 4-segment leaves -> 2396 tris.
- Checks relaxed to `min_crops 12`, `min_rows 3` (pumpkin patch has 16 pumpkins, bean garden 3 rows).
- Palette retune (muted wheat/straw) is picked up automatically; wheat now reads tan-gold, not saturated.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 4 | 4 |

Quick build: 2396-2862 tris, variation min 0.101 (03 vs 06), BUILD PASS. Final full-build numbers in the report.
Gameplay notes unchanged: furrows 2.2-3 studs (bean garden 4-stud pitch), entry gap 4.4 at the front, sockets
`harvest` (plot centre) and `entry`; collision = border boxes only (fidelity None).
Final full build: 2396-2862 tris / 3000, variation min 0.101, BUILD PASS (previews/farm_field.jpg 180 KB).

## Round 6 (fresh-review round 3) — farm_field still NEEDS-WORK (silhouette 3, readability 3) (v3)
Reviewer issues: field_05 cones read as cypress trees; wheat spikes read as crystal shards at knee height and the
beds under the wheat were too saturated (~0.60) next to kingdom gold; field_02 half-harvest beds looked
unfinished for 2,862 tris; field_06 duplicated field_03 (stone border, scarecrow, layout) and its sprouts became
green noise.
Images: `previews/farm_field.jpg` (final), A/B studies `scratchpad/farm/ab2.png` (bead heads on stalks: tulip
buds), `ab3.png` (slim ears on thin stalks: reads as wheat), `ab4.png` (smooth spindles: still flame-like),
`ab5.png` (lumpy clumps: onions/sacks), heroes `scratchpad/farm/f1.png`, `f6.png`.

Changes (VERSION 3)
- **Wheat (01, 02)**: 4 wider rows. Each row = a low, soft straw stalk mass (`hay`, darkened top so it no longer
  reads as a bread loaf) with **clumps of three thin stalks** (3-sided cones) each carrying a smooth ear, fanned and
  leaning with the wind; 17 clumps per row zig-zag across the row; ears reach ~4 studs (waist height). Ear colours
  are the muted `wheat`/`straw`/`thatch_light` only. Beds under wheat are `road_dark` (sat 0.44) on `mud` soil, so
  the straw reads light on dark without any gold.
- **field_02**: 2 cut beds now carry a stubble band with stiff tufts, a row of bound sheaves laid across the bed
  (4-sided, dark butts, `cloth_brown` band) and one stook; 2 standing rows; wattle border. 2830 tris, beds full.
- **field_05**: maize + runner beans, 6.2-7.0 studs tall (towers over the 5.5 character): two maize rows (thin stalk,
  four drooping strap leaves, tan tassel, husked cob) around a row of single bean poles (spiral vine, heart leaves,
  red flowers, pods).
- **field_06**: young **turnips** (three broad upright leaves over a white bulb with a purple shoulder) in 5 rows,
  **wattle** border, entry on the right, a **water trough + bucket** in place of the scarecrow.
- Dead code removed (old sprout/carrot/lettuce/teepee helpers).

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 4 | 3 |

Remaining weakness: inside a 3000-tri budget for a 32 x 24 plot the wheat is still a stylised mass + ~200 ears, not
a true clump-per-plant field (01 is at 2844 tris); the wheat rows read best from the 3/4 hero angle.
Note: the optional barn banners (01/04) and blue bargeboards (02) were not done: farm_barn just PASSED review and
any geometry change would drop it back to UNREVIEWED.
Final full build: 2396-2844 tris / 3000 (01 2844, 02 2830, 03 2710, 04 2396, 05 2408, 06 2640), variation min 0.105 (01 vs 02), BUILD PASS.
