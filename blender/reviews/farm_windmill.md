# farm_windmill — author review log (FORGE-02 farm worker)

Asset ids `farm_windmill_01..04`, budget `building_medium` (8000).
01 red: kingdom-stone round tower, conical red cap + finial + pennant, canvas sails (red cloth).
02 neutral: octagonal timber smock mill on a stone base, thatched boat cap, shuttered (slat) sails.
03 blue: whitewashed tower with exposed stones, timber gallery, blue-tile boat cap, mixed slat/canvas sails.
04 yellow: sandstone tower, gallery, saffron dome cap with gold finial (echoes Sunspire domes), canvas sails.
All: kit door (4.4 x 7.6 walkable), kit windows climbing the tower, string courses, stone plinth course,
tail pole with winding wheel, hoist beam with a sack on a rope, grain sacks, barrel, spare millstone.

## Round 1 — first pass (quick build)
Images: `previews/farm_windmill.jpg` (r1, overwritten), `scratchpad/farm/m.png` (01/03 at 640 px),
`scratchpad/farm/s.png` (sail debug render).

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 5 | 4 | 5 | 4 | 3 | 4 | 4 | 4 |

Problems seen
- "Canvas" sails were invisible: the geometry was there (checked volumes + an isolated render) but
  `canvas` is the same value as the neutral preview ground, so spread sails read as empty lattices.
- Sails a little ladder-like (dense bars); sacks read as small white eggs at the foot.
- Red stone tower looked whitewashed (stone_light banding).

Changes
- Sail cloth = kingdom `cloth_light` (neutral: `canvas_dark`) -> identity visible at 69 studs; new "mixed"
  style (2 canvas + 2 slats) for 03; sails 3.6 wide, sail bars every 1.25.
- Stone tower uses the kingdom stone ramp (`red_stone` / `_dark` / `_light`).
- Bigger, darker sacks (`cloth_brown`/`canvas_dark`/`apron`); weeds + flowers around the foot.

## Round 2
Images: `previews/farm_windmill.jpg`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 5 | 4 | 5 | 4 | 4 | 4 | 4 | 4 |

Problems: 03 was 41.4 studs tall (target 30-40); sacks still a loose row of blobs.
Changes (round 3): tower height 20.5-22, sail length 14.8 (smock 14.3) -> 36.6-39.9 tall; sacks stacked
as a pile (two lying on top) with a banded barrel beside them.

## Round 3 — final (full build)
Images: `previews/farm_windmill.jpg` (final), `renders/farm_windmill/farm_windmill_0N_hero.png`, `farm_windmill_gameplay.png`.

| silhouette | variation | readability | proportions | palette | detail | cohesion | tris |
|---|---|---|---|---|---|---|---|
| 5 | 4 | 5 | 4 | 4 | 4 | 4 | 4 |

Final 4720-5430 tris / 8000, 36.6-39.9 studs tall, variation min 0.243, BUILD PASS. At 67 studs the four
kingdoms separate instantly by sail cloth + cap shape (red cone, thatch boat, blue boat, saffron dome).
Remaining weaknesses: sails are static (a rigged/rotating sail assembly would need to be a separate mesh —
see the report); the windows on the round towers are flat kit windows tangent to a curved wall (small gaps
at the jambs); the smock mill is the darkest/brownest of the set.
