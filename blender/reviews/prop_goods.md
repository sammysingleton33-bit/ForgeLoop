# prop_goods — author review log (D-019)

Images: `previews/prop_goods.jpg`, `renders/prop_goods/prop_goods_crates_01_hero.png`,
`renders/prop_goods/prop_goods_sacks_01_hero.png`, `renders/prop_goods/prop_goods_gameplay.png` (overwritten each round).
Rubric order: silhouette / variation / readability / proportions / palette / detail / kit cohesion / tris.

Variants: crates (red tarp), barrels (blue painted lid, lying cask with spigot, water bucket), sacks (green),
produce (yellow: pallet with apple/cabbage/pear baskets, pumpkins), merchant (red: cloth bolts in all four
kingdom colours, rope coil, clay jars), storehouse (blue: two-level crate stack, barrel, ladder, sacks).

## Round 1 (first quick build)
Scores: 4 / 4 / 3 / 4 / 4 / 3 / 4 / 4
Problems seen:
- The "tarp" was a box-shaped red cap on the top crate (cloth thickness offset along Z only, so its sides were
  paper-thin and it read as a lid).
- Sacks looked like vases/pots: round bodies, narrow necks, all standing.
Changes: `sheet(normal="auto")` offsets cloth along the local surface normal; new tablecloth tarp (flat top,
sides hanging with folds, diagonal corners, trim hem); slumped sack (wide base, short neck, flattened 0.66-0.8,
stronger noise); sack variant rebuilt as a pile of lying sacks with standing ones on top.

## Round 2
Scores: 4 / 4 / 3 / 4 / 4 / 4 / 4 / 4
Problems seen: lying sacks were sunk half into the ground and hidden behind the grain basket.
Changes: lying sacks laid side-on to the camera on two rows at their real half-thickness, basket and crate
moved to the flanks.

## Round 3
Scores: 4 / 4 / 3 / 4 / 4 / 4 / 4 / 4
Seen: six clearly different clusters (min silhouette diff 0.22), cloth tarp/bolts and painted lids carry the
kingdom colour, produce colours pop. Tris 696-1108 / 1800 (headroom left on purpose: these are scattered in
numbers).
Remaining weaknesses: small (3-4.5 tall) so they read as clutter, not landmarks, at 40+ studs (intended);
the rope coil on the merchant crate is simple.

## Fresh-review round 2 (FORGE-02 lead: NEEDS-WORK, palette 2)
Problems reported: sacks_01 had no green; merchant_01 cloth rolls in all kingdom colours; produce_01 cloth
mustard; storehouse_01 a remix of barrels_01.
Changes: sacks tied with emerald, an emerald band round the top sack and an emerald tablecloth tarp (ivory hem)
over the crate; merchant bolts = crimson, canvas, white, dark crimson only; produce cloth = saturated gold
(`field()`); storehouse_01 rebuilt as a lean-to (low front / tall back posts, knee braces, three stepped
azure tile courses) over a pallet of lying + standing sacks with a hanging lantern (no barrels).
Seen (`prop_goods_storehouse_01_hero.png`, `prop_goods_sacks_01_hero.png`): each variant carries a clear,
correct kingdom accent; storehouse has its own silhouette (min diff 0.26).
Scores: 4 / 4 / 3 / 4 / 4 / 4 / 4 / 4. Tris 788-1222 / 1800.
