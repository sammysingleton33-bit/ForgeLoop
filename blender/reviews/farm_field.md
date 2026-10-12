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
