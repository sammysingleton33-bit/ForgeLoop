# building_market: review log (author rounds, D-019)

Generator `generators/building_market.py` v1 (helpers in `generators/_civic_common.py`), budget class
`building_small` (5000), 6 variants: kingdoms cycle red/blue/green/yellow/red/blue.
Shapes: 01 gable (greengrocer), 02 lean awning (fishmonger), 03 vault hoops (harvest), 04 pavilion
(baker), 05 double gable (potter + greengrocer), 06 long pavilion (cloth merchant).
Images: `previews/building_market.jpg`, `renders/building_market/<id>_hero.png`,
`renders/building_market/building_market_gameplay.png` (overwritten on every build; the round
descriptions below say what each one showed).

Rubric: silhouette, variation, readability at gameplay distance, proportions, palette, detail density,
cohesion with the kit, triangle cost (1-5).

## Round 1 (first quick build)
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 3, cohesion 3, tris 2.
Seen in the images:
- Every stall was floating about 9 studs above its shadow. The hanging sign sat on the ground far in front of the
  stall. Cause: after a tuple refactor the sign height read the wrong field, which put it at z=-9 and moved the pivot.
- 5 of 6 variants were over the 5000 budget: 5328, 6044, 5576, 7630 (double stall) and 5186.
- The striped canopies, valance flaps and pennants already read very well at 62 studs. The pavilion has the strongest silhouette.
Changes: fixed the sign height index. Kerb blocks are now unbevelled and longer (deck kerb from 700 to 240 tris). Removed
the post pads hidden inside the deck. Plates are now plain boxes. Produce mounds use 6-segment lathes, crates hold
3 loose items, and the pumpkin, cabbage and jug lathes are slimmer. Fewer hanging strings. The double stall is narrower,
its second bay has no hanging goods and only one basket, and it keeps only 3 of its pennants.

## Round 2
Scores: silhouette 4, variation 4, readability 4, proportions 4, palette 4, detail 3, cohesion 3, tris 4.
Seen in the images:
- Lean (02): the three rafters poked through the canvas as dark diagonal streaks. Pavilions (04/06): the hip rafters
  showed along the hips.
- The lower half of every stall was a dark brown plank counter with no kingdom colour.
- Lean (02): the high back edge was plain. Double (05): the second canopy used cloth_light, which read as pink, not red.
Changes: lean rafters are lowered 0.45 and thinner. Pavilion hip rafters are lowered 0.55 and 0.42 thick. Added pennants on
the lean's high back corners. Every counter now has a scalloped valance under the top board, alternating kingdom cloth and
canvas. Both canopies of the double use the kingdom cloth. Pavilion stripes use 2 segments and the vault arc uses 6, which
keeps the budget after adding the valance.

## Round 3 (after the kit update; final full build)
Scores: silhouette 5, variation 4, readability 5, proportions 4, palette 4, detail 4, cohesion 4, tris 4.
Seen in the images: no canvas is pierced. In the gameplay strip at 62 studs every stall is named by its striped canopy
alone, and the six canopy shapes are distinct (min silhouette diff 0.29). The kingdom colours appear on the canopy, the
counter valance and the pennants. Goods read as coloured heaps: red apples, green cabbages, orange pumpkins, loaves, fish
on ice, cloth bolts, clay jugs. Triangles are 4122-4866 of 5000. Validation: all PASS. Variation: PASS.
Remaining weaknesses:
- Fish on ice (02) is low-contrast, grey on white.
- Goods under the canopy are partly in shade in the hero view.
- The canvas is flat-shaded with 2-4 segments, so the facets show in close-ups.
