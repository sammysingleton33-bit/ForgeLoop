# prop_well — author review log (D-019)

Images: `previews/prop_well.jpg`, `renders/prop_well/prop_well_01_hero.png`, `renders/prop_well/prop_well_04_hero.png`,
`renders/prop_well/prop_well_gameplay.png` (overwritten each round).
Rubric order: silhouette / variation / readability / proportions / palette / detail / kit cohesion / tris.

Variants: 01 red kingdom-tile gable, 02 blue thatch gable on a paved apron, 03 green thatch gable with a stone
trough, 04 yellow Sunspire tiled dome with gold finial on a paved apron. All: coursed round stone curb with
capstones, water, two braced posts, winch (axle, rope drum, iron crank), rope + hanging bucket.

## Round 1 (first quick build)
Scores: 4 / 3 / 4 / 4 / 4 / 3 / 4 / 2
Problems seen:
- Over budget (1864-2120 / 1800): barrel, spare bucket, bevelled beams, 5 flowers.
- Flowers at the curb foot were pale lumps without leaves: read as pebbles.
- Tile variants 01 and 04 nearly identical (min silhouette diff 0.119); the two thatch wells too.
Changes: plain-box beams, barrel dropped, spare bucket only where there is no apron/trough, curb core 10
segments, leafy tufts with small flower heads.

## Round 2
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3
Problems seen:
- Variant 04 replaced by a Sunspire dome (ring beam on the posts, lathed dome, gold finial): strong
  silhouette change, but the dome was a smooth cap with no tile language.
Changes: two stepped tile courses on the dome (same ring-step idea as kit.cone_roof), flat underside cap.

## Round 3
Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3
Seen: wells read at 40 studs from roof shape + curb; bucket, crank and rope visible in every hero; kingdom
colour via tiles / pennant / finials. Min silhouette diff 0.21. Tris 1642-1778 / 1800.
Change after review: dome courses recoloured (trim band low, dark tiles high) so the top does not read as a
purple cap. Remaining weaknesses: little budget headroom; the two thatch variants share a roof form (kept
for kit cohesion with the cottages).

## Fresh-review round 2 (FORGE-02 lead: NEEDS-WORK, variation 2 / palette 2 / silhouette 3)
Problems reported: well_02 and well_03 were the same tan-roof well; tan roofs read as draped cloth; well_04 an
orange onion dome with a purple band; well_01 a fully kingdom-red roof; tris near the 1800 cap.
Changes: four forms now.
- 01 terracotta (`clay`) kit tile gable with red barge boards / ridge and gold finials.
- 02 Frostmere square-pyramid shingle roof (kit `cone_roof`, 4 sides, stepped courses, silver finial) on four
  corner posts with a square top frame.
- 03 open crank frame, no roof: tall braced posts, head beam, a big spoked hand-wheel instead of the crank,
  emerald oak board with ivory border, emerald pennant, stone trough.
- 04 kit thatch with pinned ridge band and layered rows (muted straw) carrying a large gold sun on a ridge
  post and a gold ball finial; dome and purple removed.
Budget: curb blocks every 2.4 studs, one bucket hoop, fewer tufts, no purple flowers. Check `roof>=1` replaced
by `posts>=2` (the open frame has no roof).
Seen (sheet): four distinct silhouettes (min diff 0.30). Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 3.
Tris 1364-1780 / 1800.

## Fresh-review round 3 (final; FORGE-02 lead notes)
Problems reported: well_01 salmon terracotta with flame-like gold spikes; well_04 thatch reads as hay and
dominates (1780 tris); well_02 mostly blue with a white spire; well_03 plaque/pennant borders and leaf small.
Changes:
- 01: neutral timber shingles with brick-red fascia boards, barge boards and ridge; gold crown on a ridge post.
- 02: grey slate square pyramid, azure fascia band as trim, white star finial on an iron spike.
- 03: 3.0 x 2.7 emerald plaque with ivory border and a 1.9 ivory oak leaf; pennant with ivory border bands.
- 04: slimmer thatch (no pins, 0.85 overhang) with a saturated gold ridge cap, ivory bands and bronze end caps,
  large sun on a ridge post; no apron / spare bucket / tufts -> 1592 tris.
Seen (`previews/prop_well.jpg`): four forms, kingdom colour as trim and finials. Tris 1450-1706 / 1800,
min silhouette diff 0.26. Scores: 4 / 4 / 4 / 4 / 4 / 4 / 4 / 4.
Note: `emblem("oak")` is now the full leaf for all callers; prop_banner pins the earlier leaf ("oak_tilted") so
its committed geometry hashes are unchanged (checked: 25/25 banner/goods/cart/bridge assets identical).
