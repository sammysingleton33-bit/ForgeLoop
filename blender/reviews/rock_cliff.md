# rock_cliff: review log (author rounds, D-019)

Generator: `generators/rock_cliff.py` (v1) + `generators/_rock_common.py`. 5 assets `rock_cliff_01..05`
(01 stone, 02 cool granite, 03 curved warm (river bend), 04 tall bluff, 05 long warm).
Images: `previews/rock_cliff.jpg`, `renders/rock_cliff/rock_cliff_NN_hero.png`,
`renders/rock_cliff/rock_cliff_gameplay.png` (git-ignored, overwritten per build).

Rubric order: silhouette / variation / readability / proportions / palette / detail / cohesion / tris.

## Round 1: first build (per-layer rectangular blocks)
Scores: 2 / 3 / 3 / 3 / 3 / 2 / 3 / 4.
Problems: stacked bricks / pallets of stone, perfectly horizontal layers, flat block fronts, tiny talus.
Changes: faceted bulging block fronts, chipped top edges, dipping strata (3-6 deg shear), bigger talus.

## Round 2
Scores: 3 / 3 / 3 / 3 / 3 / 3 / 3 / 4.
Problems: still masonry (many small blocks per layer), bluff variant a wedding cake.
Changes: rebuilt as jointed columns (vertical joints through the whole height) sliced by shared dipping strata
planes; each band steps back towards the back face (ledges); colour bands continuous across columns; grass cap.

## Round 3
Scores: 4 / 4 / 4 / 4 / 3 / 4 / 4 / 2: looked like a cliff, but 1000-1950 tris and 2 open-edge failures
(facet-moss extrusion on cliff bands).
Changes: grass via `cap_layer` (plane cut + fill, always closed); full chamfer replaced by `chamfer_lips`
(only up-facing/front-facing ledge edges); fewer grass ledges; stronger strata colour contrast.

## Round 4: trying to stay in `rock` (1000)
Wider columns (12.5-15) and thicker strata fitted 1000 (584-772 tris) but the cliffs became 2-column boxy
"stacks of crates" with rectangular skylines: silhouette 3, detail 3.
Decision: use budget class `ruin` (1500) as allowed by the brief; columns back to 10-13 studs.

## Round 5 (final)
Scores: 4 / 4 / 4 / 4 / 4 / 3 / 4 / 4 (PASS on author scoring).
Changes: end columns get a sloped shoulder cut (natural skyline falling off at the ends), half the columns a
weathered front-top edge cut; budget-aware rebuild (fewer front facets) if a variant would exceed 1450.
Tris 546-1160 under `ruin` 1500 (3 of 5 are under 1000). Final full build.
Remaining weaknesses: faces between ledges are large flat facets (detail 3); white strata band on 04 is strong;
the sloped shoulder on 01 reads as a ramp; back side is plain (meant to sit against terrain).

## Technical note (all rock/resource generators)
Before the final build, `_rock_common.to_piece` was made order-independent (`canonical()` rebuilds each bmesh in
a geometry-sorted order before triangulating; moss vertices are offset in sorted order). Some bmesh operators
order their output by memory address, so the first build in a process triangulated differently from later ones
and the geometry hash changed between runs. Verified: identical hashes across repeated builds and processes.

## Fix round after the fresh-context review (NEEDS-WORK: silhouette 3, readability 3), v2
Reviewer findings: 02 / 04 read as a built block wall and a layer-cake tower; soft pillow-bevel slabs with bright
white rim lips (mortar); too blue (02) / too white (01, 04) with alternating bands; thin grass lids; reads as a quarry.
Changes:
- Rebuilt from jointed columns of different heights made like the boulders: near-sharp hull + 1-4 fracture planes
  (broken corners, big flat facets) and deep V cuts on the front vertical edges, so neighbouring columns meet in
  vertical cracks. No chamfer lips any more (`chamfer_lips` removed from the cliff).
- Strata per column: 2-4 bands, bedding planes tilted per band, thickness varying +-40 %; ledges recess
  irregularly, one band overhangs the band below, one column gets a stepped notch (half its top band dropped),
  three variants get a jutting spur (lower faceted buttress with a sloping, pointed top).
- Palette: warm greys like the boulders (granite / stone / rock_warm / sandstone_dark), bands only shift to a
  neighbouring tone once per column (no light/dark alternation); 02 is dark warm granite instead of blue.
- Turf: thick (0.4-0.5) plates of the rock's own surface: a plateau plate on each top plus 1-2 plates on the front
  lip whose prism drapes 0.9-2.0 studs down the face; irregular polygon borders; muted turf colours.
- Budget class `cliff` (1500) added to budgets.json (approved by the FORGE-02 lead); rebuild with fewer facets
  above 1450.
Quick-build scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 3, cohesion 4,
tris 4. Remaining: the bluff (04) is still a stacked tower by design, just broken up; turf tops are a little bright.
Final full build (v2): 844-1244 tris / 1500 (class cliff), all PASS, min silhouette diff 0.298.
