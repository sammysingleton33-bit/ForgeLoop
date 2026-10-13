# building_smithy: review log (author rounds, D-019)

Generator `generators/building_smithy.py` v1 (helpers in `generators/_civic_common.py`), budget class
`building_medium` (8000), 6 variants: kingdoms cycle red/blue/green/yellow/red/blue.
Layouts: pent (gable rear block + lean-to) 01/04, shed (one mono-pitch roof from a tall back wall) 02/05,
loft (two-storey rear block + lean-to) 03/06. The forge side alternates.
Images: `previews/building_smithy.jpg`, `renders/building_smithy/<id>_hero.png`,
`renders/building_smithy/building_smithy_gameplay.png` (overwritten per build).

## Round 1 (first quick build)
Scores: silhouette 3, variation 4, readability 2, proportions 3, palette 4, detail 3, cohesion 4, tris 4.
Seen in the images:
- It read as a cottage with a porch. The lean-to was low (7 studs) and deep, so from the hero view and from
  80 studs the forge, anvil and fire were invisible inside a dark cave.
- The lean-to pitch was only 11-20°.
- Shed variants (02/05) had plain untextured side walls.
- Loft chimney (03/06): it covered the upper front windows.
Changes:
- Added a 4.4-stud forecourt yard (plinth extended, flagstones). The anvil, quench barrel and grindstone moved out into it.
- Front posts raised to 8.4 and rear blocks to about 12.2, so the lean-to is about 20°.
- The forge fire-box arch is painted `fire`, with a bigger `ember` bed and bigger flames.
- Shed side walls got kingdom quoins (stone) or a kit timber frame (plaster).
- Loft upper windows moved to the non-forge half.

## Round 2
Scores: silhouette 4, variation 4, readability 3, proportions 4, palette 4, detail 3, cohesion 4, tris 4.
Seen in the images: the yard with the anvil reads, but the forge still sat at the back wall in the roof's shadow, so the
glow was not visible. The chimney poked out of the roof behind and did not mark the building as a forge.
Changes:
- The forge moved to the front of the workshop on its side. The glowing fire-box faces the street, and the hood and tall
  stone chimney rise through the front of the lean-to, so the vertical sits at the street side and is unlike the cottage's
  gable chimney.
- Coal heap moved to the yard corner, and the iron stock to the rack.
- The quench barrel moved to the far side of the anvil so it never hides the fire.

## Round 3 (after the kit update)
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 5, tris 3.
Seen in the images:
- The kit's sagging tile slabs and crooked timbers make it look more storybook.
- The orange fire-box dots read at 80 studs together with the open dark front, the front chimney, the banner and the anvil sign.
- The big stone faces (rear block, shed back wall) looked flat, and loft 06 went over budget at 8032.
- The anvil was a small dark speck from the street.
Changes:
- The forge chimney uses the kit's new chimney with 2 pots.
- Scattered proud stones on plain stone walls (`_civic_common.wall_stones`).
- Plinth blocks are longer (3.4-5.2).
- 2 horseshoes instead of 3.
- The anvil body is scaled 1.3x on a shorter stump, with the work face at about 3.5, so it reads from the street.
Result: 6212-7760 tris of 8000. Validation: all PASS. Variation: PASS (min 0.133).

## Final (full build, 600 px heroes)
Final self-scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 5, tris 3.
Seen in the full-resolution sheet:
- Every variant shows an open dark front with the orange fire-box and flames under the hood, a tall stone chimney with
  pots on the street side, and a chunky anvil plus quench barrel in the flagstone forecourt.
- Kingdom identity comes from the banner on the outer post, the shields on the rack, the roof and the shutters.
- The anvil sign hangs from the forge-side post.
- In the gameplay strip at 80 studs all six read as smithies, not cottages.
- Pent, shed and loft give three clearly different masses.
Remaining weaknesses:
- The back of the workshop (weapon rack, shields, bellows) is in deep shade and barely visible from the street.
- The loft chimneys reach 31 studs, which is very tall but deliberate.
- Variant 06 sits at 7760 of 8000 tris, with little headroom for additions.
