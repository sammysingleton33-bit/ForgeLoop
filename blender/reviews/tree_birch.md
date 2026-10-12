# tree_birch — author review log (D-019)

Images: `previews/tree_birch.jpg`, `renders/tree_birch/tree_birch_02_hero.png`, `renders/tree_birch/tree_birch_03_hero.png`,
`renders/tree_birch/tree_birch_gameplay.png` (overwritten each round; scores taken from that round's images).

Rubric order: silhouette / variation / readability @60 / proportions / palette / detail / kit cohesion / tris.

## Round 1
Scores: 2 / 4 / 3 / 3 / 3 / 3 / 3 / 4
Problems seen:
- Canopy = separate flat pancakes on stalks (bonsai / lily-pad look), not a cohesive airy crown.
- Dark foot band 1.6-2.4 tall read as a brown sock; birch_mark dashes barely visible.
- Top clumps pale and sickly (leaf_yellow crown).
Changes: crown rebuilt from 2-4 lobes per trunk (core + Fibonacci rim clumps, the oak recipe at birch scale), lobes
alternating around the trunk, limbs into each lobe, dark twigs to the drooping lower clumps; foot band 0.9-1.4 with a
ragged noise edge in birch_mark; marks wider (1-1.7 x radius) and proud of the bark.

## Round 2
Scores: 3 / 4 / 4 / 3 / 3 / 4 / 4 / 4
Problems seen: lobes too small and offset too far, so single birches read as a skewer of puffs; the 3-stem clump read
as three lollipop trees; tops washed out.
Changes: bigger, more overlapping lobes (offset 0.5 rx), rounder rim clumps; 3-stem clump leans less so the crowns
merge; birch scheme = leaf_light low, birch_leaf mid, birch_leaf_light crown.

## Round 3
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4
Seen: six birches (single 32, twin 34, 3-stem clump 29, tall 37, young 26, autumn-gold twin 32), white trunks with
dark dashes and dark foot, narrow oval light-green crowns with gaps that show limbs, lighter and airier than the
oaks. Tris 2.4k-3.7k / 4000.
Remaining weaknesses: crown made of many similar small puffs (a little bubbly at hero distance); single, tall and
young share a silhouette family (size carries most of the difference); limbs mostly hidden.

## Round 4 (fix round after fresh-context review: NEEDS-WORK, variation 3) — v2
Reviewer findings: birch_01/04/05 were one template uniformly scaled (identical 2,352 tris); birch_06 was a recolour
of birch_02 (identical 3,648 tris) in washed-out beige; thin pole under a high lollipop, out of step with the oaks.
Changes (generator rewritten around explicit per-style stem + lobe plans, VERSION 2):
- 01 leaning: one stem curving 6-7 studs sideways (lean set across the camera view), crown thrown to that side.
- 04 broken: tall stem (base r 1.3) snapped at 22 studs with pale inner-wood cap + 5 splinters; a side leader from
  mid-height carries a lopsided crown, a small lobe on the opposite side.
- 05 young: kinked young stem with one long, nearly horizontal low branch (~7 studs up) ending in its own lobe.
- 06 forked: short thick trunk (r 1.25) splitting at ~10.5 studs into a V of two leaders; new warm ramp
  birch_gold = autumn_red underside, autumn_orange low, autumn_yellow mid, flower_yellow crown (no straw/beige).
- All: base radius 0.85-1.3 with flare and taper (trunk_taper now measured foot -> thinnest crown-carrying top),
  bends/kinks, lobes from ~35-45 % of the height (clump also gets a low lobe), lobes 10-15 % larger.
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4
Seen (quick sheet + gameplay strip): six different structures; tris now 2218 / 2850 / 2836 / 3064 / 3552 / 3744
(no two equal); min silhouette diff 0.456 (was 0.335). The snapped stub reads clearly in the gameplay strip; in the
04 hero (35 deg azimuth) it sits partly behind the leader crown.
Remaining weaknesses: crowns are still built from many similar small puffs; twin (02) and clump (03) remain the
most conventional of the six.
