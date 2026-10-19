# bridge_stone — author review log (D-019)

Images: `previews/bridge_stone.jpg`, `renders/bridge_stone/bridge_stone_1arch_01_hero.png`,
`renders/bridge_stone/bridge_stone_2arch_01_hero.png`, `renders/bridge_stone/bridge_stone_3arch_01_hero.png`,
`renders/bridge_stone/bridge_stone_gameplay.png` (overwritten each round).
Rubric order: silhouette / variation / readability / proportions / palette / detail / kit cohesion / tris.

Variants: 1 arch 40 long (warm grey stone), 2 arches 48 long (sandstone), 3 arches 56 long (cool stone).
Deck 12 clear between parapets (body 14.4 wide), parapets 3.2 above the deck incl. coping, humpback profile,
deck ends at z 0.3-0.5 so they meet the ground.

## Round 1 (first quick build)
Scores: 4 / 4 / 4 / 4 / 3 / 3 / 4 / 3
Problems seen:
- Spandrel faces are large flat planes: reads as moulded clay, not masonry.
- Long plain parapets; nothing breaks the run between the end pillars.
- 3-arch variant at 4564 tris (over 4000): flagstones and per-segment coping too fine.
Changes: protruding ashlar blocks scattered on the spandrels (rejection-sampled away from the arch rings),
pilasters rising from the cutwaters to the string course, coping stones of 1-2 segments (hand-laid rhythm),
18-20 deck stations, 4-slab staggered rows, moss lumps as plain boxes.

## Round 2 (full-res check at 600 px)
Scores: 4 / 4 / 4 / 4 / 3 / 3 / 4 / 3
Problems seen:
- Single-arch spandrels are too thin for ashlar blocks, so its faces still read plain; parapet walls (inside
  and out) are the largest flat areas in the gameplay view.
- Deck patchwork too noisy (too many pale slabs); no warm accent anywhere: all three are monochrome stone.
Changes: ashlar accents on both faces of every parapet (sloped with the deck), fewer pale slabs, iron lanterns
with glowing panes on two diagonal end pillars (2- and 3-arch variants), footing boulders thinned on the
3-arch to pay for them.

## Round 3
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3
Seen: humpback silhouettes with 1/2/3 arches read clearly at 78 studs; voussoir rings with keystones,
cutwaters + pilasters, string course, coping rhythm, staggered flagstones and lanterns give three levels of
detail. Tris 3052 / 3668 / 3860 of 4000.
Remaining weaknesses: 3-arch has little budget headroom; deck slope peaks ~33 deg on the single arch (steep
but walkable; storybook humpback); no wing walls at the ends (kept inside the 40-56 length range).

## Round 4 (final socket check)
Problem seen in the manifest: `end_a`/`end_b` came out 0.7 above the asset base because the string course
dipped below ground at the ramp ends, so the pivot (lowest point) was under the deck ends.
Change: the string course stops where the ramp is low (no geometry below z = 0); deck ends now sit at the
asset base as required. Tris 3020 / 3636 / 3828. Rebuilt in full.
