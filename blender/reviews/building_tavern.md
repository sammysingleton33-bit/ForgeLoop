# building_tavern — review log (author rounds, D-019)

Rubric: reviews/README.md. Scores are the author's self-assessment from the rendered images.
Reference for cohesion: previews/house_cottage.jpg.

## Round 1 (v1, --quick, 6 variants)
Images: previews/building_tavern.jpg (round-1 state), renders/building_tavern/building_tavern_01_hero.png, _02_hero.png
Tris 9676–12204 / 12000 (06 failed budget before trimming), variation min diff 0.079 (04 vs 05) FAIL.

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 3 | 2 | 3 | 2 | 4 | 4 | 4 | 2 |

Problems seen:
- 3-storey variants are tall narrow tower houses (46 studs tall on a 28-stud front): no "wide frontage".
- The hanging sign is almost invisible: board hung edge-on to the street (YZ plane) and small.
- 04 and 05 are the same massing (2 storeys + wing, same chimney side) -> variation fail.
- Over budget on 3-storey tile variant (plinth blocks, 2-row dormer roofs, many back windows).
Changes: frontage 30.5–35.5, lower storeys (9.8–10.2 / 8.2–8.6 / 7.4–7.8), flatter pitches; bigger sign
mounted lower; 05 re-specified; bigger plinth blocks, 1-row dormer roofs, fewer back/side windows upstairs.

## Round 2 (v1, --quick)
Images: previews/building_tavern.jpg (round-2 state), renders/building_tavern/building_tavern_05_hero.png
Tris 10148–11508, variation min diff 0.070 (01 vs 06) FAIL.

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 3 | 2 | 3 | 4 | 4 | 4 | 4 | 3 |

Problems seen: proportions now read as a wide inn, but (a) the sign still vanishes in the front-on gameplay
strip because it is edge-on, (b) all variants share one massing (box + roof + small gabled porch), so the
3-storey tile variants are near-identical in silhouette.
Changes: sign board now hangs from a crossbar at the bracket tip facing the street; new `porch` param:
`pentice` = full-width lean-to on posts sheltering the outdoor seating (changes the side silhouette) vs the
gabled entrance `gable` porch; 06 gets the cart-shed wing; pentice posts plain boxes for budget.

## Round 3 (v1, --quick)
Images: previews/building_tavern.jpg (round-3 state), renders/building_tavern/building_tavern_03_hero.png, _01_hero.png
Tris 9600–11524, variation min diff 0.139 PASS.

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 3 | 4 | 4 | 4 | 4 | 3 |

Problems seen: the pentice roof slab was rotated the wrong way (rising away from the wall), so it showed as
a band across the first floor instead of a shelter; sign readable but still small.
Changes: fixed the slab rotation; sign board 4.6 x 3.5.

## Round 4 (v1, --quick)
Images: previews/building_tavern.jpg, renders/building_tavern/building_tavern_04_hero.png
Tris 9600–11524 / 12000, validation PASS 6/6, variation min diff 0.143 (01 vs 06).

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 5 | 3 |

Seen: at 80 studs each reads as "biggest timber house": jettied 2–3 storeys, dormers, oversized external
hearth chimney, glowing taproom windows, porch or pentice with lanterns, trestle tables in front, hanging
sign. Same timbers/windows/roofs as the cottage. Remaining weaknesses: the tankard icon is not legible at
80 studs (the sign reads as a coloured board); 3-storey variants are tall (43–45 studs); tris up to 96%.

## Final build (v1, full renders, after the kit storybook pass)
Images: previews/building_tavern.jpg, renders/building_tavern/building_tavern_02_hero.png
Rebuilt against the updated kit (sagging tile roofs, pinned thatch ridges on the main roof; dormer and
porch thatch use pins=False for budget), crooked-timber wander in the framing helper, clay pots on the
hearth chimney to match the kit chimney, table legs clamped to the ground.
Tris 9644–11556 / 12000, validation PASS 6/6, variation min diff 0.137 (01 vs 06).

| Silhouette | Variation | Readability | Proportions | Palette | Detail | Cohesion | Tris |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 4 | 4 | 5 | 3 |

At full resolution the tankard on the street-facing sign is legible in the hero views. Remaining:
3-storey variants are tall (43–45 studs); 06 uses 96% of the budget.
