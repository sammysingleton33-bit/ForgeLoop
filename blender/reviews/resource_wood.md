# resource_wood: review log (author rounds, D-019)

Generator: `generators/resource_wood.py` (v1) + `generators/_rock_common.py` (`log`, `beam`). 6 assets
`resource_wood_01..06`.
Images: `previews/resource_wood.jpg`, `renders/resource_wood/resource_wood_NN_hero.png`,
`renders/resource_wood/resource_wood_gameplay.png` (git-ignored, overwritten per build).

Rubric order: silhouette / variation / readability / proportions / palette / detail / cohesion / tris.

## Round 1: first build
Scores: 4 / 4 / 4 / 4 / 3 / 3 / 4 / 3.
Problems seen:
- `bark_dark` piles read nearly black; all logs the same tone and perfectly cylindrical (machined look).
- Sawhorse variant overlapped the stump (both at the same spot): unreadable tangle.
- 05 and 06 over budget (1772, 1532 / 1500).
Changes: per-log bark mix (bark / bark_light), slight taper per log, sawhorse on its own spot with sawdust and
no stump, cut-end rings only on the front ends, 5-row pyramid starts with 5 logs, cart variant 3 rows.

## Round 2
Scores: 4 / 4 / 5 / 4 / 4 / 4 / 4 / 4.
Problems: bark still on the dark side (pale ends read clearly at 60 studs though); pyramids 01 and 06 were
near-identical silhouettes; the axe on the stump vanished at gameplay distance; branch stubs on the felled trunk
(03) invisible; piles read as neat blocks.
Changes: bark mix 50/50 bark / bark_light; bigger axe (head 0.5 x 1.5 x 0.95 + steel edge, 3.4-stud haft);
06 re-planned: 4 logs stood up leaning against the pile's far flank (resting on its slope), 4-row pyramid;
one bottom log pulled 1.3 studs forward to break the block silhouette; larger, upward branch stubs.

## Round 3 (final)
Scores: 4 / 4 / 5 / 4 / 4 / 4 / 4 / 4 (PASS on author scoring). Final full build.
Remaining weaknesses: logs are 7-sided without end chamfers (slightly hard rims); pile logs are all the same
length class; the cart (05) and sawhorse (02) props are small next to the pile at 60 studs.
Tris 892-1316 (budget 1500), all PASS, min silhouette diff 0.282.

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

## Fix round after the fresh-context review (NEEDS-WORK: variation 3), v2
Reviewer findings: one log radius and one colour; stump + axe on 5 of 6; wood_03 felled log low and weak; little
bark detail.
Changes:
- Girth varies about +-25 % per log; bark drawn from three shades (bark_dark / bark / bark_light); 45 % of logs get
  a knot or a raised bark ridge; cut ends are two-tone (pale end + darker `wood` heart disc).
- One stack shape per variant: 01 round pile on sleepers; 02 log crib (crossing layers of three); 03 felled trunk
  raised on two chocks + a two-tier stack of upright bucked rounds + a round with an iron splitting wedge;
  04 single row with two logs resting on top; 05 stack shored up with a leaning plank on a chock (stakes on the
  other side); 06 seven-log bundle lashed with two hexagonal rope bands.
- Stump + axe only on 01 and 06; the others get a bucksaw leaning on the crib, upright rounds, a chopping block
  with split wedges, a wheelbarrow of firewood.
Quick-build scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4,
tris 4.
Final full build (v2): 700-1120 tris / 1500, all PASS, min silhouette diff 0.400.
