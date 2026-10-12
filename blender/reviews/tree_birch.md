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

## Round 5 (fix round after fresh review round 2: NEEDS-WORK, silhouette 3) — v3
Reviewer findings: canopies were dozens of same-sized flat pads (stacks of plates, busy outline, no primary
masses); birch_04 showed a bare broken spike above its lower foliage; birch_05's low clump sat on a thin stick;
trunks lacked the oak's root flare; 02/03 spent 3.5-3.7k tris on overlapping pads.
Changes (VERSION 3):
- Crown = 3-5 large primary masses per tree (smooth 180-tri geodesic, rounder/taller than the oak's: rz x1.18) with
  2-3 satellite clumps each, placed close to the stem (offset x0.72) and spaced so neighbouring masses overlap
  into one crown; dark twigs shortened so they stay under the rim.
- birch_04: stem now snaps at 15.5 studs and the stub is capped inside a foliage mass (no bare spike); the side
  leader (r 0.7) carries the upper, asymmetric crown.
- birch_05: side branch shorter (4.6 studs) and chunkier (0.8 x stem radius -> 0.36 tip); its mass sits close
  to the trunk.
- All: root flare 0.55, three small dark roots, consistent dark foot band (1.3-1.7 studs, ragged edge).
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4
Seen (quick sheet + 04 hero + gameplay strip): chunky merged crowns with sunlit tops, gaps only between masses;
leaning / twin / 3-stem / side-leader / low-arm / gold V-fork all read at 57 studs. Tris 1666-3016 (was
2218-3744); min silhouette diff 0.416.
Remaining weaknesses: 04 and 05 still stack their masses vertically with a visible neck of wood between them;
satellites on top read as small bumps rather than distinct clumps.
