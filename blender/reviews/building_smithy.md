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

## Fresh review round 5

- Reviewer: fresh-context subagent (contact sheet `previews/building_smithy.jpg` only, zoomed PIL crops incl. grayscale; manifest tris), 2026-10-13
- Verdict: **NEEDS-WORK**; per-asset overrides: building_smithy_01=PASS, building_smithy_02=PASS, building_smithy_03=PASS, building_smithy_04=PASS, building_smithy_06=PASS
- Scores: silhouette 4, variation 3, readability 4, proportions 4, palette 4, detail_density 4, cohesion 4, triangle_cost 4
- Notes: It reads instantly as a forge (tall chimney, open front, glowing hearth, anvil signs), and the emblem banners are correct: crown, star, ivory oak leaf, and sun in a cream roundel. Variation fails: 01, 02, 04 and 05 are the same single-storey open gable shed with one ridge chimney, and in grayscale at 84 studs they are interchangeable. Only 03 and 06 (two-storey jettied) break the pattern. 05 is a near-duplicate of 01 in the same kingdom (asset NEEDS-WORK). Fix: give 05 (and ideally one of 02 or 04) its own massing, for example an L-plan with a stone forge hood and side bellows lean-to, a hipped roof with the chimney at the gable end, or a stone ground floor. Banners are small (~12 px at 84 studs) and smithies have no kingdom silhouette cue, so a larger gable banner would help. Tris 6212-7760/8000.

## Round 4 (fixes from fresh review round 5)
- 05 has a new layout, `ell`, an L-plan. On the non-forge side is a two-storey wing with its gable to the street:
  a kingdom-stone ground floor with quoins and a central arched door, and a jettied timber-framed plaster upper floor
  with two shuttered windows on the gable and one on the side. It has a steep (52 deg) tile roof and a big kingdom
  banner (2.8 x 3.6) hanging in the gable. The open workshop sits under a side lean-to that rises from outer eave posts
  to the wing wall, with a raking front beam. A plaster back wall closes it. The forge chimney rises at the far end,
  just above the wing ridge. The silhouette is tall stack, low lean-to, tall gable, unlike every other smithy. The
  grindstone moved into the workshop so it no longer blocks the door. W 18 -> 20 so the bellows clear the wing.
- 04 (cheap): the rear block's ridge now runs front-to-back (`cross=True`, 34 deg). A wide timbered gable faces the
  street over the lean-to, and the chimney clears it by 1.6. 04 no longer has 01's horizontal side-gable roofline.
- Kit oak: the civic `leaf` icon (a plain 14-point lozenge) is now the shared `emblem("oak")`: an ivory leaf with a
  bronze midrib and stem, flat-topped lobes. It is used on 03's banner and rack shields, and only that changes on 03.
- 01, 02 and 06 keep their geometry hashes.
Tris: 03 7352 -> 7652 (oak only), 04 7404 -> 7236, 05 6212 -> 6540 (of 8000). Variation min diff 0.139 (03 vs 06), PASS.
Seen (`previews/building_smithy.jpg`, `renders/building_smithy/building_smithy_05_hero.png`, extra 05 views from
front-left, back and straight front, and the gameplay strip at 85 studs with a grayscale copy): in grayscale at
85 studs, 05 reads as a gable-fronted house with a separate end chimney. 04 shows a front gable peak. 01 shows a
long side-gable ridge and 02 a mono-pitch shed. The new 05 gable banner reads at distance. The back of 05 is a plain
plaster and stone gable, which is acceptable for a side rarely seen.
Remaining: the civic crown (01, 05 banners and shields) is still the civic single-colour outline, not
`crown_outlines`. Aligning it would change 01's hash.
Self-scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 4, cohesion 4, tris 3.

## Fresh review round 6

- Reviewer: fresh-context subagent (contact sheet `blender/previews/building_smithy.jpg` only; crops, zooms and grayscale checks; 2026-10-13)
- Verdict: **PASS** (asset overrides: building_smithy_04=NEEDS-WORK)
- Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail_density 4, cohesion 3, triangle_cost 3
- Notes: 01, 02, 03, 05, 06 pass; 04 NEEDS-WORK. All six read as smithies (chimney, forge glow, anvil sign) and each can be told apart in grayscale at 85 studs; closest pairs are 01/02 (single-storey sheds) and 03/06 (two-storey plus lean-to), separated by chimney position, gable end and stone wing. 04 fails readability: its only emblem is a tiny gold sun on a small cream disc on a gold banner; in grayscale at gameplay distance it reads as a light dot or rosette, not a sun (effectively gold on gold). Fix: large dark-ochre sun with pointed rays on a cream field, no ring, and/or a gable sun plaque like the 05 crown. Kit notes: crowns here are plain cream vs gold with band on soldier/banner, unify; emblem presence is thin on all variants (one small banner), consider a gable plaque on each. No flame. Tris 6512-7760 of 8000 (06 at 97%).
