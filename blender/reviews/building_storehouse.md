# building_storehouse: review log (author rounds, D-019)

Generator `generators/building_storehouse.py` v1 (helpers in `generators/_civic_common.py`), budget class
`building_medium` (8000), 6 variants: kingdoms cycle red/blue/green/yellow/red/blue.
Types: granary on staddle stones (01 thatch 4x3, 03 tile 3x3, 05 tile 5x3), warehouse with big double doors
(02 stone + tile, 04 plaster/timber + thatch, 06 stone + tile + lean-to cart shed).
Images: `previews/building_storehouse.jpg`, `renders/building_storehouse/<id>_hero.png`,
`renders/building_storehouse/building_storehouse_gameplay.png` (overwritten per build).

## Round 1 (first quick build, already on the updated kit: sagging tiles, pinned thatch)
Scores: silhouette 3, variation 4, readability 3, proportions 4, palette 4, detail 4, cohesion 4, tris 4.
Seen in the images:
- Granaries: the gap under the floor, which is the key "raised on staddle stones" read, was filled by the landing
  supports, a sack pile and the deposit pallet. Staddles were short (2.9), so at 80 studs they looked like a box on the ground.
- Warehouses: the big doors with one leaf ajar, the hoist and the hanging crate read well, but the yard props made them
  30 studs deep.
- Warehouse 06: the lean-to cart shed was on the far side and invisible in the hero view.
Changes:
- Staddle stones are 3.6 tall with wider mushroom caps.
- Sacks moved out of the gap to the stair foot and the landing.
- The deposit pallet and crate stack moved under the gable hoist, where carriers drop and the hoist lifts.
- Warehouse pallet and cart moved 1 stud closer.
- The 06 lean-to moved to +X.

## Round 2
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tris 4.
Seen in the images:
- At 80 studs the granaries clearly stand on legs and the warehouses show big kingdom-coloured barn doors under a street gable.
- The warehouse stone side walls were large flat faces with only windows and quoins.
Changes: scattered proud stones on the warehouse stone walls (10 per side, 5 on the back, 2 per front pier).

## Round 3 (final full build, 600 px heroes)
Final self-scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tris 4.
Seen in the full-resolution sheet:
- Granaries (01/03/05): weatherboarded timber boxes clearly lifted on mushroom staddle stones, with the open gap visible.
  Plank stairs and a railing run along the facade to a landing. The ladder, the gable hoist with its hanging sack,
  kingdom-colour door and shutters, and a sheaf sign are all visible.
- Warehouses (02/04/06): gable to the street with big kingdom-colour barn doors (one leaf ajar onto a dark interior) in a
  heavy timber frame. They also have a loft door, an apex hoist beam with a hanging crate, sacks, a hand cart, and a
  deposit pallet.
- 06 adds a tiled lean-to cart shed.
- In the gameplay strip at 80 studs, "on legs" against "big doors" separates the two types at a glance, and both are
  distinct from the cottage.
Triangles: 5098-7254 of 8000. Validation: all PASS. Variation: PASS (min 0.18).
Remaining weaknesses:
- 02 and 04 are the closest pair: same footprint idea, different materials.
- Neither interior is modelled, so the doors are facades (a dark recess behind the ajar leaf).
- Granary sack piles are small at 80 studs.
