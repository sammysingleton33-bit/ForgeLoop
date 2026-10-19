# tree_oak — author review log (D-019)

Images: `previews/tree_oak.jpg` (contact sheet), `renders/tree_oak/tree_oak_01_hero.png`,
`renders/tree_oak/tree_oak_06_hero.png`, `renders/tree_oak/tree_oak_gameplay.png` (overwritten each round;
the scores below were taken from the image produced in that round).

Rubric order: silhouette / variation / readability @60-80 / proportions / palette / detail / kit cohesion / tris.

## Round 1 (v1 first build)
Scores: 3 / 4 / 3 / 2 / 3 / 3 / 2 / 3
Problems seen:
- Clumps painted in 4 per-face colour bands -> hard faceted "gem" look, pale triangle caps on top; nothing like
  the soft smooth thatch of the cottage.
- Crowns sparse and disjointed (popcorn): separate lumps with sky between them; tall and young variants read as
  stacked broccoli.
- Trunks spindly (top radius 0.5x base), spreading oak 23 tall (below the 24 minimum), young oak 23.9.
- One budget breach (spreading 4028/4000).
Changes: dropped the 4-band paint; reshaped all lobe plans; bigger clumps.

## Round 2 (after FORGE-02 art-director notes)
Scores: 4 / 4 / 4 / 3 / 3 / 3 / 4 / 2
Problems seen:
- Much fuller and softer, but the underside colour cut (height based) drew a saw-tooth line across clump sides,
  very visible on the autumn trees (red/orange teeth).
- Sun-cap faces read as pale crescents ("frosting") on top clumps.
- 4 of 8 variants over 4000 tris (spreading 5140).
Changes:
- Crown = per lobe one big smooth core clump (180-tri frequency-3 geodesic, scaled to the lobe ellipsoid) wrapped
  in 2-9 smaller rim clumps spread by Fibonacci over the lobe's upper surface -> one cloud-like mass, lumpy edge.
- Trunk base radius 2.0-2.3 (old 2.7), taper 0.62, stronger flare; limbs chunkier (one per lobe), branches only
  to the lowest rim clumps (where the crown opens), twigs/sprigs removed: budget goes to canopy volume.

## Round 3
Scores: 4 / 4 / 4 / 4 / 4 / 3 / 4 / 4
Problems seen:
- Rim clumps too flat (lens/pillow shapes), trunk "sprig" puff looked like a lime ball stuck on the bark.
- Round and tall oaks hid their limbs completely: trunk ran straight into the foliage.
Changes:
- Clump colour now by face normal: darker swatch only on the flattened underside (hidden from 20-30 deg cameras),
  body swatch by height in the whole canopy (oak_mid low, oak_light mid, oak_sun crown), no saw-tooth.
- Rim clumps rounder (squash 0.86-0.94, bottom 0.58-0.7); geodesic spheres only on large top clumps and large
  cores (budget 1.9k-3.8k / 4000). Trunk sprig removed.
- Round/tall side lobes raised 1.2-1.4 studs so the fork and limbs show under the crown; young oak leans slightly.

## Round 4
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4
Seen: cohesive soft crowns with dark undersides and sunlit tops, visible fork and limbs, flared buttressed trunks
with roots, knot hole, mushrooms + dead limb on the veteran; autumn orange (twin crown) and autumn yellow (dome)
read clearly at 80 studs. Heights 25.6-35.9; widths 15-37.
Remaining weaknesses: lopsided (04) and round (01) are the closest pair (still 0.32+ silhouette diff); crowns have
no small-scale leaf texture (by design: chunky storybook style), branch tubes inside the crown cost ~15% of tris.

## Round 5 (final polish)
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4
Problem seen: the autumn-yellow dome was one flat pastel yellow (no interior depth next to the green oaks).
Change: autumn_yellow scheme = autumn_orange underside, hay_dark (ochre) core and low clumps, autumn_yellow middle,
flower_yellow crown. Final full (non-quick) build after this round.
